import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ja_dut_info/modules/logic.dart';
import 'package:ja_dut_info/modules/services/ota_update_service.dart';
import 'package:ja_dut_info/modules/services/power_coordinator.dart';
import 'package:ja_dut_info/modules/ui/bubble_hover_region.dart';
import 'package:ja_dut_info/modules/ui/main_window.dart';
import 'package:ja_dut_info/modules/ui/styles.dart';

class _Monitor extends AdbMonitor {
  _Monitor() : super(autoStart: false);
  bool connected = false;
  @override
  bool get deviceConnected => connected;
  @override
  bool get isRfTesting => connected;
  void connect(bool value) {
    connected = value;
    notifyListeners();
  }
}

void main() {
  testWidgets(
    'MainWindow stops effects without ADB, collapsed, or tucked at edge',
    (tester) async {
      const windowChannel = MethodChannel('ja_route/window');
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(windowChannel, (call) async {
        if (call.method == 'getPosition') {
          return {'isDockedLeft': false, 'isDockedRight': false};
        }
        return null;
      });
      messenger.setMockMethodCallHandler(
        const MethodChannel('ja_route/theme'),
        (_) async => null,
      );
      late OtaUpdateService ota;
      await tester.runAsync(() async {
        ota = OtaUpdateService();
        await ota.ready;
      });
      final originalConfig = ota.config;
      ota.setCustomConfigFileForTesting(
        File('build/power-window-test-config.json'),
      );
      await tester.runAsync(
        () => ota.saveExternalConfigFile(
          originalConfig.copyWith(checkInterval: 'off'),
        ),
      );
      final monitor = _Monitor();
      const longValue = 'Very Long Hardware Test Text That Needs Scrolling';
      monitor.info['PCASN'] = longValue;
      final power = PowerCoordinator(autoAttachLifecycle: false);
      final theme = ThemeProvider();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AdbMonitor>.value(value: monitor),
            ChangeNotifierProvider<PowerCoordinator>.value(value: power),
            ChangeNotifierProvider<ThemeProvider>.value(value: theme),
            ChangeNotifierProvider<OtaUpdateService>.value(value: ota),
          ],
          child: MaterialApp(
            builder: (context, child) => ListenableBuilder(
              listenable: power,
              builder: (context, _) =>
                  TickerMode(enabled: power.isVisible, child: child!),
            ),
            home: const MainWindow(),
          ),
        ),
      );
      await tester.pump();
      final pulse = tester
          .widgetList<AnimatedBuilder>(find.byType(AnimatedBuilder))
          .map((widget) => widget.animation)
          .whereType<AnimationController>()
          .firstWhere(
            (controller) =>
                controller.duration == const Duration(milliseconds: 1600),
          );
      final sprout = tester
          .widgetList<AnimatedBuilder>(find.byType(AnimatedBuilder))
          .map((widget) => widget.animation)
          .whereType<AnimationController>()
          .firstWhere(
            (controller) =>
                controller.duration == const Duration(milliseconds: 360),
          );
      bool enabled() => tester
          .widget<TickerMode>(
            find
                .descendant(
                  of: find.byType(MainWindow),
                  matching: find.byType(TickerMode),
                )
                .first,
          )
          .enabled;
      void toggle() => tester
          .widgetList<GestureDetector>(find.byType(GestureDetector))
          .firstWhere((widget) => widget.onPanStart != null)
          .onTap!();
      void expectLightweight() {
        expect(pulse.isAnimating, isFalse);
        final cardFilters = find.descendant(
          of: find.byType(InfoCard),
          matching: find.byType(BackdropFilter),
        );
        final filters = tester.widgetList<BackdropFilter>(
          find.byWidgetPredicate(
            (widget) =>
                widget is BackdropFilter &&
                !cardFilters.evaluate().any(
                  (element) => identical(element.widget, widget),
                ),
          ),
        );
        expect(filters.every((filter) => !filter.enabled), isTrue);
        final cardContainers = find.descendant(
          of: find.byType(InfoCard),
          matching: find.byType(Container),
        );
        final decorations = tester
            .widgetList<Container>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is Container &&
                    !cardContainers.evaluate().any(
                      (element) => identical(element.widget, widget),
                    ),
              ),
            )
            .map((widget) => widget.decoration)
            .whereType<BoxDecoration>();
        expect(
          decorations.every(
            (decoration) =>
                decoration.boxShadow == null || decoration.boxShadow!.isEmpty,
          ),
          isTrue,
        );
      }

      try {
        expectLightweight();
        monitor.connect(true);
        await tester.pump();
        expect(sprout.isAnimating, isTrue);
        await tester.pump(const Duration(milliseconds: 180));
        expect(sprout.value, inExclusiveRange(0.0, 1.0));
        await tester.pump(const Duration(milliseconds: 400));
        expect(sprout.value, 1.0);
        expect(enabled(), isTrue);
        expect(pulse.isAnimating, isTrue);
        // Reading remains active when decorative effects stop on blur/idle.
        power.setFocused(false);
        await tester.pump();
        expectLightweight();
        void expectInformationEffects() {
          final cards = find.byType(InfoCard);
          expect(cards, findsNWidgets(7));
          final filters = tester.widgetList<BackdropFilter>(
            find.descendant(of: cards, matching: find.byType(BackdropFilter)),
          );
          expect(filters.every((filter) => filter.enabled), isTrue);
          expect(
            tester
                .widget<CircularProgressIndicator>(
                  find.byType(CircularProgressIndicator),
                )
                .value,
            isNull,
          );
        }

        expectInformationEffects();
        final marquee = find.byWidgetPredicate(
          (widget) => widget is MarqueeText && widget.text == longValue,
        );
        final scroll = tester
            .widget<SingleChildScrollView>(
              find.descendant(
                of: marquee,
                matching: find.byType(SingleChildScrollView),
              ),
            )
            .controller!;
        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pump();
        final previousOffset = scroll.offset;
        final rfRotation =
            tester
                    .widget<AnimatedBuilder>(
                      find.descendant(
                        of: find.byType(CircularProgressIndicator),
                        matching: find.byType(AnimatedBuilder),
                      ),
                    )
                    .animation
                as AnimationController;
        final previousRotation = rfRotation.value;
        await tester.pump(const Duration(milliseconds: 300));
        expect(scroll.offset, greaterThan(previousOffset));
        expect(rfRotation.value, isNot(previousRotation));
        power.setVisible(false);
        await tester.pump();
        final hiddenOffset = scroll.offset;
        final hiddenRotation = rfRotation.value;
        await tester.pump(const Duration(milliseconds: 300));
        expect(scroll.offset, hiddenOffset);
        expect(rfRotation.value, hiddenRotation);
        power.setVisible(true);
        power.setFocused(true);
        await tester.pump();
        toggle();
        await tester.pump();
        expectLightweight();
        expect(enabled(), isFalse);
        power.setHovered(true);
        await tester.pump();
        expect(enabled(), isFalse);
        toggle();
        await tester.pump();
        expect(enabled(), isTrue);
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'ja_route/window',
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onPositionChanged', {
              'isDockedRight': true,
              'isDockedLeft': false,
            }),
          ),
          (_) {},
        );
        await tester.pump();
        expectLightweight();
        tester
            .widget<BubbleHoverRegion>(find.byType(BubbleHoverRegion))
            .onChanged(true);
        await tester.pump();
        expect(enabled(), isTrue);
        tester
            .widget<BubbleHoverRegion>(find.byType(BubbleHoverRegion))
            .onChanged(false);
        await tester.pump();
        expect(enabled(), isTrue); // Cards are still visible at the edge.
        expectLightweight();
        expectInformationEffects();
        monitor.connect(false);
        await tester.pump();
        expect(sprout.isAnimating, isTrue);
        expect(sprout.status, AnimationStatus.reverse);
        await tester.pump(const Duration(milliseconds: 180));
        expect(sprout.value, inExclusiveRange(0.0, 1.0));
        await tester.pump(const Duration(milliseconds: 400));
        expect(sprout.value, 0.0);
        expect(sprout.isAnimating, isFalse);
        tester
            .widget<BubbleHoverRegion>(find.byType(BubbleHoverRegion))
            .onChanged(true);
        await tester.pump();
        expect(enabled(), isFalse);
        expect(pulse.isAnimating, isFalse);
        // Drain the position toast's one-shot delay before leaving the test.
        await tester.pump(const Duration(seconds: 2));
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        monitor.dispose();
        power.dispose();
        theme.dispose();
        await tester.runAsync(() => ota.saveExternalConfigFile(originalConfig));
        ota.setCustomConfigFileForTesting(null);
        messenger.setMockMethodCallHandler(windowChannel, null);
        messenger.setMockMethodCallHandler(
          const MethodChannel('ja_route/theme'),
          null,
        );
      }
    },
  );
}
