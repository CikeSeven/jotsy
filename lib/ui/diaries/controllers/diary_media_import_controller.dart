import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'diary_editor_controller.dart';
import 'diary_editor_insert.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/core/services/diary_media_storage_service.dart';
import 'package:node_diary/core/services/diary_video_gallery_service.dart';
import 'package:node_diary/ui/diaries/models/image_insertion.dart';
import 'package:node_diary/ui/diaries/models/media_insertion.dart';
import 'package:path/path.dart' as p;

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

  /// [picker] 替换本次的文件来源（如“这天拍的照片”已在页面里选好），
  /// 复制、插入、取消与失败回滚仍走同一条链路。[discardPickerCopies] 为
  /// false 时结束后不清理来源文件的“选择器缓存副本”：来源是用户自己的文件
  /// （桌面拖放）时，哪怕它恰好位于缓存目录里也不能删。
  Future<DiaryMediaImportOutcome> pickAndInsert({
    required DiaryEditorController controller,
    required DiaryMediaKind kind,
    required bool Function() isCurrent,
    DiaryMediaPicker? picker,
    bool discardPickerCopies = true,
  }) async {
    if (_disposed) return DiaryMediaImportOutcome.cancelled;
    if (isBusy) return DiaryMediaImportOutcome.busy;
    if (kIsWeb) return DiaryMediaImportOutcome.unsupported;
    final generation = ++_generation;
    final document = controller.document;
    var selection = diaryEditorInsertionSelection(controller);
    final anchors = [
      _MediaAnchor(
        document.nodeAtPath(selection.start.path)!,
        selection.start.offset,
      ),
      _MediaAnchor(
        document.nodeAtPath(selection.end.path)!,
        selection.end.offset,
      ),
    ];
    var anchorValid = true;
    bool canCommit() =>
        !_disposed &&
        generation == _generation &&
        anchorValid &&
        isCurrent() &&
        identical(controller.document, document);

    // 保存“指向内容的锚点”，而不是追随任意后台事务的 afterSelection。
    // 修改段前文字时按原生 Delta diff 移动偏移；段落移动时按节点 id 追踪。
    // 锚点所在块被删除就取消导入，不能误插到替补该路径的另一段里。
    final subscription = controller.state.transactionStream.listen((event) {
      if (event.$1 != af.TransactionTime.after) return;
      final nodes = {
        for (final node in walkDiaryEditorNodes(document)) node.id: node,
      };
      for (final anchor in anchors) {
        final node = nodes[anchor.node.id];
        if (node == null) {
          anchorValid = false;
          return;
        }
        anchor.follow(node);
      }
      selection = af.Selection(
        start: anchors[0].position,
        end: anchors[1].position,
      );
    });
    final imported = <DiaryFileAttachment>[];
    List<PlatformFile>? files;
    String? previousContent;
    af.Selection? previousSelection;
    _activeKind = kind;
    notifyListeners();
    try {
      files = await (picker ?? _picker)(kind);
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
      previousContent = controller.contentJson;
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
                  ? af.Node(type: 'video', attributes: {'url': file.path})
                  : af.Node(
                      type: diaryAttachmentEmbedType,
                      attributes: {
                        'path': file.path,
                        if (file.name != null) 'name': file.name,
                        if (file.sizeBytes != null) 'sizeBytes': file.sizeBytes,
                      },
                    ),
          ],
        );
      }
      imported.clear(); // 正文取得文件所有权，取消/失败清理不得删除已提交文件。
      return DiaryMediaImportOutcome.inserted;
    } catch (error, stackTrace) {
      final current = canCommit();
      if (previousContent != null && current) {
        controller.restoreContent(
          previousContent,
          selection: previousSelection,
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
      // 无论成功与否，选择器在缓存里的中转副本都已无用（视频可达数百 MB）。
      if (discardPickerCopies) {
        for (final file in files ?? const <PlatformFile>[]) {
          await DiaryMediaStorageService.discardPickerCopy(file.path);
        }
      }
      if (!_disposed) {
        _copying = false;
        _activeKind = null;
        notifyListeners();
      }
    }
  }

  /// 正文图片块能显示的格式；其余按扩展名分到视频或附件。
  static const Set<String> _imageExtensions = <String>{
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
    '.bmp',
  };
  static const Set<String> _videoExtensions = <String>{
    '.mp4',
    '.mov',
    '.m4v',
    '.3gp',
    '.avi',
    '.webm',
    '.mkv',
  };

  /// 按扩展名判断一份文件插入成哪种块：图片、视频，其余（音频、文档等）
  /// 与工具栏“文件”一样作为附件。
  static DiaryMediaKind kindForPath(String path) {
    final extension = p.extension(path).toLowerCase();
    if (_imageExtensions.contains(extension)) return DiaryMediaKind.image;
    if (_videoExtensions.contains(extension)) return DiaryMediaKind.video;
    return DiaryMediaKind.attachment;
  }

  /// 把本机文件（桌面上拖进正文的文件）插入正文：与工具栏选文件同一条链路
  /// （复制到私有目录 → 插入 → 失败回滚），只是文件来源换成 [paths]。
  ///
  /// 文件夹与已不存在的路径跳过；按原顺序把相邻的同类文件分成一段，逐段经
  /// [pickAndInsert] 插入（每段从当时的光标处接着插），某段没有插入（失败、
  /// 取消、忙）就停下并返回它的结果。全部跳过时返回 cancelled。
  Future<DiaryMediaImportOutcome> insertFiles({
    required DiaryEditorController controller,
    required List<String> paths,
    required bool Function() isCurrent,
  }) async {
    final runs = <(DiaryMediaKind, List<PlatformFile>)>[];
    for (final path in paths) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final kind = kindForPath(path);
      final picked = PlatformFile(
        name: p.basename(path),
        size: file.lengthSync(),
        path: path,
      );
      if (runs.isNotEmpty && runs.last.$1 == kind) {
        runs.last.$2.add(picked);
      } else {
        runs.add((kind, <PlatformFile>[picked]));
      }
    }
    var outcome = DiaryMediaImportOutcome.cancelled;
    for (final (kind, files) in runs) {
      outcome = await pickAndInsert(
        controller: controller,
        kind: kind,
        isCurrent: isCurrent,
        picker: (_) async => files,
        discardPickerCopies: false,
      );
      if (outcome != DiaryMediaImportOutcome.inserted) return outcome;
    }
    return outcome;
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

class _MediaAnchor {
  _MediaAnchor(this.node, this.offset) : delta = node.delta;
  af.Node node;
  int offset;
  af.Delta? delta;
  af.Position get position => af.Position(path: node.path, offset: offset);
  void follow(af.Node next) {
    final updated = next.delta;
    if (delta != null && updated != null) {
      var cursor = 0;
      var shift = 0;
      for (final op in delta!.diff(updated)) {
        if (op is af.TextInsert) {
          if (cursor <= offset) shift += op.length;
        } else if (op is af.TextDelete) {
          if (cursor < offset) shift -= op.length.clamp(0, offset - cursor);
          cursor += op.length;
        } else {
          cursor += op.length;
        }
      }
      offset = (offset + shift).clamp(0, updated.length);
    }
    node = next;
    delta = updated;
  }
}
