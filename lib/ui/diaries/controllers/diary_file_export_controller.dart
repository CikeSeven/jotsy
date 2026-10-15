import 'dart:io';

import 'package:meta/meta.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/backup_file_save_service.dart';
import '../../../core/services/data_archive_service.dart';

/// 把临时 ZIP 交给系统保存，返回保存位置；取消返回 null。
typedef DiaryFileSaver =
    Future<String?> Function({
      required File zipFile,
      required String fileName,
      required String dialogTitle,
    });

/// 把一篇日记导出为日记文件（含标签与引用媒体的 ZIP），交给系统保存。
///
/// 日记文件可在任意设备的“数据管理 → 导入数据”中合并导入，不含应用设置，
/// 也不能用来覆盖全部数据。返回是否已保存，用户取消保存时为 false。
///
/// 临时 ZIP 无论结果都会删除：移动端原生保存在返回前已复制完毕，桌面端
/// 复制后同样不再需要；视频较多时它可能很大，不能留在缓存里。
class DiaryFileExportController {
  const DiaryFileExportController._();

  static Future<bool> export({
    required AppDatabase database,
    required String diaryId,
    required String fileName,
    required String dialogTitle,
    String? password,
    @visibleForTesting
    DiaryFileSaver saveFile = BackupFileSaveService.saveBackupFile,
  }) async {
    final zipFile = await DataArchiveService.exportDiariesToZip(
      database: database,
      diaryIds: <String>[diaryId],
      zipPassword: password,
    );
    try {
      final savePath = await saveFile(
        zipFile: zipFile,
        fileName: fileName,
        dialogTitle: dialogTitle,
      );
      return savePath != null && savePath.trim().isNotEmpty;
    } finally {
      await _deleteQuietly(zipFile);
    }
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // 系统会回收缓存目录；清理失败不应把已保存的导出报告为失败。
    }
  }
}
