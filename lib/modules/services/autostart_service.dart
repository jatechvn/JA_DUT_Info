// lib/modules/services/autostart_service.dart

import 'dart:io';
import '../logger_config.dart';

/// Service managing the Windows startup autostart registry entry
/// (HKCU\Software\Microsoft\Windows\CurrentVersion\Run)
class AutostartService {
  static const String _runKey =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const String _valueName = 'JA_DUT_Info';

  /// Check whether the app is currently configured to run on Windows startup
  static Future<bool> isAutostartEnabled() async {
    if (!Platform.isWindows) return false;
    try {
      final res = await Process.run('reg', [
        'query',
        _runKey,
        '/v',
        _valueName,
      ]);
      if (res.exitCode == 0) {
        final out = res.stdout.toString();
        return out.contains(_valueName) && out.toLowerCase().contains('.exe');
      }
      return false;
    } catch (e) {
      logger.warning('Failed to query autostart registry key: $e');
      return false;
    }
  }

  /// Enable or disable running on Windows startup
  static Future<bool> setAutostartEnabled(
    bool enabled, {
    Future<ProcessResult> Function(String, List<String>)? runProcess,
  }) async {
    if (!Platform.isWindows) return false;
    try {
      if (enabled) {
        final exePath = Platform.resolvedExecutable;
        final res = await (runProcess ?? Process.run)('reg', [
          'add',
          _runKey,
          '/v',
          _valueName,
          '/t',
          'REG_SZ',
          '/d',
          '"$exePath"',
          '/f',
        ]);
        final ok = res.exitCode == 0;
        if (ok) {
          logger.info('Enabled autostart on Windows startup: $exePath');
        } else {
          logger.severe('Failed to enable autostart: ${res.stderr}');
        }
        return ok;
      } else {
        final res = await (runProcess ?? Process.run)('reg', [
          'delete',
          _runKey,
          '/v',
          _valueName,
          '/f',
        ]);
        if (res.exitCode == 0) {
          logger.info('Disabled autostart on Windows startup');
        } else {
          logger.severe('Failed to disable autostart: ${res.stderr}');
        }
        return res.exitCode == 0;
      }
    } catch (e) {
      logger.severe('Failed to modify autostart registry key: $e');
      return false;
    }
  }
}
