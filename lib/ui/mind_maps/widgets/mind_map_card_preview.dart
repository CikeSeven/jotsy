import 'package:flutter/material.dart';

import '../../../core/database/mind_map/mind_map_document.dart';
import '../../../core/database/mind_map/mind_map_text.dart';
import 'mind_map_thumbnail.dart';

/// 日记卡片上导图日记的“摘要”：导图缩略图 + 一行一级主题（用 “ · ” 连起）。
///
/// 颜色取卡片样式算好的值（[fill] / [border] 为卡片里小胶囊的底色与描边，
/// [captionStyle] 为摘要文字样式），自定义卡片颜色、经典与玻璃下都与卡片
/// 协调；导图本身按应用配色绘制。紧凑卡片矮一些。
class MindMapCardPreview extends StatelessWidget {
  const MindMapCardPreview({
    super.key,
    required this.document,
    required this.compact,
    required this.captionStyle,
    required this.fill,
    required this.border,
    this.centered = false,
  });

  final MindMapDocument document;
  final bool compact;
  final TextStyle? captionStyle;
  final Color fill;
  final Color border;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final topics = mindMapTopLevelTopics(document);
    return Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          height: compact ? 92 : 128,
          width: double.infinity,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 0.8),
          ),
          clipBehavior: Clip.antiAlias,
          child: MindMapThumbnail(
            document: document,
            padding: const EdgeInsets.all(10),
          ),
        ),
        if (topics.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            topics.join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: captionStyle,
          ),
        ],
      ],
    );
  }
}
