import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/audio_embed_codec.dart';
import 'package:node_diary/core/database/content_codec.dart';
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
      final controller = quill.QuillController(
        document: documentFromPlainText('hello world'),
        selection: const TextSelection(baseOffset: 0, extentOffset: 5),
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
    final controller = quill.QuillController.basic();
    addTearDown(controller.dispose);
    insertDiaryRecording(
      controller: controller,
      selection: const TextSelection.collapsed(offset: -1),
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
