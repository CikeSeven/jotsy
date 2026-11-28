import 'package:appflowy_editor/appflowy_editor.dart' as quill;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_toolbar_preferences.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/pages/publish_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_recording_panel.dart';
import 'package:node_diary/ui/widgets/floating_top_bar/floating_action_island.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';
import '../../../support/publish_panel_driver.dart';

/// 新建日记页（表单式）的浮岛顶栏：发布为纸飞机图标并位于“更多”左侧，
/// 录音面板打开等忙碌态下发布图标停用。
void main() {
  late AppDatabase database;
  late SettingsService settings;

  Future<void> prepare({bool showRecordingToolbar = false}) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
    if (showRecordingToolbar) {
      await settings.setDiaryToolbarAlwaysVisible(true);
      await settings.setDiaryToolbarOrderRaw(
        encodeDiaryToolbarOrder(const <DiaryToolbarItem>[
          DiaryToolbarItem.recording,
        ]),
      );
    }
  }

  tearDown(() => database.close());

  Future<void> openCreatePage(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
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
          locale: const Locale('zh'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            quill.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const EditDiaryPage(
                      entryMode: EditDiaryEntryMode.create,
                    ),
                  ),
                ),
                child: const Text('Open create'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open create'));
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'create page top bar places paper-plane publish icon left of More '
      '(${brightness.name})',
      (tester) async {
        await prepare();
        await openCreatePage(tester, brightness: brightness);
        final l10n = tester.element(find.byType(EditDiaryPage)).l10n;

        final publish = find.ancestor(
          of: find.byTooltip(l10n.autoT0136),
          matching: find.byType(IconButton),
        );
        final more = find.byTooltip(l10n.diaryEditorMoreActions);
        expect(publish, findsOneWidget);
        expect(more, findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(FloatingActionIsland),
            matching: find.byType(FilledButton),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: publish,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is FaIcon &&
                  widget.icon == FontAwesomeIcons.paperPlane.data,
            ),
          ),
          findsOneWidget,
        );
        expect(
          tester.getRect(publish).center.dx,
          lessThan(tester.getRect(more).center.dx),
        );

        await tester.enterText(find.byType(TextField).first, '晚风');
        await tester.pump();
        await tester.tap(publish);
        await tester.pump();
        await PublishPanelDriver(tester).waitUntilPublished();
        await tester.pumpAndSettle();
        expect(find.byType(PublishDiaryPage), findsOneWidget);
        expect(tester.takeException(), isNull);
        await unmount(tester);
      },
    );
  }

  testWidgets('publish icon disables while the recording panel is open', (
    tester,
  ) async {
    await prepare(showRecordingToolbar: true);
    await openCreatePage(tester);
    final l10n = tester.element(find.byType(EditDiaryPage)).l10n;

    final publish = find.ancestor(
      of: find.byTooltip(l10n.autoT0136),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(publish).onPressed, isNotNull);

    await tester.tap(find.byTooltip('录音'));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryRecordingPanel), findsOneWidget);
    expect(tester.widget<IconButton>(publish).onPressed, isNull);

    // 返回键关闭录音面板后，发布图标恢复可用。
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(DiaryRecordingPanel), findsNothing);
    expect(tester.widget<IconButton>(publish).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
