// lib/modules/ui/main_window.dart

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../logic.dart';
import 'styles.dart';

class MainWindow extends StatefulWidget {
  const MainWindow({super.key});

  @override
  State<MainWindow> createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow> {
  static const _windowChannel = MethodChannel('ja_route/window');

  void _closeApp() {
    exit(0);
  }

  void _copyToClipboard(BuildContext context, String field, String value) {
    if (value != 'N/A' && value.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: value));
      final monitor = Provider.of<AdbMonitor>(context, listen: false);
      monitor.updateStatus('Copied $field to clipboard!', true);
    }
  }

  void _startDrag() {
    if (Platform.isWindows) {
      _windowChannel.invokeMethod('startDrag');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
        const platform = MethodChannel('ja_route/theme');
        try {
          platform.invokeMethod('updateTheme', themeProvider.isDark);
        } catch (_) {}
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final monitor = Provider.of<AdbMonitor>(context);

    final statusColor = monitor.isSuccessStatus ? const Color(0xFF00FF9D) : const Color(0xFFFF4500);
    final accentColor = theme.style.accentColor;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onPanStart: (_) => _startDrag(),
        behavior: HitTestBehavior.translucent,
        child: Container(
          width: 410,
          height: 300,
          decoration: BoxDecoration(
            color: theme.style.mainBg,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: theme.style.borderTheme),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(1, 1),
              ),
            ],
          ),
          padding: const EdgeInsets.only(left: 20, right: 20, top: 15, bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Text(
                    'DUT PANEL INFO 📱',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                      fontFamily: 'Outfit',
                      shadows: [
                        Shadow(
                          color: theme.isDark ? Colors.black.withOpacity(0.8) : Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: (monitor.deviceConnected && monitor.stationResult != 'N/A')
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'TRẠM:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: theme.style.textSecondary,
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                                const SizedBox(width: 4),
                                _BlinkingText(
                                  text: monitor.stationResult,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00ADB5),
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  _ThemeToggleButton(
                    isDark: theme.isDark,
                    onPressed: () => theme.toggleTheme(),
                  ),
                  const SizedBox(width: 8),
                  _CloseButton(onPressed: _closeApp),
                ],
              ),
              const SizedBox(height: 10),
              // Body area wrapped in a Stack to support blurring overlay
              Expanded(
                child: Stack(
                  children: [
                    // Main content (Status + Grid)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Status Label
                        Row(
                          children: [
                            Text(
                              monitor.status,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                                fontFamily: 'Outfit',
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            if (monitor.allDuts.length > 1) ...[
                              const Spacer(),
                              _DutSelector(
                                currentDut: monitor.currentDut,
                                allDuts: monitor.allDuts,
                                onSelected: (val) => monitor.selectDut(val),
                                isDark: theme.isDark,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Grid fields
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: monitor.info.entries.map((entry) {
                              return Row(
                                children: [
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      '${entry.key}:',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: theme.style.textPrimary,
                                        fontFamily: 'Outfit',
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      height: 28,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: theme.style.cardBg,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: theme.style.borderTheme),
                                      ),
                                      alignment: Alignment.centerLeft,
                                      child: entry.key == 'LCMPN' && entry.value == 'Chú ý Panel này không được chạy lại màn hình'
                                          ? _BlinkingText(
                                              text: entry.value,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontFamily: 'JetBrains Mono',
                                                color: Color(0xFFFF4500),
                                                fontWeight: FontWeight.bold,
                                              ),
                                              useMarquee: true,
                                            )
                                          : (entry.key == 'LCMPN' && entry.value.startsWith('Panel này có 2 loại màn hình'))
                                              ? _MarqueeText(
                                                  text: entry.value,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontFamily: 'JetBrains Mono',
                                                    color: theme.style.textPrimary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                )
                                              : Text(
                                                  entry.value,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontFamily: 'JetBrains Mono',
                                                    color: theme.style.textPrimary,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _CopyButton(
                                    onPressed: () => _copyToClipboard(context, entry.key, entry.value),
                                    isDark: theme.isDark,
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                    // Blur Overlay
                    if (monitor.showOverlay)
                      Positioned.fill(
                        child: ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                            child: Container(
                              color: theme.isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.25),
                              child: Center(
                                child: Text(
                                  monitor.overlayText,
                                  style: TextStyle(
                                    fontSize: (monitor.overlayText == 'IQ4' || monitor.overlayText == 'IQ5') ? 64 : 44,
                                    fontWeight: FontWeight.w900,
                                    color: theme.isDark ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.8),
                                    fontFamily: 'Outfit',
                                    letterSpacing: 2,
                                    shadows: [
                                      Shadow(
                                        color: theme.isDark ? Colors.black45 : Colors.white38,
                                        blurRadius: 15,
                                        offset: const Offset(2, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _CloseButton({required this.onPressed});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFFFF4500).withOpacity(0.6) : const Color(0xFFFF4500).withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const Text(
            'X',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              fontFamily: 'Outfit',
            ),
          ),
        ),
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isDark;
  const _CopyButton({required this.onPressed, required this.isDark});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = _pressed 
        ? Colors.white.withOpacity(0.3) 
        : (_hovered ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.1));

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onPressed();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1),
            ),
          ),
          alignment: Alignment.center,
          child: const Text(
            '📋',
            style: TextStyle(fontSize: 14),
          ),
        ),
      ),
    );
  }
}

class _ThemeToggleButton extends StatefulWidget {
  final bool isDark;
  final VoidCallback onPressed;
  const _ThemeToggleButton({required this.isDark, required this.onPressed});

  @override
  State<_ThemeToggleButton> createState() => _ThemeToggleButtonState();
}

class _ThemeToggleButtonState extends State<_ThemeToggleButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: widget.isDark
                ? (_hovered ? Colors.amber.withOpacity(0.2) : Colors.amber.withOpacity(0.1))
                : (_hovered ? Colors.black.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(
            widget.isDark ? Icons.light_mode : Icons.dark_mode,
            color: widget.isDark ? Colors.amber : Colors.black87,
            size: 14,
          ),
        ),
      ),
    );
  }
}
class _DutSelector extends StatefulWidget {
  final String currentDut;
  final List<String> allDuts;
  final ValueChanged<String> onSelected;
  final bool isDark;

  const _DutSelector({
    required this.currentDut,
    required this.allDuts,
    required this.onSelected,
    required this.isDark,
  });

  @override
  State<_DutSelector> createState() => _DutSelectorState();
}

class _DutSelectorState extends State<_DutSelector> {
  bool _hovered = false;

  void _cycleDut() {
    if (widget.allDuts.length <= 1) return;
    final currentIndex = widget.allDuts.indexOf(widget.currentDut);
    final nextIndex = (currentIndex + 1) % widget.allDuts.length;
    widget.onSelected(widget.allDuts[nextIndex]);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark
        ? (_hovered ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.1))
        : (_hovered ? Colors.black.withOpacity(0.08) : Colors.black.withOpacity(0.05));

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _cycleDut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: widget.isDark ? Colors.white10 : widget.isDark ? Colors.white10 : Colors.black12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.swap_horiz, size: 14, color: Color(0xFF00ADB5)),
              const SizedBox(width: 4),
              Text(
                'Switch (${widget.allDuts.length})',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white70 : Colors.black87,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlinkingText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final bool useMarquee;

  const _BlinkingText({required this.text, required this.style, this.useMarquee = false});

  @override
  State<_BlinkingText> createState() => _BlinkingTextState();
}

class _BlinkingTextState extends State<_BlinkingText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.useMarquee
        ? _MarqueeText(text: widget.text, style: widget.style)
        : Text(
            widget.text,
            style: widget.style,
            overflow: TextOverflow.ellipsis,
          );

    return FadeTransition(
      opacity: _animation,
      child: child,
    );
  }
}

class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _MarqueeText({required this.text, required this.style});

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() async {
    if (!_scrollController.hasClients) return;
    // Small delay before beginning scroll
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    if (maxScrollExtent <= 0) return;

    while (mounted) {
      // Scroll to the end
      await _scrollController.animateTo(
        maxScrollExtent,
        duration: Duration(milliseconds: widget.text.length * 90),
        curve: Curves.linear,
      );
      if (!mounted) return;

      // Pause at the end
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;

      // Jump/animate back to start
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOut,
      );
      if (!mounted) return;

      // Pause at the start
      await Future.delayed(const Duration(milliseconds: 1500));
    }
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
      physics: const NeverScrollableScrollPhysics(), // Prevent manual dragging
      child: Text(
        widget.text,
        style: widget.style,
      ),
    );
  }
}
