import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'journal_import_delta_writer.dart';
import 'journal_import_media.dart';
import 'journal_import_models.dart';
import 'journal_import_note_bridge_html.dart';
import 'journal_import_note_bridge_text.dart';
import 'journal_import_support.dart';

/// 「笔记互迁」（note-bridge-desktop）导出中标注的平台名 → 来源。
///
/// 导出目录名（`小米笔记-20240101-120000-html`）、合并导出的文件名
/// （`小米笔记.md`）与 HTML 的 `<title>`（`小米笔记 · 笔记互迁`）都以这些
/// 名称开头，见参考项目 `models.py` 的 `PLATFORM_NAMES`。
const Map<String, JournalImportSource> noteBridgePlatformLabels = {
  '小米笔记': JournalImportSource.xiaomiNotes,
  'OPPO笔记': JournalImportSource.oppoNotes,
  'vivo笔记': JournalImportSource.vivoNotes,
  '华为备忘录': JournalImportSource.huaweiNotepad,
  '荣耀笔记': JournalImportSource.honorNotes,
  '魅族笔记': JournalImportSource.meizuNotes,
  'WPS便签': JournalImportSource.wpsNotes,
};

/// 解析「笔记互迁」从手机厂商云端（小米、OPPO、vivo、华为、荣耀、魅族、
/// WPS）导出的笔记。
///
/// 导出是一个目录（常被“打包”成 ZIP）：`导出说明.json`、附件目录
/// `resources/`，以及按所选格式与模式生成的正文文件——合并模式一个
/// `<平台名>.<html|md|txt>`，多文件模式每篇一个 `0001、<标题>.<扩展名>`。
/// 三种格式每篇都以“标题 + 创建时间 + 修改时间”开头（时间带时区，未知时
/// 为“未知”），解析细节见 `journal_import_note_bridge_html.dart` 与
/// `journal_import_note_bridge_text.dart`；DOCX 不支持。
///
/// - 导出不带笔记 ID：稳定键由创建时间（UTC）与标题组成，同一笔记无论以
///   哪种格式导出、何时再导出，都判定为同一篇；
/// - 包内同时有多种格式（如把几次导出放进同一个 ZIP）时只取保真度最高的
///   一种（HTML > Markdown > TXT），避免同一篇导入多次；
/// - 文件标注了别的平台时跳过，全部是别的平台则判为格式不符，提示用户换
///   个来源；未标注平台（多文件导出被单独挑出）时按用户选择的来源导入；
/// - 导出不含分组，不生成标签。
JournalImportParseResult parseNoteBridgeExport(
  JournalImportSource source,
  JournalImportInput input,
  JournalMediaStager media,
) {
  final root = input.extractedPath;
  final files = root == null
      ? [File(input.filePath)]
      : listJournalExportFiles(root);
  final documents = <NoteBridgeDocument>[];
  for (final file in files) {
    final document = _readDocument(file);
    if (document == null || document.notes.isEmpty) continue;
    final platform =
        document.platform ??
        _pathPlatform(
          root == null ? file.path : p.relative(file.path, from: root),
        ) ??
        _pathPlatform(input.filePath);
    if (platform != null && platform != source) continue;
    documents.add(document);
  }
  if (documents.isEmpty) throw JournalImportFormatException(source);
  final format = documents
      .map((document) => document.format)
      .reduce((a, b) => a.index <= b.index ? a : b);

  final entries = <JournalImportEntry>[];
  final keys = JournalKeyRegistry();
  for (final document in documents.where((doc) => doc.format == format)) {
    final resolver = NoteBridgeMedia(
      media,
      directory: document.file.parent.path,
      root: root ?? document.file.parent.path,
    );
    for (final note in document.notes) {
      entries.add(_entry(note, document.file, resolver, keys));
    }
  }
  return JournalImportParseResult(
    entries: entries,
    missingMediaCount: media.missingCount,
  );
}

JournalImportEntry _entry(
  NoteBridgeNote note,
  File file,
  NoteBridgeMedia resolver,
  JournalKeyRegistry keys,
) {
  final writer = JournalDeltaWriter();
  note.writeBody(writer, resolver);
  final content = writer.build();
  final time = note.created ?? note.updated;
  final title = _ownTitle(note.title, content.contentText);
  return JournalImportEntry(
    // 无时间的笔记以正文区分，不用文件时间：每次导出的文件时间都不同。
    sourceKey: keys.unique(
      time == null
          ? 'undated|$title|${content.contentText}'
          : '${time.toUtc().toIso8601String()}|${note.title.trim()}',
    ),
    title: title,
    contentJson: content.contentJson,
    contentText: content.contentText,
    createdAt: time ?? file.lastModifiedSync(),
    updatedAt: note.updated,
  );
}

/// 原笔记没有标题时，笔记互迁用正文首个非空行的前 40 个字符（正文为空时
/// 为“无标题”）充当标题；这种标题与正文重复，导入时还原为无标题。
String _ownTitle(String displayTitle, String contentText) {
  final title = displayTitle.trim();
  final firstLine = contentText
      .split('\n')
      .map((line) => line.trim())
      .firstWhere((line) => line.isNotEmpty, orElse: () => '');
  final derived = firstLine.isEmpty
      ? '无标题'
      : String.fromCharCodes(firstLine.runes.take(40));
  return title == derived ? '' : title;
}

NoteBridgeDocument? _readDocument(File file) {
  final format = switch (p.extension(file.path).toLowerCase()) {
    '.html' || '.htm' => NoteBridgeFormat.html,
    '.md' || '.markdown' => NoteBridgeFormat.markdown,
    '.txt' => NoteBridgeFormat.text,
    _ => null,
  };
  if (format == null) return null;
  final String text;
  try {
    text = utf8
        .decode(file.readAsBytesSync(), allowMalformed: true)
        .replaceFirst('﻿', '');
  } on FileSystemException {
    return null;
  }
  return switch (format) {
    NoteBridgeFormat.html => readNoteBridgeHtml(file, text),
    NoteBridgeFormat.markdown => readNoteBridgeMarkdown(
      file,
      text,
      platform: noteBridgePlatformOf(p.basenameWithoutExtension(file.path)),
    ),
    NoteBridgeFormat.text => readNoteBridgeText(
      file,
      text,
      platform: noteBridgePlatformOf(p.basenameWithoutExtension(file.path)),
    ),
  };
}

/// 名称恰为某平台名（合并导出的文件名、HTML 标题去掉“ · 笔记互迁”）时
/// 返回该平台。
JournalImportSource? noteBridgePlatformOf(String? name) {
  final text = name?.trim();
  if (text == null || text.isEmpty) return null;
  return noteBridgePlatformLabels[text.split(' · ').first.trim()];
}

/// 路径中带导出目录名（`<平台名>-<日期>-<时间>-<格式>`，打包后的 ZIP 同名）
/// 时返回该平台。
JournalImportSource? _pathPlatform(String path) {
  for (final segment in p.split(path).reversed) {
    final match = RegExp(r'^(.+?)-\d{8}-\d{6}').firstMatch(segment);
    final platform = noteBridgePlatformLabels[match?.group(1)];
    if (platform != null) return platform;
  }
  return null;
}

/// 正文格式，按保真度从高到低排列。
enum NoteBridgeFormat { html, markdown, text }

/// 一个导出文件里识别出的笔记，[platform] 为文件自身标注的平台。
class NoteBridgeDocument {
  const NoteBridgeDocument(this.file, this.format, this.notes, {this.platform});

  final File file;
  final NoteBridgeFormat format;
  final List<NoteBridgeNote> notes;
  final JournalImportSource? platform;
}

/// 一篇笔记的标题、时间与正文。正文到确定采用该文件后才由 [writeBody]
/// 转换，被舍弃的格式不会暂存媒体。
class NoteBridgeNote {
  const NoteBridgeNote({
    required this.title,
    required this.created,
    required this.updated,
    required this.writeBody,
  });

  /// 笔记互迁的展示标题（原标题为空时取自正文首行）。
  final String title;
  final DateTime? created;
  final DateTime? updated;
  final void Function(JournalDeltaWriter writer, NoteBridgeMedia media)
  writeBody;
}

/// 读取“创建时间：…”“修改时间：…”中的时间：`2024-11-03 08:30:05+08:00`
/// 或“未知”。
DateTime? parseNoteBridgeTime(String? raw) {
  final text = raw?.trim();
  if (text == null || text.isEmpty || text == '未知') return null;
  return parseJournalDateTime(text);
}

/// 把正文里指向 `resources/` 的相对路径（URL 编码）解析为媒体嵌入。
///
/// 只接受导出目录内的文件：路径越出目录（`../`）或带协议时视为无法解析，
/// 不能借导入文件读取应用私有目录里的其他文件。资源文件名是
/// `<摘要前 16 位>-<原文件名>`，未给出 [name] 时去掉摘要前缀作为附件名。
class NoteBridgeMedia {
  NoteBridgeMedia(this._stager, {required this.directory, required this.root});

  final JournalMediaStager _stager;
  final String directory;
  final String root;

  Map<String, Object?>? resolve(String source, {String? name}) {
    final src = source.trim();
    if (src.isEmpty ||
        RegExp(r'^[a-z][a-z0-9+.-]*:', caseSensitive: false).hasMatch(src)) {
      return null;
    }
    final String relative;
    try {
      relative = Uri.decodeFull(src);
    } on ArgumentError {
      _stager.missingCount++;
      return null;
    } on FormatException {
      _stager.missingCount++;
      return null;
    }
    final path = p.normalize(p.join(directory, relative));
    if (!p.isWithin(root, path)) {
      _stager.missingCount++;
      return null;
    }
    return _stager.embedFile(
      path,
      name:
          name ?? p.basename(path).replaceFirst(RegExp(r'^[0-9a-f]{16}-'), ''),
    );
  }

  /// 导出里注明“附件未获取”的媒体，计入缺失数。
  void markMissing() => _stager.missingCount++;
}
