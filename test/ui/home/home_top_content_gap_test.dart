import 'dart:async';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/node_diary_app.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_settings.dart';
import 'package:node_diary/ui/app_surface/services/app_background_image_cache.dart';
import 'package:node_diary/ui/app_surface/services/app_background_image_pipeline.dart';
import 'package:node_diary/ui/app_surface/widgets/app_page_backdrop.dart';
import 'package:node_diary/ui/diaries/providers/diary_draft_providers.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_header.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_refresh_capsule.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_card/diary_card.dart';
import 'package:node_diary/ui/diaries/widgets/diary_tag_filter_bar.dart';
import 'package:node_diary/ui/explore/pages/explore_page.dart';
import 'package:node_diary/ui/explore/sections/explore_period_bar.dart';
import 'package:node_diary/ui/home/pages/home_page.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_bottom_bar.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_top_bar_surface.dart';
import 'package:node_diary/ui/widgets/page_header.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 首页四个 Tab 的顶部：有背景时实色顶栏连同状态栏那一条一起是栏色（不
/// 露出背景），顶栏下缘看得见（有背景或玻璃顶栏）时四个 Tab 第一块内容
/// 离顶栏下缘同为 [kHomeTopContentGap]。经典无背景的“贴住”与像素基线另见
/// home_bar_shell_test.dart 与 home_nav_bar_pixel_test.dart。

const double _width = 480;
const double _height = 900;

/// 模拟的状态栏高度。
const double _statusBar = 24;

/// 全局纯色背景：纯色背景下实色栏取该颜色，用它就能认出栏色画在哪里。
const Color _bg = Color(0xFF3A6B8C);

final String _colorBackground = AppSurfaceSettings(
  global: AppBackground(
    kind: AppBackgroundKind.color,
    colorLight: _bg.toARGB32(),
  ),
).encode()!;

/// 全局图片背景（文件由测试里的加载函数代替读取）。
final String _imageBackground = const AppSurfaceSettings(
  global: AppBackground(kind: AppBackgroundKind.image, image: 'bg.png'),
).encode()!;

/// 解码由测试手动放行的加载函数：[release] 之前所有请求都挂着。
class _GatedLoader {
  final Completer<void> _gate = Completer<void>();
  int requests = 0;

  Future<AppBackgroundDecoded?> call(AppBackgroundImageKey key) async {
    requests++;
    await _gate.future;
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 8, 8),
      Paint()..color = const Color(0xFF805030),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(8, 8);
    picture.dispose();
    return AppBackgroundDecoded(image, const Color(0xFF805030));
  }

  void release() => _gate.complete();
}

Future<void> _pumpHome(
  WidgetTester tester, {
  String? surfaceRaw,
  int diaryCount = 3,
  AppBackgroundImageCache? imageCache,
}) async {
  tester.view.physicalSize = const Size(_width, _height);
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = const FakeViewPadding(top: _statusBar);
  tester.view.padding = const FakeViewPadding(top: _statusBar);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{
    'app.settings.app_surface': ?surfaceRaw,
  });
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(database.close);
  final settings = await SettingsService.create();
  await tester.runAsync(() async {
    for (var i = 0; i < diaryCount; i++) {
      await database.createDiary(
        title: 'Diary $i',
        contentDocJson: '[{"insert":"content $i\\n"}]',
        contentText: 'content $i',
        metadataJson: '{}',
      );
    }
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        settingsServiceProvider.overrideWith((ref) async => settings),
        if (imageCache != null)
          appBackgroundImageCacheProvider.overrideWithValue(imageCache),
      ],
      child: const NodeDiaryApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pumpAndSettle();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

AppLocalizations _l10n(WidgetTester tester) =>
    tester.element(find.byType(HomePage)).l10n;

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(HomeBottomBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

/// [page] 里是否有一块 [color] 色的 ColoredBox 盖满状态栏那一条
/// （0..屏宽 × 0..状态栏高）。
bool _statusBarPainted(WidgetTester tester, Finder page, Color color) {
  final boxes = find.descendant(of: page, matching: find.byType(ColoredBox));
  for (final element in boxes.evaluate()) {
    final box = element.widget as ColoredBox;
    if (box.color != color) continue;
    final rect = tester.getRect(find.byWidget(box));
    if (rect.top <= 0 &&
        rect.bottom >= _statusBar &&
        rect.left <= 0 &&
        rect.right >= _width) {
      return true;
    }
  }
  return false;
}

/// 日记页标签栏（顶栏最下面一片）的底缘。
double _tagBarBottom(WidgetTester tester) => tester
    .getRect(
      find
          .ancestor(
            of: find.byType(DiaryTagFilterBar),
            matching: find.byType(HomeTopBarSurface),
          )
          .first,
    )
    .bottom;

/// 四个 Tab 各自“顶栏下缘 → 第一块内容顶端”的距离。
Future<Map<String, double>> _measureGaps(WidgetTester tester) async {
  final l10n = _l10n(tester);
  final gaps = <String, double>{};
  gaps['diaries'] =
      tester.getRect(find.byType(DiaryCard).first).top - _tagBarBottom(tester);

  await _openTab(tester, l10n.navCalendar);
  final calendarPanel = find
      .ancestor(
        of: find.byType(CalendarRefreshCapsule),
        matching: find.byType(Container),
      )
      .first;
  gaps['calendar'] =
      tester.getRect(calendarPanel).top -
      tester.getRect(find.byType(CalendarHeader)).bottom;

  await _openTab(tester, l10n.navExplore);
  final explore = find.byType(ExplorePage);
  gaps['explore'] =
      tester.getRect(find.byType(ExplorePeriodBar)).top -
      tester
          .getRect(
            find.descendant(of: explore, matching: find.byType(PageHeader)),
          )
          .bottom;
  return gaps;
}

void main() {
  // 首页各 Tab 的顶栏恒为玻璃：下缘总看得见，有没有背景都隔同一个 12。
  group('first content sits one shared gap below the top bar', () {
    for (final background in <String?>[null, _colorBackground]) {
      testWidgets('with ${background == null ? 'no' : 'a'} background', (
        tester,
      ) async {
        await _pumpHome(tester, surfaceRaw: background);
        final gaps = await _measureGaps(tester);
        for (final entry in gaps.entries) {
          expect(
            entry.value,
            closeTo(kHomeTopContentGap, 0.01),
            reason: entry.key,
          );
        }
        await _unmount(tester);
      });
    }
  });

  group('the image background has not decoded yet', () {
    testWidgets('the gap is already in place and nothing jumps', (
      tester,
    ) async {
      final loader = _GatedLoader();
      final cache = AppBackgroundImageCache(loader: loader.call);
      addTearDown(cache.dispose);
      await _pumpHome(tester, surfaceRaw: _imageBackground, imageCache: cache);
      final diaries = find.byType(DiariesPage);
      final before = AppPageBackdrop.of(tester.element(diaries));
      expect(loader.requests, greaterThan(0));
      expect(before.hasBackground, isFalse);
      expect(before.wantsBackground, isTrue);
      // 解码前：间距已经是 12（玻璃顶栏的下缘恒看得见）。
      final cardTop = tester.getRect(find.byType(DiaryCard).first).top;
      expect(
        cardTop - _tagBarBottom(tester),
        closeTo(kHomeTopContentGap, 0.01),
      );

      await tester.runAsync(() async {
        loader.release();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      final after = AppPageBackdrop.of(tester.element(diaries));
      expect(after.hasBackground, isTrue);
      expect(after.hasImage, isTrue);
      // 解码完成前后第一张卡片的位置不变（不跳）。
      expect(tester.getRect(find.byType(DiaryCard).first).top, cardTop);
      await _unmount(tester);
    });
  });

  group('the diaries placeholder while settings load', () {
    const fill = Color(0xFF225577);

    Future<void> pumpPlaceholder(
      WidgetTester tester,
      Future<SettingsService> Function() settings,
    ) async {
      tester.view.physicalSize = const Size(_width, _height);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: _statusBar);
      tester.view.viewPadding = const FakeViewPadding(top: _statusBar);
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await tester.pumpWidget(
        ProviderScope(
          // 不自动重试：出错的设置读取直接停在错误分支。
          retry: (_, _) => null,
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            diaryDraftCountProvider.overrideWith((ref) => Stream.value(0)),
            settingsServiceProvider.overrideWith((ref) => settings()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => AppPageBackdropScope(
                // 区域设了纯色背景：页面底透明、实色栏为该颜色。
                backdrop: AppPageBackdrop(
                  area: AppBackgroundArea.diaries,
                  hasBackground: true,
                  hasImage: false,
                  pageColor: Colors.transparent,
                  solidBarColor: fill,
                  estimatedColor: fill,
                ),
                child: const DiariesPage(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('loading pads the status bar with the bar color', (
      tester,
    ) async {
      await pumpPlaceholder(tester, () => Completer<SettingsService>().future);
      expect(_statusBarPainted(tester, find.byType(DiariesPage), fill), isTrue);
      await _unmount(tester);
    });

    testWidgets('an error pads the status bar with the bar color', (
      tester,
    ) async {
      await pumpPlaceholder(tester, () async => throw StateError('boom'));
      await tester.pump();
      expect(find.textContaining('boom'), findsOneWidget);
      expect(_statusBarPainted(tester, find.byType(DiariesPage), fill), isTrue);
      await _unmount(tester);
    });
  });
}
