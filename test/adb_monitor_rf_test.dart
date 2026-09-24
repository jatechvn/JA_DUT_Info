// test/adb_monitor_rf_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:ja_dut_info/modules/logic.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AdbMonitor RF Integration Tests', () {
    test('AdbMonitor initial state includes PowerG and SRF keys', () {
      final monitor = AdbMonitor();
      
      expect(monitor.info.containsKey('PowerG'), isTrue);
      expect(monitor.info.containsKey('SRF'), isTrue);
      expect(monitor.info['PowerG'], equals('N/A'));
      expect(monitor.info['SRF'], equals('N/A'));
      expect(monitor.powerGResult, isNull);
      expect(monitor.srfResult, isNull);
      expect(monitor.goldenPanelSerial, isNull);
      expect(monitor.isRfTesting, isFalse);

      monitor.stop();
    });

    test('retestRf does not crash when no DUT is connected', () async {
      final monitor = AdbMonitor();
      expect(monitor.currentDut, isEmpty);

      // Should safely return without exception
      await monitor.retestRf();
      expect(monitor.isRfTesting, isFalse);

      monitor.stop();
    });
  });
}
