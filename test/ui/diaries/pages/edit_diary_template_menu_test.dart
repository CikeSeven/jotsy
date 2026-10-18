import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/services/day_photo_library.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_json.dart';
import 'package:node_diary/ui/widgets/expressive_menu/expressive_menu.dart';

import '../../../support/diary_drafts_harness.dart';
import '../../../support/fake_day_photo_library.dart';

/// 新建编辑页顶栏菜单的“选择模板”：空白时打开模板面板套用；仍是刚套用
/// 的模板原样时换成新选的；写了字只提示、不打开面板。
void main() {
  Finder titleField() => find.byType(TextField).first;
  Finder stripTitle(DiaryDraftsHarness h) =>
      find.text(h.l10n.diaryTemplateStripTitle);
  Finder pickerTitle(DiaryDraftsHarness h) =>
      find.text(h.l10n.diaryTemplatePickerTitle);

  String titleText(WidgetTester tester) =>
      tester.widget<TextField>(titleField()).controller!.text;

  String bodyText(WidgetTester tester) => tester
      .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
      .controller
      .document
      .toPlainText();

  const work = DiaryTemplate(
    id: 'user.work',
    name: '工作模板',
    titlePattern: '工作日志',
    bodyJson: '[{"insert":"今天做了什么\\n"}]',
    energy: 4,
    tags: <DiaryTemplateTagRef>[
      DiaryTemplateTagRef(name: '工作', color: 0xFF2196F3),
      DiaryTemplateTagRef(name: '共用', color: 0xFF4CAF50),
    ],
  );
  const reading = DiaryTemplate(
    id: 'user.reading',
    name: '读书模板',
    titlePattern: '读书笔记',
    bodyJson: '[{"insert":"书名\\n"}]',
    tags: <DiaryTemplateTagRef>[
      DiaryTemplateTagRef(name: '共用', color: 0xFF4CAF50),
      DiaryTemplateTagRef(name: '读书', color: 0xFFFF9800),
    ],
  );

  Future<void> saveTemplates(DiaryDraftsHarness h) async {
    for (final template in <DiaryTemplate>[work, reading]) {
      await h.tester.runAsync(
        () => h.database.saveDiaryTemplate(
          templateId: template.id,
          name: template.name,
          payload: DiaryTemplateJson.toPayload(template),
        ),
      );
    }
  }

  Future<DiaryDraftsHarness> openEditor(
    WidgetTester tester, {
    DiaryDraftsHarness? harness,
    String? draftId,
    String? diaryId,
    String? prefsRaw,
  }) async {
    final h = harness ?? await DiaryDraftsHarness.create(tester);
    if (prefsRaw != null) await h.settings.setDiaryTemplatePrefsRaw(prefsRaw);
    await h.pump(
      diaryId != null
          ? EditDiaryPage(diaryId: diaryId)
          : EditDiaryPage(
              entryMode: EditDiaryEntryMode.create,
              createDraftId: draftId,
            ),
      overrides: [
        dayPhotoLibraryProvider.overrideWithValue(
          FakeDayPhotoLibrary(access: DayPhotoAccess.denied),
        ),
      ],
    );
    await h.settle();
    await tester.pumpAndSettle();
    return h;
  }

  Future<void> openMenu(DiaryDraftsHarness h) async {
    await h.tester.tap(find.byTooltip(h.l10n.diaryEditorMoreActions));
    await h.tester.pumpAndSettle();
  }

  Future<void> tapChoose(DiaryDraftsHarness h) async {
    await openMenu(h);
    await h.tester.tap(find.text(h.l10n.diaryTemplateChoose));
    await h.tester.pumpAndSettle();
    await h.settle();
    await h.tester.pumpAndSettle();
  }

  /// 在面板里搜到 [name]，点开预览后选用。
  Future<void> pick(DiaryDraftsHarness h, String id, String name) async {
    await h.tester.enterText(find.byType(SearchBar), name);
    await h.tester.pumpAndSettle();
    await h.tester.tap(find.byKey(ValueKey<String>('template_pick_$id')));
    await h.tester.pumpAndSettle();
    await h.tester.tap(find.text(h.l10n.diaryTemplatePickerUse));
    await h.tester.pumpAndSettle();
    await h.settle();
    await h.tester.pumpAndSettle();
  }

  Future<void> waitForDebouncedSave(DiaryDraftsHarness h) async {
    await h.tester.pump(const Duration(milliseconds: 1400));
    await h.settle();
  }

  Future<void> closeSnackBar(DiaryDraftsHarness h) async {
    await h.tester.pump(const Duration(seconds: 5));
    await h.tester.pumpAndSettle();
  }

  Future<Map<String, int>> tagsByName(DiaryDraftsHarness h) async =>
      <String, int>{
        for (final tag in (await h.tester.runAsync(
          () => h.database.watchAllTags().first,
        ))!)
          tag.name: tag.id,
      };

  testWidgets('a new blank entry lists choose template first in the menu', (
    tester,
  ) async {
    final h = await openEditor(tester);
    await openMenu(h);

    final labels = <String>[
      h.l10n.diaryTemplateChoose,
      h.l10n.diaryTemplateSaveAs,
      h.l10n.settingsEditorTitle,
    ];
    final tops = [
      for (final label in labels) tester.getTopLeft(find.text(label)).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
    expect(
      find.descendant(
        of: find.widgetWithText(ExpressiveMenuItem, h.l10n.diaryTemplateChoose),
        matching: find.byIcon(FontAwesomeIcons.wandMagicSparkles.data),
      ),
      findsOneWidget,
    );

    await tester.tapAt(const Offset(200, 600));
    await tester.pumpAndSettle();
    await h.unmount();
  });

  testWidgets('continuing a draft has no choose template item', (tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    final draft = await h.seed('旧草稿', updatedAt: DateTime(2026, 10, 1));
    await openEditor(tester, harness: h, draftId: draft);
    await openMenu(h);

    expect(find.text(h.l10n.diaryTemplateSaveAs), findsOneWidget);
    expect(find.text(h.l10n.diaryTemplateChoose), findsNothing);

    await tester.tapAt(const Offset(200, 600));
    await tester.pumpAndSettle();
    await h.unmount();
  });

  testWidgets('editing an existing diary has no choose template item', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    final diaryId = (await tester.runAsync(
      () => h.database.createDiary(
        title: '已有的日记',
        contentDocJson: jsonEncode(<Map<String, Object?>>[
          <String, Object?>{'insert': '正文\n'},
        ]),
        contentText: '正文',
        metadataJson: '{}',
      ),
    ))!;
    await openEditor(tester, harness: h, diaryId: diaryId);
    await openMenu(h);

    expect(find.text(h.l10n.diaryTemplateSaveAs), findsOneWidget);
    expect(find.text(h.l10n.diaryTemplateChoose), findsNothing);

    await tester.tapAt(const Offset(200, 600));
    await tester.pumpAndSettle();
    await h.unmount();
  });

  testWidgets('a blank entry opens the picker and applies the choice', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await saveTemplates(h);
    await openEditor(tester, harness: h);

    await tapChoose(h);
    expect(pickerTitle(h), findsOneWidget);
    await pick(h, reading.id, reading.name);

    expect(titleText(tester), '读书笔记');
    expect(bodyText(tester), contains('书名'));
    expect(find.text('已套用「读书模板」'), findsOneWidget);
    expect(stripTitle(h), findsNothing);
    await closeSnackBar(h);
    await h.unmount();
  });

  testWidgets('an untouched template is switched for the chosen one, '
      'cleaning up what the old one brought', (tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    await saveTemplates(h);
    await openEditor(
      tester,
      harness: h,
      prefsRaw: '{"v":1,"auto":"user.work"}',
    );
    expect(titleText(tester), '工作日志');
    expect(stripTitle(h), findsNothing);
    expect((await tagsByName(h)).keys, unorderedEquals(<String>['工作', '共用']));

    await tapChoose(h);
    expect(stripTitle(h), findsNothing);
    await pick(h, reading.id, reading.name);

    expect(titleText(tester), '读书笔记');
    expect(bodyText(tester), isNot(contains('今天做了什么')));
    expect(bodyText(tester), contains('书名'));
    expect(stripTitle(h), findsNothing);
    expect(find.text('已套用「读书模板」'), findsOneWidget);
    final tags = await tagsByName(h);
    expect(
      tags.keys,
      unorderedEquals(<String>['共用', '读书']),
      reason: '只有旧模板新建的“工作”被回收，两者共用的“共用”保留',
    );

    // 原样未动：换模板不会写出草稿。
    await waitForDebouncedSave(h);
    expect(await h.drafts(), isEmpty);

    // 写一个字让它成为草稿，读出勾选的标签与预设。
    await tester.enterText(titleField(), '读书笔记！');
    await waitForDebouncedSave(h);
    final draft =
        jsonDecode((await h.drafts()).single.payload) as Map<String, Object?>;
    expect((draft['selectedTagIds']! as List<Object?>).toSet(), <Object?>{
      tags['共用'],
      tags['读书'],
    });
    expect(draft['energyLevel'], isNull, reason: '旧模板的精力预设已撤回');
    await closeSnackBar(h);
    await h.unmount();
  });

  testWidgets('after typing the menu only explains, the picker stays shut', (
    tester,
  ) async {
    final h = await openEditor(tester);
    await tester.enterText(titleField(), '自己写的');
    await tester.pumpAndSettle();

    await tapChoose(h);

    expect(pickerTitle(h), findsNothing);
    expect(find.text(h.l10n.diaryTemplateNeedsBlankEntry), findsOneWidget);
    expect(titleText(tester), '自己写的');
    await closeSnackBar(h);
    await h.unmount();
  });

  testWidgets('undoing a switched template returns to a blank entry', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await saveTemplates(h);
    await openEditor(
      tester,
      harness: h,
      prefsRaw: '{"v":1,"auto":"user.work"}',
    );

    await tapChoose(h);
    await pick(h, reading.id, reading.name);
    await tester.tap(find.text(h.l10n.commonUndo));
    await tester.pumpAndSettle();
    await h.settle();
    await tester.pumpAndSettle();

    expect(titleText(tester), isEmpty);
    expect(bodyText(tester).trim(), isEmpty);
    expect(stripTitle(h), findsOneWidget);
    expect(await tagsByName(h), isEmpty);
    await h.unmount();
  });
}
