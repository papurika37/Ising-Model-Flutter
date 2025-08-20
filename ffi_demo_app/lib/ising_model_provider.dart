import 'dart:async';
import 'dart:ffi';
import 'package:flutter/foundation.dart'; // ChangeNotifier のため
import 'package:ffi/ffi.dart';          // calloc, Pointer.toDartString のため
import 'ising_ffi.dart';


class IsingModelProvider with ChangeNotifier {
  late IsingFFI _ffi;
  IsingModelPtr? _modelPtr;

  List<int> _modelState = [];
  int _modelSize = 0;
  double _energy = 0.0;
  double _magneticMoment = 0.0;
  int _time = 0; // MCS (モンテカルロステップ/スイープ) の回数
  String _errorMessage = '';
  bool _isNativeLibLoaded = false;
  bool _isInitialized = false;
  bool _isRunning = false;
  Timer? _simulationTimer;

  final int _sweepsPerUpdate = 10; // UI更新ごとにC++側で実行するスイープ数

  // Getters
  List<int> get modelState => _modelState;
  int get modelSize => _modelSize;
  double get energy => _energy;
  double get magneticMoment => _magneticMoment;
  int get time => _time;
  String get errorMessage => _errorMessage;
  bool get isNativeLibLoaded => _isNativeLibLoaded;
  bool get isInitialized => _isInitialized;
  bool get isRunning => _isRunning;

  IsingModelProvider() {
    try {
      _ffi = IsingFFI(); // FFIインスタンスの取得（ロード試行）
      _isNativeLibLoaded = true;
    } catch (e) {
      _isNativeLibLoaded = false;
      _setError("Failed to load native simulation library: $e");
      // このエラーは main.dart 側でも検知してユーザーに通知することを推奨
    }
  }

  void _setError(String message) {
    _errorMessage = message;
    debugPrint("IsingModelProvider Error: $message"); // 開発中のログ出力
  }

  void _clearError() {
    if (_errorMessage.isNotEmpty) {
      _errorMessage = '';
    }
  }

  Future<bool> initializeModel(int n, double j, double temp) async {
    if (!_isNativeLibLoaded) {
      _setError("Native library not loaded. Cannot initialize model.");
      notifyListeners(); // UIにエラー状態を通知
      return false;
    }
    _clearError();
    if (_modelPtr != null && _modelPtr!.address != 0) {
      _ffi.deleteIsingModel(_modelPtr!);
      _modelPtr = null;
    }
    stopSimulation(); // 実行中なら停止

    try {
      _modelPtr = _ffi.createIsingModel(n, j, temp);
      if (_modelPtr == null || _modelPtr!.address == 0) {
        // C++側でエラーメッセージを取得する試み
        // IsingModelPtrがnullなので、直接はgetLastErrorを呼べないが、
        // create_ising_modelが失敗したことを示すメッセージを設定
        _setError("Failed to create Ising model (native code returned null). Check parameters (N > 0, Temp >= 0).");
        _isInitialized = false;
        notifyListeners();
        return false;
      }
      _modelSize = _ffi.getIsingModelSize(_modelPtr!);
      if (_modelSize <= 0) {
         _setError("Model size from native code is invalid ($_modelSize).");
         _isInitialized = false;
         notifyListeners();
         return false;
      }
      _isInitialized = true;
      _time = 0; // 初期化時に時間もリセット
      _updateModelData(isInitialization: true);
      return true;
    } catch (e) {
      _setError("FFI Exception during model initialization: $e");
      _isInitialized = false;
      notifyListeners();
      return false;
    }
  }

  void runModelSweeps({int sweepCount = 1}) {
    if (!_isInitialized || _modelPtr == null || _modelPtr!.address == 0) {
      debugPrint("Cannot run sweeps: Model not initialized or pointer is null.");
      return;
    }
    _clearError();
    try {
      _ffi.runIsingModelSweeps(_modelPtr!, sweepCount);
      _updateModelData();
    } catch (e) {
      _setError("FFI Exception during model sweeps: $e");
      notifyListeners(); // エラーをUIに通知
    }
  }

  void _updateModelData({bool isInitialization = false}) {
    if (!_isInitialized || _modelPtr == null || _modelPtr!.address == 0) return;

    final stateArraySize = _modelSize * _modelSize;
    if (stateArraySize <= 0) {
        _modelState = [];
    } else {
        final stateArrayPtr = calloc<Int32>(stateArraySize);
        try {
          _ffi.getIsingModelState(_modelPtr!, stateArrayPtr);
          _modelState = List<int>.generate(stateArraySize, (i) => stateArrayPtr[i]);
        } finally {
          calloc.free(stateArrayPtr);
        }
    }
    
    _energy = _ffi.getIsingModelEnergy(_modelPtr!);
    _magneticMoment = _ffi.getIsingModelMagneticMoment(_modelPtr!);
    _time = _ffi.getIsingModelTime(_modelPtr!);
    
    // UI更新通知
    // 初期化時、実行中、または手動ステップ実行時（!isInitializationは手動ステップと解釈）
    if (isInitialization || _isRunning || !isInitialized ) { 
        notifyListeners();
    }
  }

  void startSimulation({Duration interval = const Duration(milliseconds: 50)}) {
    if (!_isInitialized || _isRunning) return;
    _isRunning = true;
    notifyListeners(); // ボタンの表示などを更新
    _simulationTimer = Timer.periodic(interval, (timer) {
      if (!_isRunning) {
        timer.cancel();
        return;
      }
      runModelSweeps(sweepCount: _sweepsPerUpdate); // バッチ処理
    });
  }

  void stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _isRunning = false;
    notifyListeners(); // ボタンの表示などを更新
  }

  @override
  void dispose() {
    stopSimulation();
    if (_modelPtr != null && _modelPtr!.address != 0) {
      _ffi.deleteIsingModel(_modelPtr!);
      _modelPtr = null;
    }
    super.dispose();
  }
}