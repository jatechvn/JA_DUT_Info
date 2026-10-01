import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ja_dut_info/modules/logic.dart';
import 'package:ja_dut_info/modules/services/command_scope.dart';
import 'package:ja_dut_info/modules/services/powerg_service.dart';
import 'package:ja_dut_info/modules/services/srf_service.dart';
import 'package:ja_dut_info/modules/services/transmitter_process.dart';
import 'package:ja_dut_info/modules/utils.dart';

Future<void> until(bool Function() condition) async {
  final watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > const Duration(seconds: 5)) {
      fail('State transition timed out');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'unplug while reading clears UI; same-serial reconnect rejects old results',
    () async {
      var connected = true;
      var reads = 0;
      final oldRead = Completer<String>();
      final oldRf = Completer<PowerGResult>();
      var rfCalls = 0;
      final monitor = AdbMonitor(
        pollInterval: const Duration(milliseconds: 15),
        command: (args) async {
          if (args.length == 2) {
            return 'List of devices attached\n${connected ? 'same-serial\tdevice\n' : ''}';
          }
          if (args.last == 'persist.auto.run') return '';
          if (args.last == 'sys.boot_completed') return '1';
          if (args.last == 'pcasn') {
            reads++;
            return reads == 1 ? oldRead.future : 'QB95-NEW';
          }
          return '';
        },
        powerGVerifier: (_) async {
          rfCalls++;
          return rfCalls == 1
              ? oldRf.future
              : const PowerGResult(status: PowerGStatus.mcuOk, message: 'new');
        },
        srfVerifier: (_, _) async =>
            const SrfResult(status: SrfStatus.mcuOk, message: 'new'),
      );
      addTearDown(() {
        monitor.dispose();
        if (!oldRead.isCompleted) oldRead.complete('OLD');
        if (!oldRf.isCompleted) {
          oldRf.complete(
            const PowerGResult(status: PowerGStatus.pass, message: 'old'),
          );
        }
      });
      await until(() => reads == 1);
      expect(monitor.overlayText, 'READING');
      connected = false;
      await until(() => !monitor.deviceConnected);
      expect(monitor.currentDut, isEmpty);
      expect(monitor.overlayText, 'NO DATA');
      expect(monitor.info['PCASN'], 'N/A');
      expect(monitor.isRfTesting, isFalse);
      connected = true;
      await until(() => monitor.info['PCASN'] == 'QB95-NEW');
      oldRead.complete('QB95-OLD');
      oldRf.complete(
        const PowerGResult(status: PowerGStatus.pass, message: 'old'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(monitor.info['PCASN'], 'QB95-NEW');
      expect(monitor.powerGResult?.status, PowerGStatus.mcuOk);
    },
  );

  test(
    'offline and unauthorized devices cannot block disconnect detection',
    () async {
      var state = 'device';
      final monitor = AdbMonitor(
        pollInterval: const Duration(milliseconds: 15),
        command: (args) async {
          if (args.length == 2) {
            return 'List of devices attached\ndevice-in-name\t$state\n';
          }
          return '';
        },
      );
      addTearDown(monitor.dispose);
      await until(() => monitor.deviceConnected);
      state = 'unauthorized';
      await until(() => !monitor.deviceConnected);
      expect(monitor.overlayText, 'NO DATA');
      state = 'offline';
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(monitor.deviceConnected, isFalse);
    },
  );

  test(
    'dispose ignores a device scan which completes after shutdown',
    () async {
      final scan = Completer<String>();
      final monitor = AdbMonitor(command: (_) => scan.future);
      var notifications = 0;
      monitor.addListener(() => notifications++);
      monitor.dispose();
      scan.complete('List of devices attached\nlate-device\tdevice\n');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(monitor.deviceConnected, isFalse);
      expect(notifications, 0);
    },
  );

  test(
    'session cancellation terminates only its owned process',
    () async {
      final scope = CommandScope();
      final started = Completer<Process>();
      final result = scope.run(
        () => runTransmitterProcess('powershell.exe', [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          'Start-Sleep -Seconds 30',
        ], onStarted: started.complete),
      );
      final assertion = expectLater(result, throwsA(isA<CommandCancelled>()));
      final process = await started.future;
      scope.cancel();
      await assertion;
      expect(await process.exitCode, isNot(0));
    },
    skip: !Platform.isWindows,
  );

  test(
    'runCmd bounds a stalled command and retains cancellation signal',
    () async {
      final watch = Stopwatch()..start();
      final output = await runCmd([
        'powershell.exe',
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        'Start-Sleep -Seconds 30',
      ], timeout: const Duration(milliseconds: 150));
      expect(output, isEmpty);
      expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
      final scope = CommandScope()..cancel();
      await expectLater(
        scope.run(() => runCmd(['adb', 'devices'])),
        throwsA(isA<CommandCancelled>()),
      );
    },
    skip: !Platform.isWindows,
  );
}
