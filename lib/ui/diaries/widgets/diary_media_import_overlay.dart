import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';

/// 选文件返回后的复制等待；放在编辑页 Stack 最上层，避免半成品提前被发布。
class DiaryMediaImportOverlay extends StatelessWidget {
  const DiaryMediaImportOverlay({super.key});

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: Stack(
      alignment: Alignment.center,
      children: [
        ModalBarrier(
          dismissible: false,
          color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.16),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExpressiveLoadingIndicator(
                  semanticLabel: context.l10n.diaryMediaImporting,
                ),
                const SizedBox(height: 12),
                Text(context.l10n.diaryMediaImporting),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
