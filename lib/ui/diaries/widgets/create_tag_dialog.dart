import 'package:flutter/material.dart';

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
  return showDialog<NewTagDraft>(
    context: context,
    builder: (BuildContext _) => const _CreateTagDialog(),
  );
}

class _CreateTagDialog extends StatefulWidget {
  const _CreateTagDialog();

  @override
  State<_CreateTagDialog> createState() => _CreateTagDialogState();
}

class _CreateTagDialogState extends State<_CreateTagDialog> {
  // 颜色体系：
  // - 顶部主色族用于粗粒度选择；
  // - 下方给出该色族下的多个可选色。
  static const List<_ColorPaletteFamily> _families = <_ColorPaletteFamily>[
    _ColorPaletteFamily(
      label: '红',
      colors: <Color>[
        Color(0xFFFFEBEE),
        Color(0xFFFFCDD2),
        Color(0xFFE57373),
        Color(0xFFEF5350),
        Color(0xFFE53935),
        Color(0xFFD32F2F),
        Color(0xFFC62828),
        Color(0xFFB71C1C),
      ],
    ),
    _ColorPaletteFamily(
      label: '粉',
      colors: <Color>[
        Color(0xFFFCE4EC),
        Color(0xFFF8BBD0),
        Color(0xFFF48FB1),
        Color(0xFFF06292),
        Color(0xFFEC407A),
        Color(0xFFD81B60),
        Color(0xFFC2185B),
        Color(0xFF880E4F),
      ],
    ),
    _ColorPaletteFamily(
      label: '橙',
      colors: <Color>[
        Color(0xFFFFF3E0),
        Color(0xFFFFE0B2),
        Color(0xFFFFB74D),
        Color(0xFFFFA726),
        Color(0xFFFB8C00),
        Color(0xFFF57C00),
        Color(0xFFEF6C00),
        Color(0xFFE65100),
      ],
    ),
    _ColorPaletteFamily(
      label: '黄',
      colors: <Color>[
        Color(0xFFFFFDE7),
        Color(0xFFFFF9C4),
        Color(0xFFFFF176),
        Color(0xFFFFEE58),
        Color(0xFFFDD835),
        Color(0xFFFBC02D),
        Color(0xFFF9A825),
        Color(0xFFF57F17),
      ],
    ),
    _ColorPaletteFamily(
      label: '绿',
      colors: <Color>[
        Color(0xFFE8F5E9),
        Color(0xFFC8E6C9),
        Color(0xFFA5D6A7),
        Color(0xFF81C784),
        Color(0xFF66BB6A),
        Color(0xFF43A047),
        Color(0xFF2E7D32),
        Color(0xFF1B5E20),
      ],
    ),
    _ColorPaletteFamily(
      label: '青',
      colors: <Color>[
        Color(0xFFE0F7FA),
        Color(0xFFB2EBF2),
        Color(0xFF80DEEA),
        Color(0xFF4DD0E1),
        Color(0xFF26C6DA),
        Color(0xFF00ACC1),
        Color(0xFF00838F),
        Color(0xFF006064),
      ],
    ),
    _ColorPaletteFamily(
      label: '蓝',
      colors: <Color>[
        Color(0xFFE3F2FD),
        Color(0xFFBBDEFB),
        Color(0xFF90CAF9),
        Color(0xFF64B5F6),
        Color(0xFF42A5F5),
        Color(0xFF1E88E5),
        Color(0xFF1565C0),
        Color(0xFF0D47A1),
      ],
    ),
    _ColorPaletteFamily(
      label: '紫',
      colors: <Color>[
        Color(0xFFF3E5F5),
        Color(0xFFE1BEE7),
        Color(0xFFCE93D8),
        Color(0xFFBA68C8),
        Color(0xFFAB47BC),
        Color(0xFF8E24AA),
        Color(0xFF6A1B9A),
        Color(0xFF4A148C),
      ],
    ),
    _ColorPaletteFamily(
      label: '棕',
      colors: <Color>[
        Color(0xFFEFEBE9),
        Color(0xFFD7CCC8),
        Color(0xFFBCAAA4),
        Color(0xFFA1887F),
        Color(0xFF8D6E63),
        Color(0xFF6D4C41),
        Color(0xFF5D4037),
        Color(0xFF3E2723),
      ],
    ),
    _ColorPaletteFamily(
      label: '灰',
      colors: <Color>[
        Color(0xFFFAFAFA),
        Color(0xFFF5F5F5),
        Color(0xFFEEEEEE),
        Color(0xFFE0E0E0),
        Color(0xFFBDBDBD),
        Color(0xFF9E9E9E),
        Color(0xFF757575),
        Color(0xFF616161),
      ],
    ),
  ];

  // 输入与选择状态。
  final TextEditingController _nameController = TextEditingController();
  bool _colorPickerExpanded = false;
  int _selectedFamilyIndex = 3;
  int _selectedColorIndex = 2;
  late int _selectedColorValue;

  bool get _canSubmit => _nameController.text.trim().isNotEmpty;

  Color get _selectedColor => Color(_selectedColorValue);

  @override
  void initState() {
    super.initState();
    _selectedColorValue = _families[_selectedFamilyIndex]
        .colors[_selectedColorIndex]
        .toARGB32();
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
      _selectedColorValue = _families[index].colors[0].toARGB32();
    });
  }

  /// 选择当前主色族下的具体颜色。
  void _selectColor(int index) {
    setState(() {
      _selectedColorIndex = index;
      _selectedColorValue = _families[_selectedFamilyIndex]
          .colors[index]
          .toARGB32();
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      scrollable: true,
      title: const Text('新建标签'),
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
              decoration: const InputDecoration(labelText: '标签名'),
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
                        '选择颜色',
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
                        children: List<Widget>.generate(_families.length, (index) {
                          final family = _families[index];
                          final selected = _selectedFamilyIndex == index;
                          return Padding(
                            padding: EdgeInsets.only(
                              right: index == _families.length - 1 ? 0 : 10,
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
                                    color: selected
                                        ? colorScheme.onSurface
                                        : colorScheme.outlineVariant,
                                    width: selected ? 2.2 : 1.2,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: List<Widget>.generate(
                        _families[_selectedFamilyIndex].colors.length,
                        (index) {
                          final color = _families[_selectedFamilyIndex].colors[index];
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
                                  color: selected
                                      ? colorScheme.onSurface
                                      : colorScheme.outlineVariant,
                                  width: selected ? 2.4 : 1.2,
                                ),
                              ),
                              child: selected
                                  ? Icon(
                                      Icons.check_rounded,
                                      size: 18,
                                      color: ThemeData.estimateBrightnessForColor(color) ==
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
              crossFadeState: _colorPickerExpanded
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
          child: const Text('取消'),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: _canSubmit
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
          onPressed: _canSubmit ? _submit : null,
          child: const Text('创建'),
        ),
      ],
    );
  }
}

class _ColorPaletteFamily {
  const _ColorPaletteFamily({required this.label, required this.colors});

  final String label;
  final List<Color> colors;
}
