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

/// 设置页主题模式区块。
///
/// 仅负责主题切换 UI，不耦合标签或编辑器设置。
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
              builder: (BuildContext context, Color themeSeedColor, Widget? child) {
                return ValueListenableBuilder<HomeTabSwitchCurveType>(
                  valueListenable: settingsService.homeTabSwitchCurveNotifier,
                  builder:
                      (
                        BuildContext context,
                        HomeTabSwitchCurveType curveType,
                        Widget? child,
                      ) {
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
                                );
                                final selectedFamily =
                                    kColorPaletteFamilies[selection
                                        .familyIndex];
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    SettingsCardGroup(
                                      title: l10n.settingsThemeMode,
                                      children: <Widget>[
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child:
                                              ExpressiveButtonGroup<ThemeMode>(
                                                selected: <ThemeMode>{mode},
                                                onSelectionChanged:
                                                    (Set<ThemeMode> selection) {
                                                      final next =
                                                          selection.firstOrNull;
                                                      if (next != null) {
                                                        settingsService
                                                            .setThemeMode(next);
                                                      }
                                                    },
                                                segments:
                                                    <ButtonSegment<ThemeMode>>[
                                                      ButtonSegment<ThemeMode>(
                                                        value: ThemeMode.system,
                                                        label: Text(
                                                          l10n.autoT0046,
                                                        ),
                                                        icon: const FaIcon(
                                                          FontAwesomeIcons
                                                              .circleHalfStroke,
                                                          size: 18,
                                                        ),
                                                      ),
                                                      ButtonSegment<ThemeMode>(
                                                        value: ThemeMode.light,
                                                        label: Text(
                                                          l10n.autoT0047,
                                                        ),
                                                        icon: const FaIcon(
                                                          FontAwesomeIcons.sun,
                                                          size: 18,
                                                        ),
                                                      ),
                                                      ButtonSegment<ThemeMode>(
                                                        value: ThemeMode.dark,
                                                        label: Text(
                                                          l10n.autoT0048,
                                                        ),
                                                        icon: const FaIcon(
                                                          FontAwesomeIcons.moon,
                                                          size: 18,
                                                        ),
                                                      ),
                                                    ],
                                              ),
                                        ),
                                        _TabSwitchCurveSelector(
                                          selectedCurveType: curveType,
                                          onChanged: settingsService
                                              .setHomeTabSwitchCurveType,
                                        ),
                                        _FontScaleSelector(
                                          selectedScale: fontScale,
                                          onChanged:
                                              settingsService.setFontScale,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    SettingsCardGroup(
                                      title: l10n.settingsThemeColor,
                                      children: <Widget>[
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: PaletteColorPicker(
                                            selectedColor: themeSeedColor,
                                            selectedFamilyIndex:
                                                selection.familyIndex,
                                            selectedColorIndex:
                                                selection.colorIndex,
                                            selectedFamily: selectedFamily,
                                            onSelectFamily: (int familyIndex) {
                                              settingsService.setThemeSeedColor(
                                                kColorPaletteFamilies[familyIndex]
                                                    .colors[0],
                                              );
                                            },
                                            onSelectColor: settingsService
                                                .setThemeSeedColor,
                                          ),
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

class _TabSwitchCurveSelector extends StatelessWidget {
  const _TabSwitchCurveSelector({
    required this.selectedCurveType,
    required this.onChanged,
  });

  final HomeTabSwitchCurveType selectedCurveType;
  final ValueChanged<HomeTabSwitchCurveType> onChanged;

  String _labelForCurve(
    AppLocalizations l10n,
    HomeTabSwitchCurveType curveType,
  ) {
    return switch (curveType) {
      HomeTabSwitchCurveType.easeOutCirc =>
        l10n.settingsTabSwitchCurveEaseOutCirc,
      HomeTabSwitchCurveType.easeOutCubic =>
        l10n.settingsTabSwitchCurveEaseOutCubic,
      HomeTabSwitchCurveType.linear => l10n.settingsTabSwitchCurveLinear,
    };
  }

  Future<void> _showCurvePickerDialog(BuildContext context) async {
    final result = await showAppDialog<HomeTabSwitchCurveType>(
      context: context,
      builder: (BuildContext dialogContext) {
        final l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.settingsTabSwitchCurve),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                selected:
                    selectedCurveType == HomeTabSwitchCurveType.easeOutCirc,
                dense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                onTap: () => Navigator.of(
                  dialogContext,
                ).pop(HomeTabSwitchCurveType.easeOutCirc),
                leading: FaIcon(
                  selectedCurveType == HomeTabSwitchCurveType.easeOutCirc
                      ? FontAwesomeIcons.circleDot
                      : FontAwesomeIcons.circle,
                  size: 16,
                ),
                title: Text(l10n.settingsTabSwitchCurveEaseOutCirc),
              ),
              ListTile(
                selected:
                    selectedCurveType == HomeTabSwitchCurveType.easeOutCubic,
                dense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                onTap: () => Navigator.of(
                  dialogContext,
                ).pop(HomeTabSwitchCurveType.easeOutCubic),
                leading: FaIcon(
                  selectedCurveType == HomeTabSwitchCurveType.easeOutCubic
                      ? FontAwesomeIcons.circleDot
                      : FontAwesomeIcons.circle,
                  size: 16,
                ),
                title: Text(l10n.settingsTabSwitchCurveEaseOutCubic),
              ),
              ListTile(
                selected: selectedCurveType == HomeTabSwitchCurveType.linear,
                dense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                onTap: () => Navigator.of(
                  dialogContext,
                ).pop(HomeTabSwitchCurveType.linear),
                leading: FaIcon(
                  selectedCurveType == HomeTabSwitchCurveType.linear
                      ? FontAwesomeIcons.circleDot
                      : FontAwesomeIcons.circle,
                  size: 16,
                ),
                title: Text(l10n.settingsTabSwitchCurveLinear),
              ),
            ],
          ),
        );
      },
    );
    if (result == null || result == selectedCurveType) {
      return;
    }
    onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final currentLabel = _labelForCurve(l10n, selectedCurveType);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(l10n.settingsTabSwitchCurve),
      subtitle: Text(l10n.settingsTabSwitchCurveSubtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            currentLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          const FaIcon(FontAwesomeIcons.angleRight, size: 14),
        ],
      ),
      onTap: () => _showCurvePickerDialog(context),
    );
  }
}
