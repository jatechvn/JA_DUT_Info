import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_dut_info/modules/services/power_coordinator.dart';
import 'package:ja_dut_info/modules/ui/main_window.dart';

void main() {
  for (final state in AppLifecycleState.values) {
    testWidgets('Coordinator synchronizes initial lifecycle $state', (
      tester,
    ) async {
      tester.binding.handleAppLifecycleStateChanged(state);
      final power = PowerCoordinator();
      try {
        expect(power.isUiAnimationEnabled, state == AppLifecycleState.resumed);
        expect(power.isFocused, state == AppLifecycleState.resumed);
        expect(
          power.isVisible,
          state == AppLifecycleState.resumed ||
              state == AppLifecycleState.inactive,
        );
      } finally {
        power.dispose();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }
    });
  }

  test('Hide clears focus and hover even without exit or blur events', () {
    final power = PowerCoordinator(autoAttachLifecycle: false);
    try {
      power.setHovered(true);
      power.setVisible(false);
      expect(power.isInteracting, isFalse);
      expect(power.isFocused, isFalse);
      // Ignore a late hover event from the hidden window.
      power.setHovered(true);
      power.setVisible(true);
      expect(power.isUiAnimationEnabled, isFalse);
      power.setHovered(true);
      expect(power.isUiAnimationEnabled, isTrue);
      power.setHovered(false);
      expect(power.isUiAnimationEnabled, isFalse);
      power.setFocused(true);
      expect(power.isUiAnimationEnabled, isTrue);
    } finally {
      power.dispose();
    }
  });

  testWidgets('Lifecycle hide/show discards previous hover', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final power = PowerCoordinator();
    try {
      power.setHovered(true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      expect(power.isInteracting, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      expect(power.isVisible, isTrue);
      expect(power.isUiAnimationEnabled, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(power.isUiAnimationEnabled, isTrue);
    } finally {
      power.dispose();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }
  });

  testWidgets(
    'Changing marquee text stops old scroll and resumes after new hold',
    (tester) async {
      Widget view(String text) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 50,
            child: MarqueeText(
              key: const ValueKey('marquee'),
              text: text,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      );
      await tester.pumpWidget(
        view('Very Long Hardware Test Text That Needs Scrolling'),
      );
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final controller = tester
          .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
          .controller!;
      expect(controller.offset, greaterThan(0));
      await tester.pumpWidget(
        view('Another Long Hardware Test Text That Needs Scrolling'),
      );
      final offset = controller.offset;
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.offset, closeTo(offset, 0.01));
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.offset, greaterThan(offset));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
