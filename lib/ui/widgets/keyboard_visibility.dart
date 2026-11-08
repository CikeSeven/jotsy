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

/// 让子树不随软键盘升降重建：[shielded] 期间，子树看到的键盘停在变为
/// [shielded] 的那一刻。
///
/// 为什么：被别的页面盖着的路由（首页在搜索页、编辑页之下，预览页在编辑页
/// 之下）照样依赖 MediaQuery。键盘升起的头几帧盖过导航条时 `padding` 的
/// 底边逐帧变小，`viewInsets` 更是每帧都变，底下的页面因此逐帧重建、重新
/// 布局——真机上首页这一项就让键盘动画开头的几帧各卡 17～30ms。盖着的页面
/// 看不见，没必要跟着键盘动。
///
/// 只替换与键盘有关的两项：底部 `viewInsets` 取冻结的键盘高度，底部
/// `padding` 按 `viewPadding` 减去它重算（与引擎的算法相同，旋转屏幕等
/// 导航条变化照常生效）；[KeyboardVisibility.of] 同样取冻结值。其余字段
/// 原样透传。冻结而不是清零：编辑页正打字时盖上一个带输入框的对话框，
/// 下面的正文保持让开键盘的样子，关掉对话框时不会先撑开再缩回。
///
/// 从第一次构建起就屏蔽（首页：`KeyboardShield(shielded: true)` 常驻）时
/// 按“没有键盘”冻结，而不是取第一帧读到的值：应用从别的应用切过来、被
/// `am start` 拉起时，第一帧的 `viewInsets` 可能还带着上一个应用没收起的
/// 键盘，冻结下来后首页底部的安全区与留白会一直少掉一个键盘高。
///
/// 结构恒定：[shielded] 切换时子树不会被重新挂载。
class KeyboardShield extends StatefulWidget {
  const KeyboardShield({
    super.key,
    required this.shielded,
    required this.child,
  });

  final bool shielded;
  final Widget child;

  @override
  State<KeyboardShield> createState() => _KeyboardShieldState();
}

class _KeyboardShieldState extends State<KeyboardShield> {
  /// 冻结的键盘高度（逻辑像素）；不在屏蔽期间为 null。
  double? _frozenInset;

  /// 是否有过不屏蔽的时候：从来没有时冻结为 0（见类注释）。
  bool _everFollowed = false;

  @override
  Widget build(BuildContext context) {
    final data = MediaQuery.of(context);
    if (!widget.shielded) {
      _everFollowed = true;
      _frozenInset = null;
    } else {
      _frozenInset ??= _everFollowed ? data.viewInsets.bottom : 0;
    }
    final inset = _frozenInset;
    final shown = inset == null
        ? data
        : data.copyWith(
            viewInsets: data.viewInsets.copyWith(bottom: inset),
            padding: data.padding.copyWith(
              bottom: (data.viewPadding.bottom - inset).clamp(
                0.0,
                double.infinity,
              ),
            ),
          );
    return MediaQuery(
      data: shown,
      child: _KeyboardVisibilityScope(
        visible: shown.viewInsets.bottom > 0,
        child: widget.child,
      ),
    );
  }
}

class _KeyboardVisibilityScope extends InheritedWidget {
  const _KeyboardVisibilityScope({required this.visible, required super.child});

  final bool visible;

  @override
  bool updateShouldNotify(_KeyboardVisibilityScope oldWidget) =>
      visible != oldWidget.visible;
}
