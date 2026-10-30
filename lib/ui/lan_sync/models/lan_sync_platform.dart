// 局域网同步界面里的设备平台与端口常量（纯数据，无副作用）。

import '../../../core/services/lan_sync/lan_sync_discovery.dart';
import '../../../core/services/lan_sync/lan_sync_service_config.dart';

/// 设备所在的平台：决定设备图标与“本机 · 平台”里的平台名。
///
/// 信标与握手里的平台字段是字符串，经 [LanSyncPlatform.fromName] 读入；认不出
/// 的（以后的新平台、手写的旧值）一律为 [unknown]，界面按笔记本图标显示。
enum LanSyncPlatform {
  android,
  ios,
  linux,
  windows,
  macos,
  unknown;

  /// 手机类平台（用手机图标）；其余按电脑显示。
  bool get isMobile => this == android || this == ios;

  /// 按名称读取，不区分大小写；认不出时为 [unknown]。
  static LanSyncPlatform fromName(String? name) {
    final normalized = name?.trim().toLowerCase();
    for (final value in values) {
      if (value.name == normalized) return value;
    }
    return unknown;
  }
}

/// 同步用到的端口（docs/lan_sync.md §5.1、§5.2）。
abstract final class LanSyncPorts {
  /// UDP 发现端口：排障面板里提示 Linux 防火墙放行。
  static const int discovery = kLanSyncDiscoveryPort;

  /// TCP 同步端口的首选值：“手动输入地址”的默认端口，排障面板里提示放行。
  /// 被占用时服务端会改用随机端口，实际端口以本机 [LanSyncLocalDeviceView.port]
  /// 为准。
  static const int preferredSync = kLanSyncPreferredPort;
}
