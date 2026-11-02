import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';

import '../../../../core/database/diary_blocks/diary_blocks_schema.dart';

/// 引用竖条：3dp 圆头竖线，`primary` 55% 透明度，贯穿整块文字的高度；
/// 连续的几行引用连成一条。
///
/// 经上游 `QuoteBlockComponentBuilder.iconBuilder` 放在引用文字的起始侧
/// （见 `buildDiaryEditorBlocks`）。上游的竖条写死亮青色 `#00BCF0`，所以
/// 自己绘制，颜色只取主题语义色。
///
/// 为什么要专门“连起来”：连续的几行引用通常是几个相邻的引用块——引用里
/// 回车新起的是正文段落（上游 `insertNewLine`），再在行首输入 `> ` 或用
/// 工具栏转为引用时逐块转换，Markdown / HTML 粘贴与导入也是每行一块；而
/// 块的上下留白（`diaryTextBlockConfiguration` 给引用上下各 4dp）包在竖条
/// 外面，竖条只有文字那么高，于是相邻两块的竖条之间断开 8dp，两端还是圆头。
/// 只有同一块里的软换行（桌面 Shift + Enter，或粘贴本应用复制的这种引用）
/// 才本来就是一整条。
///
/// 做法：与上一块 / 下一块相接（[diaryQuoteBarsJoin]）的一端改为方头，并
/// 画进本块那一侧的留白直到块的边缘（[blockInsets]），两块的竖条正好在块的
/// 分界处对接；不相接的一端仍是圆头、只有文字那么高，单独的引用与改版前
/// 逐像素一致。竖条的布局宽度不变（左 2 + 3 + 右 12），多画的部分只在本块
/// 自己的留白里，不影响文字排版与点按。
///
/// 相接与否看前后两个兄弟节点：增删兄弟块、换块类型（上游是替换节点）时
/// 父块重建，本组件随之拿到新的邻居；只改邻块属性（如把下一行设为居中）
/// 时上游只通知那一块，所以这里再监听前后两个节点，邻块一变就重算两端。
/// Flutter 允许对已 dispose 的 ChangeNotifier 调用 removeListener，文档
/// 整份换掉、节点被 dispose 后移除监听也安全。
class DiaryQuoteBar extends StatelessWidget {
  const DiaryQuoteBar({
    super.key,
    required this.node,
    required this.blockInsets,
  });

  /// 这一行引用的节点。
  final af.Node node;

  /// 本块文字之外的上下留白（块配置的 padding + margin）：与邻块相接时，
  /// 竖条在那一侧画出这么长，正好到块的边缘。
  final EdgeInsets blockInsets;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary.withValues(alpha: 0.55);
    final upper = node.previous;
    final lower = node.next;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 2, end: 12),
      // 固定 3dp 宽：IntrinsicHeight 量行高时按它给文字留宽度，与实际排版
      // 一致（没有子节点的 CustomPaint 固有宽度为 0，会让两次换行结果不同）。
      child: SizedBox(
        width: 3,
        child: ListenableBuilder(
          listenable: Listenable.merge([?upper, ?lower]),
          builder: (context, _) => CustomPaint(
            painter: DiaryQuoteBarPainter(
              color: color,
              extendTop: diaryQuoteBarsJoin(upper, node)
                  ? blockInsets.top
                  : null,
              extendBottom: diaryQuoteBarsJoin(node, lower)
                  ? blockInsets.bottom
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// 上下相邻的两行引用（[upper] 紧接在 [lower] 前面、同一个父块）的竖条
/// 是否连成一条。
///
/// 只有两条竖条落在同一竖列上才连：
/// - 两块都是引用，且互为相邻的兄弟（嵌套在列表项里的引用与外面的引用、
///   中间隔着别的块的引用都不连；引用从不挂子块，兄弟相邻即视觉上相邻）；
/// - 两块都没有改变整行位置的对齐（`center` / `right` / `left`：上游把
///   文字和竖条一起按文字宽度摆放，竖条的横向位置随文字长短变化）；两端
///   对齐只作用于文字，竖条仍在起始边，照样相连；
/// - 文字方向的设置相同且不是 `auto`（方向决定竖条在左还是在右，`auto`
///   随内容变化，同一设置下两块未必同侧）。本应用不写文字方向，两块通常
///   都没有这一项。
bool diaryQuoteBarsJoin(af.Node? upper, af.Node? lower) {
  if (upper == null || lower == null) return false;
  if (upper.type != kDiaryBlockQuote || lower.type != kDiaryBlockQuote) {
    return false;
  }
  if (!identical(upper.next, lower)) return false;
  if (_movesWithText(upper) || _movesWithText(lower)) return false;
  final direction = upper.attributes[af.blockComponentTextDirection];
  return direction != af.blockComponentTextDirectionAuto &&
      direction == lower.attributes[af.blockComponentTextDirection];
}

/// 上游引用块认得的对齐（见 `BlockComponentAlignMixin`）会把文字连同竖条
/// 按文字宽度整体摆放。
bool _movesWithText(af.Node node) =>
    switch (node.attributes[kDiaryBlockAlignKey]) {
      'center' || 'right' || 'left' => true,
      _ => false,
    };

/// 画一条引用竖条。[extendTop] / [extendBottom] 为 null 的一端是圆头、与
/// 文字齐平；不为 null 的一端与邻块相接：方头，越出自身边界画这么长。
///
/// 相接处为什么用不抗锯齿的裁剪切齐：块的分界一般落在小数像素上，两块
/// 各自抗锯齿的方头会各盖住分界那一行像素的一部分，半透明的颜色叠出一条
/// 比竖条浅的细缝。这里让相接的一端先多画 [_overdraw]，再用不抗锯齿的
/// 矩形裁剪在分界处切掉：上下两块的裁剪边落在同一位置，按像素中心把那一行
/// 分给其中一块，接缝处既不留缝也不叠深。竖条的左右两边与圆头照常抗锯齿
/// （裁剪框横向与不相接的一端都留有余量，不会切到）。
class DiaryQuoteBarPainter extends CustomPainter {
  const DiaryQuoteBarPainter({
    required this.color,
    this.extendTop,
    this.extendBottom,
  });

  final Color color;
  final double? extendTop;
  final double? extendBottom;

  /// 相接一端越过裁剪边多画的长度，盖过抗锯齿的半个像素即可。
  static const double _overdraw = 1;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final cap = Radius.circular(size.width / 2);
    final top = extendTop;
    final bottom = extendBottom;
    if (top == null && bottom == null) {
      canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, cap), paint);
      return;
    }
    final barTop = top == null ? 0.0 : -top - _overdraw;
    final barBottom = bottom == null
        ? size.height
        : size.height + bottom + _overdraw;
    canvas
      ..save()
      ..clipRect(
        Rect.fromLTRB(
          -size.width,
          top == null ? barTop - _overdraw : -top,
          size.width * 2,
          bottom == null ? barBottom + _overdraw : size.height + bottom,
        ),
        doAntiAlias: false,
      )
      ..drawRRect(
        RRect.fromLTRBAndCorners(
          0,
          barTop,
          size.width,
          barBottom,
          topLeft: top == null ? cap : Radius.zero,
          topRight: top == null ? cap : Radius.zero,
          bottomLeft: bottom == null ? cap : Radius.zero,
          bottomRight: bottom == null ? cap : Radius.zero,
        ),
        paint,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(DiaryQuoteBarPainter oldDelegate) =>
      color != oldDelegate.color ||
      extendTop != oldDelegate.extendTop ||
      extendBottom != oldDelegate.extendBottom;
}
