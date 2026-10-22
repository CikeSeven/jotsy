import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_location.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/pages/publish_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/publish_location_precision_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';
import '../../../support/publish_panel_driver.dart';

const _automaticDraft = NewDiaryDraft(
  title: 'A walk',
  contentDocJson: '[{"insert":"A walk\\n"}]',
  contentText: 'A walk',
  location: '北京市 · 望京街道',
  locationFromAuto: true,
  locationLatitude: 39.989410,
  locationLongitude: 116.480881,
  locationAddressComponent: {
    'province': '北京市',
    'city': <Object?>[],
    'district': '朝阳区',
    'township': '望京街道',
    'streetNumber': {'street': '阜通东大街', 'number': '6号'},
  },
);

void main() {
  late AppDatabase database;
  late SettingsService settings;
  late List<Object?> results;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
    results = [];
  });
  tearDown(() => database.close());

  Future<void> openRoute(
    WidgetTester tester,
    WidgetBuilder builder, {
    Brightness brightness = Brightness.light,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(brightness),
          locale: const Locale('en'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            quill.FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  results.add(
                    await Navigator.of(
                      context,
                    ).push<Object?>(MaterialPageRoute(builder: builder)),
                  );
                },
                child: const Text('Open route'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open route'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  PublishPanelDriver panel(WidgetTester tester) => PublishPanelDriver(tester);

  /// 打开发布页，等进入即发表的写库完成，并让“已发表”提示条退场（展开
  /// 的面板在它下面，点不到）。
  Future<void> openPublisher(
    WidgetTester tester, {
    NewDiaryDraft draft = _automaticDraft,
    Brightness brightness = Brightness.light,
  }) async {
    await openRoute(
      tester,
      (_) => PublishDiaryPage(initialDraft: draft),
      brightness: brightness,
      settle: false,
    );
    await panel(tester).waitUntilPublished();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  Finder option(String text) => find.widgetWithText(MenuItemButton, text);

  AppLocalizations l10n(WidgetTester tester) => panel(tester).l10n;

  Future<void> expandPanel(WidgetTester tester) => panel(tester).expand();

  Future<void> openMenu(WidgetTester tester) async {
    await expandPanel(tester);
    final trigger = find.text(l10n(tester).locationPrecisionTitle);
    await tester.ensureVisible(trigger);
    await tester.pumpAndSettle();
    await tester.tap(trigger);
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String label) async {
    await openMenu(tester);
    await tester.tap(option(label));
    await tester.pumpAndSettle();
  }

  /// 返回（先退出子页、收起面板，再补存退场），读出这篇日记保存下来的
  /// 上下文字段。
  Future<Map> publishedContext(WidgetTester tester) async {
    for (var i = 0; i < 3 && results.isEmpty; i++) {
      await tester.binding.handlePopRoute();
      for (var j = 0; j < 10 && results.isEmpty; j++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
    expect(results, hasLength(1));
    final saved = await tester.runAsync(
      () => database.getDiaryWithTagsByDiaryId(results.single! as String),
    );
    final metadata = jsonDecode(saved!.diary.metadata) as Map;
    await tester.pumpAndSettle();
    // 没有任何上下文字段时 metadata 不写 context。
    return metadata['context'] as Map? ?? const {};
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'menu previews each level and publishes the chosen one in ${brightness.name}',
      (tester) async {
        if (brightness == Brightness.dark) {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
        }
        await openPublisher(tester, brightness: brightness);
        expect(panel(tester).precision, DiaryLocationPrecision.township);
        expect(option('City'), findsNothing);

        await openMenu(tester);
        // 每个层级下预览选择后的地址，方便在选择前比较。
        expect(option('北京市'), findsOneWidget);
        expect(option('北京市 · 朝阳区'), findsOneWidget);
        expect(option('北京市 · 朝阳区 · 阜通东大街6号'), findsOneWidget);
        await tester.tap(option('City'));
        await tester.pumpAndSettle();
        expect(option('City'), findsNothing);
        expect(panel(tester).locationText, '北京市');

        await choose(tester, 'Road');
        expect(panel(tester).locationText, '北京市 · 朝阳区 · 阜通东大街');
        await choose(tester, 'House number');
        expect(panel(tester).locationText, '北京市 · 朝阳区 · 阜通东大街6号');
        expect(settings.diaryLocationPrecisionRaw, 'address');

        final context = await publishedContext(tester);
        expect(context['locationPrecision'], 'address');
        expect(context['location'], '北京市 · 朝阳区 · 阜通东大街6号');
        expect((context['geo'] as Map)['latitude'], 39.989410);
        expect(tester.takeException(), isNull);
        await unmount(tester);
      },
    );
  }

  testWidgets('a level saved in the draft is published as is', (tester) async {
    final restored = NewDiaryDraft.fromJson(
      _automaticDraft
          .copyWith(
            location: '北京市',
            locationPrecision: DiaryLocationPrecision.city,
          )
          .toJson(),
    );
    await openPublisher(tester, draft: restored);
    expect(panel(tester).precision, DiaryLocationPrecision.city);
    expect(panel(tester).locationText, '北京市');

    final context = await publishedContext(tester);
    expect(context['locationPrecision'], 'city');
    expect(context['location'], '北京市');
    await unmount(tester);
  });

  testWidgets('a manually edited place keeps its text and its coordinates', (
    tester,
  ) async {
    await openPublisher(tester);
    await expandPanel(tester);
    await tester.enterText(panel(tester).locationField, 'My favourite cafe');
    await tester.pump();

    await openMenu(tester);
    // 手动地点不会被层级改写，预览也随之隐藏。
    expect(option('北京市'), findsNothing);
    await tester.tap(option('City'));
    await tester.pumpAndSettle();
    expect(panel(tester).locationText, 'My favourite cafe');
    expect(panel(tester).precision, DiaryLocationPrecision.city);

    final context = await publishedContext(tester);
    expect(context['location'], 'My favourite cafe');
    expect((context['geo'] as Map)['latitude'], 39.989410);
    await unmount(tester);
  });

  testWidgets('clearing the place stops saving the located coordinates', (
    tester,
  ) async {
    await openPublisher(tester);
    await expandPanel(tester);
    await tester.enterText(panel(tester).locationField, '');
    await tester.pump();

    final context = await publishedContext(tester);
    expect(context.containsKey('location'), isFalse);
    expect(context.containsKey('geo'), isFalse);
    await unmount(tester);
  });

  // 320dp 手机上面板内容宽约 252dp。只挂选择器本身：测试字体按方块
  // 绘制英文，整页会先在面板表头溢出，与这里要验证的菜单无关。
  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
      'the menu stays within a 320dp panel in ${locale.languageCode}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final controller = TextEditingController(text: '北京市 · 望京街道');
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: expressiveTestTheme(Brightness.light),
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: 252,
                  child: PublishLocationPrecisionPicker(
                    precision: DiaryLocationPrecision.township,
                    locationController: controller,
                    addressComponent: _automaticDraft.locationAddressComponent,
                    onChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        final picker = tester.getRect(
          find.byType(PublishLocationPrecisionPicker),
        );
        await tester.tap(find.byType(TextButton));
        await tester.pumpAndSettle();
        expect(option('北京市 · 朝阳区 · 阜通东大街6号'), findsOneWidget);
        final menu = tester.getRect(
          find
              .ancestor(
                of: find.byType(MenuItemButton).first,
                matching: find.byType(Material),
              )
              .first,
        );
        expect(menu.left, greaterThanOrEqualTo(picker.left));
        expect(menu.right, lessThanOrEqualTo(picker.right));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a new diary starts from the last chosen level', (tester) async {
    await settings.setDiaryLocationPrecisionRaw('city');
    await openRoute(
      tester,
      (_) => const EditDiaryPage(entryMode: EditDiaryEntryMode.create),
    );
    await tester.enterText(find.byType(TextField).first, 'Morning walk');
    await tester.pump();
    final l10n = tester.element(find.byType(EditDiaryPage)).l10n;
    await tester.tap(find.byTooltip(l10n.autoT0136));
    await tester.pump();
    await panel(tester).waitUntilPublished();
    await tester.pumpAndSettle();
    expect(panel(tester).precision, DiaryLocationPrecision.city);
    await unmount(tester);
  });
}
