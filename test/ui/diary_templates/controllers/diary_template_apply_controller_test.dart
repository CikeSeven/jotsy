import 'dart:convert';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_to_delta.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations_gen.dart';
import 'package:node_diary/ui/diaries/models/time_capsule.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_meta_draft_controller.dart';
import 'package:node_diary/ui/diary_templates/controllers/diary_template_apply_controller.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_selection.dart';

/// 只记标题与正文的假编辑页：正文按传入的 ops 原样编码。
class _FakePort implements DiaryTemplateEditorPort {
  _FakePort(this.meta);

  @override
  final DiaryMetaDraftController meta;

  @override
  String title = '';

  List<Map<String, Object?>> ops = const <Map<String, Object?>>[
    <String, Object?>{'insert': '\n'},
  ];

  /// 每次换内容时 [title] 与正文的样子，用来确认换模板没有中间状态。
  final List<String> replacedTitles = <String>[];

  @override
  String get contentDocJson => jsonEncode(ops);

  @override
  bool get hasContent =>
      title.trim().isNotEmpty ||
      ops.any(
        (op) => op['insert'] is! String || '${op['insert']}'.trim() != '',
      );

  @override
  DateTime get diaryDate => DateTime(2026, 10, 18);

  @override
  AppLocalizations get l10n => lookupAppLocalizations(const Locale('zh'));

  @override
  List<String> get moodOptions => const <String>['😀', '😢'];

  @override
  String replaceContent({
    required String title,
    required Map<String, Object?> document,
    required int caret,
  }) {
    this.title = title;
    ops = diaryBlocksToQuillOps(document);
    replacedTitles.add(title);
    return contentDocJson;
  }

  /// 模拟用户在标题里打字。
  void type(String text) => title = '$title$text';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  late DiaryMetaDraftController meta;
  late _FakePort port;
  late DiaryTemplateApplyController controller;
  late List<String> used;

  setUpAll(() => initializeDateFormatting('zh'));

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    meta = DiaryMetaDraftController();
    port = _FakePort(meta);
    used = <String>[];
    controller = DiaryTemplateApplyController(
      enabled: true,
      port: port,
      database: database,
      onUsed: (id) async => used.add(id),
    );
  });
  tearDown(() async {
    controller.dispose();
    meta.dispose();
    await database.close();
  });

  const work = DiaryTemplate(
    id: 'user.work',
    name: '工作',
    titlePattern: '工作日志',
    bodyJson: '[{"insert":"今天做了什么\\n"}]',
    mood: '😀',
    energy: 4,
    tags: <DiaryTemplateTagRef>[
      DiaryTemplateTagRef(name: '工作', color: 0xFF2196F3),
      DiaryTemplateTagRef(name: '共用', color: 0xFF4CAF50),
    ],
  );
  const reading = DiaryTemplate(
    id: 'user.reading',
    name: '读书',
    titlePattern: '读书笔记',
    bodyJson: '[{"insert":"书名\\n"}]',
    tags: <DiaryTemplateTagRef>[
      DiaryTemplateTagRef(name: '共用', color: 0xFF4CAF50),
      DiaryTemplateTagRef(name: '读书', color: 0xFFFF9800),
    ],
  );

  Future<Map<String, int>> tagsByName() async => <String, int>{
    for (final tag in await database.watchAllTags().first) tag.name: tag.id,
  };

  Future<DiaryTemplateApplied?> choose(
    DiaryTemplate template, {
    DiaryTemplateApplySource source = DiaryTemplateApplySource.picker,
  }) => controller.apply(
    DiaryTemplateSelection(template),
    source: source,
    replacePristine: true,
  );

  test('a blank entry can apply a template from the picker', () async {
    expect(controller.canApply, isTrue);
    final applied = await choose(work);

    expect(applied, isNotNull);
    expect(port.title, '工作日志');
    expect(meta.value.moodEmoji, '😀');
    expect((await tagsByName()).keys, unorderedEquals(<String>['工作', '共用']));
    expect(used, <String>['user.work']);
  });

  test('a pristine template is replaced in one step, reverting the old '
      'presets and its tags', () async {
    final first = (await choose(work))!;
    var stripShown = false;
    controller.addListener(() => stripShown |= controller.stripVisible);
    port.replacedTitles.clear();

    expect(controller.canApply, isTrue);
    final second = await choose(reading);

    expect(second, isNotNull);
    expect(port.title, '读书笔记');
    expect(port.contentDocJson, '[{"insert":"书名\\n"}]');
    expect(port.replacedTitles, <String>['读书笔记'], reason: '没有清空的中间状态');
    expect(stripShown, isFalse);
    expect(controller.stripVisible, isFalse);
    expect(meta.value.moodEmoji, isNull, reason: '旧模板的心情撤回');
    expect(meta.value.energyLevel, isNull);

    final tags = await tagsByName();
    expect(tags.keys, unorderedEquals(<String>['共用', '读书']));
    expect(meta.value.tagIds, unorderedEquals(tags.values));
    expect(used, <String>['user.work', 'user.reading']);

    // 旧记录已失效：它的撤销什么也不做。
    expect(await controller.undo(first), isFalse);
    expect(port.title, '读书笔记');
  });

  test('a tag the old template only selected is deselected but kept', () async {
    final existing = await database.ensureTagsByName(
      <({String name, int color})>[(name: '工作', color: 0xFF000000)],
    );
    final workId = existing.ids['工作']!;
    await choose(work);
    expect(meta.value.tagIds, contains(workId));

    await choose(reading);

    expect(meta.value.tagIds, isNot(contains(workId)));
    expect((await tagsByName())['工作'], workId);
  });

  test('undoing a replacement returns to a blank entry', () async {
    await choose(work);
    final second = (await choose(reading))!;

    expect(await controller.undo(second), isTrue);

    expect(port.title, isEmpty);
    expect(port.hasContent, isFalse);
    expect(meta.value.moodEmoji, isNull);
    expect(meta.value.tagIds, isEmpty);
    expect(await tagsByName(), isEmpty);
    expect(controller.stripVisible, isTrue);
  });

  test('words the user wrote are never replaced', () async {
    await choose(work);
    port.type('，加了几个字');

    expect(controller.canApply, isFalse);
    expect(await choose(reading), isNull);
    expect(port.title, '工作日志，加了几个字');
    expect(meta.value.moodEmoji, '😀');
  });

  test('without replacePristine a second template is still refused', () async {
    await choose(work);
    final again = await controller.apply(
      const DiaryTemplateSelection(reading),
      source: DiaryTemplateApplySource.strip,
    );
    expect(again, isNull);
    expect(port.title, '工作日志');
  });

  test('switching while the old tags are still resolving keeps the shared '
      'tag', () async {
    // 不等第一次套用的标签解析完就换模板。
    final pending = choose(work);
    final second = await choose(reading);
    await pending;

    expect(second, isNotNull);
    final tags = await tagsByName();
    expect(tags.keys, unorderedEquals(<String>['共用', '读书']));
    expect(meta.value.tagIds, unorderedEquals(tags.values));
  });

  test('the auto source does not count as recently used after a '
      'replacement', () async {
    await choose(work, source: DiaryTemplateApplySource.auto);
    await choose(reading);
    expect(used, <String>['user.reading']);
  });

  group('capsule preset', () {
    const sealed = DiaryTemplate(
      id: 'user.sealed',
      name: '给未来',
      titlePattern: '写给一个月后',
      bodyJson: '[{"insert":"你好\\n"}]',
      capsule: TimeCapsulePreset.month,
    );

    test('with time capsules on the preset sets a capsule', () async {
      await choose(sealed);
      expect(meta.value.capsule, isNotNull);
    });

    test(
      'with time capsules off the preset is ignored, the rest applies',
      () async {
        final offMeta = DiaryMetaDraftController();
        final offPort = _FakePort(offMeta);
        final off = DiaryTemplateApplyController(
          enabled: true,
          port: offPort,
          database: database,
          onUsed: (_) async {},
          capsulesEnabled: () => false,
        );
        addTearDown(() {
          off.dispose();
          offMeta.dispose();
        });
        final applied = await off.apply(
          const DiaryTemplateSelection(sealed),
          source: DiaryTemplateApplySource.picker,
        );

        expect(applied, isNotNull);
        expect(offPort.title, '写给一个月后');
        expect(offMeta.value.capsule, isNull);
        // 模板本身的预设原样保留。
        expect(applied!.template.capsule, TimeCapsulePreset.month);
      },
    );
  });
}
