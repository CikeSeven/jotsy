import 'dart:convert';

import 'package:path/path.dart' as p;

import 'diary_export_blocks.dart';
import 'diary_export_entry.dart';
import 'diary_export_format.dart';
import 'diary_export_media.dart';
import 'diary_export_naming.dart';

/// Markdown 写出器：每篇一个 `.md`，媒体放进 `media/` 并以相对路径引用。
///
/// 输出：只有一篇且没有媒体时为单个 `.md`；否则为需要打包的文件列表
/// （各篇 `.md` + `media/`）。每篇开头是 YAML front matter（title / created /
/// updated / tags / location 等），Jotsy 与 Obsidian 的 Markdown 导入都认这些
/// 字段；标题只写在 front matter 里，正文不再重复一级标题，避免导回后
/// 正文开头多出一行标题。
///
/// 正文按块写出：每个文本行一段（段间空一行，保留原来的分行），列表、
/// 待办、引用、代码块用标准语法；找不到的图片直接略过，未打包的录音、
/// 视频、附件写成一行名称。
class DiaryMarkdownWriter {
  const DiaryMarkdownWriter._();

  static const String mediaDirectory = 'media';

  static Future<DiaryExportOutput> write(
    List<DiaryExportEntry> entries, {
    required DiaryExportOptions options,
    required DiaryExportLabels labels,
    required DiaryExportMediaLibrary media,
  }) async {
    // 先确定要打包的媒体与包内路径，正文再按来源取路径。
    final mediaPaths = <String, String>{};
    final mediaFiles = <DiaryExportBundleFile>[];
    final takenNames = <String>{};
    if (options.includeMedia) {
      for (final entry in entries) {
        final images = entry.imageSources;
        for (final source in <String>[...images, ...entry.attachmentSources]) {
          if (mediaPaths.containsKey(source)) {
            continue;
          }
          // 录音、视频、附件的远程地址保留为链接，不下载进导出包。
          final isImage = images.contains(source);
          final file = await media.resolve(source, allowDownload: isImage);
          if (file == null) {
            continue;
          }
          final index = (mediaPaths.length + 1).toString().padLeft(4, '0');
          final original = DiaryExportNaming.sanitize(
            p.basenameWithoutExtension(file.file?.path ?? ''),
            maxLength: 32,
          );
          final name = DiaryExportNaming.unique(
            takenNames,
            isImage || original.isEmpty
                ? '$index${file.extension}'
                : '${index}_$original${file.extension}',
          );
          final path = '$mediaDirectory/$name';
          mediaPaths[source] = path;
          mediaFiles.add(
            file.file != null
                ? DiaryExportBundleFile.file(path, file.file!)
                : DiaryExportBundleFile.bytes(path, file.bytes!),
          );
        }
      }
    }

    final documents = <DiaryExportBundleFile>[];
    final takenDocs = <String>{};
    for (final entry in entries) {
      final text = renderEntry(
        entry,
        includeMeta: options.includeMeta,
        labels: labels,
        mediaPathOf: (String source) => mediaPaths[source],
      );
      final name = DiaryExportNaming.unique(
        takenDocs,
        '${DiaryExportNaming.entryStem(entry)}.md',
      );
      documents.add(DiaryExportBundleFile.bytes(name, utf8.encode(text)));
    }
    if (documents.length == 1 && mediaFiles.isEmpty) {
      return DiaryExportOutput.single(documents.single.bytes!);
    }
    return DiaryExportOutput.bundle(<DiaryExportBundleFile>[
      ...documents,
      ...mediaFiles,
    ]);
  }

  /// 单篇 Markdown 文本；[mediaPathOf] 返回已打包媒体的相对路径。
  static String renderEntry(
    DiaryExportEntry entry, {
    required bool includeMeta,
    required DiaryExportLabels labels,
    required String? Function(String source) mediaPathOf,
  }) {
    final out = StringBuffer()
      ..writeln('---')
      ..writeln('title: ${_yaml(labels.titleOf(entry))}')
      ..writeln('created: ${_iso(entry.createdAt)}')
      ..writeln('updated: ${_iso(entry.updatedAt)}');
    if (includeMeta) {
      final context = entry.context;
      if (entry.tagNames.isNotEmpty) {
        out.writeln('tags: [${entry.tagNames.map(_yaml).join(', ')}]');
      }
      if (context.moodEmoji != null) {
        out.writeln('mood: ${_yaml(context.moodEmoji!)}');
      }
      if (context.energyLevel != null) {
        out.writeln('energy: ${context.energyLevel}');
      }
      if (context.weather != null) {
        out.writeln('weather: ${_yaml(context.weather!)}');
      }
      if (context.location != null) {
        out.writeln('location: ${_yaml(context.location!)}');
      }
    }
    out.writeln('---');

    final body = <String>[];
    final cover = entry.cover == null ? null : mediaPathOf(entry.cover!);
    if (cover != null) {
      body.add('![](${_destination(cover)})');
    }
    body.addAll(_renderBlocks(entry, labels: labels, mediaPathOf: mediaPathOf));
    if (body.isNotEmpty) {
      out
        ..writeln()
        ..writeln(body.join('\n\n'));
    }
    return out.toString();
  }

  /// 每组相邻的同类块（列表、引用、代码）合成一段，段与段之间空一行。
  static List<String> _renderBlocks(
    DiaryExportEntry entry, {
    required DiaryExportLabels labels,
    required String? Function(String source) mediaPathOf,
  }) {
    final sections = <String>[];
    final group = <String>[];
    String? groupKind;

    void flush() {
      if (group.isEmpty) {
        return;
      }
      sections.add(
        groupKind == 'code'
            ? '```\n${group.join('\n')}\n```'
            : group.join('\n'),
      );
      group.clear();
      groupKind = null;
    }

    void addTo(String kind, String line) {
      if (groupKind != kind) {
        flush();
        groupKind = kind;
      }
      group.add(line);
    }

    for (final block in entry.blocks) {
      switch (block.kind) {
        case ExportBlockKind.paragraph:
          flush();
          final text = _inlines(block.inlines);
          // 空行只用来分段，段间本就空一行，不再额外写出。
          if (text.trim().isNotEmpty) {
            sections.add(_escapeLineStart(text));
          }
        case ExportBlockKind.heading:
          flush();
          sections.add('${'#' * block.level} ${_inlines(block.inlines)}');
        case ExportBlockKind.bullet ||
            ExportBlockKind.ordered ||
            ExportBlockKind.checked ||
            ExportBlockKind.unchecked:
          final marker = switch (block.kind) {
            ExportBlockKind.ordered => '${block.ordinal}.',
            ExportBlockKind.checked => '- [x]',
            ExportBlockKind.unchecked => '- [ ]',
            _ => '-',
          };
          addTo(
            'list',
            '${'    ' * block.indent}$marker ${_inlines(block.inlines)}',
          );
        case ExportBlockKind.quote:
          addTo('quote', '> ${_inlines(block.inlines)}');
        case ExportBlockKind.code:
          addTo('code', block.plainText);
        case ExportBlockKind.image:
          flush();
          if (block.source == entry.cover) {
            break;
          }
          final path = mediaPathOf(block.source!);
          if (path != null) {
            sections.add('![](${_destination(path)})');
          } else if (_isRemote(block.source!)) {
            sections.add('![](${_destination(block.source!)})');
          }
        case ExportBlockKind.media:
          flush();
          final path = mediaPathOf(block.source!);
          final label = labels.mediaLine(block);
          sections.add(
            path != null
                ? '[${_escape(label)}](${_destination(path)})'
                : _isRemote(block.source!)
                ? '[${_escape(label)}](${_destination(block.source!)})'
                : _escape(label),
          );
      }
    }
    flush();
    return sections;
  }

  static String _inlines(List<ExportInline> runs) {
    final out = StringBuffer();
    for (final run in runs) {
      if (run.code) {
        out.write(_code(run.text));
        continue;
      }
      var text = _escape(run.text);
      // 标记必须贴着文字，首尾空白移到标记外，否则 `** 粗体**` 不生效。
      final leading = RegExp(r'^\s*').stringMatch(text)!;
      final trailing = RegExp(
        r'\s*$',
      ).stringMatch(text.substring(leading.length))!;
      var core = text.substring(leading.length, text.length - trailing.length);
      if (core.isNotEmpty) {
        if (run.bold) core = '**$core**';
        if (run.italic) core = '*$core*';
        if (run.strike) core = '~~$core~~';
        if (run.underline) core = '<u>$core</u>';
        if (run.link != null) core = '[$core](${_destination(run.link!)})';
      }
      text = '$leading$core$trailing';
      out.write(text);
    }
    return out.toString();
  }

  static String _code(String text) {
    final fence = text.contains('`') ? '``' : '`';
    return '$fence$text$fence';
  }

  /// 只转义会被误读为标记的字符，日期中的 `-`、句末的 `!` 保持原样。
  static String _escape(String text) =>
      text.replaceAllMapped(RegExp(r'[\\`*_\[\]<>]'), (m) => '\\${m[0]}');

  /// 行首的 `#`、`-`、`+`、`1.` 会被当成标题或列表。
  static String _escapeLineStart(String text) => text.replaceFirstMapped(
    RegExp(r'^(\s*)(#|[-+](?=\s)|\d+(?=[.)]\s))'),
    (m) => '${m[1]}\\${m[2]}',
  );

  /// 链接与图片地址：空格与括号会截断地址，统一编码。
  static String _destination(String path) =>
      Uri.encodeFull(path).replaceAll('(', '%28').replaceAll(')', '%29');

  static bool _isRemote(String source) =>
      source.startsWith('http://') || source.startsWith('https://');

  static String _yaml(String value) =>
      '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

  /// 本地时间的 ISO 8601（不带时区），导入端按本地时间理解。
  static String _iso(DateTime value) =>
      value.toLocal().toIso8601String().split('.').first;
}
