import 'dart:io';

import 'package:flutter/services.dart';

import 'desktop_save_service.dart';

/// 备份文件保存服务。
///
/// 移动端仅把临时 ZIP 路径交给原生文件选择器，避免在 Dart 和原生堆中
/// 同时保留整个含视频的备份。返回保存位置；取消返回 null，失败保留源文件。
class BackupFileSaveService {
  BackupFileSaveService._();

  static const MethodChannel _mobileChannel = MethodChannel(
    'com.jotsy.diary/backup_file_saver',
  );
  static const String _zipMimeType = 'application/zip';

  static Future<String?> saveBackupFile({
    required File zipFile,
    required String fileName,
    required String dialogTitle,
  }) {
    return saveFile(
      file: zipFile,
      fileName: fileName,
      dialogTitle: dialogTitle,
      mimeType: _zipMimeType,
      extension: 'zip',
    );
  }

  /// 把任意类型的临时文件交给系统保存（日记导出的 PDF、Word 等共用）；
  /// 移动端同样只传路径，原生侧流式复制。
  static Future<String?> saveFile({
    required File file,
    required String fileName,
    required String dialogTitle,
    required String mimeType,
    required String extension,
  }) async {
    if (Platform.isAndroid || Platform.isIOS) {
      return saveNativeBackupFile(
        zipFile: file,
        fileName: fileName,
        mimeType: mimeType,
      );
    }

    // 桌面与“另存为…”共用同一条对话框 + 文件复制链路。
    return const DesktopSaveService().saveFile(
      file,
      fileName: fileName,
      dialogTitle: dialogTitle,
      extension: extension,
    );
  }

  static Future<String?> saveNativeBackupFile({
    required File zipFile,
    required String fileName,
    String mimeType = _zipMimeType,
  }) {
    return _mobileChannel.invokeMethod<String>('saveBackupFile', {
      'sourcePath': zipFile.path,
      'fileName': fileName,
      'mimeType': mimeType,
    });
  }
}
