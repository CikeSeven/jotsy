import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/explore/controllers/explore_module_actions.dart';
import 'package:node_diary/ui/explore/models/explore_appearance.dart';
import 'package:node_diary/ui/explore/models/explore_module_config.dart';
import 'package:node_diary/ui/explore/models/explore_module_data.dart';
import 'package:node_diary/ui/explore/models/explore_module_id.dart';
import 'package:node_diary/ui/explore/models/explore_module_options.dart';
import 'package:node_diary/ui/explore/sections/explore_life_cards.dart';
import 'package:node_diary/ui/explore/widgets/charts/explore_share_bars.dart';
import 'package:node_diary/ui/explore/widgets/explore_appearance_scope.dart';
import 'package:node_diary/ui/explore/widgets/explore_shared_widgets.dart';

import '../../../support/expressive_test_theme.dart';

/// 记下卡片里“打开日记”的动作；其余动作用不到。
class _RecordingActions extends ExploreModuleActions {
  final List<(String, List<String>?)> opened = <(String, List<String>?)>[];

  @override
  void openDiary(String diaryId, {List<String>? sequence}) =>
      opened.add((diaryId, sequence));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  const labels = <String>['Sunny', 'Cloudy', 'Rain', 'Snow', 'Fog', 'Wind'];

  List<ExploreGroupCount> weather(int count) => <ExploreGroupCount>[
    for (var i = 0; i < count; i++)
      ExploreGroupCount(
        label: labels[i],
        count: count - i,
        diaryIds: <String>['${labels[i]}-a', '${labels[i]}-b'],
      ),
  ];

  Future<_RecordingActions> pumpCard(
    WidgetTester tester, {
    required List<ExploreGroupCount> groups,
    double width = 360,
    ExploreWeatherStyle style = ExploreWeatherStyle.grid,
  }) async {
    final actions = _RecordingActions();
    tester.view.physicalSize = Size(width, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ExploreActionsScope(
              actions: actions,
              child: ExploreWeatherCard(
                config: ExploreModuleConfig(
                  ExploreModuleId.weather,
                  visible: true,
                ).withOption(ExploreOptions.weatherStyle, style.name),
                groups: groups,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return actions;
  }

  /// 一格的位置：天气名所在的那块可点按区域。
  Rect tile(WidgetTester tester, String label) => tester.getRect(
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first,
  );

  /// 卡片内容区（去掉默认内边距）。
  Rect content(WidgetTester tester) => tester
      .getRect(find.byType(ExploreCard))
      .deflate(ExploreAppearance.defaults.cardPadding);

  group('ExploreWeatherCard icon grid', () {
    testWidgets('tiles stretch so each full row reaches the right edge', (
      tester,
    ) async {
      // 内容宽 324：一行最多放 3 格，5 种天气均分成 3 + 2 两行。
      await pumpCard(tester, groups: weather(5));
      final inner = content(tester);
      final first = tile(tester, 'Sunny');
      final third = tile(tester, 'Rain');
      final fourth = tile(tester, 'Snow');
      expect(first.left, moreOrLessEquals(inner.left));
      expect(third.right, moreOrLessEquals(inner.right));
      expect(third.top, first.top);
      expect(first.width, moreOrLessEquals((inner.width - 8 * 2) / 3));
      // 第二行从左边起，格宽与第一行相同。
      expect(fourth.left, moreOrLessEquals(inner.left));
      expect(fourth.top, greaterThan(first.bottom));
      expect(fourth.width, moreOrLessEquals(first.width));
      expect(tile(tester, 'Fog').top, fourth.top);
    });

    testWidgets('a few weather types split the whole row between them', (
      tester,
    ) async {
      await pumpCard(tester, groups: weather(2));
      final inner = content(tester);
      final first = tile(tester, 'Sunny');
      final second = tile(tester, 'Cloudy');
      expect(first.left, moreOrLessEquals(inner.left));
      expect(second.right, moreOrLessEquals(inner.right));
      expect(second.top, first.top);
      expect(first.width, moreOrLessEquals(second.width));
    });

    testWidgets('a wider card fits more tiles per row', (tester) async {
      // 内容宽 564：一行最多 6 格，6 种天气排成一行。
      await pumpCard(tester, groups: weather(6), width: 600);
      final inner = content(tester);
      expect(tile(tester, 'Wind').top, tile(tester, 'Sunny').top);
      expect(tile(tester, 'Wind').right, moreOrLessEquals(inner.right));
    });

    testWidgets('tapping a tile opens that weather\'s diaries', (tester) async {
      final actions = await pumpCard(tester, groups: weather(3));
      await tester.tap(find.text('Cloudy'));
      await tester.pump();
      final (diaryId, sequence) = actions.opened.single;
      expect(diaryId, 'Cloudy-a');
      expect(sequence, <String>['Cloudy-a', 'Cloudy-b']);
    });

    testWidgets('stays inside a narrow card with large text', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpCard(tester, groups: weather(6), width: 120);
      expect(tester.takeException(), isNull);
      // 放不下两格时每行一格，铺满内容宽度。
      final inner = content(tester);
      expect(tile(tester, 'Sunny').width, moreOrLessEquals(inner.width));
    });
  });

  testWidgets('the ranking style still lists share bars', (tester) async {
    await pumpCard(
      tester,
      groups: weather(3),
      style: ExploreWeatherStyle.ranking,
    );
    expect(find.byType(ExploreShareBars), findsOneWidget);
    expect(find.text('Sunny'), findsOneWidget);
  });
}
