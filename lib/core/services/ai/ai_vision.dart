import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;

import '../../database/diary_blocks/diary_blocks_media.dart';
import 'ai_models.dart';

/// 把日记里的图片准备成可以发给视觉模型的 [AiImagePart]。
///
/// - 只读本机文件或内嵌的 base64，网络图片跳过（不替用户去下载）；
/// - 原图够小（长边不超过 [maxSide]、文件不超过 [passThroughBytes]、格式
///   是各家都认的 JPEG / PNG / WebP / GIF）时原样发送，省去重新编码；
/// - 否则经引擎按目标尺寸解码后编成 PNG。只解码到目标尺寸，不把整张大图
///   铺进内存；
/// - 任何一张读不出来都只跳过那一张，不让整次请求失败。
abstract final class AiVisionImages {
  static const int defaultMaxSide = 1024;
  static const int passThroughBytes = 1536 * 1024;

  static const Map<String, String> _mimeByExtension = <String, String>{
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.webp': 'image/webp',
    '.gif': 'image/gif',
  };

  /// 正文里的前 [maxCount] 张图片（按出现顺序去重）。
  static Future<List<AiImagePart>> fromDiaryContent(
    String contentJson, {
    required int maxCount,
    int maxSide = defaultMaxSide,
  }) async {
    if (maxCount <= 0) return const <AiImagePart>[];
    final sources = <String>{...extractDiaryImageSources(contentJson)};
    final images = <AiImagePart>[];
    for (final source in sources) {
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
      Uint8List bytes;
      String? mime;
      const marker = 'base64,';
      final index = source.indexOf(marker);
      if (source.startsWith('data:') && index >= 0) {
        bytes = base64Decode(source.substring(index + marker.length));
        mime = source.substring(5, source.indexOf(';')).toLowerCase();
      } else {
        final file = File(source);
        if (!await file.exists()) return null;
        bytes = await file.readAsBytes();
        mime = _mimeByExtension[p.extension(source).toLowerCase()];
      }
      return await _fit(bytes, mime, maxSide);
    } catch (_) {
      return null;
    }
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
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          if (data == null) return null;
          return AiImagePart(data.buffer.asUint8List(), 'image/png');
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
}
