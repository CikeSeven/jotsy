import 'package:flutter/widgets.dart';

/// 软键盘是否弹起（`viewInsets.bottom > 0`），只在“弹起 / 收起”切换时通知
/// 依赖者。
///
/// 键盘升降动画期间 `viewInsets.bottom` 每帧都在变：在大页面的 build 里直接
/// 读 `MediaQuery.viewInsetsOf`，整页（连同正文的每个段落块）会在动画的每
/// 一帧重建，键盘拉起、收起明显卡顿。只关心“键盘在不在”的组件改经
/// [KeyboardVisibility.of]：逐帧重建的只有本组件这一层，按布尔值比较后才
/// 通知下面的依赖者，一次升降最多各重建一次。
///
/// 应用在 `MaterialApp.builder` 里挂了一个（Navigator 之上，所有路由共用）。
/// 读的是本组件所在处的 MediaQuery；没有祖先时 [of] 退回直接读 viewInsets
/// （逐帧重建，但结果一致），只挂页面不挂应用壳的测试照常工作。
class KeyboardVisibility extends StatelessWidget {
  const KeyboardVisibility({super.key, required this.child});

  final Widget child;

  /// 软键盘此刻是否弹起；[context] 只在切换时重建。
  static bool of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_KeyboardVisibilityScope>();
    return scope?.visible ?? MediaQuery.viewInsetsOf(context).bottom > 0;
  }

  @override
  Widget build(BuildContext context) => _KeyboardVisibilityScope(
    visible: MediaQuery.viewInsetsOf(context).bottom > 0,
    child: child,
  );
}

/// 底部按软键盘高度留白（底部面板里的输入框让到键盘之上）。
///
/// 只有这一层读 `viewInsets`、随键盘动画逐帧重建；[child] 由外层构建好
/// 传进来，同一个实例逐帧原样交回，框架不再往下更新。直接在面板的 build
/// 里写 `Padding(bottom: MediaQuery.viewInsetsOf(context).bottom)` 会让整个
/// 面板内容逐帧重建。
class KeyboardInsetPadding extends StatelessWidget {
  const KeyboardInsetPadding({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: child,
  );
}

class _KeyboardVisibilityScope extends InheritedWidget {
  const _KeyboardVisibilityScope({required this.visible, required super.child});

  final bool visible;

  @override
  bool updateShouldNotify(_KeyboardVisibilityScope oldWidget) =>
      visible != oldWidget.visible;
}
