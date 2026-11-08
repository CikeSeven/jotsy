import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/settings_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../diaries/models/diary_create_prefs.dart';
import '../../diaries/providers/diary_create_prefs_provider.dart';

/// 编辑器设置里的“返回时直接发表新日记”开关（#196）。
///
/// 关闭（默认）：写新日记时按返回，这篇存进草稿箱，之后从草稿箱续写、发表。
/// 打开：按返回直接发表成日记，不经发布页；带时间胶囊的仍经发布页（封存
/// 仪式），发表失败时留在草稿箱（流程见 `EditDiaryCreateLeaveFlow`）。草稿箱
/// 本身不受影响：写作中的自动保存、被系统回收时留下的草稿照常在那里。
class SettingsPublishOnLeaveSwitch extends ConsumerWidget {
  const SettingsPublishOnLeaveSwitch({
    super.key,
    required this.settingsService,
  });

  final SettingsService settingsService;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final enabled = ref.watch(
      diaryCreatePrefsProvider.select((prefs) => prefs.publishOnLeave),
    );
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      value: enabled,
      title: Text(l10n.settingsPublishOnLeave),
      subtitle: Text(l10n.settingsPublishOnLeaveSubtitle),
      onChanged: (bool value) {
        final current = DiaryCreatePrefs.decode(
          settingsService.diaryCreatePrefsRaw,
        );
        unawaited(
          saveDiaryCreatePrefs(
            settingsService,
            current.copyWith(
              leaveAction: value
                  ? DiaryCreateLeaveAction.publish
                  : DiaryCreateLeaveAction.keepDraft,
            ),
          ),
        );
      },
    );
  }
}
