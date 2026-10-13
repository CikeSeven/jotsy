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
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

void main() {
  late AppDatabase database;
  late SettingsService settings;
  late String diaryId;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
    diaryId = await database.createDiary(
      title: 'Rebuild probe',
      contentDocJson: '[{"insert":"line one\\nline two\\n"}]',
      contentText: 'line one\nline two',
      metadataJson: '{}',
    );
  });
  tearDown(() => database.close());

  Future<void> pumpEditPage(WidgetTester tester) async {
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
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EditDiaryPage(diaryId: diaryId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  quill.QuillEditor currentEditor(WidgetTester tester) =>
      tester.widget<quill.QuillEditor>(find.byType(quill.QuillEditor));

  double editorBottomPadding(WidgetTester tester) {
    final scrollView = tester.widget<SingleChildScrollView>(
      find
          .ancestor(
            of: find.byType(quill.QuillEditor),
            matching: find.byType(SingleChildScrollView),
          )
          .first,
    );
    return (scrollView.padding! as EdgeInsets).bottom;
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('keyboard inset animation does not recreate the Quill editor', (
    tester,
  ) async {
    await pumpEditPage(tester);
    final editorBefore = currentEditor(tester);

    // 模拟键盘逐帧弹出：页面会随 viewInsets 重建，body 高度也逐帧变化。
    for (final inset in <double>[80, 160, 240, 300]) {
      tester.view.viewInsets = FakeViewPadding(bottom: inset);
      await tester.pump(const Duration(milliseconds: 16));
      expect(identical(currentEditor(tester), editorBefore), isTrue);
    }
    await unmount(tester);
  });

  testWidgets(
    'dragging the metadata panel updates the spacer without rebuilding Quill',
    (tester) async {
      await pumpEditPage(tester);
      final editorBefore = currentEditor(tester);
      final paddingBefore = editorBottomPadding(tester);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Swipe up to expand')),
      );
      for (var i = 0; i < 4; i++) {
        await gesture.moveBy(const Offset(0, -30));
        await tester.pump(const Duration(milliseconds: 16));
      }

      // 拖到一半（未越过展开阈值）：占位连续增长，Quill 实例不变。
      expect(editorBottomPadding(tester), greaterThan(paddingBefore));
      expect(identical(currentEditor(tester), editorBefore), isTrue);

      await gesture.up();
      await tester.pumpAndSettle();
      await unmount(tester);
    },
  );

  testWidgets(
    'save button tracks edits immediately and clears after reverting',
    (tester) async {
      await pumpEditPage(tester);
      final l10n = tester.element(find.byType(EditDiaryPage)).l10n;
      bool saveEnabled() =>
          tester
              .widget<IconButton>(
                find.ancestor(
                  of: find.byTooltip(l10n.commonSave),
                  matching: find.byType(IconButton),
                ),
              )
              .onPressed !=
          null;
      final titleField = find.widgetWithText(TextField, 'Rebuild probe');
      expect(saveEnabled(), isFalse);

      // 节流的首个变化立即比对：改动后下一帧保存按钮即可用。
      await tester.enterText(titleField, 'Rebuild probe!');
      await tester.pump();
      expect(saveEnabled(), isTrue);

      // 窗口内连续改回原文：尾随比对在窗口结束后清除未保存标记。
      await tester.enterText(
        find.widgetWithText(TextField, 'Rebuild probe!'),
        'Rebuild probe',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(saveEnabled(), isFalse);
      await unmount(tester);
    },
  );
}
