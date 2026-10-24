// test/dut_history_service_test.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ja_dut_info/modules/logic.dart';
import 'package:ja_dut_info/modules/services/dut_history_service.dart';
import 'package:ja_dut_info/modules/ui/dut_history_dialog.dart';
import 'package:ja_dut_info/modules/ui/styles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DutHistoryService & DutHistoryDialog Tests', () {
    test(
      'records, updates in-place for same PCASN, and enforces max 30 entries',
      () {
        final service = DutHistoryService(storageFilePath: null);

        service.recordSnapshot(
          serial: 'dut-1',
          modelName: 'IQ5',
          stationResult: 'FT1',
          info: {
            'PCASN': 'QB95-001',
            'SYSSN': 'QP50-001',
            'SYSPN': 'IQP5001',
            'LCMPN': 'LCM-1',
            'IMEI': '490154203237518',
            'CPU': 'MPSS.1',
          },
          powerGSummary: 'Đang kiểm tra...',
          srfSummary: 'Đang kiểm tra...',
          isRfPass: false,
        );
        expect(service.count, 1);

        // Update same PCASN when RF finishes -> updates index 0 in-place
        service.recordSnapshot(
          serial: 'dut-1',
          modelName: 'IQ5',
          stationResult: 'FT1',
          info: {
            'PCASN': 'QB95-001',
            'SYSSN': 'QP50-001',
            'SYSPN': 'IQP5001',
            'LCMPN': 'LCM-1',
            'IMEI': '490154203237518',
            'CPU': 'MPSS.1',
          },
          powerGSummary: 'PASS - 915 MHz',
          srfSummary: 'PASS - 319.5 MHz',
          isRfPass: true,
        );
        expect(service.count, 1);
        expect(service.entries.first.isRfPass, isTrue);
        expect(service.entries.first.powerGSummary, 'PASS - 915 MHz');

        // Insert 35 distinct DUTs and verify ring buffer cap at 30
        for (int i = 2; i <= 36; i++) {
          service.recordSnapshot(
            serial: 'dut-$i',
            modelName: 'IQ4',
            stationResult: 'MMI',
            info: {
              'PCASN': 'QB94-$i',
              'SYSSN': 'QP40-$i',
              'SYSPN': 'IQP4001',
              'LCMPN': 'LCM',
              'IMEI': '490154203237518',
              'CPU': 'MPSS',
            },
            powerGSummary: 'PASS',
            srfSummary: 'PASS',
            isRfPass: true,
          );
        }
        expect(service.count, DutHistoryService.maxEntries);
        expect(service.entries.first.pcasn, 'QB94-36');
      },
    );

    test('persists and reloads history from JSON file safely', () {
      final tempDir = Directory.systemTemp.createTempSync('dut_hist_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final path = '${tempDir.path}/dut_history.json';

      final writer = DutHistoryService(storageFilePath: path);
      writer.recordSnapshot(
        serial: 'serial-abc',
        modelName: 'IQ5',
        stationResult: 'FBT',
        info: {
          'PCASN': 'QB95-PERSIST',
          'SYSSN': 'QP50-PERSIST',
          'SYSPN': 'IQP5',
          'LCMPN': 'OK',
          'IMEI': '490154203237518',
          'CPU': 'BB-1',
        },
        powerGSummary: 'PASS - 868 MHz',
        srfSummary: 'N/A',
        isRfPass: true,
      );

      final reader = DutHistoryService(storageFilePath: path)
        ..loadFromDiskSyncSafe();
      expect(reader.count, 1);
      expect(reader.entries.first.syssn, 'QP50-PERSIST');
      expect(reader.formatAllHistoryReport(), contains('QP50-PERSIST'));
    });

    testWidgets('DutHistoryDialog renders recorded entries and clear button', (
      tester,
    ) async {
      final monitor = AdbMonitor(autoStart: false);
      addTearDown(monitor.dispose);
      monitor.history.clearHistory();
      monitor.history.recordSnapshot(
        serial: '1d98b004',
        modelName: 'IQ5',
        stationResult: 'MMI_PASS',
        info: {
          'PCASN': 'QB9501A002632V06416',
          'SYSSN': 'QP5001A002633V00633',
          'SYSPN': 'IQP5001',
          'LCMPN': 'OK',
          'IMEI': '490154203237518',
          'CPU': 'MPSS',
        },
        powerGSummary: 'PASS',
        srfSummary: 'PASS',
        isRfPass: true,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider.value(value: monitor),
          ],
          child: const MaterialApp(home: Scaffold(body: DutHistoryDialog())),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Lịch sử DUT trong phiên (1)'),
        findsOneWidget,
      );
      expect(find.textContaining('QP5001A002633V00633'), findsOneWidget);

      await tester.tap(find.text('Xóa'));
      await tester.pumpAndSettle();
      expect(monitor.history.count, 0);
    });
  });
}
