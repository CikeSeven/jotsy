// 对话页底部的输入栏（DESIGN §5.29“输入栏”）：一张 28 圆角的卡片，上面是
// 多行输入框（1–6 行、普通文字键盘），下面一排可横向滚动的胶囊（范围、
// 人设、模型 · 思考）与右侧固定的 40dp 圆形发送 / 停止按钮。
//
// - 底色与描边取 `AppGlassField`（玻璃时半透明 + 玻璃描边，经典时
//   `surfaceContainerHigh`）；聚焦时描边经 `ExpressiveStateBlend` 补间到
//   `primary` 的 0.5 不透明度。
// - 发送按钮在没有文字时禁用（颜色补间），生成中换成描边“停止”（交叉
//   淡入）；发送 / 停止算作输入框的一部分（`TextFieldTapRegion`），点了不
//   收键盘。桌面 Enter 发送、Shift + Enter 换行。
// - 胶囊：跟随默认时为细描边透明底，改过（范围不是自动、换了人设 / 模型 /
//   思考强度）时为 `secondaryContainer` 底，一眼看出这段对话的特别设置。
//
// 只随宽度重建（调用方放在 `WidthLayoutBuilder` 里，键盘升降不逐帧重建）。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../core/services/app_platform.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/widgets/app_glass_field.dart';
import '../../../widgets/desktop_horizontal_scroll.dart';
import '../../../widgets/expressive_state_blend.dart';
import '../../../widgets/text_selection_menu/app_text_context_menu.dart';

class AiChatComposer extends StatefulWidget {
  const AiChatComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.side,
    required this.busy,
    required this.enabled,
    required this.onSend,
    required this.onStop,
    required this.chips,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// 左右留白（与消息列同宽）。
  final double side;
  final bool busy;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final List<Widget> chips;

  @override
  State<AiChatComposer> createState() => _AiChatComposerState();
}

class _AiChatComposerState extends State<AiChatComposer> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(AiChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final glass = AppGlassField.of(context);
    final fill = glass?.fill ?? colors.surfaceContainerHigh;
    final idle =
        glass?.border?.color ?? colors.outlineVariant.withValues(alpha: 0.5);
    Widget field = TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      minLines: 1,
      maxLines: 6,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: l10n.aiChatInputHint,
        filled: false,
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
      ),
      contextMenuBuilder: appTextContextMenuBuilder,
    );
    if (AppPlatform.isDesktop) {
      field = CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.enter): widget.onSend,
          const SingleActivator(LogicalKeyboardKey.numpadEnter): widget.onSend,
        },
        child: field,
      );
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(widget.side, 4, widget.side, 10),
        child: ExpressiveStateBlend(
          active: widget.focusNode.hasFocus,
          builder: (context, t, _) => DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Color.lerp(
                  idle,
                  colors.primary.withValues(alpha: 0.5),
                  t,
                )!,
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                field,
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: DesktopHorizontalScroll(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: <Widget>[
                                for (final (index, chip)
                                    in widget.chips.indexed) ...<Widget>[
                                  if (index > 0) const SizedBox(width: 6),
                                  chip,
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextFieldTapRegion(
                        child: _SendButton(
                          controller: widget.controller,
                          busy: widget.busy,
                          enabled: widget.enabled,
                          onSend: widget.onSend,
                          onStop: widget.onStop,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.controller,
    required this.busy,
    required this.enabled,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool busy;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnimatedSwitcher(
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: Tween<double>(begin: 0.8, end: 1).animate(animation),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: busy
          ? IconButton.outlined(
              key: const ValueKey<String>('stop'),
              tooltip: l10n.aiPanelStop,
              onPressed: onStop,
              icon: const FaIcon(FontAwesomeIcons.stop, size: 14),
            )
          : ListenableBuilder(
              key: const ValueKey<String>('send'),
              listenable: controller,
              builder: (context, _) => IconButton.filled(
                tooltip: l10n.aiPanelSend,
                onPressed: enabled && controller.text.trim().isNotEmpty
                    ? onSend
                    : null,
                icon: const FaIcon(FontAwesomeIcons.arrowUp, size: 16),
              ),
            ),
    );
  }
}

/// 输入栏里的一枚胶囊。[custom] 时为 `secondaryContainer` 底（改过的设置）。
class AiComposerChip extends StatelessWidget {
  const AiComposerChip({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.emoji,
    this.custom = false,
    this.tooltip,
  });

  final String label;
  final VoidCallback? onPressed;
  final FaIconData? icon;
  final String? emoji;
  final bool custom;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = custom
        ? colors.onSecondaryContainer
        : colors.onSurfaceVariant;
    final chip = Material(
      color: custom ? colors.secondaryContainer : Colors.transparent,
      shape: StadiumBorder(
        side: custom
            ? BorderSide.none
            : BorderSide(color: colors.outlineVariant, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (emoji != null)
                Text(emoji!, style: const TextStyle(fontSize: 13))
              else if (icon != null)
                FaIcon(icon, size: 12, color: foreground),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: onPressed == null
                        ? foreground.withValues(alpha: 0.5)
                        : foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip!, child: chip);
  }
}
