import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Starts the executable directly so cancellation targets Java, not cmd.exe.
Future<ProcessResult> runTransmitterProcess(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Duration timeout = const Duration(seconds: 20),
  void Function(Process)? onStarted,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
  );
  onStarted?.call(process);
  final output = process.stdout
      .transform(const Utf8Decoder(allowMalformed: true))
      .join();
  final errors = process.stderr
      .transform(const Utf8Decoder(allowMalformed: true))
      .join();
  final completion = Future.wait<Object>([process.exitCode, output, errors]);
  try {
    final values = await completion.timeout(timeout);
    return ProcessResult(process.pid, values[0] as int, values[1], values[2]);
  } on TimeoutException {
    process.kill(ProcessSignal.sigkill);
    // Do not release the caller until the owned process has exited.
    await completion;
    rethrow;
  }
}

Map<String, dynamic> parseTransmitterResult(
  ProcessResult result, {
  required String action,
  required String targetFreq,
}) {
  final output = result.stdout.toString();
  Map<String, dynamic> failure(String error) => {
    'success': false,
    'error': error,
    'raw': output,
  };
  if (result.exitCode != 0) {
    return failure('Transmitter exit ${result.exitCode}: ${result.stderr}');
  }
  final lines = output.split('\n').map((line) => line.trim()).toList();
  if (lines.any(
    (line) =>
        line.startsWith('RESULT:ERROR') ||
        line.startsWith('RESULT:NO_DEVICE') ||
        line.startsWith('RESULT:NO_MATCH'),
  )) {
    return failure('Transmitter rejected the request');
  }
  for (final line in lines) {
    if (action == 'ping' && line.startsWith('RESULT:PING_OK:')) {
      return {'success': true, 'pingOnly': true, 'raw': output};
    }
    if (action != 'transmit' || !line.startsWith('RESULT:TRANSMIT_OK:')) {
      continue;
    }
    final fields = <String, String>{};
    for (final field in line.split(':').skip(2)) {
      final separator = field.indexOf('=');
      if (separator > 0) {
        fields[field.substring(0, separator)] = field.substring(separator + 1);
      }
    }
    final frequency = {'0': '915', '1': '868'}[fields['FREQ']];
    if (fields['RET'] != '0' ||
        frequency == null ||
        (targetFreq != 'all' && frequency != targetFreq) ||
        !RegExp(r'^[1-9][0-9]*$').hasMatch(fields['ID'] ?? '')) {
      continue;
    }
    return {
      'success': true,
      'sensorId': fields['ID'],
      'frequency': '$frequency MHz',
      'raw': output,
    };
  }
  return failure('No valid result for $action / $targetFreq');
}
