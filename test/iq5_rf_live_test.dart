// Run explicitly with --dart-define=IQ5_RF_SERIAL=<connected serial>.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ja_dut_info/modules/services/powerg_service.dart';
import 'package:ja_dut_info/modules/services/srf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const serial = String.fromEnvironment('IQ5_RF_SERIAL');
  const goldenEnv = String.fromEnvironment(
    'GOLDEN_SERIAL',
    defaultValue: 'bbb68d23',
  );
  test(
    'IQ5 live RF services return honest measured status',
    () async {
      final pg = await PowerGService().verifyDut(serial);
      final srf = await SrfService().verifyDut(serial, goldenSerial: goldenEnv);
      final result = {
        'serial': serial,
        'powerG': {
          'status': pg.status.name,
          'message': pg.message,
          'firmware': pg.fw,
          'frequency': pg.frequency,
          'details': pg.rawDetails,
        },
        'srf': {
          'status': srf.status.name,
          'goldenFirmware': srf.goldenFirmware,
          'message': srf.message,
          'details': srf.rawDetails,
        },
      };
      await File(
        'build/iq5-live-rf-result.json',
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(result));
      // MCU readiness must never claim measured PowerG RF on this IQ5 path.
      expect(pg.status, PowerGStatus.mcuOk, reason: pg.message);
      expect(srf.status, SrfStatus.pass, reason: srf.rawDetails);
      expect(srf.goldenFirmware, '11.2.0-G26');
      expect(srf.rawDetails, contains('RESULT:RX_OK:'));
    },
    skip: serial.isEmpty,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
