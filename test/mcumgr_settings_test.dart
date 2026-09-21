import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcumgr_flutter/mcumgr_flutter.dart';

const _settingsChannel = MethodChannel('mcumgr_flutter/method_channel');
const _logChannel = MethodChannel('mcumgr_flutter/log_event_channel');

const _firstDevice = 'AA:BB:CC:00:00:01';
const _secondDevice = 'AA:BB:CC:00:00:02';

/// The native side keeps one settings manager per device and picks it by the
/// `deviceAddress` argument, so every settings call must carry it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(_settingsChannel, (call) async {
        calls.add(call);
        return switch (call.method) {
          'readSetting' => 1,
          'fetchSettings' => '{}',
          'writeSetting' => Uint8List(0),
          _ => null,
        };
      })
      ..setMockMethodCallHandler(_logChannel, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(_settingsChannel, null)
      ..setMockMethodCallHandler(_logChannel, null);
  });

  Object? addressOf(MethodCall call) => (call.arguments as Map)['deviceAddress'];

  test('every settings call names the device it is for', () async {
    final settings = McumgrSettings();

    await settings.init(deviceAddress: _firstDevice, logEnabled: true);
    await settings.readSettings(deviceAddress: _firstDevice);
    await settings.readSetting<int>('config/interval', deviceAddress: _firstDevice);
    await settings.writeSetting('config/interval', 5, deviceAddress: _firstDevice, password: '1234');
    await settings.dispose(deviceAddress: _firstDevice);

    expect(calls.map((call) => call.method), [
      'initSettings',
      'fetchSettings',
      'readSetting',
      'writeSetting',
      'disposeSettings',
    ]);
    expect(calls.map(addressOf), everyElement(_firstDevice));
  });

  test('reads and writes of two devices keep their own addresses', () async {
    final settings = McumgrSettings();
    await settings.init(deviceAddress: _firstDevice);
    await settings.init(deviceAddress: _secondDevice);
    calls.clear();

    await settings.readSetting<int>('config/timeout/value', deviceAddress: _firstDevice);
    await settings.writeSetting('feature/enabled', true, deviceAddress: _secondDevice);

    expect(calls.map(addressOf), [_firstDevice, _secondDevice]);
    expect((calls.first.arguments as Map)['key'], 'config/timeout/value');
    expect((calls.last.arguments as Map)['key'], 'feature/enabled');
  });

  test('disposing one device releases only that device', () async {
    final settings = McumgrSettings();
    await settings.init(deviceAddress: _firstDevice, logEnabled: true);
    await settings.init(deviceAddress: _secondDevice, logEnabled: true);
    calls.clear();

    await settings.dispose(deviceAddress: _firstDevice);

    expect(calls.single.method, 'disposeSettings');
    expect(addressOf(calls.single), _firstDevice);
  });
}
