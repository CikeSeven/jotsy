import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../../settings/widgets/settings_reveal.dart';
import '../controllers/notebook_editor_controller.dart';
import '../providers/notebook_providers.dart';
import '../viewmodels/notebook_tree_rows.dart';
import 'notebook_parent_picker_sheet.dart';

/// 编辑页“上级日记本”（新建与编辑、普通与智能都有）：一行显示当前上级的
/// 完整路径（“旅行 › 2025”，没有则“无（放在书架上）”），点按打开上级选择
/// 面板（[showNotebookParentPickerSheet]，只列合法的上级）；分组下方说明
/// 父本汇总子本、最多三层。
///
/// 选择只改表单（`NotebookEditorController.parentId`），保存时由数据库层再
/// 校验一次，不合法时走页面已有的保存失败提示。智能日记本没有“隐私”分组，
/// 上级私密时的继承提示放在这一组里（普通日记本的在隐私分组里）。
class NotebookEditorParentSection extends ConsumerWidget {
  const NotebookEditorParentSection({super.key, required this.controller});

  final NotebookEditorController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tree = ref.watch(notebookTreeProvider);
    final parentId = controller.parentId;
    final parent = parentId == null ? null : tree?[parentId];
    final String summary;
    if (parentId == null) {
      summary = l10n.notebookParentNone;
    } else if (parent == null || tree == null) {
      // 书架还在读取（或上级刚被删掉，保存时由数据库层兜底）。
      summary = '';
    } else {
      summary = <String>[
        for (final ancestor in tree.ancestorsOf(parent.id)) ancestor.name,
        parent.name,
      ].join(l10n.notebookNestPathSeparator);
    }
    return SettingsCardGroup(
      title: l10n.notebookParentLabel,
      footer: l10n.notebookParentFooter,
      children: <Widget>[
        // 继承提示与它所从属的这一行合成分组里的同一项（见 SettingsReveal）。
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ListTile(
              key: const ValueKey<String>('notebook_editor_parent_tile'),
              titleAlignment: ListTileTitleAlignment.center,
              leading: FaIcon(
                FontAwesomeIcons.folderTree,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              title: Text(
                summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
              onTap: () => unawaited(_choose(context)),
            ),
            if (controller.isSmart)
              NotebookInheritedPrivacyNote(controller: controller),
          ],
        ),
      ],
    );
  }

  Future<void> _choose(BuildContext context) async {
    final choice = await showNotebookParentPickerSheet(
      context,
      childId: controller.notebookId,
      selectedParentId: controller.parentId,
    );
    if (choice != null) controller.parentId = choice.parentId;
  }
}

/// 上级私密时的继承提示：“上级「旅行」已上锁，这本也随之上锁”。只在所选
/// 上级的生效可见性比这本自己设的更严格时出现（[notebookInheritedPrivacy]），
/// 随所选上级与隐私选项变化展开 / 收起。
class NotebookInheritedPrivacyNote extends ConsumerWidget {
  const NotebookInheritedPrivacyNote({super.key, required this.controller});

  final NotebookEditorController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tree = ref.watch(notebookTreeProvider);
    final parentId = controller.parentId;
    final inherited = tree == null || parentId == null
        ? null
        : notebookInheritedPrivacy(
            tree,
            tree[parentId],
            controller.effectiveVisibility,
          );
    final Widget note;
    if (inherited == null) {
      note = const SizedBox.shrink();
    } else {
      final locked = inherited.visibility == NotebookVisibility.locked;
      final name = inherited.source.name;
      note = Padding(
        key: const ValueKey<String>('notebook_inherited_privacy'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.s,
          AppSpacing.l,
          AppSpacing.m,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: FaIcon(
                locked ? FontAwesomeIcons.lock : FontAwesomeIcons.eyeSlash,
                size: 13,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Text(
                locked
                    ? l10n.notebookParentPrivacyLocked(name)
                    : l10n.notebookParentPrivacyHidden(name),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return SettingsReveal(visible: inherited != null, child: note);
  }
}
