import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/content_codec.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

/// 标题与正文共用虚拟滚动，但必须独立持有焦点和输入连接；离开正文时
/// 隐藏光标，回到正文时仍可继续原来的插入点与待输入格式。
void main() {
  late AppDatabase database;
  late SettingsService settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
  });
  tearDown(() => database.close());

  Future<void> pumpPage(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
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
            af.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const EditDiaryPage(entryMode: EditDiaryEntryMode.create),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  ScrollPosition bodyScroll(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      )
      .position;

  for (final brightness in Brightness.values) {
    testWidgets(
      'editing the title after scrolling a long body keeps focus and position '
      'in ${brightness.name} mode',
      (tester) async {
        await pumpPage(tester, brightness: brightness);
        final editor = tester.widget<DiaryEditor>(find.byType(DiaryEditor));
        final controller = editor.controller;
        controller.restoreContent(
          plainTextToContentJson(
            List.generate(40, (index) => 'line $index').join('\n'),
          ),
        );
        final caret = af.Selection.single(path: [39], startOffset: 7);
        controller.select(caret);
        await tester.pumpAndSettle();
        controller.format('bold', true);
        await tester.pumpAndSettle();
        expect(controller.selectionAttributes['bold'], isTrue);
        final originalBody = controller.contentJson;

        // 保持末行的插入点，滚回页首编辑标题；旧逻辑会把标题焦点也算成
        // 正文焦点，随后按仍在末尾的光标把页面拉下去。
        final position = bodyScroll(tester);
        position.jumpTo(position.minScrollExtent);
        await tester.pumpAndSettle();
        final titleFinder = find.byType(TextField).first;
        final title = tester.widget<TextField>(titleFinder);
        await tester.tap(titleFinder);
        await tester.pumpAndSettle();

        expect(title.focusNode!.hasPrimaryFocus, isTrue);
        expect(editor.focusNode!.hasFocus, isFalse);
        expect(controller.state.selection, isNull);
        final offsetAtTitle = position.pixels;

        // 焦点交接时输入法可能先收起再升高；每一帧都只能照顾标题。
        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pumpAndSettle();
        for (var step = 1; step <= 10; step++) {
          tester.view.viewInsets = FakeViewPadding(bottom: 30.0 * step);
          await tester.pump(const Duration(milliseconds: 16));
          expect(title.focusNode!.hasPrimaryFocus, isTrue);
          expect(editor.focusNode!.hasFocus, isFalse);
          expect(position.pixels, closeTo(offsetAtTitle, 1));
        }
        await tester.pumpAndSettle();
        tester.testTextInput.enterText('修改后的标题');
        await tester.pumpAndSettle();
        expect(title.controller!.text, '修改后的标题');
        expect(controller.contentJson, originalBody);

        // 再回正文才恢复原插入点，待输入的加粗格式也应保留。
        editor.focusNode!.requestFocus();
        await tester.pumpAndSettle();
        expect(title.focusNode!.hasFocus, isFalse);
        expect(editor.focusNode!.hasPrimaryFocus, isTrue);
        expect(controller.state.selection, caret);
        expect(controller.selectionAttributes['bold'], isTrue);
        expect(controller.state.selectionRects(), isNotEmpty);
        expect(tester.testTextInput.hasAnyClients, isTrue);
        expect(tester.takeException(), isNull);
        await unmount(tester);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets('the title owns input before any body text has been entered', (
    tester,
  ) async {
    await pumpPage(tester);
    final editor = tester.widget<DiaryEditor>(find.byType(DiaryEditor));
    final titleFinder = find.byType(TextField).first;
    final title = tester.widget<TextField>(titleFinder);
    await tester.tap(titleFinder);
    await tester.pumpAndSettle();
    tester.testTextInput.enterText('只有标题');
    await tester.pumpAndSettle();

    expect(title.focusNode!.hasPrimaryFocus, isTrue);
    expect(editor.focusNode!.hasFocus, isFalse);
    expect(editor.controller.state.selection, isNull);
    expect(editor.controller.hasContent, isFalse);
    expect(title.controller!.text, '只有标题');
    expect(tester.takeException(), isNull);
    await unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
