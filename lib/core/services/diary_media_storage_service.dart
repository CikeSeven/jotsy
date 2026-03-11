import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 日记正文图片文件存储服务。
///
/// 约束：
/// - 仅管理应用私有目录 `diary_images` 下的资源；
/// - 删除操作只针对托管文件，避免误删用户外部路径。
class DiaryMediaStorageService {
  const DiaryMediaStorageService._();

  static const String _imagesDirectoryName = 'diary_images';

  static Future<void> deleteManagedDiaryImage(String? rawPath) async {
    final normalizedPath = rawPath?.trim();
    if (normalizedPath == null || normalizedPath.isEmpty) {
      return;
    }
    if (!await isManagedDiaryImage(normalizedPath)) {
      return;
    }

    final file = File(normalizedPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<bool> isManagedDiaryImage(String path) async {
    final imageDirectory = await _ensureImagesDirectory();
    final imagesRoot = p.normalize(imageDirectory.path);
    final normalizedPath = p.normalize(path);
    return p.isWithin(imagesRoot, normalizedPath) || normalizedPath == imagesRoot;
  }

  static Future<Directory> _ensureImagesDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, _imagesDirectoryName));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }
}
