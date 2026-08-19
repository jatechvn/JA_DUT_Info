// lib/modules/ui/styles_win11.dart

import 'package:flutter/material.dart';
import 'styles.dart';

class Windows11Style implements AppStyle {
  final bool isDark;

  Windows11Style(this.isDark);

  @override
  Color get scaffoldBg => Colors.transparent;

  @override
  Color get sidebarBg => isDark ? const Color(0x801C1B1B) : const Color(0x80F3F4F6); // 50% opacity

  @override
  Color get cardBg => isDark ? const Color(0x9A2C2B2B) : const Color(0x9AFFFFFF); // 60% opacity

  @override
  Color get mainBg => isDark ? const Color(0x801C1B1B) : const Color(0x80F3F4F6); // 50% opacity

  @override
  Color get activeTabBg => isDark ? Colors.white12 : Colors.black12;

  @override
  Color get textPrimary => isDark ? Colors.white : Colors.black87;

  @override
  Color get textSecondary => isDark ? Colors.white70 : Colors.black54;

  @override
  Color get borderTheme => isDark ? Colors.white10 : Colors.black12;

  @override
  Color get accentColor => isDark ? const Color(0xFF60CDFF) : const Color(0xFF0078D4); // Windows 11 Accent Blue
}
