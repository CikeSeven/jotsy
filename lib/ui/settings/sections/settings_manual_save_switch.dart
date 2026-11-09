import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/settings_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../diaries/models/diary_edit_prefs.dart';
import '../../diaries/providers/diary_edit_prefs_provider.dart';

/// 编辑器设置里的“手动保存修改”开关。
///
/// 关闭（默认）：编辑已有日记时改了就自动保存，返回时补存。
/// 打开：只在点阅读式编辑页顶栏的“保存”（桌面 Ctrl / ⌘ + S）时写入；有未
/// 保存的修改时返回先问“取消 / 退出 / 保存并退出”（流程见
/// `EditDiaryPersistenceFlow`）。新建日记不受影响，照常存进草稿箱。
class SettingsManualSaveSwitch extends ConsumerWidget {
  const SettingsManualSaveSwitch({super.key, required this.settingsService});

  final SettingsService settingsService;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final enabled = ref.watch(
      diaryEditPrefsProvider.select((prefs) => prefs.manualSave),
    );
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      value: enabled,
      title: Text(l10n.settingsManualSave),
      subtitle: Text(l10n.settingsManualSaveSubtitle),
      onChanged: (bool value) {
        final current = DiaryEditPrefs.decode(
          settingsService.diaryEditPrefsRaw,
        );
        unawaited(
          saveDiaryEditPrefs(
            settingsService,
            current.copyWith(
              saveMode: value
                  ? DiaryEditSaveMode.manual
                  : DiaryEditSaveMode.auto,
            ),
          ),
        );
      },
    );
  }
}
