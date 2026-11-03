// lib/modules/services/golden_audit_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../constants.dart';
import 'dut_validator.dart';
import 'powerg_service.dart';
import 'srf_service.dart';

enum FixtureHealthGrade {
  certified, // FHI >= 85%
  warning, // 70% <= FHI < 85%
  critical; // FHI < 70%

  String get label => switch (this) {
    FixtureHealthGrade.certified => 'ĐẠT CHUẨN (CERTIFIED)',
    FixtureHealthGrade.warning => 'CẢNH BÁO HAO MÒN (WARNING)',
    FixtureHealthGrade.critical => 'BẢO DƯỠNG / NGƯNG TRẠM (CRITICAL)',
  };

  String get shortLabel => switch (this) {
    FixtureHealthGrade.certified => 'CERTIFIED',
    FixtureHealthGrade.warning => 'WARNING',
    FixtureHealthGrade.critical => 'CRITICAL',
  };

  static FixtureHealthGrade fromScore(int score) {
    if (score >= 85) return FixtureHealthGrade.certified;
    if (score >= 70) return FixtureHealthGrade.warning;
    return FixtureHealthGrade.critical;
  }
}

class GoldenBoardProfile {
  final String syssn;
  final String pcasn;
  final String syspn;
  final String modelName;
  final int baselinePowerGMs;
  final int baselineSrfMs;
  final DateTime registeredAt;

  const GoldenBoardProfile({
    required this.syssn,
    required this.pcasn,
    required this.syspn,
    required this.modelName,
    this.baselinePowerGMs = 0,
    this.baselineSrfMs = 0,
    required this.registeredAt,
  });

  static bool _isValidKey(String v) {
    final t = v.trim();
    return t.isNotEmpty &&
        t != 'N/A' &&
        t != 'Chưa test MMI' &&
        !t.startsWith('Đang');
  }

  bool matches({required String syssn, required String pcasn}) {
    final snClean = syssn.trim().toUpperCase();
    final pcaClean = pcasn.trim().toUpperCase();
    if (_isValidKey(this.syssn) &&
        _isValidKey(snClean) &&
        this.syssn.trim().toUpperCase() == snClean) {
      return true;
    }
    if (_isValidKey(this.pcasn) &&
        _isValidKey(pcaClean) &&
        this.pcasn.trim().toUpperCase() == pcaClean) {
      return true;
    }
    return false;
  }

  String get displayKey => _isValidKey(syssn) ? syssn : pcasn;

  Map<String, dynamic> toJson() => {
    'syssn': syssn,
    'pcasn': pcasn,
    'syspn': syspn,
    'modelName': modelName,
    'baselinePowerGMs': baselinePowerGMs,
    'baselineSrfMs': baselineSrfMs,
    'registeredAt': registeredAt.toIso8601String(),
  };

  factory GoldenBoardProfile.fromJson(Map<String, dynamic> json) {
    return GoldenBoardProfile(
      syssn: json['syssn']?.toString() ?? 'N/A',
      pcasn: json['pcasn']?.toString() ?? 'N/A',
      syspn: json['syspn']?.toString() ?? 'N/A',
      modelName: json['modelName']?.toString() ?? 'DUT',
      baselinePowerGMs: (json['baselinePowerGMs'] as num?)?.toInt() ?? 0,
      baselineSrfMs: (json['baselineSrfMs'] as num?)?.toInt() ?? 0,
      registeredAt:
          DateTime.tryParse(json['registeredAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class ShiftCertificate {
  final String shiftId;
  final String shiftLabel;
  final DateTime certifiedAt;
  final String goldenSyssn;
  final String goldenPcasn;
  final String dutSerial;
  final int fhiScore;
  final FixtureHealthGrade grade;

  const ShiftCertificate({
    required this.shiftId,
    required this.shiftLabel,
    required this.certifiedAt,
    required this.goldenSyssn,
    required this.goldenPcasn,
    required this.dutSerial,
    required this.fhiScore,
    required this.grade,
  });

  String get formattedCertifiedTime {
    final l = certifiedAt.toLocal();
    final hh = l.hour.toString().padLeft(2, '0');
    final mm = l.minute.toString().padLeft(2, '0');
    final ss = l.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  Map<String, dynamic> toJson() => {
    'shiftId': shiftId,
    'shiftLabel': shiftLabel,
    'certifiedAt': certifiedAt.toIso8601String(),
    'goldenSyssn': goldenSyssn,
    'goldenPcasn': goldenPcasn,
    'dutSerial': dutSerial,
    'fhiScore': fhiScore,
    'grade': grade.name,
  };

  factory ShiftCertificate.fromJson(Map<String, dynamic> json) {
    final score = (json['fhiScore'] as num?)?.toInt() ?? 0;
    return ShiftCertificate(
      shiftId: json['shiftId']?.toString() ?? '',
      shiftLabel: json['shiftLabel']?.toString() ?? '',
      certifiedAt:
          DateTime.tryParse(json['certifiedAt']?.toString() ?? '') ??
          DateTime.now(),
      goldenSyssn: json['goldenSyssn']?.toString() ?? 'N/A',
      goldenPcasn: json['goldenPcasn']?.toString() ?? 'N/A',
      dutSerial: json['dutSerial']?.toString() ?? '',
      fhiScore: score,
      grade: FixtureHealthGrade.fromScore(score),
    );
  }
}

class FixtureAuditReport {
  final DateTime timestamp;
  final String dutSerial;
  final String modelName;
  final String syssn;
  final String pcasn;
  final String syspn;
  final String shiftId;
  final String shiftLabel;
  final int fhiScore;
  final int powerGScore;
  final int srfScore;
  final int busStabilityScore;
  final int identityScore;
  final FixtureHealthGrade grade;
  final bool isRegisteredGolden;
  final bool isShiftCertified;
  final List<String> diagnosticsNotes;

  const FixtureAuditReport({
    required this.timestamp,
    required this.dutSerial,
    required this.modelName,
    required this.syssn,
    required this.pcasn,
    required this.syspn,
    required this.shiftId,
    required this.shiftLabel,
    required this.fhiScore,
    required this.powerGScore,
    required this.srfScore,
    required this.busStabilityScore,
    required this.identityScore,
    required this.grade,
    required this.isRegisteredGolden,
    required this.isShiftCertified,
    required this.diagnosticsNotes,
  });

  String get formattedDateTime {
    final l = timestamp.toLocal();
    final y = l.year.toString().padLeft(4, '0');
    final m = l.month.toString().padLeft(2, '0');
    final d = l.day.toString().padLeft(2, '0');
    final hh = l.hour.toString().padLeft(2, '0');
    final mm = l.minute.toString().padLeft(2, '0');
    final ss = l.second.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm:$ss';
  }

  String formatAuditCertificate() {
    final buf = StringBuffer();
    buf.writeln(
      '=== BIÊN BẢN KIỂM CHUẨN ĐỒ GÁ & BO MẪU ($appName v$appVersion) ===',
    );
    buf.writeln('Thời gian   : $formattedDateTime');
    buf.writeln('Ca sản xuất : $shiftLabel [$shiftId]');
    buf.writeln(
      'Chứng nhận  : ${isShiftCertified ? "ĐÃ CẤP CHỨNG CHỈ ĐẦU CA (SHIFT CERTIFIED)" : "CHƯA CHỨNG NHẬN CA"}',
    );
    buf.writeln('Điểm FHI    : $fhiScore/100 (${grade.label})');
    buf.writeln('  • PowerG RF      : $powerGScore/30');
    buf.writeln('  • SRF & Golden   : $srfScore/30');
    buf.writeln('  • Cáp USB / Pogo : $busStabilityScore/20');
    buf.writeln('  • Định danh BOM  : $identityScore/20');
    buf.writeln(
      'Bo đang đo  : $modelName | ADB: $dutSerial${isRegisteredGolden ? " [BO MẪU KGU]" : ""}',
    );
    buf.writeln('  • PCASN : $pcasn');
    buf.writeln('  • SYSSN : $syssn');
    buf.writeln('  • SYSPN : $syspn');
    buf.writeln('Chẩn đoán   :');
    for (final note in diagnosticsNotes) {
      buf.writeln('  - $note');
    }
    return buf.toString().trimRight();
  }
}

class GoldenAuditService extends ChangeNotifier {
  final String? storageFilePath;
  final List<GoldenBoardProfile> _goldenBoards = [];
  final Map<String, ShiftCertificate> _shiftCertificates = {};
  FixtureAuditReport? _latestReport;
  bool _latestRfComplete = false;

  GoldenAuditService({this.storageFilePath = 'logs/golden_audit_state.json'});

  List<GoldenBoardProfile> get goldenBoards => List.unmodifiable(_goldenBoards);
  FixtureAuditReport? get latestReport => _latestReport;

  /// Resolves the production shift ID for a given timestamp.
  /// Day Shift: 07:30 <= t < 19:30 -> YYYY-MM-DD_DAY
  /// Night Shift: 19:30 <= t < 07:30 (next day) -> YYYY-MM-DD_NIGHT
  static String resolveShiftId(DateTime time) {
    final local = time.toLocal();
    final minutes = local.hour * 60 + local.minute;
    final isDay = minutes >= 450 && minutes < 1170;
    final shiftDate = minutes < 450
        ? DateTime(
            local.year,
            local.month,
            local.day,
          ).subtract(const Duration(days: 1))
        : DateTime(local.year, local.month, local.day);
    final y = shiftDate.year.toString().padLeft(4, '0');
    final m = shiftDate.month.toString().padLeft(2, '0');
    final d = shiftDate.day.toString().padLeft(2, '0');
    return '$y-$m-${d}_${isDay ? "DAY" : "NIGHT"}';
  }

  static String resolveShiftLabel(DateTime time) {
    final local = time.toLocal();
    final minutes = local.hour * 60 + local.minute;
    final isDay = minutes >= 450 && minutes < 1170;
    return isDay ? 'Ca Ngày (07:30–19:30)' : 'Ca Đêm (19:30–07:30)';
  }

  ShiftCertificate? currentShiftCertificate({DateTime? now}) {
    final shiftId = resolveShiftId(now ?? DateTime.now());
    return _shiftCertificates[shiftId];
  }

  bool isCurrentShiftCertified({DateTime? now}) =>
      currentShiftCertificate(now: now) != null;

  GoldenBoardProfile? findMatchingGolden({
    required String syssn,
    required String pcasn,
  }) {
    for (final profile in _goldenBoards) {
      if (profile.matches(syssn: syssn, pcasn: pcasn)) {
        return profile;
      }
    }
    return null;
  }

  bool isRegisteredGoldenBoard({
    required String syssn,
    required String pcasn,
  }) => findMatchingGolden(syssn: syssn, pcasn: pcasn) != null;

  /// Registers or updates a Golden KGU board profile in the whitelist.
  GoldenBoardProfile registerGoldenBoard({
    required String syssn,
    required String pcasn,
    required String syspn,
    required String modelName,
    int baselinePowerGMs = 0,
    int baselineSrfMs = 0,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final profile = GoldenBoardProfile(
      syssn: syssn.trim().isEmpty ? 'N/A' : syssn.trim(),
      pcasn: pcasn.trim().isEmpty ? 'N/A' : pcasn.trim(),
      syspn: syspn.trim().isEmpty ? 'N/A' : syspn.trim(),
      modelName: modelName.trim().isEmpty ? 'DUT' : modelName.trim(),
      baselinePowerGMs: baselinePowerGMs,
      baselineSrfMs: baselineSrfMs,
      registeredAt: timestamp,
    );

    _goldenBoards.removeWhere((p) => p.matches(syssn: syssn, pcasn: pcasn));
    _goldenBoards.insert(0, profile);

    // Registration can only certify completed evidence from this same shift.
    if (_latestReport != null &&
        profile.matches(
          syssn: _latestReport!.syssn,
          pcasn: _latestReport!.pcasn,
        )) {
      final shiftId = resolveShiftId(timestamp);
      final shiftLabel = resolveShiftLabel(timestamp);
      if (_latestRfComplete &&
          _latestReport!.shiftId == shiftId &&
          !_latestReport!.timestamp.isAfter(timestamp) &&
          _latestReport!.fhiScore >= 85) {
        _shiftCertificates[shiftId] = ShiftCertificate(
          shiftId: shiftId,
          shiftLabel: shiftLabel,
          certifiedAt: timestamp,
          goldenSyssn: profile.syssn,
          goldenPcasn: profile.pcasn,
          dutSerial: _latestReport!.dutSerial,
          fhiScore: _latestReport!.fhiScore,
          grade: _latestReport!.grade,
        );
      }
      _latestReport = FixtureAuditReport(
        timestamp: _latestReport!.timestamp,
        dutSerial: _latestReport!.dutSerial,
        modelName: _latestReport!.modelName,
        syssn: _latestReport!.syssn,
        pcasn: _latestReport!.pcasn,
        syspn: _latestReport!.syspn,
        shiftId: _latestReport!.shiftId,
        shiftLabel: _latestReport!.shiftLabel,
        fhiScore: _latestReport!.fhiScore,
        powerGScore: _latestReport!.powerGScore,
        srfScore: _latestReport!.srfScore,
        busStabilityScore: _latestReport!.busStabilityScore,
        identityScore: _latestReport!.identityScore,
        grade: _latestReport!.grade,
        isRegisteredGolden: true,
        isShiftCertified: _shiftCertificates.containsKey(
          _latestReport!.shiftId,
        ),
        diagnosticsNotes: _latestReport!.diagnosticsNotes,
      );
    }

    _persistSyncSafe();
    notifyListeners();
    return profile;
  }

  /// Removes a Golden KGU board profile from the whitelist.
  bool unregisterGoldenBoard({required String syssn, required String pcasn}) {
    final before = _goldenBoards.length;
    _goldenBoards.removeWhere((p) => p.matches(syssn: syssn, pcasn: pcasn));
    final removed = _goldenBoards.length != before;
    if (removed) {
      if (_latestReport != null &&
          _latestReport!.isRegisteredGolden &&
          !isRegisteredGoldenBoard(
            syssn: _latestReport!.syssn,
            pcasn: _latestReport!.pcasn,
          )) {
        _latestReport = FixtureAuditReport(
          timestamp: _latestReport!.timestamp,
          dutSerial: _latestReport!.dutSerial,
          modelName: _latestReport!.modelName,
          syssn: _latestReport!.syssn,
          pcasn: _latestReport!.pcasn,
          syspn: _latestReport!.syspn,
          shiftId: _latestReport!.shiftId,
          shiftLabel: _latestReport!.shiftLabel,
          fhiScore: _latestReport!.fhiScore,
          powerGScore: _latestReport!.powerGScore,
          srfScore: _latestReport!.srfScore,
          busStabilityScore: _latestReport!.busStabilityScore,
          identityScore: _latestReport!.identityScore,
          grade: _latestReport!.grade,
          isRegisteredGolden: false,
          isShiftCertified: _latestReport!.isShiftCertified,
          diagnosticsNotes: _latestReport!.diagnosticsNotes,
        );
      }
      _persistSyncSafe();
      notifyListeners();
    }
    return removed;
  }

  /// Computes the 4-pillar Fixture Health Index (FHI: 0–100%) and updates
  /// shift handover certification if a registered Golden KGU board passes (>= 85%).
  FixtureAuditReport evaluateDut({
    required String dutSerial,
    required String modelName,
    required Map<String, String> info,
    PowerGResult? powerGResult,
    SrfResult? srfResult,
    String? goldenPanelSerial,
    int eepromRetryCount = 0,
    int bootWaitMs = 0,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final shiftId = resolveShiftId(timestamp);
    final shiftLabel = resolveShiftLabel(timestamp);
    final syssn = (info['SYSSN'] ?? 'N/A').trim();
    final pcasn = (info['PCASN'] ?? 'N/A').trim();
    final syspn = (info['SYSPN'] ?? 'N/A').trim();
    final imei = (info['IMEI'] ?? 'N/A').trim();
    final cpu = (info['CPU'] ?? 'N/A').trim();

    final matchedGolden = findMatchingGolden(syssn: syssn, pcasn: pcasn);
    final isGolden = matchedGolden != null;
    final notes = <String>[];

    // 1. PowerG Link Health (0–30 points)
    int pgScore = 15;
    if (powerGResult == null || powerGResult.status == PowerGStatus.testing) {
      pgScore = 15;
      notes.add('Đang chờ kết quả kiểm tra sóng PowerG...');
    } else if (powerGResult.status == PowerGStatus.pass) {
      pgScore = 30;
      if (powerGResult.pollAttempts > 2) {
        final penalty = ((powerGResult.pollAttempts - 2) * 2).clamp(0, 10);
        pgScore -= penalty;
        notes.add(
          'PowerG phải poll ${powerGResult.pollAttempts} vòng mới thu được gói — Kiểm tra vị trí ăng-ten / suy hao buồng chắn.',
        );
      }
      if (powerGResult.durationMs > 4500) {
        pgScore -= 4;
        notes.add(
          'Thời gian thu sóng PowerG kéo dài (${(powerGResult.durationMs / 1000).toStringAsFixed(1)}s > 4.5s) — Kiểm tra khoảng cách bộ phát TX.',
        );
      } else if (powerGResult.durationMs > 2500) {
        pgScore -= 2;
      }
      if (matchedGolden != null &&
          matchedGolden.baselinePowerGMs > 0 &&
          powerGResult.durationMs > matchedGolden.baselinePowerGMs + 2000) {
        pgScore -= 2;
      }
      pgScore = pgScore.clamp(18, 30);
    } else if (powerGResult.status == PowerGStatus.mcuOk) {
      final isIq5Model = modelName.toUpperCase().contains('IQ5');
      if (isIq5Model) {
        pgScore = powerGResult.pollAttempts > 1 ? 24 : 28;
        if (powerGResult.pollAttempts > 1) {
          notes.add(
            'PowerG V4 phải thử lại giao thức Bootload/Node — Kiểm tra tiếp xúc khe cắm PowerG.',
          );
        }
      } else {
        pgScore = 22;
        notes.add(
          'PowerG đạt MCU OK nhưng chưa gắn hộp phát RF TX ngoài để đo thu sóng.',
        );
      }
    } else if (powerGResult.status == PowerGStatus.notInstalled) {
      if (srfResult != null &&
          (srfResult.isPass || srfResult.status == SrfStatus.mcuOk)) {
        pgScore = 26;
      } else {
        pgScore = 15;
        notes.add('Không phát hiện card PowerG trên thiết bị.');
      }
    } else {
      pgScore = 0;
      notes.add(
        'LỖI PowerG (${powerGResult.message}) — Kiểm tra card PowerG, ăng-ten đồ gá hoặc bộ phát TX.',
      );
    }

    // 2. SRF & Golden Panel Health (0–30 points)
    int srfScore = 15;
    if (srfResult == null || srfResult.status == SrfStatus.testing) {
      srfScore = 15;
      notes.add('Đang chờ kết quả kiểm tra sóng SRF...');
    } else if (srfResult.status == SrfStatus.pass) {
      srfScore = 30;
      if (srfResult.mcuPingRetries > 0) {
        final penalty = (srfResult.mcuPingRetries * 4).clamp(0, 10);
        srfScore -= penalty;
        notes.add(
          'MCU PIC trên card SRF phải ping thử lại (${srfResult.mcuPingRetries} lần) — Kiểm tra chân cắm UART / nguồn.',
        );
      }
      if (srfResult.durationMs > 6000) {
        srfScore -= 4;
        notes.add(
          'Thời gian thu 5 gói SRF kéo dài (${(srfResult.durationMs / 1000).toStringAsFixed(1)}s) — Kiểm tra ăng-ten SRF trên Golden Panel.',
        );
      } else if (srfResult.durationMs > 3500) {
        srfScore -= 2;
      }
      srfScore = srfScore.clamp(18, 30);
    } else if (srfResult.status == SrfStatus.mcuOk) {
      srfScore = (22 - (srfResult.mcuPingRetries * 3).clamp(0, 8)).clamp(
        14,
        22,
      );
      if (goldenPanelSerial == null || goldenPanelSerial.isEmpty) {
        notes.add(
          'Chưa kết nối Golden Panel phát mẫu SRF (chỉ kiểm tra MCU PIC).',
        );
      }
    } else if (srfResult.status == SrfStatus.notInstalled) {
      if (powerGResult != null &&
          (powerGResult.isPass || powerGResult.status == PowerGStatus.mcuOk)) {
        // Single-RF SKU (e.g. IQ5 Remote with PowerG only)
        srfScore = 27;
      } else {
        srfScore = 15;
        notes.add('Không phát hiện card SRF trên thiết bị.');
      }
    } else if (srfResult.status == SrfStatus.goldenError) {
      srfScore = 5;
      notes.add(
        'LỖI GOLDEN PANEL (${srfResult.message}) — Kiểm tra thẻ SRF Rev 2 trên Golden Panel.',
      );
    } else {
      srfScore = 0;
      notes.add(
        'LỖI thu sóng SRF (${srfResult.message}) — Kiểm tra ăng-ten SRF hoặc vị trí đặt Golden Panel.',
      );
    }

    // 3. USB Bus & Pogo-Pin Stability (0–20 points)
    int busScore = 20;
    if (eepromRetryCount > 0) {
      final penalty = (eepromRetryCount * 3).clamp(0, 12);
      busScore -= penalty;
      notes.add(
        'Đọc EEPROM phải thử lại $eepromRetryCount lần — Kiểm tra chân kim Pogo nguồn VDD hoặc cáp USB.',
      );
    }
    if (bootWaitMs > 25000) {
      busScore -= 6;
      notes.add(
        'Thời gian chờ boot kéo dài (${(bootWaitMs / 1000).toStringAsFixed(1)}s) — Kiểm tra độ sụt áp nguồn đồ gá.',
      );
    } else if (bootWaitMs > 12000) {
      busScore -= 3;
    }
    busScore = busScore.clamp(0, 20);

    // 4. Identity & Golden BOM Integrity (0–20 points)
    int idScore = 20;
    if (DutValidator.hasModelMismatch(info)) {
      idScore -= 15;
      notes.add(
        'SAI LỆCH DÒNG MÁY giữa PCASN ($pcasn) và SYSSN/SYSPN ($syssn / $syspn)!',
      );
    }
    if (pcasn.isEmpty || pcasn == 'N/A' || pcasn.startsWith('Đang')) {
      idScore -= 8;
    }
    if (syssn == 'Chưa test MMI' ||
        syspn == 'Chưa test MMI' ||
        syssn == 'N/A' ||
        syspn == 'N/A') {
      idScore -= 5;
      notes.add('Thiết bị chưa nạp đủ SYSSN / SYSPN (Chưa test MMI).');
    }
    if (imei != 'N/A' &&
        !imei.startsWith('Đang') &&
        !DutValidator.isValidImei(imei)) {
      idScore -= 5;
      notes.add('Số IMEI ($imei) sai chuẩn kiểm tra Luhn.');
    }
    if (DutValidator.isFieldWarning('CPU', cpu, info)) {
      idScore -= 4;
      notes.add('Thông số Baseband/CPU chưa hợp lệ ($cpu).');
    }
    if (matchedGolden != null &&
        matchedGolden.syspn != 'N/A' &&
        syspn != 'N/A' &&
        !syspn.startsWith('Đang') &&
        matchedGolden.syspn.toUpperCase() != syspn.toUpperCase()) {
      idScore -= 6;
      notes.add(
        'SYSPN hiện tại ($syspn) lệch với hồ sơ Bo Mẫu đã đăng ký (${matchedGolden.syspn}).',
      );
    }
    idScore = idScore.clamp(0, 20);

    final totalScore = (pgScore + srfScore + busScore + idScore).clamp(0, 100);
    final grade = FixtureHealthGrade.fromScore(totalScore);

    if (notes.isEmpty) {
      notes.add(
        'Đồ gá, cáp USB/Pogo và thu phát sóng RF hoạt động ổn định, đạt chuẩn sản xuất.',
      );
    }

    // A provisional score is not completed RF evidence. A card reported absent
    // is a finished check; null/testing means that check is still outstanding.
    final rfComplete =
        powerGResult != null &&
        powerGResult.status != PowerGStatus.testing &&
        srfResult != null &&
        srfResult.status != SrfStatus.testing;
    if (isGolden && rfComplete && grade == FixtureHealthGrade.certified) {
      _shiftCertificates[shiftId] = ShiftCertificate(
        shiftId: shiftId,
        shiftLabel: shiftLabel,
        certifiedAt: timestamp,
        goldenSyssn: matchedGolden.syssn,
        goldenPcasn: matchedGolden.pcasn,
        dutSerial: dutSerial,
        fhiScore: totalScore,
        grade: grade,
      );
      _persistSyncSafe();
    }

    final report = FixtureAuditReport(
      timestamp: timestamp,
      dutSerial: dutSerial,
      modelName: modelName,
      syssn: syssn,
      pcasn: pcasn,
      syspn: syspn,
      shiftId: shiftId,
      shiftLabel: shiftLabel,
      fhiScore: totalScore,
      powerGScore: pgScore,
      srfScore: srfScore,
      busStabilityScore: busScore,
      identityScore: idScore,
      grade: grade,
      isRegisteredGolden: isGolden,
      isShiftCertified: _shiftCertificates.containsKey(shiftId),
      diagnosticsNotes: notes,
    );

    _latestReport = report;
    _latestRfComplete = rfComplete;
    notifyListeners();
    return report;
  }

  void clearLatestReport() {
    _latestReport = null;
    _latestRfComplete = false;
    notifyListeners();
  }

  void loadFromDiskSyncSafe() {
    final path = storageFilePath;
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (!file.existsSync()) return;
      final content = file.readAsStringSync();
      final decoded = jsonDecode(content);
      if (decoded is Map) {
        final rawBoards = decoded['goldenBoards'];
        if (rawBoards is List) {
          _goldenBoards
            ..clear()
            ..addAll(
              rawBoards.whereType<Map>().map(
                (m) =>
                    GoldenBoardProfile.fromJson(Map<String, dynamic>.from(m)),
              ),
            );
        }
        final rawCerts = decoded['shiftCertificates'];
        if (rawCerts is Map) {
          _shiftCertificates.clear();
          for (final entry in rawCerts.entries) {
            if (entry.value is Map) {
              _shiftCertificates[entry.key
                  .toString()] = ShiftCertificate.fromJson(
                Map<String, dynamic>.from(entry.value as Map),
              );
            }
          }
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  void _persistSyncSafe() {
    final path = storageFilePath;
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      file.parent.createSync(recursive: true);
      final data = {
        'goldenBoards': _goldenBoards.map((b) => b.toJson()).toList(),
        'shiftCertificates': _shiftCertificates.map(
          (k, v) => MapEntry(k, v.toJson()),
        ),
      };
      file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
    } catch (_) {}
  }
}
