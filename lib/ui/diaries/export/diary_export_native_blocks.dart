part of 'diary_export_blocks.dart';

/// 先序读取树的真实深度，不经编辑器或平铺格式往返。代码块内的换行拆成
/// 导出行，语言保持到每一行，供各格式整块高亮与围栏分组共用。
///
/// - 折叠列表与段落一样是容器：子块照常以更深的缩进跟在后面（导出时全部
///   展开）。
/// - 结构有效的表格（[DiaryTableGrid]）整个成一块，格子与格内段落不再各自
///   成块；结构无效的表格（读取时本已展开，只有手改数据才会遇到）按普通
///   块往下读，格子里的段落照常导出。
/// - 日记链接卡片按一段快照标题导出（[diaryLinkCardTitle]）。
/// - 思维导图按大纲导出（[_mindMapBlocks]）：嵌入的导图先写加粗的中心主题，
///   其余主题写成逐级缩进的无序列表；整篇导图日记的中心主题就是标题，只写
///   下面的主题。
/// - 顶层连续的小图按应用的分排（[diaryThumbnailRowsBy]）标上所在那一排
///   （[ExportBlock.thumbnailRow]）：分排按顶层块本身算，而不是按导出的块
///   列表——导出时略过的块（没有快照的链接卡片、认不出又没有文字的块）在
///   应用里同样隔开前后两串小图。
/// - 认不出的块类型（更新版本写入的新块）带 `delta` 时按段落导出，不丢文字；
///   原样保留的历史嵌入（[kDiaryBlockUnknownEmbed]）按 Quill 嵌入认读。
List<ExportBlock> _parseNativeBlocks(Map<String, Object?> document) {
  final blocks = <ExportBlock>[];
  final counters = <int, int>{};
  // 与 walkDiaryBlocks 同一顺序，下标一一对应。
  final listStyles = diaryListStylesInOrder(document);
  // 正在跳过的表格所在深度：它的格子与格内段落已经并进表格块。
  int? tableDepth;
  final root = diaryBlocksRoot(document);
  final thumbnailRows = diaryThumbnailRowsBy(
    root == null ? const <Map<String, Object?>>[] : diaryBlockChildren(root),
    _isThumbnailImage,
  );
  // 当前顶层块的下标（walkDiaryBlocks 按同一个列表先序遍历）。
  var top = -1;
  for (final (visit, (node, depth)) in walkDiaryBlocks(document).indexed) {
    if (depth == 0) top++;
    if (tableDepth != null) {
      if (depth > tableDepth) continue;
      tableDepth = null;
    }
    final type = node['type'];
    final data = diaryBlockData(node);
    final align = _exportAlign(data['align']);
    if (type == kDiaryBlockMindMap) {
      counters.removeWhere((key, _) => key >= depth);
      blocks.addAll(_mindMapBlocks(data, depth));
      continue;
    }
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
      // 日记链接卡片：一段快照标题文字（内部地址在应用外打不开）；没有
      // 快照的卡片没有可导出的内容。
      kDiaryBlockLinkCard =>
        diaryLinkCardTitle(data) == null ? null : ExportBlockKind.paragraph,
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
    final imageLimits = kind == ExportBlockKind.image
        ? diaryImageSizeLimits(data)
        : null;
    final icon = data[kDiaryCalloutIconKey];
    final tone = data[kDiaryCalloutToneKey];
    final lines = type == kDiaryBlockLinkCard
        ? [
            [ExportInline(diaryLinkCardTitle(data)!)],
          ]
        : _inlineLines(node);
    for (final line in lines) {
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
          firstLineIndent: type == kDiaryBlockParagraph
              ? switch (data[kDiaryParagraphIndentKey]) {
                  final bool mark => mark,
                  _ => null,
                }
              : null,
          // 链接卡片在应用里是一张卡片，导出的标题行不按正文缩进。
          standIn: type == kDiaryBlockLinkCard,
          imageMaxWidth: imageLimits?.width,
          imageMaxHeight: imageLimits?.height,
          imageThumbnail:
              kind == ExportBlockKind.image &&
              data[kDiaryImageThumbnailKey] == true,
          thumbnailRow: depth == 0 && _isThumbnailImage(node)
              ? thumbnailRows[top].start
              : null,
        ),
      );
    }
  }
  return List.unmodifiable(blocks);
}

/// 导出里参与并排的小图：图片块且 `data.thumbnail` 恰为 `true`，读的是块
/// 文档的 JSON。编辑器的 `isDiaryThumbnailMedia` 还认视频小图，导出不认：
/// 导出里的视频是一行文件条、没有画面，夹在一排中间时把这一排断开。
bool _isThumbnailImage(Map<String, Object?> node) =>
    node[kDiaryBlockTypeKey] == kDiaryBlockImage &&
    diaryBlockData(node)[kDiaryImageThumbnailKey] == true;

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

/// 导图块的大纲：中心主题（整篇导图日记时省略，它就是标题）+ 逐级缩进的
/// 无序列表，空主题跳过；节点里的换行压成空格。主题的文字样式（整条的与
/// 局部的，见 [_mindMapInlines]）一并写出。
List<ExportBlock> _mindMapBlocks(Map<String, Object?> data, int depth) {
  final page = isMindMapPageData(data);
  final out = <ExportBlock>[];
  for (final line in mindMapOutlineLines(mindMapOfBlockData(data))) {
    if (line.text.isEmpty) continue;
    if (line.depth == 0) {
      if (page) continue;
      out.add(
        ExportBlock._(
          kind: ExportBlockKind.paragraph,
          inlines: _mindMapInlines(line.node, bold: true),
          indent: depth,
          standIn: true,
        ),
      );
      continue;
    }
    out.add(
      ExportBlock._(
        kind: ExportBlockKind.bullet,
        inlines: _mindMapInlines(line.node),
        indent: depth + line.depth - 1,
      ),
    );
  }
  return out;
}

/// 一个主题压成一行后的各段：局部样式优先，没设的随整条样式（`style`）；
/// [bold] 为这一行默认加粗（嵌入导图的中心主题）。文字颜色与高亮与正文
/// 同一套、按原色写出（半透明的高亮由各写出器叠在纸面上，同正文）。
List<ExportInline> _mindMapInlines(MindMapNode node, {bool bold = false}) {
  final style = MindMapNodeStyle(node.style);
  ExportInline inline(InlineTextRun run) {
    final marks = run.marks;
    return ExportInline(
      run.text,
      bold: marks.bold ?? (bold || style.bold == true),
      italic: marks.italic ?? style.italic ?? false,
      underline: marks.underline ?? style.underline ?? false,
      strike: marks.strike ?? style.strike ?? false,
      color: MindMapNodeStyle.parseColor(marks.color) ?? style.color,
      background:
          MindMapNodeStyle.parseColor(marks.highlight) ?? style.highlight,
    );
  }

  return <ExportInline>[
    for (final run in oneLineMindMapRuns(mindMapRunsOf(node))) inline(run),
  ];
}
