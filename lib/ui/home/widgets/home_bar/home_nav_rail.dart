// 宽窗口（≥ 600dp）首页左侧的导航栏，取代底栏。
//
// 输入：导航项（最后一项为设置，固定在栏底）、选中项、点按回调、已解析的
// 首页栏样式与顶部的新建按钮；输出：96dp 宽、铺满高度的竖栏，无副作用。
//
// - 底色与手机底栏是同一块表面（见 [HomeNavRail.backgroundOf]），但从不画
//   玻璃：侧边栏下面没有会滚过去的内容，模糊没有意义；也不画分隔线；
// - 导航项与底栏同一套视觉口径：颜色经 [HomeNavColors.resolve]，指示器
//   形态（胶囊 / 色块 / 无）、文字模式、图标大小、文字间距、色块内边距都读
//   [HomeBarResolvedStyle]，选中动画复用 [HomeNavSelectionAnimator] 与
//   [HomeNavIndicator]；
// - 指示器区域有悬停 8% / 焦点 12% 的状态层（光标随平台默认，与应用里
//   其他按钮一致），文字不显示时给长按 / 悬停提示；
// - 高度不够（矮窗口、超大字体）时整列可滚动，不溢出。

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/app_breakpoints.dart';
import '../../../../app/theme/expressive_motion.dart';
import '../../../app_surface/widgets/app_glass_fab.dart';
import '../../../app_surface/widgets/app_glass_scope.dart';
import '../../../app_surface/widgets/app_glass_surface.dart';
import '../../../app_surface/widgets/app_page_backdrop.dart';
import '../../../widgets/launch_reveal.dart';
import '../../models/home_bar_style/home_bar_resolved_style.dart';
import '../../models/home_bar_style/home_bar_style.dart';
import 'home_nav_bar.dart';
import 'home_nav_destination.dart';
import 'home_nav_indicator.dart';
import 'home_nav_layout.dart';

/// 宽窗口首页的左侧导航栏。
class HomeNavRail extends StatelessWidget {
  const HomeNavRail({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
    required this.style,
    this.leading,
  });

  /// 栏顶与新建按钮之间、栏底与最后一项之间的留白。
  static const double edgePadding = 16;

  /// 新建按钮与第一个导航项之间的距离。
  static const double leadingGap = 28;

  /// 相邻导航项之间的距离（不含导航项自身上下的 [itemPadding]）：上一项
  /// 文字底到下一项指示器顶共 itemSpacing + 2 × itemPadding = 16。
  static const double itemSpacing = 12;

  /// 每个导航项上下各自的内边距，算进点按区域。栏顶 / 栏底的留白与新建按钮
  /// 下方的间距扣掉它，指示器到新建按钮仍是 [leadingGap]、设置的文字到栏底
  /// 仍是 [edgePadding]。
  static const double itemPadding = 2;

  /// 侧边栏底色：与手机底栏实际画出的颜色相同，两种宽度下是同一块表面。
  /// - 实色：底栏（BottomNav）的底色，即 navigationBarTheme 的背景色（亮色
  ///   与页面画布同色，暗色 surfaceContainer）；当前 Tab 区域设了背景时
  ///   （[backdrop] 实际在画）改为该区域的实色栏底色——纯色背景时与页面
  ///   连成一片，图片背景时保持不透明的 surface；
  /// - 玻璃：玻璃底色（含自定义颜色）的不透明等效色 solidFill——侧边栏不
  ///   模糊，与高对比度下的玻璃底栏同一颜色。
  static Color backgroundOf(
    ThemeData theme,
    HomeBarResolvedStyle style, {
    AppPageBackdrop? backdrop,
  }) {
    if (style.isGlass) {
      return style.solidFill;
    }
    if (backdrop != null && backdrop.hasBackground) {
      return backdrop.solidBarColor;
    }
    return theme.navigationBarTheme.backgroundColor ??
        theme.colorScheme.surfaceContainer;
  }

  /// 导航项（至少一项）；最后一项（设置）固定在栏底，其余从上往下排。
  final List<BottomNavItem> items;

  /// 选中项；越界时夹到有效范围（Tab 集合变化的那一帧可能短暂越界）。
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final HomeBarResolvedStyle style;

  /// 栏顶的主操作（新建按钮，见 [HomeNavRailCreateButton]）。
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final count = items.length;
    final selected = count == 0 ? 0 : selectedIndex.clamp(0, count - 1);
    final colors = HomeNavColors.resolve(Theme.of(context), style);
    final duration = ExpressiveMotion.duration(context);

    Widget item(int index) => HomeNavSelectionAnimator(
      selected: index == selected,
      duration: duration,
      builder: (context, selection, labelCurve) => HomeNavRailDestination(
        icon: items[index].icon,
        label: items[index].label,
        selected: index == selected,
        selection: selection,
        labelCurve: labelCurve,
        style: style,
        colors: colors,
        onTap: () => onTap(index),
      ),
    );

    final column = Column(
      children: <Widget>[
        const SizedBox(height: edgePadding),
        if (leading != null) ...<Widget>[
          leading!,
          const SizedBox(height: leadingGap - itemPadding),
        ],
        for (var i = 0; i < count - 1; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: itemSpacing),
          item(i),
        ],
        const Spacer(),
        if (count > 0) ...<Widget>[
          const SizedBox(height: itemSpacing),
          item(count - 1),
        ],
        const SizedBox(height: edgePadding - itemPadding),
      ],
    );

    return LaunchReveal(
      slot: LaunchRevealSlot.navigation,
      // 透明度以外的材质：Material 承载指示器（Ink）与水波纹。
      child: Material(
        color: backgroundOf(
          Theme.of(context),
          style,
          backdrop: AppPageBackdrop.maybeOf(context),
        ),
        child: SizedBox(
          width: AppContentWidth.navRail,
          // 只避让侧边栏所在一侧（从右到左的语言下栏在右侧）与上下的系统
          // 内边距，另一侧挨着页面区。
          child: SafeArea(
            left: Directionality.of(context) == TextDirection.ltr,
            right: Directionality.of(context) == TextDirection.rtl,
            // 矮窗口或超大字体放不下时整列滚动；放得下时设置贴底。
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: CustomScrollView(
                primary: false,
                slivers: <Widget>[
                  SliverFillRemaining(hasScrollBody: false, child: column),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 侧边栏顶部的新建按钮：56×56、圆角 16 的 FAB（primaryContainer），
/// 文字只作提示与读屏（与紧凑窗口的全局 FAB 同一文案）。
class HomeNavRailCreateButton extends StatelessWidget {
  const HomeNavRailCreateButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  static const double size = 56;
  static const double radius = 16;

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glass = AppGlass.of(context).isGlass(AppGlassComponent.controls);
    final button = FloatingActionButton(
      // 同一路由里可能还有别的 FAB（各 Tab 页面），不参与 Hero 飞行。
      heroTag: null,
      tooltip: label,
      onPressed: onPressed,
      // 玻璃时底色交给外面的玻璃表面（AppGlassFab 经局部主题把它换成透明）。
      backgroundColor: glass ? null : scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      child: const FaIcon(FontAwesomeIcons.plus, size: 20),
    );
    if (!glass) return button;
    // 侧栏上没有可模糊的内容（下面只有侧栏自己的底色 / 页面背景），不模糊，
    // 只要主色半透明底色。调用方负责入场不经透明度层（GlassReveal）。
    return AppGlassFab(
      borderRadius: BorderRadius.circular(radius),
      blur: AppGlassBlur.none,
      child: button,
    );
  }
}

/// 侧边栏的一个导航项：指示器（胶囊 56×32 包住图标，或色块包住图标与
/// 文字）在上，文字在下。
///
/// 选中变化时颜色直接切换、图标经 AnimatedScale 放大、指示器横向长出，
/// 与底栏未跟随滑动时相同；“只显示选中项文字”时文字随 [labelCurve] 展开
/// 并淡入。
class HomeNavRailDestination extends StatefulWidget {
  const HomeNavRailDestination({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.selection,
    required this.labelCurve,
    required this.style,
    required this.colors,
    required this.onTap,
  });

  /// 胶囊指示器尺寸（M3 侧边导航栏规格）。
  static const double capsuleWidth = 56;
  static const double capsuleHeight = 32;

  /// 色块指示器的最小宽度（与胶囊同宽），以及它的圆角。
  static const double blockMinWidth = 56;
  static const double blockRadius = 16;

  /// 文字字号与字重。
  static const double labelFontSize = 12;
  static const FontWeight labelWeight = FontWeight.w600;

  /// 文字左右至少离栏边缘的距离。
  static const double labelSideInset = 8;

  /// 悬停 / 焦点状态层的不透明度（M3 状态层规格）。
  static const double hoverOpacity = 0.08;
  static const double focusOpacity = 0.12;

  final FaIconData icon;
  final String label;
  final bool selected;
  final Animation<double> selection;
  final Animation<double> labelCurve;
  final HomeBarResolvedStyle style;
  final HomeNavColors colors;
  final VoidCallback onTap;

  @override
  State<HomeNavRailDestination> createState() => _HomeNavRailDestinationState();
}

class _HomeNavRailDestinationState extends State<HomeNavRailDestination> {
  /// 胶囊所在的图标框：胶囊样式的水波纹与状态层画在这里。
  final GlobalKey _iconKey = GlobalKey();

  /// 色块所在的矩形：色块与“无指示器”时的水波纹画在这里。
  final GlobalKey _blockKey = GlobalKey();

  bool get _isCapsule => widget.style.indicator == HomeBarIndicator.capsule;

  /// 文字此刻是否显示（决定是否给提示）。
  bool get _labelVisible => switch (widget.style.labelMode) {
    HomeBarLabelMode.always => true,
    HomeBarLabelMode.never => false,
    HomeBarLabelMode.selected => widget.selected,
  };

  ShapeBorder get _shape => _isCapsule
      ? const StadiumBorder()
      : RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            HomeNavRailDestination.blockRadius,
          ),
        );

  Rect _rippleRect(RenderBox referenceBox) {
    final key = _isCapsule ? _iconKey : _blockKey;
    final box = key.currentContext!.findRenderObject()! as RenderBox;
    final topLeft = referenceBox.globalToLocal(box.localToGlobal(Offset.zero));
    return topLeft & box.size;
  }

  Widget _indicator() => HomeNavIndicator(
    selection: widget.selection,
    position: null,
    index: 0,
    count: 1,
    shape: _shape,
    color: widget.colors.indicator,
  );

  Widget _label(TextStyle style) {
    final text = Padding(
      padding: EdgeInsets.only(top: widget.style.labelGap),
      // 与底栏相同：文字最多放大到 1.3 倍，再长就省略。
      // 名称已由导航项的语义给出，画出来的文字不重复朗读。
      child: ExcludeSemantics(
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: Text(
            widget.label,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
    if (widget.style.labelMode != HomeBarLabelMode.selected) {
      return text;
    }
    // 只显示选中项文字：高度随显现展开，导航项之间不会突然跳动。
    return SizeTransition(
      sizeFactor: widget.labelCurve,
      alignment: Alignment.topCenter,
      child: FadeTransition(opacity: widget.labelCurve, child: text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final style = widget.style;
    final selected = widget.selected;
    final iconColor = selected ? colors.selectedIcon : colors.unselectedIcon;
    final labelStyle =
        (selected ? colors.selectedLabel : colors.unselectedLabel).copyWith(
          fontSize: HomeNavRailDestination.labelFontSize,
          fontWeight: HomeNavRailDestination.labelWeight,
        );

    final iconSlot = _isCapsule
        ? const Size(
            HomeNavRailDestination.capsuleWidth,
            HomeNavRailDestination.capsuleHeight,
          )
        : Size.square(HomeNavGeometry.iconSlot(style.iconSize));
    final icon = KeyedSubtree(
      key: _iconKey,
      child: SizedBox.fromSize(
        size: iconSlot,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            if (_isCapsule) Positioned.fill(child: _indicator()),
            AnimatedScale(
              scale: selected ? HomeNavGeometry.selectedIconScale : 1,
              duration: ExpressiveMotion.duration(context),
              curve: ExpressiveMotion.spatial,
              child: FaIcon(
                widget.icon,
                size: style.iconSize,
                color: iconColor,
              ),
            ),
          ],
        ),
      ),
    );

    final hasLabel = style.labelMode != HomeBarLabelMode.never;
    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[icon, if (hasLabel) _label(labelStyle)],
    );
    if (!_isCapsule) {
      // 色块（或无指示器时的水波纹范围）包住图标与文字，四周留内边距。
      content = Stack(
        children: <Widget>[
          Positioned.fill(
            child: KeyedSubtree(
              key: _blockKey,
              child: style.indicator == HomeBarIndicator.block
                  ? _indicator()
                  : const SizedBox.expand(),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(style.blockPadding),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth:
                    HomeNavRailDestination.blockMinWidth -
                    style.blockPadding * 2,
              ),
              child: content,
            ),
          ),
        ],
      );
    }

    final stateColor = iconColor;
    Widget result = HomeNavIndicatorInkResponse(
      rectOf: _rippleRect,
      customBorder: _shape,
      hoverColor: stateColor.withValues(
        alpha: HomeNavRailDestination.hoverOpacity,
      ),
      focusColor: stateColor.withValues(
        alpha: HomeNavRailDestination.focusOpacity,
      ),
      onTap: widget.onTap,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HomeNavRailDestination.labelSideInset,
            vertical: HomeNavRail.itemPadding,
          ),
          child: Center(child: content),
        ),
      ),
    );
    if (!_labelVisible) {
      result = Tooltip(
        message: widget.label,
        excludeFromSemantics: true,
        child: result,
      );
    }
    // 名称始终进语义（文字隐藏时也能读出）；点按动作来自 InkResponse。
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        label: widget.label,
        child: result,
      ),
    );
  }
}
