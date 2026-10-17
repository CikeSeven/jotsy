import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/long_image_tile_service.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/long_image');
  late Directory root;
  late Directory cache;
  late File source;
  late List<MethodCall> calls;

  /// 模拟原生切片：按请求写出分片与清单，并返回清单。
  Future<Object?> slice(MethodCall call) async {
    calls.add(call);
    final args = call.arguments as Map<Object?, Object?>;
    final outDir = Directory(args['outDir']! as String);
    await outDir.create(recursive: true);
    final tiles = <Map<String, Object>>[];
    for (var i = 0; i < 3; i++) {
      final name = '$i.png';
      await File(p.join(outDir.path, name)).writeAsBytes(<int>[i]);
      tiles.add({'file': name, 'top': i * 2048, 'height': 2050});
    }
    final manifest = <String, Object>{
      'version': 1,
      'source': args['source']! as String,
      'width': 1080,
      'height': 6000,
      'tiles': tiles,
    };
    await File(
      p.join(outDir.path, LongImageTileService.manifestName),
    ).writeAsString(jsonEncode(manifest));
    return manifest;
  }

  LongImageTileService service({bool supported = true}) => LongImageTileService(
    channel: channel,
    cacheDirectory: () async => cache,
    supported: supported,
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('jotsy_long_image_tiles_');
    cache = await Directory(p.join(root.path, 'cache')).create();
    source = File(p.join(root.path, 'long.png'));
    await source.writeAsBytes(<int>[1, 2, 3]);
    calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, slice);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await root.delete(recursive: true);
  });

  test('slices once for concurrent requests and keeps the result', () async {
    final tiles = service();

    final results = await Future.wait([
      tiles.tilesFor(source.path),
      tiles.tilesFor(source.path),
    ]);

    expect(calls, hasLength(1));
    expect(calls.single.method, 'sliceTall');
    expect(
      (calls.single.arguments as Map)['tileHeight'],
      LongImageTileService.tileHeight,
    );
    final result = results.first!;
    expect(identical(result, results.last), isTrue);
    expect(result.width, 1080);
    expect(result.height, 6000);
    expect(result.tiles.map((t) => t.top), <int>[0, 2048, 4096]);
    expect(
      p.isWithin(
        p.join(cache.path, LongImageTileService.directoryName),
        result.tiles.first.path,
      ),
      isTrue,
    );
    expect(tiles.peek(source.path), same(result));
  });

  test('a later run reuses tiles already on disk', () async {
    await service().tilesFor(source.path);
    calls.clear();

    final tiles = await service().tilesFor(source.path);

    expect(calls, isEmpty);
    expect(tiles!.tiles, hasLength(3));
  });

  test('a tile cleared by the system is sliced again', () async {
    final first = await service().tilesFor(source.path);
    await File(first!.tiles[1].path).delete();
    calls.clear();

    final again = await service().tilesFor(source.path);

    expect(calls, hasLength(1));
    expect(again!.tiles, hasLength(3));
  });

  test('a replaced original gets a fresh tile directory', () async {
    final first = await service().tilesFor(source.path);
    await source.writeAsBytes(<int>[9, 9, 9, 9, 9]);

    final second = await service().tilesFor(source.path);

    expect(
      p.dirname(second!.tiles.first.path),
      isNot(p.dirname(first!.tiles.first.path)),
    );
  });

  test('unsupported platforms and slicing errors fall back to null', () async {
    expect(await service(supported: false).tilesFor(source.path), isNull);
    expect(calls, isEmpty);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'slice_failed');
        });
    expect(await service().tilesFor(source.path), isNull);
    expect(await service().tilesFor(p.join(root.path, 'missing.png')), isNull);
  });
}
