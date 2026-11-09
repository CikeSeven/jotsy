// 对话页底部的输入栏（DESIGN §5.29“输入栏”）：一张 28 圆角的卡片，自上而下
// 是附图缩略图（有图时）、说明行、这段对话改过的设置（范围、人设；只在
// 改过时出现）、多行输入框（1–6 行、普通文字键盘），最下一排是“＋”、
// “模型 · 思考”与右侧固定的 40dp 圆形发送 / 停止按钮。附图与“＋”菜单的
// 部件见 `ai_chat_composer_images.dart`。
//
// 为什么把范围与人设收进“＋”：以前三枚胶囊与附图、发送挤在同一排，手机上
// 要横向滑动才看得全，最常换的模型反而被挤到屏幕外。现在这一排不滚动——
// 不常动的范围、人设与附图一起收进“＋”菜单（每行行尾写着当前值），模型留
// 在外面、放不下时省略；改过的范围 / 人设以 `secondaryContainer` 胶囊显示
// 在输入框上方（点按再改，点 × 复原），一眼看出这段对话的特别设置。
//
// - 底色与描边取 `AppGlassField`（玻璃时半透明 + 玻璃描边，经典时
//   `surfaceContainerHigh`）；聚焦时描边经 `ExpressiveStateBlend` 补间到
//   `primary` 的 0.5 不透明度。
// - 发送按钮在既没有文字也没有图片、或图片还在复制时禁用（颜色补间），
//   生成中换成描边“停止”（交叉淡入）；“＋”、胶囊、模型与发送 / 停止都算作
//   输入框的一部分（`TextFieldTapRegion`），点了不收键盘。桌面 Enter 发送、
//   Shift + Enter 换行。
//
// 只随宽度重建（调用方放在 `WidthLayoutBuilder` 里，键盘升降不逐帧重建）。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../core/services/app_platform.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/widgets/app_glass_field.dart';
import '../../../diaries/controllers/diary_comment_images_controller.dart';
import '../../../widgets/expressive_state_blend.dart';
import '../../../widgets/text_selection_menu/app_text_context_menu.dart';
import 'ai_chat_composer_images.dart';

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
    this.contextChips = const <Widget>[],
    this.options = const <AiComposerOption>[],
    this.model,
    this.images,
    this.onPickImages,
    this.onTakePhoto,
    this.note,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// 左右留白（与消息列同宽）。
  final double side;
  final bool busy;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback onStop;

  /// 这段对话改过的设置（范围、人设），显示在输入框上方；没改过时为空，
  /// 这一行不占位置。
  final List<Widget> contextChips;

  /// “＋”菜单里附图之外的几行（范围、人设）。
  final List<AiComposerOption> options;

  /// “模型 · 思考”按钮（[AiComposerModelButton]）；null 时不放。
  final Widget? model;

  /// 这条消息的附图；null 时没有附图按钮。
  final DiaryCommentImagesController? images;
  final VoidCallback? onPickImages;

  /// 拍照；null 时没有“拍照”这一项。
  final VoidCallback? onTakePhoto;

  /// 缩略图下方的一行说明；null 时不显示。
  final Widget? note;

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
                if (widget.images case final images?)
                  AiComposerImageStrip(images: images),
                ?widget.note,
                // 改过的设置出现 / 消失时补间高度，输入框不跳一下。
                AnimatedSize(
                  duration: ExpressiveMotion.duration(
                    context,
                    ExpressiveMotion.fast,
                  ),
                  curve: ExpressiveMotion.spatial,
                  alignment: Alignment.topCenter,
                  child: widget.contextChips.isEmpty
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextFieldTapRegion(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: widget.contextChips,
                              ),
                            ),
                          ),
                        ),
                ),
                field,
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      if ((widget.images, widget.onPickImages) case (
                        final images?,
                        final onPick?,
                      )) ...<Widget>[
                        TextFieldTapRegion(
                          child: AiComposerAttachButton(
                            images: images,
                            // 生成中也能先给下一条消息选图（与打字一样）；
                            // 发送按钮那时是“停止”，不会提前发出。
                            enabled: widget.enabled,
                            onPick: onPick,
                            onTakePhoto: widget.onTakePhoto,
                            options: widget.options,
                          ),
                        ),
                        const SizedBox(width: 2),
                      ],
                      // 模型按钮靠左、按内容取宽，放不下时省略而不是滚动。
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: widget.model == null
                              ? null
                              : TextFieldTapRegion(child: widget.model!),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextFieldTapRegion(
                        child: _SendButton(
                          controller: widget.controller,
                          images: widget.images,
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
    required this.images,
    required this.busy,
    required this.enabled,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final DiaryCommentImagesController? images;
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
              listenable: Listenable.merge(<Listenable?>[controller, images]),
              builder: (context, _) {
                final images = this.images;
                final hasImages = images != null && images.images.isNotEmpty;
                final copying = images != null && images.isBusy;
                final ready =
                    enabled &&
                    !copying &&
                    (controller.text.trim().isNotEmpty || hasImages);
                return IconButton.filled(
                  tooltip: l10n.aiPanelSend,
                  onPressed: ready ? onSend : null,
                  icon: const FaIcon(FontAwesomeIcons.arrowUp, size: 16),
                );
              },
            ),
    );
  }
}

/// 输入框上方的一枚胶囊：这段对话改过的一项设置（`secondaryContainer`
/// 底）。点按再改；[onClear] 给出时行尾有一枚 ×，点了复原为默认。
class AiComposerChip extends StatelessWidget {
  const AiComposerChip({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.emoji,
    this.tooltip,
    this.onClear,
  });

  final String label;
  final VoidCallback? onPressed;
  final FaIconData? icon;
  final String? emoji;
  final String? tooltip;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = onPressed == null
        ? colors.onSecondaryContainer.withValues(alpha: 0.5)
        : colors.onSecondaryContainer;
    final body = InkWell(
      onTap: onPressed,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: 10,
          end: onClear == null ? 10 : 4,
          top: 7,
          bottom: 7,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (emoji != null)
              Text(
                emoji!,
                style: theme.textTheme.labelMedium?.copyWith(fontSize: 13),
              )
            else if (icon != null)
              FaIcon(icon, size: 12, color: foreground),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
    return Material(
      color: colors.secondaryContainer,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          tooltip == null ? body : Tooltip(message: tooltip!, child: body),
          if (onClear != null)
            Tooltip(
              message: l10n.commonReset,
              child: InkWell(
                onTap: onClear,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: 6,
                    end: 10,
                    top: 8,
                    bottom: 8,
                  ),
                  child: FaIcon(
                    FontAwesomeIcons.xmark,
                    size: 11,
                    color: foreground,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 底排的“模型 · 思考”按钮：没有描边的胶囊，文字放不下时省略，行尾一枚
/// 向下的小箭头表示会打开面板。[custom]（这段对话换过模型或思考强度）时
/// 为 `secondaryContainer` 底。
class AiComposerModelButton extends StatelessWidget {
  const AiComposerModelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.custom = false,
    this.tooltip,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool custom;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final base = custom ? colors.onSecondaryContainer : colors.onSurfaceVariant;
    final foreground = onPressed == null ? base.withValues(alpha: 0.5) : base;
    final button = Material(
      color: custom ? colors.secondaryContainer : Colors.transparent,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FaIcon(FontAwesomeIcons.microchip, size: 12, color: foreground),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: foreground,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              FaIcon(FontAwesomeIcons.angleDown, size: 10, color: foreground),
            ],
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
