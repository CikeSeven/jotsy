import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

quill.QuillSimpleToolbarConfig buildDiaryQuillToolbarConfig() {
  return quill.QuillSimpleToolbarConfig(
    multiRowsDisplay: false,
    showFontFamily: false,
    showFontSize: false,
    showSubscript: false,
    showSuperscript: false,
    showDirection: false,
    showSearchButton: false,
    showClipboardCut: false,
    showClipboardCopy: false,
    showClipboardPaste: false,
    showDividers: true,
    embedButtons: FlutterQuillEmbeds.toolbarButtons(
      imageButtonOptions: QuillToolbarImageButtonOptions(
        imageButtonConfig: QuillToolbarImageConfig(
          onRequestPickImage: _pickAndPersistDiaryImage,
        ),
      ),
      videoButtonOptions: null,
      cameraButtonOptions: null,
    ),
  );
}

List<quill.EmbedBuilder> buildDiaryQuillEmbedBuilders() {
  return FlutterQuillEmbeds.defaultEditorBuilders();
}

Future<String?> _pickAndPersistDiaryImage(BuildContext context) async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: false,
    type: FileType.image,
  );
  if (result == null || result.files.isEmpty) {
    return null;
  }

  final path = result.files.first.path;
  if (path == null || path.isEmpty) {
    return null;
  }

  return _persistDiaryImage(path);
}

Future<String> _persistDiaryImage(String sourcePath) async {
  final sourceFile = File(sourcePath);
  if (!await sourceFile.exists()) {
    return sourcePath;
  }

  final appDir = await getApplicationDocumentsDirectory();
  final imageDir = Directory(p.join(appDir.path, 'diary_images'));
  if (!await imageDir.exists()) {
    await imageDir.create(recursive: true);
  }

  final extension = p.extension(sourcePath);
  final targetName =
      'img_${DateTime.now().microsecondsSinceEpoch}${extension.isEmpty ? '.jpg' : extension}';
  final targetPath = p.join(imageDir.path, targetName);

  await sourceFile.copy(targetPath);
  return targetPath;
}
