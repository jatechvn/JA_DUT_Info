// lib/modules/services/powerg_service.dart

import 'dart:async';
import 'dart:io';
import '../logger_config.dart';
import '../utils.dart';

enum PowerGStatus {
  pass,          // RF Sensor registered & MCU OK
  mcuOk,         // MCU ping OK, but RF transmitter not connected or RF test skipped
  fail,          // RF test failed or MCU error
  notInstalled,  // No PowerG daughter card installed on DUT
  testing,       // Test currently in progress
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
    final localAsset = File('${Directory.current.path}/assets/tools/powerg/PowerGTransmitter.jar');
    if (localAsset.existsSync()) return localAsset.path;

    // 2. Relative to script/executable directory
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final exeAsset = File('$exeDir/data/flutter_assets/assets/tools/powerg/PowerGTransmitter.jar');
    if (exeAsset.existsSync()) return exeAsset.path;

    final directAsset = File('$exeDir/assets/tools/powerg/PowerGTransmitter.jar');
    if (directAsset.existsSync()) return directAsset.path;

    // 3. Fallback to production workspace path if present
    const devPath = 'D:/OS-Software/OneDrive/OpenClaw_Workspace/JA_PROJECT/PROJECT_DART/JA_DUT_Info/assets/tools/powerg/PowerGTransmitter.jar';
    if (File(devPath).existsSync()) return devPath;

    return null;
  }

  /// Scan system for PowerG Transmitter COM port
  Future<String?> findTransmitterComPort() async {
    try {
      final res = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          "Get-CimInstance Win32_PnPEntity | Where-Object { \$_.PNPClass -eq 'Ports' -and (\$_.Name -match 'CP210' -or \$_.Name -match 'UART' -or \$_.DeviceID -match 'VID_10C4') } | Select-Object -ExpandProperty Name"
        ],
        runInShell: true,
      );
      final out = res.stdout.toString().trim();
      if (out.isNotEmpty) {
        final match = RegExp(r'\((COM\d+)\)').firstMatch(out);
        if (match != null) {
          final port = match.group(1);
          logger.info('[PowerGService] Detected transmitter port: $port ($out)');
          return port;
        }
      }
    } catch (e) {
      logger.warning('[PowerGService] Failed to detect COM port via PowerShell: $e');
    }
    return null;
  }

  /// Trigger PowerG Transmitter to broadcast a sensor registration packet
  Future<Map<String, dynamic>> triggerTransmitter({String action = 'transmit'}) async {
    final jarPath = _findTransmitterJarPath();
    if (jarPath == null) {
      logger.warning('[PowerGService] PowerGTransmitter.jar not found on system');
      return {'success': false, 'error': 'Transmitter tool not found'};
    }

    try {
      final jarDir = File(jarPath).parent.path;
      logger.info('[PowerGService] Running PowerGTransmitter: java -jar "$jarPath" $action');
      final result = await Process.run(
        'java',
        ['-jar', jarPath, action],
        workingDirectory: jarDir,
        runInShell: true,
      ).timeout(const Duration(seconds: 8));

      final stdout = result.stdout.toString();
      logger.info('[PowerGService] Transmitter output: $stdout');

      for (final line in stdout.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.startsWith('RESULT:TRANSMIT_OK')) {
          // Parse: RESULT:TRANSMIT_OK:FREQ=1:VER=547:ID=1011230:RET=0
          final parts = trimmed.split(':');
          String? sensorId;
          String? freq;
          for (final p in parts) {
            if (p.startsWith('ID=')) sensorId = p.substring(3);
            if (p.startsWith('FREQ=')) freq = p.substring(5);
          }
          return {
            'success': true,
            'sensorId': sensorId ?? '1011230',
            'frequency': freq == '1' ? '868 MHz' : '915 MHz',
            'raw': stdout,
          };
        } else if (trimmed.startsWith('RESULT:PING_OK')) {
          return {'success': true, 'pingOnly': true, 'raw': stdout};
        } else if (trimmed.startsWith('RESULT:NO_DEVICE')) {
          return {'success': false, 'error': 'No transmitter device attached', 'raw': stdout};
        }
      }
      return {'success': false, 'error': 'Unexpected response', 'raw': stdout};
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

    // 1. Inspect properties on DUT
    final cardOut = (await runCmd(['adb', '-s', dutSerial, 'shell', 'getprop', 'qolsys.powerg.card'])).trim();
    final cardV4Out = (await runCmd(['adb', '-s', dutSerial, 'shell', 'getprop', 'qolsys.powergv4.card'])).trim();

    final isCardInstalled = cardOut == '1' || cardV4Out == '1';
    if (!isCardInstalled) {
      logger.info('[PowerGService] PowerG card not installed on DUT $dutSerial');
      return const PowerGResult(
        status: PowerGStatus.notInstalled,
        message: 'Không có card PowerG',
      );
    }

    final fw = (await runCmd(['adb', '-s', dutSerial, 'shell', 'getprop', 'qolsys.powergv4.fw'])).trim();
    final protocol = (await runCmd(['adb', '-s', dutSerial, 'shell', 'getprop', 'persist.qolsys.powergv4.protocol'])).trim();
    final freqStr = mapProtocolToFrequency(protocol);

    // 2. Ping MCU & Radio Check (Transact 200)
    final pingOut = await runCmd(['adb', '-s', dutSerial, 'shell', 'service', 'call', 'powergservice', '200']);
    final isMcuAlive = pingOut.contains('00000001') || pingOut.contains('00000100');
    if (!isMcuAlive) {
      logger.severe('[PowerGService] MCU/Radio ping failed on $dutSerial: $pingOut');
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

    // 3. Check for external transmitter
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
      await runCmd(['adb', '-s', dutSerial, 'shell', 'service', 'call', 'powergservice', '2', 'i32', '1']);
      await runCmd(['adb', '-s', dutSerial, 'shell', 'service', 'call', 'powergservice', '201']);

      // 5. Trigger transmitter
      final transmitResult = await triggerTransmitter(action: 'transmit');
      if (!transmitResult['success']) {
        logger.warning('[PowerGService] Transmitter trigger failed: ${transmitResult['error']}');
        // Disable AutoLearn
        await runCmd(['adb', '-s', dutSerial, 'shell', 'service', 'call', 'powergservice', '2', 'i32', '0']);
        return PowerGResult(
          status: PowerGStatus.mcuOk,
          fw: fw.isEmpty ? 'N/A' : fw,
          protocol: protocol.isEmpty ? 'N/A' : protocol,
          frequency: freqStr,
          comPort: comPort,
          message: 'MCU OK (Bộ phát lỗi: ${transmitResult['error']})',
        );
      }

      // 6. Poll transact 202 for registration message
      String receivedHex = '';
      int? receivedIdDec;
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 300));
        final pollOut = await runCmd(['adb', '-s', dutSerial, 'shell', 'service', 'call', 'powergservice', '202']);
        
        final match = RegExp(r'Parcel\(([0-9a-fA-F]{8})').firstMatch(pollOut);
        if (match != null) {
          final hexVal = match.group(1)!;
          final decVal = int.tryParse(hexVal, radix: 16);
          if (decVal != null && decVal > 0) {
            receivedHex = hexVal;
            receivedIdDec = decVal;
            logger.info('[PowerGService] Received registration ID: $decVal (hex: $hexVal) on attempt $i');
            break;
          }
        }
      }

      // Disable AutoLearn
      await runCmd(['adb', '-s', dutSerial, 'shell', 'service', 'call', 'powergservice', '2', 'i32', '0']);

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
      } else {
        logger.warning('[PowerGService] Registration timeout on DUT $dutSerial');
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
      await runCmd(['adb', '-s', dutSerial, 'shell', 'service', 'call', 'powergservice', '2', 'i32', '0']);
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
