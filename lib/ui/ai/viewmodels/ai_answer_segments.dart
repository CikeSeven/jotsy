// 一条回答怎么分段（DESIGN §5.29“回答的分段”）：纯函数，落库的回答与正在
// 进行的一轮共用。
//
// 用户只需要看的东西露在外面，过程折起来：
// - 思考过程折叠块（[AiProcessSegment]）：各步与最后的思考内容、调用工具前
//   说的过渡句、只读工具、以及任何失败的调用（只调了 `open_page` 的那一步
//   之前说的话不算过渡句，是回答的一部分，作为正文露在外面）；
// - 前往卡片（[AiNavigationSegment]）：成功的 `open_page`，用户要点；
// - 改动卡片（[AiChangeSegment]）：写 / 删除类调用（执行中、成功可撤销、已
//   撤销、已拒绝、已停止、已中断），相邻的合成一组；
// - 确认卡片（[AiConfirmSegment]）：等用户点“执行 / 删除”；
// - 正文（[AiTextSegment]）：最后的回答。
//
// 相邻的可折叠项合成一个折叠块（中间没有露在外面的东西时，跨步骤也合在
// 一起），所以通常一条回答只有一个折叠块。进行中的一轮：这一步正在流的思考
// 进折叠块，正在流的文字先当正文显示（若随后调了工具，下一次构建时它成了
// 过渡句、收进折叠块，界面以 AnimatedSize 平滑收起）。

import '../models/ai_agent_steps.dart';
import '../tools/ai_tool.dart';
import '../tools/ai_tool_registry.dart';

sealed class AiAnswerSegment {
  const AiAnswerSegment();
}

/// 思考过程折叠块。
class AiProcessSegment extends AiAnswerSegment {
  AiProcessSegment(this.items);

  final List<AiProcessItem> items;

  /// 思考总时长（毫秒；不显示思考文字时也计入，摘要照样写“思考了 N 秒”）。
  int thinkingMs = 0;

  /// 有没有思考（含不显示文字的）。
  bool thought = false;

  int get toolCount => items.whereType<AiToolItem>().length;

  int get failedCount => items
      .whereType<AiToolItem>()
      .where((item) => item.call.status == AiToolCallStatus.failed)
      .length;
}

sealed class AiProcessItem {
  const AiProcessItem();
}

/// 一段思考文字。
class AiThoughtItem extends AiProcessItem {
  const AiThoughtItem(this.text);

  final String text;
}

/// 调用工具前说的话。
class AiNarrationItem extends AiProcessItem {
  const AiNarrationItem(this.text);

  final String text;
}

/// 一个折进过程里的调用（只读、失败的，或还在进行的前往）。
class AiToolItem extends AiProcessItem {
  const AiToolItem(this.call);

  final AiAgentCallRecord call;
}

/// 模型正在准备某个调用（还没有参数）。
class AiPreparingItem extends AiProcessItem {
  const AiPreparingItem(this.tool);

  final String tool;
}

class AiNavigationSegment extends AiAnswerSegment {
  const AiNavigationSegment(this.call);

  final AiAgentCallRecord call;
}

class AiChangeSegment extends AiAnswerSegment {
  AiChangeSegment(this.calls);

  final List<AiAgentCallRecord> calls;
}

class AiConfirmSegment extends AiAnswerSegment {
  const AiConfirmSegment(this.call);

  final AiAgentCallRecord call;
}

class AiTextSegment extends AiAnswerSegment {
  const AiTextSegment(this.text);

  final String text;
}

/// 一个调用该放在哪里。
enum AiCallPlacement { process, navigation, change, confirm }

AiCallPlacement aiCallPlacement(AiAgentCallRecord call) {
  final effect = aiToolByName(call.tool)?.effect ?? AiToolEffect.read;
  if (call.status == AiToolCallStatus.failed) return AiCallPlacement.process;
  switch (effect) {
    case AiToolEffect.read:
      return AiCallPlacement.process;
    case AiToolEffect.navigate:
      return call.status == AiToolCallStatus.succeeded &&
              call.navigation != null
          ? AiCallPlacement.navigation
          : AiCallPlacement.process;
    case AiToolEffect.write || AiToolEffect.destructive:
      return call.status == AiToolCallStatus.awaitingConfirmation
          ? AiCallPlacement.confirm
          : AiCallPlacement.change;
  }
}

/// 按上面的规则分段。
///
/// [steps] 为已收齐的工具步骤；[reasoning] / [text] 为最后一段（落库的
/// 回答，或进行中这一步正在流的内容），[thinkingMs] 为最后一段的思考时长。
/// [preparingTool] 为进行中模型正在准备的调用；[live] 时即使什么都还没有
/// 也给出一个折叠块（界面在里面显示“正在思考”）。
List<AiAnswerSegment> buildAiAnswerSegments({
  required List<AiAgentStepRecord> steps,
  required String reasoning,
  required String text,
  required bool showReasoning,
  int thinkingMs = 0,
  String? preparingTool,
  bool live = false,
}) {
  final segments = <AiAnswerSegment>[];

  AiProcessSegment process() {
    final last = segments.isEmpty ? null : segments.last;
    if (last is AiProcessSegment) return last;
    final created = AiProcessSegment(<AiProcessItem>[]);
    segments.add(created);
    return created;
  }

  void think(String content, int ms) {
    if (content.trim().isEmpty && ms <= 0) return;
    final block = process();
    block
      ..thought = true
      ..thinkingMs += ms;
    if (showReasoning && content.trim().isNotEmpty) {
      block.items.add(AiThoughtItem(content.trim()));
    }
  }

  for (final step in steps) {
    think(step.reasoning, step.thinkingMs);
    if (step.text.trim().isNotEmpty) {
      // 这一步只调了 open_page：前往卡片不取回任何信息，模型在它之前说的
      // 是给用户看的回答（常见写法是先写完回答、再附卡片），露在外面；其余
      // 步骤调用前说的是过渡句，折进过程。
      if (_onlyNavigation(step)) {
        segments.add(AiTextSegment(step.text.trim()));
      } else {
        process().items.add(AiNarrationItem(step.text.trim()));
      }
    }
    for (final call in step.calls) {
      switch (aiCallPlacement(call)) {
        case AiCallPlacement.process:
          process().items.add(AiToolItem(call));
        case AiCallPlacement.navigation:
          segments.add(AiNavigationSegment(call));
        case AiCallPlacement.confirm:
          segments.add(AiConfirmSegment(call));
        case AiCallPlacement.change:
          final last = segments.isEmpty ? null : segments.last;
          if (last is AiChangeSegment) {
            last.calls.add(call);
          } else {
            segments.add(AiChangeSegment(<AiAgentCallRecord>[call]));
          }
      }
    }
  }
  think(reasoning, thinkingMs);
  if (preparingTool != null) {
    process().items.add(AiPreparingItem(preparingTool));
  }
  // 进行中、正文还没开始：总有一个折叠块承载“正在思考”。
  if (live && text.trim().isEmpty && segments.lastOrNull is! AiProcessSegment) {
    process();
  }
  if (!live) _mergeThoughtOnlyFolds(segments);
  if (text.trim().isNotEmpty) segments.add(AiTextSegment(text));
  return segments;
}

bool _onlyNavigation(AiAgentStepRecord step) =>
    step.calls.isNotEmpty &&
    step.calls.every(
      (call) => aiToolByName(call.tool)?.effect == AiToolEffect.navigate,
    );

/// 卡片之后只剩思考（没有工具、没有过渡句）的折叠块并进第一个折叠块：
/// 不在卡片与正文之间再冒出一枚只写“思考了 2 秒”的胶囊。思考文字接在第一个
/// 折叠块的时间线末尾，时长累加。进行中不并（最后一块要显示“正在思考”）。
void _mergeThoughtOnlyFolds(List<AiAnswerSegment> segments) {
  final first = segments.whereType<AiProcessSegment>().firstOrNull;
  if (first == null) return;
  segments.removeWhere((segment) {
    if (identical(segment, first) || segment is! AiProcessSegment) {
      return false;
    }
    if (!segment.items.every((item) => item is AiThoughtItem)) return false;
    first.items.addAll(segment.items);
    first
      ..thinkingMs += segment.thinkingMs
      ..thought = first.thought || segment.thought;
    return true;
  });
}
