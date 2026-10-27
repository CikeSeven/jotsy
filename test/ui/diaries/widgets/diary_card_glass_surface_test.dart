import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/app_surface/widgets/app_page_backdrop.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style.dart';
import 'package:node_diary/ui/diaries/sections/diaries_list_section.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_card_surface_spec.dart';
import 'package:node_diary/ui/diaries/widgets/diary_card_outer_shadow_decoration.dart';
import 'package:node_diary/ui/diaries/widgets/diary_selection_surface.dart';
import 'package:node_diary/ui/widgets/list_item_presence.dart';

import '../../../support/expressive_test_theme.dart';

var _idSeed = 0;

/// 每个用例用新的 id：卡片派生数据按 (diaryId, updatedAt) 全局缓存。
DiaryWithTags _diary() {
  final id = 'glass_card_${_idSeed++}';
  return DiaryWithTags(
    diary: Diary(
      id: _idSeed,
      diaryId: id,
      title: '玻璃卡片',
      content: '[{"insert":"正文\\n"}]',
      contentText: '正文',
      metadata: '{}',
      createdAt: DateTime(2026, 3, 2, 9, 30),
      updatedAt: DateTime(2026, 3, 2, 9, 30),
      isArchived: false,
      isPinned: false,
      isDeleted: false,
    ),
    tags: const <Tag>[],
  );
}

const _glass = DiaryCardStyle(
  surface: DiaryCardSurfaceStyle(
    material: DiaryCardMaterial.glass,
    opacity: 0.55,
    blurSigma: 18,
    shadow: DiaryCardShadowStyle.soft,
  ),
);

AppPageBackdrop _backdrop({required bool image, BackdropKey? key}) {
  final scheme = expressiveTestTheme(Brightness.light).colorScheme;
  return AppPageBackdrop(
    area: null,
    hasBackground: image,
    hasImage: image,
    pageColor: image ? Colors.transparent : scheme.surface,
    solidBarColor: scheme.surface,
    estimatedColor: scheme.surface,
    contentBackdropKey: key,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required DiaryWithTags diary,
  DiaryCardStyle style = _glass,
  AppPageBackdrop? backdrop,
  Set<String> appearing = const <String>{},
  Animation<double>? revealProgress,
  bool highContrast = false,
  DiaryLayoutMode layout = DiaryLayoutMode.list,
  bool settle = true,
}) async {
  Widget list = CustomScrollView(
    slivers: <Widget>[
      DiariesListSection(
        diaries: <DiaryWithTags>[diary],
        layoutMode: layout,
        selectedDiaryIds: const <String>{},
        isSelectionMode: false,
        maxVisibleTags: 3,
        onCreate: () {},
        onOpenEditor: (_, _) {},
        onToggleSelection: (_, _) {},
        cardStyle: style,
        appearingDiaryIds: appearing,
        revealProgress: revealProgress,
      ),
    ],
  );
  if (backdrop != null) {
    list = AppPageBackdropScope(backdrop: backdrop, child: list);
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(Brightness.light),
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(highContrast: highContrast),
        child: child!,
      ),
      home: Scaffold(body: list),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  }
}

/// 卡片表面的底色装饰（半透明 / 玻璃卡片包在外侧投影装饰里）。
BoxDecoration _baseOf(WidgetTester tester, String diaryId) {
  final decoration = tester.widget<Container>(_surfaceOf(diaryId)).decoration;
  return decoration is DiaryCardOuterShadowDecoration
      ? decoration.base
      : decoration! as BoxDecoration;
}

Finder _blurOf(String diaryId) =>
    find.byKey(ValueKey<String>('diary_selection_blur_$diaryId'));

Finder _surfaceOf(String diaryId) =>
    find.byKey(ValueKey<String>('diary_selection_surface_$diaryId'));

BackdropFilter _filter(WidgetTester tester, String diaryId) =>
    tester.widget<BackdropFilter>(_blurOf(diaryId));

/// 卡片的模糊层之上不能有任何透明度层（Opacity / FadeTransition 及其 sliver
/// 版本），否则模糊采不到页面。
void _expectNoOpacityAbove(WidgetTester tester, String diaryId) {
  for (final type in <Type>[
    Opacity,
    FadeTransition,
    SliverOpacity,
    SliverFadeTransition,
    AnimatedOpacity,
  ]) {
    // 只看列表之内：路由转场自带的 FadeTransition 在列表之外、静止时为 1。
    expect(
      find.ancestor(
        of: _blurOf(diaryId),
        matching: find.descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(type),
        ),
      ),
      findsNothing,
      reason: '$type above the card blur',
    );
  }
}

void main() {
  testWidgets('solid cards keep the classic structure without a blur', (
    tester,
  ) async {
    final diary = _diary();
    final key = BackdropKey();
    await _pump(
      tester,
      diary: diary,
      style: DiaryCardStyle.defaults,
      backdrop: _backdrop(image: true, key: key),
    );
    final id = diary.diary.diaryId;
    expect(find.byType(BackdropFilter), findsNothing);
    // 结构：Transform.scale → Container（与改版前相同）。
    final surfaceElement = tester.element(_surfaceOf(id));
    Widget? parent;
    surfaceElement.visitAncestorElements((element) {
      parent = element.widget;
      return false;
    });
    expect(parent, isA<Transform>());
    expect(
      tester.widget<ListItemPresence>(find.byType(ListItemPresence)).glass,
      isFalse,
    );
  });

  testWidgets('glass cards blur through the page key over a background image', (
    tester,
  ) async {
    final diary = _diary();
    final key = BackdropKey();
    await _pump(
      tester,
      diary: diary,
      backdrop: _backdrop(image: true, key: key),
    );
    final id = diary.diary.diaryId;
    final filter = _filter(tester, id);
    expect(filter.backdropGroupKey, same(key));
    expect(filter.enabled, isTrue);
    expect(
      tester.widget<ListItemPresence>(find.byType(ListItemPresence)).glass,
      isTrue,
    );
  });

  testWidgets('glass cards do not blur without a background image', (
    tester,
  ) async {
    final diary = _diary();
    final key = BackdropKey();
    await _pump(
      tester,
      diary: diary,
      backdrop: _backdrop(image: false, key: key),
    );
    final filter = _filter(tester, diary.diary.diaryId);
    expect(filter.enabled, isFalse);
    expect(filter.backdropGroupKey, same(key));
  });

  testWidgets('glass cards do not blur without a shared backdrop key', (
    tester,
  ) async {
    final diary = _diary();
    await _pump(tester, diary: diary);
    final filter = _filter(tester, diary.diary.diaryId);
    expect(filter.enabled, isFalse);
    expect(filter.backdropGroupKey, isNull);
  });

  testWidgets('high contrast turns the blur off', (tester) async {
    final diary = _diary();
    await _pump(
      tester,
      diary: diary,
      backdrop: _backdrop(image: true, key: BackdropKey()),
      highContrast: true,
    );
    expect(_filter(tester, diary.diary.diaryId).enabled, isFalse);
  });

  testWidgets('the blur clip does not clip the card or its shadow', (
    tester,
  ) async {
    final diary = _diary();
    await _pump(
      tester,
      diary: diary,
      backdrop: _backdrop(image: true, key: BackdropKey()),
    );
    final id = diary.diary.diaryId;
    final blurClip = find
        .ancestor(of: _blurOf(id), matching: find.byType(ClipRRect))
        .first;
    expect(
      find.descendant(of: blurClip, matching: _surfaceOf(id)),
      findsNothing,
    );
    final decoration =
        tester.widget<Container>(_surfaceOf(id)).decoration!
            as DiaryCardOuterShadowDecoration;
    expect(decoration.shadows, isNotEmpty);
    // 模糊层与卡片同大。
    expect(tester.getRect(_blurOf(id)), tester.getRect(_surfaceOf(id)));
  });

  for (final layout in DiaryLayoutMode.values) {
    testWidgets('appearing glass cards fade without an opacity layer '
        '(${layout.name})', (tester) async {
      final diary = _diary();
      final id = diary.diary.diaryId;
      await _pump(
        tester,
        diary: diary,
        layout: layout,
        backdrop: _backdrop(image: true, key: BackdropKey()),
        appearing: <String>{id},
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 60));
      _expectNoOpacityAbove(tester, id);
      // 内容在模糊层之外淡入：卡片里的 Opacity 低于 1。
      final contentOpacity = tester.widget<Opacity>(
        find
            .descendant(of: _surfaceOf(id), matching: find.byType(Opacity))
            .first,
      );
      expect(contentOpacity.opacity, lessThan(1));
      expect(_filter(tester, id).enabled, isTrue);
      await tester.pumpAndSettle();
      _expectNoOpacityAbove(tester, id);
    });
  }

  testWidgets('the list refresh pulse reveals glass cards item by item', (
    tester,
  ) async {
    final diary = _diary();
    final id = diary.diary.diaryId;
    final pulse = AnimationController(vsync: tester, value: 0.4);
    addTearDown(pulse.dispose);
    await _pump(
      tester,
      diary: diary,
      backdrop: _backdrop(image: true, key: BackdropKey()),
      revealProgress: pulse,
    );
    _expectNoOpacityAbove(tester, id);
    final contentOpacity = tester.widget<Opacity>(
      find.descendant(of: _surfaceOf(id), matching: find.byType(Opacity)).first,
    );
    expect(contentOpacity.opacity, closeTo(0.4, 0.001));
    final decoration = _baseOf(tester, id);
    expect(decoration.color!.a, closeTo(0.55 * 0.4, 0.01));

    pulse.value = 1;
    await tester.pump();
    final settled = _baseOf(tester, id);
    expect(settled.color!.a, closeTo(0.55, 0.01));
  });

  testWidgets('solid cards fade the refresh pulse with a FadeTransition', (
    tester,
  ) async {
    final diary = _diary();
    final id = diary.diary.diaryId;
    final pulse = AnimationController(vsync: tester, value: 0.4);
    addTearDown(pulse.dispose);
    await _pump(
      tester,
      diary: diary,
      style: DiaryCardStyle.defaults,
      revealProgress: pulse,
    );
    final fades = tester
        .widgetList<FadeTransition>(
          find.ancestor(
            of: _surfaceOf(id),
            matching: find.byType(FadeTransition),
          ),
        )
        .where((fade) => fade.opacity == pulse);
    expect(fades, hasLength(1));
  });

  testWidgets('settled glass cards render at full opacity', (tester) async {
    final diary = _diary();
    await _pump(
      tester,
      diary: diary,
      backdrop: _backdrop(image: true, key: BackdropKey()),
    );
    final id = diary.diary.diaryId;
    expect(find.byType(DiarySelectionSurface), findsOneWidget);
    final decoration = _baseOf(tester, id);
    expect(decoration.color!.a, closeTo(0.55, 0.01));
  });

  group('translucent cards keep their shadow outside', () {
    // 回归：BlurStyle.outer 的圆角矩形投影曾把卡片内部离边缘较远的区域整块
    // 涂上阴影色，透过半透明底色露成正文后的一块深色矩形。这里在白底上画一张
    // 完全透明的卡片（只有投影），卡片内部各处都必须仍是纯白。
    for (final glass in <bool>[false, true]) {
      testWidgets('interior stays clean (glass: $glass)', (tester) async {
        // 测试默认关闭投影模糊；只在本用例里打开，且必须在用例体内还原
        // （tearDown 晚于框架对绘制调试变量的检查）。
        debugDisableShadows = false;
        final boundary = GlobalKey();
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: RepaintBoundary(
              key: boundary,
              child: Container(
                color: const Color(0xFFFFFFFF),
                padding: const EdgeInsets.all(40),
                alignment: Alignment.topLeft,
                child: DiarySelectionSurface(
                  diaryId: 'shadow_probe_$glass',
                  selected: false,
                  compact: false,
                  spec: DiaryCardSurfaceSpec(
                    color: const Color(0x00FFFFFF),
                    radius: 24,
                    borderColor: const Color(0x00000000),
                    borderWidth: 0,
                    glass: glass,
                    blurSigma: glass ? 18 : 0,
                    shadows: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x80000000),
                        blurRadius: 14,
                        offset: Offset(0, 4),
                        blurStyle: BlurStyle.outer,
                      ),
                    ],
                  ),
                  child: const SizedBox(width: 376, height: 142),
                ),
              ),
            ),
          ),
        );
        final pixels = await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          // 与验收截图相同的 2 倍像素比。
          final image = await render.toImage(pixelRatio: 2);
          final data = (await image.toByteData())!;
          int red(double x, double y) => data.getUint8(
            ((y * 2).round() * image.width + (x * 2).round()) * 4,
          );
          final samples = <String, int>{
            for (final (name, x, y) in <(String, double, double)>[
              ('center', 188, 71),
              ('left 48', 48, 71),
              ('right 48', 328, 71),
              ('upper 52', 188, 52),
              ('lower 99', 188, 99),
            ])
              name: red(40 + x, 40 + y),
            // 卡片下方的外侧投影仍在。
            'below': red(40 + 188, 40 + 142 + 6),
          };
          image.dispose();
          return samples;
        });
        debugDisableShadows = true;
        for (final entry in pixels!.entries) {
          if (entry.key == 'below') {
            expect(entry.value, lessThan(250), reason: 'shadow outside');
          } else {
            expect(entry.value, 255, reason: entry.key);
          }
        }
      });
    }
  });
}
