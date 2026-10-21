import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/diary_toolbar_preferences.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_hex_input.dart';
import 'package:node_diary/ui/diaries/widgets/diary_floating_toolbar.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diary_templates/models/built_in/diary_template_built_ins.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_json.dart';
import 'package:node_diary/ui/diary_templates/pages/diary_template_editor_page.dart';

import '../../../support/diary_drafts_harness.dart';

/// 模板编辑页：名称必填、插入变量、保存、未保存提醒、正文工具栏不含媒体、
/// “始终显示工具栏”时不等软键盘。
void main() {
  Future<DiaryDraftsHarness> openEditor(
    WidgetTester tester, {
    DiaryTemplate? template,
    bool toolbarAlwaysVisible = false,
  }) async {
    final h = await DiaryDraftsHarness.create(tester);
    await h.settings.setDiaryToolbarAlwaysVisible(toolbarAlwaysVisible);
    await h.pump(
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DiaryTemplateEditorPage(template: template),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return h;
  }

  Future<List<DiaryTemplate>> stored(DiaryDraftsHarness h) async => [
    for (final row in (await h.tester.runAsync(h.database.getDiaryTemplates))!)
      DiaryTemplateJson.fromPayload(row.payload, id: row.templateId)!,
  ];

  Future<void> tapSave(DiaryDraftsHarness h) async {
    await h.tester.tap(find.text(h.l10n.commonSave));
    await h.tester.pumpAndSettle();
    await h.settle();
    await h.tester.pumpAndSettle();
  }

  testWidgets('a template needs a name before it is saved', (tester) async {
    final h = await openEditor(tester);
    await tapSave(h);

    expect(find.byType(DiaryTemplateEditorPage), findsOneWidget);
    expect(find.text(h.l10n.diaryTemplateEditorNameRequired), findsOneWidget);
    expect(await stored(h), isEmpty);
    await h.unmount();
  });

  testWidgets('variables go into the title and everything is saved', (
    tester,
  ) async {
    final h = await openEditor(tester);
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    await tester.tap(find.widgetWithText(ActionChip, '日期'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '{{日期}}',
    );

    await tester.tap(find.text(h.l10n.diaryTemplateEditorTabSettings));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '散步记录');
    await tester.tap(find.widgetWithText(ChoiceChip, '生活'));
    await tester.pumpAndSettle();
    await tapSave(h);

    expect(find.byType(DiaryTemplateEditorPage), findsNothing);
    final saved = (await stored(h)).single;
    expect(saved.name, '散步记录');
    expect(saved.titlePattern, '{{日期}}');
    expect(saved.category, DiaryTemplateCategory.life);
    await h.unmount();
  });

  testWidgets('leaving with unsaved changes asks first', (tester) async {
    final h = await openEditor(tester);
    await tester.enterText(find.byType(TextField).first, '没保存的标题');
    await tester.pump();
    await tester.tap(find.byTooltip(h.l10n.commonBack));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text(h.l10n.commonCancel));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryTemplateEditorPage), findsOneWidget);
    await h.unmount();
  });

  testWidgets('an unchanged saved template closes without asking', (
    tester,
  ) async {
    final h = await openEditor(
      tester,
      template: const DiaryTemplate(
        id: 'mine-1',
        name: '已保存',
        bodyJson: '[{"insert":"正文\\n"}]',
      ),
    );
    await tester.tap(find.byTooltip(h.l10n.commonBack));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(DiaryTemplateEditorPage), findsNothing);
    await h.unmount();
  });

  testWidgets('saving an untouched built-in stores nothing, an edit stores '
      'it under the same id', (tester) async {
    final daily = buildBuiltInDiaryTemplates(
      lookupAppLocalizations(const Locale('zh')),
    ).first;
    final h = await openEditor(tester, template: daily);
    await tapSave(h);
    expect(find.byType(DiaryTemplateEditorPage), findsNothing);
    expect(await stored(h), isEmpty);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(h.l10n.diaryTemplateEditorTabSettings));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '我的每日');
    await tapSave(h);
    expect((await stored(h)).map((t) => (t.id, t.name)), [
      ('builtin.daily', '我的每日'),
    ]);
    await h.unmount();
  });

  testWidgets('the body toolbar leaves out media tools', (tester) async {
    final h = await openEditor(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.tap(find.byType(quill.QuillEditor));
    await tester.pumpAndSettle();

    final toolbar = tester.widget<DiaryFloatingToolbar>(
      find.byType(DiaryFloatingToolbar),
    );
    expect(toolbar.order, isNotEmpty);
    for (final item in [
      DiaryToolbarItem.image,
      DiaryToolbarItem.video,
      DiaryToolbarItem.attachment,
      DiaryToolbarItem.recording,
      DiaryToolbarItem.currentTime,
    ]) {
      expect(toolbar.order, isNot(contains(item)));
    }
    expect(toolbar.order, contains(DiaryToolbarItem.checkList));
    await h.unmount();
  });

  testWidgets('the color code input survives the keyboard closing briefly', (
    tester,
  ) async {
    final h = await openEditor(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.tap(find.byType(quill.QuillEditor));
    await tester.pumpAndSettle();
    // 默认顺序里颜色工具排在后面，收在「更多」里。
    expect(find.byTooltip('文字颜色'), findsNothing);
    await tester.tap(find.byTooltip('更多工具'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('文字颜色'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自定义'));
    await tester.pumpAndSettle();
    final hexField = find.descendant(
      of: find.byType(DiaryColorHexField),
      matching: find.byType(TextField),
    );
    await tester.tap(hexField);
    await tester.pumpAndSettle();

    FocusNode hexFocus() => tester.widget<TextField>(hexField).focusNode!;
    expect(hexFocus().hasFocus, isTrue);

    // 换键盘时键盘高度短暂归零：工具栏与输入框都留着。
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(hexField, findsOneWidget);
    expect(hexFocus().hasFocus, isTrue);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(hexField, findsOneWidget);
    expect(hexFocus().hasFocus, isTrue);

    // 按“完成”应用后回到正文，键盘收起时工具栏照旧隐藏。
    await tester.enterText(hexField, '3A7BD5');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(hexFocus().hasFocus, isFalse);
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(find.byType(DiaryFloatingToolbar), findsNothing);
    await h.unmount();
  });

  testWidgets('the body toolbar stays without a keyboard when always shown', (
    tester,
  ) async {
    final h = await openEditor(tester, toolbarAlwaysVisible: true);
    // 没有软键盘、也还没点正文（接实体键盘时就是这样）：工具栏已经在底部。
    expect(find.byType(DiaryFloatingToolbar), findsOneWidget);

    await tester.tap(find.byType(quill.QuillEditor));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryFloatingToolbar), findsOneWidget);
    await h.unmount();
  });
}
