import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../diaries/controllers/diary_editor_controller.dart' as editor;
import '../../../diaries/widgets/diary_editor/diary_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/expressive_surfaces.dart';
import '../../../../app/theme/seeded_theme_cache.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../diaries/providers/diary_preview_style_provider.dart';
import '../../../diaries/providers/diary_typography_provider.dart';
import '../../controllers/diary_code_block_style_editor_controller.dart';

/// 代码块样式页的实时预览：一段带行内代码的正文、一个明确指定 Python 的
/// 代码块与一个未指定语言（走自动识别）的 JSON 代码块。
///
/// 正文与代码块都经正式页面同一个 [DiaryEditor] 渲染，代码块
/// 样式取编辑中的草稿（[DiaryCodeBlockStyleEditorController.style]），滑块
/// 拖动中即时重绘；正文外观仍取用户的正文排版。示例文档在首次取到界面语言
/// 时建好（引导文字随语言切换重建），只读、不可交互：预览里不需要光标、
/// 选区与复制，也不该抢滚动手势。明暗由标题栏的按钮单独切换（预览明暗为
/// null 时跟随应用）。
class DiaryCodeBlockStylePreview extends ConsumerStatefulWidget {
  const DiaryCodeBlockStylePreview({
    super.key,
    required this.controller,
    this.bottomPadding = 0,
  });

  final DiaryCodeBlockStyleEditorController controller;
  final double bottomPadding;

  @override
  ConsumerState<DiaryCodeBlockStylePreview> createState() =>
      _DiaryCodeBlockStylePreviewState();
}

class _DiaryCodeBlockStylePreviewState
    extends ConsumerState<DiaryCodeBlockStylePreview> {
  editor.DiaryEditorController? _editor;
  String? _intro;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final intro = context.l10n.codeBlockPreviewIntro;
    if (intro == _intro) {
      return;
    }
    _intro = intro;
    _editor?.dispose();
    _editor = editor.DiaryEditorController(
      document: buildDiaryCodeBlockPreviewDocument(intro),
      selection: editor.Selection.single(path: [0], startOffset: 0),
      readOnly: true,
    );
  }

  @override
  void dispose() {
    _editor?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final appTheme = Theme.of(context);
    final brightness = controller.previewBrightness ?? appTheme.brightness;
    final previewTheme = brightness == appTheme.brightness
        ? appTheme
        : SeededThemeCache.of(
            ref.watch(appThemeSeedColorProvider),
            brightness,
            reduceMotion: MediaQuery.disableAnimationsOf(context),
          );
    final appearance = ref.watch(diaryTextAppearanceProvider);
    final editorController = _editor!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: ClipRect(
            child: Theme(
              data: previewTheme,
              child: Builder(
                builder: (BuildContext context) {
                  final scheme = Theme.of(context).colorScheme;
                  // Material 提供预览明暗下的 DefaultTextStyle：正文基础
                  // 样式取自它，否则正文颜色会停在应用主题的明暗。
                  return Material(
                    color: ExpressiveSurfaces.pageBackground(scheme),
                    child: SingleChildScrollView(
                      primary: false,
                      padding: EdgeInsets.fromLTRB(
                        20,
                        16,
                        20,
                        20 + widget.bottomPadding,
                      ),
                      child: IgnorePointer(
                        child: DiaryEditor(
                          controller: editorController,
                          appearance: appearance,
                          codeBlockStyle: controller.style,
                          shrinkWrap: true,
                          textSelection: false,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 预览示例文档：引导文字 + 行内代码，Python 代码块（明确语言），JSON 代码块
/// （未指定语言，演示自动识别）。代码本身是语言专有内容，不做本地化。
editor.Document buildDiaryCodeBlockPreviewDocument(String intro) {
  // 每行控制在约 30 个字符内：手机宽度、默认字号下不折行，行号与缩进看得
  // 清楚。
  const python = <String>[
    'def greet(name: str) -> str:',
    '    """Say hello politely."""',
    '    times = 3  # repeat count',
    '    words = ["Hi", name] * times',
    '    return " ".join(words)',
    '',
    'print(greet("Jotsy"))',
  ];
  const json = <String>[
    '{',
    '  "title": "Morning walk",',
    '  "steps": 8421,',
    '  "sunny": true',
    '}',
  ];
  List<Map<String, Object?>> block(List<String> lines, Object language) =>
      <Map<String, Object?>>[
        for (final line in lines) ...<Map<String, Object?>>[
          if (line.isNotEmpty) <String, Object?>{'insert': line},
          <String, Object?>{
            'insert': '\n',
            'attributes': <String, Object?>{'code-block': language},
          },
        ],
      ];
  return editor.diaryEditorDocument(
    jsonEncode(<Map<String, Object?>>[
      <String, Object?>{'insert': intro},
      <String, Object?>{
        'insert': 'print("hello")',
        'attributes': <String, Object?>{'code': true},
      },
      <String, Object?>{'insert': '\n'},
      ...block(python, 'python'),
      <String, Object?>{'insert': '\n'},
      ...block(json, true),
    ]),
  );
}
