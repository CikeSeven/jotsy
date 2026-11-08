import 'package:flutter/widgets.dart';

/// 对话里可展开的块（思考过程、工具详情、改动行、参考的日记）是否展开过：
/// 存在最近的 `PageStorage`（对话页给每段对话一个常驻本次运行的存储桶，
/// 见 `aiChatViewMemoryProvider`）。消息列表懒加载，滚出屏幕的项会被回收；
/// 离开对话再回来页面也是新建的——靠它两种情况下都保持原样。
///
/// [id] 为 null（没有稳定标识，如进行中的一轮）时不读不写，默认收起。
bool aiReadExpanded(BuildContext context, String? id) {
  if (id == null) return false;
  final value = PageStorage.maybeOf(
    context,
  )?.readState(context, identifier: id);
  return value is bool && value;
}

void aiWriteExpanded(BuildContext context, String? id, bool value) {
  if (id == null) return;
  PageStorage.maybeOf(context)?.writeState(context, value, identifier: id);
}
