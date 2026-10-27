import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/core/services/day_photo_library.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/expressive_motion.dart';
import '../../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../../../widgets/delayed_loading_indicator.dart';
import '../../controllers/diary_day_photos_controller.dart';
import 'diary_day_photo_tile.dart';
import 'diary_day_photos_limited_hint.dart';
import 'diary_day_photos_sheet_states.dart';

/// “这天拍的照片”全部网格：比提示条的缩略图大，带拍摄时间，方便认出要哪张。
///
/// 两个入口：提示条的“全部”（已有照片）与编辑页顶栏菜单“这天的照片”（打开
/// 前调用 [DiaryDayPhotosController.browse]，可能还在读取、未授权或这天没有
/// 照片）。主体按 [DiaryDayPhotosController.sheetPhase] 在读取中 / 未授权 /
/// 没有照片 / 网格之间 `fast` 交叉淡入，底栏只在有照片时出现。
///
/// 与提示条共用同一个 [DiaryDayPhotosController]，在这里勾选的照片关掉面板后
/// 仍保持勾选。点“插入”返回 true，由打开者执行插入（面板只负责挑选）；
/// 设封面不关面板，立即回调 [onSetCover] / [onClearCover]，结果以角标呈现。
Future<bool?> showDiaryDayPhotosSheet(
  BuildContext context, {
  required DiaryDayPhotosController controller,
  required ValueChanged<DayPhoto> onSetCover,
  required VoidCallback onClearCover,
}) {
  return showAppModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    // 底部面板默认滑入不读取系统“减少动态效果”；该模式下直接出现。
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) => DiaryDayPhotosSheet(
      controller: controller,
      onSetCover: onSetCover,
      onClearCover: onClearCover,
    ),
  );
}

class DiaryDayPhotosSheet extends StatelessWidget {
  const DiaryDayPhotosSheet({
    super.key,
    required this.controller,
    required this.onSetCover,
    required this.onClearCover,
  });

  final DiaryDayPhotosController controller;
  final ValueChanged<DayPhoto> onSetCover;
  final VoidCallback onClearCover;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 1,
      builder: (BuildContext context, ScrollController scrollController) {
        return ListenableBuilder(
          listenable: controller,
          builder: (BuildContext context, Widget? child) {
            final phase = controller.sheetPhase;
            final day = controller.day;
            final selectedCount = controller.selectedCount;
            final ready = phase == DiaryDayPhotosSheetPhase.ready;
            return Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    0,
                    AppSpacing.xl,
                    AppSpacing.m,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          day == null
                              ? l10n.diaryDayPhotosAccessTitle
                              : l10n.diaryDayPhotosSheetTitle(
                                  l10n.formatEyebrowDate(day),
                                ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      // 张数只在有照片时有意义：读取中写 0 会被误读成“没有”。
                      if (ready)
                        Text(
                          '${controller.photos.length}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: ExpressiveMotion.duration(
                      context,
                      ExpressiveMotion.fast,
                    ),
                    switchInCurve: ExpressiveMotion.effects,
                    switchOutCurve: ExpressiveMotion.exit,
                    layoutBuilder: (Widget? current, List<Widget> previous) =>
                        Stack(
                          fit: StackFit.expand,
                          children: <Widget>[...previous, ?current],
                        ),
                    child: switch (phase) {
                      DiaryDayPhotosSheetPhase.loading =>
                        const DelayedLoadingIndicator(
                          key: ValueKey<DiaryDayPhotosSheetPhase>(
                            DiaryDayPhotosSheetPhase.loading,
                          ),
                        ),
                      DiaryDayPhotosSheetPhase.needsAccess =>
                        DiaryDayPhotosSheetAccess(
                          key: const ValueKey<DiaryDayPhotosSheetPhase>(
                            DiaryDayPhotosSheetPhase.needsAccess,
                          ),
                          controller: controller,
                        ),
                      DiaryDayPhotosSheetPhase.empty =>
                        DiaryDayPhotosSheetEmpty(
                          key: const ValueKey<DiaryDayPhotosSheetPhase>(
                            DiaryDayPhotosSheetPhase.empty,
                          ),
                          controller: controller,
                        ),
                      // 只有网格挂拖动面板的 scrollController：其余状态内容
                      // 很少，不需要滚动；切换途中也不会有两个滚动视图同时
                      // 挂在这个控制器上（它只支持一个）。
                      DiaryDayPhotosSheetPhase.ready => _SheetGrid(
                        key: const ValueKey<DiaryDayPhotosSheetPhase>(
                          DiaryDayPhotosSheetPhase.ready,
                        ),
                        controller: controller,
                        scrollController: scrollController,
                        onSetCover: onSetCover,
                        onClearCover: onClearCover,
                      ),
                    },
                  ),
                ),
                if (ready)
                  _SheetActionBar(
                    selectedCount: selectedCount,
                    secondary: selectedCount == 0
                        ? null
                        : DiaryDayPhotosSecondaryAction(
                            controller: controller,
                            onSetCover: onSetCover,
                            onClearCover: onClearCover,
                          ),
                    onInsert: () => Navigator.of(context).pop(true),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// 有照片：部分授权时先列出说明与“选择更多”，下面是大图网格。
class _SheetGrid extends StatelessWidget {
  const _SheetGrid({
    super.key,
    required this.controller,
    required this.scrollController,
    required this.onSetCover,
    required this.onClearCover,
  });

  final DiaryDayPhotosController controller;
  final ScrollController scrollController;
  final ValueChanged<DayPhoto> onSetCover;
  final VoidCallback onClearCover;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final timeFormat = DateFormat.Hm(l10n.localeName);
    final photos = controller.photos;
    return Column(
      children: <Widget>[
        if (controller.isLimited)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.m,
              AppSpacing.s,
            ),
            child: DiaryDayPhotosLimitedHint(controller: controller),
          ),
        Expanded(
          child: GridView.builder(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              0,
              AppSpacing.l,
              AppSpacing.l,
            ),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 128,
              mainAxisSpacing: AppSpacing.s,
              crossAxisSpacing: AppSpacing.s,
            ),
            itemCount: photos.length,
            itemBuilder: (BuildContext context, int index) {
              final photo = photos[index];
              final inserted = controller.isInserted(photo);
              return DiaryDayPhotoTile(
                image: controller.thumbnailOf(photo),
                selected: controller.isSelected(photo),
                inserted: inserted,
                isCover: controller.isCover(photo),
                onSetCover: () => onSetCover(photo),
                onClearCover: onClearCover,
                timeLabel: timeFormat.format(photo.takenAt),
                semanticLabel: dayPhotoSemanticLabel(
                  l10n,
                  photo,
                  timeFormat,
                  inserted: inserted,
                ),
                onTap: () => controller.toggle(photo),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 面板底栏：已选数量 + 次要动作（取消选择 / 设为封面）+ 插入；未选时
/// 插入置灰。
class _SheetActionBar extends StatelessWidget {
  const _SheetActionBar({
    required this.selectedCount,
    required this.secondary,
    required this.onInsert,
  });

  final int selectedCount;
  final Widget? secondary;
  final VoidCallback onInsert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final hasSelection = selectedCount > 0;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            width: 0.8,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.s,
            AppSpacing.l,
            AppSpacing.s,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.diaryDayPhotosSelected(selectedCount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ?secondary,
              const SizedBox(width: AppSpacing.xs),
              FilledButton(
                onPressed: hasSelection ? onInsert : null,
                child: Text(
                  hasSelection
                      ? l10n.diaryDayPhotosInsertCount(selectedCount)
                      : l10n.diaryDayPhotosInsert,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
