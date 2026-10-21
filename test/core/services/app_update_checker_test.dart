import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_update_checker.dart';
import 'package:node_diary/core/services/app_update_http.dart';
import 'package:node_diary/core/services/app_update_models.dart';
import 'package:node_diary/core/services/app_update_sources.dart';

import '../../support/app_update_test_server.dart';
import '../../support/webdav_test_server.dart';

const _manifestSuffix = 'releases/latest/download/jotsy-update.json';
const _latestSuffix = 'releases/latest';
const _sumsSuffix = 'SHA256SUMS.txt';
// 接口地址为 http://127.0.0.1:<port>/api/latest，即线路 api 的 latest。
const _apiSuffix = 'latest';

void main() {
  late FakeMirrorServer server;

  setUp(() async {
    server = await FakeMirrorServer.start();
  });

  tearDown(() => server.close());

  AppUpdateSource mirror(String id) => AppUpdateSource(id, server.prefix(id));

  AppUpdateChecker checker() => AppUpdateChecker(
    http: AppUpdateHttp(clientFactory: realFixtureHttpClient),
    requestTimeout: const Duration(seconds: 2),
    latestReleaseApi: Uri.parse('http://127.0.0.1:${server.port}/api/latest'),
  );

  String manifest({String version = '0.6.1+18'}) => jsonEncode(
    AppUpdateManifest.toJson(
      version: version,
      tag: 'v0.6.1',
      notes: const <String, String>{'zh': '- 中文说明', 'en': '- English notes'},
      assets: <AppUpdateAsset>[
        AppUpdateAsset(
          name: 'jotsy-v0.6.1-arm64-v8a.apk',
          url: Uri.parse('https://unused.example'),
          size: 100,
          sha256: 'b' * 64,
        ),
      ],
    ),
  );

  test('takes the manifest from the first mirror that answers', () async {
    server.body(_manifestSuffix, manifest());
    server.route('slow', _manifestSuffix, FakeMirrorBehavior.hang);
    server.route('broken', _manifestSuffix, FakeMirrorBehavior.badGateway);
    server.route('fast', _manifestSuffix, FakeMirrorBehavior.ok);

    final stopwatch = Stopwatch()..start();
    final outcome = await checker().fetchLatest(
      sources: <AppUpdateSource>[
        mirror('slow'),
        mirror('broken'),
        mirror('fast'),
      ],
      languageCode: 'en',
    );

    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
    expect(outcome.source.id, 'fast');
    expect(outcome.release!.version, AppVersion.tryParse('0.6.1+18'));
    expect(outcome.release!.notesFor('en'), '- English notes');
    expect(outcome.release!.assets.single.sha256, 'b' * 64);
    // 有清单时不再请求接口与跳转页。
    expect(
      server.requests.where(
        (r) => r.mirror == 'api' || r.path == _latestSuffix,
      ),
      isEmpty,
    );
  });

  test(
    'falls back to the GitHub API when two sources say there is no manifest',
    () async {
      server.route('m1', _manifestSuffix, FakeMirrorBehavior.notFound);
      server.route('m2', _manifestSuffix, FakeMirrorBehavior.notFound);
      // 第三条线路一直不响应：两条 404 已足以判定没有清单，不必等它超时。
      server.route('m3', _manifestSuffix, FakeMirrorBehavior.hang);
      server.route('m3', _latestSuffix, FakeMirrorBehavior.hang);
      server.body(
        _apiSuffix,
        jsonEncode(<String, Object?>{
          'tag_name': 'v0.6.1',
          'body': '# Release v0.6.1\n\n## 新增\n- 正文',
          'assets': <Object?>[
            <String, Object?>{
              'name': 'jotsy-v0.6.1-armeabi-v7a.apk',
              'size': 42,
              'digest': 'sha256:${'c' * 64}',
            },
            <String, Object?>{'name': 'SHA256SUMS.txt', 'size': 90},
          ],
        }),
      );
      server.route('api', _apiSuffix, FakeMirrorBehavior.ok);
      server.body(
        'docs/releases/v0.6.1.en.md',
        '# Release v0.6.1\n\n- English',
      );
      server.route('m1', 'docs/releases/v0.6.1.en.md', FakeMirrorBehavior.ok);

      final stopwatch = Stopwatch()..start();
      final outcome = await checker().fetchLatest(
        sources: <AppUpdateSource>[mirror('m1'), mirror('m2'), mirror('m3')],
        languageCode: 'en',
      );

      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
      expect(outcome.source, AppUpdateSource.direct);
      expect(outcome.release!.assets.single.size, 42);
      expect(outcome.release!.assets.single.sha256, 'c' * 64);
      expect(outcome.release!.notesFor('en'), '- English');
      expect(outcome.release!.notesFor('zh'), '## 新增\n- 正文');
    },
  );

  test(
    'reads the tag from the latest redirect when the API is limited',
    () async {
      server.route('m1', _manifestSuffix, FakeMirrorBehavior.notFound);
      server.route('m2', _manifestSuffix, FakeMirrorBehavior.notFound);
      server.route('api', _apiSuffix, FakeMirrorBehavior.badGateway);
      server.redirect(
        _latestSuffix,
        '/m2/https://github.com/CikeSeven/jotsy/releases/tag/v0.6.1',
      );
      server.body(_latestSuffix, '');
      server.route('m2', _latestSuffix, FakeMirrorBehavior.ok);
      server.body(
        _sumsSuffix,
        '${'d' * 64}  jotsy-v0.6.1-arm64-v8a.apk\n'
        '${'e' * 64}  jotsy-v0.6.1-armeabi-v7a.apk\n',
      );
      server.route('m2', _sumsSuffix, FakeMirrorBehavior.ok);
      server.body('docs/releases/v0.6.1.md', '# Release v0.6.1\n\n- 中文');
      server.route('m2', 'docs/releases/v0.6.1.md', FakeMirrorBehavior.ok);
      server.route('m1', 'docs/releases/v0.6.1.md', FakeMirrorBehavior.html);

      final outcome = await checker().fetchLatest(
        sources: <AppUpdateSource>[mirror('m1'), mirror('m2')],
        languageCode: 'zh',
      );

      expect(outcome.source.id, 'm2');
      expect(outcome.release!.tag, 'v0.6.1');
      expect(
        outcome.release!.assetFor(const <String>['arm64-v8a'])!.name,
        'jotsy-v0.6.1-arm64-v8a.apk',
      );
      expect(
        outcome.release!.assetFor(const <String>['arm64-v8a'])!.sha256,
        'd' * 64,
      );
      expect(outcome.release!.notesFor('zh'), '- 中文');
    },
  );

  test(
    'reports no update while a new tag has no checksums uploaded yet',
    () async {
      server.route('m1', _manifestSuffix, FakeMirrorBehavior.notFound);
      server.route('m2', _manifestSuffix, FakeMirrorBehavior.notFound);
      server.route('api', _apiSuffix, FakeMirrorBehavior.badGateway);
      server.redirect(
        _latestSuffix,
        '/m1/https://github.com/CikeSeven/jotsy/releases/tag/v0.6.2',
      );
      server.body(_latestSuffix, '');
      server.route('m1', _latestSuffix, FakeMirrorBehavior.ok);
      // 刚发布：tag 已在，校验文件与安装包还没上传。
      server.route('m1', _sumsSuffix, FakeMirrorBehavior.notFound);

      final outcome = await checker().fetchLatest(
        sources: <AppUpdateSource>[mirror('m1'), mirror('m2')],
        languageCode: 'zh',
      );

      expect(outcome.release, isNull);
      expect(outcome.source.id, 'm1');
      // 没有可下载的版本，不再读取更新说明。
      expect(server.requests.where((r) => r.path.startsWith('docs/')), isEmpty);
    },
  );

  test(
    'stops waiting once the API and a mirror both say the APKs are not ready',
    () async {
      server.route('m1', _manifestSuffix, FakeMirrorBehavior.notFound);
      server.route('m2', _manifestSuffix, FakeMirrorBehavior.notFound);
      // 安装包传了一部分，校验文件还没上传。
      server.body(
        _apiSuffix,
        jsonEncode(<String, Object?>{
          'tag_name': 'v0.6.2',
          'assets': <Object?>[
            <String, Object?>{'name': 'jotsy-v0.6.2-arm64-v8a.apk', 'size': 42},
          ],
        }),
      );
      server.route('api', _apiSuffix, FakeMirrorBehavior.ok);
      server.redirect(
        _latestSuffix,
        '/m1/https://github.com/CikeSeven/jotsy/releases/tag/v0.6.2',
      );
      server.body(_latestSuffix, '');
      server.route('m1', _latestSuffix, FakeMirrorBehavior.ok);
      server.route('m1', _sumsSuffix, FakeMirrorBehavior.notFound);
      server.route('m2', _latestSuffix, FakeMirrorBehavior.hang);

      final stopwatch = Stopwatch()..start();
      final outcome = await checker().fetchLatest(
        sources: <AppUpdateSource>[mirror('m1'), mirror('m2')],
        languageCode: 'zh',
      );

      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
      expect(outcome.release, isNull);
    },
  );

  test(
    'one mirror missing the checksums does not hide a ready release',
    () async {
      server.route('m1', _manifestSuffix, FakeMirrorBehavior.notFound);
      server.route('m2', _manifestSuffix, FakeMirrorBehavior.notFound);
      server.route('api', _apiSuffix, FakeMirrorBehavior.badGateway);
      server.redirect(
        _latestSuffix,
        '/m1/https://github.com/CikeSeven/jotsy/releases/tag/v0.6.1',
      );
      server.body(_latestSuffix, '');
      server.route('m1', _latestSuffix, FakeMirrorBehavior.ok);
      server.route('m2', _latestSuffix, FakeMirrorBehavior.ok);
      server.route('m1', _sumsSuffix, FakeMirrorBehavior.notFound);
      server.body(_sumsSuffix, '${'d' * 64}  jotsy-v0.6.1-arm64-v8a.apk\n');
      server.route('m2', _sumsSuffix, FakeMirrorBehavior.ok);

      final outcome = await checker().fetchLatest(
        sources: <AppUpdateSource>[mirror('m1'), mirror('m2')],
        languageCode: 'zh',
      );

      expect(outcome.source.id, 'm2');
      expect(outcome.release!.tag, 'v0.6.1');
    },
  );

  test('throws a network failure when no source answers', () async {
    server.route('m1', _manifestSuffix, FakeMirrorBehavior.badGateway);
    server.route('api', _apiSuffix, FakeMirrorBehavior.badGateway);
    server.route('m1', _latestSuffix, FakeMirrorBehavior.html);

    await expectLater(
      checker().fetchLatest(
        sources: <AppUpdateSource>[mirror('m1')],
        languageCode: 'zh',
      ),
      throwsA(
        isA<AppUpdateException>().having(
          (e) => e.kind,
          'kind',
          AppUpdateFailureKind.network,
        ),
      ),
    );
  });

  test('stops waiting as soon as the check is cancelled', () async {
    server.route('m1', _manifestSuffix, FakeMirrorBehavior.hang);
    final token = AppUpdateCancelToken();
    final future = checker().fetchLatest(
      sources: <AppUpdateSource>[mirror('m1')],
      languageCode: 'zh',
      cancelToken: token,
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    token.cancel();
    await expectLater(
      future,
      throwsA(
        isA<AppUpdateException>().having(
          (e) => e.kind,
          'kind',
          AppUpdateFailureKind.cancelled,
        ),
      ),
    );
  });

  test('extractReleaseTag reads tags from mirror-rewritten locations', () {
    expect(
      extractReleaseTag(
        '/https://github.com/CikeSeven/jotsy/releases/tag/v0.4.8%2B13',
      ),
      'v0.4.8+13',
    );
    expect(extractReleaseTag('https://github.com/x/y/releases'), isNull);
  });
}
