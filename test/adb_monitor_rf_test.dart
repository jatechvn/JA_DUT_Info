// test/adb_monitor_rf_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:ja_dut_info/modules/logic.dart';
import 'package:ja_dut_info/modules/services/powerg_service.dart';
import 'package:ja_dut_info/modules/services/srf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AdbMonitor RF & Quick Actions Integration Tests', () {
    test('AdbMonitor initial state includes PowerG and SRF keys', () {
      final monitor = AdbMonitor(autoStart: false);

      expect(monitor.info.containsKey('PowerG'), isTrue);
      expect(monitor.info.containsKey('SRF'), isTrue);
      expect(monitor.info['PowerG'], equals('N/A'));
      expect(monitor.info['SRF'], equals('N/A'));
      expect(monitor.powerGResult, isNull);
      expect(monitor.srfResult, isNull);
      expect(monitor.goldenPanelSerial, isNull);
      expect(monitor.isRfTesting, isFalse);
      expect(monitor.isPowerGTesting, isFalse);
      expect(monitor.isSrfTesting, isFalse);

      monitor.stop();
    });

    test(
      'retestRf, retestPowerGOnly, retestSrfOnly, reloadCurrentDut safely no-op when disconnected',
      () async {
        final monitor = AdbMonitor(autoStart: false);
        expect(monitor.currentDut, isEmpty);

        await monitor.retestRf();
        await monitor.retestPowerGOnly();
        await monitor.retestSrfOnly();
        await monitor.reloadCurrentDut();
        expect(monitor.isRfTesting, isFalse);
        expect(
          monitor.formatFullDutReport(),
          contains('Chưa có thiết bị DUT kết nối'),
        );

        monitor.stop();
      },
    );

    test(
      'per-channel retestPowerGOnly and retestSrfOnly update independently and record history',
      () async {
        int pgCalls = 0;
        int srfCalls = 0;

        final monitor = AdbMonitor(
          pollInterval: const Duration(milliseconds: 20),
          command: (args) async {
            if (args.length == 2) {
              return 'List of devices attached\ndut-serial-1\tdevice\n';
            }
            switch (args.last) {
              case 'persist.auto.run':
                return '';
              case 'sys.boot_completed':
                return '1';
              case 'pcasn':
                return 'QB9501A002632V06416';
              case 'syssn':
                return 'QP5001A002633V00633';
              case 'syspn':
                return 'IQP5001';
              case 'lcmpn':
                return 'LCM001';
              case 'imeino':
                return '490154203237518';
              case 'gsm.version.baseband':
                return 'MPSS.HI.4.3.1';
              default:
                return '';
            }
          },
          powerGVerifier: (_) async {
            pgCalls++;
            return PowerGResult(
              status: pgCalls == 1 ? PowerGStatus.mcuOk : PowerGStatus.pass,
              frequency: '915 MHz',
              fw: '53.10',
              message: 'ok',
            );
          },
          srfVerifier: (_, _) async {
            srfCalls++;
            return const SrfResult(
              status: SrfStatus.pass,
              matrix: '0010',
              message: 'ok',
            );
          },
        );
        addTearDown(monitor.dispose);

        // Wait until initial read & RF check finish
        final watch = Stopwatch()..start();
        while (monitor.showOverlay || monitor.isRfTesting || pgCalls == 0) {
          if (watch.elapsed > const Duration(seconds: 4)) {
            fail('Timed out waiting for initial DUT load');
          }
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }

        expect(pgCalls, 1);
        expect(srfCalls, 1);
        expect(monitor.powerGResult?.status, PowerGStatus.mcuOk);
        expect(monitor.srfResult?.status, SrfStatus.pass);
        expect(monitor.history.count, 1);

        // Trigger PowerG-only retest -> SRF should NOT be called again
        await monitor.retestPowerGOnly();
        expect(pgCalls, 2);
        expect(srfCalls, 1);
        expect(monitor.powerGResult?.status, PowerGStatus.pass);

        // Trigger SRF-only retest -> PowerG should NOT be called again
        await monitor.retestSrfOnly();
        expect(pgCalls, 2);
        expect(srfCalls, 2);

        // Full report contains key parameters
        final report = monitor.formatFullDutReport();
        expect(report, contains('QB9501A002632V06416'));
        expect(report, contains('QP5001A002633V00633'));
      },
    );
  });
}
