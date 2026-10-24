import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ja_dut_info/modules/logic.dart';
import 'package:ja_dut_info/modules/ui/main_window.dart';
import 'package:ja_dut_info/modules/ui/rf_diagnostics_dialog.dart';
import 'package:ja_dut_info/modules/ui/styles.dart';

void main() {
  group('InfoCard and RF Retest / Diagnostics Tap Tests', () {
    testWidgets(
      'RF card row tap triggers retest, while settings icon tap triggers diagnostics',
      (tester) async {
        var rowRetestCalled = false;
        var diagnosticsCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 286,
                  height: 26,
                  child: GestureDetector(
                    onTap: () {
                      rowRetestCalled = true;
                    },
                    child: InfoCard(
                      fieldKey: 'RF',
                      value: 'PASS - 868 MHz (EU)',
                      isDark: true,
                      isWarning: false,
                      modelName: 'DUT',
                      isRfTesting: false,
                      onDiagnosticsTap: () => diagnosticsCalled = true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        // Verify icons and layout: tune icon is present, separate refresh button is NOT present
        expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
        expect(find.byIcon(Icons.refresh_rounded), findsNothing);
        expect(find.text('RF'), findsOneWidget);
        expect(find.text('PASS'), findsOneWidget);

        // 1. Tapping the settings icon at the end opens diagnostics dialog, NOT row retest
        await tester.tap(find.byIcon(Icons.tune_rounded));
        await tester.pump();
        expect(diagnosticsCalled, isTrue);
        expect(rowRetestCalled, isFalse);

        // Reset flags
        diagnosticsCalled = false;
        rowRetestCalled = false;

        // 2. Tapping anywhere else on the RF row triggers retest, NOT diagnostics dialog
        await tester.tap(find.text('PASS'));
        await tester.pump();
        expect(rowRetestCalled, isTrue);
        expect(diagnosticsCalled, isFalse);
      },
    );

    testWidgets('RF card shows spinner during active testing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 286,
                height: 26,
                child: InfoCard(
                  fieldKey: 'RF',
                  value: 'Đang kiểm tra sóng RF...',
                  isDark: true,
                  isWarning: false,
                  modelName: 'DUT',
                  isRfTesting: true,
                ),
              ),
            ),
          ),
        ),
      );

      // CircularProgressIndicator is visible
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // No extra refresh button
      expect(find.byIcon(Icons.refresh_rounded), findsNothing);
    });

    testWidgets('Non-RF cards render standard copy icon without RF icons', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 286,
                height: 26,
                child: InfoCard(
                  fieldKey: 'PCASN',
                  value: 'QB94LNC002635V00510',
                  isDark: false,
                  isWarning: false,
                  modelName: 'DUT',
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.copy), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsNothing);
      expect(find.byIcon(Icons.tune_rounded), findsNothing);
    });

    testWidgets(
      'RF card displays GOLDEN ERR badge on Golden Panel card failure',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 286,
                  height: 26,
                  child: InfoCard(
                    fieldKey: 'RF',
                    value:
                        'SRF: LỖI GOLDEN - Thẻ Golden Slot 1 (10.3.5-G16) đời cũ Rev 1 ko phát được TX',
                    isDark: true,
                    isWarning: true,
                    modelName: 'IQ5',
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.text('GOLDEN ERR'), findsOneWidget);
      },
    );

    testWidgets(
      'RfDiagnosticsDialog has transparent barrier and auto-closes when DUT disconnects',
      (tester) async {
        var connected = true;
        final monitor = AdbMonitor(
          pollInterval: const Duration(milliseconds: 20),
          command: (args) async {
            if (args.length == 2) {
              return connected
                  ? 'List of devices attached\ndut-1\tdevice\n'
                  : 'List of devices attached\n';
            }
            if (args.last == 'sys.boot_completed') return '1';
            return 'OK';
          },
        );
        addTearDown(monitor.dispose);

        // Wait for monitor to detect dut-1
        for (var i = 0; i < 40 && !monitor.deviceConnected; i++) {
          await tester.pump(const Duration(milliseconds: 25));
        }
        expect(monitor.deviceConnected, isTrue);

        var dialogClosed = false;
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: ThemeProvider()),
              ChangeNotifierProvider.value(value: monitor),
            ],
            child: MaterialApp(
              home: Builder(
                builder: (ctx) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () {
                      showRfDiagnosticsDialog(
                        context: ctx,
                        onDialogClosed: () => dialogClosed = true,
                      );
                    },
                    child: const Text('Open RF'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open RF'));
        await tester.pumpAndSettle();
        expect(find.text('Chẩn đoán Sóng RF'), findsOneWidget);

        // Verify modal barrier is transparent (no dim gray box around dialog)
        final barriers = tester
            .widgetList<ModalBarrier>(find.byType(ModalBarrier))
            .toList();
        expect(
          barriers.any((b) => b.color == Colors.transparent || b.color == null),
          isTrue,
        );

        // Simulate DUT disconnect -> dialog should auto-close immediately
        connected = false;
        for (var i = 0; i < 40 && !dialogClosed; i++) {
          await tester.pump(const Duration(milliseconds: 25));
        }
        await tester.pumpAndSettle();
        expect(dialogClosed, isTrue);
        expect(find.text('Chẩn đoán Sóng RF'), findsNothing);

        monitor.stop();
        await tester.pump(const Duration(seconds: 3));
      },
    );
  });
}
