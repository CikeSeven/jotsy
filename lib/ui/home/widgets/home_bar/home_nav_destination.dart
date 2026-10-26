import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../models/home_bar_style/home_bar_resolved_style.dart';
import '../../models/home_bar_style/home_bar_style.dart';
import 'home_nav_block.dart';
import 'home_nav_indicator.dart';
import 'home_nav_layout.dart';

/// 首页底栏的一个导航项（[HomeNavBar] 内部使用）。
///
/// 结构照搬 Material `NavigationDestination`：按钮语义 + “第 x 个标签，共 y
/// 个”、长按提示、水波纹裁到指示器形状、文字最多放大到 1.3 倍。选中程度有
/// 两种来源：
/// - 未跟随滑动：[selection] 是本项自己的选中动画（选中时 0→1），只驱动
///   指示器的长出与“只显示选中项文字”时的文字显现；图标与文字颜色在选中
///   变化的那一帧直接切换（与 M3 一致），图标放大经 AnimatedScale 补间；
/// - 跟随滑动（[position] 非空）：颜色、放大与文字显现都按与页面位置的距离
///   逐帧插值，指示器由锚点项画并平移（见 [HomeNavDestinationLayout]）。
class HomeNavDestination extends StatefulWidget {
  const HomeNavDestination({
    super.key,
    required this.index,
    required this.count,
    required this.icon,
    required this.label,
    required this.selected,
    required this.selection,
    required this.labelCurve,
    required this.position,
    required this.labelMode,
    required this.iconSize,
    required this.indicator,
    required this.labelGap,
    required this.blockPadding,
    required this.cornerRadius,
    required this.barHeight,
    required this.metrics,
    required this.colors,
    required this.onTap,
  });

  final int index;
  final int count;
  final FaIconData icon;
  final String label;
  final bool selected;

  /// 本项的选中动画（线性）与它的文字显现曲线。
  final Animation<double> selection;
  final Animation<double> labelCurve;
  final ValueListenable<double>? position;
  final HomeBarLabelMode labelMode;
  final double iconSize;
  final HomeBarIndicator indicator;

  /// 文字与图标框的间距、圆角块的内边距（见 HomeBarStyle 同名字段）。
  final double labelGap;
  final double blockPadding;

  /// 栏的圆角与高度：圆角块按它们推算同心圆角（见 [HomeNavBlockBorder]）。
  final double cornerRadius;
  final double barHeight;

  /// 同一栏共享的内容尺寸，跟随滑动时推算相邻一项的块大小。
  final HomeNavContentMetrics metrics;
  final HomeNavColors colors;
  final VoidCallback onTap;

  @override
  State<HomeNavDestination> createState() => _HomeNavDestinationState();
}

class _HomeNavDestinationState extends State<HomeNavDestination> {
  /// 图标框（胶囊大小）的 key：胶囊样式的水波纹按它的位置画。
  final GlobalKey _iconKey = GlobalKey();

  /// 本项圆角块占位的 key：圆角块与无指示器的水波纹按它的位置画。块的
  /// 大小要到布局时才知道（随文字宽度、内边距与文字显现变化），由布局
  /// delegate 把占位摆到块的位置。
  final GlobalKey _blockKey = GlobalKey();

  /// 选中程度 [t]（0~1）下的颜色；端点直接取原色，保证默认样式逐像素不变。
  static Color _mixColor(Color from, Color to, double t) =>
      t <= 0 ? from : (t >= 1 ? to : Color.lerp(from, to, t)!);

  static TextStyle _mixStyle(TextStyle from, TextStyle to, double t) =>
      t <= 0 ? from : (t >= 1 ? to : TextStyle.lerp(from, to, t)!);

  /// 未跟随时按是否选中取 0 / 1，跟随时随页面位置逐帧重建。
  Widget _tracked(Widget Function(double t) builder) {
    final position = widget.position;
    if (position == null) {
      return builder(widget.selected ? 1 : 0);
    }
    return ValueListenableBuilder<double>(
      valueListenable: position,
      builder: (BuildContext context, double value, Widget? _) => builder(
        HomeNavGeometry.followAmount(widget.index, value, widget.count),
      ),
    );
  }

  Animation<double> get _labelReveal {
    final position = widget.position;
    return switch (widget.labelMode) {
      HomeBarLabelMode.always => kAlwaysCompleteAnimation,
      HomeBarLabelMode.never => kAlwaysDismissedAnimation,
      HomeBarLabelMode.selected =>
        position == null
            ? widget.labelCurve
            : HomeNavFollowAmount(position, widget.index, widget.count),
    };
  }

  bool get _isCapsule => widget.indicator == HomeBarIndicator.capsule;

  ShapeBorder get _rippleShape => _isCapsule
      ? const StadiumBorder()
      : HomeNavBlockBorder(
          cornerRadius: widget.cornerRadius,
          barHeight: widget.barHeight,
        );

  /// 胶囊的水波纹画在图标框上；圆角块与“无指示器”都裁成本项圆角块的形状。
  Rect _rippleRect(RenderBox referenceBox) {
    final key = _isCapsule ? _iconKey : _blockKey;
    final box = key.currentContext!.findRenderObject()! as RenderBox;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    return referenceBox.globalToLocal(rect.topLeft) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final position = widget.position;
    final duration = ExpressiveMotion.duration(context);
    final iconSize = widget.iconSize;

    final icon = _tracked((double t) {
      final color = _mixColor(colors.unselectedIcon, colors.selectedIcon, t);
      return IconTheme.merge(
        data: IconThemeData(size: iconSize, color: color),
        child: AnimatedScale(
          // 跟随滑动时放大量已逐帧给出，不再补间（否则落后于手指）。
          scale: position == null
              ? (widget.selected ? HomeNavGeometry.selectedIconScale : 1)
              : 1 + (HomeNavGeometry.selectedIconScale - 1) * t,
          duration: position == null ? duration : Duration.zero,
          curve: ExpressiveMotion.spatial,
          child: FaIcon(widget.icon, size: iconSize, color: color),
        ),
      );
    });
    // 间距不再包在文字外（M3 用 Padding），由布局 delegate 加上：栏太矮
    // 时 delegate 要先收窄间距，文字才不越出栏。
    final label = _tracked(
      // 与 M3 相同：文字最多放大到 1.3 倍，大字体下栏的层级不变；
      // 再长就省略，窄屏不溢出。
      (double t) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: Text(
          widget.label,
          style: _mixStyle(colors.unselectedLabel, colors.selectedLabel, t),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
    // 胶囊样式的图标框至少是胶囊大小（与 M3 把指示器放进图标 Stack 时的
    // 尺寸相同）；圆角块与无指示器时收紧到图标大小加放大余量，圆角块才能
    // 贴着内容、按内边距包住它，而不是被 32dp 的胶囊框撑开。
    final slot = _isCapsule
        ? const Size(
            HomeNavGeometry.capsuleWidth,
            HomeNavGeometry.capsuleHeight,
          )
        : Size.square(HomeNavGeometry.iconSlot(iconSize));
    final labelReveal = _labelReveal;
    final layout = CustomMultiChildLayout(
      delegate: HomeNavDestinationLayout(
        labelReveal: labelReveal,
        indicator: widget.indicator,
        textDirection: Directionality.of(context),
        labelGap: widget.labelGap,
        blockPadding: widget.blockPadding,
        follow: position == null
            ? null
            : HomeNavFollow(
                position: position,
                index: widget.index,
                count: widget.count,
                labelMode: widget.labelMode,
                metrics: widget.metrics,
              ),
      ),
      children: <Widget>[
        if (!_isCapsule)
          LayoutId(
            id: HomeNavDestinationLayout.blockSlotId,
            child: SizedBox(key: _blockKey),
          ),
        if (widget.indicator != HomeBarIndicator.none)
          LayoutId(
            id: HomeNavDestinationLayout.indicatorId,
            child: HomeNavIndicator(
              selection: widget.selection,
              position: position,
              index: widget.index,
              count: widget.count,
              shape: _rippleShape,
              color: colors.indicator,
            ),
          ),
        LayoutId(
          id: HomeNavDestinationLayout.iconId,
          child: KeyedSubtree(
            key: _iconKey,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                SizedBox.fromSize(size: slot),
                icon,
              ],
            ),
          ),
        ),
        LayoutId(
          id: HomeNavDestinationLayout.labelId,
          // 隐藏的文字仍留在语义里（只有图标时读屏也能读出名称）。
          child: FadeTransition(
            alwaysIncludeSemantics: true,
            opacity: labelReveal,
            child: label,
          ),
        ),
      ],
    );

    final localizations = MaterialLocalizations.of(context);
    final content = Tooltip(
      message: widget.label,
      // 与 M3 NavigationBar 相同的提示位置。
      verticalOffset: 42,
      excludeFromSemantics: true,
      preferBelow: false,
      child: HomeNavIndicatorInkResponse(
        rectOf: _rippleRect,
        customBorder: _rippleShape,
        onTap: widget.onTap,
        child: Row(children: <Widget>[Expanded(child: layout)]),
      ),
    );
    return Semantics(
      enabled: true,
      button: true,
      child: kIsWeb
          ? content
          : Stack(
              alignment: Alignment.center,
              children: <Widget>[
                content,
                Semantics(
                  label: localizations.tabLabel(
                    tabIndex: widget.index + 1,
                    tabCount: widget.count,
                  ),
                ),
              ],
            ),
    );
  }
}

/// 水波纹与焦点高亮只画在 [rectOf] 给出的矩形里（指示器或圆角块的位置），
/// 而不是整个导航项。底栏与宽窗口的侧边导航栏共用；侧边栏另给悬停与焦点
/// 的状态层颜色（底栏不传，沿用主题）。
class HomeNavIndicatorInkResponse extends InkResponse {
  const HomeNavIndicatorInkResponse({
    super.key,
    required this.rectOf,
    super.customBorder,
    super.onTap,
    super.hoverColor,
    super.focusColor,
    super.focusNode,
    super.mouseCursor,
    super.child,
  }) : super(containedInkWell: true, highlightColor: Colors.transparent);

  final Rect Function(RenderBox referenceBox) rectOf;

  @override
  RectCallback? getRectCallback(RenderBox referenceBox) =>
      () => rectOf(referenceBox);
}

/// 导航项的颜色：实色取主题，玻璃取 `HomeBarResolvedStyle` 的前景色。
@immutable
class HomeNavColors {
  const HomeNavColors({
    required this.indicator,
    required this.selectedIcon,
    required this.unselectedIcon,
    required this.selectedLabel,
    required this.unselectedLabel,
  });

  /// 按材质解析导航项颜色（底栏与侧边导航栏共用同一口径）：
  /// - 实色沿用主题（选中图标 onSecondaryContainer、未选中 onSurfaceVariant、
  ///   指示器 secondaryContainer，文字取 navigationBarTheme）；
  /// - 玻璃（高对比度下仍算玻璃）用 [style] 的前景色与指示器色。
  factory HomeNavColors.resolve(ThemeData theme, HomeBarResolvedStyle style) {
    final scheme = theme.colorScheme;
    final labelTheme = theme.navigationBarTheme.labelTextStyle;
    final base = theme.textTheme.labelMedium ?? const TextStyle();
    // 与 M3 NavigationBar 取文字样式的顺序一致：主题优先，缺省用 M3 默认。
    final selectedLabel =
        labelTheme?.resolve(const <WidgetState>{WidgetState.selected}) ??
        base.apply(color: scheme.onSurface);
    final unselectedLabel =
        labelTheme?.resolve(const <WidgetState>{}) ??
        base.apply(color: scheme.onSurfaceVariant);
    if (!style.isGlass) {
      return HomeNavColors(
        indicator: scheme.secondaryContainer,
        selectedIcon: scheme.onSecondaryContainer,
        unselectedIcon: scheme.onSurfaceVariant,
        selectedLabel: selectedLabel,
        unselectedLabel: unselectedLabel,
      );
    }
    return HomeNavColors(
      indicator: style.indicatorColor,
      selectedIcon: style.selectedForeground,
      unselectedIcon: style.unselectedForeground,
      selectedLabel: selectedLabel.copyWith(color: style.selectedForeground),
      unselectedLabel: unselectedLabel.copyWith(
        color: style.unselectedForeground,
      ),
    );
  }

  final Color indicator;
  final Color selectedIcon;
  final Color unselectedIcon;
  final TextStyle selectedLabel;
  final TextStyle unselectedLabel;
}
