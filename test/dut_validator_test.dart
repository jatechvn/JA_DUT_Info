// test/dut_validator_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:ja_dut_info/modules/services/dut_validator.dart';

void main() {
  group('DutValidator Smart Validation Tests', () {
    test('isValidImei validates 15-digit Luhn checksums accurately', () {
      expect(DutValidator.isValidImei('490154203237518'), isTrue);
      expect(DutValidator.isValidImei('353879230123457'), isTrue);

      // Invalid Luhn check digit
      expect(DutValidator.isValidImei('353879230123458'), isFalse);
      // Wrong length
      expect(DutValidator.isValidImei('35387923012345'), isFalse);
      expect(DutValidator.isValidImei('3538792301234570'), isFalse);
      // All zeros
      expect(DutValidator.isValidImei('000000000000000'), isFalse);
      // Non-numeric
      expect(DutValidator.isValidImei('N/A'), isFalse);
    });

    test('hasModelMismatch detects cross-flashed IQ4 vs IQ5 identifiers', () {
      expect(
        DutValidator.hasModelMismatch({
          'PCASN': 'QB9501A002632V06416',
          'SYSSN': 'QP5001A002633V00633',
          'SYSPN': 'IQP5001',
        }),
        isFalse,
      );

      expect(
        DutValidator.hasModelMismatch({
          'PCASN': 'QB9401A001234V00001',
          'SYSSN': 'QP4001A001234V00001',
          'SYSPN': 'IQP4001',
        }),
        isFalse,
      );

      // IQ5 board flashed with IQ4 SYSSN
      expect(
        DutValidator.hasModelMismatch({
          'PCASN': 'QB9501A002632V06416',
          'SYSSN': 'QP4001A001234V00001',
          'SYSPN': 'IQP5001',
        }),
        isTrue,
      );

      // IQ4 board flashed with IQ5 SYSPN
      expect(
        DutValidator.hasModelMismatch({
          'PCASN': 'QB9401A001234V00001',
          'SYSSN': 'QP4001A001234V00001',
          'SYSPN': 'IQP5001',
        }),
        isTrue,
      );
    });

    test('isFieldWarning flags anomalies and ignores transient states', () {
      final cleanInfo = {
        'PCASN': 'QB9501A002632V06416',
        'SYSSN': 'QP5001A002633V00633',
        'SYSPN': 'IQP5001',
        'LCMPN': 'Chú ý Panel này không được chạy lại màn hình',
        'IMEI': '490154203237518',
        'CPU': 'MPSS.HI.4.3.1',
      };

      expect(
        DutValidator.isFieldWarning('SYSSN', 'Đang đọc...', cleanInfo),
        isFalse,
      );
      expect(
        DutValidator.isFieldWarning('IMEI', '490154203237518', cleanInfo),
        isFalse,
      );
      expect(
        DutValidator.isFieldWarning('IMEI', '353879230123458', cleanInfo),
        isTrue,
      );
      expect(
        DutValidator.isFieldWarning('SYSSN', 'Chưa test MMI', cleanInfo),
        isTrue,
      );
      expect(
        DutValidator.isFieldWarning(
          'LCMPN',
          'Chú ý Panel này không được chạy lại màn hình',
          cleanInfo,
        ),
        isTrue,
      );
      expect(
        DutValidator.isFieldWarning('RF', 'FAIL - Lỗi MCU', cleanInfo),
        isTrue,
      );
      expect(
        DutValidator.isFieldWarning('RF', 'PASS - 915 MHz', cleanInfo),
        isFalse,
      );
    });
  });
}
