import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_update_service.dart';

void main() {
  group('AppVersion', () {
    test('parses tags with and without a v prefix, build or pre-release', () {
      expect(AppVersion.tryParse('v0.6.0'), const AppVersion(0, 6, 0));
      expect(
        AppVersion.tryParse('0.6.0+17'),
        const AppVersion(0, 6, 0, build: 17),
      );
      expect(
        AppVersion.tryParse('V1.2.3-beta.1+4'),
        const AppVersion(1, 2, 3, preRelease: 'beta.1', build: 4),
      );
      expect(AppVersion.tryParse('v1.2'), const AppVersion(1, 2, 0));
      expect(AppVersion.tryParse('Release v0.6.0'), isNull);
      expect(AppVersion.tryParse(''), isNull);
    });

    test('treats a tag without a build number as the same release', () {
      final installed = AppVersion.tryParse('0.6.0+17')!;
      expect(installed.compareTo(AppVersion.tryParse('v0.6.0')!), 0);
      expect(AppVersion.tryParse('v0.6.1')!.isNewerThan(installed), isTrue);
      expect(AppVersion.tryParse('0.6.0+18')!.isNewerThan(installed), isTrue);
      expect(AppVersion.tryParse('0.5.9+30')!.isNewerThan(installed), isFalse);
    });

    test('orders pre-releases below the final release', () {
      final beta1 = AppVersion.tryParse('0.7.0-beta.1')!;
      final beta2 = AppVersion.tryParse('0.7.0-beta.2')!;
      final rc = AppVersion.tryParse('0.7.0-rc.1')!;
      final finalRelease = AppVersion.tryParse('0.7.0')!;
      expect(beta2.isNewerThan(beta1), isTrue);
      expect(rc.isNewerThan(beta2), isTrue);
      expect(finalRelease.isNewerThan(rc), isTrue);
      expect(beta1.isNewerThan(AppVersion.tryParse('0.6.9')!), isTrue);
    });
  });

  group('AppUpdateRelease.assetFor', () {
    final release = releaseFromChecksums(
      'v0.6.0',
      '${'1' * 64}  jotsy-v0.6.0-armeabi-v7a.apk\n'
          '${'2' * 64}  jotsy-v0.6.0-arm64-v8a.apk\n'
          '${'3' * 64} *jotsy-v0.6.0-x86_64.apk\n',
    )!;

    test('picks the split APK of the preferred device ABI', () {
      expect(
        release.assetFor(const <String>['arm64-v8a', 'armeabi-v7a'])!.name,
        'jotsy-v0.6.0-arm64-v8a.apk',
      );
      expect(
        release.assetFor(const <String>['armeabi-v7a', 'armeabi'])!.name,
        'jotsy-v0.6.0-armeabi-v7a.apk',
      );
      expect(
        release.assetFor(const <String>['x86_64', 'x86'])!.name,
        'jotsy-v0.6.0-x86_64.apk',
      );
    });

    test('returns null instead of an APK the device cannot install', () {
      expect(release.assetFor(const <String>['mips']), isNull);
      expect(release.assetFor(const <String>[]), isNull);
    });

    test('falls back to a universal APK when no split matches', () {
      final universal = AppUpdateRelease(
        version: const AppVersion(1, 0, 0),
        tag: 'v1.0.0',
        assets: <AppUpdateAsset>[
          AppUpdateAsset(
            name: 'jotsy-v1.0.0-arm64-v8a.apk',
            url: Uri.parse('https://example.com/a.apk'),
          ),
          AppUpdateAsset(
            name: 'jotsy-v1.0.0.apk',
            url: Uri.parse('https://example.com/b.apk'),
          ),
        ],
      );
      expect(
        universal.assetFor(const <String>['x86'])!.name,
        'jotsy-v1.0.0.apk',
      );
    });
  });

  test('releaseFromChecksums lists APKs with their SHA-256', () {
    final release = releaseFromChecksums(
      'v0.6.1',
      '${'A' * 64}  jotsy-v0.6.1-arm64-v8a.apk\r\n'
          'not a checksum line\n'
          '${'b' * 64}  notes.txt\n',
    )!;
    expect(release.version, const AppVersion(0, 6, 1));
    expect(release.assets.single.name, 'jotsy-v0.6.1-arm64-v8a.apk');
    expect(release.assets.single.sha256, 'a' * 64);
    expect(release.assets.single.size, isNull);
    expect(releaseFromChecksums('v0.6.1', 'empty'), isNull);
    expect(releaseFromChecksums('main', '${'a' * 64}  x.apk'), isNull);
  });

  group('AppUpdateManifest', () {
    test('round-trips through JSON with derived download URLs', () {
      final sha = 'a' * 64;
      final json = AppUpdateManifest.toJson(
        version: '0.6.1+18',
        tag: 'v0.6.1',
        publishedAt: DateTime.utc(2026, 10, 20, 8),
        notes: const <String, String>{
          'zh': '# Release v0.6.1\n\n## 新增\n- 应用内更新',
          'en': '# Release v0.6.1\n\n## New\n- In-app updates',
        },
        assets: <AppUpdateAsset>[
          AppUpdateAsset(
            name: 'jotsy-v0.6.1-arm64-v8a.apk',
            url: Uri.parse('https://unused.example'),
            size: 51428875,
            sha256: sha,
          ),
        ],
      );
      final release = AppUpdateManifest.parse(json)!;
      expect(release.version, AppVersion.tryParse('0.6.1+18'));
      expect(release.tag, 'v0.6.1');
      expect(release.publishedAt, DateTime.utc(2026, 10, 20, 8));
      expect(release.notesFor('en'), '## New\n- In-app updates');
      expect(release.notesFor('zh'), '## 新增\n- 应用内更新');
      final asset = release.assets.single;
      expect(asset.abi, 'arm64-v8a');
      expect(asset.size, 51428875);
      expect(asset.sha256, sha);
      expect(
        asset.url.toString(),
        'https://github.com/CikeSeven/jotsy/releases/download/v0.6.1/'
        'jotsy-v0.6.1-arm64-v8a.apk',
      );
    });

    test('rejects future schemas and manifests without usable APKs', () {
      expect(
        AppUpdateManifest.parse(<String, Object?>{
          'schema': AppUpdateManifest.schema + 1,
          'version': '9.0.0',
          'tag': 'v9.0.0',
          'assets': <Object?>[
            <String, Object?>{'name': 'a.apk'},
          ],
        }),
        isNull,
      );
      expect(
        AppUpdateManifest.parse(<String, Object?>{
          'schema': 1,
          'version': '0.6.1',
          'tag': 'v0.6.1',
          'assets': <Object?>[
            <String, Object?>{'name': 'SHA256SUMS.txt'},
          ],
        }),
        isNull,
      );
      expect(AppUpdateManifest.parse('not a map'), isNull);
    });

    test('drops malformed sizes and checksums but keeps the asset', () {
      final release = AppUpdateManifest.parse(<String, Object?>{
        'schema': 1,
        'version': '0.6.1',
        'tag': 'v0.6.1',
        'assets': <Object?>[
          <String, Object?>{
            'name': 'jotsy-v0.6.1-x86_64.apk',
            'size': -1,
            'sha256': 'not-a-hash',
          },
        ],
      })!;
      expect(release.assets.single.size, isNull);
      expect(release.assets.single.sha256, isNull);
    });
  });

  test('parseGitHubRelease reads the asset digest and the release body', () {
    final release = parseGitHubRelease(<String, Object?>{
      'tag_name': 'v0.6.0',
      'published_at': '2026-10-17T15:27:03Z',
      'body':
          '# Release v0.6.0\r\n\r\n[English](https://x) | 简体中文\r\n\r\n'
          '## 版本要点\r\n- 网盘备份\r\n\r\n**Full Changelog**: https://x',
      'assets': <Object?>[
        <String, Object?>{
          'name': 'jotsy-v0.6.0-arm64-v8a.apk',
          'size': 51428875,
          'digest':
              'sha256:3c1a0decbfd49129cc3a4fc28f4ed90ad761f7c5a2a153ef675c5a55461c5182',
        },
        <String, Object?>{'name': 'SHA256SUMS.txt', 'size': 10},
      ],
    })!;
    expect(release.version, const AppVersion(0, 6, 0));
    expect(release.assets, hasLength(1));
    expect(
      release.assets.single.sha256,
      '3c1a0decbfd49129cc3a4fc28f4ed90ad761f7c5a2a153ef675c5a55461c5182',
    );
    expect(release.notesFor('en'), '## 版本要点\n- 网盘备份');
  });

  test('cleanReleaseNotes keeps inner headings and drops web-only lines', () {
    expect(
      cleanReleaseNotes(
        '# Release v0.6.0\n\nEnglish | [简体中文](./v0.6.0.md)\n\n'
        '## Highlights\n- A\n\n# Not a title\n',
      ),
      '## Highlights\n- A\n\n# Not a title',
    );
  });

  group('AppUpdatePreferences', () {
    test('decodes field by field and falls back on bad values', () {
      final prefs = AppUpdatePreferences.decode(
        '{"autoCheck":"yes","lastCheckedAt":"bad","skippedVersion":"0.6.1",'
        '"sourceId":"ghfast","customMirror":" ","lastGoodSourceId":7}',
      );
      expect(prefs.autoCheck, isTrue);
      expect(prefs.lastCheckedAt, isNull);
      expect(prefs.skippedVersion, '0.6.1');
      expect(prefs.sourceId, 'ghfast');
      expect(prefs.customMirror, isNull);
      expect(prefs.lastGoodSourceId, isNull);
      expect(
        AppUpdatePreferences.decode('{oops'),
        const AppUpdatePreferences(),
      );
    });

    test('round-trips and clears nullable fields through copyWith', () {
      final prefs = const AppUpdatePreferences().copyWith(
        autoCheck: false,
        lastCheckedAt: DateTime(2026, 10, 17, 8),
        skippedVersion: () => '0.6.1',
        customMirror: () => 'https://mirror.example/',
      );
      expect(AppUpdatePreferences.decode(prefs.encode()), prefs);
      final cleared = prefs.copyWith(
        skippedVersion: () => null,
        customMirror: () => null,
      );
      expect(cleared.skippedVersion, isNull);
      expect(cleared.customMirror, isNull);
      expect(cleared.autoCheck, isFalse);
    });

    test('auto-checks at most once every two hours', () {
      final now = DateTime(2026, 10, 17, 12);
      expect(const AppUpdatePreferences().shouldAutoCheck(now), isTrue);
      final recent = AppUpdatePreferences(
        lastCheckedAt: now.subtract(const Duration(minutes: 90)),
      );
      expect(recent.shouldAutoCheck(now), isFalse);
      final due = AppUpdatePreferences(
        lastCheckedAt: now.subtract(const Duration(hours: 2)),
      );
      expect(due.shouldAutoCheck(now), isTrue);
      expect(
        AppUpdatePreferences(
          lastCheckedAt: now.add(const Duration(days: 3)),
        ).shouldAutoCheck(now),
        isTrue,
        reason: 'a clock moved backwards must not block checks forever',
      );
      expect(
        AppUpdatePreferences(autoCheck: false).shouldAutoCheck(now),
        isFalse,
      );
    });
  });

  group('AppUpdateSource', () {
    test('normalizes custom mirror prefixes', () {
      expect(
        AppUpdateSource.normalizeMirrorPrefix(' https://mirror.example '),
        'https://mirror.example/',
      );
      expect(
        AppUpdateSource.normalizeMirrorPrefix(
          'https://mirror.example/https://github.com/CikeSeven/jotsy',
        ),
        'https://mirror.example/',
      );
      expect(AppUpdateSource.normalizeMirrorPrefix('ftp://x.example'), isNull);
      expect(AppUpdateSource.normalizeMirrorPrefix('mirror.example'), isNull);
      expect(AppUpdateSource.normalizeMirrorPrefix(''), isNull);
    });

    test('wraps original URLs with the mirror prefix', () {
      final source = AppUpdateSource.custom('https://mirror.example')!;
      expect(
        source.wrap(Uri.parse('https://github.com/a/b')).toString(),
        'https://mirror.example/https://github.com/a/b',
      );
      expect(
        AppUpdateSource.direct.wrap(Uri.parse('https://github.com/a/b')),
        Uri.parse('https://github.com/a/b'),
      );
    });

    test('orders the chosen or last good source first, keeping fallbacks', () {
      final auto = AppUpdateSource.ordered(
        const AppUpdatePreferences(lastGoodSourceId: 'llkk'),
      );
      expect(auto.first.id, 'llkk');
      expect(auto, hasLength(AppUpdateSource.builtInSources.length));

      final custom = AppUpdateSource.ordered(
        const AppUpdatePreferences(
          sourceId: AppUpdateSource.customId,
          customMirror: 'https://mirror.example/',
        ),
      );
      expect(custom.first.prefix, 'https://mirror.example/');
      expect(custom, hasLength(AppUpdateSource.builtInSources.length + 1));

      final direct = AppUpdateSource.ordered(
        const AppUpdatePreferences(sourceId: AppUpdateSource.directId),
      );
      expect(direct.first, AppUpdateSource.direct);
    });
  });
}
