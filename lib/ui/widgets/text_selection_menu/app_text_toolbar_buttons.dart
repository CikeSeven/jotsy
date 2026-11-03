import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/expressive_motion.dart';
import 'app_text_menu_action.dart';

/// 手机文字选区胶囊里的按钮：主行的“图标在上、文字在下”按钮、末尾的
/// 「更多 / 收起」，以及展开后的两列次要区。只负责画与点按，排布与展开状态
/// 在 `app_text_selection_toolbar.dart`。

/// 主行按钮的尺寸规格。
abstract final class AppTextToolbarMetrics {
  static const double rowHeight = 56;
  static const double buttonMinWidth = 56;
  static const double buttonPadding = 10;
  static const double iconSize = 16;
  static const double iconGap = 4;
  static const double restingRadius = 20;
  static const double pressedRadius = 12;

  static const double cellHeight = 44;
  static const double cellPadding = 12;
  static const double cellRadius = 16;
  static const double cellIconGap = 12;
  static const int maxVisibleRows = 4;

  /// 分隔线：1dp，上下各留 4。
  static const double dividerHeight = 9;
  static const double dividerIndent = 12;

  /// 主行文字：labelSmall + w500，取主题文字样式派生（保留应用字体）。
  static TextStyle? labelStyleOf(ThemeData theme) =>
      theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w500,
        color: theme.colorScheme.onSurface,
      );

  /// [label] 所在按钮的宽度：文字宽 + 左右内边距，至少 [buttonMinWidth]。
  ///
  /// 布局前就要算出来（判断主行放不放得下），按钮本身也用这个宽度，保证判断
  /// 与实际排布一致。
  static double buttonWidthOf(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: labelStyleOf(Theme.of(context))),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return math.max(buttonMinWidth, width.ceilToDouble() + buttonPadding * 2);
  }
}

/// 主行按钮与次要格共用的按钮样式：叠色取 primary（按下 / 聚焦 12%、悬停
/// 8%），与 `ExpressiveMenuItem` 一致；[pressedRadius] 不为 null 时按下收紧圆角
/// （fast，减少动画时直接切换）。
ButtonStyle _buttonStyle(
  BuildContext context, {
  required EdgeInsetsGeometry padding,
  required Size minimumSize,
  required double radius,
  double? pressedRadius,
  required TextStyle? textStyle,
}) {
  final colors = Theme.of(context).colorScheme;
  return ButtonStyle(
    foregroundColor: WidgetStatePropertyAll<Color>(colors.onSurface),
    overlayColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      if (states.contains(WidgetState.pressed) ||
          states.contains(WidgetState.focused)) {
        return colors.primary.withValues(alpha: 0.12);
      }
      if (states.contains(WidgetState.hovered)) {
        return colors.primary.withValues(alpha: 0.08);
      }
      return null;
    }),
    textStyle: WidgetStatePropertyAll<TextStyle?>(textStyle),
    padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(padding),
    minimumSize: WidgetStatePropertyAll<Size>(minimumSize),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.standard,
    shape: WidgetStateProperty.resolveWith(
      (Set<WidgetState> states) => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          pressedRadius != null && states.contains(WidgetState.pressed)
              ? pressedRadius
              : radius,
        ),
      ),
    ),
    animationDuration: ExpressiveMotion.duration(
      context,
      ExpressiveMotion.fast,
    ),
  );
}

ButtonStyle _rowButtonStyle(BuildContext context) => _buttonStyle(
  context,
  padding: const EdgeInsets.symmetric(
    horizontal: AppTextToolbarMetrics.buttonPadding,
  ),
  minimumSize: const Size(
    AppTextToolbarMetrics.buttonMinWidth,
    AppTextToolbarMetrics.rowHeight,
  ),
  radius: AppTextToolbarMetrics.restingRadius,
  pressedRadius: AppTextToolbarMetrics.pressedRadius,
  textStyle: AppTextToolbarMetrics.labelStyleOf(Theme.of(context)),
);

/// 主行按钮的内容：16px 图标在上、单行文字在下。
Widget _rowContent(BuildContext context, FaIconData icon, String label) =>
    Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FaIcon(
          icon,
          size: AppTextToolbarMetrics.iconSize,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: AppTextToolbarMetrics.iconGap),
        Text(label, maxLines: 1, softWrap: false),
      ],
    );

/// 主行的一项，宽度由调用方按 [AppTextToolbarMetrics.buttonWidthOf] 给定。
class AppTextToolbarRowButton extends StatelessWidget {
  const AppTextToolbarRowButton({
    super.key,
    required this.action,
    required this.width,
  });

  final AppTextMenuAction action;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: AppTextToolbarMetrics.rowHeight,
    child: TextButton(
      style: _rowButtonStyle(context),
      onPressed: action.onPressed,
      child: _rowContent(context, action.icon, action.label),
    ),
  );
}

/// 主行末尾的「更多 / 收起」：图标与文字随 [expanded] 交叉淡入（fast），
/// 宽度取两种文字里较宽的一个，切换时主行不变宽。读屏读出当前文字与展开状态。
class AppTextToolbarMoreButton extends StatelessWidget {
  const AppTextToolbarMoreButton({
    super.key,
    required this.expanded,
    required this.moreLabel,
    required this.lessLabel,
    required this.width,
    required this.onPressed,
  });

  final bool expanded;
  final String moreLabel;
  final String lessLabel;
  final double width;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final duration = ExpressiveMotion.duration(context, ExpressiveMotion.fast);
    Widget face(bool visible, FaIconData icon, String label) => AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: duration,
      curve: ExpressiveMotion.effects,
      child: _rowContent(context, icon, label),
    );
    return SizedBox(
      width: width,
      height: AppTextToolbarMetrics.rowHeight,
      child: Semantics(
        expanded: expanded,
        label: expanded ? lessLabel : moreLabel,
        button: true,
        onTap: onPressed,
        child: ExcludeSemantics(
          child: TextButton(
            style: _rowButtonStyle(context),
            onPressed: onPressed,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                face(!expanded, FontAwesomeIcons.ellipsis, moreLabel),
                face(expanded, FontAwesomeIcons.angleUp, lessLabel),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 次要区：两列网格，每格 44 高；只有一项时整行一格。最多显示
/// [AppTextToolbarMetrics.maxVisibleRows] 行，再多在内部纵向滚动，并且不超过
/// [maxHeight]（所在一侧剩余的空间）。
///
/// 不参与卡片宽度的计算（固有宽度报 0）：卡片宽只看主行与最小宽 256，次要项
/// 文字过长时单行省略，而不是把卡片撑宽。
class AppTextToolbarSecondaryGrid extends StatelessWidget {
  const AppTextToolbarSecondaryGrid({
    super.key,
    required this.actions,
    required this.maxHeight,
  });

  final List<AppTextMenuAction> actions;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      if (actions.length == 1)
        _cell(context, actions.single)
      else
        for (var i = 0; i < actions.length; i += 2)
          Row(
            children: <Widget>[
              Expanded(child: _cell(context, actions[i])),
              Expanded(
                child: i + 1 < actions.length
                    ? _cell(context, actions[i + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
    ];
    final visibleRows = math.min(
      rows.length,
      AppTextToolbarMetrics.maxVisibleRows,
    );
    final height = math.min(
      visibleRows * AppTextToolbarMetrics.cellHeight,
      math.max(0.0, maxHeight),
    );
    return _ZeroIntrinsicWidth(
      child: SizedBox(
        height: height,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            scrollbars: false,
            overscroll: false,
            physics: const ClampingScrollPhysics(),
          ),
          child: SingleChildScrollView(
            primary: false,
            child: Column(children: rows),
          ),
        ),
      ),
    );
  }

  Widget _cell(BuildContext context, AppTextMenuAction action) {
    final theme = Theme.of(context);
    return SizedBox(
      height: AppTextToolbarMetrics.cellHeight,
      child: TextButton(
        style: _buttonStyle(
          context,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTextToolbarMetrics.cellPadding,
          ),
          minimumSize: const Size(0, AppTextToolbarMetrics.cellHeight),
          radius: AppTextToolbarMetrics.cellRadius,
          textStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        onPressed: action.onPressed,
        child: Row(
          children: <Widget>[
            FaIcon(
              action.icon,
              size: AppTextToolbarMetrics.iconSize,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: AppTextToolbarMetrics.cellIconGap),
            Expanded(
              child: Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 固有宽度报 0 的透明包装，见 [AppTextToolbarSecondaryGrid]。
class _ZeroIntrinsicWidth extends SingleChildRenderObjectWidget {
  const _ZeroIntrinsicWidth({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderZeroIntrinsicWidth();
}

class _RenderZeroIntrinsicWidth extends RenderProxyBox {
  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => 0;
}
