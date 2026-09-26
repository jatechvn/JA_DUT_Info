// test/adb_monitor_live_test.dart

// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_dut_info/modules/logic.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Live DUT and RF Pipeline Test on Connected Hardware',
    () async {
      final monitor = AdbMonitor();

      // Wait up to 25s for monitor loop to load DUT and run RF check
      for (int i = 0; i < 50; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (monitor.deviceConnected &&
            !monitor.isRfTesting &&
            monitor.powerGResult != null &&
            monitor.info['PCASN'] != 'Đang đọc...') {
          break;
        }
      }

      print('\n================ LIVE DUT TEST RESULTS ================');
      print('Current DUT:         ${monitor.currentDut}');
      print('Golden Panel:        ${monitor.goldenPanelSerial}');
      print('Device Connected:    ${monitor.deviceConnected}');
      print('PCASN:               ${monitor.info['PCASN']}');
      print('SYSSN:               ${monitor.info['SYSSN']}');
      print('Station Result:      ${monitor.stationResult}');
      print('PowerG Summary:      ${monitor.info['PowerG']}');
      print('SRF Summary:         ${monitor.info['SRF']}');
      print('PowerG Status:       ${monitor.powerGResult?.status}');
      print('SRF Status:          ${monitor.srfResult?.status}');
      print('=======================================================\n');

      expect(monitor.deviceConnected, isTrue);
      expect(monitor.info['PowerG'], isNot(equals('N/A')));
      expect(monitor.info['PowerG'], isNot(equals('Đang kiểm tra...')));
      expect(monitor.powerGResult, isNotNull);
      expect(monitor.goldenPanelSerial, equals('2b69e02'));

      monitor.stop();
    },
    timeout: const Timeout(Duration(seconds: 25)),
  );
}
