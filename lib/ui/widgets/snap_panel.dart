import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_effects.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/expressive_motion.dart';
import '../../app/theme/expressive_surfaces.dart';
import 'snap_panel_controller.dart';

export 'snap_panel_controller.dart';
export 'snap_panel_scroll.dart';

/// 叠在背景内容上、可拖动并停在三个档位的面板（卡片样式页：背景是实时预览，
/// 面板是选项）。
///
/// 布局：面板贴底，可见高度取 [SnapPanelController.layoutExtent]；背景占面板
/// 上方的区域并多延伸一个圆角半径，面板的圆角压在背景上而不是露出空白。最低档
/// 只露出拖动条与 [header]（再加系统手势区）；中档为 [halfExtent]；最高档盖满
/// 整个区域。
///
/// 手势：拖动条与 [header] 上的竖向拖动跟手移动面板；[body] 里的滚动视图经
/// [SnapPanelScrollScope] 与面板联动（内容优先，见 [SnapPanelScrollController]）。
/// 松手按速度与位置吸附。点按拖动条在档位间切换，读屏经“调大/调小”换档。
///
/// 位置逐帧变化只触发重新布局与 [body] 的淡入淡出，子树不随拖动重建。
class SnapPanel extends StatefulWidget {
  const SnapPanel({
    super.key,
    required this.controller,
    required this.background,
    required this.header,
    required this.body,
    required this.halfExtent,
    required this.handleLabel,
    required this.stopLabel,
  });

  /// 拖动条区域的高度（不含 [header]）。
  static const double handleExtent = 22;

  /// 面板顶部圆角，与悬浮面板一致。
  static const double cornerRadius = AppRadii.nav;

  /// 离开最低档后 [body] 在这段高度内淡入：最低档时内容完全隐去，系统手势区
  /// 里不会露出半截选项。
  static const double bodyFadeExtent = 48;

  /// 面板左右与底边向外多出的宽度：微边框只在顶边与圆角可见，两侧与底边的
  /// 描边落在区域之外被裁掉（面板贴着屏幕左右边缘，两侧画线会像屏幕描了边）。
  static const double _bleed = 1;

  final SnapPanelController controller;

  /// 面板背后的内容，高度随面板位置变化。
  final Widget background;

  /// 拖动条下方、始终可见的表头（如标签栏），高度取它的 preferredSize。
  final PreferredSizeWidget header;

  /// 表头下方的面板内容；其中的滚动视图用 [SnapPanelScrollScope] 包裹。
  final Widget body;

  /// 中档时面板的可见高度（含拖动条与表头）。
  final double halfExtent;

  /// 拖动条的读屏名称。
  final String handleLabel;

  /// 档位的读屏描述。
  final String Function(SnapPanelStop stop) stopLabel;

  @override
  State<SnapPanel> createState() => _SnapPanelState();
}

class _SnapPanelState extends State<SnapPanel> {
  static const BorderRadius _radius = BorderRadius.vertical(
    top: Radius.circular(SnapPanel.cornerRadius),
  );

  /// 布局之前还不知道档位高度：按初始档位给出不透明度，首帧不闪。
  double _bodyOpacity() {
    final controller = widget.controller;
    final collapsed = controller.extentOf(SnapPanelStop.collapsed);
    final expanded = controller.extentOf(SnapPanelStop.expanded);
    if (expanded <= 0) {
      return controller.stop == SnapPanelStop.collapsed ? 0 : 1;
    }
    return ((controller.layoutExtent - collapsed) / SnapPanel.bodyFadeExtent)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    controller.snapDuration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    final scheme = Theme.of(context).colorScheme;
    final headerExtent =
        SnapPanel.handleExtent + widget.header.preferredSize.height;

    final panel = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: _radius,
        boxShadow: AppEffects.softShadow(scheme),
      ),
      // 墨水效果画在最近的 Material 上：面板自己提供，否则标签与选项的水波纹
      // 会被画到页面底层、被面板底色盖住。面板与预览同为页面底色，暗色下阴影
      // 几乎看不出，顶边再加一道与卡片相同的微边框。
      child: Material(
        color: ExpressiveSurfaces.pageBackground(scheme),
        shape: RoundedRectangleBorder(
          borderRadius: _radius,
          side: ExpressiveSurfaces.cardBorderSide(scheme),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SnapPanel._bleed,
            0,
            SnapPanel._bleed,
            SnapPanel._bleed,
          ),
          child: Column(
            children: <Widget>[
              // 读屏经拖动条的“调大/调小”换档；拖动手势不再映射成整片表头的
              // 滚动动作，否则标签栏会被读成可滚动区域。
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onVerticalDragStart: (_) => controller.beginDrag(),
                onVerticalDragUpdate: (DragUpdateDetails details) =>
                    controller.dragBy(details.primaryDelta ?? details.delta.dy),
                onVerticalDragEnd: (DragEndDetails details) =>
                    controller.endDrag(details.primaryVelocity ?? 0),
                onVerticalDragCancel: () => controller.endDrag(0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _SnapPanelHandle(
                      controller: controller,
                      label: widget.handleLabel,
                      stopLabel: widget.stopLabel,
                    ),
                    // 按声明的高度排版，与最低档的高度计算一致。
                    SizedBox(
                      height: widget.header.preferredSize.height,
                      child: widget.header,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (BuildContext context, Widget? child) =>
                      Opacity(opacity: _bodyOpacity(), child: child),
                  child: widget.body,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return ClipRect(
      child: CustomMultiChildLayout(
        delegate: _SnapPanelLayout(
          controller: controller,
          headerExtent: headerExtent,
          bottomInset: MediaQuery.paddingOf(context).bottom,
          halfExtent: widget.halfExtent,
        ),
        children: <Widget>[
          LayoutId(id: _SnapPanelSlot.background, child: widget.background),
          LayoutId(id: _SnapPanelSlot.panel, child: panel),
        ],
      ),
    );
  }
}

/// 拖动条：32×4 的胶囊（与底部面板同色），点按切换档位；读屏把它当作可调节
/// 控件，值为当前档位。
class _SnapPanelHandle extends StatelessWidget {
  const _SnapPanelHandle({
    required this.controller,
    required this.label,
    required this.stopLabel,
  });

  final SnapPanelController controller;
  final String label;
  final String Function(SnapPanelStop stop) stopLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        theme.bottomSheetTheme.dragHandleColor ??
        theme.colorScheme.onSurfaceVariant;
    return ValueListenableBuilder<SnapPanelStop>(
      valueListenable: controller.stopListenable,
      builder: (BuildContext context, SnapPanelStop stop, Widget? child) {
        const stops = SnapPanelStop.values;
        final canRaise = stop.index + 1 < stops.length;
        final canLower = stop.index > 0;
        return Semantics(
          container: true,
          label: label,
          value: stopLabel(stop),
          increasedValue: canRaise ? stopLabel(stops[stop.index + 1]) : null,
          decreasedValue: canLower ? stopLabel(stops[stop.index - 1]) : null,
          onIncrease: canRaise ? () => controller.step(up: true) : null,
          onDecrease: canLower ? () => controller.step(up: false) : null,
          onTap: controller.cycle,
          child: child,
        );
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: controller.cycle,
        child: SizedBox(
          height: SnapPanel.handleExtent,
          child: Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _SnapPanelSlot { background, panel }

/// 按面板位置排布背景与面板；随控制器变化只重新布局。布局时把三档高度同步给
/// 控制器（区域高度只有这时才确定）。
class _SnapPanelLayout extends MultiChildLayoutDelegate {
  _SnapPanelLayout({
    required this.controller,
    required this.headerExtent,
    required this.bottomInset,
    required this.halfExtent,
  }) : super(relayout: controller);

  final SnapPanelController controller;
  final double headerExtent;
  final double bottomInset;
  final double halfExtent;

  @override
  void performLayout(Size size) {
    final height = size.height;
    controller.syncStops(
      collapsed: math.min(headerExtent + bottomInset, height),
      half: halfExtent,
      expanded: height,
    );
    final extent = controller.layoutExtent;
    final top = height - extent;
    layoutChild(
      _SnapPanelSlot.background,
      BoxConstraints.tightFor(
        width: size.width,
        height: math.min(height, top + SnapPanel.cornerRadius),
      ),
    );
    positionChild(_SnapPanelSlot.background, Offset.zero);
    // 区域比表头还矮时（横屏 + 键盘等）面板仍按表头高度排版，超出部分被裁掉，
    // 不会溢出。
    const bleed = SnapPanel._bleed;
    layoutChild(
      _SnapPanelSlot.panel,
      BoxConstraints.tightFor(
        width: size.width + bleed * 2,
        height: math.max(extent, headerExtent) + bleed,
      ),
    );
    positionChild(_SnapPanelSlot.panel, Offset(-bleed, top));
  }

  @override
  bool shouldRelayout(_SnapPanelLayout oldDelegate) {
    return oldDelegate.controller != controller ||
        oldDelegate.headerExtent != headerExtent ||
        oldDelegate.bottomInset != bottomInset ||
        oldDelegate.halfExtent != halfExtent;
  }
}
