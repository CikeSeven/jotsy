import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';

/// 设置页日记卡片展示区块。
///
/// 输入为异步初始化的设置服务；输出当前标签显示上限及选择弹窗。
/// 唯一副作用是在用户确认新值后持久化设置，取消弹窗不会修改服务状态。
class SettingsDiaryCardSection extends StatelessWidget {
  const SettingsDiaryCardSection({super.key, required this.settingsAsync});

  final AsyncValue<SettingsService> settingsAsync;

  String _limitLabel(AppLocalizations l10n, int limit) {
    return limit == SettingsService.minDiaryCardTagLimit
        ? l10n.settingsDiaryCardTagLimitHidden
        : l10n.settingsDiaryCardTagLimitValue(limit);
  }

  Future<void> _showTagLimitDialog(
    BuildContext context,
    SettingsService settings,
  ) async {
    final originalLimit = settings.diaryCardTagLimit;
    var selectedLimit = originalLimit;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setDialogState) {
            final l10n = dialogContext.l10n;
            final colorScheme = Theme.of(dialogContext).colorScheme;
            final selectedLabel = _limitLabel(l10n, selectedLimit);
            return AlertDialog(
              title: Text(l10n.settingsDiaryCardTagLimit),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    selectedLabel,
                    style: Theme.of(dialogContext).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Slider(
                    value: selectedLimit.toDouble(),
                    min: SettingsService.minDiaryCardTagLimit.toDouble(),
                    max: SettingsService.maxDiaryCardTagLimit.toDouble(),
                    divisions:
                        SettingsService.maxDiaryCardTagLimit -
                        SettingsService.minDiaryCardTagLimit,
                    label: selectedLabel,
                    onChanged: (double value) {
                      setDialogState(() {
                        selectedLimit = value.round();
                      });
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.commonCancel),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(l10n.commonConfirm),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && selectedLimit != originalLimit) {
      await settings.setDiaryCardTagLimit(selectedLimit);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return settingsAsync.when(
      data:
          (SettingsService settings) => ValueListenableBuilder<int>(
            valueListenable: settings.diaryCardTagLimitNotifier,
            builder: (BuildContext context, int limit, Widget? child) {
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: Text(l10n.settingsDiaryCardTagLimit),
                subtitle: Text(_limitLabel(l10n, limit)),
                trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
                onTap: () => _showTagLimitDialog(context, settings),
              );
            },
          ),
      loading:
          () => ListTile(
            enabled: false,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: Text(l10n.settingsDiaryCardTagLimit),
            trailing: LoadingIndicatorM3E(
              variant: LoadingIndicatorM3EVariant.contained,
              constraints: const BoxConstraints.tightFor(width: 24, height: 24),
              semanticLabel: l10n.dataMgmtBusyLabel,
            ),
          ),
      error:
          (Object error, StackTrace stackTrace) => ListTile(
            enabled: false,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: Text(l10n.settingsDiaryCardTagLimit),
            subtitle: Text(
              _limitLabel(l10n, SettingsService.defaultDiaryCardTagLimit),
            ),
          ),
    );
  }
}
