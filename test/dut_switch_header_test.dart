import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_dut_info/modules/ui/main_window.dart';

void main() {
  testWidgets('native header geometry follows position and slide animation', (
    tester,
  ) async {
    final rootKey = GlobalKey();
    final headerKey = GlobalKey();
    Widget scene(double left, double slide, {bool visible = true}) =>
        MaterialApp(
          home: SizedBox(
            key: rootKey,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 260),
                  left: left,
                  top: 20,
                  width: 175,
                  height: 18,
                  child: Transform.translate(
                    offset: Offset(slide, 0),
                    child: visible
                        ? DutSwitchHeader(
                            key: headerKey,
                            currentDut: 'A',
                            allDuts: const ['A', 'B'],
                            isDark: true,
                            onSwitchDut: (_) {},
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        );
    await tester.pumpWidget(scene(20, 35));
    final root = rootKey.currentContext!.findRenderObject()! as RenderBox;
    expect(measuredHeaderRect(headerKey, root)!.left, 55);
    await tester.pumpWidget(scene(120, -17));
    await tester.pump(const Duration(milliseconds: 130));
    final rect = measuredHeaderRect(headerKey, root)!;
    expect(rect.left, closeTo(53, 0.01));
    expect(rect.size, const Size(175, 18));
    expect(
      rect.topLeft,
      tester.getTopLeft(find.byKey(headerKey)) -
          root.localToGlobal(Offset.zero),
    );
    await tester.pump(const Duration(milliseconds: 130));
    expect(measuredHeaderRect(headerKey, root)!.left, 103);
    await tester.pumpWidget(scene(120, 0, visible: false));
    expect(measuredHeaderRect(headerKey, root), isNull);
  });
  group('DutSwitchHeader Widget Tests', () {
    testWidgets('Renders DUT name, count badge and ĐỔI swap action', (
      tester,
    ) async {
      String? switchedDut;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 175,
                height: 18,
                child: DutSwitchHeader(
                  currentDut: 'bc4cd33a',
                  allDuts: const ['bc4cd33a', '2b69e02'],
                  isDark: true,
                  onSwitchDut: (dut) => switchedDut = dut,
                ),
              ),
            ),
          ),
        ),
      );

      // Verify label and badges
      expect(find.text('DUT: bc4cd33a (1/2)'), findsOneWidget);
      expect(find.text('ĐỔI'), findsOneWidget);
      expect(find.byIcon(Icons.phone_android_rounded), findsOneWidget);
      expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);

      // Tap header to switch DUT
      await tester.tap(find.byType(DutSwitchHeader));
      await tester.pump();

      expect(switchedDut, equals('2b69e02'));
    });

    testWidgets('Cycles from last DUT back to first DUT when tapped', (
      tester,
    ) async {
      String? switchedDut;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 175,
                height: 18,
                child: DutSwitchHeader(
                  currentDut: '2b69e02',
                  allDuts: const ['bc4cd33a', '2b69e02'],
                  isDark: false,
                  onSwitchDut: (dut) => switchedDut = dut,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('DUT: 2b69e02 (2/2)'), findsOneWidget);

      await tester.tap(find.byType(DutSwitchHeader));
      await tester.pump();

      expect(switchedDut, equals('bc4cd33a'));
    });

    testWidgets('Hover changes state without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 175,
                height: 18,
                child: DutSwitchHeader(
                  currentDut: 'bc4cd33a',
                  allDuts: const ['bc4cd33a', 'DUT_2', 'DUT_3'],
                  isDark: true,
                  onSwitchDut: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('DUT: bc4cd33a (1/3)'), findsOneWidget);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.byType(DutSwitchHeader)));
      await tester.pumpAndSettle();
    });
  });
}
