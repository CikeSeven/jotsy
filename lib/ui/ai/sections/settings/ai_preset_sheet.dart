import 'package:flutter/material.dart';

import '../../../../core/services/ai/ai_provider_presets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../../viewmodels/ai_labels.dart';

/// 选择服务商预设的底部面板（只负责挑选）。按国内 / 国际 / 本地 / 自定义
/// 分组，每行为首字母圆标 + 名称 + 接口格式。
Future<AiProviderPreset?> showAiPresetSheet(BuildContext context) {
  return showAppModalBottomSheet<AiProviderPreset>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (BuildContext sheetContext) => const _AiPresetSheet(),
  );
}

class _AiPresetSheet extends StatelessWidget {
  const _AiPresetSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              l10n.aiPresetSheetTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final group in AiPresetGroup.values) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
              child: Text(
                aiPresetGroupLabel(l10n, group),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final preset in aiProviderPresets)
              if (preset.group == group)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  titleAlignment: ListTileTitleAlignment.center,
                  leading: AiProviderMonogram(
                    name: aiPresetLabel(l10n, preset),
                  ),
                  title: Text(aiPresetLabel(l10n, preset)),
                  subtitle: Text(aiProtocolLabel(l10n, preset.protocol)),
                  onTap: () => Navigator.of(context).pop(preset),
                ),
          ],
        ],
      ),
    );
  }
}

/// 服务商的首字母圆标（不使用品牌图标，避免冒用商标）。
class AiProviderMonogram extends StatelessWidget {
  const AiProviderMonogram({super.key, required this.name, this.size = 36});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final trimmed = name.trim();
    final letter = trimmed.isEmpty
        ? '?'
        : String.fromCharCodes(trimmed.runes.take(1)).toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Text(
        letter,
        style: theme.textTheme.titleSmall?.copyWith(
          color: colors.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
