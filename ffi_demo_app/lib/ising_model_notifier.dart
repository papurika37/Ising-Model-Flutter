import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ffi/ffi.dart';
import 'ising_ffi.dart';
import 'ising_state.dart';
import 'ising_isolate_messages.dart';

final isingModelProvider = StateNotifierProvider<IsingModelNotifier, IsingModelState>((ref) {
  final notifier = IsingModelNotifier();
  ref.onDispose(() {
    print("IsingModelNotifier: ref.onDispose called, disposing Isolate resources.");
    notifier.disposeIsolateResources();
  });
  return notifier;
});

class IsingModelNotifier extends StateNotifier<IsingModelState> {
  ReceivePort? _receivePortFromIsolate;
  SendPort? _sendPortToIsolate;
  Isolate? _simulationIsolate;
  bool _isolateCommunicationEstablished = false; // Isolateとの通信路確立フラグ
  Timer? _simulationTimer;
  final int _sweepsPerUpdate = 10;

  IsingModelNotifier() : super(const IsingModelState(errorMessage: "シミュレーションエンジンを初期化中...")) {
    _initializeIsolate();
  }


  Future<void> _initializeIsolate() async {
    if (_simulationIsolate != null) return;
    _receivePortFromIsolate = ReceivePort();
    try {
      _simulationIsolate = await Isolate.spawn(
        _isingIsolateEntrypoint,
        _receivePortFromIsolate!.sendPort,
        onError: _receivePortFromIsolate!.sendPort,
        onExit: _receivePortFromIsolate!.sendPort,
        debugName: "IsingSimulationIsolate",
      );
      print("IsingModelNotifier: Isolate spawn requested.");

      _receivePortFromIsolate!.listen((message) {
        if (message is SendPort) {
          _sendPortToIsolate = message;
          _isolateCommunicationEstablished = true;
          print("IsingModelNotifier: Communication channel with Isolate established. Waiting for FFI ready signal.");
          // ここではまだ isNativeLibLoaded を true にしない。Isolateからの専用通知を待つ。
        } else if (message is FromIsolateMessage) {
          _handleMessageFromIsolate(message);
        } else if (message is List && message.length == 2 && message[0] is String) {
          _setErrorAndCleanup("Isolate exited or errored unexpectedly: ${message[0]} ${message[1]}");
        } else if (message == null) { // onExitからnullが送られる
          _setErrorAndCleanup("Isolate exited.");
        } else {
          print("IsingModelNotifier: Received unknown message: $message");
        }
      }, onError: (error, stackTrace) { // Listen stream error
        _setErrorAndCleanup("Error listening to Isolate port: $error");
      });
    } catch (e) {
      _setErrorAndCleanup("IsingModelNotifier: Failed to spawn Isolate: $e");
    }
  }
  void _cleanupAfterIsolateFailure() {
    print("IsingModelNotifier: Cleaning up after Isolate failure or unexpected exit.");
    _isolateCommunicationEstablished = false;
    _sendPortToIsolate = null;
    _simulationIsolate?.kill(priority: Isolate.immediate); // 念のため強制終了
    _simulationIsolate = null; 
    _receivePortFromIsolate?.close(); // ポートを閉じる
    _receivePortFromIsolate = null;
    // 状態を明確なエラー/未ロード状態に設定
    state = state.copyWith(
      isNativeLibLoaded: false, 
      isInitialized: false, 
      isRunning: false,
      // errorMessage は _setError で既に設定されているか、ここで設定する
      // errorMessage: state.errorMessage.isNotEmpty ? state.errorMessage : "Isolate communication failed."
    );
  }

  void _handleMessageFromIsolate(FromIsolateMessage message) {
    switch (message.status) {
      case IsolateResponseStatus.ready:
        print("IsingModelNotifier: Isolate reported READY. Data: ${message.data}");
        // Isolate内のFFIロード成功通知を期待
        if (message.data is String && (message.data as String).startsWith("FFI loaded")) {
            state = state.copyWith(isNativeLibLoaded: true, clearErrorMessage: true);
            print("IsingModelNotifier: Native library confirmed loaded by Isolate.");
        } 
        // モデル初期化成功の応答も IsolateResponseStatus.ready で来る可能性がある
        else if (message.data is IsingDataPayload) {
          final payload = message.data as IsingDataPayload;
          state = state.copyWith(
            isNativeLibLoaded: true, // データが来たならFFIはロード済み
            modelStateGrid: payload.modelStateGrid, modelSize: payload.modelSize,
            energy: payload.energy, magneticMoment: payload.magneticMoment, time: payload.time,
            isInitialized: true, // ★ここで初期化完了とする
            clearErrorMessage: true,
          );
           print("IsingModelNotifier: Model initialized by Isolate. Size: ${payload.modelSize}");
        }
        break;
      case IsolateResponseStatus.data:
        if (message.data is IsingDataPayload) {
          final payload = message.data as IsingDataPayload;
          state = state.copyWith(
            modelStateGrid: payload.modelStateGrid, modelSize: payload.modelSize,
            energy: payload.energy, magneticMoment: payload.magneticMoment, time: payload.time,
            clearErrorMessage: true,
          );
        }
        break;
      case IsolateResponseStatus.error:
        final errorMsg = message.data as String? ?? "Unknown error from Isolate.";
        _setError(errorMsg); // UIで表示されるエラーメッセージを設定
        state = state.copyWith(isRunning: false); // エラー時は自動実行停止
        if (errorMsg.contains("Failed to load FFI")) { // IsolateからのFFIロード失敗通知
            state = state.copyWith(isNativeLibLoaded: false); // isNativeLibLoadedをfalseに
            _cleanupAfterIsolateFailure();
        }
        break;
      case IsolateResponseStatus.modelDisposed:
        state = state.copyWith(isInitialized: false, modelSize: 0, modelStateGrid: [], time: 0);
        print("IsingModelNotifier: Isolate reported model disposed.");
        break;
    }
  }
  
  void _setErrorAndCleanup(String errorMessage) {
    _setError(errorMessage);
    _isolateCommunicationEstablished = false;
    _sendPortToIsolate = null;
    // _simulationIsolate?.kill(); // Isolateが既にexitしている可能性もあるので注意
    _simulationIsolate = null; 
    _receivePortFromIsolate?.close();
    _receivePortFromIsolate = null;
    state = state.copyWith(isNativeLibLoaded: false, isInitialized: false, isRunning: false);
  }

  void _sendCommandToIsolate(IsolateCommand command, {dynamic params}) {
    if (_sendPortToIsolate != null && _isolateCommunicationEstablished) {
      _sendPortToIsolate!.send(ToIsolateMessage(command, params: params));
    } else {
      _setError("Isolate not ready or communication channel not established. Cannot send command: $command");
      state = state.copyWith(isRunning: false);
    }
  }

  void _setError(String message) {
    state = state.copyWith(errorMessage: message);
    print("IsingModelNotifier Error: $message");
  }
  void clearError() {
    if (state.errorMessage.isNotEmpty) { state = state.copyWith(clearErrorMessage: true); }
  }

  Future<void> initializeModel(int n, double j, double temp) async {
    if (!_isolateCommunicationEstablished) { 
      _setError("Isolate communication not established. Cannot initialize model."); 
      return; 
    }
    clearError();
    stopSimulation();
    
    state = state.copyWith(
      currentTemperature: temp, 
      isInitialized: false, // 初期化開始時にフラグをリセット
      modelSize: n, // 先にUIに反映させてちらつきを防ぐ
      modelStateGrid: List.filled(n*n, 0), // 仮の空グリッド
      time: 0, energy: 0, magneticMoment: 0 // 値もリセット
    );

    _sendCommandToIsolate(IsolateCommand.disposeModel); // 古いモデルをIsolate側で破棄
    _sendCommandToIsolate(IsolateCommand.init, params: InitParams(n: n, j: j, temp: temp, libraryPath: ""));
  }

  void runModelSweeps({int sweepCount = 1}) {
    if (!state.isInitialized) { return; }
    if (!_isolateCommunicationEstablished) { _setError("Isolate communication not established."); return; }
    clearError();
    _sendCommandToIsolate(IsolateCommand.runSweeps, params: RunSweepsParams(numSweeps: sweepCount));
  }

  void setTemperature(double newTemperature) {
    if (!state.isInitialized) {
      _setError("Model not initialized. Cannot set temperature.");
      return;
    }
    if (!_isolateCommunicationEstablished) {
      _setError("Isolate communication not established.");
      return;
    }
    clearError();
    state = state.copyWith(currentTemperature: newTemperature); // UI即時反映
    _sendCommandToIsolate(IsolateCommand.setTemperature, params: SetTemperatureParams(newTemperature: newTemperature));
  }

  void startSimulation({Duration interval = const Duration(milliseconds: 50)}) {
    if (!state.isInitialized || state.isRunning) return;
    if (!_isolateCommunicationEstablished) { _setError("Isolate communication not established."); return; }
    state = state.copyWith(isRunning: true);
    _simulationTimer = Timer.periodic(interval, (timer) {
      if (!state.isRunning) { timer.cancel(); return; }
      runModelSweeps(sweepCount: _sweepsPerUpdate);
    });
  }
  void stopSimulation() {
    _simulationTimer?.cancel(); _simulationTimer = null;
    if (state.isRunning) { state = state.copyWith(isRunning: false); }
  }
  
  void disposeIsolateResources() {
    print("IsingModelNotifier: disposeIsolateResources called by ref.onDispose.");
    if (_sendPortToIsolate != null) {
      _sendCommandToIsolate(IsolateCommand.disposeIsolate);
    } else { // SendPortが確立する前にNotifierが破棄された場合など
        _simulationIsolate?.kill(priority: Isolate.immediate);
    }
    _simulationIsolate = null;
    _receivePortFromIsolate?.close();
    _receivePortFromIsolate = null;
    _sendPortToIsolate = null;
    _isolateCommunicationEstablished = false;
  }

  @override
  void dispose() {
    print("IsingModelNotifier's own dispose method called.");
    // disposeIsolateResources(); // ref.onDispose で呼ばれるので通常は不要
    super.dispose();
  }
}

// --- Isolate Entry Point ---
void _isingIsolateEntrypoint(SendPort sendPortToMain) {
  // ... (この関数は前回の回答から変更なし。FFIロード成功時に IsolateResponseStatus.ready を送る) ...
  final receivePortForIsolate = ReceivePort();
  sendPortToMain.send(receivePortForIsolate.sendPort);

  IsingFFI? ffi;
  IsingModelPtr? modelPtr;

  try {
    ffi = IsingFFI();
    sendPortToMain.send(FromIsolateMessage(IsolateResponseStatus.ready, data: "FFI loaded in Isolate.")); // ★重要
  } catch (e) {
    sendPortToMain.send(FromIsolateMessage(IsolateResponseStatus.error, data: "Isolate: Failed to load FFI: $e"));
    Isolate.exit(); 
    return; 
  }

  receivePortForIsolate.listen((message) {
    if (message is ToIsolateMessage) {
      if (ffi == null) {
        sendPortToMain.send(FromIsolateMessage(IsolateResponseStatus.error, data: "Isolate: FFI not initialized."));
        return;
      }
      try {
        switch (message.command) {
          case IsolateCommand.init:
            IsingModelPtr? currentModelToDispose = modelPtr;
            if (currentModelToDispose != null && currentModelToDispose.address != 0) { ffi.deleteIsingModel(currentModelToDispose); }
            final params = message.params as InitParams; modelPtr = ffi.createIsingModel(params.n, params.j, params.temp);
            IsingModelPtr? newModel = modelPtr;
            if (newModel != null && newModel.address != 0) {
              final size = ffi.getIsingModelSize(newModel); final stateArrayPtr = calloc<Int32>(size * size); List<int> currentModelState = [];
              if (size > 0) { try { ffi.getIsingModelState(newModel, stateArrayPtr); currentModelState = List<int>.generate(size * size, (i) => stateArrayPtr[i]); } finally { calloc.free(stateArrayPtr); } }
              sendPortToMain.send(FromIsolateMessage( IsolateResponseStatus.ready, data: IsingDataPayload( modelStateGrid: currentModelState, modelSize: size, energy: ffi.getIsingModelEnergy(newModel), magneticMoment: ffi.getIsingModelMagneticMoment(newModel), time: ffi.getIsingModelTime(newModel), ), ));
            } else { modelPtr = null; sendPortToMain.send(FromIsolateMessage(IsolateResponseStatus.error, data: "Isolate: Failed to create model (pointer is null).")); }
            break;
          case IsolateCommand.runSweeps:
            IsingModelPtr? currentModelForSweeps = modelPtr;
            if (currentModelForSweeps != null && currentModelForSweeps.address != 0) {
              final params = message.params as RunSweepsParams; ffi.runIsingModelSweeps(currentModelForSweeps, params.numSweeps);
              final size = ffi.getIsingModelSize(currentModelForSweeps); final stateArrayPtr = calloc<Int32>(size * size); List<int> currentModelState = [];
              if (size > 0) { try { ffi.getIsingModelState(currentModelForSweeps, stateArrayPtr); currentModelState = List<int>.generate(size * size, (i) => stateArrayPtr[i]); } finally { calloc.free(stateArrayPtr); } }
              sendPortToMain.send(FromIsolateMessage( IsolateResponseStatus.data, data: IsingDataPayload( modelStateGrid: currentModelState, modelSize: size, energy: ffi.getIsingModelEnergy(currentModelForSweeps), magneticMoment: ffi.getIsingModelMagneticMoment(currentModelForSweeps), time: ffi.getIsingModelTime(currentModelForSweeps), ), ));
            } else { sendPortToMain.send(FromIsolateMessage(IsolateResponseStatus.error, data: "Isolate: Model not initialized for runSweeps.")); }
            break;
          case IsolateCommand.setTemperature:
            IsingModelPtr? currentModelForTempSet = modelPtr;
            if (currentModelForTempSet != null && currentModelForTempSet.address != 0) {
              final params = message.params as SetTemperatureParams;
              ffi.setIsingModelTemperature(currentModelForTempSet, params.newTemperature);
              // オプション: 温度設定完了を通知
              // sendPortToMain.send(FromIsolateMessage(IsolateResponseStatus.ready, data: "Temperature set to ${params.newTemperature}"));
            } else { sendPortToMain.send(FromIsolateMessage(IsolateResponseStatus.error, data: "Isolate: Model not initialized for setTemperature.")); }
            break;
          case IsolateCommand.disposeModel:
            IsingModelPtr? currentModelToDisposeUser = modelPtr;
             if (currentModelToDisposeUser != null && currentModelToDisposeUser.address != 0) {
              ffi.deleteIsingModel(currentModelToDisposeUser); modelPtr = null;
              sendPortToMain.send(FromIsolateMessage(IsolateResponseStatus.modelDisposed)); }
            break;
          case IsolateCommand.disposeIsolate:
            IsingModelPtr? finalModelToDispose = modelPtr;
            if (finalModelToDispose != null && finalModelToDispose.address != 0) {
              ffi.deleteIsingModel(finalModelToDispose); modelPtr = null; }
            receivePortForIsolate.close(); Isolate.exit();
        }
      } catch (e, s) { sendPortToMain.send(FromIsolateMessage(IsolateResponseStatus.error, data: "Isolate Exception: $e\nStack: $s")); }
    } else { sendPortToMain.send(FromIsolateMessage(IsolateResponseStatus.error, data: "Isolate received unknown message type: ${message.runtimeType}")); }
  });
}