import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:appflowy_editor/appflowy_editor.dart' as af;

import '../../../core/database/app_database.dart';
import '../../../core/database/diary_blocks/diary_blocks_codec.dart';

/// 预览页待办勾选的自动保存。
///
/// 预览页是只读的，唯一允许的本地改动是勾选待办。连续勾选多个待办时不必
/// 每次都写库：[schedule] 在短防抖窗口后统一提交；正在写入时再次触发只记
/// 一个排队标记，写完后再走一次防抖。正文与库里相同时跳过，写库失败静默
/// 忽略，不打断阅读。写入只改正文（[AppDatabase.updateDiaryContent]），不会
/// 把归档或回收站里的日记顺带恢复出来。
///
/// 输入：读取当前日记、文档与数据库的回调（页面持有这些状态）；输出：写入
/// 成功后的 [onSaved]（页面据此刷新详情）。
///
/// 生命周期：[dispose] 时若还有没写的勾选（防抖未到期或正在排队），立即按
/// 当下的文档写入一次——左右翻页会把刚勾完待办的那页翻走并回收，不能把这次
/// 勾选丢掉。调用方必须在释放文档之前调用 [dispose]。之后不再回调 [onSaved]。
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
  final af.Document? Function() readDocument;
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

  /// 当下要写入的内容；与库里相同或缺少数据时为 null。
  _TodoSnapshot? _snapshot() {
    final detail = readDetail();
    final document = readDocument();
    if (detail == null || document == null) {
      return null;
    }
    final contentDocJson = encodeDiaryBlocks(document.toJson());
    // 内容未变化直接跳过，减少无效写库。
    if (contentDocJson == detail.diary.content) {
      return null;
    }
    return _TodoSnapshot(
      diaryId: detail.diary.diaryId,
      contentDocJson: contentDocJson,
      contentText: diaryBlocksPlainText(document.toJson()),
    );
  }

  Future<void> _write(_TodoSnapshot snapshot) {
    return readDatabase().updateDiaryContent(
      diaryId: snapshot.diaryId,
      contentDocJson: snapshot.contentDocJson,
      contentText: snapshot.contentText,
    );
  }

  Future<void> _saveIfNeeded() async {
    if (_disposed) {
      return;
    }
    final snapshot = _snapshot();
    if (snapshot == null) {
      return;
    }
    if (_saving) {
      _queued = true;
      return;
    }

    _saving = true;
    try {
      await _write(snapshot);
      if (!_disposed) {
        onSaved();
      }
    } catch (_) {
      // 待办自动保存失败不打断阅读流程，仅静默跳过本次。
    } finally {
      _saving = false;
      if (_queued && !_disposed) {
        _queued = false;
        schedule();
      }
    }
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    final pending = (_timer?.isActive ?? false) || _queued;
    _disposed = true;
    _timer?.cancel();
    if (!pending) {
      return;
    }
    // 文档在调用方 dispose 之后就不可用，所以在这里同步取快照；写库本身
    // 异步完成，失败同样静默（与防抖写入一致）。正在进行的那次写入与这次
    // 都是整篇覆盖，后写的是更新的勾选状态。
    final snapshot = _snapshot();
    if (snapshot != null) {
      unawaited(_write(snapshot).catchError((Object _) {}));
    }
  }
}

@immutable
class _TodoSnapshot {
  const _TodoSnapshot({
    required this.diaryId,
    required this.contentDocJson,
    required this.contentText,
  });

  final String diaryId;
  final String contentDocJson;
  final String contentText;
}
