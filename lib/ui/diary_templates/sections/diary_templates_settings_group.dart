import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../settings/widgets/settings_card_group.dart';
import '../viewmodels/diary_template_auto_labels.dart';
import '../viewmodels/diary_template_library.dart';

/// 模板管理页顶部的“新建日记时”分组：建议条开关与自动套用。自动套用的
/// 时间段与默认模板在单独的页面里设置（[onOpenAutoApply]），这里只显示摘要。
class DiaryTemplatesSettingsGroup extends StatelessWidget {
  const DiaryTemplatesSettingsGroup({
    super.key,
    required this.library,
    required this.onStripChanged,
    required this.onOpenAutoApply,
  });

  final DiaryTemplateLibrary library;
  final ValueChanged<bool> onStripChanged;
  final VoidCallback onOpenAutoApply;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SettingsCardGroup(
      title: l10n.diaryTemplatesNewEntryGroup,
      children: <Widget>[
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          value: library.prefs.showStrip,
          title: Text(l10n.diaryTemplatesStripSwitch),
          subtitle: Text(l10n.diaryTemplatesStripSwitchSubtitle),
          onChanged: onStripChanged,
        ),
        ListTile(
          title: Text(l10n.diaryTemplatesAutoApply),
          subtitle: Text(diaryTemplateAutoSummary(l10n, library)),
          trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
          onTap: onOpenAutoApply,
        ),
      ],
    );
  }
}
