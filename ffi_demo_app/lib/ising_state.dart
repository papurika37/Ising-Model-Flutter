import 'package:flutter/foundation.dart';

@immutable
class IsingModelState {
  final List<int> modelStateGrid;
  final int modelSize;
  final double energy;
  final double magneticMoment;
  final int time;
  final String errorMessage;
  final bool isNativeLibLoaded;
  final bool isInitialized;
  final bool isRunning;
  final double currentTemperature;

  const IsingModelState({
    this.modelStateGrid = const [],
    this.modelSize = 0,
    this.energy = 0.0,
    this.magneticMoment = 0.0,
    this.time = 0,
    this.errorMessage = '',
    this.isNativeLibLoaded = false,
    this.isInitialized = false,
    this.isRunning = false,
    this.currentTemperature = 2.269, 
  });

  IsingModelState copyWith({
    List<int>? modelStateGrid,
    int? modelSize,
    double? energy,
    double? magneticMoment,
    int? time,
    String? errorMessage,
    bool? isNativeLibLoaded,
    bool? isInitialized,
    bool? isRunning,
    double? currentTemperature,
    bool clearErrorMessage = false,
  }) {
    return IsingModelState(
      modelStateGrid: modelStateGrid ?? this.modelStateGrid,
      modelSize: modelSize ?? this.modelSize,
      energy: energy ?? this.energy,
      magneticMoment: magneticMoment ?? this.magneticMoment,
      time: time ?? this.time,
      errorMessage: clearErrorMessage ? '' : (errorMessage ?? this.errorMessage),
      isNativeLibLoaded: isNativeLibLoaded ?? this.isNativeLibLoaded,
      isInitialized: isInitialized ?? this.isInitialized,
      isRunning: isRunning ?? this.isRunning,
      currentTemperature: currentTemperature ?? this.currentTemperature,
    );
  }
}