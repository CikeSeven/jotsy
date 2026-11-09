// 对话页的“回到底部”按钮（DESIGN §5.29“消息”）：用户往上翻、列表不再贴底
// 跟随时，在消息区底部居中浮出一枚 36dp 的圆形按钮；点了平滑滚回最新的
// 消息并重新跟随。生成中往上翻看旧内容时，靠它一步回到正在写的回答。
//
// - 显隐只听 [AiChatScrollController.followingListenable]，不随流式更新重建；
//   出现 / 消失为缩放 + 淡入（`ExpressiveMotion.fast`）。
// - 底色与描边取 `AppGlassField`（控件材质，不模糊，可以放进透明度层），
//   经典时为 `surfaceContainerHigh` + `outlineVariant` 细描边。

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/widgets/app_glass_field.dart';
import '../../widgets/ai_chat_scroll_controller.dart';

class AiScrollToBottomButton extends StatelessWidget {
  const AiScrollToBottomButton({super.key, required this.controller});

  final AiChatScrollController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final glass = AppGlassField.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: controller.followingListenable,
      builder: (context, following, _) => AnimatedSwitcher(
        duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
        switchInCurve: ExpressiveMotion.effects,
        switchOutCurve: ExpressiveMotion.exit,
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: following
            ? const SizedBox.shrink(key: ValueKey<String>('hidden'))
            : Material(
                key: const ValueKey<String>('button'),
                color: glass?.fill ?? colors.surfaceContainerHigh,
                elevation: 2,
                shadowColor: colors.shadow.withValues(alpha: 0.4),
                shape: CircleBorder(
                  side:
                      glass?.border ??
                      BorderSide(
                        color: colors.outlineVariant.withValues(alpha: 0.6),
                        width: 0.8,
                      ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Tooltip(
                  message: l10n.aiChatScrollToBottom,
                  child: InkWell(
                    onTap: () => controller.scrollToBottom(
                      duration: ExpressiveMotion.duration(
                        context,
                        ExpressiveMotion.standard,
                      ),
                      curve: ExpressiveMotion.effects,
                    ),
                    child: SizedBox.square(
                      dimension: 36,
                      child: Center(
                        child: FaIcon(
                          FontAwesomeIcons.arrowDown,
                          size: 14,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
