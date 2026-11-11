import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'expressive_menu_selection.dart';

/// 菜单行的尺寸。结构移植自 NexioSchedule 的 DropdownImpl /
/// LiquidGlassDropdownMenuItem，数值按用户反馈（原值“太大了”）整体收小：
/// 行高 45 → 40、字号 15.6 → 14.5。
abstract final class ExpressiveMenuRowMetrics {
  /// 行的胶囊离面板左右边缘的距离（高亮胶囊同样缩进）。
  ///
  /// 必须与 [panelPadding] 相等：二级菜单的标题行从触发行的胶囊往外各扩这么多
  /// 就是面板的左上角（见 ExpressiveMenuCascade 的二级面板形变）。面板圆角减去
  /// 它就是胶囊圆角（同心）。
  static const double inset = 6;

  /// 面板上下的留白（首行之上、末行之下）。
  static const double panelPadding = 6;

  /// 胶囊里的左右、上下内边距。
  static const double horizontalPadding = 12;
  static const double verticalPadding = 9;

  /// 前置图标格的宽度、到文字的间距与图标大小。
  static const double iconBox = 22;
  static const double iconGap = 10;
  static const double iconSize = 16;

  /// 选择菜单行尾对勾（或 ›、自定义尾随控件）前的间距与对勾格边长。
  static const double trailingGap = 10;
  static const double checkCell = 18;
  static const double checkSize = 14;

  /// 二级菜单入口行尾 › 的格子（9 × 14）。
  static const Size chevronCell = Size(9, 14);

  /// 图标 + 文字那一段的最大宽度。
  static const double maxTextWidth = 216;

  /// 标题字号与行高（14.5sp 中等字重）。
  static const double titleSize = 14.5;
  static const double titleHeight = 1.3;
}

/// 菜单行的交互层：把这一行登记到所在面板的 [ExpressiveMenuSelection]（由
/// 面板统一处理点按、跟手滑选与高亮胶囊），并提供键盘与读屏的入口。
///
/// - 行左右缩进 [ExpressiveMenuRowMetrics.inset]，胶囊就是缩进后的那块。
/// - 点按不在行上处理：面板的手势层按下即亮、松手执行；行上只留读屏的点按
///   动作与 Enter / 空格（ActivateIntent）。悬停与键盘聚焦报给面板，用同一块
///   胶囊高亮。不在面板里时（单独使用）退回普通的点按。
/// - 语义：一个按钮节点（合并行内文字），带选中 / 展开状态。
class ExpressiveMenuRowInk extends StatefulWidget {
  const ExpressiveMenuRowInk({
    super.key,
    required this.onTap,
    required this.child,
    this.focusNode,
    this.highlighted = false,
    this.selected,
    this.expanded,
  });

  /// 为 null 时整行禁用（不参与命中、不可聚焦）。
  final VoidCallback? onTap;
  final Widget child;
  final FocusNode? focusNode;

  /// 外部指定的高亮（如桌面文字右键菜单的方向键高亮）。
  final bool highlighted;
  final bool? selected;
  final bool? expanded;

  @override
  State<ExpressiveMenuRowInk> createState() => _ExpressiveMenuRowInkState();
}

class _ExpressiveMenuRowInkState extends State<ExpressiveMenuRowInk> {
  final ExpressiveMenuRowHandle _handle = ExpressiveMenuRowHandle();
  ExpressiveMenuSelection? _selection;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final selection = ExpressiveMenuSelectionScope.maybeOf(context);
    if (identical(selection, _selection)) return;
    _selection?.unregister(_handle);
    _selection = selection;
    selection?.register(_handle);
    _syncHighlight();
  }

  @override
  void didUpdateWidget(ExpressiveMenuRowInk oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlighted != widget.highlighted) _syncHighlight();
  }

  void _syncHighlight() {
    final selection = _selection;
    if (selection == null) return;
    // 登记与高亮都在构建期发生，胶囊的过渡要等这一帧布局完才能取到位置。
    final highlighted = widget.highlighted;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(selection, _selection)) {
        selection.setHighlighted(_handle, highlighted);
      }
    });
  }

  @override
  void dispose() {
    _selection?.unregister(_handle);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    final enabled = onTap != null;
    _handle
      ..enabled = enabled
      ..activate = onTap;
    final selection = _selection;
    Widget row = _RowBox(
      handle: _handle,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ExpressiveMenuRowMetrics.inset,
        ),
        child: widget.child,
      ),
    );
    if (selection == null) {
      row = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: row,
      );
    }
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: widget.selected,
        expanded: widget.expanded,
        onTap: selection == null ? null : onTap,
        child: FocusableActionDetector(
          focusNode: widget.focusNode,
          enabled: enabled,
          mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (ActivateIntent intent) {
                onTap?.call();
                return null;
              },
            ),
          },
          onShowHoverHighlight: (bool value) =>
              selection?.setHovered(_handle, value),
          onShowFocusHighlight: (bool value) =>
              selection?.setFocused(_handle, value),
          child: row,
        ),
      ),
    );
  }
}

/// 把行的 render box 交给登记项，面板据此取行的位置。
class _RowBox extends SingleChildRenderObjectWidget {
  const _RowBox({required this.handle, super.child});

  final ExpressiveMenuRowHandle handle;

  @override
  _RenderRowBox createRenderObject(BuildContext context) =>
      _RenderRowBox(handle);

  @override
  void updateRenderObject(BuildContext context, _RenderRowBox renderObject) {
    renderObject.handle = handle;
  }
}

class _RenderRowBox extends RenderProxyBox {
  _RenderRowBox(this._handle);

  ExpressiveMenuRowHandle _handle;
  set handle(ExpressiveMenuRowHandle value) {
    if (identical(value, _handle)) return;
    if (identical(_handle.box, this)) _handle.box = null;
    _handle = value;
    if (attached) _handle.box = this;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _handle.box = this;
  }

  @override
  void detach() {
    if (identical(_handle.box, this)) _handle.box = null;
    super.detach();
  }
}
