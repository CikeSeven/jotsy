import '../../../support/diary_content_test_helpers.dart';
import 'package:appflowy_editor/appflowy_editor.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_media.dart';
import 'package:node_diary/core/database/audio_embed_codec.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/models/recording_insertion.dart';

void main() {
  const recording = DiaryAudioAttachment(
    path: '/documents/diary_recordings/entry.m4a',
    duration: Duration(seconds: 12),
  );

  test(
    'recording is an audio block and existing selected text is retained',
    () {
      final controller = DiaryEditorController(
        document: documentFromPlainText('hello world'),
        selection: quill.Selection.single(
          path: [0],
          startOffset: 0,
          endOffset: 5,
        ),
      );
      addTearDown(controller.dispose);
      insertDiaryRecording(
        controller: controller,
        selection: controller.selection,
        recording: recording,
      );
      final delta = controller.document.toDelta().toJson();
      final embeds = delta.where((op) => op['insert'] is Map).toList();
      expect(embeds, hasLength(1));
      final audio = DiaryAudioAttachment.tryDecode(
        (embeds.single['insert'] as Map)[diaryAudioEmbedType],
      );
      expect(audio?.path, recording.path);
      expect(audio?.duration, const Duration(seconds: 12));
      expect(controller.document.toPlainText(), contains('hello\n'));
      expect(controller.document.toPlainText(), contains(' world'));
    },
  );

  test('audio-only draft is retained with an empty plain-text mirror', () {
    final controller = DiaryEditorController();
    addTearDown(controller.dispose);
    insertDiaryRecording(
      controller: controller,
      selection: null,
      recording: recording,
    );
    final raw = encodeDiaryDocumentToJson(controller.document);
    final draft = NewDiaryDraft(
      title: '',
      contentDocJson: raw,
      contentText: extractPlainTextFromDiaryDocument(controller.document),
    );
    expect(draft.contentText, isEmpty);
    expect(draft.hasContent, isTrue);
    expect(extractDiaryAudioPaths(raw), {recording.path});
    expect(
      decodeDiaryContentToDocument(raw).toDelta().toJson(),
      controller.document.toDelta().toJson(),
    );
  });

  test('invalid or metadata-only audio payloads do not crash', () {
    expect(DiaryAudioAttachment.tryDecode('not json'), isNull);
    expect(DiaryAudioAttachment.tryDecode('{"durationMs": 12}'), isNull);
    expect(extractDiaryAudioPaths('not json'), isEmpty);
    expect(diaryContentHasEmbeddedContent('{"path":"file.m4a"}'), isFalse);
  });
}
