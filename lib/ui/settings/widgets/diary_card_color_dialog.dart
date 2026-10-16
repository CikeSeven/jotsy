import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../diaries/viewmodels/diary_card_colors.dart';
import '../../widgets/color_palette_families.dart';
import '../../widgets/color_swatch_button.dart';
import '../../widgets/expressive_button_group.dart';
import '../../widgets/palette_color_picker.dart';

/// 自定义颜色对话框的结果：浅色值与可选的深色值（null 表示自动推导）。
class DiaryCardCustomColor {
  const DiaryCardCustomColor({required this.light, this.dark});

  final int light;
  final int? dark;
}

/// 选择一个自定义颜色（浅色 / 深色两态）。
///
/// 深色默认“自动配色”：按 [DiaryCardColors.deriveDark] 由浅色值推导，关闭后
/// 可单独指定。颜色来自调色板或 6 位 HEX 输入；取消返回 null。
Future<DiaryCardCustomColor?> showDiaryCardColorDialog(
  BuildContext context, {
  required String title,
  required int light,
  required int? dark,
  required DiaryCardColorRole role,
}) {
  return showDialog<DiaryCardCustomColor>(
    context: context,
    builder: (BuildContext context) => _DiaryCardColorDialog(
      title: title,
      initialLight: light,
      initialDark: dark,
      role: role,
    ),
  );
}

class _DiaryCardColorDialog extends StatefulWidget {
  const _DiaryCardColorDialog({
    required this.title,
    required this.initialLight,
    required this.initialDark,
    required this.role,
  });

  final String title;
  final int initialLight;
  final int? initialDark;
  final DiaryCardColorRole role;

  @override
  State<_DiaryCardColorDialog> createState() => _DiaryCardColorDialogState();
}

class _DiaryCardColorDialogState extends State<_DiaryCardColorDialog> {
  static final RegExp _hexPattern = RegExp(r'^#?[0-9a-fA-F]{6}$');

  late int _light = widget.initialLight;
  late int? _dark = widget.initialDark;
  bool _editingDark = false;
  late int _familyIndex = _selectionFor(_currentValue).familyIndex;
  final TextEditingController _hexController = TextEditingController();
  bool _hexInvalid = false;

  bool get _darkAuto => _dark == null;

  int get _derivedDark =>
      DiaryCardColors.deriveDark(Color(_light), widget.role).toARGB32();

  int get _currentValue => _editingDark ? (_dark ?? _derivedDark) : _light;

  @override
  void initState() {
    super.initState();
    _hexController.text = _hex(_currentValue);
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  static ColorPaletteSelection _selectionFor(int value) =>
      resolveColorPaletteSelection(
        initialColor: value,
        fallbackFamilyIndex: 6,
        fallbackColorIndex: 5,
      );

  static String _hex(int value) =>
      (value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

  void _setCurrent(int value, {bool updateHex = true}) {
    setState(() {
      final opaque = 0xFF000000 | (value & 0xFFFFFF);
      if (_editingDark) {
        _dark = opaque;
      } else {
        _light = opaque;
      }
      final selection = _selectionFor(opaque);
      if (selection.colorValue == opaque) {
        _familyIndex = selection.familyIndex;
      }
      if (updateHex) {
        _hexController.text = _hex(opaque);
        _hexInvalid = false;
      }
    });
  }

  void _switchTarget(bool dark) {
    setState(() {
      _editingDark = dark;
      _familyIndex = _selectionFor(_currentValue).familyIndex;
      _hexController.text = _hex(_currentValue);
      _hexInvalid = false;
    });
  }

  void _onHexChanged(String raw) {
    final text = raw.trim();
    if (!_hexPattern.hasMatch(text)) {
      setState(() => _hexInvalid = text.isNotEmpty);
      return;
    }
    _setCurrent(
      int.parse(text.replaceFirst('#', ''), radix: 16),
      updateHex: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final current = _currentValue;
    final selection = _selectionFor(current);
    final family = kColorPaletteFamilies[_familyIndex];
    final showPicker = !_editingDark || !_darkAuto;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ExpressiveButtonGroup<bool>(
              minSegmentWidth: 88,
              segments: <ButtonSegment<bool>>[
                ButtonSegment<bool>(value: false, label: Text(l10n.autoT0047)),
                ButtonSegment<bool>(value: true, label: Text(l10n.autoT0048)),
              ],
              selected: <bool>{_editingDark},
              onSelectionChanged: (Set<bool> value) =>
                  _switchTarget(value.single),
            ),
            const SizedBox(height: 12),
            if (_editingDark) ...<Widget>[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _darkAuto,
                title: Text(l10n.diaryCardStyleColorDarkAuto),
                subtitle: Text(l10n.diaryCardStyleColorDarkAutoSubtitle),
                onChanged: (bool auto) {
                  setState(() {
                    _dark = auto ? null : _derivedDark;
                    _familyIndex = _selectionFor(_currentValue).familyIndex;
                    _hexController.text = _hex(_currentValue);
                    _hexInvalid = false;
                  });
                },
              ),
              if (_darkAuto)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Color(_derivedDark),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.5,
                            ),
                            width: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        colorSwatchHex(Color(_derivedDark)),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (showPicker) ...<Widget>[
              PaletteColorPicker(
                selectedColor: Color(current),
                selectedFamilyIndex: _familyIndex,
                selectedColorIndex: selection.colorValue == current
                    ? selection.colorIndex
                    : -1,
                selectedFamily: family,
                onSelectFamily: (int index) {
                  setState(() => _familyIndex = index);
                  _setCurrent(
                    kColorPaletteFamilies[index].colors[0].toARGB32(),
                  );
                },
                onSelectColor: (Color color) => _setCurrent(color.toARGB32()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _hexController,
                decoration: InputDecoration(
                  labelText: l10n.diaryCardStyleHexLabel,
                  prefixText: '#',
                  // 长度上限只用来拦截粘贴的长文本，不显示计数。
                  counterText: '',
                  errorText: _hexInvalid ? l10n.diaryCardStyleHexInvalid : null,
                ),
                maxLength: 7,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp('[#0-9a-fA-F]')),
                ],
                onChanged: _onHexChanged,
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.onSurfaceVariant,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
          onPressed: () => Navigator.of(
            context,
          ).pop(DiaryCardCustomColor(light: _light, dark: _dark)),
          child: Text(l10n.commonConfirm),
        ),
      ],
    );
  }
}
