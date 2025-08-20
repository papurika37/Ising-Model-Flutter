// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:collection/collection.dart'; // 不要
import 'ising_model_notifier.dart';
import 'ising_state.dart';

// ... (main, MyApp, IsingModelPage のクラス定義は変更なし) ...
void main() { /* ...前回答と同じ... */ runApp( const ProviderScope( child: MyApp(), ), ); }
class MyApp extends StatelessWidget { /* ...前回答と同じ... */ const MyApp({super.key}); @override Widget build(BuildContext context) { return MaterialApp( title: 'Ising Model FFI (Riverpod + Isolate)', theme: ThemeData( colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal), useMaterial3: true, ), home: const IsingModelPage(), ); } }
class IsingModelPage extends ConsumerStatefulWidget { /* ...前回答と同じ... */ const IsingModelPage({super.key}); @override ConsumerState<IsingModelPage> createState() => _IsingModelPageState(); }


class _IsingModelPageState extends ConsumerState<IsingModelPage> {
  final _nController = TextEditingController(text: '32');
  final _jController = TextEditingController(text: '1.0');
  bool _fatalErrorDialogShownOnce = false;

  @override
  void initState() { /* ...前回答と同じ... */ 
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isingState = ref.read(isingModelProvider);
      if (!isingState.isNativeLibLoaded && 
          (isingState.errorMessage.contains("Failed to load") || 
           isingState.errorMessage.contains("Unsupported platform") ||
           isingState.errorMessage.contains("exited") ||
           isingState.errorMessage.contains("spawn Isolate"))) {
        // initState でダイアログを出す場合、buildメソッドが呼ばれる前に状態が変わる可能性があるため、
        // buildメソッド内で状態に応じて表示を切り替える方が堅牢です。
        // ここでのダイアログ表示は削除または build メソッドのロジックに委ねることを検討。
        // 今回は build メソッドで集中的に処理するため、ここでのダイアログ呼び出しはコメントアウトまたは削除。
        // _showFatalErrorDialog(context, "Fatal Error...", isingState.errorMessage);
      }
    });
  }
  @override
  void dispose() { /* ...前回答と同じ... */ _nController.dispose(); _jController.dispose(); super.dispose(); }
  void _showErrorSnackBar(String message) { /* ...前回のコードと同じ... */ }
  void _showFatalErrorDialog(BuildContext ctx, String title, String message) { /* ...前回のコードと同じ... */ }


  @override
  Widget build(BuildContext context) {
    final isingState = ref.watch(isingModelProvider);
    final String currentErrorMessage = isingState.errorMessage;

    // 1. ネイティブライブラリのロード状態に基づいてUIを分岐
    if (!isingState.isNativeLibLoaded) {
      // isNativeLibLoaded が false の場合
      bool isFatalError = currentErrorMessage.contains("Failed to load") ||
                          currentErrorMessage.contains("Unsupported platform") ||
                          currentErrorMessage.contains("exited") ||
                          currentErrorMessage.contains("spawn Isolate");

      if (isFatalError) {
        // 明確なロード失敗エラーの場合
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showFatalErrorDialog(
            context, // ★ build context を渡す
            "Fatal Error: Native Library/Engine Failed",
            "The simulation engine could not be started. This application requires it to function correctly.\n\n"
            "Details: $currentErrorMessage\n\n"
            "Please ensure the C++ library is correctly compiled and placed, then restart the application.",
          );
        });
        return Scaffold( // ★ 必ずWidgetを返す
          appBar: AppBar(title: const Text('Error Loading Simulation')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Error: Could not start the simulation engine.\n$currentErrorMessage",
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 16),
              ),
            ),
          ),
        );
      } else {
        // まだロード中、または他の初期化中メッセージの場合
        return Scaffold( // ★ 必ずWidgetを返す
          appBar: AppBar(title: const Text('Ising Model')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(currentErrorMessage.isNotEmpty ? currentErrorMessage : "Loading simulation engine..."),
              ],
            ),
          ),
        );
      }
    } else {
      // isNativeLibLoaded が true の場合 (FFIライブラリロード成功後)
      // その他のエラーがあればスナックバーで表示
      if (currentErrorMessage.isNotEmpty && !_fatalErrorDialogShownOnce) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && (ModalRoute.of(context)?.isCurrent ?? true)) {
            _showErrorSnackBar(currentErrorMessage);
            ref.read(isingModelProvider.notifier).clearError();
          }
        });
      }

      // 通常のUIを構築して返す
      return Scaffold( // ★ 必ずWidgetを返す
        appBar: AppBar(title: const Text('Ising Model')),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              _buildParameterInputs(context, isingState), // isingState を渡す
              const SizedBox(height: 10),
              _buildControlButtons(context, isingState), // isingState を渡す
              const SizedBox(height: 10),
              _buildInfoDisplay(context, isingState),   // isingState を渡す
              const SizedBox(height: 10),
              Expanded(child: _buildIsingModelGrid(context, isingState)), // isingState を渡す
            ],
          ),
        ),
      );
    }
    // このポイントには論理的に到達しないはずだが、念のためエラーを投げるか、
    // デフォルトのWidgetを返すことで、解析ツールを納得させることができる場合がある。
    // ただし、上記の if/else if/else 構造で網羅されているはず。
    // throw StateError("Build method reached an unexpected state.");
  }

  // _buildParameterInputs, _buildControlButtons, _buildInfoDisplay, _buildIsingModelGrid の各メソッドは
  // 前回の回答から変更ありません。引数に isingState を取るように修正済みです。
  Widget _buildParameterInputs(BuildContext context, IsingModelState isingState) { /* ...前回のコードと同じ... */ 
    final bool enableNonTempInputs = isingState.isNativeLibLoaded && !isingState.isInitialized;
    final bool enableTempSlider = isingState.isNativeLibLoaded && isingState.isInitialized;
    return Card( elevation: 2, child: Padding( padding: const EdgeInsets.all(12.0),
        child: Column( children: [ Row( children: [
                Expanded(child: TextField(controller: _nController, decoration: const InputDecoration(labelText: 'Size (N)', border: OutlineInputBorder()), keyboardType: TextInputType.number, enabled: enableNonTempInputs,)),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _jController, decoration: const InputDecoration(labelText: 'J', border: OutlineInputBorder()), keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), enabled: enableNonTempInputs,)),
              ],), const SizedBox(height: 12),
            Row( children: [
                Text("Temp (T): ${isingState.currentTemperature.toStringAsFixed(3)}", style: const TextStyle(fontSize: 16)),
                Expanded( child: Slider( value: isingState.currentTemperature, min: 0.01, max: 5.0, divisions: 499, 
                    label: isingState.currentTemperature.toStringAsFixed(3),
                    onChanged: enableTempSlider ? (double value) { ref.read(isingModelProvider.notifier).state = isingState.copyWith(currentTemperature: value); } : null,
                    onChangeEnd: enableTempSlider ? (double value) { ref.read(isingModelProvider.notifier).setTemperature(value); } : null,
                  ), ), ], ), ], ), ), );
  }
  Widget _buildControlButtons(BuildContext context, IsingModelState isingState) { /* ...前回のコードと同じ... */ 
    final bool canInteract = isingState.isNativeLibLoaded;
    return Row( mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        ElevatedButton.icon( icon: const Icon(Icons.build_circle_outlined), label: const Text('Initialize'),
          onPressed: canInteract ? () async {
            final n = int.tryParse(_nController.text); final j = double.tryParse(_jController.text); final temp = isingState.currentTemperature; // スライダーの現在の値
            if (n == null || j == null ) { _showErrorSnackBar("Please enter valid numbers for N and J."); return; }
            if (n <= 0) { _showErrorSnackBar("N must be positive."); return; }
            // temp のバリデーションはスライダーのmin/maxで担保されていると仮定
            await ref.read(isingModelProvider.notifier).initializeModel(n, j, temp);
          } : null, ),
        ElevatedButton.icon( icon: const Icon(Icons.skip_next_outlined), label: const Text('Step (1 MCS)'),
          onPressed: (canInteract && isingState.isInitialized && !isingState.isRunning) 
              ? () => ref.read(isingModelProvider.notifier).runModelSweeps(sweepCount: 1) : null, ),
        ElevatedButton.icon( icon: Icon(isingState.isRunning ? Icons.pause_circle_outline : Icons.play_circle_outline),
          label: Text(isingState.isRunning ? 'Stop Batch' : 'Start Batch'),
          style: ElevatedButton.styleFrom( backgroundColor: isingState.isRunning ? Theme.of(context).colorScheme.tertiaryContainer : Theme.of(context).colorScheme.primaryContainer,
            foregroundColor: isingState.isRunning ? Theme.of(context).colorScheme.onTertiaryContainer : Theme.of(context).colorScheme.onPrimaryContainer, ),
          onPressed: (canInteract && isingState.isInitialized) ? () {
                  if (isingState.isRunning) { ref.read(isingModelProvider.notifier).stopSimulation(); } 
                  else { ref.read(isingModelProvider.notifier).startSimulation(); } } : null, ), ], );
  }
  Widget _buildInfoDisplay(BuildContext context, IsingModelState isingState) { /* ...前回のコードと同じ... */ 
    return Card( elevation: 2, child: Padding( padding: const EdgeInsets.all(12.0),
        child: Row( mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            Text('MCS: ${isingState.time}'), Text('E: ${isingState.energy.toStringAsFixed(3)}'),
            Text('M: ${isingState.magneticMoment.toStringAsFixed(3)}'), ], ), ), );
  }
  Widget _buildIsingModelGrid(BuildContext context, IsingModelState isingState) { /* ...前回のコードと同じ... */ 
    if (!isingState.isNativeLibLoaded && !isingState.errorMessage.contains("Failed to load")) { /* buildメソッド先頭で処理されるので、ここは実質通らないはず*/ return const Center(child: CircularProgressIndicator());}
    if (!isingState.isInitialized) { return const Center(child: Text('Initialize the model to see the visualization.')); }
    if (isingState.modelSize == 0 || isingState.modelStateGrid.isEmpty) { return const Center(child: Text('Model state is empty or size is zero.')); }
    return LayoutBuilder( builder: (context, constraints) {
        return AspectRatio( aspectRatio: 1.0,
          child: CustomPaint( painter: IsingGridPainter( modelState: isingState.modelStateGrid, modelSize: isingState.modelSize,
              spinUpColor: Colors.teal.shade800, spinDownColor: Colors.grey.shade300, ),
            size: Size(constraints.maxWidth, constraints.maxWidth), ), ); } );
  }
}

class IsingGridPainter extends CustomPainter { /* ...前回のコードと同じ... */ 
  final List<int> modelState; final int modelSize; final Paint spinUpPaint; final Paint spinDownPaint;
  IsingGridPainter({ required this.modelState, required this.modelSize, Color spinUpColor = Colors.black, Color spinDownColor = Colors.white,
  }) : spinUpPaint = Paint()..color = spinUpColor, spinDownPaint = Paint()..color = spinDownColor;
  @override void paint(Canvas canvas, Size size) {
    if (modelSize == 0 || modelState.length != modelSize * modelSize) return;
    final double cellWidth = size.width / modelSize; final double cellHeight = size.height / modelSize;
    for (int i = 0; i < modelSize; i++) { for (int j = 0; j < modelSize; j++) {
        final int index = i * modelSize + j; if (index >= modelState.length) continue;
        final paintToUse = modelState[index] == 1 ? spinUpPaint : spinDownPaint;
        canvas.drawRect( Rect.fromLTWH(j * cellWidth, i * cellHeight, cellWidth, cellHeight), paintToUse); } } }
  @override bool shouldRepaint(covariant IsingGridPainter oldDelegate) {
    if (oldDelegate.modelSize != modelSize) return true; return oldDelegate.modelState != modelState; }
}