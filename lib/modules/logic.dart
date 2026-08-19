// lib/modules/logic.dart

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'utils.dart';
import 'logger_config.dart';

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
  };
  Map<String, String> get info => _info;

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
    final lines = out.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
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

  Future<bool> _checkIsDut(String serial) async {
    final out = await runCmd(['adb', '-s', serial, 'shell', 'getprop', 'persist.auto.run']);
    final isDut = out != '1';
    logger.info('Check DUT [$serial] - persist.auto.run: \'$out\' -> Is DUT: $isDut');
    return isDut;
  }

  Future<void> selectDut(String serial) async {
    if (!_allDuts.contains(serial)) return;
    await _loadDut(serial);
  }

  Future<void> _loadDut(String serial) async {
    logger.info('Loading DUT: $serial');
    _currentDut = serial;
    _deviceConnected = true;
    _isSuccessStatus = true;
    _status = 'Connected: $serial';
    _stationResult = 'Loading...';
    
    _overlayText = 'LOADING';
    _showOverlay = true;
    notifyListeners();

    // 1. Read PCASN first to determine device model overlay
    String pcasnVal = 'N/A';
    try {
      pcasnVal = await runCmd(['adb', '-s', serial, 'shell', 'testeepapi', 'r', 'pcasn']);
      if (pcasnVal.isEmpty || pcasnVal.toLowerCase().contains('error') || pcasnVal.toLowerCase().contains('not found')) {
        pcasnVal = 'N/A';
      }
    } catch (e) {
      logger.severe('Failed to read PCASN: $e');
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

    // 2. Fetch all other parameters in parallel
    final commands = {
      'SYSPN': ['adb', '-s', serial, 'shell', 'testeepapi', 'r', 'syspn'],
      'LCMPN': ['adb', '-s', serial, 'shell', 'testeepapi', 'r', 'lcmpn'],
      'IMEI': ['adb', '-s', serial, 'shell', 'testeepapi', 'r', 'imei'],
      'CPU': ['adb', '-s', serial, 'shell', 'getprop', 'gsm.version.baseband'],
    };

    final List<Future<void>> tasks = [];

    // Pipeline task for SYSSN and Station Result
    tasks.add(() async {
      var syssnVal = '';
      try {
        syssnVal = await runCmd(['adb', '-s', serial, 'shell', 'testeepapi', 'r', 'syssn']);
        if (syssnVal.isEmpty || syssnVal.toLowerCase().contains('error') || syssnVal.toLowerCase().contains('not found')) {
          syssnVal = 'N/A';
        }
        if (syssnVal.contains('\xff') || syssnVal.contains('ÿ') || syssnVal.contains('\ufffd') || syssnVal.contains('?????') || RegExp(r'\?{5,}').hasMatch(syssnVal)) {
          syssnVal = 'Chưa test MMI';
        }
      } catch (e) {
        logger.severe('Failed to load SYSSN: $e');
        syssnVal = 'N/A';
      }

      if (_currentDut != serial) return;
      _info['SYSSN'] = syssnVal;

      // Update log session
      var safeSyssn = syssnVal.replaceAll(RegExp(r'[^a-zA-Z0-9\-_]'), '');
      if (safeSyssn.isEmpty || safeSyssn == 'NA' || safeSyssn == 'ChuatestMMI') {
        safeSyssn = 'UNPROGRAMMED_DUT_$serial';
      }
      if (safeSyssn != 'N/A') {
        setDutLogSession(safeSyssn);
      }
      notifyListeners();

      // Now query station result using the retrieved SYSSN
      if (syssnVal != 'N/A' && syssnVal != 'Chưa test MMI' && syssnVal.isNotEmpty && !syssnVal.contains('?')) {
        await _fetchStation(syssnVal, serial);
      } else {
        _stationResult = 'N/A';
        notifyListeners();
      }
    }());

    commands.forEach((key, cmd) {
      tasks.add(() async {
        var val = '';
        try {
          if (key == 'IMEI') {
            val = await runCmd(cmd);
            final cleanVal = val.trim().replaceAll(RegExp(r'\s+'), '');
            final isNumeric = cleanVal.isNotEmpty && RegExp(r'^\d+$').hasMatch(cleanVal);
            if (!isNumeric) {
              logger.info('[IMEI] Value \'$val\' is not numeric. Falling back to testeepapi r imeino');
              val = await runCmd(['adb', '-s', serial, 'shell', 'testeepapi', 'r', 'imeino']);
            }
          } else {
            val = await runCmd(cmd);
          }
          
          if (val.isEmpty || val.toLowerCase().contains('error') || val.toLowerCase().contains('not found')) {
            val = 'N/A';
          }
          
          if (key == 'CPU') {
            val = val.replaceAll('[', '').replaceAll(']', '');
          }

          if (val.contains('\xff') || val.contains('ÿ') || val.contains('\ufffd') || val.contains('?????') || RegExp(r'\?{5,}').hasMatch(val)) {
            if (key == 'SYSSN' || key == 'SYSPN') {
              val = 'Chưa test MMI';
            } else if (key == 'LCMPN') {
              val = 'Panel ko nạp màn hình';
            }
          }
        } catch (e) {
          logger.severe('Failed to load $key: $e');
          val = 'N/A';
        }

        if (_currentDut != serial) return;
        _info[key] = val;
        notifyListeners();
      }());
    });

    // Wait for commands and timer to finish
    await Future.wait([...tasks, splashTimer]);

    if (_currentDut == serial) {
      // Check if SYSSN starts with QP5, QH5, or QP4 to override LCMPN
      final syssnVal = _info['SYSSN'] ?? '';
      final syssnUpper = syssnVal.toUpperCase();
      if (syssnUpper.startsWith('QP5') || syssnUpper.startsWith('QH5') || syssnUpper.startsWith('QP4')) {
        _info['LCMPN'] = 'Chú ý Panel này không được chạy lại màn hình';
      } else if (syssnUpper.startsWith('QPH') && _info['LCMPN'] == 'Panel ko nạp màn hình') {
        _info['LCMPN'] = 'Panel này có 2 loại màn hình, nếu màn hình bị lỗi hiển thị -> hãy chạy lại màn hình';
      }

      _showOverlay = false;
      notifyListeners();
    }
  }

  Future<void> _fetchStation(String syssn, String serial) async {
    final client = HttpClient();
    client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    try {
      final url = 'https://vncmes.ces.myfiinet.com/api/cloudmes-mes/feign/dataDeviceApi/getProcessBySnForQolsys?strSSN=$syssn&strPlantCode=CABG_VN';
      logger.info('Fetching station for $syssn: $url');
      final request = await client.getUrl(Uri.parse(url)).timeout(const Duration(seconds: 5));
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

        final match = RegExp(r'<string[^>]*>\s*([\s\S]*?)\s*</string>').firstMatch(trimmed);
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

  Future<void> _checkDevices() async {
    final devices = await _getDevices();
    final List<String> activeDuts = [];

    for (final dev in devices) {
      if (await _checkIsDut(dev)) {
        activeDuts.add(dev);
      }
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
      if (_currentDut.isNotEmpty || _overlayText != 'NO DATA' || !_showOverlay) {
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
        };
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
        logger.info('Current DUT disconnected or none selected, selecting first available: $newDut');
        await _loadDut(newDut);
      }
    }
  }

  void updateStatus(String newStatus, bool isSuccess) {
    _status = newStatus;
    _isSuccessStatus = isSuccess;
    notifyListeners();
  }
}
