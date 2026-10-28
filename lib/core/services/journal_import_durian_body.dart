import 'dart:convert';

import 'package:path/path.dart' as p;

import '../database/divider_embed_codec.dart';
import 'journal_import_block_writer.dart';
import 'journal_import_markdown.dart';
import 'journal_import_media.dart';
import 'journal_import_quill.dart';

/// 榴莲日记一篇日记的正文与媒体（依据应用 0.14x 的逆向分析）。
///
/// `diary.type` 决定正文所在的列：
/// - 0 纯文本：`content` 是文本框原文；图片格 `images_grid` 显示在正文之后；
/// - 1 富文本：`quill_json` 是 flutter_quill 的 Delta（op 数组），`content`
///   只是纯文本副本（嵌入处为 U+FFFC）；`quill_json` 为空或不是合法 Delta
///   时应用自己也退回显示 `content`；
/// - 2 Markdown：`content` 是 Markdown 原文，图片写作 `![](文件名)`；
/// - 其他值应用不显示正文，这里按纯文本兜底，不丢文字。
///
/// 图片格是逗号分隔的媒体项：`img:<名>`、`video:<名>`、`live:<静图>|<视频>`
/// （实况照片），不带前缀的按图片；富文本的图片嵌入
/// `{"image": "<同样的写法>"}` 也用这套写法。富文本与 Markdown 的图片格是
/// “本篇用过的媒体”，与正文里的图片重叠，只补上正文没引用的项。
///
/// 文件都以裸文件名存放在备份的 `image/`（图片、视频、实况两段）与
/// `attachment/`（录音与其他文件）目录里；旧数据可能存着原设备上的绝对
/// 路径或经过 URL 编码，一律按文件名查找。
class DurianDiaryBody {
  DurianDiaryBody({
    required this.media,
    required this.images,
    required this.attachments,
  });

  final JournalMediaStager media;

  /// 备份 `image/` 与 `attachment/` 目录下的文件：小写文件名 → 路径。
  final Map<String, String> images;
  final Map<String, String> attachments;

  /// 写出一篇日记的正文：先正文，再补图片格里正文没用到的媒体，最后是
  /// 按 `position` 排好的附件路径。
  void write(
    JournalBlockWriter writer, {
    required int? type,
    required String content,
    required String quillJson,
    required String imagesGrid,
    required List<String> attachmentPaths,
  }) {
    final used = <String>{};
    final grid = parseDurianMediaItems(imagesGrid);
    final ops = type == 1 ? decodeDurianQuill(quillJson) : null;
    if (ops != null) {
      appendJournalQuillOps(
        writer,
        ops,
        resolveEmbed: (embed) => _embedOf(embed, used),
      );
    } else if (type == 2) {
      JournalMarkdownConverter(
        writer,
        inlineHtml: true,
        resolveEmbed: (source) => _markdownImage(source, used),
      ).append(content);
    } else {
      // 富文本退回 content 时去掉嵌入占位符；纯文本原样保留空白与空行。
      // 只有空白时不写，免得只有图片的日记开头多出空行。
      final text = type == 1 ? content.replaceAll('\uFFFC', '') : content;
      if (text.trim().isNotEmpty) appendJournalPlainText(writer, text);
    }
    // 正文已引用的文件跳过；实况照片只引用了一段时补上另一段。
    for (final item in grid) {
      _writeItem(writer, item, used);
    }
    for (final path in attachmentPaths) {
      final file = _find(path, attachments) ?? _find(path, images);
      if (file == null) {
        media.missingCount++;
        continue;
      }
      if (!used.add(_key(path))) continue;
      final data = media.embedFile(file);
      if (data != null) writer.embed(data);
    }
  }

  /// 评论里的图片，写法与图片格相同；旧数据可能是 JSON 字符串数组。
  void writeMedia(JournalBlockWriter writer, String items) {
    final used = <String>{};
    for (final item in parseDurianCommentMedia(items)) {
      _writeItem(writer, item, used);
    }
  }

  /// 富文本嵌入：分隔线、图片 / 视频；实况照片的静图与视频依次放在原位。
  /// 认不出的嵌入（应用只有这两种）丢弃。
  List<Map<String, Object?>> _embedOf(
    Map<Object?, Object?> embed,
    Set<String> used,
  ) {
    if (embed.containsKey('divider')) return const [diaryDividerEmbed];
    final value = embed['image'];
    final item = value is String ? parseDurianMediaItem(value) : null;
    if (item == null) return const [];
    // 正文里同一张图出现多次就照样放多次（暂存只拷一份）；“已用过”只用来
    // 给图片格去重。
    return [
      for (final (index, file) in item.files.indexed)
        if (_resolve(file, item.kinds[index], used) case final data?) data,
    ];
  }

  /// Markdown 的 `![](名字)`：只认本地文件名与网页图片，实况照片在
  /// Markdown 里不会出现。本地文件缺失时丢弃。
  Map<String, Object?>? _markdownImage(String source, Set<String> used) {
    final item = parseDurianMediaItem(source);
    return item == null
        ? null
        : _resolve(item.files.first, item.kinds.first, used);
  }

  void _writeItem(
    JournalBlockWriter writer,
    DurianMediaItem item,
    Set<String> used,
  ) {
    for (final (index, file) in item.files.indexed) {
      if (used.contains(_key(file))) continue;
      final data = _resolve(file, item.kinds[index], used);
      if (data != null) writer.embed(data);
    }
  }

  /// 网页地址原样作为网络图片；本地文件按文件名在 `image/`（再找
  /// `attachment/`）里查找，缺失时计入缺失并返回 null。
  Map<String, Object?>? _resolve(
    String value,
    JournalMediaKind kind,
    Set<String> used,
  ) {
    if (RegExp(r'^https?://', caseSensitive: false).hasMatch(value)) {
      used.add(_key(value));
      return kind == JournalMediaKind.image ? {'image': value} : null;
    }
    final file = _find(value, images) ?? _find(value, attachments);
    used.add(_key(value));
    if (file == null) {
      media.missingCount++;
      return null;
    }
    return media.embedFile(file, kind: kind);
  }
}

/// 图片格或嵌入里的一项：文件与各自的类型（实况照片是静图 + 视频两项）。
class DurianMediaItem {
  const DurianMediaItem(this.files, this.kinds);

  final List<String> files;
  final List<JournalMediaKind> kinds;
}

/// 解析一项媒体写法，空值返回 null。`live:` 两段都非空才算实况，否则
/// 与应用一致按整串当图片。
DurianMediaItem? parseDurianMediaItem(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  if (value.startsWith('img:')) {
    final name = value.substring(4).trim();
    return name.isEmpty
        ? null
        : DurianMediaItem([name], const [JournalMediaKind.image]);
  }
  if (value.startsWith('video:')) {
    final name = value.substring(6).trim();
    return name.isEmpty
        ? null
        : DurianMediaItem([name], const [JournalMediaKind.video]);
  }
  if (value.startsWith('live:')) {
    final parts = value.substring(5).split('|');
    if (parts.length == 2 &&
        parts[0].trim().isNotEmpty &&
        parts[1].trim().isNotEmpty) {
      return DurianMediaItem(
        [parts[0].trim(), parts[1].trim()],
        const [JournalMediaKind.image, JournalMediaKind.video],
      );
    }
  }
  return DurianMediaItem([value], const [JournalMediaKind.image]);
}

/// 图片格：逗号分隔的媒体项（网络图片地址已经过 URL 编码，不含逗号）。
List<DurianMediaItem> parseDurianMediaItems(String grid) => [
  for (final part in grid.split(','))
    if (parseDurianMediaItem(part) case final item?) item,
];

/// 评论的 `images`：逗号分隔的媒体项，或旧版的 JSON 字符串数组。
List<DurianMediaItem> parseDurianCommentMedia(String raw) {
  final text = raw.trim();
  if (text.startsWith('[')) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        return [
          for (final value in decoded)
            if (value is String)
              if (parseDurianMediaItem(value) case final item?) item,
        ];
      }
    } on FormatException {
      // 不是 JSON：按逗号分隔的写法读。
    }
  }
  return parseDurianMediaItems(text);
}

/// 富文本 `quill_json`：op 数组（不是 `{"ops": …}`），去掉 `retain` op。
/// 应用要求每个 op 都是对象、最后一个 op 是以换行结尾的文字，否则改为只读
/// 显示 `content`；这里同样返回 null 让调用方退回 `content`。
List<Object?>? decodeDurianQuill(String raw) {
  if (raw.trim().isEmpty) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return null;
  }
  if (decoded is! List) return null;
  final ops = [
    for (final op in decoded)
      if (op is! Map || !op.containsKey('retain')) op,
  ];
  if (ops.isEmpty || ops.any((op) => op is! Map)) return null;
  final last = (ops.last as Map)['insert'];
  return last is String && last.endsWith('\n') ? ops : null;
}

/// 文件名查找键：经过 URL 编码的先解码，带目录的取文件名，忽略大小写。
String _key(String value) {
  var name = value.trim().replaceAll('\\', '/');
  try {
    name = Uri.decodeComponent(name);
  } on ArgumentError {
    // 文件名里本来就有 `%`：按原样查找。
  } on FormatException {
    // 同上。
  }
  return p.posix.basename(name).toLowerCase();
}

String? _find(String value, Map<String, String> index) =>
    index[_key(value)] ??
    index[p.posix.basename(value.trim().replaceAll('\\', '/')).toLowerCase()];
