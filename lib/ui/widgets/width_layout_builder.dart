import 'package:flutter/widgets.dart';

/// 只随可用宽度重建的 [LayoutBuilder]。
///
/// 软键盘升降时 Scaffold 逐帧缩小 body 的高度，普通 LayoutBuilder 每帧都会
/// 重新调用 builder，把下面的整棵子树（如搜索结果整列日记卡片）逐帧重建，
/// 键盘动画因此掉帧。多数页面只按宽度分档、算左右留白，高度变化不影响构建
/// 结果：本组件在宽度不变时直接交回上一次构建的子树（同一个 widget 实例，
/// 框架不再往下更新），高度交给子树自己的布局（Viewport 等照常按新高度
/// 排版）。
///
/// builder 拿到的是本组件自己的 context，而不是布局回调里的那个：builder 里
/// 读的 InheritedWidget 依赖因此记在本组件上，依赖变化时本组件重建并标记
/// 失效，紧接着的布局按新数据重新构建；父级重建（传入新的 builder 闭包）
/// 同理。若依赖记在布局回调的 context 上，“依赖变化”与“高度变化”落在同一
/// 帧（如键盘盖过导航条那几帧 padding 也在变）时会被误当成纯高度变化而
/// 沿用旧子树。
///
/// 需要按高度构建的地方（如按可用高度限制面板）仍用 [LayoutBuilder]。
class WidthLayoutBuilder extends StatefulWidget {
  const WidthLayoutBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, double maxWidth) builder;

  @override
  State<WidthLayoutBuilder> createState() => _WidthLayoutBuilderState();
}

class _WidthLayoutBuilderState extends State<WidthLayoutBuilder> {
  Widget? _child;
  double? _width;

  /// 本组件重建过（父级换了 builder，或 builder 读的依赖变了），下一次
  /// 布局回调必须重新构建。
  bool _stale = true;

  @override
  Widget build(BuildContext context) {
    _stale = true;
    return LayoutBuilder(
      builder: (BuildContext _, BoxConstraints constraints) {
        final width = constraints.maxWidth;
        final child = _child;
        if (child != null && !_stale && width == _width) {
          return child;
        }
        _stale = false;
        _width = width;
        return _child = widget.builder(context, width);
      },
    );
  }
}
