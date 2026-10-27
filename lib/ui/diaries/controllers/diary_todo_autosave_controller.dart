import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:appflowy_editor/appflowy_editor.dart' as af;

import '../../../core/database/app_database.dart';
import '../../../core/database/diary_blocks/diary_blocks_codec.dart';
import '../../../core/services/desktop_exit_guard.dart';

/// 预览页待办勾选的自动保存。
///
/// 预览页是只读的，唯一允许的本地改动是勾选待办。连续勾选多个待办时不必
/// 每次都写库：[schedule] 在短防抖窗口后统一提交，写入期间继续勾选的状态
/// 也依次写入。正文与库里相同时跳过，失败保留待存状态并经 onSaveError
/// 提示；桌面退出时取消关闭。写入只改正文（[AppDatabase.updateDiaryContent]），
/// 不会把归档或回收站里的日记顺带恢复出来。
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
    this.onSaveError,
  }) {
    _exitGuard = DesktopExitGuard(onExit: flush);
  }

  /// 防抖窗口（写库节流，不是动画时长）。
  static const Duration debounce = Duration(milliseconds: 260);

  final DiaryWithTags? Function() readDetail;
  final af.Document? Function() readDocument;
  final AppDatabase Function() readDatabase;
  final VoidCallback onSaved;
  final ValueChanged<Object>? onSaveError;
  late final DesktopExitGuard _exitGuard;

  Timer? _timer;
  Future<bool>? _pendingSave;
  _TodoSnapshot? _lastSaved;
  bool _dirty = false;
  bool _disposed = false;

  void schedule() {
    if (_disposed) {
      return;
    }
    _dirty = true;
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(flush()));
  }

  /// 同步读取当下内容；销毁时也先取出它，后续写入不能再读已释放的文档。
  _TodoSnapshot? _snapshot() {
    final detail = readDetail();
    final document = readDocument();
    if (detail == null || document == null) {
      return null;
    }
    final contentDocJson = encodeDiaryBlocks(document.toJson());
    return _TodoSnapshot(
      diaryId: detail.diary.diaryId,
      contentDocJson: contentDocJson,
      contentText: diaryBlocksPlainText(document.toJson()),
    );
  }

  Future<void> _write(_TodoSnapshot snapshot, {AppDatabase? database}) {
    return (database ?? readDatabase()).updateDiaryContent(
      diaryId: snapshot.diaryId,
      contentDocJson: snapshot.contentDocJson,
      contentText: snapshot.contentText,
    );
  }

  /// 不等防抖，等待本轮全部勾选落盘；关闭窗口前由退出守卫调用。
  Future<bool> flush() {
    _timer?.cancel();
    // 只读正文可能来自旧格式，解码后的 JSON 与库存原文并不逐字相同。没有
    // 勾选就不写，避免仅打开阅读页、再关闭窗口也刷新日记的最后编辑时间。
    if (_disposed || (!_dirty && _pendingSave == null)) {
      return Future.value(true);
    }
    return _pendingSave ??= _savePending().whenComplete(
      () => _pendingSave = null,
    );
  }

  bool _needsWrite(_TodoSnapshot snapshot) {
    // 详情订阅尚未刷新时，以真正完成的写入为准：保存期间勾回原状态也必须
    // 再写一次，不能拿仍旧显示原状态的详情当作已存的依据。
    final saved = _lastSaved;
    final previous = saved?.diaryId == snapshot.diaryId
        ? saved?.contentDocJson
        : readDetail()?.diary.content;
    return previous != snapshot.contentDocJson;
  }

  Future<bool> _savePending() async {
    while (!_disposed) {
      final snapshot = _snapshot();
      if (snapshot == null || !_needsWrite(snapshot)) {
        _dirty = false;
        return true;
      }
      try {
        await _write(snapshot);
        _lastSaved = snapshot;
        if (!_disposed) onSaved();
      } catch (error) {
        if (!_disposed) onSaveError?.call(error);
        return false;
      }
    }
    return true;
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    final pending =
        _dirty || (_timer?.isActive ?? false) || _pendingSave != null;
    final snapshot = pending ? _snapshot() : null;
    final saving = _pendingSave;
    final needsWrite =
        snapshot != null && (saving != null || _needsWrite(snapshot));
    final database = needsWrite ? readDatabase() : null;
    _disposed = true;
    _timer?.cancel();
    _exitGuard.dispose();
    if (snapshot != null && database != null) {
      // 翻页卸载时先等旧写入，再提交刚才同步取得的最新快照，避免旧勾选
      // 反过来覆盖新勾选。失败仍保留既有阅读流程，不回调已释放的页面。
      unawaited(
        (saving ?? Future.value(true))
            .then((_) async {
              if (_lastSaved?.diaryId != snapshot.diaryId ||
                  _lastSaved?.contentDocJson != snapshot.contentDocJson) {
                await _write(snapshot, database: database);
              }
            })
            .catchError((Object _) {}),
      );
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
