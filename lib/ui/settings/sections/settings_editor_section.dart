import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:node_diary/ui/settings/pages/diary_toolbar_order_page.dart';
import 'package:node_diary/ui/settings/pages/mood_options_page.dart';

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
          builder: (
            BuildContext context,
            String? toolbarOrderRaw,
            Widget? child,
          ) {
            return ValueListenableBuilder<String?>(
              valueListenable:
                  settingsService.diaryToolbarHiddenItemsRawNotifier,
              builder: (
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
                      (DiaryToolbarItem item) => _labelForItem(context, item),
                    )
                    .join(' · ');
                return ValueListenableBuilder<EditorBodyFontSizePreset>(
                  valueListenable:
                      settingsService.editorBodyFontSizePresetNotifier,
                  builder: (
                    BuildContext context,
                    EditorBodyFontSizePreset fontSizePreset,
                    Widget? child,
                  ) {
                    return ValueListenableBuilder<EditorBodyLineHeightPreset>(
                      valueListenable:
                          settingsService.editorBodyLineHeightPresetNotifier,
                      builder: (
                        BuildContext context,
                        EditorBodyLineHeightPreset lineHeightPreset,
                        Widget? child,
                      ) {
                        return ValueListenableBuilder<String?>(
                          valueListenable:
                              settingsService.moodOptionsRawNotifier,
                          builder: (
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
                                _EditorBodyFontSizeTile(
                                  settingsService: settingsService,
                                  selectedPreset: fontSizePreset,
                                ),
                                const Divider(height: 1),
                                _EditorBodyLineHeightTile(
                                  settingsService: settingsService,
                                  selectedPreset: lineHeightPreset,
                                ),
                                const Divider(height: 1),
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
                                            settingsService: settingsService,
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  title: Text(l10n.settingsMoodOptionsTitle),
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
                                            settingsService: settingsService,
                                          );
                                        },
                                      ),
                                    );
                                  },
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
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                semanticLabel: l10n.dataMgmtBusyLabel,
              ),
            ),
          ),
      error:
          (Object error, StackTrace stackTrace) =>
              ListTile(title: Text(l10n.autoT0045(error.toString()))),
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
      DiaryToolbarItem.currentTime => l10n.diaryToolbarInsertCurrentTime,
    };
  }
}

class _EditorBodyFontSizeTile extends StatelessWidget {
  const _EditorBodyFontSizeTile({
    required this.settingsService,
    required this.selectedPreset,
  });

  final SettingsService settingsService;
  final EditorBodyFontSizePreset selectedPreset;

  String _presetLabel(AppLocalizations l10n, EditorBodyFontSizePreset preset) {
    return switch (preset) {
      EditorBodyFontSizePreset.small => l10n.settingsEditorBodyFontSizeSmall,
      EditorBodyFontSizePreset.medium => l10n.settingsEditorBodyFontSizeMedium,
      EditorBodyFontSizePreset.large => l10n.settingsEditorBodyFontSizeLarge,
    };
  }

  Future<void> _showPresetDialog(BuildContext context) async {
    final result = await showDialog<EditorBodyFontSizePreset>(
      context: context,
      builder: (BuildContext dialogContext) {
        final l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.settingsEditorBodyFontSize),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  Navigator.of(
                    dialogContext,
                  ).pop(EditorBodyFontSizePreset.small);
                },
                leading: FaIcon(
                  selectedPreset == EditorBodyFontSizePreset.small
                      ? FontAwesomeIcons.circleDot
                      : FontAwesomeIcons.circle,
                  size: 16,
                ),
                title: Text(l10n.settingsEditorBodyFontSizeSmall),
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  Navigator.of(
                    dialogContext,
                  ).pop(EditorBodyFontSizePreset.medium);
                },
                leading: FaIcon(
                  selectedPreset == EditorBodyFontSizePreset.medium
                      ? FontAwesomeIcons.circleDot
                      : FontAwesomeIcons.circle,
                  size: 16,
                ),
                title: Text(l10n.settingsEditorBodyFontSizeMedium),
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  Navigator.of(
                    dialogContext,
                  ).pop(EditorBodyFontSizePreset.large);
                },
                leading: FaIcon(
                  selectedPreset == EditorBodyFontSizePreset.large
                      ? FontAwesomeIcons.circleDot
                      : FontAwesomeIcons.circle,
                  size: 16,
                ),
                title: Text(l10n.settingsEditorBodyFontSizeLarge),
              ),
            ],
          ),
        );
      },
    );
    if (result == null || result == selectedPreset) {
      return;
    }
    await settingsService.setEditorBodyFontSizePreset(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      title: Text(l10n.settingsEditorBodyFontSize),
      subtitle: Text(l10n.settingsEditorBodyFontSizeSubtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            _presetLabel(l10n, selectedPreset),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          const FaIcon(FontAwesomeIcons.angleRight, size: 14),
        ],
      ),
      onTap: () => _showPresetDialog(context),
    );
  }
}

class _EditorBodyLineHeightTile extends StatelessWidget {
  const _EditorBodyLineHeightTile({
    required this.settingsService,
    required this.selectedPreset,
  });

  final SettingsService settingsService;
  final EditorBodyLineHeightPreset selectedPreset;

  String _presetLabel(
    AppLocalizations l10n,
    EditorBodyLineHeightPreset preset,
  ) {
    return switch (preset) {
      EditorBodyLineHeightPreset.compact =>
        l10n.settingsEditorLineHeightCompact,
      EditorBodyLineHeightPreset.normal => l10n.settingsEditorLineHeightNormal,
      EditorBodyLineHeightPreset.relaxed =>
        l10n.settingsEditorLineHeightRelaxed,
    };
  }

  Future<void> _showPresetDialog(BuildContext context) async {
    final result = await showDialog<EditorBodyLineHeightPreset>(
      context: context,
      builder: (BuildContext dialogContext) {
        final l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.settingsEditorLineHeight),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  Navigator.of(
                    dialogContext,
                  ).pop(EditorBodyLineHeightPreset.compact);
                },
                leading: FaIcon(
                  selectedPreset == EditorBodyLineHeightPreset.compact
                      ? FontAwesomeIcons.circleDot
                      : FontAwesomeIcons.circle,
                  size: 16,
                ),
                title: Text(l10n.settingsEditorLineHeightCompact),
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  Navigator.of(
                    dialogContext,
                  ).pop(EditorBodyLineHeightPreset.normal);
                },
                leading: FaIcon(
                  selectedPreset == EditorBodyLineHeightPreset.normal
                      ? FontAwesomeIcons.circleDot
                      : FontAwesomeIcons.circle,
                  size: 16,
                ),
                title: Text(l10n.settingsEditorLineHeightNormal),
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  Navigator.of(
                    dialogContext,
                  ).pop(EditorBodyLineHeightPreset.relaxed);
                },
                leading: FaIcon(
                  selectedPreset == EditorBodyLineHeightPreset.relaxed
                      ? FontAwesomeIcons.circleDot
                      : FontAwesomeIcons.circle,
                  size: 16,
                ),
                title: Text(l10n.settingsEditorLineHeightRelaxed),
              ),
            ],
          ),
        );
      },
    );
    if (result == null || result == selectedPreset) {
      return;
    }
    await settingsService.setEditorBodyLineHeightPreset(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      title: Text(l10n.settingsEditorLineHeight),
      subtitle: Text(l10n.settingsEditorLineHeightSubtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            _presetLabel(l10n, selectedPreset),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          const FaIcon(FontAwesomeIcons.angleRight, size: 14),
        ],
      ),
      onTap: () => _showPresetDialog(context),
    );
  }
}
