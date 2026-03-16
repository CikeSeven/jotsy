import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
                          const SizedBox(height: 16),
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DropdownButtonFormField<HomeTabSwitchCurveType>(
      key: ValueKey<HomeTabSwitchCurveType>(selectedCurveType),
      initialValue: selectedCurveType,
      decoration: InputDecoration(
        isDense: true,
        labelText: l10n.settingsTabSwitchCurve,
        helperText: l10n.settingsTabSwitchCurveSubtitle,
        border: const OutlineInputBorder(),
      ),
      items: <DropdownMenuItem<HomeTabSwitchCurveType>>[
        DropdownMenuItem<HomeTabSwitchCurveType>(
          value: HomeTabSwitchCurveType.easeOutCirc,
          child: Text(l10n.settingsTabSwitchCurveEaseOutCirc),
        ),
        DropdownMenuItem<HomeTabSwitchCurveType>(
          value: HomeTabSwitchCurveType.easeOutCubic,
          child: Text(l10n.settingsTabSwitchCurveEaseOutCubic),
        ),
        DropdownMenuItem<HomeTabSwitchCurveType>(
          value: HomeTabSwitchCurveType.linear,
          child: Text(l10n.settingsTabSwitchCurveLinear),
        ),
      ],
      onChanged: (HomeTabSwitchCurveType? next) {
        if (next == null) {
          return;
        }
        onChanged(next);
      },
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
              l10n.autoT0151,
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
