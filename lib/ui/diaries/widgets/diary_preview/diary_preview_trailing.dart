import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../ai/sections/ai_replies_section.dart';
import '../../../todos/widgets/diary_linked_todos_section.dart';
import '../../viewmodels/diary_preview_resolved_style.dart';
import '../diary_comments/diary_comments_section.dart';
import '../diary_link/diary_backlinks_section.dart';
import 'diary_preview_body.dart';

/// 正文之后的页尾各块（含各自上方的间距）：“最后编辑于”、提到这篇的日记、
/// 相关待办（待办功能开启且有关联时）、留言区与 AI 回应。预览页的正文列与
/// 阅读式编辑页的编辑器页尾共用，两处的顺序与间距一致；为 null 的块不出现、
/// 不占位。
///
/// 返回子组件列表而不是一个 Column：预览页把它们直接排进正文那一列，组件
/// 结构与抽出之前相同。
List<Widget> diaryPreviewTrailing(
  BuildContext context, {
  required String diaryId,
  required DiaryPreviewResolvedStyle resolved,
  String? editedLabel,
  DiaryPreviewBacklinks? backlinks,
  DiaryPreviewComments? comments,
  String? aiRepliesFor,
  ValueChanged<AiResultRow>? onAiContinueChat,
}) {
  return <Widget>[
    if (editedLabel != null) ...<Widget>[
      const SizedBox(height: 16),
      DiaryPreviewEditedLine(label: editedLabel),
    ],
    if (backlinks != null) ...<Widget>[
      const SizedBox(height: 28),
      DiaryBacklinksSection(data: backlinks, textColor: resolved.bodyColor),
    ],
    // 自己判断待办功能与有没有关联的待办，不显示时连间距一起不占位。
    DiaryLinkedTodosSection(
      key: ValueKey<String>('diary_linked_todos_$diaryId'),
      diaryId: diaryId,
      textColor: resolved.bodyColor,
    ),
    if (comments != null) ...<Widget>[
      const SizedBox(height: 28),
      DiaryCommentsSection(
        key: ValueKey<String>('diary_comments_$diaryId'),
        data: comments,
        textColor: resolved.bodyColor,
      ),
    ],
    if (aiRepliesFor != null) ...<Widget>[
      const SizedBox(height: 28),
      AiRepliesSection(
        key: ValueKey<String>('ai_replies_$aiRepliesFor'),
        diaryId: aiRepliesFor,
        textColor:
            resolved.bodyColor ?? Theme.of(context).colorScheme.onSurface,
        onContinueChat: onAiContinueChat,
      ),
    ],
  ];
}
