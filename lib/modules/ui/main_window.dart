// lib/modules/ui/main_window.dart

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../logic.dart';
import 'styles.dart';
import 'bubble_hover_region.dart';

class MainWindow extends StatefulWidget {
  const MainWindow({super.key});

  @override
  State<MainWindow> createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow> with TickerProviderStateMixin {
  static const _windowChannel = MethodChannel('ja_route/window');

  late final AnimationController _sproutAnimController;
  late final AnimationController _pulseAnimController;
  late final AnimationController _stationAnimController;

  bool _isExpanded = true;
  bool _bubbleHovered = false;
  String? _hoveredKey;
  String _toastMessage = '';
  bool _showToast = false;
  bool _isMenuOpen = false;
  String _lastSentHitRectsKey = '';

  // Dynamic 4-corner auto-detection & QQ Guardian edge docking state
  bool _autoCornerMode = true;
  bool _isRight =
      true; // true: bubble on Right (cards on Left); false: bubble on Left (cards on Right)
  bool _isBottom =
      true; // true: bubble on Bottom (cards Above); false: bubble on Top (cards Below)
  bool _isDockedLeft = false;
  bool _isDockedRight = true;
  String _currentCorner = 'BR';

  void _closeApp() {
    exit(0);
  }

  void _copyToClipboard(String field, String value) {
    if (value != 'N/A' && value.isNotEmpty && !value.contains('Đang')) {
      Clipboard.setData(ClipboardData(text: value));
      final monitor = Provider.of<AdbMonitor>(context, listen: false);
      monitor.updateStatus('Copied $field: $value', true);
      _triggerToast('Đã sao chép $field!');
    }
  }

  void _triggerToast(String msg) {
    setState(() {
      _toastMessage = msg;
      _showToast = true;
    });
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() => _showToast = false);
      }
    });
  }

  void _updateNativeHitTestRects({
    required Rect bubbleHoverRect,
    required double targetCardsLeft,
    required double startY,
    required double cardWidth,
    required int cardCount,
    Rect? wireStationHitRect,
  }) {
    if (!Platform.isWindows) return;

    final List<Map<String, double>> rects = [];

    if (_isMenuOpen) {
      // When context menu is open, capture all input so user can interact and click outside to dismiss
      rects.add({'x': 0.0, 'y': 0.0, 'w': 440.0, 'h': 335.0});
    } else {
      rects.add({
        'x': bubbleHoverRect.left,
        'y': bubbleHoverRect.top,
        'w': bubbleHoverRect.width,
        'h': bubbleHoverRect.height,
      });

      // Keep the gaps and the hidden cards transparent to mouse input.
      if (_isExpanded && _sproutAnimController.value > 0.01) {
        for (var i = 0; i < cardCount; i++) {
          rects.add({
            'x': targetCardsLeft,
            'y': startY + i * 36.0,
            'w': cardWidth,
            'h': 30.0,
          });
        }
      }

      // Wire Station Badge Hit Rect (when docked at screen edge)
      if (wireStationHitRect != null) {
        rects.add({
          'x': wireStationHitRect.left,
          'y': wireStationHitRect.top,
          'w': wireStationHitRect.width,
          'h': wireStationHitRect.height,
        });
      }

      // 3. Toast Notification Hit Rect (if showing)
      if (_showToast) {
        rects.add({
          'x': 6.0,
          'y': _isBottom ? 6.0 : 286.0,
          'w': 240.0,
          'h': 40.0,
        });
      }
    }

    final key = rects.toString();
    if (key == _lastSentHitRectsKey) return;
    _lastSentHitRectsKey = key;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _windowChannel.invokeMethod('setHitTestRects', rects);
    });
  }

  void _startDrag() {
    if (Platform.isWindows) {
      _windowChannel.invokeMethod('startDrag');
    }
  }

  void _fetchWindowPosition() async {
    if (!Platform.isWindows) return;
    try {
      final res = await _windowChannel.invokeMethod('getPosition');
      if (res is Map) {
        _applyPositionMap(Map<dynamic, dynamic>.from(res));
      }
    } catch (_) {}
  }

  void _applyPositionMap(Map<dynamic, dynamic> map) {
    final isDockedLeft = map['isDockedLeft'] as bool? ?? false;
    final isDockedRight = map['isDockedRight'] as bool? ?? true;

    if (!_autoCornerMode) {
      if (isDockedLeft != _isDockedLeft || isDockedRight != _isDockedRight) {
        setState(() {
          _isDockedLeft = isDockedLeft;
          _isDockedRight = isDockedRight;
        });
      }
      return;
    }

    final isRight = map['isRight'] as bool? ?? true;
    final isBottom = map['isBottom'] as bool? ?? true;
    final corner = map['corner'] as String? ?? 'BR';

    if (isRight != _isRight ||
        isBottom != _isBottom ||
        corner != _currentCorner ||
        isDockedLeft != _isDockedLeft ||
        isDockedRight != _isDockedRight) {
      setState(() {
        _isRight = isRight;
        _isBottom = isBottom;
        _isDockedLeft = isDockedLeft;
        _isDockedRight = isDockedRight;
        _currentCorner = corner;
      });
      _triggerToast(
        'Vị trí: ${isBottom ? "Dưới (Thẻ bám Taskbar)" : "Trên (Thẻ bám Mép Trên)"} - Dây bên ${isRight ? "Phải" : "Trái"}',
      );
    }
  }

  void _setManualCorner(String corner) {
    setState(() {
      _currentCorner = corner;
      if (corner == 'BR') {
        _isRight = true;
        _isBottom = true;
        _autoCornerMode = false;
      } else if (corner == 'BL') {
        _isRight = false;
        _isBottom = true;
        _autoCornerMode = false;
      } else if (corner == 'TR') {
        _isRight = true;
        _isBottom = false;
        _autoCornerMode = false;
      } else if (corner == 'TL') {
        _isRight = false;
        _isBottom = false;
        _autoCornerMode = false;
      } else if (corner == 'AUTO') {
        _autoCornerMode = true;
        _fetchWindowPosition();
      }
    });
    _triggerToast(
      _autoCornerMode
          ? 'Đã bật Tự Động Nhận Dạng Góc'
          : 'Đã cố định Góc $_currentCorner',
    );
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _sproutAnimController.forward();
      } else {
        _sproutAnimController.reverse();
      }
    });
  }

  void _showContextMenu(BuildContext context, TapDownDetails details) {
    setState(() => _isMenuOpen = true);
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final monitor = Provider.of<AdbMonitor>(context, listen: false);

    final position = RelativeRect.fromRect(
      details.globalPosition & const Size(40, 40),
      Offset.zero & MediaQuery.of(context).size,
    );

    showMenu<String>(
      context: context,
      position: position,
      color: theme.isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.isDark ? Colors.white24 : Colors.black12),
      ),
      items: [
        PopupMenuItem<String>(
          value: 'theme',
          height: 36,
          child: Row(
            children: [
              Icon(
                theme.isDark ? Icons.light_mode : Icons.dark_mode,
                size: 16,
                color: theme.isDark ? Colors.amber : const Color(0xFF0F172A),
              ),
              const SizedBox(width: 8),
              Text(
                theme.isDark ? 'Giao diện Sáng' : 'Giao diện Tối',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'Outfit',
                  color: theme.isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
        // Corner Selection Submenu
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'corner_auto',
          height: 32,
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 15,
                color: _autoCornerMode ? const Color(0xFF10B981) : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                'Tự động nhận dạng góc${_autoCornerMode ? " (Bật)" : ""}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: _autoCornerMode
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: _autoCornerMode
                      ? const Color(0xFF10B981)
                      : (theme.isDark ? Colors.white70 : Colors.black87),
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'corner_br',
          height: 30,
          child: Text(
            '↘️ Góc Dưới - Phải (Thẻ bám Taskbar, Dây bên Phải)',
            style: TextStyle(
              fontSize: 11,
              color: theme.isDark ? Colors.white70 : Colors.black87,
              fontFamily: 'Outfit',
            ),
          ),
        ),
        PopupMenuItem<String>(
          value: 'corner_bl',
          height: 30,
          child: Text(
            '↙️ Góc Dưới - Trái (Thẻ bám Taskbar, Dây bên Trái)',
            style: TextStyle(
              fontSize: 11,
              color: theme.isDark ? Colors.white70 : Colors.black87,
              fontFamily: 'Outfit',
            ),
          ),
        ),
        PopupMenuItem<String>(
          value: 'corner_tr',
          height: 30,
          child: Text(
            '↗️ Góc Trên - Phải (Thẻ bám Mép Trên, Dây bên Phải)',
            style: TextStyle(
              fontSize: 11,
              color: theme.isDark ? Colors.white70 : Colors.black87,
              fontFamily: 'Outfit',
            ),
          ),
        ),
        PopupMenuItem<String>(
          value: 'corner_tl',
          height: 30,
          child: Text(
            '↖️ Góc Trên - Trái (Thẻ bám Mép Trên, Dây bên Trái)',
            style: TextStyle(
              fontSize: 11,
              color: theme.isDark ? Colors.white70 : Colors.black87,
              fontFamily: 'Outfit',
            ),
          ),
        ),
        const PopupMenuDivider(height: 1),
        if (monitor.allDuts.length > 1)
          PopupMenuItem<String>(
            value: 'switch_dut',
            height: 36,
            child: Row(
              children: [
                const Icon(
                  Icons.swap_horiz,
                  size: 16,
                  color: Color(0xFF00ADB5),
                ),
                const SizedBox(width: 8),
                Text(
                  'Đổi DUT (${monitor.allDuts.indexOf(monitor.currentDut) + 1}/${monitor.allDuts.length})',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Outfit',
                    color: theme.isDark
                        ? Colors.white
                        : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        PopupMenuItem<String>(
          value: 'close',
          height: 36,
          child: const Row(
            children: [
              Icon(Icons.close, size: 16, color: Color(0xFFEF4444)),
              SizedBox(width: 8),
              Text(
                'Đóng ứng dụng',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'Outfit',
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (mounted) {
        setState(() => _isMenuOpen = false);
      }
      if (value == 'theme') {
        theme.toggleTheme();
      } else if (value == 'corner_auto') {
        _setManualCorner('AUTO');
      } else if (value == 'corner_br') {
        _setManualCorner('BR');
      } else if (value == 'corner_bl') {
        _setManualCorner('BL');
      } else if (value == 'corner_tr') {
        _setManualCorner('TR');
      } else if (value == 'corner_tl') {
        _setManualCorner('TL');
      } else if (value == 'switch_dut') {
        if (monitor.allDuts.length > 1) {
          final nextIdx =
              (monitor.allDuts.indexOf(monitor.currentDut) + 1) %
              monitor.allDuts.length;
          monitor.selectDut(monitor.allDuts[nextIdx]);
        }
      } else if (value == 'close') {
        _closeApp();
      }
    });
  }

  @override
  void initState() {
    super.initState();

    _sproutAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _sproutAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        setState(() {});
      }
    });

    _pulseAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _stationAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    // Listen to MethodChannel messages from C++ Win32 runner
    _windowChannel.setMethodCallHandler((call) async {
      if (call.method == 'onPositionChanged') {
        if (call.arguments is Map) {
          _applyPositionMap(Map<dynamic, dynamic>.from(call.arguments as Map));
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final themeProvider = Provider.of<ThemeProvider>(
          context,
          listen: false,
        );
        const platform = MethodChannel('ja_route/theme');
        try {
          platform.invokeMethod('updateTheme', themeProvider.isDark);
        } catch (_) {}
        _fetchWindowPosition();
      }
    });
  }

  @override
  void dispose() {
    _sproutAnimController.dispose();
    _pulseAnimController.dispose();
    _stationAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final monitor = Provider.of<AdbMonitor>(context);

    // Auto-trigger sprout / retract
    if (monitor.deviceConnected &&
        !_sproutAnimController.isCompleted &&
        !_sproutAnimController.isAnimating) {
      if (_isExpanded) {
        _sproutAnimController.forward();
      }
    } else if (!monitor.deviceConnected &&
        _sproutAnimController.value > 0 &&
        !_sproutAnimController.isAnimating) {
      _sproutAnimController.reverse();
    }

    String modelName = 'DUT';
    String subLabel = 'WAIT ADB';
    Gradient bubbleGradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF334155), Color(0xFF1E293B)],
    );

    if (monitor.deviceConnected) {
      final pcasn = monitor.info['PCASN'] ?? '';
      if (monitor.overlayText == 'IQ5' ||
          pcasn.toUpperCase().startsWith('QB95')) {
        modelName = 'IQ5';
        subLabel = 'DUT READY';
        bubbleGradient = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00B4DB), Color(0xFF0083B0), Color(0xFF0052D4)],
        );
      } else if (monitor.overlayText == 'IQ4' ||
          pcasn.toUpperCase().startsWith('QB94')) {
        modelName = 'IQ4';
        subLabel = 'DUT READY';
        bubbleGradient = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0), Color(0xFF1F1C2C)],
        );
      } else if (monitor.showOverlay && monitor.overlayText == 'LOADING') {
        modelName = '⏳';
        subLabel = 'READING';
        bubbleGradient = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD97706), Color(0xFFB45309)],
        );
      } else {
        modelName = 'DUT';
        subLabel = 'ONLINE';
        bubbleGradient = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0084FF), Color(0xFF00C6FF)],
        );
      }
    }

    const keys = ['PCASN', 'SYSSN', 'SYSPN', 'LCMPN', 'IMEI', 'CPU'];
    const cardHeight = 30.0;
    const cardGap = 6.0;
    const cardWidth = 286.0;
    const bubbleSize = 66.0;

    // -----------------------------------------------------------------------
    // QQ GUARDIAN EDGE DOCKING MECHANICS (80% TUCKED & SNUG CARDS):
    // When the window is pushed against the monitor edge:
    // 1. If not hovering: the sphere tucks 80% deep into the screen edge,
    //    leaving a sleek glowing ~13px crescent tab with pulsing LED.
    // 2. The cards also smoothly slide snug & close against the screen edge!
    // 3. When hovered: the sphere springs out into full view and cards slide
    //    to provide ample room for grabbing/dragging.
    // -----------------------------------------------------------------------
    final bool isInteracting = _bubbleHovered || _hoveredKey != null;

    final bool isDockedCurrentSide = _isRight ? _isDockedRight : _isDockedLeft;

    // -----------------------------------------------------------------------
    // CORNER DYNAMICS (Bám sát Taskbar khi ở dưới & Bám sát Mép trên khi ở trên):
    // - Khi ở GÓC DƯỚI (_isBottom == true):
    //   Khối tròn ở TRÊN (top: 10.0), các thẻ ở DƯỚI bám sát ngay trên Taskbar
    //   startY = 115.0 -> đáy thẻ CPU tại Y = 325.0 (cách đáy cửa sổ 10px bám sát Taskbar).
    // - Khi ở GÓC TRÊN (_isBottom == false):
    //   Các thẻ ở TRÊN bám sát mép trên màn hình (startY = 10.0 -> Y = 10.0..220.0),
    //   Khối tròn chuyển xuống DƯỚI các thẻ (actualBubbleTop = 256.0, Column top = 232 / 256).
    // -----------------------------------------------------------------------
    final double normalBubbleLeft = _isRight ? 354.0 : 20.0;
    // 80% tucked into screen edge: 66 * 0.80 = 52.8px hidden, ~13px visible tab
    final double tuckedBubbleLeft = _isRight ? 427.0 : -53.0;

    final double targetBubbleLeft = (isDockedCurrentSide && !isInteracting)
        ? tuckedBubbleLeft
        : normalBubbleLeft;

    // Cards position: perfectly aligned directly under/above the bubble
    final double normalCardsLeft = _isRight ? 134.0 : 20.0;
    final double targetCardsLeft = normalCardsLeft;

    // Check if Station is available
    final bool hasStation =
        monitor.deviceConnected && monitor.stationResult != 'N/A';

    // Standard bubble station pill appears when NOT docked or when hovered/interacting
    final bool hasStationPill =
        hasStation && (!isDockedCurrentSide || isInteracting);

    // Docked wire station badge appears when docked at screen edge and NOT hovering
    final bool hasDockedWireStation =
        hasStation && isDockedCurrentSide && !isInteracting;

    final double startY = _isBottom ? 115.0 : 10.0;

    final double bubbleTop = _isBottom
        ? 10.0
        : (hasStationPill ? 232.0 : 256.0);

    final double actualBubbleTop = _isBottom ? 10.0 : 256.0;

    // Anchor point on the bubble for wires (stretches dynamically as bubble moves):
    // When _isBottom: anchor is at bottom center of bubble (Y = 76.0)
    // When !_isBottom: anchor is at TOP center of bubble (Y = 256.0)
    final Offset bubbleAnchor = (isDockedCurrentSide && !isInteracting)
        ? Offset(_isRight ? 427.0 : 13.0, actualBubbleTop + bubbleSize / 2)
        : Offset(
            targetBubbleLeft + bubbleSize / 2,
            _isBottom ? (actualBubbleTop + bubbleSize) : actualBubbleTop,
          );

    final double verticalWireX = _isRight
        ? (targetCardsLeft + cardWidth - 33.0)
        : (targetCardsLeft + 33.0);

    // Target point on each card (cards stay fixed & 100% inside screen):
    final double cardWireTargetX = verticalWireX;

    final cardCenterYs = List.generate(
      keys.length,
      (i) => startY + i * (cardHeight + cardGap) + cardHeight / 2,
    );

    final bubbleHoverRect = bubbleInteractionRect(
      isRight: _isRight,
      isBottom: _isBottom,
      isDocked: isDockedCurrentSide,
    );

    final targetCardY = _isBottom ? cardCenterYs.first : cardCenterYs.last;
    final dockedStationGeom = computeLeadInWireStationGeometry(
      bubbleAnchor: bubbleAnchor,
      wireX: verticalWireX,
      cardY: targetCardY,
      isBottom: _isBottom,
    );

    final wireStationHitRect = hasDockedWireStation
        ? Rect.fromCenter(
            center: dockedStationGeom.position,
            width: 70.0,
            height: 28.0,
          )
        : null;

    _updateNativeHitTestRects(
      bubbleHoverRect: bubbleHoverRect,
      targetCardsLeft: targetCardsLeft,
      startY: startY,
      cardWidth: cardWidth,
      cardCount: keys.length,
      wireStationHitRect: wireStationHitRect,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox(
        width: 440,
        height: 335,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. Dynamic Bézier Leader Wires with Dedicated RepaintBoundary
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _sproutAnimController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _WirePainter(
                        bubbleAnchor: bubbleAnchor,
                        cardTargetX: cardWireTargetX,
                        cardCenterYs: cardCenterYs,
                        growthProgress: _sproutAnimController.value,
                        hoveredIndex: _hoveredKey != null
                            ? keys.indexOf(_hoveredKey!)
                            : null,
                        isDark: theme.isDark,
                        isRight: _isRight,
                        isBottom: _isBottom,
                        verticalWireX: verticalWireX,
                      ),
                    );
                  },
                ),
              ),
            ),

            // 2. Vertical Stacking Frosted Glass Cards (Smooth Animation & Snug Edge Alignment)
            ...keys.asMap().entries.map((entry) {
              final idx = entry.key;
              final key = entry.value;
              final val = monitor.info[key] ?? 'N/A';
              final isWarning =
                  key == 'LCMPN' && val.contains('không được chạy lại');

              return AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: targetCardsLeft,
                top: startY + idx * (cardHeight + cardGap),
                width: cardWidth,
                height: cardHeight,
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _sproutAnimController,
                    builder: (context, child) {
                      final itemDelay = idx * 0.07;
                      final animVal =
                          ((_sproutAnimController.value - itemDelay) /
                                  (1.0 - itemDelay))
                              .clamp(0.0, 1.0);
                      final curvedVal = Curves.easeOutCubic.transform(animVal);

                      if (curvedVal <= 0.01) {
                        return const SizedBox.shrink();
                      }

                      // Slide direction adapts to corner orientation
                      final slideOffsetX = _isRight
                          ? (35.0 * (1.0 - curvedVal))
                          : (-35.0 * (1.0 - curvedVal));

                      return Opacity(
                        opacity: curvedVal,
                        child: Transform.translate(
                          offset: Offset(slideOffsetX, 0),
                          child: child,
                        ),
                      );
                    },
                    child: MouseRegion(
                      onEnter: (_) => setState(() => _hoveredKey = key),
                      onExit: (_) => setState(() => _hoveredKey = null),
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => _copyToClipboard(key, val),
                        child: _InfoCard(
                          fieldKey: key,
                          value: val,
                          isDark: theme.isDark,
                          isWarning: isWarning,
                          modelName: modelName,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),

            // 2.5. Docked Wire Station Badge (Tilted along Bézier lead-in curve)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              left: dockedStationGeom.position.dx,
              top: dockedStationGeom.position.dy,
              child: FractionalTranslation(
                translation: const Offset(-0.5, -0.5),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  opacity: hasDockedWireStation ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !hasDockedWireStation,
                    child: _WireStationBadge(
                      stationText: monitor.stationResult,
                      angle: dockedStationGeom.angle,
                      isDark: theme.isDark,
                      onTap: () =>
                          _copyToClipboard('STATION', monitor.stationResult),
                    ),
                  ),
                ),
              ),
            ),

            // 3. Floating Messenger Chathead Bubble with QQ Guardian Edge Docking
            AnimatedPositioned(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              left: targetBubbleLeft,
              top: bubbleTop,
              child: RepaintBoundary(
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // If window is at top corner (bubble below cards), Station Pill appears above the bubble
                      if (!_isBottom &&
                          hasStationPill &&
                          (!isDockedCurrentSide || _bubbleHovered))
                        _StationPill(
                          stationText: monitor.stationResult,
                          animation: _stationAnimController,
                          isBottom: true,
                        ),

                      // Main Circular Chathead Bubble (Pops out when hovered at edge)
                      GestureDetector(
                        onTap: _toggleExpand,
                        onPanStart: (_) => _startDrag(),
                        onSecondaryTapDown: (details) =>
                            _showContextMenu(context, details),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: bubbleSize,
                              height: bubbleSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: bubbleGradient,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    blurRadius: 18,
                                    offset: const Offset(0, 6),
                                  ),
                                  BoxShadow(
                                    color:
                                        (modelName == 'IQ5'
                                                ? const Color(0xFF00ADB5)
                                                : (modelName == 'IQ4'
                                                      ? const Color(0xFF8E2DE2)
                                                      : const Color(
                                                          0xFF0084FF,
                                                        )))
                                            .withValues(
                                              alpha: monitor.deviceConnected
                                                  ? 0.55
                                                  : 0.0,
                                            ),
                                    blurRadius: 18,
                                    spreadRadius: 1,
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  width: 1.8,
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Glass top gloss highlight
                                  Positioned(
                                    top: 2,
                                    left: 10,
                                    right: 10,
                                    height: 16,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.white.withValues(
                                              alpha: 0.45,
                                            ),
                                            Colors.white.withValues(alpha: 0.0),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Content Column
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        modelName,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          fontFamily: 'Outfit',
                                          color: Colors.white,
                                          height: 1.0,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black54,
                                              blurRadius: 6,
                                              offset: Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        subLabel,
                                        style: TextStyle(
                                          fontSize: 7.5,
                                          fontWeight: FontWeight.w800,
                                          fontFamily: 'Outfit',
                                          color: Colors.white.withValues(
                                            alpha: 0.9,
                                          ),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Isolated Live Pulse Status Dot (Always centered on visible side of tucked sphere)
                            Positioned(
                              right: _isRight ? null : 1,
                              left: _isRight ? 1 : null,
                              top: 26,
                              child: _PulseStatusDot(
                                isConnected: monitor.deviceConnected,
                                pulseAnimation: _pulseAnimController,
                              ),
                            ),

                            // Mini Close Button on Hover
                            if (_bubbleHovered)
                              Positioned(
                                top: -4,
                                right: _isRight ? -4 : null,
                                left: _isRight ? null : -4,
                                child: GestureDetector(
                                  onTap: _closeApp,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFEF4444),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.close,
                                      size: 10,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // If window is at bottom corner (bubble above cards), Station Pill appears below the bubble
                      if (_isBottom &&
                          hasStationPill &&
                          (!isDockedCurrentSide || _bubbleHovered))
                        _StationPill(
                          stationText: monitor.stationResult,
                          animation: _stationAnimController,
                          isBottom: false,
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // This region stays still while the bubble animates underneath it.
            Positioned.fromRect(
              rect: bubbleHoverRect,
              child: BubbleHoverRegion(
                onChanged: (hovered) {
                  if (_bubbleHovered != hovered) {
                    setState(() => _bubbleHovered = hovered);
                  }
                },
              ),
            ),

            // Toast Notification
            if (_showToast)
              Positioned(
                top: _isBottom ? 10 : null,
                bottom: _isBottom ? null : 10,
                left: 10,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF10B981),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 12,
                            color: Color(0xFF10B981),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _toastMessage,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Isolated Station Pill Widget
// ---------------------------------------------------------------------------
class _StationPill extends StatelessWidget {
  final String stationText;
  final Animation<double> animation;
  final bool isBottom;

  const _StationPill({
    required this.stationText,
    required this.animation,
    this.isBottom = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (isBottom ? -3.0 : 3.0) * animation.value),
          child: child,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            margin: EdgeInsets.only(
              bottom: isBottom ? 4 : 0,
              top: isBottom ? 0 : 4,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFF00ADB5).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00ADB5).withValues(alpha: 0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              stationText,
              style: const TextStyle(
                fontSize: 9.5,
                fontFamily: 'JetBrains Mono',
                fontWeight: FontWeight.w800,
                color: Color(0xFF042F2E),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tilted Wire Station Badge Widget (Docked Edge Mode)
// ---------------------------------------------------------------------------
class _WireStationBadge extends StatelessWidget {
  final String stationText;
  final double angle;
  final bool isDark;
  final VoidCallback? onTap;

  const _WireStationBadge({
    required this.stationText,
    required this.angle,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F172A).withValues(alpha: 0.94)
                  : Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF38BDF8).withValues(alpha: 0.9)
                    : const Color(0xFF0084FF).withValues(alpha: 0.8),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isDark
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFF0084FF))
                      .withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: (isDark ? Colors.black : Colors.white)
                      .withValues(alpha: 0.6),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Text(
              stationText,
              style: TextStyle(
                fontSize: 10.0,
                fontFamily: 'JetBrains Mono',
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: isDark
                    ? const Color(0xFF38BDF8)
                    : const Color(0xFF0084FF),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Isolated Live Pulse Status Dot Widget
// ---------------------------------------------------------------------------
class _PulseStatusDot extends StatelessWidget {
  final bool isConnected;
  final Animation<double> pulseAnimation;

  const _PulseStatusDot({
    required this.isConnected,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isConnected
        ? const Color(0xFF10B981)
        : const Color(0xFF64748B);

    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (context, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            if (isConnected)
              Container(
                width: 14 + 6 * pulseAnimation.value,
                height: 14 + 6 * pulseAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withValues(
                    alpha: 0.5 * (1.0 - pulseAnimation.value),
                  ),
                ),
              ),
            Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
                border: Border.all(color: const Color(0xFF0F172A), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.8),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// High Performance Dynamic Leader Wires Painter (Bézier Arches & Vertical Spine)
// ---------------------------------------------------------------------------
class _WirePainter extends CustomPainter {
  final Offset bubbleAnchor;
  final double cardTargetX;
  final List<double> cardCenterYs;
  final double growthProgress;
  final int? hoveredIndex;
  final bool isDark;
  final bool isRight;
  final bool isBottom;
  final double? verticalWireX;

  static final Paint _wirePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static final Paint _dotPaint = Paint()..style = PaintingStyle.fill;

  const _WirePainter({
    required this.bubbleAnchor,
    required this.cardTargetX,
    required this.cardCenterYs,
    required this.growthProgress,
    required this.hoveredIndex,
    required this.isDark,
    required this.isRight,
    this.isBottom = true,
    this.verticalWireX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (growthProgress <= 0.005) return;

    final baseWireColor = isDark
        ? const Color(0xFF38BDF8)
        : const Color(0xFF0084FF);

    // -------------------------------------------------------------------------
    // VERTICAL SPINE WIRE LAYOUT FOR ALL CORNERS (BL, BR, TL, TR)
    // - GÓC DƯỚI (BL, BR): Khối tròn ở trên, các thẻ ở dưới bám sát Taskbar.
    //   Sống dây chạy thẳng đứng từ khối tròn xuống các thẻ.
    // - GÓC TRÊN (TL, TR): Các thẻ ở trên bám sát mép trên, khối tròn ở dưới.
    //   Sống dây chạy thẳng đứng từ khối tròn vươn ngược lên các thẻ.
    // -------------------------------------------------------------------------
    if (verticalWireX != null && cardCenterYs.isNotEmpty) {
      final wireX = verticalWireX!;
      final firstCardY = cardCenterYs.first;
      final lastCardY = cardCenterYs.last;

      if (isBottom) {
        // --- GÓC DƯỚI (BL, BR): Khối tròn ở trên, các thẻ ở dưới bám sát Taskbar ---
        final totalDist = (lastCardY - bubbleAnchor.dy).clamp(10.0, 500.0);
        final currentReachY = bubbleAnchor.dy + totalDist * growthProgress;

        // 1. Lead-in wire từ khối tròn xuống thẻ đầu tiên (firstCardY)
        final double leadInEndY = firstCardY.clamp(
          bubbleAnchor.dy,
          currentReachY,
        );
        final leadInPath = Path()..moveTo(bubbleAnchor.dx, bubbleAnchor.dy);

        final isLeadInStraight = (bubbleAnchor.dx - wireX).abs() < 1.0;
        if (isLeadInStraight) {
          leadInPath.lineTo(wireX, leadInEndY);
        } else {
          // Khi docking nép mép màn hình: đường cong S uốn lượn mượt mà nối vào sống dây thẳng
          final cp1 = Offset(
            bubbleAnchor.dx + (wireX - bubbleAnchor.dx) * 0.45,
            bubbleAnchor.dy,
          );
          final cp2 = Offset(wireX, leadInEndY - 15.0);
          leadInPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, wireX, leadInEndY);
        }

        _wirePaint
          ..color = (hoveredIndex != null)
              ? baseWireColor.withValues(alpha: 0.95)
              : baseWireColor.withValues(alpha: 0.65 * growthProgress)
          ..strokeWidth = (hoveredIndex != null) ? 2.4 : 2.0;
        canvas.drawPath(leadInPath, _wirePaint);

        // 2. Sống dây thẳng đứng xuyên qua các thẻ dọc xuống currentReachY
        if (currentReachY > firstCardY) {
          final spinePath = Path()
            ..moveTo(wireX, firstCardY)
            ..lineTo(wireX, currentReachY.clamp(firstCardY, lastCardY));

          canvas.drawPath(spinePath, _wirePaint);
        }

        // 3. Các mắt nối (junction terminals) tại tâm từng thẻ
        for (int i = 0; i < cardCenterYs.length; i++) {
          final nodeY = cardCenterYs[i];
          if (nodeY > currentReachY) continue;

          final isHovered = (hoveredIndex == i);
          if (isHovered) {
            // Hiệu ứng vầng hào quang neon khi hover
            _dotPaint.color = baseWireColor.withValues(alpha: 0.45);
            canvas.drawCircle(Offset(wireX, nodeY), 6.5, _dotPaint);

            // Đoạn dây sáng rực nối thẻ
            final segY1 = (i == 0) ? bubbleAnchor.dy : cardCenterYs[i - 1];
            final segY2 = (i == cardCenterYs.length - 1)
                ? nodeY
                : cardCenterYs[i + 1];
            final highlightPaint = Paint()
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..strokeWidth = 3.2
              ..color = isDark
                  ? const Color(0xFF67E8F9)
                  : const Color(0xFF38BDF8);

            if (i == 0 && (bubbleAnchor.dx - wireX).abs() >= 1.0) {
              canvas.drawPath(leadInPath, highlightPaint);
              if (cardCenterYs.length > 1) {
                canvas.drawLine(
                  Offset(wireX, nodeY),
                  Offset(wireX, cardCenterYs[1]),
                  highlightPaint,
                );
              }
            } else {
              canvas.drawLine(
                Offset(wireX, segY1),
                Offset(wireX, segY2),
                highlightPaint,
              );
            }
          }

          // Chấm terminal mắt dây
          _dotPaint.color = isHovered ? Colors.white : baseWireColor;
          canvas.drawCircle(
            Offset(wireX, nodeY),
            isHovered ? 4.0 : 2.5,
            _dotPaint,
          );
        }

        // 4. Chấm neo tại khối tròn
        _dotPaint.color = baseWireColor;
        canvas.drawCircle(bubbleAnchor, 3.5, _dotPaint);
        return;
      } else {
        // --- GÓC TRÊN (TL, TR): Các thẻ ở trên bám mép trên, khối tròn chuyển xuống dưới ---
        final totalDist = (bubbleAnchor.dy - firstCardY).clamp(10.0, 500.0);
        // Dây vươn ngược lên trên từ bubbleAnchor (Y ~256) lên thẻ 0 (Y ~25)
        final currentReachY = bubbleAnchor.dy - totalDist * growthProgress;

        // 1. Lead-in wire từ khối tròn lên thẻ dưới cùng gần nó nhất (lastCardY)
        final double leadInEndY = lastCardY.clamp(
          currentReachY,
          bubbleAnchor.dy,
        );
        final leadInPath = Path()..moveTo(bubbleAnchor.dx, bubbleAnchor.dy);

        final isLeadInStraight = (bubbleAnchor.dx - wireX).abs() < 1.0;
        if (isLeadInStraight) {
          leadInPath.lineTo(wireX, leadInEndY);
        } else {
          // Khi docking nép mép màn hình: đường cong S uốn lượn mượt mà nối vào sống dây thẳng
          final cp1 = Offset(
            bubbleAnchor.dx + (wireX - bubbleAnchor.dx) * 0.45,
            bubbleAnchor.dy,
          );
          final cp2 = Offset(wireX, leadInEndY + 15.0);
          leadInPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, wireX, leadInEndY);
        }

        _wirePaint
          ..color = (hoveredIndex != null)
              ? baseWireColor.withValues(alpha: 0.95)
              : baseWireColor.withValues(alpha: 0.65 * growthProgress)
          ..strokeWidth = (hoveredIndex != null) ? 2.4 : 2.0;
        canvas.drawPath(leadInPath, _wirePaint);

        // 2. Sống dây thẳng đứng vươn ngược lên trên qua các thẻ
        if (currentReachY < lastCardY) {
          final spinePath = Path()
            ..moveTo(wireX, lastCardY)
            ..lineTo(wireX, currentReachY.clamp(firstCardY, lastCardY));

          canvas.drawPath(spinePath, _wirePaint);
        }

        // 3. Các mắt nối (junction terminals) tại tâm từng thẻ
        for (int i = 0; i < cardCenterYs.length; i++) {
          final nodeY = cardCenterYs[i];
          if (nodeY < currentReachY) continue;

          final isHovered = (hoveredIndex == i);
          if (isHovered) {
            // Hiệu ứng vầng hào quang neon khi hover
            _dotPaint.color = baseWireColor.withValues(alpha: 0.45);
            canvas.drawCircle(Offset(wireX, nodeY), 6.5, _dotPaint);

            // Đoạn dây sáng rực nối thẻ
            final segY1 = (i == 0) ? nodeY : cardCenterYs[i - 1];
            final segY2 = (i == cardCenterYs.length - 1)
                ? bubbleAnchor.dy
                : cardCenterYs[i + 1];
            final highlightPaint = Paint()
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..strokeWidth = 3.2
              ..color = isDark
                  ? const Color(0xFF67E8F9)
                  : const Color(0xFF38BDF8);

            if (i == cardCenterYs.length - 1 &&
                (bubbleAnchor.dx - wireX).abs() >= 1.0) {
              canvas.drawPath(leadInPath, highlightPaint);
              if (cardCenterYs.length > 1) {
                canvas.drawLine(
                  Offset(wireX, nodeY),
                  Offset(wireX, cardCenterYs[cardCenterYs.length - 2]),
                  highlightPaint,
                );
              }
            } else {
              canvas.drawLine(
                Offset(wireX, segY1),
                Offset(wireX, segY2),
                highlightPaint,
              );
            }
          }

          // Chấm terminal mắt dây
          _dotPaint.color = isHovered ? Colors.white : baseWireColor;
          canvas.drawCircle(
            Offset(wireX, nodeY),
            isHovered ? 4.0 : 2.5,
            _dotPaint,
          );
        }

        // 4. Chấm neo tại khối tròn
        _dotPaint.color = baseWireColor;
        canvas.drawCircle(bubbleAnchor, 3.5, _dotPaint);
        return;
      }
    }

    // -------------------------------------------------------------------------
    // HORIZONTAL FLOWING BÉZIER CURVES FOR CORNERS: BR, TR, TL
    // -------------------------------------------------------------------------
    for (int i = 0; i < cardCenterYs.length; i++) {
      final cardY = cardCenterYs[i];
      final isHovered = (hoveredIndex == i);

      final deltaX = cardTargetX - bubbleAnchor.dx;
      final deltaY = cardY - bubbleAnchor.dy;

      final targetX = bubbleAnchor.dx + deltaX * growthProgress;
      final targetY = bubbleAnchor.dy + deltaY * growthProgress;

      // Ensure generous horizontal curve span for silky natural arches in all states
      final span = (targetX - bubbleAnchor.dx).abs().clamp(30.0, 90.0);
      final cp1x = isRight
          ? (bubbleAnchor.dx - span * 0.45)
          : (bubbleAnchor.dx + span * 0.45);
      final cp1y = bubbleAnchor.dy + (targetY - bubbleAnchor.dy) * 0.05;

      final cp2x = isRight ? (targetX + span * 0.35) : (targetX - span * 0.35);
      final cp2y = targetY;

      final path = Path()
        ..moveTo(bubbleAnchor.dx, bubbleAnchor.dy)
        ..cubicTo(cp1x, cp1y, cp2x, cp2y, targetX, targetY);

      _wirePaint
        ..color = isHovered
            ? baseWireColor.withValues(alpha: 1.0)
            : baseWireColor.withValues(alpha: 0.55 * growthProgress)
        ..strokeWidth = isHovered ? 3.0 : 1.8;

      canvas.drawPath(path, _wirePaint);

      _dotPaint.color = isHovered ? Colors.white : baseWireColor;
      canvas.drawCircle(
        Offset(targetX, targetY),
        isHovered ? 4.0 : 2.5,
        _dotPaint,
      );
    }

    _dotPaint.color = baseWireColor;
    canvas.drawCircle(bubbleAnchor, 3.5, _dotPaint);
  }

  @override
  bool shouldRepaint(covariant _WirePainter oldDelegate) {
    return oldDelegate.growthProgress != growthProgress ||
        oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.isDark != isDark ||
        oldDelegate.isRight != isRight ||
        oldDelegate.isBottom != isBottom ||
        oldDelegate.verticalWireX != verticalWireX ||
        oldDelegate.bubbleAnchor != bubbleAnchor ||
        oldDelegate.cardTargetX != cardTargetX;
  }
}

// ---------------------------------------------------------------------------
// Compact Frosted Glass Info Card Row Widget with Blur Effect
// ---------------------------------------------------------------------------
class _InfoCard extends StatelessWidget {
  final String fieldKey;
  final String value;
  final bool isDark;
  final bool isWarning;
  final String modelName;

  const _InfoCard({
    required this.fieldKey,
    required this.value,
    required this.isDark,
    required this.isWarning,
    required this.modelName,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isWarning
        ? (isDark
              ? const Color(0xFF7F1D1D).withValues(alpha: 0.85)
              : const Color(0xFFFEE2E2).withValues(alpha: 0.95))
        : (isDark
              ? const Color(0xFF0F172A).withValues(alpha: 0.88)
              : Colors.white.withValues(alpha: 0.94));

    final borderColor = isWarning
        ? const Color(0xFFEF4444).withValues(alpha: 0.85)
        : (isDark
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.black.withValues(alpha: 0.12));

    IconData getIcon() {
      switch (fieldKey) {
        case 'PCASN':
          return Icons.memory;
        case 'SYSSN':
          return Icons.tag;
        case 'SYSPN':
          return Icons.inventory_2_outlined;
        case 'LCMPN':
          return Icons.desktop_windows_outlined;
        case 'IMEI':
          return Icons.phone_android;
        case 'CPU':
          return Icons.developer_board;
        default:
          return Icons.info_outline;
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: isWarning
                    ? const Color(0xFFEF4444).withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                getIcon(),
                size: 12,
                color: isWarning
                    ? const Color(0xFFEF4444)
                    : (isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 5),
              SizedBox(
                width: 44,
                child: Text(
                  fieldKey,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Outfit',
                    color: isWarning
                        ? const Color(0xFFEF4444)
                        : (isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF475569)),
                  ),
                ),
              ),
              Expanded(
                child: _MarqueeText(
                  text: value,
                  isWarning: isWarning,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'JetBrains Mono',
                    fontWeight: FontWeight.w600,
                    color: isWarning
                        ? const Color(0xFFEF4444)
                        : (isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                ),
              ),
              if (fieldKey == 'PCASN' &&
                  modelName != 'DUT' &&
                  modelName != '⏳') ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    modelName,
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'JetBrains Mono',
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Icon(
                Icons.copy,
                size: 11,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Asymmetric Marquee Text Widget (Native Scrollport + 100% Extent Tracking)
// ---------------------------------------------------------------------------
class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final bool isWarning;

  const _MarqueeText({
    required this.text,
    required this.style,
    this.isWarning = false,
  });

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  @override
  void didUpdateWidget(covariant _MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
    }
  }

  Future<void> _startScrolling() async {
    if (!mounted || !_scrollController.hasClients || _isScrolling) return;
    _isScrolling = true;

    // Initial hold delay (1500ms)
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted || !_scrollController.hasClients) {
      _isScrolling = false;
      return;
    }

    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) {
      _isScrolling = false;
      return;
    }

    while (mounted && _scrollController.hasClients) {
      // 1. Slow linear scroll to the end
      final travelDuration = Duration(milliseconds: widget.text.length * 60);
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: travelDuration,
        curve: Curves.linear,
      );
      if (!mounted || !_scrollController.hasClients) break;

      // Hold at the end (1500ms)
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted || !_scrollController.hasClients) break;

      // 2. Fast snap bounce back to start (800ms)
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOut,
      );
      if (!mounted || !_scrollController.hasClients) break;

      // Hold at the start (1500ms)
      await Future.delayed(const Duration(milliseconds: 1500));
    }

    _isScrolling = false;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.only(right: 4.0),
        child: Text(widget.text, style: widget.style, maxLines: 1),
      ),
    );
  }
}
