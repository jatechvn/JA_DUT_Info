import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_dut_info/modules/services/srf_receiver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('receiver DEX JAR is included in Flutter assets', () async {
    final data = await rootBundle.load('assets/tools/srf/SrfReceiver.jar');
    expect(data.lengthInBytes, greaterThan(1000));
    expect(data.buffer.asUint8List(data.offsetInBytes, 2), [0x50, 0x4b]);
  });
  const valid = 'RESULT:RX_OK:ID=25390A:COUNT=5:CLEAN=1';
  test(
    'RF result requires matching ID, five frames and successful cleanup',
    () {
      expect(srfAirId('GE'), '25390A');
      expect(srfAirId('Honeywell'), '49CA0A');
      expect(srfAirId('DSC'), '49CA0A');
      expect(srfAirId('unknown'), isNull);
      bool parse(String output, {int exit = 0}) =>
          srfReceivePassed(ProcessResult(1, exit, output, ''), '25390A');
      expect(parse(valid), isTrue);
      for (final output in [
        'Result: Parcel(00000000 00000000)',
        valid.replaceAll('25390A', '49CA0A'),
        valid.replaceAll('COUNT=5', 'COUNT=4'),
        valid.replaceAll('CLEAN=1', 'CLEAN=0'),
        '$valid\nRESULT:ERROR:cleanup failed',
        '$valid\nRESULT:RX_FAIL:COUNT=0',
      ]) {
        expect(parse(output), isFalse, reason: output);
      }
      expect(parse(valid, exit: 1), isFalse);
    },
  );

  test('service detection and binder replies reject misleading errors', () {
    expect(
      srfServiceFound(
        'Service srfservice_ttyHSLX: found',
        'srfservice_ttyHSLX',
      ),
      isTrue,
    );
    expect(
      srfServiceFound(
        'Service srfservice_ttyHSLX: not found',
        'srfservice_ttyHSLX',
      ),
      isFalse,
    );
    expect(srfParcelSuccess("Result: Parcel(00000000 '....')", 0), isTrue);
    expect(srfParcelSuccess("Result: Parcel(00000001 '....')", 1), isTrue);
    expect(srfParcelSuccess('error 00000000', 0), isFalse);
    expect(
      srfParcelSuccess("Result: Parcel(ffffffff 00000000 '........')", 0),
      isFalse,
    );
    expect(srfParcelIntCode("Result: Parcel(00000000 '....')"), 0);
    expect(srfParcelIntCode("Result: Parcel(0000000a '....')"), 10);
    expect(srfParcelIntCode('error'), isNull);

    expect(
      srfParseParcelString16(
        "Result: Parcel(\n"
        "  0x00000000: 00000000 0000000a 00300031 0033002e '........1.0...3.'\n"
        "  0x00000010: 0035002e 0047002d 00360031 00000000 '..5.-.G.1.6.....')\n",
      ),
      '10.3.5-G16',
    );
    expect(
      srfParseParcelString16(
        "Result: Parcel(00000000 0000000a 00310031 0032002e 0030002e 0047002d 00360032 00000000 '........1.1...2...0.-.G.2.6.....')",
      ),
      '11.2.0-G26',
    );
    expect(
      srfParseParcelString16(
        "Result: Parcel(\r\n"
        "  0x00000000: 0000000a 00310031 0032002e 0030002e '....1.1...2...0.'\r\n"
        "  0x00000010: 0047002d 00360032 00000000          '-.G.2.6.....    ')\r\n",
      ),
      '11.2.0-G26',
    );
    expect(isUnsupportedGoldenRev1Firmware('10.3.5-G16'), isTrue);
    expect(isUnsupportedGoldenRev1Firmware('10.3.5-D16'), isTrue);
    expect(isUnsupportedGoldenRev1Firmware('10.3.5-H16'), isTrue);
    expect(isUnsupportedGoldenRev1Firmware('11.2.0-G26'), isFalse);
    expect(isUnsupportedGoldenRev1Firmware('11.2.1-D26'), isFalse);
    expect(isUnsupportedGoldenRev1Firmware('11.2.2-H26'), isFalse);
  });

  final sdkCache = File(
    Platform.resolvedExecutable,
  ).parent.parent.parent.parent;
  final dartExe = '${sdkCache.path}/dart-sdk/bin/dart.exe';
  Future<SrfReceiveResult> simulate(String result, bool tx) =>
      runSrfReceiverProcess(
        dartExe,
        ['test/fixtures/srf_receiver_process.dart', result],
        airId: '25390A',
        transmit: () async => tx,
        readyTimeout: const Duration(seconds: 2),
        completionTimeout: const Duration(seconds: 3),
      );

  test(
    'pipeline requires both Golden acknowledgement and DUT reception',
    () async {
      final success = await simulate(valid, true);
      expect(success.passed, isTrue, reason: success.details);
      expect((await simulate(valid, false)).passed, isFalse);
      expect((await simulate('RESULT:RX_FAIL:COUNT=0', true)).passed, isFalse);
      expect(
        (await simulate('$valid\nRESULT:ERROR:cleanup failed', true)).passed,
        isFalse,
      );
    },
    skip: !Platform.isWindows,
  );

  test('failed bind never triggers transmission', () async {
    var called = false;
    final result = await runSrfReceiverProcess(
      'powershell.exe',
      [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        "[Console]::Out.WriteLine('RESULT:ERROR:bind failed'); exit 1",
      ],
      airId: '25390A',
      transmit: () async {
        called = true;
        return true;
      },
    );
    expect(result.passed, isFalse);
    expect(called, isFalse);
  }, skip: !Platform.isWindows);

  test(
    'readiness timeout terminates the owned process and skips transmit',
    () async {
      var called = false;
      final result = await runSrfReceiverProcess(
        'powershell.exe',
        [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          'Start-Sleep -Seconds 30',
        ],
        airId: '25390A',
        transmit: () async {
          called = true;
          return true;
        },
        readyTimeout: const Duration(milliseconds: 50),
        completionTimeout: const Duration(milliseconds: 100),
      );
      expect(result.passed, isFalse);
      expect(result.details, contains('TimeoutException'));
      expect(called, isFalse);
    },
    skip: !Platform.isWindows,
  );
}
