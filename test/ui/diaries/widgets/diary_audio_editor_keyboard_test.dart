import '../../../support/diary_content_test_helpers.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/audio_embed_codec.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_waveform_visualizer.dart';

import '../../../support/expressive_test_theme.dart';
import '../../../support/fake_audio_player.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      '$brightness recording controls keep keyboard hidden and preserve the body cursor',
      (tester) async {
        final focus = FocusNode();
        final player = FakeAudioPlayer();
        final controller = _controller();
        addTearDown(focus.dispose);
        addTearDown(controller.dispose);
        await tester.pumpWidget(_editor(controller, focus, player, brightness));
        await tester.pumpAndSettle();
        final selection = controller.selection;
        final content = encodeDiaryDocumentToJson(controller.document);
        expect(tester.testTextInput.isVisible, isFalse);
        await tester.tap(find.byTooltip('播放录音'));
        await tester.pumpAndSettle();
        expect(player.playCalls, 1);
        expect(find.byTooltip('暂停播放'), findsOneWidget);
        expect(tester.testTextInput.isVisible, isFalse);
        expect(controller.selection, selection);
        await tester.tap(find.byTooltip('暂停播放'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('播放录音'), findsOneWidget);
        await tester.tap(find.byTooltip('播放录音'));
        await tester.pump(const Duration(milliseconds: 40));
        await tester.tap(find.byTooltip('暂停播放'));
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isFalse);
        expect(controller.selection, selection);
        await tester.tap(find.byType(DiaryWaveformBarVisualizer));
        await tester.pumpAndSettle();
        await tester.drag(
          find.byType(DiaryWaveformBarVisualizer),
          const Offset(60, 0),
        );
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isFalse);
        expect(focus.hasFocus, isFalse);
        expect(focus.canRequestFocus, isTrue);
        expect(controller.selection, selection);
        expect(encodeDiaryDocumentToJson(controller.document), content);
        final body = tester.getRect(find.byType(DiaryEditor));
        await tester.tapAt(Offset(body.left + 30, body.bottom - 14));
        await tester.pumpAndSettle();
        expect(focus.hasFocus, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$brightness recording rename opens its own keyboard without focusing the body',
      (tester) async {
        final focus = FocusNode();
        final controller = _controller();
        addTearDown(focus.dispose);
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _editor(controller, focus, FakeAudioPlayer(), brightness),
        );
        await tester.pumpAndSettle();
        final selection = controller.selection;
        await tester.tap(find.byTooltip('重命名录音'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(tester.testTextInput.isVisible, isTrue);
        expect(focus.hasFocus, isFalse);
        await tester.enterText(find.byType(TextField), '我的录音');
        await tester.tap(find.widgetWithText(TextButton, '确认'));
        await tester.pumpAndSettle();
        expect(find.text('我的录音'), findsOneWidget);
        expect(controller.selection, selection);
        expect(tester.testTextInput.isVisible, isFalse);
        expect(focus.hasFocus, isFalse);
        await tester.tap(find.byTooltip('播放录音'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('暂停播放'), findsOneWidget);
        expect(tester.testTextInput.isVisible, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'failed recording playback reports an error without opening the keyboard',
    (tester) async {
      final focus = FocusNode();
      final controller = _controller();
      final player = FakeAudioPlayer()..fail = true;
      addTearDown(focus.dispose);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _editor(controller, focus, player, Brightness.light),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('播放录音'));
      await tester.pumpAndSettle();
      expect(find.text('录音无法播放'), findsWidgets);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(focus.canRequestFocus, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
}

DiaryEditorController _controller() => DiaryEditorController(
  document: decodeDiaryContentToDocument(
    jsonEncode([
      {
        'insert': {
          diaryAudioEmbedType: const DiaryAudioAttachment(
            path: '/diary_recordings/entry.m4a',
            duration: Duration(seconds: 12),
            name: '原始录音',
          ).encode(),
        },
      },
      {'insert': '\n正文继续输入\n'},
    ]),
  ),
  selection: quill.Selection.single(path: [1], startOffset: 0),
);

Widget _editor(
  DiaryEditorController controller,
  FocusNode focus,
  FakeAudioPlayer player,
  Brightness brightness,
) => MaterialApp(
  theme: expressiveTestTheme(brightness),
  locale: const Locale('zh'),
  localizationsDelegates: const [
    ...AppLocalizations.localizationsDelegates,
    quill.AppFlowyEditorLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 320,
        child: nativeTestEditor(
          controller: controller,
          focusNode: focus,
          audioPlayer: player,
        ),
      ),
    ),
  ),
);
