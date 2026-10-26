import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_update_models.dart';
import 'package:path/path.dart' as p;

import '../../tool/update_manifest.dart';

void main() {
  late Directory root;
  late Directory artifacts;
  late Directory notes;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('update_manifest_test_');
    artifacts = await Directory(p.join(root.path, 'artifacts')).create();
    notes = await Directory(p.join(root.path, 'releases')).create();
  });

  tearDown(() => root.delete(recursive: true));

  test('reads the pubspec version with its build number', () {
    expect(readPubspecVersion('name: x\nversion: 0.6.1+18\n'), '0.6.1+18');
    expect(readPubspecVersion("version: '1.0.0'"), '1.0.0');
    expect(readPubspecVersion('name: x'), isNull);
  });

  test(
    'writes a manifest the app can parse, with sizes and checksums',
    () async {
      final arm64 = utf8.encode('arm64 package');
      await File(
        p.join(artifacts.path, 'jotsy-v0.6.1-arm64-v8a.apk'),
      ).writeAsBytes(arm64);
      await File(
        p.join(artifacts.path, 'jotsy-v0.6.1-x86_64.apk'),
      ).writeAsString('x86 package');
      await File(p.join(artifacts.path, 'SHA256SUMS.txt')).writeAsString('-');
      await File(
        p.join(notes.path, 'v0.6.1.md'),
      ).writeAsString('# Release v0.6.1\n\n## 新增\n- 应用内更新\n');
      await File(
        p.join(notes.path, 'v0.6.1.en.md'),
      ).writeAsString('# Release v0.6.1\n\n## New\n- In-app updates\n');

      final text = await buildUpdateManifest(
        pubspec: 'version: 0.6.1+18\n',
        tag: 'v0.6.1',
        artifacts: artifacts,
        releaseNotes: notes,
        publishedAt: DateTime.utc(2026, 10, 20, 8),
      );

      final release = AppUpdateManifest.parse(jsonDecode(text))!;
      expect(release.version, AppVersion.tryParse('0.6.1+18'));
      expect(release.publishedAt, DateTime.utc(2026, 10, 20, 8));
      expect(release.assets.map((a) => a.name), <String>[
        'jotsy-v0.6.1-arm64-v8a.apk',
        'jotsy-v0.6.1-x86_64.apk',
      ]);
      final asset = release.assetFor(const <String>['arm64-v8a'])!;
      expect(asset.size, arm64.length);
      expect(asset.sha256, sha256.convert(arm64).toString());
      expect(release.notesFor('zh'), '## 新增\n- 应用内更新');
      expect(release.notesFor('en'), '## New\n- In-app updates');
    },
  );

  test('falls back to the release body for missing Chinese notes', () async {
    await File(p.join(artifacts.path, 'a-arm64-v8a.apk')).writeAsString('a');
    final text = await buildUpdateManifest(
      pubspec: 'version: 0.6.1+18\n',
      tag: 'v0.6.1',
      artifacts: artifacts,
      releaseNotes: notes,
      fallbackNotes: '## 正文\n- 来自 Release',
    );
    final release = AppUpdateManifest.parse(jsonDecode(text))!;
    expect(release.notesFor('zh'), '## 正文\n- 来自 Release');
    expect(release.notes.containsKey('en'), isFalse);
  });

  test('refuses a tag that does not match the pubspec version', () async {
    await File(p.join(artifacts.path, 'a-arm64-v8a.apk')).writeAsString('a');
    await expectLater(
      buildUpdateManifest(
        pubspec: 'version: 0.6.1+18\n',
        tag: 'v0.6.2',
        artifacts: artifacts,
        releaseNotes: notes,
      ),
      throwsStateError,
    );
  });

  test('refuses to write a manifest without APKs', () async {
    await expectLater(
      buildUpdateManifest(
        pubspec: 'version: 0.6.1+18\n',
        tag: 'v0.6.1',
        artifacts: artifacts,
        releaseNotes: notes,
      ),
      throwsStateError,
    );
  });

  test('lists desktop packages next to the APKs with sizes and checksums, '
      'which APK-only clients skip', () async {
    await File(
      p.join(artifacts.path, 'jotsy-v0.6.1-arm64-v8a.apk'),
    ).writeAsString('arm64 package');
    final setup = utf8.encode('windows installer');
    final tarball = utf8.encode('linux tarball');
    await File(
      p.join(artifacts.path, 'jotsy-v0.6.1-windows-x64-setup.exe'),
    ).writeAsBytes(setup);
    await File(
      p.join(artifacts.path, 'jotsy-v0.6.1-windows-x64.zip'),
    ).writeAsString('windows portable');
    await File(
      p.join(artifacts.path, 'jotsy-v0.6.1-linux-x64.tar.gz'),
    ).writeAsBytes(tarball);
    await File(p.join(artifacts.path, 'SHA256SUMS.txt')).writeAsString('-');

    final text = await buildUpdateManifest(
      pubspec: 'version: 0.6.1+18\n',
      tag: 'v0.6.1',
      artifacts: artifacts,
      releaseNotes: notes,
    );

    final json = jsonDecode(text) as Map<String, Object?>;
    final rawAssets = (json['assets']! as List).cast<Map<String, Object?>>();
    expect(rawAssets.map((a) => a['name']), <String>[
      'jotsy-v0.6.1-arm64-v8a.apk',
      'jotsy-v0.6.1-linux-x64.tar.gz',
      'jotsy-v0.6.1-windows-x64-setup.exe',
      'jotsy-v0.6.1-windows-x64.zip',
    ]);
    for (final asset in rawAssets) {
      expect(asset['size'], isA<int>());
      expect(asset['sha256'], matches(RegExp(r'^[0-9a-f]{64}$')));
    }

    final release = AppUpdateManifest.parse(json)!;
    // Android 只会从 APK 里挑选。
    expect(release.assets.map((a) => a.name), <String>[
      'jotsy-v0.6.1-arm64-v8a.apk',
    ]);
    final windows = release.desktopAssetFor(AppUpdateDesktopTarget.windows)!;
    expect(windows.name, 'jotsy-v0.6.1-windows-x64-setup.exe');
    expect(windows.size, setup.length);
    expect(windows.sha256, sha256.convert(setup).toString());
    final linux = release.desktopAssetFor(AppUpdateDesktopTarget.linux)!;
    expect(linux.name, 'jotsy-v0.6.1-linux-x64.tar.gz');
    expect(linux.sha256, sha256.convert(tarball).toString());
  });

  test('refuses a manifest with only desktop packages', () async {
    await File(
      p.join(artifacts.path, 'jotsy-v0.6.1-linux-x64.tar.gz'),
    ).writeAsString('linux');
    await expectLater(
      buildUpdateManifest(
        pubspec: 'version: 0.6.1+18\n',
        tag: 'v0.6.1',
        artifacts: artifacts,
        releaseNotes: notes,
      ),
      throwsStateError,
    );
  });
}
