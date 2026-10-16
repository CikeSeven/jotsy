import 'dart:convert';
import 'dart:io';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'journal_import_delta_writer.dart';
import 'journal_import_html.dart';
import 'journal_import_note_bridge.dart';

/// 读取「笔记互迁」的 HTML 导出；不是该格式时返回 null。
///
/// 合并模式是一个离线阅读器：`<script id="note-data">` 里的 JSON 数组每项
/// 一篇（`html` 字段为渲染好的正文）；多文件模式每篇一个页面，正文在
/// `<main class="single"><article>` 中。两者正文结构相同：
/// `<h2>标题</h2><div class="meta">创建时间：…<br>修改时间：…</div>` 之后是
/// 由受控富文本模型生成的块（参考项目 `richtext.py` 的 `block_html`）。
NoteBridgeDocument? readNoteBridgeHtml(File file, String text) {
  final document = html_parser.parse(text);
  final platform = noteBridgePlatformOf(document.querySelector('title')?.text);
  final data = document.querySelector('script#note-data');
  final containers = <dom.Element>[];
  if (data != null) {
    final Object? records;
    try {
      records = jsonDecode(data.text);
    } on FormatException {
      return null;
    }
    if (records is! List) return null;
    for (final record in records.whereType<Map>()) {
      final html = record['html'];
      if (html is! String) continue;
      final container = dom.Element.tag('article');
      html_parser.parseFragment(html).reparentChildren(container);
      containers.add(container);
    }
  } else {
    containers.addAll(document.querySelectorAll('main.single > article'));
  }
  final notes = containers.map(_note).nonNulls.toList(growable: false);
  if (notes.isEmpty) return null;
  return NoteBridgeDocument(
    file,
    NoteBridgeFormat.html,
    notes,
    platform: platform,
  );
}

/// 拆出开头的标题与时间行，其余为正文；开头不是这种结构时返回 null。
NoteBridgeNote? _note(dom.Element container) {
  final heading = container.children.firstOrNull;
  final meta = heading?.nextElementSibling;
  if (heading?.localName != 'h2' ||
      meta == null ||
      !meta.classes.contains('meta')) {
    return null;
  }
  final stamp = RegExp(
    r'创建时间：(.*?)修改时间：(.*)$',
    dotAll: true,
  ).firstMatch(meta.text);
  if (stamp == null) return null;
  final title = heading!.text.trim();
  heading.remove();
  meta.remove();
  return NoteBridgeNote(
    title: title,
    created: parseNoteBridgeTime(stamp.group(1)),
    updated: parseNoteBridgeTime(stamp.group(2)),
    writeBody: (writer, media) => _writeBody(container, writer, media),
  );
}

/// 先把导出专用的标记还原成通用 HTML，再交给 [JournalHtmlConverter]：
///
/// - 图注 `<figcaption>` 是附件文件名、`.warning` 是导出时的转换提示，都不
///   是笔记内容，丢弃（“附件未获取”计入缺失媒体）；
/// - 正文标题因页面标题占用了 `<h2>` 而整体下移一级（一级标题是 `<h2>`），
///   这里移回；
/// - 待办是 `<p class="todo">☑ 文本</p>`，改成带 `data-checked` 的列表项；
/// - 每个列表项单独成 `<ul>/<ol>`，层级只体现在 `margin-left`（每级
///   1.4em），按层级套上外层列表，转换器据此算出缩进；
/// - 其他附件是 `<p>📎 <a href download>名称</a></p>`，转为附件嵌入。
void _writeBody(
  dom.Element container,
  JournalDeltaWriter writer,
  NoteBridgeMedia media,
) {
  for (final caption in container.querySelectorAll('figcaption')) {
    caption.remove();
  }
  for (final warning in container.querySelectorAll('.warning')) {
    if (warning.text.trim() == '附件未获取') media.markMissing();
    warning.remove();
  }
  for (final heading in container.querySelectorAll('h2, h3, h4, h5, h6')) {
    final level = int.parse(heading.localName!.substring(1));
    final shifted = dom.Element.tag('h${level - 1}');
    heading.reparentChildren(shifted);
    heading.replaceWith(shifted);
  }
  for (final todo in container.querySelectorAll('p.todo')) {
    final mark = todo.nodes.firstOrNull;
    if (mark is! dom.Text) continue;
    final checked = mark.data.startsWith('☑');
    if (!checked && !mark.data.startsWith('☐')) continue;
    mark.data = mark.data.substring(1).replaceFirst(RegExp(r'^ '), '');
    final item = dom.Element.tag('li')..attributes['data-checked'] = '$checked';
    todo.reparentChildren(item);
    todo.replaceWith(dom.Element.tag('ul')..append(item));
  }
  for (final list in container.querySelectorAll('ul[style], ol[style]')) {
    final indent = RegExp(
      r'margin-left\s*:\s*([\d.]+)em',
    ).firstMatch(list.attributes['style']!);
    final level = indent == null
        ? 0
        : (double.parse(indent.group(1)!) / 1.4).round().clamp(0, 5);
    var current = list;
    for (var i = 0; i < level; i++) {
      final wrapper = dom.Element.tag(list.localName);
      current.replaceWith(wrapper);
      wrapper.append(current);
      current = wrapper;
    }
  }

  final converter = JournalHtmlConverter(
    writer,
    resolveEmbed: (source) => media.resolve(source),
  );
  for (final node in container.nodes.toList()) {
    final file = node is dom.Element && node.localName == 'p'
        ? node.querySelector('a[download]')
        : null;
    if (file == null) {
      converter.appendNodes([node]);
      continue;
    }
    final data = media.resolve(
      file.attributes['href'] ?? '',
      name: file.text.trim(),
    );
    if (data != null) writer.embed(data);
  }
}
