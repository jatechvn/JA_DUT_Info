// test/golden_audit_service_test.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ja_dut_info/modules/logic.dart';
import 'package:ja_dut_info/modules/services/golden_audit_service.dart';
import 'package:ja_dut_info/modules/services/powerg_service.dart';
import 'package:ja_dut_info/modules/services/srf_service.dart';
import 'package:ja_dut_info/modules/ui/golden_audit_dialog.dart';
import 'package:ja_dut_info/modules/ui/styles.dart';

void main() {
  group('GoldenAuditService - Shift Resolution', () {
    test(
      'resolves Day Shift (07:30 - 19:29) and Night Shift (19:30 - 07:29)',
      () {
        final morning = DateTime(2026, 11, 3, 8, 15);
        expect(GoldenAuditService.resolveShiftId(morning), '2026-11-03_DAY');
        expect(
          GoldenAuditService.resolveShiftLabel(morning),
          'Ca Ngày (07:30–19:30)',
        );

        final evening = DateTime(2026, 11, 3, 20, 0);
        expect(GoldenAuditService.resolveShiftId(evening), '2026-11-03_NIGHT');
        expect(
          GoldenAuditService.resolveShiftLabel(evening),
          'Ca Đêm (19:30–07:30)',
        );

        // Post-midnight (02:30 AM on Nov 4 belongs to Nov 3 Night Shift)
        final postMidnight = DateTime(2026, 11, 4, 2, 30);
        expect(
          GoldenAuditService.resolveShiftId(postMidnight),
          '2026-11-03_NIGHT',
        );
      },
    );
  });

  group('GoldenAuditService - 3-Tier FHI Scoring & Diagnostics', () {
    test('certified grade (FHI >= 85%) on healthy fixture and valid DUT', () {
      final service = GoldenAuditService(storageFilePath: null);
      final report = service.evaluateDut(
        dutSerial: 'd166f87c',
        modelName: 'IQ4',
        info: const {
          'PCASN': 'QB9400123456',
          'SYSSN': 'QP4001X022624V00001',
          'SYSPN': 'IQP4001',
          'LCMPN': 'Chú ý Panel này không được chạy lại màn hình',
          'IMEI': '359208100000005', // Valid Luhn
          'CPU': 'LE20B04-1234',
        },
        powerGResult: const PowerGResult(
          status: PowerGStatus.pass,
          fw: '80.26',
          protocol: '8',
          frequency: '915 MHz (NA)',
          sensorId: '1014562',
          message: 'RF PASS',
          durationMs: 1400,
          pollAttempts: 1,
        ),
        srfResult: const SrfResult(
          status: SrfStatus.pass,
          matrix: '1000',
          slots: [
            SrfSlotInfo(
              slotNumber: 1,
              serviceName: 'srfservice_ttyHSLX',
              fw: '10.3.5-G26',
              frequency: '319.5 MHz',
              brand: 'GE',
            ),
          ],
          goldenPanelSerial: 'golden01',
          message: 'RF PASS',
          durationMs: 2100,
          mcuPingRetries: 0,
        ),
        goldenPanelSerial: 'golden01',
        eepromRetryCount: 0,
        bootWaitMs: 3000,
      );

      expect(report.fhiScore, 100);
      expect(report.powerGScore, 30);
      expect(report.srfScore, 30);
      expect(report.busStabilityScore, 20);
      expect(report.identityScore, 20);
      expect(report.grade, FixtureHealthGrade.certified);
    });

    test(
      'warning grade (70% <= FHI < 85%) on degraded pogo/retries & MCU-only RF',
      () {
        final service = GoldenAuditService(storageFilePath: null);
        final report = service.evaluateDut(
          dutSerial: 'd166f87c',
          modelName: 'IQ4',
          info: const {
            'PCASN': 'QB9400123456',
            'SYSSN': 'QP4001X022624V00001',
            'SYSPN': 'IQP4001',
            'LCMPN': 'OK',
            'IMEI': '359208100000008',
            'CPU': 'LE20B04-1234',
          },
          powerGResult: const PowerGResult(
            status: PowerGStatus.mcuOk,
            fw: '80.26',
            protocol: '8',
            frequency: '915 MHz (NA)',
            message: 'MCU OK',
            durationMs: 1800,
            pollAttempts: 1,
          ),
          srfResult: const SrfResult(
            status: SrfStatus.mcuOk,
            matrix: '1000',
            message: 'MCU OK',
            durationMs: 2000,
            mcuPingRetries: 1,
          ),
          eepromRetryCount: 2,
          bootWaitMs: 4000,
        );

        // pg=22, srf=19, bus=14, id=20 => 75% (warning)
        expect(report.fhiScore, inInclusiveRange(70, 84));
        expect(report.grade, FixtureHealthGrade.warning);
        expect(
          report.diagnosticsNotes.any((n) => n.contains('EEPROM phải thử lại')),
          isTrue,
        );
      },
    );

    test('critical grade (FHI < 70%) on RF failure and model mismatch', () {
      final service = GoldenAuditService(storageFilePath: null);
      final report = service.evaluateDut(
        dutSerial: 'bad01',
        modelName: 'IQ5',
        info: const {
          'PCASN': 'QB9500123456', // IQ5 board
          'SYSSN': 'QP4001X022624V00001', // IQ4 SYSSN mismatch!
          'SYSPN': 'IQP4001',
          'LCMPN': 'OK',
          'IMEI': '123456789012345', // Invalid Luhn
          'CPU': 'msm', // Invalid baseband placeholder
        },
        powerGResult: const PowerGResult(
          status: PowerGStatus.fail,
          message: 'FAIL',
        ),
        srfResult: const SrfResult(status: SrfStatus.fail, message: 'FAIL'),
        eepromRetryCount: 4,
        bootWaitMs: 30000,
      );

      expect(report.fhiScore, lessThan(70));
      expect(report.grade, FixtureHealthGrade.critical);
      expect(
        report.diagnosticsNotes.any((n) => n.contains('SAI LỆCH DÒNG MÁY')),
        isTrue,
      );
    });
  });

  group(
    'GoldenAuditService - Golden KGU Registration, Shift Cert & Persistence',
    () {
      test(
        'registers Golden board, auto-certifies shift on FHI >= 85%, and persists to disk',
        () {
          final tempDir = Directory.systemTemp.createTempSync(
            'golden_audit_test_',
          );
          try {
            final filePath = '${tempDir.path}/golden_audit_state.json';
            final now = DateTime(2026, 11, 3, 9, 0);
            final service = GoldenAuditService(storageFilePath: filePath);

            service.registerGoldenBoard(
              syssn: 'QR5EU0X022624V00016',
              pcasn: 'QB95R0012345',
              syspn: 'IQR5EU0',
              modelName: 'IQ5',
              baselinePowerGMs: 2500,
              now: now,
            );

            expect(
              service.isRegisteredGoldenBoard(
                syssn: 'QR5EU0X022624V00016',
                pcasn: 'OTHER',
              ),
              isTrue,
            );
            expect(service.isCurrentShiftCertified(now: now), isFalse);

            // Evaluate the registered Golden board with passing IQ5 PowerG Node
            final report = service.evaluateDut(
              dutSerial: 'da9c1c8d',
              modelName: 'IQ5',
              info: const {
                'PCASN': 'QB95R0012345',
                'SYSSN': 'QR5EU0X022624V00016',
                'SYSPN': 'IQR5EU0',
                'LCMPN': 'Chú ý Panel này không được chạy lại màn hình',
                'IMEI': 'N/A',
                'CPU': 'BP04BP10ABM01(SC200EWFDAR14A01)',
              },
              powerGResult: PowerGService.iq5McuResult(
                fw: '02.26',
                protocol: '9',
                details: 'Operation Result: SUCCESS',
                durationMs: 2400,
                pollAttempts: 1,
              ),
              srfResult: const SrfResult(
                status: SrfStatus.notInstalled,
                matrix: '0000',
                message: 'Không có card SRF',
              ),
              now: now,
            );

            expect(report.isRegisteredGolden, isTrue);
            expect(report.fhiScore, greaterThanOrEqualTo(85));
            expect(report.grade, FixtureHealthGrade.certified);
            expect(report.isShiftCertified, isTrue);
            expect(service.isCurrentShiftCertified(now: now), isTrue);
            expect(
              report.formatAuditCertificate(),
              contains('ĐÃ CẤP CHỨNG CHỈ ĐẦU CA (SHIFT CERTIFIED)'),
            );

            // Reload from disk in a new service instance
            final reloaded = GoldenAuditService(storageFilePath: filePath)
              ..loadFromDiskSyncSafe();
            expect(reloaded.goldenBoards.length, 1);
            expect(reloaded.goldenBoards.first.syssn, 'QR5EU0X022624V00016');
            expect(reloaded.isCurrentShiftCertified(now: now), isTrue);

            // Unregister Golden board
            final removed = reloaded.unregisterGoldenBoard(
              syssn: 'QR5EU0X022624V00016',
              pcasn: 'QB95R0012345',
            );
            expect(removed, isTrue);
            expect(reloaded.goldenBoards, isEmpty);
          } finally {
            tempDir.deleteSync(recursive: true);
          }
        },
      );

      testWidgets(
        'GoldenAuditDialog renders 396x295 Frosted Glass without overflow',
        (tester) async {
          final monitor = AdbMonitor(
            autoStart: false,
            command: (_) async => '',
            powerGVerifier: (_) async => const PowerGResult(
              status: PowerGStatus.pass,
              fw: '80.26',
              protocol: '8',
              frequency: '915 MHz (NA)',
              message: 'PASS',
            ),
            srfVerifier: (_, _) async => const SrfResult(
              status: SrfStatus.pass,
              matrix: '1000',
              message: 'PASS',
            ),
          );
          monitor.goldenAudit.evaluateDut(
            dutSerial: 'd166f87c',
            modelName: 'IQ4',
            info: const {
              'PCASN': 'QB9400123456',
              'SYSSN': 'QP4001X022624V00001',
              'SYSPN': 'IQP4001',
              'LCMPN': 'OK',
              'IMEI': '359208100000005',
              'CPU': 'LE20B04-1234',
            },
            powerGResult: const PowerGResult(
              status: PowerGStatus.pass,
              fw: '80.26',
              protocol: '8',
              frequency: '915 MHz (NA)',
              message: 'PASS',
            ),
            srfResult: const SrfResult(
              status: SrfStatus.pass,
              matrix: '1000',
              message: 'PASS',
            ),
            goldenPanelSerial: 'golden01',
          );

          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => ThemeProvider()),
                ChangeNotifierProvider.value(value: monitor),
              ],
              child: const MaterialApp(
                home: Scaffold(body: GoldenAuditDialog()),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('100%'), findsOneWidget);
          expect(find.text('CERTIFIED'), findsOneWidget);
          expect(find.text('Sóng PowerG'), findsOneWidget);
          expect(find.text('Sóng SRF & Golden'), findsOneWidget);
          expect(find.text('Cáp USB / Kim Pogo'), findsOneWidget);
          expect(find.text('Định danh & BOM'), findsOneWidget);

          monitor.dispose();
        },
      );
    },
  );
}
