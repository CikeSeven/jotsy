import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';

import '../../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../controllers/diary_callout_editing.dart';
import '../../models/diary_callout_tone.dart';
import 'diary_block_marker_metrics.dart';

/// 提示块（`callout`）：圆角 12 的底色框（底色只取 [DiaryCalloutTone]），框内
/// 行首是图标 emoji（`data.icon`，缺省 [kDiaryCalloutDefaultIcon]），隔 8dp
/// 接正文。
///
/// - 输入：块节点、共用的文字块配置（字形、占位、对齐与块外间距
///   `padding`，见 `diaryTextBlockConfiguration`）、行首标记的几何
///   [DiaryMarkerMetrics]；
/// - 外间距取配置的 `padding`（与引用同为上下 4dp），框内留白固定为上下
///   12dp、左右 14dp；
/// - 图标与正文首行对齐：图标按正文字号排在一个字号见方的格子里，格子中心
///   落在首行字形中心（[DiaryMarkerMetrics.glyphCenter]），与列表标记同一
///   口径；字号、行距与系统字体缩放变化时一起变化；
/// - 对齐（含两端对齐）只作用于正文：图标始终在起始侧，正文在剩下的宽度里
///   按 `data.align` 排版；
/// - 只读（预览、模板预览）与编辑共用；提示块从不挂子块（不在
///   [kDiaryContainerBlockTypes] 里），这里也不画子块。
class DiaryCalloutBlockBuilder extends af.BlockComponentBuilder {
  DiaryCalloutBlockBuilder({super.configuration, required this.markers});

  final DiaryMarkerMetrics markers;

  @override
  af.BlockComponentWidget build(
    af.BlockComponentContext blockComponentContext,
  ) {
    final node = blockComponentContext.node;
    return DiaryCalloutBlock(
      key: node.key,
      node: node,
      configuration: configuration,
      markers: markers,
    );
  }

  @override
  af.BlockComponentValidate get validate =>
      (node) => node.delta != null;
}

/// 框内留白与图标、正文之间的间距。
const EdgeInsets kDiaryCalloutPadding = EdgeInsets.symmetric(
  vertical: 12,
  horizontal: 14,
);
const double kDiaryCalloutRadius = 12;
const double kDiaryCalloutIconGap = 8;

class DiaryCalloutBlock extends af.BlockComponentStatefulWidget {
  const DiaryCalloutBlock({
    super.key,
    required super.node,
    super.configuration = const af.BlockComponentConfiguration(),
    required this.markers,
  });

  final DiaryMarkerMetrics markers;

  @override
  State<DiaryCalloutBlock> createState() => _DiaryCalloutBlockState();
}

class _DiaryCalloutBlockState extends State<DiaryCalloutBlock>
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
    debugLabel: kDiaryBlockCallout,
  );

  @override
  af.BlockComponentConfiguration get configuration => widget.configuration;

  @override
  af.Node get node => widget.node;

  /// 外层由 [af.NestedBlockComponentStatefulWidgetMixin] 包上块的 `margin`；
  /// 提示块没有子块，只画自己。底色不用上游的 `backgroundColor`
  /// （[decoration]），只按底色档位。
  @override
  Widget buildComponent(
    BuildContext context, {
    bool withBackgroundColor = true,
  }) {
    final textDirection = calculateTextDirection(
      layoutDirection: Directionality.maybeOf(context),
    );
    final tone = DiaryCalloutTone.fromId(node.attributes[kDiaryCalloutToneKey]);
    Widget child = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      textDirection: textDirection,
      children: [
        DiaryCalloutIcon(
          icon: diaryCalloutIconOf(node),
          metrics: widget.markers,
        ),
        const SizedBox(width: kDiaryCalloutIconGap),
        Expanded(
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
      ],
    );

    child = Container(
      key: blockComponentKey,
      width: double.infinity,
      padding: kDiaryCalloutPadding,
      decoration: BoxDecoration(
        color: tone.background(Theme.of(context).colorScheme),
        borderRadius: BorderRadius.circular(kDiaryCalloutRadius),
      ),
      child: child,
    );

    child = af.BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      remoteSelection: editorState.remoteSelections,
      blockColor: editorState.editorStyle.selectionColor,
      supportTypes: const [af.BlockSelectionType.block],
      child: child,
    );

    return Padding(padding: padding, child: child);
  }
}

/// 提示块行首的图标：一个字号见方的格子，emoji 按正文字号居中排在格子里，
/// 格子中心对齐正文首行的字形中心；格子所在的列与首行等高。
///
/// 为什么不直接与正文同样式排一行：emoji 字体的上下缘与正文字体不同，
/// 同样字号排出的行高、基线都不一样，直接并排会上下错开。这里用强制的
/// 支柱把 emoji 的行盒压成正好一个字号高，再把格子放到首行字形中心。
class DiaryCalloutIcon extends StatelessWidget {
  const DiaryCalloutIcon({
    super.key,
    required this.icon,
    required this.metrics,
  });

  final String icon;
  final DiaryMarkerMetrics metrics;

  /// 图标列宽：emoji 的字面普遍比一个字号略宽，留出余量免得被裁。
  double get _columnWidth => metrics.em * 1.25;

  @override
  Widget build(BuildContext context) {
    final em = metrics.em;
    return SizedBox(
      width: _columnWidth,
      height: metrics.lineExtent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: metrics.glyphCenter - em / 2,
            height: em,
            child: Center(
              child: Text(
                icon,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                textAlign: TextAlign.center,
                // 字号已按正文缩放换算过，这里不再缩放。
                textScaler: TextScaler.noScaling,
                textHeightBehavior: const TextHeightBehavior(
                  leadingDistribution: TextLeadingDistribution.even,
                ),
                strutStyle: StrutStyle(
                  fontSize: em,
                  height: 1,
                  forceStrutHeight: true,
                  leadingDistribution: TextLeadingDistribution.even,
                ),
                style: TextStyle(
                  fontSize: em,
                  height: 1,
                  leadingDistribution: TextLeadingDistribution.even,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
