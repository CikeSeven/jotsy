import 'dart:ui' as ui show Image;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/image_viewer_hero.dart';
import '../../models/time_capsule.dart';
import '../../providers/diary_typography_provider.dart';
import '../../viewmodels/diary_preview_view_data.dart';
import 'diary_preview_body.dart';
import 'diary_preview_header.dart';
import 'diary_preview_meta.dart';
import 'diary_preview_top_bar.dart';

/// 打开看图页：本篇的全部图片来源、点按的那一张与抓取的共享元素。
typedef DiaryPreviewImageOpener =
    void Function(
      List<String> sources,
      String initialSource,
      ImageViewerHero? hero,
    );

/// 预览页的整页内容：顶栏、头图、标题、信息栏与正文组成的滚动视图。
///
/// 输入：已解封的日记、它的派生数据与只读 Quill 控制器，以及顶栏动作与看图
/// 回调；不读写数据库，也不持有状态，设置页的实时预览可以直接复用。
class DiaryPreviewContent extends ConsumerWidget {
  const DiaryPreviewContent({
    super.key,
    required this.detail,
    required this.viewData,
    required this.controller,
    required this.scrollController,
    required this.onOpenImage,
    required this.onOpenTypography,
    required this.onEdit,
    required this.onMore,
    this.coverPlaceholder,
    this.staticCover = false,
  });

  final DiaryWithTags detail;
  final DiaryPreviewViewData viewData;

  /// 正文控制器；尚未绑定时为 null（正文区不占位）。
  final quill.QuillController? controller;
  final ScrollController scrollController;
  final DiaryPreviewImageOpener onOpenImage;
  final VoidCallback onOpenTypography;
  final VoidCallback onEdit;
  final VoidCallback onMore;

  /// 列表封面抓取的画面：头图共享元素的落点与占位。
  final ui.Image? coverPlaceholder;

  /// 分享长图期间用静态头图（见 [DiaryPreviewCover]）。
  final bool staticCover;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diary = detail.diary;
    final appearance = ref.watch(diaryTextAppearanceProvider);
    final capsuleState = TimeCapsuleState.fromFields(
      lockedAt: diary.capsuleLockedAt,
      unlockAt: diary.capsuleUnlockAt,
      now: DateTime.now(),
    );
    final title = diary.title.trim().isEmpty
        ? context.l10n.autoT0033
        : diary.title.trim();
    final images = viewData.images;
    final coverSource = viewData.coverSource;
    final controller = this.controller;

    return CustomScrollView(
      controller: scrollController,
      slivers: <Widget>[
        DiaryPreviewTopBar(
          onOpenTypography: onOpenTypography,
          onEdit: onEdit,
          onMore: onMore,
        ),
        if (coverSource != null)
          DiaryPreviewCover(
            diaryId: diary.diaryId,
            source: coverSource,
            staticCover: staticCover,
            placeholder: coverPlaceholder,
            onTap: (hero) => onOpenImage(images, coverSource, hero),
          ),
        DiaryPreviewTitle(title: title, appearance: appearance),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: DiaryPreviewMeta(detail: detail, viewData: viewData),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DiaryPreviewCapsuleInsight(
                  capsuleState: capsuleState,
                  moodEmoji: viewData.moodEmoji,
                ),
                if (capsuleState.isCapsule) const SizedBox(height: 14),
                if (controller == null)
                  const SizedBox.shrink()
                else
                  DiaryPreviewBody(
                    diary: diary,
                    controller: controller,
                    appearance: appearance,
                    onOpenImage: (source, hero) =>
                        onOpenImage(images, source, hero),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
