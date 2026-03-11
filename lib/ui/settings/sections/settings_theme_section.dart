import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
                  segments: const <ButtonSegment<ThemeMode>>[
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      label: Text('系统'),
                      icon: Icon(Icons.settings_suggest_outlined),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      label: Text('浅色'),
                      icon: Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      label: Text('深色'),
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
          () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
      error:
          (Object error, StackTrace stackTrace) =>
              ListTile(title: Text('设置加载失败: $error')),
    );
  }
}
