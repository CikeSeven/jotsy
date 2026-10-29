part of 'diary_export_blocks.dart';

/// 先序读取树的真实深度，不经编辑器或平铺格式往返。代码块内的换行拆成
/// 导出行，语言保持到每一行，供各格式整块高亮与围栏分组共用。
///
/// - 折叠列表与段落一样是容器：子块照常以更深的缩进跟在后面（导出时全部
///   展开）。
/// - 结构有效的表格（[DiaryTableGrid]）整个成一块，格子与格内段落不再各自
///   成块；结构无效的表格（读取时本已展开，只有手改数据才会遇到）按普通
///   块往下读，格子里的段落照常导出。
/// - 认不出的块类型（更新版本写入的新块）带 `delta` 时按段落导出，不丢文字；
///   原样保留的历史嵌入（[kDiaryBlockUnknownEmbed]）按 Quill 嵌入认读。
List<ExportBlock> _parseNativeBlocks(Map<String, Object?> document) {
  final blocks = <ExportBlock>[];
  final counters = <int, int>{};
  // 与 walkDiaryBlocks 同一顺序，下标一一对应。
  final listStyles = diaryListStylesInOrder(document);
  // 正在跳过的表格所在深度：它的格子与格内段落已经并进表格块。
  int? tableDepth;
  for (final (visit, (node, depth)) in walkDiaryBlocks(document).indexed) {
    if (tableDepth != null) {
      if (depth > tableDepth) continue;
      tableDepth = null;
    }
    final type = node['type'];
    final data = diaryBlockData(node);
    final align = _exportAlign(data['align']);
    final table = DiaryTableGrid.of(node);
    final kind = switch (type) {
      'paragraph' => ExportBlockKind.paragraph,
      'heading' => ExportBlockKind.heading,
      'bulleted_list' => ExportBlockKind.bullet,
      'numbered_list' => ExportBlockKind.ordered,
      'todo_list' =>
        data['checked'] == true
            ? ExportBlockKind.checked
            : ExportBlockKind.unchecked,
      'quote' => ExportBlockKind.quote,
      'code' => ExportBlockKind.code,
      'divider' => ExportBlockKind.divider,
      'image' => ExportBlockKind.image,
      'video' || 'audio' || 'attachment' => ExportBlockKind.media,
      kDiaryBlockCallout => ExportBlockKind.callout,
      kDiaryBlockToggleList => ExportBlockKind.toggle,
      _ when table != null => ExportBlockKind.table,
      _ when data[kDiaryBlockDeltaKey] is List => ExportBlockKind.paragraph,
      _ => null,
    };
    if (kind == null) {
      final value = data[kDiaryBlockValueKey];
      final embed = type == kDiaryBlockUnknownEmbed && value is Map
          ? ExportBlockParser._embed(value, indent: depth, align: align)
          : null;
      if (embed != null) {
        counters.removeWhere((key, _) => key >= depth);
        blocks.add(embed);
      }
      continue;
    }
    var ordinal = 0;
    if (kind == ExportBlockKind.ordered) {
      counters.removeWhere((key, _) => key > depth);
      ordinal = counters[depth] = (counters[depth] ?? 0) + 1;
    } else {
      counters.removeWhere((key, _) => key >= depth);
    }
    if (table != null) {
      tableDepth = depth;
      blocks.add(
        ExportBlock._(
          kind: ExportBlockKind.table,
          indent: depth,
          tableRows: _tableRows(table),
          tableHeaderRow: table.headerRow,
        ),
      );
      continue;
    }
    final file = kind == ExportBlockKind.media && type != 'audio'
        ? DiaryFileAttachment.tryDecode(data)
        : null;
    final audio = type == 'audio' ? DiaryAudioAttachment.tryDecode(data) : null;
    final source = kind == ExportBlockKind.image
        ? (data['url'] is String ? (data['url'] as String).trim() : null)
        : audio?.path ?? file?.path;
    if ((kind == ExportBlockKind.image || kind == ExportBlockKind.media) &&
        (source == null || source.isEmpty)) {
      continue;
    }
    final icon = data[kDiaryCalloutIconKey];
    final tone = data[kDiaryCalloutToneKey];
    for (final line in _inlineLines(node)) {
      final level = data['level'];
      blocks.add(
        ExportBlock._(
          kind: kind,
          inlines: List.unmodifiable(line),
          indent: depth,
          ordinal: ordinal,
          level: kind == ExportBlockKind.heading
              ? (level is num && level.isFinite ? level.toInt().clamp(1, 6) : 1)
              : 0,
          align: align,
          source: source,
          mediaKind: switch (type) {
            'audio' => ExportMediaKind.audio,
            'video' => ExportMediaKind.video,
            'attachment' => ExportMediaKind.file,
            _ => null,
          },
          mediaName: audio?.name ?? file?.displayName,
          mediaDuration: audio?.duration,
          codeLanguage: type == 'code'
              ? codeBlockExplicitLanguage(data['language'])
              : null,
          orderedStyle: listStyles[visit].ordered,
          bulletStyle: listStyles[visit].bullet,
          calloutIcon: kind != ExportBlockKind.callout
              ? null
              : icon is String && icon.trim().isNotEmpty
              ? icon.trim()
              : kDiaryCalloutDefaultIcon,
          calloutTone: kind != ExportBlockKind.callout
              ? null
              : kDiaryCalloutTones.contains(tone)
              ? tone as String
              : kDiaryCalloutToneDefault,
        ),
      );
    }
  }
  return List.unmodifiable(blocks);
}

ExportAlign _exportAlign(Object? value) => switch (value) {
  'center' => ExportAlign.center,
  'right' => ExportAlign.end,
  'justify' => ExportAlign.justify,
  _ => ExportAlign.start,
};

/// 文字块的行内片段按块内换行切成行（只有代码块会有多行）；没有文字时为
/// 一个空行。
List<List<ExportInline>> _inlineLines(Map<String, Object?> node) {
  final lines = <List<ExportInline>>[[]];
  for (final op in diaryBlockDelta(node)) {
    final attrs = op['attributes'];
    final parts = (op['insert'] as String).split('\n');
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) lines.add([]);
      if (parts[i].isNotEmpty) {
        lines.last.add(
          ExportInline.fromAttributes(
            parts[i],
            attrs is Map ? Map<String, dynamic>.from(attrs) : const {},
          ),
        );
      }
    }
  }
  return lines;
}

/// 表格的格子文字（[ExportBlock.tableRows]）：一格里的各段（及段内换行）
/// 之间放一个 [ExportInline.lineBreak]。
List<List<List<ExportInline>>> _tableRows(DiaryTableGrid table) {
  return List.unmodifiable(<List<List<ExportInline>>>[
    for (var row = 0; row < table.rows; row++)
      List.unmodifiable(<List<ExportInline>>[
        for (var col = 0; col < table.cols; col++)
          List<ExportInline>.unmodifiable(<ExportInline>[
            for (final (index, line) in <List<ExportInline>>[
              for (final block in table.textBlocksAt(row, col))
                ..._inlineLines(block),
            ].indexed) ...<ExportInline>[
              if (index > 0) ExportInline.lineBreak,
              ...line,
            ],
          ]),
      ]),
  ]);
}
