import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'transmitter_process.dart';

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
  final process = await Process.start(executable, arguments);
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
    transmitted = await transmit().timeout(const Duration(seconds: 8));
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
