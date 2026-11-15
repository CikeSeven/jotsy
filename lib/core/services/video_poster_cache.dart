import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'storage/media_compressor.dart';

/// 视频的封面帧（一帧 JPEG）：正文里的视频小图与存储管理的缩略图共用这一份
/// 生成与缓存（#252）。
///
/// - 输入：视频的绝对路径；调用方已经知道字节数与修改时间时一并传入（存储
///   管理扫描时就有），省一次 stat。
/// - 输出：临时目录 [directoryName] 下的 JPEG 路径。平台取不到帧（只有 Android
///   有原生实现，见 [MediaCompressor.supportsVideoInfo]）、文件不存在或解码
///   失败时为 null，调用方画占位。
/// - 副作用：写缓存文件。缓存键含路径、大小、修改时间与最长边：同一路径的
///   文件被替换后自然换一帧；旧帧由存储管理的“清理缓存”回收（目录登记在
///   `StorageCacheCatalog`）。
///
/// 同一键的并发请求只生成一次；失败不记住（文件可能刚复制完），下次再试。
class VideoPosterCache {
  VideoPosterCache({
    MediaCompressor? compressor,
    Future<Directory> Function()? temporaryDirectory,
  }) : compressor = compressor ?? createPlatformMediaCompressor(),
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  /// 应用内共用的实例（正文视频小图）；存储管理带着自己的压缩器另建一个，
  /// 磁盘缓存仍是同一个目录。
  static final VideoPosterCache shared = VideoPosterCache();

  /// 缓存目录名。沿用存储管理最早用的名字：已有的缓存仍在“清理缓存”的清单里。
  static const String directoryName = 'storage_video_thumbs';

  /// 存储管理列表 / 网格缩略图的最长边（像素）。
  static const int listMaxSide = 320;

  final MediaCompressor compressor;
  final Future<Directory> Function() _temporaryDirectory;
  final Map<String, Future<String?>> _pending = {};

  /// 本平台能不能取帧；不能时 [posterOf] 一律为 null，调用方可以直接画占位。
  bool get isSupported => compressor.supportsVideoInfo;

  /// [path] 的封面帧路径，最长边不超过 [maxSide] 像素；见类型说明。
  Future<String?> posterOf(
    String path, {
    int maxSide = listMaxSide,
    int? bytes,
    DateTime? modifiedAt,
  }) async {
    if (!isSupported || path.isEmpty) return null;
    var size = bytes;
    var modified = modifiedAt;
    if (size == null || modified == null) {
      try {
        final stat = await File(path).stat();
        if (stat.type != FileSystemEntityType.file) return null;
        size ??= stat.size;
        modified ??= stat.modified;
      } on FileSystemException {
        return null;
      }
    }
    final name = sha1
        .convert(
          utf8.encode(
            '$path|$size|${modified.millisecondsSinceEpoch}|$maxSide',
          ),
        )
        .toString();
    return _pending[name] ??= () async {
      final target = p.join(
        (await _temporaryDirectory()).path,
        directoryName,
        '$name.jpg',
      );
      if (await File(target).exists()) return target;
      final ok = await compressor.videoThumbnail(
        path,
        target: target,
        maxSide: maxSide,
      );
      if (!ok) _pending.remove(name);
      return ok ? target : null;
    }();
  }
}
