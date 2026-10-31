// test/auto_sn_service_test.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_dut_info/modules/services/auto_sn_service.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AutoSnConfig JSON & Hot-Reload Tests', () {
    late Directory tempDir;
    late String configPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('autosn_test_');
      configPath = p.join(tempDir.path, 'auto_sn_config.json');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'Creates default auto_sn_config.json when missing and evaluates QP SN',
      () {
        final service = AutoSnService(
          configFilePath: configPath,
          initNativeChannel: false,
        );

        expect(File(configPath).existsSync(), isTrue);
        expect(service.enabled, isTrue);
        expect(service.config.forms, isNotEmpty);

        final resWithSuffix = evaluateSnWithConfig(
          'QP4001ABCDEF1234567-USA',
          service.config,
        );
        expect(resWithSuffix.isValid, isTrue);
        expect(resWithSuffix.snCore, 'QP4001ABCDEF1234567');
        expect(resWithSuffix.suffix, '-USA');
        expect(resWithSuffix.generatedPn, 'IQP4001-USA');
        expect(resWithSuffix.hadCaret, isFalse);

        final resWithCaret = evaluateSnWithConfig(
          'QP4002ABCDEF1234567^',
          service.config,
        );
        expect(resWithCaret.isValid, isTrue);
        expect(resWithCaret.generatedPn, 'IQP4002');
        expect(resWithCaret.hadCaret, isTrue);
      },
    );

    test(
      'Hot-reloads newly added form & prefix_overrides and survives malformed JSON',
      () {
        final toasts = <String>[];
        final service = AutoSnService(
          configFilePath: configPath,
          initNativeChannel: false,
          onToast: toasts.add,
        );

        // Initially QH form is disabled in defaults
        expect(
          evaluateSnWithConfig(
            'QH5009ABCDEF1234567-EU',
            service.config,
          ).isValid,
          isFalse,
        );

        // Write updated JSON enabling QH form and adding a prefix override
        final customJson = {
          'enabled': true,
          'target_process': 'javaw.exe',
          'com_port_keyword': 'Qualcomm HS-USB Diagnostics 9091',
          'com_wait_timeout_sec': 30,
          'adb_wait_timeout_sec': 60,
          'append_caret': true,
          'skip_clipboard_contains': ['1\tPanelTamper'],
          'prefix_overrides': {'QP4088': 'IQP4008'},
          'forms': [
            {
              'name': 'Custom QH Form',
              'enabled': true,
              'sn_regex': r'^(QH[A-Z0-9]{17})(-[A-Z]{2,4})?(\^)?$',
              'pn_prefix': 'I',
              'sn_take_length': 6,
              'keep_suffix': true,
              'fixed_pn': '',
            },
            {
              'name': 'Standard QP Form',
              'enabled': true,
              'sn_regex': r'^(QP[A-Z0-9]{17})(-[A-Z]{2,4})?(\^)?$',
              'pn_prefix': 'I',
              'sn_take_length': 6,
              'keep_suffix': true,
              'fixed_pn': '',
            },
          ],
        };

        final file = File(configPath);
        file.writeAsStringSync(jsonEncode(customJson));
        file.setLastModifiedSync(
          DateTime.now().add(const Duration(seconds: 5)),
        );

        expect(service.loadOrCreateConfigSync(notifyOnError: true), isTrue);

        final qhMatch = evaluateSnWithConfig(
          'QH5009ABCDEF1234567-EU',
          service.config,
        );
        expect(qhMatch.isValid, isTrue);
        expect(qhMatch.generatedPn, 'IQH5009-EU');

        final overrideMatch = evaluateSnWithConfig(
          'QP4088ABCDEF1234567-CAN',
          service.config,
        );
        expect(overrideMatch.isValid, isTrue);
        expect(overrideMatch.generatedPn, 'IQP4008-CAN');

        // Now corrupt the JSON file and verify fallback safety
        file.writeAsStringSync('{ broken json ');
        file.setLastModifiedSync(
          DateTime.now().add(const Duration(seconds: 10)),
        );

        expect(service.loadOrCreateConfigSync(notifyOnError: true), isFalse);
        expect(
          toasts.any((t) => t.contains('Lỗi cú pháp auto_sn_config.json')),
          isTrue,
        );
        // Last valid config must still be intact
        expect(
          evaluateSnWithConfig(
            'QH5009ABCDEF1234567-EU',
            service.config,
          ).isValid,
          isTrue,
        );
      },
    );
  });

  group('Step 2 & Step 3 Classification Unit Tests', () {
    test(
      'parseAdbUsbDevices keeps device & unauthorized USB serials and ignores TCP/IP',
      () {
        const raw = '''
List of devices attached
* daemon started successfully
bbb68d23\tdevice
8f28f904\tunauthorized
192.168.1.100:5555\tdevice
dead0001\toffline
''';
        final list = parseAdbUsbDevices(raw);
        expect(list.length, 2);
        expect(list[0].serial, 'bbb68d23');
        expect(list[0].isAuthorized, isTrue);
        expect(list[1].serial, '8f28f904');
        expect(list[1].isUnauthorized, isTrue);
      },
    );

    test('Step 2 NEVER mistakes single Golden Panel for TargetDUT', () {
      final decision = classifyStep2UsbDevices(
        usbEntries: const [
          AdbUsbDeviceEntry(serial: 'bbb68d23', state: 'device'),
        ],
        autoRunBySerial: const {'bbb68d23': '1'},
        hwSerialBySerial: const {},
        comPortCount: 1,
      );

      expect(decision.type, Step2DecisionType.waitForDut);
      expect(decision.targetDut, isNull);
      expect(decision.goldenSerial, 'bbb68d23');
    });

    test(
      'Step 2 selects unauthorized DUT when Golden Panel is also connected',
      () {
        final decision = classifyStep2UsbDevices(
          usbEntries: const [
            AdbUsbDeviceEntry(serial: 'bbb68d23', state: 'device'),
            AdbUsbDeviceEntry(serial: 'dut_unauth_01', state: 'unauthorized'),
          ],
          autoRunBySerial: const {'bbb68d23': '1'},
          hwSerialBySerial: const {},
          comPortCount: 2,
        );

        expect(decision.type, Step2DecisionType.foundTargetDut);
        expect(decision.targetDut, 'dut_unauth_01');
        expect(decision.goldenSerial, 'bbb68d23');
        expect(decision.isTargetAuthorized, isFalse);
      },
    );

    test('Step 2 merges 2 ADB interfaces that share the same ro.serialno', () {
      final decision = classifyStep2UsbDevices(
        usbEntries: const [
          AdbUsbDeviceEntry(serial: 'dut_main', state: 'device'),
          AdbUsbDeviceEntry(serial: 'dut_diag', state: 'device'),
        ],
        autoRunBySerial: const {'dut_main': '0', 'dut_diag': '0'},
        hwSerialBySerial: const {
          'dut_main': 'SAME_HW_SN',
          'dut_diag': 'SAME_HW_SN',
        },
        comPortCount: 1,
      );

      expect(decision.type, Step2DecisionType.foundTargetDut);
      expect(decision.targetDut, 'dut_main');
    });
  });

  group('End-to-End AutoSnService Pipeline Tests', () {
    late Directory tempDir;
    late String configPath;
    const testChannel = MethodChannel('ja_route/autosn_test');
    final channelCalls = <MethodCall>[];

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('autosn_e2e_');
      configPath = p.join(tempDir.path, 'auto_sn_config.json');
      channelCalls.clear();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(testChannel, null);
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'Full flow: Golden + unauthorized DUT -> authorized -> sends Space',
      () async {
        late AutoSnService service;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(testChannel, (call) async {
              channelCalls.add(call);
              if (call.method == 'fillPn') {
                // Simulate native worker notifying completion
                Future.microtask(() async {
                  await TestDefaultBinaryMessengerBinding
                      .instance
                      .defaultBinaryMessenger
                      .handlePlatformMessage(
                        testChannel.name,
                        const StandardMethodCodec().encodeMethodCall(
                          const MethodCall('onPnFilled', true),
                        ),
                        (_) {},
                      );
                });
              } else if (call.method == 'sendSpace') {
                Future.microtask(() async {
                  await TestDefaultBinaryMessengerBinding
                      .instance
                      .defaultBinaryMessenger
                      .handlePlatformMessage(
                        testChannel.name,
                        const StandardMethodCodec().encodeMethodCall(
                          const MethodCall('onSpaceSent', true),
                        ),
                        (_) {},
                      );
                });
              }
              return true;
            });

        int adbDevicesCallCount = 0;
        String? readyDut;

        service = AutoSnService(
          channel: testChannel,
          configFilePath: configPath,
          comCounter: (_) async => 2,
          knownGoldenSerialGetter: () => 'golden_panel_1',
          onDutReady: (s) => readyDut = s,
          adbCommand: (args) async {
            final cmd = args.join(' ');
            if (cmd == 'adb devices') {
              adbDevicesCallCount++;
              if (adbDevicesCallCount == 1) {
                // First poll: only Golden is visible
                return 'List of devices attached\ngolden_panel_1\tdevice\n';
              } else if (adbDevicesCallCount == 2) {
                // Second poll: DUT appears as unauthorized
                return 'List of devices attached\ngolden_panel_1\tdevice\ndut_target_99\tunauthorized\n';
              } else {
                // Third+ poll: Operator tapped Allow USB Debugging -> device
                return 'List of devices attached\ngolden_panel_1\tdevice\ndut_target_99\tdevice\n';
              }
            }
            if (cmd.contains(
              'dut_target_99 shell getprop sys.boot_completed',
            )) {
              return '1\n1\nrunning\n';
            }
            return '';
          },
        );

        final result = await service.handleCapturedSnFromNative(
          rawText: 'QP4001ABCDEF1234567-USA',
          javawHwnd: 12345,
          comPollInterval: const Duration(milliseconds: 10),
          postComStabilizeDelay: const Duration(milliseconds: 10),
          adbPollInterval: const Duration(milliseconds: 10),
          preSpaceDelay: const Duration(milliseconds: 10),
        );

        expect(result.isValid, isTrue);
        expect(result.generatedPn, 'IQP4001-USA');
        expect(readyDut, 'dut_target_99');

        final fillCall = channelCalls.firstWhere((c) => c.method == 'fillPn');
        expect((fillCall.arguments as Map)['pn'], 'IQP4001-USA');
        expect((fillCall.arguments as Map)['hadCaret'], isFalse);

        final spaceCalls = channelCalls.where((c) => c.method == 'sendSpace');
        expect(spaceCalls.length, 1);
        expect((spaceCalls.first.arguments as Map)['hwnd'], 12345);
      },
    );
  });
}
