import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/expressive_motion.dart';
import '../expressive_menu/expressive_menu_item.dart';
import '../expressive_menu/expressive_menu_layout.dart';
import '../expressive_menu/expressive_menu_panel.dart';
import 'app_text_menu_action.dart';

/// 桌面上的文字右键菜单：玻璃竖排菜单，左上角贴着指针。
///
/// - 输入：指针位置 [anchor]（全局坐标；覆盖层从屏幕原点开始，同手机胶囊）、
///   菜单项 [actions]、关闭回调 [onDismiss]。
/// - 输出：铺满覆盖层的盒子，菜单经 [ExpressiveMenuPosition] 定位：指针为
///   起始角，下方放不下翻到上方，右侧放不下左移，夹进安全区留 8。
/// - 副作用：挂载期间登记一个早期按键处理器（见下），卸载时撤掉。
///
/// 外观同 §5.4 的弹出菜单：表面与内边距 8 复用 [ExpressiveMenuPanel]（宽度取
/// 内容固有宽、最小 176，这里最大 320），每行是 [ExpressiveMenuItem]（没有
/// 锚点时它直接执行动作），行尾为快捷键提示。按 [AppTextMenuSlot] 分成三组
/// （lead → primary → secondary），组间 1dp 分隔线。展开 0.96→1 缩放，从起始角
/// 开始（`fast` / `effects`），减少动画时瞬时。
///
/// 键盘：↑/↓ 移动高亮、Enter 执行高亮项、Esc 调 [onDismiss]。为什么不把焦点
/// 移进菜单：输入框（与正文）失去焦点就会拆掉自己的选区浮层，菜单也跟着没了。
/// 所以焦点留在输入框，菜单经 `FocusManager.addEarlyKeyEventHandler` 在按键
/// 分发给焦点之前拦下这几个键（返回 handled，Esc 不会落到页面上），高亮用
/// 与聚焦相同的 primary 12% 叠色画出来。其余按键照常交给输入框。
///
/// 点外部关闭不由它负责：输入框的选区浮层自己处理，日记正文由调用方处理。
class AppTextContextMenuPanel extends StatefulWidget {
  const AppTextContextMenuPanel({
    super.key,
    required this.anchor,
    required this.actions,
    required this.onDismiss,
  });

  final Offset anchor;
  final List<AppTextMenuAction> actions;
  final VoidCallback onDismiss;

  static const double maxWidth = 320;

  /// 分隔线上下的留白。
  static const double dividerGap = 4;

  @override
  State<AppTextContextMenuPanel> createState() =>
      _AppTextContextMenuPanelState();
}

class _AppTextContextMenuPanelState extends State<AppTextContextMenuPanel>
    with SingleTickerProviderStateMixin {
  static const double _openScale = 0.96;

  /// 前置图标的固定槽宽（略大于 16px 图标里最宽的字形）。
  static const double _iconSlotWidth = 20;

  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: ExpressiveMotion.fast,
  )..addStatusListener(_statusChanged);
  late final CurvedAnimation _progress = CurvedAnimation(
    parent: _reveal,
    curve: ExpressiveMotion.effects,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: _openScale,
    end: 1,
  ).animate(_progress);
  final ScrollController _scroll = ScrollController();
  bool _started = false;

  /// 键盘高亮的项在 [_ordered] 里的下标，-1 表示没有。
  int _highlighted = -1;

  /// 按显示顺序排好的菜单项（lead → primary → secondary，组内保持原顺序）。
  List<AppTextMenuAction> get _ordered => <AppTextMenuAction>[
    for (final slot in AppTextMenuSlot.values)
      ...widget.actions.where((AppTextMenuAction a) => a.slot == slot),
  ];

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addEarlyKeyEventHandler(_handleKey);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reveal.duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.fast,
    );
    if (ExpressiveMotion.reduceMotion(context)) {
      _reveal.value = 1;
    } else if (!_started) {
      _reveal.forward();
    }
    _started = true;
  }

  @override
  void didUpdateWidget(AppTextContextMenuPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_highlighted >= widget.actions.length) _highlighted = -1;
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_handleKey);
    _progress.dispose();
    _reveal.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _statusChanged(AnimationStatus status) {
    // 滚动条只在展开完成后显示，缩放过程中不闪现。
    if (mounted) setState(() {});
  }

  KeyEventResult _handleKey(KeyEvent event) {
    if (event is KeyUpEvent || !mounted) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final count = _ordered.length;
    if (key == LogicalKeyboardKey.escape) {
      widget.onDismiss();
      return KeyEventResult.handled;
    }
    if (count == 0) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.arrowDown) {
      // 还没有高亮时 ↓ 落在第一项、↑ 落在最后一项，与弹出菜单一致。
      setState(() => _highlighted = (_highlighted + 1) % count);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(
        () => _highlighted = _highlighted <= 0 ? count - 1 : _highlighted - 1,
      );
      return KeyEventResult.handled;
    }
    if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) &&
        _highlighted >= 0 &&
        event is KeyDownEvent) {
      _ordered[_highlighted].onPressed();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => widget.actions.isEmpty
      ? const SizedBox.shrink()
      : LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // 系统栏与键盘取自视图本身，理由同 ExpressiveMenuArea。
            final view = MediaQueryData.fromView(View.of(context));
            final bounds = view.padding
                .deflateRect(
                  view.viewInsets.deflateRect(
                    Offset.zero & constraints.biggest,
                  ),
                )
                .deflate(ExpressiveMenuArea.screenMargin);
            return ExpressiveMenuPosition(
              anchor: Rect.fromLTWH(widget.anchor.dx, widget.anchor.dy, 0, 0),
              bounds: bounds,
              placement: ExpressiveMenuPlacement.start,
              textDirection: Directionality.of(context),
              scale: _scale,
              gap: 0,
              child: ExpressiveMenuPanel(
                reveal: _progress,
                scrollController: _scroll,
                showScrollbar: _reveal.status == AnimationStatus.completed,
                maxWidth: math.max(
                  0,
                  math.min(AppTextContextMenuPanel.maxWidth, bounds.width),
                ),
                children: _rows(context),
              ),
            );
          },
        );

  List<Widget> _rows(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final shortcutStyle = theme.textTheme.labelMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final highlight = ButtonStyle(
      backgroundColor: WidgetStatePropertyAll<Color>(
        colors.primary.withValues(alpha: 0.12),
      ),
    );
    final ordered = _ordered;
    final rows = <Widget>[];
    AppTextMenuSlot? previous;
    for (final (index, action) in ordered.indexed) {
      if (previous != null && previous != action.slot) {
        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppTextContextMenuPanel.dividerGap,
            ),
            child: Divider(
              height: 1,
              thickness: 1,
              color: colors.outlineVariant,
            ),
          ),
        );
      }
      previous = action.slot;
      final shortcut = action.shortcut;
      rows.add(
        ExpressiveMenuItem(
          onPressed: action.onPressed,
          style: index == _highlighted ? highlight : null,
          // FontAwesome 各字形宽度不同（剪刀比复制宽），固定图标槽宽，
          // 各行文字才从同一竖线起排。
          leadingIcon: SizedBox(
            width: _iconSlotWidth,
            child: Center(child: FaIcon(action.icon)),
          ),
          trailingIcon: shortcut == null
              ? null
              : Text(shortcut, style: shortcutStyle),
          child: Text(
            action.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    return rows;
  }
}
