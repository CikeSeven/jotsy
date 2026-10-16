import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style.dart';
import 'package:node_diary/ui/diaries/sections/diaries_list_section.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';
import 'package:node_diary/ui/widgets/image_viewer_hero.dart';

import '../../../support/expressive_test_theme.dart';

var _idSeed = 0;

/// 每个用例用新的 id：卡片派生数据按 (diaryId, updatedAt) 全局缓存。
DiaryWithTags _diary({
  String title = '卡片标题',
  String text = '正文摘要的内容',
  String? cover,
  List<String> images = const <String>[],
  String metadata = '{"context":{"moodEmoji":"😊","weatherIconCode":"100"}}',
  bool pinned = false,
  bool locked = false,
  List<Tag> tags = const <Tag>[Tag(id: 1, name: '生活', color: 0xFF4CAF50)],
}) {
  final now = DateTime.now();
  final id = 'style_${_idSeed++}';
  final embeds = images.map((image) => '{"insert":{"image":"$image"}},').join();
  return DiaryWithTags(
    diary: Diary(
      id: _idSeed,
      diaryId: id,
      title: title,
      content: '[$embeds{"insert":"$text\\n"}]',
      contentText: text,
      metadata: metadata,
      cover: cover,
      createdAt: DateTime(2026, 3, 2, 9, 30),
      updatedAt: DateTime(2026, 3, 2, 9, 30),
      isArchived: false,
      isPinned: pinned,
      isDeleted: false,
      capsuleLockedAt: locked ? now : null,
      capsuleUnlockAt: locked ? now.add(const Duration(days: 30)) : null,
    ),
    tags: tags,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required List<DiaryWithTags> diaries,
  DiaryCardStyle style = DiaryCardStyle.defaults,
  DiaryLayoutMode layout = DiaryLayoutMode.list,
  Set<String> selected = const <String>{},
  bool selectionMode = false,
  bool opensLockedCapsulePage = true,
  void Function(DiaryWithTags diary)? onOpen,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(Brightness.light),
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CustomScrollView(
          slivers: <Widget>[
            DiariesListSection(
              diaries: diaries,
              layoutMode: layout,
              selectedDiaryIds: selected,
              isSelectionMode: selectionMode,
              maxVisibleTags: 3,
              onCreate: () {},
              onOpenEditor: (diary, _) => onOpen?.call(diary),
              onToggleSelection: (_, _) {},
              cardStyle: style,
              opensLockedCapsulePage: opensLockedCapsulePage,
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

DiaryCardStyle _listMode(DiaryCardModeStyle Function(DiaryCardModeStyle) f) =>
    DiaryCardStyle.defaults.withMode(
      DiaryCardMode.list,
      f(DiaryCardModeStyle.listDefaults),
    );

Finder _icon(FaIconData icon) => find.byWidgetPredicate(
  (widget) => widget is FaIcon && widget.icon?.codePoint == icon.codePoint,
);

void main() {
  group('cover positions', () {
    testWidgets('end cover sits after the text', (tester) async {
      await _pump(
        tester,
        diaries: <DiaryWithTags>[_diary(cover: '/cover.png')],
        style: _listMode(
          (m) => m.copyWith(coverPosition: DiaryCardCoverPosition.end),
        ),
      );
      expect(tester.takeException(), isNull);
      final image = tester.getRect(find.byType(Image));
      final title = tester.getRect(find.text('卡片标题'));
      expect(image.left, greaterThan(title.right));
      expect(
        tester.widget<ImageHero>(find.byType(ImageHero)).borderRadius,
        BorderRadius.circular(16),
      );
    });

    testWidgets('top cover spans the card with top-rounded corners', (
      tester,
    ) async {
      await _pump(
        tester,
        diaries: <DiaryWithTags>[_diary(cover: '/cover.png')],
        style: _listMode(
          (m) => m.copyWith(coverPosition: DiaryCardCoverPosition.top),
        ),
      );
      expect(tester.takeException(), isNull);
      final image = tester.getRect(find.byType(Image));
      final title = tester.getRect(find.text('卡片标题'));
      expect(image.height, 160);
      expect(image.bottom, lessThanOrEqualTo(title.top));
      expect(
        tester.widget<ImageHero>(find.byType(ImageHero)).borderRadius,
        const BorderRadius.vertical(top: Radius.circular(24)),
      );
    });

    testWidgets('inset top cover keeps its own rounded corners', (
      tester,
    ) async {
      await _pump(
        tester,
        diaries: <DiaryWithTags>[_diary(cover: '/cover.png')],
        style: _listMode(
          (m) => m.copyWith(
            coverPosition: DiaryCardCoverPosition.top,
            coverInset: true,
            coverRadius: 10,
          ),
        ),
      );
      expect(
        tester.widget<ImageHero>(find.byType(ImageHero)).borderRadius,
        BorderRadius.circular(10),
      );
    });

    testWidgets('background cover puts the text on a panel over the photo', (
      tester,
    ) async {
      await _pump(
        tester,
        diaries: <DiaryWithTags>[_diary(cover: '/cover.png')],
        style: _listMode(
          (m) => m.copyWith(coverPosition: DiaryCardCoverPosition.background),
        ),
      );
      expect(tester.takeException(), isNull);
      final image = tester.getRect(find.byType(Image));
      final title = tester.getRect(find.text('卡片标题'));
      expect(image.height, greaterThanOrEqualTo(160));
      expect(image.contains(title.center), isTrue);
    });

    testWidgets('hidden cover renders no image', (tester) async {
      await _pump(
        tester,
        diaries: <DiaryWithTags>[_diary(cover: '/cover.png')],
        style: _listMode(
          (m) => m.copyWith(coverPosition: DiaryCardCoverPosition.hidden),
        ),
      );
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('collage shows three photos with one shared element', (
      tester,
    ) async {
      final style = _listMode(
        (m) => m.copyWith(coverPosition: DiaryCardCoverPosition.top),
      );
      await _pump(
        tester,
        diaries: <DiaryWithTags>[
          _diary(images: const <String>['/a.png', '/b.png', '/c.png']),
        ],
        style: style.copyWith(content: style.content.copyWith(collage: true)),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(Image), findsNWidgets(3));
      expect(find.byType(ImageHero), findsOneWidget);
    });

    testWidgets('placeholders fill the cover spot without a photo', (
      tester,
    ) async {
      await _pump(
        tester,
        diaries: <DiaryWithTags>[_diary()],
        style: DiaryCardStyle.defaults.copyWith(
          content: const DiaryCardContentStyle(
            coverFallback: DiaryCardCoverFallback.dateBlock,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('2'), findsOneWidget);
      expect(find.byType(ImageHero), findsNothing);

      await _pump(
        tester,
        diaries: <DiaryWithTags>[_diary()],
        style: DiaryCardStyle.defaults.copyWith(
          content: const DiaryCardContentStyle(
            coverFallback: DiaryCardCoverFallback.moodTile,
          ),
        ),
      );
      // 印章里一个、心情块里一个。
      expect(find.text('😊'), findsNWidgets(2));
    });

    testWidgets('mood and weather can sit on the cover', (tester) async {
      final style = _listMode(
        (m) => m.copyWith(metaPosition: DiaryCardMetaPosition.cover),
      );
      await _pump(
        tester,
        diaries: <DiaryWithTags>[_diary(cover: '/cover.png')],
        style: style,
      );
      final cover = tester.getRect(find.byType(Image));
      expect(cover.contains(tester.getCenter(find.text('😊'))), isTrue);

      // 没有封面时回到眉线。
      await _pump(tester, diaries: <DiaryWithTags>[_diary()], style: style);
      final eyebrow = tester.getRect(find.text('3月2日 · 周一'));
      expect(
        (tester.getCenter(find.text('😊')).dy - eyebrow.center.dy).abs(),
        lessThan(4),
      );
    });
  });

  group('content', () {
    testWidgets('block order changes the vertical order', (tester) async {
      await _pump(
        tester,
        diaries: <DiaryWithTags>[_diary()],
        style: DiaryCardStyle.defaults.copyWith(
          content: const DiaryCardContentStyle(
            blocks: <DiaryCardBlock>[
              DiaryCardBlock.preview,
              DiaryCardBlock.title,
              DiaryCardBlock.eyebrow,
              DiaryCardBlock.tags,
              DiaryCardBlock.footer,
            ],
          ),
        ),
      );
      final preview = tester.getRect(find.text('正文摘要的内容'));
      final title = tester.getRect(find.text('卡片标题'));
      final date = tester.getRect(find.text('3月2日 · 周一'));
      expect(preview.top, lessThan(title.top));
      expect(title.top, lessThan(date.top));
    });

    testWidgets('a hidden title moves the selection mark to the date line', (
      tester,
    ) async {
      final diary = _diary();
      await _pump(
        tester,
        diaries: <DiaryWithTags>[diary],
        style: DiaryCardStyle.defaults.copyWith(
          content: const DiaryCardContentStyle(showTitle: false),
        ),
        selected: <String>{diary.diary.diaryId},
        selectionMode: true,
      );
      expect(find.text('卡片标题'), findsNothing);
      final mark = tester.getCenter(_icon(FontAwesomeIcons.solidCircleCheck));
      final date = tester.getRect(find.text('3月2日 · 周一'));
      expect((mark.dy - date.center.dy).abs(), lessThan(6));
    });

    testWidgets('hiding title and date keeps the mark as an overlay', (
      tester,
    ) async {
      final diary = _diary(metadata: '{}');
      await _pump(
        tester,
        diaries: <DiaryWithTags>[diary],
        style: DiaryCardStyle.defaults.copyWith(
          content: const DiaryCardContentStyle(showTitle: false),
          meta: const DiaryCardMetaStyle(showDate: false),
        ),
        selected: <String>{diary.diary.diaryId},
        selectionMode: true,
      );
      expect(tester.takeException(), isNull);
      expect(_icon(FontAwesomeIcons.solidCircleCheck), findsOneWidget);
    });

    testWidgets('untitled entries show the placeholder by default', (
      tester,
    ) async {
      await _pump(tester, diaries: <DiaryWithTags>[_diary(title: '  ')]);
      expect(find.text('无标题'), findsOneWidget);
    });

    testWidgets('without the placeholder only untitled entries lose the line', (
      tester,
    ) async {
      final untitled = _diary(title: '');
      await _pump(
        tester,
        diaries: <DiaryWithTags>[untitled, _diary()],
        style: DiaryCardStyle.defaults.copyWith(
          content: const DiaryCardContentStyle(showUntitled: false),
        ),
        selected: <String>{untitled.diary.diaryId},
        selectionMode: true,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('无标题'), findsNothing);
      expect(find.text('卡片标题'), findsOneWidget);
      // 没有标题行的那篇把选择标记挂到日期行，且只有一个（不再叠加浮层）。
      final mark = tester.getCenter(_icon(FontAwesomeIcons.solidCircleCheck));
      final date = tester.getRect(find.text('3月2日 · 周一').first);
      expect((mark.dy - date.center.dy).abs(), lessThan(6));
    });

    testWidgets(
      'an untitled entry without a date line keeps the overlay mark',
      (tester) async {
        final diary = _diary(title: '', metadata: '{}');
        await _pump(
          tester,
          diaries: <DiaryWithTags>[diary],
          style: DiaryCardStyle.defaults.copyWith(
            content: const DiaryCardContentStyle(showUntitled: false),
            meta: const DiaryCardMetaStyle(showDate: false),
          ),
          selected: <String>{diary.diary.diaryId},
          selectionMode: true,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('无标题'), findsNothing);
        expect(_icon(FontAwesomeIcons.solidCircleCheck), findsOneWidget);
      },
    );

    testWidgets('locked capsules keep the untitled placeholder', (
      tester,
    ) async {
      await _pump(
        tester,
        diaries: <DiaryWithTags>[_diary(title: '', locked: true)],
        style: DiaryCardStyle.defaults.copyWith(
          content: const DiaryCardContentStyle(showUntitled: false),
        ),
      );
      expect(find.text('无标题'), findsOneWidget);
    });

    testWidgets('footer extras show location, word count and media', (
      tester,
    ) async {
      await _pump(
        tester,
        diaries: <DiaryWithTags>[
          _diary(
            text: '一二三四五',
            images: const <String>['/a.png', '/b.png'],
            metadata:
                '{"context":{"location":"西湖","energyLevel":3,"moodEmoji":"😊"}}',
          ),
        ],
        style: DiaryCardStyle.defaults.copyWith(
          meta: const DiaryCardMetaStyle(
            showLocation: true,
            showEnergy: true,
            showWordCount: true,
            showMedia: true,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('西湖'), findsOneWidget);
      expect(find.text('5 字'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(_icon(FontAwesomeIcons.locationDot), findsOneWidget);
    });

    testWidgets('tag styles change the chip decoration', (tester) async {
      Finder chipContainers() => find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).color ==
                const Color(0xFF4CAF50).withValues(alpha: 0.08),
      );
      await _pump(tester, diaries: <DiaryWithTags>[_diary()]);
      expect(chipContainers(), findsOneWidget);
      await _pump(
        tester,
        diaries: <DiaryWithTags>[_diary()],
        style: DiaryCardStyle.defaults.copyWith(
          content: const DiaryCardContentStyle(
            tagStyle: DiaryCardTagStyle.plain,
          ),
        ),
      );
      expect(chipContainers(), findsNothing);
      expect(find.textContaining('生活', findRichText: true), findsOneWidget);
    });
  });

  group('surface', () {
    BoxDecoration surfaceDecoration(WidgetTester tester, DiaryWithTags diary) =>
        tester
                .widget<Container>(
                  find.byKey(
                    ValueKey<String>(
                      'diary_selection_surface_${diary.diary.diaryId}',
                    ),
                  ),
                )
                .decoration!
            as BoxDecoration;

    testWidgets('gradient and accent strip appear only when enabled', (
      tester,
    ) async {
      var diary = _diary();
      await _pump(tester, diaries: <DiaryWithTags>[diary]);
      expect(surfaceDecoration(tester, diary).gradient, isNull);
      expect(surfaceDecoration(tester, diary).color, isNotNull);

      diary = _diary();
      await _pump(
        tester,
        diaries: <DiaryWithTags>[diary],
        style: const DiaryCardStyle(
          surface: DiaryCardSurfaceStyle(
            gradient: true,
            accentBar: DiaryCardAccentBar.start,
            accentWidth: 5,
          ),
        ),
      );
      final decoration = surfaceDecoration(tester, diary);
      expect(decoration.gradient, isA<LinearGradient>());
      expect(decoration.color, isNull);
      final strip = find.byWidgetPredicate(
        (widget) =>
            widget is PositionedDirectional &&
            widget.width == 5 &&
            widget.child is ColoredBox,
      );
      expect(strip, findsOneWidget);
    });

    testWidgets('a zero-width border draws no outline at rest', (tester) async {
      final diary = _diary();
      await _pump(
        tester,
        diaries: <DiaryWithTags>[diary],
        style: const DiaryCardStyle(
          surface: DiaryCardSurfaceStyle(borderWidth: 0),
        ),
      );
      final surface = tester.widget<Container>(
        find.byKey(
          ValueKey<String>('diary_selection_surface_${diary.diary.diaryId}'),
        ),
      );
      expect((surface.foregroundDecoration! as BoxDecoration).border, isNull);
    });

    testWidgets('locked capsules ignore mood colors and stay sealed', (
      tester,
    ) async {
      final diary = _diary(
        locked: true,
        text: 'hidden content',
        metadata: '{"context":{"moodEmoji":"😭"}}',
      );
      await _pump(
        tester,
        diaries: <DiaryWithTags>[diary],
        style: const DiaryCardStyle(
          surface: DiaryCardSurfaceStyle(
            background: DiaryCardColorSpec(
              source: DiaryCardColorSource.mood,
              strength: 1,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('hidden content'), findsNothing);
      final context = tester.element(find.byType(DiariesListSection));
      expect(
        surfaceDecoration(tester, diary).color,
        Theme.of(context).colorScheme.surfaceContainerLowest,
      );
    });

    testWidgets('preview capsules open through the callback, not a page', (
      tester,
    ) async {
      final diary = _diary(locked: true);
      DiaryWithTags? opened;
      await _pump(
        tester,
        diaries: <DiaryWithTags>[diary],
        opensLockedCapsulePage: false,
        onOpen: (value) => opened = value,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(DiariesListSection),
          matching: find.byType(InkWell),
        ),
      );
      await tester.pumpAndSettle();
      expect(opened, same(diary));
    });
  });

  testWidgets('waterfall honors the column count and side margin', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final diaries = <DiaryWithTags>[_diary(), _diary(), _diary()];
    await _pump(
      tester,
      diaries: diaries,
      layout: DiaryLayoutMode.waterfall,
      style: DiaryCardStyle.defaults.withMode(
        DiaryCardMode.waterfall,
        DiaryCardModeStyle.waterfallDefaults.copyWith(
          columns: 3,
          sideMargin: 20,
          cardGap: 10,
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final rects = <Rect>[
      for (final diary in diaries)
        tester.getRect(
          find.byKey(
            ValueKey<String>('diary_selection_surface_${diary.diary.diaryId}'),
          ),
        ),
    ];
    expect(rects.first.left, 20);
    expect(rects.map((rect) => rect.top.round()).toSet(), hasLength(1));
    expect(rects[1].left - rects[0].right, closeTo(10, 0.01));
  });
}
