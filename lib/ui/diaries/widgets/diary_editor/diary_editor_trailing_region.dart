import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 正文编辑器页尾（`DiaryEditor.footer`）里一段不属于正文的内容：阅读式
/// 编辑页正文之后的“最后编辑于”、提到这篇的日记、留言区与 AI 回应。
///
/// 页尾和正文在同一个虚拟滚动里，默认点到正文下方的任何地方都算“点正文
/// 下方的空白”：上游会把插入点挪到文末并弹出键盘，文末是图片等嵌入块时
/// [DiaryEditorKeyboardReopen] 还会补一个空段落。点留言、链接卡片这些
/// 内容时不该开始编辑，所以：
/// - 区域里没被子组件接住的点按由这里吞掉（不透明的点按识别器在竞技场里
///   先于外层编辑器的识别器胜出），里面的按钮、卡片照常响应；
/// - [isHit] 让补行逻辑认出点按落在这里，不补行。
class DiaryEditorTrailingRegion extends StatelessWidget {
  const DiaryEditorTrailingRegion({super.key, required this.child});

  final Widget child;

  /// [position]（全局坐标）处的点按是否落在某个页尾区域里。
  static bool isHit(BuildContext context, Offset position) {
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(
      result,
      position,
      View.of(context).viewId,
    );
    return result.path.any(
      (HitTestEntry entry) => entry.target is _RenderTrailingRegionMarker,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _TrailingRegionMarker(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // 只为在竞技场里接住点按，不做任何事。
        onTap: () {},
        child: child,
      ),
    );
  }
}

class _TrailingRegionMarker extends SingleChildRenderObjectWidget {
  const _TrailingRegionMarker({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTrailingRegionMarker();
}

/// 只做标记的透明代理：命中测试与绘制都交给子节点。
class _RenderTrailingRegionMarker extends RenderProxyBox {}
