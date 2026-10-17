import 'dart:ui' as ui show Image;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/image_viewer_hero.dart';
import '../../models/diary_preview_style/diary_preview_behavior.dart';
import '../../models/diary_preview_style/diary_preview_style.dart';
import '../../models/time_capsule.dart';
import '../../providers/diary_typography_provider.dart';
import '../../viewmodels/diary_preview_resolved_style.dart';
import '../../viewmodels/diary_preview_view_data.dart';
import 'diary_preview_body.dart';
import 'diary_preview_header.dart';
import 'diary_preview_meta.dart';
import 'diary_preview_neighbors.dart';
import 'diary_preview_top_bar.dart';

/// 打开看图页：本篇的全部图片来源、点按的那一张与抓取的共享元素。
typedef DiaryPreviewImageOpener =
    void Function(
      List<String> sources,
      String initialSource,
      ImageViewerHero? hero,
    );

/// 预览页顶栏的动作。
class DiaryPreviewActions {
  const DiaryPreviewActions({
    required this.onOpenTypography,
    required this.onEdit,
    required this.onShare,
    required this.onMore,
    this.onBack,
  });

  final VoidCallback onOpenTypography;
  final VoidCallback onEdit;
  final VoidCallback onShare;
  final VoidCallback onMore;

  /// 返回按钮；null 时返回上一页。
  final VoidCallback? onBack;
}

/// 预览页的整页内容：顶栏、头图、标题、信息栏与正文组成的滚动视图，版式全部
/// 来自 [DiaryPreviewResolvedStyle]。
///
/// 输入：已解封的日记、它的派生数据与只读 Quill 控制器、解析后的样式与阅读
/// 行为，以及顶栏动作与看图回调；不读写数据库，也不持有状态，设置页的实时
/// 预览可以直接复用。默认样式下产出的部件结构与改版前逐项相同。
///
/// 放在翻页器里时传入 [paging]：顶栏可显示位置，正文末尾可显示上一篇 /
/// 下一篇，滚动视图改为始终可滚动——正文不满一屏时也要有竖向识别器参与
/// 手势竞争，斜着滑才不会被当成翻页（见 `DiaryPagerView`）。
class DiaryPreviewContent extends ConsumerWidget {
  const DiaryPreviewContent({
    super.key,
    required this.detail,
    required this.viewData,
    required this.controller,
    required this.scrollController,
    required this.resolved,
    required this.behavior,
    required this.actions,
    required this.onOpenImage,
    this.coverHeroTag,
    this.coverPlaceholder,
    this.staticCover = false,
    this.extraBottomPadding = 0,
    this.paging,
  });

  final DiaryWithTags detail;
  final DiaryPreviewViewData viewData;

  /// 正文控制器；尚未绑定时为 null（正文区不占位）。
  final quill.QuillController? controller;
  final ScrollController scrollController;
  final DiaryPreviewResolvedStyle resolved;
  final DiaryPreviewBehavior behavior;
  final DiaryPreviewActions actions;
  final DiaryPreviewImageOpener onOpenImage;

  /// 头图的共享元素标签；null 时不建立 Hero。
  final Object? coverHeroTag;

  /// 列表封面抓取的画面：头图共享元素的落点与占位。
  final ui.Image? coverPlaceholder;

  /// 分享长图期间用静态头图（见 [DiaryPreviewCover]）。
  final bool staticCover;

  /// 页尾额外留白（设置页预览底部被面板圆角压住的高度）。
  final double extraBottomPadding;

  /// 在翻页顺序里的位置；单篇打开时为 null。
  final DiaryPreviewPaging? paging;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final diary = detail.diary;
    final style = resolved.style;
    final appearance = ref.watch(diaryTextAppearanceProvider);
    final capsuleState = TimeCapsuleState.fromFields(
      lockedAt: diary.capsuleLockedAt,
      unlockAt: diary.capsuleUnlockAt,
      now: DateTime.now(),
    );
    final images = viewData.images;
    final coverSource = style.cover.mode == DiaryPreviewCoverMode.hidden
        ? null
        : style.cover.useFirstImage
        ? viewData.coverSource
        : _explicitCover(diary);
    final title = _titleText(l10n, diary, style.title);
    final meta = style.meta;
    final hasMeta = DiaryPreviewMeta.hasContent(detail, viewData, meta);
    final metaWidget = hasMeta
        ? DiaryPreviewMeta(detail: detail, viewData: viewData, style: meta)
        : null;
    final controller = this.controller;
    final editedLabel = style.body.showLastEdited
        ? diaryPreviewEditedLabel(l10n, diary, style.body.editedFormat)
        : null;
    final showInsight = style.body.showCapsuleInsight;
    final paging = this.paging;
    final neighbors =
        paging != null && paging.hasNeighbors && style.navigation.neighborCards
        ? paging
        : null;

    // 标题与信息栏的上下顺序：信息栏在上时它先占 14 的上边距，标题收为 10。
    final metaAbove =
        metaWidget != null &&
        meta.position == DiaryPreviewMetaPosition.aboveTitle;
    final metaBelow =
        metaWidget != null &&
        meta.position == DiaryPreviewMetaPosition.belowTitle;
    final metaAtEnd =
        metaWidget != null && meta.position == DiaryPreviewMetaPosition.end;

    return CustomScrollView(
      controller: scrollController,
      physics: paging == null ? null : const AlwaysScrollableScrollPhysics(),
      slivers: <Widget>[
        DiaryPreviewTopBar(
          style: style.page,
          title: switch (style.page.topBarTitle) {
            DiaryPreviewTopBarTitle.label => l10n.autoT0120,
            DiaryPreviewTopBarTitle.date => l10n.formatFullDate(
              diary.createdAt.toLocal(),
            ),
            DiaryPreviewTopBarTitle.none => null,
            DiaryPreviewTopBarTitle.position =>
              paging?.position ?? l10n.autoT0120,
          },
          titleSemantics:
              style.page.topBarTitle == DiaryPreviewTopBarTitle.position
              ? paging?.positionSemantics
              : null,
          background: resolved.background,
          onOpenTypography: actions.onOpenTypography,
          onEdit: actions.onEdit,
          onShare: actions.onShare,
          onMore: actions.onMore,
          onBack: actions.onBack,
        ),
        if (coverSource != null)
          DiaryPreviewCover(
            heroTag: coverHeroTag,
            source: coverSource,
            resolved: resolved,
            staticCover: staticCover,
            placeholder: coverPlaceholder,
            onTap: (hero) => onOpenImage(images, coverSource, hero),
          ),
        if (metaAbove)
          DiaryPreviewSection(resolved: resolved, top: 14, child: metaWidget),
        if (title != null)
          DiaryPreviewTitle(
            title: title,
            appearance: appearance,
            resolved: resolved,
            topPadding: metaAbove ? 10 : 14,
          ),
        if (metaBelow)
          DiaryPreviewSection(
            resolved: resolved,
            top: title == null ? 14 : 10,
            child: metaWidget,
          ),
        DiaryPreviewSection(
          resolved: resolved,
          top: 14,
          bottom: 28 + extraBottomPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (showInsight) ...<Widget>[
                DiaryPreviewCapsuleInsight(
                  capsuleState: capsuleState,
                  moodEmoji: viewData.moodEmoji,
                ),
                if (capsuleState.isCapsule) const SizedBox(height: 14),
              ],
              if (controller == null)
                const SizedBox.shrink()
              else ...<Widget>[
                DiaryPreviewBody(
                  controller: controller,
                  appearance: appearance,
                  onOpenImage: (source, hero) =>
                      onOpenImage(images, source, hero),
                  showEmptyHint: style.body.showEmptyHint,
                  todoToggle: behavior.todoToggle,
                  textSelection: behavior.textSelection,
                  textColor: resolved.bodyColor,
                ),
                if (metaAtEnd) ...<Widget>[
                  const SizedBox(height: 20),
                  metaWidget,
                ],
                if (editedLabel != null) ...<Widget>[
                  const SizedBox(height: 16),
                  DiaryPreviewEditedLine(label: editedLabel),
                ],
                if (neighbors != null) ...<Widget>[
                  const SizedBox(height: 24),
                  DiaryPreviewNeighborCards(
                    paging: neighbors,
                    textColor: resolved.bodyColor,
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String? _explicitCover(Diary diary) {
    final cover = diary.cover?.trim();
    return cover == null || cover.isEmpty ? null : cover;
  }

  /// 标题行文字：样式隐藏标题时为 null；没写标题时按“无标题”占位开关取
  /// 占位文字或 null。
  static String? _titleText(
    AppLocalizations l10n,
    Diary diary,
    DiaryPreviewTitleStyle style,
  ) {
    if (!style.visible) {
      return null;
    }
    final title = diary.title.trim();
    if (title.isNotEmpty) {
      return title;
    }
    return style.showUntitled ? l10n.autoT0033 : null;
  }
}
