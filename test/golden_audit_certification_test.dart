import 'package:flutter_test/flutter_test.dart';
import 'package:ja_dut_info/modules/services/golden_audit_service.dart';
import 'package:ja_dut_info/modules/services/powerg_service.dart';
import 'package:ja_dut_info/modules/services/srf_service.dart';

const _info = {
  'PCASN': 'QB9400123456',
  'SYSSN': 'QP4001X022624V00001',
  'SYSPN': 'IQP4001',
  'IMEI': '359208100000005',
  'CPU': 'LE20B04-1234',
};
const _pg = PowerGResult(status: PowerGStatus.pass, message: 'PASS');
const _srf = SrfResult(status: SrfStatus.pass, matrix: '1000', message: 'PASS');

void _register(GoldenAuditService service, DateTime now) {
  service.registerGoldenBoard(
    syssn: _info['SYSSN']!,
    pcasn: _info['PCASN']!,
    syspn: _info['SYSPN']!,
    modelName: 'IQ4',
    now: now,
  );
}

FixtureAuditReport _evaluate(
  GoldenAuditService service,
  DateTime now, {
  PowerGResult? pg = _pg,
  SrfResult? srf = _srf,
}) => service.evaluateDut(
  dutSerial: 'test',
  modelName: 'IQ4',
  info: _info,
  powerGResult: pg,
  srfResult: srf,
  now: now,
);

void main() {
  final morning = DateTime(2026, 11, 3, 9);
  for (final registerFirst in [true, false]) {
    for (final pending in [
      'PowerG absent',
      'PowerG testing',
      'SRF absent',
      'SRF testing',
    ]) {
      test('$pending cannot certify (register first: $registerFirst)', () {
        final service = GoldenAuditService(storageFilePath: null);
        addTearDown(service.dispose);
        if (registerFirst) _register(service, morning);
        final report = _evaluate(
          service,
          morning,
          pg: pending == 'PowerG absent'
              ? null
              : pending == 'PowerG testing'
              ? const PowerGResult(
                  status: PowerGStatus.testing,
                  message: 'Testing',
                )
              : _pg,
          srf: pending == 'SRF absent'
              ? null
              : pending == 'SRF testing'
              ? const SrfResult(
                  status: SrfStatus.testing,
                  matrix: '1000',
                  message: 'Testing',
                )
              : _srf,
        );
        expect(report.fhiScore, greaterThanOrEqualTo(85));
        if (!registerFirst) _register(service, morning);
        expect(service.isCurrentShiftCertified(now: morning), isFalse);
        expect(service.latestReport!.isShiftCertified, isFalse);
        _evaluate(service, morning.add(const Duration(minutes: 1)));
        expect(service.isCurrentShiftCertified(now: morning), isTrue);
      });
    }
  }

  final boundaries = [
    (DateTime(2026, 11, 3, 19, 29), DateTime(2026, 11, 3, 19, 30)),
    (DateTime(2026, 11, 4, 7, 29), DateTime(2026, 11, 4, 7, 30)),
    (morning, morning.add(const Duration(days: 1))),
  ];
  for (final (measuredAt, registeredAt) in boundaries) {
    test(
      'Registration at $registeredAt cannot reuse measurement $measuredAt',
      () {
        final service = GoldenAuditService(storageFilePath: null);
        addTearDown(service.dispose);
        final original = _evaluate(service, measuredAt);
        _register(service, registeredAt);
        // Repeated registration must not relabel old evidence to the new shift.
        _register(service, registeredAt);
        expect(service.isCurrentShiftCertified(now: registeredAt), isFalse);
        expect(service.latestReport!.timestamp, measuredAt);
        expect(service.latestReport!.shiftId, original.shiftId);
        expect(service.latestReport!.shiftLabel, original.shiftLabel);
        _evaluate(service, registeredAt);
        expect(service.isCurrentShiftCertified(now: registeredAt), isTrue);
      },
    );
  }

  test('Same-shift completed measurement can certify on registration', () {
    final service = GoldenAuditService(storageFilePath: null);
    addTearDown(service.dispose);
    _evaluate(service, morning);
    _register(service, morning.add(const Duration(minutes: 5)));
    expect(service.isCurrentShiftCertified(now: morning), isTrue);
    expect(service.latestReport!.isShiftCertified, isTrue);
  });

  test('Clear report invalidates cached certification eligibility', () {
    final service = GoldenAuditService(storageFilePath: null);
    addTearDown(service.dispose);
    _evaluate(service, morning);
    service.clearLatestReport();
    _register(service, morning);
    expect(service.isCurrentShiftCertified(now: morning), isFalse);
  });
}
