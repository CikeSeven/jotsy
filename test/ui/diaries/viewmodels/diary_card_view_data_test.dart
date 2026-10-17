import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_card_view_data.dart';

Diary _diary({
  String id = 'd1',
  DateTime? updatedAt,
  String metadata = '{}',
  String contentText = 'body',
  String content = '[{"insert":"body\\n"}]',
  String? cover,
}) {
  final at = DateTime(2026, 10, 5, 9);
  return Diary(
    id: 1,
    diaryId: id,
    title: 'Title',
    content: content,
    contentText: contentText,
    metadata: metadata,
    cover: cover,
    createdAt: at,
    updatedAt: updatedAt ?? at,
    isArchived: false,
    isPinned: false,
    isDeleted: false,
  );
}

void main() {
  setUp(DiaryCardViewData.debugClearCache);

  test('parses context fields written by the publish composer', () {
    final data = DiaryCardViewData.of(
      _diary(
        metadata:
            '{"context":{"moodEmoji":"😊","weather":"晴","weatherIconCode":"100",'
            '"location":"杭州","energyLevel":"4"}}',
      ),
    );
    expect(data.moodEmoji, '😊');
    expect(data.weather, '晴');
    expect(data.weatherIconCode, '100');
    expect(data.location, '杭州');
    expect(data.energyLevel, 4);
  });

  test('reuses parsed data until the diary is updated', () {
    final first = DiaryCardViewData.of(_diary());
    expect(identical(DiaryCardViewData.of(_diary()), first), isTrue);

    final updated = DiaryCardViewData.of(
      _diary(updatedAt: DateTime(2026, 10, 6)),
    );
    expect(identical(updated, first), isFalse);
  });

  test('long bodies evict the least recently used text within the budget', () {
    final body = '字' * (DiaryCardViewData.cacheTextCodeUnitLimit ~/ 3);
    final a = _diary(id: 'a', contentText: body);
    final b = _diary(id: 'b', contentText: body);
    final c = _diary(id: 'c', contentText: body);
    final first = DiaryCardViewData.of(a);
    final second = DiaryCardViewData.of(b);
    // 访问 a 刷新 LRU 次序；第三篇使文本总量超过预算，应先释放 b。
    expect(identical(DiaryCardViewData.of(a), first), isTrue);
    DiaryCardViewData.of(c);
    expect(identical(DiaryCardViewData.of(a), first), isTrue);
    expect(identical(DiaryCardViewData.of(b), second), isFalse);
  });

  test(
    'an oversized entry renders without displacing ordinary cached entries',
    () {
      final ordinary = _diary();
      final cached = DiaryCardViewData.of(ordinary);
      final huge = _diary(
        id: 'huge',
        contentText: '字' * (DiaryCardViewData.cacheTextCodeUnitLimit + 1),
        cover: '/cover.jpg',
      );
      final view = DiaryCardViewData.of(huge);
      expect(view.previewText, '字' * DiaryCardViewData.previewTextMaxLength);
      expect(view.previewCover, '/cover.jpg');
      expect(identical(DiaryCardViewData.of(huge), view), isFalse);
      expect(identical(DiaryCardViewData.of(ordinary), cached), isTrue);
    },
  );

  test('truncates long bodies into a single-line preview', () {
    final data = DiaryCardViewData.of(
      _diary(contentText: '${'a' * 300}\nsecond line'),
    );
    expect(data.previewText.length, DiaryCardViewData.previewTextMaxLength);
    expect(data.previewText, isNot(contains('\n')));
  });

  test('falls back to the first image embedded in the body', () {
    final data = DiaryCardViewData.of(
      _diary(content: '[{"insert":"intro\\n"},{"insert":{"image":"/a.png"}}]'),
    );
    expect(data.previewCover, '/a.png');
    final explicit = DiaryCardViewData.of(
      _diary(id: 'd2', cover: ' /cover.png '),
    );
    expect(explicit.previewCover, '/cover.png');
  });

  test('tolerates corrupted metadata and content', () {
    final data = DiaryCardViewData.of(
      _diary(metadata: '{broken', content: 'not json'),
    );
    expect(data.moodEmoji, isNull);
    expect(data.energyLevel, isNull);
    expect(data.previewCover, isNull);
  });
}
