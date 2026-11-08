import 'dart:io';

import 'package:node_diary/core/services/storage/media_compressor.dart';
import 'package:node_diary/core/services/storage/storage_compress_plan.dart';
import 'package:node_diary/core/services/storage/storage_usage_models.dart';

/// 不调原生通道的压缩器：把输出写成 [outputBytes] 个字节（默认原文件的
/// 四分之一），记录调用；[failPaths] 里的源文件返回失败。
class FakeMediaCompressor implements MediaCompressor {
  FakeMediaCompressor({
    this.supportsCompression = true,
    this.outputBytes,
    this.videoInfo = const <String, StorageVideoInfo>{},
    this.space,
    this.beforeEach,
  });

  @override
  final bool supportsCompression;

  @override
  bool get supportsVideoInfo => supportsCompression;

  /// 固定的输出大小；为 null 时取原文件的四分之一。
  final int? outputBytes;
  final Map<String, StorageVideoInfo> videoInfo;
  final StorageDeviceSpace? space;

  /// 每次压缩前回调（测试在这里取消或改库）。
  final Future<void> Function(String source)? beforeEach;
  final Set<String> failPaths = <String>{};
  final List<String> compressed = <String>[];

  @override
  Future<StorageDeviceSpace?> deviceSpace() async => space;

  @override
  Future<Map<String, StorageVideoInfo>> probeVideos(List<String> paths) async =>
      {
        for (final path in paths)
          if (videoInfo[path] case final info?) path: info,
      };

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
  ) => _write(source, target);

  @override
  Future<bool> compressVideo(
    String source,
    String target,
    StorageVideoPreset preset, {
    void Function(double progress)? onProgress,
    StorageCancelToken? cancel,
  }) async {
    onProgress?.call(0.5);
    return _write(source, target);
  }

  Future<bool> _write(String source, String target) async {
    await beforeEach?.call(source);
    if (failPaths.contains(source)) return false;
    final length = await File(source).length();
    await File(
      target,
    ).writeAsBytes(List<int>.filled(outputBytes ?? length ~/ 4, 7));
    compressed.add(source);
    return true;
  }
}
