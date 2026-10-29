import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/editing_session_registry.dart';

void main() {
  final registry = EditingSessionRegistry.instance;

  setUp(registry.debugReset);
  tearDown(registry.debugReset);

  group('blockers', () {
    test(
      'count leases immediately and notify listeners in a microtask',
      () async {
        final notified = <int>[];
        void listener() => notified.add(registry.activeEditors.value);
        registry.activeEditors.addListener(listener);
        addTearDown(() => registry.activeEditors.removeListener(listener));

        final first = registry.beginEditing('first');
        final second = registry.beginEditing('second');
        expect(registry.isEditing, isTrue);
        expect(registry.activeEditorCount, 2);
        expect(
          registry.activeEditorLabels,
          unorderedEquals(['first', 'second']),
        );
        // 通知推迟到微任务，且同一轮的两次登记合并为一次。
        expect(notified, isEmpty);
        await Future<void>.value();
        expect(notified, [2]);

        first.end();
        second.end();
        expect(registry.isEditing, isFalse);
        await Future<void>.value();
        expect(registry.activeEditors.value, 0);
        expect(notified, [2, 0]);
      },
    );

    test('ending a lease twice only releases it once', () async {
      final kept = registry.beginEditing('kept');
      final lease = registry.beginEditing('twice');
      lease.end();
      lease.end();
      expect(lease.isEnded, isTrue);
      expect(registry.activeEditorCount, 1);
      expect(registry.activeEditorLabels, ['kept']);
      kept.end();
      expect(registry.isEditing, isFalse);
    });

    test('leases from before debugReset no longer affect the counts', () {
      final stale = registry.beginEditing('stale');
      registry.debugReset();
      final fresh = registry.beginEditing('fresh');
      stale.end();
      expect(registry.activeEditorCount, 1);
      fresh.end();
      expect(registry.activeEditorCount, 0);
    });
  });

  group('flushers', () {
    test(
      'flushAll runs every flusher and swallows individual errors',
      () async {
        final ran = <String>[];
        final slow = Completer<void>();
        registry.registerFlusher(() async {
          ran.add('failing');
          throw StateError('disk unavailable');
        });
        registry.registerFlusher(() async {
          ran.add('slow');
          await slow.future;
        });
        var finished = false;
        final flushing = registry.flushAll().then((_) => finished = true);
        await Future<void>.value();
        expect(ran, ['failing', 'slow']);
        // 等最慢的冲刷者结束才返回。
        expect(finished, isFalse);
        slow.complete();
        await flushing;
        expect(finished, isTrue);
      },
    );

    test('an ended flusher is not called again, even if ended twice', () async {
      var calls = 0;
      final lease = registry.registerFlusher(() async => calls++);
      expect(registry.flusherCount, 1);
      await registry.flushAll();
      lease
        ..end()
        ..end();
      expect(registry.flusherCount, 0);
      await registry.flushAll();
      expect(calls, 1);
    });
  });

  group('undo windows', () {
    test('wait returns true at once when no window is open', () async {
      expect(
        await registry.waitForUndoWindows(timeout: const Duration(seconds: 1)),
        isTrue,
      );
    });

    test('wait resolves true once every window closes', () async {
      final first = registry.beginUndoWindow();
      final second = registry.beginUndoWindow();
      expect(registry.openUndoWindowCount, 2);
      bool? result;
      unawaited(
        registry
            .waitForUndoWindows(timeout: const Duration(seconds: 10))
            .then((value) => result = value),
      );
      first.end();
      await Future<void>.value();
      expect(result, isNull);
      second.end();
      second.end();
      await Future<void>.value();
      expect(result, isTrue);
      expect(registry.openUndoWindowCount, 0);
      expect(registry.openUndoWindows.value, 0);
    });

    test('wait resolves false when the timeout passes first', () async {
      final window = registry.beginUndoWindow();
      final result = await registry.waitForUndoWindows(
        timeout: const Duration(milliseconds: 20),
      );
      expect(result, isFalse);
      // 超时之后再关闭窗口不会二次完成，也不会抛错。
      window.end();
      expect(registry.openUndoWindowCount, 0);
    });
  });

  test('dataReplaced broadcasts every notification to all listeners', () async {
    var first = 0;
    var second = 0;
    final a = registry.dataReplaced.listen((_) => first++);
    final b = registry.dataReplaced.listen((_) => second++);
    addTearDown(a.cancel);
    addTearDown(b.cancel);
    registry
      ..notifyDataReplaced()
      ..notifyDataReplaced();
    await Future<void>.delayed(Duration.zero);
    expect(first, 2);
    expect(second, 2);
  });

  group('reorder guard', () {
    test('a drop in place releases the blocker immediately', () {
      final guard = ReorderEditingGuard('drag');
      guard.start(3);
      expect(registry.isEditing, isTrue);
      guard.dropped(4); // 从下方落回原位：插入位置为原位 + 1。
      expect(registry.isEditing, isFalse);
    });

    test('a moved drop keeps blocking until the write completes', () async {
      final guard = ReorderEditingGuard('drag');
      guard.start(0);
      guard.dropped(3);
      expect(registry.isEditing, isTrue);
      final write = Completer<void>();
      final holding = guard.holdUntil(write.future);
      // 写入期间再拿起一行另起一份登记，不被上一次写入的结束放掉。
      guard.start(1);
      expect(registry.activeEditorCount, 2);
      write.complete();
      await holding;
      expect(registry.activeEditorCount, 1);
      guard.dispose();
      expect(registry.isEditing, isFalse);
    });

    test('a failed write still releases the blocker', () async {
      final guard = ReorderEditingGuard('drag');
      guard.start(0);
      await expectLater(
        guard.holdUntil(Future<void>.error(StateError('locked'))),
        throwsStateError,
      );
      expect(registry.isEditing, isFalse);
    });
  });
}
