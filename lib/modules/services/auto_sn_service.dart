// lib/modules/services/auto_sn_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../logger_config.dart';
import '../utils.dart';
import 'command_scope.dart';

/// Một biểu mẫu (Form) nhận diện SN và quy tắc tạo mã PN trong `auto_sn_config.json`.
class AutoSnFormRule {
  final String name;
  final bool enabled;
  final String snRegex;
  final String pnPrefix;
  final int snTakeLength;
  final bool keepSuffix;
  final String fixedPn;

  const AutoSnFormRule({
    required this.name,
    this.enabled = true,
    required this.snRegex,
    this.pnPrefix = 'I',
    this.snTakeLength = 6,
    this.keepSuffix = true,
    this.fixedPn = '',
  });

  factory AutoSnFormRule.fromJson(Map<String, dynamic> json) {
    return AutoSnFormRule(
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : 'Unnamed SN Form',
      enabled: json['enabled'] as bool? ?? true,
      snRegex:
          (json['sn_regex'] as String?)?.trim() ??
          r'^(QP[A-Z0-9]{17})(-[A-Z]{3})?(\^)?$',
      pnPrefix: (json['pn_prefix'] as String?) ?? 'I',
      snTakeLength: (json['sn_take_length'] as num?)?.toInt() ?? 6,
      keepSuffix: json['keep_suffix'] as bool? ?? true,
      fixedPn: (json['fixed_pn'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'enabled': enabled,
    'sn_regex': snRegex,
    'pn_prefix': pnPrefix,
    'sn_take_length': snTakeLength,
    'keep_suffix': keepSuffix,
    'fixed_pn': fixedPn,
  };
}

/// Cấu hình tổng thể của module AutoSN (`auto_sn_config.json`).
class AutoSnConfig {
  final bool enabled;
  final String targetProcess;
  final String comPortKeyword;
  final int comWaitTimeoutSec;
  final int adbWaitTimeoutSec;
  final bool appendCaret;
  final List<String> skipClipboardContains;
  final Map<String, String> prefixOverrides;
  final List<AutoSnFormRule> forms;

  const AutoSnConfig({
    required this.enabled,
    required this.targetProcess,
    required this.comPortKeyword,
    required this.comWaitTimeoutSec,
    required this.adbWaitTimeoutSec,
    required this.appendCaret,
    required this.skipClipboardContains,
    required this.prefixOverrides,
    required this.forms,
  });

  factory AutoSnConfig.defaults() {
    return const AutoSnConfig(
      enabled: true,
      targetProcess: 'javaw.exe',
      comPortKeyword: 'Qualcomm HS-USB Diagnostics 9091',
      comWaitTimeoutSec: 30,
      adbWaitTimeoutSec: 60,
      appendCaret: true,
      skipClipboardContains: ['1\tPanelTamper'],
      prefixOverrides: {'EXAMPLE_QP9999': 'IQP9999-SPECIAL'},
      forms: [
        AutoSnFormRule(
          name:
              'Form Chuẩn Qolsys QP (19 ký tự + hậu tố tùy chọn, VD: QP4001xxxxxxxxxxxxx-USA)',
          enabled: true,
          snRegex: r'^(QP[A-Z0-9]{17})(-[A-Z]{3})?(\^)?$',
          pnPrefix: 'I',
          snTakeLength: 6,
          keepSuffix: true,
          fixedPn: '',
        ),
        AutoSnFormRule(
          name: 'Form Dự Phòng Qolsys QH (19 ký tự + hậu tố tùy chọn)',
          enabled: false,
          snRegex: r'^(QH[A-Z0-9]{17})(-[A-Z]{3})?(\^)?$',
          pnPrefix: 'I',
          snTakeLength: 6,
          keepSuffix: true,
          fixedPn: '',
        ),
      ],
    );
  }

  AutoSnConfig copyWith({bool? enabled}) {
    return AutoSnConfig(
      enabled: enabled ?? this.enabled,
      targetProcess: targetProcess,
      comPortKeyword: comPortKeyword,
      comWaitTimeoutSec: comWaitTimeoutSec,
      adbWaitTimeoutSec: adbWaitTimeoutSec,
      appendCaret: appendCaret,
      skipClipboardContains: skipClipboardContains,
      prefixOverrides: prefixOverrides,
      forms: forms,
    );
  }

  factory AutoSnConfig.fromJson(Map<String, dynamic> json) {
    final defaults = AutoSnConfig.defaults();
    final rawSkip = json['skip_clipboard_contains'];
    final skipList = rawSkip is List
        ? rawSkip
              .map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList(growable: false)
        : defaults.skipClipboardContains;

    final rawOverrides = json['prefix_overrides'];
    final overrides = <String, String>{};
    if (rawOverrides is Map) {
      for (final entry in rawOverrides.entries) {
        final k = entry.key.toString().trim();
        final v = entry.value?.toString().trim() ?? '';
        if (k.isNotEmpty && v.isNotEmpty) {
          overrides[k] = v;
        }
      }
    } else {
      overrides.addAll(defaults.prefixOverrides);
    }

    final rawForms = json['forms'];
    final parsedForms = <AutoSnFormRule>[];
    if (rawForms is List) {
      for (final item in rawForms) {
        if (item is Map) {
          parsedForms.add(
            AutoSnFormRule.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return AutoSnConfig(
      enabled: json['enabled'] as bool? ?? defaults.enabled,
      targetProcess:
          (json['target_process'] as String?)?.trim().isNotEmpty == true
          ? (json['target_process'] as String).trim()
          : defaults.targetProcess,
      comPortKeyword:
          (json['com_port_keyword'] as String?)?.trim().isNotEmpty == true
          ? (json['com_port_keyword'] as String).trim()
          : defaults.comPortKeyword,
      comWaitTimeoutSec:
          ((json['com_wait_timeout_sec'] as num?)?.toInt() ??
                  defaults.comWaitTimeoutSec)
              .clamp(5, 300),
      adbWaitTimeoutSec:
          ((json['adb_wait_timeout_sec'] as num?)?.toInt() ??
                  defaults.adbWaitTimeoutSec)
              .clamp(5, 300),
      appendCaret: json['append_caret'] as bool? ?? defaults.appendCaret,
      skipClipboardContains: skipList,
      prefixOverrides: overrides,
      forms: parsedForms.isNotEmpty ? parsedForms : defaults.forms,
    );
  }

  Map<String, dynamic> toJson() => {
    '_comment':
        'Cấu hình Tự động nhận diện SN & điền PN cho javaw.exe. Sửa file này và bấm Lưu (Ctrl+S) sẽ có hiệu lực ngay ở lần nhấn Enter tiếp theo mà không cần khởi động lại app.',
    'enabled': enabled,
    'target_process': targetProcess,
    'com_port_keyword': comPortKeyword,
    'com_wait_timeout_sec': comWaitTimeoutSec,
    'adb_wait_timeout_sec': adbWaitTimeoutSec,
    'append_caret': appendCaret,
    'skip_clipboard_contains': skipClipboardContains,
    'prefix_overrides': {
      '_comment':
          'Tùy chọn: Nếu mã SN bắt đầu bằng khóa dưới đây thì ưu tiên lấy thẳng mã PN chỉ định (vẫn tự ghép hậu tố -XXX nếu có).',
      for (final entry in prefixOverrides.entries)
        if (entry.key != '_comment') entry.key: entry.value,
    },
    'forms': forms.map((f) => f.toJson()).toList(),
  };
}

/// Kết quả kiểm tra chuỗi SN đọc từ Clipboard theo cấu hình `AutoSnConfig`.
class AutoSnMatchResult {
  final bool isEmpty;
  final bool isValid;
  final String rawInput;
  final String snCore;
  final String suffix;
  final String generatedPn;
  final bool hadCaret;
  final String matchedFormName;

  const AutoSnMatchResult._({
    required this.isEmpty,
    required this.isValid,
    required this.rawInput,
    this.snCore = '',
    this.suffix = '',
    this.generatedPn = '',
    this.hadCaret = false,
    this.matchedFormName = '',
  });

  factory AutoSnMatchResult.empty() =>
      const AutoSnMatchResult._(isEmpty: true, isValid: false, rawInput: '');

  factory AutoSnMatchResult.invalid(String raw) =>
      AutoSnMatchResult._(isEmpty: false, isValid: false, rawInput: raw);

  factory AutoSnMatchResult.valid({
    required String rawInput,
    required String snCore,
    required String suffix,
    required String generatedPn,
    required bool hadCaret,
    required String matchedFormName,
  }) => AutoSnMatchResult._(
    isEmpty: false,
    isValid: true,
    rawInput: rawInput,
    snCore: snCore,
    suffix: suffix,
    generatedPn: generatedPn,
    hadCaret: hadCaret,
    matchedFormName: matchedFormName,
  );
}

/// Hàm thuần kiểm tra chuỗi SN với danh sách `forms` và `prefix_overrides` trong `AutoSnConfig`.
AutoSnMatchResult evaluateSnWithConfig(String rawClipboard, AutoSnConfig cfg) {
  final txt = rawClipboard.trim();
  if (txt.isEmpty) {
    return AutoSnMatchResult.empty();
  }

  for (final form in cfg.forms) {
    if (!form.enabled || form.snRegex.trim().isEmpty) continue;
    RegExp reg;
    try {
      reg = RegExp(form.snRegex.trim());
    } catch (e) {
      logger.warning('[AutoSN] Invalid regex in form "${form.name}": $e');
      continue;
    }

    final match = reg.firstMatch(txt);
    if (match == null) continue;

    final hadCaret = txt.endsWith('^');
    String snCore = '';
    String suffix = '';

    if (match.groupCount >= 1 && (match.group(1)?.isNotEmpty ?? false)) {
      snCore = match.group(1)!;
      if (match.groupCount >= 2 && match.group(2) != null) {
        final g2 = match.group(2)!;
        if (g2 != '^') {
          suffix = g2;
        }
      }
    } else {
      var whole = match.group(0) ?? txt;
      if (whole.endsWith('^')) {
        whole = whole.substring(0, whole.length - 1);
      }
      final dashIdx = whole.indexOf('-');
      if (dashIdx > 0) {
        snCore = whole.substring(0, dashIdx);
        suffix = whole.substring(dashIdx);
      } else {
        snCore = whole;
      }
    }

    if (snCore.isEmpty) continue;

    // 1. Check prefix_overrides first
    String? overridePn;
    final snUpper = snCore.toUpperCase();
    for (final entry in cfg.prefixOverrides.entries) {
      final key = entry.key.trim();
      if (key.isEmpty ||
          key.startsWith('_') ||
          key.toUpperCase() == 'COMMENT' ||
          key.toUpperCase().startsWith('EXAMPLE_')) {
        continue;
      }
      if (snUpper.startsWith(key.toUpperCase())) {
        overridePn = entry.value.trim();
        break;
      }
    }

    String generatedPn;
    if (overridePn != null && overridePn.isNotEmpty) {
      generatedPn = (form.keepSuffix && !overridePn.contains('-'))
          ? '$overridePn$suffix'
          : overridePn;
    } else if (form.fixedPn.isNotEmpty) {
      generatedPn = (form.keepSuffix && !form.fixedPn.contains('-'))
          ? '${form.fixedPn}$suffix'
          : form.fixedPn;
    } else {
      final takeLen = form.snTakeLength.clamp(0, snCore.length);
      final snPrefix = snCore.substring(0, takeLen);
      generatedPn = '${form.pnPrefix}$snPrefix${form.keepSuffix ? suffix : ""}';
    }

    return AutoSnMatchResult.valid(
      rawInput: txt,
      snCore: snCore,
      suffix: suffix,
      generatedPn: generatedPn,
      hadCaret: hadCaret,
      matchedFormName: form.name,
    );
  }

  return AutoSnMatchResult.invalid(txt);
}

/// Biểu diễn một dòng thiết bị USB trong kết quả `adb devices`.
class AdbUsbDeviceEntry {
  final String serial;
  final String state; // 'device', 'unauthorized', 'offline', etc.

  const AdbUsbDeviceEntry({required this.serial, required this.state});

  bool get isAuthorized => state == 'device';
  bool get isUnauthorized => state == 'unauthorized';
}

/// Tách danh sách thiết bị USB từ output của `adb devices` (bỏ qua kết nối TCP/IP có dấu `:`).
List<AdbUsbDeviceEntry> parseAdbUsbDevices(String adbDevicesOutput) {
  final lines = adbDevicesOutput
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  final entries = <AdbUsbDeviceEntry>[];
  for (final line in lines) {
    if (line.toLowerCase().startsWith('list of devices') ||
        line.startsWith('*')) {
      continue;
    }
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length < 2) continue;
    final serial = parts[0].trim();
    final state = parts[1].trim();
    if (serial.isEmpty || serial.contains(':')) {
      // Skip wireless TCP/IP ADB entries (e.g. 192.168.1.5:5555)
      continue;
    }
    if (state == 'device' || state == 'unauthorized') {
      entries.add(AdbUsbDeviceEntry(serial: serial, state: state));
    }
  }
  return entries;
}

enum Step2DecisionType {
  waitForDut,
  foundTargetDut,
  retryAmbiguousDualDut,
  abortTooManyDevices,
}

class Step2Decision {
  final Step2DecisionType type;
  final String? targetDut;
  final String? goldenSerial;
  final bool isTargetAuthorized;
  final String statusMessage;

  const Step2Decision({
    required this.type,
    this.targetDut,
    this.goldenSerial,
    this.isTargetAuthorized = false,
    required this.statusMessage,
  });
}

/// Phân loại thiết bị ở Bước 2:
/// - Luôn loại trừ mọi thiết bị có `persist.auto.run == '1'` (Golden Panel), kể cả khi chỉ có 1 thiết bị.
/// - Nhận diện cả thiết bị DUT đang ở trạng thái `unauthorized` hoặc `device`.
Step2Decision classifyStep2UsbDevices({
  required List<AdbUsbDeviceEntry> usbEntries,
  required Map<String, String> autoRunBySerial,
  required Map<String, String> hwSerialBySerial,
  required int comPortCount,
}) {
  if (usbEntries.isEmpty) {
    return const Step2Decision(
      type: Step2DecisionType.waitForDut,
      statusMessage: '⏳ [AutoSN] Đang đợi ADB nhận thiết bị DUT...',
    );
  }

  String? goldenSerial;
  final dutCandidates = <AdbUsbDeviceEntry>[];

  for (final entry in usbEntries) {
    final autoRun = (autoRunBySerial[entry.serial] ?? '').trim();
    if (autoRun == '1') {
      goldenSerial ??= entry.serial;
    } else {
      dutCandidates.add(entry);
    }
  }

  if (dutCandidates.isEmpty) {
    // Only Golden Panel is present so far — must NOT mistake Golden for DUT!
    return Step2Decision(
      type: Step2DecisionType.waitForDut,
      goldenSerial: goldenSerial,
      statusMessage:
          '⏳ [AutoSN] Đã nhận Golden ($goldenSerial) — Đang chờ cắm DUT...',
    );
  }

  if (dutCandidates.length == 1) {
    final dut = dutCandidates.first;
    final modeTag = goldenSerial != null ? 'Có Golden' : 'Không Golden';
    return Step2Decision(
      type: Step2DecisionType.foundTargetDut,
      targetDut: dut.serial,
      goldenSerial: goldenSerial,
      isTargetAuthorized: dut.isAuthorized,
      statusMessage:
          '📱 [AutoSN - $modeTag] DUT: ${dut.serial} — Đang kiểm tra USB Debug...',
    );
  }

  if (dutCandidates.length == 2) {
    final c1 = dutCandidates[0];
    final c2 = dutCandidates[1];
    final hw1 = (hwSerialBySerial[c1.serial] ?? '').trim();
    final hw2 = (hwSerialBySerial[c2.serial] ?? '').trim();

    if (hw1.isNotEmpty && hw1 == hw2) {
      return Step2Decision(
        type: Step2DecisionType.foundTargetDut,
        targetDut: c1.serial,
        goldenSerial: goldenSerial,
        isTargetAuthorized: c1.isAuthorized,
        statusMessage:
            '📱 [AutoSN] DUT: ${c1.serial} (2 ADB interface) — Đang kiểm tra USB Debug...',
      );
    }
    if (c1.isAuthorized && c2.isAuthorized) {
      if (hw1.isNotEmpty && hw2.isEmpty) {
        return Step2Decision(
          type: Step2DecisionType.foundTargetDut,
          targetDut: c1.serial,
          goldenSerial: goldenSerial,
          isTargetAuthorized: true,
          statusMessage:
              '📱 [AutoSN] DUT: ${c1.serial} — Đang kiểm tra USB Debug...',
        );
      }
      if (hw2.isNotEmpty && hw1.isEmpty) {
        return Step2Decision(
          type: Step2DecisionType.foundTargetDut,
          targetDut: c2.serial,
          goldenSerial: goldenSerial,
          isTargetAuthorized: true,
          statusMessage:
              '📱 [AutoSN] DUT: ${c2.serial} — Đang kiểm tra USB Debug...',
        );
      }
    }
    final expectedDutComPorts = goldenSerial != null
        ? (comPortCount - 1)
        : comPortCount;
    if (expectedDutComPorts == 1) {
      final preferred = c1.isAuthorized ? c1 : c2;
      return Step2Decision(
        type: Step2DecisionType.foundTargetDut,
        targetDut: preferred.serial,
        goldenSerial: goldenSerial,
        isTargetAuthorized: preferred.isAuthorized,
        statusMessage:
            '📱 [AutoSN] DUT: ${preferred.serial} (1 COM) — Đang kiểm tra USB Debug...',
      );
    }

    return Step2Decision(
      type: Step2DecisionType.retryAmbiguousDualDut,
      goldenSerial: goldenSerial,
      statusMessage: '⚠️ [AutoSN] Phát hiện 2 thiết bị nghi vấn DUT...',
    );
  }

  return Step2Decision(
    type: Step2DecisionType.abortTooManyDevices,
    goldenSerial: goldenSerial,
    statusMessage:
        '❌ [AutoSN] Quá nhiều thiết bị (${usbEntries.length})! Chỉ cắm tối đa 1 DUT + 1 Golden.',
  );
}

/// Kiểm tra điều kiện sẵn sàng của hệ thống Android / USB Debug ở Bước 3 (không phụ thuộc lệnh `grep`).
bool isStep3ShellReady({
  required String bootCompleted,
  required String devBootComplete,
  required String adbdState,
  String notificationDump = '',
}) {
  if (bootCompleted.trim() == '1' || devBootComplete.trim() == '1') {
    return true;
  }
  if (adbdState.trim().toLowerCase() == 'running') {
    return true;
  }
  if (notificationDump.isNotEmpty) {
    final lower = notificationDump.toLowerCase();
    if (lower.contains('pkg=android') &&
        (lower.contains('usb') || lower.contains('adb'))) {
      return true;
    }
  }
  return false;
}

/// Dịch vụ quản lý tính năng Tự động SN/PN & Xác thực USB Debug (`javaw.exe`).
class AutoSnService extends ChangeNotifier {
  static const MethodChannel _defaultChannel = MethodChannel('ja_route/autosn');

  final MethodChannel _channel;
  final Future<String> Function(List<String>) _adbCommand;
  final Future<int> Function(String keyword)? _customComCounter;
  final String _configFilePath;
  final String? Function()? knownGoldenSerialGetter;
  final void Function(String message)? onToast;
  final void Function(String dutSerial)? onDutReady;

  AutoSnConfig _config = AutoSnConfig.defaults();
  AutoSnConfig get config => _config;
  bool get enabled => _config.enabled;

  DateTime? _lastConfigModified;
  bool _isSessionRunning = false;
  bool get isSessionRunning => _isSessionRunning;

  String _sessionStatus = '';
  String get sessionStatus => _sessionStatus;

  int _sessionEpoch = 0;
  CommandScope? _sessionScope;
  Completer<bool>? _pnFilledCompleter;
  Completer<bool>? _spaceSentCompleter;

  final Set<String> _cachedGoldenSerials = <String>{};

  AutoSnService({
    MethodChannel? channel,
    Future<String> Function(List<String>)? adbCommand,
    Future<int> Function(String keyword)? comCounter,
    String? configFilePath,
    this.knownGoldenSerialGetter,
    this.onToast,
    this.onDutReady,
    bool initNativeChannel = true,
  }) : _channel = channel ?? _defaultChannel,
       _adbCommand =
           adbCommand ??
           ((args) => runCmd(args, timeout: const Duration(seconds: 4))),
       _customComCounter = comCounter,
       _configFilePath = configFilePath ?? defaultConfigFilePath() {
    loadOrCreateConfigSync();
    if (initNativeChannel) {
      _setupNativeChannel();
      unawaited(_syncNativeConfig());
    }
  }

  static String defaultConfigFilePath() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidate = p.join(exeDir, 'auto_sn_config.json');
    if (File(candidate).existsSync()) {
      return candidate;
    }
    final cwdCandidate = p.join(Directory.current.path, 'auto_sn_config.json');
    if (File(cwdCandidate).existsSync()) {
      return cwdCandidate;
    }
    return candidate;
  }

  String get configFilePath => _configFilePath;

  void _setupNativeChannel() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onSnCaptured':
          if (call.arguments is Map) {
            final map = Map<dynamic, dynamic>.from(call.arguments as Map);
            final text = (map['text'] as String?) ?? '';
            final hwnd = (map['hwnd'] as num?)?.toInt() ?? 0;
            await handleCapturedSnFromNative(rawText: text, javawHwnd: hwnd);
          }
          break;
        case 'onPnFilled':
          final ok = call.arguments == true;
          if (_pnFilledCompleter != null && !_pnFilledCompleter!.isCompleted) {
            _pnFilledCompleter!.complete(ok);
          }
          break;
        case 'onSpaceSent':
          final ok = call.arguments == true;
          if (_spaceSentCompleter != null &&
              !_spaceSentCompleter!.isCompleted) {
            _spaceSentCompleter!.complete(ok);
          }
          break;
        case 'onEscapePressed':
          cancelActiveSession(reason: 'Đã hủy phiên chờ AutoSN (Esc)');
          break;
      }
    });
  }

  Future<void> _syncNativeConfig() async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod('configure', {
        'enabled': _config.enabled,
        'targetProcess': _config.targetProcess,
        'skipTokens': _config.skipClipboardContains,
      });
    } catch (e) {
      logger.warning('[AutoSN] Native channel configure skipped/failed: $e');
    }
  }

  /// Đọc file `auto_sn_config.json` (tự tạo file mặc định nếu chưa có).
  /// Nếu file bị lỗi cú pháp JSON, giữ nguyên cấu hình hợp lệ gần nhất và báo Toast.
  bool loadOrCreateConfigSync({bool notifyOnError = false}) {
    final file = File(_configFilePath);
    try {
      if (!file.existsSync()) {
        file.parent.createSync(recursive: true);
        final jsonStr = const JsonEncoder.withIndent(
          '  ',
        ).convert(_config.toJson());
        file.writeAsStringSync('$jsonStr\n');
        _lastConfigModified = file.lastModifiedSync();
        return true;
      }

      final statModified = file.lastModifiedSync();
      if (_lastConfigModified != null &&
          statModified.isAtSameMomentAs(_lastConfigModified!)) {
        return true;
      }

      final content = file.readAsStringSync();
      final decoded = jsonDecode(content);
      if (decoded is! Map) {
        throw const FormatException('Root JSON must be an object');
      }
      _config = AutoSnConfig.fromJson(Map<String, dynamic>.from(decoded));
      _lastConfigModified = statModified;
      logger.info(
        '[AutoSN] Loaded auto_sn_config.json (${_config.forms.length} forms, enabled=${_config.enabled}).',
      );
      return true;
    } catch (e) {
      logger.warning('[AutoSN] Failed to parse $_configFilePath: $e');
      if (notifyOnError) {
        _emitToast(
          '⚠️ Lỗi cú pháp auto_sn_config.json — Đang dùng cấu hình hợp lệ gần nhất',
        );
      }
      return false;
    }
  }

  /// Bật hoặc tắt tính năng AutoSN và lưu ngay vào `auto_sn_config.json`.
  Future<void> setEnabled(bool value) async {
    loadOrCreateConfigSync();
    _config = _config.copyWith(enabled: value);
    try {
      final file = File(_configFilePath);
      final jsonStr = const JsonEncoder.withIndent(
        '  ',
      ).convert(_config.toJson());
      file.writeAsStringSync('$jsonStr\n');
      _lastConfigModified = file.lastModifiedSync();
    } catch (e) {
      logger.warning('[AutoSN] Could not write config file: $e');
    }

    if (!value && _isSessionRunning) {
      cancelActiveSession(reason: 'Đã tắt Tự động SN/PN');
    }
    await _syncNativeConfig();
    notifyListeners();
  }

  /// Mở file `auto_sn_config.json` bằng trình soạn thảo mặc định trên Windows.
  Future<bool> openConfigFileInEditor() async {
    loadOrCreateConfigSync();
    if (!Platform.isWindows) return false;
    try {
      await Process.start('notepad.exe', [
        _configFilePath,
      ], mode: ProcessStartMode.detached);
      return true;
    } catch (e) {
      logger.warning('[AutoSN] Could not launch notepad for config: $e');
      return false;
    }
  }

  /// Hủy phiên chờ kết nối COM/ADB hiện tại (khi nhấn Esc hoặc tắt tính năng).
  void cancelActiveSession({String? reason}) {
    if (!_isSessionRunning) return;
    _sessionEpoch++;
    _sessionScope?.cancel();
    _sessionScope = null;
    _isSessionRunning = false;
    _sessionStatus = '';
    unawaited(_setNativeSessionWaiting(false));
    if (reason != null && reason.isNotEmpty) {
      logger.info('[AutoSN] Session cancelled: $reason');
      _emitToast('⏹️ [AutoSN] $reason');
    }
    notifyListeners();
  }

  Future<void> _setNativeSessionWaiting(bool waiting) async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod('setSessionWaiting', waiting);
    } catch (_) {}
  }

  void _emitToast(String msg) {
    _sessionStatus = msg;
    onToast?.call(msg);
    notifyListeners();
  }

  Future<int> _countQualcommPorts(String keyword) async {
    if (_customComCounter != null) {
      return _customComCounter(keyword);
    }
    if (!Platform.isWindows) return 0;
    try {
      final count = await _channel.invokeMethod<int>('countComPorts', keyword);
      return count ?? 0;
    } catch (e) {
      logger.warning('[AutoSN] countComPorts error: $e');
      return 0;
    }
  }

  /// Xử lý chuỗi SN vừa đọc từ `javaw.exe` (tự động Hot-Reload `auto_sn_config.json`).
  Future<AutoSnMatchResult> handleCapturedSnFromNative({
    required String rawText,
    required int javawHwnd,
    Duration comPollInterval = const Duration(milliseconds: 400),
    Duration postComStabilizeDelay = const Duration(milliseconds: 1500),
    Duration adbPollInterval = const Duration(milliseconds: 1000),
    Duration preSpaceDelay = const Duration(milliseconds: 400),
  }) async {
    // 1. Hot-reload JSON config if modified on disk
    loadOrCreateConfigSync(notifyOnError: true);
    unawaited(_syncNativeConfig());

    final matchResult = evaluateSnWithConfig(rawText, _config);

    // 2. Empty clipboard -> send NumpadEnter and exit
    if (matchResult.isEmpty) {
      try {
        await _channel.invokeMethod('sendNumpadEnter', {'hwnd': javawHwnd});
      } catch (_) {}
      return matchResult;
    }

    // 3. Invalid SN format -> warn & restore focus in javaw.exe
    if (!matchResult.isValid) {
      logger.warning('[AutoSN] Invalid SN format: "${matchResult.rawInput}"');
      _emitToast('❌ [AutoSN] SN sai định dạng: "${matchResult.rawInput}"');
      try {
        await _channel.invokeMethod('onInvalidSn', {'hwnd': javawHwnd});
      } catch (_) {}
      return matchResult;
    }

    // 4. Valid SN -> Fill GeneratedPN into javaw.exe
    logger.info(
      '[AutoSN] Matched "${matchResult.matchedFormName}": SN=${matchResult.snCore} -> PN=${matchResult.generatedPn}',
    );

    // Cancel any previous waiting session before starting the new one
    if (_isSessionRunning) {
      _sessionEpoch++;
      _sessionScope?.cancel();
    }

    final myEpoch = ++_sessionEpoch;
    final scope = CommandScope();
    _sessionScope = scope;
    _isSessionRunning = true;
    notifyListeners();

    try {
      _pnFilledCompleter = Completer<bool>();
      await _channel.invokeMethod('fillPn', {
        'hwnd': javawHwnd,
        'pn': matchResult.generatedPn,
        'hadCaret': matchResult.hadCaret,
        'appendCaret': _config.appendCaret,
      });
      await _pnFilledCompleter!.future.timeout(
        const Duration(seconds: 3),
        onTimeout: () => true,
      );
    } catch (_) {}

    if (myEpoch != _sessionEpoch || !_config.enabled) {
      return matchResult;
    }

    await _setNativeSessionWaiting(true);
    _emitToast(
      '⏳ [AutoSN] Đã điền ${matchResult.generatedPn} — Đang chờ kết nối COM...',
    );

    try {
      await _runSteps1To3(
        epoch: myEpoch,
        scope: scope,
        javawHwnd: javawHwnd,
        comPollInterval: comPollInterval,
        postComStabilizeDelay: postComStabilizeDelay,
        adbPollInterval: adbPollInterval,
        preSpaceDelay: preSpaceDelay,
      );
    } finally {
      if (myEpoch == _sessionEpoch) {
        _isSessionRunning = false;
        _sessionScope = null;
        await _setNativeSessionWaiting(false);
        notifyListeners();
      }
    }

    return matchResult;
  }

  Future<void> _runSteps1To3({
    required int epoch,
    required CommandScope scope,
    required int javawHwnd,
    required Duration comPollInterval,
    required Duration postComStabilizeDelay,
    required Duration adbPollInterval,
    required Duration preSpaceDelay,
  }) async {
    bool isCancelled() =>
        epoch != _sessionEpoch || !_isSessionRunning || scope.cancelled;

    // =========================================================================
    // BƯỚC 1: Đợi ít nhất 1 cổng COM Qualcomm 9091 xuất hiện
    // =========================================================================
    final step1Deadline = DateTime.now().add(
      Duration(seconds: _config.comWaitTimeoutSec),
    );
    int comPortCount = 0;
    while (!isCancelled()) {
      comPortCount = await _countQualcommPorts(_config.comPortKeyword);
      if (comPortCount >= 1) {
        break;
      }
      if (DateTime.now().isAfter(step1Deadline)) {
        logger.warning('[AutoSN] Step 1 TIMEOUT: No COM port detected.');
        _emitToast('❌ [AutoSN] Timeout: Không thấy thiết bị kết nối qua COM.');
        return;
      }
      await Future.delayed(comPollInterval);
    }
    if (isCancelled()) return;

    logger.info(
      '[AutoSN] Step 1 OK: detected $comPortCount COM port(s). Stabilizing...',
    );
    _emitToast('⏳ [AutoSN] Đã thấy cổng COM — Chờ thiết bị ổn định...');
    await Future.delayed(postComStabilizeDelay);
    if (isCancelled()) return;

    // =========================================================================
    // BƯỚC 2: Nhận diện TargetDUT qua ADB (Loại trừ Golden Panel & hỗ trợ unauthorized)
    // =========================================================================
    final knownGolden = knownGoldenSerialGetter?.call();
    if (knownGolden != null && knownGolden.isNotEmpty) {
      _cachedGoldenSerials.add(knownGolden);
    }

    final autoRunCache = <String, String>{
      for (final g in _cachedGoldenSerials) g: '1',
    };
    final hwSerialCache = <String, String>{};
    int dualDutRetries = 0;
    String? targetDut;
    final step2Deadline = DateTime.now().add(
      Duration(seconds: _config.adbWaitTimeoutSec),
    );

    while (!isCancelled()) {
      final rawDevices = await _runScopedAdb(scope, ['adb', 'devices']);
      if (isCancelled()) return;

      final usbEntries = parseAdbUsbDevices(rawDevices);

      // Query persist.auto.run for every authorized USB device not yet cached
      for (final entry in usbEntries) {
        if (entry.isAuthorized && !autoRunCache.containsKey(entry.serial)) {
          final val = (await _runScopedAdb(scope, [
            'adb',
            '-s',
            entry.serial,
            'shell',
            'getprop',
            'persist.auto.run',
          ])).trim();
          if (isCancelled()) return;
          if (val == '1') {
            autoRunCache[entry.serial] = '1';
            _cachedGoldenSerials.add(entry.serial);
          } else if (val.isNotEmpty || entry.isAuthorized) {
            autoRunCache[entry.serial] = val;
          }
        }
      }

      // If there are 2 non-Golden candidates that are authorized, read ro.serialno
      final nonGoldenAuthorized = usbEntries
          .where((e) => e.isAuthorized && autoRunCache[e.serial] != '1')
          .toList();
      if (nonGoldenAuthorized.length == 2) {
        for (final entry in nonGoldenAuthorized) {
          if (!hwSerialCache.containsKey(entry.serial)) {
            final hw = (await _runScopedAdb(scope, [
              'adb',
              '-s',
              entry.serial,
              'shell',
              'getprop',
              'ro.serialno',
            ])).trim();
            if (isCancelled()) return;
            hwSerialCache[entry.serial] = hw;
          }
        }
      }

      comPortCount = await _countQualcommPorts(_config.comPortKeyword);
      final decision = classifyStep2UsbDevices(
        usbEntries: usbEntries,
        autoRunBySerial: autoRunCache,
        hwSerialBySerial: hwSerialCache,
        comPortCount: comPortCount,
      );

      if (decision.type == Step2DecisionType.foundTargetDut &&
          decision.targetDut != null) {
        targetDut = decision.targetDut!;
        logger.info(
          '[AutoSN] Step 2 OK: TargetDUT=$targetDut (Golden=${decision.goldenSerial ?? "none"})',
        );
        _emitToast(decision.statusMessage);
        break;
      } else if (decision.type == Step2DecisionType.abortTooManyDevices) {
        logger.severe('[AutoSN] Step 2 ABORT: ${decision.statusMessage}');
        _emitToast(decision.statusMessage);
        return;
      } else if (decision.type == Step2DecisionType.retryAmbiguousDualDut) {
        dualDutRetries++;
        logger.warning('[AutoSN] Step 2 dual DUT retry $dualDutRetries/3');
        if (dualDutRetries >= 3) {
          _emitToast(
            '❌ [AutoSN] Phát hiện nhiều DUT! Chỉ được cắm 1 DUT tại một thời điểm.',
          );
          return;
        }
        _emitToast(
          '⚠️ [AutoSN] Chưa xác định được Golden (thử $dualDutRetries/3)...',
        );
      } else {
        _emitToast(decision.statusMessage);
      }

      if (DateTime.now().isAfter(step2Deadline)) {
        logger.warning('[AutoSN] Step 2 TIMEOUT waiting for TargetDUT.');
        _emitToast('❌ [AutoSN] Timeout: Không nhận diện được DUT qua ADB.');
        return;
      }
      await Future.delayed(adbPollInterval);
    }

    if (isCancelled() || targetDut == null) return;

    // =========================================================================
    // BƯỚC 3: Dual-Check trên TargetDUT (Authorized 'device' + Shell/Boot Ready)
    // =========================================================================
    final step3Deadline = DateTime.now().add(
      Duration(seconds: _config.adbWaitTimeoutSec),
    );
    bool authorizedAndReady = false;

    while (!isCancelled()) {
      final rawDevices = await _runScopedAdb(scope, ['adb', 'devices']);
      if (isCancelled()) return;

      final usbEntries = parseAdbUsbDevices(rawDevices);
      final dutEntry = usbEntries
          .where((e) => e.serial == targetDut)
          .firstOrNull;

      if (dutEntry != null && dutEntry.isAuthorized) {
        // Dual-Check: verify ADB shell & boot/adbd readiness on TargetDUT
        final propsOut = await _runScopedAdb(scope, [
          'adb',
          '-s',
          targetDut,
          'shell',
          'getprop sys.boot_completed; getprop dev.bootcomplete; getprop init.svc.adbd',
        ]);
        if (isCancelled()) return;

        final propLines = propsOut
            .split(RegExp(r'\r?\n'))
            .map((l) => l.trim())
            .toList();
        final bootCompleted = propLines.isNotEmpty ? propLines[0] : '';
        final devBootComplete = propLines.length > 1 ? propLines[1] : '';
        final adbdState = propLines.length > 2 ? propLines[2] : '';

        if (isStep3ShellReady(
          bootCompleted: bootCompleted,
          devBootComplete: devBootComplete,
          adbdState: adbdState,
        )) {
          authorizedAndReady = true;
          break;
        }
      } else {
        _emitToast(
          '📱 [AutoSN] DUT: $targetDut — Chờ bấm Allow USB Debug trên màn hình...',
        );
      }

      if (DateTime.now().isAfter(step3Deadline)) {
        logger.warning('[AutoSN] Step 3 TIMEOUT on DUT=$targetDut');
        _emitToast(
          '❌ [AutoSN] Timeout: DUT $targetDut chưa sẵn sàng USB Debug.',
        );
        return;
      }
      await Future.delayed(adbPollInterval);
    }

    if (isCancelled() || !authorizedAndReady) return;

    await Future.delayed(preSpaceDelay);
    if (isCancelled()) return;

    try {
      _spaceSentCompleter = Completer<bool>();
      await _channel.invokeMethod('sendSpace', {'hwnd': javawHwnd});
      await _spaceSentCompleter!.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => true,
      );
    } catch (_) {}

    logger.info('[AutoSN] Step 3 COMPLETE: Sent Space for DUT=$targetDut');
    _emitToast('✅ [AutoSN] USB Debug OK ($targetDut) — Đã gửi Space!');
    onDutReady?.call(targetDut);
  }

  Future<String> _runScopedAdb(CommandScope scope, List<String> args) async {
    if (scope.cancelled) return '';
    try {
      return await scope.run(() => _adbCommand(args));
    } catch (_) {
      return '';
    }
  }
}
