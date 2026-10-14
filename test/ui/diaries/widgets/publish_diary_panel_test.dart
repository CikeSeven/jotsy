import 'package:flutter/material.dart';
import '../../../support/expressive_test_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/publish_diary_panel.dart';

Widget _panelHost() => MaterialApp(
  theme: expressiveTestTheme(Brightness.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(
    body: Stack(
      children: <Widget>[
        Align(
          alignment: Alignment.bottomCenter,
          child: PublishDiaryPanel(
            saving: false,
            hasCover: false,
            coverLabel: null,
            locating: false,
            weatherLoading: false,
            locationController: TextEditingController(),
            weatherController: TextEditingController(),
            weatherIconCode: null,
            moodEmoji: null,
            energyLevel: 4,
            tags: const <Tag>[],
            tagsLoading: false,
            tagsError: null,
            selectedTagIds: const <int>{},
            onPickCover: () {},
            onResolveLocation: () {},
            onResolveWeather: () {},
            onLocationChanged: (_) {},
            onWeatherChanged: (_) {},
            onCreateTag: () {},
            onToggleTag: (_, _) {},
            onMoodChanged: (_) {},
            onEnergyChanged: (_) {},
            onPublish: () {},
          ),
        ),
      ],
    ),
  ),
);

/// 表头双箭头的纵向缩放：1 = 上指，-1 = 下指。
double _arrowFlip(WidgetTester tester) => tester
    .widget<Transform>(
      find
          .ancestor(
            of: find.byIcon(FontAwesomeIcons.anglesUp.data),
            matching: find.byType(Transform),
          )
          .first,
    )
    .transform
    .storage[5];

void main() {
  testWidgets('time capsule picker stays inside publish panel', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              Align(
                alignment: Alignment.bottomCenter,
                child: PublishDiaryPanel(
                  saving: false,
                  hasCover: false,
                  coverLabel: null,
                  locating: false,
                  weatherLoading: false,
                  locationController: TextEditingController(),
                  weatherController: TextEditingController(),
                  weatherIconCode: null,
                  moodEmoji: null,
                  energyLevel: 4,
                  tags: const <Tag>[],
                  tagsLoading: false,
                  tagsError: null,
                  selectedTagIds: const <int>{},
                  onPickCover: () {},
                  onResolveLocation: () {},
                  onResolveWeather: () {},
                  onLocationChanged: (_) {},
                  onWeatherChanged: (_) {},
                  onCreateTag: () {},
                  onToggleTag: (_, _) {},
                  onMoodChanged: (_) {},
                  onEnergyChanged: (_) {},
                  onPublish: () {},
                  showTimeCapsuleOption: true,
                  timeCapsuleLabel: 'Not sealed',
                  onTimeCapsuleChanged: (_) {},
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Swipe up to expand'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Time lock'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Choose unlock time'), findsOneWidget);
  });

  testWidgets('energy switch toggles between enabled and disabled states', (
    tester,
  ) async {
    double? updatedEnergy;

    Widget buildPanel({required double? energyLevel}) {
      return MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              Align(
                alignment: Alignment.bottomCenter,
                child: PublishDiaryPanel(
                  saving: false,
                  hasCover: false,
                  coverLabel: null,
                  locating: false,
                  weatherLoading: false,
                  locationController: TextEditingController(),
                  weatherController: TextEditingController(),
                  weatherIconCode: null,
                  moodEmoji: null,
                  energyLevel: energyLevel,
                  tags: const <Tag>[],
                  tagsLoading: false,
                  tagsError: null,
                  selectedTagIds: const <int>{},
                  onPickCover: () {},
                  onResolveLocation: () {},
                  onResolveWeather: () {},
                  onLocationChanged: (_) {},
                  onWeatherChanged: (_) {},
                  onCreateTag: () {},
                  onToggleTag: (_, _) {},
                  onMoodChanged: (_) {},
                  onEnergyChanged: (val) => updatedEnergy = val,
                  onPublish: () {},
                ),
              ),
            ],
          ),
        ),
      );
    }

    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 1. Initial state with energy enabled (4.0)
    await tester.pumpWidget(buildPanel(energyLevel: 4));
    await tester.tap(find.text('Swipe up to expand'));
    await tester.pumpAndSettle();

    final energySwitchFinder = find.byType(Switch);
    expect(energySwitchFinder, findsOneWidget);
    await tester.ensureVisible(energySwitchFinder);
    await tester.pumpAndSettle();

    final switchWidgetOn = tester.widget<Switch>(energySwitchFinder);
    expect(switchWidgetOn.value, isTrue);
    expect(find.byType(Slider), findsOneWidget);
    final switchRightOn = tester.getTopRight(energySwitchFinder).dx;

    // Toggle switch off
    await tester.tap(energySwitchFinder);
    await tester.pumpAndSettle();
    expect(updatedEnergy, isNull);

    // 2. Re-pump with energyLevel: null (disabled state)
    await tester.pumpWidget(buildPanel(energyLevel: null));
    await tester.pumpAndSettle();

    final switchWidgetOff = tester.widget<Switch>(energySwitchFinder);
    expect(switchWidgetOff.value, isFalse);
    expect(find.byType(Slider), findsNothing);
    expect(find.text('Not recorded'), findsOneWidget);
    final switchRightOff = tester.getTopRight(energySwitchFinder).dx;
    expect(switchRightOff, equals(switchRightOn));

    // Toggle switch back on
    await tester.ensureVisible(energySwitchFinder);
    await tester.tap(energySwitchFinder);
    await tester.pumpAndSettle();
    expect(updatedEnergy, 4.0);
  });

  testWidgets(
    'collapsed panel sits just above the keyboard, not lifted twice',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // 与编辑页/发布页一致：Scaffold 默认随键盘缩小 body，面板贴 body 底边。
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 0,
                  child: PublishDiaryPanel(
                    saving: false,
                    hasCover: false,
                    coverLabel: null,
                    locating: false,
                    weatherLoading: false,
                    locationController: TextEditingController(),
                    weatherController: TextEditingController(),
                    weatherIconCode: null,
                    moodEmoji: null,
                    energyLevel: 4,
                    tags: const <Tag>[],
                    tagsLoading: false,
                    tagsError: null,
                    selectedTagIds: const <int>{},
                    onPickCover: () {},
                    onResolveLocation: () {},
                    onResolveWeather: () {},
                    onLocationChanged: (_) {},
                    onWeatherChanged: (_) {},
                    onCreateTag: () {},
                    onToggleTag: (_, _) {},
                    onMoodChanged: (_) {},
                    onEnergyChanged: (_) {},
                    onPublish: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      const keyboardTop = 900.0 - 300.0;
      final handleLabel = tester.getRect(find.text('Swipe up to expand'));
      // 收起态面板高 56dp，底部留白 10 + 18；标签应紧贴键盘上方，
      // 而不是被再抬升一个键盘高度。
      expect(handleLabel.bottom, lessThan(keyboardTop));
      expect(keyboardTop - handleLabel.bottom, lessThan(80));
    },
  );
  testWidgets(
    'dragging the panel follows the finger without rebuilding content',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_panelHost());
      expect(_arrowFlip(tester), 1);
      await tester.tap(find.text('Swipe up to expand'));
      await tester.pumpAndSettle();
      expect(_arrowFlip(tester), -1);
      expect(find.text('Swipe down to collapse'), findsOneWidget);

      final contentBefore = tester.widget<Text>(find.text('Cover'));
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Swipe down to collapse')),
      );
      await gesture.moveBy(const Offset(0, 40));
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();

      // 拖到半途：箭头处在压扁/翻转的中间态，而不是在阈值处硬切朝向。
      final flip = _arrowFlip(tester);
      expect(flip, greaterThan(-1));
      expect(flip, lessThan(1));
      // 宽度内缩、淡入逐帧变化，但子页内容没有随进度重建。
      expect(
        identical(tester.widget<Text>(find.text('Cover')), contentBefore),
        isTrue,
      );

      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('header arrow keeps a discrete direction under reduce motion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(_panelHost());
    await tester.tap(find.text('Swipe up to expand'));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Swipe down to collapse')),
    );
    await gesture.moveBy(const Offset(0, 40));
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    expect(_arrowFlip(tester).abs(), 1);

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
