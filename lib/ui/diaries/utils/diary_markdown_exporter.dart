import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:intl/intl.dart';

/// 日记 Markdown 导出工具。
///
/// 设计目标：
/// - 在不引入额外 Markdown 转换依赖的前提下，覆盖日记场景常见格式；
/// - 保留标题、时间、标签等基础信息；
/// - 对列表/待办/引用/标题/代码块/图片做可读导出。
class DiaryMarkdownExporter {
  const DiaryMarkdownExporter._();

  static String build({
    required String title,
    required DateTime createdAt,
    required DateTime updatedAt,
    required List<String> tagNames,
    required quill.Document document,
  }) {
    final buffer = StringBuffer();
    final safeTitle = title.trim().isEmpty ? 'Untitled' : title.trim();
    final formatter = DateFormat('yyyy-MM-dd HH:mm');
    final createdLabel = formatter.format(createdAt.toLocal());
    final updatedLabel = formatter.format(updatedAt.toLocal());

    buffer.writeln('# ${_escape(safeTitle)}');
    buffer.writeln();
    buffer.writeln('- Created: $createdLabel');
    buffer.writeln('- Updated: $updatedLabel');
    if (tagNames.isNotEmpty) {
      buffer.writeln('- Tags: ${tagNames.join(', ')}');
    }
    buffer.writeln();

    buffer.write(_convertDeltaToMarkdown(document.toDelta().toJson()));
    return buffer.toString().trimRight();
  }

  static String _convertDeltaToMarkdown(List<dynamic> rawOps) {
    final ops = rawOps.whereType<Map>().map((op) => op.cast<String, dynamic>());
    final out = StringBuffer();
    final lineBuffer = StringBuffer();
    final orderedCounters = <int, int>{};
    var inCodeBlock = false;

    void flushLine([Map<String, dynamic>? lineAttrs]) {
      final rawLine = lineBuffer.toString();
      lineBuffer.clear();
      final attrs = lineAttrs ?? const <String, dynamic>{};
      final isCodeLine = attrs['code-block'] == true;
      final listType = attrs['list']?.toString();
      final headerLevel = attrs['header'] is num
          ? (attrs['header'] as num).toInt().clamp(1, 6)
          : null;
      final isBlockquote = attrs['blockquote'] == true;
      final indent = attrs['indent'] is num ? (attrs['indent'] as num).toInt() : 0;
      final indentPrefix = '  ' * indent;

      if (isCodeLine && !inCodeBlock) {
        inCodeBlock = true;
        out.writeln('```');
      }
      if (!isCodeLine && inCodeBlock) {
        inCodeBlock = false;
        out.writeln('```');
      }

      if (isCodeLine) {
        out.writeln(rawLine);
        return;
      }

      if (listType != 'ordered') {
        orderedCounters.clear();
      }

      String line = rawLine;
      if (headerLevel != null) {
        line = '${'#' * headerLevel} $line';
      } else if (listType == 'ordered') {
        final current = orderedCounters[indent] ?? 1;
        orderedCounters[indent] = current + 1;
        line = '$indentPrefix$current. $line';
      } else if (listType == 'bullet') {
        line = '$indentPrefix- $line';
      } else if (listType == 'checked') {
        line = '$indentPrefix- [x] $line';
      } else if (listType == 'unchecked') {
        line = '$indentPrefix- [ ] $line';
      } else if (isBlockquote) {
        line = '$indentPrefix> $line';
      }

      out.writeln(line);
    }

    for (final op in ops) {
      final attrs = (op['attributes'] is Map)
          ? (op['attributes'] as Map).cast<String, dynamic>()
          : const <String, dynamic>{};
      final insert = op['insert'];
      if (insert is String) {
        final parts = insert.split('\n');
        for (var i = 0; i < parts.length; i++) {
          final segment = parts[i];
          if (segment.isNotEmpty) {
            lineBuffer.write(_applyInlineStyles(segment, attrs));
          }
          if (i < parts.length - 1) {
            flushLine(attrs);
          }
        }
        continue;
      }
      if (insert is Map) {
        final image = insert['image'];
        if (image is String && image.trim().isNotEmpty) {
          if (lineBuffer.isNotEmpty) {
            flushLine();
          }
          out.writeln('![image](${image.trim()})');
          continue;
        }
        final video = insert['video'];
        if (video is String && video.trim().isNotEmpty) {
          if (lineBuffer.isNotEmpty) {
            flushLine();
          }
          out.writeln(video.trim());
        }
      }
    }

    if (lineBuffer.isNotEmpty) {
      flushLine();
    }
    if (inCodeBlock) {
      out.writeln('```');
    }
    return out.toString().trimRight();
  }

  static String _applyInlineStyles(String text, Map<String, dynamic> attrs) {
    var result = _escape(text);
    if (attrs['code'] == true) {
      result = '`$result`';
    }
    if (attrs['bold'] == true) {
      result = '**$result**';
    }
    if (attrs['italic'] == true) {
      result = '*$result*';
    }
    if (attrs['strike'] == true) {
      result = '~~$result~~';
    }
    if (attrs['underline'] == true) {
      result = '<u>$result</u>';
    }
    final link = attrs['link'];
    if (link is String && link.trim().isNotEmpty) {
      result = '[$result](${link.trim()})';
    }
    return result;
  }

  static String _escape(String raw) {
    return raw
        .replaceAll(r'\', r'\\')
        .replaceAll('`', r'\`')
        .replaceAll('*', r'\*')
        .replaceAll('_', r'\_')
        .replaceAll('{', r'\{')
        .replaceAll('}', r'\}')
        .replaceAll('[', r'\[')
        .replaceAll(']', r'\]')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)')
        .replaceAll('#', r'\#')
        .replaceAll('+', r'\+')
        .replaceAll('-', r'\-')
        .replaceAll('!', r'\!');
  }
}
