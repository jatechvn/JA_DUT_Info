// lib/modules/services/powerg_service.dart

import 'dart:async';
import 'dart:io';
import '../logger_config.dart';
import '../utils.dart';
import 'transmitter_process.dart';

enum PowerGStatus {
  pass, // RF Sensor registered & MCU OK
  mcuOk, // MCU ping OK, but RF transmitter not connected or RF test skipped
  fail, // RF test failed or MCU error
  notInstalled, // No PowerG daughter card installed on DUT
  testing, // Test currently in progress
}

class PowerGResult {
  final PowerGStatus status;
  final String fw;
  final String protocol;
  final String frequency;
  final String? sensorId;
  final String? comPort;
  final String message;
  final String rawDetails;

  const PowerGResult({
    required this.status,
    this.fw = 'N/A',
    this.protocol = 'N/A',
    this.frequency = 'N/A',
    this.sensorId,
    this.comPort,
    required this.message,
    this.rawDetails = '',
  });

  bool get isPass => status == PowerGStatus.pass;
  bool get isInstalled => status != PowerGStatus.notInstalled;

  String get displaySummary {
    if (!isInstalled) return 'N/A - Không có card';
    if (status == PowerGStatus.pass) {
      final idStr = sensorId != null ? ' (ID: $sensorId)' : '';
      return 'PASS - $frequency$idStr [FW: $fw]';
    }
    if (status == PowerGStatus.mcuOk) {
      return 'MCU OK - $frequency [FW: $fw] (Chưa test RF)';
    }
    if (status == PowerGStatus.testing) {
      return 'Đang kiểm tra...';
    }
    return 'FAIL - $message';
  }

  @override
  String toString() => displaySummary;
}

class PowerGService {
  static final PowerGService _instance = PowerGService._internal();
  factory PowerGService() => _instance;
  PowerGService._internal();

  /// Map PowerG protocol code to human-readable frequency band
  static String mapProtocolToFrequency(String protocol) {
    switch (protocol.trim()) {
      case '9':
        return '868 MHz (EU)';
      case '8':
        return '915 MHz (NA)';
      case '6':
        return '915 MHz (LATAM)';
      case '4':
        return '915 MHz (ANZ)';
      case '7':
        return '433 MHz';
      default:
        if (protocol.isNotEmpty && protocol != 'N/A') {
          return 'Protocol $protocol';
        }
        return 'N/A';
    }
  }

  /// Locate the standalone PowerG transmitter runner JAR
  String? _findTransmitterJarPath() {
    // 1. Current working directory assets
    final localAsset = File(
      '${Directory.current.path}/assets/tools/powerg/PowerGTransmitter.jar',
    );
    if (localAsset.existsSync()) return localAsset.path;

    // 2. Relative to script/executable directory
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final exeAsset = File(
      '$exeDir/data/flutter_assets/assets/tools/powerg/PowerGTransmitter.jar',
    );
    if (exeAsset.existsSync()) return exeAsset.path;

    final directAsset = File(
      '$exeDir/assets/tools/powerg/PowerGTransmitter.jar',
    );
    if (directAsset.existsSync()) return directAsset.path;

    // 3. Fallback to production workspace path if present
    const devPath =
        'D:/OS-Software/OneDrive/OpenClaw_Workspace/JA_PROJECT/PROJECT_DART/JA_DUT_Info/assets/tools/powerg/PowerGTransmitter.jar';
    if (File(devPath).existsSync()) return devPath;

    return null;
  }

  /// Scan system for PowerG Transmitter COM port
  Future<String?> findTransmitterComPort() async {
    try {
      final res = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        "Get-CimInstance Win32_PnPEntity | Where-Object { \$_.PNPClass -eq 'Ports' -and (\$_.Name -match 'CP210' -or \$_.Name -match 'UART' -or \$_.DeviceID -match 'VID_10C4') } | Select-Object -ExpandProperty Name",
      ], runInShell: true);
      final out = res.stdout.toString().trim();
      if (out.isNotEmpty) {
        final match = RegExp(r'\((COM\d+)\)').firstMatch(out);
        if (match != null) {
          final port = match.group(1);
          logger.info(
            '[PowerGService] Detected transmitter port: $port ($out)',
          );
          return port;
        }
      }
    } catch (e) {
      logger.warning(
        '[PowerGService] Failed to detect COM port via PowerShell: $e',
      );
    }
    return null;
  }

  /// Trigger PowerG Transmitter to broadcast a sensor registration packet
  Future<Map<String, dynamic>> triggerTransmitter({
    String action = 'transmit',
    String targetFreq = 'all',
  }) async {
    final jarPath = _findTransmitterJarPath();
    if (jarPath == null) {
      logger.warning(
        '[PowerGService] PowerGTransmitter.jar not found on system',
      );
      return {'success': false, 'error': 'Transmitter tool not found'};
    }

    try {
      final jarDir = File(jarPath).parent.path;
      logger.info(
        '[PowerGService] Running PowerGTransmitter: java -jar "$jarPath" $action $targetFreq',
      );
      final result = await runTransmitterProcess('java', [
        '-Xmx64m',
        '-Xms16m',
        '-jar',
        jarPath,
        action,
        targetFreq,
      ], workingDirectory: jarDir);
      logger.info('[PowerGService] Transmitter output: ${result.stdout}');
      return parseTransmitterResult(
        result,
        action: action,
        targetFreq: targetFreq,
      );
    } catch (e) {
      logger.severe('[PowerGService] Exception running PowerGTransmitter: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Full Verification for DUT:
  /// 1. Check card installation & properties
  /// 2. Ping MCU & Radio check (transact 200)
  /// 3. Enable AutoLearn (transact 2 1) & Clear buffer (transact 201)
  /// 4. Trigger transmitter
  /// 5. Poll registration buffer (transact 202)
  /// 6. Disable AutoLearn (transact 2 0)
  Future<PowerGResult> verifyDut(String dutSerial) async {
    logger.info('[PowerGService] Starting verification on DUT: $dutSerial');

    // 1. Inspect properties on DUT with retry (allows time for boot & hw_discovery)
    bool isCardInstalled = false;
    String cardOut = '';
    String cardV4Out = '';
    String protocol = '';

    for (var attempt = 1; attempt <= 10; attempt++) {
      cardOut = (await runCmd([
        'adb',
        '-s',
        dutSerial,
        'shell',
        'getprop',
        'qolsys.powerg.card',
      ])).trim();
      cardV4Out = (await runCmd([
        'adb',
        '-s',
        dutSerial,
        'shell',
        'getprop',
        'qolsys.powergv4.card',
      ])).trim();
      protocol = (await runCmd([
        'adb',
        '-s',
        dutSerial,
        'shell',
        'getprop',
        'persist.qolsys.powergv4.protocol',
      ])).trim();

      if (cardOut == '1' || cardV4Out == '1') {
        isCardInstalled = true;
        break;
      }

      // If persist protocol exists (e.g. 9 or 8), card was previously detected
      if (protocol.isNotEmpty && protocol != '0' && protocol != 'N/A') {
        final hwdEnd = (await runCmd([
          'adb',
          '-s',
          dutSerial,
          'shell',
          'getprop',
          'qolsys.hwd.end',
        ])).trim();
        if (hwdEnd != '1' && attempt == 1) {
          logger.info(
            '[PowerGService] Triggering hardware discovery for PowerG on $dutSerial',
          );
          await runCmd([
            'adb',
            '-s',
            dutSerial,
            'shell',
            'setprop',
            'qolsys.factory.hwd',
            '1',
          ]);
        }
      } else {
        final hwdEnd = (await runCmd([
          'adb',
          '-s',
          dutSerial,
          'shell',
          'getprop',
          'qolsys.hwd.end',
        ])).trim();
        if (hwdEnd == '1' && attempt >= 3) {
          // Hardware discovery has completed and confirmed no PowerG card
          break;
        }
      }

      if (attempt < 10) {
        await Future.delayed(const Duration(milliseconds: 1500));
      }
    }

    if (!isCardInstalled) {
      logger.info(
        '[PowerGService] PowerG card not installed on DUT $dutSerial after retries',
      );
      return const PowerGResult(
        status: PowerGStatus.notInstalled,
        message: 'Không có card PowerG',
      );
    }

    // 2. Ensure powergservice is started & ready in ServiceManager
    for (var i = 1; i <= 6; i++) {
      final chk = await runCmd([
        'adb',
        '-s',
        dutSerial,
        'shell',
        'service',
        'check',
        'powergservice',
      ]);
      if (chk.contains('found')) {
        break;
      }
      if (i == 1 || i == 3) {
        logger.info(
          '[PowerGService] Starting powergd service on $dutSerial...',
        );
        await runCmd(['adb', '-s', dutSerial, 'shell', 'start', 'powergd']);
      }
      await Future.delayed(const Duration(seconds: 1));
    }

    // 3. Read firmware with retry
    var fw = (await runCmd([
      'adb',
      '-s',
      dutSerial,
      'shell',
      'getprop',
      'qolsys.powergv4.fw',
    ])).trim();
    if (fw.isEmpty || fw == 'N/A') {
      for (var f = 0; f < 5; f++) {
        await Future.delayed(const Duration(seconds: 1));
        fw = (await runCmd([
          'adb',
          '-s',
          dutSerial,
          'shell',
          'getprop',
          'qolsys.powergv4.fw',
        ])).trim();
        if (fw.isNotEmpty && fw != 'N/A') break;
      }
    }
    if (protocol.isEmpty || protocol == 'N/A') {
      protocol = (await runCmd([
        'adb',
        '-s',
        dutSerial,
        'shell',
        'getprop',
        'persist.qolsys.powergv4.protocol',
      ])).trim();
    }
    final freqStr = mapProtocolToFrequency(protocol);

    // 4. Ping MCU & Radio Check (Transact 200) with retry
    bool isMcuAlive = false;
    String pingOut = '';
    for (var p = 1; p <= 3; p++) {
      pingOut = await runCmd([
        'adb',
        '-s',
        dutSerial,
        'shell',
        'service',
        'call',
        'powergservice',
        '200',
      ]);
      if (pingOut.contains('00000001') || pingOut.contains('00000100')) {
        isMcuAlive = true;
        break;
      }
      if (p < 3) await Future.delayed(const Duration(seconds: 1));
    }

    if (!isMcuAlive) {
      logger.severe(
        '[PowerGService] MCU/Radio ping failed on $dutSerial after retries: $pingOut',
      );
      return PowerGResult(
        status: PowerGStatus.fail,
        fw: fw.isEmpty ? 'N/A' : fw,
        protocol: protocol.isEmpty ? 'N/A' : protocol,
        frequency: freqStr,
        message: 'Lỗi MCU / Radio (Transact 200 thất bại)',
        rawDetails: pingOut,
      );
    }
    logger.info('[PowerGService] MCU & Radio ping PASS on $dutSerial');

    // 5. Check for external transmitter
    final comPort = await findTransmitterComPort();
    if (comPort == null) {
      logger.warning('[PowerGService] Transmitter COM port not detected');
      return PowerGResult(
        status: PowerGStatus.mcuOk,
        fw: fw.isEmpty ? 'N/A' : fw,
        protocol: protocol.isEmpty ? 'N/A' : protocol,
        frequency: freqStr,
        message: 'MCU OK (Chưa gắn bộ phát RF)',
      );
    }

    // 4. Enable AutoLearn & Clear buffer on DUT
    try {
      await runCmd([
        'adb',
        '-s',
        dutSerial,
        'shell',
        'service',
        'call',
        'powergservice',
        '2',
        'i32',
        '1',
      ]);
      await runCmd([
        'adb',
        '-s',
        dutSerial,
        'shell',
        'service',
        'call',
        'powergservice',
        '201',
      ]);

      // 5. Trigger transmitter with frequency awareness
      final targetFreq = (protocol == '8' || protocol == '6' || protocol == '4')
          ? '915'
          : ((protocol == '9') ? '868' : 'all');
      final transmitResult = await triggerTransmitter(
        action: 'transmit',
        targetFreq: targetFreq,
      );

      final transmitterFailed = !transmitResult['success'];
      if (transmitterFailed) {
        logger.warning(
          '[PowerGService] Transmitter trigger issue: ${transmitResult['error']} (checking if background broadcast or MMI tool is active)',
        );
      }

      // 6. Poll transact 202 for registration message
      String receivedHex = '';
      int? receivedIdDec;
      // 20 attempts x 400ms = 8.0 seconds polling window
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 400));
        final pollOut = await runCmd([
          'adb',
          '-s',
          dutSerial,
          'shell',
          'service',
          'call',
          'powergservice',
          '202',
        ]);

        final match = RegExp(r'Parcel\(([0-9a-fA-F]{8})').firstMatch(pollOut);
        if (match != null) {
          final hexVal = match.group(1)!;
          final decVal = int.tryParse(hexVal, radix: 16);
          if (decVal != null && decVal > 0) {
            receivedHex = hexVal;
            receivedIdDec = decVal;
            logger.info(
              '[PowerGService] Received registration ID: $decVal (hex: $hexVal) on attempt $i',
            );
            break;
          }
        }
      }

      // Disable AutoLearn
      await runCmd([
        'adb',
        '-s',
        dutSerial,
        'shell',
        'service',
        'call',
        'powergservice',
        '2',
        'i32',
        '0',
      ]);

      if (receivedIdDec != null) {
        return PowerGResult(
          status: PowerGStatus.pass,
          fw: fw.isEmpty ? 'N/A' : fw,
          protocol: protocol.isEmpty ? 'N/A' : protocol,
          frequency: freqStr,
          sensorId: receivedIdDec.toString(),
          comPort: comPort,
          message: 'RF PASS (ID: $receivedIdDec)',
          rawDetails: 'Registered Hex: $receivedHex',
        );
      } else if (transmitterFailed) {
        return PowerGResult(
          status: PowerGStatus.mcuOk,
          fw: fw.isEmpty ? 'N/A' : fw,
          protocol: protocol.isEmpty ? 'N/A' : protocol,
          frequency: freqStr,
          comPort: comPort,
          message: 'MCU OK (Bộ phát bận/lỗi: ${transmitResult['error']})',
        );
      } else {
        logger.warning(
          '[PowerGService] Registration timeout on DUT $dutSerial',
        );
        return PowerGResult(
          status: PowerGStatus.fail,
          fw: fw.isEmpty ? 'N/A' : fw,
          protocol: protocol.isEmpty ? 'N/A' : protocol,
          frequency: freqStr,
          comPort: comPort,
          message: 'FAIL (Không nhận được tín hiệu RF)',
        );
      }
    } catch (e) {
      logger.severe('[PowerGService] Error during RF verification: $e');
      // Ensure AutoLearn is disabled
      await runCmd([
        'adb',
        '-s',
        dutSerial,
        'shell',
        'service',
        'call',
        'powergservice',
        '2',
        'i32',
        '0',
      ]);
      return PowerGResult(
        status: PowerGStatus.fail,
        fw: fw.isEmpty ? 'N/A' : fw,
        protocol: protocol.isEmpty ? 'N/A' : protocol,
        frequency: freqStr,
        comPort: comPort,
        message: 'Lỗi kiểm tra RF: $e',
      );
    }
  }
}
