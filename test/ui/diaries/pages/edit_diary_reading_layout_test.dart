import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as quill;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_features.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/ai/models/ai_preference_parts.dart';
import 'package:node_diary/ui/ai/providers/ai_providers.dart';
import 'package:node_diary/ui/ai/providers/ai_records_providers.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_behavior.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_settings.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_style.dart';
import 'package:node_diary/ui/diaries/pages/diary_search_page.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_preview_resolved_style.dart';
import 'package:node_diary/ui/diaries/widgets/diary_comments/diary_comments_section.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor_trailing_region.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_meta.dart';
import 'package:node_diary/ui/diaries/widgets/diary_reading_editor/diary_reading_editor_header.dart';
import 'package:node_diary/ui/diaries/widgets/diary_share_widgets.dart';
import 'package:node_diary/ui/diaries/widgets/publish_diary_panel.dart';
import 'package:node_diary/ui/diaries/widgets/publish_panel/publish_panel_summary_bar.dart';
import 'package:node_diary/ui/widgets/expressive_menu/expressive_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/diary_content_test_helpers.dart';
import '../../../support/expressive_test_theme.dart';
import '../../../support/publish_panel_driver.dart';

/// 编辑已有日记的阅读式版式：页面与预览页同一样式，标题与正文就地可改，
/// 信息栏打开信息面板。
void main() {
  late AppDatabase database;
  late SettingsService settings;
  late String diaryId;
  late int tagId;

  /// 装配：按 [style] 写入预览页样式，建一篇带心情与标签的日记。
  /// [comments] 打开留言功能；[paragraphs] 为正文段落数（长正文时页尾在
  /// 视口之外、没有构建）；[openInEditor] 打开“打开日记时直接编辑”。
  Future<void> prepare({
    DiaryPreviewStyle style = DiaryPreviewStyle.defaults,
    bool comments = false,
    int paragraphs = 1,
    bool inNotebook = false,
    bool openInEditor = false,
  }) async {
    final encoded = DiaryPreviewSettings(
      current: style,
      behavior: DiaryPreviewBehavior(openInEditor: openInEditor),
    ).encode();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.settings.diary_preview_style': ?encoded,
      if (comments)
        'app.settings.app_features': AppFeatures.defaults
            .copyWith(comments: true)
            .encode(),
    });
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
    tagId = await database.createTag(name: 'Travel', color: 0xFF4CAF50);
    final notebookId = inNotebook
        ? await database.createNotebook(name: 'Trips')
        : null;
    final body = List<String>.generate(
      paragraphs,
      (i) => i == 0 ? 'Sunset over the sea' : 'Line $i',
    );
    diaryId = await database.createDiary(
      title: 'Seaside',
      contentDocJson: '[{"insert":"${body.join('\\n')}\\n"}]',
      contentText: body.join('\n'),
      metadataJson: '{"context":{"moodEmoji":"😊","location":"West Lake"}}',
      tagIds: <int>[tagId],
      notebookIds: notebookId == null ? null : <String>[notebookId],
    );
  }

  tearDown(() => database.close());

  /// 打开编辑页；返回编辑页结束时的结果（删除时为 true）。[ai] 让写作灵感、
  /// 生成标题 / 推荐与 AI 回应三个模块可用（不配置真实服务）。
  Future<Future<Object?>> openEditor(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    bool ai = false,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late Future<Object?> result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((ref) async => settings),
          if (ai) ...[
            aiModuleAvailableProvider.overrideWith(
              (ref, module) => const <AiModule>{
                AiModule.prompts,
                AiModule.suggest,
                AiModule.reply,
              }.contains(module),
            ),
            aiPrivateDiaryIdsProvider.overrideWith(
              (ref) => Stream<Set<String>>.value(const <String>{}),
            ),
          ],
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(brightness),
          locale: const Locale('en'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            quill.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  result = Navigator.of(context).push<Object?>(
                    MaterialPageRoute<Object?>(
                      builder: (_) => EditDiaryPage(diaryId: diaryId),
                    ),
                  );
                },
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    return result;
  }

  AppLocalizations l10nOf(WidgetTester tester) =>
      tester.element(find.byType(EditDiaryPage)).l10n;

  TextField titleField(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField).first);

  DiaryEditor editorOf(WidgetTester tester) =>
      tester.widget<DiaryEditor>(find.byType(DiaryEditor));

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets('an existing diary opens laid out like the preview page '
        '(${brightness.name})', (tester) async {
      await prepare();
      await openEditor(tester, brightness: brightness);

      // 标题：预览标题的样式（默认特粗），没有下划线；正文左右 16。
      final title = titleField(tester);
      expect(title.controller!.text, 'Seaside');
      expect(title.style?.fontWeight, FontWeight.w800);
      expect(title.decoration?.border, InputBorder.none);
      expect(title.maxLength, 200);
      expect(
        editorOf(tester).padding,
        const EdgeInsets.symmetric(horizontal: 16),
      );
      // 信息栏显示心情、地点与标签；页面上没有信息面板与收起栏。
      expect(find.byType(DiaryReadingMetaButton), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DiaryPreviewMeta),
          matching: find.textContaining('😊'),
        ),
        findsOneWidget,
      );
      expect(find.text('Travel'), findsOneWidget);
      expect(find.byType(PublishDiaryPanel), findsNothing);
      expect(find.byKey(PublishPanelSummaryBar.summaryKey), findsNothing);
      // 打开时不聚焦、不弹键盘，也就没有“完成”。
      expect(title.focusNode!.hasFocus, isFalse);
      expect(editorOf(tester).focusNode!.hasFocus, isFalse);
      expect(find.byTooltip(l10nOf(tester).diaryReadingDone), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }

  testWidgets('tapping the info bar opens the details panel; '
      'collapsing it unmounts the panel', (tester) async {
    await prepare();
    await openEditor(tester);
    final driver = PublishPanelDriver(tester);

    await tester.tap(find.byType(DiaryReadingMetaButton));
    await tester.pumpAndSettle();
    expect(find.byType(PublishDiaryPanel), findsOneWidget);
    expect(driver.expandedHeader, findsOneWidget);

    // 返回键先收面板：收回到底后面板卸载，页面还在。
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(PublishDiaryPanel), findsNothing);
    expect(find.byType(EditDiaryPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('a mood changed in the panel shows in the info bar right away '
      'and is saved', (tester) async {
    await prepare();
    await openEditor(tester);
    final driver = PublishPanelDriver(tester);
    await driver.expand();

    driver.setMood('😢');
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(DiaryPreviewMeta),
        matching: find.textContaining('😢'),
      ),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 600));
    final saved = (await tester.runAsync(
      () => database.getDiaryWithTagsByDiaryId(diaryId),
    ))!;
    expect(saved.diary.metadata, contains('😢'));
    await unmount(tester);
  });

  testWidgets('tapping the comment count scrolls down to the comments, like '
      'the preview page, instead of opening the panel', (tester) async {
    await prepare(comments: true, paragraphs: 80);
    await tester.runAsync(
      () => database.addDiaryComment(diaryId: diaryId, content: 'Looking back'),
    );
    await openEditor(tester);
    final l10n = l10nOf(tester);
    // 长正文：页尾（留言区）在视口之外，还没构建。
    expect(find.byType(DiaryCommentsSection), findsNothing);

    await tester.tap(find.text(l10n.diaryCommentsCount(1)));
    await tester.pumpAndSettle();
    expect(find.byType(PublishDiaryPanel), findsNothing);
    final section = find.byType(DiaryCommentsSection);
    expect(section, findsOneWidget);
    // 留言区整块进入视口（顶栏之下、屏幕之内）。它在文末，后面没有足够的
    // 内容把它顶到视口最上方，与预览页相同。
    final rect = tester.getRect(section);
    expect(rect.top, greaterThanOrEqualTo(kToolbarHeight));
    expect(rect.bottom, lessThanOrEqualTo(900));
    expect(find.text('Looking back'), findsOneWidget);

    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('tapping a tag chip saves first and opens that tag\'s search, '
      'like the preview page', (tester) async {
    await prepare();
    await openEditor(tester);
    await tester.enterText(find.byType(TextField).first, 'Typed just now');

    await tester.tap(
      find.descendant(
        of: find.byType(DiaryPreviewMeta),
        matching: find.text('Travel'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PublishDiaryPanel), findsNothing);
    expect(find.byType(DiarySearchPage), findsOneWidget);
    final stored = (await tester.runAsync(
      () => database.getDiaryWithTagsByDiaryId(diaryId),
    ))!;
    expect(stored.diary.title, 'Typed just now');
    await unmount(tester);
  });

  testWidgets('tapping a notebook chip saves first and goes home to that '
      'notebook, like the preview page', (tester) async {
    await prepare(inNotebook: true);
    await openEditor(tester);
    await tester.enterText(find.byType(TextField).first, 'Typed just now');

    await tester.tap(
      find.descendant(
        of: find.byType(DiaryPreviewMeta),
        matching: find.text('Trips'),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    // 回到首页（这里是测试的首个路由）：编辑页已关掉，但最后的输入写进了库。
    expect(find.byType(EditDiaryPage), findsNothing);
    expect(find.byType(PublishDiaryPanel), findsNothing);
    final stored = (await tester.runAsync(
      () => database.getDiaryWithTagsByDiaryId(diaryId),
    ))!;
    expect(stored.diary.title, 'Typed just now');
    await unmount(tester);
  });

  /// 在编辑页之上压一页（别处的页面），返回它的 Navigator 以便关掉。
  Future<NavigatorState> coverEditor(WidgetTester tester) async {
    final navigator = Navigator.of(tester.element(find.byType(EditDiaryPage)));
    unawaited(
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Another page')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return navigator;
  }

  Future<void> settleWithDatabase(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
    }
  }

  testWidgets('covering the editor saves at once; coming back after the diary '
      'was changed elsewhere shows the latest version', (tester) async {
    await prepare();
    await openEditor(tester);
    final l10n = l10nOf(tester);
    await tester.enterText(find.byType(TextField).first, 'Mine');

    // 被盖住：不等防抖，最后的输入立即写进库。
    final navigator = await coverEditor(tester);
    await settleWithDatabase(tester);
    final stored = (await tester.runAsync(
      () => database.getDiaryWithTagsByDiaryId(diaryId),
    ))!;
    expect(stored.diary.title, 'Mine');

    // 别处（上面那页里又打开了这一篇）改了它：库里的时间按秒存，隔开一秒。
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await database.updateDiary(
        diaryId: diaryId,
        title: 'Changed elsewhere',
        contentDocJson: '[{"insert":"Rewritten body\\n"}]',
        contentText: 'Rewritten body',
        metadataJson: stored.diary.metadata,
        tagIds: <int>[tagId],
      );
    });

    navigator.pop();
    await settleWithDatabase(tester);
    expect(titleField(tester).controller!.text, 'Changed elsewhere');
    expect(editorOf(tester).controller.plainText, contains('Rewritten body'));
    expect(find.text(l10n.diaryReadingReloaded), findsOneWidget);

    // 换上的内容算“已存”：不会被自动保存再写一遍成旧内容。
    await tester.pump(const Duration(milliseconds: 600));
    await settleWithDatabase(tester);
    final after = (await tester.runAsync(
      () => database.getDiaryWithTagsByDiaryId(diaryId),
    ))!;
    expect(after.diary.title, 'Changed elsewhere');
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('coming back with nothing changed elsewhere keeps the editor as '
      'it was', (tester) async {
    await prepare();
    await openEditor(tester);
    final l10n = l10nOf(tester);
    final controllerBefore = editorOf(tester).controller;
    await tester.enterText(find.byType(TextField).first, 'Still mine');

    final navigator = await coverEditor(tester);
    await settleWithDatabase(tester);
    navigator.pop();
    await settleWithDatabase(tester);

    expect(titleField(tester).controller!.text, 'Still mine');
    expect(identical(editorOf(tester).controller, controllerBefore), isTrue);
    expect(find.text(l10n.diaryReadingReloaded), findsNothing);
    await unmount(tester);
  });

  testWidgets('coming back after the diary was deleted elsewhere leaves the '
      'editor instead of bringing it back', (tester) async {
    await prepare();
    await openEditor(tester);
    final l10n = l10nOf(tester);

    final navigator = await coverEditor(tester);
    await tester.runAsync(() => database.softDeleteDiary(diaryId));
    navigator.pop();
    await settleWithDatabase(tester);

    expect(find.byType(EditDiaryPage), findsNothing);
    expect(find.text(l10n.autoT0122), findsOneWidget);
    final stored = (await tester.runAsync(
      () => database.getDiaryWithTagsByDiaryId(diaryId),
    ))!;
    expect(stored.diary.isDeleted, isTrue);
    await unmount(tester);
  });

  testWidgets('a paper colour from the preview style colours the page', (
    tester,
  ) async {
    await prepare(
      style: DiaryPreviewStyle.defaults.copyWith(
        page: DiaryPreviewStyle.defaults.page.copyWith(
          paper: DiaryPreviewPaper.warm,
        ),
      ),
    );
    await openEditor(tester);
    final scaffold = tester.widget<Scaffold>(
      find
          .descendant(
            of: find.byType(EditDiaryPage),
            matching: find.byType(Scaffold),
          )
          .first,
    );
    final warm = DiaryPreviewResolvedStyle.paperColors[DiaryPreviewPaper.warm]!;
    expect(scaffold.backgroundColor, Color(warm.$1));
    await unmount(tester);
  });

  testWidgets('a hidden preview title still leaves the title editable, and an '
      'info bar after the body moves to the trailing region', (tester) async {
    await prepare(
      style: DiaryPreviewStyle.defaults.copyWith(
        title: DiaryPreviewStyle.defaults.title.copyWith(visible: false),
        meta: DiaryPreviewStyle.defaults.meta.copyWith(
          position: DiaryPreviewMetaPosition.end,
        ),
      ),
    );
    await openEditor(tester);
    expect(titleField(tester).controller!.text, 'Seaside');
    expect(
      find.descendant(
        of: find.byType(DiaryEditorTrailingRegion),
        matching: find.byType(DiaryReadingMetaButton),
      ),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('editing the body shows Done, which ends editing', (
    tester,
  ) async {
    await prepare();
    await openEditor(tester);
    final l10n = l10nOf(tester);
    editorOf(tester).focusNode!.requestFocus();
    await tester.pumpAndSettle();
    expect(find.byTooltip(l10n.diaryReadingDone), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.diaryReadingDone));
    await tester.pumpAndSettle();
    expect(editorOf(tester).focusNode!.hasFocus, isFalse);
    expect(find.byTooltip(l10n.diaryReadingDone), findsNothing);
    await unmount(tester);
  });

  testWidgets('More → Delete saves the last edit, moves the diary to the '
      'recycle bin and ends with true', (tester) async {
    await prepare();
    final result = await openEditor(tester);
    final l10n = l10nOf(tester);
    await tester.enterText(find.byType(TextField).first, 'Last words');

    await tester.tap(find.byTooltip(l10n.autoT0125));
    await tester.pumpAndSettle();
    expect(find.text(l10n.diaryReadingEditInfo), findsOneWidget);
    await tester.tap(find.text(l10n.commonDelete));
    await tester.pumpAndSettle();
    // 确认对话框里的“删除”。
    await tester.tap(find.text(l10n.commonDelete).last);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(await result, isTrue);
    expect(find.byType(EditDiaryPage), findsNothing);
    final stored = (await tester.runAsync(
      () => database.getDiaryWithTagsByDiaryId(diaryId),
    ))!;
    expect(stored.diary.isDeleted, isTrue);
    expect(stored.diary.title, 'Last words');
    await unmount(tester);
  });

  /// “更多”菜单里文字为 [label] 的那一项。
  Finder menuItem(String label) =>
      find.widgetWithText(ExpressiveMenuItem, label);

  testWidgets('the top bar shares, and More leaves out what the preview page '
      'already offers', (tester) async {
    await prepare(comments: true);
    await openEditor(tester);
    final l10n = l10nOf(tester);

    // 顶栏的分享按钮（不随预览页样式开关）打开分享面板。
    await tester.tap(find.byTooltip(l10n.previewShare));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryShareTextPreview), findsOneWidget);
    Navigator.of(tester.element(find.byType(DiaryShareTextPreview))).pop();
    await tester.pumpAndSettle();

    // “更多”是弹出菜单：分享、导出、写留言与 AI 回应在预览页，这里没有。
    await tester.tap(find.byTooltip(l10n.autoT0125));
    await tester.pumpAndSettle();
    expect(menuItem(l10n.diaryReadingEditInfo), findsOneWidget);
    expect(menuItem(l10n.diaryTemplateSaveAs), findsOneWidget);
    expect(menuItem(l10n.settingsEditorTitle), findsOneWidget);
    // 页面样式在预览页的“更多”里；AI 不可用时没有 AI 二级菜单。
    expect(menuItem(l10n.diaryPreviewStyleMoreEntry), findsNothing);
    expect(menuItem(l10n.diaryReadingAiMenu), findsNothing);
    expect(menuItem(l10n.commonDelete), findsOneWidget);
    expect(menuItem(l10n.previewShare), findsNothing);
    expect(menuItem(l10n.previewExport), findsNothing);
    expect(menuItem(l10n.diaryCommentSheetNew), findsNothing);
    expect(menuItem(l10n.aiReplyMoreItem), findsNothing);
    await unmount(tester);
  });

  testWidgets('with “open diaries in the editor” on, More keeps share, export '
      'and writing a comment', (tester) async {
    await prepare(comments: true, openInEditor: true);
    await openEditor(tester);
    final l10n = l10nOf(tester);

    await tester.tap(find.byTooltip(l10n.autoT0125));
    await tester.pumpAndSettle();
    expect(menuItem(l10n.diaryReadingEditInfo), findsOneWidget);
    expect(menuItem(l10n.previewShare), findsOneWidget);
    expect(menuItem(l10n.previewExport), findsOneWidget);
    expect(menuItem(l10n.diaryCommentSheetNew), findsOneWidget);
    // AI 不可用时没有 AI 回应。
    expect(menuItem(l10n.aiReplyMoreItem), findsNothing);

    // 菜单里的分享与顶栏同一个面板。
    await tester.tap(menuItem(l10n.previewShare));
    await tester.pumpAndSettle();
    expect(find.byType(ExpressiveMenuItem), findsNothing);
    expect(find.byType(DiaryShareTextPreview), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('AI actions sit together in an AI submenu', (tester) async {
    await prepare(openInEditor: true);
    await openEditor(tester, ai: true);
    final l10n = l10nOf(tester);

    await tester.tap(find.byTooltip(l10n.autoT0125));
    await tester.pumpAndSettle();
    // 主菜单里只有“AI ›”一行，AI 的各项不平铺。
    expect(menuItem(l10n.diaryReadingAiMenu), findsOneWidget);
    expect(find.text(l10n.aiSlashPrompts), findsNothing);
    expect(find.text(l10n.aiSuggestTitle), findsNothing);
    expect(find.text(l10n.aiReplyMoreItem), findsNothing);
    expect(menuItem(l10n.diaryPreviewStyleMoreEntry), findsNothing);

    await tester.tap(menuItem(l10n.diaryReadingAiMenu));
    await tester.pumpAndSettle();
    expect(menuItem(l10n.aiSlashPrompts), findsOneWidget);
    expect(menuItem(l10n.aiSuggestTitle), findsOneWidget);
    expect(menuItem(l10n.aiSuggestMeta), findsOneWidget);
    // 打开日记时直接编辑：AI 回应也在二级菜单里。
    expect(menuItem(l10n.aiReplyMoreItem), findsOneWidget);
    await unmount(tester);
  });
}
