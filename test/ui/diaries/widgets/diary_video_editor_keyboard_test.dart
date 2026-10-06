import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/content_codec.dart';
import 'package:node_diary/core/services/video_export_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_playback_gestures.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_embed_builder.dart';

import '../../../support/expressive_test_theme.dart';
import '../../../support/fake_video_player.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      '$brightness video buttons and seeking keep keyboard hidden while body remains editable',
      (tester) async {
        final focus = FocusNode();
        final player = FakeVideoPlayer();
        final controller = quill.QuillController(
          document: decodeDiaryContentToDocument(
            jsonEncode([
              {
                'insert': {'video': '/video.mp4'},
              },
              {'insert': '\n正文继续输入\n'},
            ]),
          ),
          selection: const TextSelection.collapsed(offset: 2),
        );
        addTearDown(controller.dispose);
        addTearDown(focus.dispose);
        final service = _KeyboardCheckExportService();
        await tester.pumpWidget(
          MaterialApp(
            theme: expressiveTestTheme(brightness),
            locale: const Locale('zh'),
            localizationsDelegates: const [
              ...AppLocalizations.localizationsDelegates,
              quill.FlutterQuillLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 320,
                  child: quill.QuillEditor.basic(
                    focusNode: focus,
                    controller: controller,
                    config: quill.QuillEditorConfig(
                      scrollable: false,
                      onTapUp: (details, getPosition) => isDiaryPlaybackTap(
                        controller,
                        getPosition(details.globalPosition),
                      ),
                      embedBuilders: [
                        DiaryVideoEmbedBuilder(
                          playerFactory: (_) => player,
                          exportService: service,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final selection = controller.selection;
        expect(tester.testTextInput.isVisible, isFalse);
        await tester.tap(find.byTooltip('播放视频').last);
        await tester.pumpAndSettle();
        expect(player.value.isPlaying, isTrue);
        expect(tester.testTextInput.isVisible, isFalse);
        expect(focus.hasFocus, isFalse);
        expect(controller.selection, selection);
        await tester.tap(find.byTooltip('暂停视频'));
        await tester.pumpAndSettle();
        expect(player.value.isPlaying, isFalse);
        expect(tester.testTextInput.isVisible, isFalse);
        await tester.tap(find.byTooltip('播放视频').last);
        await tester.pump(const Duration(milliseconds: 40));
        await tester.tap(find.byTooltip('暂停视频'));
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isFalse);
        expect(focus.hasFocus, isFalse);
        final slider = find.byType(Slider);
        await tester.drag(slider, const Offset(60, 0));
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isFalse);
        expect(focus.canRequestFocus, isTrue);
        await tester.tap(find.byTooltip('导出视频'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(tester.testTextInput.isVisible, isFalse);
        await tester.tap(find.widgetWithText(TextButton, '取消'));
        await tester.pumpAndSettle();
        expect(service.exportCount, 0);
        expect(tester.testTextInput.isVisible, isFalse);
        await tester.tap(find.byTooltip('全屏播放'));
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isFalse);
        await tester.tap(find.byTooltip('退出全屏'));
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isFalse);
        expect(focus.hasFocus, isFalse);
        final editorRect = tester.getRect(find.byType(quill.QuillEditor));
        await tester.tapAt(
          Offset(editorRect.left + 30, editorRect.bottom - 14),
        );
        await tester.pumpAndSettle();
        expect(focus.hasFocus, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'video tap guard excludes body and empty lines immediately after a video',
    () {
      final controller = quill.QuillController(
        document: decodeDiaryContentToDocument(
          jsonEncode([
            {
              'insert': {'video': '/video.mp4'},
            },
            {'insert': '\n\ntext\n'},
          ]),
        ),
        selection: const TextSelection.collapsed(offset: 0),
      );
      addTearDown(controller.dispose);
      expect(
        isDiaryPlaybackTap(controller, const TextPosition(offset: 0)),
        isTrue,
      );
      expect(
        isDiaryPlaybackTap(controller, const TextPosition(offset: 1)),
        isTrue,
      );
      expect(
        isDiaryPlaybackTap(controller, const TextPosition(offset: 2)),
        isFalse,
      );
      expect(
        isDiaryPlaybackTap(controller, const TextPosition(offset: 3)),
        isFalse,
      );
    },
  );
}

class _KeyboardCheckExportService extends VideoExportService {
  int exportCount = 0;
  @override
  Future<void> saveToGallery(String source) async {
    exportCount++;
  }
}
