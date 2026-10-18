import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
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
}
