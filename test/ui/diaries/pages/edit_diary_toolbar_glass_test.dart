import 'package:appflowy_editor/appflowy_editor.dart' as quill;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/app_surface/models/app_glass_style.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_enums.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_scope.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_floating_toolbar.dart';
import 'package:node_diary/ui/diaries/widgets/diary_recording_panel.dart';
import 'package:node_diary/ui/diary_templates/pages/diary_template_editor_page.dart';
import 'package:node_diary/ui/widgets/glass/glass_reveal.dart';
import 'package:node_diary/ui/widgets/glass/glass_surface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/diary_drafts_harness.dart';
import '../../../support/expressive_test_theme.dart';
import 'package:node_diary/ui/diaries/widgets/publish_diary_panel.dart';
import '../../../support/publish_panel_driver.dart';

const AppGlassStyle _glass = AppGlassStyle(mode: AppGlassMode.glass);

const ValueKey<String> _toolbarLayer = ValueKey<String>(
  'edit-floating-toolbar',
);
const ValueKey<String> _metaLayer = ValueKey<String>('edit-meta-panel');

/// 编辑页“工具栏”材质为玻璃时：悬浮工具栏卡片、录音面板与信息面板都是玻璃
/// 表面、背景模糊开启；入场与淡出途中都没有透明度层包住玻璃（透明度层里的
/// 背景模糊采不到下面的正文）。经典材质时结构与接入前相同。
void main() {
  late AppDatabase database;
  late SettingsService settings;
  late String diaryId;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
    diaryId = await database.createDiary(
      title: 'Glass probe',
      contentDocJson: '[{"insert":"line one\\nline two\\n"}]',
      contentText: 'line one\nline two',
      metadataJson: '{}',
    );
  });
  tearDown(() => database.close());

  Future<void> pumpPage(
    WidgetTester tester,
    Widget page, {
    AppGlassStyle? style = _glass,
    double keyboard = 0,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('zh'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            quill.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: style == null ? page : AppGlassScope(style: style, child: page),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  /// 包住 [of] 的最近一块玻璃表面。
  Finder glassAround(Finder of) =>
      find.ancestor(of: of, matching: find.byType(GlassSurface)).first;

  bool blurEnabled(WidgetTester tester, Finder glass) => tester
      .widget<BackdropFilter>(
        find.descendant(of: glass, matching: find.byType(BackdropFilter)).first,
      )
      .enabled;

  /// [glass] 与图层根 [layer] 之间的透明度层（Opacity / FadeTransition）。
  List<Widget> fadeLayersBetween(Finder glass, Finder layer) {
    final root = layer.evaluate().single;
    final found = <Widget>[];
    glass.evaluate().single.visitAncestorElements((Element element) {
      if (identical(element, root)) return false;
      final widget = element.widget;
      if (widget is Opacity ||
          widget is FadeTransition ||
          widget is AnimatedOpacity) {
        found.add(widget);
      }
      return true;
    });
    return found;
  }

  double revealOf(WidgetTester tester, Finder glass) =>
      GlassReveal.of(tester.element(glass));

  testWidgets('classic toolbar keeps the opaque elevated card', (tester) async {
    await pumpPage(
      tester,
      const EditDiaryPage(entryMode: EditDiaryEntryMode.create),
      style: null,
      keyboard: 300,
    );
    final toolbar = find.byType(DiaryFloatingToolbar);
    expect(toolbar, findsOneWidget);
    expect(
      find.ancestor(of: toolbar, matching: find.byType(GlassSurface)),
      findsNothing,
    );
    final card = find.ancestor(
      of: toolbar,
      matching: find.byWidgetPredicate(
        (w) =>
            w is Material &&
            w.elevation == 8 &&
            w.borderRadius == BorderRadius.circular(18),
      ),
    );
    expect(card, findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets(
    'glass toolbar enters without an opacity layer and blurs the body',
    (tester) async {
      // 新建页：正文已有焦点，键盘弹起前没有工具栏。
      await pumpPage(
        tester,
        const EditDiaryPage(entryMode: EditDiaryEntryMode.create),
      );
      final toolbar = find.byType(DiaryFloatingToolbar);
      expect(toolbar, findsNothing);

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(toolbar, findsOneWidget);
      final glass = glassAround(toolbar);
      // 入场途中：显现进度在 0 与 1 之间，由玻璃自己淡入，外面没有透明度层。
      expect(revealOf(tester, glass), inExclusiveRange(0, 1));
      expect(fadeLayersBetween(glass, find.byKey(_toolbarLayer)), isEmpty);

      await tester.pumpAndSettle();
      expect(revealOf(tester, glass), 1);
      expect(blurEnabled(tester, glass), isTrue);
      expect(
        tester.widget<GlassSurface>(glass).borderRadius,
        BorderRadius.circular(18),
      );
      expect(fadeLayersBetween(glass, find.byKey(_toolbarLayer)), isEmpty);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    },
  );

  testWidgets('glass recording panel is its own glass card under the toolbar', (
    tester,
  ) async {
    await pumpPage(
      tester,
      const EditDiaryPage(entryMode: EditDiaryEntryMode.create),
      keyboard: 300,
    );
    await tester.tap(find.byTooltip('录音'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final panel = find.byType(DiaryRecordingPanel);
    expect(panel, findsOneWidget);
    final panelGlass = find
        .descendant(of: panel, matching: find.byType(GlassSurface))
        .first;
    expect(revealOf(tester, panelGlass), inExclusiveRange(0, 1));
    expect(fadeLayersBetween(panelGlass, find.byKey(_toolbarLayer)), isEmpty);

    await tester.pumpAndSettle();
    expect(blurEnabled(tester, panelGlass), isTrue);
    // 工具栏卡片同样还是玻璃，两块玻璃上下排开、不重叠。
    final toolbarGlass = glassAround(find.byType(DiaryFloatingToolbar));
    expect(
      tester.getRect(toolbarGlass).overlaps(tester.getRect(panelGlass)),
      isFalse,
    );
    // 录音面板没有外层的软阴影（会从半透明底里透出来）。
    expect(
      find.descendant(
        of: panel,
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).boxShadow != null,
        ),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets(
    'glass info panel has no outer shadow and rises without an opacity layer',
    (tester) async {
      await pumpPage(tester, EditDiaryPage(diaryId: diaryId));
      final driver = PublishPanelDriver(tester);
      // 阅读式编辑页平时不挂信息面板：点信息栏后面板从底边升起，途中没有
      // 透明度层包住玻璃（靠平移离场 / 入场，不靠淡入淡出）。
      await tester.tap(driver.readingMetaButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final panel = find.byType(PublishDiaryPanel);
      expect(panel, findsOneWidget);
      var glass = find
          .descendant(of: panel, matching: find.byType(GlassSurface))
          .first;
      expect(fadeLayersBetween(glass, find.byKey(_metaLayer)), isEmpty);
      await tester.pumpAndSettle();

      final header = driver.expandedHeader;
      expect(header, findsOneWidget);
      glass = glassAround(header);
      expect(blurEnabled(tester, glass), isTrue);
      expect(
        tester.widget<GlassSurface>(glass).shadowColor,
        isNotNull,
        reason: 'the shadow is drawn outside the glass only',
      );
      final boxShadows = find.ancestor(
        of: glass,
        matching: find.byWidgetPredicate(
          (w) =>
              (w is DecoratedBox &&
                  w.decoration is BoxDecoration &&
                  (w.decoration as BoxDecoration).boxShadow != null) ||
              (w is Container &&
                  w.decoration is BoxDecoration &&
                  (w.decoration as BoxDecoration).boxShadow != null),
        ),
      );
      expect(boxShadows, findsNothing);
      expect(fadeLayersBetween(glass, find.byKey(_metaLayer)), isEmpty);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    },
  );

  testWidgets(
    'the glass toolbar steps aside while the glass info panel is open, so '
    'the two never stack',
    (tester) async {
      await settings.setDiaryToolbarAlwaysVisible(true);
      await pumpPage(tester, EditDiaryPage(diaryId: diaryId));
      final driver = PublishPanelDriver(tester);
      final toolbar = find.byType(DiaryFloatingToolbar);
      expect(toolbar, findsOneWidget);
      expect(revealOf(tester, glassAround(toolbar)), 1);
      expect(find.byType(PublishDiaryPanel), findsNothing);

      // 面板挂上时工具栏让位：同一区域不会叠两层模糊。
      await tester.tap(driver.readingMetaButton);
      await tester.pumpAndSettle();
      expect(find.byType(PublishDiaryPanel), findsOneWidget);
      expect(toolbar, findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(PublishDiaryPanel), findsNothing);
      expect(toolbar, findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    },
  );

  testWidgets('template editor toolbar is glass too', (tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    await h.settings.setDiaryToolbarAlwaysVisible(true);
    await h.pump(
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AppGlassScope(
                  style: _glass,
                  child: DiaryTemplateEditorPage(),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final toolbar = find.byType(DiaryFloatingToolbar);
    expect(toolbar, findsOneWidget);
    final glass = glassAround(toolbar);
    expect(blurEnabled(tester, glass), isTrue);
    expect(tester.takeException(), isNull);
    await h.unmount();
  });
}
