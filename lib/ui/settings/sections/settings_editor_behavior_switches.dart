import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/settings_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../diaries/models/diary_create_prefs.dart';
import '../../diaries/models/diary_edit_prefs.dart';
import '../../diaries/providers/diary_create_prefs_provider.dart';
import '../../diaries/providers/diary_edit_prefs_provider.dart';

/// 编辑器设置里的“发布时自动展开详细信息”开关。
///
/// 关闭（默认）：进入发布页时底部详细信息面板保持收起，需手动上滑或点按展开。
/// 打开：进入发布页完成发表后自动展开底部详细信息面板。
class SettingsExpandPublishPanelSwitch extends ConsumerWidget {
  const SettingsExpandPublishPanelSwitch({
    super.key,
    required this.settingsService,
  });

  final SettingsService settingsService;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final enabled = ref.watch(
      diaryCreatePrefsProvider.select((prefs) => prefs.expandPublishPanel),
    );
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      value: enabled,
      title: Text(l10n.settingsExpandPublishPanel),
      subtitle: Text(l10n.settingsExpandPublishPanelSubtitle),
      onChanged: (bool value) {
        final current = DiaryCreatePrefs.decode(
          settingsService.diaryCreatePrefsRaw,
        );
        unawaited(
          saveDiaryCreatePrefs(
            settingsService,
            current.copyWith(expandPublishPanel: value),
          ),
        );
      },
    );
  }
}

/// 编辑器设置里的“插入图片和视频时默认小图”开关。
///
/// 关闭（默认）：插入图片与视频按正常大小显示（仅紧跟在小图后插入时跟随）。
/// 打开：新插入或粘贴进正文的外部图片与视频默认以方形小图显示，仍可按菜单
/// 恢复正常显示。
class SettingsDefaultMediaThumbnailSwitch extends ConsumerWidget {
  const SettingsDefaultMediaThumbnailSwitch({
    super.key,
    required this.settingsService,
  });

  final SettingsService settingsService;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final enabled = ref.watch(
      diaryEditPrefsProvider.select((prefs) => prefs.defaultMediaThumbnail),
    );
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      value: enabled,
      title: Text(l10n.settingsDefaultMediaThumbnail),
      subtitle: Text(l10n.settingsDefaultMediaThumbnailSubtitle),
      onChanged: (bool value) {
        final current = DiaryEditPrefs.decode(
          settingsService.diaryEditPrefsRaw,
        );
        unawaited(
          saveDiaryEditPrefs(
            settingsService,
            current.copyWith(defaultMediaThumbnail: value),
          ),
        );
      },
    );
  }
}
