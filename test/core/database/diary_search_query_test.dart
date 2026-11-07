import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';

/// 搜索口径的数据库查询：多词 AND、LIKE 字面匹配、含归档、筛选谓词、
/// 计数与列表一致、留言多词命中、常用标签的篇数。
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> diary(
    String title, {
    String? body,
    Map<String, Object?> context = const <String, Object?>{},
    List<int> tagIds = const <int>[],
    List<String>? notebookIds,
    DateTime? unlockAt,
  }) {
    final text = body ?? title;
    return db.createDiary(
      title: title,
      contentDocJson: '[{"insert":"$text\\n"}]',
      contentText: text,
      metadataJson: jsonEncode(<String, Object?>{'context': context}),
      tagIds: tagIds,
      notebookIds: notebookIds,
      createdAtOverride: DateTime.now().subtract(const Duration(days: 3)),
      capsuleUnlockAt: unlockAt,
      capsuleLockedAt: unlockAt == null
          ? null
          : DateTime.now().subtract(const Duration(days: 30)),
    );
  }

  Future<List<String>> titles({
    String keyword = '',
    List<int> tagIds = const <int>[],
    bool matchComments = false,
    bool includeArchived = false,
    DiaryScopePredicate? filter,
  }) async {
    final rows = await db
        .watchDiaries(
          keyword: keyword,
          requiredTagIds: tagIds,
          matchComments: matchComments,
          includeArchived: includeArchived,
          filter: filter,
          sortMode: DiarySortMode.titleAsc,
        )
        .first;
    return rows.map((row) => row.diary.title).toList();
  }

  Future<int> count({
    String keyword = '',
    bool includeArchived = false,
    DiaryScopePredicate? filter,
  }) => db
      .watchActiveDiaryCount(
        keyword: keyword,
        includeArchived: includeArchived,
        filter: filter,
      )
      .first;

  test('every whitespace separated word must match somewhere', () async {
    await diary('京都', body: '下雨的寺庙');
    await diary('京都 晴天', body: '红叶');
    await diary('大阪', body: '下雨的街');

    expect(await titles(keyword: '京都'), <String>['京都', '京都 晴天']);
    // 两个词分别命中标题与正文也算。
    expect(await titles(keyword: '京都 下雨'), <String>['京都']);
    // 全角空格同样分词；词序无关。
    expect(await titles(keyword: '下雨　京都'), <String>['京都']);
    expect(await titles(keyword: '京都 东京'), isEmpty);
  });

  test('percent and underscore in the keyword match literally', () async {
    await diary('完成 100% 目标');
    await diary('完成 1000 目标');
    await diary('file_name');
    await diary('filename');

    expect(await titles(keyword: '100%'), <String>['完成 100% 目标']);
    expect(await titles(keyword: 'file_'), <String>['file_name']);
  });

  test('archived diaries only come back when asked for', () async {
    await diary('海边 一');
    final archived = await diary('海边 二');
    await db.archiveDiary(archived);

    expect(await titles(keyword: '海边'), <String>['海边 一']);
    expect(await titles(keyword: '海边', includeArchived: true), <String>[
      '海边 一',
      '海边 二',
    ]);
    expect(
      await db.getActiveDiaryIds(keyword: '海边', includeArchived: true),
      hasLength(2),
    );
    expect(await count(keyword: '海边'), 1);
    expect(await count(keyword: '海边', includeArchived: true), 2);
  });

  test('the filter predicate narrows list, ids and count alike', () async {
    await diary('a', context: <String, Object?>{'moodEmoji': '😊'});
    await diary('b', context: <String, Object?>{'moodEmoji': '😢'});
    await diary('c', context: <String, Object?>{'moodEmoji': '😊'});
    final filter = compileNotebookRules(
      NotebookRuleSet(
        rules: <NotebookRule>[
          NotebookMoodRule(emojis: <String>['😊']),
        ],
      ),
    );

    expect(await titles(filter: filter), <String>['a', 'c']);
    expect(await db.getActiveDiaryIds(filter: filter), hasLength(2));
    expect(await count(filter: filter), 2);
    // 关键词与筛选同时生效。
    expect(await titles(keyword: 'c', filter: filter), <String>['c']);
  });

  test('a sealed capsule only matches by title', () async {
    final future = DateTime.now().add(const Duration(days: 30));
    await diary('胶囊', body: '秘密', unlockAt: future);

    expect(await titles(keyword: '胶囊'), <String>['胶囊']);
    expect(await titles(keyword: '秘密'), isEmpty);
  });

  test('comments match per word and hits accept any word', () async {
    final first = await diary('散步', body: '公园');
    await diary('读书', body: '图书馆');
    await db.addDiaryComment(diaryId: first, content: '后来又去了湖边');

    expect(await titles(keyword: '散步 湖边', matchComments: true), <String>['散步']);
    expect(await titles(keyword: '散步 湖边'), isEmpty);
    final hits = await db.watchDiaryCommentHits('湖边 图书馆').first;
    expect(hits.keys, <String>[first]);
  });

  test('tag usage counts skip archived, sealed and private diaries', () async {
    final travel = await db.createTag(name: '旅行', color: 0xff336699);
    final food = await db.createTag(name: '美食', color: 0xff993366);
    final secret = await db.createNotebook(
      name: '私密',
      visibility: NotebookVisibility.hidden,
    );
    await diary('1', tagIds: <int>[travel, food]);
    await diary('2', tagIds: <int>[travel]);
    await diary('3', tagIds: <int>[food], notebookIds: <String>[secret]);
    final archived = await diary('4', tagIds: <int>[food]);
    await db.archiveDiary(archived);
    await diary(
      '5',
      tagIds: <int>[food],
      unlockAt: DateTime.now().add(const Duration(days: 9)),
    );

    final usages = await db.watchTagUsageCounts().first;
    expect(usages.map((usage) => (usage.tagId, usage.uses)), <(int, int)>[
      (travel, 2),
      (food, 1),
    ]);
  });
}
