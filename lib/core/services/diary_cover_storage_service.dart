import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 发布页封面文件存储服务。
///
/// 约束：
/// - 只管理应用私有目录下的封面文件；
/// - 删除操作仅作用于本服务生成的文件，避免误删用户原始图片。
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
    return targetPath;
  }

  static Future<void> deleteManagedCover(String? path) async {
    final normalizedPath = path?.trim();
    if (normalizedPath == null || normalizedPath.isEmpty) {
      return;
    }
    if (!await isManagedCover(normalizedPath)) {
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
    return p.isWithin(coversRoot, normalizedPath) || normalizedPath == coversRoot;
  }

  static Future<Directory> _ensureCoversDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, _coversDirectoryName));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }
}
