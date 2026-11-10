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
import 'package:node_diary/ui/ai/sections/settings/ai_model_sheets.dart';
import 'package:node_diary/ui/settings/pages/settings_page.dart';
import 'package:node_diary/ui/settings/widgets/settings_option_tiles.dart';

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
    await h.pump(const SettingsPage());
    await tester.pumpAndSettle();
    // AI 助手在末尾一组（关于之上）：先滚到底，确认关闭时那里没有它。
    await tester.scrollUntilVisible(
      find.text(h.l10n.settingsAbout),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(h.l10n.aiSettingsEntrySubtitle), findsNothing);

    await h.settings.setAppFeaturesRaw('{"ai":true}');
    await tester.pumpAndSettle();
    final entry = find.text(h.l10n.aiSettingsEntrySubtitle);
    expect(entry, findsOneWidget);
    expect(
      tester.getTopLeft(entry).dy,
      lessThan(tester.getTopLeft(find.text(h.l10n.settingsAbout)).dy),
    );

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

    // 图片理解默认开，从属选项随开关收起。
    final vision = find.widgetWithText(SwitchListTile, l10n.aiModuleVision);
    expect(prefsOf(h).isModuleEnabled(AiModule.vision), isTrue);
    expect(find.text(l10n.aiOptionVisionSize), findsOneWidget);
    await tapCentered(tester, vision);
    expect(prefsOf(h).isModuleEnabled(AiModule.vision), isFalse);
    expect(find.text(l10n.aiOptionVisionSize), findsNothing);

    final autoReply = find.widgetWithText(
      SwitchListTile,
      l10n.aiOptionAutoReply,
    );
    await tapCentered(tester, autoReply);
    expect(prefsOf(h).autoReply, isTrue);
    await h.unmount();
  });

  testWidgets('photos-per-request slider drags up to 20 and saves on release', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await h.pump(const AiSettingsPage());
    final l10n = h.l10n;

    final tile = find.ancestor(
      of: find.text(l10n.aiOptionVisionImages),
      matching: find.byType(SettingsSliderTile),
    );
    final slider = find.descendant(of: tile, matching: find.byType(Slider));
    await tester.runAsync(
      () => Scrollable.ensureVisible(tester.element(slider), alignment: 0.5),
    );
    await tester.pumpAndSettle();
    // 曾经 onChanged 为 null，滑块停用，拖不动、一直是默认的 3 张。
    expect(tester.widget<Slider>(slider).onChanged, isNotNull);
    expect(
      find.descendant(of: tile, matching: find.text(l10n.aiPhotos(3))),
      findsOneWidget,
    );

    // 拖动中只改本地预览，不写偏好。
    final gesture = await tester.startGesture(tester.getCenter(slider));
    await gesture.moveBy(const Offset(2000, 0));
    await tester.pump();
    expect(
      find.descendant(
        of: tile,
        matching: find.text(l10n.aiPhotos(AiPreferences.maxVisionImages)),
      ),
      findsOneWidget,
    );
    expect(prefsOf(h).visionMaxImages, AiPreferences.defaultVisionMaxImages);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(AiPreferences.maxVisionImages, 20);
    expect(prefsOf(h).visionMaxImages, 20);

    // 拖回最左是 1 张。
    await tester.drag(slider, const Offset(-2000, 0));
    await tester.pumpAndSettle();
    expect(prefsOf(h).visionMaxImages, 1);
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
    // 预设不带模型：新建后从服务商获取。
    expect(saved.models, isEmpty);
    // 密钥不进备份：设置里没有它，备份字段也没有服务商。
    final captured = BackupSettings.capture(h.settings).toString();
    expect(captured, isNot(contains('sk-test')));
    store.dispose();
    await h.unmount();
  });

  testWidgets('tapping outside a field drops its focus on touch', (
    tester,
  ) async {
    // 手机上默认点外面不取消焦点：收起键盘后再点别的（打开面板、切换开关）
    // 焦点被还给输入框，键盘又弹出来。编辑页点输入框以外的地方即取消焦点。
    final h = await DiaryDraftsHarness.create(tester);
    final preset = aiProviderPresetById(AiPresetIds.deepseek)!;
    await h.pump(AiProviderEditPage.create(preset));
    await tester.pumpAndSettle();
    final keyField = find.widgetWithText(TextField, h.l10n.aiProviderApiKey);
    await tester.tap(keyField);
    await tester.pump();
    EditableText editable() => tester.widget<EditableText>(
      find.descendant(of: keyField, matching: find.byType(EditableText)),
    );
    expect(editable().focusNode.hasFocus, isTrue);

    await tapCentered(tester, find.text(h.l10n.aiProviderEnabled));
    expect(editable().focusNode.hasFocus, isFalse);
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

  testWidgets('model sheet saves tool calling turned off', (tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    AiModelSheetResult? result;
    await h.pump(
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showAiModelSettingsSheet(
              context,
              const AiModelConfig(id: 'tool-model'),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    Future<AiModelConfig> toggleAndSave() async {
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final toggle = find.text(h.l10n.aiModelToolsToggle);
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tester.tap(find.text(h.l10n.commonSave));
      await tester.pumpAndSettle();
      return (result! as AiModelSheetUpdated).model;
    }

    final off = await toggleAndSave();
    expect(off.tools, isFalse);
    expect(off.toJson()['tools'], isFalse);
    await h.unmount();
  });

  for (final (locale, label) in const [
    (Locale('zh'), '10万字'),
    (Locale('en'), '100K words'),
  ]) {
    testWidgets(
      'privacy page abbreviates the budget and has no per-entry limit '
      'in ${locale.languageCode}',
      (tester) async {
        final h = await DiaryDraftsHarness.create(tester);
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
              home: const AiPrivacyPage(),
            ),
          ),
        );
        await h.settle();
        await tester.pumpAndSettle();
        final l10n = lookupAppLocalizations(locale);
        await tester.scrollUntilVisible(
          find.text(l10n.aiPrivacyBudget),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(label), findsOneWidget);
        expect(find.text(l10n.aiPrivacyBudgetSubtitle), findsOneWidget);
        expect(find.byType(Slider), findsOneWidget);
        await h.unmount();
      },
    );
  }

  for (final locale in AppLocalizations.supportedLocales) {
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
