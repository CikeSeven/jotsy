import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_content.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_gateway.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_kind.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_settings.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_style.dart';
import 'package:node_diary/ui/home_widgets/pages/home_widget_studio_page.dart';
import 'package:node_diary/ui/home_widgets/pages/home_widgets_page.dart';
import 'package:node_diary/ui/home_widgets/models/home_widget_style_library.dart';
import 'package:node_diary/ui/home_widgets/providers/home_widget_providers.dart';
import 'package:node_diary/ui/settings/sections/settings_home_groups.dart';

import '../../support/diary_drafts_harness.dart';
import '../../support/fake_home_widget_gateway.dart';

void main() {
  group('settings entry', () {
    testWidgets('appears in the General group on Android', (tester) async {
      final h = await DiaryDraftsHarness.create(tester);
      await h.pump(
        const Scaffold(
          body: SingleChildScrollView(child: SettingsGeneralGroup()),
        ),
      );
      expect(find.text(h.l10n.homeWidgetsTitle), findsOneWidget);
      await h.unmount();
    });

    testWidgets('is hidden on desktop', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final h = await DiaryDraftsHarness.create(tester);
      await h.pump(
        const Scaffold(
          body: SingleChildScrollView(child: SettingsGeneralGroup()),
        ),
      );
      expect(find.text(h.l10n.homeWidgetsTitle), findsNothing);
      await h.unmount();
      debugDefaultTargetPlatformOverride = null;
    });
  });

  testWidgets('lists the widgets on the home screen and the gallery', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    final gateway = FakeHomeWidgetGateway(
      installed: const <InstalledHomeWidget>[
        InstalledHomeWidget(widgetId: 3, kind: HomeWidgetKind.today),
      ],
    );
    await h.pump(
      HomeWidgetsPage(settingsService: h.settings),
      overrides: [homeWidgetGatewayProvider.overrideWithValue(gateway)],
    );
    final l10n = h.l10n;
    expect(find.text(l10n.homeWidgetsInstalledGroup), findsOneWidget);
    expect(find.text(l10n.homeWidgetsInstalledEmpty), findsNothing);
    // 桌面上的今日一行 + 组件库里的今日卡片。
    expect(find.text(l10n.homeWidgetKindToday), findsWidgets);
    expect(find.text(l10n.homeWidgetKindQuickCapture), findsWidgets);
    expect(
      find.text(
        '${l10n.homeWidgetPaletteApp} · ${l10n.homeWidgetBackgroundSurface}',
      ),
      findsOneWidget,
    );
    await h.unmount();
  });

  testWidgets('the gallery only offers kinds whose feature is on', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    // 足够高，整个组件库一次建好，不必滚动去找。
    tester.view.physicalSize = const Size(400, 4000);
    await h.pump(
      HomeWidgetsPage(settingsService: h.settings),
      overrides: [
        homeWidgetGatewayProvider.overrideWithValue(FakeHomeWidgetGateway()),
      ],
    );
    final l10n = h.l10n;
    // 纪念日默认关闭：组件库里没有纪念日小组件；心情月历跟着日历（默认开）。
    expect(find.text(l10n.homeWidgetKindMoodCalendar), findsWidgets);
    expect(find.text(l10n.homeWidgetKindAnniversary), findsNothing);

    await h.settings.setAppFeaturesRaw(
      '{"calendar":true,"anniversaries":true}',
    );
    await h.settle();
    expect(find.text(l10n.homeWidgetKindAnniversary), findsWidgets);

    await h.settings.setAppFeaturesRaw('{"calendar":false}');
    await h.settle();
    expect(find.text(l10n.homeWidgetKindMoodCalendar), findsNothing);
    await h.unmount();
  });

  testWidgets('designing a new widget pins it and keeps the design pending', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    _wide(tester);
    final gateway = FakeHomeWidgetGateway();
    await h.pump(
      HomeWidgetStudioPage(
        settingsService: h.settings,
        kind: HomeWidgetKind.quickCapture,
      ),
      overrides: [homeWidgetGatewayProvider.overrideWithValue(gateway)],
    );
    final l10n = h.l10n;
    await _openTab(tester, l10n.homeWidgetTabStyle);
    await _tapInPanel(tester, find.text(l10n.homeWidgetBackgroundVivid));
    await h.settle();
    await tester.tap(find.text(l10n.homeWidgetAddToHome));
    await h.settle();
    expect(gateway.pinRequests, <HomeWidgetKind>[HomeWidgetKind.quickCapture]);
    final stored = HomeWidgetSettings.decode(
      h.settings.homeWidgetsRawNotifier.value,
    );
    expect(
      stored.pending.single.instance.style.background,
      HomeWidgetBackground.vivid,
    );
    expect(find.text(l10n.homeWidgetPinRequested), findsOneWidget);
    await h.unmount();
  });

  testWidgets('a new recent entries design shows its source in the preview', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    _wide(tester);
    final gateway = FakeHomeWidgetGateway();
    await h.pump(
      HomeWidgetStudioPage(
        settingsService: h.settings,
        kind: HomeWidgetKind.recentDiaries,
      ),
      overrides: [homeWidgetGatewayProvider.overrideWithValue(gateway)],
    );
    final l10n = h.l10n;
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeWidgetStudioPage)),
    );
    // 草稿交给快照，预览才算得出它选的来源。
    expect(
      container.read(homeWidgetPreviewContentProvider),
      RecentDiariesContent.defaults,
    );
    await _openTab(tester, l10n.homeWidgetTabContent);
    await _tapInPanel(tester, find.text(l10n.diaryPinnedBadge));
    await h.settle();
    expect(
      container.read(homeWidgetPreviewContentProvider),
      const RecentDiariesContent(source: RecentDiariesSource.pinned),
    );
    await tester.tap(find.text(l10n.homeWidgetAddToHome));
    await h.settle();
    final stored = HomeWidgetSettings.decode(
      h.settings.homeWidgetsRawNotifier.value,
    );
    expect(
      (stored.pending.single.instance.content as RecentDiariesContent).source,
      RecentDiariesSource.pinned,
    );
    await h.unmount();
  });

  testWidgets('presets restyle the widget and the look can be saved', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    _wide(tester);
    final gateway = FakeHomeWidgetGateway(
      installed: const <InstalledHomeWidget>[
        InstalledHomeWidget(widgetId: 4, kind: HomeWidgetKind.today),
      ],
    );
    await h.pump(
      HomeWidgetStudioPage(
        settingsService: h.settings,
        kind: HomeWidgetKind.today,
        widgetId: 4,
      ),
      overrides: [homeWidgetGatewayProvider.overrideWithValue(gateway)],
    );
    final l10n = h.l10n;
    await _openTab(tester, l10n.homeWidgetTabPresets);
    await _tapInPanel(tester, find.text(l10n.homeWidgetPresetNight));
    await tester.pump(const Duration(milliseconds: 400));
    await h.settle();
    HomeWidgetSettings stored() =>
        HomeWidgetSettings.decode(h.settings.homeWidgetsRawNotifier.value);
    expect(stored().instances[4]!.style, HomeWidgetStylePreset.night.style);
    // 存为“我的样式”：命名对话框里直接确认默认名字。
    await _tapInPanel(tester, find.text(l10n.styleEditorSaveCurrent));
    await tester.tap(find.text(l10n.commonConfirm).last);
    await h.settle();
    final saved = homeWidgetSavedStyles(stored());
    expect(saved.single.style, HomeWidgetStylePreset.night.style);
    expect(find.text(saved.single.name), findsWidgets);
    // 外观改动与“我的样式”各自写回，不互相覆盖。
    expect(stored().instances[4]!.style, HomeWidgetStylePreset.night.style);
    await h.unmount();
  });

  testWidgets('a launcher that cannot pin explains how to add it by hand', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    final gateway = FakeHomeWidgetGateway()..pinSupported = false;
    await h.pump(
      HomeWidgetStudioPage(
        settingsService: h.settings,
        kind: HomeWidgetKind.today,
      ),
      overrides: [homeWidgetGatewayProvider.overrideWithValue(gateway)],
    );
    await tester.tap(find.text(h.l10n.homeWidgetAddToHome));
    await h.settle();
    expect(find.text(h.l10n.homeWidgetPinUnsupportedTitle), findsOneWidget);
    expect(gateway.pinRequests, isEmpty);
    await h.unmount();
  });

  testWidgets('editing a widget on the home screen saves it right away', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    _wide(tester);
    final gateway = FakeHomeWidgetGateway(
      installed: const <InstalledHomeWidget>[
        InstalledHomeWidget(widgetId: 3, kind: HomeWidgetKind.today),
      ],
    );
    await h.pump(
      HomeWidgetStudioPage(
        settingsService: h.settings,
        kind: HomeWidgetKind.today,
        widgetId: 3,
      ),
      overrides: [homeWidgetGatewayProvider.overrideWithValue(gateway)],
    );
    final l10n = h.l10n;
    expect(find.text(l10n.homeWidgetAddToHome), findsNothing);
    expect(find.text(l10n.homeWidgetsInstalledHint), findsOneWidget);
    await _openTab(tester, l10n.homeWidgetTabStyle);
    await _tapInPanel(tester, find.text(l10n.homeWidgetBackgroundTonal));
    await tester.pump(const Duration(milliseconds: 400));
    await h.settle();
    final stored = HomeWidgetSettings.decode(
      h.settings.homeWidgetsRawNotifier.value,
    );
    expect(stored.instances[3]!.style.background, HomeWidgetBackground.tonal);
    await h.unmount();
  });
}

/// 切到工作室的某个标签页（有切换动画，推进到结束）。
Future<void> _openTab(WidgetTester tester, String label) async {
  final tab = find.widgetWithText(Tab, label);
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

/// 选项列表按需构建：目标还没进树时先在当前标签页里向下滚，再点。
Future<void> _tapInPanel(WidgetTester tester, Finder target) async {
  final inPanel = find.descendant(
    of: find.byType(TabBarView),
    matching: target,
  );
  if (inPanel.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      inPanel,
      120,
      scrollable: find
          .descendant(
            of: find.byType(TabBarView),
            matching: find.byWidgetPredicate(
              (Widget widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            ),
          )
          .first,
    );
  }
  await tester.ensureVisible(inPanel);
  await tester.pumpAndSettle();
  await tester.tap(inPanel);
  await tester.pumpAndSettle();
}

/// 宽窗口：工作室的预览与选项左右并排，选项栏占满高度，按钮都点得到。
void _wide(WidgetTester tester) {
  tester.view.physicalSize = const Size(1100, 1000);
}
