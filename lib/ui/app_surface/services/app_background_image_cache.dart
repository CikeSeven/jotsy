import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// 背景图的小型 LRU 缓存（默认 3 项）。
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
  AppBackgroundImageCache({this.capacity = 3, AppBackgroundImageLoader? loader})
    : _loader = loader ?? defaultLoader;

  final int capacity;
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
    _entries.remove(key)?.dispose();
    _entries[key] = master;
    while (_entries.length > capacity) {
      final oldest = _entries.keys.first;
      _entries.remove(oldest)!.dispose();
    }
    for (final waiter in waiters) {
      waiter.complete(master.clone());
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
    for (final entry in _entries.values) {
      entry.dispose();
    }
    _entries.clear();
  }
}

/// 全应用共用的背景图缓存；随根 ProviderScope 释放。测试可覆盖为注入了
/// 加载函数的实例。
final appBackgroundImageCacheProvider = Provider<AppBackgroundImageCache>((
  Ref ref,
) {
  final cache = AppBackgroundImageCache();
  ref.onDispose(cache.dispose);
  return cache;
});
