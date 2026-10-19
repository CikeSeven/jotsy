import 'dart:io';

import 'package:path/path.dart' as p;

import 'journal_import_delta_writer.dart';
import 'journal_import_files.dart';
import 'journal_import_front_matter.dart';
import 'journal_import_markdown.dart';
import 'journal_import_media.dart';
import 'journal_import_models.dart';
import 'journal_import_support.dart';

/// 解析一组 Markdown / 纯文本笔记：单个 `.md`/`.txt` 文件，或包含它们的
/// ZIP（Obsidian 库、Bear、Notion、Typora、Joplin「Markdown + Front
/// Matter」等导出）。每个文件一篇。
///
/// - 标题：front matter 的 `title`；否则正文首行的一级标题（从正文移除）；
///   再否则取文件名（去掉 Notion 追加的 32 位 ID）。文件名只是日期的日记
///   （如 `2024-01-15.md`）不另设标题；
/// - 发表时间：front matter 的 `created`/`date` 等；否则文件名里的日期
///   （可带时间）；再否则 ZIP 里记录的文件修改时间；
/// - 标签：front matter 的 `tags`（列表或逗号分隔），位置取 `location` 与
///   `latitude`/`longitude`；所在一级文件夹记为所在日记本
///   （[JournalImportEntry.notebooks]）；
/// - 正文逐行转换并识别行内 HTML；图片与附件链接先按相对路径、再按文件名
///   在整个导出中查找（Obsidian 的附件文件夹），`![[图片.png]]` 嵌入同样
///   支持，`[[笔记]]` 双链保留为文字；
/// - 稳定键是文件在导出中的相对路径。
JournalImportParseResult parseMarkdownFilesExport(
  JournalImportInput input,
  JournalMediaStager media,
) {
  final root = input.extractedPath ?? p.dirname(input.filePath);
  final files = input.extractedPath == null
      ? [File(input.filePath)]
      : listJournalExportFiles(root)
            .where(
              (file) => !p
                  .split(p.relative(file.path, from: root))
                  .any((segment) => segment.startsWith('.')),
            )
            .toList(growable: false);
  final notes = files
      .where((file) => _noteExtensions.contains(_extension(file.path)))
      .toList(growable: false);
  if (notes.isEmpty) {
    throw const JournalImportFormatException(JournalImportSource.markdown);
  }
  final exportFiles = JournalImportFiles(root);

  final folders = _topFolders(notes, root);
  final entries = <JournalImportEntry>[];
  final issues = JournalImportIssues();
  for (final file in notes) {
    Map<String, Object?>? resolve(String source) =>
        _resolve(source, file.parent.path, exportFiles, media);
    try {
      entries.add(
        _parseNote(
          file,
          input.extractedPath == null
              ? p.basename(file.path)
              : p.posix.joinAll(p.split(p.relative(file.path, from: root))),
          resolve,
          folder: folders[file.path],
        ),
      );
    } on FormatException {
      issues.skip(JournalSkipReason.unreadable);
    }
  }
  return JournalImportParseResult(
    entries: entries,
    missingMediaCount: media.missingCount,
    skippedNotes: issues.skipped,
  );
}

const Set<String> _noteExtensions = {'md', 'markdown', 'mdown', 'txt'};

String _extension(String path) =>
    p.extension(path).toLowerCase().replaceFirst('.', '');

/// 每个文件所在的一级文件夹（Obsidian 的文件夹、Joplin 的笔记本），记为
/// 所在日记本。先去掉所有文件共有的外层目录（打包时多出的那一层），TextBundle
/// 包不算文件夹，Notion 文件夹名去掉 ID。
Map<String, String> _topFolders(List<File> notes, String root) {
  final directories = {
    for (final file in notes)
      file.path: p
          .split(p.relative(file.parent.path, from: root))
          .where(
            (segment) =>
                segment != '.' &&
                !segment.toLowerCase().endsWith('.textbundle'),
          )
          .toList(),
  };
  var shared = 0;
  final first = directories.values.first;
  while (shared < first.length &&
      directories.values.every(
        (segments) =>
            segments.length > shared && segments[shared] == first[shared],
      )) {
    shared++;
  }
  return {
    for (final MapEntry(:key, :value) in directories.entries)
      if (value.length > shared)
        key: value[shared].replaceFirst(RegExp(r'\s+[0-9a-f]{32}$'), '').trim(),
  };
}

JournalImportEntry _parseNote(
  File file,
  String sourceKey,
  JournalEmbedResolver resolve, {
  String? folder,
}) {
  final text = readJournalText(
    file,
  ).replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (_extension(file.path) == 'txt') {
    final writer = JournalDeltaWriter(preserveWhitespace: true);
    appendJournalPlainText(writer, text);
    final content = writer.build();
    final nameDate = _fileNameDate(_noteStem(file));
    return JournalImportEntry(
      sourceKey: sourceKey,
      title: nameDate?.rest ?? _noteStem(file),
      contentJson: content.contentJson,
      contentText: content.contentText,
      createdAt: nameDate?.date ?? file.lastModifiedSync(),
      // 与 Markdown 笔记一致：所在一级文件夹记为所在日记本，不直接当标签。
      notebooks: [?folder],
    );
  }
  final (:fields, :body) = splitJournalFrontMatter(text);
  var markdown = body;
  var title = journalFrontMatterString(fields, const ['title']) ?? '';
  final writer = JournalDeltaWriter();
  final converter = JournalMarkdownConverter(
    writer,
    resolveEmbed: resolve,
    resolveLink: resolve,
    inlineHtml: true,
  );
  if (title.isEmpty) {
    final heading = RegExp(r'^\s*# +(.+?)\s*#*\s*$').firstMatch(
      markdown
          .split('\n')
          .firstWhere((line) => line.trim().isNotEmpty, orElse: () => ''),
    );
    if (heading != null) {
      title = converter.plainInline(heading.group(1)!);
      markdown = markdown.replaceFirst(RegExp(r'^\s*#[^\n]*\n?'), '');
    }
  }

  final stem = _noteStem(file);
  final nameDate = _fileNameDate(stem);
  if (title.isEmpty) title = nameDate == null ? stem : nameDate.rest;
  converter.append(_wikiLinks(markdown));
  final content = writer.build();

  final created =
      parseLooseJournalDate(
        journalFrontMatterString(fields, const [
          'created',
          'date',
          'created_at',
          'createdat',
          'creation_date',
          'date created',
          'created time',
        ]),
      ) ??
      nameDate?.date ??
      file.lastModifiedSync();
  final updated = parseLooseJournalDate(
    journalFrontMatterString(fields, const [
      'updated',
      'modified',
      'updated_at',
      'updatedat',
      'last_modified',
      'date modified',
      'last edited time',
    ]),
  );
  final latitude = double.tryParse('${fields['latitude'] ?? ''}');
  final longitude = double.tryParse('${fields['longitude'] ?? ''}');
  final hasCoordinate = isJournalCoordinate(latitude, longitude);
  return JournalImportEntry(
    sourceKey: sourceKey,
    title: title,
    contentJson: content.contentJson,
    contentText: content.contentText,
    createdAt: created,
    updatedAt: updated,
    tags: [..._tags(fields['tags'] ?? fields['tag'] ?? fields['keywords'])],
    notebooks: [?folder],
    location: journalFrontMatterString(fields, const ['location', 'place']),
    latitude: hasCoordinate ? latitude : null,
    longitude: hasCoordinate ? longitude : null,
  );
}

/// 文件名主干：Bear 的 TextBundle（`标题.textbundle/text.md`）取包名，
/// Notion 的 `标题 <32 位十六进制 ID>` 去掉 ID。
String _noteStem(File file) {
  var stem = p.basenameWithoutExtension(file.path);
  final parent = p.basename(file.parent.path);
  if (stem == 'text' && parent.toLowerCase().endsWith('.textbundle')) {
    stem = p.basenameWithoutExtension(parent);
  }
  return stem.replaceFirst(RegExp(r'\s+[0-9a-f]{32}$'), '').trim();
}

/// 文件名开头的日期（可带时间），如 `2024-01-15`、`2024_01_15 0830 晨跑`、
/// `20240115`；[rest] 是日期之后剩下的文字（作标题用）。
({DateTime date, String rest})? _fileNameDate(String stem) {
  final match = RegExp(
    r'^(\d{4})[-_.]?(\d{2})[-_.]?(\d{2})'
    r'(?:[ T_-]+(\d{2})[-:.h]?(\d{2})(?:[-:.]?(\d{2}))?)?(?!\d)',
  ).firstMatch(stem);
  if (match == null) return null;
  int field(int group) => int.tryParse(match.group(group) ?? '') ?? 0;
  final (month, day, hour, minute) = (field(2), field(3), field(4), field(5));
  if (!isJournalCalendarDate(field(1), month, day)) return null;
  if (hour > 23 || minute > 59 || field(6) > 59) return null;
  return (
    date: DateTime(field(1), month, day, hour, minute, field(6)),
    rest: stem
        .substring(match.end)
        .replaceFirst(RegExp(r'^[\s\-_.,:：·]+'), '')
        .trim(),
  );
}

List<String> _tags(Object? raw) {
  final values = switch (raw) {
    final List<String> list => list,
    final String text => text.split(RegExp(r'[,，]|\s+(?=#)')),
    _ => const <String>[],
  };
  return [
    for (final value in values)
      if (value.trim().replaceFirst(RegExp(r'^#'), '').trim() case final tag
          when tag.isNotEmpty)
        tag,
  ];
}

/// Obsidian 双链：`![[图片.png|300]]` 改写为标准图片语法，`[[笔记|别名]]`
/// 与 `[[笔记#标题]]` 保留为文字。代码围栏内不改写。
String _wikiLinks(String markdown) {
  String? fence;
  return markdown
      .split('\n')
      .map((line) {
        final opening = RegExp(r'^\s*(`{3,}|~{3,})').firstMatch(line);
        if (fence != null) {
          if (line.trimLeft().startsWith(fence!)) fence = null;
          return line;
        }
        if (opening != null) {
          fence = opening.group(1)!.substring(0, 3);
          return line;
        }
        return line
            .replaceAllMapped(
              RegExp(r'!\[\[([^\]|#^]+)(?:[#^][^\]|]*)?(?:\|[^\]]*)?\]\]'),
              (match) {
                final target = match.group(1)!.trim();
                // 嵌入的是另一篇笔记（无扩展名或 .md）时只留名字。
                if (_noteExtensions.contains(_extension(target)) ||
                    p.extension(target).isEmpty) {
                  return target;
                }
                return '![](${Uri.encodeFull(target).replaceAll('(', '%28').replaceAll(')', '%29')})';
              },
            )
            .replaceAllMapped(
              RegExp(r'\[\[([^\]|]+?)(?:\|([^\]]+))?\]\]'),
              (match) =>
                  (match.group(2) ?? match.group(1)!.split('#').first).trim(),
            );
      })
      .join('\n');
}

Map<String, Object?>? _resolve(
  String source,
  String directory,
  JournalImportFiles files,
  JournalMediaStager media,
) {
  var src = source.trim();
  if (src.toLowerCase().startsWith('data:')) return media.embedDataUri(src);
  if (src.startsWith('<') && src.endsWith('>')) {
    src = src.substring(1, src.length - 1);
  }
  if (src.isEmpty ||
      src.startsWith('#') ||
      RegExp(r'^[a-z][a-z0-9+.-]*:', caseSensitive: false).hasMatch(src)) {
    return null;
  }
  // 链接到另一篇笔记的不是附件，保留文字。
  if (_noteExtensions.contains(_extension(src.split(RegExp('[?#]')).first))) {
    return null;
  }
  final path = files.resolve(src, from: directory);
  if (path != null && _noteExtensions.contains(_extension(path))) return null;
  if (path == null) {
    media.missingCount++;
    return null;
  }
  return media.embedFile(path);
}
