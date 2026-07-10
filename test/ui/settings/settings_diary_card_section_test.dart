import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/sections/settings_diary_card_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('saves the selected tag limit after confirmation', (
    WidgetTester tester,
  ) async {
    final settings = await SettingsService.create();

    await _pumpSection(
      tester,
      settingsAsync: AsyncData<SettingsService>(settings),
    );

    expect(settings.diaryCardTagLimit, 2);
    expect(find.text('Diary card tags'), findsOneWidget);
    expect(find.text('Show up to 2 tags'), findsOneWidget);

    await tester.tap(find.text('Diary card tags'));
    await tester.pumpAndSettle();

    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(5);
    await tester.pump();

    expect(find.text('Show up to 5 tags'), findsOneWidget);

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(settings.diaryCardTagLimit, 5);
    expect(find.text('Show up to 5 tags'), findsOneWidget);

    final recreatedSettings = await SettingsService.create();
    expect(recreatedSettings.diaryCardTagLimit, 5);
  });

  testWidgets('keeps the original limit when the dialog is canceled', (
    WidgetTester tester,
  ) async {
    final settings = await SettingsService.create();

    await _pumpSection(
      tester,
      settingsAsync: AsyncData<SettingsService>(settings),
    );
    await tester.tap(find.text('Diary card tags'));
    await tester.pumpAndSettle();

    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(0);
    await tester.pump();

    expect(find.text('Do not show tags'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(settings.diaryCardTagLimit, 2);
    expect(find.text('Show up to 2 tags'), findsOneWidget);
    expect(find.text('Do not show tags'), findsNothing);
  });

  testWidgets('labels zero as hidden', (WidgetTester tester) async {
    final settings = await SettingsService.create();
    await settings.setDiaryCardTagLimit(0);

    await _pumpSection(
      tester,
      settingsAsync: AsyncData<SettingsService>(settings),
    );

    expect(find.text('Diary card tags'), findsOneWidget);
    expect(find.text('Do not show tags'), findsOneWidget);
  });

  testWidgets('exposes localized slider values to assistive technology', (
    WidgetTester tester,
  ) async {
    await _withSemantics(tester, () async {
      final settings = await SettingsService.create();

      await _pumpSection(
        tester,
        settingsAsync: AsyncData<SettingsService>(settings),
      );
      await tester.tap(find.text('Diary card tags'));
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.byType(Slider)).value,
        'Show up to 2 tags',
      );

      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged!(0);
      await tester.pump();

      expect(
        tester.getSemantics(find.byType(Slider)).value,
        'Do not show tags',
      );
    });
  });

  testWidgets('renders localized loading and error states', (
    WidgetTester tester,
  ) async {
    await _withSemantics(tester, () async {
      await _pumpSection(
        tester,
        settingsAsync: const AsyncLoading<SettingsService>(),
        settle: false,
      );

      expect(
        find.bySemanticsLabel(RegExp('Loading diary card settings')),
        findsOneWidget,
      );

      await _pumpSection(
        tester,
        settingsAsync: AsyncError<SettingsService>(
          StateError('settings failed'),
          StackTrace.empty,
        ),
      );

      expect(find.text('Setting unavailable'), findsOneWidget);
      expect(find.text('Show up to 2 tags'), findsNothing);
    });
  });

  testWidgets(
    'renders the selector without overflow in light and dark themes',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      for (final themeMode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
        final settings = await SettingsService.create();
        await _pumpSection(
          tester,
          settingsAsync: AsyncData<SettingsService>(settings),
          themeMode: themeMode,
        );

        final screenRect = Rect.fromLTWH(
          0,
          0,
          tester.view.physicalSize.width / tester.view.devicePixelRatio,
          tester.view.physicalSize.height / tester.view.devicePixelRatio,
        );
        _expectFitsWithin(tester, find.text('Diary card tags'), screenRect);
        _expectFitsWithin(tester, find.text('Show up to 2 tags'), screenRect);

        await tester.tap(find.text('Diary card tags'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final dialog = find.byType(AlertDialog);
        expect(dialog, findsOneWidget);
        final dialogRect = tester.getRect(dialog);
        _expectFitsWithin(tester, dialog, screenRect);
        _expectFitsWithin(
          tester,
          find.descendant(of: dialog, matching: find.text('Diary card tags')),
          dialogRect,
        );
        _expectFitsWithin(
          tester,
          find.descendant(of: dialog, matching: find.text('Show up to 2 tags')),
          dialogRect,
        );
        _expectFitsWithin(
          tester,
          find.widgetWithText(TextButton, 'Cancel'),
          dialogRect,
        );
        _expectFitsWithin(
          tester,
          find.widgetWithText(TextButton, 'Confirm'),
          dialogRect,
        );
      }
    },
  );
}

Future<void> _withSemantics(
  WidgetTester tester,
  Future<void> Function() body,
) async {
  final semanticsHandle = tester.ensureSemantics();
  try {
    await body();
  } finally {
    semanticsHandle.dispose();
  }
}

Future<void> _pumpSection(
  WidgetTester tester, {
  required AsyncValue<SettingsService> settingsAsync,
  ThemeMode themeMode = ThemeMode.light,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      key: ValueKey<ThemeMode>(themeMode),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      themeMode: themeMode,
      home: Scaffold(
        body: SettingsDiaryCardSection(settingsAsync: settingsAsync),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void _expectFitsWithin(WidgetTester tester, Finder finder, Rect boundary) {
  expect(finder, findsOneWidget);
  final rect = tester.getRect(finder);
  expect(rect.left, greaterThanOrEqualTo(boundary.left));
  expect(rect.top, greaterThanOrEqualTo(boundary.top));
  expect(rect.right, lessThanOrEqualTo(boundary.right));
  expect(rect.bottom, lessThanOrEqualTo(boundary.bottom));
}
