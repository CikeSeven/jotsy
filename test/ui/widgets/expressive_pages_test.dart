import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_header.dart';
import 'package:node_diary/ui/settings/pages/settings_page.dart';
import 'package:node_diary/ui/settings/sections/settings_theme_section.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';
import 'package:node_diary/ui/widgets/bottom_nav.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/expressive_test_theme.dart';

// 可选输出真实 widget 渲染供人工检查；普通测试不写文件、不维护易漂移的像素快照。
const _writePreviews = bool.fromEnvironment('EXPRESSIVE_PREVIEWS');
const _previewKey = ValueKey('expressive-preview');

void main() {
  setUpAll(() async {
    if (!_writePreviews) return;
    final fonts = {
      'HarmonyOSSansSC':
          'assets/fonts/harmonyos_sans_sc/HarmonyOS_Sans_SC_Regular.ttf',
      'packages/font_awesome_flutter/FontAwesomeSolid':
          'packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Free-Solid-900.otf',
      'packages/font_awesome_flutter/FontAwesomeRegular':
          'packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Free-Regular-400.otf',
    };
    for (final font in fonts.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final brightness in Brightness.values) {
    for (final locale in ['en', 'zh']) {
      testWidgets(
        'settings and navigation fit $locale at 320dp in $brightness',
        (tester) async {
          _phone(tester, const Size(320, 800));
          final theme = expressiveTestTheme(brightness);
          await tester.pumpWidget(
            _app(
              brightness: brightness,
              locale: locale,
              child: Scaffold(
                body: SettingsPage(
                  pageBackgroundColor: theme.colorScheme.surface,
                ),
                bottomNavigationBar: BottomNav(
                  items: const [
                    BottomNavItem(
                      label: 'Diaries',
                      icon: FontAwesomeIcons.book,
                    ),
                    BottomNavItem(
                      label: 'Calendar',
                      icon: FontAwesomeIcons.calendar,
                    ),
                    BottomNavItem(
                      label: 'Explore',
                      icon: FontAwesomeIcons.compass,
                    ),
                    BottomNavItem(
                      label: 'Settings',
                      icon: FontAwesomeIcons.gear,
                    ),
                  ],
                  selectedIndex: 3,
                  onTap: (_) {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(Card), findsAtLeastNWidgets(4));
          expect(tester.takeException(), isNull);
          if (locale == 'zh') {
            await _preview(tester, 'settings-${brightness.name}');
          }
        },
      );
    }

    testWidgets(
      'theme selection and scale dialog remain usable in $brightness',
      (tester) async {
        _phone(tester, const Size(360, 900));
        final settings = await SettingsService.create();
        await tester.pumpWidget(
          _app(
            brightness: brightness,
            child: Scaffold(
              appBar: const AppTopBar(title: Text('Appearance')),
              body: SingleChildScrollView(
                child: SettingsThemeSection(settingsAsync: AsyncData(settings)),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Dark'));
        await tester.pumpAndSettle();
        expect(settings.themeModeNotifier.value, ThemeMode.dark);
        expect(tester.takeException(), isNull);
        await _preview(tester, 'appearance-${brightness.name}');

        final l10n = AppLocalizations.of(
          tester.element(find.byType(SettingsThemeSection)),
        );
        await tester.tap(find.text(l10n.settingsFontScale));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await _preview(tester, 'dialog-${brightness.name}');
        await tester.tap(find.text(l10n.commonCancel));
        await tester.pumpAndSettle();
        expect(
          settings.fontScaleNotifier.value,
          SettingsService.defaultFontScale,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('calendar header keeps all actions separate on narrow screens', (
    tester,
  ) async {
    _phone(tester, const Size(320, 640));
    var previous = 0;
    var next = 0;
    var today = 0;
    await tester.pumpWidget(
      _app(
        child: Scaffold(
          body: Stack(
            children: [
              CalendarHeader(
                title: 'September 2026',
                onJumpToToday: () => today++,
                onPreviousMonth: () => previous++,
                onNextMonth: () => next++,
                onPickDate: () {},
              ),
            ],
          ),
        ),
      ),
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(CalendarHeader)),
    );
    await tester.tap(find.byTooltip(l10n.autoT0184));
    await tester.tap(find.byTooltip(l10n.autoT0185));
    await tester.tap(find.byTooltip(l10n.autoT0180));
    expect([previous, next, today], [1, 1, 1]);
    expect(
      tester
          .getRect(find.text('September 2026'))
          .overlaps(tester.getRect(find.text(l10n.autoT0183))),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
}

void _phone(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _app({
  required Widget child,
  Brightness brightness = Brightness.light,
  String locale = 'en',
}) => MaterialApp(
  theme: expressiveTestTheme(brightness),
  locale: Locale(locale),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => RepaintBoundary(key: _previewKey, child: child),
  home: child,
);

Future<void> _preview(WidgetTester tester, String name) async {
  if (!_writePreviews) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_previewKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/expressive-review/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
