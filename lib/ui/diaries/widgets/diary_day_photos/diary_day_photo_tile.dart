import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/core/services/day_photo_library.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../widgets/expressive_image_frame.dart';
import '../../../widgets/expressive_menu/expressive_menu.dart';
import '../../../widgets/expressive_state_blend.dart';
import '../../../widgets/image_viewer_hero.dart';
import '../../controllers/diary_day_photos_controller.dart';
import 'diary_day_photo_badges.dart';

/// 预览页点开某一项：[hero] 为点按时抓取的缩略图画面（只有图片且没开减少
/// 动画时才有），所有权随之转交预览页。
typedef DiaryDayPhotoPreviewCallback = void Function(ImageViewerHero? hero);

/// “这天拍的照片”里的一格：方形缩略图 + 右上角勾选圈。
///
/// 点按分两处（与常见相册选择器一致）：
/// - 点缩略图打开预览页（[onPreview]），在那里看大图、播放视频；
/// - 点右上角勾选圈（触控区 [checkTarget] 见方）勾选 / 取消（[onToggle]）。
///
/// 三种状态：
/// - 未选：原图亮度，空心勾选圈提示可点；
/// - 已选：主色描边 + 实心勾选（经 [ExpressiveStateBlend] 补间，不硬切）；
/// - 已插入：压暗并换成次要色的勾，勾选圈不可点——同一项不会被插两次；
///   缩略图仍可点开预览。
///
/// 视频（[videoDuration] 非 null）右下角多一个“▶ 时长”胶囊。当前封面在左上角
/// 多一个“封面”胶囊（已插入时也不压暗）。长按图片（包括已插入的）弹出“设为
/// 封面 / 取消封面”菜单；视频不能当封面，没有长按菜单。
///
/// 提示条与“全部”面板共用，[timeLabel] 只在面板里传（格子够大放得下）。
class DiaryDayPhotoTile extends StatelessWidget {
  const DiaryDayPhotoTile({
    super.key,
    required this.image,
    required this.selected,
    required this.inserted,
    required this.semanticLabel,
    required this.onToggle,
    required this.onPreview,
    this.heroTag,
    this.videoDuration,
    this.isCover = false,
    this.onSetCover,
    this.onClearCover,
    this.timeLabel,
  });

  final ImageProvider image;
  final bool selected;
  final bool inserted;
  final String semanticLabel;
  final VoidCallback onToggle;
  final DiaryDayPhotoPreviewCallback onPreview;

  /// 缩略图飞入预览页的共享元素标签；null（视频、没有唯一标签）时只淡入。
  final Object? heroTag;

  /// 视频时长；图片为 null。
  final Duration? videoDuration;
  final bool isCover;
  final VoidCallback? onSetCover;
  final VoidCallback? onClearCover;
  final String? timeLabel;

  static const double radius = 12;

  /// 右上角勾选圈的触控区边长：比 20dp 的圈大不少，又必须小于提示条格子
  /// （76dp）的一半——格子正中点下去得是预览，不能落进勾选区。
  static const double checkTarget = 36;

  bool get _isVideo => videoDuration != null;

  /// 长按菜单的唯一一项：按当前状态是设为或取消封面。
  Widget _buildCoverMenuItem(AppLocalizations l10n) => ExpressiveMenuItem(
    leadingIcon: FaIcon(
      isCover ? FontAwesomeIcons.xmark : FontAwesomeIcons.image,
    ),
    onPressed: () => (isCover ? onClearCover : onSetCover)?.call(),
    child: Text(
      isCover ? l10n.diaryDayPhotosClearCover : l10n.diaryDayPhotosSetCover,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(radius);
    // 点按时从画面所在的子树抓共享元素（整格都可点，但画面只是其中一层）。
    final heroAnchor = ImageViewerHeroAnchor();
    // 缩略图放在 builder 之外：勾选补间逐帧重建时不重建图片。
    // 解码完成前露出占位底色，淡入时不透出页面背景。
    final thumbnail = ImageViewerHeroSource(
      tag: heroTag,
      borderRadius: borderRadius,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: ColoredBox(
          color: colorScheme.surfaceContainerHighest,
          child: Builder(
            builder: (BuildContext context) {
              heroAnchor.context = context;
              return Image(
                image: image,
                fit: BoxFit.cover,
                frameBuilder: expressiveImageFrameBuilder,
                errorBuilder: (_, _, _) => Center(
                  child: FaIcon(
                    _isVideo ? FontAwesomeIcons.film : FontAwesomeIcons.image,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    void preview() {
      final tag = heroTag;
      onPreview(tag == null ? null : heroAnchor.capture(tag: tag));
    }

    final canEditCover =
        !_isVideo && (isCover ? onClearCover != null : onSetCover != null);
    final l10n = context.l10n;
    // 菜单锚在整个格子上、从格子起始边展开（与改版前的长按菜单一样贴格子起始边），
    // 下方放不下时翻到上方。
    return ExpressiveMenuAnchor(
      placement: ExpressiveMenuPlacement.start,
      menuChildren: <Widget>[_buildCoverMenuItem(l10n)],
      builder: (BuildContext context, ExpressiveMenuAnchorState menu, _) =>
          Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _buildBody(context, menu, thumbnail, canEditCover, preview),
              Positioned(
                top: 0,
                right: 0,
                width: checkTarget,
                height: checkTarget,
                child: _buildCheckTarget(l10n),
              ),
            ],
          ),
    );
  }

  /// 缩略图本体：点按预览、长按封面菜单，勾选圈与胶囊只画不响应。
  Widget _buildBody(
    BuildContext context,
    ExpressiveMenuAnchorState menu,
    Widget thumbnail,
    bool canEditCover,
    VoidCallback preview,
  ) {
    final l10n = context.l10n;
    return Semantics(
      button: true,
      label: isCover
          ? l10n.diaryDayPhotosCoverLabel(semanticLabel)
          : semanticLabel,
      onTapHint: l10n.diaryDayPhotosPreview,
      onLongPressHint: canEditCover
          ? (isCover
                ? l10n.diaryDayPhotosClearCover
                : l10n.diaryDayPhotosSetCover)
          : null,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: preview,
        onLongPress: canEditCover
            ? () {
                Feedback.forLongPress(context);
                menu.open();
              }
            : null,
        child: ExpressiveStateBlend(
          active: selected,
          child: thumbnail,
          builder: (BuildContext context, double t, Widget? child) =>
              _buildLayers(context, t, child),
        ),
      ),
    );
  }

  Widget _buildLayers(BuildContext context, double t, Widget? child) {
    final colorScheme = Theme.of(context).colorScheme;
    final fast = ExpressiveMotion.duration(context, ExpressiveMotion.fast);
    final duration = videoDuration;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        AnimatedOpacity(
          opacity: inserted ? 0.4 : 1,
          duration: fast,
          curve: ExpressiveMotion.effects,
          child: child,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Color.lerp(
                colorScheme.outlineVariant.withValues(alpha: 0.5),
                colorScheme.primary,
                t,
              )!,
              width: 0.8 + 1.7 * t,
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: DiaryDayPhotoCheckBadge(t: t, inserted: inserted),
        ),
        if (timeLabel case final String label)
          Positioned(
            left: 6,
            bottom: 6,
            child: DiaryDayPhotoInfoPill(label: label),
          ),
        if (duration != null)
          Positioned(
            right: 6,
            bottom: 6,
            child: DiaryDayPhotoInfoPill(
              label: dayPhotoDurationLabel(duration),
              icon: FontAwesomeIcons.play,
            ),
          ),
        Positioned(
          top: 6,
          left: 6,
          child: AnimatedScale(
            scale: isCover ? 1 : 0.6,
            duration: fast,
            curve: ExpressiveMotion.spatial,
            child: AnimatedOpacity(
              opacity: isCover ? 1 : 0,
              duration: fast,
              curve: ExpressiveMotion.effects,
              child: const DiaryDayPhotoCoverPill(),
            ),
          ),
        ),
      ],
    );
  }

  /// 勾选圈的触控区：透明、盖在缩略图右上角；已插入时不可点。
  Widget _buildCheckTarget(AppLocalizations l10n) {
    return Semantics(
      button: !inserted,
      checked: selected || inserted,
      label: inserted ? l10n.diaryDayPhotosInserted : l10n.diaryDayPhotosSelect,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: inserted ? null : onToggle,
      ),
    );
  }
}

/// 读屏文案：拍摄时间（视频另带时长）+（已插入时）状态。
String dayPhotoSemanticLabel(
  AppLocalizations l10n,
  DayPhoto photo,
  DateFormat timeFormat, {
  required bool inserted,
}) {
  final time = timeFormat.format(photo.takenAt);
  if (photo.isVideo) {
    final duration = dayPhotoDurationLabel(photo.duration);
    return inserted
        ? l10n.diaryDayPhotosVideoInsertedLabel(time, duration)
        : l10n.diaryDayPhotosVideoLabel(time, duration);
  }
  return inserted
      ? l10n.diaryDayPhotosInsertedLabel(time)
      : l10n.diaryDayPhotosPhotoLabel(time);
}

/// 共享元素标签：提示条与面板里的同一张照片用同一个标签——面板是弹出层，
/// 从面板打开预览不会飞行，两处不会同时参与。
Object dayPhotoHeroTag(DayPhoto photo) =>
    ImageViewerHeroTag('day_photo', photo.id);

/// 提示条标题：只有照片“这天拍的 N 张照片”、只有视频“这天拍的 N 段视频”，
/// 都有时两个数分开写。
String dayPhotosTitle(
  AppLocalizations l10n,
  DiaryDayPhotosController controller,
) {
  final videos = controller.videoCount;
  final photos = controller.photos.length - videos;
  if (videos == 0) return l10n.diaryDayPhotosTitle(photos);
  if (photos == 0) return l10n.diaryDayPhotosTitleVideos(videos);
  return l10n.diaryDayPhotosTitleMixed(photos, videos);
}

/// 已选数量的文案：全是图片时为“已选 N 张”，有视频时为“已选 N 项”。
String dayPhotosSelectedLabel(
  AppLocalizations l10n,
  DiaryDayPhotosController controller,
) {
  final count = controller.selectedCount;
  return controller.selectionHasVideo
      ? l10n.diaryDayPhotosSelectedItems(count)
      : l10n.diaryDayPhotosSelected(count);
}

/// 插入按钮的文案（带数量）：量词规则同 [dayPhotosSelectedLabel]。
String dayPhotosInsertCountLabel(
  AppLocalizations l10n,
  DiaryDayPhotosController controller,
) {
  final count = controller.selectedCount;
  return controller.selectionHasVideo
      ? l10n.diaryDayPhotosInsertCountItems(count)
      : l10n.diaryDayPhotosInsertCount(count);
}

/// 操作行左侧的次要按钮（提示条与面板共用）：只选了一张图片时是“设为封面 /
/// 取消封面”，多选或选的是视频时是“取消选择”（只选一项时再点一次那项的
/// 勾选圈就能取消，不必占一个按钮；也让 320dp 宽度下这一行放得下）。
class DiaryDayPhotosSecondaryAction extends StatelessWidget {
  const DiaryDayPhotosSecondaryAction({
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
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final single = controller.singleSelection;
    if (single == null || single.isVideo) {
      return TextButton(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.onSurfaceVariant,
        ),
        onPressed: controller.clearSelection,
        child: Text(l10n.diaryDayPhotosClear),
      );
    }
    final isCover = controller.isCover(single);
    return TextButton(
      onPressed: isCover ? onClearCover : () => onSetCover(single),
      child: Text(
        isCover ? l10n.diaryDayPhotosClearCover : l10n.diaryDayPhotosSetCover,
      ),
    );
  }
}
