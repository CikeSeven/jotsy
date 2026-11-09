// 智能体的对话历史（纯函数）：把以前各轮按当时发给模型的样子原样回放。
//
// 为什么原样回放（借鉴 pi 等编码智能体的只追加记录）：
// - 模型看到的是自己真实发出的工具调用与拿到的结果，不会去模仿一段“做过
//   哪些操作”的文字（以前在回答后附这样一段，模型学着在正文里写调用记录、
//   以为这样就生成了按钮，实际一个工具都没调）；
// - 前缀只追加不改写：下一轮请求的开头与上一轮最后一次请求逐字相同，服务商
//   的前缀缓存整段命中（DeepSeek 等自动缓存；Anthropic 另由客户端打断点）。
//
// 回放规则：
// - 用户消息：发出时的全文（`meta.prompt`：现在几点、对话范围、固定的日记
//   与问题），旧消息没有时用原文；
// - 智能体回答（`meta.refs` 存在的新记录）：逐步回放——助手消息（同一服务商
//   与模型时带协议回放数据与调用上的签名、这一步的原文、工具调用）+ 工具
//   结果（结果原文；没有结果的调用补一条错误结果，保证每个调用都有结果），
//   最后是回答正文，引用编号原样保留（编号在整段对话里连续，见
//   [aiAgentCitationsOf]）；
// - 检索问答的回答、旧版本的智能体回答：只回放正文，去掉引用编号（那时的
//   编号每轮从 D1 开始，留着会张冠李戴）；
// - 出错 / 停止的回答：回放已经做过的步骤（可能已经改了数据），不回放半截
//   正文；没有步骤的出错回答不进历史；
// - 换了服务商或模型：协议回放数据与调用签名不带（只认产生它的模型），调用
//   id 规范成各家都接受的字符；
// - 窗口：超过字数预算时从最旧的整轮开始丢，一次丢到预算的一半，之后起点
//   不变直到再次超出（按顺序模拟得到起点，每轮重算结果一样），缓存只在丢的
//   那一轮断一次；单轮超过预算一半的回答只回放正文；
// - 图片：用户附图放在提问文字之前，“查看图片”看过的图放在那一步的工具
//   结果之后，与当轮发出时的位置一致。这里只给出槽位
//   （[aiAgentHistoryImageSlots]），由调用方统一加载成图片或占位后经
//   [aiAgentHistory] 的 `images` 插回；窗口大小按每张图固定的字数
//   （[kAiImageHistoryWeight]）计，不因加载结果而变。

import 'dart:convert';

import '../../../core/database/app_database.dart';
import '../../../core/services/ai/ai_models.dart';
import '../../../core/services/ai/ai_provider_config.dart';
import '../../../l10n/app_localizations.dart';
import '../models/ai_agent_steps.dart';
import 'ai_agent_image_slots.dart';
import 'ai_chat_images.dart';
import 'ai_citations.dart';
import 'ai_task_prompts.dart';

/// 历史的默认字数预算（字符）；模型写明了上下文长度时按它，见
/// [aiAgentHistoryBudget]。
const int kAiAgentHistoryBudget = 128000;

/// 模型 [model] 的历史预算：上下文长度（token）按字符计，夹在 3.2 万到
/// 20 万字之间——再长对质量与延迟都没好处，缓存价也不是零。
int aiAgentHistoryBudget(AiModelConfig model) {
  final window = model.contextWindow;
  if (window == null || window <= 0) return kAiAgentHistoryBudget;
  return window.clamp(32000, 200000);
}

/// 一条消息 meta 里与回放有关的几项。
class _RowMeta {
  _RowMeta(this.json);

  factory _RowMeta.of(AiMessageRow row) {
    try {
      final decoded = jsonDecode(row.meta);
      if (decoded is Map) return _RowMeta(decoded.cast<String, Object?>());
    } on FormatException {
      // 坏掉的 meta 当作没有。
    }
    return _RowMeta(const <String, Object?>{});
  }

  final Map<String, Object?> json;

  String? get prompt =>
      json['prompt'] is String ? json['prompt'] as String : null;

  /// 原样回放格式的智能体回答（步骤里存着结果原文、引用编号整段连续）。
  bool get replayable => json['agent'] == true && json['refs'] is List;

  String? get providerId =>
      json['providerId'] is String ? json['providerId'] as String : null;

  String? get model => json['model'] is String ? json['model'] as String : null;

  String? get scopeDiary =>
      json['scopeDiary'] is String ? json['scopeDiary'] as String : null;

  List<AiCitation> get refs => [
    if (json['refs'] case final List<Object?> list)
      for (final item in list)
        if (AiCitation.fromJson(item) case final citation?) citation,
  ];
}

/// 以前各轮回放成的消息。
class AiAgentHistory {
  const AiAgentHistory(this.messages, {this.scopeDiaries = const <String>{}});

  final List<AiMessage> messages;

  /// 窗口里的用户消息已经带过全文的固定日记（不必再放进这一轮）。
  final Set<String> scopeDiaries;
}

/// 把 [rows]（旧 → 新，不含这一轮的问题）回放成消息。[target] 是这一轮的
/// 模型，决定协议回放数据带不带；[budget] 为字数预算（字符）；[images] 为
/// 窗口里各图片槽位（[aiAgentHistoryImageSlots]）加载成的图片或占位文字，
/// 缺的槽位不放东西（不带图片的调用方传空表即可）。
AiAgentHistory aiAgentHistory(
  List<AiMessageRow> rows, {
  required AppLocalizations l10n,
  required AiResolvedModel target,
  int budget = kAiAgentHistoryBudget,
  Map<String, AiPart> images = const <String, AiPart>{},
}) {
  final units = _units(rows, l10n: l10n, target: target, budget: budget);
  final start = aiAgentWindowStart([
    for (final unit in units) unit.size,
  ], budget);
  final messages = <AiMessage>[];
  final scopeDiaries = <String>{};
  for (final unit in units.skip(start)) {
    for (final entry in unit.entries) {
      _push(messages, entry.withImages(images));
    }
    scopeDiaries.addAll(unit.scopeDiaries);
  }
  // 各家协议都要求以用户消息开头：开头是助手（预览页“继续聊聊”带进来的
  // 那条回应）时补一句“请回应这篇日记”。
  if (messages.isNotEmpty && messages.first.role == AiRole.assistant) {
    messages.insert(
      0,
      AiMessage.text(AiRole.user, l10n.aiPromptReplyInstruction),
    );
  }
  return AiAgentHistory(messages, scopeDiaries: scopeDiaries);
}

/// 窗口里的图片槽位，按在请求里出现的顺序（与 [aiAgentHistory] 同一窗口）。
List<AiImageSlot> aiAgentHistoryImageSlots(
  List<AiMessageRow> rows, {
  required AppLocalizations l10n,
  required AiResolvedModel target,
  int budget = kAiAgentHistoryBudget,
}) {
  final units = _units(rows, l10n: l10n, target: target, budget: budget);
  final start = aiAgentWindowStart([
    for (final unit in units) unit.size,
  ], budget);
  return [
    for (final unit in units.skip(start))
      for (final entry in unit.entries) ...[
        ...entry.leading,
        ...entry.trailing,
      ],
  ];
}

/// 整段对话里智能体用过的引用编号（新记录的 `meta.refs`），这一轮的
/// `AiCitationBook` 接着编号：旧结果里的 [D3] 仍指同一篇。
List<AiCitation> aiAgentCitationsOf(List<AiMessageRow> rows) => [
  for (final row in rows)
    if (row.role == AiMessageRole.assistant) ..._RowMeta.of(row).refs,
];

/// 回放出的一条消息，以及插在它前面（用户附图）与后面（工具结果后的图）
/// 的图片槽位。
class _Entry {
  const _Entry(
    this.message, {
    this.leading = const <AiImageSlot>[],
    this.trailing = const <AiImageSlot>[],
  });

  final AiMessage message;
  final List<AiImageSlot> leading;
  final List<AiImageSlot> trailing;

  /// 估算的大小：文字按字符，每张图按固定字数（不看加载结果）。
  int get size =>
      _sizeOf(<AiMessage>[message]) +
      (leading.length + trailing.length) * kAiImageHistoryWeight;

  AiMessage withImages(Map<String, AiPart> images) {
    if (leading.isEmpty && trailing.isEmpty) return message;
    return AiMessage(message.role, <AiPart>[
      for (final slot in leading) ?images[slot.key],
      ...message.parts,
      for (final slot in trailing) ?images[slot.key],
    ]);
  }
}

/// 一轮（以用户消息开头，或开头的助手消息）回放成的消息与估算的大小。
class _Unit {
  _Unit();

  final List<_Entry> entries = <_Entry>[];
  final Set<String> scopeDiaries = <String>{};
  int size = 0;
}

List<_Unit> _units(
  List<AiMessageRow> rows, {
  required AppLocalizations l10n,
  required AiResolvedModel target,
  required int budget,
}) {
  final imagesByMessage = <String, List<AiChatImage>>{};
  for (final image in aiChatImages(rows)) {
    (imagesByMessage[image.messageId] ??= <AiChatImage>[]).add(image);
  }
  final units = <_Unit>[];
  _Unit? current;
  for (final row in rows) {
    final meta = _RowMeta.of(row);
    if (row.role != AiMessageRole.assistant) {
      // 连续的用户消息（中间的回答出错了）留在同一轮里。
      if (current == null ||
          current.entries.lastOrNull?.message.role != AiRole.user) {
        current = _Unit();
        units.add(current);
      }
      final images = imagesByMessage[row.messageId] ?? const <AiChatImage>[];
      var text = meta.prompt ?? row.content;
      // 检索问答里只发了图片的问题没有存全文：用“[N 张图片]”占住文字。
      if (text.trim().isEmpty && images.isNotEmpty) {
        text = l10n.aiChatImagesSummary(images.length);
      }
      final entry = _Entry(
        AiMessage.text(AiRole.user, text),
        leading: aiQuestionImageSlots(images),
      );
      current.entries.add(entry);
      current.size += entry.size;
      if (meta.scopeDiary case final id?) current.scopeDiaries.add(id);
      continue;
    }
    if (current == null) {
      current = _Unit();
      units.add(current);
    }
    final full = meta.replayable
        ? _replayAnswer(row, meta, target: target)
        : null;
    final fullSize = full == null ? 0 : _entriesSize(full);
    // 单轮太大（读了很多日记）时只回放正文：整轮都放会挤掉其他轮。
    final entries = full != null && fullSize <= budget ~/ 2
        ? full
        : [
            for (final message in _plainAnswer(
              row,
              keepCitations: meta.replayable,
            ))
              _Entry(message),
          ];
    current.entries.addAll(entries);
    current.size += _entriesSize(entries);
  }
  return units;
}

int _entriesSize(List<_Entry> entries) =>
    entries.fold<int>(0, (sum, entry) => sum + entry.size);

/// 窗口起点：按顺序累加各轮大小，超出 [budget] 时把起点往后挪到剩下的不超过
/// 预算的一半。只看已有各轮的大小，所以每轮重算得到同样的起点（只有再次超出
/// 时才变），缓存只在这时断一次。
int aiAgentWindowStart(List<int> sizes, int budget) {
  var start = 0;
  var total = 0;
  for (var i = 0; i < sizes.length; i++) {
    total += sizes[i];
    if (total <= budget) continue;
    while (start <= i && total > budget ~/ 2) {
      total -= sizes[start];
      start++;
    }
  }
  return start;
}

/// 新记录的智能体回答：逐步回放，最后是正文（出错 / 停止时不带半截正文）。
List<_Entry> _replayAnswer(
  AiMessageRow row,
  _RowMeta meta, {
  required AiResolvedModel target,
}) {
  final sameModel =
      meta.providerId == target.provider.id && meta.model == target.model.id;
  final entries = <_Entry>[];
  for (final step in AiAgentStepRecord.decodeList(row.steps)) {
    if (step.calls.isEmpty) continue;
    entries
      ..add(
        _Entry(
          AiMessage(AiRole.assistant, <AiPart>[
            if (sameModel) ...step.replay,
            if (step.text.isNotEmpty) AiTextPart(step.text),
            for (final call in step.calls)
              AiToolCallPart(_call(call, sameModel: sameModel)),
          ]),
        ),
      )
      ..add(
        _Entry(
          AiMessage(AiRole.user, <AiPart>[
            for (final call in step.calls)
              AiToolResultPart(
                callId: sameModel ? call.id : aiPortableCallId(call.id),
                name: call.tool,
                content: call.result ?? _missingResult(call.status),
                isError: call.result == null || call.resultIsError,
              ),
          ]),
          // 当轮各调用附的图片按调用顺序接在全部结果之后（与
          // `AiAgentLoop` 一致）。
          trailing: [
            for (final call in step.calls)
              for (final (index, image) in call.images.indexed)
                AiImageSlot(
                  key: aiCallImageKey(row.messageId, call.id, index),
                  label: image.label,
                  source: image.source,
                  diaryId: image.diaryId,
                ),
          ],
        ),
      );
  }
  if (row.status == AiMessageStatus.done && row.content.trim().isNotEmpty) {
    entries.add(_Entry(AiMessage.text(AiRole.assistant, row.content)));
  }
  return entries;
}

/// 只回放正文：检索问答、旧记录与超大的回答。
List<AiMessage> _plainAnswer(AiMessageRow row, {required bool keepCitations}) {
  if (row.status == AiMessageStatus.error) return const <AiMessage>[];
  final text = keepCitations ? row.content : aiStripCitations(row.content);
  if (text.trim().isEmpty) return const <AiMessage>[];
  return <AiMessage>[AiMessage.text(AiRole.assistant, text)];
}

AiToolCall _call(AiAgentCallRecord call, {required bool sameModel}) {
  final raw = call.args.length == 1 ? call.args[kAiRawArgumentsKey] : null;
  return AiToolCall(
    id: sameModel ? call.id : aiPortableCallId(call.id),
    name: call.tool,
    argumentsRaw: raw is String ? raw : jsonEncode(call.args),
    arguments: raw is String ? null : call.args,
    argumentsError: raw is String ? 'Invalid arguments.' : null,
    idFromProvider: sameModel ? call.idFromProvider : false,
    providerData: sameModel ? call.providerData : null,
  );
}

/// 没有结果的调用（停止、中断）补的错误结果：每个调用都得有结果，否则各家
/// 协议都拒收。
String _missingResult(AiToolCallStatus status) => jsonEncode(<String, Object?>{
  'error': status == AiToolCallStatus.cancelled
      ? 'Not run: the user stopped this turn.'
      : 'No result: the turn was interrupted before this call finished.',
});

/// 跨服务商时把调用 id 规范成各家都接受的写法（字母、数字、`_`、`-`，最长
/// 64）。同一模型时原样保留，前缀才与当时发出的一致。
String aiPortableCallId(String id) {
  final cleaned = id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  final value = cleaned.isEmpty ? 'call' : cleaned;
  return value.length > 64 ? value.substring(0, 64) : value;
}

int _sizeOf(List<AiMessage> messages) {
  var size = 0;
  for (final message in messages) {
    for (final part in message.parts) {
      size += switch (part) {
        AiTextPart(:final text) => text.length,
        AiToolCallPart(:final call) =>
          call.name.length + call.argumentsRaw.length,
        AiToolResultPart(:final content) => content.length,
        AiReplayPart(:final data) => jsonEncode(data).length,
        AiImagePart() => kAiImageHistoryWeight,
      };
    }
  }
  return size;
}

/// 追加一条消息，与上一条同一角色时合并（各家协议都要求用户 / 助手交替；
/// 工具结果后面紧跟下一轮的问题时并进同一条用户消息，客户端会照样拆开）。
void _push(List<AiMessage> messages, AiMessage message) {
  if (message.parts.isEmpty) return;
  final last = messages.lastOrNull;
  if (last != null && last.role == message.role) {
    messages[messages.length - 1] = AiMessage(last.role, <AiPart>[
      ...last.parts,
      ...message.parts,
    ]);
    return;
  }
  messages.add(message);
}
