import 'package:flutter/material.dart';
import 'package:node_diary/ui/widgets/expressive_button_group.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/widgets/color_palette_families.dart';
import '../../widgets/app_modal/app_dialog.dart';
import '../widgets/settings_card_group.dart';
import '../../widgets/palette_color_picker.dart';

/// 外观页的「主题」与「界面」两组。
///
/// 「主题」：明暗模式按钮组与主题色色板；「界面」：字体大小。只负责这两组
/// UI，不耦合标签或编辑器设置。主题色的色系为统一色板加
/// 末尾的“黑白”（[kThemeColorPaletteFamilies]）；灰色与黑白怎样装配成主题见
/// `appColorSchemeFromSeed`。
class SettingsThemeSection extends StatelessWidget {
  const SettingsThemeSection({super.key, required this.settingsAsync});

  static const int _fallbackFamilyIndex = 6;
  static const int _fallbackColorIndex = 5;

  final AsyncValue<SettingsService> settingsAsync;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return settingsAsync.when(
      data: (settingsService) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: settingsService.themeModeNotifier,
          builder: (BuildContext context, ThemeMode mode, Widget? child) {
            return ValueListenableBuilder<Color>(
              valueListenable: settingsService.themeSeedColorNotifier,
              builder:
                  (BuildContext context, Color themeSeedColor, Widget? child) {
                    return ValueListenableBuilder<double>(
                      valueListenable: settingsService.fontScaleNotifier,
                      builder:
                          (
                            BuildContext context,
                            double fontScale,
                            Widget? child,
                          ) {
                            final selection = resolveColorPaletteSelection(
                              initialColor: themeSeedColor.toARGB32(),
                              fallbackFamilyIndex: _fallbackFamilyIndex,
                              fallbackColorIndex: _fallbackColorIndex,
                              preserveUnknownColor: false,
                              families: kThemeColorPaletteFamilies,
                            );
                            final selectedFamily =
                                kThemeColorPaletteFamilies[selection
                                    .familyIndex];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                SettingsCardGroup(
                                  title: l10n.settingsThemeGroup,
                                  children: <Widget>[
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: _ThemeModeButtons(
                                        mode: mode,
                                        onChanged: settingsService.setThemeMode,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: PaletteColorPicker(
                                        selectedColor: themeSeedColor,
                                        selectedFamilyIndex:
                                            selection.familyIndex,
                                        selectedColorIndex:
                                            selection.colorIndex,
                                        selectedFamily: selectedFamily,
                                        families: kThemeColorPaletteFamilies,
                                        onSelectFamily: (int familyIndex) {
                                          settingsService.setThemeSeedColor(
                                            kThemeColorPaletteFamilies[familyIndex]
                                                .colors[0],
                                          );
                                        },
                                        onSelectColor:
                                            settingsService.setThemeSeedColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SettingsCardGroup(
                                  title: l10n.settingsInterfaceGroup,
                                  children: <Widget>[
                                    _FontScaleSelector(
                                      selectedScale: fontScale,
                                      onChanged: settingsService.setFontScale,
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
}

/// 明暗模式按钮组：跟随系统 / 浅色 / 深色。
class _ThemeModeButtons extends StatelessWidget {
  const _ThemeModeButtons({required this.mode, required this.onChanged});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ExpressiveButtonGroup<ThemeMode>(
      selected: <ThemeMode>{mode},
      onSelectionChanged: (Set<ThemeMode> selection) {
        final next = selection.firstOrNull;
        if (next != null) {
          onChanged(next);
        }
      },
      segments: <ButtonSegment<ThemeMode>>[
        ButtonSegment<ThemeMode>(
          value: ThemeMode.system,
          label: Text(l10n.autoT0046),
          icon: const FaIcon(FontAwesomeIcons.circleHalfStroke, size: 18),
        ),
        ButtonSegment<ThemeMode>(
          value: ThemeMode.light,
          label: Text(l10n.autoT0047),
          icon: const FaIcon(FontAwesomeIcons.sun, size: 18),
        ),
        ButtonSegment<ThemeMode>(
          value: ThemeMode.dark,
          label: Text(l10n.autoT0048),
          icon: const FaIcon(FontAwesomeIcons.moon, size: 18),
        ),
      ],
    );
  }
}

class _FontScaleSelector extends StatelessWidget {
  const _FontScaleSelector({
    required this.selectedScale,
    required this.onChanged,
  });

  final double selectedScale;
  final ValueChanged<double> onChanged;

  String _formatScaleLabel(double scale) {
    return '${(scale * 100).round()}%';
  }

  Future<void> _showFontScaleDialog(BuildContext context) async {
    final originalScale = selectedScale;
    var currentScale = selectedScale;
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final l10n = dialogContext.l10n;
        return StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setDialogState) {
            final previewBaseStyle =
                Theme.of(dialogContext).textTheme.bodyMedium ??
                const TextStyle(fontSize: 14);
            final previewScaleFactor = selectedScale == 0
                ? 1.0
                : currentScale / selectedScale;
            final previewFontSize =
                (previewBaseStyle.fontSize ?? 14) * previewScaleFactor;
            return AlertDialog(
              title: Text(l10n.settingsFontScale),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    _formatScaleLabel(currentScale),
                    style: Theme.of(dialogContext).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Slider(
                    value: currentScale,
                    min: SettingsService.minFontScale,
                    max: SettingsService.maxFontScale,
                    divisions:
                        ((SettingsService.maxFontScale -
                                    SettingsService.minFontScale) /
                                SettingsService.fontScaleStep)
                            .round(),
                    label: _formatScaleLabel(currentScale),
                    onChanged: (double value) {
                      setDialogState(() {
                        currentScale = value;
                      });
                    },
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        dialogContext,
                      ).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Theme.of(
                          dialogContext,
                        ).colorScheme.outlineVariant.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Text(
                      l10n.settingsFontScalePreview,
                      style: previewBaseStyle.copyWith(
                        fontSize: previewFontSize,
                      ),
                    ),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(
                      dialogContext,
                    ).colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.commonCancel),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(l10n.commonConfirm),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && currentScale != originalScale) {
      onChanged(currentScale);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(l10n.settingsFontScale),
      subtitle: Text(l10n.settingsFontScaleSubtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            _formatScaleLabel(selectedScale),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          const FaIcon(FontAwesomeIcons.angleRight, size: 14),
        ],
      ),
      onTap: () => _showFontScaleDialog(context),
    );
  }
}
