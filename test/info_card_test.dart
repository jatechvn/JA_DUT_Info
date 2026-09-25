import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_dut_info/modules/ui/main_window.dart';

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
  });
}
