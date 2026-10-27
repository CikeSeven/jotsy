import 'package:flutter/material.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_toolbar_size.dart';
import 'package:node_diary/ui/widgets/expressive_button_group.dart';

import '../widgets/settings_option_tiles.dart';

/// “工具栏大小”：小 / 标准 / 大 / 特大，点选即保存（本机偏好）。编辑页与模板
/// 编辑页的悬浮工具栏、工具栏排序页的分界线都监听同一个设置值。
class SettingsToolbarSizeTile extends StatelessWidget {
  const SettingsToolbarSizeTile({super.key, required this.settings});

  final SettingsService settings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ValueListenableBuilder<String?>(
      valueListenable: settings.diaryToolbarSizeRawNotifier,
      builder: (BuildContext context, String? raw, Widget? child) {
        return SettingsChoiceTile(
          title: l10n.diaryToolbarSizeTitle,
          subtitle: l10n.diaryToolbarSizeSubtitle,
          child: ExpressiveButtonGroup<DiaryToolbarSize>(
            minSegmentWidth: 64,
            segments: <ButtonSegment<DiaryToolbarSize>>[
              for (final size in DiaryToolbarSize.values)
                ButtonSegment<DiaryToolbarSize>(
                  value: size,
                  label: Text(size.label(l10n)),
                ),
            ],
            selected: <DiaryToolbarSize>{DiaryToolbarSize.decode(raw)},
            onSelectionChanged: (Set<DiaryToolbarSize> selection) =>
                settings.setDiaryToolbarSizeRaw(selection.single.storageKey),
          ),
        );
      },
    );
  }
}
