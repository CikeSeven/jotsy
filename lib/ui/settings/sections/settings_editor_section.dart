import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:node_diary/ui/settings/pages/diary_toolbar_order_page.dart';

/// 设置页编辑器配置区块。
class SettingsEditorSection extends StatelessWidget {
  const SettingsEditorSection({
    super.key,
    required this.settingsAsync,
  });

  final AsyncValue<SettingsService> settingsAsync;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return settingsAsync.when(
      data: (settingsService) {
        final order = decodeDiaryToolbarOrder(
          settingsService.diaryToolbarOrderRaw,
        );
        final preview = order
            .take(4)
            .map((DiaryToolbarItem item) => _labelForItem(context, item))
            .join(' · ');
        return ListTile(
          title: Text(l10n.autoT0043),
          subtitle: Text(l10n.autoT0044(preview)),
          trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) {
                  return DiaryToolbarOrderPage(
                    settingsService: settingsService,
                  );
                },
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
              ListTile(title: Text(l10n.autoT0045(error))),
    );
  }

  String _labelForItem(BuildContext context, DiaryToolbarItem item) {
    final l10n = context.l10n;
    return switch (item) {
      DiaryToolbarItem.undo => l10n.autoT0006,
      DiaryToolbarItem.redo => l10n.autoT0007,
      DiaryToolbarItem.bold => l10n.autoT0008,
      DiaryToolbarItem.italic => l10n.autoT0009,
      DiaryToolbarItem.underline => l10n.autoT0010,
      DiaryToolbarItem.strikeThrough => l10n.autoT0011,
      DiaryToolbarItem.inlineCode => l10n.autoT0012,
      DiaryToolbarItem.textColor => l10n.autoT0013,
      DiaryToolbarItem.backgroundColor => l10n.autoT0014,
      DiaryToolbarItem.clearFormat => l10n.autoT0015,
      DiaryToolbarItem.image => l10n.autoT0016,
      DiaryToolbarItem.headerStyle => l10n.autoT0017,
      DiaryToolbarItem.orderedList => l10n.autoT0018,
      DiaryToolbarItem.bulletList => l10n.autoT0019,
      DiaryToolbarItem.checkList => l10n.autoT0020,
      DiaryToolbarItem.codeBlock => l10n.autoT0021,
      DiaryToolbarItem.quote => l10n.autoT0022,
      DiaryToolbarItem.indent => l10n.autoT0023,
      DiaryToolbarItem.link => l10n.autoT0024,
    };
  }
}
