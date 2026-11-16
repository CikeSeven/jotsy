// 导图 AI 的请求构建与回复解析（纯函数，不碰数据库与网络）。
//
// 输入：[AiPromptKit]（回答语言、偏好与隐私）+ 这次的材料（主题、导图、
// 日记）。输出：[AiRequest]（模型名留空，由 `AiService` 换成实际模型）。
// 提示词文本全部来自 ARB（`aiPromptMindMap*`）。
//
// 回复一律要求写成 Markdown 大纲（`# 中心主题` + 两格缩进的 `- ` 列表），
// 解析只经 [mindMapAiParseMap] / [mindMapAiParseBranches]（复用
// `mindMapFromMarkdown`）：流式生成时对“到目前为止的文字”反复解析即可，
// 半截的最后一行只是暂时少几个字，下一次解析自然补齐。

import '../../../core/database/app_database.dart';
import '../../../core/database/mind_map/mind_map_document.dart';
import '../../../core/database/mind_map/mind_map_text.dart';
import '../../../core/services/ai/ai_models.dart';
import '../../../core/services/ai/ai_provider_config.dart';
import '../../../core/services/mind_map_io/mind_map_markdown_io.dart';
import '../../ai/viewmodels/ai_prompt_builder.dart';

/// AI 生成导图的风格。
enum MindMapAiStyle { divergent, structured, study }

/// 生成导图的层数选项（中心主题以下）。
const List<int> kMindMapAiDepths = <int>[2, 3, 4];

/// 发给模型的导图大纲最多多少行：再多的主题对“展开 / 总结”帮助不大，
/// 只会占满上下文。
const int _maxOutlineLines = 400;

String _outline(MindMapDocument document, String untitled) {
  final lines = mindMapOutlineText(document, untitled: untitled).split('\n');
  if (lines.length <= _maxOutlineLines) return lines.join('\n');
  return '${lines.take(_maxOutlineLines).join('\n')}\n…';
}

String _system(AiPromptKit kit) =>
    kit.system(task: kit.l10n.aiPromptMindMapSystem);

AiRequest _request(AiPromptKit kit, String user, {int maxOutput = 4000}) =>
    AiRequest(
      model: '',
      system: _system(kit),
      temperature: kit.temperature(AiTaskKind.writing),
      maxOutputTokens: maxOutput,
      messages: <AiMessage>[AiMessage.text(AiRole.user, user)],
    );

/// 按主题生成整张导图。
AiRequest mindMapAiGenerateRequest(
  AiPromptKit kit, {
  required String topic,
  required int depth,
  required MindMapAiStyle style,
  String extra = '',
}) {
  final l10n = kit.l10n;
  final user = <String>[
    l10n.aiPromptMindMapGenerate(topic.trim()),
    l10n.aiPromptMindMapDepth(depth),
    switch (style) {
      MindMapAiStyle.divergent => l10n.aiPromptMindMapStyleDivergent,
      MindMapAiStyle.structured => l10n.aiPromptMindMapStyleStructured,
      MindMapAiStyle.study => l10n.aiPromptMindMapStyleStudy,
    },
    if (extra.trim().isNotEmpty) l10n.aiPromptMindMapExtra(extra.trim()),
    l10n.aiPromptMindMapFormat,
  ].join('\n\n');
  return _request(kit, user);
}

/// 给 [nodeId] 添加子主题：带上从中心主题到它的路径与整张导图。
AiRequest mindMapAiExpandRequest(
  AiPromptKit kit, {
  required MindMapDocument document,
  required String nodeId,
  required String untitled,
  String extra = '',
}) {
  final l10n = kit.l10n;
  final index = document.index;
  final path = <String>[];
  String? cursor = nodeId;
  while (cursor != null) {
    final text = _line(index[cursor]?.text ?? '');
    path.insert(0, text.isEmpty ? untitled : text);
    cursor = index.parentOf(cursor);
  }
  final topic = path.last;
  final user = <String>[
    l10n.aiPromptMindMapExpand(topic),
    if (path.length > 1) l10n.aiPromptMindMapPath(path.join(' > ')),
    l10n.aiPromptMindMapCurrent(_outline(document, untitled)),
    if (extra.trim().isNotEmpty) l10n.aiPromptMindMapExtra(extra.trim()),
    l10n.aiPromptMindMapExpandFormat,
  ].join('\n\n');
  return _request(kit, user, maxOutput: 2000);
}

/// 由一篇日记生成导图（日记按隐私设置带元数据，正文受“最多发送”约束）。
AiRequest mindMapAiFromDiaryRequest(
  AiPromptKit kit, {
  required AiContextDiary diary,
  String extra = '',
}) {
  final l10n = kit.l10n;
  final user = <String>[
    l10n.aiPromptMindMapFromDiary,
    if (extra.trim().isNotEmpty) l10n.aiPromptMindMapExtra(extra.trim()),
    l10n.aiPromptMindMapFormat,
    kit.diary(diary, maxWords: kit.prefs.privacy.contextBudget),
  ].join('\n\n');
  return _request(kit, user);
}

/// 总结整张导图（回复为普通 Markdown）。
AiRequest mindMapAiSummaryRequest(
  AiPromptKit kit, {
  required MindMapDocument document,
  required String untitled,
}) {
  final l10n = kit.l10n;
  final user = <String>[
    l10n.aiPromptMindMapSummarize,
    _outline(document, untitled),
  ].join('\n\n');
  return AiRequest(
    model: '',
    system: kit.system(withLength: true),
    temperature: kit.temperature(AiTaskKind.writing),
    messages: <AiMessage>[AiMessage.text(AiRole.user, user)],
  );
}

/// 把整张导图的回复解析成中心主题；[topic] 不为空时中心主题固定为它（用户
/// 给的主题比模型改写的更可靠）。还没有任何分支时为 null。
MindMapNode? mindMapAiParseMap(String reply, {String topic = ''}) {
  final root = mindMapFromMarkdown(_outlineOnly(reply), fallbackTitle: topic);
  if (root == null) return null;
  final fixed = _line(topic);
  final result = fixed.isEmpty ? root : root.copyWith(text: fixed);
  return result.children.isEmpty ? null : result;
}

/// 把“添加子主题”的回复解析成新的子主题列表（可能带下一级）。模型偶尔
/// 仍写了 `# 标题`：那时取标题下的列表。
List<MindMapNode> mindMapAiParseBranches(String reply) {
  final root = mindMapFromMarkdown(_outlineOnly(reply));
  if (root == null) return const <MindMapNode>[];
  return <MindMapNode>[
    for (final child in root.children)
      if (child.text.trim().isNotEmpty || child.children.isNotEmpty) child,
  ];
}

final RegExp _outlineLine = RegExp(r'^\s*(?:#{1,6}\s|[-*+]\s|\d+[.)]\s)');

/// 只留下大纲行（标题与列表项）：去掉包住回复的代码围栏（流式时可能只有
/// 开头那一行）与模型偶尔附带的说明文字——拒绝或闲聊的回复由此读不出
/// 主题，而不是变成一个写着“抱歉……”的主题。
String _outlineOnly(String reply) =>
    reply.split('\n').where((line) => _outlineLine.hasMatch(line)).join('\n');

String _line(String text) => text.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();
