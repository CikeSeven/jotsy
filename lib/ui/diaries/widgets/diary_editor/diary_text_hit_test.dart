import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/widgets.dart';

import '../../../../core/database/diary_blocks/diary_blocks_schema.dart';

/// 文字前面有可点的行首控件（列表标记、待办勾选框、折叠三角、提示块图标）
/// 的块：横向只认文字本身的左缘之右。
const Set<String> _kLeadingControlBlockTypes = <String>{
  kDiaryBlockBulletedList,
  kDiaryBlockNumberedList,
  kDiaryBlockTodoList,
  kDiaryBlockToggleList,
  kDiaryBlockCallout,
};

/// 正文里全局坐标 [global] 处的文字位置（预览页双击进入编辑时用作编辑页的
/// 初始光标）。
///
/// 只认文字块（带 delta 的块：段落、标题、列表、待办、引用、代码、提示块、
/// 折叠块标题行、表格格内段落）。纵向取块里富文本组件（上游
/// `DefaultSelectableMixin.forwardKey`）的上下缘；横向为整块宽度，短行、
/// 居中或靠右的行两侧的空白也算这一行。行首有可点控件的块
/// （[_kLeadingControlBlockTypes]）只从文字左缘算起，免得双击列表标记、待办
/// 勾选框、折叠三角也进入编辑。嵌入块（图片、视频、分隔线、日记卡片）与收起
/// 的折叠内容（没有渲染）一律不算。
///
/// 块与块之间的空隙（段间距）离最近一行不超过 [tolerance] 时归到那一行，
/// 否则为 null；容差取得小，代码块标题栏的复制按钮这类贴着文字的控件不会被
/// 算进来。偏移按块的文字长度夹取：块组件自己负责首行缩进等占位的偏移换算
/// （经 `getPositionInOffset`）。
///
/// 只读布局，不改选区、不触发重建；须在布局完成后调用（指针事件里）。
af.Position? diaryTextPositionAt(
  af.EditorState state,
  Offset global, {
  double tolerance = 6,
}) {
  af.Node? best;
  af.SelectableMixin? bestSelectable;
  var bestDistance = double.infinity;

  void visit(af.Node node) {
    final delta = node.delta;
    final selectable = node.selectable;
    if (delta != null && selectable is af.DefaultSelectableMixin) {
      final textRect = _globalRect(
        (selectable as af.DefaultSelectableMixin).forwardKey.currentContext,
      );
      final blockRect = _globalRect(node.key.currentContext);
      if (textRect != null && blockRect != null) {
        final left = _kLeadingControlBlockTypes.contains(node.type)
            ? textRect.left
            : blockRect.left;
        final inColumn = global.dx >= left && global.dx <= blockRect.right;
        if (inColumn) {
          final distance = global.dy < textRect.top
              ? textRect.top - global.dy
              : global.dy > textRect.bottom
              ? global.dy - textRect.bottom
              : 0.0;
          if (distance < bestDistance) {
            bestDistance = distance;
            best = node;
            bestSelectable = selectable;
          }
        }
      }
    }
    for (final child in node.children) {
      visit(child);
    }
  }

  for (final node in state.document.root.children) {
    visit(node);
  }
  final node = best;
  final selectable = bestSelectable;
  if (node == null || selectable == null || bestDistance > tolerance) {
    return null;
  }
  // 点在行的上下方（段间距里）时按这一行的纵向范围夹回去再取字，免得落到
  // 富文本之外取出 -1。
  final textRect = _globalRect(
    (selectable as af.DefaultSelectableMixin).forwardKey.currentContext,
  )!;
  final probe = Offset(
    global.dx,
    global.dy.clamp(textRect.top + 0.5, textRect.bottom - 0.5),
  );
  final length = node.delta?.length ?? 0;
  final offset = selectable.getPositionInOffset(probe).offset;
  return af.Position(path: node.path, offset: offset.clamp(0, length));
}

Rect? _globalRect(BuildContext? context) {
  final box = context?.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}
