import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:node_diary/core/database/audio_embed_codec.dart';

/// Quill 使用透明点击识别器，子控件已处理点击后仍会移动选区/拉起键盘。
/// 只消费音频/视频块及其结尾换行的点击，后方正文和空行仍走正常编辑手势。
bool isDiaryPlaybackTap(
  quill.QuillController controller,
  TextPosition position,
) {
  final offset = position.offset.clamp(0, controller.document.length - 1);
  final text = controller.document.toPlainText();
  final leaf = controller.document.querySegmentLeafNode(offset).leaf;
  if (leaf is quill.Embed &&
      _isPlaybackEmbed(leaf) &&
      offset == leaf.documentOffset) {
    return true;
  }
  if (offset > 0 && text[offset] == '\n') {
    final preceding = controller.document.querySegmentLeafNode(offset - 1).leaf;
    return preceding is quill.Embed &&
        _isPlaybackEmbed(preceding) &&
        offset == preceding.documentOffset + 1;
  }
  return false;
}

bool _isPlaybackEmbed(quill.Embed embed) =>
    embed.value.type == quill.BlockEmbed.videoType ||
    embed.value.type == diaryAudioEmbedType;
