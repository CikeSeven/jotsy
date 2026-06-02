import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

/// 备份文件保存服务。
///
/// Android 的 `file_picker.saveFile(bytes: ...)` 会把整个 ZIP 通过
/// MethodChannel 传给原生层，大备份会同时占用 Dart 堆和 Android 堆。
/// 因此 Android 走应用自有通道，仅传临时文件路径，由原生 SAF 按流复制。
class BackupFileSaveService {
  BackupFileSaveService._();

  static const MethodChannel _androidChannel = MethodChannel(
    'com.jotsy.diary/backup_file_saver',
  );
  static const String _zipMimeType = 'application/zip';

  static Future<String?> saveBackupFile({
    required File zipFile,
    required String fileName,
    required String dialogTitle,
  }) async {
    if (Platform.isAndroid) {
      return saveAndroidBackupFile(zipFile: zipFile, fileName: fileName);
    }

    if (Platform.isIOS) {
      return FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const <String>['zip'],
        bytes: await zipFile.readAsBytes(),
      );
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

  static Future<String?> saveAndroidBackupFile({
    required File zipFile,
    required String fileName,
  }) {
    return _androidChannel.invokeMethod<String>('saveBackupFile', {
      'sourcePath': zipFile.path,
      'fileName': fileName,
      'mimeType': _zipMimeType,
    });
  }
}
