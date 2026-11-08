// 把 `buildAiAnswerSegments` 的分段画出来：折叠块、前往卡片、改动卡片、
// 确认卡片与正文，段间距 10。落库的回答与正在进行的一轮共用。
//
// 只有最后一段是折叠块、且这一轮在进行时，它才是“进行中”（胶囊写当前
// 动作、转加载指示）；后面已经有卡片或正文时，思考已经结束，显示摘要。

import 'package:flutter/material.dart';

import '../../controllers/ai_thinking_clock.dart';
import '../../viewmodels/ai_answer_segments.dart';
import '../../viewmodels/ai_citations.dart';
import '../../widgets/ai_markdown_view.dart';
import 'ai_action_cards.dart';
import 'ai_answer_actions.dart';
import 'ai_process_fold.dart';

class AiAnswerSegmentsView extends StatelessWidget {
  const AiAnswerSegmentsView({
    super.key,
    required this.keyPrefix,
    required this.segments,
    required this.actions,
    this.live = false,
    this.clock,
    this.status,
  });

  /// 折叠块与卡片的 key 前缀（这条回答的 id）：列表复用时展开状态不串。
  final String keyPrefix;
  final List<AiAnswerSegment> segments;
  final AiAnswerActions actions;
  final bool live;
  final AiThinkingClock? clock;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final (index, segment) in segments.indexed)
          Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 10),
            child: switch (segment) {
              AiProcessSegment() => AiProcessFold(
                key: ValueKey<String>('$keyPrefix-fold-$index'),
                segment: segment,
                actions: actions,
                live: live && index == segments.length - 1,
                clock: clock,
                status: status,
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
              AiTextSegment(:final text) => AiMarkdownView(
                markdown: aiNormalizeCitations(text),
                onCitation: actions.onCitation,
                bodyStyle: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
              ),
            },
          ),
      ],
    );
  }
}
