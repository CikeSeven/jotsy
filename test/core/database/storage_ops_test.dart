import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  Future<Diary> diaryRow(String diaryId) => (database.select(
    database.diaries,
  )..where((t) => t.diaryId.equals(diaryId))).getSingle();

  test('reads every source with private, locked and capsule flags', () async {
    final hidden = await database.createNotebook(
      name: '隐藏',
      visibility: NotebookVisibility.hidden,
    );
    final locked = await database.createNotebook(
      name: '上锁',
      visibility: NotebookVisibility.locked,
    );
    final child = await database.createNotebook(name: '子本', parentId: locked);
    final plain = await database.createDiary(
      title: '普通',
      contentDocJson: '',
      contentText: '',
      metadataJson: '{}',
    );
    final inHidden = await database.createDiary(
      title: '隐藏里',
      contentDocJson: '',
      contentText: '',
      metadataJson: '{}',
      notebookIds: [hidden],
    );
    final inLockedChild = await database.createDiary(
      title: '上锁子本里',
      contentDocJson: '',
      contentText: '',
      metadataJson: '{}',
      notebookIds: [child],
    );
    await database.addDiaryComment(
      diaryId: plain,
      content: '',
      images: ['/x/diary_images/m/a.jpg'],
    );
    await database.addDiaryComment(diaryId: plain, content: '没有图');

    final sources = await database.getStorageReferenceSources();
    StorageDiarySource diary(String id) =>
        sources.diaries.singleWhere((d) => d.diaryId == id);

    expect(diary(plain).isPrivate, isFalse);
    expect(diary(inHidden).isPrivate, isTrue);
    expect(diary(inHidden).isLocked, isFalse);
    expect(diary(inLockedChild).isPrivate, isTrue);
    expect(diary(inLockedChild).isLocked, isTrue);
    expect(sources.comments, hasLength(1));
    final lockedChild = sources.notebooks.singleWhere(
      (n) => n.notebookId == child,
    );
    expect(lockedChild.isLocked, isTrue);
  });

  test('applies edits only to rows that still match', () async {
    final id = await database.createDiary(
      title: '',
      contentDocJson: 'old',
      contentText: 'old',
      metadataJson: '{}',
      cover: '/x/diary_covers/c.jpg',
    );
    final changed = await database.createDiary(
      title: '',
      contentDocJson: 'old',
      contentText: 'old',
      metadataJson: '{}',
    );
    final before = await diaryRow(id);
    final local = before.id;
    final changedLocal = (await diaryRow(changed)).id;
    await database.updateDiaryContent(
      diaryId: changed,
      contentDocJson: 'edited elsewhere',
      contentText: 'edited elsewhere',
    );

    final result = await database.applyStorageMediaEdits(
      StorageMediaEdits(
        diaries: [
          StorageDiaryEdit(
            id: local,
            expectedContent: 'old',
            expectedCover: '/x/diary_covers/c.jpg',
            content: 'new',
            contentText: 'new text',
            cover: null,
          ),
          StorageDiaryEdit(
            id: changedLocal,
            expectedContent: 'old',
            expectedCover: null,
            content: 'new',
            cover: null,
          ),
        ],
      ),
    );

    expect(result.applied, 1);
    expect(result.skipped, 1);
    final after = await diaryRow(id);
    expect(after.content, 'new');
    expect(after.contentText, 'new text');
    expect(after.cover, isNull);
    expect(after.updatedAt, before.updatedAt.add(const Duration(seconds: 1)));
    expect((await diaryRow(changed)).content, 'edited elsewhere');
  });

  test('deletes a comment left without text or images', () async {
    final diary = await database.createDiary(
      title: '',
      contentDocJson: '',
      contentText: '',
      metadataJson: '{}',
    );
    final onlyImage = await database.addDiaryComment(
      diaryId: diary,
      content: '',
      images: ['/x/diary_images/m/a.jpg'],
    );
    final withText = await database.addDiaryComment(
      diaryId: diary,
      content: '好看',
      images: ['/x/diary_images/m/a.jpg'],
    );
    final rows = await database.select(database.diaryComments).get();
    int local(String commentId) =>
        rows.singleWhere((row) => row.commentId == commentId).id;
    String images(String commentId) =>
        rows.singleWhere((row) => row.commentId == commentId).images!;

    final result = await database.applyStorageMediaEdits(
      StorageMediaEdits(
        comments: [
          for (final id in [onlyImage, withText])
            StorageCommentEdit(
              id: local(id),
              expectedImages: images(id),
              images: null,
            ),
        ],
      ),
    );

    expect(result.applied, 2);
    final remaining = await database.select(database.diaryComments).get();
    expect(remaining.map((row) => row.commentId), [withText]);
    expect(remaining.single.images, isNull);
    expect(remaining.single.editedAt, isNotNull);
  });

  test('rewrites notebook payloads and drafts with preconditions', () async {
    final notebookId = await database.createNotebook(name: '旅行');
    final payload = jsonEncode({'cover': '/x/diary_covers/c.jpg'});
    await (database.update(database.notebooks)
          ..where((t) => t.notebookId.equals(notebookId)))
        .write(NotebooksCompanion(payload: Value(payload)));
    final notebook = await (database.select(
      database.notebooks,
    )..where((t) => t.notebookId.equals(notebookId))).getSingle();
    await database.saveDiaryDraft(
      title: '草稿',
      contentText: '',
      payload: '{"cover":"/x/diary_covers/c.jpg"}',
    );
    final draft = await database.select(database.diaryDrafts).getSingle();

    final result = await database.applyStorageMediaEdits(
      StorageMediaEdits(
        notebooks: [
          StorageNotebookEdit(
            id: notebook.id,
            expectedPayload: payload,
            payload: '{}',
          ),
        ],
        drafts: [
          StorageDraftEdit(
            id: draft.id,
            expectedPayload: 'stale',
            payload: '{}',
          ),
        ],
      ),
    );

    expect(result.applied, 1);
    expect(result.skipped, 1);
    final after = await (database.select(
      database.notebooks,
    )..where((t) => t.notebookId.equals(notebookId))).getSingle();
    expect(after.payload, '{}');
    expect(
      (await database.select(database.diaryDrafts).getSingle()).payload,
      draft.payload,
    );
  });

  test('reports free pages and compacts the database', () async {
    final stats = await database.getStorageDatabaseStats();
    expect(stats.pageSize, greaterThan(0));
    await database.compactDatabase();
  });
}
