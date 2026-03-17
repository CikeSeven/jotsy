import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/widgets/color_palette_families.dart';

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
              builder: (
                BuildContext context,
                Color themeSeedColor,
                Widget? child,
              ) {
                return ValueListenableBuilder<HomeTabSwitchCurveType>(
                  valueListenable: settingsService.homeTabSwitchCurveNotifier,
                  builder: (
                    BuildContext context,
                    HomeTabSwitchCurveType curveType,
                    Widget? child,
                  ) {
                    final selection = resolveColorPaletteSelection(
                      initialColor: themeSeedColor.toARGB32(),
                      fallbackFamilyIndex: _fallbackFamilyIndex,
                      fallbackColorIndex: _fallbackColorIndex,
                      preserveUnknownColor: false,
                    );
                    final selectedFamily =
                        kColorPaletteFamilies[selection.familyIndex];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SegmentedButton<ThemeMode>(
                              selected: <ThemeMode>{mode},
                              onSelectionChanged: (Set<ThemeMode> selection) {
                                final next = selection.firstOrNull;
                                if (next != null) {
                                  settingsService.setThemeMode(next);
                                }
                              },
                              segments: <ButtonSegment<ThemeMode>>[
                                ButtonSegment<ThemeMode>(
                                  value: ThemeMode.system,
                                  label: Text(l10n.autoT0046),
                                  icon: Icon(Icons.settings_suggest_outlined),
                                ),
                                ButtonSegment<ThemeMode>(
                                  value: ThemeMode.light,
                                  label: Text(l10n.autoT0047),
                                  icon: Icon(Icons.light_mode_outlined),
                                ),
                                ButtonSegment<ThemeMode>(
                                  value: ThemeMode.dark,
                                  label: Text(l10n.autoT0048),
                                  icon: Icon(Icons.dark_mode_outlined),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _TabSwitchCurveSelector(
                            selectedCurveType: curveType,
                            onChanged:
                                settingsService.setHomeTabSwitchCurveType,
                          ),
                          const SizedBox(height: 8),
                          Divider(
                            height: 1,
                            color: Theme.of(context).colorScheme.outlineVariant
                                .withValues(alpha: 0.45),
                          ),
                          const SizedBox(height: 12),
                          _ThemeSeedColorPicker(
                            selectedColor: themeSeedColor,
                            selectedFamilyIndex: selection.familyIndex,
                            selectedColorIndex: selection.colorIndex,
                            selectedFamily: selectedFamily,
                            onSelectFamily: (int familyIndex) {
                              settingsService.setThemeSeedColor(
                                kColorPaletteFamilies[familyIndex].colors[0],
                              );
                            },
                            onSelectColor: settingsService.setThemeSeedColor,
                          ),
                        ],
                      ),
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
    final result = await showDialog<HomeTabSwitchCurveType>(
      context: context,
      builder: (BuildContext dialogContext) {
        final l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.settingsTabSwitchCurve),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                onTap:
                    () => Navigator.of(
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
                dense: true,
                contentPadding: EdgeInsets.zero,
                onTap:
                    () => Navigator.of(
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
                dense: true,
                contentPadding: EdgeInsets.zero,
                onTap:
                    () => Navigator.of(
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
      contentPadding: EdgeInsets.zero,
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

class _ThemeSeedColorPicker extends StatelessWidget {
  const _ThemeSeedColorPicker({
    required this.selectedColor,
    required this.selectedFamilyIndex,
    required this.selectedColorIndex,
    required this.selectedFamily,
    required this.onSelectFamily,
    required this.onSelectColor,
  });

  final Color selectedColor;
  final int selectedFamilyIndex;
  final int selectedColorIndex;
  final ColorPaletteFamily selectedFamily;
  final ValueChanged<int> onSelectFamily;
  final ValueChanged<Color> onSelectColor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: selectedColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              l10n.settingsThemeColor,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List<Widget>.generate(kColorPaletteFamilies.length, (
              index,
            ) {
              final family = kColorPaletteFamilies[index];
              final selected = selectedFamilyIndex == index;
              return Padding(
                padding: EdgeInsets.only(
                  right: index == kColorPaletteFamilies.length - 1 ? 0 : 10,
                ),
                child: GestureDetector(
                  onTap: () => onSelectFamily(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: family.colors[2],
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color:
                            selected
                                ? colorScheme.onSurface
                                : colorScheme.outlineVariant,
                        width: selected ? 2.0 : 1.0,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List<Widget>.generate(selectedFamily.colors.length, (
            index,
          ) {
            final color = selectedFamily.colors[index];
            final selected = selectedColorIndex == index;
            return GestureDetector(
              onTap: () => onSelectColor(color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        selected ? colorScheme.onSurface : colorScheme.outline,
                    width: selected ? 2.2 : 1.0,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
