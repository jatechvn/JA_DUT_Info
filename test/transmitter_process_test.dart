import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_dut_info/modules/services/transmitter_process.dart';

void main() {
  const valid = 'RESULT:TRANSMIT_OK:INDEX=1:FREQ=0:ID=1011231:RET=0';
  Map<String, dynamic> parse(
    String output, {
    int exit = 0,
    String action = 'transmit',
  }) => parseTransmitterResult(
    ProcessResult(1, exit, output, 'error'),
    action: action,
    targetFreq: '915',
  );

  test('accepts only a successful matching radio result', () {
    expect(parse(valid)['sensorId'], '1011231');
    for (final output in [
      valid.replaceAll('RET=0', 'RET=1'),
      valid.replaceAll('FREQ=0', 'FREQ=1'),
      valid.replaceAll(':RET=0', ''),
      valid.replaceAll('ID=1011231', 'ID='),
      'RESULT:PING_OK:ID=1011231',
      '$valid\nRESULT:ERROR:cleanup failed',
    ]) {
      expect(parse(output)['success'], isFalse, reason: output);
    }
    expect(parse(valid, exit: 2)['success'], isFalse);
    expect(
      parse('RESULT:PING_OK:ID=1011231', action: 'ping')['success'],
      isTrue,
    );
  });

  test(
    'timeout terminates the owned process before returning',
    () async {
      Process? child;
      await expectLater(
        runTransmitterProcess(
          'powershell.exe',
          [
            '-NoProfile',
            '-NonInteractive',
            '-Command',
            'Start-Sleep -Seconds 30',
          ],
          timeout: const Duration(milliseconds: 300),
          onStarted: (process) => child = process,
        ),
        throwsA(isA<TimeoutException>()),
      );
      expect(child, isNotNull);
      expect(
        await child!.exitCode.timeout(const Duration(seconds: 1)),
        isNot(0),
      );
    },
    skip: !Platform.isWindows,
  );

  test('captures both output streams and nonzero exit', () async {
    final result = await runTransmitterProcess('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      '[Console]::Out.WriteLine("ok"); [Console]::Error.WriteLine("bad"); exit 7',
    ]);
    expect(result.exitCode, 7);
    expect(result.stdout, contains('ok'));
    expect(result.stderr, contains('bad'));
  }, skip: !Platform.isWindows);
}
