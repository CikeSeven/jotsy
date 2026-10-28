import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/l10n/app_localizations_gen_en.dart';
import 'package:node_diary/ui/app_surface/services/app_background_image_cache.dart';
import 'package:node_diary/ui/explore/models/explore_module_id.dart';
import 'package:node_diary/ui/explore/models/explore_settings.dart';
import 'package:node_diary/ui/explore/sections/explore_content_view.dart';
import 'package:node_diary/ui/settings/pages/appearance_language_page.dart';
import 'package:node_diary/ui/settings/pages/explore_layout_page.dart';
import 'package:node_diary/ui/settings/sections/explore_layout/explore_layout_cards_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/explore_page_harness.dart';
import '../../support/expressive_test_theme.dart';

void main() {
  final l10n = AppLocalizationsEn();

  testWidgets('focusing a card opens the cards tab with its options', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final service = await SettingsService.create();
    final settings = await pumpExploreHarness(
      tester,
      ExploreLayoutPage(
        settingsService: service,
        focus: ExploreModuleId.heatmap,
      ),
      size: const Size(1200, 1600),
    );
    expect(settings, isNotNull);
    // 预览是真实卡片。
    expect(find.byType(ExploreContentView), findsOneWidget);
    // 停在“卡片”页，热力图的选项已展开（并滚到可见处）。
    expect(find.text(l10n.exploreLayoutSpan), findsOneWidget);
    expect(find.text(l10n.exploreOptBasis), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(ExploreLayoutCardsTab),
        matching: find.text(l10n.exploreValWords),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      ExploreSettings.decode(
        service.exploreLayoutRaw,
      ).current.module(ExploreModuleId.heatmap).options['basis'],
      'words',
    );
  });

  for (final explore in <bool>[true, false]) {
    testWidgets('appearance settings list the explore entry only when the '
        'explore tab is on ($explore)', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'app.settings.app_features': '{"explore":$explore}',
      });
      final settings = await SettingsService.create();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsServiceProvider.overrideWith((ref) async => settings),
            appBackgroundImageCacheProvider.overrideWith(
              (ref) => AppBackgroundImageCache(loader: (_) async => null),
            ),
          ],
          child: MaterialApp(
            theme: expressiveTestTheme(Brightness.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AppearanceLanguagePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.settingsExploreLayout),
        explore ? findsOneWidget : findsNothing,
      );
    });
  }
}
