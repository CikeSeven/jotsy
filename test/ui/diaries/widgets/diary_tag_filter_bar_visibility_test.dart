import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/widgets/diary_tag_filter_bar.dart';
import 'package:node_diary/ui/diaries/widgets/tag_filter_clear_button.dart';

import 'tag_filter_bar_test_support.dart';

/// 一个标签都没有时，标签栏只剩清除叉：整栏收起，有标签或仍有选中的筛选时显示。
void main() {
  final bar = find.byType(DiaryTagFilterBar);
  final clearButton = find.byType(TagFilterClearButton).hitTestable();

  testWidgets('no tags collapses the bar so no lone clear button is left', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      buildTagBarHarness(
        key: GlobalKey<TagBarHarnessState>(),
        tags: const <Tag>[],
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(bar).height, 0);
    expect(clearButton, findsNothing);
    expect(find.bySemanticsLabel('Clear tag filters'), findsNothing);
    semantics.dispose();
  });

  testWidgets('tags keep the clear button even when nothing is selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTagBarHarness(
        key: GlobalKey<TagBarHarnessState>(),
        tags: createTags(2),
      ),
    );
    await tester.pumpAndSettle();

    expect(clearButton, findsOneWidget);
  });

  testWidgets('a selection left without tags still offers the clear button', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTagBarHarness(
        key: GlobalKey<TagBarHarnessState>(),
        tags: const <Tag>[],
        selectedTagIds: const <int>{7},
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(bar).height, greaterThan(0));
    expect(clearButton, findsOneWidget);
  });

  testWidgets('the first tag unfolds the bar instead of popping it in', (
    tester,
  ) async {
    final key = GlobalKey<TagBarHarnessState>();
    await tester.pumpWidget(buildTagBarHarness(key: key, tags: const <Tag>[]));
    await tester.pumpAndSettle();
    expect(tester.getSize(bar).height, 0);

    await tester.pumpWidget(buildTagBarHarness(key: key, tags: createTags(1)));
    await tester.pump(const Duration(milliseconds: 60));
    final midHeight = tester.getSize(bar).height;
    await tester.pumpAndSettle();
    final settledHeight = tester.getSize(bar).height;

    expect(midHeight, greaterThan(0));
    expect(midHeight, lessThan(settledHeight));
    expect(clearButton, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing the last tag folds the bar away', (tester) async {
    final key = GlobalKey<TagBarHarnessState>();
    await tester.pumpWidget(buildTagBarHarness(key: key, tags: createTags(1)));
    await tester.pumpAndSettle();
    final shownHeight = tester.getSize(bar).height;

    await tester.pumpWidget(buildTagBarHarness(key: key, tags: const <Tag>[]));
    await tester.pump(const Duration(milliseconds: 60));
    final midHeight = tester.getSize(bar).height;
    await tester.pumpAndSettle();

    expect(midHeight, greaterThan(0));
    expect(midHeight, lessThan(shownHeight));
    expect(tester.getSize(bar).height, 0);
    expect(clearButton, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
