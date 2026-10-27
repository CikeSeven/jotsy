import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/app_surface/services/app_background_image_cache.dart';

import '../../../support/backup_test_fixture.dart';
import '../app_surface_test_images.dart';

AppBackgroundImageKey _key(String name) => AppBackgroundImageKey.forDisplay(
  fileName: name,
  blur: 0,
  logicalSize: const Size(400, 800),
  devicePixelRatio: 1,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hands out clones and evicts the least recently used entry', () async {
    final loader = FakeBackgroundLoader();
    final cache = AppBackgroundImageCache(capacity: 2, loader: loader.call);
    addTearDown(cache.dispose);

    final a = (await cache.load(_key('a')))!;
    final b = (await cache.load(_key('b')))!;
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    expect(a.image.isCloneOf(loader.produced[0]), isTrue);
    expect(a.averageColor, loader.color);

    // 读 a 把它记为最近使用，再插入 c 时淘汰的是 b。
    cache.peek(_key('a'))!.dispose();
    final c = (await cache.load(_key('c')))!;
    addTearDown(c.dispose);
    expect(cache.length, 2);
    expect(cache.contains(_key('b')), isFalse);
    expect(cache.contains(_key('a')), isTrue);
    // 缓存释放了自己的 b，持有方手里的 clone 仍可用。
    expect(loader.produced[1].debugDisposed, isTrue);
    expect(b.image.debugDisposed, isFalse);
    expect(b.image.width, 8);
  });

  test('concurrent requests for one key share a single load', () async {
    final loader = FakeBackgroundLoader();
    final cache = AppBackgroundImageCache(loader: loader.call);
    addTearDown(cache.dispose);

    final results = await Future.wait(<Future<AppBackgroundImage?>>[
      cache.load(_key('a')),
      cache.load(_key('a')),
    ]);
    expect(loader.requests, hasLength(1));
    expect(results[0]!.image.isCloneOf(results[1]!.image), isTrue);
    for (final image in results) {
      image!.dispose();
    }
    // 命中缓存：不再加载。
    cache.peek(_key('a'))!.dispose();
    expect(loader.requests, hasLength(1));
  });

  test('a missing file yields null and is retried later', () async {
    final loader = FakeBackgroundLoader()..missing.add('gone.png');
    final cache = AppBackgroundImageCache(loader: loader.call);
    addTearDown(cache.dispose);

    expect(await cache.load(_key('gone.png')), isNull);
    expect(cache.contains(_key('gone.png')), isFalse);
    // 文件之后（如恢复备份）才出现：下次请求重新加载。
    loader.missing.clear();
    final image = await cache.load(_key('gone.png'));
    expect(image, isNotNull);
    image!.dispose();
    expect(loader.requests, hasLength(2));
  });

  test('dispose releases every entry and later loads give null', () async {
    final loader = FakeBackgroundLoader();
    final cache = AppBackgroundImageCache(loader: loader.call);
    final a = (await cache.load(_key('a')))!;
    cache.dispose();
    expect(loader.produced.single.debugDisposed, isTrue);
    expect(a.image.debugDisposed, isFalse);
    a.dispose();
    expect(await cache.load(_key('b')), isNull);
  });

  test('the default loader treats a missing managed file as none', () async {
    final fixture = await BackupTestFixture.create();
    addTearDown(fixture.dispose);
    expect(
      await AppBackgroundImageCache.defaultLoader(_key('nope.png')),
      isNull,
    );
  });
}
