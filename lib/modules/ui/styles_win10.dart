// lib/modules/ui/styles_win10.dart

import 'package:flutter/material.dart';
import 'styles.dart';

class Windows10Style implements AppStyle {
  final bool isDark;

  Windows10Style(this.isDark);

  @override
  Color get scaffoldBg => Colors.transparent;

  @override
  Color get sidebarBg => isDark ? const Color(0xB21C1B1B) : const Color(0xB2F3F4F6); // 70% opacity

  @override
  Color get cardBg => isDark ? const Color(0xD92C2B2B) : const Color(0xD9FFFFFF); // 85% opacity

  @override
  Color get mainBg => isDark ? const Color(0xB21C1B1B) : const Color(0xB2F3F4F6); // 70% opacity

  @override
  Color get activeTabBg => isDark ? Colors.white12 : Colors.black12;

  @override
  Color get textPrimary => isDark ? Colors.white : Colors.black87;

  @override
  Color get textSecondary => isDark ? Colors.white70 : Colors.black54;

  @override
  Color get borderTheme => isDark ? Colors.white10 : Colors.black12;

  @override
  Color get accentColor => const Color(0xFF0078D7); // Windows 10 Accent Blue
}
