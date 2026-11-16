import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../../database/diary_blocks/diary_link_target.dart';
import '../../database/mind_map/mind_map_document.dart';

/// 导图 ↔ XMind 文件（`.xmind`，zip 包）（纯函数）。
///
/// 写出 XMind 2020 起的格式：`content.json`（工作表数组，第一张的
/// `rootTopic`）+ `metadata.json` + `manifest.json`。读取时先找
/// `content.json`，没有再读 XMind 8 的 `content.xml`。主题的标题、子主题
/// （`children.attached`）、备注（`notes.plain.content`）、网址（`href`）、
/// 标签（`labels`）、图标（`markers[].markerId`，对应见 [_xmindMarkers]）、
/// 收起（`branch: folded`）与结构（`structureClass`，对应见
/// [_xmindStructures]）双向转换；认不出的忽略。坏文件返回 null，不抛出。

/// XMind 图标 id ↔ 贴纸 id（同一贴纸只写第一个对应）。
const List<(String, String)> _xmindMarkers = <(String, String)>[
  ('priority-1', 'priority:1'),
  ('priority-2', 'priority:2'),
  ('priority-3', 'priority:3'),
  ('priority-4', 'priority:4'),
  ('priority-5', 'priority:5'),
  ('priority-6', 'priority:6'),
  ('priority-7', 'priority:6'),
  ('priority-8', 'priority:6'),
  ('priority-9', 'priority:6'),
  ('task-start', 'progress:0'),
  ('task-quarter', 'progress:25'),
  ('task-half', 'progress:50'),
  ('task-3quar', 'progress:75'),
  ('task-done', 'progress:100'),
  ('flag-red', 'flag:red'),
  ('flag-orange', 'flag:orange'),
  ('flag-yellow', 'flag:yellow'),
  ('flag-green', 'flag:green'),
  ('flag-blue', 'flag:blue'),
  ('flag-purple', 'flag:purple'),
  ('star-red', 'star:red'),
  ('star-orange', 'star:orange'),
  ('star-yellow', 'star:yellow'),
  ('star-green', 'star:green'),
  ('star-blue', 'star:blue'),
  ('star-purple', 'star:purple'),
  ('smiley-smile', 'face:smile'),
  ('smiley-laugh', 'face:laugh'),
  ('smiley-angry', 'face:angry'),
  ('smiley-cry', 'face:sad'),
  ('smiley-surprise', 'face:surprise'),
  ('smiley-boring', 'face:think'),
  ('symbol-right', 'symbol:check'),
  ('symbol-wrong', 'symbol:cross'),
  ('symbol-question', 'symbol:question'),
  ('symbol-exclam', 'symbol:exclaim'),
  ('symbol-idea', 'symbol:idea'),
  ('symbol-heart', 'symbol:heart'),
];

/// XMind 结构类 ↔ 本应用结构 id。
const List<(String, String)> _xmindStructures = <(String, String)>[
  ('org.xmind.ui.map.unbalanced', 'mind_map'),
  ('org.xmind.ui.map', 'mind_map'),
  ('org.xmind.ui.map.clockwise', 'mind_map'),
  ('org.xmind.ui.logic.right', 'logic_right'),
  ('org.xmind.ui.logic.left', 'logic_left'),
  ('org.xmind.ui.org-chart.down', 'org_down'),
  ('org.xmind.ui.tree.right', 'tree_right'),
  ('org.xmind.ui.timeline.horizontal', 'timeline'),
  ('org.xmind.ui.fishbone.rightHeaded', 'fishbone'),
  ('org.xmind.ui.fishbone.leftHeaded', 'fishbone'),
];

String? _markerFromXmind(String? id) {
  for (final (xmind, ours) in _xmindMarkers) {
    if (xmind == id) return ours;
  }
  return null;
}

String? _markerToXmind(String id) {
  for (final (xmind, ours) in _xmindMarkers) {
    if (ours == id) return xmind;
  }
  return null;
}

/// 写出 `.xmind` 文件的字节。
Uint8List mindMapToXmind(
  MindMapDocument document, {
  String untitled = '',
  String sheetTitle = 'Sheet 1',
  String creator = 'Jotsy',
}) {
  var counter = 0;
  String id() => 'jotsy-${counter++}';
  Map<String, Object?> topic(MindMapNode node, {bool root = false}) {
    final text = node.text.trim();
    final href = node.href?.trim() ?? '';
    final markers = <Map<String, Object?>>[
      for (final icon in node.icons)
        if (_markerToXmind(icon) case final marker?)
          <String, Object?>{'markerId': marker},
    ];
    final note = node.note?.trim() ?? '';
    final structure = root
        ? <String, String>{
            for (final (xmind, ours) in _xmindStructures.reversed) ours: xmind,
          }[document.structure ?? 'mind_map']
        : null;
    return <String, Object?>{
      'id': id(),
      'class': 'topic',
      'title': root && text.isEmpty ? untitled : text,
      'structureClass': ?structure,
      if (href.isNotEmpty && !DiaryLinkTarget.isLink(href)) 'href': href,
      if (node.labels.isNotEmpty) 'labels': node.labels,
      if (markers.isNotEmpty) 'markers': markers,
      if (note.isNotEmpty)
        'notes': <String, Object?>{
          'plain': <String, Object?>{'content': note},
        },
      if (node.collapsed && node.children.isNotEmpty) 'branch': 'folded',
      if (node.children.isNotEmpty)
        'children': <String, Object?>{
          'attached': <Map<String, Object?>>[
            for (final child in node.children) topic(child),
          ],
        },
    };
  }

  final content = <Map<String, Object?>>[
    <String, Object?>{
      'id': id(),
      'class': 'sheet',
      'title': sheetTitle,
      'rootTopic': topic(document.root, root: true),
    },
  ];
  final metadata = <String, Object?>{
    'creator': <String, Object?>{'name': creator},
  };
  final manifest = <String, Object?>{
    'file-entries': <String, Object?>{
      'content.json': <String, Object?>{},
      'metadata.json': <String, Object?>{},
    },
  };
  final archive = Archive();
  void add(String name, Object? json) {
    final bytes = utf8.encode(jsonEncode(json));
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('content.json', content);
  add('metadata.json', metadata);
  add('manifest.json', manifest);
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// 读出 `.xmind` 文件：中心主题与结构 id（认不出的结构为 null）。
({MindMapNode root, String? structure})? mindMapFromXmind(Uint8List bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    return null;
  }
  ArchiveFile? find(String name) {
    for (final file in archive.files) {
      if (file.isFile && file.name == name) return file;
    }
    return null;
  }

  final json = find('content.json');
  if (json != null) {
    try {
      final decoded = jsonDecode(utf8.decode(json.content as List<int>));
      if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
        final sheet = decoded.first as Map;
        final root = sheet['rootTopic'];
        if (root is Map) {
          var counter = 0;
          final node = _fromJsonTopic(root, () => 'x${counter++}');
          return (root: node, structure: _structureOf(root['structureClass']));
        }
      }
    } catch (_) {
      // 落到 content.xml。
    }
  }
  final xml = find('content.xml');
  if (xml == null) return null;
  try {
    final document = XmlDocument.parse(utf8.decode(xml.content as List<int>));
    final topic = document
        .findAllElements('sheet')
        .firstOrNull
        ?.childElements
        .where((element) => element.name.local == 'topic')
        .firstOrNull;
    if (topic == null) return null;
    var counter = 0;
    return (
      root: _fromXmlTopic(topic, () => 'x${counter++}'),
      structure: _structureOf(topic.getAttribute('structure-class')),
    );
  } catch (_) {
    return null;
  }
}

String? _structureOf(Object? raw) {
  for (final (xmind, ours) in _xmindStructures) {
    if (xmind == raw) return ours;
  }
  return null;
}

MindMapNode _fromJsonTopic(Map topic, String Function() id) {
  final children = topic['children'];
  final attached = children is Map ? children['attached'] : null;
  final notes = topic['notes'];
  final plain = notes is Map ? notes['plain'] : null;
  final note = plain is Map ? plain['content'] : null;
  final markers = topic['markers'];
  final labels = topic['labels'];
  final href = topic['href'];
  return MindMapNode(
    id: id(),
    text: topic['title'] is String ? (topic['title'] as String).trim() : '',
    note: note is String && note.trim().isNotEmpty ? note : null,
    href: href is String && href.startsWith('http') ? href : null,
    labels: labels is List
        ? <String>[
            for (final l in labels)
              if (l is String) l,
          ]
        : const <String>[],
    icons: markers is List
        ? <String>[
            for (final m in markers)
              if (m is Map)
                if (_markerFromXmind(m['markerId'] as String?) case final id?)
                  id,
          ]
        : const <String>[],
    collapsed: topic['branch'] == 'folded',
    children: attached is List
        ? <MindMapNode>[
            for (final child in attached)
              if (child is Map) _fromJsonTopic(child, id),
          ]
        : const <MindMapNode>[],
  );
}

MindMapNode _fromXmlTopic(XmlElement topic, String Function() id) {
  XmlElement? child(String name) => topic.childElements
      .where((element) => element.name.local == name)
      .firstOrNull;
  final children = <MindMapNode>[];
  final container = child('children');
  if (container != null) {
    for (final topics in container.childElements) {
      if (topics.name.local != 'topics' ||
          (topics.getAttribute('type') ?? 'attached') != 'attached') {
        continue;
      }
      for (final sub in topics.childElements) {
        if (sub.name.local == 'topic') children.add(_fromXmlTopic(sub, id));
      }
    }
  }
  final plain = child('notes')?.childElements
      .where((element) => element.name.local == 'plain')
      .firstOrNull
      ?.innerText
      .trim();
  final href = topic.attributes
      .where((attribute) => attribute.name.local == 'href')
      .firstOrNull
      ?.value;
  return MindMapNode(
    id: id(),
    text: child('title')?.innerText.trim() ?? '',
    note: plain == null || plain.isEmpty ? null : plain,
    href: href != null && href.startsWith('http') ? href : null,
    labels: <String>[
      for (final label in child('labels')?.childElements ?? <XmlElement>[])
        if (label.innerText.trim().isNotEmpty) label.innerText.trim(),
    ],
    icons: <String>[
      for (final ref in child('marker-refs')?.childElements ?? <XmlElement>[])
        if (_markerFromXmind(ref.getAttribute('marker-id')) case final id?) id,
    ],
    collapsed: topic.getAttribute('branch') == 'folded',
    children: children,
  );
}
