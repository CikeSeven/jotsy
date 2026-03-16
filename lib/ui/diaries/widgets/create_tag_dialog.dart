import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/widgets/color_palette_families.dart';

/// 弹窗创建标签时的临时数据对象。
class NewTagDraft {
  const NewTagDraft({required this.name, required this.color});

  final String name;
  final int color;
}

/// 展示“新建标签”弹窗并返回输入结果。
///
/// - 返回 `null` 表示取消
/// - 返回 `NewTagDraft` 表示输入合法可提交
Future<NewTagDraft?> showCreateTagDialog(BuildContext context) async {
  return showTagDraftDialog(
    context,
    title: context.l10n.autoT0040,
    actionLabel: context.l10n.commonCreate,
  );
}

/// 展示“编辑标签”弹窗并返回输入结果。
Future<NewTagDraft?> showEditTagDialog(
  BuildContext context, {
  required String initialName,
  required int initialColor,
}) async {
  return showTagDraftDialog(
    context,
    title: context.l10n.autoT0149,
    actionLabel: context.l10n.commonSave,
    initialName: initialName,
    initialColor: initialColor,
  );
}

/// 统一标签草稿弹窗（新建/编辑共用同一套视觉与交互）。
Future<NewTagDraft?> showTagDraftDialog(
  BuildContext context, {
  required String title,
  required String actionLabel,
  String? initialName,
  int? initialColor,
}) async {
  return showDialog<NewTagDraft>(
    context: context,
    builder:
        (BuildContext _) => _CreateTagDialog(
          title: title,
          actionLabel: actionLabel,
          initialName: initialName,
          initialColor: initialColor,
        ),
  );
}

class _CreateTagDialog extends StatefulWidget {
  const _CreateTagDialog({
    required this.title,
    required this.actionLabel,
    this.initialName,
    this.initialColor,
  });

  final String title;
  final String actionLabel;
  final String? initialName;
  final int? initialColor;

  @override
  State<_CreateTagDialog> createState() => _CreateTagDialogState();
}

class _CreateTagDialogState extends State<_CreateTagDialog> {
  static const int _fallbackFamilyIndex = 3;
  static const int _fallbackColorIndex = 2;

  // 颜色体系：
  // - 顶部主色族用于粗粒度选择；
  // - 下方给出该色族下的多个可选色。
  // 输入与选择状态。
  late final TextEditingController _nameController;
  bool _colorPickerExpanded = false;
  int _selectedFamilyIndex = 0;
  int _selectedColorIndex = 0;
  late int _selectedColorValue;

  bool get _canSubmit => _nameController.text.trim().isNotEmpty;

  Color get _selectedColor => Color(_selectedColorValue);

  @override
  void initState() {
    super.initState();
    final initialSelection = _resolveInitialColorSelection();
    _selectedFamilyIndex = initialSelection.familyIndex;
    _selectedColorIndex = initialSelection.colorIndex;
    _selectedColorValue = initialSelection.colorValue;
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _nameController.addListener(_handleNameChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_handleNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  /// 标签名变化时刷新“创建按钮可用性”。
  void _handleNameChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// 切换主色族，并重置为该色族第一个颜色。
  void _selectFamily(int index) {
    setState(() {
      _selectedFamilyIndex = index;
      _selectedColorIndex = 0;
      _selectedColorValue = kColorPaletteFamilies[index].colors[0].toARGB32();
    });
  }

  /// 选择当前主色族下的具体颜色。
  void _selectColor(int index) {
    setState(() {
      _selectedColorIndex = index;
      _selectedColorValue =
          kColorPaletteFamilies[_selectedFamilyIndex].colors[index].toARGB32();
    });
  }

  /// 提交创建结果。
  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    Navigator.of(
      context,
    ).pop(NewTagDraft(name: name, color: _selectedColorValue));
  }

  ColorPaletteSelection _resolveInitialColorSelection() {
    return resolveColorPaletteSelection(
      initialColor: widget.initialColor,
      fallbackFamilyIndex: _fallbackFamilyIndex,
      fallbackColorIndex: _fallbackColorIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _nameController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(labelText: l10n.autoT0150),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            // 颜色选择区域的展开/收起入口。
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() => _colorPickerExpanded = !_colorPickerExpanded);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: _selectedColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.autoT0151,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      _colorPickerExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            // 展开后展示两层颜色选择：
            // 1) 主色族横向卡片；
            // 2) 具体颜色圆点网格。
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List<Widget>.generate(
                          kColorPaletteFamilies.length,
                          (index) {
                            final family = kColorPaletteFamilies[index];
                            final selected = _selectedFamilyIndex == index;
                            return Padding(
                              padding: EdgeInsets.only(
                                right:
                                    index == kColorPaletteFamilies.length - 1
                                        ? 0
                                        : 10,
                              ),
                              child: GestureDetector(
                                onTap: () => _selectFamily(index),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: family.colors[2],
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color:
                                          selected
                                              ? colorScheme.onSurface
                                              : colorScheme.outlineVariant,
                                      width: selected ? 2.2 : 1.2,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: List<Widget>.generate(
                        kColorPaletteFamilies[_selectedFamilyIndex]
                            .colors
                            .length,
                        (index) {
                          final color =
                              kColorPaletteFamilies[_selectedFamilyIndex]
                                  .colors[index];
                          final selected = _selectedColorIndex == index;
                          return GestureDetector(
                            onTap: () => _selectColor(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      selected
                                          ? colorScheme.onSurface
                                          : colorScheme.outlineVariant,
                                  width: selected ? 2.4 : 1.2,
                                ),
                              ),
                              child:
                                  selected
                                      ? Icon(
                                        Icons.check_rounded,
                                        size: 18,
                                        color:
                                            ThemeData.estimateBrightnessForColor(
                                                      color,
                                                    ) ==
                                                    Brightness.dark
                                                ? Colors.white
                                                : Colors.black87,
                                      )
                                      : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              crossFadeState:
                  _colorPickerExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 180),
            ),
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
          style: TextButton.styleFrom(
            foregroundColor:
                _canSubmit ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
          onPressed: _canSubmit ? _submit : null,
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }
}
