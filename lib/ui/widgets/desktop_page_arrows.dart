// 桌面上翻页类页面（预览页左右翻日记、看图页左右切图）的鼠标与键盘入口。
//
// 职责：
// - [DesktopPageArrows]：指针悬停在页面上时，左右边缘淡入“上一个 / 下一个”
//   圆形按钮；没有上一个 / 下一个时不显示对应一侧。只是叠在页面上的按钮，
//   不加任何拖动识别器或滚动容器（翻页手势仍归页面自己的 PageView）。
// - [DesktopPageKeys]：←/→（与 PageUp/PageDown）翻页、Esc 走返回。
//
// 两者都只在桌面（[AppPlatform.isDesktop]）生效，手机上原样返回 child，
// 触屏的交互与改版前一致。没有副作用，翻页与返回都交给调用方的回调。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../app/theme/expressive_motion.dart';
import '../../core/services/app_platform.dart';
import '../app_surface/widgets/app_glass_field.dart';

/// 指针悬停时在 [child] 左右边缘淡入的翻页按钮（只在桌面）。
///
/// [onPrevious] / [onNext] 为 null 时不显示那一侧（已在一端，或页面暂时不能
/// 翻页）。按钮在指针移出页面后淡出；淡出期间与隐藏时不接收点按。
class DesktopPageArrows extends StatefulWidget {
  const DesktopPageArrows({
    super.key,
    required this.child,
    required this.previousTooltip,
    required this.nextTooltip,
    this.onPrevious,
    this.onNext,
  });

  final Widget child;
  final String previousTooltip;
  final String nextTooltip;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  /// 按钮直径。
  static const double size = 44;

  /// 按钮离页面左右边缘的距离。
  static const double edgeInset = 16;

  @override
  State<DesktopPageArrows> createState() => _DesktopPageArrowsState();
}

class _DesktopPageArrowsState extends State<DesktopPageArrows> {
  bool _hovering = false;

  void _setHovering(bool hovering) {
    if (hovering != _hovering) setState(() => _hovering = hovering);
  }

  @override
  Widget build(BuildContext context) {
    if (!AppPlatform.isDesktop) {
      return widget.child;
    }
    // 结构恒定：两侧按钮始终在树里，只切不透明度与是否接收点按，悬停进出时
    // 页面本身不会重新挂载。
    return MouseRegion(
      onEnter: (_) => _setHovering(true),
      onExit: (_) => _setHovering(false),
      // 页面内的移动也算悬停：路由刚推入时指针已在页面上，收不到 onEnter。
      onHover: (_) => _setHovering(true),
      child: Stack(
        children: <Widget>[
          Positioned.fill(child: widget.child),
          _arrow(
            key: const ValueKey<String>('desktop-page-previous'),
            alignment: AlignmentDirectional.centerStart,
            icon: FontAwesomeIcons.angleLeft,
            tooltip: widget.previousTooltip,
            onPressed: widget.onPrevious,
          ),
          _arrow(
            key: const ValueKey<String>('desktop-page-next'),
            alignment: AlignmentDirectional.centerEnd,
            icon: FontAwesomeIcons.angleRight,
            tooltip: widget.nextTooltip,
            onPressed: widget.onNext,
          ),
        ],
      ),
    );
  }

  Widget _arrow({
    required Key key,
    required AlignmentDirectional alignment,
    required FaIconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    final visible = _hovering && onPressed != null;
    return Positioned.fill(
      key: key,
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesktopPageArrows.edgeInset,
          ),
          child: IgnorePointer(
            ignoring: !visible,
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: ExpressiveMotion.duration(
                context,
                ExpressiveMotion.fast,
              ),
              curve: ExpressiveMotion.effects,
              child: _DesktopPageArrowButton(
                icon: icon,
                tooltip: tooltip,
                // 淡出时保留上一次的回调，按钮外观不会在淡出途中变成禁用态。
                onPressed: onPressed ?? () {},
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopPageArrowButton extends StatelessWidget {
  const _DesktopPageArrowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final FaIconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // “控件”为玻璃时换成玻璃底色 + 描边；不模糊（按钮在 AnimatedOpacity 里
    // 淡入淡出，模糊会在淡入时闪一块无模糊的底）。
    final glassField = AppGlassField.of(context);
    return SizedBox.square(
      dimension: DesktopPageArrows.size,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          // 叠在正文与图片上：略透出下面的内容，又足够不透明保证图标可读。
          backgroundColor:
              glassField?.fill ??
              scheme.surfaceContainerHigh.withValues(alpha: 0.92),
          foregroundColor: scheme.onSurface,
          side: glassField?.border,
          shape: const CircleBorder(),
          fixedSize: const Size.square(DesktopPageArrows.size),
          minimumSize: const Size.square(DesktopPageArrows.size),
        ),
        icon: FaIcon(icon, size: 18),
      ),
    );
  }
}

/// 桌面上的翻页与返回按键：←/PageUp 上一个、→/PageDown 下一个、Esc 返回。
///
/// 自带一个 autofocus 的焦点：页面里没有别的焦点时按键也能送到这里；正文
/// 等子级拿到焦点时按键先交给子级，子级不处理的再冒泡上来。回调为 null 的
/// 按键不绑定（照常冒泡给外层）。不要嵌套使用：外层的焦点会挡住内层。
/// 页面上开着弹出菜单这类局部历史时，Esc 先关掉它（见 [_escape]）。
class DesktopPageKeys extends StatelessWidget {
  const DesktopPageKeys({
    super.key,
    required this.child,
    this.onPrevious,
    this.onNext,
    this.onEscape,
  });

  final Widget child;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onEscape;

  @override
  Widget build(BuildContext context) {
    if (!AppPlatform.isDesktop) {
      return child;
    }
    final onPrevious = this.onPrevious;
    final onNext = this.onNext;
    final onEscape = this.onEscape;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        if (onPrevious != null) ...<ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.arrowLeft): onPrevious,
          const SingleActivator(LogicalKeyboardKey.pageUp): onPrevious,
        },
        if (onNext != null) ...<ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.arrowRight): onNext,
          const SingleActivator(LogicalKeyboardKey.pageDown): onNext,
        },
        if (onEscape != null)
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              _escape(context, onEscape),
      },
      child: Focus(autofocus: true, child: child),
    );
  }

  /// 页面上还开着登记了局部历史的浮层（如 ExpressiveMenuAnchor 的弹出菜单，
  /// 焦点不在菜单里时它自己的 Esc 收不到）时，Esc 先弹出那条历史、关掉浮层，
  /// 与系统返回一致；否则才执行页面的返回。
  static void _escape(BuildContext context, VoidCallback onEscape) {
    if (ModalRoute.of(context)?.willHandlePopInternally ?? false) {
      Navigator.of(context).maybePop();
      return;
    }
    onEscape();
  }
}
