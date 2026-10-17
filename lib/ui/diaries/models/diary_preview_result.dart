import 'package:flutter/foundation.dart';

/// 预览页的返回结果：删除了哪一篇。
///
/// 预览页可以左右滑动切换日记，被删的未必是最初点开的那篇，所以结果带上
/// 日记 id，入口按它给出撤销提示并恢复。
@immutable
class DiaryPreviewResult {
  const DiaryPreviewResult.deleted(this.diaryId);

  final String diaryId;

  @override
  bool operator ==(Object other) =>
      other is DiaryPreviewResult && other.diaryId == diaryId;

  @override
  int get hashCode => diaryId.hashCode;
}
