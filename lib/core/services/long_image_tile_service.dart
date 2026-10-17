import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 长图的一段分片：原图中 [top] 起、高 [height] 像素的整宽区域。
@immutable
class LongImageTile {
  const LongImageTile({
    required this.path,
    required this.top,
    required this.height,
  });

  final String path;
  final int top;
  final int height;
}

/// 一张长图按竖向切成的分片（自上而下）；只有一段时就是原图本身。
@immutable
class LongImageTiles {
  const LongImageTiles({
    required this.width,
    required this.height,
    required this.tiles,
  });

  /// 不分片：整张原图作为唯一一段（非 Android、切片失败时的退路）。
  LongImageTiles.single(
    String path, {
    required this.width,
    required this.height,
  }) : tiles = <LongImageTile>[
         LongImageTile(path: path, top: 0, height: height),
       ];

  /// 原图像素宽高。
  final int width;
  final int height;
  final List<LongImageTile> tiles;

  bool get isSliced => tiles.length > 1;

  static LongImageTiles? fromManifest(Map<Object?, Object?> json, String dir) {
    final width = json['width'];
    final height = json['height'];
    final rawTiles = json['tiles'];
    if (width is! int || height is! int || rawTiles is! List) {
      return null;
    }
    final tiles = <LongImageTile>[];
    for (final raw in rawTiles) {
      if (raw is! Map) return null;
      final file = raw['file'];
      final top = raw['top'];
      final tileHeight = raw['height'];
      if (file is! String || top is! int || tileHeight is! int) return null;
      tiles.add(
        LongImageTile(path: p.join(dir, file), top: top, height: tileHeight),
      );
    }
    if (width <= 0 || height <= 0 || tiles.isEmpty) {
      return null;
    }
    return LongImageTiles(width: width, height: height, tiles: tiles);
  }
}

/// 把长图切成若干竖向分片并缓存在应用缓存目录 `diary_image_tiles/` 下。
///
/// 为什么要切：Impeller 解码时把宽、高分别限制在 GPU 最大纹理尺寸以内（不保持
/// 比例），超长截图会被压扁；整张按显示宽度解码又要几十 MB 内存，而正文折叠
/// 只露出顶部一段。切成 [tileHeight] 高的分片后，每段都远小于纹理上限，显示时
/// 只解码可见的几段。
///
/// - 输入：本地原图路径与其像素尺寸（来自 `ImageDimensions`）；
/// - 输出：分片清单；不支持（非 Android、原图带 EXIF 旋转、动图）或失败时为
///   null，调用方退回整张按比例缩小解码；
/// - 副作用：原生侧（`DiaryLongImageSlicer`）用 `BitmapRegionDecoder` 逐段解码
///   并写出 PNG/JPEG 与 `manifest.json`，原图不动。目录按“路径 + 大小 + 修改
///   时间”取哈希，原图被替换时自然换新目录；缓存可被系统随时清掉，缺失时重切。
///   原图不存在的分片目录由媒体回收（`sweepDiaryMediaFiles`）删除。
class LongImageTileService {
  LongImageTileService({
    MethodChannel? channel,
    Future<Directory> Function()? cacheDirectory,
    bool? supported,
  }) : _channel = channel ?? const MethodChannel(channelName),
       _cacheDirectory = cacheDirectory ?? getTemporaryDirectory,
       _supported =
           supported ??
           (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  static const String channelName = 'com.jotsy.diary/long_image';

  /// 缓存根目录名（位于 `getTemporaryDirectory()` 下）。
  static const String directoryName = 'diary_image_tiles';

  /// 清单文件名；原生侧最后写出，存在即表示该目录完整。
  static const String manifestName = 'manifest.json';

  /// 分片高度（原图像素）。2048 远低于常见的 8192/16384 纹理上限，正文折叠
  /// 通常只需要第一段。
  static const int tileHeight = 2048;

  /// 清单格式版本；切片规则变化时递增，旧目录随之失效。
  static const int _version = 1;

  /// 全局实例；测试可替换为注入了假通道的实例。
  static LongImageTileService instance = LongImageTileService();

  final MethodChannel _channel;
  final Future<Directory> Function() _cacheDirectory;
  final bool _supported;
  final Map<String, LongImageTiles?> _results = <String, LongImageTiles?>{};
  final Map<String, Future<LongImageTiles?>> _pending =
      <String, Future<LongImageTiles?>>{};

  bool get isSupported => _supported;

  /// 本进程内是否已有结果（含不支持/失败的 null）。
  bool isResolved(String path) => _results.containsKey(path);

  LongImageTiles? peek(String path) => _results[path];

  /// 取得（必要时生成）[path] 的分片；同一路径的并发请求合并为一次。
  Future<LongImageTiles?> tilesFor(String path) {
    if (_results.containsKey(path)) {
      return Future<LongImageTiles?>.value(_results[path]);
    }
    return _pending[path] ??= _load(path).then((tiles) {
      _pending.remove(path);
      _results[path] = tiles;
      return tiles;
    });
  }

  Future<LongImageTiles?> _load(String path) async {
    if (!_supported) {
      return null;
    }
    try {
      final source = File(path);
      final stat = await source.stat();
      if (stat.type != FileSystemEntityType.file) {
        return null;
      }
      final root = await _cacheDirectory();
      final key = sha1
          .convert(
            utf8.encode(
              '$path|${stat.size}|${stat.modified.millisecondsSinceEpoch}'
              '|$tileHeight|$_version',
            ),
          )
          .toString()
          .substring(0, 24);
      final dir = p.join(root.path, directoryName, key);
      final cached = await _readManifest(dir);
      if (cached != null) {
        return cached;
      }
      final manifest = await _channel.invokeMapMethod<Object?, Object?>(
        'sliceTall',
        <String, Object?>{
          'source': path,
          'outDir': dir,
          'tileHeight': tileHeight,
        },
      );
      if (manifest == null) {
        return null;
      }
      return LongImageTiles.fromManifest(manifest, dir);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  static Future<LongImageTiles?> _readManifest(String dir) async {
    final file = File(p.join(dir, manifestName));
    if (!await file.exists()) {
      return null;
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        return null;
      }
      final tiles = LongImageTiles.fromManifest(decoded, dir);
      if (tiles == null) {
        return null;
      }
      // 系统清理缓存可能只删掉部分文件，缺任何一段都重切。
      for (final tile in tiles.tiles) {
        if (!await File(tile.path).exists()) {
          return null;
        }
      }
      return tiles;
    } on FormatException {
      return null;
    }
  }
}
