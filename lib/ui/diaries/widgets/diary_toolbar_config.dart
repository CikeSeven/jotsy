import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/expressive_controls.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';
import 'package:node_diary/core/services/diary_media_storage_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_table_editing.dart';
import 'package:node_diary/ui/diaries/controllers/diary_text_style_editing.dart';
import 'package:node_diary/ui/diaries/controllers/diary_toggle_editing.dart';
import 'package:node_diary/ui/diaries/models/diary_toolbar_layout.dart';
import 'package:node_diary/ui/diaries/models/diary_toolbar_preferences.dart';
import 'package:node_diary/ui/diaries/models/diary_text_style_options.dart';
import 'package:node_diary/ui/diaries/models/diary_toolbar_time_format.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';
import 'package:node_diary/ui/widgets/expressive_state_blend.dart';

import 'diary_link_dialog.dart';

/// 工具栏保持同一套尺寸与图标，动作直接作用于 AppFlowy 选区和节点。
const BoxConstraints kDiaryToolbarButtonConstraints = BoxConstraints.tightFor(
  width: 32,
  height: 32,
);

bool isDiaryToolbarItemActive(
  DiaryToolbarItem item,
  Map<String, Object?> attributes,
) => switch (item) {
  DiaryToolbarItem.bold => attributes['bold'] == true,
  DiaryToolbarItem.italic => attributes['italic'] == true,
  DiaryToolbarItem.underline => attributes['underline'] == true,
  DiaryToolbarItem.strikeThrough => attributes['strikethrough'] == true,
  DiaryToolbarItem.superscript =>
    attributes[kDiaryInlineScript] == kDiaryScriptSuper,
  DiaryToolbarItem.subscript =>
    attributes[kDiaryInlineScript] == kDiaryScriptSub,
  DiaryToolbarItem.inlineCode => attributes['code'] == true,
  DiaryToolbarItem.textColor => attributes['font_color'] != null,
  DiaryToolbarItem.backgroundColor => attributes['bg_color'] != null,
  DiaryToolbarItem.headerStyle => attributes['type'] == 'heading',
  DiaryToolbarItem.align =>
    DiaryTextAlign.fromAttribute(attributes['align']) != DiaryTextAlign.left,
  DiaryToolbarItem.fontSize => attributes['size'] != null,
  DiaryToolbarItem.orderedList => attributes['type'] == 'numbered_list',
  DiaryToolbarItem.bulletList => attributes['type'] == 'bulleted_list',
  DiaryToolbarItem.checkList => attributes['type'] == 'todo_list',
  DiaryToolbarItem.codeBlock => attributes['type'] == 'code',
  DiaryToolbarItem.quote => attributes['type'] == 'quote',
  // 光标在提示块里（选区的块都是提示块）；面板开着时由工具栏经
  // `panelOpen` 另行点亮。
  DiaryToolbarItem.callout => attributes['type'] == 'callout',
  // 光标在折叠块的标题里（选区的块都是折叠块）。
  DiaryToolbarItem.toggle => attributes['type'] == 'toggle_list',
  DiaryToolbarItem.indent =>
    attributes['depth'] is num && (attributes['depth'] as num) > 0,
  DiaryToolbarItem.link => attributes['href'] != null,
  _ => false,
};

/// 构建一个工具按钮。[onPressed] 给出时取代默认动作（有序 / 无序列表由
/// 工具栏决定转为列表还是打开列表面板，标题、对齐、字号打开各自的面板），
/// [panelOpen] 为它的面板正开着，与“选区正处在这种格式里”一样显示选中态。
/// 对齐按钮的图标随选区当前的对齐变化。
Widget buildDiaryToolbarItem(
  BuildContext context,
  DiaryToolbarItem item,
  DiaryEditorController controller, {
  VoidCallback? onPressed,
  bool panelOpen = false,
  String? currentTimeFormatPattern,
  VoidCallback? onRecordingPressed,
  bool recordingOpen = false,
  void Function(DiaryMediaKind)? onMediaPressed,
  DiaryMediaKind? activeMediaKind,
  bool mediaImportBusy = false,
}) {
  Widget button(DiaryToolbarItem tool, {bool outdent = false}) =>
      ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final kind = switch (tool) {
            DiaryToolbarItem.image => DiaryMediaKind.image,
            DiaryToolbarItem.video => DiaryMediaKind.video,
            DiaryToolbarItem.attachment => DiaryMediaKind.attachment,
            _ => null,
          };
          final active =
              panelOpen ||
              (tool == DiaryToolbarItem.recording && recordingOpen) ||
              isDiaryToolbarItemActive(tool, controller.activeAttributes);
          final enabled =
              !controller.readOnly &&
              switch (tool) {
                DiaryToolbarItem.undo => controller.hasUndo,
                DiaryToolbarItem.redo => controller.hasRedo,
                DiaryToolbarItem.recording =>
                  !mediaImportBusy && onRecordingPressed != null,
                DiaryToolbarItem.image ||
                DiaryToolbarItem.video ||
                DiaryToolbarItem.attachment =>
                  !mediaImportBusy && !recordingOpen && onMediaPressed != null,
                // 格子里只能放段落，不缩进（缩进即成为上一段的子块）。
                DiaryToolbarItem.indent =>
                  !diarySelectionInTable(controller) &&
                      (outdent
                          ? af.isOutdentable(controller.state)
                          : af.isIndentable(controller.state)),
                // 代码块里的文字是原文，不写上下标：选区只落在代码块里时停用。
                DiaryToolbarItem.superscript || DiaryToolbarItem.subscript =>
                  controller.selection == null ||
                      diaryTextStyleTargets(controller).isNotEmpty,
                _ => true,
              };
          return ExpressiveStateBlend(
            active: active,
            builder: (context, t, _) {
              final colors = Theme.of(context).colorScheme;
              return IconButton(
                tooltip: tool == DiaryToolbarItem.indent
                    ? (outdent
                          ? context.l10n.diaryEditorOutdent
                          : context.l10n.diaryEditorIndent)
                    : tool.label(context.l10n),
                onPressed: enabled
                    ? () {
                        if (onPressed != null) {
                          onPressed();
                          return;
                        }
                        if (kind != null) {
                          onMediaPressed!(kind);
                          return;
                        }
                        if (tool == DiaryToolbarItem.recording) {
                          onRecordingPressed!();
                          return;
                        }
                        if (tool == DiaryToolbarItem.currentTime) {
                          insertDiaryToolbarCurrentTime(
                            context,
                            controller,
                            formatPattern: currentTimeFormatPattern,
                          );
                          return;
                        }
                        if (tool == DiaryToolbarItem.link) {
                          unawaited(editDiaryLink(context, controller));
                          return;
                        }
                        _apply(tool, controller, outdent: outdent);
                      }
                    : null,
                constraints: kDiaryToolbarButtonConstraints,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                style: ButtonStyle(
                  tapTargetSize: MaterialTapTargetSize.padded,
                  shape: ExpressiveControls.shape,
                  backgroundColor: WidgetStatePropertyAll(
                    colors.primaryContainer.withValues(alpha: t),
                  ),
                  foregroundColor: WidgetStatePropertyAll(
                    Color.lerp(colors.onSurface, colors.onPrimaryContainer, t),
                  ),
                ),
                icon: kind != null && kind == activeMediaKind
                    ? ExpressiveLoadingIndicator(
                        size: 16,
                        semanticLabel: context.l10n.diaryMediaImporting,
                      )
                    : FaIcon(
                        outdent
                            ? FontAwesomeIcons.outdent
                            : tool == DiaryToolbarItem.align
                            ? diaryTextAlignIcon(
                                DiaryTextAlign.fromAttribute(
                                  controller.activeAttributes['align'],
                                ),
                              )
                            : tool.iconData,
                        size: 14,
                      ),
              );
            },
          );
        },
      );
  if (item == DiaryToolbarItem.indent) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(item),
        const SizedBox(width: kDiaryToolbarIndentGap),
        button(item, outdent: true),
      ],
    );
  }
  return button(item);
}

void _apply(
  DiaryToolbarItem item,
  DiaryEditorController controller, {
  bool outdent = false,
}) {
  final inline = switch (item) {
    DiaryToolbarItem.bold => 'bold',
    DiaryToolbarItem.italic => 'italic',
    DiaryToolbarItem.underline => 'underline',
    DiaryToolbarItem.strikeThrough => 'strikethrough',
    DiaryToolbarItem.inlineCode => 'code',
    _ => null,
  };
  if (inline != null) {
    controller.toggle(inline);
    return;
  }
  final type = switch (item) {
    DiaryToolbarItem.checkList => 'todo_list',
    DiaryToolbarItem.quote => 'quote',
    _ => null,
  };
  if (type != null) {
    controller.setBlockType(
      controller.activeAttributes['type'] == type ? 'paragraph' : type,
      attributes: type == 'todo_list' ? {'checked': false} : const {},
    );
    return;
  }
  switch (item) {
    case DiaryToolbarItem.superscript:
      toggleDiaryScript(controller, DiaryScript.superscript);
    case DiaryToolbarItem.subscript:
      toggleDiaryScript(controller, DiaryScript.subscript);
    case DiaryToolbarItem.toggle:
      // 不全是折叠块时转为折叠块，全是时转回正文（代码块除外）。
      toggleDiaryToggleBlocks(controller);
    case DiaryToolbarItem.undo:
      controller.undo();
    case DiaryToolbarItem.redo:
      controller.redo();
    case DiaryToolbarItem.indent:
      (outdent ? af.outdentCommand : af.indentCommand).handler(
        controller.state,
      );
    case DiaryToolbarItem.clearFormat:
      final transaction = controller.state.transaction;
      for (final node in controller.selectedNodes) {
        final delta = node.delta;
        if (delta == null) continue;
        final clean = af.Delta.fromJson([
          for (final op in delta) {'insert': (op as af.TextInsert).text},
        ]);
        transaction.updateNodeType(node, 'paragraph', {
          'delta': clean.toJson(),
        });
      }
      transaction.afterSelection = controller.selection;
      controller.apply(transaction);
    default:
      break;
  }
}

/// 对齐的图标：工具栏「对齐」按钮（按选区当前的对齐）与对齐面板共用。
FaIconData diaryTextAlignIcon(DiaryTextAlign align) => switch (align) {
  DiaryTextAlign.left => FontAwesomeIcons.alignLeft,
  DiaryTextAlign.center => FontAwesomeIcons.alignCenter,
  DiaryTextAlign.right => FontAwesomeIcons.alignRight,
  DiaryTextAlign.justify => FontAwesomeIcons.alignJustify,
};
