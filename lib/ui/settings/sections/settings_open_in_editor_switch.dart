import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/settings_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../diaries/models/diary_preview_style/diary_preview_settings.dart';
import '../../diaries/providers/diary_preview_style_provider.dart';

/// 编辑器设置里的“打开日记时直接编辑”开关：点开日记跳过预览页、直接进入
/// 编辑页（未解封的时间胶囊仍先显示封存页，见 `openDiaryPage`）。
///
/// 值存在预览页的阅读行为（`DiaryPreviewBehavior.openInEditor`）里：它决定
/// 预览页出不出现，与其他阅读习惯一样随备份导出、不随预设改变。写入时在
/// 最新的存储值上只改这一项，不覆盖预览页样式页里的其他设置。
class SettingsOpenInEditorSwitch extends ConsumerWidget {
  const SettingsOpenInEditorSwitch({super.key, required this.settingsService});

  final SettingsService settingsService;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final enabled = ref.watch(
      diaryPreviewBehaviorProvider.select((behavior) => behavior.openInEditor),
    );
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      value: enabled,
      title: Text(l10n.settingsOpenDiaryInEditor),
      subtitle: Text(l10n.settingsOpenDiaryInEditorSubtitle),
      onChanged: (bool value) {
        final current = DiaryPreviewSettings.decode(
          settingsService.diaryPreviewStyleRawNotifier.value,
        );
        unawaited(
          saveDiaryPreviewSettings(
            settingsService,
            current.withBehavior(
              current.behavior.copyWith(openInEditor: value),
            ),
          ),
        );
      },
    );
  }
}
