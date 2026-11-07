import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 嵌入块里自己处理点按的内容（图片、播放器、附件条、日记卡片）。块里这层
/// 以外的地方——图片右侧的空白、上下留白、整条分隔线——算块旁的空白：
/// 点在那里，插入点停到块的左侧或右侧、键盘弹出（DiaryEditorKeyboardReopen
/// → DiaryEmbedCaretInput）；点在内容上仍交给内容自己（看图、播放、打开
/// 卡片），不弹键盘。块上的插入点也画在这层的边上。
///
/// 只是一个标记：不参与命中测试、不改布局，按几何判断（[contains] /
/// [rectIn]）。
class DiaryEmbedContent extends SingleChildRenderObjectWidget {
  const DiaryEmbedContent({super.key, required super.child});

  static _RenderDiaryEmbedContent? _find(RenderObject block) {
    _RenderDiaryEmbedContent? found;
    void visit(RenderObject object) {
      if (found != null) return;
      if (object is _RenderDiaryEmbedContent) {
        found = object;
        return;
      }
      object.visitChildren(visit);
    }

    visit(block);
    return found;
  }

  /// [block] 的渲染子树里，内容标记是否盖住全局坐标 [position]。
  static bool contains(RenderObject block, Offset position) {
    final content = _find(block);
    if (content == null || !content.hasSize) return false;
    final local = content.globalToLocal(position);
    return (Offset.zero & content.size).contains(local);
  }

  /// 内容在 [block] 里的矩形；没有内容标记（分隔线等）时为整块。
  static Rect rectIn(RenderBox block) {
    final content = _find(block);
    if (content == null || !content.hasSize || !content.attached) {
      return Offset.zero & block.size;
    }
    return content.localToGlobal(Offset.zero, ancestor: block) & content.size;
  }

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderDiaryEmbedContent();
}

class _RenderDiaryEmbedContent extends RenderProxyBox {}

/// 独占一行、没有文字的块（媒体、分隔线、日记链接卡片）共用的块级选区：
/// 整块只有两个插入点位置，偏移 0 在内容左侧、1 在右侧（[DiaryEmbedContent]
/// 的边上，图片比列宽窄时就紧贴着画面），画成闪烁的竖线、与内容等高；范围
/// 选区跨过它时画整块的底色。规则见 diary_embed_editing.dart。
mixin DiaryEmbedSelectable<T extends af.BlockComponentStatefulWidget>
    on State<T>, af.SelectableMixin<T> {
  af.Node get node => widget.node;
  RenderBox? get box => context.findRenderObject() as RenderBox?;

  /// 插入点竖线的宽度，同正文。
  static const double _caretWidth = 2;

  /// 竖线与内容之间的空隙。
  static const double _caretGap = 2;

  /// 包住块内容：上游据此绘制选区与光标。
  Widget buildEmbedSelection(af.EditorState state, Widget child) {
    return af.BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: state.selectionNotifier,
      remoteSelection: state.remoteSelections,
      blockColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
      cursorColor: state.editorStyle.cursorColor,
      supportTypes: const [
        af.BlockSelectionType.block,
        af.BlockSelectionType.selection,
        af.BlockSelectionType.cursor,
      ],
      child: child,
    );
  }

  Rect get _content {
    final block = box;
    if (block == null || !block.hasSize) return Rect.zero;
    return DiaryEmbedContent.rectIn(block);
  }

  @override
  af.Position start() => af.Position(path: node.path);
  @override
  af.Position end() => af.Position(path: node.path, offset: 1);

  /// 点在内容上方为左侧，下方为右侧（点在最后一块下面的空白处，插入点停在
  /// 它右侧）；与内容同高时按左右半边。
  @override
  af.Position getPositionInOffset(Offset start) {
    final block = box;
    if (block == null || !block.hasSize) return end();
    final local = block.globalToLocal(start);
    final content = _content;
    if (local.dy > content.bottom) return end();
    if (local.dy < content.top) return this.start();
    return local.dx < content.center.dx ? this.start() : end();
  }

  @override
  bool get shouldCursorBlink => true;
  @override
  af.CursorStyle get cursorStyle => af.CursorStyle.verticalLine;
  @override
  Rect getBlockRect({bool shiftWithBaseOffset = false}) =>
      Offset.zero & (box?.size ?? Size.zero);
  @override
  Rect? getCursorRectInPosition(
    af.Position position, {
    bool shiftWithBaseOffset = false,
  }) {
    final content = _content;
    // 画在块外也行：选区容器不裁剪（上游 `Clip.none`）。并排的小图每块只有
    // 方格宽，右侧的竖线落在格间的空隙里；靠行首的图片，左侧的竖线落在
    // 页面左边距里。
    final x = position.offset > 0
        ? content.right + _caretGap
        : content.left - _caretGap - _caretWidth;
    return Rect.fromLTWH(x, content.top, _caretWidth, content.height);
  }

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
