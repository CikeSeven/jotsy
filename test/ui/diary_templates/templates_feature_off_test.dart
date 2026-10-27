import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/day_photo_library.dart';
import 'package:node_diary/ui/diaries/controllers/diary_create_entry_flow.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diary_templates/widgets/diary_template_strip.dart';
import 'package:node_diary/ui/notebooks/pages/notebook_editor_page.dart';
import 'package:node_diary/ui/settings/sections/settings_editor_section.dart';
import 'package:node_diary/ui/settings/widgets/settings_card_group.dart';

import '../../support/diary_drafts_harness.dart';
import '../../support/fake_day_photo_library.dart';
import '../notebooks/notebook_test_support.dart';

/// 功能管理关闭“日记模板”：建议条、自动套用（按时间段与日记本默认模板）、
/// 草稿面板的“从模板新建”、编辑页菜单、设置入口与日记本编辑页的默认模板
/// 一律不出现；模板偏好与日记本里存的模板 id 原样保留。
void main() {
  const templatesOff = '{"templates":false}';

  /// 每个用例只建一次环境；[featuresRaw] 在打开页面前写入设置。
  Future<DiaryDraftsHarness> harness(
    WidgetTester tester, {
    String? featuresRaw,
  }) async {
    final h = await DiaryDraftsHarness.create(tester);
    if (featuresRaw != null) await h.settings.setAppFeaturesRaw(featuresRaw);
    return h;
  }

  Future<void> openBlankEditor(DiaryDraftsHarness h) async {
    await h.pump(
      const EditDiaryPage(entryMode: EditDiaryEntryMode.create),
      overrides: [
        dayPhotoLibraryProvider.overrideWithValue(
          FakeDayPhotoLibrary(access: DayPhotoAccess.denied),
        ),
      ],
    );
    await h.settle();
    await h.tester.pumpAndSettle();
  }

  String titleText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField).first).controller!.text;

  Future<void> openMenu(DiaryDraftsHarness h) async {
    await h.tester.tap(find.byTooltip(h.l10n.diaryEditorMoreActions));
    await h.tester.pumpAndSettle();
  }

  Future<void> closeMenu(DiaryDraftsHarness h) async {
    await h.tester.tapAt(const Offset(200, 600));
    await h.tester.pumpAndSettle();
  }

  group('new diary editor', () {
    testWidgets('templates on: the strip and both menu items are there', (
      tester,
    ) async {
      final h = await harness(tester);
      await openBlankEditor(h);

      expect(find.byType(DiaryTemplateStrip), findsOneWidget);
      expect(find.text(h.l10n.diaryTemplateStripTitle), findsOneWidget);
      await openMenu(h);
      expect(find.text(h.l10n.diaryTemplateChoose), findsOneWidget);
      expect(find.text(h.l10n.diaryTemplateSaveAs), findsOneWidget);
      await closeMenu(h);
      await h.unmount();
    });

    testWidgets('templates off: no strip and no template items in the menu', (
      tester,
    ) async {
      final h = await harness(tester, featuresRaw: templatesOff);
      await openBlankEditor(h);

      expect(find.byType(DiaryTemplateStrip), findsNothing);
      expect(find.text(h.l10n.diaryTemplateStripTitle), findsNothing);
      await openMenu(h);
      expect(find.text(h.l10n.diaryTemplateChoose), findsNothing);
      expect(find.text(h.l10n.diaryTemplateSaveAs), findsNothing);
      // 菜单其余项照常。
      expect(find.text(h.l10n.settingsEditorTitle), findsOneWidget);
      await closeMenu(h);
      await h.unmount();
    });

    testWidgets('templates off: the auto template is not applied and the '
        'prefs are kept', (tester) async {
      final h = await harness(tester, featuresRaw: templatesOff);
      const prefs = '{"v":1,"auto":"builtin.gratitude"}';
      await h.settings.setDiaryTemplatePrefsRaw(prefs);
      await openBlankEditor(h);
      await tester.pumpAndSettle();

      expect(titleText(tester), isEmpty);
      expect(find.byType(SnackBar), findsNothing);
      final tags = (await tester.runAsync(
        () => h.database.watchAllTags().first,
      ))!;
      expect(tags, isEmpty, reason: '没套用模板，也就没有为它新建标签');
      expect(h.settings.diaryTemplatePrefsRaw, prefs);
      await h.unmount();
    });
  });

  group('create entry flow', () {
    final results = <DiaryCreateEntryResult>[];
    setUp(results.clear);

    Future<void> pumpOpener(DiaryDraftsHarness h, {String? notebookId}) {
      return h.pump(
        Consumer(
          builder: (context, ref, _) => Scaffold(
            body: TextButton(
              onPressed: () async => results.add(
                await runDiaryCreateEntryFlow(
                  context,
                  ref,
                  notebookId: notebookId,
                ),
              ),
              child: const Text('New'),
            ),
          ),
        ),
      );
    }

    Future<void> tapNew(DiaryDraftsHarness h) async {
      await h.tester.tap(find.text('New'));
      await h.settleAll();
    }

    testWidgets('templates off: the draft picker has no from-template row', (
      tester,
    ) async {
      final h = await harness(tester, featuresRaw: templatesOff);
      await h.seed('一份', updatedAt: DateTime(2026, 10, 1));
      await pumpOpener(h);
      await tapNew(h);

      expect(find.text(h.l10n.diaryDraftPickerTitle), findsOneWidget);
      expect(find.text(h.l10n.diaryDraftPickerFromTemplate), findsNothing);
      expect(find.text(h.l10n.diaryDraftPickerViewAll(1)), findsOneWidget);
      expect(find.text(h.l10n.diaryDraftPickerNewBlank), findsOneWidget);

      await tester.tap(find.text(h.l10n.diaryDraftPickerNewBlank));
      await h.settleAll();
      expect(
        tester.widget<EditDiaryPage>(find.byType(EditDiaryPage)).createDraftId,
        isNull,
      );
      await h.unmount();
    });

    testWidgets('templates off: a blank entry in a notebook skips its '
        'default template and keeps it stored', (tester) async {
      final h = await harness(tester, featuresRaw: templatesOff);
      final travel = await h.notebook(
        '旅行',
        payload: NotebookPayload(templateId: 'builtin.gratitude'),
      );
      await pumpOpener(h, notebookId: travel);
      await tapNew(h);

      final page = tester.widget<EditDiaryPage>(find.byType(EditDiaryPage));
      expect(page.createNotebookId, travel);
      expect(page.createTemplate, isNull);
      expect(titleText(tester), isEmpty);
      expect(
        (await h.notebookRow(travel))!.parsedPayload.templateId,
        'builtin.gratitude',
      );
      await h.unmount();
    });
  });

  group('settings', () {
    Future<void> pumpSection(DiaryDraftsHarness h) async {
      await h.pump(
        Scaffold(
          body: ListView(
            children: <Widget>[
              SettingsEditorSection(settingsAsync: AsyncData(h.settings)),
            ],
          ),
        ),
      );
      await h.tester.pumpAndSettle();
    }

    Finder editorGroupDividers() => find.descendant(
      of: find.byType(SettingsCardGroup).first,
      matching: find.byType(Divider),
    );

    testWidgets('templates off: editor settings has no templates entry', (
      tester,
    ) async {
      final h = await harness(tester, featuresRaw: templatesOff);
      await pumpSection(h);

      expect(find.text(h.l10n.diaryTemplatesTitle), findsNothing);
      // 同组只剩四项（排版、代码块样式、打开日记时直接编辑、当天照片），
      // 之间三条分隔线（不留空占位多出来的那条）。
      expect(editorGroupDividers(), findsNWidgets(3));
      await h.unmount();
    });

    testWidgets('turning templates back on brings the entry back', (
      tester,
    ) async {
      final h = await harness(tester, featuresRaw: templatesOff);
      await pumpSection(h);
      expect(find.text(h.l10n.diaryTemplatesTitle), findsNothing);

      await h.settings.setAppFeaturesRaw(null);
      await h.settle();
      await tester.pumpAndSettle();
      expect(find.text(h.l10n.diaryTemplatesTitle), findsOneWidget);
      expect(editorGroupDividers(), findsNWidgets(4));
      await h.unmount();
    });
  });

  group('notebook editor', () {
    Future<DiaryDraftsHarness> openNotebookEditor(
      WidgetTester tester, {
      String? featuresRaw,
    }) async {
      final h = await harness(tester, featuresRaw: featuresRaw);
      final id = await h.notebook(
        '旅行',
        payload: NotebookPayload(templateId: 'builtin.gratitude'),
      );
      await h.pump(
        Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(NotebookEditorPage.route(notebookId: id)),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await h.settleAll();
      return h;
    }

    /// 默认模板一项排在最后，紧跟“排序”之后：滚到“排序”时它也已构建。
    Future<void> scrollToBottom(DiaryDraftsHarness h) async {
      await h.tester.scrollUntilVisible(
        find.text(h.l10n.notebookSortLabel),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await h.settleAll();
    }

    testWidgets('templates on: the default template field is shown', (
      tester,
    ) async {
      final h = await openNotebookEditor(tester);
      await scrollToBottom(h);
      expect(find.text(h.l10n.notebookTemplateLabel), findsOneWidget);
      await h.unmount();
    });

    testWidgets('templates off: no default template field, saving keeps the '
        'stored template', (tester) async {
      final h = await openNotebookEditor(tester, featuresRaw: templatesOff);
      await tester.enterText(find.byType(TextField).first, '远方');
      await tester.pump();
      await scrollToBottom(h);
      expect(find.text(h.l10n.notebookTemplateLabel), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, h.l10n.commonSave));
      await h.settleAll();

      final rows = await h.shelf();
      expect(rows.single.name, '远方');
      expect(rows.single.parsedPayload.templateId, 'builtin.gratitude');
      await h.unmount();
    });
  });
}
