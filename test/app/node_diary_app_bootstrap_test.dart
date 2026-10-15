import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/launch_brand_mark.dart';
import 'package:node_diary/app/node_diary_app.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';
import 'package:node_diary/ui/home/pages/home_page.dart';
import 'package:node_diary/ui/widgets/launch_reveal.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _loader = ValueKey<String>('bootstrap_loader');

Future<void> _pumpApp(
  WidgetTester tester, {
  Duration? diariesDelay,
  bool launchBrandMark = false,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(database.close);
  final settings = await SettingsService.create();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        settingsServiceProvider.overrideWith((ref) async => settings),
        if (diariesDelay != null)
          pagedDiariesProvider.overrideWith(
            (ref, query) => Stream.fromFuture(
              Future<PagedDiariesResult>.delayed(
                diariesDelay,
                () => PagedDiariesResult(
                  items: const <DiaryWithTags>[],
                  limit: query.limit,
                  hasMore: false,
                ),
              ),
            ),
          ),
      ],
      child: NodeDiaryApp(launchBrandMark: launchBrandMark),
    ),
  );
}

/// 推进到首页挂载的那一帧（快速启动，数据由内存库给出）。
Future<void> _pumpUntilHome(WidgetTester tester) async {
  for (var frame = 0; frame < 120; frame++) {
    if (find.byType(HomePage).evaluate().isNotEmpty) {
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  fail('the home page never mounted');
}

/// 首页里每个启动编排槽位当前的不透明度。
List<double> _revealOpacities(WidgetTester tester) => <double>[
  for (final reveal in find.byType(LaunchReveal).evaluate())
    tester
        .widget<Opacity>(
          find
              .descendant(
                of: find.byElementPredicate((element) => element == reveal),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity,
];

/// 原生启动资源里的颜色（亮色取 values，暗色取 values-night）。
Color _nativeColor(String name, {required bool night}) {
  final xml = File(
    'android/app/src/main/res/${night ? 'values-night' : 'values'}/colors.xml',
  ).readAsStringSync();
  final hex = RegExp(
    '<color name="$name">#([0-9A-Fa-f]{6})</color>',
  ).firstMatch(xml)!.group(1)!;
  return Color(0xFF000000 | int.parse(hex, radix: 16));
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

void main() {
  testWidgets('fast bootstrap goes straight home without a loader flash', (
    tester,
  ) async {
    await _pumpApp(tester);
    for (var frame = 0; frame < 25; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byKey(_loader), findsNothing, reason: '$frame');
    }
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('the first bootstrap frame paints a full-screen background', (
    tester,
  ) async {
    await _pumpApp(tester);
    // 首帧设置仍在加载，处于空白底阶段；它必须铺满屏幕，否则什么都不画，
    // Android 移除原生启动背景后会透出黑色 Surface。
    final blank = find.byKey(const ValueKey<String>('bootstrap_blank'));
    expect(blank, findsOneWidget);
    expect(
      tester.getSize(blank),
      tester.view.physicalSize / tester.view.devicePixelRatio,
    );
    await tester.pumpAndSettle();
    await _unmount(tester);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'the first frame continues the native splash in ${brightness.name} mode',
      (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await _pumpApp(tester, launchBrandMark: true);

        // 首帧尚未读到设置，用的是默认种子色主题：底色与图形颜色必须等于原生
        // 启动资源，图形在屏幕正中，系统闪屏移除时画面不变。
        final night = brightness == Brightness.dark;
        final blank = find.byKey(const ValueKey<String>('bootstrap_blank'));
        expect(
          tester.widget<ColoredBox>(blank).color,
          _nativeColor('launch_background', night: night),
        );
        final mark = find.byType(LaunchBrandMark);
        expect(tester.getCenter(mark), tester.getCenter(blank));
        expect(
          Theme.of(tester.element(mark)).colorScheme.primary,
          _nativeColor('launch_brand_mark', night: night),
        );
        await tester.pumpAndSettle();
        await _unmount(tester);
      },
    );
  }

  testWidgets('home rises in slot by slot as the brand mark recedes', (
    tester,
  ) async {
    await _pumpApp(tester, launchBrandMark: true);
    await _pumpUntilHome(tester);

    // 挂载首页的这一帧：顶栏、标签栏、导航与 FAB 都还在起点，品牌图形仍完整。
    final initial = _revealOpacities(tester);
    expect(initial, hasLength(greaterThanOrEqualTo(4)));
    expect(initial, everyElement(0));
    expect(find.byType(LaunchBrandMark), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(LaunchBrandMark), findsNothing);
    expect(_revealOpacities(tester), everyElement(1));
    await _unmount(tester);
  });

  testWidgets('reduce motion goes straight to the settled home', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pumpApp(tester, launchBrandMark: true);
    await _pumpUntilHome(tester);

    expect(find.byType(LaunchBrandMark), findsNothing);
    expect(_revealOpacities(tester), everyElement(1));
    await tester.pumpAndSettle();
    await _unmount(tester);
  });

  testWidgets('slow bootstrap shows the loader for a minimum duration', (
    tester,
  ) async {
    await _pumpApp(tester, diariesDelay: const Duration(milliseconds: 400));

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(_loader), findsNothing);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(_loader), findsOneWidget);

    // 数据在 400ms 到达，但加载页需至少保留到 250 + 500 = 750ms。
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(HomePage), findsNothing);
    expect(find.byKey(_loader), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byKey(_loader), findsNothing);
    await _unmount(tester);
  });

  testWidgets('the diary list is already there on the first home frame', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final settings = await SettingsService.create();
    // 非默认排序：预热必须与日记页首帧的查询完全一致才能命中同一实例。
    await settings.setDiarySortModeRaw('titleAsc');
    await tester.runAsync(
      () => database.createDiary(
        title: 'Warm start',
        contentDocJson: '[{"insert":"body\\n"}]',
        contentText: 'body',
        metadataJson: '{}',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
        child: const NodeDiaryApp(),
      ),
    );
    var sawHome = false;
    for (var frame = 0; frame < 120 && !sawHome; frame++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
      await tester.pump(const Duration(milliseconds: 16));
      if (find.byType(HomePage).evaluate().isEmpty) {
        continue;
      }
      sawHome = true;
      // 首页出现的同一帧里列表已有数据，不会先空白/转圈再硬切。
      expect(find.text('Warm start'), findsOneWidget);
    }
    expect(sawHome, isTrue);
    await _unmount(tester);
  });
}
