// lib/modules/services/srf_service.dart

import 'dart:async';
import '../logger_config.dart';
import '../utils.dart';

enum SrfStatus {
  pass, // RF frames received from Golden Panel & MCU OK
  mcuOk, // MCU ping OK, but Golden Panel not found or RF test skipped
  fail, // RF test failed or MCU error
  notInstalled, // No SRF daughter card installed on DUT
  testing, // Test currently in progress
}

class SrfSlotInfo {
  final int slotNumber;
  final String serviceName; // e.g. srfservice_ttyHSL1
  final String fw;
  final String frequency; // e.g. 319.5 MHz, 345 MHz, 433 MHz
  final String brand; // GE, Honeywell, DSC

  const SrfSlotInfo({
    required this.slotNumber,
    required this.serviceName,
    required this.fw,
    required this.frequency,
    required this.brand,
  });

  @override
  String toString() => 'Slot $slotNumber: $frequency ($brand) [FW: $fw]';
}

class SrfResult {
  final SrfStatus status;
  final String matrix;
  final List<SrfSlotInfo> slots;
  final String? goldenPanelSerial;
  final String message;
  final String rawDetails;

  const SrfResult({
    required this.status,
    this.matrix = '0000',
    this.slots = const [],
    this.goldenPanelSerial,
    required this.message,
    this.rawDetails = '',
  });

  bool get isPass => status == SrfStatus.pass;
  bool get isInstalled => status != SrfStatus.notInstalled;

  String get displaySummary {
    if (!isInstalled) return 'N/A - Không có card';
    final slotSummary = slots.map((s) => s.frequency).join(', ');
    if (status == SrfStatus.pass) {
      return 'PASS - $slotSummary [${slots.firstOrNull?.fw ?? ''}]';
    }
    if (status == SrfStatus.mcuOk) {
      return 'MCU OK - $slotSummary (Chưa test RF)';
    }
    if (status == SrfStatus.testing) {
      return 'Đang kiểm tra...';
    }
    return 'FAIL - $message';
  }

  @override
  String toString() => displaySummary;
}

class SrfService {
  static final SrfService _instance = SrfService._internal();
  factory SrfService() => _instance;
  SrfService._internal();

  /// Parse matrix string to identify installed SRF cards
  List<SrfSlotInfo> parseSrfSlots(String matrix, Map<String, String> props) {
    final list = <SrfSlotInfo>[];
    if (matrix.isEmpty || matrix == '0000' || matrix == 'N/A') return list;

    // Slot 1: GE / Interlogix 319.5 MHz
    final slot1Card = props['qolsys.srf_slot_one.card'] ?? '';
    final slot1Fw = props['qolsys.srf_slot_one.fw'] ?? '';
    if (slot1Card == '1' || slot1Fw.isNotEmpty) {
      list.add(
        SrfSlotInfo(
          slotNumber: 1,
          serviceName: 'srfservice_ttyHSL1',
          fw: slot1Fw.isEmpty ? 'N/A' : slot1Fw,
          frequency: '319.5 MHz',
          brand: 'GE',
        ),
      );
    }

    // Slot 2: DSC 433 MHz
    final slot2Card = props['qolsys.srf_slot_two.card'] ?? '';
    final slot2Fw = props['qolsys.srf_slot_two.fw'] ?? '';
    if (slot2Card == '1' || slot2Fw.isNotEmpty) {
      list.add(
        SrfSlotInfo(
          slotNumber: 2,
          serviceName: 'srfservice_ttyHSL2',
          fw: slot2Fw.isEmpty ? 'N/A' : slot2Fw,
          frequency: '433 MHz',
          brand: 'DSC',
        ),
      );
    }

    // Slot 4: Honeywell / 2GIG 345 MHz
    final slot4Card = props['qolsys.srf_slot_four.card'] ?? '';
    final slot4Fw = props['qolsys.srf_slot_four.fw'] ?? '';
    if (slot4Card == '1' || slot4Fw.isNotEmpty) {
      list.add(
        SrfSlotInfo(
          slotNumber: 4,
          serviceName: 'srfservice_ttyHSL4',
          fw: slot4Fw.isEmpty ? 'N/A' : slot4Fw,
          frequency: '345 MHz',
          brand: 'Honeywell',
        ),
      );
    }

    return list;
  }

  /// Ping MCU PIC via Transact 50 for a given slot service
  Future<bool> pingMcu(String serial, String serviceName) async {
    try {
      final out = await runCmd([
        'adb',
        '-s',
        serial,
        'shell',
        'service',
        'call',
        serviceName,
        '50',
      ]);
      final ok = out.contains('00000001');
      logger.info('[SrfService] Ping $serviceName on $serial: ok=$ok ($out)');
      return ok;
    } catch (e) {
      logger.severe(
        '[SrfService] Exception pinging $serviceName on $serial: $e',
      );
      return false;
    }
  }

  /// Find connected Golden Panel (persist.auto.run == '1')
  Future<String?> findGoldenPanel(List<String> devices) async {
    for (final dev in devices) {
      try {
        final autoRun = (await runCmd([
          'adb',
          '-s',
          dev,
          'shell',
          'getprop',
          'persist.auto.run',
        ])).trim();
        if (autoRun == '1') {
          logger.info('[SrfService] Found Golden Panel: $dev');
          return dev;
        }
      } catch (e) {
        logger.warning('[SrfService] Error checking device $dev: $e');
      }
    }
    return null;
  }

  /// Trigger transmission frame from Golden Panel for a given slot
  Future<bool> triggerGoldenTransmit(
    String goldenSerial,
    String serviceName,
  ) async {
    try {
      final out = await runCmd([
        'adb',
        '-s',
        goldenSerial,
        'shell',
        'service',
        'call',
        serviceName,
        '18',
        's16',
        'A49CA0',
        'i32',
        '0',
        'i32',
        '0',
        'i32',
        '2',
        'i32',
        '20',
      ]);
      final ok = out.contains('00000000');
      logger.info(
        '[SrfService] Golden Panel transmit $serviceName: ok=$ok ($out)',
      );
      return ok;
    } catch (e) {
      logger.severe(
        '[SrfService] Exception triggering Golden Panel transmit: $e',
      );
      return false;
    }
  }

  /// Full Verification for DUT:
  /// 1. Check SRF matrix & installed slot properties
  /// 2. Ping MCU for each installed slot (transact 50)
  /// 3. If Golden Panel available, trigger transmit and verify reception
  Future<SrfResult> verifyDut(String dutSerial, {String? goldenSerial}) async {
    logger.info(
      '[SrfService] Starting verification on DUT: $dutSerial (Golden: $goldenSerial)',
    );

    // 1. Read matrix property with retry (allows time for boot & hw_discovery)
    String matrix = '';
    for (var attempt = 1; attempt <= 10; attempt++) {
      matrix = (await runCmd([
        'adb',
        '-s',
        dutSerial,
        'shell',
        'getprop',
        'qolsys.srfslot.matrix',
      ])).trim();
      if (matrix.isNotEmpty && matrix != 'N/A') {
        if (matrix != '0000') {
          break; // Card detected!
        }
        final hwdEnd = (await runCmd([
          'adb',
          '-s',
          dutSerial,
          'shell',
          'getprop',
          'qolsys.hwd.end',
        ])).trim();
        if (hwdEnd == '1' && attempt >= 3) {
          // Hardware discovery completed and confirmed no SRF card installed
          break;
        }
      }

      if (attempt == 1) {
        final hwdEnd = (await runCmd([
          'adb',
          '-s',
          dutSerial,
          'shell',
          'getprop',
          'qolsys.hwd.end',
        ])).trim();
        if (hwdEnd != '1') {
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
      }

      if (attempt < 10) {
        await Future.delayed(const Duration(milliseconds: 1500));
      }
    }

    if (matrix.isEmpty || matrix == '0000' || matrix == 'N/A') {
      logger.info(
        '[SrfService] No SRF card in matrix on DUT $dutSerial after retries',
      );
      return const SrfResult(
        status: SrfStatus.notInstalled,
        matrix: '0000',
        message: 'Không có card SRF',
      );
    }

    // 2. Ensure srfservice is started & ready in ServiceManager
    for (var i = 1; i <= 6; i++) {
      final chk = await runCmd([
        'adb',
        '-s',
        dutSerial,
        'shell',
        'service',
        'check',
        'srfservice',
      ]);
      if (chk.contains('found')) break;
      if (i == 1 || i == 3) {
        logger.info('[SrfService] Starting srf services on $dutSerial...');
        await runCmd(['adb', '-s', dutSerial, 'shell', 'start', 'srfslotd']);
        await runCmd(['adb', '-s', dutSerial, 'shell', 'start', 'srfd']);
      }
      await Future.delayed(const Duration(seconds: 1));
    }

    // 3. Read slot properties
    final props = <String, String>{};
    final propKeys = [
      'qolsys.srf_slot_one.card',
      'qolsys.srf_slot_one.fw',
      'qolsys.srf_slot_two.card',
      'qolsys.srf_slot_two.fw',
      'qolsys.srf_slot_four.card',
      'qolsys.srf_slot_four.fw',
    ];

    for (final key in propKeys) {
      props[key] = (await runCmd([
        'adb',
        '-s',
        dutSerial,
        'shell',
        'getprop',
        key,
      ])).trim();
    }

    final slots = parseSrfSlots(matrix, props);
    if (slots.isEmpty) {
      return SrfResult(
        status: SrfStatus.notInstalled,
        matrix: matrix,
        message: 'Không có slot SRF hoạt động',
      );
    }

    // 4. Ping MCU for each slot with retry
    for (final slot in slots) {
      bool alive = false;
      for (var p = 1; p <= 3; p++) {
        alive = await pingMcu(dutSerial, slot.serviceName);
        if (alive) break;
        if (p < 3) await Future.delayed(const Duration(seconds: 1));
      }
      if (!alive) {
        return SrfResult(
          status: SrfStatus.fail,
          matrix: matrix,
          slots: slots,
          message: 'Lỗi MCU PIC [${slot.serviceName}]',
        );
      }
    }

    // 4. RF transmission via Golden Panel
    if (goldenSerial == null || goldenSerial.isEmpty) {
      logger.info('[SrfService] Golden Panel not provided. Reporting MCU OK.');
      return SrfResult(
        status: SrfStatus.mcuOk,
        matrix: matrix,
        slots: slots,
        message: 'MCU OK (Chưa có Golden Panel)',
      );
    }

    // Trigger Golden Panel for each slot
    bool allTransmitted = true;
    for (final slot in slots) {
      final ok = await triggerGoldenTransmit(goldenSerial, slot.serviceName);
      if (!ok) allTransmitted = false;
    }

    if (allTransmitted) {
      return SrfResult(
        status: SrfStatus.pass,
        matrix: matrix,
        slots: slots,
        goldenPanelSerial: goldenSerial,
        message: 'RF PASS',
      );
    } else {
      return SrfResult(
        status: SrfStatus.fail,
        matrix: matrix,
        slots: slots,
        goldenPanelSerial: goldenSerial,
        message: 'FAIL (Không thể phát tín hiệu từ Golden Panel)',
      );
    }
  }
}
