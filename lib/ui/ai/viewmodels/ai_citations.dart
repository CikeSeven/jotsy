// 回答里的日记引用 `[Dn]`（纯函数）：回顾与对话共用。
//
// 模型有时把几处引用写在一起（`[D3, D5]`、`[D3，D5]`、`[D3][D5]`）。显示前
// 经 [aiNormalizeCitations] 拆成一个个 `[Dn]`（渲染成可点的胶囊）；复制、
// 分享与另存为日记时经 [aiStripCitations] 去掉编号（离开这次回答编号就
// 没有意义了）。

final RegExp _group = RegExp(r'\[\s*(D\d{1,3}(?:\s*[,，、]\s*D\d{1,3})*)\s*\]');
final RegExp _separator = RegExp(r'\s*[,，、]\s*');

/// 回答里引用到的编号，按出现先后、去重。
List<String> aiCitedRefs(String text) {
  final refs = <String>[];
  for (final match in _group.allMatches(text)) {
    for (final ref in match.group(1)!.split(_separator)) {
      if (!refs.contains(ref)) refs.add(ref);
    }
  }
  return refs;
}

/// 把合写的引用拆开：`[D3, D5]` → `[D3][D5]`。
String aiNormalizeCitations(String text) => text.replaceAllMapped(
  _group,
  (match) =>
      [for (final ref in match.group(1)!.split(_separator)) '[$ref]'].join(),
);

/// 去掉全部引用编号（连同编号前多出来的一个空格）。
String aiStripCitations(String text) =>
    text.replaceAll(RegExp(r' ?' + _group.pattern), '');
