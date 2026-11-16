import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/database/mind_map/mind_map_document.dart';
import '../../../core/database/mind_map/mind_map_text.dart';
import '../../../l10n/app_localizations.dart';
import '../models/mind_map_options.dart';
import '../viewmodels/mind_map_labels.dart';
import 'mind_map_thumbnail.dart';

/// 正文里的导图外观：整篇导图日记的“舞台”与普通日记里嵌入的导图卡片。
///
/// 底色与日记链接卡片、提示块的中性档同为 `surfaceContainerHigh`，导图画在
/// 上面（导图的描边节点取卡片色，在这块底上仍分得清）。

/// 导图日记在阅读时的舞台：铺满正文宽度的大幅缩略图，高度按导图的外形在
/// 240 到 480 之间；底部一行是主题数与结构，右下角“全屏查看”。点按任意
/// 处打开全屏查看页（[onOpen]）。不处理拖动，预览页的左右翻页照常。
class MindMapStage extends StatelessWidget {
  const MindMapStage({super.key, required this.document, required this.onOpen});

  final MindMapDocument document;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final count = mindMapNodeCount(document);
    final structure = MindMapStructure.resolve(document.structure);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final height = mindMapPreferredHeight(
          document,
          context,
          width: constraints.maxWidth,
          min: 240,
          max: 480,
        );
        return Material(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  height: height,
                  child: MindMapThumbnail(
                    document: document,
                    padding: const EdgeInsets.all(24),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                  child: Row(
                    children: <Widget>[
                      FaIcon(
                        FontAwesomeIcons.sitemap,
                        size: 13,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${l10n.mindMapTopicCount(count)} · '
                          '${mindMapStructureLabel(l10n, structure)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: onOpen,
                        icon: const FaIcon(FontAwesomeIcons.expand, size: 13),
                        label: Text(l10n.mindMapViewFull),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          textStyle: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 普通日记里嵌入的导图卡片：16:9 缩略图（最高 220）+ 标题与主题数。
class MindMapEmbedCard extends StatelessWidget {
  const MindMapEmbedCard({
    super.key,
    required this.document,
    required this.onTap,
    this.onLongPress,
    this.onSecondaryTapUp,
    this.editable = false,
  });

  final MindMapDocument document;
  final VoidCallback onTap;
  final GestureLongPressStartCallback? onLongPress;
  final GestureTapUpCallback? onSecondaryTapUp;

  /// 编辑态：右侧是“编辑”铅笔，否则是“全屏”。
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final height = (constraints.maxWidth * 9 / 16).clamp(120.0, 220.0);
        return Semantics(
          button: true,
          label: mindMapTitle(l10n, document.root.text),
          child: GestureDetector(
            onLongPressStart: onLongPress,
            onSecondaryTapUp: onSecondaryTapUp,
            child: Material(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(
                      height: height,
                      child: ExcludeSemantics(
                        child: MindMapThumbnail(
                          document: document,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
                      child: Row(
                        children: <Widget>[
                          FaIcon(
                            FontAwesomeIcons.sitemap,
                            size: 13,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              mindMapTitle(l10n, document.root.text),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.mindMapTopicCount(mindMapNodeCount(document)),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 10),
                          FaIcon(
                            editable
                                ? FontAwesomeIcons.penToSquare
                                : FontAwesomeIcons.expand,
                            size: 13,
                            color: colors.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
