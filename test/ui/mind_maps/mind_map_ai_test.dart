import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as quill;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_codec.dart';
import 'package:node_diary/core/database/mind_map/mind_map_blocks.dart';
import 'package:node_diary/core/database/mind_map/mind_map_document.dart';
import 'package:node_diary/core/database/mind_map/mind_map_text.dart';
import 'package:node_diary/core/services/ai/ai_models.dart';
import 'package:node_diary/core/services/ai/ai_provider_store.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/ai/providers/ai_providers.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/mind_maps/controllers/mind_map_ai_session.dart';
import 'package:node_diary/ui/mind_maps/controllers/mind_map_editing_controller.dart';
import 'package:node_diary/ui/mind_maps/sections/mind_map_ai_sheet.dart';
import 'package:node_diary/ui/mind_maps/widgets/mind_map_workspace.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/expressive_test_theme.dart';
import '../../support/fake_ai.dart';

/// 导图 AI：AI 关闭或没配好时没有入口；起步卡生成整张导图（确认后替换，
/// 一步撤销）；给主题添加子主题；总结写进中心主题的备注。
void main() {
  late AppDatabase database;
  late SettingsService settings;
  late AiProviderStore store;
  late List<AiRequest> requests;
  var reply = '';

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
    store = await AiProviderStore.create();
    requests = <AiRequest>[];
    reply = '';
  });
  tearDown(() async {
    store.dispose();
    await database.close();
  });

  final l10n = lookupAppLocalizations(const Locale('en'));

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> pumpApp(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((ref) async => settings),
          aiProviderStoreProvider.overrideWith((ref) async => store),
          aiServiceProvider.overrideWith(
            (ref) async =>
                fakeAiService(store, reply: (_) => reply, requests: requests),
          ),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('en'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            quill.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }

  Future<String> emptyMindMapDiary(WidgetTester tester) async {
    final map = MindMapDocument.blank();
    return (await tester.runAsync(
      () => database.createDiary(
        title: '',
        contentDocJson: encodeDiaryBlocks(mindMapDiaryDocument(map)),
        contentText: '',
        metadataJson: '{}',
      ),
    ))!;
  }

  MindMapEditingController workspaceController(WidgetTester tester) =>
      tester.widget<MindMapWorkspace>(find.byType(MindMapWorkspace)).controller;

  testWidgets('no AI entries while AI is off or nothing is configured', (
    tester,
  ) async {
    final diaryId = await emptyMindMapDiary(tester);
    await pumpApp(tester, EditDiaryPage(diaryId: diaryId));
    expect(find.text(l10n.mindMapStarterTitle), findsOneWidget);
    expect(find.text(l10n.mindMapAiTile), findsNothing);
    expect(find.text(l10n.mindMapAi), findsNothing);
    await unmount(tester);

    await tester.runAsync(() => settings.setAppFeaturesRaw('{"ai":true}'));
    await pumpApp(tester, EditDiaryPage(diaryId: diaryId));
    expect(find.text(l10n.mindMapAiTile), findsNothing);
    expect(find.text(l10n.mindMapAi), findsNothing);
    await unmount(tester);
  });

  testWidgets('the starter tile generates a whole map that replaces the '
      'empty one in one undo step', (tester) async {
    await tester.runAsync(() async {
      await settings.setAppFeaturesRaw('{"ai":true}');
      await seedFakeAiProvider(store);
    });
    reply = '# Something else\n- Packing\n  - Passport\n- Hotel';
    final diaryId = await emptyMindMapDiary(tester);
    await pumpApp(tester, EditDiaryPage(diaryId: diaryId));

    await tester.tap(find.text(l10n.mindMapAiTile));
    await settle(tester);
    expect(find.text(l10n.mindMapAiGenerate), findsOneWidget);
    expect(requests, isEmpty);
    await tester.enterText(
      find.widgetWithText(TextField, l10n.mindMapAiTopicHint),
      'Trip',
    );
    await tester.pump();
    await tester.tap(find.text(l10n.mindMapAiRun));
    await settle(tester);
    expect(requests, hasLength(1));

    await tester.tap(find.text(l10n.mindMapAiUse));
    await settle(tester);
    final controller = workspaceController(tester);
    expect(
      mindMapOutlineText(controller.document),
      'Trip\n- Packing\n  - Passport\n- Hotel',
    );
    controller.undo();
    expect(mindMapHasOnlyRoot(controller.document), isTrue);
    await unmount(tester);
  });

  testWidgets('expanding a topic adds the new subtopics under it', (
    tester,
  ) async {
    await tester.runAsync(() => seedFakeAiProvider(store));
    reply = '- Sunscreen\n  - SPF 50\n- Hat';
    final controller = MindMapEditingController(
      MindMapDocument.blank().copyWith(
        root: mindMapNodeFromOutline('Trip\n  Packing\n    Passport')!,
      ),
    );
    addTearDown(controller.dispose);
    final packing = controller.document.root.children.single;
    late BuildContext host;
    await pumpApp(
      tester,
      Builder(
        builder: (BuildContext context) {
          host = context;
          return const Scaffold(body: SizedBox.expand());
        },
      ),
    );
    unawaited(
      showMindMapAiSheet(
        host,
        task: MindMapAiTask.expand,
        controller: controller,
        nodeId: packing.id,
      ),
    );
    await settle(tester);
    expect(find.text(l10n.mindMapAiExpandHint('Packing')), findsOneWidget);
    expect(requests, hasLength(1));

    await tester.tap(find.text(l10n.mindMapAiAdd));
    await settle(tester);
    expect(
      mindMapOutlineText(controller.document),
      'Trip\n- Packing\n  - Passport\n  - Sunscreen\n    - SPF 50\n  - Hat',
    );
    controller.undo();
    expect(
      mindMapOutlineText(controller.document),
      'Trip\n- Packing\n  - Passport',
    );
    await unmount(tester);
  });

  testWidgets('a summary can go into the central topic note', (tester) async {
    await tester.runAsync(() => seedFakeAiProvider(store));
    reply = 'The trip needs a passport.';
    final controller = MindMapEditingController(
      MindMapDocument.blank().copyWith(
        root: mindMapNodeFromOutline('Trip\n  Packing\n    Passport')!,
      ),
    );
    addTearDown(controller.dispose);
    late BuildContext host;
    await pumpApp(
      tester,
      Builder(
        builder: (BuildContext context) {
          host = context;
          return const Scaffold(body: SizedBox.expand());
        },
      ),
    );
    unawaited(
      showMindMapAiSheet(
        host,
        task: MindMapAiTask.summarize,
        controller: controller,
      ),
    );
    await settle(tester);
    expect(find.text('The trip needs a passport.'), findsOneWidget);

    await tester.tap(find.text(l10n.mindMapAiToNote));
    await settle(tester);
    expect(controller.document.root.note, 'The trip needs a passport.');
    expect(find.text(l10n.mindMapAiNoteAdded), findsOneWidget);
    await unmount(tester);
  });
}
