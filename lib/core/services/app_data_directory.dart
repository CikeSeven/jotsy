import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'app_platform.dart';

/// 应用私有数据（数据库、正文图片 / 视频 / 附件、录音、封面、备份暂存）的
/// 根目录，所有读写托管数据的服务都经这里取得，禁止各自调用 path_provider。
///
/// - 手机：应用文档目录（`getApplicationDocumentsDirectory`），是沙盒内的
///   私有目录，沿用至今，已有用户的数据都在这里，不能改；
/// - 桌面：应用支持目录（`getApplicationSupportDirectory`，如 Linux 的
///   `~/.local/share/<应用 id>`、Windows 的 `%APPDATA%\<公司>\<应用>`）。桌面的
///   “文档目录”就是用户自己的 `~/Documents`，把数据库和媒体散落在那里既会和
///   用户文件混在一起，也可能被网盘同步工具误同步。桌面此前没有用户，无需迁移。
///
/// 备份里的媒体路径只按 `diary_images/...` 这类托管子目录名重绑到本目录
/// （`BackupMediaPaths`），与根目录在哪无关，跨平台恢复同样成立。
Future<Directory> appDataRootDirectory() async {
  if (!AppPlatform.isDesktop) {
    return getApplicationDocumentsDirectory();
  }
  // 桌面的支持目录首次启动时可能还不存在；SQLite 只建文件不建父目录，
  // 这里先建好，各服务拼子目录时也不必再判断根目录。
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  return directory;
}
