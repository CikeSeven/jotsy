import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/app_surface/models/app_glass_style.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_enums.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_controls_theme.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_fab.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_field.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_scope.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_surface.dart';
import 'package:node_diary/ui/app_surface/widgets/on_glass.dart';
import 'package:node_diary/ui/diaries/models/tag_picker_sort.dart';
import 'package:node_diary/ui/diaries/pages/diary_search_page.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_overlays.dart';
import 'package:node_diary/ui/diaries/widgets/diary_tag_filter_bar.dart';
import 'package:node_diary/ui/diaries/widgets/publish_panel/publish_panel_tile.dart';
import 'package:node_diary/ui/diaries/widgets/publish_panel/publish_tag_row.dart';
import 'package:node_diary/ui/diaries/widgets/publish_panel/publish_tag_search_bar.dart';
import 'package:node_diary/ui/diaries/widgets/tag_filter_chip.dart';
import 'package:node_diary/ui/diary_templates/widgets/diary_template_search_field.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_presets.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_resolved_style.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_chrome_scope.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_top_bar_surface.dart';
import 'package:node_diary/ui/widgets/expressive_button_group.dart';
import 'package:node_diary/ui/widgets/glass/glass_reveal.dart';
import 'package:node_diary/ui/widgets/glass/glass_surface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

const AppGlassStyle _glass = AppGlassStyle(mode: AppGlassMode.glass);

/// 只把信息面板（工具栏）设为玻璃，“控件”保持经典。
final AppGlassStyle _toolbarOnly = AppGlassStyle.defaults.withOverride(
  AppGlassComponent.toolbar,
  AppGlassOverride.glass,
);

/// 带主题、本地化与（可选）材质 scope 的测试外壳。
Widget _host({
  AppGlassStyle? style,
  Brightness brightness = Brightness.light,
  required Widget child,
}) {
  return MaterialApp(
    theme: expressiveTestTheme(brightness),
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (BuildContext context, Widget? child) =>
        style == null ? child! : AppGlassScope(style: style, child: child!),
    home: Scaffold(body: child),
  );
}

/// 放在一块“工具栏”玻璃上（与信息面板相同的组件类别）。
Widget _onToolbarGlass(Widget child) => AppGlassSurface(
  component: AppGlassComponent.toolbar,
  blur: AppGlassBlur.always,
  child: child,
);

bool _translucent(Color color) => color.a > 0 && color.a < 1;

ColorScheme _scheme(WidgetTester tester, Finder finder) =>
    Theme.of(tester.element(finder)).colorScheme;

bool _underOpacity(WidgetTester tester, Finder finder, Type stopAt) {
  var under = false;
  tester.element(finder).visitAncestorElements((element) {
    final widget = element.widget;
    if (widget.runtimeType == stopAt) return false;
    if (widget is Opacity ||
        widget is FadeTransition ||
        widget is AnimatedOpacity) {
      under = true;
      return false;
    }
    return true;
  });
  return under;
}

const Tag _tagA = Tag(id: 1, name: 'Travel', color: 0xff336699);
const Tag _tagB = Tag(id: 2, name: 'Work', color: 0xffaa5500);

Widget _tagBar({Set<int> selected = const <int>{1}}) => DiaryTagFilterBar(
  tags: const <Tag>[_tagA, _tagB],
  expansionProgress: ValueNotifier<double>(0),
  canExpand: () => false,
  canCollapse: () => false,
  selectedTagFilterIds: selected,
  onToggleTagFilter: (_, _) {},
  onClearTagFilters: () {},
  onVerticalDragStart: (_) {},
  onVerticalDragUpdate: (_, _) {},
  onVerticalDragEnd: (_) {},
  onCollapse: () {},
);

TagFilterChip _chip(WidgetTester tester, String label) =>
    tester.widget<TagFilterChip>(
      find.ancestor(of: find.text(label), matching: find.byType(TagFilterChip)),
    );

void main() {
  group('OnGlass', () {
    testWidgets('is false off glass and true inside an AppGlassSurface', (
      tester,
    ) async {
      late bool outside;
      late bool inside;
      await tester.pumpWidget(
        _host(
          style: _glass,
          child: Column(
            children: <Widget>[
              Builder(
                builder: (context) {
                  outside = OnGlass.of(context);
                  return const SizedBox(height: 10);
                },
              ),
              _onToolbarGlass(
                Builder(
                  builder: (context) {
                    inside = OnGlass.of(context);
                    return const SizedBox(height: 10);
                  },
                ),
              ),
            ],
          ),
        ),
      );
      expect(outside, isFalse);
      expect(inside, isTrue);
    });

    testWidgets('AppGlassField: classic null, glass controls, on glass well', (
      tester,
    ) async {
      AppGlassField? classic;
      AppGlassField? controls;
      AppGlassField? well;
      await tester.pumpWidget(
        _host(
          child: Builder(
            builder: (context) {
              classic = AppGlassField.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpWidget(
        _host(
          style: _glass,
          child: Builder(
            builder: (context) {
              controls = AppGlassField.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpWidget(
        _host(
          style: _toolbarOnly,
          child: _onToolbarGlass(
            Builder(
              builder: (context) {
                well = AppGlassField.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(classic, isNull);
      expect(_translucent(controls!.fill), isTrue);
      expect(controls!.border, isNotNull);
      final scheme = _scheme(tester, find.byType(Scaffold));
      expect(well!.fill, OnGlass.wellColor(scheme));
      expect(well!.border, isNull);
    });
  });

  group('publish panel on glass', () {
    for (final brightness in Brightness.values) {
      testWidgets('rows turn translucent on a glass panel ($brightness)', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            style: _toolbarOnly,
            brightness: brightness,
            child: Column(
              children: <Widget>[
                const PublishPanelTile(key: Key('plain'), child: Text('a')),
                _onToolbarGlass(
                  const PublishPanelTile(key: Key('glass'), child: Text('b')),
                ),
              ],
            ),
          ),
        );
        Color colorOf(String key) => tester
            .widget<Material>(
              find
                  .descendant(
                    of: find.byKey(Key(key)),
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .color!;
        final scheme = _scheme(tester, find.byType(Scaffold));
        expect(colorOf('plain'), PublishPanelTile.surfaceColor(scheme));
        expect(colorOf('glass'), OnGlass.wellColor(scheme));
        expect(_translucent(colorOf('glass')), isTrue);
      });
    }

    testWidgets('unselected tag rows use the well color on glass', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          style: _toolbarOnly,
          child: _onToolbarGlass(
            PublishTagRow(tag: _tagA, selected: false, onToggle: (_) {}),
          ),
        ),
      );
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(PublishTagRow),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(
        material.color,
        OnGlass.wellColor(_scheme(tester, find.byType(PublishTagRow))),
      );
    });
  });

  group('search fields', () {
    Widget tagSearch() => PublishTagSearchBar(
      controller: TextEditingController(),
      focusNode: FocusNode(),
      onChanged: (_) {},
      sort: TagPickerSort.custom,
      onSortChanged: (_) {},
    );

    Color pillColor(WidgetTester tester) => tester
        .widgetList<Material>(
          find.descendant(
            of: find.byType(PublishTagSearchBar),
            matching: find.byType(Material),
          ),
        )
        .firstWhere((material) => material.shape is StadiumBorder)
        .color!;

    testWidgets('the tag search pill keeps its classic fill', (tester) async {
      await tester.pumpWidget(_host(child: tagSearch()));
      expect(
        pillColor(tester),
        PublishPanelTile.surfaceColor(
          _scheme(tester, find.byType(PublishTagSearchBar)),
        ),
      );
    });

    testWidgets('glass controls give the tag search a glass fill, no blur', (
      tester,
    ) async {
      await tester.pumpWidget(_host(style: _glass, child: tagSearch()));
      final glass = AppGlass.of(
        tester.element(find.byType(PublishTagSearchBar)),
      );
      expect(pillColor(tester), glass.fill);
      expect(_translucent(pillColor(tester)), isTrue);
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('the tag search on a glass panel uses the well color', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(style: _toolbarOnly, child: _onToolbarGlass(tagSearch())),
      );
      expect(
        pillColor(tester),
        OnGlass.wellColor(_scheme(tester, find.byType(PublishTagSearchBar))),
      );
    });

    testWidgets('the template search turns translucent with a glass border', (
      tester,
    ) async {
      Widget field() => DiaryTemplateSearchField(
        controller: TextEditingController(),
        focusNode: FocusNode(),
        onChanged: (_) {},
      );
      await tester.pumpWidget(_host(child: field()));
      expect(
        tester.widget<SearchBar>(find.byType(SearchBar)).backgroundColor,
        isNull,
      );

      await tester.pumpWidget(_host(style: _glass, child: field()));
      final bar = tester.widget<SearchBar>(find.byType(SearchBar));
      final fill = bar.backgroundColor!.resolve(<WidgetState>{})!;
      expect(_translucent(fill), isTrue);
      expect(bar.side, isNotNull);
      expect(find.byType(BackdropFilter), findsNothing);
    });

    Future<void> pumpSearchPage(
      WidgetTester tester, {
      AppGlassStyle? style,
    }) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final settings = await SettingsService.create();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsServiceProvider.overrideWith((ref) async => settings),
            tagListProvider.overrideWith((ref) => Stream.value(const <Tag>[])),
            pagedDiariesProvider.overrideWith(
              (ref, query) => Stream.value(
                PagedDiariesResult(
                  items: const <DiaryWithTags>[],
                  limit: query.limit,
                  hasMore: false,
                ),
              ),
            ),
          ],
          child: _host(style: style, child: const DiarySearchPage()),
        ),
      );
      await tester.pumpAndSettle();
    }

    BoxDecoration searchBarDecoration(WidgetTester tester) => tester
        .widgetList<Container>(
          find.ancestor(
            of: find.byType(TextField),
            matching: find.byType(Container),
          ),
        )
        .map((container) => container.decoration)
        .whereType<BoxDecoration>()
        .first;

    testWidgets('the diary search bar is translucent glass without blur', (
      tester,
    ) async {
      await pumpSearchPage(tester);
      final classic = searchBarDecoration(tester);
      expect(classic.color!.a, greaterThan(0.9));

      await pumpSearchPage(tester, style: _glass);
      final glass = AppGlass.of(tester.element(find.byType(TextField)));
      final decoration = searchBarDecoration(tester);
      expect(decoration.color, glass.fill);
      expect(_translucent(decoration.color!), isTrue);
      expect((decoration.border! as Border).top.color, glass.border!.color);
      expect(
        find.ancestor(
          of: find.byType(TextField),
          matching: find.byType(BackdropFilter),
        ),
        findsNothing,
      );
    });
  });

  group('tag filter chips', () {
    testWidgets('classic keeps the tag tinted chips', (tester) async {
      await tester.pumpWidget(_host(child: _tagBar()));
      expect(
        _chip(tester, 'Work').unselectedColor,
        const Color(0xffaa5500).withValues(alpha: 0.08),
      );
    });

    testWidgets('glass chips are translucent and selection stays distinct', (
      tester,
    ) async {
      await tester.pumpWidget(_host(style: _glass, child: _tagBar()));
      final glass = AppGlass.of(tester.element(find.byType(DiaryTagFilterBar)));
      final idle = _chip(tester, 'Work');
      final picked = _chip(tester, 'Travel');
      expect(idle.unselectedColor, glass.fill);
      expect(_translucent(idle.unselectedColor), isTrue);
      expect(_translucent(picked.selectedColor), isTrue);
      expect(picked.selectedColor, isNot(idle.unselectedColor));
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('the glass header still has exactly two enabled blurs', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          style: _glass,
          child: Builder(
            builder: (context) => HomeChromeScope(
              style: HomeBarResolvedStyle.resolve(
                HomeBarPreset.glass.style,
                Theme.of(context).colorScheme,
              ),
              child: BackdropGroup(
                child: Column(
                  children: <Widget>[
                    const HomeTopBarSurface(
                      solidColor: Color(0xFFEEEEEE),
                      grouped: true,
                      child: SizedBox(height: 68, child: Text('masthead')),
                    ),
                    HomeTopBarSurface(
                      solidColor: const Color(0xFFEEEEEE),
                      grouped: true,
                      child: _tagBar(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final filters = tester
          .renderObjectList<RenderBackdropFilter>(find.byType(BackdropFilter))
          .where((filter) => filter.enabled)
          .toList();
      expect(filters, hasLength(2));
    });
  });

  group('preview back to top', () {
    Future<ScrollController> pump(
      WidgetTester tester, {
      AppGlassStyle? style,
    }) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          style: style,
          child: Stack(
            children: <Widget>[
              ListView.builder(
                controller: controller,
                itemCount: 200,
                itemBuilder: (_, index) =>
                    SizedBox(height: 50, child: Text('row $index')),
              ),
              PositionedDirectional(
                end: 16,
                bottom: 16,
                child: DiaryPreviewBackToTop(controller: controller),
              ),
            ],
          ),
        ),
      );
      return controller;
    }

    Finder surface() => find.descendant(
      of: find.byType(AppGlassFab),
      matching: find.byType(GlassSurface),
    );

    testWidgets('classic keeps the small FAB in an AnimatedOpacity', (
      tester,
    ) async {
      final controller = await pump(tester);
      controller.jumpTo(2000);
      await tester.pumpAndSettle();
      expect(find.byType(AppGlassFab), findsNothing);
      expect(
        find.ancestor(
          of: find.byType(FloatingActionButton),
          matching: find.byType(AnimatedOpacity),
        ),
        findsOneWidget,
      );
      // 经典按钮的点按区仍是 48dp。
      expect(
        tester.getSize(find.byType(FloatingActionButton)),
        const Size(48, 48),
      );
    });

    testWidgets('glass reveals through GlassReveal and scrolls to top', (
      tester,
    ) async {
      final controller = await pump(tester, style: _glass);
      controller.jumpTo(2000);
      final reveals = <double>[];
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          _underOpacity(tester, surface(), Stack),
          isFalse,
          reason: 'frame $frame',
        );
        reveals.add(GlassReveal.of(tester.element(surface())));
      }
      expect(reveals.any((value) => value > 0 && value < 1), isTrue);
      expect(reveals.last, 1);
      final glass = tester.widget<GlassSurface>(surface());
      expect(_translucent(glass.fill), isTrue);
      expect(
        tester
            .widget<BackdropFilter>(
              find.descendant(
                of: surface(),
                matching: find.byType(BackdropFilter),
              ),
            )
            .enabled,
        isTrue,
      );
      // 玻璃与看得见的按钮同为 40dp，外面补回 4dp 点按边，占位仍是 48dp。
      expect(tester.getSize(surface()), const Size(40, 40));
      expect(
        tester.getSize(
          find.ancestor(of: surface(), matching: find.byType(Padding)).first,
        ),
        const Size(48, 48),
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(controller.offset, 0);

      // 点在补回的点按边上同样回到顶部。
      controller.jumpTo(2000);
      await tester.pumpAndSettle();
      final rect = tester.getRect(surface());
      await tester.tapAt(rect.topLeft - const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(controller.offset, 0);
    });
  });

  group('ExpressiveButtonGroup', () {
    Widget buttonGroup() => ExpressiveButtonGroup<int>(
      selected: const <int>{0},
      onSelectionChanged: (_) {},
      segments: const <ButtonSegment<int>>[
        ButtonSegment<int>(value: 0, label: Text('Week')),
        ButtonSegment<int>(value: 1, label: Text('Month')),
      ],
    );

    Material segment(WidgetTester tester, String label) =>
        tester.widget<Material>(
          find
              .descendant(
                of: find.ancestor(
                  of: find.text(label),
                  matching: find.byType(FilledButton),
                ),
                matching: find.byType(Material),
              )
              .first,
        );

    BorderSide sideOf(Material material) =>
        (material.shape! as OutlinedBorder).side;

    testWidgets('classic keeps the opaque tonal segments', (tester) async {
      await tester.pumpWidget(_host(child: buttonGroup()));
      final scheme = _scheme(tester, find.byType(Scaffold));
      expect(segment(tester, 'Week').color, scheme.primary);
      expect(segment(tester, 'Month').color, scheme.surfaceContainerHighest);
      expect(sideOf(segment(tester, 'Month')), BorderSide.none);
    });

    for (final brightness in Brightness.values) {
      testWidgets('glass controls: glass fill and border, no blur '
          '($brightness)', (tester) async {
        await tester.pumpWidget(
          _host(style: _glass, brightness: brightness, child: buttonGroup()),
        );
        final scheme = _scheme(tester, find.byType(Scaffold));
        final glass = AppGlass.of(tester.element(find.text('Month')));
        final month = segment(tester, 'Month');
        expect(_translucent(month.color!), isTrue);
        expect(month.color, glass.fill);
        expect(sideOf(month), glass.border);
        // 选中段仍是主色、不加描边。
        final week = segment(tester, 'Week');
        expect(week.color, scheme.primary);
        expect(sideOf(week), BorderSide.none);
        // 与输入框一样不模糊，即使直接放在页面上。
        expect(find.byType(BackdropFilter), findsNothing);
      });
    }

    testWidgets('classic controls on a glass panel use the well color', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(style: _toolbarOnly, child: _onToolbarGlass(buttonGroup())),
      );
      final scheme = _scheme(tester, find.byType(Scaffold));
      final month = segment(tester, 'Month');
      expect(month.color, OnGlass.wellColor(scheme));
      expect(sideOf(month), BorderSide.none);
      expect(segment(tester, 'Week').color, scheme.primary);
    });
  });

  group('AppGlassControlsTheme', () {
    Future<ThemeData> pumpTheme(
      WidgetTester tester,
      AppGlassStyle style,
    ) async {
      late ThemeData theme;
      await tester.pumpWidget(
        MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          builder: (BuildContext context, Widget? child) => AppGlassScope(
            style: style,
            child: AppGlassControlsTheme(child: child!),
          ),
          home: Builder(
            builder: (context) {
              theme = Theme.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      return theme;
    }

    testWidgets('classic leaves the theme untouched', (tester) async {
      final theme = await pumpTheme(tester, AppGlassStyle.defaults);
      final base = expressiveTestTheme(Brightness.light);
      expect(theme.chipTheme, base.chipTheme);
      expect(theme.inputDecorationTheme, base.inputDecorationTheme);
      expect(theme.switchTheme, base.switchTheme);
    });

    testWidgets('glass controls: chips, inputs and switch tracks go glass', (
      tester,
    ) async {
      final theme = await pumpTheme(tester, _glass);
      final glass = AppGlass.of(tester.element(find.byType(SizedBox)));
      expect(_translucent(glass.fill), isTrue);

      final chip = theme.chipTheme;
      expect(chip.backgroundColor, glass.fill);
      // 选中仍为强调色、不加描边。
      expect(chip.selectedColor, theme.colorScheme.secondaryContainer);
      final side = chip.side! as WidgetStateBorderSide;
      expect(side.resolve(<WidgetState>{}), glass.border);
      expect(
        side.resolve(<WidgetState>{WidgetState.selected}),
        BorderSide.none,
      );

      final input = theme.inputDecorationTheme;
      expect(input.fillColor, glass.fill);
      expect(
        (input.enabledBorder! as OutlineInputBorder).borderSide,
        glass.border,
      );
      // 获得焦点时仍是主色描边。
      expect(
        (input.focusedBorder! as OutlineInputBorder).borderSide.color,
        theme.colorScheme.primary,
      );

      final track = theme.switchTheme.trackColor!;
      expect(track.resolve(<WidgetState>{}), glass.fill);
      expect(track.resolve(<WidgetState>{WidgetState.selected}), isNull);
    });

    testWidgets('a themed FilterChip paints the glass fill', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          builder: (BuildContext context, Widget? child) => AppGlassScope(
            style: _glass,
            child: AppGlassControlsTheme(child: child!),
          ),
          home: Scaffold(
            body: FilterChip(
              label: const Text('Tag'),
              selected: false,
              onSelected: (_) {},
            ),
          ),
        ),
      );
      final glass = AppGlass.of(tester.element(find.text('Tag')));
      // Chip 的底色与描边画在 Ink 的 ShapeDecoration 上。
      final decoration =
          tester
                  .widget<Ink>(
                    find.descendant(
                      of: find.byType(FilterChip),
                      matching: find.byType(Ink),
                    ),
                  )
                  .decoration!
              as ShapeDecoration;
      expect(decoration.color, glass.fill);
      expect((decoration.shape as OutlinedBorder).side, glass.border);
    });
  });

  group('AppGlassField.tonalButtonStyle', () {
    testWidgets('null when classic, glass fill and border otherwise', (
      tester,
    ) async {
      ButtonStyle? classic;
      ButtonStyle? controls;
      ButtonStyle? well;
      await tester.pumpWidget(
        _host(
          child: Builder(
            builder: (context) {
              classic = AppGlassField.tonalButtonStyle(context);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpWidget(
        _host(
          style: _glass,
          child: Builder(
            builder: (context) {
              controls = AppGlassField.tonalButtonStyle(context);
              return const SizedBox();
            },
          ),
        ),
      );
      final glass = AppGlass.of(tester.element(find.byType(SizedBox)));
      await tester.pumpWidget(
        _host(
          style: _toolbarOnly,
          child: _onToolbarGlass(
            Builder(
              builder: (context) {
                well = AppGlassField.tonalButtonStyle(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      final scheme = _scheme(tester, find.byType(Scaffold));
      expect(classic, isNull);
      expect(controls!.backgroundColor!.resolve(<WidgetState>{}), glass.fill);
      // 禁用态交给按钮自己的禁用色。
      expect(
        controls!.backgroundColor!.resolve(<WidgetState>{WidgetState.disabled}),
        isNull,
      );
      expect(controls!.side!.resolve(<WidgetState>{}), glass.border);
      expect(
        well!.backgroundColor!.resolve(<WidgetState>{}),
        OnGlass.wellColor(scheme),
      );
      expect(well!.side, isNull);
    });
  });
}
