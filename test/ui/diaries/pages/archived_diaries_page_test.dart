import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/widgets/diary_selection_surface.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/archived_diaries_page.dart';
import 'package:node_diary/ui/settings/pages/recycle_bin_page.dart';
import 'package:node_diary/ui/settings/widgets/recycle_bin_tile.dart';
import 'package:node_diary/ui/widgets/empty_hint.dart';
import 'package:node_diary/ui/widgets/list_item_presence.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

Future<AppDatabase> _pumpPage(
  WidgetTester tester,
  Widget page, {
  required Future<void> Function(AppDatabase db, String id) prepare,
}) async {
  tester.view.physicalSize = const Size(400, 860);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(database.close);
  final settings = await SettingsService.create();
  final id = await database.createDiary(
    title: 'Stored diary',
    contentDocJson: '[{"insert":"body\\n"}]',
    contentText: 'body',
    metadataJson: '{}',
  );
  await prepare(database, id);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        settingsServiceProvider.overrideWith((ref) async => settings),
      ],
      child: MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return database;
}

double _presenceHeight(WidgetTester tester) =>
    tester.getSize(find.byType(ListItemPresence).first).height;

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

void main() {
  testWidgets('archive bulk unarchive collapses the card before committing', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      const ArchivedDiariesPage(),
      prepare: (db, id) => db.archiveDiary(id),
    );
    final fullHeight = _presenceHeight(tester);

    await tester.longPress(_storedCard());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('取消归档'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    // 收起动画进行中：条目仍在列表里但高度在缩小。
    expect(_presenceHeight(tester), lessThan(fullHeight));
    expect(_presenceHeight(tester), greaterThan(0));

    await tester.pumpAndSettle();
    expect(find.byType(EmptyHint), findsOneWidget);
    expect(find.text('Stored diary'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await _unmount(tester);
  });

  testWidgets('archive swipe unarchive removes the dismissed card at once', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      const ArchivedDiariesPage(),
      prepare: (db, id) => db.archiveDiary(id),
    );

    await tester.drag(_storedCard(), const Offset(-500, 0));
    await tester.pumpAndSettle();
    // 已 dismiss 的 Dismissible 若仍留在树中会抛断言。
    expect(tester.takeException(), isNull);
    expect(find.text('Stored diary'), findsNothing);
    expect(find.byType(EmptyHint), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await _unmount(tester);
  });

  testWidgets('desktop right-click offers unarchive and it unarchives', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      const ArchivedDiariesPage(),
      prepare: (db, id) => db.archiveDiary(id),
    );
    // 桌面上没有左滑（Dismissible），右键菜单代替。
    expect(find.byType(Dismissible), findsNothing);
    await tester.tap(
      _storedCard(),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(find.text('归档'), findsNothing);
    await tester.tap(find.text('取消归档'));
    await tester.pumpAndSettle();
    expect(find.byType(EmptyHint), findsOneWidget);
    expect(find.text('已取消归档 1 条日记'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await _unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('recycle bin restore collapses the row then shows empty state', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      const RecycleBinPage(),
      prepare: (db, id) => db.softDeleteDiary(id),
    );
    final fullHeight = _presenceHeight(tester);

    await tester.tap(find.byType(RecycleBinTile));
    await tester.pumpAndSettle();
    // 勾选后底部升起操作栏。
    await tester.tap(find.text('恢复'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(_presenceHeight(tester), lessThan(fullHeight));

    await tester.pumpAndSettle();
    expect(find.byType(EmptyHint), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await _unmount(tester);
  });
}

/// 整张卡片：点按/长按/拖动由叠在内容之上的前景墨水层接收，直接对文字取点
/// 会命中墨水层而非文字本身。
Finder _storedCard() => find.ancestor(
  of: find.text('Stored diary'),
  matching: find.byType(DiarySelectionSurface),
);
