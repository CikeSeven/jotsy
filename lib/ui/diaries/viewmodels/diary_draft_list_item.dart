import 'dart:convert';

import '../../../core/database/app_database.dart';
import '../../../utils/text_stats.dart';
import 'diary_card_view_data.dart';

/// 草稿箱列表与新建面板里一行草稿的展示数据。
///
/// 输入：草稿表的一行；输出：显示标题（标题为空时取正文第一行，都没有时为
/// null，由界面显示“无标题”）、去掉已当作标题那一行后的单行摘要、字数、
/// 缩略图（封面优先，否则取正文第一张图，与日记卡片同一取图规则）。无副作用。
///
/// 正文 JSON 只在需要缩略图时解析一次：草稿通常只有几份，不做缓存。
class DiaryDraftListItem {
  DiaryDraftListItem._({
    required this.row,
    required this.displayTitle,
    required this.snippet,
  });

  factory DiaryDraftListItem.of(DiaryDraftRow row) {
    final title = _singleLine(row.title);
    final lines = row.contentText
        .split('\n')
        .map(_singleLine)
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    // 没写标题时，正文第一行顶上来当标题，摘要从第二行开始，不重复显示。
    final usesFirstLine = title.isEmpty && lines.isNotEmpty;
    final snippetLines = usesFirstLine ? lines.skip(1) : lines;
    return DiaryDraftListItem._(
      row: row,
      displayTitle: title.isNotEmpty
          ? title
          : (usesFirstLine ? lines.first : null),
      snippet: _truncate(snippetLines.join(' ')),
    );
  }

  /// 摘要最多两行，截断后再交给 Text，避免为长草稿排版整段正文。
  static const int snippetMaxLength = 160;

  final DiaryDraftRow row;

  /// null 表示标题与正文文字都为空（例如只有图片），界面显示“无标题”。
  final String? displayTitle;

  /// 单行化的摘要；可能为空字符串。
  final String snippet;

  String get draftId => row.draftId;
  DateTime get updatedAt => row.updatedAt;

  /// 正文字数（口径见 [TextStats]），按草稿与编辑时间缓存。
  late final int wordCount = DiaryWordCounts.of(
    diaryId: 'draft_${row.draftId}',
    updatedAt: row.updatedAt,
    text: row.contentText,
  );

  /// 缩略图路径：封面优先，否则取正文第一张图；载荷损坏或无图时为 null。
  late final String? thumbnail = _resolveThumbnail();

  String? _resolveThumbnail() {
    final Object? decoded;
    try {
      decoded = jsonDecode(row.payload);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final cover = decoded['cover'];
    if (cover is String && cover.trim().isNotEmpty) return cover.trim();
    final content = decoded['contentDocJson'];
    return content is String
        ? DiaryCardViewData.firstImageInContent(content)
        : null;
  }

  static String _singleLine(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _truncate(String text) => text.length > snippetMaxLength
      ? text.substring(0, snippetMaxLength)
      : text;
}
