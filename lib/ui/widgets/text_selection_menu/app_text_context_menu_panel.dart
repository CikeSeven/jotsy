import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/expressive_motion.dart';
import '../expressive_menu/expressive_menu_item.dart';
import '../expressive_menu/expressive_menu_layout.dart';
import '../expressive_menu/expressive_menu_motion.dart';
import '../expressive_menu/expressive_menu_panel.dart';
import '../expressive_menu/expressive_menu_surface.dart';
import '../expressive_menu/expressive_submenu.dart';
import 'app_text_menu_action.dart';

/// 桌面上的文字右键菜单：玻璃竖排菜单，左上角贴着指针。
///
/// - 输入：指针位置 [anchor]（全局坐标；覆盖层从屏幕原点开始，同手机胶囊）、
///   菜单项 [actions]、关闭回调 [onDismiss]。
/// - 输出：铺满覆盖层的盒子，菜单经 [ExpressiveMenuCascade] 定位：指针为
///   起始角，下方放不下翻到上方，右侧放不下左移，夹进安全区（左右留 8）。
/// - 副作用：挂载期间登记一个早期按键处理器（见下），卸载时撤掉。
///
/// 外观与动效同 §5.4 的弹出菜单：玻璃 [ExpressiveMenuGlass] + 面板
/// [ExpressiveMenuPanel]（宽度取内容固有宽、最小 200，这里最大 320），每行是
/// [ExpressiveMenuItem]（没有锚点时它直接执行动作），行尾为快捷键提示。按
/// [AppTextMenuSlot] 分成三组（lead → primary → secondary），组间为
/// [ExpressiveMenuDivider]。从指针处 28 的小圆长成面板（[ExpressiveMenuMotion]
/// 的容器变换）；减少动画时瞬时。
///
/// 键盘：↑/↓ 移动高亮、Enter 执行高亮项、Esc 调 [onDismiss]。为什么不把焦点
/// 移进菜单：输入框（与正文）失去焦点就会拆掉自己的选区浮层，菜单也跟着没了。
/// 所以焦点留在输入框，菜单经 `FocusManager.addEarlyKeyEventHandler` 在按键
/// 分发给焦点之前拦下这几个键（返回 handled，Esc 不会落到页面上），高亮用
/// 与聚焦相同的高亮色块画出来（[ExpressiveMenuItem.highlighted]）。其余按键
/// 照常交给输入框。
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

  @override
  State<AppTextContextMenuPanel> createState() =>
      _AppTextContextMenuPanelState();
}

class _AppTextContextMenuPanelState extends State<AppTextContextMenuPanel>
    with TickerProviderStateMixin {
  late final ExpressiveMenuMotion _motion = ExpressiveMenuMotion(
    vsync: this,
    // 滚动条只在展开完成后显示，缩放过程中不闪现。
    onStatusChanged: (_) {
      if (mounted) setState(() {});
    },
  );
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
    if (ExpressiveMotion.reduceMotion(context)) {
      if (_motion.status != AnimationStatus.completed) _motion.snapOpen();
    } else if (!_started) {
      _motion.open();
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
    _motion.dispose();
    _scroll.dispose();
    super.dispose();
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
            final colors = Theme.of(context).colorScheme;
            final anchor = Rect.fromLTWH(
              widget.anchor.dx,
              widget.anchor.dy,
              0,
              0,
            );
            return ExpressiveMenuCascade(
              anchor: anchor,
              bounds: ExpressiveMenuArea.of(
                context,
                constraints.biggest,
                anchor,
              ).bounds,
              cover: false,
              placement: ExpressiveMenuPlacement.start,
              textDirection: Directionality.of(context),
              motion: _motion,
              shadowColor: ExpressiveMenuSurface.ringShadowOf(colors),
              borderColor: ExpressiveMenuSurface.borderOf(colors),
              children: <Widget>[
                ExpressiveMenuGlass(motion: _motion),
                ExpressiveMenuPanel(
                  scrollController: _scroll,
                  jelly: _motion.primaryJelly,
                  ready: () => _motion.dragSelectReadyNow,
                  showScrollbar: _motion.status == AnimationStatus.completed,
                  maxWidth: AppTextContextMenuPanel.maxWidth,
                  children: _rows(context),
                ),
              ],
            );
          },
        );

  List<Widget> _rows(BuildContext context) {
    final theme = Theme.of(context);
    final shortcutStyle = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final ordered = _ordered;
    final rows = <Widget>[];
    AppTextMenuSlot? previous;
    for (final (index, action) in ordered.indexed) {
      if (previous != null && previous != action.slot) {
        rows.add(const ExpressiveMenuDivider());
      }
      previous = action.slot;
      final shortcut = action.shortcut;
      rows.add(
        ExpressiveMenuItem(
          onPressed: action.onPressed,
          highlighted: index == _highlighted,
          leadingIcon: FaIcon(action.icon),
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
