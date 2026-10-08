import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

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
  }) async {
    if (Platform.isAndroid || Platform.isIOS) {
      return saveNativeBackupFile(zipFile: zipFile, fileName: fileName);
    }

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const <String>['zip'],
    );
    if (savePath != null && savePath.trim().isNotEmpty) {
      final outputFile = File(savePath);
      await outputFile.parent.create(recursive: true);
      await zipFile.copy(outputFile.path);
    }
    return savePath;
  }

  static Future<String?> saveNativeBackupFile({
    required File zipFile,
    required String fileName,
  }) {
    return _mobileChannel.invokeMethod<String>('saveBackupFile', {
      'sourcePath': zipFile.path,
      'fileName': fileName,
      'mimeType': _zipMimeType,
    });
  }
}
