// lib/modules/services/power_coordinator.dart

import 'dart:async';
import 'package:flutter/widgets.dart';
import '../logger_config.dart';

/// Coordinates UI power-saving state across the desktop widget.
///
/// Distinguishes between:
/// - [isVisible]: Window is shown (not hidden/minimized).
/// - [isFocused]: Window has OS focus or is active.
/// - [isInteracting]: User is currently hovering, dragging, or tapping the widget.
/// - [isIdle]: Inactivity timeout elapsed without user interaction.
///
/// When [isUiAnimationEnabled] is false, UI tickers are muted via [TickerMode],
/// continuous animations are paused. Data updates can still request frames.
/// Background business tasks (AdbMonitor, OTA, hardware checks) are not paused.
class PowerCoordinator extends ChangeNotifier {
  final Duration idleTimeout;
  AppLifecycleListener? _lifecycleListener;

  bool _isVisible = true;
  bool _isFocused = true;
  bool _isInteracting = false;
  bool _isIdle = false;
  Timer? _idleTimer;
  bool _disposed = false;

  PowerCoordinator({
    this.idleTimeout = const Duration(seconds: 12),
    bool autoAttachLifecycle = true,
  }) {
    if (autoAttachLifecycle) {
      _initLifecycleListener();
    }
    _startIdleTimer();
  }

  bool get isVisible => _isVisible;
  bool get isFocused => _isFocused;
  bool get isInteracting => _isInteracting;
  bool get isIdle => _isIdle;

  /// Derived state: UI animations are active only when visible, focused or interacting, and not idle.
  bool get isUiAnimationEnabled =>
      _isVisible && (_isFocused || _isInteracting) && !_isIdle;

  void _initLifecycleListener() {
    try {
      _lifecycleListener = AppLifecycleListener(
        onShow: () => setVisible(true),
        onHide: () => setVisible(false),
        onResume: () {
          setVisible(true);
          setFocused(true);
          recordUserActivity();
        },
        onInactive: () => setFocused(false),
        onPause: () => setFocused(false),
        onDetach: () {
          setVisible(false);
          setFocused(false);
        },
        onStateChange: _handleLifecycleState,
      );
      // Registering a listener does not replay the current lifecycle state.
      final state = WidgetsBinding.instance.lifecycleState;
      if (state != null) _handleLifecycleState(state);
    } catch (e) {
      logger.warning(
        '[PowerCoordinator] Could not attach AppLifecycleListener: $e',
      );
    }
  }

  void _handleLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    switch (state) {
      case AppLifecycleState.resumed:
        setVisible(true);
        setFocused(true);
        recordUserActivity();
        break;
      case AppLifecycleState.inactive:
        setFocused(false);
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        setVisible(false);
        setFocused(false);
        break;
    }
  }

  void setVisible(bool visible) {
    if (_disposed || _isVisible == visible) return;
    _isVisible = visible;
    logger.fine('[PowerCoordinator] isVisible: $visible');
    if (visible) {
      _startIdleTimer();
    } else {
      _idleTimer?.cancel();
      // A hidden window may never receive MouseRegion.onExit or a blur event.
      _isInteracting = false;
      _isFocused = false;
    }
    notifyListeners();
  }

  void setFocused(bool focused) {
    if (_disposed || _isFocused == focused) return;
    _isFocused = focused;
    logger.fine('[PowerCoordinator] isFocused: $focused');
    if (focused) {
      recordUserActivity();
    }
    _notifyIfStateChanged();
  }

  void setHovered(bool hovered) {
    if (_disposed || (!_isVisible && hovered)) return;
    if (_isInteracting != hovered) {
      _isInteracting = hovered;
      logger.fine('[PowerCoordinator] isInteracting (hover): $hovered');
      if (hovered) {
        recordUserActivity();
      } else {
        _startIdleTimer();
      }
      _notifyIfStateChanged();
    }
  }

  /// Records user activity (mouse move, tap, drag, scroll).
  /// Resets the idle countdown and wakes up UI from idle sleep.
  void recordUserActivity() {
    if (_disposed) return;
    _idleTimer?.cancel();
    final wasIdle = _isIdle;
    _isIdle = false;

    _startIdleTimer();

    if (wasIdle) {
      logger.fine('[PowerCoordinator] Woke from idle sleep via user activity.');
      notifyListeners();
    }
  }

  void _startIdleTimer() {
    _idleTimer?.cancel();
    if (_disposed || !_isVisible) return;

    _idleTimer = Timer(idleTimeout, () {
      if (_disposed || _isInteracting) return;
      if (!_isIdle) {
        _isIdle = true;
        logger.fine(
          '[PowerCoordinator] Inactivity threshold (${idleTimeout.inSeconds}s) reached -> Idle sleep.',
        );
        notifyListeners();
      }
    });
  }

  void _notifyIfStateChanged() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _idleTimer?.cancel();
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    super.dispose();
  }
}
