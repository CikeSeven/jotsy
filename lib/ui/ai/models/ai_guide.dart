// AI 助手的使用指南：打包在 `assets/ai_guide/<语言>/<id>.md` 的文章。
//
// 文章是给模型读的事实材料（Phase 的 Skill 做法：目录常驻系统提示词、正文
// 按需读取）。只有中英两份：日文、俄文界面读英文版，模型按界面语言回答
// （与 `aiPrompt*`、更新日志同一口径）。
//
// 文件格式：开头一段 `---` 包住的头信息（`key: value`，列表写成
// `[a, b]`），之后是 Markdown 正文。头信息字段：
// - id：与文件名相同；title / summary：目录里的一行；
// - features：相关的功能开关（`AppFeatures` 的字段名），关着时读文章的结果
//   里注明；platforms：只在部分平台有的整篇功能（空为全平台）；
// - destinations：相关页面（`AiDestination.id`）；keywords：检索用。
// 解析逐字段容错：缺 id / title 的文章丢弃，其余缺省为空。

import 'package:meta/meta.dart';

@immutable
class AiGuideArticle {
  const AiGuideArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.body,
    this.features = const <String>[],
    this.platforms = const <String>[],
    this.destinations = const <String>[],
    this.keywords = const <String>[],
  });

  final String id;
  final String title;
  final String summary;
  final String body;
  final List<String> features;
  final List<String> platforms;
  final List<String> destinations;
  final List<String> keywords;

  /// 解析一篇文章；格式不对（没有头信息、缺 id 或标题）时返回 null。
  static AiGuideArticle? parse(String raw) {
    final text = raw.replaceAll('\r\n', '\n').trimLeft();
    if (!text.startsWith('---\n')) return null;
    final end = text.indexOf('\n---', 4);
    if (end < 0) return null;
    final fields = <String, String>{};
    for (final line in text.substring(4, end).split('\n')) {
      final colon = line.indexOf(':');
      if (colon <= 0) continue;
      fields[line.substring(0, colon).trim()] = line
          .substring(colon + 1)
          .trim();
    }
    final id = fields['id'] ?? '';
    final title = fields['title'] ?? '';
    if (id.isEmpty || title.isEmpty) return null;
    final bodyStart = text.indexOf('\n', end + 4);
    return AiGuideArticle(
      id: id,
      title: title,
      summary: fields['summary'] ?? '',
      body: bodyStart < 0 ? '' : text.substring(bodyStart + 1).trim(),
      features: _list(fields['features']),
      platforms: _list(fields['platforms']),
      destinations: _list(fields['destinations']),
      keywords: _list(fields['keywords']),
    );
  }

  /// `[a, b, c]`（或不带方括号的 `a, b`）拆成列表。
  static List<String> _list(String? raw) {
    if (raw == null) return const <String>[];
    var value = raw.trim();
    if (value.startsWith('[')) value = value.substring(1);
    if (value.endsWith(']')) value = value.substring(0, value.length - 1);
    return [
      for (final item in value.split(','))
        if (item.trim().isNotEmpty) item.trim(),
    ];
  }
}

/// 一种语言的全部文章（按 id 排序）。
@immutable
class AiGuideCatalog {
  AiGuideCatalog(Iterable<AiGuideArticle> articles)
    : articles = List<AiGuideArticle>.unmodifiable(
        [...articles]..sort((a, b) => a.id.compareTo(b.id)),
      );

  static final AiGuideCatalog empty = AiGuideCatalog(const <AiGuideArticle>[]);

  final List<AiGuideArticle> articles;

  AiGuideArticle? byId(String id) {
    for (final article in articles) {
      if (article.id == id) return article;
    }
    return null;
  }

  /// 放进系统提示词的目录：每篇一行“id：标题 —— 摘要”。
  String get index => [
    for (final article in articles)
      '- ${article.id}: ${article.title} — ${article.summary}',
  ].join('\n');
}
