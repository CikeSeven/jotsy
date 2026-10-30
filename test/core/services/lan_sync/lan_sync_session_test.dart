import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/editing_session_registry.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_messages.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_session.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_session_protocol.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';

import '../../../support/lan_sync_two_devices.dart';
import 'lan_sync_fake_channel.dart';
import 'lan_sync_session_harness.dart';

/// 会话状态机（内存信道）：正常流程与每个失败点——两边状态一致、信道关闭、
/// 暂存区清掉，之后重试照常收敛。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late LanSyncTestClock clock;
  late LanSyncTestDevice a;
  late LanSyncTestDevice b;

  setUp(() async {
    EditingSessionRegistry.instance.debugReset();
    clock = LanSyncTestClock();
    a = await LanSyncTestDevice.create('device-a', clock: clock);
    b = await LanSyncTestDevice.create('device-b', clock: clock);
    final image = await a.writeMedia('diary_images/media_a/p.jpg', [1, 2, 3]);
    await seedDiary(a.db, 'a1', title: 'A1', content: docWithImage('a', image));
    await seedDiary(b.db, 'b1', title: 'B1');
  });

  tearDown(() async {
    await a.dispose();
    await b.dispose();
  });

  void expectClosed(SessionRun run) {
    expect(run.initiatorChannel.isClosed, isTrue);
    expect(run.responderChannel.isClosed, isTrue);
    expect(leftoverStaging(a), isEmpty);
    expect(leftoverStaging(b), isEmpty);
  }

  Future<void> expectConverged() async {
    final retry = await runSession(a, b, clock);
    expect(retry.initiatorResult.failure, isNull);
    expect(retry.responderResult.failure, isNull);
    expect(await a.canonical(), await b.canonical());
  }

  Future<void> expectNothingWritten() async {
    expect(await diaryIds(a), {'a1'});
    expect(await diaryIds(b), {'b1'});
  }

  test('正常流程：两边收敛，计数与媒体正确，信道关闭', () async {
    final run = await runSession(a, b, clock);
    expect(run.initiatorResult.failure, isNull);
    expect(run.responderResult.failure, isNull);
    expect(await a.canonical(), await b.canonical());
    expect(run.initiatorResult.received.added, 1);
    expect(run.initiatorResult.sent.added, 1);
    expect(run.responderResult.received.added, 1);
    expect(run.responderResult.sent.added, 1);
    expect(run.initiatorResult.transferredFiles, 1);
    expect(run.responderResult.received.mediaFiles, 1);
    expect(
      await File(b.mediaPath('diary_images/media_a/p.jpg')).readAsBytes(),
      [1, 2, 3],
    );
    expect(run.initiator.progress.value.stage, LanSyncStage.merging);
    expectClosed(run);

    // 再来一次什么都不写、不传。
    final again = await runSession(a, b, clock);
    expect(again.initiatorResult.received.isEmpty, isTrue);
    expect(again.initiatorResult.sent.isEmpty, isTrue);
    expect(again.initiatorChannel.blobsSent, 0);
    expect(again.responderChannel.blobsSent, 1, reason: '只有清单');
  });

  test('只有日记以外的变化时，计数按种类报告，两边口径一致', () async {
    await expectConverged();
    await a.db.addDiaryComment(diaryId: 'b1', content: '读后感');
    final run = await runSession(a, b, clock);
    expect(run.initiatorResult.failure, isNull);
    expect(run.initiatorResult.sent.diaries, 0);
    expect(run.initiatorResult.sent.others, {SyncEntity.comment: 1});
    expect(run.initiatorResult.sent.isEmpty, isFalse);
    expect(run.responderResult.received, run.initiatorResult.sent);
    expect(run.initiatorResult.received.isEmpty, isTrue);
  });

  test('响应方收到不兼容的 hello：回 version 拒绝并关闭', () async {
    final (ic, rc) = FakeLanSyncChannel.pair();
    final responder = LanSyncSession.responder(
      channel: rc,
      context: sessionContextOf(b, clock),
      peer: LanSyncSessionPeer(deviceId: a.deviceId),
      syncSettings: false,
      acceptAutomatic: true,
      timeouts: kTestSessionTimeouts,
    );
    final replies = <LanSyncMessage>[];
    ic.messages.listen(replies.add, onError: (_) {});
    ic.blobs.listen((_) {}, onError: (_) {});
    final running = responder.run();
    await ic.send(
      const LanSyncSessionHello(
        formatVersion: 999,
        appVersion: 'future',
        entities: {'diary'},
        syncSettings: false,
        restoredPending: false,
      ).toMessage(),
    );
    final result = await running;
    expect(result.failure, LanSyncFailure.incompatibleVersion);
    expect(result.started, isFalse);
    expect(replies.single.type, LanSyncSessionMessages.reject);
    expect(replies.single.fields['reason'], 'version');
    expect(rc.isClosed, isTrue);
  });

  test('发起方收到 version 拒绝：不兼容，什么都不写', () async {
    // 手写的响应方：收到 hello 就回 version 拒绝。
    final (ic, rc) = FakeLanSyncChannel.pair();
    rc.messages.listen((message) {
      if (message.type == LanSyncSessionMessages.hello) {
        unawaited(
          rc.send(
            LanSyncMessage(LanSyncSessionMessages.reject, {
              'reason': 'version',
            }),
          ),
        );
      }
    }, onError: (_) {});
    rc.blobs.listen((_) {}, onError: (_) {});
    final result = await LanSyncSession.initiator(
      channel: ic,
      context: sessionContextOf(a, clock),
      peer: LanSyncSessionPeer(deviceId: b.deviceId),
      automatic: false,
      syncSettings: false,
      localLoserTitleSuffix: '',
      remoteLoserTitleSuffix: '',
      onConfirmation: (_) {},
      timeouts: kTestSessionTimeouts,
    ).run();
    expect(result.failure, LanSyncFailure.incompatibleVersion);
    expect(ic.isClosed, isTrue);
  });

  test('响应方正在编辑：两边都是 busy，什么都不写', () async {
    final run = await runSession(a, b, clock, responderEditing: true);
    expect(run.initiatorResult.failure, LanSyncFailure.busy);
    expect(run.responderResult.failure, LanSyncFailure.busy);
    expect(run.responderResult.started, isFalse);
    await expectNothingWritten();
    expectClosed(run);
  });

  test('响应方关了自动同步：自动会话被 declined', () async {
    final run = await runSession(
      a,
      b,
      clock,
      automatic: true,
      acceptAutomatic: false,
    );
    expect(run.initiatorResult.failure, LanSyncFailure.declined);
    expect(run.responderResult.automatic, isTrue);
    await expectNothingWritten();
    expectClosed(run);
  });

  test('对方一直不回话：静默超时，信道关闭', () async {
    final (ic, rc) = FakeLanSyncChannel.pair();
    rc.messages.listen((_) {}, onError: (_) {});
    rc.blobs.listen((_) {}, onError: (_) {});
    final result = await LanSyncSession.initiator(
      channel: ic,
      context: sessionContextOf(a, clock),
      peer: LanSyncSessionPeer(deviceId: b.deviceId),
      automatic: false,
      syncSettings: false,
      localLoserTitleSuffix: '',
      remoteLoserTitleSuffix: '',
      onConfirmation: (_) {},
      timeouts: const LanSyncSessionTimeouts(
        silence: Duration(milliseconds: 150),
        keepAlive: Duration(milliseconds: 50),
      ),
    ).run();
    expect(result.failure, LanSyncFailure.timedOut);
    expect(ic.isClosed, isTrue);
  });

  for (final phase in [
    LanSyncSessionMessages.manifestGet,
    LanSyncSessionMessages.recordsGet,
    LanSyncSessionMessages.mediaHave,
    LanSyncSessionMessages.mediaPut,
    LanSyncSessionMessages.apply,
  ]) {
    test('发起方在 $phase 时取消：两边都不写，之后重试收敛', () async {
      final run = await runSession(
        a,
        b,
        clock,
        setup: (run) => run.initiatorChannel.onSend = (message) {
          if (message.type == phase) run.initiator.cancel();
        },
      );
      expect(run.initiatorResult.failure, LanSyncFailure.cancelled);
      expect(run.responderResult.failure, LanSyncFailure.peerCancelled);
      // `sync.apply` 已在发送途中时，对方可能在看到中止之前就开始写入
      // （写入事务不能中途打断）；之前的阶段一定什么都没写。
      if (phase != LanSyncSessionMessages.apply) await expectNothingWritten();
      expectClosed(run);
      await expectConverged();
    });
  }

  test('响应方在发清单时取消：发起方看到对方取消', () async {
    final run = await runSession(
      a,
      b,
      clock,
      setup: (run) => run.responderChannel.onSend = (message) {
        if (message.type == LanSyncSessionMessages.manifest) {
          run.responder.cancel();
        }
      },
    );
    expect(run.responderResult.failure, LanSyncFailure.cancelled);
    expect(run.initiatorResult.failure, LanSyncFailure.peerCancelled);
    await expectNothingWritten();
    expectClosed(run);
  });

  test('传媒体中途断线：两边都不写，暂存区清空，重试收敛', () async {
    final run = await runSession(
      a,
      b,
      clock,
      setup: (run) => run.initiatorChannel.killAfterBlobBytes = 1,
    );
    expect(run.initiatorResult.failure, LanSyncFailure.connectionLost);
    expect(run.responderResult.failure, LanSyncFailure.connectionLost);
    await expectNothingWritten();
    expectClosed(run);
    await expectConverged();
  });

  test('响应方写完、回执发出前断线：只有响应方写了，重试收敛', () async {
    final run = await runSession(
      a,
      b,
      clock,
      setup: (run) =>
          run.responderChannel.killBefore = (message) =>
              message.type == LanSyncSessionMessages.applied,
    );
    expect(run.initiatorResult.failure, LanSyncFailure.connectionLost);
    expect(run.responderResult.failure, LanSyncFailure.connectionLost);
    expect(await diaryIds(b), {'a1', 'b1'});
    expect(await diaryIds(a), {'a1'});
    expectClosed(run);
    await expectConverged();
  });
}
