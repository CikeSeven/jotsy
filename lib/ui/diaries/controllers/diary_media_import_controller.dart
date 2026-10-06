import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TextSelection;
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/quill_delta.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/core/services/diary_media_storage_service.dart';
import 'package:node_diary/core/services/diary_video_gallery_service.dart';
import 'package:node_diary/ui/diaries/models/image_insertion.dart';
import 'package:node_diary/ui/diaries/models/media_insertion.dart';

typedef DiaryMediaPicker = Future<List<PlatformFile>?> Function(DiaryMediaKind);
typedef DiaryMediaImporter =
    Future<DiaryFileAttachment> Function(PlatformFile, DiaryMediaKind);

enum DiaryMediaImportOutcome { inserted, cancelled, failed, busy, unsupported }

/// 编排系统选文件 → 私有目录复制 → 正文插入；不构建 UI，不保存数据库。
/// 页面退出或正文控制器更换会使当前操作失效，并清理尚未提交的文件。
class DiaryMediaImportController extends ChangeNotifier {
  DiaryMediaImportController({
    DiaryMediaPicker? picker,
    DiaryMediaImporter? importer,
  }) : _picker = picker ?? _pickFiles,
       _importer = importer ?? _importFile;

  final DiaryMediaPicker _picker;
  final DiaryMediaImporter _importer;
  DiaryMediaKind? _activeKind;
  bool _disposed = false;
  bool _copying = false;
  int _generation = 0;

  bool get isBusy => _activeKind != null;
  bool get isCopying => _copying;
  DiaryMediaKind? get activeKind => _activeKind;

  void cancel() => _generation++;

  Future<DiaryMediaImportOutcome> pickAndInsert({
    required quill.QuillController controller,
    required DiaryMediaKind kind,
    required bool Function() isCurrent,
  }) async {
    if (_disposed) return DiaryMediaImportOutcome.cancelled;
    if (isBusy) return DiaryMediaImportOutcome.busy;
    if (kIsWeb) return DiaryMediaImportOutcome.unsupported;
    final generation = ++_generation;
    final document = controller.document;
    var selection = controller.selection;
    bool canCommit() =>
        !_disposed &&
        generation == _generation &&
        isCurrent() &&
        identical(controller.document, document);

    // 选择器打开及复制期间可能发生正文变更，让锚点随 Delta 移动，避免使用
    // 打开系统选择器之前已经过时的字符偏移。提交自身的变更前取消监听。
    final subscription = document.changes.listen((change) {
      if (selection.isValid) {
        selection = selection.copyWith(
          baseOffset: change.change.transformPosition(selection.baseOffset),
          extentOffset: change.change.transformPosition(selection.extentOffset),
        );
      }
    });
    final imported = <DiaryFileAttachment>[];
    Delta? previousContent;
    TextSelection? previousSelection;
    _activeKind = kind;
    notifyListeners();
    try {
      final files = await _picker(kind);
      if (!canCommit() || files == null || files.isEmpty) {
        return DiaryMediaImportOutcome.cancelled;
      }
      _copying = true;
      notifyListeners();
      for (final file in files) {
        imported.add(await _importer(file, kind));
        if (!canCommit()) return DiaryMediaImportOutcome.cancelled;
      }
      await subscription.cancel();
      if (!canCommit()) return DiaryMediaImportOutcome.cancelled;
      previousContent = document.toDelta();
      previousSelection = controller.selection;
      if (kind == DiaryMediaKind.image) {
        insertDiaryImages(
          controller: controller,
          imagePaths: imported.map((file) => file.path).toList(),
          selection: selection,
        );
      } else {
        insertDiaryMediaBlocks(
          controller: controller,
          selection: selection,
          embeds: [
            for (final file in imported)
              kind == DiaryMediaKind.video
                  ? quill.BlockEmbed.video(file.path)
                  : quill.BlockEmbed(diaryAttachmentEmbedType, file.encode()),
          ],
        );
      }
      imported.clear(); // 正文取得文件所有权，取消/失败清理不得删除已提交文件。
      return DiaryMediaImportOutcome.inserted;
    } catch (error, stackTrace) {
      final current = canCommit();
      if (previousContent != null && current) {
        controller.document = quill.Document.fromDelta(previousContent);
        controller.updateSelection(
          previousSelection!,
          quill.ChangeSource.local,
        );
      }
      debugPrint('Diary media import failed: $error\n$stackTrace');
      return current
          ? DiaryMediaImportOutcome.failed
          : DiaryMediaImportOutcome.cancelled;
    } finally {
      await subscription.cancel();
      for (final file in imported) {
        try {
          await DiaryMediaStorageService.deleteManagedDiaryFile(file.path);
        } catch (error) {
          debugPrint('Uncommitted diary file cleanup failed: $error');
        }
      }
      if (!_disposed) {
        _copying = false;
        _activeKind = null;
        notifyListeners();
      }
    }
  }

  static Future<List<PlatformFile>?> _pickFiles(DiaryMediaKind kind) async {
    // file_picker 的 Android 图片走相册，但视频走 SAF 文件管理器。
    // 视频改用同类相册入口；其他平台继续复用插件已有的系统媒体选择行为。
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        kind == DiaryMediaKind.video) {
      return DiaryVideoGalleryService.pickAndroidVideos();
    }
    final result = await FilePicker.platform.pickFiles(
      type: switch (kind) {
        DiaryMediaKind.image => FileType.image,
        DiaryMediaKind.video => FileType.video,
        DiaryMediaKind.attachment => FileType.any,
      },
      allowMultiple: true,
      withData: false,
      withReadStream: true,
    );
    return result?.files;
  }

  static Future<DiaryFileAttachment> _importFile(
    PlatformFile file,
    DiaryMediaKind kind,
  ) => DiaryMediaStorageService.importFile(
    kind: kind,
    fileName: file.name,
    sourcePath: file.path,
    readStream: file.readStream,
    bytes: file.bytes,
  );

  @override
  void dispose() {
    _disposed = true;
    cancel();
    super.dispose();
  }
}
