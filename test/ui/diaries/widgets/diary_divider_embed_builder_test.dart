import '../../../support/diary_content_test_helpers.dart';
import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../support/expressive_test_theme.dart';

/// 导入笔记的正文：居中、颜色、背景、字号与分隔线都要能在编辑器里渲染。
const List<Map<String, Object?>> _importedOps = [
  {'insert': '居中标题'},
  {
    'insert': '\n',
    'attributes': {'align': 'center'},
  },
  {
    'insert': {'divider': 'hr'},
  },
  {'insert': '\n'},
  {
    'insert': '红字',
    'attributes': {'color': '#FFFA2A2D', 'size': 'huge'},
  },
  {
    'insert': '黄底',
    'attributes': {'background': '#61FFBF00', 'size': 'small'},
  },
  {'insert': '\n'},
];

void main() {
  for (final brightness in Brightness.values) {
    for (final readOnly in [false, true]) {
      testWidgets('imported formats render ($brightness, readOnly=$readOnly)', (
        tester,
      ) async {
        final controller = DiaryEditorController(
          document: documentFromLegacyDelta(_importedOps),
          selection: quill.Selection.single(path: [0], startOffset: 0),
          readOnly: readOnly,
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: expressiveTestTheme(brightness),
            localizationsDelegates: const [
              ...AppLocalizations.localizationsDelegates,
              quill.AppFlowyEditorLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: nativeTestEditor(controller: controller)),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        final divider = tester.widget<Divider>(find.byType(Divider));
        final scheme = Theme.of(
          tester.element(find.byType(Divider)),
        ).colorScheme;
        // 分隔线跟随主题色槽，亮暗主题下都可见。
        expect(divider.color, scheme.outlineVariant);
        expect(find.textContaining('居中标题', findRichText: true), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
