import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/core/services/file_open_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/media_insertion.dart';
import 'package:node_diary/ui/diaries/widgets/diary_attachment_embed_builder.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';

import '../../../support/expressive_test_theme.dart';

void main() {
  const file = DiaryFileAttachment(
    path: '/documents/diary_attachments/report.pdf',
    name: '会议报告.pdf',
    sizeBytes: 1536,
  );

  for (final brightness in Brightness.values) {
    for (final readOnly in [false, true]) {
      testWidgets(
        'attachment opens from $brightness diary with readOnly=$readOnly',
        (tester) async {
          final controller = quill.QuillController.basic();
          addTearDown(controller.dispose);
          insertDiaryMediaBlocks(
            controller: controller,
            selection: controller.selection,
            embeds: [quill.BlockEmbed(diaryAttachmentEmbedType, file.encode())],
          );
          controller.readOnly = readOnly;
          final service = FakeFileOpenService();
          await tester.pumpWidget(_editor(controller, brightness, service));
          await tester.pumpAndSettle();
          expect(find.text('会议报告.pdf'), findsOneWidget);
          expect(find.text('PDF · 1.5 KB'), findsOneWidget);
          final icon = tester.widget<FaIcon>(
            find.byIcon(FontAwesomeIcons.filePdf.data),
          );
          expect(
            icon.color,
            expressiveTestTheme(brightness).colorScheme.onSecondaryContainer,
          );
          await tester.tap(find.text('会议报告.pdf'));
          await tester.pumpAndSettle();
          expect(service.openedPaths, [file.path]);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets('imported file alias opens and reports unavailable handler', (
    tester,
  ) async {
    final controller = quill.QuillController.basic();
    addTearDown(controller.dispose);
    insertDiaryMediaBlocks(
      controller: controller,
      selection: controller.selection,
      embeds: [quill.BlockEmbed('file', file.path)],
    );
    controller.readOnly = true;
    final service = FakeFileOpenService()..failure = FileOpenFailure.noApp;
    await tester.pumpWidget(_editor(controller, Brightness.dark, service));
    await tester.pumpAndSettle();
    await tester.tap(find.text('report.pdf'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(service.openedPaths, [file.path]);
    expect(find.text('手机上没有可打开此文件的应用'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'opening indicator blocks repeated taps until the handler returns',
    (tester) async {
      final controller = quill.QuillController.basic();
      addTearDown(controller.dispose);
      insertDiaryMediaBlocks(
        controller: controller,
        selection: controller.selection,
        embeds: [quill.BlockEmbed(diaryAttachmentEmbedType, file.encode())],
      );
      controller.readOnly = true;
      final gate = Completer<FileOpenFailure?>();
      final service = FakeFileOpenService()..completion = gate;
      await tester.pumpWidget(_editor(controller, Brightness.light, service));
      await tester.pumpAndSettle();
      await tester.tap(find.text('会议报告.pdf'));
      await tester.pump();
      expect(find.byType(ExpressiveLoadingIndicator), findsOneWidget);
      await tester.tap(find.text('会议报告.pdf'));
      expect(service.openedPaths, [file.path]);
      gate.complete(null);
      await tester.pumpAndSettle();
      expect(find.byType(ExpressiveLoadingIndicator), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('malformed imported attachments render a localized error', (
    tester,
  ) async {
    final controller = quill.QuillController.basic();
    addTearDown(controller.dispose);
    insertDiaryMediaBlocks(
      controller: controller,
      selection: controller.selection,
      embeds: [quill.BlockEmbed(diaryAttachmentEmbedType, '{broken')],
    );
    await tester.pumpWidget(
      _editor(controller, Brightness.light, FakeFileOpenService()),
    );
    await tester.pumpAndSettle();
    expect(find.text('附件文件不存在或无法访问'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Widget _editor(
  quill.QuillController controller,
  Brightness brightness,
  FileOpenService service,
) => MaterialApp(
  theme: expressiveTestTheme(brightness),
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
        embedBuilders: [
          DiaryAttachmentEmbedBuilder(openService: service),
          DiaryAttachmentEmbedBuilder(embedType: 'file', openService: service),
        ],
      ),
    ),
  ),
);

class FakeFileOpenService extends FileOpenService {
  final openedPaths = <String>[];
  FileOpenFailure? failure;
  Completer<FileOpenFailure?>? completion;

  @override
  Future<FileOpenFailure?> open(String source) async {
    openedPaths.add(source);
    return completion == null ? failure : await completion!.future;
  }
}
