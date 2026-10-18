import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:node_diary/core/database/divider_embed_codec.dart';

/// 正文分隔线（导入笔记的 `<hr>`、手机笔记的分隔线）：独占一行的细线，
/// 用 `outlineVariant` 跟随亮暗主题。编辑页里可以像其他嵌入一样选中删除。
class DiaryDividerEmbedBuilder extends quill.EmbedBuilder {
  const DiaryDividerEmbedBuilder();

  @override
  String get key => diaryDividerEmbedType;

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}
