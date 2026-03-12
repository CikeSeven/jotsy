import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/core/services/settings_service.dart';

/// 设置页主题模式区块。
///
/// 仅负责主题切换 UI，不耦合标签或编辑器设置。
class SettingsThemeSection extends StatelessWidget {
  const SettingsThemeSection({
    super.key,
    required this.settingsAsync,
  });

  final AsyncValue<SettingsService> settingsAsync;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return settingsAsync.when(
      data: (settingsService) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: settingsService.themeModeNotifier,
          builder: (BuildContext context, ThemeMode mode, Widget? child) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<ThemeMode>(
                  selected: <ThemeMode>{mode},
                  onSelectionChanged: (Set<ThemeMode> selection) {
                    final next = selection.firstOrNull;
                    if (next != null) {
                      settingsService.setThemeMode(next);
                    }
                  },
                  segments: <ButtonSegment<ThemeMode>>[
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      label: Text(l10n.autoT0046),
                      icon: Icon(Icons.settings_suggest_outlined),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      label: Text(l10n.autoT0047),
                      icon: Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      label: Text(l10n.autoT0048),
                      icon: Icon(Icons.dark_mode_outlined),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading:
          () => Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: LoadingIndicatorM3E(
                variant: LoadingIndicatorM3EVariant.contained,
                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                semanticLabel: l10n.dataMgmtBusyLabel,
              ),
            ),
          ),
      error:
           (Object error, StackTrace stackTrace) =>
              ListTile(title: Text(l10n.autoT0045(error.toString()))),
    );
  }
}
