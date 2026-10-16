import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style_settings.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';
import 'diaries_tag_filter_test_support.dart';

void main() {
  testWidgets('the first frame with cards already uses the stored style', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.settings.diary_card_style': DiaryCardStyleSettings.defaults
          .withCurrent(
            const DiaryCardStyle(
              surface: DiaryCardSurfaceStyle(cornerRadius: 10),
            ),
          )
          .encode()!,
    });
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = await SettingsService.create();
    final theme = expressiveTestTheme(Brightness.light);
    final diaries = createGestureDiaries(3);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsServiceProvider.overrideWith((ref) async => settings),
          tagListProvider.overrideWith((ref) => Stream.value(const <Tag>[])),
          pagedDiariesProvider.overrideWith(
            (ref, query) => Stream.value(
              PagedDiariesResult(
                items: diaries,
                limit: query.limit,
                hasMore: false,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: theme,
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiariesPage(pageBackgroundColor: theme.colorScheme.surface),
        ),
      ),
    );

    final surface = find.byKey(
      const ValueKey<String>('diary_selection_surface_diary-1'),
      skipOffstage: false,
    );
    // 逐帧推进：卡片出现的第一帧就必须是存储的圆角，不能先画默认的 24。
    var frames = 0;
    while (surface.evaluate().isEmpty && frames < 60) {
      await tester.pump(const Duration(milliseconds: 16));
      frames++;
    }
    expect(surface, findsOneWidget);
    final decoration =
        tester.widget<Container>(surface).decoration! as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(10));
    await tester.pumpAndSettle();
  });
}
