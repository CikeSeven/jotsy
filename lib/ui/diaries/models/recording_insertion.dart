import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:node_diary/core/database/audio_embed_codec.dart';

/// Inserts an audio block at the captured body selection without deleting
/// selected prose or Quill's required trailing newline.
void insertDiaryRecording({
  required quill.QuillController controller,
  required TextSelection selection,
  required DiaryAudioAttachment recording,
}) {
  final maxOffset = controller.document.length - 1;
  var index = selection.isValid ? selection.end.clamp(0, maxOffset) : maxOffset;
  final text = controller.document.toPlainText();
  if (index > 0 && text[index - 1] != '\n') {
    controller.replaceText(index, 0, '\n', null, ignoreFocus: true);
    index++;
  }
  controller.replaceText(
    index,
    0,
    quill.BlockEmbed(diaryAudioEmbedType, recording.encode()),
    null,
    ignoreFocus: true,
  );
  // Quill only auto-wraps built-in video embeds. Audio needs its own newline
  // and an editable line after the block, including in an otherwise empty note.
  controller.replaceText(
    index + 1,
    0,
    '\n',
    TextSelection.collapsed(offset: index + 2),
    ignoreFocus: true,
  );
}
