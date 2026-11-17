import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/controllers/diary_create_entry_flow.dart';
import 'package:node_diary/ui/diaries/controllers/diary_create_morph.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/providers/diary_draft_providers.dart';
import 'package:node_diary/ui/diaries/widgets/draft_count_badge.dart';
import 'package:node_diary/ui/widgets/container_transform/morph_anchor.dart';
import 'package:node_diary/ui/widgets/container_transform/morph_landing.dart';
import 'package:node_diary/ui/widgets/container_transform/morph_page_route.dart';

import '../../../support/diary_drafts_harness.dart';

/// 从新建按钮展开编辑页；返回时写了东西落进草稿箱角标（份数 +1），没写
/// 回到新建按钮。
void main() {
  const createKey = ValueKey<String>('create');
  const badgeKey = ValueKey<String>('drafts_badge');

  Future<void> pumpHome(DiaryDraftsHarness harness, {bool withAnchor = true}) {
    return harness.pump(
      Consumer(
        builder: (context, ref, _) {
          final count = ref.watch(diaryDraftCountProvider).value ?? 0;
          final button = FloatingActionButton(
            key: createKey,
            heroTag: null,
            onPressed: () =>
                runDiaryCreateEntryFlow(context, ref, fromCreateButton: true),
            child: const Icon(Icons.add),
          );
          return Scaffold(
            appBar: AppBar(
              actions: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: DraftCountBadge(
                    key: badgeKey,
                    count: count,
                    child: const Icon(Icons.edit_note, size: 18),
                  ),
                ),
              ],
            ),
            floatingActionButton: withAnchor
                ? MorphAnchor(
                    tag: DiaryCreateMorph.createButton,
                    borderRadius: 16,
                    color: Colors.teal,
                    appearance: const Icon(Icons.add),
                    child: button,
                  )
                : button,
          );
        },
      ),
    );
  }

  Route<Object?> editorRoute(WidgetTester tester) => ModalRoute.of(
    tester.element(find.byType(EditDiaryPage, skipOffstage: false)),
  )!;

  Future<void> openEditor(
    WidgetTester tester,
    DiaryDraftsHarness harness,
  ) async {
    await tester.tap(find.byKey(createKey));
    await harness.settle();
    await tester.pumpAndSettle();
    expect(find.byType(EditDiaryPage), findsOneWidget);
  }

  /// 返回，直到量出落点。
  Future<MorphLandingSession> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pump();
    final session = MorphLandingSession.current.value!;
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    return session;
  }

  Finder badgeLabel(String text) =>
      find.descendant(of: find.byKey(badgeKey), matching: find.text(text));

  testWidgets('the create button opens the editor by growing out of it', (
    tester,
  ) async {
    final harness = await DiaryDraftsHarness.create(tester);
    await pumpHome(harness);

    await openEditor(tester, harness);

    expect(editorRoute(tester), isA<MorphPageRoute<Object?>>());
    await harness.unmount();
  });

  testWidgets('without a visible create button it opens as a plain page', (
    tester,
  ) async {
    final harness = await DiaryDraftsHarness.create(tester);
    await pumpHome(harness, withAnchor: false);

    await openEditor(tester, harness);

    expect(editorRoute(tester), isNot(isA<MorphPageRoute<Object?>>()));
    await harness.unmount();
  });

  testWidgets('leaving with words drops into the drafts badge, then +1', (
    tester,
  ) async {
    final harness = await DiaryDraftsHarness.create(tester);
    await pumpHome(harness);
    await openEditor(tester, harness);

    await tester.enterText(find.byType(TextField).first, '没写完的');
    await tester.pump();
    final session = await back(tester);
    expect(session.targets(DiaryCreateMorph.draftsBadge), isTrue);

    // 草稿在收回途中写进库，角标仍扣着旧份数（0：不显示）。
    await harness.settle();
    expect((await harness.drafts()).single.title, '没写完的');
    expect(badgeLabel('1'), findsNothing);

    await tester.pumpAndSettle();
    expect(session.phase.value, MorphLandingPhase.landed);
    expect(find.byType(EditDiaryPage), findsNothing);
    expect(badgeLabel('1'), findsOneWidget);
    await harness.unmount();
  });

  testWidgets('leaving untouched shrinks back into the create button', (
    tester,
  ) async {
    final harness = await DiaryDraftsHarness.create(tester);
    await pumpHome(harness);
    await openEditor(tester, harness);

    final session = await back(tester);
    expect(session.involves(DiaryCreateMorph.draftsBadge), isFalse);
    expect(session.targets(DiaryCreateMorph.createButton), isTrue);
    await tester.pumpAndSettle();
    await harness.settle();
    expect(await harness.drafts(), isEmpty);
    await harness.unmount();
  });
}
