import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_crypto.dart'
    show LanSyncRole;
import 'package:node_diary/core/services/lan_sync/lan_sync_service.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_plan.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/lan_sync/controllers/engine_lan_sync_ui_controller.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_engine_events.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_engine_mapping.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_item_counts.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_platform.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_session_view.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_ui_events.dart';
import 'package:node_diary/ui/lan_sync/providers/lan_sync_engine_assembly.dart';
import 'package:node_diary/ui/lan_sync/widgets/lan_sync_labels.dart';

/// 引擎 → 界面的纯换算：失败原因、阶段、同步记录、整页状态、配对阶段、
/// 确认应答（两个方向）、事件与冲突副本后缀。
void main() {
  LanSyncPairedDevice device({
    String id = 'peer-1',
    String name = 'ThinkPad',
    String? alias,
    bool needsAttention = false,
  }) => LanSyncPairedDevice(
    deviceId: id,
    name: name,
    platform: 'linux',
    publicKey: List<int>.filled(32, 7),
    pairedAt: DateTime.utc(2026, 9, 1, 8),
    lastSyncAt: DateTime.utc(2026, 10, 1, 9),
    alias: alias,
    autoSync: false,
    needsAttention: needsAttention,
  );

  LanSyncEngineState stateWith(LanSyncPeerState peer) => LanSyncEngineState(
    local: LanSyncLocalDevice(
      deviceId: 'me',
      name: 'Pixel',
      platform: 'android',
    ),
    peers: [peer],
  );

  group('失败原因', () {
    test('每个引擎失败原因都有界面原因，按对照表换算', () {
      const expected = <LanSyncFailure, LanSyncFailureReason>{
        LanSyncFailure.unreachable: LanSyncFailureReason.unreachable,
        LanSyncFailure.connectionLost: LanSyncFailureReason.connectionLost,
        LanSyncFailure.timedOut: LanSyncFailureReason.timedOut,
        LanSyncFailure.declined: LanSyncFailureReason.declined,
        LanSyncFailure.cancelled: LanSyncFailureReason.cancelled,
        LanSyncFailure.peerCancelled: LanSyncFailureReason.declined,
        LanSyncFailure.incompatibleVersion:
            LanSyncFailureReason.incompatibleVersion,
        LanSyncFailure.untrusted: LanSyncFailureReason.untrusted,
        LanSyncFailure.ticketExpired: LanSyncFailureReason.ticketExpired,
        LanSyncFailure.writeFailed: LanSyncFailureReason.writeFailed,
        LanSyncFailure.busy: LanSyncFailureReason.busy,
        LanSyncFailure.localEditing: LanSyncFailureReason.localEditing,
        LanSyncFailure.needsConfirmation:
            LanSyncFailureReason.needsConfirmation,
        LanSyncFailure.deferred: LanSyncFailureReason.deferred,
        LanSyncFailure.transferFailed: LanSyncFailureReason.connectionLost,
        LanSyncFailure.protocolError: LanSyncFailureReason.unknown,
        LanSyncFailure.unknown: LanSyncFailureReason.unknown,
      };
      expect(expected.keys.toSet(), LanSyncFailure.values.toSet());
      for (final entry in expected.entries) {
        expect(
          lanSyncFailureReasonOf(entry.key),
          entry.value,
          reason: '$entry',
        );
      }
    });

    test('新加的四种原因在两种语言里都有说明与短原因', () {
      for (final locale in const [Locale('zh'), Locale('en')]) {
        final l10n = lookupAppLocalizations(locale);
        final unknown = lanSyncSyncFailureText(
          l10n,
          LanSyncFailureReason.unknown,
        );
        for (final reason in const [
          LanSyncFailureReason.busy,
          LanSyncFailureReason.localEditing,
          LanSyncFailureReason.deferred,
          LanSyncFailureReason.needsConfirmation,
        ]) {
          expect(lanSyncSyncFailureText(l10n, reason), isNot(unknown));
          expect(lanSyncSyncReasonText(l10n, reason), isNotEmpty);
        }
        expect(
          lanSyncPairingFailureText(l10n, LanSyncFailureReason.busy),
          isNot(lanSyncPairingFailureText(l10n, LanSyncFailureReason.unknown)),
        );
      }
      final zh = lookupAppLocalizations(const Locale('zh'));
      expect(
        lanSyncSyncFailureText(zh, LanSyncFailureReason.busy),
        contains('对方正在编辑'),
      );
      expect(
        lanSyncSyncFailureText(zh, LanSyncFailureReason.localEditing),
        contains('请先关闭正在编辑的页面'),
      );
    });
  });

  test('会话阶段按顺序一一对应', () {
    expect([
      for (final stage in LanSyncStage.values) lanSyncSessionStageOf(stage),
    ], LanSyncSessionStage.values);
  });

  test('同步记录：字段同名搬过来，时间换成本地，失败原因换算', () {
    final record = LanSyncSessionRecord(
      peerId: 'peer-1',
      at: DateTime.utc(2026, 10, 1, 9),
      duration: const Duration(seconds: 3),
      automatic: true,
      receivedDiaries: 2,
      sentDiaries: 1,
      mediaBytes: 4096,
      conflictCopies: 1,
      firstSync: true,
    );
    final view = lanSyncHistoryEntryOf(record);
    expect(view.at, record.at.toLocal());
    expect(view.at.isUtc, isFalse);
    expect(view.duration, const Duration(seconds: 3));
    expect(view.automatic, isTrue);
    expect(view.receivedDiaries, 2);
    expect(view.sentDiaries, 1);
    expect(view.mediaBytes, 4096);
    expect(view.conflictCopies, 1);
    expect(view.firstSync, isTrue);
    expect(view.succeeded, isTrue);

    final failed = lanSyncHistoryEntryOf(
      LanSyncSessionRecord(
        peerId: 'peer-1',
        at: DateTime.utc(2026, 10, 1),
        failure: LanSyncFailure.busy,
      ),
    );
    expect(failed.failureReason, LanSyncFailureReason.busy);
  });

  test('整页状态：本机、已配对设备（进度、记录、需要确认）、附近设备与开关', () {
    final engine = LanSyncEngineState(
      local: LanSyncLocalDevice(
        deviceId: 'me',
        name: 'Pixel',
        platform: 'android',
        addresses: const ['192.168.1.5'],
        port: 24562,
        discoverable: false,
        discoveryListening: false,
      ),
      peers: [
        LanSyncPeerState(
          device: device(alias: '书房'),
          online: true,
          address: '192.168.1.8',
          session: const LanSyncProgress(
            stage: LanSyncStage.transferring,
            sentDiaries: 1,
            receivedDiaries: 2,
            filesDone: 1,
            filesTotal: 3,
            bytesDone: 10,
            bytesTotal: 30,
            bytesPerSecond: 5,
          ),
          awaitingConfirmation: true,
          history: [
            LanSyncSessionRecord(peerId: 'peer-1', at: DateTime.utc(2026)),
          ],
        ),
      ],
      nearby: const [
        LanSyncNearbyDevice(
          deviceId: 'n1',
          name: 'Laptop',
          platform: 'windows',
          address: '192.168.1.9',
        ),
      ],
      autoSync: false,
      syncSettings: true,
      searching: true,
    );
    final view = lanSyncViewStateOf(engine);
    expect(view.local.name, 'Pixel');
    expect(view.local.platform, LanSyncPlatform.android);
    expect(view.local.primaryAddress, '192.168.1.5');
    expect(view.local.port, 24562);
    expect(view.local.discoverable, isFalse);
    expect(view.local.discoveryListening, isFalse);
    final peer = view.peers.single;
    expect(peer.deviceId, 'peer-1');
    expect(peer.displayName, '书房');
    expect(peer.platform, LanSyncPlatform.linux);
    expect(peer.online, isTrue);
    expect(peer.address, '192.168.1.8');
    expect(peer.autoSync, isFalse);
    expect(peer.needsAttention, isTrue);
    expect(peer.pairedAt, DateTime.utc(2026, 9, 1, 8).toLocal());
    expect(peer.lastSyncAt, DateTime.utc(2026, 10, 1, 9).toLocal());
    expect(
      peer.session,
      const LanSyncSessionView(
        peerId: 'peer-1',
        stage: LanSyncSessionStage.transferring,
        sentDiaries: 1,
        receivedDiaries: 2,
        filesDone: 1,
        filesTotal: 3,
        bytesDone: 10,
        bytesTotal: 30,
        bytesPerSecond: 5,
      ),
    );
    expect(peer.history, hasLength(1));
    expect(view.nearby.single.platform, LanSyncPlatform.windows);
    expect(view.autoSyncEnabled, isFalse);
    expect(view.syncSettingsEnabled, isTrue);
    expect(view.searching, isTrue);
    // 自动同步留下的标记同样算“需要确认”。
    expect(
      lanSyncViewStateOf(
        stateWith(LanSyncPeerState(device: device(needsAttention: true))),
      ).needsAttention,
      isTrue,
    );
  });

  group('配对阶段', () {
    test('每个引擎配对状态都换成对应的界面阶段', () {
      expect(
        lanSyncPairingPhaseOf(
          const LanSyncPairingState(LanSyncPairingStatus.connecting),
        ),
        const LanSyncPairingConnecting(),
      );
      expect(
        lanSyncPairingPhaseOf(
          const LanSyncPairingState(
            LanSyncPairingStatus.awaitingUser,
            code: '123456',
          ),
        ),
        const LanSyncPairingAwaitingUser('123456'),
      );
      expect(
        lanSyncPairingPhaseOf(
          const LanSyncPairingState(
            LanSyncPairingStatus.awaitingPeer,
            code: '123456',
          ),
        ),
        const LanSyncPairingAwaitingPeer('123456'),
      );
      expect(
        lanSyncPairingPhaseOf(
          const LanSyncPairingState(
            LanSyncPairingStatus.succeeded,
            peerId: 'p',
          ),
        ),
        const LanSyncPairingSucceeded('p'),
      );
      expect(
        lanSyncPairingPhaseOf(
          const LanSyncPairingState(
            LanSyncPairingStatus.failed,
            failure: LanSyncFailure.peerCancelled,
          ),
        ),
        const LanSyncPairingFailed(LanSyncFailureReason.declined),
      );
    });

    test('阶段视图跟随引擎的配对状态并通知监听者', () {
      final source = ValueNotifier<LanSyncPairingState>(
        const LanSyncPairingState(LanSyncPairingStatus.connecting),
      );
      addTearDown(source.dispose);
      final phase = LanSyncPairingPhaseView(source);
      var notified = 0;
      void listener() => notified++;
      phase.addListener(listener);
      source.value = const LanSyncPairingState(
        LanSyncPairingStatus.awaitingUser,
        code: '654321',
      );
      expect(notified, 1);
      expect(phase.value, const LanSyncPairingAwaitingUser('654321'));
      phase.removeListener(listener);
      source.value = const LanSyncPairingState(
        LanSyncPairingStatus.succeeded,
        peerId: 'x',
      );
      expect(notified, 1);
      expect(phase.value, const LanSyncPairingSucceeded('x'));
    });
  });

  group('确认应答', () {
    test('以哪边为准：两个方向一一对应，取消为 null', () {
      for (final choice in LanSyncSideChoice.values) {
        final engine = lanSyncEngineSideChoiceOf(choice)!;
        expect(lanSyncUiSideChoiceOf(engine), choice);
      }
      expect(
        lanSyncEngineSideChoiceOf(LanSyncSideChoice.preferPeer),
        SyncSideChoice.preferRemote,
      );
      expect(lanSyncEngineSideChoiceOf(null), isNull);
    });

    test('删除保护：两个方向一一对应，取消为 null', () {
      for (final choice in LanSyncDeletionChoice.values) {
        final engine = lanSyncEngineDeletionDecisionOf(choice)!;
        expect(lanSyncUiDeletionChoiceOf(engine), choice);
      }
      expect(lanSyncEngineDeletionDecisionOf(null), isNull);
    });

    test('界面的 respond 换算后交给引擎的请求', () async {
      final side = LanSyncSideChoiceRequest(
        peerId: 'peer-1',
        counts: const <SyncEntity, int>{
          SyncEntity.diary: 3,
          SyncEntity.notebook: 1,
          SyncEntity.membership: 2,
        },
      );
      final event =
          lanSyncConfirmationEventOf(side, peerName: 'ThinkPad')
              as LanSyncChooseSideEvent;
      expect(
        event.items,
        LanSyncItemCounts(const <LanSyncItemKind, int>{
          LanSyncItemKind.diaries: 3,
          LanSyncItemKind.notebooks: 3,
        }),
      );
      expect(event.peerName, 'ThinkPad');
      await event.respond(LanSyncSideChoice.preferPeer);
      expect(await side.answer, SyncSideChoice.preferRemote);

      final cancelled = LanSyncSideChoiceRequest(
        peerId: 'p',
        counts: const <SyncEntity, int>{SyncEntity.diary: 1},
      );
      await (lanSyncConfirmationEventOf(cancelled, peerName: '')
              as LanSyncChooseSideEvent)
          .respond(null);
      expect(await cancelled.answer, isNull);

      final guard = LanSyncDeletionGuardRequest(
        peerId: 'peer-1',
        count: 4,
        onLocalSide: false,
      );
      final guardEvent =
          lanSyncConfirmationEventOf(guard, peerName: 'ThinkPad')
              as LanSyncDeletionGuardEvent;
      expect(guardEvent.deleteCount, 4);
      expect(guardEvent.onSide, LanSyncSide.peer);
      await guardEvent.respond(LanSyncDeletionChoice.keepAndRestore);
      expect(await guard.answer, LanSyncDeletionDecision.keepAndRestore);
    });
  });

  group('事件', () {
    LanSyncSessionResult result({
      LanSyncRole role = LanSyncRole.initiator,
      bool automatic = false,
      LanSyncFailure? failure,
    }) => LanSyncSessionResult(
      peerId: 'peer-1',
      role: role,
      automatic: automatic,
      startedAt: DateTime.utc(2026, 10, 1),
      duration: const Duration(seconds: 2),
      failure: failure,
      received: const LanSyncChangeTally(added: 1, mediaFiles: 2),
      sent: const LanSyncChangeTally(updated: 3, mediaBytes: 9),
      conflictCopies: const [LanSyncCopyInfo(diaryId: 'c', title: 'T')],
    );

    test('本机发起的手动同步给完成摘要（显示名备注优先）', () {
      final state = stateWith(LanSyncPeerState(device: device(alias: '书房')));
      final event =
          lanSyncUiEventOf(
                LanSyncSessionEnded(result(), firstSync: false),
                state,
              )
              as LanSyncSessionFinishedEvent;
      expect(event.peerId, 'peer-1');
      final summary = event.summary;
      expect(summary.peerName, '书房');
      expect(summary.duration, const Duration(seconds: 2));
      expect(summary.received.added, 1);
      expect(summary.received.mediaCount, 2);
      expect(summary.sent.updated, 3);
      expect(summary.sent.mediaBytes, 9);
      expect(summary.conflictCopies.single.title, 'T');
      expect(summary.succeeded, isTrue);

      final failed =
          lanSyncUiEventOf(
                LanSyncSessionEnded(
                  result(failure: LanSyncFailure.localEditing),
                  firstSync: false,
                ),
                state,
              )
              as LanSyncSessionFinishedEvent;
      expect(failed.summary.failureReason, LanSyncFailureReason.localEditing);
    });

    test('对方发起的、自动的会话结束不给完成摘要', () {
      final state = stateWith(LanSyncPeerState(device: device()));
      expect(
        lanSyncUiEventOf(
          LanSyncSessionEnded(
            result(role: LanSyncRole.responder),
            firstSync: false,
          ),
          state,
        ),
        isNull,
      );
      expect(
        lanSyncUiEventOf(
          LanSyncSessionEnded(result(automatic: true), firstSync: false),
          state,
        ),
        isNull,
      );
    });

    test('自动同步写入与需要确认换成提示事件', () {
      final state = stateWith(LanSyncPeerState(device: device()));
      final applied =
          lanSyncUiEventOf(
                const LanSyncAutoSyncApplied(peerId: 'peer-1', diaries: 5),
                state,
              )
              as LanSyncAutoSyncAppliedEvent;
      expect(applied.peerName, 'ThinkPad');
      expect(applied.diaries, 5);
      final attention =
          lanSyncUiEventOf(const LanSyncAttentionNeeded('peer-1'), state)
              as LanSyncAutoSyncNeedsAttentionEvent;
      expect(attention.peerId, 'peer-1');
      expect(attention.peerName, 'ThinkPad');
    });
  });

  test('冲突副本后缀按当前语言拼出，不支持的语言按英文', () {
    expect(
      lanSyncConflictTitleSuffix(const Locale('zh'), 'ThinkPad'),
      '（冲突副本 · ThinkPad）',
    );
    expect(
      lanSyncConflictTitleSuffix(const Locale('en'), 'ThinkPad'),
      ' (conflict copy · ThinkPad)',
    );
    expect(
      lanSyncConflictTitleSuffix(const Locale('fr'), 'X'),
      ' (conflict copy · X)',
    );
  });

  test('应用生命周期：resumed 为前台，paused / hidden / detached 为后台', () {
    expect(lanSyncForegroundOf(AppLifecycleState.resumed), isTrue);
    expect(lanSyncForegroundOf(AppLifecycleState.paused), isFalse);
    expect(lanSyncForegroundOf(AppLifecycleState.hidden), isFalse);
    expect(lanSyncForegroundOf(AppLifecycleState.detached), isFalse);
    expect(lanSyncForegroundOf(AppLifecycleState.inactive), isNull);
    expect(lanSyncForegroundOf(null), isNull);
  });
}
