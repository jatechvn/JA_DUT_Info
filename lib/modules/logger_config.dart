// lib/modules/logger_config.dart

import 'dart:io';
import 'package:logging/logging.dart';
import 'constants.dart';

final Logger logger = Logger(appName);
File? _currentLogFile;
Directory? _logDir;

Future<void> initLogger() async {
  Logger.root.level = Level.ALL;

  try {
    _logDir = Directory('logs');
    if (!await _logDir!.exists()) {
      await _logDir!.create(recursive: true);
    }
    _currentLogFile = File('logs/startup.log');
    // Clear/Reset startup log on start
    if (await _currentLogFile!.exists()) {
      try {
        await _currentLogFile!.delete();
      } catch (_) {}
    }
  } catch (e) {
    print('Failed to initialize log directory: $e');
  }

  Logger.root.onRecord.listen((record) {
    final logMessage = '${record.time.toLocal().toString().substring(11, 19)} [${record.level.name}] ${record.message}';
    print(logMessage);
    
    if (_currentLogFile != null) {
      try {
        _currentLogFile!.writeAsStringSync('$logMessage\n', mode: FileMode.append);
      } catch (_) {}
    }
  });

  logger.info('Logger initialized.');
}

void setDutLogSession(String? syssn) {
  if (_logDir == null) return;
  try {
    if (syssn == null || syssn.isEmpty) {
      _currentLogFile = File('logs/startup.log');
      logger.info('Switched log session back to startup.log');
    } else {
      _currentLogFile = File('logs/$syssn.log');
      logger.info('--- LOG SESSION STARTED FOR SYSSN: $syssn ---');
    }
  } catch (e) {
    print('Failed to switch log session: $e');
  }
}
