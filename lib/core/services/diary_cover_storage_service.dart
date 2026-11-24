import 'dart:io';

import 'package:path/path.dart' as p;
import 'app_data_directory.dart';
import 'heif_image_converter.dart';
import 'storage/managed_media_dedup.dart';

/// 发布页封面文件存储服务。
///
/// 约束：
/// - 只管理应用私有目录下的封面文件；
/// - 删除操作仅作用于本次刚导入、还没被共用的文件，避免误删用户原始图片或
///   别处在用的文件；
/// - HEIC / HEIF / AVIF 封面在能转码的平台转成 JPEG（见 [HeifImageConverter]），
///   同步或备份到桌面后同样能显示；
/// - 拷贝后若 `diary_images/` 或 `diary_covers/` 里已有逐字节相同的文件（例如
///   把正文里的图设为封面），改用那份、删掉新副本（[ManagedMediaDedup]）：
///   封面因此可能指向 `diary_images/`，备份恢复重绑封面时两个目录都会找。
class DiaryCoverStorageService {
  const DiaryCoverStorageService._();

  static const String _coversDirectoryName = 'diary_covers';

  static Future<String> importCover(String sourcePath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw const FileSystemException('封面源文件不存在');
    }

    final coversDirectory = await _ensureCoversDirectory();
    final extension = p.extension(sourcePath);
    final targetName =
        'cover_${DateTime.now().microsecondsSinceEpoch}'
        '${extension.isEmpty ? '.jpg' : extension}';
    final targetPath = p.join(coversDirectory.path, targetName);

    await sourceFile.copy(targetPath);
    final stored = await HeifImageConverter.convertImported(targetPath);
    // 先登记再找同内容文件，顺序见 DiaryMediaStorageService.importFile。
    FreshManagedFiles.claim(stored);
    return ManagedMediaDedup.adopt(stored, cover: true);
  }

  /// 删除本次刚导入、还没交给日记的封面（导入完成时页面已经关闭）。复用的
  /// 已有文件与以前的封面不动，交给按引用的媒体回收。
  static Future<void> deleteManagedCover(String? path) async {
    final normalizedPath = path?.trim();
    if (normalizedPath == null || normalizedPath.isEmpty) {
      return;
    }
    if (!await isManagedCover(normalizedPath)) {
      return;
    }
    if (!FreshManagedFiles.release(normalizedPath)) {
      return;
    }

    final file = File(normalizedPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<bool> isManagedCover(String path) async {
    final coversDirectory = await _ensureCoversDirectory();
    final coversRoot = p.normalize(coversDirectory.path);
    final normalizedPath = p.normalize(path);
    return p.isWithin(coversRoot, normalizedPath) ||
        normalizedPath == coversRoot;
  }

  static Future<Directory> _ensureCoversDirectory() async {
    final root = await appDataRootDirectory();
    final directory = Directory(p.join(root.path, _coversDirectoryName));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }
}
