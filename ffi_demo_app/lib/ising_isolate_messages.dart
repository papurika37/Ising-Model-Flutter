import 'dart:ffi';

enum IsolateCommand { 
  init, runSweeps, setTemperature, disposeModel, disposeIsolate 
}

class ToIsolateMessage {
  final IsolateCommand command;
  final dynamic params;
  ToIsolateMessage(this.command, {this.params});
}

class InitParams {
  final int n; final double j; final double temp; final String libraryPath;
  InitParams({required this.n, required this.j, required this.temp, required this.libraryPath});
}

class RunSweepsParams {
  final int numSweeps;
  RunSweepsParams({required this.numSweeps});
}

class SetTemperatureParams {
  final double newTemperature;
  SetTemperatureParams({required this.newTemperature});
}

enum IsolateResponseStatus { ready, data, error, modelDisposed }

class FromIsolateMessage {
  final IsolateResponseStatus status;
  final dynamic data;
  FromIsolateMessage(this.status, {this.data});
}

class IsingDataPayload {
  final List<int> modelStateGrid; final int modelSize; final double energy;
  final double magneticMoment; final int time;
  IsingDataPayload({
    required this.modelStateGrid, required this.modelSize, required this.energy,
    required this.magneticMoment, required this.time,
  });
}