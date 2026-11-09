// 把 `buildAiAnswerSegments` 的分段画出来：折叠块、前往卡片、改动卡片、
// 确认卡片与正文，段间距 10。落库的回答与正在进行的一轮共用。
//
// - 只有最后一段是折叠块、且这一轮在进行时，它才是“进行中”（胶囊写当前
//   动作、转加载指示）；后面已经有卡片或正文时，思考已经结束，显示摘要。
// - 正文经 [AiRevealedMarkdown]：进行中的最后一段按稳定的速度逐字放出，
//   落库后的最后一条回答接着把剩下的放完（[handoff]）；其余直接显示。
// - 进行中的一轮里新出现的段（折叠块、卡片、正文）淡入上移；组件建立时
//   已经有的段不动——滚出屏幕再回来不会整条重播。卡片用的是不模糊的控件
//   材质（`AppGlassField`），可以放进透明度层。

import 'package:flutter/material.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../widgets/expressive_entrance.dart';
import '../../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../../controllers/ai_thinking_clock.dart';
import '../../viewmodels/ai_answer_segments.dart';
import '../../widgets/ai_stream_reveal.dart';
import 'ai_action_cards.dart';
import 'ai_answer_actions.dart';
import 'ai_process_fold.dart';

class AiAnswerSegmentsView extends StatefulWidget {
  const AiAnswerSegmentsView({
    super.key,
    required this.keyPrefix,
    required this.segments,
    required this.actions,
    this.live = false,
    this.clock,
    this.status,
    this.handoff,
  });

  /// 折叠块与卡片的 key 前缀（这条回答的 id）：列表复用时展开状态不串。
  final String keyPrefix;
  final List<AiAnswerSegment> segments;
  final AiAnswerActions actions;
  final bool live;
  final AiThinkingClock? clock;
  final String? status;

  /// 最后一段正文“放到了哪里”的交接（见 [AiRevealHandoff]）；只给进行中的
  /// 一轮与最后一条回答。
  final AiRevealHandoff? handoff;

  @override
  State<AiAnswerSegmentsView> createState() => _AiAnswerSegmentsViewState();
}

class _AiAnswerSegmentsViewState extends State<AiAnswerSegmentsView> {
  /// 组件建立时已经有的段数：它们不播入场动画。
  late final int _initialCount = widget.live ? widget.segments.length : 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final segments = widget.segments;
    final live = widget.live;
    final actions = widget.actions;
    final keyPrefix = widget.keyPrefix;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final (index, segment) in segments.indexed)
          _entrance(
            index,
            Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : 10),
              child: switch (segment) {
                AiProcessSegment() => AiProcessFold(
                  key: ValueKey<String>('$keyPrefix-fold-$index'),
                  segment: segment,
                  actions: actions,
                  live: live && index == segments.length - 1,
                  clock: widget.clock,
                  status: widget.status,
                  // 进行中的一轮不记展开状态（落库后换成这条回答的 id）。
                  storageId: live ? null : '$keyPrefix:fold:$index',
                ),
                AiNavigationSegment(:final call) => AiDestinationCard(
                  key: ValueKey<String>('$keyPrefix-${call.id}'),
                  call: call,
                  actions: actions,
                ),
                AiChangeSegment(:final calls) => AiChangeGroupCard(
                  key: ValueKey<String>('$keyPrefix-change-${calls.first.id}'),
                  calls: calls,
                  live: live,
                  actions: actions,
                  storagePrefix: live ? null : keyPrefix,
                ),
                AiConfirmSegment(:final call) => AiConfirmCard(
                  key: ValueKey<String>('$keyPrefix-${call.id}'),
                  call: call,
                  actions: actions,
                ),
                // 回答正文可长按选字，菜单与输入框同一套。
                AiTextSegment(:final text) => AppSelectionArea(
                  child: AiRevealedMarkdown(
                    text: text,
                    live: live && index == segments.length - 1,
                    handoff: index == segments.length - 1
                        ? widget.handoff
                        : null,
                    onCitation: actions.onCitation,
                    bodyStyle: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                  ),
                ),
              },
            ),
          ),
      ],
    );
  }

  /// 进行中新出现的段套一层入场动画；同一位置始终是同一种外壳（按位置
  /// 判断），段的内容换了动画状态也不丢。
  Widget _entrance(int index, Widget child) {
    if (!widget.live || index < _initialCount) return child;
    return ExpressiveEntrance(duration: ExpressiveMotion.medium, child: child);
  }
}
