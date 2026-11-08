import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_platform.dart';
import 'managed_file_paths.dart';

/// 把源文件转成 JPEG 写到目标路径；成功返回 true。测试经
/// [HeifImageConverter.debugTranscoder] 替换。
typedef HeifJpegTranscoder =
    Future<bool> Function(String source, String target);

/// HEIF 系图片（HEIC / HEIF / AVIF）→ JPEG。
///
/// 为什么需要：手机相册默认存 HEIC，Android 用系统解码器能显示，原样复制进
/// 托管目录在手机上看不出问题；但桌面（Windows / Linux）版用 Flutter 自带的
/// 解码器，只认 JPEG / PNG / GIF / WebP / BMP，同步或备份到桌面后这些图只显示
/// “图片加载失败”。桌面上没有可靠的 HEIC 解码手段，所以由能解码的一端（Android
/// 9+，[AppPlatform.supportsHeifToJpeg]）在图片进库时转码（[convertImported]），
/// 已存的旧图由启动后的修复（`HeifMediaRepairService`）补上。
///
/// - 识别只看文件头（ISO BMFF `ftyp` 盒的主品牌与兼容品牌），不看扩展名：
///   导入来源的扩展名不可靠，HEIC 也可能叫 `.jpg`；
/// - 转码经原生通道 `com.jotsy.diary/image_transcode`（`DiaryImageTranscoder.kt`）：
///   方向写进像素、EXIF 方向归正，拍摄时间、相机与 GPS 标签照搬；原文件只读；
/// - 不能转码（其他平台、Android 8 及以下、解码失败）时一律保留原文件，调用方
///   照旧使用原路径——手机上它仍能显示，不能因为转码失败丢图。
abstract final class HeifImageConverter {
  static const MethodChannel _channel = MethodChannel(
    'com.jotsy.diary/image_transcode',
  );

  static HeifJpegTranscoder? _debugTranscoder;

  /// 原生端回报过“系统不支持”（Android 8 及以下）后本进程不再尝试。
  static bool _unsupported = false;

  /// 测试用：替换原生转码；为 null 时恢复默认。
  @visibleForTesting
  static set debugTranscoder(HeifJpegTranscoder? value) {
    _debugTranscoder = value;
    _unsupported = false;
  }

  /// 本机能否转码（不代表某个文件一定转得成）。
  ///
  /// 除了 [AppPlatform.supportsHeifToJpeg] 还要运行时 `Platform.isAndroid`：
  /// widget 测试默认按 Android 跑，但原生通道只在真机工程里注册（见
  /// [AppPlatform] 的说明），测试里不能去调用它，也不该安排启动修复。
  static bool get canConvert =>
      _debugTranscoder != null ||
      (AppPlatform.supportsHeifToJpeg && Platform.isAndroid && !_unsupported);

  /// HEIF 系图片的品牌：HEIC / HEIF 静态图与图片序列、通用 HEIF（mif1 / msf1）
  /// 与 AVIF。视频容器（isom、mp41、qt 等）不在其中。
  static const Set<String> _imageBrands = <String>{
    'heic',
    'heix',
    'heim',
    'heis',
    'hevc',
    'hevx',
    'hevm',
    'hevs',
    'mif1',
    'mif2',
    'msf1',
    'avif',
    'avis',
  };

  /// 判定所需的文件头长度：`ftyp` 盒通常在 40 字节以内，留些余量给兼容品牌。
  static const int headerLength = 64;

  /// [head] 是不是 HEIF 系图片的文件头。
  static bool isHeifHeader(List<int> head) {
    if (head.length < 12) return false;
    String fourcc(int offset) => String.fromCharCodes(head, offset, offset + 4);
    if (fourcc(4) != 'ftyp') return false;
    if (_imageBrands.contains(fourcc(8))) return true;
    // 主品牌是通用值时看兼容品牌（偏移 16 起，每 4 字节一个，到盒末尾为止）。
    final boxSize =
        (head[0] << 24) | (head[1] << 16) | (head[2] << 8) | head[3];
    final end = boxSize < head.length ? boxSize : head.length;
    for (var offset = 16; offset + 4 <= end; offset += 4) {
      if (_imageBrands.contains(fourcc(offset))) return true;
    }
    return false;
  }

  /// 读文件头判定；文件不存在或读不了时为 false。
  static Future<bool> isHeifFile(String path) async {
    try {
      final file = await File(path).open();
      try {
        return isHeifHeader(await file.read(headerLength));
      } finally {
        await file.close();
      }
    } on FileSystemException {
      return false;
    }
  }

  /// [isHeifFile] 的同步版本，供后台 isolate 批量扫描。
  static bool isHeifFileSync(String path) {
    try {
      final file = File(path).openSync();
      try {
        return isHeifHeader(file.readSync(headerLength));
      } finally {
        file.closeSync();
      }
    } on FileSystemException {
      return false;
    }
  }

  /// 把 [source] 转成 JPEG 写到 [target]（已存在则覆盖）；成功返回 true。
  /// 不能转码或失败时返回 false，不抛出、不留半成品。
  static Future<bool> toJpeg(String source, String target) async {
    final debug = _debugTranscoder;
    if (debug != null) return debug(source, target);
    if (!canConvert) return false;
    try {
      await _channel.invokeMethod<Object?>('toJpeg', <String, Object?>{
        'source': source,
        'target': target,
      });
      return true;
    } on PlatformException catch (error) {
      if (error.code == 'unsupported') _unsupported = true;
      debugPrint('HEIF to JPEG failed: ${error.code} ${error.message}');
      return false;
    } on MissingPluginException {
      _unsupported = true;
      return false;
    }
  }

  /// 与 [source] 同目录、主名相同的 `.jpg` 路径（[freshSiblingPath]）。
  static String jpegSiblingPath(String source) =>
      freshSiblingPath(source, 'jpg');

  /// 刚复制进托管目录、还没有任何地方引用的 [path]：是 HEIF 且转码成功时
  /// 在同目录写出 JPEG、删掉这份副本并返回 JPEG 路径；否则原样返回 [path]。
  static Future<String> convertImported(String path) async {
    if (!canConvert || !await isHeifFile(path)) return path;
    final target = jpegSiblingPath(path);
    if (!await toJpeg(path, target)) return path;
    try {
      await File(path).delete();
    } on FileSystemException catch (error) {
      // 只是多留一份没人引用的副本，媒体回收会处理。
      debugPrint('HEIF copy cleanup failed: $error');
    }
    return target;
  }
}
