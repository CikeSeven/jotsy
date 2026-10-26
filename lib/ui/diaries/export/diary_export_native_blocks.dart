part of 'diary_export_blocks.dart';

/// 先序读取树的真实深度，不经编辑器或平铺格式往返。代码块内的换行拆成
/// 导出行，语言保持到每一行，供各格式整块高亮与围栏分组共用。
List<ExportBlock> _parseNativeBlocks(Map<String, Object?> document) {
  final blocks = <ExportBlock>[];
  final counters = <int, int>{};
  for (final (node, depth) in walkDiaryBlocks(document)) {
    final type = node['type'];
    final data = diaryBlockData(node);
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
      _ => null,
    };
    if (kind == null) continue;
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
    var ordinal = 0;
    if (kind == ExportBlockKind.ordered) {
      counters.removeWhere((key, _) => key > depth);
      ordinal = counters[depth] = (counters[depth] ?? 0) + 1;
    } else {
      counters.removeWhere((key, _) => key >= depth);
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
          align: switch (data['align']) {
            'center' => ExportAlign.center,
            'right' => ExportAlign.end,
            'justify' => ExportAlign.justify,
            _ => ExportAlign.start,
          },
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
        ),
      );
    }
  }
  return List.unmodifiable(blocks);
}
