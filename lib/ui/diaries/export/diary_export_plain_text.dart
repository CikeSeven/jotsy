import 'diary_export_blocks.dart';

/// 块列表 → 纯文本（分享、TXT 与 CSV 导出共用）。
///
/// 纯文本的读者是社交应用的发布框、记事本与表格软件，它们都不渲染
/// Markdown，`**粗体**` 之类的标记会原样露出来，所以只保留读得懂的结构：
/// 列表用 `•` / `1.` / `☐` / `☑` 前缀、引用用 `> `、缩进两格一级；链接文字
/// 与地址不同时在后面附上地址；分隔线写成一行 [dividerLine]。嵌入块交给
/// [embedLabel] 决定写成一行说明还是略过（返回 null）。连续空行压成一行，
/// 首尾空行去掉。
class ExportPlainText {
  const ExportPlainText._();

  static const String dividerLine = '———';

  static String render(
    List<ExportBlock> blocks, {
    String? Function(ExportBlock block)? embedLabel,
  }) {
    final lines = <String>[];
    for (final block in blocks) {
      if (block.kind == ExportBlockKind.image ||
          block.kind == ExportBlockKind.media) {
        final label = embedLabel?.call(block);
        if (label != null) {
          lines.add(label);
        }
        continue;
      }
      if (block.kind == ExportBlockKind.divider) {
        lines.add(dividerLine);
        continue;
      }
      if (block.kind == ExportBlockKind.callout ||
          block.kind == ExportBlockKind.toggle ||
          block.kind == ExportBlockKind.table) {
        // 暂按普通段落写（ExportBlock.fallbackLines），内容不丢。
        for (final line in block.fallbackLines) {
          final text = line.map(_inlineText).join();
          lines.add(text.isEmpty ? '' : '${'  ' * block.indent}$text');
        }
        continue;
      }
      final text = block.inlines.map(_inlineText).join();
      final prefix = switch (block.kind) {
        ExportBlockKind.bullet ||
        ExportBlockKind.ordered => '${block.listMarker} ',
        ExportBlockKind.checked => '☑ ',
        ExportBlockKind.unchecked => '☐ ',
        ExportBlockKind.quote => '> ',
        _ => '',
      };
      lines.add(
        text.isEmpty && prefix.isEmpty
            ? ''
            : '${'  ' * block.indent}$prefix$text',
      );
    }
    return collapseBlankLines(lines);
  }

  static String _inlineText(ExportInline run) {
    final link = run.link;
    if (link != null && link != run.text.trim()) {
      return '${run.text} ($link)';
    }
    return run.text;
  }

  /// 连续空行压成一行，并去掉首尾空行与每行行尾空白。
  static String collapseBlankLines(Iterable<String> lines) {
    final out = <String>[];
    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.isEmpty && (out.isEmpty || out.last.isEmpty)) {
        continue;
      }
      out.add(line);
    }
    while (out.isNotEmpty && out.last.isEmpty) {
      out.removeLast();
    }
    return out.join('\n');
  }
}
