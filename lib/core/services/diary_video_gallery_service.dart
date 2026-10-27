import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

/// Android 视频经系统照片选择器（不支持时使用系统文件选择器）按项授权。
/// 原生层把临时 URI 流式缓存为文件后只传路径；长期存储仍由媒体导入服务负责。
class DiaryVideoGalleryService {
  const DiaryVideoGalleryService._();

  static const MethodChannel _channel = MethodChannel(
    'com.jotsy.diary/video_gallery',
  );

  static Future<List<PlatformFile>?> pickAndroidVideos() async {
    final files = await _channel.invokeListMethod<dynamic>('pickVideos');
    if (files == null) return null;
    return files.map((data) {
      final file = Map<String, dynamic>.from(data as Map);
      return PlatformFile(
        name: file['name'] as String,
        path: file['path'] as String,
        size: (file['size'] as num).toInt(),
      );
    }).toList();
  }
}
