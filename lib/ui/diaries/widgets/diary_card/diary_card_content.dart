import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../widgets/image_viewer_hero.dart';
import '../../models/diary_card_style/diary_card_style.dart';
import '../../viewmodels/diary_card_appearance.dart';
import '../../viewmodels/diary_card_resolved_style.dart';
import '../../viewmodels/diary_card_view_data.dart';
import 'diary_card_cover.dart';
import 'diary_card_cover_placeholder.dart';

/// 卡片骨架：按布局模式与封面位置把封面（或无封面占位）和正文区块排好。
///
/// - 列表侧边封面：`Padding → Row[封面, 间距, Expanded(正文)]`（封面在右时
///   镜像）；
/// - 顶部封面：通栏贴顶（上两角由卡片裁圆，下接细分隔线）或内缩到内边距
///   里；开启拼贴且正文有多张图时排成拼贴；
/// - 背景封面：封面铺满卡片，正文放在底部的半透明底板上；
/// - 隐藏：只有正文。
///
/// 默认样式（列表左侧 116 方图、瀑布流通栏 140 顶图）产出的结构与改版前
/// 相同。共享元素只挂在真实封面（拼贴的第一张）上，占位块不参与。
class DiaryCardContent extends StatelessWidget {
  const DiaryCardContent({
    super.key,
    required this.diary,
    required this.viewData,
    required this.resolved,
    required this.appearance,
    required this.blocks,
    required this.coverAnchor,
    this.coverIndicators,
  });

  final DiaryWithTags diary;
  final DiaryCardViewData viewData;
  final DiaryCardResolvedStyle resolved;
  final DiaryCardAppearance appearance;
  final Widget blocks;

  /// 点按卡片时抓取封面画面的锚点；null 表示不参与共享元素（设置页预览）。
  final ImageViewerHeroAnchor? coverAnchor;

  /// 叠在封面角上的心情天气（样式把它放在封面上且这张卡有封面时）。
  final Widget? coverIndicators;

  DiaryCardModeStyle get _m => resolved.modeStyle;

  EdgeInsetsDirectional _textPadding({bool atTop = true}) =>
      EdgeInsetsDirectional.fromSTEB(
        resolved.paddingH + resolved.accentStartInset,
        resolved.paddingV + (atTop ? resolved.accentTopInset : 0),
        resolved.paddingH,
        resolved.paddingV,
      );

  @override
  Widget build(BuildContext context) {
    final cover = viewData.previewCover;
    return switch (_m.coverPosition) {
      DiaryCardCoverPosition.start ||
      DiaryCardCoverPosition.end => _side(context, cover),
      DiaryCardCoverPosition.top => _top(context, cover),
      DiaryCardCoverPosition.background when cover != null => _background(
        context,
        cover,
      ),
      DiaryCardCoverPosition.background || DiaryCardCoverPosition.hidden =>
        Padding(padding: _textPadding(), child: blocks),
    };
  }

  Widget _withIndicators(Widget cover) {
    final indicators = coverIndicators;
    if (indicators == null) {
      return cover;
    }
    return Stack(
      children: <Widget>[
        cover,
        PositionedDirectional(top: 6, end: 6, child: indicators),
      ],
    );
  }

  Widget _hero(BorderRadius radius, Widget child) => DiaryCardCoverHero(
    diaryId: diary.diary.diaryId,
    anchor: coverAnchor,
    borderRadius: radius,
    child: child,
  );

  /// 没有封面时的占位；样式未开启或缺少心情时为 null。
  Widget? _placeholder({
    required double? width,
    required double height,
    required double radius,
    bool horizontal = false,
  }) {
    switch (resolved.style.content.coverFallback) {
      case DiaryCardCoverFallback.none:
        return null;
      case DiaryCardCoverFallback.dateBlock:
        return DiaryCardDateBlock(
          date: resolved.style.meta.dateSource == DiaryCardDateSource.created
              ? diary.diary.createdAt
              : diary.diary.updatedAt,
          width: width,
          height: height,
          radius: radius,
          horizontal: horizontal,
        );
      case DiaryCardCoverFallback.moodTile:
        final mood = viewData.moodEmoji;
        if (mood == null) {
          return null;
        }
        return DiaryCardMoodTile(
          moodEmoji: mood,
          tint: resolved.moodColorFor(mood),
          width: width,
          height: height,
          radius: radius,
        );
    }
  }

  Widget _side(BuildContext context, String? cover) {
    final size = resolved.sideCoverSize;
    final radius = _m.coverShape == DiaryCardCoverShape.circle
        ? size.width / 2
        : _m.coverRadius;
    final Widget? coverWidget = cover != null
        ? _withIndicators(
            _hero(
              BorderRadius.circular(radius),
              DiaryCardCoverImage(
                source: cover,
                width: size.width,
                height: size.height,
                radius: radius,
              ),
            ),
          )
        : _placeholder(width: size.width, height: size.height, radius: radius);
    final atStart = _m.coverPosition == DiaryCardCoverPosition.start;
    return Padding(
      padding: _textPadding(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (coverWidget != null && atStart) ...[
            coverWidget,
            SizedBox(width: _m.coverGap),
          ],
          Expanded(child: blocks),
          if (coverWidget != null && !atStart) ...[
            SizedBox(width: _m.coverGap),
            coverWidget,
          ],
        ],
      ),
    );
  }

  Widget _top(BuildContext context, String? cover) {
    final inset = _m.coverInset;
    final height = _m.coverHeight;
    final Widget? coverWidget;
    if (cover != null) {
      final direction = Directionality.of(context);
      final images = resolved.style.content.collage
          ? viewData.collageImages
          : const <String>[];
      // 通栏封面贴着卡片顶边，上方两角由卡片裁圆；内缩封面四角自带圆角。
      final visibleRadius = inset
          ? BorderRadius.circular(_m.coverRadius)
          : BorderRadius.vertical(top: Radius.circular(resolved.cornerRadius));
      if (images.length > 1) {
        final firstRadius =
            (inset
                    ? BorderRadiusDirectional.horizontal(
                        start: Radius.circular(_m.coverRadius),
                      )
                    : BorderRadiusDirectional.only(
                        topStart: Radius.circular(resolved.cornerRadius),
                      ))
                .resolve(direction);
        final collage = DiaryCardCollage(
          first: _hero(
            firstRadius,
            DiaryCardCoverImage(
              source: images.first,
              height: height,
              radius: 0,
            ),
          ),
          others: images.sublist(1),
          height: height,
        );
        coverWidget = _withIndicators(
          inset
              ? ClipRRect(borderRadius: visibleRadius, child: collage)
              : collage,
        );
      } else {
        coverWidget = _withIndicators(
          _hero(
            visibleRadius,
            DiaryCardCoverImage(
              source: cover,
              width: double.infinity,
              height: height,
              radius: inset ? _m.coverRadius : 0,
            ),
          ),
        );
      }
    } else {
      coverWidget = _placeholder(
        width: double.infinity,
        height: height < 88 ? height : 88,
        radius: inset ? _m.coverRadius : 0,
        horizontal: true,
      );
    }

    if (inset) {
      return Padding(
        padding: _textPadding(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (coverWidget != null) ...[
              coverWidget,
              SizedBox(height: _m.coverGap),
            ],
            blocks,
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (coverWidget != null) ...[
          coverWidget,
          if (_m.coverDivider)
            Divider(
              height: 0.6,
              thickness: 0.6,
              color: appearance.dividerColor,
            ),
        ],
        Padding(
          padding: _textPadding(atTop: coverWidget == null),
          child: blocks,
        ),
      ],
    );
  }

  Widget _background(BuildContext context, String cover) {
    final indicators = coverIndicators;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: _m.coverHeight),
      child: Stack(
        alignment: AlignmentDirectional.bottomStart,
        children: <Widget>[
          Positioned.fill(
            child: _hero(
              BorderRadius.circular(resolved.cornerRadius),
              DiaryCardCoverImage(
                source: cover,
                width: double.infinity,
                height: double.infinity,
                radius: 0,
              ),
            ),
          ),
          if (indicators != null)
            PositionedDirectional(
              top: 8 + resolved.accentTopInset,
              end: 8,
              child: indicators,
            ),
          Container(
            width: double.infinity,
            color: appearance.panelColor.withValues(
              alpha: appearance.panelColor.a * _m.scrim,
            ),
            padding: _textPadding(atTop: false),
            child: blocks,
          ),
        ],
      ),
    );
  }
}
