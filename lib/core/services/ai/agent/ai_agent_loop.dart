// 智能体的一轮：模型请求 → 收齐正文 / 思考 / 工具调用 → 依次执行调用 →
// 把结果回传 → 下一步，直到模型不再调用工具。
//
// 职责边界（借鉴 Phase 的 AgentLoop / AgentLoopHost）：本类只管顺序与收尾
// 条件，不碰数据库、界面与具体工具；落库、确认、执行都经 [AiAgentHost]。
//
// - 只有协议正常收尾（[AiFinishReason.isComplete]）的步骤才执行调用；截断或
//   中断时以 [AiAgentEnd.incomplete] 结束，调用一个都不执行；
// - 同一步的多个调用按顺序串行执行，结果按调用 id 一一回传；
// - 最后一步（第 [maxSteps] 步）不许再调用工具（`toolChoice: none`），让模型
//   用已有的结果作答；服务商无视这一点仍要调用时以
//   [AiAgentEnd.stepsExhausted] 结束；
// - 停止：令牌取消后 `AiService` 以 cancelled 抛出，正在执行的工具由宿主
//   自行检查令牌；本类在每个调用前后检查令牌，不再派发新的调用；
// - 请求失败（AiException）原样抛出，已完成的步骤由宿主在
//   [AiAgentHost.onStepOutput] / [AiAgentHost.execute] 里落过库。

import '../../http_cancel_token.dart';
import '../ai_failure.dart';
import '../ai_models.dart';
import '../ai_provider_config.dart';
import '../ai_service.dart';

/// 一步（一次模型请求）收齐的输出。
class AiAgentStepOutput {
  const AiAgentStepOutput({
    required this.text,
    required this.reasoning,
    required this.calls,
    required this.replay,
    this.usage,
    this.finishReason,
  });

  final String text;
  final String reasoning;
  final List<AiToolCall> calls;
  final List<AiReplayPart> replay;
  final AiUsage? usage;
  final AiFinishReason? finishReason;
}

/// 宿主：落库、界面、确认与工具执行。
abstract interface class AiAgentHost {
  /// 模型流的增量（正文、思考、某个调用开始），供界面实时显示。
  void onDelta(int step, AiChunk chunk);

  /// 一步的输出收齐、准备执行其中的调用之前（宿主据此落库这一步）。
  Future<void> onStepOutput(int step, AiAgentStepOutput output);

  /// 执行一个调用（含参数校验、确认与落库），返回回传给模型的结果与要附在
  /// 结果之后的图片。失败也要返回结果（`isError: true`），不要抛出——模型
  /// 会据此改正或换个做法；只有停止（令牌已取消）时可以抛 cancelled。
  Future<AiToolExecution> execute(int step, AiToolCall call);
}

/// 一个调用的执行结果：回传的结果与附在后面的图片（“查看图片”）。
class AiToolExecution {
  const AiToolExecution(this.result, {this.images = const <AiImagePart>[]});

  final AiToolResultPart result;
  final List<AiImagePart> images;
}

enum AiAgentEnd {
  /// 模型给出了不带调用的回答。
  answered,

  /// 最后一步仍要调用工具。
  stepsExhausted,

  /// 响应被截断或中断，其中的调用没有执行。
  incomplete,
}

class AiAgentResult {
  const AiAgentResult({
    required this.end,
    required this.text,
    required this.reasoning,
    required this.steps,
    this.usage,
    this.finishReason,
  });

  final AiAgentEnd end;

  /// 最后一步的正文（不带调用时就是回答）。
  final String text;
  final String reasoning;

  /// 执行过工具的步数。
  final int steps;

  /// 各步用量之和。
  final AiUsage? usage;
  final AiFinishReason? finishReason;
}

class AiAgentLoop {
  AiAgentLoop({
    required this.service,
    required this.model,
    required this.host,
    this.maxSteps = 20,
  }) : assert(maxSteps > 0);

  final AiService service;
  final AiResolvedModel model;
  final AiAgentHost host;
  final int maxSteps;

  Future<AiAgentResult> run(AiRequest request, HttpCancelToken token) async {
    final messages = <AiMessage>[...request.messages];
    AiUsage? total;
    for (var step = 0; step < maxSteps; step++) {
      final last = step == maxSteps - 1;
      final output = await _request(
        step,
        request.copyWith(
          messages: List<AiMessage>.of(messages),
          toolChoice: last ? AiToolChoice.none : request.toolChoice,
        ),
        token,
      );
      if (output.usage case final usage?) {
        total = total == null ? usage : total + usage;
      }
      AiAgentResult finish(AiAgentEnd end) => AiAgentResult(
        end: end,
        text: output.text,
        reasoning: output.reasoning,
        steps: step,
        usage: total,
        finishReason: output.finishReason,
      );
      if (output.calls.isEmpty) return finish(AiAgentEnd.answered);
      if (!(output.finishReason?.isComplete ?? false)) {
        return finish(AiAgentEnd.incomplete);
      }
      if (last) return finish(AiAgentEnd.stepsExhausted);

      await host.onStepOutput(step, output);
      // 工具结果在前，各调用附的图片按调用顺序接在全部结果之后，同在一条
      // 用户消息里（各家客户端都能把图片与结果分开发出；回放时也放在这里）。
      final results = <AiPart>[];
      final images = <AiPart>[];
      for (final call in output.calls) {
        _checkCancelled(token);
        final execution = await host.execute(step, call);
        results.add(execution.result);
        images.addAll(execution.images);
      }
      _checkCancelled(token);
      messages
        ..add(
          AiMessage(AiRole.assistant, <AiPart>[
            ...output.replay,
            if (output.text.isNotEmpty) AiTextPart(output.text),
            for (final call in output.calls) AiToolCallPart(call),
          ]),
        )
        ..add(AiMessage(AiRole.user, <AiPart>[...results, ...images]));
    }
    // 上面最后一步要么作答、要么以 stepsExhausted 返回，走不到这里。
    throw StateError('unreachable');
  }

  Future<AiAgentStepOutput> _request(
    int step,
    AiRequest request,
    HttpCancelToken token,
  ) async {
    final text = StringBuffer();
    final reasoning = StringBuffer();
    final calls = <AiToolCall>[];
    final replay = <AiReplayPart>[];
    AiUsage? usage;
    AiFinishReason? finish;
    await for (final chunk in service.stream(
      model,
      request,
      cancelToken: token,
    )) {
      text.write(chunk.text);
      reasoning.write(chunk.reasoning);
      calls.addAll(chunk.toolCalls);
      replay.addAll(chunk.replay);
      if (chunk.usage case final chunkUsage?) {
        usage = (usage ?? const AiUsage()).merge(chunkUsage);
      }
      finish = chunk.finishReason ?? finish;
      host.onDelta(step, chunk);
    }
    _checkCancelled(token);
    if (finish == AiFinishReason.filtered && text.isEmpty && calls.isEmpty) {
      throw const AiException(AiFailureKind.contentFiltered);
    }
    return AiAgentStepOutput(
      text: text.toString(),
      reasoning: reasoning.toString(),
      calls: calls,
      replay: replay,
      usage: usage,
      finishReason: finish,
    );
  }

  static void _checkCancelled(HttpCancelToken token) {
    if (token.isCancelled) throw const AiException(AiFailureKind.cancelled);
  }
}
