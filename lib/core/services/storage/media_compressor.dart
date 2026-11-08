import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../app_platform.dart';
import 'storage_compress_plan.dart';
import 'storage_usage_models.dart';

/// 压缩与媒体信息的平台能力（docs/rules/storage.md）。
///
/// 只有 Android 有实现（[AppPlatform.supportsMediaCompression]）：图片经
/// `com.jotsy.diary/image_transcode` 的 `compress`（系统 ImageDecoder 按目标
/// 尺寸解码、JPEG 编码、照搬拍摄时间与 GPS 等 EXIF），视频经
/// `com.jotsy.diary/video_tools`（Media3 Transformer 转 H.264 / AAC 的 MP4，
/// MediaMetadataRetriever 读元数据与取帧，StatFs 读设备空间）。桌面不提供
/// 压缩，[UnsupportedMediaCompressor] 一律返回“做不到”。
///
/// 所有方法都不抛出：失败返回 false / null，由调用方计为跳过。
abstract interface class MediaCompressor {
  /// 能否压缩图片与视频。
  bool get supportsCompression;

  /// 能否读视频元数据与缩略图。
  bool get supportsVideoInfo;

  Future<StorageDeviceSpace?> deviceSpace();

  /// 按绝对路径读取视频元数据；读不到的不在结果里。
  Future<Map<String, StorageVideoInfo>> probeVideos(List<String> paths);

  /// 在 [target] 写一张最长边不超过 [maxSide] 的 JPEG 缩略图。
  Future<bool> videoThumbnail(
    String source, {
    required String target,
    int maxSide = 320,
  });

  /// 把 [source] 压成 JPEG 写到 [target]（不存在的新路径）。
  Future<bool> compressImage(
    String source,
    String target,
    StorageImagePreset preset,
  );

  /// 把 [source] 转成 MP4 写到 [target]；[onProgress] 收到 0–1 的进度。
  Future<bool> compressVideo(
    String source,
    String target,
    StorageVideoPreset preset, {
    void Function(double progress)? onProgress,
    StorageCancelToken? cancel,
  });
}

/// 压缩流程的取消信号：取消后正在进行的视频转码会被中止。
class StorageCancelToken {
  final Completer<void> _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;

  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (!isCancelled) _cancelled.complete();
  }
}

/// 不能压缩的平台（桌面）。
class UnsupportedMediaCompressor implements MediaCompressor {
  const UnsupportedMediaCompressor();

  @override
  bool get supportsCompression => false;

  @override
  bool get supportsVideoInfo => false;

  @override
  Future<StorageDeviceSpace?> deviceSpace() async => null;

  @override
  Future<Map<String, StorageVideoInfo>> probeVideos(List<String> paths) async =>
      const <String, StorageVideoInfo>{};

  @override
  Future<bool> videoThumbnail(
    String source, {
    required String target,
    int maxSide = 320,
  }) async => false;

  @override
  Future<bool> compressImage(
    String source,
    String target,
    StorageImagePreset preset,
  ) async => false;

  @override
  Future<bool> compressVideo(
    String source,
    String target,
    StorageVideoPreset preset, {
    void Function(double progress)? onProgress,
    StorageCancelToken? cancel,
  }) async => false;
}

/// 本平台的压缩器：Android 为原生实现，其余平台为 [UnsupportedMediaCompressor]。
///
/// 除了 [AppPlatform] 还要运行时 `Platform.isAndroid`：widget 测试默认按
/// Android 跑，但原生通道只在真机工程里注册。
MediaCompressor createPlatformMediaCompressor() =>
    AppPlatform.supportsMediaCompression && Platform.isAndroid
    ? NativeMediaCompressor()
    : const UnsupportedMediaCompressor();

/// Android 原生实现（见类型说明）。
class NativeMediaCompressor implements MediaCompressor {
  NativeMediaCompressor() {
    _videoChannel.setMethodCallHandler(_onCall);
  }

  static const MethodChannel _imageChannel = MethodChannel(
    'com.jotsy.diary/image_transcode',
  );
  static const MethodChannel _videoChannel = MethodChannel(
    'com.jotsy.diary/video_tools',
  );

  final Map<int, void Function(double)> _progress = {};
  int _nextJob = 0;

  @override
  bool get supportsCompression => true;

  @override
  bool get supportsVideoInfo => true;

  Future<Object?> _onCall(MethodCall call) async {
    if (call.method != 'progress') return null;
    final arguments = call.arguments;
    if (arguments is! Map) return null;
    final id = arguments['id'];
    final value = arguments['value'];
    if (id is int && value is num) _progress[id]?.call(value.toDouble());
    return null;
  }

  @override
  Future<StorageDeviceSpace?> deviceSpace() async {
    final result = await _invoke<Map<Object?, Object?>>(
      _videoChannel,
      'deviceSpace',
    );
    final total = result?['total'];
    final free = result?['free'];
    if (total is! int || free is! int || total <= 0) return null;
    return StorageDeviceSpace(totalBytes: total, freeBytes: free);
  }

  @override
  Future<Map<String, StorageVideoInfo>> probeVideos(List<String> paths) async {
    if (paths.isEmpty) return const <String, StorageVideoInfo>{};
    final result = await _invoke<Map<Object?, Object?>>(
      _videoChannel,
      'probe',
      {'paths': paths},
    );
    final infos = <String, StorageVideoInfo>{};
    result?.forEach((path, value) {
      if (path is! String || value is! Map) return;
      int read(String key) {
        final number = value[key];
        return number is int ? number : 0;
      }

      infos[path] = StorageVideoInfo(
        width: read('width'),
        height: read('height'),
        durationMs: read('durationMs'),
        bitrate: read('bitrate'),
      );
    });
    return infos;
  }

  @override
  Future<bool> videoThumbnail(
    String source, {
    required String target,
    int maxSide = 320,
  }) async =>
      await _invoke<bool>(_videoChannel, 'thumbnail', {
        'source': source,
        'target': target,
        'maxSide': maxSide,
      }) ??
      false;

  @override
  Future<bool> compressImage(
    String source,
    String target,
    StorageImagePreset preset,
  ) async {
    final result = await _invoke<Object?>(_imageChannel, 'compress', {
      'source': source,
      'target': target,
      'maxSide': preset.maxSide,
      'quality': preset.quality,
    });
    return result != null;
  }

  @override
  Future<bool> compressVideo(
    String source,
    String target,
    StorageVideoPreset preset, {
    void Function(double progress)? onProgress,
    StorageCancelToken? cancel,
  }) async {
    final id = _nextJob++;
    if (onProgress != null) _progress[id] = onProgress;
    unawaited(
      cancel?.whenCancelled.then(
        (_) => _invoke<Object?>(_videoChannel, 'cancel', {'id': id}),
      ),
    );
    try {
      return await _invoke<bool>(_videoChannel, 'transcode', {
            'id': id,
            'source': source,
            'target': target,
            'shortSide': preset.shortSide,
            'videoBitrate': preset.videoBitrate,
            'audioBitrate': StorageVideoPreset.audioBitrate,
          }) ??
          false;
    } finally {
      _progress.remove(id);
    }
  }

  static Future<T?> _invoke<T>(
    MethodChannel channel,
    String method, [
    Object? arguments,
  ]) async {
    try {
      return await channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      debugPrint('Media tools $method failed: ${error.code} ${error.message}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
