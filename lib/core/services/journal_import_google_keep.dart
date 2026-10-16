import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'journal_import_delta_writer.dart';
import 'journal_import_html.dart';
import 'journal_import_media.dart';
import 'journal_import_models.dart';
import 'journal_import_support.dart';

/// 解析 Google Takeout 导出的 Google Keep 笔记（`Takeout/Keep/*.json`，
/// 附件与 JSON 同级），也接受单独挑出的一个 JSON。
///
/// 按 JSON 结构而不是目录名识别笔记（非英文账号的目录名可能不同）：含
/// 数字 `userEditedTimestampUsec` 或 `createdTimestampUsec` 的对象即为一篇。
/// 同级的 `.html` 副本与 `Labels.txt` 忽略。
///
/// 映射：createdTimestampUsec（微秒，2021 年前后的导出缺失时用编辑时间）
/// → 发表时间；userEditedTimestampUsec（可能为 0）→ 更新时间；title →
/// 标题；textContentHtml（较新导出才有，样式在内联 style 中）或
/// textContent → 正文；listContent → 待办列表；labels → 标签；
/// isPinned/isArchived → 置顶/归档；annotations（网页链接）→ 正文末尾的
/// 链接行。图片与涂鸦按 Keep 的版式放在正文之前，录音放在之后。回收站中
/// 的笔记不导入。Keep 没有笔记 ID，稳定键由时间戳与标题组成。
JournalImportParseResult parseGoogleKeepExport(
  JournalImportInput input,
  JournalMediaStager media,
) {
  final files = input.extractedPath == null
      ? [File(input.filePath)]
      : listJournalExportFiles(input.extractedPath!);
  final entries = <JournalImportEntry>[];
  final keys = JournalKeyRegistry();
  final listings = <String, List<String>>{};
  var recognized = false;
  for (final file in files) {
    if (p.extension(file.path).toLowerCase() != '.json') continue;
    final Object? decoded;
    try {
      decoded = jsonDecode(file.readAsStringSync());
    } on FormatException {
      continue;
    } on FileSystemException {
      continue;
    }
    if (decoded is! Map) continue;
    final raw = decoded.cast<String, Object?>();
    final created = _usec(raw['createdTimestampUsec']);
    final edited = _usec(raw['userEditedTimestampUsec']);
    if (created == null && edited == null) continue;
    recognized = true;
    if (raw['isTrashed'] == true) continue;
    entries.add(
      _parseNote(raw, created ?? edited!, edited, file, media, keys, listings),
    );
  }
  if (!recognized) {
    throw const JournalImportFormatException(JournalImportSource.googleKeep);
  }
  return JournalImportParseResult(
    entries: entries,
    missingMediaCount: media.missingCount,
  );
}

/// 正数微秒时间戳 → 本地时间；缺失或为 0 时返回 null。
DateTime? _usec(Object? value) => value is num && value > 0
    ? DateTime.fromMicrosecondsSinceEpoch(value.toInt())
    : null;

JournalImportEntry _parseNote(
  Map<String, Object?> raw,
  DateTime createdAt,
  DateTime? updatedAt,
  File file,
  JournalMediaStager media,
  JournalKeyRegistry keys,
  Map<String, List<String>> listings,
) {
  final writer = JournalDeltaWriter();
  final attachments = [
    for (final item in (raw['attachments'] as List?) ?? const [])
      if (item is Map && journalString(item['filePath']) != null)
        _attachmentPath(
          file.parent,
          journalString(item['filePath'])!,
          listings,
        ),
  ];
  // Keep 把图片与涂鸦显示在标题上方，录音在正文下方。
  final later = <Map<String, Object?>>[];
  for (final path in attachments) {
    final data = media.embedFile(path);
    if (data == null) continue;
    if (data.containsKey('image') || data.containsKey('video')) {
      writer.embed(data);
    } else {
      later.add(data);
    }
  }

  final html = journalString(raw['textContentHtml']);
  final text = raw['textContent'];
  if (html != null) {
    JournalHtmlConverter(writer).appendHtml(html);
  } else if (text is String) {
    appendJournalPlainText(writer, text);
  }
  for (final item in (raw['listContent'] as List?) ?? const []) {
    if (item is! Map) continue;
    final itemText = (item['text'] as String? ?? '').replaceAll('\n', ' ');
    writer.text(itemText);
    writer.endLine({
      'list': item['isChecked'] == true ? 'checked' : 'unchecked',
    });
  }
  for (final annotation in (raw['annotations'] as List?) ?? const []) {
    if (annotation is! Map) continue;
    final url = journalString(annotation['url']);
    if (url == null || !RegExp(r'^https?://').hasMatch(url)) continue;
    writer.text(journalString(annotation['title']) ?? url, {'link': url});
    writer.endLine();
  }
  later.forEach(writer.embed);
  final content = writer.build();

  final title = (journalString(raw['title']) ?? '').replaceAll(
    RegExp(r'\s*\n\s*'),
    ' ',
  );
  return JournalImportEntry(
    sourceKey: keys.unique(
      '${raw['createdTimestampUsec'] ?? raw['userEditedTimestampUsec']}'
      '|$title',
    ),
    title: title,
    contentJson: content.contentJson,
    contentText: content.contentText,
    createdAt: createdAt,
    updatedAt: updatedAt,
    tags: [
      for (final label in (raw['labels'] as List?) ?? const [])
        if (label is Map && journalString(label['name']) != null)
          journalString(label['name'])!,
    ],
    pinned: raw['isPinned'] == true,
    archived: raw['isArchived'] == true,
  );
}

/// 附件与 JSON 同级。早期导出里 JSON 写 `.jpeg` 而文件是 `.jpg`（或相反），
/// 依次尝试原名、互换扩展名、同主名的任一文件；都找不到时返回原路径，由
/// 媒体暂存计入缺失。同主名查找用的目录清单缓存在 [listings]，几千篇笔记
/// 的导出也只列一次目录。
String _attachmentPath(
  Directory directory,
  String filePath,
  Map<String, List<String>> listings,
) {
  final name = p.basename(filePath.replaceAll('\\', '/'));
  final exact = p.join(directory.path, name);
  if (File(exact).existsSync()) return exact;
  final extension = p.extension(name).toLowerCase();
  final swapped = switch (extension) {
    '.jpeg' => '.jpg',
    '.jpg' => '.jpeg',
    _ => null,
  };
  if (swapped != null) {
    final candidate = p.join(directory.path, p.setExtension(name, swapped));
    if (File(candidate).existsSync()) return candidate;
  }
  final stem = p.basenameWithoutExtension(name);
  final siblings = listings[directory.path] ??= [
    for (final entity in directory.listSync())
      if (entity is File &&
          !const {
            '.json',
            '.html',
          }.contains(p.extension(entity.path).toLowerCase()))
        entity.path,
  ];
  return siblings.firstWhere(
    (path) => p.basenameWithoutExtension(path) == stem,
    orElse: () => exact,
  );
}
