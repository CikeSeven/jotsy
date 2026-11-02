import 'package:appflowy_editor/appflowy_editor.dart' as quill;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/ai/ai_models.dart';
import 'package:node_diary/core/services/ai/ai_provider_store.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/ai/providers/ai_providers.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_ai/diary_ai_writing_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';
import '../../../support/fake_ai.dart';

/// 编辑页的 AI 写作：工具只在 AI 可用时出现；面板里的指令流式生成，
/// “替换”一次写回正文并关闭面板；关掉 AI 后入口全部消失。
void main() {
  late AppDatabase database;
  late SettingsService settings;
  late AiProviderStore store;
  late String diaryId;
  late List<AiRequest> requests;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
    store = await AiProviderStore.create();
    requests = <AiRequest>[];
    await settings.setDiaryToolbarAlwaysVisible(true);
    // AI 写作放在工具栏最前，不必去「更多」里找。
    await settings.setDiaryToolbarOrderRaw('ai,bold');
    diaryId = await database.createDiary(
      title: 'AI probe',
      contentDocJson: '[{"insert":"teh sentence\\n"}]',
      contentText: 'teh sentence',
      metadataJson: '{}',
    );
  });
  tearDown(() async {
    store.dispose();
    await database.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> pumpPage(WidgetTester tester) async {
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
            (ref) async => fakeAiService(
              store,
              reply: (_) => 'the sentence',
              requests: requests,
            ),
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
          home: EditDiaryPage(diaryId: diaryId),
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

  final l10n = lookupAppLocalizations(const Locale('en'));
  Finder aiTool() => find.byTooltip(l10n.aiToolbarLabel);

  testWidgets('no AI tool while the feature is off', (tester) async {
    await tester.runAsync(() => seedFakeAiProvider(store));
    await pumpPage(tester);
    expect(aiTool(), findsNothing);
    await unmount(tester);
  });

  testWidgets('no AI tool when on but nothing is configured', (tester) async {
    await settings.setAppFeaturesRaw('{"ai":true}');
    await pumpPage(tester);
    expect(aiTool(), findsNothing);
    await unmount(tester);
  });

  testWidgets('a command streams a result that replaces the paragraph', (
    tester,
  ) async {
    await settings.setAppFeaturesRaw('{"ai":true}');
    await tester.runAsync(() => seedFakeAiProvider(store));
    await pumpPage(tester);
    expect(aiTool(), findsOneWidget);

    await tester.tap(aiTool());
    await settle(tester);
    expect(find.byType(DiaryAiWritingPanel), findsOneWidget);

    await tester.tap(find.text(l10n.aiActionPolish));
    await settle(tester);
    expect(requests, hasLength(1));
    expect(requests.single.messages.single.text, contains('teh sentence'));
    expect(find.text('the sentence'), findsWidgets);

    await tester.tap(find.text(l10n.aiPanelReplace));
    await settle(tester);
    expect(find.byType(DiaryAiWritingPanel), findsNothing);
    // 自动保存把写回的正文存进数据库。
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 700)),
    );
    await settle(tester);
    final saved = await tester.runAsync(() => database.getAiDiary(diaryId));
    expect(saved!.contentText, 'the sentence');
    await unmount(tester);
  });
}
