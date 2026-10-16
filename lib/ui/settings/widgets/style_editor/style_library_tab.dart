import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/style_library/saved_style.dart';
import '../../../diaries/models/style_library/style_code.dart';
import '../../controllers/style_editor_controller.dart';
import '../settings_card_group.dart';
import 'style_editor_common.dart';
import 'style_preset_grid.dart';

/// 样式编辑页的“预设”标签页：内置风格、我的样式（保存 / 重命名 / 删除）与
/// 样式码分享导入。会整体替换当前样式的操作都给撤销提示。
///
/// [S] 样式类型，[L] 设置整体，[P] 内置预设的标识；预设的匹配与套用由
/// 具体页面提供（[matchingPreset]、[applyPreset]）。
class StyleLibraryTab<S, L extends StyleLibrary<S, L>, P>
    extends StatelessWidget {
  const StyleLibraryTab({
    super.key,
    required this.controller,
    required this.presets,
    required this.matchingPreset,
    required this.applyPreset,
  });

  final StyleEditorController<S, L> controller;
  final List<StylePresetOption<P>> presets;

  /// 当前样式对应的内置预设；不是任何预设时为 null。
  final P? matchingPreset;

  /// 套用预设，返回此前的样式供撤销。
  final Future<S> Function(P id) applyPreset;

  String _presetName(P id) =>
      presets.firstWhere((option) => option.id == id).name;

  Future<void> _applyPreset(BuildContext context, P id) async {
    if (matchingPreset == id) {
      return;
    }
    final message = context.l10n.styleEditorApplied(_presetName(id));
    final previous = await applyPreset(id);
    if (!context.mounted) {
      return;
    }
    unawaited(
      showStyleEditorUndoSnackBar(
        context,
        message: message,
        onUndo: () => controller.applyStyle(previous),
      ),
    );
  }

  Future<void> _applySaved(BuildContext context, SavedStyle<S> item) async {
    if (controller.style == item.style) {
      return;
    }
    final message = context.l10n.styleEditorApplied(item.name);
    final previous = await controller.applyStyle(item.style);
    if (!context.mounted) {
      return;
    }
    unawaited(
      showStyleEditorUndoSnackBar(
        context,
        message: message,
        onUndo: () => controller.applyStyle(previous),
      ),
    );
  }

  Future<void> _saveCurrent(BuildContext context) async {
    final l10n = context.l10n;
    final name = await showStyleEditorNameDialog(
      context,
      title: l10n.styleEditorSaveDialogTitle,
      initialName: l10n.styleEditorDefaultName(
        controller.settings.saved.length + 1,
      ),
    );
    if (name == null) {
      return;
    }
    final saved = await controller.saveCurrentAs(name);
    if (saved && context.mounted) {
      showStyleEditorMessage(context, l10n.styleEditorSavedDone(name));
    }
  }

  Future<void> _rename(BuildContext context, SavedStyle<S> item) async {
    final name = await showStyleEditorNameDialog(
      context,
      title: context.l10n.styleEditorRenameDialogTitle,
      initialName: item.name,
    );
    if (name != null) {
      await controller.renameSaved(item.id, name);
    }
  }

  Future<void> _delete(BuildContext context, SavedStyle<S> item) async {
    final message = context.l10n.styleEditorDeletedDone(item.name);
    final removed = await controller.deleteSaved(item.id);
    if (removed == null || !context.mounted) {
      return;
    }
    unawaited(
      showStyleEditorUndoSnackBar(
        context,
        message: message,
        onUndo: () => controller.restoreSaved(removed.$1, removed.$2),
      ),
    );
  }

  Future<void> _copyCode(BuildContext context) async {
    final message = context.l10n.styleEditorCodeCopied;
    final preset = matchingPreset;
    final code = controller.exportCode(
      name: preset == null ? null : _presetName(preset),
    );
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) {
      showStyleEditorMessage(context, message);
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
      case StyleCodeStatus.empty:
        showStyleEditorMessage(context, l10n.styleEditorImportEmpty);
      case StyleCodeStatus.invalid:
        showStyleEditorMessage(context, l10n.styleEditorImportInvalid);
      case StyleCodeStatus.ok || StyleCodeStatus.newerVersion:
        final message = result.status == StyleCodeStatus.newerVersion
            ? l10n.styleEditorImportNewer
            : name == null
            ? l10n.styleEditorImported
            : l10n.styleEditorImportedNamed(name);
        unawaited(
          showStyleEditorUndoSnackBar(
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
    const tilePadding = EdgeInsets.symmetric(horizontal: 16, vertical: 4);
    return StyleEditorTabList(
      children: <Widget>[
        SettingsCardGroup(
          title: l10n.styleEditorPresetsTitle,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: StylePresetGrid<P>(
                options: presets,
                selected: matchingPreset,
                onSelected: (id) => _applyPreset(context, id),
              ),
            ),
          ],
        ),
        SettingsCardGroup(
          title: l10n.styleEditorSavedTitle,
          footer: controller.canSaveMore
              ? null
              : l10n.styleEditorSaveLimit(SavedStyles.maxItems),
          children: <Widget>[
            if (saved.isEmpty)
              ListTile(
                contentPadding: tilePadding,
                subtitle: Text(l10n.styleEditorSavedEmpty),
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
                  tooltip: l10n.styleEditorSavedActions(item.name),
                  icon: const FaIcon(
                    FontAwesomeIcons.ellipsisVertical,
                    size: 16,
                  ),
                  onSelected: (bool rename) =>
                      rename ? _rename(context, item) : _delete(context, item),
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<bool>>[
                    PopupMenuItem<bool>(
                      value: true,
                      child: Text(l10n.styleEditorRename),
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
              contentPadding: tilePadding,
              enabled: controller.canSaveMore,
              leading: const FaIcon(FontAwesomeIcons.plus, size: 16),
              title: Text(l10n.styleEditorSaveCurrent),
              onTap: () => _saveCurrent(context),
            ),
          ],
        ),
        SettingsCardGroup(
          title: l10n.styleEditorShareTitle,
          children: <Widget>[
            ListTile(
              contentPadding: tilePadding,
              leading: const FaIcon(FontAwesomeIcons.copy, size: 16),
              title: Text(l10n.styleEditorCopyCode),
              subtitle: Text(l10n.styleEditorCopyCodeSubtitle),
              onTap: () => _copyCode(context),
            ),
            ListTile(
              contentPadding: tilePadding,
              leading: const FaIcon(FontAwesomeIcons.paste, size: 16),
              title: Text(l10n.styleEditorImportCode),
              subtitle: Text(l10n.styleEditorImportCodeSubtitle),
              onTap: () => _importCode(context),
            ),
          ],
        ),
      ],
    );
  }
}
