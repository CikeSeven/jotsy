import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../database/diary_blocks/diary_blocks_media.dart';
import 'ai_models.dart';

/// 把日记与对话里的图片准备成可以发给视觉模型的 [AiImagePart]。
///
/// - 只读本机文件或内嵌的 base64，网络图片跳过（不替用户去下载）；
/// - 原图够小（长边不超过 [maxSide]、文件不超过 [passThroughBytes]、格式
///   是各家都认的 JPEG / PNG / WebP / GIF）时原样发送，省去重新编码；
/// - 否则经引擎按目标尺寸解码（只解码到目标尺寸，不把整张大图铺进内存），
///   不透明的编成 JPEG（后台 isolate），带透明度的编成 PNG（JPEG 没有透明
///   通道）。照片的 PNG 是 JPEG 的好几倍，十几张就会超出服务商的请求体上限；
/// - 任何一张读不出来都只跳过那一张，不让整次请求失败；
/// - 结果按（来源、文件大小、修改时间、目标尺寸）缓存在内存里：智能体每轮
///   原样重发历史图片，同一张图每次给出**逐字节相同**的结果（提示缓存按
///   前缀命中），也不必每轮重新解码编码。文件被替换（压缩、恢复备份）后
///   大小或修改时间变了，自然重新读取。
abstract final class AiVisionImages {
  static const int defaultMaxSide = 1024;
  static const int passThroughBytes = 1536 * 1024;

  /// 重新编码时的 JPEG 画质。
  static const int jpegQuality = 85;

  /// 缓存最多占用的字节数（按图片字节计）。
  static const int _cacheBudgetBytes = 32 * 1024 * 1024;

  static const Map<String, String> _mimeByExtension = <String, String>{
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.webp': 'image/webp',
    '.gif': 'image/gif',
  };

  /// 最近用过的在后：超出预算时从最早用过的开始丢。读不出的记为 null，
  /// 同一份坏文件不反复尝试。
  static final LinkedHashMap<String, AiImagePart?> _cache =
      LinkedHashMap<String, AiImagePart?>();
  static int _cacheBytes = 0;

  /// 正文里的图片来源：文档顺序、去掉重复的。智能体给图片编号（“第 n 张”）
  /// 与查看图片都只按这一份列表，编号因此处处一致。
  static List<String> sourcesOf(String contentJson) =>
      <String>{...extractDiaryImageSources(contentJson)}.toList();

  /// 正文里的前 [maxCount] 张图片（按出现顺序去重）。
  static Future<List<AiImagePart>> fromDiaryContent(
    String contentJson, {
    required int maxCount,
    int maxSide = defaultMaxSide,
  }) async {
    if (maxCount <= 0) return const <AiImagePart>[];
    final images = <AiImagePart>[];
    for (final source in sourcesOf(contentJson)) {
      if (images.length >= maxCount) break;
      final image = await load(source, maxSide: maxSide);
      if (image != null) images.add(image);
    }
    return images;
  }

  /// 读取一张图片；读不出来返回 null。
  static Future<AiImagePart?> load(
    String source, {
    int maxSide = defaultMaxSide,
  }) async {
    try {
      final uri = Uri.tryParse(source);
      if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
        return null;
      }
      const marker = 'base64,';
      final index = source.indexOf(marker);
      if (source.startsWith('data:') && index >= 0) {
        final key = 'data:${md5.convert(utf8.encode(source))}|$maxSide';
        return await _cached(key, () {
          final bytes = base64Decode(source.substring(index + marker.length));
          final mime = source.substring(5, source.indexOf(';')).toLowerCase();
          return _fit(bytes, mime, maxSide);
        });
      }
      final file = File(source);
      if (!await file.exists()) return null;
      final stat = await file.stat();
      final key =
          '$source|${stat.size}|${stat.modified.microsecondsSinceEpoch}|'
          '$maxSide';
      return await _cached(key, () async {
        final bytes = await file.readAsBytes();
        final mime = _mimeByExtension[p.extension(source).toLowerCase()];
        return _fit(bytes, mime, maxSide);
      });
    } catch (_) {
      return null;
    }
  }

  static Future<AiImagePart?> _cached(
    String key,
    Future<AiImagePart?> Function() compute,
  ) async {
    if (_cache.containsKey(key)) {
      final hit = _cache.remove(key);
      _cache[key] = hit;
      return hit;
    }
    AiImagePart? result;
    try {
      result = await compute();
    } catch (_) {
      result = null;
    }
    _cache[key] = result;
    _cacheBytes += result?.bytes.lengthInBytes ?? 0;
    while (_cacheBytes > _cacheBudgetBytes && _cache.length > 1) {
      final oldest = _cache.keys.first;
      _cacheBytes -= _cache.remove(oldest)?.bytes.lengthInBytes ?? 0;
    }
    return result;
  }

  /// 清空缓存（测试用）。
  static void debugClearCache() {
    _cache.clear();
    _cacheBytes = 0;
  }

  static Future<AiImagePart?> _fit(
    Uint8List bytes,
    String? mime,
    int maxSide,
  ) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      final width = descriptor.width;
      final height = descriptor.height;
      if (width <= 0 || height <= 0) return null;
      final longSide = math.max(width, height);
      final knownFormat = mime != null && _mimeByExtension.containsValue(mime);
      if (knownFormat &&
          longSide <= maxSide &&
          bytes.lengthInBytes <= passThroughBytes) {
        return AiImagePart(bytes, mime);
      }
      final scale = longSide > maxSide ? maxSide / longSide : 1.0;
      final codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (width * scale).round()),
        targetHeight: math.max(1, (height * scale).round()),
      );
      try {
        final frame = await codec.getNextFrame();
        final image = frame.image;
        try {
          final rgba = await image.toByteData(
            format: ui.ImageByteFormat.rawStraightRgba,
          );
          if (rgba == null) return null;
          if (_hasTransparency(rgba)) {
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            if (png == null) return null;
            return AiImagePart(png.buffer.asUint8List(), 'image/png');
          }
          final jpeg = await encodeJpeg(
            rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes),
            width: image.width,
            height: image.height,
          );
          return AiImagePart(jpeg, 'image/jpeg');
        } finally {
          image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } finally {
      descriptor.dispose();
      buffer.dispose();
    }
  }

  /// RGBA 像素里有没有不完全不透明的点（有就编 PNG 保住透明）。
  static bool _hasTransparency(ByteData rgba) {
    for (var i = 3; i < rgba.lengthInBytes; i += 4) {
      if (rgba.getUint8(i) != 0xFF) return true;
    }
    return false;
  }

  /// 把不透明的 RGBA 像素编成 JPEG（后台 isolate；纯 Dart 编码，输出只取决
  /// 于输入，同一张图每次逐字节相同）。
  static Future<Uint8List> encodeJpeg(
    Uint8List rgba, {
    required int width,
    required int height,
  }) => Isolate.run(() {
    final image = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgba.buffer,
      bytesOffset: rgba.offsetInBytes,
      numChannels: 4,
    );
    return img.encodeJpg(
      image,
      quality: jpegQuality,
      chroma: img.JpegChroma.yuv420,
    );
  });
}
