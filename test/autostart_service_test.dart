import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_dut_info/modules/services/autostart_service.dart';

void main() {
  for (final enabled in [true, false]) {
    test(
      'autostart $enabled propagates registry success and failure',
      () async {
        for (final code in [0, 1]) {
          final ok = await AutostartService.setAutostartEnabled(
            enabled,
            runProcess: (exe, args) async {
              expect(exe, 'reg');
              expect(args.first, enabled ? 'add' : 'delete');
              if (enabled) {
                expect(
                  args[args.indexOf('/d') + 1],
                  '"${Platform.resolvedExecutable}"',
                );
              }
              return ProcessResult(0, code, '', 'Access denied');
            },
          );
          expect(ok, code == 0);
        }
      },
      skip: !Platform.isWindows,
    );
  }
  test('autostart handles process launch failure', () async {
    expect(
      await AutostartService.setAutostartEnabled(
        true,
        runProcess: (_, _) async => throw const ProcessException('reg', []),
      ),
      isFalse,
    );
  }, skip: !Platform.isWindows);
  group('AutostartService Tests', () {
    test('isAutostartEnabled returns a boolean without throwing', () async {
      final enabled = await AutostartService.isAutostartEnabled();
      expect(enabled, isA<bool>());
    });

    test('Non-windows platforms return false gracefully', () async {
      if (!Platform.isWindows) {
        expect(await AutostartService.isAutostartEnabled(), isFalse);
        expect(await AutostartService.setAutostartEnabled(true), isFalse);
      }
    });
  });
}
