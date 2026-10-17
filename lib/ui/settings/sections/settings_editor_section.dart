import 'package:flutter/material.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/services/diary_font_storage_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/providers/diary_typography_provider.dart';
import 'package:node_diary/ui/diaries/widgets/diary_font_choices.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:node_diary/ui/diaries/widgets/diary_typography_metrics_editor.dart';
import 'package:node_diary/ui/settings/pages/diary_toolbar_order_page.dart';
import 'package:node_diary/ui/settings/pages/diary_typography_page.dart';
import 'package:node_diary/ui/settings/pages/mood_options_page.dart';
import '../widgets/settings_card_group.dart';

/// 设置页编辑器配置区块。
class SettingsEditorSection extends StatelessWidget {
  const SettingsEditorSection({super.key, required this.settingsAsync});

  final AsyncValue<SettingsService> settingsAsync;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return settingsAsync.when(
      data: (settingsService) {
        return ValueListenableBuilder<String?>(
          valueListenable: settingsService.diaryToolbarOrderRawNotifier,
          builder: (BuildContext context, String? toolbarOrderRaw, Widget? child) {
            return ValueListenableBuilder<String?>(
              valueListenable:
                  settingsService.diaryToolbarHiddenItemsRawNotifier,
              builder:
                  (
                    BuildContext context,
                    String? toolbarHiddenItemsRaw,
                    Widget? child,
                  ) {
                    final order = decodeDiaryToolbarOrder(toolbarOrderRaw);
                    final hiddenItems = decodeDiaryToolbarHiddenItems(
                      toolbarHiddenItemsRaw,
                    );
                    final enabledOrder = filterEnabledDiaryToolbarOrder(
                      order,
                      hiddenItems,
                    );
                    final preview = enabledOrder
                        .take(4)
                        .map(
                          (DiaryToolbarItem item) =>
                              _labelForItem(context, item),
                        )
                        .join(' · ');
                    return ValueListenableBuilder<String?>(
                      valueListenable: settingsService.moodOptionsRawNotifier,
                      builder:
                          (
                            BuildContext context,
                            String? moodOptionsRaw,
                            Widget? child,
                          ) {
                            final moodOptions =
                                SettingsService.decodeMoodOptions(
                                  moodOptionsRaw,
                                );
                            return Column(
                              children: <Widget>[
                                SettingsCardGroup(
                                  title: l10n.settingsEditorGroup,
                                  children: <Widget>[
                                    const _DiaryTypographyTile(),
                                    _DayPhotoSuggestionsSwitch(
                                      settings: settingsService,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SettingsCardGroup(
                                  title: l10n.settingsEditorToolsGroup,
                                  children: <Widget>[
                                    ListTile(
                                      title: Text(l10n.autoT0043),
                                      subtitle: Text(
                                        l10n.autoT0044(
                                          preview.isEmpty ? '-' : preview,
                                        ),
                                      ),
                                      trailing: const FaIcon(
                                        FontAwesomeIcons.angleRight,
                                        size: 14,
                                      ),
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (BuildContext context) {
                                              return DiaryToolbarOrderPage(
                                                settingsService:
                                                    settingsService,
                                              );
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                    ListTile(
                                      title: Text(
                                        l10n.settingsMoodOptionsTitle,
                                      ),
                                      subtitle: Text(
                                        '${l10n.settingsMoodOptionsSubtitle}\n${moodOptions.join(' ')}',
                                      ),
                                      trailing: const FaIcon(
                                        FontAwesomeIcons.angleRight,
                                        size: 14,
                                      ),
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (BuildContext context) {
                                              return MoodOptionsPage(
                                                settingsService:
                                                    settingsService,
                                              );
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                    );
                  },
            );
          },
        );
      },
      loading: () => Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: ExpressiveLoadingIndicator(size: 32)),
      ),
      error: (Object error, StackTrace stackTrace) =>
          ListTile(title: Text(l10n.autoT0045(error.toString()))),
    );
  }

  String _labelForItem(BuildContext context, DiaryToolbarItem item) =>
      item.label(context.l10n);
}

/// “正文字体与排版”入口：副标题概括当前字体、字号与行距。
class _DiaryTypographyTile extends ConsumerWidget {
  const _DiaryTypographyTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final typography = ref.watch(diaryTypographyProvider);
    final importedFonts =
        ref.watch(diaryImportedFontsProvider).asData?.value ??
        const <DiaryImportedFont>[];
    final options = diaryFontOptions(l10n, importedFonts);
    // 所选导入字体缺失时正文按内置字体显示，概括也如实显示内置字体。
    final fontLabel = options
        .firstWhere(
          (option) => option.id == typography.fontId,
          orElse: () => options.first,
        )
        .label;
    return ListTile(
      title: Text(l10n.diaryTypographyTitle),
      subtitle: Text(
        l10n.diaryTypographySummary(
          fontLabel,
          formatDiaryTypographyValue(typography.fontSize),
          formatDiaryTypographyValue(typography.lineHeight),
        ),
      ),
      trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const DiaryTypographyPage(),
        ),
      ),
    );
  }
}

/// “补写时推荐当天照片”开关：关掉后补写日记不再出现这天的照片提示条，
/// 也就不会再提示申请相册权限。
class _DayPhotoSuggestionsSwitch extends StatelessWidget {
  const _DayPhotoSuggestionsSwitch({required this.settings});

  final SettingsService settings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ValueListenableBuilder<bool>(
      valueListenable: settings.dayPhotoSuggestionsEnabledNotifier,
      builder: (BuildContext context, bool enabled, Widget? child) {
        return SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          value: enabled,
          title: Text(l10n.settingsDayPhotoSuggestions),
          subtitle: Text(l10n.settingsDayPhotoSuggestionsSubtitle),
          onChanged: settings.setDayPhotoSuggestionsEnabled,
        );
      },
    );
  }
}
