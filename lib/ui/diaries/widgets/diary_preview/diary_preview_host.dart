import 'package:flutter/widgets.dart';

/// 一篇预览嵌在页面里（宽窗口日记页的右栏），而不是作为独立路由打开时的
/// 宿主：原本要“返回上一页”的几件事改由宿主接手。
///
/// 独立路由（列表、日历、探索、搜索、日记本等入口推入的预览页）不传宿主，
/// 行为不变：删除以 `DiaryPreviewResult.deleted` 返回、日记不见了就退出。
@immutable
class DiaryPreviewHost {
  const DiaryPreviewHost({required this.onDeleted, required this.onVanished});

  /// 这一篇被删除了（“更多”里删除、编辑页里删除或封存页里删除），参数为
  /// 日记 id：宿主移走选中并给出撤销。
  final ValueChanged<String> onDeleted;

  /// 这一篇已不存在（详情查询返回空，如被彻底删除）：宿主清除选中。
  final VoidCallback onVanished;
}

/// 标记预览嵌在宿主里，供预览内部不便逐层传参的部件（顶栏）查询：嵌入时
/// 不显示返回按钮——右栏没有可返回的上一页。
class DiaryPreviewHostScope extends InheritedWidget {
  const DiaryPreviewHostScope({super.key, required super.child});

  /// [context] 所在的预览是否嵌在宿主里。
  static bool isEmbedded(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DiaryPreviewHostScope>() !=
      null;

  // 只表达“是否嵌入”，没有可变的数据：重建时无需通知。
  @override
  bool updateShouldNotify(DiaryPreviewHostScope oldWidget) => false;
}
