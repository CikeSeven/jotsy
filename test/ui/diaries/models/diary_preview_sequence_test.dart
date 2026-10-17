import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_sequence.dart';

DiaryWithTags _diary(String id) {
  final now = DateTime(2026, 10, 16);
  return DiaryWithTags(
    diary: Diary(
      id: id.hashCode,
      diaryId: id,
      title: id,
      content: '[]',
      contentText: '',
      metadata: '{}',
      createdAt: now,
      updatedAt: now,
      isArchived: false,
      isPinned: false,
      isDeleted: false,
    ),
    tags: const <Tag>[],
  );
}

const DiaryPreviewListQuery _query = DiaryPreviewListQuery(
  keyword: '',
  requiredTagIds: <int>[],
  sortMode: DiarySortMode.updatedDesc,
  excludedIds: <String>{'hidden'},
);

void main() {
  test('fromItems keeps list order, drops duplicates and seeds each page', () {
    final sequence = DiaryPreviewSequence.fromItems(<DiaryWithTags>[
      _diary('a'),
      _diary('b'),
      _diary('a'),
    ]);
    expect(sequence.ids, <String>['a', 'b']);
    expect(sequence.seeds.keys, <String>['a', 'b']);
    expect(() => sequence.ids.add('c'), throwsUnsupportedError);
  });

  test('only a list with another diary or more to load can page', () {
    expect(DiaryPreviewSequence(ids: <String>['a']).canPage, isFalse);
    expect(DiaryPreviewSequence(ids: <String>['a', 'b']).canPage, isTrue);
    expect(
      DiaryPreviewSequence(ids: <String>['a'], query: _query).canPage,
      isTrue,
    );
  });

  test('the rest of the list is appended after the loaded window', () {
    final sequence = DiaryPreviewSequence(
      ids: <String>['a', 'b'],
      query: _query,
    );
    expect(
      sequence.extendedWith(<String>['a', 'b', 'hidden', 'c', 'd']),
      <String>['a', 'b', 'c', 'd'],
    );
  });

  test('ids that moved above the window are not added twice', () {
    // 'c' 在预览页打开后被编辑、排到了前面：它已经翻不到了，不再追加。
    final sequence = DiaryPreviewSequence(
      ids: <String>['a', 'b'],
      query: _query,
    );
    expect(sequence.extendedWith(<String>['c', 'a', 'b', 'd']), <String>[
      'a',
      'b',
      'd',
    ]);
  });

  test('without the window anchor every new id is appended', () {
    // 快照末尾那篇已被删除，按“追加所有新 id”退回。
    final sequence = DiaryPreviewSequence(
      ids: <String>['a', 'gone'],
      query: _query,
    );
    expect(sequence.extendedWith(<String>['x', 'a', 'y']), <String>[
      'a',
      'gone',
      'y',
    ]);
    final noAnchor = DiaryPreviewSequence(ids: <String>['gone'], query: _query);
    expect(noAnchor.extendedWith(<String>['x', 'y']), <String>[
      'gone',
      'x',
      'y',
    ]);
  });
}
