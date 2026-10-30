import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../../../l10n/app_localizations.dart';
import '../../controllers/diary_editor_controller.dart';
import '../../controllers/diary_toggle_editing.dart';
import '../../controllers/diary_toggle_state.dart';
import 'diary_block_marker_metrics.dart';

/// 折叠块（`toggle_list`）：标题行 = 行首的展开 / 收起标记 + 标题文字，展开
/// 时子块（折叠的内容）按列表子块的缩进排在下面，收起时子块整个不建。
///
/// - 输入：块节点、共用的文字块配置（字形、占位「折叠块」、对齐与块外间距，
///   见 `diaryTextBlockConfiguration`）、行首标记几何 [DiaryMarkerMetrics] 与
///   编辑会话；
/// - 标记格与列表标记同一套几何：列宽（子块缩进）× 首行高，三角的中心落在
///   首行字形中心、距起始边 11dp（与无序列表圆点同一竖线）；展开时三角
///   顺时针转 90° 朝下，转动经 [ExpressiveMotion]（减少动画时直接到位）；
/// - 对齐（含两端对齐）只作用于标题文字：标记始终在起始侧，标题在剩下的
///   宽度里按 `data.align` 排版（同提示块）；
/// - 收起状态：编辑态读写文档里的 `data.collapsed`（点按标记经
///   [setDiaryToggleCollapsed] 写一步可撤销的事务）；只读（预览、模板预览）
///   点按只改本地显示状态（[diaryToggleViewCollapsed]），从不写文档；
/// - 收起时子块不建组件：被收起的节点没有几何，段落把手与拖动不会落进去
///   （见 `DiaryBlockGaps`）。展开但没有子块时不画任何占位。
class DiaryToggleBlockBuilder extends af.BlockComponentBuilder {
  DiaryToggleBlockBuilder({
    super.configuration,
    required this.markers,
    required this.controller,
  });

  final DiaryMarkerMetrics markers;
  final DiaryEditorController controller;

  @override
  af.BlockComponentWidget build(
    af.BlockComponentContext blockComponentContext,
  ) {
    final node = blockComponentContext.node;
    return DiaryToggleBlock(
      key: node.key,
      node: node,
      configuration: configuration,
      markers: markers,
      controller: controller,
    );
  }

  @override
  af.BlockComponentValidate get validate =>
      (node) => node.delta != null;
}

class DiaryToggleBlock extends af.BlockComponentStatefulWidget {
  const DiaryToggleBlock({
    super.key,
    required super.node,
    super.configuration = const af.BlockComponentConfiguration(),
    required this.markers,
    required this.controller,
  });

  final DiaryMarkerMetrics markers;
  final DiaryEditorController controller;

  @override
  State<DiaryToggleBlock> createState() => _DiaryToggleBlockState();
}

class _DiaryToggleBlockState extends State<DiaryToggleBlock>
    with
        af.SelectableMixin,
        af.DefaultSelectableMixin,
        af.BlockComponentConfigurable,
        af.BlockComponentBackgroundColorMixin,
        af.NestedBlockComponentStatefulWidgetMixin,
        af.BlockComponentTextDirectionMixin,
        af.BlockComponentAlignMixin {
  @override
  final forwardKey = GlobalKey(debugLabel: 'flowy_rich_text');

  @override
  GlobalKey<State<StatefulWidget>> get containerKey => widget.node.key;

  @override
  GlobalKey<State<StatefulWidget>> blockComponentKey = GlobalKey(
    debugLabel: kDiaryBlockToggleList,
  );

  @override
  af.BlockComponentConfiguration get configuration => widget.configuration;

  @override
  af.Node get node => widget.node;

  bool get _readOnly => widget.controller.readOnly;

  /// 当前显示为收起：编辑态按文档，只读按本地显示状态。
  bool get _collapsed =>
      _readOnly ? diaryToggleViewCollapsed(node) : isDiaryToggleCollapsed(node);

  void _toggle() {
    final collapse = !_collapsed;
    if (_readOnly) {
      setState(() => setDiaryToggleViewCollapsed(node, collapse));
      return;
    }
    // 文档改动后上游按节点重建本块，这里不另行 setState。
    setDiaryToggleCollapsed(widget.controller, node, collapsed: collapse);
  }

  /// 取代 [af.NestedBlockComponentStatefulWidgetMixin.build]：收起时只建
  /// 标题行，子块（折叠的内容）整个不建。
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: configuration.margin(node),
      child: node.children.isEmpty || _collapsed
          ? buildComponent(context)
          : buildComponentWithChildren(context),
    );
  }

  @override
  Widget buildComponent(
    BuildContext context, {
    bool withBackgroundColor = true,
  }) {
    final textDirection = calculateTextDirection(
      layoutDirection: Directionality.maybeOf(context),
    );
    final expanded = !_collapsed;
    final padding = this.padding;
    // 块的上下间距分别放进标记与标题里，而不是包在整行外面：标记的点按区
    // 连同上下间距一起算（标记格本身只有首行高），点按标记行的上下边缘
    // 也能展开 / 收起；排出来的位置与整行外包间距完全相同。
    Widget child = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      textDirection: textDirection,
      children: [
        DiaryToggleMarker(
          expanded: expanded,
          metrics: widget.markers,
          textDirection: textDirection,
          padding: EdgeInsets.only(top: padding.top, bottom: padding.bottom),
          onToggle: _toggle,
        ),
        Expanded(
          child: Padding(
            padding: padding,
            child: af.AppFlowyRichText(
              key: forwardKey,
              delegate: this,
              node: widget.node,
              editorState: editorState,
              textAlign: alignment?.toTextAlign ?? textAlign,
              placeholderText: placeholderText,
              textSpanDecorator: (textSpan) => textSpan.updateTextStyle(
                textStyleWithTextSpan(textSpan: textSpan),
              ),
              placeholderTextSpanDecorator: (textSpan) =>
                  textSpan.updateTextStyle(
                    placeholderTextStyleWithTextSpan(textSpan: textSpan),
                  ),
              textDirection: textDirection,
              cursorColor: editorState.editorStyle.cursorColor,
              selectionColor: editorState.editorStyle.selectionColor,
              cursorWidth: editorState.editorStyle.cursorWidth,
            ),
          ),
        ),
      ],
    );

    child = Container(
      key: blockComponentKey,
      width: double.infinity,
      decoration: withBackgroundColor ? decoration : null,
      child: child,
    );

    return af.BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      remoteSelection: editorState.remoteSelections,
      blockColor: editorState.editorStyle.selectionColor,
      supportTypes: const [af.BlockSelectionType.block],
      child: child,
    );
  }
}

/// 折叠块行首的展开 / 收起标记：列表标记同款的标记格（列宽 × 首行高），
/// 三角（`caretRight`，`onSurfaceVariant`）中心落在首行字形中心、距起始边
/// 11dp；展开时转 90° 朝下（从右往左排版时三角朝左、逆时针转）。
///
/// 点按区域是整个标记格连同上下的块间距（[padding]），读屏为“展开 /
/// 收起”按钮。转动是隐式动画，
/// 时长取 [ExpressiveMotion.fast]，减少动画时直接到位。
class DiaryToggleMarker extends StatelessWidget {
  const DiaryToggleMarker({
    super.key,
    required this.expanded,
    required this.metrics,
    required this.onToggle,
    this.textDirection = TextDirection.ltr,
    this.padding = EdgeInsets.zero,
  });

  final bool expanded;
  final DiaryMarkerMetrics metrics;
  final VoidCallback onToggle;
  final TextDirection textDirection;

  /// 标记格外的上下间距（块的上下间距），算进点按区域。
  final EdgeInsets padding;

  /// 16sp 正文下三角图标的字号与中心距起始边的距离。
  static const double _designSize = 14;
  static const double _designCenter = 11;

  @override
  Widget build(BuildContext context) {
    final rtl = textDirection == TextDirection.rtl;
    final size = metrics.dp(_designSize);
    final l10n = context.l10n;
    return Semantics(
      container: true,
      button: true,
      label: expanded ? l10n.diaryToggleCollapse : l10n.diaryToggleExpand,
      onTap: onToggle,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
        child: Container(
          padding: padding,
          width: metrics.width,
          height: metrics.lineExtent + padding.vertical,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 起始侧按标题的文字方向（可能与界面方向不同），不按环境
              // 的 Directionality。
              Positioned(
                left: rtl
                    ? metrics.width - metrics.dp(_designCenter) - size / 2
                    : metrics.dp(_designCenter) - size / 2,
                top: metrics.glyphCenter - size / 2,
                width: size,
                height: size,
                child: AnimatedRotation(
                  turns: expanded ? (rtl ? -0.25 : 0.25) : 0,
                  duration: ExpressiveMotion.duration(
                    context,
                    ExpressiveMotion.fast,
                  ),
                  curve: ExpressiveMotion.effects,
                  child: Center(
                    child: FaIcon(
                      rtl
                          ? FontAwesomeIcons.caretLeft
                          : FontAwesomeIcons.caretRight,
                      size: size,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
