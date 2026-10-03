// test/power_coordinator_test.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_dut_info/modules/services/power_coordinator.dart';
import 'package:ja_dut_info/modules/ui/main_window.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PowerCoordinator Unit Tests', () {
    test('Initial state is fully active', () {
      final coordinator = PowerCoordinator(
        idleTimeout: const Duration(seconds: 12),
        autoAttachLifecycle: false,
      );
      addTearDown(coordinator.dispose);

      expect(coordinator.isVisible, isTrue);
      expect(coordinator.isFocused, isTrue);
      expect(coordinator.isInteracting, isFalse);
      expect(coordinator.isIdle, isFalse);
      expect(coordinator.isUiAnimationEnabled, isTrue);
    });

    test('Losing focus disables UI animations, hovering restores it', () {
      final coordinator = PowerCoordinator(
        idleTimeout: const Duration(seconds: 12),
        autoAttachLifecycle: false,
      );
      addTearDown(coordinator.dispose);

      coordinator.setFocused(false);
      expect(coordinator.isFocused, isFalse);
      expect(coordinator.isUiAnimationEnabled, isFalse);

      // Hovering over floating widget restores UI animations even when window lacks OS focus
      coordinator.setHovered(true);
      expect(coordinator.isInteracting, isTrue);
      expect(coordinator.isUiAnimationEnabled, isTrue);

      coordinator.setHovered(false);
      expect(coordinator.isInteracting, isFalse);
      expect(coordinator.isUiAnimationEnabled, isFalse);
    });

    test('Hiding window mutes UI animation regardless of focus', () {
      final coordinator = PowerCoordinator(
        idleTimeout: const Duration(seconds: 12),
        autoAttachLifecycle: false,
      );
      addTearDown(coordinator.dispose);

      coordinator.setVisible(false);
      expect(coordinator.isVisible, isFalse);
      expect(coordinator.isUiAnimationEnabled, isFalse);

      // Showing without focus remains muted
      coordinator.setFocused(false);
      coordinator.setVisible(true);
      expect(coordinator.isVisible, isTrue);
      expect(coordinator.isFocused, isFalse);
      expect(coordinator.isUiAnimationEnabled, isFalse);
    });

    test(
      'Idle timeout triggers idle sleep, recordUserActivity wakes it',
      () async {
        final coordinator = PowerCoordinator(
          idleTimeout: const Duration(milliseconds: 50),
          autoAttachLifecycle: false,
        );
        addTearDown(coordinator.dispose);

        expect(coordinator.isIdle, isFalse);
        expect(coordinator.isUiAnimationEnabled, isTrue);

        // Wait for idle timer
        await Future.delayed(const Duration(milliseconds: 70));
        expect(coordinator.isIdle, isTrue);
        expect(coordinator.isUiAnimationEnabled, isFalse);

        // Record user activity wakes it
        coordinator.recordUserActivity();
        expect(coordinator.isIdle, isFalse);
        expect(coordinator.isUiAnimationEnabled, isTrue);
      },
    );
  });

  group('TickerMode and Animation Gating Widget Tests', () {
    testWidgets(
      'Ordinary repeating animation stops when TickerMode is disabled',
      (tester) async {
        final coordinator = PowerCoordinator(autoAttachLifecycle: false);
        AnimationController? controller;

        try {
          await tester.pumpWidget(
            ListenableBuilder(
              listenable: coordinator,
              builder: (context, _) {
                return MaterialApp(
                  home: TickerMode(
                    enabled: coordinator.isUiAnimationEnabled,
                    child: _MutedTickerWidget(
                      onController: (c) => controller = c,
                    ),
                  ),
                );
              },
            ),
          );

          // Run animation for 200ms
          await tester.pump(const Duration(milliseconds: 200));
          expect(controller!.value, greaterThan(0.0));
          final valBeforePause = controller!.value;

          // Blur/unfocus window -> TickerMode disabled
          coordinator.setFocused(false);
          await tester.pump();

          // Advance time by 200ms while muted; controller value must not advance
          await tester.pump(const Duration(milliseconds: 200));
          expect(controller!.value, equals(valBeforePause));

          // Refocus window -> TickerMode enabled
          coordinator.setFocused(true);
          await tester.pump();

          // Resumes advancing
          await tester.pump(const Duration(milliseconds: 200));
          expect(controller!.value, greaterThan(valBeforePause));
        } finally {
          coordinator.dispose();
        }
      },
    );

    testWidgets(
      'Phase and direction continuity across pause/resume in PhaseTrackingWidget',
      (tester) async {
        final coordinator = PowerCoordinator(autoAttachLifecycle: false);
        AnimationController? controller;

        try {
          await tester.pumpWidget(
            MaterialApp(
              home: _PhaseTrackingWidget(
                coordinator: coordinator,
                onController: (c) => controller = c,
              ),
            ),
          );

          // Run forward leg for 300ms
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(controller!.status, equals(AnimationStatus.forward));
          final midForwardVal = controller!.value;
          expect(midForwardVal, greaterThan(0.1));

          // Pause while moving forward
          coordinator.setFocused(false);
          await tester.pump();
          expect(controller!.isAnimating, isFalse);
          final stoppedVal = controller!.value;

          // Advance time while paused: value remains constant
          await tester.pump(const Duration(milliseconds: 300));
          expect(controller!.value, equals(stoppedVal));

          // Resume: should continue forward from stoppedVal
          coordinator.setFocused(true);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          expect(controller!.value, greaterThan(stoppedVal));
        } finally {
          coordinator.dispose();
        }
      },
    );
  });

  group('MarqueeText Widget Tests', () {
    testWidgets('Marquee pauses gracefully when TickerMode is disabled', (
      tester,
    ) async {
      final coordinator = PowerCoordinator(autoAttachLifecycle: false);

      try {
        await tester.pumpWidget(
          ListenableBuilder(
            listenable: coordinator,
            builder: (context, _) {
              return MaterialApp(
                home: Scaffold(
                  body: SizedBox(
                    width: 50,
                    child: TickerMode(
                      enabled: coordinator.isUiAnimationEnabled,
                      child: const MarqueeText(
                        text:
                            'Very Long Hardware Test Text That Needs Scrolling',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Mute TickerMode
        coordinator.setFocused(false);
        await tester.pump();

        // Advancing time must not throw unhandled timer or ticker exceptions
        await tester.pump(const Duration(seconds: 2));

        // Unmute TickerMode
        coordinator.setFocused(true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Unmount cleanly
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        coordinator.dispose();
      }
    });
  });

  group('Background Business Task Isolation Tests', () {
    test(
      'Background periodic timer continues running even when UI animations are disabled',
      () async {
        final coordinator = PowerCoordinator(
          idleTimeout: const Duration(milliseconds: 20),
          autoAttachLifecycle: false,
        );
        addTearDown(coordinator.dispose);

        // Force UI animations disabled (idle or unfocused)
        coordinator.setFocused(false);
        expect(coordinator.isUiAnimationEnabled, isFalse);

        int backgroundTickCount = 0;
        final backgroundTimer = Timer.periodic(
          const Duration(milliseconds: 25),
          (_) {
            backgroundTickCount++;
          },
        );
        addTearDown(backgroundTimer.cancel);

        await Future.delayed(const Duration(milliseconds: 90));

        // Business timer must execute completely uninhibited
        expect(backgroundTickCount, greaterThanOrEqualTo(2));
      },
    );
  });
}

class _MutedTickerWidget extends StatefulWidget {
  final ValueChanged<AnimationController>? onController;

  const _MutedTickerWidget({this.onController});

  @override
  State<_MutedTickerWidget> createState() => _MutedTickerWidgetState();
}

class _MutedTickerWidgetState extends State<_MutedTickerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
    widget.onController?.call(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Text('${_controller.value}'),
    );
  }
}

class _PhaseTrackingWidget extends StatefulWidget {
  final PowerCoordinator coordinator;
  final ValueChanged<AnimationController>? onController;

  const _PhaseTrackingWidget({required this.coordinator, this.onController});

  @override
  State<_PhaseTrackingWidget> createState() => _PhaseTrackingWidgetState();
}

class _PhaseTrackingWidgetState extends State<_PhaseTrackingWidget>
    with TickerProviderStateMixin {
  late final AnimationController _pulseAnimController;
  bool _pulseWasForward = true;

  @override
  void initState() {
    super.initState();
    _pulseAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    widget.coordinator.addListener(_onPowerStateChanged);
    widget.onController?.call(_pulseAnimController);
    _syncAnimationState(widget.coordinator.isUiAnimationEnabled);
  }

  void _onPowerStateChanged() {
    if (!mounted) return;
    _syncAnimationState(widget.coordinator.isUiAnimationEnabled);
  }

  void _syncAnimationState(bool enabled) {
    if (enabled) {
      if (!_pulseAnimController.isAnimating) {
        if (_pulseWasForward) {
          _pulseAnimController
              .forward(from: _pulseAnimController.value)
              .whenCompleteOrCancel(() {
                if (widget.coordinator.isUiAnimationEnabled && mounted) {
                  _pulseAnimController.repeat(reverse: true);
                }
              });
        } else {
          _pulseAnimController
              .reverse(from: _pulseAnimController.value)
              .whenCompleteOrCancel(() {
                if (widget.coordinator.isUiAnimationEnabled && mounted) {
                  _pulseAnimController.repeat(reverse: true);
                }
              });
        }
      }
    } else {
      if (_pulseAnimController.isAnimating) {
        _pulseWasForward =
            (_pulseAnimController.status == AnimationStatus.forward);
        _pulseAnimController.stop(canceled: false);
      }
    }
  }

  @override
  void dispose() {
    widget.coordinator.removeListener(_onPowerStateChanged);
    _pulseAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimController,
      builder: (context, _) => Text('${_pulseAnimController.value}'),
    );
  }
}
