// lib/modules/ui/styles.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'styles_win10.dart';
import 'styles_win11.dart';

abstract class AppStyle {
  Color get scaffoldBg;
  Color get sidebarBg;
  Color get cardBg;
  Color get mainBg;
  Color get activeTabBg;
  Color get textPrimary;
  Color get textSecondary;
  Color get borderTheme;
  Color get accentColor;
}

class ThemeProvider extends ChangeNotifier {
  static const _channel = MethodChannel('ja_route/theme');

  bool _isDark = false; // Default to light mode as requested
  bool _isWin11 = false;
  late AppStyle _style;

  bool get isDark => _isDark;
  bool get isWin11 => _isWin11;
  AppStyle get style => _style;

  ThemeProvider() {
    _detectWindowsVersion();
    _resolveStyle();
    _applyNativeTheme();
  }

  void _detectWindowsVersion() {
    if (!Platform.isWindows) {
      _isWin11 = false;
      return;
    }
    try {
      final versionStr = Platform.operatingSystemVersion;
      if (versionStr.contains('Windows 11')) {
        _isWin11 = true;
        return;
      }
      final match = RegExp(r'Build\s+(\d+)', caseSensitive: false).firstMatch(versionStr);
      if (match != null) {
        final buildNumber = int.tryParse(match.group(1) ?? '') ?? 0;
        _isWin11 = buildNumber >= 22000;
      }
    } catch (_) {}
  }

  void toggleTheme() {
    _isDark = !_isDark;
    _resolveStyle();
    _applyNativeTheme();
    notifyListeners();
  }

  void setTheme(bool dark) {
    _isDark = dark;
    _resolveStyle();
    _applyNativeTheme();
    notifyListeners();
  }

  void _resolveStyle() {
    if (_isWin11) {
      _style = Windows11Style(_isDark);
    } else {
      _style = Windows10Style(_isDark);
    }
  }

  Future<void> _applyNativeTheme() async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod('updateTheme', _isDark);
    } catch (e) {
      print('Failed to apply native theme: $e');
    }
  }

  ThemeData get themeData {
    return ThemeData(
      brightness: _isDark ? Brightness.dark : Brightness.light,
      primaryColor: _style.accentColor,
      scaffoldBackgroundColor: Colors.transparent,
      cardColor: _style.cardBg,
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontFamily: 'Outfit'),
      ),
    );
  }
}
