// lib/modules/utils.dart

import 'dart:io';
import 'logger_config.dart';

Future<String> runCmd(List<String> cmd) async {
  if (cmd.isEmpty) return '';
  final cmdStr = cmd.join(' ');
  // Log CMD as INFO or FINE. In python, it's DEBUG (which we map to info in console or keep as log output)
  logger.info('CMD: $cmdStr');
  try {
    final executable = cmd[0];
    final arguments = cmd.sublist(1);
    
    final result = await Process.run(
      executable,
      arguments,
      runInShell: true,
    );
    
    final out = result.stdout.toString().trim();
    final err = result.stderr.toString().trim();
    
    if (err.isNotEmpty) {
      logger.warning('STDERR: $err');
    }
    logger.info('OUT: $out');
    return out;
  } catch (e) {
    logger.severe('CMD EXCEPTION: $e');
    return '';
  }
}
