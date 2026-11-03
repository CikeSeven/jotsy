import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import 'diary_media_storage_service.dart';

/// 正文“拍照 / 录像”：经 Android 原生通道打开系统相机拍一张照片或一段视频
/// （`DiaryCameraCapture.kt`，只在 `AppPlatform.supportsCameraCapture`）。
///
/// - 输出：系统相机直接写进 `cache/diary_camera/<批次>/`，返回这一份文件；
///   长期存储仍由 [DiaryMediaStorageService.importFile] 负责，导入后经
///   [DiaryMediaStorageService.discardPickerCopy] 删掉暂存（该目录登记在
///   `pickerCacheDirectoryNames`）。不存进系统相册。
/// - 取消返回 null；失败抛 [PlatformException]：`camera_permission_denied`
///   （没有相机权限）、`camera_unavailable`（没有相机或相机应用）、
///   `capture_failed`（拍到的文件读不出来）。
class DiaryCameraCaptureService {
  const DiaryCameraCaptureService._();

  static const MethodChannel _channel = MethodChannel(
    'com.jotsy.diary/camera_capture',
  );

  /// 只接受图片与视频；附件没有“拍摄”入口。
  static Future<List<PlatformFile>?> capture(DiaryMediaKind kind) async {
    assert(kind != DiaryMediaKind.attachment);
    final files = await _channel.invokeListMethod<dynamic>('capture', {
      'kind': kind == DiaryMediaKind.video ? 'video' : 'image',
    });
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
