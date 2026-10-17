import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
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
              quill.FlutterQuillLocalizations.delegate,
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
    expect(find.byType(quill.QuillEditor), findsNothing);
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
    expect(find.byType(quill.QuillEditor), findsOneWidget);
    final controller = tester
        .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
        .controller;
    expect(controller.document.toPlainText().trim(), 'Plain body');
    expect(controller.readOnly, isTrue);
  });
}
