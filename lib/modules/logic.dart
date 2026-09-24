// lib/modules/logic.dart

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'utils.dart';
import 'logger_config.dart';
import 'services/powerg_service.dart';
import 'services/srf_service.dart';

class AdbMonitor extends ChangeNotifier {
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

  bool _isRfTesting = false;
  bool get isRfTesting => _isRfTesting;

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

  AdbMonitor() {
    start();
  }

  void start() {
    if (_running) return;
    _running = true;
    logger.info('Monitor thread started.');
    _loop();
  }

  void stop() {
    _running = false;
    logger.info('Stopping monitor thread...');
  }

  Future<void> _loop() async {
    while (_running) {
      try {
        await _checkDevices();
      } catch (e) {
        logger.severe('Error in check devices loop: $e');
      }
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Future<List<String>> _getDevices() async {
    final out = await runCmd(['adb', 'devices']);
    final lines = out
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final devices = <String>[];
    if (lines.length > 1) {
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i];
        if (line.contains('device') && !line.contains('offline')) {
          final parts = line.split(RegExp(r'\s+'));
          if (parts.isNotEmpty) {
            devices.add(parts[0]);
          }
        }
      }
    }
    return devices;
  }

  Future<void> selectDut(String serial) async {
    if (!_allDuts.contains(serial)) return;
    await _loadDut(serial);
  }

  Future<bool> _waitForBootComplete(String serial) async {
    logger.info('Checking boot status on DUT: $serial...');

    // Quick check first if already booted
    try {
      final bootCompleted = (await runCmd([
        'adb',
        '-s',
        serial,
        'shell',
        'getprop',
        'sys.boot_completed',
      ])).trim();
      if (bootCompleted == '1') {
        logger.info('DUT $serial already boot completed.');
        return true;
      }
    } catch (_) {}

    logger.info(
      'DUT $serial is booting. Waiting for sys.boot_completed == 1...',
    );
    _status = 'DUT đang khởi động (Đang chờ boot xong)...';
    _overlayText = 'BOOTING';
    _showOverlay = true;
    notifyListeners();

    // Poll up to 60 seconds (60 iterations x 1s)
    for (var i = 0; i < 60; i++) {
      if (!_running || _currentDut != serial) return false;
      await Future.delayed(const Duration(seconds: 1));

      try {
        final bootCompleted = (await runCmd([
          'adb',
          '-s',
          serial,
          'shell',
          'getprop',
          'sys.boot_completed',
        ])).trim();
        final devBoot = (await runCmd([
          'adb',
          '-s',
          serial,
          'shell',
          'getprop',
          'dev.bootcomplete',
        ])).trim();
        if (bootCompleted == '1' || devBoot == '1') {
          logger.info('DUT $serial reached boot_completed after ${i + 1}s.');
          // Grace period for system daemons and RIL to initialize
          await Future.delayed(const Duration(milliseconds: 1500));
          return true;
        }
      } catch (_) {}
    }

    logger.warning('DUT $serial timed out waiting for boot completed.');
    return false;
  }

  Future<void> _loadDut(String serial) async {
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
    await _waitForBootComplete(serial);
    if (_currentDut != serial) return;

    _status = 'DUT đã boot xong. Đang nạp thông số...';
    _overlayText = 'READING';
    notifyListeners();

    // 2. Trigger non-blocking RF check now that boot is complete
    _checkRfAsync(serial);

    // 3. Read PCASN with retry up to 5 times (allows I2C/EEPROM to settle)
    String pcasnVal = 'N/A';
    for (var attempt = 1; attempt <= 5; attempt++) {
      if (_currentDut != serial) return;
      try {
        final out = await runCmd([
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

    if (_currentDut != serial) return;
    _info['PCASN'] = pcasnVal;

    // Determine target overlay text
    if (pcasnVal.toUpperCase().startsWith('QB95')) {
      _overlayText = 'IQ5';
    } else if (pcasnVal.toUpperCase().startsWith('QB94')) {
      _overlayText = 'IQ4';
    } else {
      _overlayText = 'NO DATA';
    }
    notifyListeners();

    // Spawn 3-second splash timer
    final splashTimer = Future.delayed(const Duration(seconds: 3));

    // 4. Fetch all other parameters with retry loops
    final List<Future<void>> tasks = [];

    // Pipeline task for SYSSN and Station Result (with retry up to 5 times)
    tasks.add(() async {
      var syssnVal = '';
      for (var attempt = 1; attempt <= 5; attempt++) {
        if (_currentDut != serial) return;
        try {
          final out = await runCmd([
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

      if (_currentDut != serial) return;
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
        if (_currentDut != serial) return;
        try {
          var val = await runCmd([
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
          final bb1 = await runCmd([
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
            final bbRo = await runCmd([
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
      if (_currentDut != serial) return;
      _info['CPU'] = cpuVal;
      notifyListeners();
    }());

    // Pipeline task for IMEI with retry and fallback
    tasks.add(() async {
      var imeiVal = '';
      for (var attempt = 1; attempt <= 5; attempt++) {
        if (_currentDut != serial) return;
        try {
          var val = await runCmd([
            'adb',
            '-s',
            serial,
            'shell',
            'testeepapi',
            'r',
            'imei',
          ]);
          var cleanVal = val.trim().replaceAll(RegExp(r'\s+'), '');
          final isNumeric =
              cleanVal.isNotEmpty && RegExp(r'^\d+$').hasMatch(cleanVal);
          if (!isNumeric) {
            val = await runCmd([
              'adb',
              '-s',
              serial,
              'shell',
              'testeepapi',
              'r',
              'imeino',
            ]);
            cleanVal = val.trim().replaceAll(RegExp(r'\s+'), '');
          }
          if (cleanVal.isNotEmpty &&
              !cleanVal.toLowerCase().contains('error') &&
              !cleanVal.toLowerCase().contains('not found')) {
            imeiVal = cleanVal;
            break;
          }
        } catch (e) {
          logger.severe('Attempt $attempt failed to load IMEI: $e');
        }
        if (attempt < 5) await Future.delayed(const Duration(seconds: 1));
      }
      if (imeiVal.isEmpty) imeiVal = 'N/A';
      if (_currentDut != serial) return;
      _info['IMEI'] = imeiVal;
      notifyListeners();
    }());

    // Pipeline task for SYSPN with retry
    tasks.add(() async {
      var syspnVal = '';
      for (var attempt = 1; attempt <= 5; attempt++) {
        if (_currentDut != serial) return;
        try {
          final val = (await runCmd([
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
      if (_currentDut != serial) return;
      _info['SYSPN'] = syspnVal;
      notifyListeners();
    }());

    // Pipeline task for LCMPN with retry
    tasks.add(() async {
      var lcmpnVal = '';
      for (var attempt = 1; attempt <= 5; attempt++) {
        if (_currentDut != serial) return;
        try {
          final val = (await runCmd([
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
      if (_currentDut != serial) return;
      _info['LCMPN'] = lcmpnVal;
      notifyListeners();
    }());

    // Wait for commands and timer to finish
    await Future.wait([...tasks, splashTimer]);

    if (_currentDut == serial) {
      // Check if SYSSN starts with QP5, QH5, or QP4 to override LCMPN
      final syssnVal = _info['SYSSN'] ?? '';
      final syssnUpper = syssnVal.toUpperCase();
      if (syssnUpper.startsWith('QP5') ||
          syssnUpper.startsWith('QH5') ||
          syssnUpper.startsWith('QP4')) {
        _info['LCMPN'] = 'Chú ý Panel này không được chạy lại màn hình';
      } else if (syssnUpper.startsWith('QPH') &&
          _info['LCMPN'] == 'Panel ko nạp màn hình') {
        _info['LCMPN'] =
            'Panel này có 2 loại màn hình, nếu màn hình bị lỗi hiển thị -> hãy chạy lại màn hình';
      }

      _showOverlay = false;
      notifyListeners();
    }
  }

  Future<void> _fetchStation(String syssn, String serial) async {
    final client = HttpClient();
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
      final response = await request.close();
      if (response.statusCode == 200) {
        final content = await response.transform(utf8.decoder).join();
        final trimmed = content.trim();
        if (!trimmed.startsWith('<?xml')) {
          if (_currentDut == serial) {
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

        if (_currentDut == serial) {
          _stationResult = result.isEmpty ? 'NO DATA' : result;
          logger.info('Station result for $syssn: $result');
          notifyListeners();
        }
      } else {
        if (_currentDut == serial) {
          _stationResult = 'NO DATA';
          notifyListeners();
        }
      }
    } catch (e) {
      logger.severe('Failed to fetch station for $syssn: $e');
      if (_currentDut == serial) {
        _stationResult = 'NO DATA';
        notifyListeners();
      }
    } finally {
      client.close();
    }
  }

  Future<void> _checkRfAsync(String serial) async {
    if (_currentDut != serial) return;
    _isRfTesting = true;
    _info['PowerG'] = 'Đang kiểm tra...';
    _info['SRF'] = 'Đang kiểm tra...';
    notifyListeners();

    try {
      final pgService = PowerGService();
      final srfService = SrfService();

      // Run PowerG and SRF checks concurrently
      final pgFuture = pgService.verifyDut(serial);
      final srfFuture = srfService.verifyDut(
        serial,
        goldenSerial: _goldenPanelSerial,
      );

      final pgRes = await pgFuture;
      if (_currentDut == serial) {
        _powerGResult = pgRes;
        _info['PowerG'] = pgRes.displaySummary;
        notifyListeners();
      }

      final srfRes = await srfFuture;
      if (_currentDut == serial) {
        _srfResult = srfRes;
        _info['SRF'] = srfRes.displaySummary;
        notifyListeners();
      }
    } catch (e) {
      logger.severe('Failed to run RF check for $serial: $e');
      if (_currentDut == serial) {
        _info['PowerG'] = 'Lỗi test RF';
        _info['SRF'] = 'Lỗi test RF';
      }
    } finally {
      if (_currentDut == serial) {
        _isRfTesting = false;
        notifyListeners();
      }
    }
  }

  Future<void> retestRf() async {
    if (_currentDut.isEmpty) return;
    logger.info('User requested RF retest for $_currentDut');
    await _checkRfAsync(_currentDut);
  }

  Future<void> _checkDevices() async {
    final devices = await _getDevices();
    final List<String> activeDuts = [];
    String? detectedGolden;

    for (final dev in devices) {
      final autoRun = (await runCmd([
        'adb',
        '-s',
        dev,
        'shell',
        'getprop',
        'persist.auto.run',
      ])).trim();
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
        logger.info('All DUTs disconnected (was: $_currentDut)');
        _currentDut = '';
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
        _isRfTesting = false;
        _overlayText = 'NO DATA';
        _showOverlay = true;
        _stationResult = 'N/A';
        setDutLogSession(null); // Switch back to startup.log
        notifyListeners();
      }
    } else {
      // If our current selected DUT is no longer connected, select the first available one
      if (!_allDuts.contains(_currentDut)) {
        final newDut = _allDuts[0];
        logger.info(
          'Current DUT disconnected or none selected, selecting first available: $newDut',
        );
        await _loadDut(newDut);
      } else if (_currentDut.isNotEmpty && _deviceConnected) {
        // Check if currently connected DUT has started a reboot
        try {
          final bootCompleted = (await runCmd([
            'adb',
            '-s',
            _currentDut,
            'shell',
            'getprop',
            'sys.boot_completed',
          ])).trim();
          if (bootCompleted.isNotEmpty &&
              bootCompleted != '1' &&
              bootCompleted != 'N/A') {
            logger.info(
              'Detected current DUT $_currentDut reboot in progress (sys.boot_completed=$bootCompleted). Reloading...',
            );
            await _loadDut(_currentDut);
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
