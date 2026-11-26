import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_data_directory.dart';
import 'package:node_diary/core/services/app_data_location.dart';
import 'package:node_diary/core/services/app_platform.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  late Directory supportDir;
  late Directory exeDir;

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('jotsy_location_test_');
    supportDir = Directory(p.join(tempRoot.path, 'support'))..createSync();
    exeDir = Directory(p.join(tempRoot.path, 'app'))..createSync();
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    invalidateAppDataRootCache();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (tempRoot.existsSync()) {
      tempRoot.deleteSync(recursive: true);
    }
  });

  AppDataLocationStore makeStore({bool withExe = true}) => AppDataLocationStore(
    supportDirectoryProvider: () async => supportDir,
    executableDirectoryProvider: () => withExe ? exeDir : null,
  );

  group('AppPlatform.supportsCustomDataDirectory', () {
    test('enabled on desktop platforms and disabled on mobile', () {
      for (final platform in <TargetPlatform>[
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.macOS,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(AppPlatform.supportsCustomDataDirectory, isTrue);
      }

      for (final platform in <TargetPlatform>[
        TargetPlatform.android,
        TargetPlatform.iOS,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(AppPlatform.supportsCustomDataDirectory, isFalse);
      }
    });
  });

  group('BOM JSON codec', () {
    test('round-trips UTF-8 BOM JSON containing non-ASCII paths', () {
      const sample = <String, Object?>{
        'version': 1,
        'path': r'D:\我的日记\JotsyData',
        'useDefault': false,
      };
      final encoded = encodeDataLocationJson(sample);
      expect(encoded.startsWith('\uFEFF'), isTrue);

      final decoded = decodeJsonObjectWithOptionalBom(encoded);
      expect(decoded, equals(sample));
      expect(decodeJsonObjectWithOptionalBom('  \uFEFF  '), isNull);
      expect(decodeJsonObjectWithOptionalBom('{broken'), isNull);
    });
  });

  group('AppDataLocationStore.resolve precedence', () {
    test('defaults to support directory when no config exists', () async {
      final store = makeStore();
      final res = await store.resolve();

      expect(res.defaultRoot.path, p.normalize(supportDir.path));
      expect(res.activeRoot.path, p.normalize(supportDir.path));
      expect(res.isCustomLocation, isFalse);
      expect(res.isPortableConfig, isFalse);
      expect(res.pendingTargetPath, isNull);
    });

    test(
      'uses installer defaultPath seed for fresh users without support DB',
      () async {
        final presetDir = p.join(tempRoot.path, '自定义数据目录');
        File(
          p.join(exeDir.path, executableDataLocationConfigFileName),
        ).writeAsStringSync(
          encodeDataLocationJson(<String, Object?>{
            'version': 1,
            'defaultPath': presetDir,
          }),
        );

        final store = makeStore();
        final res = await store.resolve();

        expect(res.activeRoot.path, p.normalize(presetDir));
        expect(res.isCustomLocation, isTrue);
        expect(res.isPortableConfig, isFalse);
      },
    );

    test(
      'ignores installer defaultPath seed when support DB already exists',
      () async {
        File(
          p.join(supportDir.path, appDatabaseFileName),
        ).writeAsBytesSync(<int>[1, 2, 3]);
        File(
          p.join(exeDir.path, executableDataLocationConfigFileName),
        ).writeAsStringSync(
          encodeDataLocationJson(<String, Object?>{
            'version': 1,
            'defaultPath': p.join(tempRoot.path, 'OtherData'),
          }),
        );

        final store = makeStore();
        final res = await store.resolve();

        expect(res.activeRoot.path, p.normalize(supportDir.path));
        expect(res.isCustomLocation, isFalse);
      },
    );

    test(
      'resolves portable relative path against executable directory',
      () async {
        File(
          p.join(exeDir.path, executableDataLocationConfigFileName),
        ).writeAsStringSync(
          jsonEncode(<String, Object?>{
            'version': 1,
            'portable': true,
            'path': 'JotsyData',
          }),
        );

        final store = makeStore();
        final res = await store.resolve();

        expect(
          res.activeRoot.path,
          p.normalize(p.join(exeDir.path, 'JotsyData')),
        );
        expect(res.isCustomLocation, isTrue);
        expect(res.isPortableConfig, isTrue);
      },
    );

    test(
      'explicit user data_location.json overrides executable config and preserves pending target',
      () async {
        final portableDir = p.join(exeDir.path, 'PortableData');
        final userCustomDir = p.join(tempRoot.path, 'UserChosen');
        final pendingDir = p.join(tempRoot.path, 'PendingChosen');

        File(
          p.join(exeDir.path, executableDataLocationConfigFileName),
        ).writeAsStringSync(
          jsonEncode(<String, Object?>{
            'version': 1,
            'portable': true,
            'path': 'PortableData',
          }),
        );

        final store = makeStore();
        await store.saveUserConfig(
          supportDir: supportDir,
          targetPath: userCustomDir,
          pendingTargetPath: pendingDir,
        );

        final res = await store.resolve();
        expect(res.activeRoot.path, p.normalize(userCustomDir));
        expect(res.pendingTargetPath, p.normalize(pendingDir));
        expect(res.isCustomLocation, isTrue);
        expect(res.isPortableConfig, isFalse);

        // Portable config side-car also got updated when relocating from exeDir.
        final portableJson = decodeJsonObjectWithOptionalBom(
          File(
            p.join(exeDir.path, executableDataLocationConfigFileName),
          ).readAsStringSync(),
        );
        expect(portableJson?['path'], p.normalize(userCustomDir));
        expect(p.normalize(portableDir), isNot(res.activeRoot.path));

        // Resetting back to default forces useDefault: true even if exe config exists.
        await store.saveUserConfig(supportDir: supportDir, targetPath: null);
        final resetRes = await store.resolve();
        expect(resetRes.activeRoot.path, p.normalize(supportDir.path));
        expect(resetRes.isCustomLocation, isFalse);
        expect(resetRes.isPortableConfig, isFalse);
      },
    );
  });

  group('AppDataLocationStore.inspectTarget & markers', () {
    test(
      'rejects empty, relative, drive root, same, nested, and app bundle targets',
      () async {
        final current = Directory(p.join(tempRoot.path, 'current'))
          ..createSync();
        final store = makeStore();

        Future<AppDataLocationTargetStatus> check(String candidate) async {
          final result = await store.inspectTarget(
            candidate,
            currentRoot: current.path,
            defaultRoot: supportDir.path,
          );
          return result.status;
        }

        expect(await check('   '), AppDataLocationTargetStatus.invalidEmpty);
        expect(
          await check('relative/sub'),
          AppDataLocationTargetStatus.invalidRelative,
        );
        expect(await check('/'), AppDataLocationTargetStatus.invalidDriveRoot);
        expect(
          await check(current.path),
          AppDataLocationTargetStatus.invalidSameAsCurrent,
        );
        expect(
          await check(p.join(current.path, 'child')),
          AppDataLocationTargetStatus.invalidNestedWithCurrent,
        );
        expect(
          await check(tempRoot.path),
          AppDataLocationTargetStatus.invalidNestedWithCurrent,
        );
        expect(
          await check(exeDir.path),
          AppDataLocationTargetStatus.invalidInsideAppBundle,
        );
        expect(
          await check(p.join(exeDir.path, 'data')),
          AppDataLocationTargetStatus.invalidInsideAppBundle,
        );
        expect(
          await check(p.join(exeDir.path, 'data', 'nested')),
          AppDataLocationTargetStatus.invalidInsideAppBundle,
        );

        // Portable build allows sibling folder outside data/.
        expect(
          await check(p.join(exeDir.path, 'PortableData')),
          AppDataLocationTargetStatus.validEmpty,
        );

        // Installed build (with unins000.exe) blocks any subdirectory under exeDir.
        File(p.join(exeDir.path, 'unins000.exe')).writeAsStringSync('stub');
        expect(
          await check(p.join(exeDir.path, 'InstalledSub')),
          AppDataLocationTargetStatus.invalidInsideAppBundle,
        );
      },
    );

    test(
      'distinguishes empty, OS metadata, unrelated files, and existing DB',
      () async {
        final current = Directory(p.join(tempRoot.path, 'current'))
          ..createSync();
        final store = makeStore();

        final newDir = p.join(tempRoot.path, 'new_nonexistent');
        expect(
          (await store.inspectTarget(
            newDir,
            currentRoot: current.path,
            defaultRoot: supportDir.path,
          )).status,
          AppDataLocationTargetStatus.validEmpty,
        );

        final osOnlyDir = Directory(p.join(tempRoot.path, 'os_only'))
          ..createSync();
        File(p.join(osOnlyDir.path, 'desktop.ini')).writeAsStringSync('');
        File(p.join(osOnlyDir.path, '.DS_Store')).writeAsStringSync('');
        expect(
          (await store.inspectTarget(
            osOnlyDir.path,
            currentRoot: current.path,
            defaultRoot: supportDir.path,
          )).status,
          AppDataLocationTargetStatus.validEmpty,
        );

        // Default support directory with only shared_preferences & data_location is validEmpty.
        File(
          p.join(supportDir.path, 'shared_preferences.json'),
        ).writeAsStringSync('{}');
        File(
          p.join(supportDir.path, dataLocationConfigFileName),
        ).writeAsStringSync('{}');
        expect(
          (await store.inspectTarget(
            supportDir.path,
            currentRoot: current.path,
            defaultRoot: supportDir.path,
          )).status,
          AppDataLocationTargetStatus.validEmpty,
        );

        final nonEmptyOther = Directory(p.join(tempRoot.path, 'other_files'))
          ..createSync();
        File(
          p.join(nonEmptyOther.path, 'readme.txt'),
        ).writeAsStringSync('hello');
        expect(
          (await store.inspectTarget(
            nonEmptyOther.path,
            currentRoot: current.path,
            defaultRoot: supportDir.path,
          )).status,
          AppDataLocationTargetStatus.invalidNonEmptyOther,
        );

        final existingDbDir = Directory(p.join(tempRoot.path, 'existing_jotsy'))
          ..createSync();
        File(
          p.join(existingDbDir.path, appDatabaseFileName),
        ).writeAsBytesSync(<int>[1]);
        expect(
          (await store.inspectTarget(
            existingDbDir.path,
            currentRoot: current.path,
            defaultRoot: supportDir.path,
          )).status,
          AppDataLocationTargetStatus.validExistingJotsyData,
        );
      },
    );

    test('detects non-writable directory when parent denies writes', () async {
      if (!Platform.isLinux && !Platform.isMacOS) return;
      final readOnlyDir = Directory(p.join(tempRoot.path, 'readonly'))
        ..createSync();
      Process.runSync('chmod', <String>['555', readOnlyDir.path]);
      addTearDown(
        () => Process.runSync('chmod', <String>['755', readOnlyDir.path]),
      );

      // Skip assertion if running as root where mode 0555 remains writable.
      var canStillWrite = false;
      final probe = File(p.join(readOnlyDir.path, '.root_check'));
      try {
        probe.writeAsStringSync('x');
        probe.deleteSync();
        canStillWrite = true;
      } on FileSystemException {
        canStillWrite = false;
      }
      if (canStillWrite) return;

      final store = makeStore();
      final result = await store.inspectTarget(
        p.join(readOnlyDir.path, 'target'),
        currentRoot: supportDir.path,
        defaultRoot: supportDir.path,
      );
      expect(result.status, AppDataLocationTargetStatus.invalidNotWritable);
    });

    test('writes and reads bound root marker safely', () async {
      final store = makeStore();
      expect(await store.readBoundRootMarker(supportDir), isNull);

      final markerDir = Directory(p.join(tempRoot.path, 'marker_root'));
      await store.writeBoundRootMarker(markerDir);
      expect(
        await store.readBoundRootMarker(markerDir),
        p.normalize(markerDir.path),
      );

      File(
        p.join(markerDir.path, boundRootMarkerFileName),
      ).writeAsStringSync('{corrupt');
      expect(await store.readBoundRootMarker(markerDir), isNull);
    });

    test(
      'appDataRootDirectory & appFontsBaseDirectory respect custom desktop config',
      () async {
        final customRoot = p.join(tempRoot.path, 'CustomDesktopRoot');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              (MethodCall call) async {
                if (call.method == 'getApplicationSupportDirectory') {
                  return supportDir.path;
                }
                return tempRoot.path;
              },
            );

        await AppDataLocationStore.instance.saveUserConfig(
          supportDir: supportDir,
          targetPath: customRoot,
        );
        invalidateAppDataRootCache();

        final root = await appDataRootDirectory();
        final fonts = await appFontsBaseDirectory();
        expect(p.normalize(root.path), p.normalize(customRoot));
        expect(p.normalize(fonts.path), p.normalize(customRoot));
        expect(root.existsSync(), isTrue);
      },
    );
  });
}
