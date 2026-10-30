import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/diary_blocks/diary_link_target.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_link_search.dart';
import 'package:node_diary/ui/diaries/models/diary_link_candidate.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_tree.dart';

void main() {
  late AppDatabase db;
  final l10n = lookupAppLocalizations(const Locale('zh'));

  setUpAll(() => initializeDateFormatting());
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> diary(
    String title, {
    String body = '',
    DateTime? createdAt,
    DateTime? unlockAt,
    List<String>? notebookIds,
  }) => db.createDiary(
    title: title,
    contentDocJson: '[{"insert":"$body\\n"}]',
    contentText: body,
    metadataJson: '{}',
    notebookIds: notebookIds,
    createdAtOverride: createdAt,
    capsuleUnlockAt: unlockAt,
    capsuleLockedAt: unlockAt == null
        ? null
        : DateTime.now().subtract(const Duration(days: 1)),
  );

  Future<List<DiaryLinkCandidate>> search(
    String query, {
    Set<DiaryLinkKind> kinds = const {
      DiaryLinkKind.diary,
      DiaryLinkKind.notebook,
    },
    String? exclude,
  }) async => searchDiaryLinkCandidates(
    db: db,
    tree: NotebookTree(await db.watchNotebooks().first),
    l10n: l10n,
    query: query,
    kinds: kinds,
    excludeDiaryId: exclude,
  );

  test('lists notebooks before diaries and matches pinyin', () async {
    final travel = await db.createNotebook(name: '旅行手账');
    await db.createNotebook(name: '读书');
    final trip = await diary('旅行的第一天');
    await diary('普通的一天');

    final found = await search('旅行');
    expect(found.map((c) => (c.kind, c.label)), [
      (DiaryLinkKind.notebook, '旅行手账'),
      (DiaryLinkKind.diary, '旅行的第一天'),
    ]);
    expect(found.first.target, DiaryLinkTarget.notebook(travel));
    expect(found.last.target, DiaryLinkTarget.diary(trip));
    // 日记本名认拼音（全拼前缀与首字母）。
    expect((await search('lxsz')).single.label, '旅行手账');
    expect(
      (await search('dushu', kinds: {DiaryLinkKind.notebook})).single.label,
      '读书',
    );
  });

  test('kinds narrow the search and the edited diary is left out', () async {
    await db.createNotebook(name: '一天一页');
    final self = await diary('一天');
    final other = await diary('又一天');
    final diaries = await search('一天', kinds: {DiaryLinkKind.diary});
    expect(diaries.map((c) => c.kind).toSet(), {DiaryLinkKind.diary});
    expect(
      (await search(
        '一天',
        kinds: {DiaryLinkKind.diary},
        exclude: self,
      )).map((c) => c.target.id),
      [other],
    );
  });

  test('private diaries never show up but private notebooks do', () async {
    final locked = await db.createNotebook(
      name: '秘密',
      visibility: NotebookVisibility.locked,
    );
    await diary('秘密日记', notebookIds: [locked]);
    final found = await search('秘密');
    expect(found.map((c) => (c.kind, c.label)), [
      (DiaryLinkKind.notebook, '秘密'),
    ]);
  });

  test('untitled diaries use a short excerpt or their date', () async {
    await diary(
      '',
      body: '今天去了很远很远的地方看了一整天的海和天空',
      createdAt: DateTime(2026, 3, 8, 9),
    );
    await diary('', createdAt: DateTime(2026, 3, 9, 9));
    final labels = (await search(
      '',
      kinds: {DiaryLinkKind.diary},
    )).map((c) => c.label).toList();
    expect(labels, contains('今天去了很远很远的地方看了一整天的海和天…'));
    expect(labels, contains('3月9日 的日记'));
  });

  test('sealed capsules keep their excerpt and cover out', () async {
    await diary(
      '',
      body: '写给一年后的自己',
      createdAt: DateTime(2026, 3, 8, 9),
      unlockAt: DateTime.now().add(const Duration(days: 300)),
    );
    final candidate = (await search('', kinds: {DiaryLinkKind.diary})).single;
    expect(candidate.sealed, isTrue);
    expect(candidate.cover, isNull);
    expect(candidate.label, '3月8日 的日记');
  });

  test('the controller debounces and keeps only the latest query', () async {
    final calls = <String>[];
    final pending = <String, Completer<List<DiaryLinkCandidate>>>{};
    final controller = DiaryLinkSearchController((query, kinds) {
      calls.add(query);
      return (pending[query] = Completer()).future;
    }, kinds: {DiaryLinkKind.diary});
    addTearDown(controller.dispose);

    controller.update('', force: true);
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['']);
    // 停手前的检索词不查询。
    controller.update('a');
    controller.update('ab');
    await Future<void>.delayed(
      DiaryLinkSearchController.debounce + const Duration(milliseconds: 20),
    );
    expect(calls, ['', 'ab']);
    // 旧结果晚到时丢弃。
    final candidate = DiaryLinkCandidate.diary(
      target: const DiaryLinkTarget.diary('x'),
      label: 'x',
      createdAt: DateTime(2026),
    );
    pending['']!.complete([candidate]);
    await Future<void>.delayed(Duration.zero);
    expect(controller.results, isNull);
    pending['ab']!.complete(const []);
    await Future<void>.delayed(Duration.zero);
    expect(controller.results, isEmpty);
  });
}
