// 表单类二级页（设置子页、各管理页）在宽窗口下的内容列。
//
// 职责：把 [AppContentWidth.form] 换算成滚动视图的左右内边距，让内容列在
// 宽窗口里居中、最宽 720，而滚动视图本身仍铺满（滚动条与滚轮留在窗口边缘）。
// 手机上（可用宽度 ≤ 720 + 两侧原留白）换算结果与改版前的固定留白相同，
// 布局不变。宽度一律取页面实际可用的宽度（`LayoutBuilder`），不取
// `MediaQuery`：首页宽窗口左侧有导航栏，Tab 页拿到的宽度比窗口窄。
//
// 纯换算与无状态 widget，没有副作用。

import 'package:flutter/widgets.dart';

import '../../app/theme/app_breakpoints.dart';

/// 表单内容列的宽度与留白换算。
abstract final class FormWidth {
  /// 内容列的最大宽度。
  static const double maxWidth = AppContentWidth.form;

  /// 内容列每侧的留白：页面今天固定留 [minGutter] 的地方改用这个值。
  static double gutter(double available, {double minGutter = 16}) =>
      AppContentWidth.gutter(available, maxWidth, minGutter: minGutter);

  /// 子项自带 [childInset] 左右边距（如 `SettingsCardGroup` 的 16）、滚动
  /// 视图本身原本不留边时，滚动视图要补的左右内边距；手机上为 0。
  static double extra(double available, {double childInset = 16}) =>
      gutter(available, minGutter: childInset) - childInset;
}

/// 贴底的操作栏（多选栏等）按内容列居中：栏自身带 [sideInset] 的左右
/// 边距时，最宽为内容列宽度加两侧边距，使栏的可见边缘与内容列对齐。
class FormWidthBar extends StatelessWidget {
  const FormWidthBar({super.key, this.sideInset = 0, required this.child});

  final double sideInset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CenteredContent(
      maxWidth: FormWidth.maxWidth + sideInset * 2,
      child: child,
    );
  }
}
