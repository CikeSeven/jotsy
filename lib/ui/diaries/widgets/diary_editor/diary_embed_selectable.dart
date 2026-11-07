import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 嵌入块里自己处理点按的内容（图片、播放器、附件条、日记卡片）。块里这层
/// 以外的地方——图片右侧的空白、上下留白、整条分隔线——算块旁的空白：
/// 点在那里，插入点挪到块下面一行（DiaryEditorKeyboardReopen →
/// `placeDiaryCaretAfterEmbed`）；点在内容上仍交给内容自己（看图、播放、
/// 打开卡片），插入点不动。
///
/// 只是一个标记：不参与命中测试、不改布局，点按后按几何判断（[contains]）。
class DiaryEmbedContent extends SingleChildRenderObjectWidget {
  const DiaryEmbedContent({super.key, required super.child});

  /// [block] 的渲染子树里，是否有内容标记盖住全局坐标 [position]。
  static bool contains(RenderObject block, Offset position) {
    var hit = false;
    void visit(RenderObject object) {
      if (hit) return;
      if (object is _RenderDiaryEmbedContent && object.hasSize) {
        final local = object.globalToLocal(position);
        if ((Offset.zero & object.size).contains(local)) {
          hit = true;
          return;
        }
      }
      object.visitChildren(visit);
    }

    visit(block);
    return hit;
  }

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderDiaryEmbedContent();
}

class _RenderDiaryEmbedContent extends RenderProxyBox {}

/// 独占一行、没有文字的块（媒体、日记链接卡片）共用的块级选区：整块只有
/// 开头与结尾两个位置，光标盖住整块（`cover`），选中时画整块的底色。
mixin DiaryEmbedSelectable<T extends af.BlockComponentStatefulWidget>
    on State<T>, af.SelectableMixin<T> {
  af.Node get node => widget.node;
  RenderBox? get box => context.findRenderObject() as RenderBox?;

  /// 包住块内容：上游据此绘制选区与光标。
  Widget buildEmbedSelection(af.EditorState state, Widget child) {
    return af.BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: state.selectionNotifier,
      remoteSelection: state.remoteSelections,
      blockColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
      supportTypes: const [
        af.BlockSelectionType.block,
        af.BlockSelectionType.selection,
        af.BlockSelectionType.cursor,
      ],
      child: child,
    );
  }

  @override
  af.Position start() => af.Position(path: node.path);
  @override
  af.Position end() => af.Position(path: node.path, offset: 1);
  @override
  af.Position getPositionInOffset(Offset start) => end();
  @override
  bool get shouldCursorBlink => false;
  @override
  af.CursorStyle get cursorStyle => af.CursorStyle.cover;
  @override
  Rect getBlockRect({bool shiftWithBaseOffset = false}) =>
      Offset.zero & (box?.size ?? Size.zero);
  @override
  Rect? getCursorRectInPosition(
    af.Position position, {
    bool shiftWithBaseOffset = false,
  }) => getBlockRect();
  @override
  List<Rect> getRectsInSelection(
    af.Selection selection, {
    bool shiftWithBaseOffset = false,
  }) => [getBlockRect()];
  @override
  af.Selection getSelectionInRange(Offset start, Offset end) =>
      af.Selection.single(path: node.path, startOffset: 0, endOffset: 1);
  @override
  Offset localToGlobal(Offset offset, {bool shiftWithBaseOffset = false}) =>
      box?.localToGlobal(offset) ?? offset;
  @override
  TextDirection textDirection() => TextDirection.ltr;
}
