import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../calendar/widgets/calendar_options_controls.dart';
import '../../settings/widgets/style_editor/style_editor_common.dart';
import '../../widgets/app_modal/app_dialog.dart';
import '../../widgets/color_palette_families.dart';
import '../../widgets/color_swatch_button.dart';
import '../controllers/notebook_editor_controller.dart';
import '../models/notebook_icon.dart';
import '../widgets/notebook_icon_grid.dart';

/// 快速新建日记本的弹窗：名称、紧凑的颜色行与图标行（常用 6 个，“更多”
/// 展开全部）。创建成功返回新日记本的业务 id，取消返回 null。
///
/// 供收录选择器等“边选边建”的场景使用；完整设置（封面、隐私、排序、模板）
/// 仍在编辑页。
Future<String?> showQuickCreateNotebookDialog(
  BuildContext context, {
  String? initialName,
}) {
  return showAppDialog<String>(
    context: context,
    builder: (BuildContext _) =>
        _QuickCreateNotebookDialog(initialName: initialName),
  );
}

class _QuickCreateNotebookDialog extends ConsumerStatefulWidget {
  const _QuickCreateNotebookDialog({this.initialName});

  final String? initialName;

  @override
  ConsumerState<_QuickCreateNotebookDialog> createState() =>
      _QuickCreateNotebookDialogState();
}

class _QuickCreateNotebookDialogState
    extends ConsumerState<_QuickCreateNotebookDialog> {
  // 控制器跟随对话框生命周期释放：关闭动画期间仍可能重建。
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName ?? '',
  )..addListener(_changed);
  NotebookIcon _icon = NotebookIcon.fallback;
  int? _color;
  bool _allIcons = false;
  bool _saving = false;

  bool get _canSubmit => _name.text.trim().isNotEmpty && !_saving;

  void _changed() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _saving = true);
    try {
      final id = await ref
          .read(appDatabaseProvider)
          .createNotebook(
            name: _name.text,
            payload: NotebookPayload(icon: _icon.name, color: _color),
          );
      if (mounted) Navigator.of(context).pop(id);
    } catch (error) {
      debugPrint('Quick-creating notebook failed: $error');
      if (!mounted) return;
      setState(() => _saving = false);
      showStyleEditorMessage(context, context.l10n.notebookSaveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.notebookNew),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: NotebookEditorController.maxNameLength,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.notebookNameLabel,
                hintText: l10n.notebookNameHint,
              ),
              onSubmitted: (_) => unawaited(_submit()),
            ),
            const SizedBox(height: AppSpacing.s),
            CalendarOptionsFieldLabel(text: l10n.notebookColorLabel),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                ChoiceChip(
                  label: Text(l10n.notebookColorFollowTheme),
                  selected: _color == null,
                  onSelected: (_) => setState(() => _color = null),
                ),
                for (final family in kColorPaletteFamilies)
                  ColorSwatchButton(
                    color: family.colors[5],
                    selected: _color == family.colors[5].toARGB32(),
                    semanticLabel: l10n.colorSwatchLabel(
                      colorSwatchHex(family.colors[5]),
                    ),
                    onTap: () =>
                        setState(() => _color = family.colors[5].toARGB32()),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            CalendarOptionsFieldLabel(text: l10n.notebookIconLabel),
            AnimatedSize(
              duration: ExpressiveMotion.durationNonZero(
                context,
                ExpressiveMotion.medium,
              ),
              curve: ExpressiveMotion.effects,
              alignment: Alignment.topCenter,
              child: NotebookIconGrid(
                selected: _icon,
                color: _color,
                icons: _allIcons
                    ? NotebookIcon.values
                    : <NotebookIcon>[
                        ...NotebookIcon.common,
                        // 在“更多”里选过的图标收起后仍然看得到。
                        if (!NotebookIcon.common.contains(_icon)) _icon,
                      ],
                onSelected: (icon) => setState(() => _icon = icon),
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => setState(() => _allIcons = !_allIcons),
                icon: FaIcon(
                  _allIcons
                      ? FontAwesomeIcons.angleUp
                      : FontAwesomeIcons.angleDown,
                  size: 14,
                ),
                label: Text(
                  _allIcons ? l10n.notebookIconLess : l10n.notebookIconMore,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          style: TextButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: scheme.primary,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
          onPressed: _canSubmit ? () => unawaited(_submit()) : null,
          child: Text(l10n.commonCreate),
        ),
      ],
    );
  }
}
