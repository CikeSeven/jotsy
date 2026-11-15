import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/storage/media_compressor.dart';
import 'package:node_diary/core/services/video_poster_cache.dart';
import 'package:path/path.dart' as p;

import '../../support/fake_media_compressor.dart';

/// 取帧时写一个假的 JPEG，记录调用；[fail] 为 true 时取不到帧。
class _FrameCompressor extends FakeMediaCompressor {
  final List<(String, int)> calls = <(String, int)>[];
  bool fail = false;
  Completer<void>? gate;

  @override
  Future<bool> videoThumbnail(
    String source, {
    required String target,
    int maxSide = 320,
  }) async {
    calls.add((source, maxSide));
    await gate?.future;
    if (fail) return false;
    await File(target).create(recursive: true);
    await File(target).writeAsBytes(const <int>[0xFF, 0xD8, 0xFF]);
    return true;
  }
}

void main() {
  late Directory root;
  late File video;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('video_poster_cache_');
    video = File(p.join(root.path, 'trip.mp4'))..writeAsBytesSync([1, 2, 3]);
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  VideoPosterCache cache(MediaCompressor compressor) => VideoPosterCache(
    compressor: compressor,
    temporaryDirectory: () async => root,
  );

  test('writes one frame per file and size, then reuses it', () async {
    final compressor = _FrameCompressor()..gate = Completer<void>();
    final posters = cache(compressor);
    // 同一键的并发请求只取一次帧。
    final first = posters.posterOf(video.path, maxSide: 720);
    final second = posters.posterOf(video.path, maxSide: 720);
    compressor.gate!.complete();
    final frame = await first;
    expect(await second, frame);
    expect(frame, isNotNull);
    expect(
      p.isWithin(p.join(root.path, VideoPosterCache.directoryName), frame!),
      isTrue,
    );
    expect(File(frame).existsSync(), isTrue);
    expect(compressor.calls, [(video.path, 720)]);

    // 新的缓存实例（下次启动）直接用磁盘上的帧。
    final again = cache(compressor);
    expect(await again.posterOf(video.path, maxSide: 720), frame);
    expect(compressor.calls, hasLength(1));

    // 不同的最长边是另一帧。
    expect(await posters.posterOf(video.path), isNot(frame));
    expect(compressor.calls.last, (video.path, VideoPosterCache.listMaxSide));
  });

  test('a replaced file gets a new frame', () async {
    final compressor = _FrameCompressor();
    final posters = cache(compressor);
    final before = await posters.posterOf(video.path);
    video
      ..writeAsBytesSync([1, 2, 3, 4, 5])
      ..setLastModifiedSync(DateTime(2030));
    final after = await posters.posterOf(video.path);
    expect(after, isNot(before));
    expect(compressor.calls, hasLength(2));
  });

  test('failures are not remembered and missing files are skipped', () async {
    final compressor = _FrameCompressor()..fail = true;
    final posters = cache(compressor);
    expect(await posters.posterOf(video.path), isNull);
    compressor.fail = false;
    expect(await posters.posterOf(video.path), isNotNull);
    expect(compressor.calls, hasLength(2));

    expect(await posters.posterOf(p.join(root.path, 'missing.mp4')), isNull);
    expect(compressor.calls, hasLength(2));
  });

  test('platforms without frame extraction return null without IO', () async {
    final posters = cache(const UnsupportedMediaCompressor());
    expect(posters.isSupported, isFalse);
    expect(await posters.posterOf(video.path), isNull);
    expect(
      Directory(p.join(root.path, VideoPosterCache.directoryName)).existsSync(),
      isFalse,
    );
  });
}
