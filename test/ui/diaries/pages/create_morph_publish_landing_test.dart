import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_create_morph.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/pages/publish_diary_page.dart';
import 'package:node_diary/ui/widgets/container_transform/morph_anchor.dart';
import 'package:node_diary/ui/widgets/container_transform/morph_landing.dart';
import 'package:node_diary/ui/widgets/container_transform/morph_page_route.dart';
import 'package:node_diary/ui/widgets/list_item_presence.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';
import '../../../support/publish_panel_driver.dart';

/// 从新建按钮展开编辑页 → 发表 → 返回：整页落进列表里的新卡片，原有的
/// 卡片同时从原位置让位滑下去，新卡片不再另外“长高”出现。
void main() {
  testWidgets('a published diary lands in the list while the list makes room', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final settings = await SettingsService.create();
    await tester.runAsync(
      () => database.createDiary(
        title: 'Earlier note',
        contentDocJson: '[{"insert":"before\\n"}]',
        contentText: 'before',
        metadataJson: '{}',
      ),
    );
    Future<void> Function()? createAction;
    final theme = expressiveTestTheme(Brightness.light);
    Finder inList(String text) => find.descendant(
      of: find.byType(DiariesPage),
      matching: find.text(text),
    );

    Future<void> drain([int rounds = 1]) async {
      for (var i = 0; i < rounds; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
        child: MaterialApp(
          theme: theme,
          locale: const Locale('en'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            quill.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiariesPage(
              pageBackgroundColor: theme.colorScheme.surface,
              onCreateActionChanged: (action) => createAction = action,
            ),
            floatingActionButton: MorphAnchor(
              tag: DiaryCreateMorph.createButton,
              borderRadius: 16,
              color: theme.colorScheme.primaryContainer,
              appearance: const Icon(Icons.add),
              child: FloatingActionButton(
                heroTag: null,
                onPressed: () => createAction?.call(),
                child: const Icon(Icons.add),
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 10 && inList('Earlier note').evaluate().isEmpty; i++) {
      await drain();
    }
    Offset earlierAt() => tester.getTopLeft(inList('Earlier note'));
    final earlierBefore = earlierAt();

    await tester.tap(find.byType(FloatingActionButton));
    await drain(3);
    await tester.pumpAndSettle();
    expect(
      ModalRoute.of(tester.element(find.byType(EditDiaryPage))),
      isA<MorphPageRoute<Object?>>(),
    );

    await tester.enterText(find.byType(TextField).first, 'Sunset by the sea');
    await tester.pump();
    final l10n = tester.element(find.byType(EditDiaryPage)).l10n;
    await tester.tap(find.widgetWithText(FilledButton, l10n.autoT0136));
    await tester.pump();
    await PublishPanelDriver(tester).waitUntilPublished();
    await tester.pumpAndSettle();
    expect(find.byType(PublishDiaryPage), findsOneWidget);
    await drain(3);

    await tester.binding.handlePopRoute();
    MorphLandingSession? session;
    for (var i = 0; i < 20 && session == null; i++) {
      await drain();
      session = MorphLandingSession.current.value;
    }
    expect(session, isNotNull);
    expect(session!.candidates.single, isA<MorphLiveLanding>());
    for (var i = 0; i < 20 && session.target == null; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    expect(session.target, isNotNull);

    // 起步那一帧：原有卡片还在新建前的位置（被让位位移拉回原处）。
    await tester.pump(const Duration(milliseconds: 1));
    expect((earlierAt() - earlierBefore).distance, lessThan(1));
    // 新卡片排在最终位置，不再走“长高”的出现动画。
    final newCard = inList('Sunset by the sea');
    expect(newCard, findsOneWidget);
    final presence = tester.widget<ListItemPresence>(
      find.ancestor(of: newCard, matching: find.byType(ListItemPresence)),
    );
    expect(presence.appearing, isFalse);

    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final midway = earlierAt();
    expect((midway - earlierBefore).distance, greaterThan(1));

    await tester.pumpAndSettle();
    expect(session.phase.value, MorphLandingPhase.landed);
    expect(find.byType(PublishDiaryPage), findsNothing);
    // 停稳：原有卡片让出了新卡片的位置（瀑布流里换到另一列，列表里移到
    // 下面），新卡片占着它原来的地方。
    final earlierAfter = earlierAt();
    expect(
      (earlierAfter - earlierBefore).distance,
      greaterThan((midway - earlierBefore).distance),
    );
    expect((tester.getTopLeft(newCard) - earlierBefore).distance, lessThan(1));

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
