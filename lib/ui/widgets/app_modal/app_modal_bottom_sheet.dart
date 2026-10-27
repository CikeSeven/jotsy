import 'package:flutter/material.dart';

import '../../app_surface/widgets/app_glass_scope.dart';
import '../../app_surface/widgets/app_glass_surface.dart';

/// 全应用打开模态底部面板的唯一入口（`test/ui/widgets/app_modal_source_test.dart`
/// 源码检查兜底：本目录之外不得直接调用 `showModalBottomSheet`）。
///
/// 输入：与 [showModalBottomSheet] 同名同义的参数（只收仓库实际用到的那些，
/// 原样透传）；输出：面板关闭时的返回值。材质取自调用处的
/// `AppGlass.of(context).isGlass(AppGlassComponent.sheets)`：
///
/// - 经典：原样调用 [showModalBottomSheet]，行为与像素和接入前完全相同；
/// - 玻璃：面板本身（BottomSheet 的 Material）改为透明、无投影、不画 SDK
///   拖动条，[builder] 的内容外面包一块 [AppGlassSurface]（总是模糊——面板
///   下面是页面内容，不模糊上面的文字没法读），圆角只取主题面板形状的上方
///   两角。原本会显示拖动条时，在玻璃**里面**顶部按 SDK `_DragHandle` 的
///   尺寸、颜色与上下间距自己画一个：SDK 的拖动条画在 BottomSheet 的
///   Material 上、玻璃之外，会被玻璃盖住或浮在玻璃外面。拖动手势仍由
///   BottomSheet 本身负责（整块面板可拖），与经典一致。
///
/// 路由仍是 [ModalBottomSheetRoute]：入场是位移（`_BottomSheetLayoutWithSizeListener`
/// 按动画值摆放），没有 Opacity / FadeTransition 祖先，玻璃的背景模糊可以
/// 正常采样页面；`isScrollControlled`、`useSafeArea`、`constraints`、键盘避让
/// （调用方自己按 viewInsets 留白）与 [DraggableScrollableSheet] 内容都不受
/// 影响——玻璃只是包在内容外面、随内容尺寸伸缩。
Future<T?> showAppModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  BoxConstraints? constraints,
  Color? barrierColor,
  String? barrierLabel,
  bool isScrollControlled = false,
  bool useRootNavigator = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool? showDragHandle,
  bool useSafeArea = false,
  RouteSettings? routeSettings,
  AnimationStyle? sheetAnimationStyle,
  bool? requestFocus,
}) {
  final glass = AppGlass.of(context);
  if (!glass.isGlass(AppGlassComponent.sheets)) {
    return showModalBottomSheet<T>(
      context: context,
      builder: builder,
      constraints: constraints,
      barrierColor: barrierColor,
      barrierLabel: barrierLabel,
      isScrollControlled: isScrollControlled,
      useRootNavigator: useRootNavigator,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      showDragHandle: showDragHandle,
      useSafeArea: useSafeArea,
      routeSettings: routeSettings,
      sheetAnimationStyle: sheetAnimationStyle,
      requestFocus: requestFocus,
    );
  }
  final sheetTheme = Theme.of(context).bottomSheetTheme;
  // 与 BottomSheet 判断要不要画拖动条的口径一致：调用方显式给出时以它为准，
  // 否则可拖且主题打开拖动条时才画。
  final handle =
      showDragHandle ?? (enableDrag && (sheetTheme.showDragHandle ?? false));
  final radius = appSheetTopRadius(
    sheetTheme.shape,
    Directionality.of(context),
  );
  return showModalBottomSheet<T>(
    context: context,
    // 面板底色、投影与拖动条都交给玻璃：留着 Material 的底色会在玻璃下面
    // 再垫一层不透明表面（双层表面），模糊也就看不出来。
    backgroundColor: Colors.transparent,
    elevation: 0,
    showDragHandle: false,
    constraints: constraints,
    barrierColor: barrierColor,
    barrierLabel: barrierLabel,
    isScrollControlled: isScrollControlled,
    useRootNavigator: useRootNavigator,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useSafeArea: useSafeArea,
    routeSettings: routeSettings,
    sheetAnimationStyle: sheetAnimationStyle,
    requestFocus: requestFocus,
    builder: (BuildContext sheetContext) => AppGlassSurface(
      component: AppGlassComponent.sheets,
      blur: AppGlassBlur.always,
      borderRadius: radius,
      // 内容放进 Builder：builder 拿到的 context 在玻璃之内，自定义底色时
      // 读到的是玻璃换过前景色的主题。
      child: handle
          ? Stack(
              alignment: Alignment.topCenter,
              children: <Widget>[
                const AppGlassSheetDragHandle(),
                Padding(
                  // 与 BottomSheet 给拖动条让出的高度一致（SDK 同样用
                  // kMinInteractiveDimension）。
                  padding: const EdgeInsets.only(top: kMinInteractiveDimension),
                  child: Builder(builder: builder),
                ),
              ],
            )
          : Builder(builder: builder),
    ),
  );
}

/// 玻璃面板的圆角：只取主题面板形状的上方两角（面板贴着屏幕底边，下方
/// 不圆）。主题不是圆角矩形时退回 M3 默认的上方 28。
BorderRadius appSheetTopRadius(ShapeBorder? shape, TextDirection direction) {
  if (shape is RoundedRectangleBorder) {
    final resolved = shape.borderRadius.resolve(direction);
    return BorderRadius.only(
      topLeft: resolved.topLeft,
      topRight: resolved.topRight,
    );
  }
  return const BorderRadius.vertical(top: Radius.circular(28));
}

/// 画在玻璃面板里面的拖动条，尺寸、颜色、上下间距与语义都照搬 SDK 的
/// `_DragHandle`：48×48 的可点区域里居中一条（主题尺寸，缺省 32×4）全圆角
/// 小条；读屏可点按关闭。
///
/// 颜色：主题的 `dragHandleColor`（缺省 onSurfaceVariant）。玻璃用自定义
/// 底色时改取玻璃里换过的 onSurfaceVariant——主题里的颜色是按实色面板烤
/// 好的，叠在用户的颜色上可能看不清。悬停态不单独处理：主题给的是普通
/// 颜色而不是 WidgetStateColor，SDK 那里悬停同样不变色。
class AppGlassSheetDragHandle extends StatelessWidget {
  const AppGlassSheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sheetTheme = theme.bottomSheetTheme;
    final size = sheetTheme.dragHandleSize ?? const Size(32, 4);
    final themed = WidgetStateProperty.resolveAs<Color?>(
      sheetTheme.dragHandleColor,
      const <WidgetState>{},
    );
    final color = AppGlass.of(context).customTint
        ? theme.colorScheme.onSurfaceVariant
        : themed ?? theme.colorScheme.onSurfaceVariant;
    return Semantics(
      label: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      container: true,
      button: true,
      // SDK 的拖动条点按即 BottomSheet.onClosing：面板路由在栈顶时关闭。
      onTap: () {
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          Navigator.of(context).pop();
        }
      },
      child: SizedBox(
        width: size.width < kMinInteractiveDimension
            ? kMinInteractiveDimension
            : size.width,
        height: size.height < kMinInteractiveDimension
            ? kMinInteractiveDimension
            : size.height,
        child: Center(
          child: Container(
            width: size.width,
            height: size.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size.height / 2),
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
