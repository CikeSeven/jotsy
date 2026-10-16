import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/diary_card_style/diary_card_style_code.dart';
import '../../../diaries/models/diary_card_style/diary_card_style_presets.dart';
import '../../../diaries/models/diary_card_style/diary_card_style_settings.dart';
import '../../controllers/diary_card_style_editor_controller.dart';
import '../../widgets/settings_card_group.dart';
import 'diary_card_style_common.dart';
import 'diary_card_style_labels.dart';
import 'diary_card_style_preset_grid.dart';

/// “预设”标签页：内置风格、我的样式（保存/重命名/删除）与样式码分享导入。
/// 会整体替换当前样式的操作都给撤销提示。
class DiaryCardStylePresetsTab extends StatelessWidget {
  const DiaryCardStylePresetsTab({super.key, required this.controller});

  final DiaryCardStyleEditorController controller;

  Future<void> _applyPreset(BuildContext context, DiaryCardPresetId id) async {
    if (controller.matchingPreset == id) {
      return;
    }
    final l10n = context.l10n;
    final previous = await controller.applyPreset(id);
    if (!context.mounted) {
      return;
    }
    unawaited(
      showDiaryCardStyleUndoSnackBar(
        context,
        message: l10n.diaryCardStyleApplied(diaryCardPresetName(l10n, id)),
        onUndo: () => controller.applyStyle(previous),
      ),
    );
  }

  Future<void> _applySaved(
    BuildContext context,
    DiaryCardSavedStyle item,
  ) async {
    if (controller.style == item.style) {
      return;
    }
    final message = context.l10n.diaryCardStyleApplied(item.name);
    final previous = await controller.applyStyle(item.style);
    if (!context.mounted) {
      return;
    }
    unawaited(
      showDiaryCardStyleUndoSnackBar(
        context,
        message: message,
        onUndo: () => controller.applyStyle(previous),
      ),
    );
  }

  Future<void> _saveCurrent(BuildContext context) async {
    final l10n = context.l10n;
    final name = await showDiaryCardStyleNameDialog(
      context,
      title: l10n.diaryCardStyleSaveDialogTitle,
      initialName: l10n.diaryCardStyleDefaultName(
        controller.settings.saved.length + 1,
      ),
    );
    if (name == null) {
      return;
    }
    final saved = await controller.saveCurrentAs(name);
    if (saved && context.mounted) {
      showDiaryCardStyleMessage(context, l10n.diaryCardStyleSavedDone(name));
    }
  }

  Future<void> _rename(BuildContext context, DiaryCardSavedStyle item) async {
    final name = await showDiaryCardStyleNameDialog(
      context,
      title: context.l10n.diaryCardStyleRenameDialogTitle,
      initialName: item.name,
    );
    if (name != null) {
      await controller.renameSaved(item.id, name);
    }
  }

  Future<void> _delete(BuildContext context, DiaryCardSavedStyle item) async {
    final message = context.l10n.diaryCardStyleDeletedDone(item.name);
    final removed = await controller.deleteSaved(item.id);
    if (removed == null || !context.mounted) {
      return;
    }
    unawaited(
      showDiaryCardStyleUndoSnackBar(
        context,
        message: message,
        onUndo: () => controller.restoreSaved(removed.$1, removed.$2),
      ),
    );
  }

  Future<void> _copyCode(BuildContext context) async {
    final message = context.l10n.diaryCardStyleCodeCopied;
    final preset = controller.matchingPreset;
    final code = controller.exportCode(
      name: preset == null ? null : diaryCardPresetName(context.l10n, preset),
    );
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) {
      showDiaryCardStyleMessage(context, message);
    }
  }

  Future<void> _importCode(BuildContext context) async {
    final l10n = context.l10n;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final (result, previous) = await controller.importCode(data?.text);
    if (!context.mounted) {
      return;
    }
    final name = result.name;
    switch (result.status) {
      case DiaryCardStyleCodeStatus.empty:
        showDiaryCardStyleMessage(context, l10n.diaryCardStyleImportEmpty);
      case DiaryCardStyleCodeStatus.invalid:
        showDiaryCardStyleMessage(context, l10n.diaryCardStyleImportInvalid);
      case DiaryCardStyleCodeStatus.ok || DiaryCardStyleCodeStatus.newerVersion:
        final message = result.status == DiaryCardStyleCodeStatus.newerVersion
            ? l10n.diaryCardStyleImportNewer
            : name == null
            ? l10n.diaryCardStyleImported
            : l10n.diaryCardStyleImportedNamed(name);
        unawaited(
          showDiaryCardStyleUndoSnackBar(
            context,
            message: message,
            onUndo: () {
              if (previous != null) {
                controller.applyStyle(previous);
              }
            },
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final saved = controller.settings.saved;
    final matchingSaved = controller.matchingSaved;
    return DiaryCardStyleTabList(
      children: <Widget>[
        SettingsCardGroup(
          title: l10n.diaryCardStylePresetsTitle,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: DiaryCardPresetGrid(
                selected: controller.matchingPreset,
                onSelected: (id) => _applyPreset(context, id),
              ),
            ),
          ],
        ),
        SettingsCardGroup(
          title: l10n.diaryCardStyleSavedTitle,
          footer: controller.canSaveMore
              ? null
              : l10n.diaryCardStyleSaveLimit(DiaryCardStyleSettings.maxSaved),
          children: <Widget>[
            if (saved.isEmpty)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                subtitle: Text(l10n.diaryCardStyleSavedEmpty),
              ),
            for (final item in saved)
              ListTile(
                contentPadding: const EdgeInsetsDirectional.only(
                  start: 16,
                  end: 4,
                ),
                leading: const FaIcon(FontAwesomeIcons.swatchbook, size: 16),
                title: Text(item.name),
                selected: identical(item, matchingSaved),
                onTap: () => _applySaved(context, item),
                trailing: PopupMenuButton<bool>(
                  tooltip: l10n.diaryCardStyleSavedActions(item.name),
                  icon: const FaIcon(
                    FontAwesomeIcons.ellipsisVertical,
                    size: 16,
                  ),
                  onSelected: (bool rename) =>
                      rename ? _rename(context, item) : _delete(context, item),
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<bool>>[
                    PopupMenuItem<bool>(
                      value: true,
                      child: Text(l10n.diaryCardStyleRename),
                    ),
                    PopupMenuItem<bool>(
                      value: false,
                      child: Text(
                        l10n.commonDelete,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              enabled: controller.canSaveMore,
              leading: const FaIcon(FontAwesomeIcons.plus, size: 16),
              title: Text(l10n.diaryCardStyleSaveCurrent),
              onTap: () => _saveCurrent(context),
            ),
          ],
        ),
        SettingsCardGroup(
          title: l10n.diaryCardStyleShareTitle,
          children: <Widget>[
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: const FaIcon(FontAwesomeIcons.copy, size: 16),
              title: Text(l10n.diaryCardStyleCopyCode),
              subtitle: Text(l10n.diaryCardStyleCopyCodeSubtitle),
              onTap: () => _copyCode(context),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: const FaIcon(FontAwesomeIcons.paste, size: 16),
              title: Text(l10n.diaryCardStyleImportCode),
              subtitle: Text(l10n.diaryCardStyleImportCodeSubtitle),
              onTap: () => _importCode(context),
            ),
          ],
        ),
      ],
    );
  }
}
