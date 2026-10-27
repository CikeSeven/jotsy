import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'app_data_directory.dart';
import 'diary_media_storage_service.dart';

/// 应用背景图（“背景与材质”）的文件存储。
///
/// - 输入：用户选中的图片路径；输出：托管目录 `app_backgrounds/` 里的
///   **文件名**。设置（`AppSurfaceSettings`）只存文件名、不存路径：托管根目录
///   在不同设备、不同平台上不同，存文件名才能让完整备份恢复后设置直接有效；
/// - 副作用：只在本目录内新建 / 删除文件，从不改动用户选中的原图。
///
/// 这个目录刻意不放进 `backupMediaDirectories`：那份列表同时是日记媒体回收
/// （`diary_media_sweeper.dart`）的扫描范围，背景图不被任何日记引用，放进去
/// 会被当作孤儿文件删掉。随完整备份导出与覆盖恢复见
/// `backupSettingsMediaDirectories`；未引用文件的清理只经 [deleteUnreferenced]。
class AppBackgroundStorageService {
  const AppBackgroundStorageService._();

  static const String directoryName = 'app_backgrounds';

  /// 文件名是否可以安全地拼到托管目录下。
  ///
  /// 设置可能来自手改的备份或旧版本，文件名里带路径分隔符或 `..` 时拼出的
  /// 路径会逃出托管目录（目录穿越），一律拒绝；渲染层与清理都只认通过这里
  /// 的名字。
  static bool isValidName(String? name) {
    if (name == null) return false;
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed != name) return false;
    if (name == '.' || name == '..' || name.contains('..')) return false;
    if (name.contains('/') || name.contains('\\')) return false;
    // Windows 盘符（`C:x`）与 NUL 同样会改变路径的含义。
    if (name.contains(':') || name.contains('\u0000')) return false;
    return true;
  }

  /// 已拿到托管根目录时同步拼出背景图路径，供渲染层逐帧使用；调用方须先
  /// 用 [isValidName] 校验 [name]。
  static String pathFor(Directory root, String name) =>
      p.join(root.path, directoryName, name);

  /// 把 [sourcePath] 拷贝进托管目录，返回新文件名
  /// （`bg_<微秒时间戳><扩展名>`，没有扩展名时按 `.jpg`）。
  ///
  /// 每次都生成新名字而不是覆盖旧图：设置写入失败或用户撤销时，旧设置指向
  /// 的文件仍然完好。
  static Future<String> importImage(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('背景图源文件不存在');
    }
    final directory = await _ensureDirectory();
    final extension = p.extension(sourcePath).toLowerCase();
    final name =
        'bg_${DateTime.now().microsecondsSinceEpoch}'
        '${extension.isEmpty ? '.jpg' : extension}';
    await source.copy(p.join(directory.path, name));
    return name;
  }

  /// 解析文件名对应的托管文件；名字不合法或文件已不存在时返回 null
  /// （渲染层据此按“没有背景”处理，不报错）。
  static Future<File?> resolve(String? name) async {
    if (!isValidName(name)) return null;
    final root = await appDataRootDirectory();
    final file = File(pathFor(root, name!));
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    return type == FileSystemEntityType.file ? file : null;
  }

  /// 选一张图片并导入托管目录。
  ///
  /// 文件选择器在部分平台会先把原图复制到缓存，无论导入成功与否都在
  /// finally 里丢掉这份缓存（与日记本封面同一条链路），不在缓存里留大图。
  static Future<AppBackgroundPickResult> pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) {
      return const AppBackgroundPickCancelled();
    }
    final selectedPath = result.files.first.path?.trim();
    if (selectedPath == null || selectedPath.isEmpty) {
      return const AppBackgroundPickMissingPath();
    }
    try {
      return AppBackgroundPicked(await importImage(selectedPath));
    } catch (error) {
      debugPrint('App background import failed: $error');
      return const AppBackgroundPickFailed();
    } finally {
      await DiaryMediaStorageService.discardPickerCopy(selectedPath);
    }
  }

  /// 删除托管目录里不在 [keep] 中的文件，返回删除的个数。
  ///
  /// [keep] 应取自已保存的设置（`AppSurfaceSettings.referencedImages`，含
  /// 暂未启用的区域背景）；刚导入、还没写进设置的图片调用方不能在此时清理。
  /// 只删本目录第一层的普通文件：子目录与符号链接一律不碰，单个文件删除
  /// 失败不影响其余文件。
  static Future<int> deleteUnreferenced(Set<String> keep) async {
    final root = await appDataRootDirectory();
    final directory = Directory(p.join(root.path, directoryName));
    if (!await directory.exists()) return 0;
    var deleted = 0;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      if (keep.contains(p.basename(entity.path))) continue;
      try {
        await entity.delete();
        deleted++;
      } on FileSystemException catch (error) {
        debugPrint('App background cleanup skipped ${entity.path}: $error');
      }
    }
    return deleted;
  }

  static Future<Directory> _ensureDirectory() async {
    final root = await appDataRootDirectory();
    final directory = Directory(p.join(root.path, directoryName));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }
}

/// [AppBackgroundStorageService.pickAndImport] 的结果。
sealed class AppBackgroundPickResult {
  const AppBackgroundPickResult();
}

/// 用户取消了选择。
final class AppBackgroundPickCancelled extends AppBackgroundPickResult {
  const AppBackgroundPickCancelled();
}

/// 选择器没有给出本地路径（如部分云端文件）。
final class AppBackgroundPickMissingPath extends AppBackgroundPickResult {
  const AppBackgroundPickMissingPath();
}

/// 拷贝进托管目录失败。
final class AppBackgroundPickFailed extends AppBackgroundPickResult {
  const AppBackgroundPickFailed();
}

/// 导入成功，[name] 为托管目录里的文件名。
final class AppBackgroundPicked extends AppBackgroundPickResult {
  const AppBackgroundPicked(this.name);

  final String name;
}
