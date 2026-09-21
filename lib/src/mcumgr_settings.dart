import 'dart:async';

import 'package:flutter/services.dart';
import 'package:mcumgr_flutter/mcumgr_flutter.dart';

import 'mcumgr_update_logger.dart';

enum PrecisionMode {
  auto('auto'),
  forceFloat32('forceFloat32'),
  forceDouble64('forceDouble64');

  const PrecisionMode(this.value);

  final String value;
}

const _methodChannel = MethodChannel('mcumgr_flutter/method_channel');

/// Reads and writes device settings over SMP.
///
/// The native side keeps one settings manager per device, so several devices
/// can be connected at once: every call names the device it is meant for, and
/// a call for a device that was never initialised fails instead of reaching
/// another one.
final class McumgrSettings {
  /// Log subscriptions per device address, so re-initialising or disposing one
  /// device never touches another device's log stream.
  final _logSubscriptions = <String, StreamSubscription<McuLogMessage>>{};

  /// Opens the settings manager for [deviceAddress]. Calling it again for the
  /// same device replaces that device's manager; other devices keep theirs.
  Future<void> init({
    required String deviceAddress,
    bool padTo4Bytes = false,
    bool encodeValueToCBOR = false,
    bool useByteStringEncoding = true,
    bool logEnabled = false,
    PrecisionMode precisionMode = PrecisionMode.auto,
  }) async {
    // Drop the device's previous log subscription before attaching a new one,
    // otherwise every re-init stacks one more listener and each message is
    // printed once per init.
    await _logSubscriptions.remove(deviceAddress)?.cancel();
    if (logEnabled) {
      final logger = McuMgrLogger.deviceIdentifier(deviceAddress);
      _logSubscriptions[deviceAddress] = logger.logMessageStream.listen((logMessage) {
        print("MCUMGR Log [$deviceAddress]: ${logMessage.message}");
      });
    }

    return _methodChannel.invokeMethod('initSettings', {
      'deviceAddress': deviceAddress,
      'padTo4Bytes': padTo4Bytes,
      'encodeValueToCBOR': encodeValueToCBOR,
      'useByteStringEncoding': useByteStringEncoding,
      'precisionMode': precisionMode.value,
    });
  }

  Future<String> readSettings({required String deviceAddress}) async {
    final result = await _methodChannel.invokeMethod<String>('fetchSettings', {
      'deviceAddress': deviceAddress,
    });

    if (result == null) {
      throw Exception("No response from native plugin");
    }

    return result;
  }

  Future<T> readSetting<T>(String key, {required String deviceAddress}) async {
    final result = await _methodChannel.invokeMethod<T>('readSetting', {
      'deviceAddress': deviceAddress,
      'key': key,
    });

    if (result == null) {
      throw Exception("No response from native plugin");
    }

    return result;
  }

  /// Writes [value] to setting [key].
  ///
  /// When [password] is non-null, it is added to the SMP write payload as the
  /// `pwd` CBOR field. Firmware implementations that gate writes on a setting
  /// password use this field to authorise the operation; firmwares that don't
  /// care simply ignore it. When [password] is null the payload omits `pwd`
  /// entirely.
  ///
  /// Password injection is only honoured when the manager was initialised
  /// with `useByteStringEncoding: false` (direct CBOR map payload path). With
  /// `useByteStringEncoding: true` the [password] parameter is silently
  /// ignored because the underlying `SettingsManager.write` API on each
  /// platform hardcodes the payload to `{name, val}` with no extension hook.
  Future<Uint8List> writeSetting(
    String key,
    dynamic value, {
    required String deviceAddress,
    String? password,
  }) async {
    final resultBytes = await _methodChannel.invokeMethod<Uint8List>('writeSetting', {
      'deviceAddress': deviceAddress,
      'key': key,
      'value': value,
      if (password != null) 'password': password,
    });
    if (resultBytes == null) {
      throw Exception("No response from native plugin");
    }
    return resultBytes;
  }

  /// Releases the settings manager of [deviceAddress] only.
  Future<void> dispose({required String deviceAddress}) async {
    await _logSubscriptions.remove(deviceAddress)?.cancel();
    return _methodChannel.invokeMethod('disposeSettings', {
      'deviceAddress': deviceAddress,
    });
  }
}
