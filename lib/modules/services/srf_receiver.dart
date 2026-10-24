import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'transmitter_process.dart';
import 'command_scope.dart';

String? srfAirId(String brand) => switch (brand) {
  'GE' => '25390A',
  'Honeywell' || 'DSC' => '49CA0A',
  _ => null,
};

bool srfServiceFound(String output, String name) =>
    output.trim() == 'Service $name: found';

/// A binder Parcel word is not evidence when it only occurs inside error text.
bool srfParcelSuccess(String output, int value) => RegExp(
  '^Result: Parcel\\(\\s*${value.toRadixString(16).padLeft(8, '0')}\\s+[^\\r\\n]*\\)\\s*\$',
).hasMatch(output.trim());

/// Extracts the first 32-bit integer status code from a binder Parcel reply
/// (e.g., `Result: Parcel(0000000a '....')` -> `10`).
int? srfParcelIntCode(String output) {
  final match = RegExp(
    r'^Result:\s*Parcel\(\s*([0-9a-fA-F]{8})\b',
  ).firstMatch(output.trim());
  if (match == null) return null;
  return int.tryParse(match.group(1)!, radix: 16);
}

/// Decodes a UTF-16 String16 reply from `service call srfservice_ttyHSL* 14`
/// (`GetFullPicVer`), e.g. `10.3.5-G16` or `11.2.0-G26`.
String? srfParseParcelString16(String output) {
  final cleaned = output
      .replaceAll(RegExp(r"'[^']*'"), '')
      .replaceAll(RegExp(r'0x[0-9a-fA-F]+:'), '');
  final words = RegExp(
    r'\b[0-9a-fA-F]{8}\b',
  ).allMatches(cleaned).map((m) => int.parse(m.group(0)!, radix: 16)).toList();
  if (words.isEmpty) return null;
  int len;
  int startIdx;
  if (words[0] == 0 && words.length >= 2 && words[1] > 0 && words[1] <= 128) {
    len = words[1];
    startIdx = 2;
  } else if (words[0] > 0 && words[0] <= 128) {
    len = words[0];
    startIdx = 1;
  } else {
    return null;
  }
  final codeUnits = <int>[];
  for (var i = startIdx; i < words.length && codeUnits.length < len; i++) {
    final word = words[i];
    final c1 = word & 0xFFFF;
    if (c1 != 0) codeUnits.add(c1);
    if (codeUnits.length >= len) break;
    final c2 = (word >> 16) & 0xFFFF;
    if (c2 != 0) codeUnits.add(c2);
  }
  if (codeUnits.isEmpty) return null;
  return String.fromCharCodes(codeUnits).trim();
}

/// Returns true if an SRF card firmware string is an older Rev 1 daughter card
/// (e.g. `10.3.5-G16`, `x.x.x-D16`, `x.x.x-H16`) which does not support
/// `TRANSMIT_RAW` (Transaction 18) on a Golden Panel.
bool isUnsupportedGoldenRev1Firmware(String fw) {
  final upper = fw.trim().toUpperCase();
  return RegExp(r'-[GDH]1\d*\b').hasMatch(upper);
}

bool srfReceivePassed(ProcessResult result, String airId) {
  final lines = result.stdout.toString().split('\n').map((s) => s.trim());
  return result.exitCode == 0 &&
      !lines.any((s) => s.startsWith('RESULT:ERROR')) &&
      lines.where((s) => s.startsWith('RESULT:')).length == 1 &&
      lines.contains('RESULT:RX_OK:ID=$airId:COUNT=5:CLEAN=1');
}

class SrfReceiveResult {
  final bool passed;
  final String details;
  const SrfReceiveResult(this.passed, this.details);
}

/// Owns one ADB process. The remote helper also enforces its own deadline.
Future<SrfReceiveResult> runSrfReceiverProcess(
  String executable,
  List<String> arguments, {
  required String airId,
  required Future<bool> Function() transmit,
  Duration readyTimeout = const Duration(seconds: 6),
  Duration completionTimeout = const Duration(seconds: 47),
}) async {
  final scope = CommandScope.current;
  scope?.check();
  final process = await Process.start(executable, arguments);
  scope?.attach(process);
  final ready = Completer<void>();
  final armed = Completer<void>();
  final output = StringBuffer();
  final errors = process.stderr
      .transform(const Utf8Decoder(allowMalformed: true))
      .join();
  final stdoutDone = process.stdout
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(const LineSplitter())
      .forEach((line) {
        output.writeln(line);
        if (line == 'READY:$airId' && !ready.isCompleted) ready.complete();
        if (line == 'ARMED:$airId' && !armed.isCompleted) armed.complete();
      });
  final completion = Future.wait<Object>([
    process.exitCode,
    stdoutDone.then((_) => ''),
    errors,
  ]);
  // Do not leave readiness waits pending after a failed launch/bind.
  completion.then((_) {
    if (!ready.isCompleted) ready.complete();
    if (!armed.isCompleted) armed.complete();
  });
  bool transmitted = false;
  try {
    await ready.future.timeout(readyTimeout);
    if (!output.toString().split('\n').contains('READY:$airId')) {
      throw StateError('Receiver did not bind');
    }
    process.stdin.writeln('GO');
    await process.stdin.flush();
    await armed.future.timeout(readyTimeout);
    if (!output.toString().split('\n').contains('ARMED:$airId')) {
      throw StateError('Receiver events not enabled');
    }
    scope?.check();
    transmitted = await transmit().timeout(const Duration(seconds: 8));
    if (!transmitted) {
      await process.stdin.close().catchError((_) {});
      try {
        await completion.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        process.kill();
        await completion;
      }
      return SrfReceiveResult(false, 'TX_ACK=false\n${output.toString()}');
    }
    final values = await completion.timeout(completionTimeout);
    final result = ProcessResult(
      process.pid,
      values[0] as int,
      output.toString(),
      values[2],
    );
    return SrfReceiveResult(
      transmitted && srfReceivePassed(result, airId),
      'TX_ACK=$transmitted\n${output.toString()}${values[2]}',
    );
  } catch (error) {
    // Close input; normal remote execution finishes and disables events by itself.
    // Wait for that cleanup before terminating the local transport.
    await process.stdin.close().catchError((_) {});
    try {
      await completion.timeout(completionTimeout);
    } on TimeoutException {
      process.kill();
      await completion;
    }
    return SrfReceiveResult(false, '$error\n$output');
  } finally {
    scope?.detach(process);
  }
}

final _activeSrfDevices = <String>{};
File? _receiverJar;

Future<SrfReceiveResult> receiveSrfOnDut(
  String serial,
  String airId,
  Future<bool> Function() transmit,
) async {
  if (!RegExp(r'^[a-zA-Z0-9._:-]+$').hasMatch(serial) ||
      !['25390A', '49CA0A'].contains(airId)) {
    return const SrfReceiveResult(false, 'Invalid receiver arguments');
  }
  if (!_activeSrfDevices.add(serial)) {
    return const SrfReceiveResult(false, 'SRF test already active on DUT');
  }
  try {
    if (_receiverJar == null) {
      final asset = await rootBundle.load('assets/tools/srf/SrfReceiver.jar');
      final folder = await Directory.systemTemp.createTemp('ja-srf-');
      final file = File('${folder.path}/SrfReceiver.jar');
      await file.writeAsBytes(
        asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
      );
      _receiverJar = file;
    }
    final remote =
        '/data/local/tmp/ja_srf_${DateTime.now().microsecondsSinceEpoch}.jar';
    final push = await runTransmitterProcess('adb', [
      '-s',
      serial,
      'push',
      _receiverJar!.path,
      remote,
    ]);
    if (push.exitCode != 0) {
      return SrfReceiveResult(false, 'Push failed: ${push.stderr}');
    }
    return await runSrfReceiverProcess(
      'adb',
      [
        '-s',
        serial,
        'shell',
        'CLASSPATH=$remote app_process / com.jatech.srf.SrfReceiver $airId',
      ],
      airId: airId,
      transmit: transmit,
    );
  } catch (error) {
    return SrfReceiveResult(false, error.toString());
  } finally {
    _activeSrfDevices.remove(serial);
  }
}
