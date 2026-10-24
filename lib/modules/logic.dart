// lib/modules/logic.dart

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'utils.dart';
import 'logger_config.dart';
import 'services/powerg_service.dart';
import 'services/srf_service.dart';
import 'services/boot_gate.dart';
import 'services/command_scope.dart';
import 'services/dut_history_service.dart';

class AdbMonitor extends ChangeNotifier {
  int _loadGeneration = 0;
  bool _bootReady = false;
  late final BootGate _bootGate;
  final Future<String> Function(List<String>) _command;
  final Future<PowerGResult> Function(String) _verifyPowerG;
  final Future<SrfResult> Function(String, String?) _verifySrf;
  final Duration pollInterval;
  final DutHistoryService history;
  CommandScope? _readScope;
  bool _loading = false;
  int _loopEpoch = 0;
  bool _running = false;
  bool get running => _running;

  bool _deviceConnected = false;
  bool get deviceConnected => _deviceConnected;

  String _currentDut = '';
  String get currentDut => _currentDut;

  List<String> _allDuts = [];
  List<String> get allDuts => _allDuts;

  Map<String, String> _info = {
    'PCASN': 'N/A',
    'SYSSN': 'N/A',
    'SYSPN': 'N/A',
    'LCMPN': 'N/A',
    'IMEI': 'N/A',
    'CPU': 'N/A',
    'PowerG': 'N/A',
    'SRF': 'N/A',
  };
  Map<String, String> get info => _info;

  PowerGResult? _powerGResult;
  PowerGResult? get powerGResult => _powerGResult;

  SrfResult? _srfResult;
  SrfResult? get srfResult => _srfResult;

  String? _goldenPanelSerial;
  String? get goldenPanelSerial => _goldenPanelSerial;

  bool _isPowerGTesting = false;
  bool get isPowerGTesting => _isPowerGTesting;

  bool _isSrfTesting = false;
  bool get isSrfTesting => _isSrfTesting;

  bool get isRfTesting => _isPowerGTesting || _isSrfTesting;

  String _status = 'Waiting for DUT connection...';
  String get status => _status;

  bool _isSuccessStatus = false;
  bool get isSuccessStatus => _isSuccessStatus;

  String _overlayText = 'NO DATA';
  String get overlayText => _overlayText;

  bool _showOverlay = true;
  bool get showOverlay => _showOverlay;

  String _stationResult = 'N/A';
  String get stationResult => _stationResult;

  /// Robust device classification for IQ5
  static bool isIq5Device({
    String pcasn = '',
    String sysConfig = '',
    String buildProduct = '',
    String productDevice = '',
    String syspn = '',
    String syssn = '',
  }) {
    final pUpper = pcasn.toUpperCase();
    final cUpper = sysConfig.toUpperCase();
    final bLower = buildProduct.toLowerCase();
    final dLower = productDevice.toLowerCase();
    final pnUpper = syspn.toUpperCase();
    final snUpper = syssn.toUpperCase();

    if (pUpper.startsWith('QB95') ||
        pUpper.startsWith('QB85') ||
        pUpper.startsWith('QC95')) {
      return true;
    }
    if (cUpper.startsWith('IQP5') ||
        cUpper.startsWith('IQH5') ||
        cUpper.startsWith('IQ5')) {
      return true;
    }
    if (pnUpper.startsWith('IQP5') ||
        pnUpper.startsWith('IQH5') ||
        pnUpper.startsWith('IQ5')) {
      return true;
    }
    if (snUpper.startsWith('QP5') || snUpper.startsWith('QH5')) {
      return true;
    }
    if (bLower.contains('tucson') || dLower.contains('tucson')) {
      return true;
    }
    return false;
  }

  /// Robust device classification for IQ4
  static bool isIq4Device({
    String pcasn = '',
    String sysConfig = '',
    String buildProduct = '',
    String productDevice = '',
    String syspn = '',
    String syssn = '',
  }) {
    final pUpper = pcasn.toUpperCase();
    final cUpper = sysConfig.toUpperCase();
    final bLower = buildProduct.toLowerCase();
    final dLower = productDevice.toLowerCase();
    final pnUpper = syspn.toUpperCase();
    final snUpper = syssn.toUpperCase();

    if (pUpper.startsWith('QB94') ||
        pUpper.startsWith('QB84') ||
        pUpper.startsWith('QB74') ||
        pUpper.startsWith('QB64') ||
        pUpper.startsWith('QC94') ||
        pUpper.startsWith('QD94')) {
      return true;
    }
    if (cUpper.startsWith('IQP4') ||
        cUpper.startsWith('IQH4') ||
        cUpper.startsWith('IQ4')) {
      return true;
    }
    if (pnUpper.startsWith('IQP4') ||
        pnUpper.startsWith('IQH4') ||
        pnUpper.startsWith('IQ4')) {
      return true;
    }
    if (snUpper.startsWith('QP4') ||
        snUpper.startsWith('QH4') ||
        snUpper.startsWith('QPH')) {
      return true;
    }
    if (bLower == 'lucy' ||
        bLower.contains('lucy') ||
        dLower == 'lucy' ||
        dLower.contains('lucy')) {
      return true;
    }
    return false;
  }

  AdbMonitor({
    Future<String> Function(List<String>)? command,
    Future<PowerGResult> Function(String)? powerGVerifier,
    Future<SrfResult> Function(String, String?)? srfVerifier,
    this.pollInterval = const Duration(seconds: 2),
    bool autoStart = true,
    DutHistoryService? historyService,
  }) : _verifyPowerG =
           powerGVerifier ?? ((serial) => PowerGService().verifyDut(serial)),
       _verifySrf =
           srfVerifier ??
           ((serial, golden) =>
               SrfService().verifyDut(serial, goldenSerial: golden)),
       _command =
           command ??
           ((args) => runCmd(args, timeout: const Duration(seconds: 5))),
       history =
           historyService ??
           ((command == null && powerGVerifier == null && srfVerifier == null)
               ? (DutHistoryService()..loadFromDiskSyncSafe())
               : DutHistoryService(storageFilePath: null)) {
    _bootGate = BootGate(
      (serial, property) =>
          _command(['adb', '-s', serial, 'shell', 'getprop', property]),
    );
    if (autoStart) start();
  }

  void start() {
    if (_running) return;
    _running = true;
    logger.info('Monitor thread started.');
    _loop(++_loopEpoch);
  }

  void stop() {
    _running = false;
    _loopEpoch++;
    _readScope?.cancel();
    _readScope = null;
    _loading = false;
    _loadGeneration++;
    _bootReady = false;
    logger.info('Stopping monitor thread...');
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  Future<void> _loop(int epoch) async {
    while (_running && epoch == _loopEpoch) {
      try {
        await _checkDevices();
      } catch (e) {
        logger.severe('Error in check devices loop: $e');
      }
      await Future.delayed(pollInterval);
    }
  }

  Future<List<String>> _getDevices() async {
    final out = await _command(['adb', 'devices']);
    final lines = out
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final devices = <String>[];
    if (lines.length > 1) {
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i];
        final parts = line.split(RegExp(r'\s+'));
        if (parts.length >= 2 && parts[1] == 'device') {
          devices.add(parts[0]);
        }
      }
    }
    return devices;
  }

  Future<void> selectDut(String serial) async {
    if (!_allDuts.contains(serial)) return;
    await _loadDut(serial);
  }

  Future<bool> _waitForBootComplete(String serial, int generation) async {
    logger.info('Checking boot status on DUT: $serial...');

    logger.info(
      'DUT $serial is booting. Waiting for sys.boot_completed == 1...',
    );
    _status = 'DUT đang khởi động (Đang chờ boot xong)...';
    _overlayText = 'BOOTING';
    _showOverlay = true;
    notifyListeners();

    return _bootGate.wait(
      serial,
      isCurrent: () =>
          _running && _currentDut == serial && _loadGeneration == generation,
    );
  }

  Future<void> _loadDut(String serial) async {
    _readScope?.cancel();
    final scope = CommandScope();
    _readScope = scope;
    _loading = true;
    try {
      await scope.run(() => _readDut(serial));
    } on CommandCancelled {
      // Normal USB removal, selection change or monitor shutdown.
    } catch (error) {
      logger.severe('DUT read failed: $error');
      if (_running && identical(_readScope, scope)) {
        _status = 'Lỗi đọc thiết bị. Sẽ kiểm tra lại...';
        _bootReady = false;
        notifyListeners();
      }
    } finally {
      if (identical(_readScope, scope)) _loading = false;
    }
  }

  Future<void> _readDut(String serial) async {
    final generation = ++_loadGeneration;
    bool isCurrent() =>
        _running && _currentDut == serial && _loadGeneration == generation;
    _bootReady = false;
    _isPowerGTesting = false;
    _isSrfTesting = false;
    logger.info('Loading DUT: $serial');
    _currentDut = serial;
    _deviceConnected = true;
    _isSuccessStatus = true;
    _status = 'Connected: $serial';
    _stationResult = 'Loading...';
    _powerGResult = null;
    _srfResult = null;
    _info = {
      'PCASN': 'Đang đọc...',
      'SYSSN': 'Đang đọc...',
      'SYSPN': 'Đang đọc...',
      'LCMPN': 'Đang đọc...',
      'IMEI': 'Đang đọc...',
      'CPU': 'Đang đọc...',
      'PowerG': 'Đang chờ boot...',
      'SRF': 'Đang chờ boot...',
    };

    _overlayText = 'LOADING';
    _showOverlay = true;
    notifyListeners();

    // 1. Wait for boot completion if device is rebooting
    final booted = await _waitForBootComplete(serial, generation);
    if (!_running || _currentDut != serial || _loadGeneration != generation) {
      return;
    }
    if (!booted) {
      _status = 'Chưa hoàn tất khởi động. Sẽ kiểm tra lại...';
      _isSuccessStatus = false;
      notifyListeners();
      return;
    }
    _bootReady = true;
    _isSuccessStatus = true;

    _status = 'DUT đã boot xong. Đang nạp thông số...';
    _overlayText = 'READING';
    notifyListeners();

    // 2. Trigger non-blocking RF check now that boot is complete
    _checkRfAsync(serial);

    // 3. Read PCASN and system identification properties in parallel
    String pcasnVal = 'N/A';
    final pcasnFuture = () async {
      for (var attempt = 1; attempt <= 5; attempt++) {
        if (!isCurrent()) return;
        try {
          final out = await _command([
            'adb',
            '-s',
            serial,
            'shell',
            'testeepapi',
            'r',
            'pcasn',
          ]);
          final trimmed = out.trim();
          if (trimmed.isNotEmpty &&
              !trimmed.toLowerCase().contains('error') &&
              !trimmed.toLowerCase().contains('not found')) {
            pcasnVal = trimmed;
            break;
          }
        } catch (e) {
          logger.severe('Attempt $attempt failed to read PCASN: $e');
        }
        if (attempt < 5) await Future.delayed(const Duration(seconds: 1));
      }
      if (pcasnVal.isEmpty ||
          pcasnVal.toLowerCase().contains('error') ||
          pcasnVal.toLowerCase().contains('not found')) {
        pcasnVal = 'N/A';
      }
    }();

    final sysPropsFuture = Future.wait<String>([
      _command(['adb', '-s', serial, 'shell', 'getprop', 'qolsys.sys.config']),
      _command(['adb', '-s', serial, 'shell', 'getprop', 'ro.build.product']),
      _command(['adb', '-s', serial, 'shell', 'getprop', 'ro.product.device']),
    ]);

    await Future.wait<void>([pcasnFuture, sysPropsFuture]);
    if (!isCurrent()) return;

    _info['PCASN'] = pcasnVal;
    final sysProps = await sysPropsFuture;
    final sysConfig = sysProps[0].trim();
    final buildProduct = sysProps[1].trim();
    final productDevice = sysProps[2].trim();

    // Determine target overlay text
    if (isIq5Device(
      pcasn: pcasnVal,
      sysConfig: sysConfig,
      buildProduct: buildProduct,
      productDevice: productDevice,
    )) {
      _overlayText = 'IQ5';
    } else if (isIq4Device(
      pcasn: pcasnVal,
      sysConfig: sysConfig,
      buildProduct: buildProduct,
      productDevice: productDevice,
    )) {
      _overlayText = 'IQ4';
    } else {
      _overlayText = 'DUT';
    }
    notifyListeners();

    // Fast transition timer (reduced from 3s to 250ms for <1.5s total load)
    final splashTimer = Future.delayed(const Duration(milliseconds: 250));

    // 4. Fetch all other parameters concurrently
    final List<Future<void>> tasks = [];

    // Pipeline task for SYSSN and Station Result (with retry up to 5 times)
    tasks.add(() async {
      var syssnVal = '';
      for (var attempt = 1; attempt <= 5; attempt++) {
        if (!isCurrent()) return;
        try {
          final out = await _command([
            'adb',
            '-s',
            serial,
            'shell',
            'testeepapi',
            'r',
            'syssn',
          ]);
          final trimmed = out.trim();
          if (trimmed.isNotEmpty &&
              !trimmed.toLowerCase().contains('error') &&
              !trimmed.toLowerCase().contains('not found')) {
            syssnVal = trimmed;
            break;
          }
        } catch (e) {
          logger.severe('Attempt $attempt failed to load SYSSN: $e');
        }
        if (attempt < 5) await Future.delayed(const Duration(seconds: 1));
      }

      if (syssnVal.isEmpty ||
          syssnVal.toLowerCase().contains('error') ||
          syssnVal.toLowerCase().contains('not found')) {
        syssnVal = 'N/A';
      }
      if (syssnVal.contains('\xff') ||
          syssnVal.contains('ÿ') ||
          syssnVal.contains('\ufffd') ||
          syssnVal.contains('?????') ||
          RegExp(r'\?{5,}').hasMatch(syssnVal)) {
        syssnVal = 'Chưa test MMI';
      }

      if (!isCurrent()) return;
      _info['SYSSN'] = syssnVal;

      // Update log session
      var safeSyssn = syssnVal.replaceAll(RegExp(r'[^a-zA-Z0-9\-_]'), '');
      if (safeSyssn.isEmpty ||
          safeSyssn == 'NA' ||
          safeSyssn == 'ChuatestMMI') {
        safeSyssn = 'UNPROGRAMMED_DUT_$serial';
      }
      if (safeSyssn != 'N/A') {
        setDutLogSession(safeSyssn);
      }
      notifyListeners();

      // Now query station result using the retrieved SYSSN
      if (syssnVal != 'N/A' &&
          syssnVal != 'Chưa test MMI' &&
          syssnVal.isNotEmpty &&
          !syssnVal.contains('?')) {
        await _fetchStation(syssnVal, serial);
      } else {
        _stationResult = 'N/A';
        notifyListeners();
      }
    }());

    // Pipeline task for CPU (gsm.version.baseband) with multi-retry up to 10 attempts and fallbacks
    tasks.add(() async {
      var cpuVal = '';
      for (var attempt = 1; attempt <= 10; attempt++) {
        if (!isCurrent()) return;
        try {
          var val = await _command([
            'adb',
            '-s',
            serial,
            'shell',
            'getprop',
            'gsm.version.baseband',
          ]);
          val = val.replaceAll('[', '').replaceAll(']', '').trim();
          if (val.isNotEmpty &&
              !val.toLowerCase().contains('error') &&
              !val.toLowerCase().contains('not found')) {
            cpuVal = val;
            break;
          }
          // Secondary fallback: gsm.version.baseband1
          final bb1 = await _command([
            'adb',
            '-s',
            serial,
            'shell',
            'getprop',
            'gsm.version.baseband1',
          ]);
          final cleanBb1 = bb1.replaceAll('[', '').replaceAll(']', '').trim();
          if (cleanBb1.isNotEmpty &&
              !cleanBb1.toLowerCase().contains('error') &&
              !cleanBb1.toLowerCase().contains('not found')) {
            cpuVal = cleanBb1;
            break;
          }
          // Tertiary fallback: ro.boot.baseband / ro.baseband
          if (attempt >= 5) {
            final bbRo = await _command([
              'adb',
              '-s',
              serial,
              'shell',
              'getprop',
              'ro.boot.baseband',
            ]);
            final cleanRo = bbRo.replaceAll('[', '').replaceAll(']', '').trim();
            if (cleanRo.isNotEmpty &&
                !cleanRo.toLowerCase().contains('error') &&
                !cleanRo.toLowerCase().contains('not found')) {
              cpuVal = cleanRo;
              break;
            }
          }
        } catch (e) {
          logger.severe('Attempt $attempt failed to load CPU: $e');
        }
        if (attempt < 10) {
          await Future.delayed(const Duration(milliseconds: 1500));
        }
      }

      if (cpuVal.isEmpty) cpuVal = 'N/A';
      if (!isCurrent()) return;
      _info['CPU'] = cpuVal;
      notifyListeners();
    }());

    // Pipeline task for IMEI with retry and fallback
    tasks.add(() async {
      final isIq5 = AdbMonitor.isIq5Device(
        pcasn: pcasnVal,
        sysConfig: sysConfig,
        buildProduct: buildProduct,
      );
      var imeiVal = '';
      for (var attempt = 1; attempt <= 5; attempt++) {
        if (!isCurrent()) return;
        try {
          var cmd = isIq5 ? 'imeino' : 'imei';
          var val = await _command([
            'adb',
            '-s',
            serial,
            'shell',
            'testeepapi',
            'r',
            cmd,
          ]);
          var cleanVal = val.trim().replaceAll(RegExp(r'\s+'), '');
          var isNumeric =
              cleanVal.isNotEmpty && RegExp(r'^\d+$').hasMatch(cleanVal);
          if (!isNumeric) {
            val = await _command([
              'adb',
              '-s',
              serial,
              'shell',
              'testeepapi',
              'r',
              isIq5 ? 'imei' : 'imeino',
            ]);
            cleanVal = val.trim().replaceAll(RegExp(r'\s+'), '');
            isNumeric =
                cleanVal.isNotEmpty && RegExp(r'^\d+$').hasMatch(cleanVal);
          }
          if (isNumeric) {
            imeiVal = cleanVal;
            break;
          }
        } catch (e) {
          logger.severe('Attempt $attempt failed to load IMEI: $e');
        }
        if (attempt < 5) await Future.delayed(const Duration(seconds: 1));
      }
      if (imeiVal.isEmpty) imeiVal = 'N/A';
      if (!isCurrent()) return;
      _info['IMEI'] = imeiVal;
      notifyListeners();
    }());

    // Pipeline task for SYSPN with retry
    tasks.add(() async {
      var syspnVal = '';
      for (var attempt = 1; attempt <= 5; attempt++) {
        if (!isCurrent()) return;
        try {
          final val = (await _command([
            'adb',
            '-s',
            serial,
            'shell',
            'testeepapi',
            'r',
            'syspn',
          ])).trim();
          if (val.isNotEmpty &&
              !val.toLowerCase().contains('error') &&
              !val.toLowerCase().contains('not found')) {
            syspnVal = val;
            break;
          }
        } catch (e) {
          logger.severe('Attempt $attempt failed to load SYSPN: $e');
        }
        if (attempt < 5) await Future.delayed(const Duration(seconds: 1));
      }
      if (syspnVal.isEmpty) syspnVal = 'N/A';
      if (syspnVal.contains('\xff') ||
          syspnVal.contains('ÿ') ||
          syspnVal.contains('\ufffd') ||
          syspnVal.contains('?????') ||
          RegExp(r'\?{5,}').hasMatch(syspnVal)) {
        syspnVal = 'Chưa test MMI';
      }
      if (!isCurrent()) return;
      _info['SYSPN'] = syspnVal;
      notifyListeners();
    }());

    // Pipeline task for LCMPN with retry
    tasks.add(() async {
      var lcmpnVal = '';
      for (var attempt = 1; attempt <= 5; attempt++) {
        if (!isCurrent()) return;
        try {
          final val = (await _command([
            'adb',
            '-s',
            serial,
            'shell',
            'testeepapi',
            'r',
            'lcmpn',
          ])).trim();
          if (val.isNotEmpty &&
              !val.toLowerCase().contains('error') &&
              !val.toLowerCase().contains('not found')) {
            lcmpnVal = val;
            break;
          }
        } catch (e) {
          logger.severe('Attempt $attempt failed to load LCMPN: $e');
        }
        if (attempt < 5) await Future.delayed(const Duration(seconds: 1));
      }
      if (lcmpnVal.isEmpty) lcmpnVal = 'N/A';
      if (lcmpnVal.contains('\xff') ||
          lcmpnVal.contains('ÿ') ||
          lcmpnVal.contains('\ufffd') ||
          lcmpnVal.contains('?????') ||
          RegExp(r'\?{5,}').hasMatch(lcmpnVal)) {
        lcmpnVal = 'Panel ko nạp màn hình';
      }
      if (!isCurrent()) return;
      _info['LCMPN'] = lcmpnVal;
      notifyListeners();
    }());

    // Wait for commands and timer to finish
    await Future.wait([...tasks, splashTimer]);

    if (isCurrent()) {
      final syssnVal = _info['SYSSN'] ?? '';
      final syssnUpper = syssnVal.toUpperCase();
      final syspnVal = _info['SYSPN'] ?? '';
      final pcasnVal = _info['PCASN'] ?? '';

      final is5 = AdbMonitor.isIq5Device(
        pcasn: pcasnVal,
        syspn: syspnVal,
        syssn: syssnVal,
      );
      final is4 = AdbMonitor.isIq4Device(
        pcasn: pcasnVal,
        syspn: syspnVal,
        syssn: syssnVal,
      );

      // Refine overlayText if it was DUT or NO DATA
      if (_overlayText == 'DUT' || _overlayText == 'NO DATA') {
        if (is5) {
          _overlayText = 'IQ5';
        } else if (is4) {
          _overlayText = 'IQ4';
        }
      }

      // Check if PCASN or SYSSN indicates LCMPN override
      if (is5 || syssnUpper.startsWith('QP4')) {
        _info['LCMPN'] = 'Chú ý Panel này không được chạy lại màn hình';
      } else if (syssnUpper.startsWith('QPH') &&
          _info['LCMPN'] == 'Panel ko nạp màn hình') {
        _info['LCMPN'] =
            'Panel này có 2 loại màn hình, nếu màn hình bị lỗi hiển thị -> hãy chạy lại màn hình';
      }

      _showOverlay = false;
      _recordHistorySnapshot();
      notifyListeners();
    }
  }

  void _recordHistorySnapshot() {
    if (!_deviceConnected || _currentDut.isEmpty) return;
    final pcasn = _info['PCASN'] ?? 'N/A';
    if (pcasn.isEmpty || pcasn == 'Đang đọc...') return;
    final syssn = _info['SYSSN'] ?? '';
    final syspn = _info['SYSPN'] ?? '';
    final model = isIq5Device(pcasn: pcasn, syssn: syssn, syspn: syspn)
        ? 'IQ5'
        : (isIq4Device(pcasn: pcasn, syssn: syssn, syspn: syspn)
              ? 'IQ4'
              : (_overlayText == 'IQ5' || _overlayText == 'IQ4'
                    ? _overlayText
                    : 'DUT'));
    final pgSum = _powerGResult?.displaySummary ?? (_info['PowerG'] ?? 'N/A');
    final srfSum = _srfResult?.displaySummary ?? (_info['SRF'] ?? 'N/A');
    final rfPass =
        (_powerGResult?.isPass ?? false) || (_srfResult?.isPass ?? false);
    history.recordSnapshot(
      serial: _currentDut,
      modelName: model,
      stationResult: _stationResult,
      info: _info,
      powerGSummary: pgSum,
      srfSummary: srfSum,
      isRfPass: rfPass,
    );
  }

  String formatFullDutReport() {
    if (!_deviceConnected || _currentDut.isEmpty) {
      return 'Chưa có thiết bị DUT kết nối.';
    }
    final pcasn = _info['PCASN'] ?? 'N/A';
    final syssn = _info['SYSSN'] ?? 'N/A';
    final syspn = _info['SYSPN'] ?? 'N/A';
    final model = isIq5Device(pcasn: pcasn, syssn: syssn, syspn: syspn)
        ? 'IQ5'
        : (isIq4Device(pcasn: pcasn, syssn: syssn, syspn: syspn)
              ? 'IQ4'
              : (_overlayText == 'IQ5' || _overlayText == 'IQ4'
                    ? _overlayText
                    : 'DUT'));
    final entry = DutHistoryEntry(
      timestamp: DateTime.now(),
      serial: _currentDut,
      modelName: model,
      stationResult: _stationResult,
      info: _info,
      powerGSummary:
          _powerGResult?.displaySummary ?? (_info['PowerG'] ?? 'N/A'),
      srfSummary: _srfResult?.displaySummary ?? (_info['SRF'] ?? 'N/A'),
      isRfPass:
          (_powerGResult?.isPass ?? false) || (_srfResult?.isPass ?? false),
    );
    return entry.formatReport();
  }

  Future<void> reloadCurrentDut() async {
    if (_currentDut.isEmpty) return;
    logger.info('User requested full reload for $_currentDut');
    await _loadDut(_currentDut);
  }

  Future<void> _fetchStation(String syssn, String serial) async {
    final generation = _loadGeneration;
    bool isCurrent() =>
        _running && _currentDut == serial && _loadGeneration == generation;
    final scope = CommandScope.current;
    final client = HttpClient();
    void cancelRequest() => client.close(force: true);
    scope?.onCancel(cancelRequest);
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
    try {
      final url =
          'https://vncmes.ces.myfiinet.com/api/cloudmes-mes/feign/dataDeviceApi/getProcessBySnForQolsys?strSSN=$syssn&strPlantCode=CABG_VN';
      logger.info('Fetching station for $syssn: $url');
      final request = await client
          .getUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      request.headers.set('accept', '*/*');
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      if (response.statusCode == 200) {
        final content = await response
            .transform(utf8.decoder)
            .join()
            .timeout(const Duration(seconds: 5));
        final trimmed = content.trim();
        if (!trimmed.startsWith('<?xml')) {
          if (isCurrent()) {
            _stationResult = 'NO DATA';
            notifyListeners();
          }
          return;
        }

        final match = RegExp(
          r'<string[^>]*>\s*([\s\S]*?)\s*</string>',
        ).firstMatch(trimmed);
        var result = '';
        if (match != null) {
          result = match.group(1)!.trim();
        } else {
          result = trimmed;
        }

        if (isCurrent()) {
          _stationResult = result.isEmpty ? 'NO DATA' : result;
          logger.info('Station result for $syssn: $result');
          notifyListeners();
        }
      } else {
        if (isCurrent()) {
          _stationResult = 'NO DATA';
          notifyListeners();
        }
      }
    } catch (e) {
      logger.severe('Failed to fetch station for $syssn: $e');
      if (isCurrent()) {
        _stationResult = 'NO DATA';
        notifyListeners();
      }
    } finally {
      scope?.removeCallback(cancelRequest);
      client.close(force: true);
    }
  }

  Future<void> _checkRfAsync(
    String serial, {
    bool checkPowerG = true,
    bool checkSrf = true,
  }) async {
    if (!_running || !_bootReady || _currentDut != serial) {
      return;
    }
    if ((checkPowerG && _isPowerGTesting) || (checkSrf && _isSrfTesting)) {
      return;
    }
    final generation = _loadGeneration;
    bool isCurrent() =>
        _running &&
        _bootReady &&
        _currentDut == serial &&
        generation == _loadGeneration;

    if (checkPowerG) {
      _isPowerGTesting = true;
      _info['PowerG'] = 'Đang kiểm tra...';
    }
    if (checkSrf) {
      _isSrfTesting = true;
      _info['SRF'] = 'Đang kiểm tra...';
    }
    notifyListeners();

    try {
      final futures = <Future<void>>[];
      if (checkPowerG) {
        futures.add(
          _verifyPowerG(serial).then((pgRes) {
            if (isCurrent()) {
              _powerGResult = pgRes;
              _info['PowerG'] = pgRes.displaySummary;
              _recordHistorySnapshot();
              notifyListeners();
            }
          }),
        );
      }
      if (checkSrf) {
        futures.add(
          _verifySrf(serial, _goldenPanelSerial).then((srfRes) {
            if (isCurrent()) {
              _srfResult = srfRes;
              _info['SRF'] = srfRes.displaySummary;
              _recordHistorySnapshot();
              notifyListeners();
            }
          }),
        );
      }
      await Future.wait<void>(futures);
    } catch (e) {
      logger.severe('Failed to run RF check for $serial: $e');
      if (isCurrent()) {
        if (checkPowerG) _info['PowerG'] = 'Lỗi test RF';
        if (checkSrf) _info['SRF'] = 'Lỗi test RF';
      }
    } finally {
      if (isCurrent()) {
        if (checkPowerG) _isPowerGTesting = false;
        if (checkSrf) _isSrfTesting = false;
        _recordHistorySnapshot();
        notifyListeners();
      }
    }
  }

  Future<void> retestRf() async {
    if (_currentDut.isEmpty) return;
    logger.info('User requested RF retest for $_currentDut');
    final scope = _readScope;
    if (scope != null) await scope.run(() => _checkRfAsync(_currentDut));
  }

  Future<void> retestPowerGOnly() async {
    if (_currentDut.isEmpty) return;
    logger.info('User requested PowerG-only retest for $_currentDut');
    final scope = _readScope;
    if (scope != null) {
      await scope.run(
        () => _checkRfAsync(_currentDut, checkPowerG: true, checkSrf: false),
      );
    }
  }

  Future<void> retestSrfOnly() async {
    if (_currentDut.isEmpty) return;
    logger.info('User requested SRF-only retest for $_currentDut');
    final scope = _readScope;
    if (scope != null) {
      await scope.run(
        () => _checkRfAsync(_currentDut, checkPowerG: false, checkSrf: true),
      );
    }
  }

  void _clearDut() {
    _readScope?.cancel();
    _readScope = null;
    _loading = false;
    logger.info('All DUTs disconnected (was: $_currentDut)');
    _currentDut = '';
    _loadGeneration++;
    _bootReady = false;
    _deviceConnected = false;
    _isSuccessStatus = false;
    _status = 'Waiting for DUT connection...';
    _info = {
      'PCASN': 'N/A',
      'SYSSN': 'N/A',
      'SYSPN': 'N/A',
      'LCMPN': 'N/A',
      'IMEI': 'N/A',
      'CPU': 'N/A',
      'PowerG': 'N/A',
      'SRF': 'N/A',
    };
    _powerGResult = null;
    _srfResult = null;
    _isPowerGTesting = false;
    _isSrfTesting = false;
    _overlayText = 'NO DATA';
    _showOverlay = true;
    _stationResult = 'N/A';
    setDutLogSession(null); // Switch back to startup.log
    notifyListeners();
  }

  Future<void> _checkDevices() async {
    final epoch = _loopEpoch;
    final devices = await _getDevices();
    if (!_running || epoch != _loopEpoch) return;

    // Detect disappearance before any per-device metadata commands can stall.
    if (_currentDut.isNotEmpty && !devices.contains(_currentDut)) {
      _clearDut();
    }
    final List<String> activeDuts = [];
    String? detectedGolden;

    for (final dev in devices) {
      final autoRun = (await _command([
        'adb',
        '-s',
        dev,
        'shell',
        'getprop',
        'persist.auto.run',
      ])).trim();
      if (!_running || epoch != _loopEpoch) return;
      if (autoRun == '1') {
        detectedGolden = dev;
      } else {
        activeDuts.add(dev);
      }
    }

    if (_goldenPanelSerial != detectedGolden) {
      _goldenPanelSerial = detectedGolden;
      logger.info('Golden panel detected: $_goldenPanelSerial');
      notifyListeners();
    }

    activeDuts.sort();

    // Check if connected DUT list has changed
    bool listChanged = false;
    if (activeDuts.length != _allDuts.length) {
      listChanged = true;
    } else {
      for (int i = 0; i < activeDuts.length; i++) {
        if (activeDuts[i] != _allDuts[i]) {
          listChanged = true;
          break;
        }
      }
    }

    if (listChanged) {
      _allDuts = activeDuts;
      logger.info('Connected DUT list updated: $_allDuts');
      notifyListeners();
    }

    if (_allDuts.isEmpty) {
      if (_currentDut.isNotEmpty ||
          _overlayText != 'NO DATA' ||
          !_showOverlay) {
        _clearDut();
      }
    } else {
      // If our current selected DUT is no longer connected, select the first available one
      if (!_allDuts.contains(_currentDut)) {
        final newDut = _allDuts[0];
        logger.info(
          'Current DUT disconnected or none selected, selecting first available: $newDut',
        );
        unawaited(_loadDut(newDut));
      } else if (_currentDut.isNotEmpty && _deviceConnected && !_loading) {
        // Check if currently connected DUT has started a reboot
        try {
          final serial = _currentDut;
          final ready = await _bootGate
              .isReady(serial)
              .timeout(const Duration(seconds: 5));
          if (!_running || _currentDut != serial) return;
          if (!ready || !_bootReady) {
            unawaited(_loadDut(serial));
          }
        } catch (_) {}
      }
    }
  }

  void updateStatus(String newStatus, bool isSuccess) {
    _status = newStatus;
    _isSuccessStatus = isSuccess;
    notifyListeners();
  }
}
