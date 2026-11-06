import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/theme.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_mood_palette.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_behavior.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_style.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_preview_resolved_style.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_preview_view_data.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_content.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_header.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_neighbors.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_surface.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_top_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _appSeed = Color(SettingsService.defaultThemeSeedColorValue);

DiaryWithTags _detail() {
  final created = DateTime(2025, 9, 3, 9, 30);
  return DiaryWithTags(
    diary: Diary(
      id: 1,
      diaryId: 'long-image-capture',
      title: '仪仗方队',
      content: '[{"insert":"陆军方队\\n海军方队\\n空军方队\\n"}]',
      contentText: '陆军方队\n海军方队\n空军方队',
      metadata: '{}',
      createdAt: created,
      updatedAt: created,
      isArchived: false,
      isPinned: false,
      isDeleted: false,
    ),
    tags: const <Tag>[],
  );
}

/// 有上一篇、下一篇的翻页位置（正文末尾会显示两张导航卡片）。
DiaryPreviewPaging _paging() {
  return DiaryPreviewPaging(
    position: '2 / 3',
    positionSemantics: '第 2 篇，共 3 篇',
    previous: DiaryPreviewNeighbor(title: '上一篇的标题', onOpen: () {}),
    next: DiaryPreviewNeighbor(title: '下一篇的标题', onOpen: () {}),
  );
}

/// 装配一篇预览内容；[capturing] 对应预览页截取分享长图的那段时间。
Future<void> _pump(
  WidgetTester tester, {
  required bool capturing,
  DiaryPreviewTopBarMode topBar = DiaryPreviewTopBarMode.pinned,
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final settings = await SettingsService.create();
  final detail = _detail();
  final body = DiaryEditorController(
    document: diaryEditorDocument(detail.diary.content),
    selection: af.Selection.single(path: <int>[0], startOffset: 0),
    readOnly: true,
  );
  addTearDown(body.dispose);
  final scroll = ScrollController();
  addTearDown(scroll.dispose);
  final theme = buildSeededAppTheme(_appSeed, Brightness.light);
  final style = DiaryPreviewStyle.defaults.copyWith(
    page: DiaryPreviewStyle.defaults.page.copyWith(topBar: topBar),
    navigation: DiaryPreviewStyle.defaults.navigation.copyWith(
      neighborCards: true,
    ),
  );
  final resolved = DiaryPreviewResolvedStyle.resolve(
    style: style,
    appTheme: theme,
    appSeed: _appSeed,
    screenSize: const Size(400, 800),
    reduceMotion: false,
    moodPalette: DiaryMoodPalette.defaults,
  );
  void ignore() {}
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsServiceProvider.overrideWith((ref) async => settings),
      ],
      child: MaterialApp(
        theme: theme,
        locale: const Locale('zh'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          ...AppLocalizations.localizationsDelegates,
          af.AppFlowyEditorLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: DiaryPreviewSurface(
          resolved: resolved,
          scrollController: scroll,
          content: DiaryPreviewContent(
            detail: detail,
            viewData: DiaryPreviewViewData.resolve(detail.diary),
            controller: body,
            scrollController: scroll,
            resolved: resolved,
            behavior: DiaryPreviewBehavior.defaults,
            capturingLongImage: capturing,
            paging: _paging(),
            onOpenImage: (_, _, hero) => hero?.dispose(),
            actions: DiaryPreviewActions(
              onOpenTypography: ignore,
              onEdit: ignore,
              onShare: ignore,
              onMore: ignore,
              onBack: ignore,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the reading page keeps its top bar and neighbor cards', (
    tester,
  ) async {
    await _pump(tester, capturing: false);

    expect(find.byType(DiaryPreviewTopBar), findsOneWidget);
    expect(find.byType(SliverAppBar), findsOneWidget);
    expect(
      find.byType(DiaryPreviewNeighborCards, skipOffstage: false),
      findsOneWidget,
    );
  });

  for (final mode in DiaryPreviewTopBarMode.values) {
    testWidgets('capturing the long image leaves out the ${mode.name} top bar '
        'and the neighbor cards', (tester) async {
      await _pump(tester, capturing: true, topBar: mode);

      // 顶栏一旦在截图边界里，常驻时每屏都截到、拼接后会在长图中间
      // 再出现一次；截图期间根本不建。
      expect(find.byType(DiaryPreviewTopBar), findsNothing);
      expect(find.byType(SliverAppBar), findsNothing);
      expect(find.byTooltip('返回'), findsNothing);
      expect(
        find.byType(DiaryPreviewNeighborCards, skipOffstage: false),
        findsNothing,
      );
      // 日记本身照常在：标题从图片顶端排起，上方只留一小段边距（没有
      // 状态栏与顶栏的高度）。
      expect(find.byType(DiaryPreviewTitle), findsOneWidget);
      expect(tester.getTopLeft(find.text('仪仗方队')).dy, lessThan(40));
      expect(find.text('陆军方队', findRichText: true), findsOneWidget);
    });
  }
}
