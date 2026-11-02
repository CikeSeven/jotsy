import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/ai/ai_models.dart';
import 'package:node_diary/core/services/ai/ai_provider_config.dart';
import 'package:node_diary/core/services/ai/ai_provider_presets.dart';
import 'package:node_diary/core/services/ai/ai_provider_store.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/backup_settings.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/ai/models/ai_preference_parts.dart';
import 'package:node_diary/ui/ai/models/ai_preferences.dart';
import 'package:node_diary/ui/ai/pages/settings/ai_actions_page.dart';
import 'package:node_diary/ui/ai/pages/settings/ai_model_routing_page.dart';
import 'package:node_diary/ui/ai/pages/settings/ai_personas_page.dart';
import 'package:node_diary/ui/ai/pages/settings/ai_privacy_page.dart';
import 'package:node_diary/ui/ai/pages/settings/ai_provider_edit_page.dart';
import 'package:node_diary/ui/ai/pages/settings/ai_settings_page.dart';
import 'package:node_diary/ui/ai/pages/settings/ai_usage_page.dart';
import 'package:node_diary/ui/settings/pages/settings_page.dart';

import '../../support/diary_drafts_harness.dart';

/// AI 设置：入口只在功能管理打开后出现；各设置页在窄屏两种语言下不溢出；
/// 开关与保存写到正确的地方（偏好进设置，服务商只进本机存储）。
void main() {
  AiPreferences prefsOf(DiaryDraftsHarness h) =>
      AiPreferences.decode(h.settings.aiPrefsRaw);

  /// 滚到屏幕中间再点：贴着屏幕边缘时会被顶栏或底部挡住。
  Future<void> tapCentered(WidgetTester tester, Finder finder) async {
    await tester.runAsync(
      () => Scrollable.ensureVisible(tester.element(finder), alignment: 0.5),
    );
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('settings home shows the AI entry only when the feature is on', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await h.pump(const Scaffold(body: SettingsPage()));
    await tester.pumpAndSettle();
    expect(find.text(h.l10n.aiSettingsEntrySubtitle), findsNothing);

    await h.settings.setAppFeaturesRaw('{"ai":true}');
    await tester.pumpAndSettle();
    final entry = find.text(h.l10n.aiSettingsEntrySubtitle);
    expect(entry, findsOneWidget);

    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(AiSettingsPage), findsOneWidget);
    expect(find.text(h.l10n.aiStatusNotConfiguredTitle), findsOneWidget);
    await h.unmount();
  });

  testWidgets('module switches and nested options write preferences', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await h.pump(const AiSettingsPage());
    final l10n = h.l10n;

    final writing = find.widgetWithText(SwitchListTile, l10n.aiModuleWriting);
    await tapCentered(tester, writing);
    expect(prefsOf(h).isModuleEnabled(AiModule.writing), isFalse);

    // 图片理解默认关，从属选项随开关展开。
    final vision = find.widgetWithText(SwitchListTile, l10n.aiModuleVision);
    expect(find.text(l10n.aiOptionVisionSize), findsNothing);
    await tapCentered(tester, vision);
    expect(prefsOf(h).isModuleEnabled(AiModule.vision), isTrue);
    expect(find.text(l10n.aiOptionVisionSize), findsOneWidget);

    final autoReply = find.widgetWithText(
      SwitchListTile,
      l10n.aiOptionAutoReply,
    );
    await tapCentered(tester, autoReply);
    expect(prefsOf(h).autoReply, isTrue);
    await h.unmount();
  });

  testWidgets('saving a new provider stores it locally, not in settings', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    final preset = aiProviderPresetById(AiPresetIds.deepseek)!;
    await h.pump(
      Navigator(
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: SizedBox()),
        ),
      ),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => AiProviderEditPage.create(preset),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('DeepSeek'), findsWidgets);

    await tester.enterText(
      find.widgetWithText(TextField, h.l10n.aiProviderApiKey),
      'sk-test',
    );
    await tester.tap(find.text(h.l10n.commonSave));
    await h.settle();
    await tester.pumpAndSettle();

    final store = (await tester.runAsync(AiProviderStore.create))!;
    final saved = store.config.providers.single;
    expect(saved.name, 'DeepSeek');
    expect(saved.apiKey, 'sk-test');
    expect(saved.baseUrl, preset.baseUrl);
    expect(saved.models.map((m) => m.id), preset.models);
    // 密钥不进备份：设置里没有它，备份字段也没有服务商。
    final captured = BackupSettings.capture(h.settings).toString();
    expect(captured, isNot(contains('sk-test')));
    store.dispose();
    await h.unmount();
  });

  testWidgets('a bad address blocks saving with an inline error', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    final preset = aiProviderPresetById(AiPresetIds.customOpenAi)!;
    await h.pump(AiProviderEditPage.create(preset));
    await tester.tap(find.text(h.l10n.commonSave));
    await tester.pumpAndSettle();
    expect(find.text(h.l10n.aiProviderUrlInvalid), findsOneWidget);
    await h.unmount();
  });

  testWidgets('status card shows the default model once one is usable', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    final store = (await tester.runAsync(AiProviderStore.create))!;
    await tester.runAsync(
      () => store.saveProvider(
        const AiProviderConfig(
          id: 'p',
          name: 'Local',
          protocol: AiProtocol.openAi,
          baseUrl: 'http://127.0.0.1:1/v1',
          models: [AiModelConfig(id: 'tiny-model')],
        ),
      ),
    );
    store.dispose();
    await h.pump(const AiSettingsPage());
    await tester.pumpAndSettle();
    expect(find.text('tiny-model'), findsOneWidget);
    expect(find.text(h.l10n.aiStatusTest), findsOneWidget);
    await h.unmount();
  });

  for (final locale in const [Locale('zh'), Locale('en')]) {
    for (final entry in <String, Widget Function()>{
      'settings': () => const AiSettingsPage(),
      'provider': () =>
          AiProviderEditPage.create(aiProviderPresetById(AiPresetIds.ollama)!),
      'routing': () => const AiModelRoutingPage(),
      'personas': () => const AiPersonasPage(),
      'actions': () => const AiActionsPage(),
      'privacy': () => const AiPrivacyPage(),
      'usage': () => const AiUsagePage(),
    }.entries) {
      testWidgets('${entry.key} page fits 320dp in ${locale.languageCode}', (
        tester,
      ) async {
        final h = await DiaryDraftsHarness.create(tester);
        tester.view.physicalSize = const Size(320, 720);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(h.database),
              settingsServiceProvider.overrideWith((ref) async => h.settings),
            ],
            child: MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: entry.value(),
            ),
          ),
        );
        await h.settle();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await h.unmount();
      });
    }
  }
}
