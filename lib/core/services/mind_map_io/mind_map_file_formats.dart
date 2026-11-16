import 'dart:convert';
import 'dart:typed_data';

import '../../database/mind_map/mind_map_document.dart';
import 'mind_map_markdown_io.dart';
import 'mind_map_xml_formats.dart';
import 'mind_map_xmind_io.dart';

/// 导图能读写的文件格式与按扩展名分派的导入入口（纯 Dart）。
enum MindMapFileFormat {
  xmind('xmind', 'application/vnd.xmind.workbook'),
  opml('opml', 'text/x-opml'),
  freeMind('mm', 'application/x-freemind'),
  markdown('md', 'text/markdown');

  const MindMapFileFormat(this.extension, this.mimeType);

  final String extension;
  final String mimeType;

  /// 导入时认的扩展名（不含点，小写）。
  static const List<String> importExtensions = <String>[
    'xmind',
    'opml',
    'mm',
    'md',
    'markdown',
    'txt',
  ];
}

/// 一次导入的结果：中心主题（节点 id 只是临时的）与文件里的结构 id。
typedef MindMapImport = ({MindMapNode root, String? structure});

/// 按文件名的扩展名解析 [bytes]；读不出导图时为 null。[fallbackTitle] 为
/// 文件里没有中心主题文字时的替代（通常是去掉扩展名的文件名）。
MindMapImport? importMindMapFile(
  String fileName,
  Uint8List bytes, {
  String? fallbackTitle,
}) {
  final dot = fileName.lastIndexOf('.');
  final extension = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
  final title =
      fallbackTitle ?? (dot < 0 ? fileName : fileName.substring(0, dot));
  if (extension == 'xmind') return mindMapFromXmind(bytes);
  final text = _decodeText(bytes);
  final MindMapNode? root = switch (extension) {
    'opml' => mindMapFromOpml(text, fallbackTitle: title),
    'mm' => mindMapFromFreeMind(text),
    _ => mindMapFromMarkdown(text, fallbackTitle: title),
  };
  return root == null ? null : (root: root, structure: null);
}

String _decodeText(Uint8List bytes) {
  var text = utf8.decode(bytes, allowMalformed: true);
  if (text.startsWith('﻿')) text = text.substring(1);
  return text;
}
