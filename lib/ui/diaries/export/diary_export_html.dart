import 'dart:convert';

import 'diary_export_blocks.dart';
import 'diary_export_entry.dart';
import 'diary_export_format.dart';
import 'diary_export_media.dart';

/// HTML 写出器：所有日记写进一个网页。
///
/// - 单篇：图片以 data URI 内嵌，单个文件在手机浏览器里也能直接打开；
/// - 多篇且带图片：打包成 `index.html` + `media/`，图片按原文件流式写入，
///   批量导出几百张照片也不会整份读进内存（base64 还会再胀大三分之一）。
/// 录音、视频、附件写成一行名称（体积大，不适合内嵌）。只收浏览器能
/// 显示的图片格式（读文件头识别），HEIC 等略过。样式内联，跟随系统亮色 /
/// 暗色；正文标题从 h2 起，h1 留给日记标题。
class DiaryHtmlWriter {
  const DiaryHtmlWriter._();

  static const String bundledPageName = 'index.html';

  static Future<DiaryExportOutput> write(
    List<DiaryExportEntry> entries, {
    required DiaryExportOptions options,
    required DiaryExportLabels labels,
    required DiaryExportMediaLibrary media,
    required String documentTitle,
    required String languageTag,
  }) async {
    final bundle = entries.length > 1;
    // 来源 → img 的 src（data URI，或打包时的相对路径）。
    final images = <String, String>{};
    final mediaFiles = <DiaryExportBundleFile>[];
    if (options.includeMedia) {
      for (final entry in entries) {
        for (final source in entry.imageSources) {
          if (images.containsKey(source)) {
            continue;
          }
          final file = await media.resolve(source);
          // 读不出格式（如 HEIC）的图片浏览器多半也显示不了，略过。
          final info = file == null ? null : await media.imageInfoOf(source);
          if (file == null || info == null) {
            continue;
          }
          if (bundle) {
            final index = (mediaFiles.length + 1).toString().padLeft(4, '0');
            final path = 'media/$index${info.extension}';
            images[source] = path;
            mediaFiles.add(
              file.file != null
                  ? DiaryExportBundleFile.file(path, file.file!)
                  : DiaryExportBundleFile.bytes(path, file.bytes!),
            );
          } else {
            final bytes = await media.bytesOf(source);
            if (bytes != null) {
              images[source] =
                  'data:${info.mimeType};base64,${base64Encode(bytes)}';
            }
          }
        }
      }
    }

    final out = StringBuffer()
      ..write('<!DOCTYPE html>\n<html lang="${_attr(languageTag)}">\n<head>\n')
      ..write('<meta charset="utf-8">\n')
      ..write(
        '<meta name="viewport" content="width=device-width, initial-scale=1">\n',
      )
      ..write('<meta name="generator" content="Jotsy">\n')
      ..write('<title>${_text(documentTitle)}</title>\n')
      ..write('<style>$_css</style>\n</head>\n<body>\n<main>\n');
    for (final entry in entries) {
      _writeEntry(out, entry, options: options, labels: labels, images: images);
    }
    out
      ..write('<footer>${_text(labels.exportedBy)}</footer>\n')
      ..write('</main>\n</body>\n</html>\n');
    final page = utf8.encode(out.toString());
    if (mediaFiles.isEmpty) {
      return DiaryExportOutput.single(page);
    }
    return DiaryExportOutput.bundle(<DiaryExportBundleFile>[
      DiaryExportBundleFile.bytes(bundledPageName, page),
      ...mediaFiles,
    ]);
  }

  static void _writeEntry(
    StringBuffer out,
    DiaryExportEntry entry, {
    required DiaryExportOptions options,
    required DiaryExportLabels labels,
    required Map<String, String> images,
  }) {
    out
      ..write('<article>\n<header>\n')
      ..write('<h1>${_text(labels.titleOf(entry))}</h1>\n')
      ..write(
        '<p class="meta"><time datetime="${_attr(entry.createdAt.toLocal().toIso8601String())}">'
        '${_text(labels.formatDateTime(entry.createdAt.toLocal()))}</time></p>\n',
      );
    if (options.includeMeta) {
      final meta = labels.metaLine(entry);
      if (meta.isNotEmpty) {
        out.write('<p class="meta">${_text(meta)}</p>\n');
      }
      if (entry.tagNames.isNotEmpty) {
        out.write('<ul class="tags">');
        for (final tag in entry.tagNames) {
          out.write('<li>#${_text(tag)}</li>');
        }
        out.write('</ul>\n');
      }
    }
    out.write('</header>\n');
    final cover = entry.cover == null ? null : images[entry.cover!];
    if (cover != null) {
      out.write(
        '<figure class="cover"><img src="${_attr(cover)}" alt=""></figure>\n',
      );
    }
    _writeBlocks(out, entry, labels: labels, images: images);
    out.write('</article>\n');
  }

  static void _writeBlocks(
    StringBuffer out,
    DiaryExportEntry entry, {
    required DiaryExportLabels labels,
    required Map<String, String> images,
  }) {
    final blocks = entry.blocks;
    var i = 0;
    while (i < blocks.length) {
      final block = blocks[i];
      if (block.isListItem) {
        final end = _runEnd(blocks, i, (ExportBlock b) => b.isListItem);
        _writeList(out, blocks.sublist(i, end));
        i = end;
        continue;
      }
      if (block.kind == ExportBlockKind.quote) {
        final end = _runEnd(
          blocks,
          i,
          (ExportBlock b) => b.kind == ExportBlockKind.quote,
        );
        out.write('<blockquote>');
        for (final line in blocks.sublist(i, end)) {
          out.write('<p>${_inlines(line.inlines)}</p>');
        }
        out.write('</blockquote>\n');
        i = end;
        continue;
      }
      if (block.kind == ExportBlockKind.code) {
        final end = _runEnd(
          blocks,
          i,
          (ExportBlock b) => b.kind == ExportBlockKind.code,
        );
        final code = blocks
            .sublist(i, end)
            .map((ExportBlock b) => _text(b.plainText))
            .join('\n');
        out.write('<pre><code>$code</code></pre>\n');
        i = end;
        continue;
      }
      switch (block.kind) {
        case ExportBlockKind.heading:
          final level = (block.level + 1).clamp(2, 6);
          out.write(
            '<h$level${_align(block)}>${_inlines(block.inlines)}</h$level>\n',
          );
        case ExportBlockKind.image:
          final data = images[block.source!];
          if (data != null && block.source != entry.cover) {
            out.write(
              '<figure><img src="${_attr(data)}" alt="" loading="lazy"></figure>\n',
            );
          }
        case ExportBlockKind.media:
          out.write(
            '<p class="attachment">${_text(labels.mediaLine(block))}</p>\n',
          );
        case ExportBlockKind.divider:
          out.write('<hr>\n');
        default:
          final html = _inlines(block.inlines);
          out.write(
            html.trim().isEmpty
                ? '<p class="blank"></p>\n'
                : '<p${_align(block)}>$html</p>\n',
          );
      }
      i++;
    }
  }

  static int _runEnd(
    List<ExportBlock> blocks,
    int start,
    bool Function(ExportBlock block) test,
  ) {
    var end = start;
    while (end < blocks.length && test(blocks[end])) {
      end++;
    }
    return end;
  }

  /// 把一段连续的列表项写成嵌套的 ul / ol：缩进加深时在上一项里开子列表，
  /// 回退时关闭；同一层级换了列表类型（有序 ↔ 无序 / 待办）时另起一个列表。
  static void _writeList(StringBuffer out, List<ExportBlock> items) {
    final stack = <({String tag, int indent})>[];
    var itemOpen = false;
    String tagOf(ExportBlock b) =>
        b.kind == ExportBlockKind.ordered ? 'ol' : 'ul';

    for (final item in items) {
      final tag = tagOf(item);
      while (stack.isNotEmpty && stack.last.indent > item.indent) {
        out.write('</li></${stack.removeLast().tag}>');
        itemOpen = true;
      }
      if (stack.isNotEmpty &&
          stack.last.indent == item.indent &&
          stack.last.tag != tag) {
        out.write('</li></${stack.removeLast().tag}>');
        itemOpen = false;
      }
      if (stack.isEmpty || stack.last.indent < item.indent) {
        final start = item.kind == ExportBlockKind.ordered && item.ordinal > 1
            ? ' start="${item.ordinal}"'
            : '';
        out.write('<$tag$start>');
        stack.add((tag: tag, indent: item.indent));
      } else if (itemOpen) {
        out.write('</li>');
      }
      final task = switch (item.kind) {
        ExportBlockKind.checked =>
          ' class="task"><input type="checkbox" disabled checked',
        ExportBlockKind.unchecked =>
          ' class="task"><input type="checkbox" disabled',
        _ => null,
      };
      out.write(
        task == null
            ? '<li>${_inlines(item.inlines)}'
            : '<li$task> ${_inlines(item.inlines)}',
      );
      itemOpen = true;
    }
    while (stack.isNotEmpty) {
      out.write('</li></${stack.removeLast().tag}>');
    }
    out.write('\n');
  }

  static String _align(ExportBlock block) => switch (block.align) {
    ExportAlign.center => ' style="text-align:center"',
    ExportAlign.end => ' style="text-align:right"',
    ExportAlign.justify => ' style="text-align:justify"',
    ExportAlign.start => '',
  };

  static String _inlines(List<ExportInline> runs) {
    final out = StringBuffer();
    for (final run in runs) {
      var html = _text(run.text);
      if (run.code) html = '<code>$html</code>';
      if (run.bold) html = '<strong>$html</strong>';
      if (run.italic) html = '<em>$html</em>';
      if (run.underline) html = '<u>$html</u>';
      if (run.strike) html = '<s>$html</s>';
      final link = run.link;
      if (link != null && _isSafeLink(link)) {
        html = '<a href="${_attr(link)}">$html</a>';
      }
      out.write(html);
    }
    return out.toString();
  }

  /// 只保留 http(s)、mailto、tel 链接：导出页可能在任意浏览器里打开，
  /// `javascript:` 之类的地址不能变成可点的链接。
  static bool _isSafeLink(String link) {
    final scheme = Uri.tryParse(link)?.scheme.toLowerCase();
    return scheme == 'http' ||
        scheme == 'https' ||
        scheme == 'mailto' ||
        scheme == 'tel';
  }

  static String _text(String value) =>
      const HtmlEscape(HtmlEscapeMode.element).convert(value);

  static String _attr(String value) =>
      const HtmlEscape(HtmlEscapeMode.attribute).convert(value);

  static const String _css = '''
:root{color-scheme:light dark;--bg:#f6fafe;--card:#ffffff;--text:#1a1c1e;--muted:#5f6368;--line:#d9dee4;--accent:#1e6586;--chip:#e3f0f7}
@media (prefers-color-scheme:dark){:root{--bg:#111318;--card:#1a1c20;--text:#e3e2e6;--muted:#a8acb3;--line:#33373d;--accent:#8ccff1;--chip:#20323c}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);font:16px/1.75 -apple-system,BlinkMacSystemFont,"HarmonyOS Sans SC","PingFang SC","Microsoft YaHei","Noto Sans CJK SC",sans-serif}
main{max-width:760px;margin:0 auto;padding:24px 16px 48px}
article{background:var(--card);border:0.8px solid var(--line);border-radius:24px;padding:24px;margin:0 0 24px;overflow-wrap:anywhere}
article>header h1{margin:0 0 4px;font-size:24px;line-height:1.35}
.meta{margin:0;color:var(--muted);font-size:14px}
.tags{list-style:none;margin:8px 0 0;padding:0;display:flex;flex-wrap:wrap;gap:6px}
.tags li{background:var(--chip);color:var(--accent);border-radius:12px;padding:0 10px;font-size:13px;font-weight:600}
article>header{margin-bottom:16px}
p{margin:0}
p.blank{height:1em}
h2,h3,h4,h5,h6{margin:16px 0 4px;line-height:1.4}
figure{margin:12px 0}
hr{margin:16px 0;border:0;border-top:1px solid var(--line)}
img{display:block;max-width:100%;height:auto;border-radius:16px}
.cover img{width:100%}
blockquote{margin:8px 0;padding:4px 0 4px 14px;border-left:3px solid var(--line);color:var(--muted)}
pre{margin:8px 0;padding:12px 14px;background:var(--bg);border-radius:12px;overflow:auto;font-size:14px;line-height:1.6}
code{font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}
p code,li code{background:var(--bg);border-radius:6px;padding:1px 5px}
ul,ol{margin:4px 0;padding-left:1.6em}
li.task{list-style:none;margin-left:-1.4em}
a{color:var(--accent)}
.attachment{color:var(--muted);font-size:14px;margin:4px 0}
footer{color:var(--muted);font-size:12px;text-align:center}
@media print{body{background:#fff}article{border:none;padding:0;break-inside:auto;page-break-after:always}footer{display:none}}
''';
}
