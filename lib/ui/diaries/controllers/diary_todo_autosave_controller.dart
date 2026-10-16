import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../../core/database/app_database.dart';
import '../../../core/database/content_codec.dart';

/// 预览页待办勾选的自动保存。
///
/// 预览页是只读的，唯一允许的本地改动是勾选待办。连续勾选多个待办时不必
/// 每次都写库：[schedule] 在短防抖窗口后统一提交；正在写入时再次触发只记
/// 一个排队标记，写完后再走一次防抖。正文与库里相同时跳过，写库失败静默
/// 忽略，不打断阅读。
///
/// 输入：读取当前日记、文档与数据库的回调（页面持有这些状态）；输出：写入
/// 成功后的 [onSaved]（页面据此刷新详情）。[dispose] 之后不再写入也不再回调。
class DiaryTodoAutoSaveController {
  DiaryTodoAutoSaveController({
    required this.readDetail,
    required this.readDocument,
    required this.readDatabase,
    required this.onSaved,
  });

  /// 防抖窗口（写库节流，不是动画时长）。
  static const Duration debounce = Duration(milliseconds: 260);

  final DiaryWithTags? Function() readDetail;
  final quill.Document? Function() readDocument;
  final AppDatabase Function() readDatabase;
  final VoidCallback onSaved;

  Timer? _timer;
  bool _saving = false;
  bool _queued = false;
  bool _disposed = false;

  void schedule() {
    if (_disposed) {
      return;
    }
    _timer?.cancel();
    _timer = Timer(debounce, _saveIfNeeded);
  }

  Future<void> _saveIfNeeded() async {
    final detail = readDetail();
    final document = readDocument();
    if (_disposed || detail == null || document == null) {
      return;
    }

    final contentDocJson = encodeDiaryDocumentToJson(document);
    // 内容未变化直接跳过，减少无效写库。
    if (contentDocJson == detail.diary.content) {
      return;
    }

    if (_saving) {
      _queued = true;
      return;
    }

    _saving = true;
    try {
      await readDatabase().updateDiary(
        diaryId: detail.diary.diaryId,
        title: detail.diary.title,
        contentDocJson: contentDocJson,
        contentText: extractPlainTextFromDiaryDocument(document),
        metadataJson: detail.diary.metadata,
        cover: detail.diary.cover,
        tagIds: detail.tags.map((tag) => tag.id).toList(growable: false),
      );
      if (!_disposed) {
        onSaved();
      }
    } catch (_) {
      // 待办自动保存失败不打断阅读流程，仅静默跳过本次。
    } finally {
      _saving = false;
      if (_queued) {
        _queued = false;
        schedule();
      }
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }
}
