import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/services/diary_media_storage_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../utils/pinyin/name_index.dart';
import '../../models/diary_toolbar_preferences.dart';
import '../../controllers/diary_editor_controller.dart';
import '../../controllers/diary_editor_insert.dart';

/// 命令菜单里的分组，按此顺序排列。
enum DiaryBlockCommandGroup { text, list, insert }

/// 桌面选区菜单和手机 `/` 菜单共用同一份命令定义与事务。
class DiaryBlockCommand {
  const DiaryBlockCommand(
    this.type,
    this.label,
    this.icon,
    this.keywords, {
    required this.group,
    this.markdown,
    this.attributes = const {},
    this.action,
  });

  /// 目标块类型（转换类命令）或插入的内容类型。
  final String type;
  final String label;
  final FaIconData icon;
  final List<String> keywords;
  final DiaryBlockCommandGroup group;

  /// 对应的 Markdown 快捷输入（如 `##`、`-`），菜单行尾展示，顺带教用户
  /// 下次直接输入；没有对应写法时为 null。
  final String? markdown;

  /// 转换时写入的块属性（标题级别等）。
  final Map<String, Object> attributes;
  final VoidCallback? action;

  /// 筛选规则：
  /// - 类型、关键词与 Markdown 写法按前缀匹配——单个字母若按包含匹配，
  ///   `/h` 会因 paragraph、checkList 里有 h 而把正文、待办也列进来；
  /// - 名称按包含匹配（中文名常从中间输入，如“代码”）；两个字符起再认
  ///   拼音（[NameIndexKey]：全拼前缀与首字母，如 `/biaoti`、`/dmk`），
  ///   软键盘不用切到中文输入法也能找到。单个字母不认拼音首字母，否则
  ///   `/h` 会因“多行（duo hang）”命中代码块。
  bool matches(String query) {
    if (query.isEmpty) return true;
    final needle = query.toLowerCase();
    if ([
      type,
      ?markdown,
      ...keywords,
    ].any((value) => value.toLowerCase().startsWith(needle))) {
      return true;
    }
    if (label.toLowerCase().contains(needle)) return true;
    return needle.length >= 2 &&
        NameIndexKey.of(label).matches(normalizeNameQuery(query));
  }
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
    const ['text', 'p', '正文', '段落'],
    group: DiaryBlockCommandGroup.text,
  ),
  for (final (level, label) in [
    (1, l10n.diaryEditorHeading1),
    (2, l10n.diaryEditorHeading2),
    (3, l10n.diaryEditorHeading3),
    (4, l10n.diaryEditorHeading4),
    (5, l10n.diaryEditorHeading5),
    (6, l10n.diaryEditorHeading6),
  ])
    DiaryBlockCommand(
      'heading',
      label,
      FontAwesomeIcons.heading,
      ['heading', 'h$level', 'title', '标题'],
      group: DiaryBlockCommandGroup.text,
      markdown: '#' * level,
      attributes: {'level': level},
    ),
  DiaryBlockCommand(
    'quote',
    DiaryToolbarItem.quote.label(l10n),
    DiaryToolbarItem.quote.iconData,
    const ['quote', 'blockquote', '引用'],
    group: DiaryBlockCommandGroup.text,
    markdown: '>',
  ),
  DiaryBlockCommand(
    'code',
    DiaryToolbarItem.codeBlock.label(l10n),
    DiaryToolbarItem.codeBlock.iconData,
    const ['code', 'codeblock', '代码'],
    group: DiaryBlockCommandGroup.text,
    markdown: '```',
  ),
  for (final (item, type, markdown) in [
    (DiaryToolbarItem.bulletList, 'bulleted_list', '-'),
    (DiaryToolbarItem.orderedList, 'numbered_list', '1.'),
    (DiaryToolbarItem.checkList, 'todo_list', '[]'),
  ])
    DiaryBlockCommand(
      type,
      item.label(l10n),
      item.iconData,
      [item.storageKey, 'list', '列表'],
      group: DiaryBlockCommandGroup.list,
      markdown: markdown,
      attributes: {if (type == 'todo_list') 'checked': false},
    ),
  DiaryBlockCommand(
    'divider',
    l10n.diaryEditorDivider,
    FontAwesomeIcons.minus,
    const ['hr', 'divider', 'line', '分隔线', '分割线'],
    group: DiaryBlockCommandGroup.insert,
    markdown: '---',
  ),
  if (onMedia != null) ...[
    DiaryBlockCommand(
      'image',
      l10n.autoT0016,
      FontAwesomeIcons.image,
      const ['image', 'photo', 'picture', '图片', '照片'],
      group: DiaryBlockCommandGroup.insert,
      action: () => onMedia(DiaryMediaKind.image),
    ),
    DiaryBlockCommand(
      'video',
      l10n.diaryToolbarInsertVideo,
      FontAwesomeIcons.video,
      const ['video', 'movie', '视频'],
      group: DiaryBlockCommandGroup.insert,
      action: () => onMedia(DiaryMediaKind.video),
    ),
    DiaryBlockCommand(
      'attachment',
      l10n.diaryToolbarInsertAttachment,
      FontAwesomeIcons.paperclip,
      const ['file', 'attachment', '附件', '文件'],
      group: DiaryBlockCommandGroup.insert,
      action: () => onMedia(DiaryMediaKind.attachment),
    ),
  ],
  if (onRecording != null)
    DiaryBlockCommand(
      'audio',
      l10n.diaryToolbarRecording,
      FontAwesomeIcons.microphone,
      const ['audio', 'recording', 'voice', '录音', '语音'],
      group: DiaryBlockCommandGroup.insert,
      action: onRecording,
    ),
];

/// 分组名称。
String diaryBlockCommandGroupLabel(
  AppLocalizations l10n,
  DiaryBlockCommandGroup group,
) => switch (group) {
  DiaryBlockCommandGroup.text => l10n.diaryEditorCommandGroupText,
  DiaryBlockCommandGroup.list => l10n.diaryEditorCommandGroupList,
  DiaryBlockCommandGroup.insert => l10n.diaryEditorCommandGroupInsert,
};

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
    controller.setBlockType(command.type, attributes: command.attributes);
  }
}
