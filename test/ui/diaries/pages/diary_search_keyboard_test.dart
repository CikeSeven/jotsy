import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/diary_search_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_card/diary_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

void main() {
  testWidgets('keyboard animation does not rebuild the result cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = await SettingsService.create();
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.runAsync(() async {
      for (var i = 0; i < 12; i++) {
        await database.createDiary(
          title: 'Trip $i',
          contentDocJson: '[{"insert":"Trip notes $i\\n"}]',
          contentText: 'Trip notes $i',
          metadataJson: '{}',
        );
      }
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const DiarySearchPage(initialKeyword: 'Trip'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DiaryCard), findsWidgets);

    // 只数动画前就在屏上的卡片：视口变高时新滚进来的卡片是首次构建。
    final shown = find.byType(DiaryCard).evaluate().toSet();
    var cardBuilds = 0;
    debugOnRebuildDirtyWidget = (Element element, bool builtOnce) {
      if (shown.contains(element)) cardBuilds++;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);
    // 键盘逐帧升起再收起：结果列表区逐帧变矮又变高，已在屏上的卡片一次都
    // 不重建。
    for (final inset in <double>[60, 120, 180, 240, 300, 200, 100, 0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: inset);
      await tester.pump(const Duration(milliseconds: 16));
    }
    debugOnRebuildDirtyWidget = null;
    expect(cardBuilds, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
