// test/boot_retry_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:ja_dut_info/modules/logic.dart';
import 'package:ja_dut_info/modules/services/powerg_service.dart';
import 'package:ja_dut_info/modules/services/srf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Boot Waiting and Multi-Retry Unit Tests', () {
    test(
      'AdbMonitor initial state has placeholder labels while waiting for boot',
      () {
        final monitor = AdbMonitor();

        expect(monitor.info['CPU'], equals('N/A'));
        expect(monitor.info['PowerG'], equals('N/A'));
        expect(monitor.info['SRF'], equals('N/A'));
        expect(monitor.isRfTesting, isFalse);

        monitor.stop();
      },
    );

    test(
      'PowerGService handles uninstalled card after retries gracefully',
      () async {
        final pg = PowerGService();
        // Dummy serial that does not exist
        final result = await pg.verifyDut('non_existent_serial_12345');
        expect(result.isInstalled, isFalse);
        expect(result.status, equals(PowerGStatus.notInstalled));
        expect(result.displaySummary, equals('N/A - Không có card'));
      },
    );

    test(
      'SrfService handles uninstalled card after retries gracefully',
      () async {
        final srf = SrfService();
        // Dummy serial that does not exist
        final result = await srf.verifyDut('non_existent_serial_12345');
        expect(result.isInstalled, isFalse);
        expect(result.status, equals(SrfStatus.notInstalled));
        expect(result.displaySummary, equals('N/A - Không có card'));
      },
    );
  });
}
