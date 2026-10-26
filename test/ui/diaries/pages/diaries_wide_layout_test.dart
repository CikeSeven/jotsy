import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/pages/diary_preview_page.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';
import 'package:node_diary/ui/diaries/widgets/diary_detail_pane/diary_detail_pane.dart';
import 'package:node_diary/ui/diaries/widgets/diary_tag_filter_bar.dart';

import 'diaries_wide_test_support.dart';

void main() {
  testWidgets(
    'a medium window centres the list column at 720 and opens the full preview',
    (tester) async {
      await pumpWideDiariesPage(
        tester,
        size: const Size(900, 700),
        diaries: <DiaryWithTags>[
          for (var index = 0; index < 6; index++) wideDiary('medium', index),
        ],
      );

      // 刊头与标签栏跟内容列对齐：900 宽里每侧补 90，列宽 720。
      final head = tester.getRect(find.byType(DiaryHeadSection));
      expect(head.left, 90);
      expect(head.width, 720);
      final tagBar = tester.getRect(find.byType(DiaryTagFilterBar));
      expect(tagBar.left, 90);
      expect(tagBar.width, 720);

      // 单栏：没有右栏。
      expect(find.byType(DiaryDetailPane), findsNothing);

      // 卡片在内容列里，保留自己的左右边距且居中。
      final card = tester.getRect(wideListCards.first);
      expect(card.left, greaterThan(90));
      expect(card.right, lessThan(810));
      expect(card.left - 90, closeTo(810 - card.right, 0.01));
      expect(card.width, lessThanOrEqualTo(720));

      // 单栏：点卡片照旧推入完整的预览页。
      await tester.tap(wideCard('medium title 0'));
      await tester.pumpAndSettle();
      expect(find.byType(DiaryPreviewPage), findsOneWidget);

      await unmountWideDiariesPage(tester);
    },
  );

  testWidgets('a phone window keeps the full-width list', (tester) async {
    await pumpWideDiariesPage(
      tester,
      size: const Size(400, 860),
      diaries: <DiaryWithTags>[
        for (var index = 0; index < 4; index++) wideDiary('phone', index),
      ],
    );

    expect(find.byType(DiaryDetailPane), findsNothing);
    final head = tester.getRect(find.byType(DiaryHeadSection));
    expect(head.left, 0);
    expect(head.width, 400);
    final card = tester.getRect(wideListCards.first);
    expect(card.left, closeTo(400 - card.right, 0.01));
    expect(card.width, greaterThan(360));

    await tester.tap(wideCard('phone title 0'));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryPreviewPage), findsOneWidget);

    await unmountWideDiariesPage(tester);
  });
}
