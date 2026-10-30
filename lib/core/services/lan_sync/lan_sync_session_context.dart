// 会话的输入：本机的同步部件与对方信息（由 lan_sync_session.dart 导出）。
//
// 纯数据，无副作用。服务每次会话按当前状态新建一份；测试直接用
// test/support/lan_sync_two_devices.dart 的两台设备拼出来。
import 'dart:io';

import 'sync/sync_apply.dart';
import 'sync/sync_local_state.dart';
import 'sync/sync_media.dart';
import 'sync/sync_media_index.dart';

/// 本机参与会话的同步部件（同一台设备的会话共用；一次只能有一个会话在用）。
class LanSyncSessionContext {
  const LanSyncSessionContext({
    required this.deviceId,
    required this.state,
    required this.applier,
    required this.media,
    required this.mediaIndex,
    required this.dataRoot,
    required this.flushAll,
    required this.isEditing,
    this.clock = DateTime.now,
    this.appVersion = '',
  });

  final String deviceId;
  final SyncLocalState state;
  final SyncApplier applier;
  final SyncMediaLibrary media;
  final SyncMediaIndex mediaIndex;
  final Directory dataRoot;

  /// 会话开始时让常驻的自动保存先落盘（`EditingSessionRegistry.flushAll`）。
  final Future<void> Function() flushAll;

  /// 现在有没有阻塞同步的编辑页（响应方据此回 busy）。
  final bool Function() isEditing;
  final DateTime Function() clock;
  final String appVersion;
}

/// 对方（来自配对记录）与本机对它的记忆。
class LanSyncSessionPeer {
  const LanSyncSessionPeer({
    required this.deviceId,
    this.firstSync = false,
    this.restoredPending = false,
  });

  final String deviceId;

  /// 与它从没成功同步过（发起方据此让“以哪边为准”生效）。
  final bool firstSync;

  /// 本机覆盖恢复之后还没和它成功同步过（随 hello 告诉对方）。
  final bool restoredPending;
}
