import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/widgets/home_hint_visibility_scope.dart';
import '../../controllers/diary_block_language_tracker.dart';
import '../../models/diary_code_block/diary_code_language.dart';
import '../../viewmodels/diary_code_block_look.dart';
import 'diary_code_line_numbers.dart';
import 'diary_editor_spans.dart';
import 'diary_editor_styles.dart';

// 正文代码块（`code`）：原生可编辑/只读块组件，含可选标题栏、动态宽行号列与
// 内部富文本。
//
// 输入：块节点、块配置、解析后的代码块外观 [DiaryCodeBlockLook] 与语言跟踪器；
// 输出：挂载 `node.key` 的顶层块组件（成为上游 `CompositedTransformTarget` 的
// 直接子节点），使 `DefaultSelectableMixin.baseOffset` 自动计入标题栏、内边距
// 与行号槽偏移，选区水滴把手、折叠光标把手与触控区逐像素对齐；
// 副作用：点击标题栏复制按钮写入剪贴板并提示。

/// 代码内容区内边距。
const double _kCodeContentPadding = 10;

/// 代码块的块组件构建器：直接产出带 `node.key` 的 [DiaryCodeBlockSurface]，
/// 不再在外层二次套壳（外层套壳会让 `node.key` 落在外壳内侧、与
/// `node.layerLink` 脱节，导致手机选区把手向左上错位，#381）。
class DiaryCodeBlockBuilder extends af.BlockComponentBuilder {
  DiaryCodeBlockBuilder({
    super.configuration,
    required this.look,
    required this.tracker,
  });

  final DiaryCodeBlockLook look;
  final DiaryBlockLanguageTracker tracker;

  @override
  af.BlockComponentWidget build(af.BlockComponentContext context) =>
      DiaryCodeBlockSurface(
        key: context.node.key,
        node: context.node,
        configuration: configuration,
        look: look,
        tracker: tracker,
      );

  @override
  af.BlockComponentValidate get validate =>
      (node) => node.delta != null;
}

/// 代码块组件：标题栏与行号不进入文档或文字偏移，也不参与输入法；行号直接
/// 读取内部 [af.AppFlowyRichText] 实际排版好的 [RenderParagraph] 纵坐标
/// （见 [DiaryCodeLineNumbersPainter]）。
class DiaryCodeBlockSurface extends af.BlockComponentStatefulWidget {
  const DiaryCodeBlockSurface({
    super.key,
    required super.node,
    super.configuration = const af.BlockComponentConfiguration(),
    required this.look,
    required this.tracker,
  });

  final DiaryCodeBlockLook look;
  final DiaryBlockLanguageTracker tracker;

  @override
  State<DiaryCodeBlockSurface> createState() => _DiaryCodeBlockSurfaceState();
}

class _DiaryCodeBlockSurfaceState extends State<DiaryCodeBlockSurface>
    with
        af.SelectableMixin,
        af.DefaultSelectableMixin,
        af.BlockComponentConfigurable,
        af.BlockComponentBackgroundColorMixin,
        af.NestedBlockComponentStatefulWidgetMixin,
        af.BlockComponentTextDirectionMixin {
  @override
  final forwardKey = GlobalKey(debugLabel: 'flowy_rich_text');

  @override
  GlobalKey<State<StatefulWidget>> get containerKey => widget.node.key;

  @override
  GlobalKey<State<StatefulWidget>> blockComponentKey = GlobalKey(
    debugLabel: kDiaryBlockCode,
  );

  @override
  af.BlockComponentConfiguration get configuration => widget.configuration;

  @override
  af.Node get node => widget.node;

  String? _cachedText;
  List<int> _cachedLineStarts = const [0];

  List<int> _lineStartsFor(String text) {
    if (_cachedText == text) return _cachedLineStarts;
    _cachedText = text;
    return _cachedLineStarts = diaryCodeLineStarts(text);
  }

  /// 取出内部 [af.AppFlowyRichText] 实际绘制代码正文的 [RenderParagraph]：
  /// 上游在它的 Stack 中先放占位 RichText、最后放正文 RichText。
  RenderParagraph? _codeParagraph() {
    final root = forwardKey.currentContext;
    if (root is! Element) return null;
    RenderParagraph? result;
    void visit(Element element) {
      final object = element.renderObject;
      if (element.widget is RichText && object is RenderParagraph) {
        result = object;
      }
      element.visitChildElements(visit);
    }

    root.visitChildElements(visit);
    return result;
  }

  @override
  Widget buildComponent(
    BuildContext context, {
    bool withBackgroundColor = true,
  }) {
    final look = widget.look;
    final text = node.delta?.toPlainText() ?? '';
    final choice = DiaryCodeLanguageChoice.fromAttributeValue(
      node.attributes['language'],
    );
    final detected = diaryBlockHighlightLanguage(
      node,
      text,
      look,
      widget.tracker,
    );
    final l10n = context.l10n;
    final label = choice.isPlain
        ? l10n.codeBlockLanguagePlain
        : diaryCodeLanguageById(choice.languageId ?? detected ?? '')?.name ??
              l10n.codeBlockLabelGeneric;
    final scaler = diaryEditorTextScaler(context);
    // 合并编辑器正文基础样式，使“跟随正文字体”时行号与槽宽测量拿到与
    // AppFlowyRichText 完全一致的字族与字重。
    final resolvedStyle = editorState.editorStyle.textStyleConfiguration.text
        .merge(look.codeTextStyle);
    final lineStarts = look.lineNumbers ? _lineStartsFor(text) : const [0];
    final gutterMetrics = look.lineNumbers
        ? diaryCodeGutterMetrics(
            lineCount: lineStarts.length,
            style: resolvedStyle,
            scaler: scaler,
          )
        : null;

    final richText = SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.ltr,
        children: [
          af.AppFlowyRichText(
            key: forwardKey,
            delegate: this,
            node: widget.node,
            editorState: editorState,
            // 代码按原文排版，固定左对齐、从左到右，不随段对齐拉开空格。
            textAlign: TextAlign.start,
            placeholderText: ' ',
            textSpanDecorator: (textSpan) => textSpan.updateTextStyle(
              textStyleWithTextSpan(textSpan: textSpan),
            ),
            placeholderTextSpanDecorator: (textSpan) => textSpan
                .updateTextStyle(textStyleWithTextSpan(textSpan: textSpan)),
            textDirection: TextDirection.ltr,
            cursorColor: editorState.editorStyle.cursorColor,
            selectionColor: editorState.editorStyle.selectionColor,
            cursorWidth: editorState.editorStyle.cursorWidth,
          ),
        ],
      ),
    );

    Widget surface = DecoratedBox(
      key: blockComponentKey,
      decoration: BoxDecoration(
        color: look.palette.background,
        borderRadius: BorderRadius.circular(look.style.radius),
        border: look.style.border
            ? Border.all(color: look.palette.border, width: 0.8)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (look.header) _buildHeader(context, label, text),
          Padding(
            padding: const EdgeInsets.all(_kCodeContentPadding),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final clamped = gutterMetrics == null
                    ? null
                    : clampDiaryCodeGutterMetrics(
                        gutterMetrics,
                        constraints.maxWidth,
                      );
                final gutter = clamped?.width ?? 0.0;
                final numberRight = clamped?.numberRight ?? 0.0;
                final contentWidth = (constraints.maxWidth - gutter).clamp(
                  1.0,
                  double.infinity,
                );
                return Stack(
                  children: [
                    if (gutter > 0)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: DiaryCodeLineNumbersPainter(
                              paragraphFinder: _codeParagraph,
                              text: text,
                              lineStarts: lineStarts,
                              style: resolvedStyle,
                              color: look.palette.lineNumber,
                              numberRight: numberRight,
                              contentWidth: contentWidth,
                              scaler: scaler,
                              highlightLanguage: detected,
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: EdgeInsets.only(left: gutter),
                      child: richText,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );

    surface = af.BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      remoteSelection: editorState.remoteSelections,
      blockColor: editorState.editorStyle.selectionColor,
      supportTypes: const [af.BlockSelectionType.block],
      child: surface,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: DiaryCodeBlockLook.blockGap,
      ),
      child: surface,
    );
  }

  Widget _buildHeader(BuildContext context, String label, String text) {
    final look = widget.look;
    final l10n = context.l10n;
    return Container(
      height: DiaryCodeBlockLook.headerHeight,
      padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
      decoration: BoxDecoration(
        color: look.palette.header,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(look.style.radius),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: look.palette.foreground),
            ),
          ),
          IconButton(
            tooltip: l10n.codeBlockCopy,
            constraints: const BoxConstraints.tightFor(width: 36, height: 32),
            padding: EdgeInsets.zero,
            icon: FaIcon(
              FontAwesomeIcons.copy,
              size: 13,
              color: look.palette.foreground,
            ),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) {
                HomeHintVisibilityScope.showTrackedSnackBar(
                  context: context,
                  snackBar: SnackBar(content: Text(l10n.codeBlockCopied)),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
