// 同步引擎的状态快照 → 界面视图状态的换算（纯函数，无副作用）。
//
// 对照表在 lan_sync_service.dart 顶部（docs/lan_sync.md §9）：字段同名的
// 直接搬，平台字符串经 `LanSyncPlatform.fromName`，会话阶段按下标对应，失败
// 原因经 [lanSyncFailureReasonOf]。事件与确认应答的换算见
// lan_sync_engine_events.dart。
//
// 时间一律换成本地时间：引擎的配对与同步记录存 UTC（store.json 的毫秒），
// 界面的日期格式化按本地时区显示，相对时间（“N 分钟前”）不受影响。

import '../../../core/services/lan_sync/lan_sync_service.dart';
import '../../../core/services/lan_sync/sync/sync_model.dart';
import 'lan_sync_item_counts.dart';
import 'lan_sync_platform.dart';
import 'lan_sync_qr_ticket.dart';
import 'lan_sync_session_summary.dart';
import 'lan_sync_session_view.dart';
import 'lan_sync_view_state.dart';

/// 引擎失败原因 → 界面失败原因。
///
/// 同名的直接对应；“对方取消”在界面上按“对方拒绝”说明（界面不区分对方是
/// 拒绝还是中途取消，下一步都是去对方那里看看）；媒体传输失败按连接中断
/// 说明（已写入的部分下次补齐，说法相同）；协议错误归入其他原因。
LanSyncFailureReason lanSyncFailureReasonOf(LanSyncFailure failure) {
  return switch (failure) {
    LanSyncFailure.unreachable => LanSyncFailureReason.unreachable,
    LanSyncFailure.connectionLost ||
    LanSyncFailure.transferFailed => LanSyncFailureReason.connectionLost,
    LanSyncFailure.timedOut => LanSyncFailureReason.timedOut,
    LanSyncFailure.declined ||
    LanSyncFailure.peerCancelled => LanSyncFailureReason.declined,
    LanSyncFailure.cancelled => LanSyncFailureReason.cancelled,
    LanSyncFailure.incompatibleVersion =>
      LanSyncFailureReason.incompatibleVersion,
    LanSyncFailure.untrusted => LanSyncFailureReason.untrusted,
    LanSyncFailure.ticketExpired => LanSyncFailureReason.ticketExpired,
    LanSyncFailure.writeFailed => LanSyncFailureReason.writeFailed,
    LanSyncFailure.busy => LanSyncFailureReason.busy,
    LanSyncFailure.localEditing => LanSyncFailureReason.localEditing,
    LanSyncFailure.deferred => LanSyncFailureReason.deferred,
    LanSyncFailure.needsConfirmation => LanSyncFailureReason.needsConfirmation,
    LanSyncFailure.protocolError ||
    LanSyncFailure.unknown => LanSyncFailureReason.unknown,
  };
}

/// 引擎会话阶段 → 界面会话阶段（两边按同样的顺序声明，按下标对应）。
LanSyncSessionStage lanSyncSessionStageOf(LanSyncStage stage) {
  return switch (stage) {
    LanSyncStage.connecting => LanSyncSessionStage.connecting,
    LanSyncStage.comparing => LanSyncSessionStage.comparing,
    LanSyncStage.transferring => LanSyncSessionStage.transferring,
    LanSyncStage.merging => LanSyncSessionStage.merging,
  };
}

/// 正在进行的会话进度。
LanSyncSessionView lanSyncSessionViewOf(
  String peerId,
  LanSyncProgress progress,
) {
  return LanSyncSessionView(
    peerId: peerId,
    stage: lanSyncSessionStageOf(progress.stage),
    sentDiaries: progress.sentDiaries,
    receivedDiaries: progress.receivedDiaries,
    filesDone: progress.filesDone,
    filesTotal: progress.filesTotal,
    bytesDone: progress.bytesDone,
    bytesTotal: progress.bytesTotal,
    bytesPerSecond: progress.bytesPerSecond,
  );
}

/// 一条同步记录。
LanSyncHistoryEntryView lanSyncHistoryEntryOf(LanSyncSessionRecord record) {
  final failure = record.failure;
  return LanSyncHistoryEntryView(
    at: record.at.toLocal(),
    duration: record.duration,
    automatic: record.automatic,
    receivedDiaries: record.receivedDiaries,
    sentDiaries: record.sentDiaries,
    otherChanges: record.receivedOthers + record.sentOthers,
    mediaBytes: record.mediaBytes,
    conflictCopies: record.conflictCopies,
    firstSync: record.firstSync,
    failureReason: failure == null ? null : lanSyncFailureReasonOf(failure),
  );
}

/// 一台已配对设备。
LanSyncPeerView lanSyncPeerViewOf(LanSyncPeerState peer) {
  final device = peer.device;
  final session = peer.session;
  return LanSyncPeerView(
    deviceId: device.deviceId,
    name: device.name,
    alias: device.alias,
    platform: LanSyncPlatform.fromName(device.platform),
    pairedAt: device.pairedAt.toLocal(),
    online: peer.online,
    address: peer.address,
    lastSyncAt: device.lastSyncAt?.toLocal(),
    autoSync: device.autoSync,
    needsAttention: peer.needsAttention,
    session: session == null
        ? null
        : lanSyncSessionViewOf(device.deviceId, session),
    history: [for (final record in peer.history) lanSyncHistoryEntryOf(record)],
  );
}

/// 整体状态快照 → 整页视图状态。
LanSyncViewState lanSyncViewStateOf(LanSyncEngineState state) {
  final local = state.local;
  return LanSyncViewState(
    local: LanSyncLocalDeviceView(
      name: local.name,
      platform: LanSyncPlatform.fromName(local.platform),
      addresses: local.addresses,
      port: local.port,
      discoverable: local.discoverable,
      discoveryListening: local.discoveryListening,
    ),
    peers: [for (final peer in state.peers) lanSyncPeerViewOf(peer)],
    nearby: [
      for (final device in state.nearby)
        LanSyncNearbyView(
          deviceId: device.deviceId,
          name: device.name,
          platform: LanSyncPlatform.fromName(device.platform),
          address: device.address,
        ),
    ],
    autoSyncEnabled: state.autoSync,
    syncSettingsEnabled: state.syncSettings,
    searching: state.searching,
  );
}

/// 引擎的实体 → 界面的数据种类（引擎已按 `syncSummaryEntityOf` 把收录、
/// 顺序列表归到日记本 / 模板；这里再兜一次底）。
LanSyncItemKind lanSyncItemKindOf(SyncEntity entity) {
  return switch (entity) {
    SyncEntity.diary => LanSyncItemKind.diaries,
    SyncEntity.tag => LanSyncItemKind.tags,
    SyncEntity.notebook ||
    SyncEntity.membership ||
    SyncEntity.orderList => LanSyncItemKind.notebooks,
    SyncEntity.comment => LanSyncItemKind.comments,
    SyncEntity.template => LanSyncItemKind.templates,
    SyncEntity.anniversary => LanSyncItemKind.anniversaries,
    SyncEntity.dayMood => LanSyncItemKind.dayMoods,
    SyncEntity.settings => LanSyncItemKind.settings,
  };
}

/// 按实体的计数 → 按数据种类的计数（同一种类的相加）。
LanSyncItemCounts lanSyncItemCountsOf(Map<SyncEntity, int> counts) {
  final byKind = <LanSyncItemKind, int>{};
  for (final entry in counts.entries) {
    final kind = lanSyncItemKindOf(entry.key);
    byKind[kind] = (byKind[kind] ?? 0) + entry.value;
  }
  return LanSyncItemCounts(byKind);
}

/// 一个方向的变化计数（完成摘要的“收到 / 发出”）。
LanSyncChangeCounts lanSyncChangeCountsOf(LanSyncChangeTally tally) {
  return LanSyncChangeCounts(
    added: tally.added,
    updated: tally.updated,
    deleted: tally.deleted,
    others: lanSyncItemCountsOf(tally.others).withoutDiaries,
    mediaCount: tally.mediaFiles,
    mediaBytes: tally.mediaBytes,
  );
}

/// 一次会话结果 → 完成摘要；[peerName] 是对方的显示名（备注名优先）。
LanSyncSessionSummary lanSyncSummaryOf(
  LanSyncSessionResult result, {
  required String peerName,
}) {
  final failure = result.failure;
  return LanSyncSessionSummary(
    peerName: peerName,
    duration: result.duration,
    received: lanSyncChangeCountsOf(result.received),
    sent: lanSyncChangeCountsOf(result.sent),
    conflictCopies: [
      for (final copy in result.conflictCopies)
        LanSyncConflictCopy(diaryId: copy.diaryId, title: copy.title),
    ],
    failureReason: failure == null ? null : lanSyncFailureReasonOf(failure),
  );
}

/// 引擎签发的二维码 → 界面的二维码。
LanSyncQrTicket lanSyncQrTicketOf(LanSyncIssuedQr issued) {
  return LanSyncQrTicket(
    payload: issued.payload,
    issuedAt: issued.issuedAt,
    expiresAt: issued.expiresAt,
  );
}
