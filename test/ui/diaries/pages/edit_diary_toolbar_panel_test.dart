import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

/// 编辑页与悬浮工具栏「更多」面板的装配：面板展开时正文让位、光标被推到
/// 面板上方，收起后额外留白归零。
void main() {
  late AppDatabase database;
  late SettingsService settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
  });
  tearDown(() => database.close());

  Future<void> pumpCreatePage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    // 悬浮工具栏只在软键盘弹起且正文有焦点时出现。
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('zh'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            quill.FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const EditDiaryPage(
            entryMode: EditDiaryEntryMode.create,
            restoreCreateDraft: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('expanding More pushes the caret above the panel', (
    tester,
  ) async {
    await pumpCreatePage(tester);
    final controller = tester
        .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
        .controller;
    controller.replaceText(
      0,
      0,
      List<String>.generate(40, (index) => 'line $index').join('\n'),
      null,
    );
    controller.updateSelection(
      TextSelection.collapsed(offset: controller.document.length - 1),
      quill.ChangeSource.local,
    );
    await tester.pumpAndSettle();

    // 停在正文末尾：最后一行刚好露在工具栏上方。
    final body = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    final position = tester.state<ScrollableState>(body.first).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();

    final rawEditor = tester.state<quill.QuillRawEditorState>(
      find.byType(quill.QuillRawEditor),
    );
    double caretBottom() {
      final renderEditor = rawEditor.renderEditor;
      final caret = renderEditor.getLocalRectForCaret(
        controller.selection.extent,
      );
      return renderEditor.localToGlobal(caret.bottomLeft).dy;
    }

    double toolbarTop() =>
        tester.getTopLeft(find.byType(DiaryFloatingToolbar)).dy;

    expect(caretBottom(), lessThanOrEqualTo(toolbarTop()));
    final offsetBefore = position.pixels;

    await tester.tap(find.byTooltip('更多工具'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('插入图片'), findsOneWidget);
    expect(position.pixels, greaterThan(offsetBefore));
    expect(caretBottom(), lessThanOrEqualTo(toolbarTop()));

    await tester.tap(find.byTooltip('收起更多工具'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('插入图片'), findsNothing);
    expect(tester.getSize(find.byType(DiaryToolbarPanelReserve)).height, 0);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('More does not scroll the body while the title is edited', (
    tester,
  ) async {
    await pumpCreatePage(tester);
    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    final body = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    final position = tester.state<ScrollableState>(body.first).position;
    final offsetBefore = position.pixels;

    await tester.tap(find.byTooltip('更多工具'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('插入图片'), findsOneWidget);
    expect(position.pixels, offsetBefore);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
