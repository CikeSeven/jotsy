import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';

import '../../controllers/diary_editor_controller.dart';
import 'diary_embed_selectable.dart';

/// 分隔线：独占一行的 1dp 细线，块高 [height]（线居中，上下留白各一半）。
///
/// 画法与上游 `DividerBlockComponentBuilder` 相同；换成自己的块组件只为
/// 共用嵌入块的插入点（[DiaryEmbedSelectable]：左右两侧各一个位置、竖线
/// 光标）——上游的分隔线把插入点画成盖住整块、不连接输入法。整条线都算块旁
/// 的空白（没有 DiaryEmbedContent），点左半边插入点在左侧、右半边在右侧。
class DiaryDividerBlockBuilder extends af.BlockComponentBuilder {
  DiaryDividerBlockBuilder({
    required this.controller,
    required this.lineColor,
    required this.height,
    super.configuration,
  });

  final DiaryEditorController controller;
  final Color lineColor;
  final double height;

  @override
  af.BlockComponentValidate get validate =>
      (node) => node.children.isEmpty;

  @override
  af.BlockComponentWidget build(af.BlockComponentContext context) =>
      _DiaryDividerBlock(
        key: context.node.key,
        node: context.node,
        controller: controller,
        lineColor: lineColor,
        height: height,
        configuration: configuration,
      );
}

class _DiaryDividerBlock extends af.BlockComponentStatefulWidget {
  const _DiaryDividerBlock({
    super.key,
    required super.node,
    required this.controller,
    required this.lineColor,
    required this.height,
    required super.configuration,
  });

  final DiaryEditorController controller;
  final Color lineColor;
  final double height;

  @override
  State<_DiaryDividerBlock> createState() => _DiaryDividerBlockState();
}

class _DiaryDividerBlockState extends State<_DiaryDividerBlock>
    with af.SelectableMixin, DiaryEmbedSelectable {
  @override
  Widget build(BuildContext context) {
    final configuration = widget.configuration;
    // 外边距也包进选区容器：插入点与选区的矩形都按整块（块组件的渲染框）
    // 计算，容器与它重合时才画在对的位置。
    return buildEmbedSelection(
      widget.controller.state,
      Padding(
        padding: configuration.margin(node) + configuration.padding(node),
        child: Container(
          height: widget.height,
          alignment: Alignment.center,
          child: Divider(color: widget.lineColor, thickness: 1),
        ),
      ),
    );
  }
}
