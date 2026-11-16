import 'package:xml/xml.dart';

import '../../database/diary_blocks/diary_link_target.dart';
import '../../database/mind_map/mind_map_document.dart';

/// 导图 ↔ OPML 2.0 与 FreeMind（`.mm`）（纯函数）。
///
/// OPML：`outline` 元素嵌套（文字在 `text`），备注写在 `_note`，网址写在
/// `url`；没有图标。
/// FreeMind：`node` 元素嵌套（文字在 `TEXT`），网址写在 `LINK`，备注为 `richcontent
/// TYPE="NOTE"`，图标为 `icon` 元素的 `BUILTIN`（与本应用贴纸的对应见
/// [_freeMindIcons]）。日记链接只在应用里打得开，导出时不写。导入时坏文件
/// 返回 null，不抛出。

String mindMapToOpml(MindMapDocument document, {String untitled = ''}) {
  final builder = XmlBuilder()
    ..processing('xml', 'version="1.0" encoding="UTF-8"');
  final title = _line(document.root.text);
  void outline(MindMapNode node) {
    builder.element(
      'outline',
      nest: () {
        builder.attribute(
          'text',
          node == document.root && title.isEmpty ? untitled : _line(node.text),
        );
        final note = node.note?.trim() ?? '';
        if (note.isNotEmpty) builder.attribute('_note', note);
        final href = _webHref(node);
        if (href != null) builder.attribute('url', href);
        for (final child in node.children) {
          outline(child);
        }
      },
    );
  }

  builder.element(
    'opml',
    nest: () {
      builder.attribute('version', '2.0');
      builder.element(
        'head',
        nest: () =>
            builder.element('title', nest: title.isEmpty ? untitled : title),
      );
      builder.element('body', nest: () => outline(document.root));
    },
  );
  return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
}

MindMapNode? mindMapFromOpml(String source, {String fallbackTitle = ''}) {
  final XmlDocument xml;
  try {
    xml = XmlDocument.parse(source);
  } on XmlException {
    return null;
  }
  final body = xml.findAllElements('body').firstOrNull;
  if (body == null) return null;
  var counter = 0;
  MindMapNode convert(XmlElement element) {
    final text =
        element.getAttribute('text') ?? element.getAttribute('title') ?? '';
    final note = element.getAttribute('_note');
    final url = element.getAttribute('url') ?? element.getAttribute('htmlUrl');
    return MindMapNode(
      id: 'p${counter++}',
      text: text.trim(),
      note: note == null || note.trim().isEmpty ? null : note,
      href: url == null || url.trim().isEmpty ? null : url.trim(),
      children: <MindMapNode>[
        for (final child in element.childElements)
          if (child.name.local == 'outline') convert(child),
      ],
    );
  }

  final tops = <XmlElement>[
    for (final child in body.childElements)
      if (child.name.local == 'outline') child,
  ];
  if (tops.isEmpty) return null;
  if (tops.length == 1) return convert(tops.single);
  final title =
      xml.findAllElements('title').firstOrNull?.innerText.trim() ??
      fallbackTitle;
  return MindMapNode(
    id: 'p${counter++}',
    text: title.isEmpty ? fallbackTitle : title,
    children: <MindMapNode>[for (final top in tops) convert(top)],
  );
}

/// FreeMind 内置图标 ↔ 贴纸 id。
const Map<String, String> _freeMindIcons = <String, String>{
  'full-1': 'priority:1',
  'full-2': 'priority:2',
  'full-3': 'priority:3',
  'full-4': 'priority:4',
  'full-5': 'priority:5',
  'full-6': 'priority:6',
  'button_ok': 'symbol:check',
  'button_cancel': 'symbol:cross',
  'help': 'symbol:question',
  'messagebox_warning': 'symbol:exclaim',
  'idea': 'symbol:idea',
  'flag': 'flag:red',
  'flag-orange': 'flag:orange',
  'flag-yellow': 'flag:yellow',
  'flag-green': 'flag:green',
  'flag-blue': 'flag:blue',
  'flag-pink': 'flag:purple',
  'bookmark': 'star:yellow',
  'ksmiletris': 'face:smile',
  'smiley-angry': 'face:angry',
  'smily_bad': 'face:sad',
  'smiley-oh': 'face:surprise',
};

String mindMapToFreeMind(MindMapDocument document, {String untitled = ''}) {
  final reverse = <String, String>{
    for (final entry in _freeMindIcons.entries) entry.value: entry.key,
  };
  final builder = XmlBuilder();
  void node(MindMapNode current, {String? position}) {
    builder.element(
      'node',
      nest: () {
        final text = _line(current.text);
        builder.attribute(
          'TEXT',
          current == document.root && text.isEmpty ? untitled : text,
        );
        if (position != null) builder.attribute('POSITION', position);
        if (current.collapsed && current.children.isNotEmpty) {
          builder.attribute('FOLDED', 'true');
        }
        final href = _webHref(current);
        if (href != null) builder.attribute('LINK', href);
        for (final icon in current.icons) {
          final builtin = reverse[icon];
          if (builtin != null) {
            builder.element(
              'icon',
              nest: () => builder.attribute('BUILTIN', builtin),
            );
          }
        }
        final note = current.note?.trim() ?? '';
        if (note.isNotEmpty) {
          builder.element(
            'richcontent',
            nest: () {
              builder.attribute('TYPE', 'NOTE');
              builder.element(
                'html',
                nest: () => builder.element(
                  'body',
                  nest: () {
                    for (final line in note.split('\n')) {
                      builder.element('p', nest: line);
                    }
                  },
                ),
              );
            },
          );
        }
        for (final child in current.children) {
          node(
            child,
            position: current == document.root
                ? (child.side == 'l' ? 'left' : 'right')
                : null,
          );
        }
      },
    );
  }

  builder.element(
    'map',
    nest: () {
      builder.attribute('version', '1.0.1');
      node(document.root);
    },
  );
  return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
}

MindMapNode? mindMapFromFreeMind(String source) {
  final XmlDocument xml;
  try {
    xml = XmlDocument.parse(source);
  } on XmlException {
    return null;
  }
  final map = xml.findAllElements('map').firstOrNull;
  final top = map?.childElements
      .where((element) => element.name.local == 'node')
      .firstOrNull;
  if (top == null) return null;
  var counter = 0;
  MindMapNode convert(XmlElement element, {bool root = false}) {
    var text = element.getAttribute('TEXT') ?? '';
    String? note;
    for (final rich in element.childElements) {
      if (rich.name.local != 'richcontent') continue;
      final type = rich.getAttribute('TYPE');
      final content = rich.findAllElements('p').isEmpty
          ? rich.innerText.trim()
          : rich
                .findAllElements('p')
                .map((p) => p.innerText.trim())
                .where((line) => line.isNotEmpty)
                .join('\n');
      if (type == 'NODE' && text.isEmpty) text = content;
      if (type == 'NOTE' && content.isNotEmpty) note = content;
    }
    final link = element.getAttribute('LINK');
    final position = element.getAttribute('POSITION');
    return MindMapNode(
      id: 'f${counter++}',
      text: text.trim(),
      note: note,
      href: link == null || link.trim().isEmpty || link.startsWith('#')
          ? null
          : link.trim(),
      collapsed: element.getAttribute('FOLDED') == 'true',
      side: root
          ? null
          : position == 'left'
          ? 'l'
          : position == 'right'
          ? 'r'
          : null,
      icons: <String>[
        for (final icon in element.childElements)
          if (icon.name.local == 'icon')
            if (_freeMindIcons[icon.getAttribute('BUILTIN')] case final id?) id,
      ],
      children: <MindMapNode>[
        for (final child in element.childElements)
          if (child.name.local == 'node') convert(child),
      ],
    );
  }

  // POSITION 只出现在根下的直接子主题上（左右之分）。
  return convert(top, root: true);
}

String _line(String text) => text.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();

/// 网址链接（日记链接只在应用里打得开，导出时不写）。
String? _webHref(MindMapNode node) {
  final href = node.href?.trim() ?? '';
  if (href.isEmpty || DiaryLinkTarget.isLink(href)) return null;
  return href;
}
