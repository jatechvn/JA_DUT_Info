// lib/modules/services/dut_history_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../constants.dart';

class DutHistoryEntry {
  final DateTime timestamp;
  final String serial;
  final String modelName;
  final String stationResult;
  final Map<String, String> info;
  final String powerGSummary;
  final String srfSummary;
  final bool isRfPass;

  const DutHistoryEntry({
    required this.timestamp,
    required this.serial,
    required this.modelName,
    required this.stationResult,
    required this.info,
    required this.powerGSummary,
    required this.srfSummary,
    required this.isRfPass,
  });

  String get syssn => info['SYSSN'] ?? 'N/A';
  String get pcasn => info['PCASN'] ?? 'N/A';
  String get syspn => info['SYSPN'] ?? 'N/A';
  String get lcmpn => info['LCMPN'] ?? 'N/A';
  String get imei => info['IMEI'] ?? 'N/A';
  String get cpu => info['CPU'] ?? 'N/A';

  String get formattedTime {
    final l = timestamp.toLocal();
    final hh = l.hour.toString().padLeft(2, '0');
    final mm = l.minute.toString().padLeft(2, '0');
    final ss = l.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  String get formattedDateTime {
    final l = timestamp.toLocal();
    final y = l.year.toString().padLeft(4, '0');
    final m = l.month.toString().padLeft(2, '0');
    final d = l.day.toString().padLeft(2, '0');
    return '$y-$m-$d $formattedTime';
  }

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'serial': serial,
    'modelName': modelName,
    'stationResult': stationResult,
    'info': info,
    'powerGSummary': powerGSummary,
    'srfSummary': srfSummary,
    'isRfPass': isRfPass,
  };

  factory DutHistoryEntry.fromJson(Map<String, dynamic> json) {
    final rawInfo = json['info'];
    final parsedInfo = <String, String>{};
    if (rawInfo is Map) {
      for (final e in rawInfo.entries) {
        parsedInfo[e.key.toString()] = e.value?.toString() ?? 'N/A';
      }
    }
    return DutHistoryEntry(
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      serial: json['serial']?.toString() ?? '',
      modelName: json['modelName']?.toString() ?? 'DUT',
      stationResult: json['stationResult']?.toString() ?? 'N/A',
      info: parsedInfo,
      powerGSummary: json['powerGSummary']?.toString() ?? 'N/A',
      srfSummary: json['srfSummary']?.toString() ?? 'N/A',
      isRfPass: json['isRfPass'] == true,
    );
  }

  String formatReport() {
    final buf = StringBuffer();
    buf.writeln('[$appName v$appVersion - $modelName] $formattedDateTime');
    buf.writeln('ADB Serial : $serial');
    buf.writeln('Station    : $stationResult');
    buf.writeln('PCASN      : $pcasn');
    buf.writeln('SYSSN      : $syssn');
    buf.writeln('SYSPN      : $syspn');
    buf.writeln('LCMPN      : $lcmpn');
    buf.writeln('IMEI       : $imei');
    buf.writeln('CPU        : $cpu');
    buf.writeln('PowerG     : $powerGSummary');
    buf.writeln('SRF        : $srfSummary');
    return buf.toString().trimRight();
  }
}

class DutHistoryService extends ChangeNotifier {
  static const int maxEntries = 30;
  final List<DutHistoryEntry> _entries = [];
  final String? storageFilePath;

  DutHistoryService({this.storageFilePath = 'logs/dut_history.json'});

  List<DutHistoryEntry> get entries => List.unmodifiable(_entries);
  int get count => _entries.length;

  /// Records or updates the snapshot for a connected DUT.
  /// If the most recent entry belongs to the same ADB serial (or matching non-empty PCASN),
  /// it is updated in-place at index 0; otherwise, any older entry for the same
  /// PCASN/serial is replaced and moved to index 0.
  void recordSnapshot({
    required String serial,
    required String modelName,
    required String stationResult,
    required Map<String, String> info,
    required String powerGSummary,
    required String srfSummary,
    required bool isRfPass,
    DateTime? timestamp,
  }) {
    if (serial.trim().isEmpty) return;
    final pcasn = (info['PCASN'] ?? '').trim();
    if (pcasn.isEmpty || pcasn == 'Đang đọc...') return;

    final entry = DutHistoryEntry(
      timestamp: timestamp ?? DateTime.now(),
      serial: serial,
      modelName: modelName,
      stationResult: stationResult,
      info: Map<String, String>.from(info),
      powerGSummary: powerGSummary,
      srfSummary: srfSummary,
      isRfPass: isRfPass,
    );

    final existingIdx = _entries.indexWhere((e) {
      if (pcasn != 'N/A' && e.pcasn == pcasn) return true;
      return e.serial == serial && e.pcasn == pcasn;
    });

    if (existingIdx == 0) {
      _entries[0] = entry;
    } else {
      if (existingIdx > 0) {
        _entries.removeAt(existingIdx);
      }
      _entries.insert(0, entry);
      if (_entries.length > maxEntries) {
        _entries.removeRange(maxEntries, _entries.length);
      }
    }

    _persistSyncSafe();
    notifyListeners();
  }

  void clearHistory() {
    _entries.clear();
    _persistSyncSafe();
    notifyListeners();
  }

  String formatAllHistoryReport() {
    if (_entries.isEmpty) return 'Chưa có lịch sử DUT trong phiên.';
    return _entries.map((e) => e.formatReport()).join('\n${'-' * 48}\n');
  }

  void loadFromDiskSyncSafe() {
    final path = storageFilePath;
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (!file.existsSync()) return;
      final content = file.readAsStringSync();
      final decoded = jsonDecode(content);
      if (decoded is List) {
        _entries
          ..clear()
          ..addAll(
            decoded
                .whereType<Map>()
                .take(maxEntries)
                .map(
                  (m) => DutHistoryEntry.fromJson(Map<String, dynamic>.from(m)),
                ),
          );
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
      final encoded = jsonEncode(_entries.map((e) => e.toJson()).toList());
      file.writeAsStringSync(encoded);
    } catch (_) {}
  }
}
