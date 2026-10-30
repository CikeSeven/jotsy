// 同步引擎的一次性事件 → 界面事件的换算，以及确认应答的双向换算（纯函数，
// 无副作用；对照见 lan_sync_service.dart 顶部）。
//
// - 配对：界面的 `phase` 是引擎配对状态的“视图”（[LanSyncPairingPhaseView]），
//   不另存一份，读取时现算，引擎状态变化即通知界面；`respond` 直接转给引擎。
// - 确认：界面选项 ↔ 引擎选项。本机在确认里总是发起方，“以本机为准”即
//   引擎的 `preferLocal`、“以对方为准”即 `preferRemote`；删除保护的
//   `onLocalSide` ↔ 界面的 `LanSyncSide`。
// - 会话结束：只有本机发起的手动同步给完成摘要；对方发起的、自动同步的
//   不弹面板（自动同步另有提示，结果都在同步记录里）。
// - 界面的 `respond` 按接口约定不抛出：引擎的应答只完成 Completer，这里再
//   兜一层，异常只记日志。

import 'package:flutter/foundation.dart';

import '../../../core/services/lan_sync/lan_sync_crypto.dart' show LanSyncRole;
import '../../../core/services/lan_sync/lan_sync_service.dart';
import '../../../core/services/lan_sync/sync/sync_plan.dart';
import 'lan_sync_engine_mapping.dart';
import 'lan_sync_platform.dart';
import 'lan_sync_ui_events.dart';

/// 引擎配对状态 → 界面配对阶段。
///
/// 核对码缺失（不该出现）时按空串显示；成功缺 peerId 同理——界面成功态的
/// “立即同步”对空 id 不产生效果。失败缺原因按其他原因说明。
LanSyncPairingPhase lanSyncPairingPhaseOf(LanSyncPairingState state) {
  return switch (state.status) {
    LanSyncPairingStatus.connecting => const LanSyncPairingConnecting(),
    LanSyncPairingStatus.awaitingUser => LanSyncPairingAwaitingUser(
      state.code ?? '',
    ),
    LanSyncPairingStatus.awaitingPeer => LanSyncPairingAwaitingPeer(
      state.code ?? '',
    ),
    LanSyncPairingStatus.succeeded => LanSyncPairingSucceeded(
      state.peerId ?? '',
    ),
    LanSyncPairingStatus.failed => LanSyncPairingFailed(
      lanSyncFailureReasonOf(state.failure ?? LanSyncFailure.unknown),
    ),
  };
}

/// 引擎配对状态的界面视图：监听者直接挂在引擎的通知器上，[value] 每次现算。
/// 不持有资源，不需要释放；引擎的配对对象结束后不再变化，它也随之不再变化。
class LanSyncPairingPhaseView implements ValueListenable<LanSyncPairingPhase> {
  LanSyncPairingPhaseView(this._source);

  final ValueListenable<LanSyncPairingState> _source;

  @override
  LanSyncPairingPhase get value => lanSyncPairingPhaseOf(_source.value);

  @override
  void addListener(VoidCallback listener) => _source.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _source.removeListener(listener);
}

/// 界面“以哪边为准”的选择 → 引擎选择（null 为取消）。
SyncSideChoice? lanSyncEngineSideChoiceOf(LanSyncSideChoice? choice) {
  return switch (choice) {
    null => null,
    LanSyncSideChoice.keepBoth => SyncSideChoice.keepBoth,
    LanSyncSideChoice.preferLocal => SyncSideChoice.preferLocal,
    LanSyncSideChoice.preferPeer => SyncSideChoice.preferRemote,
  };
}

/// 引擎选择 → 界面选择（反方向，测试与日志用；本机总是发起方）。
LanSyncSideChoice lanSyncUiSideChoiceOf(SyncSideChoice choice) {
  return switch (choice) {
    SyncSideChoice.keepBoth => LanSyncSideChoice.keepBoth,
    SyncSideChoice.preferLocal => LanSyncSideChoice.preferLocal,
    SyncSideChoice.preferRemote => LanSyncSideChoice.preferPeer,
  };
}

/// 界面删除保护的选择 → 引擎选择（null 为取消）。
LanSyncDeletionDecision? lanSyncEngineDeletionDecisionOf(
  LanSyncDeletionChoice? choice,
) {
  return switch (choice) {
    null => null,
    LanSyncDeletionChoice.syncDeletion => LanSyncDeletionDecision.syncDeletion,
    LanSyncDeletionChoice.keepAndRestore =>
      LanSyncDeletionDecision.keepAndRestore,
  };
}

/// 引擎删除保护的选择 → 界面选择（反方向）。
LanSyncDeletionChoice lanSyncUiDeletionChoiceOf(
  LanSyncDeletionDecision decision,
) {
  return switch (decision) {
    LanSyncDeletionDecision.syncDeletion => LanSyncDeletionChoice.syncDeletion,
    LanSyncDeletionDecision.keepAndRestore =>
      LanSyncDeletionChoice.keepAndRestore,
  };
}

/// 一台已配对设备的显示名：备注名优先（与 `LanSyncPeerView.displayName`
/// 同一口径）；设备已不在列表里（刚取消配对）时为空串。
String lanSyncPeerDisplayName(LanSyncEngineState state, String peerId) {
  final device = state.peer(peerId)?.device;
  if (device == null) return '';
  final alias = device.alias?.trim();
  return alias == null || alias.isEmpty ? device.name : alias;
}

/// 引擎事件 → 界面事件；不需要界面反应的（对方发起或自动的会话结束）为
/// null。[state] 是事件发生时的引擎快照，用来取对方的显示名。
LanSyncUiEvent? lanSyncUiEventOf(
  LanSyncEngineEvent event,
  LanSyncEngineState state,
) {
  switch (event) {
    case LanSyncPairingStarted(:final pairing):
      return lanSyncPairingEventOf(pairing);
    case LanSyncConfirmationRequested(:final request):
      return lanSyncConfirmationEventOf(
        request,
        peerName: lanSyncPeerDisplayName(state, request.peerId),
      );
    case LanSyncSessionEnded(:final result):
      if (result.role != LanSyncRole.initiator || result.automatic) {
        return null;
      }
      return LanSyncSessionFinishedEvent(
        peerId: result.peerId,
        summary: lanSyncSummaryOf(
          result,
          peerName: lanSyncPeerDisplayName(state, result.peerId),
        ),
      );
    case LanSyncAutoSyncApplied(:final peerId, :final diaries):
      return LanSyncAutoSyncAppliedEvent(
        peerId: peerId,
        peerName: lanSyncPeerDisplayName(state, peerId),
        diaries: diaries,
      );
    case LanSyncAttentionNeeded(:final peerId):
      return LanSyncAutoSyncNeedsAttentionEvent(
        peerId: peerId,
        peerName: lanSyncPeerDisplayName(state, peerId),
      );
  }
}

/// 一次配对 → 界面配对事件。
LanSyncPairingEvent lanSyncPairingEventOf(LanSyncPairing pairing) {
  return LanSyncPairingEvent(
    direction: pairing.incoming
        ? LanSyncPairingDirection.incoming
        : LanSyncPairingDirection.outgoing,
    peerName: pairing.peerName,
    platform: LanSyncPlatform.fromName(pairing.platform),
    phase: LanSyncPairingPhaseView(pairing.state),
    respond: (bool accept) => _guard(() => pairing.respond(accept)),
  );
}

/// 确认请求 → 界面确认事件；界面的应答换算后交给请求。
LanSyncConfirmationEvent lanSyncConfirmationEventOf(
  LanSyncConfirmationRequest request, {
  required String peerName,
}) {
  return switch (request) {
    LanSyncSideChoiceRequest() => LanSyncChooseSideEvent(
      peerId: request.peerId,
      peerName: peerName,
      items: lanSyncItemCountsOf(request.counts),
      respond: (LanSyncSideChoice? choice) => _guard(
        () async => request.respond(lanSyncEngineSideChoiceOf(choice)),
      ),
    ),
    LanSyncDeletionGuardRequest() => LanSyncDeletionGuardEvent(
      peerId: request.peerId,
      peerName: peerName,
      deleteCount: request.count,
      onSide: request.onLocalSide ? LanSyncSide.local : LanSyncSide.peer,
      respond: (LanSyncDeletionChoice? choice) => _guard(
        () async => request.respond(lanSyncEngineDeletionDecisionOf(choice)),
      ),
    ),
  };
}

/// 界面回调按接口约定不抛出：引擎的异常只记日志。
Future<void> _guard(Future<void> Function() action) async {
  try {
    await action();
  } on Object catch (error, stack) {
    debugPrint('LAN sync respond failed: $error\n$stack');
  }
}
