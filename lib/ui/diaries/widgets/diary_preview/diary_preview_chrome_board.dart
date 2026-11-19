import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'diary_preview_top_bar.dart';

/// 翻页器里各篇的浮岛内容（按日记 id）。
///
/// 为什么需要它：浮岛是外壳，不该跟着页面一起左右滑走。翻页器把浮岛提到
/// 所有页之上，只为当前这一篇画；而动作（分享、导出、删除……）与页面状态
/// 都在各篇自己的 `DiaryPreviewView` 里，于是由各篇在构建时把内容登记到
/// 这里，翻页器取当前那篇的来画。
///
/// 时机：登记发生在页面构建期间，不能当场通知（会在构建中让祖先重建），
/// 改为这一帧结束后合并通知一次。
class DiaryPreviewChromeBoard extends ChangeNotifier {
  final Map<String, DiaryPreviewChromeEntry> _entries =
      <String, DiaryPreviewChromeEntry>{};
  bool _scheduled = false;
  bool _disposed = false;

  DiaryPreviewChromeEntry? operator [](String diaryId) => _entries[diaryId];

  /// 登记（或更新）[diaryId] 这一篇的浮岛内容。
  void publish(String diaryId, DiaryPreviewChromeEntry entry) {
    _entries[diaryId] = entry;
    _schedule();
  }

  /// 这一篇不再提供浮岛内容（页面销毁、变成封存页）。
  void retract(String diaryId) {
    if (_entries.remove(diaryId) != null) {
      _schedule();
    }
  }

  void _schedule() {
    if (_scheduled || _disposed) {
      return;
    }
    _scheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _scheduled = false;
        if (!_disposed) {
          notifyListeners();
        }
      })
      ..ensureVisualUpdate();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// 把 [DiaryPreviewChromeBoard] 交给翻页器里的各篇。
class DiaryPreviewChromeScope extends InheritedWidget {
  const DiaryPreviewChromeScope({
    super.key,
    required this.board,
    required super.child,
  });

  final DiaryPreviewChromeBoard board;

  /// [context] 所在的预览是否由翻页器统一画浮岛；不建立依赖（看板本身不变）。
  static DiaryPreviewChromeBoard? maybeOf(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<DiaryPreviewChromeScope>();
    return (element?.widget as DiaryPreviewChromeScope?)?.board;
  }

  @override
  bool updateShouldNotify(DiaryPreviewChromeScope oldWidget) =>
      board != oldWidget.board;
}
