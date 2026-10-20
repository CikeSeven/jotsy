import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/services/settings_service.dart';
import '../../../l10n/app_localizations.dart';
import '../pages/diary_code_block_style_page.dart';

/// 编辑器设置里的“代码块样式”入口，紧跟“正文字体与排版”。与同组各行一样
/// 不放前导图标（只有一行带图标会让同组标题错位）。
class SettingsCodeBlockStyleTile extends StatelessWidget {
  const SettingsCodeBlockStyleTile({super.key, required this.settingsService});

  final SettingsService settingsService;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      title: Text(l10n.codeBlockStyleTitle),
      subtitle: Text(l10n.codeBlockStyleSubtitle),
      trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              DiaryCodeBlockStylePage(settingsService: settingsService),
        ),
      ),
    );
  }
}
