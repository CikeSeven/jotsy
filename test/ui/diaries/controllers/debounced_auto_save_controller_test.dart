import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/editing_session_registry.dart';
import 'package:node_diary/ui/diaries/controllers/debounced_auto_save_controller.dart';
import 'package:node_diary/ui/diaries/models/edit_diary_snapshot.dart';

EditDiarySnapshot snapshot(String title) => EditDiarySnapshot(
  title: title,
  contentDocJson: '[{"insert":"body\\n"}]',
  contentText: 'body',
  cover: null,
  metadataJson: '{}',
  selectedTagIds: {},
  createdAt: null,
);

void main() {
  final registry = EditingSessionRegistry.instance;
  setUp(registry.debugReset);
  tearDown(registry.debugReset);

  test('blocks sync from construction until dispose', () {
    final controller = DebouncedAutoSaveController<EditDiarySnapshot>(
      debounce: const Duration(milliseconds: 500),
      readSnapshot: () => snapshot('a'),
      writeSnapshot: (_) async {},
      onError: (error) => fail('$error'),
      editingLabel: 'edit-page',
    );
    expect(registry.activeEditorLabels, ['edit-page']);
    controller.dispose();
    expect(registry.isEditing, isFalse);
    // 重复 dispose（close 之后页面再 dispose）不会出错，也不影响计数。
    controller.dispose();
    expect(registry.activeEditorCount, 0);
  });

  test('keeps blocking sync until a save in flight finishes', () async {
    final write = Completer<void>();
    var current = snapshot('original');
    final controller = DebouncedAutoSaveController<EditDiarySnapshot>(
      debounce: const Duration(milliseconds: 500),
      readSnapshot: () => current,
      writeSnapshot: (_) => write.future,
      onError: (error) => fail('$error'),
    );
    controller.initialize(current);
    current = snapshot('edit');
    final saving = controller.flush();
    controller.dispose();
    expect(registry.isEditing, isTrue);
    write.complete();
    await saving;
    await Future<void>.value();
    expect(registry.isEditing, isFalse);
  });

  test(
    'flush serializes writes and includes edits made during a save',
    () async {
      final firstWrite = Completer<void>();
      var current = snapshot('original');
      final written = <String>[];
      final controller = DebouncedAutoSaveController<EditDiarySnapshot>(
        debounce: const Duration(milliseconds: 500),
        readSnapshot: () => current,
        writeSnapshot: (value) async {
          written.add(value.title);
          if (written.length == 1) await firstWrite.future;
        },
        onError: (error) => fail('$error'),
      );
      addTearDown(controller.dispose);
      controller.initialize(current);
      current = snapshot('first edit');
      final saving = controller.flush();
      expect(written, ['first edit']);

      // 改回最初的内容仍要排在已开始的写入后保存，不能只和初始值比较。
      current = snapshot('original');
      expect(identical(controller.flush(), saving), isTrue);
      expect(written, ['first edit']);
      firstWrite.complete();
      expect(await saving, isTrue);
      expect(written, ['first edit', 'original']);
    },
  );

  test('failed writes remain pending and can be retried', () async {
    var current = snapshot('original');
    var shouldFail = true;
    final errors = <Object>[];
    final written = <String>[];
    final controller = DebouncedAutoSaveController<EditDiarySnapshot>(
      debounce: const Duration(milliseconds: 500),
      readSnapshot: () => current,
      writeSnapshot: (value) async {
        if (shouldFail) throw StateError('disk unavailable');
        written.add(value.title);
      },
      onError: errors.add,
    );
    addTearDown(controller.dispose);
    controller.initialize(current);
    current = snapshot('latest edit');
    expect(await controller.flush(), isFalse);
    expect(errors, hasLength(1));

    shouldFail = false;
    expect(await controller.flush(), isTrue);
    expect(written, ['latest edit']);
    expect(await controller.flush(), isTrue);
    expect(written, hasLength(1));
  });

  test('unchanged snapshots do not write to the database', () async {
    final current = snapshot('original');
    var writes = 0;
    final controller = DebouncedAutoSaveController<EditDiarySnapshot>(
      debounce: const Duration(milliseconds: 500),
      readSnapshot: () => current,
      writeSnapshot: (_) async => writes++,
      onError: (error) => fail('$error'),
    );
    addTearDown(controller.dispose);
    controller.initialize(current);
    expect(await controller.flush(), isTrue);
    expect(writes, 0);
  });

  test('dispose during a write prevents reading the disposed editor', () async {
    var current = snapshot('original');
    var reads = 0;
    final write = Completer<void>();
    final controller = DebouncedAutoSaveController<EditDiarySnapshot>(
      debounce: const Duration(milliseconds: 500),
      readSnapshot: () {
        reads++;
        return current;
      },
      writeSnapshot: (_) => write.future,
      onError: (error) => fail('$error'),
    );
    controller.initialize(current);
    current = snapshot('edit');
    final saving = controller.flush();
    controller.dispose();
    write.complete();
    expect(await saving, isFalse);
    expect(reads, 1);
  });
  test('close waits for the write in flight and stops later saves', () async {
    var current = snapshot('original');
    final write = Completer<void>();
    final written = <String>[];
    final controller = DebouncedAutoSaveController<EditDiarySnapshot>(
      debounce: const Duration(milliseconds: 500),
      readSnapshot: () => current,
      writeSnapshot: (value) async {
        written.add(value.title);
        await write.future;
      },
      onError: (error) => fail('$error'),
    );
    controller.initialize(current);
    current = snapshot('edit');
    unawaited(controller.flush());

    var closed = false;
    final closing = controller.close().then((_) => closed = true);
    await Future<void>.delayed(Duration.zero);
    // 写入未完成时 close 不能先返回：调用方接着要删草稿，晚到的写入会把它写回。
    expect(closed, isFalse);
    write.complete();
    await closing;
    expect(closed, isTrue);

    current = snapshot('after close');
    controller.schedule();
    expect(await controller.flush(), isFalse);
    expect(written, ['edit']);
  });

  group('manual mode', () {
    const settleDelay = Duration(milliseconds: 300);

    test('edits only mark unsaved changes and flush writes them', () async {
      var current = snapshot('original');
      final written = <String>[];
      final controller = DebouncedAutoSaveController<EditDiarySnapshot>(
        debounce: const Duration(milliseconds: 10),
        readSnapshot: () => current,
        writeSnapshot: (value) async => written.add(value.title),
        onError: (error) => fail('$error'),
        manual: () => true,
      );
      addTearDown(controller.dispose);
      controller.initialize(current);
      expect(controller.hasUnsavedChanges, isFalse);

      current = snapshot('edit');
      controller.schedule();
      controller.schedule();
      await Future<void>.delayed(settleDelay);
      // 防抖早已过去也不写：只更新“有未保存的修改”。
      expect(written, isEmpty);
      expect(controller.unsaved.value, isTrue);
      expect(controller.hasUnsavedChanges, isTrue);
      // settle 只等进行中的写入，不发起新的写入。
      expect(await controller.settle(), isTrue);
      expect(written, isEmpty);

      expect(await controller.flush(), isTrue);
      expect(written, ['edit']);
      expect(controller.unsaved.value, isFalse);
      expect(controller.hasUnsavedChanges, isFalse);
    });

    test('changing back to the saved content clears the mark', () async {
      var current = snapshot('original');
      final controller = DebouncedAutoSaveController<EditDiarySnapshot>(
        debounce: const Duration(milliseconds: 10),
        readSnapshot: () => current,
        writeSnapshot: (_) async => fail('manual mode must not write'),
        onError: (error) => fail('$error'),
        manual: () => true,
      );
      addTearDown(controller.dispose);
      controller.initialize(current);
      current = snapshot('edit');
      controller.schedule();
      await Future<void>.delayed(settleDelay);
      expect(controller.unsaved.value, isTrue);

      current = snapshot('original');
      controller.schedule();
      await Future<void>.delayed(settleDelay);
      expect(controller.unsaved.value, isFalse);
    });

    test('settle waits for a save in flight', () async {
      var current = snapshot('original');
      final write = Completer<void>();
      final controller = DebouncedAutoSaveController<EditDiarySnapshot>(
        debounce: const Duration(milliseconds: 10),
        readSnapshot: () => current,
        writeSnapshot: (_) => write.future,
        onError: (error) => fail('$error'),
        manual: () => true,
      );
      addTearDown(controller.dispose);
      controller.initialize(current);
      current = snapshot('edit');
      final saving = controller.flush();
      var settled = false;
      final settling = controller.settle().then((ok) => settled = ok);
      await Future<void>.delayed(Duration.zero);
      expect(settled, isFalse);
      write.complete();
      await settling;
      expect(settled, isTrue);
      expect(await saving, isTrue);
    });

    test('switching back to automatic saving writes on schedule', () async {
      var manual = true;
      var current = snapshot('original');
      final written = <String>[];
      final controller = DebouncedAutoSaveController<EditDiarySnapshot>(
        debounce: const Duration(milliseconds: 10),
        readSnapshot: () => current,
        writeSnapshot: (value) async => written.add(value.title),
        onError: (error) => fail('$error'),
        manual: () => manual,
      );
      addTearDown(controller.dispose);
      controller.initialize(current);
      current = snapshot('edit');
      controller.schedule();
      await Future<void>.delayed(settleDelay);
      expect(written, isEmpty);

      manual = false;
      controller.schedule();
      await Future<void>.delayed(settleDelay);
      expect(written, ['edit']);
    });
  });
}
