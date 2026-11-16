import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_codec.dart';
import 'package:node_diary/core/database/mind_map/mind_map_blocks.dart';
import 'package:node_diary/core/database/mind_map/mind_map_document.dart';
import 'package:node_diary/core/database/mind_map/mind_map_text.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_detail_pane/diary_detail_pane.dart';
import 'package:node_diary/ui/mind_maps/widgets/mind_map_workspace.dart';

import 'diaries_wide_test_support.dart';

/// 宽窗口双栏：导图日记没有预览，点按卡片不在右栏阅读，直接推入编辑页；
/// 文字日记照常在右栏阅读。
void main() {
  DiaryWithTags mindMapDiary() {
    final map = MindMapDocument.blank().copyWith(
      root: mindMapNodeFromOutline('Plan\n  Work\n  Rest')!,
    );
    final base = wideDiary('map', 1).diary;
    return DiaryWithTags(
      diary: base.copyWith(
        title: 'Plan',
        content: encodeDiaryBlocks(mindMapDiaryDocument(map)),
        contentText: mindMapPlainText(map),
      ),
      tags: const <Tag>[],
    );
  }

  Finder inPane(String text) => find.descendant(
    of: find.byType(DiaryDetailPane),
    matching: find.text(text),
  );

  testWidgets('in two panes a mind map diary opens the editor instead of the '
      'reading pane', (tester) async {
    await pumpWideDiariesPage(
      tester,
      size: const Size(1280, 800),
      diaries: <DiaryWithTags>[wideDiary('map', 0), mindMapDiary()],
    );

    await tester.tap(wideCard('map title 0'));
    await tester.pumpAndSettle();
    expect(inPane('map title 0'), findsOneWidget);
    expect(find.byType(EditDiaryPage), findsNothing);

    await tester.tap(wideCard('Plan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(EditDiaryPage), findsOneWidget);
    expect(find.byType(MindMapWorkspace), findsOneWidget);

    await unmountWideDiariesPage(tester);
  });
}
