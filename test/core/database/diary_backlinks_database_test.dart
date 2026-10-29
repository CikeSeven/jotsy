import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_codec.dart';
import 'package:node_diary/core/database/diary_blocks/diary_link_target.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// 正文为一段带链接的文字，或一张卡片。
  String linking(DiaryLinkTarget target, {bool card = false}) =>
      encodeDiaryBlocks({
        'document': {
          'type': 'page',
          'children': [
            if (card)
              {'type': 'link_card', 'data': diaryLinkCardData(target, '标题')}
            else
              {
                'type': 'paragraph',
                'data': {
                  'delta': [
                    {'insert': '想起 '},
                    {
                      'insert': '那天',
                      'attributes': {'href': target.toHref()},
                    },
                  ],
                },
              },
          ],
        },
      });

  Future<String> diary(
    String title, {
    String content = '',
    DateTime? createdAt,
    DateTime? unlockAt,
    List<String>? notebookIds,
  }) => db.createDiary(
    title: title,
    contentDocJson: content.isEmpty
        ? encodeDiaryBlocks(diaryBlocksFromPlainText(title))
        : content,
    contentText: title,
    metadataJson: '{}',
    createdAtOverride: createdAt,
    capsuleUnlockAt: unlockAt,
    capsuleLockedAt: unlockAt == null
        ? null
        : DateTime.now().subtract(const Duration(days: 1)),
    notebookIds: notebookIds,
  );

  Future<List<String>> titles(DiaryLinkTarget target) async => [
    for (final link in await db.watchDiaryBacklinks(target).first) link.title,
  ];

  test('lists diaries linking inline or by card, newest first', () async {
    final target = await diary('目标');
    final targetLink = DiaryLinkTarget.diary(target);
    await diary(
      '行内',
      content: linking(targetLink),
      createdAt: DateTime(2026, 1, 1),
    );
    await diary(
      '卡片',
      content: linking(targetLink, card: true),
      createdAt: DateTime(2026, 2, 1),
    );
    await diary('无关');
    expect(await titles(targetLink), ['卡片', '行内']);
    // 一次性读取与数据流同一口径。
    expect(
      [for (final link in await db.getDiaryBacklinks(targetLink)) link.title],
      ['卡片', '行内'],
    );
    final first = (await db.watchDiaryBacklinks(targetLink).first).first;
    expect(first.createdAt, DateTime(2026, 2, 1));
    expect(first.excerpt, '卡片');
  });

  test('ids that prefix one another do not match', () async {
    await diary('a', content: linking(const DiaryLinkTarget.diary('abcd')));
    expect(await titles(const DiaryLinkTarget.diary('abc')), isEmpty);
    expect(await titles(const DiaryLinkTarget.diary('abcd')), ['a']);
    // 日记与日记本的地址不相混。
    expect(await titles(const DiaryLinkTarget.notebook('abcd')), isEmpty);
  });

  test('typed text that looks like the address is not a link', () async {
    await diary(
      '打字',
      content: encodeDiaryBlocks(
        diaryBlocksFromPlainText('"jotsy://diary/abc" 只是文字'),
      ),
    );
    expect(await titles(const DiaryLinkTarget.diary('abc')), isEmpty);
  });

  test(
    'trash, sealed capsules, private diaries and itself are left out',
    () async {
      final target = DiaryLinkTarget.diary(await diary('目标'));
      final trashed = await diary('回收站', content: linking(target));
      await db.softDeleteDiary(trashed);
      await diary(
        '胶囊',
        content: linking(target),
        unlockAt: DateTime.now().add(const Duration(days: 30)),
      );
      final hidden = await db.createNotebook(
        name: '私密',
        visibility: NotebookVisibility.hidden,
      );
      await diary('私密', content: linking(target), notebookIds: [hidden]);
      final archived = await diary('归档', content: linking(target));
      await db.archiveDiary(archived);
      // 链接到自己的那篇不算。
      final self = await db.createDiary(
        title: '自己',
        contentDocJson: '{}',
        contentText: '',
        metadataJson: '{}',
      );
      await db.updateDiaryContent(
        diaryId: self,
        contentDocJson: linking(DiaryLinkTarget.diary(self)),
        contentText: '',
      );
      expect(await titles(target), ['归档']);
      expect(await titles(DiaryLinkTarget.diary(self)), isEmpty);
    },
  );

  test('notebooks list the diaries that mention them', () async {
    final notebook = await db.createNotebook(name: '旅行');
    await diary(
      '提到本子',
      content: linking(DiaryLinkTarget.notebook(notebook), card: true),
    );
    expect(await titles(DiaryLinkTarget.notebook(notebook)), ['提到本子']);
  });

  test('the stream updates when a diary adds a link', () async {
    final target = DiaryLinkTarget.diary(await diary('目标'));
    final later = await diary('后来');
    final updates = db
        .watchDiaryBacklinks(target)
        .map((links) => [for (final link in links) link.title]);
    expect(await updates.first, isEmpty);
    await db.updateDiaryContent(
      diaryId: later,
      contentDocJson: linking(target),
      contentText: '后来',
    );
    expect(await updates.first, ['后来']);
  });
}
