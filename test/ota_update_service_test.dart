import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_dut_info/modules/services/ota_update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File configFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dut_ota_test_');
    configFile = File('${tempDir.path}/update_config.json');

    OtaUpdateService().setCustomConfigFileForTesting(configFile);
    OtaUpdateService().setCustomServerDirForTesting(null);
  });

  tearDown(() async {
    OtaUpdateService().setCustomConfigFileForTesting(null);
    OtaUpdateService().setCustomServerDirForTesting(null);

    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('SemanticVersion Unit Tests', () {
    test('Correctly parses SemVer formats with and without prefix', () {
      final v1 = SemanticVersion.tryParse('1.0.0');
      expect(v1, isNotNull);
      expect(v1!.major, equals(1));
      expect(v1.minor, equals(0));
      expect(v1.patch, equals(0));
      expect(v1.build, isNull);

      final v2 = SemanticVersion.tryParse('v2.2.1+5');
      expect(v2, isNotNull);
      expect(v2!.major, equals(2));
      expect(v2.minor, equals(2));
      expect(v2.patch, equals(1));
      expect(v2.build, equals(5));

      final v3 = SemanticVersion.tryParse('2.3');
      expect(v3, isNotNull);
      expect(v3!.major, equals(2));
      expect(v3.minor, equals(3));
      expect(v3.patch, equals(0));
    });

    test('Rejects invalid SemVer strings', () {
      expect(SemanticVersion.tryParse(null), isNull);
      expect(SemanticVersion.tryParse(''), isNull);
      expect(SemanticVersion.tryParse('invalid'), isNull);
      expect(SemanticVersion.tryParse('1.2.3.4'), isNull);
      expect(SemanticVersion.tryParse('v'), isNull);
    });

    test('SemanticVersion comparisons work correctly', () {
      final v1 = SemanticVersion.tryParse('2.2.0')!;
      final v2 = SemanticVersion.tryParse('2.2.1')!;
      final v3 = SemanticVersion.tryParse('2.3.0')!;
      final v4 = SemanticVersion.tryParse('3.0.0')!;

      expect(v1 < v2, isTrue);
      expect(v2 > v1, isTrue);
      expect(v2 < v3, isTrue);
      expect(v3 < v4, isTrue);
      expect(v1 <= v2, isTrue);
      expect(v2 >= v1, isTrue);
      expect(v2 == SemanticVersion.tryParse('v2.2.1'), isTrue);
    });

    test('Prerelease and build numbers comparison', () {
      final rc1 = SemanticVersion.tryParse('2.3.0-rc.1')!;
      final rc2 = SemanticVersion.tryParse('2.3.0-rc.2')!;
      final release = SemanticVersion.tryParse('2.3.0')!;
      final build1 = SemanticVersion.tryParse('2.3.0+1')!;
      final build2 = SemanticVersion.tryParse('2.3.0+2')!;

      expect(rc1 < rc2, isTrue);
      expect(rc2 < release, isTrue);
      expect(build1 < build2, isTrue);
      expect(release <= build1, isTrue);
    });

    test('displayVersion and toString', () {
      final v = SemanticVersion.tryParse('2.2.1')!;
      expect(v.toString(), equals('2.2.1'));
      expect(v.displayVersion, equals('v2.2.1'));
    });
  });

  group('Package Name & UNC Path Helpers', () {
    test('isValidPackageName validates correct package filenames', () {
      expect(
        OtaUpdateService.isValidPackageName(
          'JA_DUT_Info_v2.2.1_Windows_x64.zip',
        ),
        isTrue,
      );
      expect(
        OtaUpdateService.isValidPackageName('JA_DUT_Info_2.3.0.zip'),
        isTrue,
      );
      expect(
        OtaUpdateService.isValidPackageName(
          'JA_DUT_Info_v2.3.0-rc1+4_Windows_x64.zip',
        ),
        isTrue,
      );

      // Invalid
      expect(
        OtaUpdateService.isValidPackageName('../JA_DUT_Info_v2.2.1.zip'),
        isFalse,
      );
      expect(
        OtaUpdateService.isValidPackageName('JA_LAN_Messenger_v1.0.0.zip'),
        isFalse,
      );
      expect(OtaUpdateService.isValidPackageName('JA_DUT_Info.exe'), isFalse);
    });

    test('extractSmbShareRoot extracts UNC root correctly', () {
      expect(
        OtaUpdateService.extractSmbShareRoot(
          r'\\10.81.141.226\temp\FBT\JA_PROJECT\JA_Update\JA_DUT_Info',
        ),
        equals(r'\\10.81.141.226\temp'),
      );
      expect(
        OtaUpdateService.extractSmbShareRoot('//10.81.141.226/temp/folder'),
        equals(r'\\10.81.141.226\temp'),
      );
      expect(OtaUpdateService.extractSmbShareRoot(r'C:\Local\Path'), isNull);
      expect(OtaUpdateService.extractSmbShareRoot(r'\\incomplete'), isNull);
    });
  });

  group('OtaUpdateConfig Unit Tests', () {
    test('Defaults do not embed SMB credentials', () {
      final defaults = OtaUpdateConfig.defaults();

      expect(defaults.username, isEmpty);
      expect(defaults.password, isEmpty);
    });

    test('Serialization to/from JSON works properly', () {
      const config = OtaUpdateConfig(
        serverPath: r'\\server\share\path',
        username: 'admin',
        password: 'secret_password',
        checkInterval: 'weekly',
        autoDownload: true,
      );

      final json = config.toJson();
      expect(json['serverPath'], equals(r'\\server\share\path'));
      expect(json['username'], equals('admin'));
      expect(json['password'], equals('secret_password'));
      expect(json['checkInterval'], equals('weekly'));
      expect(json['autoDownload'], isTrue);

      final restored = OtaUpdateConfig.fromJson(json);
      expect(restored.serverPath, equals(config.serverPath));
      expect(restored.username, equals(config.username));
      expect(restored.password, equals(config.password));
      expect(restored.checkInterval, equals(config.checkInterval));
      expect(restored.autoDownload, equals(config.autoDownload));
    });

    test('loadExternalConfigFile and saveExternalConfigFile', () async {
      final service = OtaUpdateService();
      expect(await configFile.exists(), isFalse);

      const customConfig = OtaUpdateConfig(
        serverPath: r'\\custom\server\path',
        username: 'test_user',
        password: 'test_pass',
        checkInterval: 'monthly',
      );

      await service.saveExternalConfigFile(customConfig);
      expect(await configFile.exists(), isTrue);

      final loaded = await service.loadExternalConfigFile();
      expect(loaded, isNotNull);
      expect(loaded!.serverPath, equals(r'\\custom\server\path'));
      expect(loaded.username, equals('test_user'));
      expect(loaded.checkInterval, equals('monthly'));
    });
  });

  group('shouldCheckForUpdates Tests', () {
    test('Handles checkInterval frequencies correctly', () {
      final service = OtaUpdateService();
      final now = DateTime(2026, 9, 21, 12, 0);

      // When interval is 'off'
      expect(
        service.shouldCheckForUpdates(
          interval: 'off',
          lastCheckTime: now.subtract(const Duration(days: 100)),
          now: now,
        ),
        isFalse,
      );

      // When lastCheckTime is null
      expect(
        service.shouldCheckForUpdates(
          interval: 'daily',
          lastCheckTime: null,
          now: now,
        ),
        isTrue,
      );

      // Daily
      expect(
        service.shouldCheckForUpdates(
          interval: 'daily',
          lastCheckTime: now.subtract(const Duration(hours: 23)),
          now: now,
        ),
        isFalse,
      );
      expect(
        service.shouldCheckForUpdates(
          interval: 'daily',
          lastCheckTime: now.subtract(const Duration(hours: 25)),
          now: now,
        ),
        isTrue,
      );

      // Weekly
      expect(
        service.shouldCheckForUpdates(
          interval: 'weekly',
          lastCheckTime: now.subtract(const Duration(days: 6)),
          now: now,
        ),
        isFalse,
      );
      expect(
        service.shouldCheckForUpdates(
          interval: 'weekly',
          lastCheckTime: now.subtract(const Duration(days: 8)),
          now: now,
        ),
        isTrue,
      );
    });
  });

  group('generateApplyUpdateScript Tests', () {
    test('Generates valid script targeting ja_dut_info.exe', () {
      final script = OtaUpdateService.generateApplyUpdateScript(
        oldPid: 1234,
        sourceDir: r'C:\Temp\Extract',
        targetDir: r'C:\App\JA_DUT_Info',
        exeName: 'ja_dut_info.exe',
      );

      expect(script, contains('set "OLD_PID=1234"'));
      expect(script, contains(r'set "SRC_DIR=C:\Temp\Extract"'));
      expect(script, contains(r'set "DST_DIR=C:\App\JA_DUT_Info"'));
      expect(script, contains('set "EXE_NAME=ja_dut_info.exe"'));
      expect(script, contains('tasklist /fi "PID eq %OLD_PID%"'));
      expect(script, contains('robocopy "%SRC_DIR%" "%DST_DIR%"'));
      expect(script, contains('start "" "%DST_DIR%\\%EXE_NAME%"'));
      expect(script, contains(':rollback'));
    });

    test('Throws ArgumentError on invalid or injected paths', () {
      expect(
        () => OtaUpdateService.generateApplyUpdateScript(
          oldPid: 1234,
          sourceDir: 'C:\\Temp\\"evil',
          targetDir: 'C:\\App',
          exeName: 'ja_dut_info.exe',
        ),
        throwsArgumentError,
      );

      expect(
        () => OtaUpdateService.generateApplyUpdateScript(
          oldPid: -1,
          sourceDir: 'C:\\Temp',
          targetDir: 'C:\\App',
          exeName: 'ja_dut_info.exe',
        ),
        throwsArgumentError,
      );
    });
  });

  group('checkForUpdates Discovery Tests', () {
    test('Discovers newer version from version.json', () async {
      final serverDir = Directory('${tempDir.path}/server')..createSync();
      OtaUpdateService().setCustomServerDirForTesting(serverDir);

      // Create a dummy zip file
      final zipFile = File(
        '${serverDir.path}/JA_DUT_Info_v2.3.0_Windows_x64.zip',
      );
      zipFile.writeAsStringSync('dummy zip content');

      // Create version.json
      final versionJson = File('${serverDir.path}/version.json');
      versionJson.writeAsStringSync(
        jsonEncode({
          'version': '2.3.0',
          'fileName': 'JA_DUT_Info_v2.3.0_Windows_x64.zip',
          'releaseNotes': 'Bản cập nhật tính năng LAN OTA Update',
          'releaseDate': '2026-09-21T15:00:00Z',
        }),
      );

      final result = await OtaUpdateService().checkForUpdates(
        overrideServerPath: serverDir.path,
        overrideCurrentVersion: '2.2.1',
      );

      expect(result.isConnectionSuccess, isTrue);
      expect(result.hasUpdate, isTrue);
      expect(result.packageInfo, isNotNull);
      expect(result.packageInfo!.version.toString(), equals('2.3.0'));
      expect(
        result.packageInfo!.releaseNotes,
        equals('Bản cập nhật tính năng LAN OTA Update'),
      );
    });

    test('Discovers newer version by scanning .zip filename', () async {
      final serverDir = Directory('${tempDir.path}/server_scan')..createSync();
      OtaUpdateService().setCustomServerDirForTesting(serverDir);

      // Create 2 zip files: v2.2.0 and v2.3.1
      File(
        '${serverDir.path}/JA_DUT_Info_v2.2.0_Windows_x64.zip',
      ).writeAsStringSync('old zip');
      File(
        '${serverDir.path}/JA_DUT_Info_v2.3.1_Windows_x64.zip',
      ).writeAsStringSync('new zip');

      final result = await OtaUpdateService().checkForUpdates(
        overrideServerPath: serverDir.path,
        overrideCurrentVersion: '2.2.1',
      );

      expect(result.isConnectionSuccess, isTrue);
      expect(result.hasUpdate, isTrue);
      expect(result.packageInfo, isNotNull);
      expect(result.packageInfo!.version.toString(), equals('2.3.1'));
    });

    test('Reports no update when current version is equal or higher', () async {
      final serverDir = Directory('${tempDir.path}/server_same')..createSync();
      OtaUpdateService().setCustomServerDirForTesting(serverDir);

      File(
        '${serverDir.path}/JA_DUT_Info_v2.2.1_Windows_x64.zip',
      ).writeAsStringSync('same zip');

      final result = await OtaUpdateService().checkForUpdates(
        overrideServerPath: serverDir.path,
        overrideCurrentVersion: '2.2.1',
      );

      expect(result.isConnectionSuccess, isTrue);
      expect(result.hasUpdate, isFalse);
    });
  });
}
