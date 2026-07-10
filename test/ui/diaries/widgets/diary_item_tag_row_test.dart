import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/widgets/diary_item_tag_row.dart';

const _narrowCardKey = Key('narrow-diary-tag-card');

void main() {
  testWidgets('uses two visible tags by default and summarizes the remainder', (
    tester,
  ) async {
    final tags = _createTags(4);

    await tester.pumpWidget(_buildTestApp(DiaryItemTagRow(tags: tags)));

    expect(_tagLabel('Tag 1'), findsOneWidget);
    expect(_tagLabel('Tag 2'), findsOneWidget);
    expect(_tagLabel('Tag 3'), findsNothing);
    expect(_tagLabel('Tag 4'), findsNothing);
    expect(find.text('+2'), findsOneWidget);
  });

  testWidgets('centers the overflow summary with an adjacent tag', (
    tester,
  ) async {
    final tags = _createTags(4);

    await tester.pumpWidget(_buildTestApp(DiaryItemTagRow(tags: tags)));

    final tagRect = tester.getRect(_tagLabel('Tag 2'));
    final summaryRect = tester.getRect(find.text('+2'));
    expect(summaryRect.center.dy, closeTo(tagRect.center.dy, 0.01));
  });

  testWidgets('uses a custom visible tag limit', (tester) async {
    final tags = _createTags(4);

    await tester.pumpWidget(
      _buildTestApp(DiaryItemTagRow(tags: tags, maxVisibleTags: 3)),
    );

    expect(_tagLabel('Tag 1'), findsOneWidget);
    expect(_tagLabel('Tag 2'), findsOneWidget);
    expect(_tagLabel('Tag 3'), findsOneWidget);
    expect(_tagLabel('Tag 4'), findsNothing);
    expect(find.text('+1'), findsOneWidget);
  });

  testWidgets('hides the entire tag row when the limit is zero', (
    tester,
  ) async {
    final tags = _createTags(2);

    await tester.pumpWidget(
      _buildTestApp(DiaryItemTagRow(tags: tags, maxVisibleTags: 0)),
    );

    expect(_tagLabel('Tag 1'), findsNothing);
    expect(_tagLabel('Tag 2'), findsNothing);
    expect(find.textContaining(RegExp(r'^\+\d+$')), findsNothing);
  });

  testWidgets('treats a negative direct limit as hidden', (tester) async {
    final tags = _createTags(2);

    await tester.pumpWidget(
      _buildTestApp(DiaryItemTagRow(tags: tags, maxVisibleTags: -1)),
    );

    expect(_tagLabel('Tag 1'), findsNothing);
    expect(_tagLabel('Tag 2'), findsNothing);
    expect(find.textContaining(RegExp(r'^\+\d+$')), findsNothing);
  });

  testWidgets(
    'wraps twenty long tags without horizontal overflow in a narrow card',
    (tester) async {
      final tags = _createTags(
        20,
        nameForIndex:
            (index) => 'Long unique tag label $index for a narrow diary card',
      );

      await tester.pumpWidget(
        _buildTestApp(
          SizedBox(
            key: _narrowCardKey,
            width: 150,
            child: DiaryItemTagRow(tags: tags, maxVisibleTags: 20),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final containerRect = tester.getRect(find.byKey(_narrowCardKey));
      final tagRunCenters = <double>{};
      for (final tag in tags) {
        final tagFinder = _tagLabel(tag.name);
        expect(tagFinder, findsOneWidget);

        final tagRect = tester.getRect(tagFinder);
        expect(tagRect.left, greaterThanOrEqualTo(containerRect.left - 0.01));
        expect(tagRect.right, lessThanOrEqualTo(containerRect.right + 0.01));
        tagRunCenters.add(tagRect.center.dy);
      }
      expect(tagRunCenters.length, greaterThan(1));
      expect(find.textContaining(RegExp(r'^\+\d+$')), findsNothing);
    },
  );
}

List<Tag> _createTags(int count, {String Function(int index)? nameForIndex}) {
  return List<Tag>.generate(count, (index) {
    final number = index + 1;
    return Tag(
      id: number,
      name: nameForIndex?.call(number) ?? 'Tag $number',
      color: 0xFF336699,
    );
  });
}

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[child],
      ),
    ),
  );
}

Finder _tagLabel(String label) {
  return find.textContaining(label, findRichText: true);
}
