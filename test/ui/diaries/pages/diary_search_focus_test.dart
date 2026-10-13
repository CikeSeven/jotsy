import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/diary_search_page.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

void main() {
  testWidgets('search field focuses only after the route transition', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = await SettingsService.create();
    final navigatorKey = GlobalKey<NavigatorState>();
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
        child: MaterialApp(
          navigatorKey: navigatorKey,
          theme: expressiveTestTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      ),
    );

    navigatorKey.currentState!.push(DiarySearchPage.buildRoute());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    // 转场途中不弹键盘，避免 viewInsets 动画与路由动画叠加。
    expect(tester.testTextInput.isVisible, isFalse);

    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);
  });
}
