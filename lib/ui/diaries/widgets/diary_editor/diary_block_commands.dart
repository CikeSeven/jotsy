import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/services/diary_media_storage_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../models/diary_toolbar_preferences.dart';
import '../../controllers/diary_editor_controller.dart';
import '../../controllers/diary_editor_insert.dart';

/// 桌面选区菜单和手机命令面板共用同一份命令定义与事务。
class DiaryBlockCommand {
  const DiaryBlockCommand(
    this.type,
    this.label,
    this.icon,
    this.keywords, {
    this.action,
  });
  final String type;
  final String label;
  final FaIconData icon;
  final List<String> keywords;
  final VoidCallback? action;
  bool matches(String query) =>
      query.isEmpty ||
      [
        label,
        type,
        ...keywords,
      ].any((value) => value.toLowerCase().contains(query.toLowerCase()));
}

List<DiaryBlockCommand> diaryBlockCommands(
  AppLocalizations l10n, {
  void Function(DiaryMediaKind)? onMedia,
  VoidCallback? onRecording,
}) => [
  DiaryBlockCommand(
    'paragraph',
    l10n.diaryEditorParagraph,
    FontAwesomeIcons.paragraph,
    const ['text', '正文'],
  ),
  DiaryBlockCommand('heading', l10n.autoT0017, FontAwesomeIcons.heading, const [
    'heading',
    'title',
    '标题',
  ]),
  for (final item in [
    DiaryToolbarItem.bulletList,
    DiaryToolbarItem.orderedList,
    DiaryToolbarItem.checkList,
    DiaryToolbarItem.quote,
    DiaryToolbarItem.codeBlock,
  ])
    DiaryBlockCommand(
      switch (item) {
        DiaryToolbarItem.bulletList => 'bulleted_list',
        DiaryToolbarItem.orderedList => 'numbered_list',
        DiaryToolbarItem.checkList => 'todo_list',
        DiaryToolbarItem.quote => 'quote',
        _ => 'code',
      },
      item.label(l10n),
      item.iconData,
      [item.storageKey],
    ),
  DiaryBlockCommand(
    'divider',
    l10n.diaryEditorDivider,
    FontAwesomeIcons.minus,
    const ['hr', 'divider', '分隔线'],
  ),
  if (onMedia != null) ...[
    DiaryBlockCommand('image', l10n.autoT0016, FontAwesomeIcons.image, const [
      'photo',
      '图片',
    ], action: () => onMedia(DiaryMediaKind.image)),
    DiaryBlockCommand(
      'video',
      l10n.diaryToolbarInsertVideo,
      FontAwesomeIcons.video,
      const ['video', '视频'],
      action: () => onMedia(DiaryMediaKind.video),
    ),
    DiaryBlockCommand(
      'attachment',
      l10n.diaryToolbarInsertAttachment,
      FontAwesomeIcons.paperclip,
      const ['file', '附件'],
      action: () => onMedia(DiaryMediaKind.attachment),
    ),
  ],
  if (onRecording != null)
    DiaryBlockCommand(
      'audio',
      l10n.diaryToolbarRecording,
      FontAwesomeIcons.microphone,
      const ['recording', '录音'],
      action: onRecording,
    ),
];

void applyDiaryBlockCommand(
  DiaryEditorController controller,
  DiaryBlockCommand command,
) {
  if (controller.state.isDisposed || controller.readOnly) return;
  if (command.action != null) {
    command.action!();
    return;
  }
  if (command.type == 'divider') {
    insertDiaryEditorNodes(controller: controller, nodes: [af.dividerNode()]);
  } else {
    controller.setBlockType(
      command.type,
      attributes: {
        if (command.type == 'todo_list') 'checked': false,
        if (command.type == 'heading') 'level': 1,
      },
    );
  }
}
