import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'expressive_menu_anchor.dart';
import 'expressive_menu_item.dart';

/// 打开二级菜单的一项：行尾带 ›，点按后菜单在原地换成 [menuChildren]
/// （顶部是“‹ 标题”返回行），而不是在旁边再弹一块面板。
///
/// 为什么原地下钻而不是向侧面级联：菜单多从顶栏行尾的 ⋮ 打开，贴着屏幕的
/// 结束边，侧面没有放第二块面板的地方，手机上级联只会盖住上一级。
///
/// [menuChildren] 在点按时取定、放进锚点的下钻栈：二级菜单显示期间外面重建
/// 不会刷新它。要随选择即时变化的内容（保持菜单打开的单选项的对勾）应放进
/// 自己维护选中态的子组件里。
class ExpressiveSubmenuItem extends StatelessWidget {
  const ExpressiveSubmenuItem({
    super.key,
    required this.child,
    required this.menuChildren,
    this.leadingIcon,
  });

  /// 条目文字；二级菜单顶部的返回行也用它作标题。
  final Widget child;

  /// 前置图标，与 [ExpressiveMenuItem.leadingIcon] 相同。
  final Widget? leadingIcon;

  /// 二级菜单的内容，通常是若干 [ExpressiveMenuItem]。
  final List<Widget> menuChildren;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return ExpressiveMenuItem(
      closeOnActivate: false,
      leadingIcon: leadingIcon,
      // 行尾 › 只是“还有下一级”的提示，取次要色，不与主色的前置图标抢眼。
      trailingIcon: ExcludeSemantics(
        child: FaIcon(
          rtl ? FontAwesomeIcons.angleLeft : FontAwesomeIcons.angleRight,
          size: ExpressiveMenuItem.checkSize,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      onPressed: () =>
          ExpressiveMenuAnchorState.maybeOf(context)?.openSubmenu(this),
      child: child,
    );
  }
}

/// 二级菜单顶部的返回行：‹ + 加粗标题，点按回到上一级；读屏读作“返回，标题”。
class ExpressiveSubmenuHeader extends StatelessWidget {
  const ExpressiveSubmenuHeader({
    super.key,
    required this.title,
    required this.onBack,
  });

  final Widget title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return ExpressiveMenuItem(
      closeOnActivate: false,
      leadingIcon: FaIcon(
        rtl ? FontAwesomeIcons.angleRight : FontAwesomeIcons.angleLeft,
      ),
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll<TextStyle?>(
          theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      onPressed: onBack,
      child: Semantics(
        label: MaterialLocalizations.of(context).backButtonTooltip,
        child: title,
      ),
    );
  }
}

/// 菜单里分组之间的细线：`outlineVariant` 1dp，左右缩进 12、上下各留 4。
class ExpressiveMenuDivider extends StatelessWidget {
  const ExpressiveMenuDivider({super.key});

  static const double inset = 12;
  static const double spacing = 4;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: inset, vertical: spacing),
    child: Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).colorScheme.outlineVariant,
    ),
  );
}

/// 锚点的下钻栈：当前显示的各级二级菜单，以及它们在所在路由登记的返回历史。
///
/// 每进一层登记一条 [LocalHistoryEntry]：系统返回 / 预测式返回先退一层，退回
/// 根菜单后才轮到锚点自己的那条历史关闭菜单（局部历史按后进先出弹出）。
class ExpressiveSubmenuStack {
  ExpressiveSubmenuStack({required this.onPoppedByRoute});

  /// 被系统返回退掉一层后调用；经 [pop] 主动退出时不调用。
  final VoidCallback onPoppedByRoute;

  final List<_SubmenuLevel> _levels = <_SubmenuLevel>[];

  /// 栈顶的二级菜单；null 为根菜单。
  ExpressiveSubmenuItem? get current =>
      _levels.isEmpty ? null : _levels.last.item;

  bool get isEmpty => _levels.isEmpty;

  void push(ExpressiveSubmenuItem item, ModalRoute<Object?>? route) {
    final level = _SubmenuLevel(item);
    _levels.add(level);
    _register(level, route);
  }

  /// 收起途中又被重新展开：页面还是收起前的那一级，按层补回返回历史（锚点
  /// 自己的那条已先补上，顺序仍是根菜单在最底下）。
  void restoreHistory(ModalRoute<Object?>? route) {
    for (final level in _levels) {
      if (level.entry == null) _register(level, route);
    }
  }

  void _register(_SubmenuLevel level, ModalRoute<Object?>? route) {
    if (route == null) return;
    late final LocalHistoryEntry entry;
    entry = LocalHistoryEntry(
      // 不让 AppBar 因此把返回键换成关闭键。
      impliesAppBarDismissal: false,
      onRemove: () {
        // 主动退出或撤销历史时已先解除关联；只有被返回弹出时才退一层。
        if (level.entry != entry || !_levels.contains(level)) return;
        level.entry = null;
        _levels.remove(level);
        onPoppedByRoute();
      },
    );
    level.entry = entry;
    route.addLocalHistoryEntry(entry);
  }

  /// 退回上一级。
  void pop() {
    if (_levels.isEmpty) return;
    final level = _levels.removeLast();
    final entry = level.entry;
    level.entry = null;
    entry?.remove();
  }

  /// 撤掉全部返回历史、页面保留：菜单开始收起时调用，收起动画里内容不换，
  /// 动画中的返回手势作用于页面本身。
  void releaseHistory() {
    for (final level in _levels) {
      final entry = level.entry;
      level.entry = null;
      entry?.remove();
    }
  }

  /// 回到根菜单（浮层移除后、下次重新展开前调用）。
  void clear() {
    releaseHistory();
    _levels.clear();
  }
}

class _SubmenuLevel {
  _SubmenuLevel(this.item);

  final ExpressiveSubmenuItem item;
  LocalHistoryEntry? entry;
}
