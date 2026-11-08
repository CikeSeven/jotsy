import 'package:flutter/foundation.dart';

import '../../models/ai_tool_subject.dart';
import '../../tools/ai_tool.dart';

/// 一条回答里用户能做的事（对话页提供，层层传给分段、卡片与详情）。
@immutable
class AiAnswerActions {
  const AiAnswerActions({
    required this.onCitation,
    required this.onOpenPage,
    required this.onOpenSubject,
    this.onUndo,
    this.onDecide,
  });

  /// 点了正文里的 `[Dn]` 引用。
  final ValueChanged<String> onCitation;

  /// 点了前往卡片。
  final ValueChanged<AiToolNavigation> onOpenPage;

  /// 点了对象胶囊（日记、日记本、标签、待办、纪念日）。
  final ValueChanged<AiToolSubject> onOpenSubject;

  /// 撤销这些调用（null 为全部可撤销的）；生成中或不能撤销时为 null。
  final void Function(Set<String>? callIds)? onUndo;

  /// 进行中：用户在确认卡上点了执行（true）或取消（false）。
  final void Function(String callId, bool approved)? onDecide;
}
