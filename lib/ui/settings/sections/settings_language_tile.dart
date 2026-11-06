import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_languages.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/services/app_service.dart';
import '../../widgets/app_modal/app_dialog.dart';
import '../widgets/settings_nav_tile.dart';

/// 设置首页“通用”组里的“语言”行：行尾显示当前界面语言的自称，点开语言
/// 选择对话框。选项与自称都取 [appLanguages]，不随界面语言翻译。
///
/// 设置服务未就绪时行照常显示（没有当前值），点了没有反应。
class SettingsLanguageTile extends ConsumerWidget {
  const SettingsLanguageTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsServiceProvider).asData?.value;
    if (settings == null) {
      return SettingsNavTile(
        icon: FontAwesomeIcons.language,
        title: l10n.settingsLanguage,
        onTap: null,
      );
    }
    return ValueListenableBuilder<Locale>(
      valueListenable: settings.localeNotifier,
      builder: (BuildContext context, Locale locale, Widget? child) {
        final code = settings.appLocaleCode;
        final current = appLanguages
            .where((language) => language.code == code)
            .firstOrNull;
        return SettingsNavTile(
          icon: FontAwesomeIcons.language,
          title: l10n.settingsLanguage,
          value: current?.nativeName,
          onTap: () => _showLanguagePickerDialog(context, settings),
        );
      },
    );
  }

  Future<void> _showLanguagePickerDialog(
    BuildContext context,
    SettingsService settingsService,
  ) async {
    final result = await showAppDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        final l10n = dialogContext.l10n;
        final colorScheme = Theme.of(dialogContext).colorScheme;
        // 选中底色交给 ListTile 自身绘制（tileColor 经 Ink 画在对话框 Material
        // 上），外层不再包不透明 Container，否则点击水波纹会被底色盖住。
        Widget buildOption(String code, String label) {
          final selected = settingsService.appLocaleCode == code;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              selected: selected,
              tileColor: selected ? colorScheme.secondaryContainer : null,
              selectedTileColor: colorScheme.secondaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              onTap: () => Navigator.of(dialogContext).pop(code),
              leading: FaIcon(
                selected ? FontAwesomeIcons.circleDot : FontAwesomeIcons.circle,
                size: 16,
                color: selected
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              title: Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? colorScheme.onSecondaryContainer
                      : colorScheme.onSurface,
                ),
              ),
            ),
          );
        }

        return AlertDialog(
          title: Text(l10n.languageDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final language in appLanguages)
                buildOption(language.code, language.nativeName),
            ],
          ),
        );
      },
    );
    if (result == null || result == settingsService.appLocaleCode) {
      return;
    }
    await settingsService.setAppLocaleCode(result);
  }
}
