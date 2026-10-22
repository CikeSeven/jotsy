import 'dart:convert';
import 'package:appflowy_editor/appflowy_editor.dart' as af;
import '../../../core/database/audio_embed_codec.dart';
import '../controllers/diary_editor_controller.dart';
import '../controllers/diary_editor_insert.dart';

/// 录音与其他媒体共用块插入事务，不删除选中文字，不把录音转为识别文本。
void insertDiaryRecording({
  required DiaryEditorController controller,
  af.Selection? selection,
  required DiaryAudioAttachment recording,
}) => insertDiaryEditorNodes(
  controller: controller,
  selection: selection,
  nodes: [af.Node(type: 'audio', attributes: jsonDecode(recording.encode()))],
);
