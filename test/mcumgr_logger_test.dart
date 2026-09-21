import 'package:fixnum/fixnum.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcumgr_flutter/proto/flutter_mcu.pb.dart';
import 'package:mcumgr_flutter/src/mcumgr_update_logger.dart';

const _logChannel = EventChannel('mcumgr_flutter/log_event_channel');

/// The native log stream tags each message with the device it came from. iOS
/// writes the peripheral UUID in upper case, while Dart callers usually hold it
/// in lower case, as CoreBluetooth-based plugins report it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<int> logEvent(String uuid, String message) => ProtoLogMessageStreamArg(
    uuid: uuid,
    protoLogMessage: ProtoLogMessage(
      message: message,
      logCategory: ProtoLogMessage_LogCategory.TRANSPORT,
      logLevel: ProtoLogMessage_LogLevel.INFO,
      logDateTime: Int64(0),
    ),
  ).writeToBuffer();

  void emitOnListen(List<List<int>> events) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
      _logChannel,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          for (final event in events) {
            sink.success(event);
          }
        },
      ),
    );
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(_logChannel, null);
  });

  test('a message tagged with the device UUID in another case still reaches its logger', () async {
    emitOnListen([logEvent('9F1C2D3E-4A5B-6C7D-8E9F-0A1B2C3D4E5F', 'from the device')]);

    final logger = McuMgrLogger.deviceIdentifier('9f1c2d3e-4a5b-6c7d-8e9f-0a1b2c3d4e5f');

    expect((await logger.logMessageStream.first).message, 'from the device');
  });

  test("another device's messages stay out", () async {
    emitOnListen([
      logEvent('1A2B3C4D-5E6F-7A8B-9C0D-E1F2A3B4C5D6', 'from the other device'),
      logEvent('9F1C2D3E-4A5B-6C7D-8E9F-0A1B2C3D4E5F', 'from this device'),
    ]);

    final logger = McuMgrLogger.deviceIdentifier('9f1c2d3e-4a5b-6c7d-8e9f-0a1b2c3d4e5f');

    expect((await logger.logMessageStream.first).message, 'from this device');
  });
}
