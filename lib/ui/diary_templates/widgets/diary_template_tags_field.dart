import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../diaries/widgets/create_tag_dialog.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../controllers/diary_template_editor_controller.dart';
import '../models/diary_template.dart';

/// 模板预设标签：`# 名称` 小胶囊（可移除）与“添加标签”。添加时可以选本机
/// 已有的标签，或输入一个新名称与颜色——新标签此时**不写库**，套用模板时
/// 本机没有才新建。
class DiaryTemplateTagsField extends StatelessWidget {
  const DiaryTemplateTagsField({super.key, required this.controller});

  final DiaryTemplateEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: AppSpacing.s,
      runSpacing: AppSpacing.s,
      children: <Widget>[
        for (final tag in controller.tags)
          InputChip(
            label: Text('# ${tag.name}'),
            avatar: CircleAvatar(backgroundColor: Color(tag.color), radius: 5),
            onDeleted: () => controller.removeTag(tag.name),
          ),
        if (controller.tags.length < DiaryTemplate.maxTags)
          ActionChip(
            avatar: const FaIcon(FontAwesomeIcons.plus, size: 12),
            label: Text(l10n.diaryTemplateEditorAddTag),
            onPressed: () async {
              final picked = await _pickTag(context, controller.tags);
              if (picked != null) controller.addTag(picked);
            },
          ),
      ],
    );
  }
}

/// 选一个标签：本机已有、还没加进模板的标签，最后一行“新建标签”。
Future<DiaryTemplateTagRef?> _pickTag(
  BuildContext context,
  List<DiaryTemplateTagRef> current,
) async {
  final choice = await showAppModalBottomSheet<Object>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) => _TagPickerBody(current: current),
  );
  if (choice is Tag) {
    return DiaryTemplateTagRef(name: choice.name, color: choice.color);
  }
  if (choice == _newTag && context.mounted) {
    final draft = await showCreateTagDialog(context);
    if (draft == null) return null;
    return DiaryTemplateTagRef(name: draft.name, color: draft.color);
  }
  return null;
}

const Object _newTag = Object();

class _TagPickerBody extends ConsumerWidget {
  const _TagPickerBody({required this.current});

  final List<DiaryTemplateTagRef> current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final taken = current.map((t) => t.name).toSet();
    final tags = (ref.watch(tagListProvider).asData?.value ?? const <Tag>[])
        .where((tag) => !taken.contains(tag.name))
        .toList(growable: false);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      builder: (BuildContext context, ScrollController controller) {
        return ListView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.l,
            0,
            AppSpacing.l,
            AppSpacing.l + MediaQuery.paddingOf(context).bottom,
          ),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xs,
                0,
                AppSpacing.xs,
                AppSpacing.m,
              ),
              child: Text(
                l10n.diaryTemplateEditorAddTag,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Wrap(
              spacing: AppSpacing.s,
              runSpacing: AppSpacing.s,
              children: <Widget>[
                for (final tag in tags)
                  ActionChip(
                    avatar: CircleAvatar(
                      backgroundColor: Color(tag.color),
                      radius: 5,
                    ),
                    label: Text('# ${tag.name}'),
                    onPressed: () => Navigator.of(context).pop(tag),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
              ),
              leading: FaIcon(
                FontAwesomeIcons.plus,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              title: Text(l10n.diaryTemplateEditorNewTag),
              onTap: () => Navigator.of(context).pop(_newTag),
            ),
          ],
        );
      },
    );
  }
}
