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

  static String protocolFromMatrix(String value) {
    final matrix = value.trim().toUpperCase();
    // Match complete band tokens, not their first digit (900M != protocol 9).
    final bands = RegExp(
      r'(?:^|[^A-Z0-9])(800M?|868(?:M|MHZ)?|900M?|915(?:M|MHZ)?)(?=$|[^A-Z0-9])',
    ).allMatches(matrix).map((m) => m.group(1)!.startsWith('8') ? '9' : '8').toSet();
    if (bands.length == 1) return bands.single;
    if (matrix == '9' || matrix == '8') return matrix;
    return '';
  }

  static bool isPowerGServiceFound(String output) => RegExp(
    r'^Service\s+powergservice:\s+found\s*$',
    multiLine: true,
  ).hasMatch(output.trim());

  static PowerGResult iq5McuResult({
    required String fw,
    required String protocol,
    required String details,
  }) => PowerGResult(
    status: PowerGStatus.mcuOk,
    fw: fw.trim().isEmpty ? 'N/A' : fw,
    protocol: protocol.trim().isEmpty ? 'N/A' : protocol,
    frequency: mapProtocolToFrequency(protocol),
    message: 'Card & MCU OK (Chưa test thu sóng RF)',
    rawDetails: details,
  );

  /// Map PowerG protocol code to human-readable frequency band
  static String mapProtocolToFrequency(String protocol) {
    switch (protocol.trim().toUpperCase()) {
      case '9':
      case '868':
      case '868M':
      case '868MHZ':
        return '868 MHz (EU)';
      case '8':
      case '915':
      case '915M':
      case '915MHZ':
        return '915 MHz (NA)';
      case '6':
        return '915 MHz (LATAM)';
      case '4':
        return '915 MHz (ANZ)';
      case '7':
      case '433':
      case '433M':
      case '433MHZ':
        return '433 MHz';
      default:
        if (protocol.isNotEmpty && protocol != 'N/A') {
          return 'Protocol $protocol';
        }
        return 'N/A';
    }
  }

  /// Comprehensive protocol resolution supporting IQ4 and IQ5
  Future<String> _resolveProtocol(
    String dutSerial, {
    String currentProtocol = '',
  }) async {
    final cur = currentProtocol.trim();
    if (cur.isNotEmpty && cur != '0' && cur != 'N/A') {
      return cur;
    }

    // 1. Primary property on IQ4: qolsys.slot_one.protocol (8 = 915MHz, 9 = 868MHz)
    var proto = (await runCmd([
      'adb',
      '-s',
      dutSerial,
      'shell',
      'getprop',
      'qolsys.slot_one.protocol',
    ])).trim();
    if (proto.isNotEmpty && proto != '0' && proto != 'N/A') return proto;

    // 2. qolsys.powergv4.protocol
    proto = (await runCmd([
      'adb',
      '-s',
      dutSerial,
      'shell',
      'getprop',
      'qolsys.powergv4.protocol',
    ])).trim();
    if (proto.isNotEmpty && proto != '0' && proto != 'N/A') return proto;

    // 3. persist.qolsys.powergv4.protocol
    proto = (await runCmd([
      'adb',
      '-s',
      dutSerial,
      'shell',
      'getprop',
      'persist.qolsys.powergv4.protocol',
    ])).trim();
    if (proto.isNotEmpty && proto != '0' && proto != 'N/A') return proto;

    // 4. qolsys.powerg.protocol
    proto = (await runCmd([
      'adb',
      '-s',
      dutSerial,
      'shell',
      'getprop',
      'qolsys.powerg.protocol',
    ])).trim();
    if (proto.isNotEmpty && proto != '0' && proto != 'N/A') return proto;

    // 5. persist.qolsys.powerg.protocol
    proto = (await runCmd([
      'adb',
      '-s',
      dutSerial,
      'shell',
      'getprop',
      'persist.qolsys.powerg.protocol',
    ])).trim();
    if (proto.isNotEmpty && proto != '0' && proto != 'N/A') return proto;

    // 6. qolsys.card.matrix (e.g. 900M or 800M)
    final matrix = (await runCmd([
      'adb',
      '-s',
      dutSerial,
      'shell',
      'getprop',
      'qolsys.card.matrix',
    ])).trim().toUpperCase();
    final matrixProtocol = protocolFromMatrix(matrix);
    if (matrixProtocol.isNotEmpty) return matrixProtocol;

    // 7. SYSPN from testeepapi (e.g. IQP4004 is 868MHz, IQP4001 is 915MHz)
    final syspn = (await runCmd([
      'adb',
      '-s',
      dutSerial,
      'shell',
      'testeepapi',
      'r',
      'syspn',
    ])).trim().toUpperCase();
    if (syspn.contains('4004') ||
        syspn.contains('4008') ||
        syspn.contains('4009') ||
        syspn.contains('868')) {
      return '9'; // 868 MHz
    }
    if (syspn.contains('4001') ||
        syspn.contains('4002') ||
        syspn.contains('4003') ||
        syspn.contains('915')) {
      return '8'; // 915 MHz
    }

    return '';
  }

  /// Comprehensive firmware resolution supporting IQ4 and IQ5
  Future<String> _resolveFirmware(
    String dutSerial, {
    String currentFw = '',
  }) async {
    final cur = currentFw.trim();
    if (cur.isNotEmpty && cur != 'N/A') return cur;

    for (var f = 0; f < 4; f++) {
      var fw = (await runCmd([
        'adb',
        '-s',
        dutSerial,
        'shell',
        'getprop',
        'qolsys.powergv4.fw',
      ])).trim();
      if (fw.isNotEmpty && fw != 'N/A') return fw;

      fw = (await runCmd([
        'adb',
        '-s',
        dutSerial,
        'shell',
        'getprop',
        'qolsys.powerg.fw',
      ])).trim();
      if (fw.isNotEmpty && fw != 'N/A') return fw;

      fw = (await runCmd([
        'adb',
        '-s',
        dutSerial,
        'shell',
        'getprop',
        'qolsys.powerg.radio.fw',
      ])).trim();
      if (fw.isNotEmpty && fw != 'N/A') return fw;

      final hwdMat = (await runCmd([
        'adb',
        '-s',
        dutSerial,
        'shell',
        'getprop',
        'persist.qolsys.hwd.matrix',
      ])).trim();
      if (hwdMat.isNotEmpty && hwdMat != 'N/A') {
        final parts = hwdMat.split(RegExp(r'[,;|\s]+'));
        for (final p in parts) {
          if (RegExp(r'^\d+\.\d+$').hasMatch(p)) {
            return p;
          }
        }
      }

      if (f < 3) await Future.delayed(const Duration(milliseconds: 500));
    }
    return 'N/A';
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
        "Get-CimInstance Win32_SerialPort | Where-Object Description -match 'CP210|Silicon|UART' | Select-Object -ExpandProperty DeviceID",
      ], runInShell: true);
      final out = res.stdout.toString().trim();
      if (out.isNotEmpty) {
        final lines = out.split(RegExp(r'[\r\n]+'));
        for (final l in lines) {
          final trimmed = l.trim();
          if (RegExp(r'^COM\d+$', caseSensitive: false).hasMatch(trimmed)) {
            logger.info('[PowerGService] Detected transmitter port: $trimmed');
            return trimmed;
          }
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
      protocol = await _resolveProtocol(dutSerial, currentProtocol: protocol);

      if (cardOut == '1' ||
          cardV4Out == '1' ||
          (protocol.isNotEmpty && protocol != '0' && protocol != 'N/A')) {
        isCardInstalled = true;
        break;
      }

      // Check service check powergservice as additional confirmation
      final srvCheck = (await runCmd([
        'adb',
        '-s',
        dutSerial,
        'shell',
        'service',
        'check',
        'powergservice',
      ])).trim();
      if (isPowerGServiceFound(srvCheck)) {
        isCardInstalled = true;
        break;
      }

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
      } else if (hwdEnd == '1' && attempt >= 5) {
        // Stop after 5 attempts if hardware discovery confirms no card
        break;
      }

      if (attempt < 10) {
        await Future.delayed(const Duration(milliseconds: 1200));
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

    // Detect if DUT is IQ5
    final pcasnCheck = (await runCmd([
      'adb',
      '-s',
      dutSerial,
      'shell',
      'testeepapi',
      'r',
      'pcasn',
    ])).trim();
    final sysConfig = (await runCmd([
      'adb',
      '-s',
      dutSerial,
      'shell',
      'getprop',
      'qolsys.sys.config',
    ])).trim();
    final isIQ5 =
        pcasnCheck.toUpperCase().startsWith('QB95') ||
        pcasnCheck.toUpperCase().startsWith('QB85') ||
        pcasnCheck.toUpperCase().startsWith('QC95') ||
        sysConfig.toUpperCase().startsWith('IQP5') ||
        sysConfig.toUpperCase().startsWith('IQH5') ||
        sysConfig.toUpperCase().startsWith('IQ5');

    if (isIQ5) {
      logger.info(
        '[PowerGService] Detected IQ5 platform on $dutSerial. Running hardware bootloader/MCU diagnostic.',
      );
      // Read slot
      var slot = (await runCmd([
        'adb',
        '-s',
        dutSerial,
        'shell',
        'getprop',
        'qolsys.powergv4.slot',
      ])).trim();
      if (slot.isEmpty || slot == 'N/A') slot = '1';

      // Read FW and protocol
      var fw = await _resolveFirmware(dutSerial);
      protocol = await _resolveProtocol(dutSerial, currentProtocol: protocol);
      var freqStr = mapProtocolToFrequency(protocol);

      // Run powergv4bootload -s $slot -c 1
      final bootloadOut = await runCmd([
        'adb',
        '-s',
        dutSerial,
        'shell',
        'powergv4bootload',
        '-s',
        slot,
        '-c',
        '1',
      ]);

      // Check success across Library v3.0 and v3.15+
      final hasHello =
          bootloadOut.contains('PGHOST Received hello!') ||
          bootloadOut.contains('Got Hello Message') ||
          bootloadOut.contains('Hello received');
      final hasVersion =
          bootloadOut.contains('version:') ||
          bootloadOut.contains('Found version:') ||
          bootloadOut.contains('Updated version:');
      final isSuccess =
          bootloadOut.contains('Operation Result: SUCCESS') ||
          bootloadOut.contains('Return SUCCESS') ||
          (hasHello && hasVersion);

      if (isSuccess) {
        // Extract RF fw if still empty
        if (fw.isEmpty || fw == 'N/A') {
          final m2 = RegExp(
            r'Firmware version2:\s*([\d\.]+)',
          ).firstMatch(bootloadOut);
          if (m2 != null) {
            fw = m2.group(1)!;
          } else {
            final m1 = RegExp(
              r'(?:Found )?version:\s*([\d\.]+)',
            ).firstMatch(bootloadOut);
            if (m1 != null) fw = m1.group(1)!;
          }
        }
        if (protocol.isEmpty || protocol == 'N/A') {
          final regionMatch = RegExp(r'region=(\d+)').firstMatch(bootloadOut);
          if (regionMatch != null) {
            final r = regionMatch.group(1);
            if (r == '0') {
              protocol = '8';
            } else if (r == '1') {
              protocol = '9';
            } else if (r == '2') {
              protocol = '7';
            }
            freqStr = mapProtocolToFrequency(protocol);
          }
        }
        logger.info(
          '[PowerGService] IQ5 PowerG V4 MCU & Radio check PASS on $dutSerial',
        );
        return iq5McuResult(fw: fw, protocol: protocol, details: bootloadOut);
      } else {
        logger.severe(
          '[PowerGService] IQ5 PowerG V4 check failed on $dutSerial: $bootloadOut',
        );
        return PowerGResult(
          status: PowerGStatus.fail,
          fw: fw.isEmpty ? 'N/A' : fw,
          protocol: protocol.isEmpty ? 'N/A' : protocol,
          frequency: freqStr,
          message: 'Lỗi MCU / Radio (powergv4bootload thất bại)',
          rawDetails: bootloadOut,
        );
      }
    }

    // 2. Ensure powergservice is started & ready in ServiceManager (IQ4)
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
      if (isPowerGServiceFound(chk)) {
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

    // 3. Read firmware and protocol with robust multi-property fallback
    final fw = await _resolveFirmware(dutSerial);
    protocol = await _resolveProtocol(dutSerial, currentProtocol: protocol);
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
      final targetFreq =
          (protocol == '8' ||
              protocol == '6' ||
              protocol == '4' ||
              protocol == '915' ||
              protocol.toUpperCase().contains('915'))
          ? '915'
          : ((protocol == '9' ||
                    protocol == '868' ||
                    protocol.toUpperCase().contains('868'))
                ? '868'
                : 'all');
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
