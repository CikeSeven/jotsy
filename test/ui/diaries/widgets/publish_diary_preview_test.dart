import '../../../support/diary_content_test_helpers.dart';
import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/widgets/publish_diary_preview.dart';

import '../../../support/expressive_test_theme.dart';

void main() {
  Future<void> pumpPreview(WidgetTester tester, NewDiaryDraft draft) =>
      tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: expressiveTestTheme(Brightness.light),
            locale: const Locale('en'),
            localizationsDelegates: const [
              ...AppLocalizations.localizationsDelegates,
              quill.AppFlowyEditorLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: PublishDiaryPreview(draft: draft),
              ),
            ),
          ),
        ),
      );

  testWidgets('an empty diary shows the untitled and no-content placeholders', (
    tester,
  ) async {
    await pumpPreview(
      tester,
      const NewDiaryDraft(
        title: '  ',
        contentDocJson: '[{"insert":"\\n"}]',
        contentText: '',
      ),
    );
    expect(find.text('Untitled diary'), findsOneWidget);
    expect(find.text('No content'), findsOneWidget);
    expect(find.byType(DiaryEditor), findsNothing);
  });

  // 正文不是 Delta JSON（旧数据、导入异常）时页面仍能打开，按纯文本显示。
  testWidgets('a body that is not a delta still opens as plain text', (
    tester,
  ) async {
    await pumpPreview(
      tester,
      const NewDiaryDraft(
        title: 'A walk',
        contentDocJson: 'Plain body',
        contentText: 'Plain body',
      ),
    );
    expect(find.text('A walk'), findsOneWidget);
    expect(find.byType(DiaryEditor), findsOneWidget);
    final controller = tester
        .widget<DiaryEditor>(find.byType(DiaryEditor))
        .controller;
    expect(controller.document.toPlainText().trim(), 'Plain body');
    expect(controller.readOnly, isTrue);
  });
}
