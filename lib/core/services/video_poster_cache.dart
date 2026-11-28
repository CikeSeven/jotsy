import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'storage/media_compressor.dart';
import 'storage/storage_usage_models.dart';

/// 视频的封面帧（一帧 JPEG）与元信息（尺寸、时长）：正文视频卡片 / 小图与
/// 存储管理的缩略图共用这一份生成与缓存（#252）。
///
/// - 输入：视频的绝对路径；调用方已经知道字节数与修改时间时一并传入（存储
///   管理扫描时就有），省一次 stat。
/// - 输出：临时目录 [directoryName] 下的 JPEG 路径，或 [StorageVideoInfo]。
///   平台取不到帧（只有 Android 有原生实现，见 [MediaCompressor.supportsVideoInfo]）、
///   文件不存在或解码失败时为 null，调用方画占位。
/// - 副作用：写缓存文件。缓存键含路径、大小、修改时间与最长边：同一路径的
///   文件被替换后自然换一帧；旧帧由存储管理的“清理缓存”回收（目录登记在
///   `StorageCacheCatalog`）。
///
/// 同一键的并发请求只生成一次；失败不记住（文件可能刚复制完），下次再试。
/// 原生取帧与元信息探测限制最大并发数，避免多段视频同时触发大量
/// `MediaMetadataRetriever` 导致卡顿或 OOM。
class VideoPosterCache {
  VideoPosterCache({
    MediaCompressor? compressor,
    Future<Directory> Function()? temporaryDirectory,
  }) : compressor = compressor ?? createPlatformMediaCompressor(),
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  /// 应用内共用的实例（正文视频卡片与小图）；存储管理带着自己的压缩器另建一个，
  /// 磁盘缓存仍是同一个目录。
  static final VideoPosterCache shared = VideoPosterCache();

  /// 缓存目录名。沿用存储管理最早用的名字：已有的缓存仍在“清理缓存”的清单里。
  static const String directoryName = 'storage_video_thumbs';

  /// 存储管理列表 / 网格缩略图的最长边（像素）。
  static const int listMaxSide = 320;

  static const int _infoCapacity = 256;
  static const int _maxConcurrentNativeOps = 2;

  final MediaCompressor compressor;
  final Future<Directory> Function() _temporaryDirectory;
  final Map<String, Future<String?>> _pending = {};
  final LinkedHashMap<String, StorageVideoInfo> _infos =
      LinkedHashMap<String, StorageVideoInfo>();
  final Map<String, Future<StorageVideoInfo?>> _pendingInfo = {};
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();
  int _runningNativeOps = 0;

  /// 本平台能不能取帧与元信息；不能时一律返回 null，调用方可以直接画占位。
  bool get isSupported => compressor.supportsVideoInfo;

  /// 已缓存的视频元信息（未探测或失败时为 null）。
  StorageVideoInfo? peekInfo(String path) => _infos[path];

  /// 探测 [path] 的宽高与时长（只走轻量元信息读取，不创建播放器）；已缓存时
  /// 直接返回，同一路径的并发请求合并，失败不缓存。
  Future<StorageVideoInfo?> infoOf(String path) {
    if (!isSupported || path.isEmpty) return Future<StorageVideoInfo?>.value();
    final cached = _infos[path];
    if (cached != null) return Future<StorageVideoInfo?>.value(cached);
    return _pendingInfo[path] ??= _probeInfo(path);
  }

  Future<StorageVideoInfo?> _probeInfo(String path) async {
    try {
      final result = await _withPermit(() => compressor.probeVideos([path]));
      final info = result[path];
      if (info != null) {
        _rememberInfo(path, info);
      }
      return info;
    } finally {
      _pendingInfo.remove(path);
    }
  }

  void _rememberInfo(String path, StorageVideoInfo info) {
    _infos.remove(path);
    _infos[path] = info;
    while (_infos.length > _infoCapacity) {
      _infos.remove(_infos.keys.first);
    }
  }

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
      final ok = await _withPermit(
        () => compressor.videoThumbnail(path, target: target, maxSide: maxSide),
      );
      if (!ok) _pending.remove(name);
      return ok ? target : null;
    }();
  }

  Future<T> _withPermit<T>(Future<T> Function() action) async {
    if (_runningNativeOps >= _maxConcurrentNativeOps) {
      final waiter = Completer<void>();
      _waiters.addLast(waiter);
      await waiter.future;
    }
    _runningNativeOps++;
    try {
      return await action();
    } finally {
      _runningNativeOps--;
      if (_waiters.isNotEmpty) {
        _waiters.removeFirst().complete();
      }
    }
  }
}
