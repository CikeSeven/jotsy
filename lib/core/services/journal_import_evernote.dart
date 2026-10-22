import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'journal_import_block_writer.dart';
import 'journal_import_evernote_enml.dart';
import 'journal_import_evernote_reader.dart';
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
/// 都会还原；加密片段无法解密，原始密文与提示保留在 metadata 并在预览说明。
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
  final issues = JournalImportIssues();
  for (final file in files) {
    final notebook = p.basenameWithoutExtension(file.path);
    try {
      readEnexNotes(file, (note) {
        final encrypted = enexEncryptedFragments(note);
        if (encrypted.isNotEmpty) issues.partialContent++;
        entries.add(
          _parseNote(
            note,
            media,
            keys,
            notebook: notebook,
            keepNotebook: files.length > 1,
            fallbackTime: file.lastModifiedSync(),
            encrypted: encrypted,
          ),
        );
      });
      recognized = true;
    } on XmlException {
      throw const JournalImportFormatException(JournalImportSource.evernote);
    } on FormatException {
      throw const JournalImportFormatException(JournalImportSource.evernote);
    }
  }
  if (!recognized) {
    throw const JournalImportFormatException(JournalImportSource.evernote);
  }
  return JournalImportParseResult(
    entries: entries,
    missingMediaCount: media.missingCount,
    partialContentCount: issues.partialContent,
  );
}

JournalImportEntry _parseNote(
  XmlElement note,
  JournalMediaStager media,
  JournalKeyRegistry keys, {
  required String notebook,
  required bool keepNotebook,
  required DateTime fallbackTime,
  required List<Map<String, String>> encrypted,
}) {
  final resources = EnexResources(media);
  for (final resource in note.findElements('resource')) {
    resources.add(resource);
  }
  final writer = JournalBlockWriter();
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
  final createdAt = created ?? updated ?? fallbackTime;
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
    sourceMetadata: {if (encrypted.isNotEmpty) 'encryptedFragments': encrypted},
  );
}

/// `20240228T183012Z`（UTC）；兼容个别导出里的 `20180306T91108 AMZ`。
DateTime? _enexTime(String? raw) {
  final text = raw?.trim() ?? '';
  final parsed = parseJournalDateTime(text);
  if (parsed != null) {
    return parsed;
  }
  final match = RegExp(
    r'^(\d{4})(\d{2})(\d{2})T(\d{1,2})(\d{2})(\d{2}) ?([AP]M)Z$',
    caseSensitive: false,
  ).firstMatch(text);
  if (match == null) return null;
  if (!isJournalCalendarDate(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      ) ||
      int.parse(match.group(4)!) < 1 ||
      int.parse(match.group(4)!) > 12 ||
      int.parse(match.group(5)!) > 59 ||
      int.parse(match.group(6)!) > 59) {
    return null;
  }
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
