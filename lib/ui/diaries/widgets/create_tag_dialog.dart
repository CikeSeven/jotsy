import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/widgets/color_palette_families.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/color_palette_picker.dart';

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
    builder: (BuildContext _) => _CreateTagDialog(
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

  // 颜色体系见 ColorPalettePicker：顶部主色族粗选，下方选该色族里的具体颜色。
  // 输入与选择状态。
  late final TextEditingController _nameController;
  bool _colorPickerExpanded = false;
  late int _selectedColorValue;

  bool get _canSubmit => _nameController.text.trim().isNotEmpty;

  Color get _selectedColor => Color(_selectedColorValue);

  @override
  void initState() {
    super.initState();
    _selectedColorValue = _resolveInitialColorSelection().colorValue;
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
            if (_nameController.text.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: _selectedColor.withValues(
                    alpha: colorScheme.brightness == Brightness.light
                        ? 0.08
                        : 0.16,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _selectedColor.withValues(
                      alpha: colorScheme.brightness == Brightness.light
                          ? 0.22
                          : 0.32,
                    ),
                    width: 0.65,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '#',
                      style: TextStyle(
                        color: _selectedColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _nameController.text.trim(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _selectedColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.4,
                          ),
                          width: 1,
                        ),
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
                    FaIcon(
                      _colorPickerExpanded
                          ? FontAwesomeIcons.angleUp
                          : FontAwesomeIcons.angleDown,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            // 展开后展示两层颜色选择（主色族 + 具体颜色，见 ColorPalettePicker）。
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ColorPalettePicker(
                  selectedColor: _selectedColorValue,
                  fallbackFamilyIndex: _fallbackFamilyIndex,
                  onSelected: (color) =>
                      setState(() => _selectedColorValue = color),
                ),
              ),
              crossFadeState: _colorPickerExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              // AnimatedCrossFade 内部用 AnimatedSize 过渡高度，减少动画时同样
              // 不能传 0 时长（见 ExpressiveMotion.durationNonZero）。
              duration: ExpressiveMotion.durationNonZero(
                context,
                ExpressiveMotion.fast,
              ),
              sizeCurve: ExpressiveMotion.effects,
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
            foregroundColor: _canSubmit
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
          onPressed: _canSubmit ? _submit : null,
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }
}
