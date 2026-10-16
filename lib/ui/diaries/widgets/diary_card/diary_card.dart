import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/image_viewer_hero.dart';
import '../../models/diary_card_style/diary_card_style.dart';
import '../../models/time_capsule.dart';
import '../../pages/locked_diary_page.dart';
import '../../viewmodels/diary_card_resolved_style.dart';
import '../../viewmodels/diary_card_view_data.dart';
import '../diary_selection_surface.dart';
import 'diary_card_blocks.dart';
import 'diary_card_content.dart';
import 'diary_card_locked_content.dart';
import 'diary_card_selection_mark.dart';

/// 打开日记：整条数据 + 从封面抓取的共享元素画面（可能为 null）。
typedef DiaryOpenCallback =
    void Function(DiaryWithTags diary, ImageViewerHero? coverHero);

/// 日记列表 / 瀑布流 / 搜索 / 归档 / 日历卡片视图共用的日记卡片。
///
/// 输入：日记数据、已解析的卡片样式 [resolved]、选择状态与交互回调；输出：
/// 卡片本身（表面、内容与点按反馈），不含列表项的进出动画与滑动归档
/// （由 `DiariesListSection` 包裹）。
///
/// 结构：`DiarySelectionSurface → ClipRRect → Stack[内容, 强调条, (选择标记
/// 浮层), 墨水层]`。水波纹与按压高亮叠在内容之上：画在内容下方透明
/// Material 上的墨水会被封面图、未解封胶囊的不透明主体盖住，按下去几乎看
/// 不到反馈。卡片内容不含可点击子控件，前景层不会吞掉其他交互；点击/长按
/// 语义仍并入 DiarySelectionSurface 的容器节点。
///
/// 交互：选择模式下点击切换选中；普通模式点击进入预览页（未解封胶囊进入
/// 封存页）；长按强制选中。
class DiaryCard extends StatelessWidget {
  const DiaryCard({
    super.key,
    required this.diary,
    required this.resolved,
    required this.selected,
    required this.isSelectionMode,
    required this.maxVisibleTags,
    required this.onOpenEditor,
    required this.onToggleSelection,
    this.enableCoverHero = true,
    this.opensLockedCapsulePage = true,
  });

  /// 选择标记展开、列表项进出的过渡时长。
  static const Duration transitionDuration = ExpressiveMotion.medium;

  final DiaryWithTags diary;
  final DiaryCardResolvedStyle resolved;
  final bool selected;
  final bool isSelectionMode;
  final int maxVisibleTags;
  final DiaryOpenCallback onOpenEditor;
  final void Function(String noteId, bool forceSelect) onToggleSelection;

  /// 封面是否作为预览页头图的共享元素来源；设置页预览里关闭，避免与真实
  /// 列表的同名 Hero 冲突。
  final bool enableCoverHero;

  /// 点按未解封胶囊是否进入封存页；设置页预览的示例胶囊不是真实日记，
  /// 关闭后改为走 [onOpenEditor]。
  final bool opensLockedCapsulePage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entry = diary.diary;
    final diaryId = entry.diaryId;
    // metadata、摘要与封面按 (diaryId, updatedAt) 缓存，滚动重建不再重复解析。
    final viewData = DiaryCardViewData.of(entry);
    final capsuleState = TimeCapsuleState.fromFields(
      lockedAt: entry.capsuleLockedAt,
      unlockAt: entry.capsuleUnlockAt,
      now: DateTime.now(),
    );
    final isLockedCapsule = capsuleState.isLocked;
    final appearance = resolved.appearanceFor(
      pinned: entry.isPinned,
      locked: isLockedCapsule,
      moodEmoji: viewData.moodEmoji,
      tags: diary.tags,
    );
    final title = entry.title.trim().isEmpty ? l10n.autoT0033 : entry.title;
    // 封面所在的 context：点按卡片时从这里抓取已绘制的封面画面。未解封胶囊
    // 的模糊封面不参与共享元素。
    final coverAnchor = enableCoverHero ? ImageViewerHeroAnchor() : null;
    final style = resolved.style;
    final radius = resolved.cornerRadius;

    Widget content;
    var markOverlay = false;
    if (isLockedCapsule) {
      content = DiaryCardLockedContent(
        diary: diary,
        title: title,
        previewCover: viewData.previewCover,
        capsuleState: capsuleState,
        resolved: resolved,
        appearance: appearance,
      );
    } else {
      final hasCover =
          viewData.previewCover != null &&
          resolved.modeStyle.coverPosition != DiaryCardCoverPosition.hidden;
      final metaPosition = resolved.metaPositionFor(hasCover: hasCover);
      final blocks = DiaryCardBlocks(
        diary: diary,
        viewData: viewData,
        title: title,
        resolved: resolved,
        appearance: appearance,
        selected: selected,
        isSelectionMode: isSelectionMode,
        maxVisibleTags: maxVisibleTags,
        metaPosition: metaPosition,
        selectionMarkDuration: transitionDuration,
      );
      final indicators = blocks.buildIndicators(onCover: true);
      content = DiaryCardContent(
        diary: diary,
        viewData: viewData,
        resolved: resolved,
        appearance: appearance,
        blocks: blocks,
        coverAnchor: coverAnchor,
        coverIndicators:
            metaPosition == DiaryCardMetaPosition.cover && !indicators.isEmpty
            ? indicators
            : null,
      );
      markOverlay =
          DiaryCardBlocks.selectionMarkHost(
            style,
            hasEyebrow: DiaryCardBlocks.hasEyebrowContent(
              style: style,
              pinned: entry.isPinned,
              hasIndicators: !blocks.buildIndicators().isEmpty,
              metaPosition: metaPosition,
            ),
          ) ==
          null;
    }

    final accentBar = style.surface.accentBar;
    final accentBarColor = appearance.accentBarColor;
    return DiarySelectionSurface(
      diaryId: diaryId,
      selected: selected,
      compact: resolved.compact,
      spec: appearance.surface,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: <Widget>[
            content,
            if (accentBarColor != null && accentBar == DiaryCardAccentBar.start)
              PositionedDirectional(
                start: 0,
                top: 0,
                bottom: 0,
                width: style.surface.accentWidth,
                child: ColoredBox(color: accentBarColor),
              ),
            if (accentBarColor != null && accentBar == DiaryCardAccentBar.top)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: style.surface.accentWidth,
                child: ColoredBox(color: accentBarColor),
              ),
            // 标题与眉线都隐藏时，选择标记以浮层贴在右上角。
            if (markOverlay)
              PositionedDirectional(
                top: resolved.paddingV + resolved.accentTopInset,
                end: resolved.paddingH,
                child: DiaryCardSelectionMark(
                  selected: selected,
                  isSelectionMode: isSelectionMode,
                  compact: resolved.compact,
                  selectedColor: appearance.accentColor,
                  unselectedColor: appearance.mutedColor,
                  duration: transitionDuration,
                ),
              ),
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: radius > 0
                      ? BorderRadius.circular(radius)
                      : null,
                  onTap: () {
                    if (isSelectionMode) {
                      onToggleSelection(diaryId, false);
                      return;
                    }
                    if (isLockedCapsule && opensLockedCapsulePage) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => LockedDiaryPage(
                            diaryId: diaryId,
                            initialDetail: diary,
                          ),
                        ),
                      );
                      return;
                    }
                    onOpenEditor(
                      diary,
                      coverAnchor?.capture(tag: diaryCoverHeroTag(diaryId)),
                    );
                  },
                  onLongPress: () {
                    // Android 上 InkWell 已经通过 Feedback.forLongPress
                    // 震动；iOS 不会，补一次以确认进入多选。
                    if (Theme.of(context).platform == TargetPlatform.iOS) {
                      unawaited(HapticFeedback.mediumImpact());
                    }
                    onToggleSelection(diaryId, true);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
