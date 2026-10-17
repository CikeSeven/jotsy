import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/core/services/day_photo_library.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../widgets/expressive_image_frame.dart';
import '../../../widgets/expressive_state_blend.dart';
import '../../controllers/diary_day_photos_controller.dart';

/// “这天拍的照片”里的一格：方形缩略图 + 右上角勾选圈。
///
/// 三种状态：
/// - 未选：原图亮度，空心勾选圈提示可点；
/// - 已选：主色描边 + 实心勾选（经 [ExpressiveStateBlend] 补间，不硬切）；
/// - 已插入：压暗并换成次要色的勾，点按无效——同一张不会被插两次。
///
/// 当前封面在左上角多一个“封面”胶囊（已插入时也不压暗）。长按任意一格
/// （包括已插入的）弹出“设为封面 / 取消封面”菜单。
///
/// 提示条与“全部”面板共用，[timeLabel] 只在面板里传（格子够大放得下）。
class DiaryDayPhotoTile extends StatelessWidget {
  const DiaryDayPhotoTile({
    super.key,
    required this.image,
    required this.selected,
    required this.inserted,
    required this.semanticLabel,
    required this.onTap,
    this.isCover = false,
    this.onSetCover,
    this.onClearCover,
    this.timeLabel,
  });

  final ImageProvider image;
  final bool selected;
  final bool inserted;
  final String semanticLabel;
  final VoidCallback onTap;
  final bool isCover;
  final VoidCallback? onSetCover;
  final VoidCallback? onClearCover;
  final String? timeLabel;

  /// 长按菜单：锚在格子上，只有一项（按当前状态是设为或取消封面）。
  Future<void> _showCoverMenu(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    Feedback.forLongPress(context);
    final rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    final l10n = context.l10n;
    final confirmed = await showMenu<bool>(
      context: context,
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      items: <PopupMenuEntry<bool>>[
        PopupMenuItem<bool>(
          value: true,
          child: Row(
            children: <Widget>[
              FaIcon(
                isCover ? FontAwesomeIcons.xmark : FontAwesomeIcons.image,
                size: 14,
              ),
              const SizedBox(width: 12),
              Text(
                isCover
                    ? l10n.diaryDayPhotosClearCover
                    : l10n.diaryDayPhotosSetCover,
              ),
            ],
          ),
        ),
      ],
    );
    if (confirmed != true || !context.mounted) return;
    (isCover ? onClearCover : onSetCover)?.call();
  }

  static const double radius = 12;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(radius);
    // 缩略图放在 builder 之外：勾选补间逐帧重建时不重建图片。
    // 解码完成前露出占位底色，淡入时不透出页面背景。
    final thumbnail = ClipRRect(
      borderRadius: borderRadius,
      child: ColoredBox(
        color: colorScheme.surfaceContainerHighest,
        child: Image(
          image: image,
          fit: BoxFit.cover,
          frameBuilder: expressiveImageFrameBuilder,
          errorBuilder: (_, _, _) => Center(
            child: FaIcon(
              FontAwesomeIcons.image,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
    final canEditCover = isCover ? onClearCover != null : onSetCover != null;
    final l10n = context.l10n;
    return Semantics(
      button: !inserted,
      checked: selected || inserted,
      label: isCover
          ? l10n.diaryDayPhotosCoverLabel(semanticLabel)
          : semanticLabel,
      onLongPressHint: canEditCover
          ? (isCover
                ? l10n.diaryDayPhotosClearCover
                : l10n.diaryDayPhotosSetCover)
          : null,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: inserted ? null : onTap,
        onLongPress: canEditCover ? () => _showCoverMenu(context) : null,
        child: ExpressiveStateBlend(
          active: selected,
          child: thumbnail,
          builder: (BuildContext context, double t, Widget? child) {
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                AnimatedOpacity(
                  opacity: inserted ? 0.4 : 1,
                  duration: ExpressiveMotion.duration(
                    context,
                    ExpressiveMotion.fast,
                  ),
                  curve: ExpressiveMotion.effects,
                  child: child,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
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
                  child: _CheckBadge(t: t, inserted: inserted),
                ),
                if (timeLabel case final String label)
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: _TimePill(label: label),
                  ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: AnimatedScale(
                    scale: isCover ? 1 : 0.6,
                    duration: ExpressiveMotion.duration(
                      context,
                      ExpressiveMotion.fast,
                    ),
                    curve: ExpressiveMotion.spatial,
                    child: AnimatedOpacity(
                      opacity: isCover ? 1 : 0,
                      duration: ExpressiveMotion.duration(
                        context,
                        ExpressiveMotion.fast,
                      ),
                      curve: ExpressiveMotion.effects,
                      child: const _CoverPill(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CheckBadge extends StatelessWidget {
  const _CheckBadge({required this.t, required this.inserted});

  final double t;
  final bool inserted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fill = inserted
        ? colorScheme.secondary
        : Color.lerp(
            colorScheme.surface.withValues(alpha: 0.7),
            colorScheme.primary,
            t,
          )!;
    final border = inserted
        ? colorScheme.secondary
        : Color.lerp(colorScheme.surface, colorScheme.primary, t)!;
    final iconOpacity = inserted ? 1.0 : t;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: border, width: 1.4),
      ),
      alignment: Alignment.center,
      child: Opacity(
        opacity: iconOpacity,
        child: FaIcon(
          FontAwesomeIcons.check,
          size: 10,
          color: inserted ? colorScheme.onSecondary : colorScheme.onPrimary,
        ),
      ),
    );
  }
}

/// “封面”胶囊：主色容器底，与勾选圈、时间胶囊区分开。
class _CoverPill extends StatelessWidget {
  const _CoverPill();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          context.l10n.diaryDayPhotosCoverBadge,
          maxLines: 1,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// 拍摄时间小胶囊：表面色半透明底，明暗主题下都与照片拉开对比。
class _TimePill extends StatelessWidget {
  const _TimePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          maxLines: 1,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurface,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// 读屏文案：拍摄时间 +（已插入时）状态。
String dayPhotoSemanticLabel(
  AppLocalizations l10n,
  DayPhoto photo,
  DateFormat timeFormat, {
  required bool inserted,
}) {
  final time = timeFormat.format(photo.takenAt);
  return inserted
      ? l10n.diaryDayPhotosInsertedLabel(time)
      : l10n.diaryDayPhotosPhotoLabel(time);
}

/// 操作行左侧的次要按钮（提示条与面板共用）：只选了一张时是“设为封面 /
/// 取消封面”，多选时是“取消选择”（只选一张时再点一次那张就能取消，
/// 不必占一个按钮；也让 320dp 宽度下这一行放得下）。
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
    if (single == null) {
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
