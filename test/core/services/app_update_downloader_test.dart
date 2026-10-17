import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_update_downloader.dart';
import 'package:node_diary/core/services/app_update_http.dart';
import 'package:node_diary/core/services/app_update_models.dart';
import 'package:node_diary/core/services/app_update_sources.dart';
import 'package:path/path.dart' as p;

import '../../support/app_update_test_server.dart';
import '../../support/webdav_test_server.dart';

const _apkName = 'jotsy-v0.6.1-arm64-v8a.apk';

void main() {
  late FakeMirrorServer server;
  late Directory cache;
  late Uint8List payload;
  late AppUpdateRelease release;

  setUp(() async {
    server = await FakeMirrorServer.start();
    cache = await Directory.systemTemp.createTemp('app_update_test_');
    final random = Random(7);
    payload = Uint8List.fromList(
      List<int>.generate(300 << 10, (_) => random.nextInt(256)),
    );
    server.body(_apkName, payload);
    release = AppUpdateRelease(
      version: AppVersion.tryParse('0.6.1+18')!,
      tag: 'v0.6.1',
      assets: <AppUpdateAsset>[
        AppUpdateAsset(
          name: _apkName,
          url: AppUpdateEndpoints.assetUrl('v0.6.1', _apkName),
          size: payload.length,
          sha256: sha256.convert(payload).toString(),
        ),
      ],
    );
  });

  tearDown(() async {
    await server.close();
    await cache.delete(recursive: true);
  });

  AppUpdateSource mirror(String id) => AppUpdateSource(id, server.prefix(id));

  AppUpdateDownloader downloader({
    Duration stallTimeout = const Duration(seconds: 20),
    Duration lowSpeedWindow = const Duration(seconds: 15),
    int lowSpeedBytesPerSecond = 24 << 10,
  }) => AppUpdateDownloader(
    http: AppUpdateHttp(clientFactory: realFixtureHttpClient),
    cacheDirectory: () async => cache,
    probeTimeout: const Duration(seconds: 2),
    connectTimeout: const Duration(seconds: 2),
    stallTimeout: stallTimeout,
    lowSpeedWindow: lowSpeedWindow,
    lowSpeedBytesPerSecond: lowSpeedBytesPerSecond,
    probeBytes: 16 << 10,
  );

  File partFile() => File(
    p.join(
      cache.path,
      AppUpdateDownloader.directoryName,
      '${AppUpdateDownloader.fileNameFor(release, release.assets.single)}.part',
    ),
  );

  Matcher failsWith(AppUpdateFailureKind kind) =>
      throwsA(isA<AppUpdateException>().having((e) => e.kind, 'kind', kind));

  test(
    'skips unreachable mirrors after probing and verifies the APK',
    () async {
      server.route('down', _apkName, FakeMirrorBehavior.badGateway);
      server.route('html', _apkName, FakeMirrorBehavior.html);
      server.route('good', _apkName, FakeMirrorBehavior.ok);
      final progress = <AppUpdateDownloadProgress>[];
      AppUpdateSource? succeeded;

      final file = await downloader().download(
        release: release,
        asset: release.assets.single,
        sources: <AppUpdateSource>[
          mirror('down'),
          mirror('html'),
          mirror('good'),
        ],
        onProgress: progress.add,
        onSourceSucceeded: (source) => succeeded = source,
      );

      expect(await file.readAsBytes(), payload);
      expect(p.basename(file.path), '0.6.1+18-arm64-v8a.apk');
      expect(partFile().existsSync(), isFalse);
      expect(succeeded?.id, 'good');
      expect(progress.last.received, payload.length);
      expect(progress.last.fraction, 1.0);
      // 测速之后只在可用线路上下载完整文件。
      final fullDownloads = server.requests.where(
        (r) => r.path.endsWith(_apkName) && r.range == null,
      );
      expect(fullDownloads.map((r) => r.mirror), <String>['good']);
    },
  );

  test('resumes a partial download with a Range request', () async {
    server.route('good', _apkName, FakeMirrorBehavior.ok);
    final part = partFile();
    await part.parent.create(recursive: true);
    await part.writeAsBytes(payload.sublist(0, 100 << 10));

    final file = await downloader().download(
      release: release,
      asset: release.assets.single,
      sources: <AppUpdateSource>[mirror('good')],
      onProgress: (_) {},
    );

    expect(await file.readAsBytes(), payload);
    expect(server.requests.single.range, 'bytes=${100 << 10}-');
  });

  test(
    'continues on the next mirror from where a dropped one stopped',
    () async {
      server.cutAfter = 120 << 10;
      server.route('flaky', _apkName, FakeMirrorBehavior.cut);
      server.route('good', _apkName, FakeMirrorBehavior.ok);
      AppUpdateSource? succeeded;

      final file = await downloader().download(
        release: release,
        asset: release.assets.single,
        sources: <AppUpdateSource>[mirror('flaky'), mirror('good')],
        onProgress: (_) {},
        probe: false,
        onSourceSucceeded: (source) => succeeded = source,
      );

      expect(await file.readAsBytes(), payload);
      expect(succeeded?.id, 'good');
      final resumed = server.requests.lastWhere((r) => r.mirror == 'good');
      expect(resumed.range, 'bytes=${120 << 10}-');
    },
  );

  test('restarts from scratch when a mirror ignores Range', () async {
    server.route('norange', _apkName, FakeMirrorBehavior.ignoreRange);
    final part = partFile();
    await part.parent.create(recursive: true);
    await part.writeAsBytes(List<int>.filled(50 << 10, 0));

    final file = await downloader().download(
      release: release,
      asset: release.assets.single,
      sources: <AppUpdateSource>[mirror('norange')],
      onProgress: (_) {},
    );

    expect(await file.readAsBytes(), payload);
  });

  test('switches away from a mirror that stops sending data', () async {
    server.cutAfter = 40 << 10;
    server.route('stalled', _apkName, FakeMirrorBehavior.stall);
    server.route('good', _apkName, FakeMirrorBehavior.ok);

    final file = await downloader(stallTimeout: const Duration(seconds: 1))
        .download(
          release: release,
          asset: release.assets.single,
          sources: <AppUpdateSource>[mirror('stalled'), mirror('good')],
          onProgress: (_) {},
          probe: false,
        );

    expect(await file.readAsBytes(), payload);
    final resumed = server.requests.lastWhere((r) => r.mirror == 'good');
    expect(resumed.range, 'bytes=${40 << 10}-');
  });

  test('moves to another mirror when the current one is throttled', () async {
    server.route('throttled', _apkName, FakeMirrorBehavior.drip);
    server.route('good', _apkName, FakeMirrorBehavior.ok);
    final used = <String>{};

    final file =
        await downloader(
          lowSpeedWindow: const Duration(seconds: 1),
          lowSpeedBytesPerSecond: 64 << 10,
        ).download(
          release: release,
          asset: release.assets.single,
          sources: <AppUpdateSource>[mirror('throttled'), mirror('good')],
          onProgress: (progress) => used.add(progress.source.id),
          probe: false,
        );

    expect(await file.readAsBytes(), payload);
    expect(used, contains('good'));
    final resumed = server.requests.lastWhere((r) => r.mirror == 'good');
    expect(resumed.range, isNotNull, reason: 'keeps the trickled bytes');
  });

  test(
    'keeps a slow mirror when there is no other mirror to switch to',
    () async {
      server.route('good', _apkName, FakeMirrorBehavior.ok);
      final file =
          await downloader(
            lowSpeedWindow: const Duration(milliseconds: 1),
            lowSpeedBytesPerSecond: 1 << 30,
          ).download(
            release: release,
            asset: release.assets.single,
            sources: <AppUpdateSource>[mirror('good')],
            onProgress: (_) {},
          );
      expect(await file.readAsBytes(), payload);
    },
  );

  test(
    'deletes the file and reports tampering on a checksum mismatch',
    () async {
      server.route('good', _apkName, FakeMirrorBehavior.ok);
      final tampered = AppUpdateRelease(
        version: release.version,
        tag: release.tag,
        assets: <AppUpdateAsset>[
          AppUpdateAsset(
            name: _apkName,
            url: release.assets.single.url,
            size: payload.length,
            sha256: '0' * 64,
          ),
        ],
      );

      await expectLater(
        downloader().download(
          release: tampered,
          asset: tampered.assets.single,
          sources: <AppUpdateSource>[mirror('good')],
          onProgress: (_) {},
        ),
        failsWith(AppUpdateFailureKind.integrity),
      );
      expect(partFile().existsSync(), isFalse);
    },
  );

  test('gives up with a network failure when every mirror fails', () async {
    server.route('a', _apkName, FakeMirrorBehavior.badGateway);
    server.route('b', _apkName, FakeMirrorBehavior.notFound);

    await expectLater(
      downloader().download(
        release: release,
        asset: release.assets.single,
        sources: <AppUpdateSource>[mirror('a'), mirror('b')],
        onProgress: (_) {},
      ),
      failsWith(AppUpdateFailureKind.network),
    );
  });

  test('keeps the partial file when the download is cancelled', () async {
    server.route('slow', _apkName, FakeMirrorBehavior.drip);
    final token = AppUpdateCancelToken();
    final future = downloader().download(
      release: release,
      asset: release.assets.single,
      sources: <AppUpdateSource>[mirror('slow')],
      onProgress: (_) {},
      cancelToken: token,
    );
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    token.cancel();

    await expectLater(future, failsWith(AppUpdateFailureKind.cancelled));
    expect(partFile().existsSync(), isTrue);
    expect(partFile().lengthSync(), greaterThan(0));
  });

  test('reuses a verified download and cleans up installed versions', () async {
    server.route('good', _apkName, FakeMirrorBehavior.ok);
    final subject = downloader();
    final file = await subject.download(
      release: release,
      asset: release.assets.single,
      sources: <AppUpdateSource>[mirror('good')],
      onProgress: (_) {},
    );
    final requestCount = server.requests.length;

    expect(
      (await subject.findDownloaded(release, release.assets.single))?.path,
      file.path,
    );
    await subject.download(
      release: release,
      asset: release.assets.single,
      sources: <AppUpdateSource>[mirror('good')],
      onProgress: (_) {},
    );
    expect(server.requests.length, requestCount);

    final stale = File(p.join(file.parent.path, '0.5.2-x86_64.apk.part'));
    await stale.writeAsString('old');
    await subject.cleanUp(
      installed: AppVersion.tryParse('0.6.0+17')!,
      keep: release,
    );
    expect(file.existsSync(), isTrue);
    expect(stale.existsSync(), isFalse);

    await subject.cleanUp(installed: AppVersion.tryParse('0.6.1+18')!);
    expect(file.existsSync(), isFalse);
    expect(file.parent.existsSync(), isFalse);
  });
}
