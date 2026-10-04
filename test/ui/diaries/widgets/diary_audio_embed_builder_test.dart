import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/audio_embed_codec.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/recording_insertion.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';

void main() {
  for (final readOnly in [false, true]) {
    testWidgets('recording renders as a player with readOnly=$readOnly', (
      tester,
    ) async {
      final controller = quill.QuillController.basic();
      insertDiaryRecording(
        controller: controller,
        selection: const TextSelection.collapsed(offset: 0),
        recording: const DiaryAudioAttachment(
          path: '/documents/diary_recordings/entry.m4a',
          duration: Duration(seconds: 12),
        ),
      );
      controller.readOnly = readOnly;
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            quill.FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: quill.QuillEditor.basic(
              controller: controller,
              config: quill.QuillEditorConfig(
                embedBuilders: buildDiaryQuillEmbedBuilders(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byTooltip('播放录音'), findsOneWidget);
      expect(find.text('00:00 / 00:12'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('editable audio player shows rename button and updates title', (
    tester,
  ) async {
    final controller = quill.QuillController.basic();
    insertDiaryRecording(
      controller: controller,
      selection: const TextSelection.collapsed(offset: 0),
      recording: const DiaryAudioAttachment(
        path: '/documents/diary_recordings/entry.m4a',
        duration: Duration(seconds: 10),
        name: '原始录音',
      ),
    );
    controller.readOnly = false;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          ...AppLocalizations.localizationsDelegates,
          quill.FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: quill.QuillEditor.basic(
            controller: controller,
            config: quill.QuillEditorConfig(
              embedBuilders: buildDiaryQuillEmbedBuilders(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('原始录音'), findsOneWidget);
    expect(find.byTooltip('重命名录音'), findsOneWidget);

    // Tap rename button to open dialog
    await tester.tap(find.byTooltip('重命名录音'));
    await tester.pumpAndSettle();

    expect(find.text('重命名录音'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '我的心声');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(find.text('我的心声'), findsOneWidget);
    final delta = controller.document.toDelta().toJson();
    final embeds = delta.where((op) => op['insert'] is Map).toList();
    expect(embeds, hasLength(1));
    final updatedAttachment = DiaryAudioAttachment.tryDecode(
      (embeds.single['insert'] as Map)[diaryAudioEmbedType],
    );
    expect(updatedAttachment?.name, '我的心声');
  });

  test(
    'DiaryAudioAttachment encodes and decodes name and waveform correctly',
    () {
      const original = DiaryAudioAttachment(
        path: '/test/audio.m4a',
        duration: Duration(seconds: 42),
        name: '会议录音',
        waveform: [0.12, 0.45, 0.88, 0.3],
      );

      final encoded = original.encode();
      final decoded = DiaryAudioAttachment.tryDecode(encoded);

      expect(decoded, isNotNull);
      expect(decoded!.path, '/test/audio.m4a');
      expect(decoded.duration, const Duration(seconds: 42));
      expect(decoded.name, '会议录音');
      expect(decoded.waveform, [0.12, 0.45, 0.88, 0.3]);
    },
  );
}
