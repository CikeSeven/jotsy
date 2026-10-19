import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'journal_import_delta_writer.dart';
import 'journal_import_evernote_enml.dart';
import 'journal_import_html.dart';
import 'journal_import_media.dart';
import 'journal_import_models.dart';
import 'journal_import_support.dart';

/// 解析 Evernote / 印象笔记的 ENEX 导出：每个笔记本导出一个 `.enex`，可多选
/// 后打包成 ZIP，也可直接选一个 `.enex`。
///
/// `<en-export>` 下每个 `<note>` 一篇：`title`、`created`/`updated`
/// （`yyyymmddThhmmssZ`，UTC）、多个 `tag`、`note-attributes`（经纬度等）、
/// `content`（CDATA 包裹的 ENML，即带 `en-media`/`en-todo`/`en-crypt` 的
/// XHTML）与 `resource`（base64 附件）。ENML 中 `<en-media hash>` 的 hash
/// 是附件解码后字节的 MD5，附件元素本身不带 hash，需要自己计算；正文没有
/// 引用的附件追加在末尾。v10 的待办列表（`--en-todo`/`--en-checked` 样式）、
/// 代码块（`--en-codeblock` 样式）与任务（`<task>` 元素，正文里只有占位块）
/// 都会还原；加密片段无法解密，丢弃。
///
/// ENEX 不含笔记 ID 与笔记本名：稳定键由笔记本文件名、创建时间与标题组成；
/// 多个笔记本一起导入时记下文件名作为所在笔记本（[JournalImportEntry.notebooks]），
/// 只导入一个文件时不记。大文件按笔记分块读取，不把
/// 整个文件一次读入内存。
JournalImportParseResult parseEvernoteExport(
  JournalImportInput input,
  JournalMediaStager media,
) {
  final files = input.extractedPath == null
      ? [File(input.filePath)]
      : listJournalExportFiles(input.extractedPath!)
            .where((file) => p.extension(file.path).toLowerCase() == '.enex')
            .toList(growable: false);
  final entries = <JournalImportEntry>[];
  final keys = JournalKeyRegistry();
  var recognized = false;
  for (final file in files) {
    final notebook = p.basenameWithoutExtension(file.path);
    _forEachNote(file, (xml) {
      final note = _parseXml(xml);
      if (note == null) return;
      recognized = true;
      entries.add(
        _parseNote(
          note,
          media,
          keys,
          notebook: notebook,
          keepNotebook: files.length > 1,
        ),
      );
    });
  }
  if (!recognized) {
    throw const JournalImportFormatException(JournalImportSource.evernote);
  }
  return JournalImportParseResult(
    entries: entries,
    missingMediaCount: media.missingCount,
  );
}

/// 逐块解码文件，每凑齐一个 `<note>…</note>` 就交给 [onNote]。ENML 在 CDATA
/// 里且已转义，正文不会出现字面的 `</note>`。
void _forEachNote(File file, void Function(String xml) onNote) {
  final RandomAccessFile handle;
  try {
    handle = file.openSync();
  } on FileSystemException {
    return;
  }
  final decoded = StringBuffer();
  final sink = const Utf8Decoder(
    allowMalformed: true,
  ).startChunkedConversion(StringConversionSink.fromStringSink(decoded));
  final splitter = _NoteSplitter(onNote);
  try {
    while (true) {
      final chunk = handle.readSync(1 << 20);
      if (chunk.isEmpty) {
        sink.close();
      } else {
        sink.add(chunk);
      }
      splitter.feed(decoded.toString());
      decoded.clear();
      if (chunk.isEmpty) break;
    }
  } finally {
    handle.closeSync();
  }
}

/// 按 `<note>` / `</note>` 切分流式文本。每块只扫描新到的文字（加上可能
/// 跨块的标记残余），单篇笔记带着几十 MB 附件时也不会反复重扫、反复拼接
/// 整段字符串。
class _NoteSplitter {
  _NoteSplitter(this._onNote);

  static const String _open = '<note>';
  static const String _close = '</note>';

  final void Function(String xml) _onNote;
  final StringBuffer _note = StringBuffer();
  bool _inNote = false;

  /// 上一块末尾可能是半个标记的几个字符。
  String _carry = '';

  void feed(String text) {
    var offset = 0;
    while (offset < text.length) {
      final rest = text.substring(offset);
      final probe = _carry + rest;
      final marker = _inNote ? _close : _open;
      final found = probe.indexOf(marker);
      if (found < 0) {
        if (_inNote) _note.write(rest);
        final keep = marker.length - 1;
        _carry = probe.length > keep
            ? probe.substring(probe.length - keep)
            : probe;
        return;
      }
      // 标记可能从 _carry 中开始；consumed 是本块中到标记末尾的字符数。
      final consumed = found + marker.length - _carry.length;
      _carry = '';
      if (_inNote) {
        _note.write(rest.substring(0, consumed));
        _onNote(_note.toString());
        _note.clear();
      } else {
        _note.write(_open);
      }
      _inNote = !_inNote;
      offset += consumed;
    }
  }
}

/// 解析一篇笔记的 XML。印象笔记偶尔在图注里留下未转义的 `&`，严格解析
/// 失败时把这种 `&` 转义后重试一次。
XmlElement? _parseXml(String xml) {
  for (final source in [
    xml,
    xml.replaceAll(
      RegExp(r'&(?!(?:[a-zA-Z][a-zA-Z0-9]*|#\d+|#x[0-9a-fA-F]+);)'),
      '&amp;',
    ),
  ]) {
    try {
      return XmlDocument.parse(source).rootElement;
    } on XmlException {
      continue;
    }
  }
  return null;
}

JournalImportEntry _parseNote(
  XmlElement note,
  JournalMediaStager media,
  JournalKeyRegistry keys, {
  required String notebook,
  required bool keepNotebook,
}) {
  final resources = EnexResources(media);
  for (final resource in note.findElements('resource')) {
    resources.add(resource);
  }
  final writer = JournalDeltaWriter();
  final enml = note.getElement('content')?.innerText.trim() ?? '';
  final body = enmlToHtml(enml, note);
  JournalHtmlConverter(
    writer,
    resolveEmbed: resources.resolve,
  ).appendNodes(body.nodes.toList());
  resources.unreferenced().forEach(writer.embed);
  final content = writer.build();

  final attributes = note.getElement('note-attributes');
  final latitude = double.tryParse(
    attributes?.getElement('latitude')?.innerText.trim() ?? '',
  );
  final longitude = double.tryParse(
    attributes?.getElement('longitude')?.innerText.trim() ?? '',
  );
  final hasCoordinate = isJournalCoordinate(latitude, longitude);
  final title = note.getElement('title')?.innerText.trim() ?? '';
  final created = _enexTime(note.getElement('created')?.innerText);
  final updated = _enexTime(note.getElement('updated')?.innerText);
  final createdAt = created ?? updated ?? DateTime.now();
  return JournalImportEntry(
    sourceKey: keys.unique(
      '$notebook|${(created ?? updated)?.toUtc().toIso8601String()}|$title',
    ),
    title: title,
    contentJson: content.contentJson,
    contentText: content.contentText,
    createdAt: createdAt,
    updatedAt: updated,
    tags: [
      for (final tag in note.findElements('tag'))
        if (tag.innerText.trim() case final name when name.isNotEmpty) name,
    ],
    notebooks: [if (keepNotebook && notebook.isNotEmpty) notebook],
    location: journalString(attributes?.getElement('place-name')?.innerText),
    latitude: hasCoordinate ? latitude : null,
    longitude: hasCoordinate ? longitude : null,
  );
}

/// `20240228T183012Z`（UTC）；兼容个别导出里的 `20180306T91108 AMZ`。
DateTime? _enexTime(String? raw) {
  final text = raw?.trim() ?? '';
  final parsed = DateTime.tryParse(text);
  if (parsed != null) {
    return parsed.year <= 1970
        ? null
        : (parsed.isUtc ? parsed.toLocal() : parsed);
  }
  final match = RegExp(
    r'^(\d{4})(\d{2})(\d{2})T(\d{1,2})(\d{2})(\d{2}) ?([AP]M)Z$',
    caseSensitive: false,
  ).firstMatch(text);
  if (match == null) return null;
  var hour = int.parse(match.group(4)!) % 12;
  if (match.group(7)!.toUpperCase() == 'PM') hour += 12;
  return DateTime.utc(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
    hour,
    int.parse(match.group(5)!),
    int.parse(match.group(6)!),
  ).toLocal();
}
