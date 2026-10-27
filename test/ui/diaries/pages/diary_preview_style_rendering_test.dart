import '../../../support/diary_content_test_helpers.dart';
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_behavior.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_settings.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_style.dart';
import 'package:node_diary/ui/diaries/pages/diary_preview_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_overlays.dart';
import 'package:node_diary/ui/diaries/widgets/publish_diary_cover_sliver.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

var _idSeed = 0;

DiaryWithTags _diary({
  String title = '海边的一天',
  String? cover,
  String content = '[{"insert":"晚霞把整片海都染成了橘色\\n"}]',
  String text = '晚霞把整片海都染成了橘色',
  bool edited = true,
}) {
  final created = DateTime(2025, 3, 2, 9, 30);
  return DiaryWithTags(
    diary: Diary(
      id: _idSeed,
      diaryId: 'preview-style-${_idSeed++}',
      title: title,
      content: content,
      contentText: text,
      metadata:
          '{"context":{"moodEmoji":"😊","energyLevel":4,"location":"西湖","weather":"晴","weatherIconCode":"100"}}',
      cover: cover,
      createdAt: created,
      updatedAt: edited ? created.add(const Duration(days: 1)) : created,
      isArchived: false,
      isPinned: false,
      isDeleted: false,
    ),
    tags: const <Tag>[Tag(id: 1, name: '旅行', color: 0xFF4CAF50)],
  );
}

class _PendingDetailDatabase extends AppDatabase {
  _PendingDetailDatabase() : super.forTesting(NativeDatabase.memory());

  @override
  Future<DiaryWithTags?> getDiaryWithTagsByDiaryId(String diaryId) =>
      Completer<DiaryWithTags?>().future;
}

Future<void> _pump(
  WidgetTester tester, {
  DiaryPreviewStyle style = DiaryPreviewStyle.defaults,
  DiaryPreviewBehavior behavior = DiaryPreviewBehavior.defaults,
  DiaryWithTags? detail,
  Brightness brightness = Brightness.light,
}) async {
  // 同一个用例里多次装配时先卸掉旧树：ProviderScope 与页面状态都要重建，
  // 否则沿用上一次的设置服务。
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
  final encoded = DiaryPreviewSettings(
    current: style,
    behavior: behavior,
  ).encode();
  SharedPreferences.setMockInitialValues(<String, Object>{
    'app.settings.diary_preview_style': ?encoded,
  });
  final settings = await SettingsService.create();
  final database = _PendingDetailDatabase();
  addTearDown(database.close);
  final entry = detail ?? _diary();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        settingsServiceProvider.overrideWith((ref) async => settings),
      ],
      child: MaterialApp(
        theme: expressiveTestTheme(brightness),
        locale: const Locale('zh'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          ...AppLocalizations.localizationsDelegates,
          quill.AppFlowyEditorLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: DiaryPreviewPage(
          diaryId: entry.diary.diaryId,
          initialDetail: entry,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

double _top(WidgetTester tester, Finder finder) =>
    tester.getTopLeft(finder.first).dy;

void main() {
  testWidgets('the default look keeps the original top bar and details', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('日记'), findsOneWidget);
    expect(find.textContaining('发表于'), findsOneWidget);
    expect(find.text('西湖'), findsOneWidget);
    expect(find.text('心情 😊'), findsOneWidget);
    expect(find.textContaining('最后编辑于'), findsOneWidget);
    expect(find.byType(DiaryPreviewProgressLine), findsNothing);
    expect(find.byType(DiaryPreviewBackToTop), findsNothing);
    final bar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
    expect(bar.floating, isTrue);
    expect(bar.pinned, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('details move above the title or after the text', (tester) async {
    await _pump(
      tester,
      style: const DiaryPreviewStyle(
        meta: DiaryPreviewMetaStyle(
          position: DiaryPreviewMetaPosition.aboveTitle,
        ),
      ),
    );
    expect(
      _top(tester, find.text('西湖')),
      lessThan(_top(tester, find.text('海边的一天'))),
    );

    await _pump(
      tester,
      style: const DiaryPreviewStyle(
        meta: DiaryPreviewMetaStyle(position: DiaryPreviewMetaPosition.end),
      ),
    );
    expect(
      _top(tester, find.text('西湖')),
      greaterThan(_top(tester, find.byType(DiaryEditor))),
    );
    expect(
      _top(tester, find.text('西湖')),
      lessThan(_top(tester, find.textContaining('最后编辑于'))),
    );
  });

  testWidgets('detail switches, date format and chip styles apply', (
    tester,
  ) async {
    await _pump(
      tester,
      style: const DiaryPreviewStyle(
        meta: DiaryPreviewMetaStyle(
          showLocation: false,
          showMood: false,
          dateFormat: DiaryCardDateFormat.full,
          dateSource: DiaryCardDateSource.updated,
          tagStyle: DiaryCardTagStyle.plain,
          showWordCount: true,
          showReadingTime: false,
        ),
      ),
    );
    expect(find.text('西湖'), findsNothing);
    expect(find.textContaining('心情'), findsNothing);
    expect(find.text('更新于 2025年3月3日'), findsOneWidget);
    expect(find.text('#旅行'), findsOneWidget);
    expect(find.text('12 字'), findsOneWidget);
  });

  testWidgets('cover modes: inset, hidden and no fallback to body photos', (
    tester,
  ) async {
    // 手机宽度：宽窗口的头图改放进正文列（见 diary_preview_wide_layout_test）。
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const photo = '/missing/photo.png';
    final withCover = _diary(cover: photo);
    await _pump(
      tester,
      detail: withCover,
      style: const DiaryPreviewStyle(
        cover: DiaryPreviewCoverStyle(
          mode: DiaryPreviewCoverMode.inset,
          radius: 20,
          height: 300,
          fit: DiaryPreviewCoverFit.cover,
        ),
      ),
    );
    final sliver = tester.widget<PublishDiaryCoverSliver>(
      find.byType(PublishDiaryCoverSliver),
    );
    expect(sliver.borderRadius, BorderRadius.circular(20));
    expect(sliver.maxExtentHeight, 300);
    expect(sliver.fillFrame, isTrue);

    await _pump(
      tester,
      detail: withCover,
      style: const DiaryPreviewStyle(
        cover: DiaryPreviewCoverStyle(mode: DiaryPreviewCoverMode.hidden),
      ),
    );
    expect(find.byType(PublishDiaryCoverSliver), findsNothing);

    final bodyPhoto = _diary(
      content: '[{"insert":{"image":"$photo"}},{"insert":"\\n图下的文字\\n"}]',
      text: '图下的文字',
    );
    await _pump(tester, detail: bodyPhoto);
    expect(find.byType(PublishDiaryCoverSliver), findsOneWidget);
    await _pump(
      tester,
      detail: bodyPhoto,
      style: const DiaryPreviewStyle(
        cover: DiaryPreviewCoverStyle(useFirstImage: false),
      ),
    );
    expect(find.byType(PublishDiaryCoverSliver), findsNothing);
  });

  testWidgets('the title can hide, drop the untitled placeholder and scale', (
    tester,
  ) async {
    await _pump(
      tester,
      detail: _diary(title: ''),
      style: const DiaryPreviewStyle(
        title: DiaryPreviewTitleStyle(showUntitled: false),
      ),
    );
    expect(find.text('无标题'), findsNothing);

    await _pump(
      tester,
      style: const DiaryPreviewStyle(
        title: DiaryPreviewTitleStyle(
          scale: 1.5,
          weight: DiaryPreviewTitleWeight.regular,
          align: DiaryPreviewAlign.center,
        ),
      ),
    );
    final title = tester.widget<Text>(find.text('海边的一天'));
    expect(title.textAlign, TextAlign.center);
    expect(title.style?.fontWeight, FontWeight.w400);
    final base = Theme.of(
      tester.element(find.text('海边的一天')),
    ).textTheme.headlineSmall!.fontSize!;
    expect(title.style?.fontSize, closeTo(base * 1.5, 0.01));

    await _pump(
      tester,
      style: const DiaryPreviewStyle(
        title: DiaryPreviewTitleStyle(visible: false),
      ),
    );
    expect(find.text('海边的一天'), findsNothing);
  });

  testWidgets('ink paper turns a light app page dark and stays readable', (
    tester,
  ) async {
    await _pump(
      tester,
      style: const DiaryPreviewStyle(
        page: DiaryPreviewPageStyle(paper: DiaryPreviewPaper.ink),
      ),
    );
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, const Color(0xFF1E2126));
    final pageTheme = Theme.of(tester.element(find.text('海边的一天')));
    expect(pageTheme.brightness, Brightness.dark);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a custom text color is used only with enough contrast', (
    tester,
  ) async {
    Color? paragraphColor() => tester
        .widget<DiaryEditor>(find.byType(DiaryEditor))
        .controller
        .state
        .editorStyle
        .textStyleConfiguration
        .text
        .color;

    await _pump(
      tester,
      style: const DiaryPreviewStyle(
        page: DiaryPreviewPageStyle(textLight: 0xFF5A2D0C),
      ),
    );
    expect(paragraphColor(), const Color(0xFF5A2D0C));

    // 浅黄文字压在浅色纸上对比度不足：回退为主题正文色。
    await _pump(
      tester,
      style: const DiaryPreviewStyle(
        page: DiaryPreviewPageStyle(textLight: 0xFFFFF4C2),
      ),
    );
    final theme = Theme.of(tester.element(find.byType(DiaryEditor)));
    expect(paragraphColor(), theme.textTheme.bodyMedium!.color);
  });

  testWidgets('top bar mode, title, buttons and reading aids apply', (
    tester,
  ) async {
    await _pump(
      tester,
      style: const DiaryPreviewStyle(
        page: DiaryPreviewPageStyle(
          topBar: DiaryPreviewTopBarMode.pinned,
          topBarTitle: DiaryPreviewTopBarTitle.none,
          showEditButton: false,
          showShareButton: true,
          progress: DiaryPreviewProgress.line,
          backToTop: true,
        ),
      ),
    );
    final bar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
    expect(bar.pinned, isTrue);
    expect(find.text('日记'), findsNothing);
    expect(find.byTooltip('编辑'), findsNothing);
    expect(find.byTooltip('分享'), findsOneWidget);
    expect(find.byType(DiaryPreviewProgressLine), findsOneWidget);
    expect(find.byType(DiaryPreviewBackToTop), findsOneWidget);
  });

  testWidgets('share sits before edit, and edit stays next to more', (
    tester,
  ) async {
    await _pump(
      tester,
      style: const DiaryPreviewStyle(
        page: DiaryPreviewPageStyle(showShareButton: true),
      ),
    );
    final share = tester.getCenter(find.byTooltip('分享')).dx;
    final edit = tester.getCenter(find.byTooltip('编辑')).dx;
    final more = tester.getCenter(find.byTooltip('更多')).dx;
    expect(share, lessThan(edit));
    expect(edit, lessThan(more));
  });

  testWidgets('the default style hides the word count and reading time', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.textContaining('12 字'), findsNothing);
    expect(find.textContaining('分钟'), findsNothing);

    // 只打开字数：阅读时长仍是关的。
    await _pump(
      tester,
      style: const DiaryPreviewStyle(
        meta: DiaryPreviewMetaStyle(showWordCount: true),
      ),
    );
    expect(find.text('12 字'), findsOneWidget);
    expect(find.textContaining('分钟'), findsNothing);
  });

  testWidgets('reading behavior locks to-dos and text selection', (
    tester,
  ) async {
    await _pump(
      tester,
      behavior: const DiaryPreviewBehavior(
        todoToggle: false,
        textSelection: false,
      ),
    );
    final config = tester.widget<DiaryEditor>(find.byType(DiaryEditor));
    expect(config.todoToggle, isFalse);
    expect(config.textSelection, isFalse);
  });

  testWidgets('the long image behavior reaches the body image builder', (
    tester,
  ) async {
    bool foldsLongImages() =>
        tester.widget<DiaryEditor>(find.byType(DiaryEditor)).foldLongImages;

    await _pump(tester);
    expect(foldsLongImages(), isTrue);

    await _pump(
      tester,
      behavior: const DiaryPreviewBehavior(
        longImageMode: DiaryPreviewLongImageMode.full,
      ),
    );
    expect(foldsLongImages(), isFalse);
  });

  testWidgets('a limited text width centers the text on wide screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(
      tester,
      style: const DiaryPreviewStyle(
        page: DiaryPreviewPageStyle(limitWidth: true, contentWidth: 600),
      ),
    );
    final editor = tester.getRect(find.byType(DiaryEditor));
    expect(editor.width, closeTo(600 - 32, 0.5));
    expect(editor.center.dx, closeTo(500, 0.5));
  });

  testWidgets('changing to a re-themed look keeps the reading position', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = await SettingsService.create();
    final database = _PendingDetailDatabase();
    addTearDown(database.close);
    final long = List<String>.filled(60, '一段很长的正文。').join('\\n');
    final detail = _diary(content: '[{"insert":"$long\\n"}]', text: long);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('zh'),
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            ...AppLocalizations.localizationsDelegates,
            quill.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiaryPreviewPage(
            diaryId: detail.diary.diaryId,
            initialDetail: detail,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    final scrollable = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );
    final before = tester
        .state<ScrollableState>(scrollable.first)
        .position
        .pixels;
    expect(before, greaterThan(0));

    // 设置页那边换成墨色纸 + 进度线：整页换主题，但滚动位置与页面状态保留。
    await settings.setDiaryPreviewStyleRaw(
      const DiaryPreviewSettings(
        current: DiaryPreviewStyle(
          page: DiaryPreviewPageStyle(
            paper: DiaryPreviewPaper.ink,
            progress: DiaryPreviewProgress.line,
          ),
        ),
      ).encode(),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.state<ScrollableState>(scrollable.first).position.pixels,
      before,
    );
    expect(
      Theme.of(tester.element(find.byType(DiaryEditor))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('the first frame already uses the stored look', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.settings.diary_preview_style': const DiaryPreviewSettings(
        current: DiaryPreviewStyle(
          page: DiaryPreviewPageStyle(
            topBarTitle: DiaryPreviewTopBarTitle.none,
          ),
        ),
      ).encode()!,
    });
    final settings = await SettingsService.create();
    final database = _PendingDetailDatabase();
    addTearDown(database.close);
    final detail = _diary();
    late BuildContext navigatorContext;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('zh'),
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            ...AppLocalizations.localizationsDelegates,
            quill.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          // 与应用一致：设置服务在启动时就已就绪，之后才打开预览页。
          home: Consumer(
            builder: (context, ref, _) {
              navigatorContext = context;
              ref.watch(settingsServiceProvider);
              return const Scaffold();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(
      Navigator.of(navigatorContext).push(
        MaterialPageRoute<void>(
          builder: (_) => DiaryPreviewPage(
            diaryId: detail.diary.diaryId,
            initialDetail: detail,
          ),
        ),
      ),
    );
    // 新路由的第一帧先在幕后构建（为共享元素测量），查找时包含幕后部件。
    await tester.pump();
    expect(find.byType(DiaryPreviewPage, skipOffstage: false), findsOneWidget);
    expect(find.byType(SliverAppBar, skipOffstage: false), findsOneWidget);
    expect(find.text('日记', skipOffstage: false), findsNothing);
    await tester.pumpAndSettle();
  });
}
