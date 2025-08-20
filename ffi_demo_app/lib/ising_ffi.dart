import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

final class IsingModelOpaque extends Opaque {}
typedef IsingModelPtr = Pointer<IsingModelOpaque>;

typedef CreateIsingModelNative = IsingModelPtr Function(Int32 nSize, Float jInteraction, Double temperature);
typedef CreateIsingModelDart = IsingModelPtr Function(int nSize, double jInteraction, double temperature);

typedef DeleteIsingModelNative = Void Function(IsingModelPtr modelPtr);
typedef DeleteIsingModelDart = void Function(IsingModelPtr modelPtr);

typedef RunSweepsIsingModelNative = Void Function(IsingModelPtr modelPtr, Int32 numSweeps);
typedef RunSweepsIsingModelDart = void Function(IsingModelPtr modelPtr, int numSweeps);

typedef SetIsingModelTemperatureNative = Void Function(IsingModelPtr modelPtr, Double newTemperature);
typedef SetIsingModelTemperatureDart = void Function(IsingModelPtr modelPtr, double newTemperature);

typedef GetIsingModelStateNative = Void Function(IsingModelPtr modelPtr, Pointer<Int32> outStateArray);
typedef GetIsingModelStateDart = void Function(IsingModelPtr modelPtr, Pointer<Int32> outStateArray);

typedef GetIsingModelSizeNative = Int32 Function(IsingModelPtr modelPtr);
typedef GetIsingModelSizeDart = int Function(IsingModelPtr modelPtr);

typedef GetIsingModelEnergyNative = Double Function(IsingModelPtr modelPtr);
typedef GetIsingModelEnergyDart = double Function(IsingModelPtr modelPtr);

typedef GetIsingModelMagneticMomentNative = Double Function(IsingModelPtr modelPtr);
typedef GetIsingModelMagneticMomentDart = double Function(IsingModelPtr modelPtr);

typedef GetIsingModelTimeNative = Uint64 Function(IsingModelPtr modelPtr);
typedef GetIsingModelTimeDart = int Function(IsingModelPtr modelPtr);

typedef GetLastErrorNative = Pointer<Utf8> Function(IsingModelPtr modelPtr);
typedef GetLastErrorDart = Pointer<Utf8> Function(IsingModelPtr modelPtr);

class IsingFFI {
  late CreateIsingModelDart createIsingModel;
  late DeleteIsingModelDart deleteIsingModel;
  late RunSweepsIsingModelDart runIsingModelSweeps;
  late SetIsingModelTemperatureDart setIsingModelTemperature;
  late GetIsingModelStateDart getIsingModelState;
  late GetIsingModelSizeDart getIsingModelSize;
  late GetIsingModelEnergyDart getIsingModelEnergy;
  late GetIsingModelMagneticMomentDart getIsingModelMagneticMoment;
  late GetIsingModelTimeDart getIsingModelTime;
  late GetLastErrorDart getLastError;

  static final IsingFFI _instance = IsingFFI._internal();
  factory IsingFFI() => _instance;

  IsingFFI._internal() {
    final libraryPath = _getLibraryPath();
    try {
      final dylib = DynamicLibrary.open(libraryPath);
      createIsingModel = dylib.lookup<NativeFunction<CreateIsingModelNative>>('create_ising_model').asFunction<CreateIsingModelDart>();
      deleteIsingModel = dylib.lookup<NativeFunction<DeleteIsingModelNative>>('delete_ising_model').asFunction<DeleteIsingModelDart>();
      runIsingModelSweeps = dylib.lookup<NativeFunction<RunSweepsIsingModelNative>>('run_sweeps_ising_model').asFunction<RunSweepsIsingModelDart>();
      setIsingModelTemperature = dylib.lookup<NativeFunction<SetIsingModelTemperatureNative>>('set_ising_model_temperature').asFunction<SetIsingModelTemperatureDart>();
      getIsingModelState = dylib.lookup<NativeFunction<GetIsingModelStateNative>>('get_ising_model_state').asFunction<GetIsingModelStateDart>();
      getIsingModelSize = dylib.lookup<NativeFunction<GetIsingModelSizeNative>>('get_ising_model_size').asFunction<GetIsingModelSizeDart>();
      getIsingModelEnergy = dylib.lookup<NativeFunction<GetIsingModelEnergyNative>>('get_ising_model_energy').asFunction<GetIsingModelEnergyDart>();
      getIsingModelMagneticMoment = dylib.lookup<NativeFunction<GetIsingModelMagneticMomentNative>>('get_ising_model_magnetic_moment').asFunction<GetIsingModelMagneticMomentDart>();
      getIsingModelTime = dylib.lookup<NativeFunction<GetIsingModelTimeNative>>('get_ising_model_time').asFunction<GetIsingModelTimeDart>();
      getLastError = dylib.lookup<NativeFunction<GetLastErrorNative>>('get_last_error').asFunction<GetLastErrorDart>();
    } catch (e) {
      print("Fatal Error (IsingFFI constructor): Could not load native library from '$libraryPath': $e");
      rethrow;
    }
  }

  String _getLibraryPath() {
    String libName; String platformDir;
    if (Platform.isLinux) { libName = 'libising_model.so'; platformDir = 'linux'; } 
    else if (Platform.isMacOS) { libName = 'libising_model.dylib'; platformDir = 'macos'; } 
    else if (Platform.isWindows) { libName = 'ising_model.dll'; platformDir = 'windows'; } 
    else { throw UnsupportedError('Unsupported platform for FFI: ${Platform.operatingSystem}'); }
    return path.join(Directory.current.path, 'native_libs', platformDir, libName);
  }
}