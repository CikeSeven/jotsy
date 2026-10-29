/// HTML 表格的结构判断（导入与粘贴共用，见 JournalHtmlConverter）：哪些
/// 表格规整到能写成表格块。规整即：
/// - 行只来自 `<thead>` / `<tbody>` / `<tfoot>` / `<tr>`（`<colgroup>` 忽略），
///   格子只有 `<td>` / `<th>`，中间不夹文字、`<caption>` 或别的元素；
/// - 没有 `rowspan` / `colspan` 大于 1 的格子（每行格数是否相同、行列数
///   上限由调用方再查）；
/// - 格子里只有行内格式、`<br>` 与 `<p>`（[journalHtmlCellIsInline]）。
/// 纯 DOM 读取，不写任何东西。
library;

import 'package:html/dom.dart' as dom;

/// HTML 表格的行与格（行优先）；结构不规整时为 null。首行在 `<thead>`
/// 里或全是 `<th>` 时 `headerRow` 为 true。
({List<List<dom.Element>> rows, bool headerRow})? journalHtmlTableRows(
  dom.Element table,
) {
  final rows = <List<dom.Element>>[];
  var headerRow = false;
  bool addRows(Iterable<dom.Node> nodes) {
    for (final node in nodes) {
      if (node is dom.Text) {
        if (node.text.trim().isNotEmpty) return false;
        continue;
      }
      if (node is! dom.Element) continue;
      if (node.localName != 'tr') return false;
      final cells = <dom.Element>[];
      for (final child in node.nodes) {
        if (child is dom.Text) {
          if (child.text.trim().isNotEmpty) return false;
          continue;
        }
        if (child is! dom.Element) continue;
        if (child.localName != 'td' && child.localName != 'th') return false;
        if (_span(child.attributes['rowspan']) > 1 ||
            _span(child.attributes['colspan']) > 1) {
          return false;
        }
        cells.add(child);
      }
      if (cells.isEmpty) return false;
      rows.add(cells);
    }
    return true;
  }

  for (final node in table.nodes) {
    if (node is dom.Text) {
      if (node.text.trim().isNotEmpty) return null;
      continue;
    }
    if (node is! dom.Element) continue;
    switch (node.localName) {
      case 'thead':
        if (rows.isEmpty) headerRow = true;
        if (!addRows(node.nodes)) return null;
      case 'tbody' || 'tfoot':
        if (!addRows(node.nodes)) return null;
      case 'tr':
        // <tr> 直接写在 <table> 下（HTML 解析器通常会补上 <tbody>）。
        if (!addRows([node])) return null;
      case 'colgroup' || 'col':
        continue;
      default:
        return null;
    }
  }
  if (rows.isEmpty) return null;
  if (!headerRow) {
    headerRow = rows.first.every((cell) => cell.localName == 'th');
  }
  return (rows: rows, headerRow: headerRow);
}

/// `rowspan` / `colspan` 的值；缺省或写错时按 1（与浏览器一致）。
int _span(String? raw) => int.tryParse(raw?.trim() ?? '') ?? 1;

/// 格子里只有行内格式、`<br>` 与 `<p>`（以及本就丢弃、不产出内容的
/// `<script>` 等）。
bool journalHtmlCellIsInline(dom.Element cell) => cell.children.every(
  (element) =>
      _cellTags.contains(element.localName) && journalHtmlCellIsInline(element),
);

const Set<String> _cellTags = {
  'b',
  'strong',
  'i',
  'em',
  'cite',
  'dfn',
  'u',
  'ins',
  's',
  'strike',
  'del',
  'code',
  'kbd',
  'samp',
  'tt',
  'a',
  'span',
  'font',
  'mark',
  'big',
  'small',
  'sup',
  'sub',
  'br',
  'p',
  'script',
  'style',
  'noscript',
  'template',
};
