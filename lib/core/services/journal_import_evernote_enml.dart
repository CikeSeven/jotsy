import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart';

import 'journal_import_html.dart';
import 'journal_import_media.dart';
import 'journal_import_support.dart';

/// Evernote ENML 正文与附件的转换：把 `en-todo`、`en-media`、`en-crypt`、
/// v10 的待办样式、代码块与任务占位块改写成通用 HTML，交给
/// [JournalHtmlConverter]；附件按解码后字节的 MD5 与 `en-media` 对应。
/// 纯内存转换，媒体写入经 [JournalMediaStager]。

/// ENML 是 XHTML：`<en-todo/>`、`<en-media …/>` 等自闭合写法在 HTML 解析
/// 中会被当成开标签，把其后的文字吞成子节点（随后删除标记时一并丢失），
/// 所以先展开成成对标签，并去掉 XML 声明与 DOCTYPE。
String _htmlFromEnml(String enml) => enml
    .replaceFirst(RegExp(r'^\s*<\?xml[^>]*\?>'), '')
    .replaceFirst(RegExp(r'^\s*<!DOCTYPE[^>]*>'), '')
    .replaceAllMapped(
      RegExp(r'<([a-zA-Z][\w-]*)(\s[^<>]*?)?\s*/>'),
      (match) => _voidElements.contains(match.group(1)!.toLowerCase())
          ? match.group(0)!
          : '<${match.group(1)}${match.group(2) ?? ''}></${match.group(1)}>',
    );

const Set<String> _voidElements = {
  'area', 'base', 'br', 'col', 'embed', 'hr', 'img', //
  'input', 'link', 'meta', 'source', 'track', 'wbr',
};

/// 把一篇笔记的 ENML 转成 [JournalHtmlConverter] 可直接转换的 HTML 节点树：
/// 展开自闭合标签、去掉 XML 声明，再改写 ENML 专有标记（见 [_normalizeEnml]）。
dom.Element enmlToHtml(String enml, XmlElement note) {
  final body = dom.Element.tag('div');
  html_parser.parseFragment(_htmlFromEnml(enml)).reparentChildren(body);
  _normalizeEnml(body, _tasks(note));
  return body;
}

/// 保留无法解密的原始片段与解密提示；正文仍显示可读内容，预览会说明有
/// 不完整的篇目。密文只进入日记 metadata，随完整备份保留。
List<Map<String, String>> enexEncryptedFragments(XmlElement note) {
  final enml = note.getElement('content')?.innerText ?? '';
  final body = html_parser.parseFragment(_htmlFromEnml(enml));
  return [
    for (final element in body.querySelectorAll('en-crypt'))
      {
        for (final entry in element.attributes.entries)
          '${entry.key}': entry.value,
        'ciphertext': element.text,
      },
  ];
}

/// v10 任务：按 `taskGroupNoteLevelID` 分组、组内按 `sortWeight` 排序，
/// 值为（标题，是否完成）。
Map<String, List<(String, bool)>> _tasks(XmlElement note) {
  final groups = <String, List<(String, String, bool)>>{};
  for (final task in note.findElements('task')) {
    final group = task.getElement('taskGroupNoteLevelID')?.innerText.trim();
    if (group == null || group.isEmpty) continue;
    (groups[group] ??= []).add((
      task.getElement('sortWeight')?.innerText ?? '',
      task.getElement('title')?.innerText.trim() ?? '',
      task.getElement('taskStatus')?.innerText.trim() == 'completed',
    ));
  }
  return {
    for (final MapEntry(:key, :value) in groups.entries)
      key: [
        for (final (_, title, done)
            in value..sort((a, b) => a.$1.compareTo(b.$1)))
          (title, done),
      ],
  };
}

/// 把 ENML 的专有标记改写成 [JournalHtmlConverter] 认识的 HTML。
void _normalizeEnml(dom.Element body, Map<String, List<(String, bool)>> tasks) {
  for (final crypt in body.getElementsByTagName('en-crypt').toList()) {
    crypt.remove();
  }
  for (final element in body.querySelectorAll('[style]')) {
    final style = element.attributes['style']!;
    final group = RegExp(r'--en-task-group\s*:\s*true').hasMatch(style)
        ? RegExp(r'--en-id\s*:\s*([^;]+)').firstMatch(style)?.group(1)?.trim()
        : null;
    if (group != null) {
      final list = dom.Element.tag('ul');
      for (final (title, done) in tasks[group] ?? const <(String, bool)>[]) {
        list.append(
          dom.Element.tag('li')
            ..attributes['data-checked'] = '$done'
            ..text = title,
        );
      }
      element.replaceWith(list);
      continue;
    }
    if (RegExp(r'-(en|evernote)-codeblock\s*:\s*true').hasMatch(style)) {
      final lines = element.children.isEmpty
          ? [element.text]
          : element.children.map((line) => line.text);
      element.replaceWith(dom.Element.tag('pre')..text = lines.join('\n'));
      continue;
    }
    if (element.localName == 'li' && element.parent?.localName == 'ul') {
      final listStyle = element.parent!.attributes['style'] ?? '';
      if (RegExp(r'--en-todo\s*:\s*true').hasMatch(listStyle)) {
        element.attributes['data-checked'] =
            '${RegExp(r'--en-checked\s*:\s*true').hasMatch(style)}';
      }
    }
  }
  for (final todo in body.getElementsByTagName('en-todo').toList()) {
    final checked = '${todo.attributes['checked'] == 'true'}';
    dom.Element? block = todo.parent;
    while (block != null &&
        block != body &&
        !const {'li', 'div', 'p'}.contains(block.localName)) {
      block = block.parent;
    }
    todo.remove();
    if (block == null || block == body) continue;
    final item = block.localName == 'li'
        ? block
        : _closest(block, 'li') ?? _wrapInList(block);
    item.attributes['data-checked'] = checked;
  }
  for (final media in body.getElementsByTagName('en-media').toList()) {
    final hash = media.attributes['hash']?.trim().toLowerCase() ?? '';
    media.replaceWith(dom.Element.tag('img')..attributes['src'] = 'enex:$hash');
  }
}

dom.Element? _closest(dom.Element element, String tag) {
  for (var node = element.parent; node != null; node = node.parent) {
    if (node.localName == tag) return node;
  }
  return null;
}

/// 把单独的待办段落（`<div><en-todo/>文字</div>`）改成单项列表。
dom.Element _wrapInList(dom.Element block) {
  final item = dom.Element.tag('li');
  block.reparentChildren(item);
  block.replaceWith(dom.Element.tag('ul')..append(item));
  return item;
}

/// 一篇笔记的附件：按解码后字节的 MD5 索引，被正文引用时才写入暂存区，
/// 同一附件多处引用只暂存一次。
class EnexResources {
  EnexResources(this._media);

  final JournalMediaStager _media;
  final Map<String, ({List<int> bytes, String name, String mime})> _byHash = {};
  final Map<String, Map<String, Object?>> _staged = {};

  void add(XmlElement resource) {
    final data = resource.getElement('data')?.innerText ?? '';
    final List<int> bytes;
    try {
      bytes = base64.decode(data.replaceAll(RegExp(r'\s+'), ''));
    } on FormatException {
      _media.missingCount++;
      return;
    }
    if (bytes.isEmpty) {
      _media.missingCount++;
      return;
    }
    final mime = resource.getElement('mime')?.innerText.trim() ?? '';
    final fileName = journalString(
      resource
          .getElement('resource-attributes')
          ?.getElement('file-name')
          ?.innerText,
    );
    _byHash.putIfAbsent(
      md5.convert(bytes).toString(),
      () => (bytes: bytes, name: fileName ?? 'media', mime: mime),
    );
  }

  Map<String, Object?>? resolve(String source) {
    if (source.startsWith('enex:')) {
      final hash = source.substring(5);
      final resource = _byHash[hash];
      if (resource == null) {
        _media.missingCount++;
        return null;
      }
      return _staged[hash] ??= _media.embedBytes(
        resource.bytes,
        name: resource.name,
        mime: resource.mime,
      );
    }
    return _media.embedDataUri(source);
  }

  /// 正文没有引用的附件，按导出中的顺序追加在末尾。
  Iterable<Map<String, Object?>> unreferenced() sync* {
    for (final hash in _byHash.keys.toList()) {
      if (_staged.containsKey(hash)) continue;
      yield resolve('enex:$hash')!;
    }
  }
}
