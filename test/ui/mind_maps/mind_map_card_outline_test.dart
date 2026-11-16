import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_codec.dart';
import 'package:node_diary/core/database/mind_map/mind_map_blocks.dart';
import 'package:node_diary/core/database/mind_map/mind_map_document.dart';
import 'package:node_diary/core/database/mind_map/mind_map_text.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_card_resolved_style.dart';
import 'package:node_diary/ui/diaries/widgets/diary_card/diary_card.dart';
import 'package:node_diary/ui/mind_maps/widgets/mind_map_card_outline.dart';
import 'package:node_diary/ui/mind_maps/widgets/mind_map_thumbnail.dart';

import '../../support/expressive_test_theme.dart';

/// 列表卡片上的导图日记：摘要是大纲（没有缩略图与底板），中心主题是标题；
/// 窄卡片、大字号下不溢出。
void main() {
  var nextId = 0;

  DiaryWithTags mindMapDiary(String outline, {String? title}) {
    final map = MindMapDocument.blank().copyWith(
      root: mindMapNodeFromOutline(outline)!,
    );
    nextId++;
    return DiaryWithTags(
      diary: Diary(
        id: nextId,
        diaryId: 'map-$nextId',
        title: title ?? map.root.text,
        content: encodeDiaryBlocks(mindMapDiaryDocument(map)),
        contentText: mindMapPlainText(map),
        metadata: '{}',
        createdAt: DateTime(2026, 11, 16),
        updatedAt: DateTime(2026, 11, 16),
        isArchived: false,
        isPinned: false,
        isDeleted: false,
      ),
      tags: const <Tag>[],
    );
  }

  Future<void> pumpCard(
    WidgetTester tester,
    DiaryWithTags diary, {
    DiaryCardMode mode = DiaryCardMode.list,
    double width = 400,
    double textScale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    final theme = expressiveTestTheme(brightness);
    final resolved = DiaryCardResolvedStyle.resolve(
      style: DiaryCardStyle.defaults,
      mode: mode,
      theme: theme,
      screenWidth: width,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: width,
                child: DiaryCard(
                  diary: diary,
                  resolved: resolved,
                  selected: false,
                  isSelectionMode: false,
                  maxVisibleTags: 3,
                  enableCoverHero: false,
                  onOpenEditor: (_, _, _) {},
                  onToggleSelection: (_, _) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a mind map diary card shows its topics as an outline under the '
      'central topic, without a thumbnail', (tester) async {
    await pumpCard(
      tester,
      mindMapDiary(
        'Trip\n'
        '  Packing\n'
        '    Passport\n'
        '    Charger\n'
        '    Tickets\n'
        '    Snacks\n'
        '  Route\n'
        '  Budget',
      ),
    );

    expect(find.byType(MindMapThumbnail), findsNothing);
    expect(find.byType(MindMapCardOutline), findsOneWidget);
    // 默认列表样式摘要 2 行 → 大纲 6 行：先放满一级主题，再按先序放子主题，
    // 放不下的（Snacks）不出现。
    expect(find.text('Trip'), findsOneWidget);
    for (final topic in <String>[
      'Packing',
      'Passport',
      'Charger',
      'Tickets',
      'Route',
      'Budget',
    ]) {
      expect(find.text(topic), findsOneWidget);
    }
    expect(find.text('Snacks'), findsNothing);
    // 子主题缩进在一级主题的文字起点上。
    final packing = tester.getTopLeft(find.text('Packing'));
    final passport = tester.getTopLeft(find.text('Passport'));
    expect(passport.dx, greaterThan(packing.dx));
    expect(
      tester.getTopLeft(find.text('Route')).dx,
      moreOrLessEquals(packing.dx),
    );
  });

  testWidgets('a mind map without a central topic text is titled Untitled, '
      'not after its first topic', (tester) async {
    await pumpCard(tester, mindMapDiary('_\n  Alpha\n  Beta', title: ''));

    expect(find.text('Untitled'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
  });

  testWidgets('narrow cards with large text do not overflow in either theme '
      'or layout', (tester) async {
    final diary = mindMapDiary(
      'A very long central topic that keeps going on and on\n'
      '  ${'Long first-level topic ' * 6}\n'
      '    ${'Deep child topic ' * 6}\n'
      '      ${'Even deeper topic ' * 6}\n'
      '  Second',
    );
    for (final mode in DiaryCardMode.values) {
      for (final brightness in Brightness.values) {
        await pumpCard(
          tester,
          diary,
          mode: mode,
          width: mode == DiaryCardMode.list ? 320 : 160,
          textScale: 1.3,
          brightness: brightness,
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(MindMapCardOutline), findsOneWidget);
      }
    }
  });
}
