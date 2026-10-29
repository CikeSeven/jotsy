import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_features.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/providers/diary_code_block_style_provider.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:node_diary/ui/settings/providers/app_features_provider.dart';

import 'expressive_test_theme.dart';

/// 日记链接的编辑器测试共用：真实的内存数据库 + 正文编辑器。
///
/// 数据库查询与 `@` 菜单的防抖都在真实异步里完成，用 [settleLinkEditor]
/// 推进；每个测试最后调用 [unmountLinkEditor]，drift 关闭流查询时留下的计时器
/// 在测试里冲刷掉。

const DiaryTextAppearance _appearance = DiaryTextAppearance(
  typography: DiaryTypography(),
);

/// 一段正文（段落）的块文档 JSON。
String linkTestDocument(List<Map<String, Object?>> children) => jsonEncode({
  'document': {'type': 'page', 'children': children},
});

Map<String, Object?> linkTestParagraph(List<Map<String, Object?>> delta) => {
  'type': 'paragraph',
  'data': {'delta': delta},
};

Future<void> pumpLinkEditor(
  WidgetTester tester,
  AppDatabase db,
  DiaryEditorController controller, {
  FocusNode? focusNode,
  AppFeatures features = AppFeatures.defaults,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        diaryCodeBlockStyleProvider.overrideWith(_DefaultCodeStyle.new),
        appFeaturesProvider.overrideWith(() => _FixedFeatures(features)),
      ],
      child: MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('zh'),
        localizationsDelegates: const [
          ...AppLocalizations.localizationsDelegates,
          af.AppFlowyEditorLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DiaryEditor(
            controller: controller,
            appearance: _appearance,
            focusNode: focusNode,
          ),
        ),
      ),
    ),
  );
  await settleLinkEditor(tester);
}

/// 逐帧推进几次，期间让真实异步（数据库查询）跑完。
Future<void> settleLinkEditor(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> unmountLinkEditor(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  await tester.pump(Duration.zero);
}

/// 正文取得焦点，返回输入法里已有的文字（之后的输入接在它后面）。
Future<String> focusLinkEditor(WidgetTester tester, FocusNode node) async {
  node.requestFocus();
  await tester.pump();
  return tester.testTextInput.editingState!['text'] as String;
}

/// 软键盘把正文改成“原有文字 + [text]”。字符快捷键（`/`、`@`、回车）只在
/// 一次只输入一个字时触发，调用方须逐字输入它们。
Future<void> typeIntoLinkEditor(
  WidgetTester tester,
  String prefix,
  String text,
) async {
  tester.testTextInput.updateEditingValue(
    TextEditingValue(
      text: '$prefix$text',
      selection: TextSelection.collapsed(offset: prefix.length + text.length),
    ),
  );
  await settleLinkEditor(tester);
}

/// [path] 处文字块的行内 Delta。
List<Map<String, Object?>> linkTestDelta(
  DiaryEditorController controller, [
  List<int> path = const [0],
]) => [
  for (final op in controller.document.nodeAtPath(path)!.delta!.toJson())
    (op as Map).cast<String, Object?>(),
];

class _DefaultCodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}

class _FixedFeatures extends AppFeaturesNotifier {
  _FixedFeatures(this.features);

  final AppFeatures features;

  @override
  AppFeatures build() => features;
}
