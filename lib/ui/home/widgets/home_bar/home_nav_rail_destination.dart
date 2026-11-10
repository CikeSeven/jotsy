import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../models/home_bar_style/home_bar_metrics.dart';
import '../../models/home_bar_style/home_bar_resolved_style.dart';
import '../../models/home_bar_style/home_bar_style.dart';
import 'home_nav_colors.dart';
import 'home_nav_geometry.dart';
import 'home_nav_ink_response.dart';

/// 侧边栏（宽窗口，[HomeNavRail]）的一个导航项：与底栏同样大小的一格
/// （显示文字时 72×48，只有图标时 64×42），图标在上、文字在下并在格子里
/// 居中，选中时格子铺上胶囊形的指示器。
///
/// 输入：图标、名称、是否选中、选中动画（[selection] 线性、[labelCurve]
/// 渐变）、已解析样式（只读文字模式）与颜色；输出：占满侧边栏宽度的一行
/// 点按区。无副作用。
///
/// 选中变化时颜色直接切换、图标经 AnimatedScale 放大、指示器先跳到 40%
/// 宽再横向长满（[ExpressiveMotion.spatial]）；“只显示选中项文字”时文字随
/// [labelCurve] 展开并淡入。侧边栏的各项竖着排、彼此不相邻，指示器不在
/// 项之间滑动（底栏那颗滑动的指示器见 `HomeNavIndicator`）。
///
/// 水波纹、悬停与焦点状态层只画在格子里（胶囊形），不铺满整行。
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

  /// 文字字号：比底栏大一号，桌面上隔着更远的距离也读得清。
  static const double labelFontSize = 12;

  /// 每个导航项上下各自的内边距，算进点按区域（`HomeNavRail.itemPadding`
  /// 取它，排版时从相邻的间距里扣掉）。
  static const double verticalPadding = 2;

  /// 悬停 / 焦点状态层的不透明度（M3 状态层规格）。
  static const double hoverOpacity = 0.08;
  static const double focusOpacity = 0.12;

  /// 一格（指示器、水波纹与状态层）的大小：与底栏的导航项相同。
  static Size cellSize(HomeBarLabelMode mode) => Size(
    HomeBarMetrics.itemWidth(mode),
    HomeBarMetrics.itemHeight(HomeBarMetrics.barHeight(mode)),
  );

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
  /// 格子所在的矩形：指示器、水波纹与状态层都画在这里。
  final GlobalKey _cellKey = GlobalKey();

  HomeBarLabelMode get _labelMode => widget.style.labelMode;

  /// 文字此刻是否显示（决定是否给提示）。
  bool get _labelVisible => switch (_labelMode) {
    HomeBarLabelMode.always => true,
    HomeBarLabelMode.never => false,
    HomeBarLabelMode.selected => widget.selected,
  };

  Rect _rippleRect(RenderBox referenceBox) {
    final box = _cellKey.currentContext!.findRenderObject()! as RenderBox;
    final topLeft = referenceBox.globalToLocal(box.localToGlobal(Offset.zero));
    return topLeft & box.size;
  }

  /// 指示器：用 Ink 画在侧边栏的 Material 上，水波纹才会盖在它上面。
  /// 未选中时宽度为 0；选中时从 40% 宽横向长满。
  Widget _indicator() => AnimatedBuilder(
    animation: widget.selection,
    builder: (BuildContext context, Widget? child) {
      final selection = widget.selection;
      final scale = selection.isDismissed
          ? 0.0
          : 0.4 + 0.6 * ExpressiveMotion.spatial.transform(selection.value);
      return Transform(
        alignment: Alignment.center,
        // 只横向缩放。
        transform: Matrix4.diagonal3Values(scale, 1, 1),
        child: child,
      );
    },
    child: Ink(
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: widget.colors.indicator,
      ),
    ),
  );

  Widget _label(TextStyle style) {
    final text = Padding(
      padding: const EdgeInsets.only(top: HomeBarMetrics.labelGap),
      // 与底栏相同：文字最多放大到 1.3 倍，太长的名称等比缩小到放得下。
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(widget.label, style: style, maxLines: 1, softWrap: false),
        ),
      ),
    );
    if (_labelMode != HomeBarLabelMode.selected) {
      return text;
    }
    // 只显示选中项文字：高度随显现展开，图标随之让到上方。
    return SizeTransition(
      sizeFactor: widget.labelCurve,
      alignment: Alignment.topCenter,
      child: FadeTransition(opacity: widget.labelCurve, child: text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final selected = widget.selected;
    final iconColor = selected ? colors.selectedIcon : colors.unselectedIcon;
    final labelStyle =
        (selected ? colors.selectedLabel : colors.unselectedLabel).copyWith(
          fontSize: HomeNavRailDestination.labelFontSize,
          height: 1.2,
        );

    final icon = SizedBox.square(
      dimension: HomeBarMetrics.iconBox,
      child: Center(
        child: AnimatedScale(
          scale: selected ? HomeNavGeometry.selectedIconScale : 1,
          duration: ExpressiveMotion.duration(context),
          curve: ExpressiveMotion.spatial,
          child: FaIcon(
            widget.icon,
            size: HomeBarMetrics.iconSize,
            color: iconColor,
          ),
        ),
      ),
    );
    final cell = SizedBox.fromSize(
      size: HomeNavRailDestination.cellSize(_labelMode),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: KeyedSubtree(key: _cellKey, child: _indicator()),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: HomeBarMetrics.labelSideInset,
              ),
              // 名称已由导航项的语义给出，画出来的文字不重复朗读。
              child: ExcludeSemantics(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    icon,
                    if (_labelMode != HomeBarLabelMode.never)
                      _label(labelStyle),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Widget result = HomeNavIndicatorInkResponse(
      rectOf: _rippleRect,
      customBorder: const StadiumBorder(),
      hoverColor: iconColor.withValues(
        alpha: HomeNavRailDestination.hoverOpacity,
      ),
      focusColor: iconColor.withValues(
        alpha: HomeNavRailDestination.focusOpacity,
      ),
      onTap: widget.onTap,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: HomeNavRailDestination.verticalPadding,
          ),
          child: Center(child: cell),
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
