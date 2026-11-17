import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/device_auth_service.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/notebooks/providers/home_notebook_scope_provider.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_header_card.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_switcher/notebook_deck.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_switcher/notebook_switcher_indicator.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_switcher_chip.dart';

import '../../support/diary_drafts_harness.dart';
import 'notebook_test_support.dart';

/// 首页日记本卡组：右滑拉出（跟手、阈值、松手）、点切换胶囊打开、点选与
/// 拖选切换、返回收起、子本展开、上锁验证。
void main() {
  Future<DiaryDraftsHarness> pumpHome(
    WidgetTester tester, {
    Future<void> Function(DiaryDraftsHarness h)? seed,
    FakeDeviceAuth? auth,
    bool listLayout = false,
    bool notebooksOff = false,
  }) async {
    // 手机竖屏：卡组贴左缘、竖直居中。
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await DiaryDraftsHarness.create(tester);
    if (listLayout) await h.settings.setDiaryLayoutModeRaw('list');
    if (notebooksOff) {
      await h.settings.setAppFeaturesRaw('{"notebooks":false}');
    }
    await seed?.call(h);
    await h.pump(
      const DiariesPage(),
      overrides: [
        deviceAuthServiceProvider.overrideWithValue(auth ?? FakeDeviceAuth()),
      ],
    );
    await h.settleAll();
    return h;
  }

  HomeNotebookScope scopeOf(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(DiariesPage)),
  ).read(homeNotebookScopeProvider);

  Future<void> seedTwo(DiaryDraftsHarness h) async {
    final travel = await h.notebook('旅行');
    await h.notebook('读书');
    await h.diary('在京都', notebookIds: <String>[travel]);
    await h.diary('上班路上');
  }

  /// 从列表中间往右拉 [distance]，分几步移动；[release] 为 false 时不松手。
  Future<TestGesture> pull(
    WidgetTester tester,
    double distance, {
    bool release = true,
  }) async {
    final gesture = await tester.startGesture(const Offset(60, 420));
    const steps = 12;
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(Offset(distance / steps, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    if (release) {
      await gesture.up();
    }
    return gesture;
  }

  testWidgets('tapping the chip opens the deck and a card switches scope', (
    tester,
  ) async {
    final h = await pumpHome(tester, seed: seedTwo);
    expect(find.byType(NotebookDeck), findsNothing);
    await tester.tap(find.byType(NotebookSwitcherChip));
    await h.settleAll();
    expect(find.byType(NotebookDeck), findsOneWidget);
    expect(deckCard('全部日记'), findsOneWidget);
    expect(deckCard('未收录'), findsOneWidget);
    expect(deckCard('旅行'), findsOneWidget);
    expect(deckCard('读书'), findsOneWidget);

    await tester.tap(deckCard('旅行'));
    await h.settleAll();
    expect(find.byType(NotebookDeck), findsNothing);
    expect(scopeOf(tester).notebookId, isNotNull);
    expect(find.byType(NotebookHeaderCard), findsOneWidget);
    expect(find.text('在京都'), findsOneWidget);
    expect(find.text('上班路上'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(NotebookSwitcherChip),
        matching: find.text('旅行'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await h.unmount();
  });

  testWidgets('a short right pull shows the edge pill and springs back', (
    tester,
  ) async {
    final h = await pumpHome(tester, seed: seedTwo);
    final gesture = await pull(tester, 40, release: false);
    expect(find.byType(NotebookSwitcherIndicator), findsOneWidget);
    await gesture.up();
    await h.settleAll();
    expect(find.byType(NotebookSwitcherIndicator), findsNothing);
    expect(find.byType(NotebookDeck), findsNothing);
    expect(scopeOf(tester).isAll, isTrue);
    await h.unmount();
  });

  testWidgets('pulling past the threshold opens the deck on release', (
    tester,
  ) async {
    final h = await pumpHome(tester, seed: seedTwo);
    await pull(tester, 90);
    await h.settleAll();
    expect(find.byType(NotebookDeck), findsOneWidget);
    await tester.tap(deckCard('读书'));
    await h.settleAll();
    expect(find.byType(NotebookDeck), findsNothing);
    expect(find.text('这本还空着'), findsOneWidget);
    await h.unmount();
  });

  testWidgets('a left pull does not open the deck', (tester) async {
    final h = await pumpHome(tester, seed: seedTwo);
    final gesture = await tester.startGesture(const Offset(300, 420));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byType(NotebookSwitcherIndicator), findsNothing);
    await gesture.up();
    await h.settleAll();
    expect(find.byType(NotebookDeck), findsNothing);
    await h.unmount();
  });

  testWidgets('pulling all the way open then sliding down picks a card', (
    tester,
  ) async {
    final h = await pumpHome(tester, seed: seedTwo);
    final gesture = await pull(tester, 320, release: false);
    await h.tester.pumpAndSettle();
    expect(find.byType(NotebookDeck), findsOneWidget);
    // 手指不松：先在卡组外竖着挪一点进入拖选（此时没有卡片被抬起），
    // 再移到“旅行”那张的顶条上。悬停的卡片抬起后下面的卡片会让位，所以
    // 目标在它被抬起之前量好、一步移过去。
    final target = tester.getCenter(deckCard('旅行'));
    await gesture.moveBy(const Offset(0, 24));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveTo(target);
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await h.settleAll();
    expect(find.byType(NotebookDeck), findsNothing);
    expect(find.text('在京都'), findsOneWidget);
    expect(find.text('上班路上'), findsNothing);
    await h.unmount();
  });

  testWidgets('in list layout cards hand right drags to the deck', (
    tester,
  ) async {
    final h = await pumpHome(tester, seed: seedTwo, listLayout: true);
    final card = tester.getCenter(find.text('上班路上'));
    final gesture = await tester.startGesture(card);
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(12, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await h.settleAll();
    expect(find.byType(NotebookDeck), findsOneWidget);
    expect(await systemBackLeavesApp(tester), isFalse);
    await h.settleAll();
    expect(find.byType(NotebookDeck), findsNothing);

    // 左滑仍是卡片的归档。
    await tester.drag(find.text('上班路上'), const Offset(-300, 0));
    await h.settleAll();
    expect(find.byType(NotebookDeck), findsNothing);
    expect(find.text('上班路上'), findsNothing);
    await h.unmount();
  });

  testWidgets('the pull does nothing while notebooks are off', (tester) async {
    final h = await pumpHome(tester, seed: seedTwo, notebooksOff: true);
    final gesture = await pull(tester, 120, release: false);
    expect(find.byType(NotebookSwitcherIndicator), findsNothing);
    await gesture.up();
    await h.settleAll();
    expect(find.byType(NotebookDeck), findsNothing);
    await h.unmount();
  });

  testWidgets('the pull does nothing while selecting diaries', (tester) async {
    final h = await pumpHome(tester, seed: seedTwo);
    await tester.longPress(find.text('上班路上'));
    await h.settleAll();
    final gesture = await pull(tester, 120, release: false);
    expect(find.byType(NotebookSwitcherIndicator), findsNothing);
    await gesture.up();
    await h.settleAll();
    expect(find.byType(NotebookDeck), findsNothing);
    await h.unmount();
  });

  testWidgets('back closes the deck first and keeps the scope', (tester) async {
    final h = await pumpHome(tester, seed: seedTwo);
    await tester.tap(find.byType(NotebookSwitcherChip));
    await h.settleAll();
    expect(find.byType(NotebookDeck), findsOneWidget);
    expect(await systemBackLeavesApp(tester), isFalse);
    await h.settleAll();
    expect(find.byType(NotebookDeck), findsNothing);
    expect(scopeOf(tester).isAll, isTrue);
    await h.unmount();
  });

  testWidgets('tapping the scrim closes the deck', (tester) async {
    final h = await pumpHome(tester, seed: seedTwo);
    await tester.tap(find.byType(NotebookSwitcherChip));
    await h.settleAll();
    await tester.tapAt(const Offset(390, 400));
    await h.settleAll();
    expect(find.byType(NotebookDeck), findsNothing);
    expect(scopeOf(tester).isAll, isTrue);
    await h.unmount();
  });

  testWidgets('a parent card unfolds its sub-notebooks in the deck', (
    tester,
  ) async {
    final h = await pumpHome(
      tester,
      seed: (h) async {
        final travel = await h.notebook('旅行');
        final japan = await h.notebook('日本', parentId: travel);
        await h.diary('在京都', notebookIds: <String>[japan]);
        await h.diary('上班路上');
      },
    );
    await tester.tap(find.byType(NotebookSwitcherChip));
    await h.settleAll();
    expect(deckCard('日本'), findsNothing);
    await tester.tap(find.bySemanticsLabel('展开 1 本子日记本'));
    await h.settleAll();
    expect(deckCard('日本'), findsOneWidget);
    await tester.tap(deckCard('日本'));
    await h.settleAll();
    expect(find.text('在京都'), findsOneWidget);
    expect(find.text('上班路上'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(NotebookSwitcherChip),
        matching: find.text('日本'),
      ),
      findsOneWidget,
    );
    await h.unmount();
  });

  testWidgets('a denied locked notebook keeps the deck open', (tester) async {
    final auth = FakeDeviceAuth(results: <bool>[false, true]);
    final h = await pumpHome(
      tester,
      auth: auth,
      seed: (h) async {
        final vault = await h.notebook(
          '保险箱',
          visibility: NotebookVisibility.locked,
        );
        await h.diary('秘密', notebookIds: <String>[vault]);
        await h.diary('上班路上');
      },
    );
    await pickFromDeck(h, '保险箱');
    expect(auth.reasons, <String>['解锁「保险箱」']);
    expect(find.byType(NotebookDeck), findsOneWidget);
    expect(scopeOf(tester).isAll, isTrue);

    await pickFromDeck(h, '保险箱');
    expect(find.byType(NotebookDeck), findsNothing);
    expect(find.text('秘密'), findsOneWidget);
    await h.unmount();
  });
}
