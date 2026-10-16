import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// 把导出内容交给用户选择的位置保存；返回是否保存（用户取消为 false）。
///
/// 平台差异：Android / iOS 的系统保存对话框连同字节一起写入（应用拿不到可
/// 写的真实路径）；桌面端只返回路径，由这里创建目录并写文件。
Future<bool> saveDiaryExportBytes({
  required String dialogTitle,
  required Uint8List bytes,
  required String fileName,
  required List<String> allowedExtensions,
}) async {
  String? savePath;
  if (Platform.isAndroid || Platform.isIOS) {
    savePath = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      bytes: bytes,
    );
  } else {
    savePath = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    if (savePath != null && savePath.trim().isNotEmpty) {
      final outputFile = File(savePath);
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsBytes(bytes, flush: true);
    }
  }
  return savePath != null && savePath.trim().isNotEmpty;
}
