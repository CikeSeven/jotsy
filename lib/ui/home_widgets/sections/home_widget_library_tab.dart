import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/services/home_widgets/home_widget_style.dart';
import '../../../l10n/app_localizations.dart';
import '../../diaries/models/style_library/saved_style.dart';
import '../../diaries/models/style_library/style_code.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../../settings/widgets/style_editor/style_editor_common.dart';
import '../../settings/widgets/style_editor/style_preset_grid.dart';
import '../../widgets/expressive_menu/expressive_menu.dart';
import '../controllers/home_widget_studio_controller.dart';
import '../controllers/home_widget_style_library_controller.dart';
import '../models/home_widget_style_library.dart';
import '../providers/home_widget_providers.dart';

/// 工作室「预设」标签页：内置外观、我的样式（保存 / 重命名 / 删除）与样式码分享
/// 导入，布局与文案同应用里各样式编辑页的“预设”页（`StyleLibraryTab`）。
///
/// 只换外观，内容选项不动；会整体替换当前外观的操作（套用、导入）都给撤销提示。
/// 外观与种类无关，预设与“我的样式”在所有种类之间共用。
class HomeWidgetLibraryTab extends ConsumerWidget {
  const HomeWidgetLibraryTab({
    super.key,
    required this.controller,
    required this.library,
  });

  final HomeWidgetStudioController controller;
  final HomeWidgetStyleLibraryController library;

  /// 换上 [style]，给出可撤销的提示。
  Future<void> _apply(
    BuildContext context,
    HomeWidgetStyle style,
    String message,
  ) async {
    final previous = controller.style;
    if (previous == style) return;
    controller.updateStyle(style);
    await showStyleEditorUndoSnackBar(
      context,
      message: message,
      onUndo: () => controller.updateStyle(previous),
    );
  }

  Future<void> _saveCurrent(BuildContext context) async {
    final l10n = context.l10n;
    final name = await showStyleEditorNameDialog(
      context,
      title: l10n.styleEditorSaveDialogTitle,
      initialName: l10n.styleEditorDefaultName(library.saved.length + 1),
    );
    if (name == null) return;
    final saved = await library.save(name, controller.style);
    if (saved && context.mounted) {
      showStyleEditorMessage(context, l10n.styleEditorSavedDone(name));
    }
  }

  Future<void> _rename(
    BuildContext context,
    SavedStyle<HomeWidgetStyle> item,
  ) async {
    final name = await showStyleEditorNameDialog(
      context,
      title: context.l10n.styleEditorRenameDialogTitle,
      initialName: item.name,
    );
    if (name != null) await library.rename(item.id, name);
  }

  Future<void> _delete(
    BuildContext context,
    SavedStyle<HomeWidgetStyle> item,
  ) async {
    final message = context.l10n.styleEditorDeletedDone(item.name);
    final removed = await library.delete(item.id);
    if (removed == null || !context.mounted) return;
    unawaited(
      showStyleEditorUndoSnackBar(
        context,
        message: message,
        onUndo: () => library.restore(removed.$1, removed.$2),
      ),
    );
  }

  Future<void> _copyCode(BuildContext context, String? name) async {
    final message = context.l10n.styleEditorCodeCopied;
    await Clipboard.setData(
      ClipboardData(
        text: homeWidgetStyleCode.encode(controller.style, name: name),
      ),
    );
    if (context.mounted) showStyleEditorMessage(context, message);
  }

  Future<void> _importCode(BuildContext context) async {
    final l10n = context.l10n;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!context.mounted) return;
    final result = homeWidgetStyleCode.decode(data?.text);
    final style = result.style;
    switch (result.status) {
      case StyleCodeStatus.empty:
        showStyleEditorMessage(context, l10n.styleEditorImportEmpty);
      case StyleCodeStatus.invalid:
        showStyleEditorMessage(context, l10n.styleEditorImportInvalid);
      case StyleCodeStatus.ok || StyleCodeStatus.newerVersion:
        if (style == null) return;
        final name = result.name;
        await _apply(
          context,
          style,
          result.status == StyleCodeStatus.newerVersion
              ? l10n.styleEditorImportNewer
              : name == null
              ? l10n.styleEditorImported
              : l10n.styleEditorImportedNamed(name),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final saved = homeWidgetSavedStyles(ref.watch(homeWidgetSettingsProvider));
    final style = controller.style;
    final preset = HomeWidgetStylePreset.matching(style);
    final matchingSaved = SavedStyles.matching(saved, style);
    final canSaveMore = saved.length < SavedStyles.maxItems;
    const tilePadding = EdgeInsets.symmetric(horizontal: 16, vertical: 4);
    return StyleEditorTabList(
      children: <Widget>[
        SettingsCardGroup(
          title: l10n.styleEditorPresetsTitle,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: StylePresetGrid<HomeWidgetStylePreset>(
                options: <StylePresetOption<HomeWidgetStylePreset>>[
                  for (final option in HomeWidgetStylePreset.values)
                    StylePresetOption<HomeWidgetStylePreset>(
                      id: option,
                      icon: option.icon,
                      name: option.name(l10n),
                      description: option.description(l10n),
                    ),
                ],
                selected: preset,
                onSelected: (HomeWidgetStylePreset option) => _apply(
                  context,
                  option.style,
                  l10n.styleEditorApplied(option.name(l10n)),
                ),
              ),
            ),
          ],
        ),
        SettingsCardGroup(
          title: l10n.styleEditorSavedTitle,
          footer: canSaveMore
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
                onTap: () => _apply(
                  context,
                  item.style,
                  l10n.styleEditorApplied(item.name),
                ),
                trailing: ExpressiveMenuButton(
                  tooltip: l10n.styleEditorSavedActions(item.name),
                  icon: const FaIcon(
                    FontAwesomeIcons.ellipsisVertical,
                    size: 16,
                  ),
                  items: <Widget>[
                    ExpressiveMenuItem(
                      leadingIcon: const FaIcon(FontAwesomeIcons.penToSquare),
                      onPressed: () => _rename(context, item),
                      child: Text(l10n.styleEditorRename),
                    ),
                    ExpressiveMenuItem(
                      leadingIcon: const FaIcon(FontAwesomeIcons.trashCan),
                      destructive: true,
                      onPressed: () => _delete(context, item),
                      child: Text(l10n.commonDelete),
                    ),
                  ],
                ),
              ),
            ListTile(
              contentPadding: tilePadding,
              enabled: canSaveMore,
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
              onTap: () =>
                  _copyCode(context, preset?.name(l10n) ?? matchingSaved?.name),
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
