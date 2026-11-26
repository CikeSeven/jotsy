import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'app_data_location.dart';
import 'app_platform.dart';

/// 应用私有数据（数据库、正文图片 / 视频 / 附件、录音、封面、备份暂存）的
/// 根目录，所有读写托管数据的服务都经这里取得，禁止各自调用 path_provider。
///
/// - 手机：应用文档目录（`getApplicationDocumentsDirectory`），是沙盒内的
///   私有目录，沿用至今，已有用户的数据都在这里，不能改；
/// - 桌面：默认使用应用支持目录（`getApplicationSupportDirectory`，如 Linux 的
///   `~/.local/share/<应用 id>`、Windows 的 `%APPDATA%\<公司>\<应用>`），也可由
///   用户经安装程序或存储管理设置迁移到自定义目录（配置存于
///   [AppDataLocationStore]）。
///
/// 备份里的媒体路径只按 `diary_images/...` 这类托管子目录名重绑到本目录
/// （`BackupMediaPaths`），与根目录在哪无关，跨平台恢复同样成立。
Future<Directory> appDataRootDirectory() async {
  if (!AppPlatform.isDesktop) {
    return getApplicationDocumentsDirectory();
  }
  return AppDataLocationStore.instance.resolveDirectory();
}

/// 导入正文字体的基目录：桌面跟随 [appDataRootDirectory]（可一并迁移），
/// 手机保留在既有用户使用的 `getApplicationSupportDirectory`。
Future<Directory> appFontsBaseDirectory() {
  if (AppPlatform.isDesktop) {
    return appDataRootDirectory();
  }
  return getApplicationSupportDirectory();
}

/// 清除桌面数据根目录缓存（迁移或切换存储位置后调用）。
void invalidateAppDataRootCache() {
  AppDataLocationStore.instance.invalidateCache();
}
