import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/ui/widgets/delayed_loading_gate.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';

/// 选文件返回后的复制等待；放在编辑页 Stack 最上层，避免半成品提前被发布。
///
/// 输入：[copying] 为复制进行中。常驻在树上以便淡入淡出：
/// - 拦截立即生效：复制期间放一个透明 [ModalBarrier]，编辑区不可操作；它只在
///   复制期间存在，常驻会屏蔽下层的读屏语义；
/// - 画面延迟出现：图片复制通常不到 100ms，此前遮罩淡入到一半就被硬撤，形成
///   一闪。现在复制超过 300ms 才淡入遮罩与卡片，结束时淡出而不是硬切；隐藏时
///   静音指示器的 ticker。
class DiaryMediaImportOverlay extends StatelessWidget {
  const DiaryMediaImportOverlay({super.key, required this.copying});

  final bool copying;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (copying) const ModalBarrier(dismissible: false),
        IgnorePointer(
          child: DelayedLoadingGate(
            loading: copying,
            builder: (context, show) => AnimatedOpacity(
              opacity: show ? 1 : 0,
              duration: ExpressiveMotion.duration(
                context,
                ExpressiveMotion.fast,
              ),
              curve: ExpressiveMotion.effects,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: Theme.of(
                        context,
                      ).colorScheme.scrim.withValues(alpha: 0.16),
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TickerMode(
                            enabled: show,
                            child: ExpressiveLoadingIndicator(
                              semanticLabel: context.l10n.diaryMediaImporting,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(context.l10n.diaryMediaImporting),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
