import 'dart:ui' show ImageFilter, SemanticsHitTestBehavior;

import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../app_surface/widgets/app_glass_scope.dart';
import '../../app_surface/widgets/app_glass_surface.dart';
import '../../app_surface/widgets/app_page_backdrop.dart';

/// 全应用打开对话框的唯一入口（`test/ui/widgets/app_modal_source_test.dart`
/// 源码检查兜底：本目录之外不得直接调用 `showDialog`）。SDK 自带的
/// `showDatePicker` / `showTimePicker` 等内部调用不经这里。
///
/// 输入：与 [showDialog] 同名同义的参数（原样透传）；输出：对话框关闭时的
/// 返回值。材质取自调用处的 `AppGlass.of(context).isGlass(AppGlassComponent.dialogs)`：
///
/// - 经典：原样调用 [showDialog]，行为与像素和接入前完全相同；
/// - 玻璃：推入 [AppGlassDialogRoute]——底层一块铺满路由的“整页磨砂”，
///   其上对话框本体淡入并从 0.95 放大到 1；对话框卡片经主题覆盖变成半透明
///   玻璃底色（见 [AppGlassDialogRoute]）。遮罩比经典浅：磨砂已经把对话框
///   和页面分开，再压一层 54% 的黑会把磨砂透出的页面压成一片灰。
///
/// 玻璃路径不走 `showGeneralDialog`：它不收 `traversalEdgeBehavior`，而
/// [showDialog] 默认把焦点圈在对话框里（closedLoop），桌面 Tab 键不应跳回
/// 下面的页面；它也不抓取调用处的局部主题。这里直接推入同一类
/// [RawDialogRoute]（`showGeneralDialog` 本身也只是推它），并照 [DialogRoute]
/// 的做法抓取主题、包 SafeArea 与语义，保证两条路径对调用方完全等价。
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
  TraversalEdgeBehavior? traversalEdgeBehavior,
  bool? requestFocus,
}) {
  final glass = AppGlass.of(context);
  if (!glass.isGlass(AppGlassComponent.dialogs)) {
    return showDialog<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      barrierLabel: barrierLabel,
      useSafeArea: useSafeArea,
      useRootNavigator: useRootNavigator,
      routeSettings: routeSettings,
      anchorPoint: anchorPoint,
      traversalEdgeBehavior: traversalEdgeBehavior,
      requestFocus: requestFocus,
    );
  }
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  return navigator.push<T>(
    AppGlassDialogRoute<T>(
      builder: builder,
      themes: themes,
      // 对话框下面就是调用处的页面：自定义底色的前景兜底按这页的估计色算。
      backdropColor: AppPageBackdrop.estimatedColorOf(context),
      barrierColor: barrierColor ?? appGlassDialogBarrierColor(context, glass),
      barrierDismissible: barrierDismissible,
      barrierLabel:
          barrierLabel ??
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
      useSafeArea: useSafeArea,
      settings: routeSettings,
      anchorPoint: anchorPoint,
      traversalEdgeBehavior:
          traversalEdgeBehavior ?? TraversalEdgeBehavior.closedLoop,
      requestFocus: requestFocus,
      transitionDuration: ExpressiveMotion.duration(
        context,
        ExpressiveMotion.medium,
      ),
    ),
  );
}

/// 玻璃对话框的遮罩色。
///
/// 能磨砂时取 scrim 的 24%：磨砂本身已经让页面退到后面、对话框浮在前面，
/// 遮罩只需略微压暗以示“页面暂不可用”；经典的 54% 黑叠在磨砂上会把透出
/// 的页面颜色压成一片灰，玻璃也就没了意义。24% 约为经典的一半，亮色主题下
/// 仍能看出页面被压住。
///
/// 不能磨砂（高对比度，或用户把模糊调到 0）时没有磨砂来分隔层次，退回与
/// [showDialog] 相同的遮罩色，保证对话框与页面分得开。
Color appGlassDialogBarrierColor(BuildContext context, AppGlassResolved glass) {
  if (!glass.canBlur) {
    return DialogTheme.of(context).barrierColor ??
        Theme.of(context).dialogTheme.barrierColor ??
        Colors.black54;
  }
  return Theme.of(context).colorScheme.scrim.withValues(alpha: 0.24);
}

/// 玻璃对话框的路由：铺满路由的磨砂层 + 淡入放大的对话框本体。
///
/// 页面（pageBuilder）照 [DialogRoute]：抓取的调用处主题 → 玻璃卡片主题 →
/// SafeArea → 不透明语义。玻璃卡片主题：`dialogTheme` 的底色换成玻璃
/// `fill`（半透明；高对比度时为不透明的 solidFill）、无投影无着色，形状保留
/// 主题圆角并加上玻璃描边（设置打开描边时）。`AlertDialog` / `Dialog` /
/// `SimpleDialog` 都从 `DialogTheme` 取这些值，于是自动变成半透明卡片；调用方
/// 显式给了 `backgroundColor` 的对话框优先用自己的颜色，不受影响。卡片本身
/// 不再模糊——下面的整页磨砂已经模糊过，同一区域禁止叠两层模糊。
///
/// 转场（[buildTransitions]）：
/// - 磨砂层：一块铺满路由的 [BackdropFilter]，sigma = blurSigma × 动画值，
///   随入场 / 退场线性加深 / 变浅；节点始终在树里、只切 `enabled`（动画值为
///   0 或不能磨砂时关），并且不放进任何 Opacity / FadeTransition——放进去后
///   背景模糊只能采到透明层自己。`IgnorePointer`：点按要落到下面的遮罩上，
///   点遮罩关闭才照常工作；
/// - 对话框本体：淡入（effects / 退场 exit）+ 从 0.95 放大（spatial 弹簧 /
///   退场 exit）。本体不含 BackdropFilter，可以放进 FadeTransition；
/// - 时长 medium；系统减少动画时为 0，直接显示。
class AppGlassDialogRoute<T> extends RawDialogRoute<T> {
  AppGlassDialogRoute({
    required WidgetBuilder builder,
    CapturedThemes? themes,
    required Color backdropColor,
    super.barrierColor,
    super.barrierDismissible,
    super.barrierLabel,
    bool useSafeArea = true,
    super.settings,
    super.anchorPoint,
    super.traversalEdgeBehavior,
    super.requestFocus,
    super.transitionDuration,
  }) : super(
         pageBuilder:
             (
               BuildContext buildContext,
               Animation<double> animation,
               Animation<double> secondaryAnimation,
             ) {
               final Widget card = AppGlassDialogTheme(
                 backdropColor: backdropColor,
                 child: Builder(builder: builder),
               );
               Widget dialog = themes?.wrap(card) ?? card;
               if (useSafeArea) {
                 dialog = SafeArea(child: dialog);
               }
               // 与 DialogRoute 相同：对话框内的点按不穿透到遮罩的语义节点。
               return Semantics(
                 hitTestBehavior: SemanticsHitTestBehavior.opaque,
                 child: dialog,
               );
             },
       );

  CurvedAnimation? _fade;
  CurvedAnimation? _scale;

  /// 曲线动画挂在路由上、随路由释放：带 reverseCurve 的 CurvedAnimation 会
  /// 监听父动画的状态，每次 build 新建会漏掉监听。
  void _bind(Animation<double> animation) {
    if (_fade?.parent == animation) return;
    _fade?.dispose();
    _scale?.dispose();
    _fade = CurvedAnimation(
      parent: animation,
      curve: ExpressiveMotion.effects,
      reverseCurve: ExpressiveMotion.exit,
    );
    _scale = CurvedAnimation(
      parent: animation,
      curve: ExpressiveMotion.spatial,
      reverseCurve: ExpressiveMotion.exit,
    );
  }

  static final Animatable<double> _scaleTween = Tween<double>(
    begin: 0.95,
    end: 1,
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    _bind(animation);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        AppGlassDialogBackdrop(animation: animation),
        FadeTransition(
          opacity: _fade!,
          child: ScaleTransition(
            scale: _scaleTween.animate(_scale!),
            child: child,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _fade?.dispose();
    _scale?.dispose();
    super.dispose();
  }
}

/// 玻璃对话框下面的整页磨砂层（见 [AppGlassDialogRoute] 的转场说明）。
///
/// 模糊强度与开关每帧从 [AppGlass.of] 读：对话框开着时切换高对比度，磨砂
/// 随即关闭。
class AppGlassDialogBackdrop extends StatelessWidget {
  const AppGlassDialogBackdrop({super.key, required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final glass = AppGlass.of(context);
    return IgnorePointer(
      child: ClipRect(
        child: AnimatedBuilder(
          animation: animation,
          builder: (BuildContext context, Widget? child) {
            final t = animation.value.clamp(0.0, 1.0);
            final sigma = glass.blurSigma * t;
            return BackdropFilter(
              enabled: glass.canBlur && t > 0,
              filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: child,
            );
          },
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// 把子树里的对话框卡片换成玻璃底色（见 [AppGlassDialogRoute] 的页面说明）。
///
/// 自定义底色时与 [AppGlassSurface] 同一口径做前景兜底：按“玻璃底色叠在
/// [backdropColor] 上”的结果检查主题前景的对比度，不够时换成可读色。
class AppGlassDialogTheme extends StatelessWidget {
  const AppGlassDialogTheme({
    super.key,
    required this.backdropColor,
    required this.child,
  });

  /// 对话框下面页面的估计颜色（调用处的 `AppPageBackdrop.estimatedColor`）。
  final Color backdropColor;
  final Widget child;

  /// M3 对话框的默认形状（主题没给时）。
  static const ShapeBorder _defaultShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(28)),
  );

  @override
  Widget build(BuildContext context) {
    final glass = AppGlass.of(context);
    Widget content = Builder(
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        final dialogTheme = theme.dialogTheme;
        var shape = dialogTheme.shape ?? _defaultShape;
        final side = glass.border;
        if (side != null && shape is OutlinedBorder) {
          shape = shape.copyWith(side: side);
        }
        return Theme(
          data: theme.copyWith(
            dialogTheme: dialogTheme.copyWith(
              backgroundColor: glass.fill,
              elevation: 0,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              shape: shape,
            ),
          ),
          child: child,
        );
      },
    );
    if (glass.customTint) {
      content = AppGlassForegroundTheme(
        foreground: glass.foregroundFor(backdropColor),
        child: content,
      );
    }
    return content;
  }
}
