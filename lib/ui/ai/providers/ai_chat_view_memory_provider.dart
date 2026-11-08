import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 对话页的界面状态（滚动位置、是否贴底、展开过的思考过程与工具详情）：
/// 每段对话一个 `PageStorageBucket`，常驻本次运行。
///
/// 对话页离开后（去了首页的某个 Tab 或日记本）再“回到对话”，新建的页面
/// 从这里取回离开前的样子；消息列表懒加载、滚出屏幕的项会被回收，展开状态
/// 也靠它保留。不落库：重启应用后从底部、全部收起开始。
final aiChatViewMemoryProvider = Provider<AiChatViewMemory>(
  (Ref ref) => AiChatViewMemory(),
);

class AiChatViewMemory {
  final Map<String, PageStorageBucket> _buckets = <String, PageStorageBucket>{};

  /// [conversationId] 的存储桶；还没有对话（空白新对话）时用共用的一个。
  PageStorageBucket bucketFor(String? conversationId) =>
      _buckets.putIfAbsent(conversationId ?? '', PageStorageBucket.new);

  /// 对话删掉了：它的界面状态一并丢掉。
  void forget(String conversationId) => _buckets.remove(conversationId);
}
