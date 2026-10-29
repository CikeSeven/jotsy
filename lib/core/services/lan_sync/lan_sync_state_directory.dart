import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../app_data_directory.dart';
import '../app_platform.dart';
import 'lan_sync_network.dart';

/// 局域网同步本机状态目录（`identity.json`、`store.json`、检查点、分面历史、
/// 墓碑等，见 docs/lan_sync.md §3）的生产解析，返回前确保目录存在。
///
/// 为什么要放在“不备份”的位置：这里存的是**这台设备**的身份（deviceId 与
/// 私钥种子）和它与每台对端的同步进度。Android 的自动备份（Auto Backup，本应用
/// 未关闭）与换机迁移会把应用目录整份搬到新手机上——新手机就会冒用旧手机的
/// 身份，被已配对设备当成同一台；带过去的检查点、墓碑也不再对应新手机的数据，
/// 下一次同步会把对端的记录误判为“本机已删除”。`noBackupFilesDir` 正是系统为
/// “不要随备份与迁移带走”的文件准备的目录，身份缺失时会重新生成并清空同步
/// 状态，等于一台新设备（§3“身份”）。
///
/// - Android：`<noBackupFilesDir>/lan_sync/`，路径经原生通道取得；通道不可用时
///   回落到应用支持目录（会随备份克隆，打印日志以便排查），不让同步整体失败。
/// - 桌面（Linux / Windows / macOS）：应用支持目录下 `lan_sync/`。桌面没有系统级
///   应用备份，这里经 [appDataRootDirectory] 取得（桌面上它就是应用支持目录），
///   遵守“托管数据根目录只经它取得”的约定；`lan_sync/` 不在备份的媒体目录名单
///   里，也不会被应用自己的备份打包。
/// - 其他平台（iOS 不支持局域网同步，仅为完整性）：应用支持目录。
///
/// 只供生产装配处（`lan_sync_service.dart`）调用；同步引擎各类一律由构造参数
/// 注入 `stateDir`，测试传临时目录。
Future<Directory> lanSyncStateDirectory({LanSyncNativeChannel? channel}) async {
  final Directory base;
  if (AppPlatform.isAndroid) {
    final noBackup = await (channel ?? LanSyncNativeChannel.instance)
        .noBackupDirectory();
    if (noBackup != null) {
      base = Directory(noBackup);
    } else {
      debugPrint(
        'lanSyncStateDirectory: noBackupFilesDir unavailable, '
        'falling back to the application support directory.',
      );
      base = await getApplicationSupportDirectory();
    }
  } else if (AppPlatform.isDesktop) {
    base = await appDataRootDirectory();
  } else {
    base = await getApplicationSupportDirectory();
  }
  final directory = Directory(p.join(base.path, lanSyncStateDirectoryName));
  await directory.create(recursive: true);
  return directory;
}

/// 状态目录名。
const String lanSyncStateDirectoryName = 'lan_sync';
