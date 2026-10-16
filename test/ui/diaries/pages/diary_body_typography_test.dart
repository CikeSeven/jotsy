import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/diary_preview_page.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/sections/diary_typography_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

/// 正文段落实际使用的 Quill 样式。
quill.DefaultTextBlockStyle _paragraph(WidgetTester tester) => tester
    .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
    .config
    .customStyles!
    .paragraph!;

/// 正文基础样式必须来自主题，而不是 MaterialApp 的兜底样式（红色等宽粗体，
/// 页面 State 的 context 位于 Scaffold 之上时会取到它）。
void _expectThemeBodyStyle(WidgetTester tester, TextStyle style) {
  final theme = Theme.of(tester.element(find.byType(quill.QuillEditor)));
  expect(style.debugLabel, isNot(contains('fallback style')));
  expect(style.color, theme.textTheme.bodyMedium!.color);
  expect(style.fontWeight, isNot(FontWeight.w900));
}

/// 详情查询不返回，页面始终按入口数据渲染，避免数据库计时器干扰。
class _PendingDetailDatabase extends AppDatabase {
  _PendingDetailDatabase() : super.forTesting(NativeDatabase.memory());

  @override
  Future<DiaryWithTags?> getDiaryWithTagsByDiaryId(String diaryId) =>
      Completer<DiaryWithTags?>().future;
}

void main() {
  late SettingsService settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    settings = await SettingsService.create();
  });

  Widget app(Brightness brightness, AppDatabase database, Widget home) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        settingsServiceProvider.overrideWith((ref) async => settings),
      ],
      child: MaterialApp(
        theme: expressiveTestTheme(brightness),
        locale: const Locale('zh'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          ...AppLocalizations.localizationsDelegates,
          quill.FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'the editor body follows the typography in ${brightness.name}',
      (tester) async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        final diaryId = await database.createDiary(
          title: '标题',
          contentDocJson: '[{"insert":"正文\\n"}]',
          contentText: '正文',
          metadataJson: '{}',
        );
        tester.view.physicalSize = const Size(400, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        // 与应用一致：编辑页经 MaterialPageRoute 打开，位于 Scaffold 之外。
        await tester.pumpWidget(
          app(
            brightness,
            database,
            Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => EditDiaryPage(diaryId: diaryId),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        _expectThemeBodyStyle(tester, _paragraph(tester).style);
        expect(_paragraph(tester).style.fontFamily, 'HarmonyOSSansSC');
        expect(_paragraph(tester).style.fontSize, 16);

        // 设置变化即时作用到已打开的编辑页，标题跟随字体。
        await settings.setDiaryTypography(
          const DiaryTypography().copyWith(
            fontId: DiaryTypography.systemFontId,
            fontSize: 20,
            paragraphSpacing: 8,
          ),
        );
        await tester.pumpAndSettle();
        expect(_paragraph(tester).style.fontSize, 20);
        expect(_paragraph(tester).style.fontFamily, 'sans-serif');
        expect(_paragraph(tester).verticalSpacing.bottom, 8);
        _expectThemeBodyStyle(tester, _paragraph(tester).style);
        // 发布面板也显示标题，按标题输入框的控制器定位编辑区里的那一个。
        final title = tester.widget<TextField>(
          find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.controller?.text == '标题' &&
                widget.maxLength == 200,
          ),
        );
        expect(title.style?.fontFamily, 'sans-serif');

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await database.close();
        await tester.pump(Duration.zero);
      },
    );

    testWidgets('the preview body uses the typography and the quick panel in '
        '${brightness.name}', (tester) async {
      final database = _PendingDetailDatabase();
      addTearDown(database.close);
      final now = DateTime(2026, 10, 14, 9);
      final detail = DiaryWithTags(
        diary: Diary(
          id: 1,
          diaryId: 'typography-1',
          title: '海边日落',
          content: '[{"insert":"晚霞把整片海都染成了橘色\\n"}]',
          contentText: '晚霞把整片海都染成了橘色',
          metadata: '{}',
          createdAt: now,
          updatedAt: now,
          isArchived: false,
          isPinned: false,
          isDeleted: false,
        ),
        tags: const <Tag>[],
      );
      await settings.setDiaryTypography(
        const DiaryTypography().copyWith(fontSize: 18, lineHeight: 2),
      );
      await tester.pumpWidget(
        app(
          brightness,
          database,
          DiaryPreviewPage(diaryId: 'typography-1', initialDetail: detail),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = tester.element(find.byType(DiaryPreviewPage)).l10n;

      _expectThemeBodyStyle(tester, _paragraph(tester).style);
      expect(_paragraph(tester).style.fontSize, 18);
      expect(_paragraph(tester).style.height, 2);

      await tester.tap(find.byTooltip(l10n.diaryTypographyQuickTooltip));
      await tester.pumpAndSettle();
      expect(find.byType(DiaryTypographySheet), findsOneWidget);
      await tester.tap(
        find.byTooltip(
          l10n.diaryTypographyIncrease(l10n.diaryTypographyFontSize),
        ),
      );
      await tester.pumpAndSettle();

      // 面板后方的正文随之重排。
      expect(settings.diaryTypography.fontSize, 19);
      expect(_paragraph(tester).style.fontSize, 19);
    });
  }
}
