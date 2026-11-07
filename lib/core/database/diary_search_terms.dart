/// 搜索关键词的拆词与 LIKE 转义（纯函数，无 IO）。
///
/// 数据库查询（列表、计数、预览翻页、留言命中）与界面高亮共用这一处口径：
/// 搜索框里以空白分隔的多个词须**全部**出现（每个词各自在标题、正文或留言
/// 里任一处即可），高亮也按同一组词标出，两边不会对不上。
library;

/// 一次搜索最多参与匹配的词数：每个词都会在 SQL 里展开成一组 LIKE，词再多
/// 既无实际意义，也会让查询无谓变慢。超出的词忽略。
const int maxSearchTerms = 8;

final RegExp _whitespace = RegExp(r'\s+');

/// 把搜索框里的文字拆成参与匹配的词：按任意空白（含全角空格）切分，
/// 忽略大小写去重（保留第一次出现的写法），最多 [maxSearchTerms] 个。
///
/// 空串或全是空白时为空表。
List<String> splitSearchTerms(String keyword) {
  final trimmed = keyword.trim();
  if (trimmed.isEmpty) {
    return const <String>[];
  }
  final seen = <String>{};
  final terms = <String>[];
  for (final raw in trimmed.split(_whitespace)) {
    if (raw.isEmpty || !seen.add(raw.toLowerCase())) {
      continue;
    }
    terms.add(raw);
    if (terms.length == maxSearchTerms) {
      break;
    }
  }
  return List<String>.unmodifiable(terms);
}

/// LIKE 的转义：用户输入里的 `%`、`_` 与转义符本身按字面匹配。配合
/// `LIKE ? ESCAPE '\'` 使用。
String escapeLike(String value) =>
    value.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');

/// 某个词的“包含”模式：`%词%`（已转义）。
String containsLikePattern(String term) => '%${escapeLike(term)}%';
