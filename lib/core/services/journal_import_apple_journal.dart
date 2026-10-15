import 'dart:io';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;

import 'journal_import_delta_writer.dart';
import 'journal_import_html.dart';
import 'journal_import_media.dart';
import 'journal_import_models.dart';
import 'journal_import_support.dart';

/// 解析 Apple 手记（Journal）「导出所有手记条目」得到的 ZIP。
///
/// 结构：`AppleJournalEntries/index.html` 按新到旧列出条目，
/// `Entries/<YYYY-MM-DD…>.html` 每篇一个，媒体在 `Resources/`。条目 HTML 中
/// `.pageHeader` 是日期，`.assetGrid .gridItem.assetType_<类型>` 是附件网格
/// （照片/视频/录音/地图/心境等），`.title` 是标题，`.bodyText` 内是正文段落。
///
/// 导出只记录日期不记录时间：发表时间取文件名中的日期（缺失时解析英文
/// 页眉），同一天的多篇按 index.html 的先后排成 12:00、12:01…，保持原有
/// 顺序。照片、视频、录音按原样放在正文之前（与手记的版式一致）；地图附件
/// 的地点名作为位置；心境、联系人、运动等其他附件没有对应字段，不导入。
JournalImportParseResult parseAppleJournalExport(
  JournalImportInput input,
  JournalMediaStager media,
) {
  final root = input.extractedPath;
  if (root == null) {
    throw const JournalImportFormatException(JournalImportSource.appleJournal);
  }
  final files = listJournalExportFiles(root);
  bool isHtml(File file) =>
      const {'.html', '.htm'}.contains(p.extension(file.path).toLowerCase());
  // 资源按文件名兜底查找：路径大小写或 Unicode 规范化与 HTML 中的不一致时仍能找到。
  final resources = <String, String>{
    for (final file in files.where((file) => !isHtml(file)))
      p.basename(file.path).toLowerCase(): file.path,
  };
  final order = <String, int>{};
  for (final index in files.where(
    (file) => p.basename(file.path).toLowerCase() == 'index.html',
  )) {
    final document = html_parser.parse(index.readAsStringSync());
    for (final link in document.querySelectorAll('a[href]')) {
      final target = p.normalize(
        p.join(index.parent.path, Uri.decodeFull(link.attributes['href']!)),
      );
      order.putIfAbsent(target, () => order.length);
    }
  }

  final pages = <({File file, dom.Document document, DateTime date})>[];
  var recognized = false;
  for (final file in files.where(isHtml)) {
    if (p.basename(file.path).toLowerCase() == 'index.html') continue;
    final document = html_parser.parse(file.readAsStringSync());
    if (document.querySelector('.pageHeader, .bodyText, .assetGrid') == null) {
      continue;
    }
    recognized = true;
    final date =
        _fileDate(p.basename(file.path)) ??
        _headerDate(document.querySelector('.pageHeader')?.text ?? '');
    if (date != null) pages.add((file: file, document: document, date: date));
  }
  if (!recognized) {
    throw const JournalImportFormatException(JournalImportSource.appleJournal);
  }

  // 同一天内按 index.html 由旧到新（列表是新的在前），没有索引时按文件名。
  int position(File file) => order[p.normalize(file.path)] ?? -1;
  pages.sort((a, b) {
    final byDate = a.date.compareTo(b.date);
    if (byDate != 0) return byDate;
    final byIndex = position(b.file).compareTo(position(a.file));
    return byIndex != 0 ? byIndex : a.file.path.compareTo(b.file.path);
  });

  final entries = <JournalImportEntry>[];
  DateTime? previousDate;
  var minute = 0;
  for (final page in pages) {
    minute = page.date == previousDate ? minute + 1 : 0;
    previousDate = page.date;
    // 用日历字段构造而不是加 Duration：夏令时切换日加 12 小时会偏一小时。
    final createdAt = DateTime(
      page.date.year,
      page.date.month,
      page.date.day,
      12,
      minute,
    );
    entries.add(
      _parsePage(page.file, page.document, createdAt, root, resources, media),
    );
  }
  return JournalImportParseResult(
    entries: entries,
    missingMediaCount: media.missingCount,
  );
}

JournalImportEntry _parsePage(
  File file,
  dom.Document document,
  DateTime createdAt,
  String root,
  Map<String, String> resources,
  JournalMediaStager media,
) {
  Map<String, Object?>? resolve(String source) {
    if (RegExp(r'^[a-z]+:', caseSensitive: false).hasMatch(source)) return null;
    final relative = Uri.decodeFull(source);
    final direct = p.normalize(p.join(file.parent.path, relative));
    final path = File(direct).existsSync()
        ? direct
        : resources[p.basename(relative).toLowerCase()] ?? direct;
    return media.embedFile(path);
  }

  final writer = JournalDeltaWriter();
  String? location;
  for (final item in document.querySelectorAll('.assetGrid .gridItem')) {
    final type = item.classes
        .firstWhere((name) => name.startsWith('assetType_'), orElse: () => '')
        .replaceFirst('assetType_', '')
        .toLowerCase();
    if (type.contains('map') || type == 'location') {
      location ??= _overlayText(item);
      continue;
    }
    if (!const {'photo', 'livephoto', 'video', 'audio'}.contains(type)) {
      continue;
    }
    final source = [
      for (final element in item.querySelectorAll(
        'video[src], video source[src], audio[src], audio source[src], img[src]',
      ))
        element.attributes['src']!,
    ].firstOrNull;
    if (source == null) continue;
    final data = resolve(source);
    if (data != null) writer.embed(data);
  }

  final prompt = document.querySelector('.reflectionPrompt')?.text.trim();
  if (prompt != null && prompt.isNotEmpty) {
    writer.text(prompt, const {'italic': true});
    writer.endLine(const {'blockquote': true});
  }
  final converter = JournalHtmlConverter(writer, resolveEmbed: resolve);
  final body = document.querySelector('.bodyText');
  if (body != null) {
    // 导出的包裹标记不成对（`<div class='bodyText'></span></p>`），HTML 解析
    // 会补出没有任何子节点的空 `<p>`；手记里真正的空行带 `<br>`，可放心去掉。
    for (final paragraph in body.querySelectorAll('p')) {
      if (paragraph.nodes.isEmpty) paragraph.remove();
    }
    converter.appendNodes(body.nodes);
  } else {
    converter.appendNodes(
      document
          .querySelectorAll('p')
          .where(
            (paragraph) => paragraph.querySelector('.pageContainer') == null,
          ),
    );
  }
  final content = writer.build();
  return JournalImportEntry(
    sourceKey: p.posix.joinAll(p.split(p.relative(file.path, from: root))),
    title:
        document
            .querySelector('.title')
            ?.text
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim() ??
        '',
    contentJson: content.contentJson,
    contentText: content.contentText,
    createdAt: createdAt,
    location: location,
  );
}

String? _overlayText(dom.Element item) {
  final texts = item
      .querySelectorAll('.gridItemOverlayFooter, .gridItemOverlayHeader')
      .map((element) => element.text.trim())
      .where((text) => text.isNotEmpty)
      .toList(growable: false);
  return texts.isEmpty ? null : texts.join(' · ');
}

DateTime? _fileDate(String name) {
  final match = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(name);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return DateTime(year, month, day);
}

/// 英文页眉 `Sunday, 3 November 2024` 或 `Sunday, November 3, 2024`。
DateTime? _headerDate(String header) {
  final year = RegExp(r'\b(\d{4})\b').firstMatch(header);
  final day = RegExp(r'\b(\d{1,2})\b').firstMatch(header);
  final month = journalEnglishMonth(header);
  if (year == null || day == null || month == null) return null;
  return DateTime(int.parse(year.group(1)!), month, int.parse(day.group(1)!));
}
