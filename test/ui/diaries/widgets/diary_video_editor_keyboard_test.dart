import '../../../support/diary_content_test_helpers.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/video_export_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../support/expressive_test_theme.dart';
import '../../../support/fake_video_player.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      '$brightness video buttons and seeking keep keyboard hidden while body remains editable',
      (tester) async {
        final focus = FocusNode();
        final player = FakeVideoPlayer();
        final controller = DiaryEditorController(
          document: decodeDiaryContentToDocument(
            jsonEncode([
              {
                'insert': {'video': '/video.mp4'},
              },
              {'insert': '\n正文继续输入\n'},
            ]),
          ),
          selection: quill.Selection.single(path: [1], startOffset: 0),
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
                    shrinkWrap: true,
                    videoPlayerFactory: (_) => player,
                    videoExportService: service,
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
        final editorRect = tester.getRect(find.byType(DiaryEditor));
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
}

class _KeyboardCheckExportService extends VideoExportService {
  int exportCount = 0;
  @override
  Future<void> saveToGallery(String source) async {
    exportCount++;
  }
}
