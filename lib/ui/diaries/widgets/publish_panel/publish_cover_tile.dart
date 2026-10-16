import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_meta_actions.dart';
import 'package:node_diary/ui/diaries/models/diary_meta_draft.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_meta_draft_controller.dart';
import 'package:node_diary/ui/widgets/delayed_loading_gate.dart';
import 'package:node_diary/ui/widgets/expressive_image_frame.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';
import 'package:node_diary/ui/widgets/value_listenable_selector.dart';

import 'publish_panel_tile.dart';

/// 封面行：点按选图；已有封面时显示缩略图并可清除。只随草稿的封面与
/// 导入状态重建。
///
/// 选图后复制到应用目录需要一点时间：导入超过 [DelayedLoadingGate] 的延迟
/// 才在缩略图位置显示加载指示，快速完成时不闪。
class PublishCoverTile extends StatelessWidget {
  const PublishCoverTile({
    super.key,
    required this.draft,
    required this.actions,
  });

  final DiaryMetaDraftController draft;
  final DiaryMetaActions actions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textStyle = Theme.of(context).textTheme.bodySmall;
    return ValueListenableBuilder<bool>(
      valueListenable: actions.importingCover,
      builder: (context, importing, _) =>
          ValueListenableSelector<DiaryMetaDraft, String?>(
            valueListenable: draft,
            selector: (value) => value.cover,
            builder: (context, cover, _) => PublishPanelTile(
              onTap: importing ? null : () => actions.pickCover(context),
              child: Row(
                children: <Widget>[
                  Text(
                    l10n.autoT0162,
                    style: PublishPanelTile.titleStyle(context),
                  ),
                  const SizedBox(width: 12),
                  DelayedLoadingGate(
                    loading: importing,
                    builder: (context, showLoading) => showLoading
                        ? const SizedBox(
                            width: _CoverThumbnail.width,
                            height: _CoverThumbnail.height,
                            child: Center(
                              child: SizedBox.square(
                                dimension: 20,
                                child: ExpressiveLoadingIndicator(),
                              ),
                            ),
                          )
                        : cover == null
                        ? const SizedBox.shrink()
                        : _CoverThumbnail(cover: cover),
                  ),
                  if (cover != null) const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      cover == null ? l10n.autoT0161 : l10n.publishCoverChange,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textStyle,
                    ),
                  ),
                  if (cover != null && !importing)
                    IconButton(
                      onPressed: actions.clearCover,
                      icon: const FaIcon(FontAwesomeIcons.xmark, size: 12),
                      visualDensity: VisualDensity.compact,
                      tooltip: l10n.autoT0163,
                    ),
                  const SizedBox(width: 6),
                  const FaIcon(FontAwesomeIcons.chevronRight, size: 12),
                ],
              ),
            ),
          ),
    );
  }
}

/// 封面缩略图：按显示尺寸缩小解码（只限宽度、保持比例，小图不放大），
/// 首次解码淡入，加载失败显示占位图标。
class _CoverThumbnail extends StatelessWidget {
  const _CoverThumbnail({required this.cover});

  static const double width = 44;
  static const double height = 30;

  final String cover;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final uri = Uri.tryParse(cover);
    final isNetwork =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    final ImageProvider source = isNetwork
        ? NetworkImage(cover)
        : FileImage(File(cover));
    // 宽度按 2 倍取，裁成 cover 时横图高度也基本够用，不至于明显发虚。
    final decodeWidth = (width * 2 * MediaQuery.devicePixelRatioOf(context))
        .round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: width,
        height: height,
        child: Image(
          image: ResizeImage(source, width: decodeWidth, allowUpscaling: false),
          fit: BoxFit.cover,
          frameBuilder: expressiveImageFrameBuilder,
          errorBuilder: (context, _, _) => ColoredBox(
            color: colorScheme.surfaceContainer,
            child: Center(
              child: FaIcon(
                FontAwesomeIcons.image,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
