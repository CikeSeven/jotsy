import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/device_auth_service.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_style.dart';
import 'package:node_diary/ui/diaries/pages/diary_preview_page.dart';
import 'package:node_diary/ui/diaries/pages/diary_search_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_chips.dart';

import '../../../support/diary_drafts_harness.dart';
import '../../../support/expressive_test_theme.dart';
import '../../notebooks/notebook_test_support.dart';

/// 预览页信息栏的标签：点按打开搜索页并选中这个标签；三种标签样式都可点，
/// 可点与不可点时排布相同（设置页预览不传点按）。
void main() {
  const tag = DiaryPreviewChipItem(
    kind: DiaryPreviewChipKind.tag,
    label: '旅行',
    tagColor: 0xFF4CAF50,
    tagId: 7,
  );

  Future<void> pumpChip(
    WidgetTester tester,
    DiaryCardTagStyle style, {
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        home: Scaffold(
          body: Center(
            child: DiaryPreviewChip(item: tag, tagStyle: style, onTap: onTap),
          ),
        ),
      ),
    );
  }

  for (final style in DiaryCardTagStyle.values) {
    testWidgets('a ${style.name} tag is tappable without changing its size', (
      tester,
    ) async {
      await pumpChip(tester, style);
      final chip = find.byType(DiaryPreviewChip);
      final size = tester.getSize(chip);
      expect(
        find.descendant(of: chip, matching: find.byType(InkWell)),
        findsNothing,
      );

      var taps = 0;
      await pumpChip(tester, style, onTap: () => taps++);
      expect(tester.getSize(chip), size);
      await tester.tap(find.textContaining('旅行'));
      expect(taps, 1);
    });
  }

  testWidgets('tapping a tag in the preview opens the search for it', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    final sea = (await tester.runAsync(
      () => h.database.createTag(name: '海边', color: 0xFF2196F3),
    ))!;
    final diary = (await tester.runAsync(
      () => h.database.createDiary(
        title: '在海边',
        contentDocJson: '[{"insert":"正文\\n"}]',
        contentText: '正文',
        metadataJson: '{}',
        tagIds: <int>[sea],
      ),
    ))!;
    await h.pump(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DiaryPreviewPage(diaryId: diary),
                ),
              ),
              child: const Text('home'),
            ),
          ),
        ),
      ),
      overrides: [
        deviceAuthServiceProvider.overrideWithValue(FakeDeviceAuth()),
      ],
    );
    await tester.tap(find.text('home'));
    await h.settleAll();

    await tester.tap(
      find.descendant(
        of: find.byType(DiaryPreviewChip),
        matching: find.text('海边'),
      ),
    );
    await h.settleAll();

    final search = tester.widget<DiarySearchPage>(find.byType(DiarySearchPage));
    expect(search.initialTagIds, <int>{sea});
    expect(search.scope, DiaryListScope.all);
    await h.unmount();
  });
}
