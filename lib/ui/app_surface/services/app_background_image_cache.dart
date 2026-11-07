import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';

import '../../../core/services/app_background_storage_service.dart';
import 'app_background_image_key.dart';
import 'app_background_image_pipeline.dart';

export 'app_background_image_key.dart';

/// 背景图的一个句柄：[image] 是 `ui.Image` 的一份 clone，附带均色与键。
///
/// 持有者（渲染层）在不再显示、被替换或自身卸载时必须 [dispose]；需要再交给
/// 别人时用 [clone]。像素只有一份，clone 只多一个引用计数。
class AppBackgroundImage {
  AppBackgroundImage._(this.image, this.averageColor, this.key);

  final ui.Image image;

  /// 整张图的平均颜色（含透明度，未预乘）。
  final Color averageColor;
  final AppBackgroundImageKey key;

  AppBackgroundImage clone() =>
      AppBackgroundImage._(image.clone(), averageColor, key);

  void dispose() => image.dispose();
}

/// 按键加载一份背景图；返回 null 表示文件缺失或解码失败（按没有背景处理）。
typedef AppBackgroundImageLoader =
    Future<AppBackgroundDecoded?> Function(AppBackgroundImageKey key);

/// 背景图的小型 LRU 缓存（最多 3 项、合计 32 MiB RGBA 像素）。
///
/// - 输入：[AppBackgroundImageKey]；输出：[AppBackgroundImage] clone，
///   调用方负责释放；
/// - 同一键的并发请求合并为一次加载；结果到达时在同一个同步段里先放进
///   缓存、再给每个等待者各一份 clone，期间不会被别的插入挤掉；
/// - 超出容量时淘汰最久未用的一项并释放缓存自己的句柄——正在显示它的页面
///   手里还有 clone，像素随最后一个句柄释放；
/// - 加载失败不缓存：文件可能随后（如恢复备份）才出现，下次请求重新加载。
///
/// 为什么只缓存 3 项：一张手机全屏背景解码后十几到几十 MB，常见用法是全局
/// 一张或首页几个 Tab 各一张，3 项足以覆盖“返回上一页、来回切 Tab”的重用，
/// 更多就是常驻的大块内存。
class AppBackgroundImageCache {
  AppBackgroundImageCache({
    this.capacity = 3,
    this.maxBytes = 32 * 1024 * 1024,
    AppBackgroundImageLoader? loader,
  }) : assert(capacity >= 0),
       assert(maxBytes >= 0),
       _loader = loader ?? defaultLoader;

  final int capacity;
  final int maxBytes;
  int _retainedBytes = 0;
  int _generation = 0;
  final AppBackgroundImageLoader _loader;
  final LinkedHashMap<AppBackgroundImageKey, AppBackgroundImage> _entries =
      LinkedHashMap<AppBackgroundImageKey, AppBackgroundImage>();
  final Map<AppBackgroundImageKey, List<Completer<AppBackgroundImage?>>>
  _waiting = <AppBackgroundImageKey, List<Completer<AppBackgroundImage?>>>{};
  bool _disposed = false;

  /// 默认加载：解析托管文件 → [AppBackgroundImagePipeline.load]。文件缺失或
  /// 解码失败只记一行日志、返回 null，设置原样保留。
  static Future<AppBackgroundDecoded?> defaultLoader(
    AppBackgroundImageKey key,
  ) async {
    final file = await AppBackgroundStorageService.resolve(key.fileName);
    if (file == null) {
      debugPrint('App background missing: ${key.fileName}');
      return null;
    }
    try {
      return await AppBackgroundImagePipeline.load(file, key);
    } catch (error) {
      debugPrint('App background decode failed (${key.fileName}): $error');
      return null;
    }
  }

  /// 已缓存时同步给出一份 clone（并把它记为最近使用），否则为 null。
  AppBackgroundImage? peek(AppBackgroundImageKey key) {
    final entry = _entries.remove(key);
    if (entry == null) return null;
    _entries[key] = entry;
    return entry.clone();
  }

  /// 取一份 clone；未缓存时加载。失败或缓存已释放时得到 null。
  Future<AppBackgroundImage?> load(AppBackgroundImageKey key) {
    final hit = peek(key);
    if (hit != null) return Future<AppBackgroundImage?>.value(hit);
    if (_disposed) return Future<AppBackgroundImage?>.value();
    final completer = Completer<AppBackgroundImage?>();
    final waiters = _waiting[key];
    if (waiters != null) {
      waiters.add(completer);
    } else {
      _waiting[key] = <Completer<AppBackgroundImage?>>[completer];
      unawaited(_run(key));
    }
    return completer.future;
  }

  Future<void> _run(AppBackgroundImageKey key) async {
    final generation = _generation;
    AppBackgroundDecoded? decoded;
    try {
      decoded = await _loader(key);
    } catch (error) {
      debugPrint('App background load failed (${key.fileName}): $error');
    }
    final waiters =
        _waiting.remove(key) ?? const <Completer<AppBackgroundImage?>>[];
    if (decoded == null || _disposed) {
      decoded?.image.dispose();
      for (final waiter in waiters) {
        waiter.complete(null);
      }
      return;
    }
    final master = AppBackgroundImage._(
      decoded.image,
      decoded.averageColor,
      key,
    );
    // 先给等待者自己的句柄：单张超过缓存预算时仍按原质量交给活动页面，
    // 只放弃缓存；绝不能先释放 master 再 clone。
    for (final waiter in waiters) {
      waiter.complete(master.clone());
    }
    final bytes = _bytesOf(master);
    if (generation != _generation || capacity == 0 || bytes > maxBytes) {
      master.dispose();
      return;
    }
    _remove(key);
    _entries[key] = master;
    _retainedBytes += bytes;
    while (_entries.length > capacity || _retainedBytes > maxBytes) {
      _remove(_entries.keys.first);
    }
  }

  static int _bytesOf(AppBackgroundImage entry) =>
      entry.image.width * entry.image.height * 4;

  void _remove(AppBackgroundImageKey key) {
    final entry = _entries.remove(key);
    if (entry == null) return;
    _retainedBytes -= _bytesOf(entry);
    entry.dispose();
  }

  /// 只计缓存自己的句柄；页面仍持有的 clone、解码中间图和 GPU 资源另计。
  int get retainedBytes => _retainedBytes;

  /// 内存压力时释放可重建的缓存，活动页面的 clone 继续有效。旧的进行中
  /// 加载仍给等待者结果，但不能在压力处理后又把缓存填回去。
  void clear() {
    _generation++;
    while (_entries.isNotEmpty) {
      _remove(_entries.keys.first);
    }
  }

  /// 缓存中的项数（测试用）。
  @visibleForTesting
  int get length => _entries.length;

  /// 是否缓存了 [key]（测试用，不改变使用顺序）。
  @visibleForTesting
  bool contains(AppBackgroundImageKey key) => _entries.containsKey(key);

  /// 释放缓存持有的全部句柄；之后的请求一律得到 null。进行中的加载完成后
  /// 直接释放结果。
  void dispose() {
    _disposed = true;
    clear();
  }
}

class _BackgroundCacheMemoryObserver extends WidgetsBindingObserver {
  _BackgroundCacheMemoryObserver(this.cache);
  final AppBackgroundImageCache cache;

  @override
  void didHaveMemoryPressure() => cache.clear();
}

/// 全应用共用的背景图缓存；随根 ProviderScope 释放。测试可覆盖为注入了
/// 加载函数的实例。
final appBackgroundImageCacheProvider = Provider<AppBackgroundImageCache>((
  Ref ref,
) {
  final cache = AppBackgroundImageCache();
  final observer = _BackgroundCacheMemoryObserver(cache);
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() {
    WidgetsBinding.instance.removeObserver(observer);
    cache.dispose();
  });
  return cache;
});
