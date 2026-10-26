import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/diaries/pages/diary_preview_page.dart';
import 'package:node_diary/ui/diaries/pages/locked_diary_page.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';
import 'package:node_diary/ui/diaries/widgets/diary_card/diary_card_reading_ring.dart';
import 'package:node_diary/ui/diaries/widgets/diary_detail_pane/diary_detail_pane.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_view.dart';
import 'package:node_diary/ui/widgets/empty_hint.dart';

import 'diaries_wide_test_support.dart';

Finder _inPane(Finder finder) =>
    find.descendant(of: find.byType(DiaryDetailPane), matching: finder);

/// 标题为 [title] 的卡片外的阅读环是否处于选中。
bool _ringActive(WidgetTester tester, String title) => tester
    .widget<DiaryCardReadingRing>(
      find
          .ancestor(
            of: find.text(title),
            matching: find.byType(DiaryCardReadingRing),
          )
          .first,
    )
    .active;

List<DiaryWithTags> _diaries(String prefix, {int count = 5}) => <DiaryWithTags>[
  for (var index = 0; index < count; index++) wideDiary(prefix, index),
];

AppLocalizations _l10n(WidgetTester tester) =>
    tester.element(find.byType(DiariesPage)).l10n;

void main() {
  testWidgets('an expanded window shows the list and an empty detail pane', (
    tester,
  ) async {
    await pumpWideDiariesPage(
      tester,
      size: const Size(1280, 800),
      diaries: _diaries('panes'),
    );
    final l10n = _l10n(tester);

    // 左栏：38% 的 1280 为 486.4，夹到 440；里面与同宽的手机一样。
    expect(find.byType(DiaryDetailPane), findsOneWidget);
    final head = tester.getRect(find.byType(DiaryHeadSection));
    expect(head.left, 0);
    expect(head.width, 440);
    final card = tester.getRect(wideListCards.first);
    expect(card.right, lessThan(440));

    // 右栏：上、右、下各留 12，左侧紧挨左栏；启动时不自动选中。
    final pane = tester.getRect(
      find
          .descendant(
            of: find.byType(DiaryDetailPane),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(pane.left, 440);
    expect(pane.top, 12);
    expect(pane.right, 1280 - 12);
    expect(pane.bottom, 800 - 12);
    expect(_inPane(find.byType(EmptyHint)), findsOneWidget);
    expect(find.text(l10n.diaryDetailPaneEmpty), findsOneWidget);
    // 手机平台上不提示桌面快捷键。
    expect(find.textContaining('Ctrl+N'), findsNothing);

    await unmountWideDiariesPage(tester);
  });

  testWidgets('on desktop the empty pane also suggests Ctrl+N', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await pumpWideDiariesPage(
        tester,
        size: const Size(1280, 800),
        diaries: _diaries('desktop-empty'),
      );
      final l10n = _l10n(tester);
      expect(
        _inPane(
          find.text(
            '${l10n.diaryDetailPaneEmpty}\n'
            '${l10n.diaryDetailPaneCreateHint('Ctrl+N')}',
          ),
        ),
        findsOneWidget,
      );
      await unmountWideDiariesPage(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('clicking a card reads it in the pane without pushing a route', (
    tester,
  ) async {
    await pumpWideDiariesPage(
      tester,
      size: const Size(1280, 800),
      diaries: _diaries('click'),
    );

    await tester.tap(wideCard('click title 1'));
    await tester.pumpAndSettle();

    expect(find.byType(DiaryPreviewPage), findsNothing);
    expect(_inPane(find.byType(DiaryPreviewView)), findsOneWidget);
    expect(_inPane(find.text('click title 1')), findsOneWidget);
    // 右栏顶栏没有返回按钮，也没有“日记”标题。
    expect(_inPane(find.byTooltip(_l10n(tester).commonBack)), findsNothing);
    expect(_inPane(find.text(_l10n(tester).autoT0120)), findsNothing);
    expect(_ringActive(tester, 'click title 1'), isTrue);
    expect(_ringActive(tester, 'click title 0'), isFalse);

    // 换一篇：右栏跟着换，环也跟着换。
    await tester.tap(wideCard('click title 3'));
    await tester.pumpAndSettle();
    expect(_inPane(find.text('click title 3')), findsOneWidget);
    expect(_inPane(find.text('click title 1')), findsNothing);
    expect(_ringActive(tester, 'click title 3'), isTrue);
    expect(_ringActive(tester, 'click title 1'), isFalse);

    await unmountWideDiariesPage(tester);
  });

  testWidgets('a sealed capsule opens its sealed page in the pane', (
    tester,
  ) async {
    await pumpWideDiariesPage(
      tester,
      size: const Size(1280, 800),
      diaries: <DiaryWithTags>[
        wideDiary('capsule', 0),
        wideDiary(
          'capsule',
          1,
          unlockAt: DateTime.now().add(const Duration(days: 30)),
        ),
      ],
    );

    await tester.tap(wideCard('capsule title 1'));
    await tester.pumpAndSettle();

    expect(find.byType(DiaryPreviewPage), findsNothing);
    expect(_inPane(find.byType(LockedDiaryPage)), findsOneWidget);
    expect(_inPane(find.textContaining('capsule body 1')), findsNothing);
    expect(_inPane(find.byTooltip(_l10n(tester).commonBack)), findsNothing);

    await unmountWideDiariesPage(tester);
  });

  testWidgets(
    'deleting the read entry moves the selection on and offers undo',
    (tester) async {
      final store = await pumpWideDiariesPage(
        tester,
        size: const Size(1280, 800),
        diaries: _diaries('delete', count: 3),
      );
      final l10n = _l10n(tester);

      await tester.tap(wideCard('delete title 1'));
      await tester.pumpAndSettle();

      await tester.tap(_inPane(find.byTooltip(l10n.autoT0125)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.commonDelete));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(l10n.commonDelete),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(store.deleted, <String>{'delete-1'});
      // 选中移到下一篇，右栏没有推入或退出路由。
      expect(_inPane(find.text('delete title 2')), findsOneWidget);
      expect(find.byType(DiaryDetailPane), findsOneWidget);
      expect(find.text(l10n.autoT0075), findsOneWidget);

      await tester.tap(find.text(l10n.commonUndo));
      await tester.pumpAndSettle();
      expect(store.restored, <String>{'delete-1'});
      expect(store.deleted, isEmpty);
      // 撤销只恢复日记，选中不跳回去。
      expect(_inPane(find.text('delete title 2')), findsOneWidget);

      await unmountWideDiariesPage(tester);
    },
  );

  testWidgets('deleting the last entry moves the selection back', (
    tester,
  ) async {
    final store = await pumpWideDiariesPage(
      tester,
      size: const Size(1280, 800),
      diaries: _diaries('last', count: 2),
    );
    final l10n = _l10n(tester);

    await tester.tap(wideCard('last title 1'));
    await tester.pumpAndSettle();
    await tester.tap(_inPane(find.byTooltip(l10n.autoT0125)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.commonDelete));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(l10n.commonDelete),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(store.deleted, <String>{'last-1'});
    expect(_inPane(find.text('last title 0')), findsOneWidget);

    await unmountWideDiariesPage(tester);
  });

  testWidgets('the selection clears when the entry leaves the list', (
    tester,
  ) async {
    final store = await pumpWideDiariesPage(
      tester,
      size: const Size(1280, 800),
      diaries: _diaries('leave', count: 3),
    );

    await tester.tap(wideCard('leave title 0'));
    await tester.pumpAndSettle();
    expect(_inPane(find.text('leave title 0')), findsOneWidget);

    // 别处删掉了它（如多选删除）：列表推送新数据后右栏回到空状态。
    store.softDelete('leave-0');
    await tester.pumpAndSettle();
    expect(_inPane(find.byType(EmptyHint)), findsOneWidget);

    await unmountWideDiariesPage(tester);
  });

  testWidgets('switching to the waterfall keeps reading the same entry', (
    tester,
  ) async {
    await pumpWideDiariesPage(
      tester,
      size: const Size(1280, 800),
      diaries: _diaries('layout'),
    );
    final l10n = _l10n(tester);

    await tester.tap(wideCard('layout title 2'));
    await tester.pumpAndSettle();

    // 左栏刊头的“更多”（不是右栏顶栏的）→ 瀑布流。
    await tester.tap(
      find.descendant(
        of: find.byType(DiaryHeadSection),
        matching: find.byTooltip(l10n.autoT0125),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.autoT0147));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.byType(SliverMasonryGrid), findsOneWidget);
    expect(_inPane(find.text('layout title 2')), findsOneWidget);
    expect(_ringActive(tester, 'layout title 2'), isTrue);

    await unmountWideDiariesPage(tester);
  });

  testWidgets(
    'shrinking the window hides the selection and widening shows it again',
    (tester) async {
      await pumpWideDiariesPage(
        tester,
        size: const Size(1280, 800),
        diaries: _diaries('resize'),
      );

      await tester.tap(wideCard('resize title 2'));
      await tester.pumpAndSettle();
      expect(_inPane(find.text('resize title 2')), findsOneWidget);

      tester.view.physicalSize = const Size(900, 800);
      await tester.pumpAndSettle();
      expect(find.byType(DiaryDetailPane), findsNothing);
      // 不自动推入预览页。
      expect(find.byType(DiaryPreviewPage), findsNothing);

      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpAndSettle();
      expect(_inPane(find.text('resize title 2')), findsOneWidget);
      expect(_ringActive(tester, 'resize title 2'), isTrue);

      await unmountWideDiariesPage(tester);
    },
  );
}
