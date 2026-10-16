import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/services/settings_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../diaries/models/diary_card_style/diary_card_style_settings.dart';
import '../pages/diary_card_style_page.dart';
import 'diary_card_style/diary_card_style_labels.dart';

/// 外观与语言页的“日记卡片样式”入口。
///
/// 副标题显示当前样式的名字：内置预设名、我的样式名或“自定义”，跟随
/// raw notifier 实时更新（从样式页返回、恢复备份后都会刷新）。
class SettingsDiaryCardStyleTile extends StatelessWidget {
  const SettingsDiaryCardStyleTile({super.key, required this.settingsAsync});

  final AsyncValue<SettingsService> settingsAsync;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const padding = EdgeInsets.symmetric(horizontal: 16, vertical: 4);
    return settingsAsync.when(
      data: (SettingsService settings) => ValueListenableBuilder<String?>(
        valueListenable: settings.diaryCardStyleRawNotifier,
        builder: (BuildContext context, String? raw, Widget? child) {
          final name = diaryCardStyleDisplayName(
            l10n,
            DiaryCardStyleSettings.decode(raw),
          );
          return ListTile(
            contentPadding: padding,
            title: Text(l10n.diaryCardStyleTitle),
            subtitle: Text(l10n.diaryCardStyleEntrySubtitle(name)),
            trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) =>
                    DiaryCardStylePage(settingsService: settings),
              ),
            ),
          );
        },
      ),
      loading: () => ListTile(
        enabled: false,
        contentPadding: padding,
        title: Text(l10n.diaryCardStyleTitle),
      ),
      error: (Object error, StackTrace stackTrace) => ListTile(
        enabled: false,
        contentPadding: padding,
        title: Text(l10n.diaryCardStyleTitle),
      ),
    );
  }
}
