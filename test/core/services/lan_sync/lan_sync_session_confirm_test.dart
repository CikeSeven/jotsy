import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/editing_session_registry.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_session.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_plan.dart';

import '../../../support/lan_sync_two_devices.dart';
import 'lan_sync_session_harness.dart';

/// 会话里需要用户确认的情况（内存信道）：以哪边为准的三种应答与自动同步
/// 中止、确认期间断线，以及删除保护的两种选择。
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
    await seedDiary(a.db, 'a1', title: 'A1');
    await seedDiary(b.db, 'b1', title: 'B1');
  });

  tearDown(() async {
    await a.dispose();
    await b.dispose();
  });

  void expectClosed(SessionRun run) {
    expect(run.initiatorChannel.isClosed, isTrue);
    expect(run.responderChannel.isClosed, isTrue);
  }

  Future<void> expectConverged() async {
    final retry = await runSession(a, b, clock);
    expect(retry.initiatorResult.failure, isNull);
    expect(await a.canonical(), await b.canonical());
  }

  group('确认', () {
    setUp(() async {
      // 两边各自有一篇同 id、内容不同的日记：首次同步时没有共同祖先。
      await seedDiary(a.db, 'same', title: 'mine', updated: 1700000500);
      await seedDiary(b.db, 'same', title: 'theirs', updated: 1700000400);
    });

    test('以本机为准：取发起方的版本，不生成副本', () async {
      final run = await runSession(
        a,
        b,
        clock,
        firstSync: true,
        answer: (request) => (request as LanSyncSideChoiceRequest).respond(
          SyncSideChoice.preferLocal,
        ),
      );
      expect(run.requests.single, isA<LanSyncSideChoiceRequest>());
      expect(run.initiatorResult.failure, isNull);
      expect(run.initiatorResult.conflictCopies, isEmpty);
      expect(await a.canonical(), await b.canonical());
      final row = await (b.db.select(
        b.db.diaries,
      )..where((t) => t.diaryId.equals('same'))).getSingle();
      expect(row.title, 'mine');
    });

    test('保留两份：生成一份冲突副本，两边都知道', () async {
      final run = await runSession(a, b, clock, firstSync: true);
      expect(run.initiatorResult.conflictCopies, hasLength(1));
      expect(run.responderResult.conflictCopies, hasLength(1));
      expect(
        run.initiatorResult.conflictCopies.single.title,
        endsWith('(copy · device-b)'),
      );
      expect(await a.canonical(), await b.canonical());
    });

    test('取消确认：发起方 cancelled、对方 declined，什么都不写', () async {
      final run = await runSession(
        a,
        b,
        clock,
        firstSync: true,
        answer: (request) =>
            (request as LanSyncSideChoiceRequest).respond(null),
      );
      expect(run.initiatorResult.failure, LanSyncFailure.cancelled);
      expect(run.responderResult.failure, LanSyncFailure.declined);
      expect(await diaryIds(b), {'b1', 'same'});
      expectClosed(run);
    });

    test('自动同步遇到需要确认：两边都中止为 needsConfirmation', () async {
      final run = await runSession(
        a,
        b,
        clock,
        firstSync: true,
        automatic: true,
      );
      expect(run.requests, isEmpty);
      expect(run.initiatorResult.failure, LanSyncFailure.needsConfirmation);
      expect(run.responderResult.failure, LanSyncFailure.needsConfirmation);
      expect(await diaryIds(b), {'b1', 'same'});
      expectClosed(run);
    });

    test('确认期间对方断开：请求作废，会话以断线结束', () async {
      SessionRun? current;
      final run = await runSession(
        a,
        b,
        clock,
        firstSync: true,
        setup: (run) => current = run,
        answer: (_) => current!.responderChannel.destroy(),
      );
      expect(run.initiatorResult.failure, LanSyncFailure.connectionLost);
      expect(run.requests.single.isPending, isFalse);
    });
  });

  group('删除保护', () {
    setUp(() async {
      for (var i = 0; i < 25; i++) {
        await seedDiary(a.db, 'bulk-$i', title: 'bulk $i');
      }
      await expectConverged();
      for (var i = 0; i < 25; i++) {
        await a.db.hardDeleteDiary('bulk-$i');
      }
    });

    test('保留并恢复：日记复制回删掉它们的一边', () async {
      final run = await runSession(
        a,
        b,
        clock,
        answer: (request) {
          final guard = request as LanSyncDeletionGuardRequest;
          expect(guard.count, 25);
          expect(guard.onLocalSide, isFalse);
          guard.respond(LanSyncDeletionDecision.keepAndRestore);
        },
      );
      expect(run.initiatorResult.failure, isNull);
      expect(run.initiatorResult.received.added, 25);
      expect((await diaryIds(a)).length, 27);
      expect(await a.canonical(), await b.canonical());
    });

    test('照常同步删除：对方也删掉', () async {
      final run = await runSession(a, b, clock);
      expect(run.requests.single, isA<LanSyncDeletionGuardRequest>());
      expect(run.initiatorResult.sent.deleted, 25);
      expect(await diaryIds(b), {'a1', 'b1'});
    });
  });
}
