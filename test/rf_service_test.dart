// test/rf_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:ja_dut_info/modules/services/powerg_service.dart';
import 'package:ja_dut_info/modules/services/srf_service.dart';

void main() {
  group('PowerG Service Unit Tests', () {
    test('Protocol to Frequency Mapping', () {
      expect(PowerGService.mapProtocolToFrequency('9'), equals('868 MHz (EU)'));
      expect(PowerGService.mapProtocolToFrequency('8'), equals('915 MHz (NA)'));
      expect(
        PowerGService.mapProtocolToFrequency('6'),
        equals('915 MHz (LATAM)'),
      );
      expect(
        PowerGService.mapProtocolToFrequency('4'),
        equals('915 MHz (ANZ)'),
      );
      expect(PowerGService.mapProtocolToFrequency('7'), equals('433 MHz'));
      expect(PowerGService.mapProtocolToFrequency(''), equals('N/A'));
      expect(PowerGService.mapProtocolToFrequency('N/A'), equals('N/A'));
    });

    test('PowerGResult Summary Formatting', () {
      const notInstalled = PowerGResult(
        status: PowerGStatus.notInstalled,
        message: 'Không có card PowerG',
      );
      expect(notInstalled.isInstalled, isFalse);
      expect(notInstalled.isPass, isFalse);
      expect(notInstalled.displaySummary, equals('N/A - Không có card'));

      const passResult = PowerGResult(
        status: PowerGStatus.pass,
        fw: '83.03',
        protocol: '9',
        frequency: '868 MHz (EU)',
        sensorId: '1011230',
        message: 'RF PASS',
      );
      expect(passResult.isInstalled, isTrue);
      expect(passResult.isPass, isTrue);
      expect(passResult.displaySummary, contains('PASS'));
      expect(passResult.displaySummary, contains('868 MHz (EU)'));
      expect(passResult.displaySummary, contains('1011230'));
      expect(passResult.displaySummary, contains('83.03'));

      const mcuOkResult = PowerGResult(
        status: PowerGStatus.mcuOk,
        fw: '83.03',
        frequency: '868 MHz (EU)',
        message: 'MCU OK',
      );
      expect(mcuOkResult.isPass, isFalse);
      expect(mcuOkResult.displaySummary, contains('MCU OK'));
      expect(mcuOkResult.displaySummary, contains('Chưa test RF'));
    });
  });

  group('SRF Service Unit Tests', () {
    test('SRF Slot Parsing from Matrix and Props', () {
      final srfService = SrfService();

      // Case 1: Empty / 0000 matrix
      expect(srfService.parseSrfSlots('0000', {}), isEmpty);
      expect(srfService.parseSrfSlots('', {}), isEmpty);

      // Case 2: Multi-card matrix (like Golden Panel 1405)
      final mockProps = {
        'qolsys.srf_slot_one.card': '1',
        'qolsys.srf_slot_one.fw': '11.2.0-G26',
        'qolsys.srf_slot_two.card': '1',
        'qolsys.srf_slot_two.fw': '11.2.1-D26',
        'qolsys.srf_slot_four.card': '1',
        'qolsys.srf_slot_four.fw': '11.2.2-H26',
      };
      final slots = srfService.parseSrfSlots('1405', mockProps);
      expect(slots.length, equals(3));
      expect(slots[0].slotNumber, equals(1));
      expect(slots[0].frequency, equals('319.5 MHz'));
      expect(slots[0].brand, equals('GE'));
      expect(slots[0].fw, equals('11.2.0-G26'));

      expect(slots[1].slotNumber, equals(2));
      expect(slots[1].frequency, equals('433 MHz'));
      expect(slots[1].brand, equals('DSC'));

      expect(slots[2].slotNumber, equals(4));
      expect(slots[2].frequency, equals('345 MHz'));
      expect(slots[2].brand, equals('Honeywell'));
    });

    test('SrfResult Summary Formatting', () {
      const notInstalled = SrfResult(
        status: SrfStatus.notInstalled,
        message: 'Không có card SRF',
      );
      expect(notInstalled.isInstalled, isFalse);
      expect(notInstalled.displaySummary, equals('N/A - Không có card'));

      const passResult = SrfResult(
        status: SrfStatus.pass,
        matrix: '1405',
        slots: [
          SrfSlotInfo(
            slotNumber: 1,
            serviceName: 'srfservice_ttyHSL1',
            fw: '11.2.0-G26',
            frequency: '319.5 MHz',
            brand: 'GE',
          ),
        ],
        message: 'RF PASS',
      );
      expect(passResult.isInstalled, isTrue);
      expect(passResult.isPass, isTrue);
      expect(passResult.displaySummary, contains('PASS'));
      expect(passResult.displaySummary, contains('319.5 MHz'));
    });
  });
}
