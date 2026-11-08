import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../diaries/widgets/diary_day_photos/diary_day_photo_badges.dart';
import '../../widgets/expressive_state_blend.dart';
import '../viewmodels/storage_media_view.dart';
import 'storage_media_thumb.dart';

/// 媒体页网格里的一格：方形缩略图，左下角大小、右下角视频时长，可压缩时
/// 左上角一个小标记；多选时右上角出现勾选圈，选中描边加粗为主色。外观
/// 沿用“这天的照片”的格子（勾选圈与信息胶囊同一组件）。
class StorageMediaGridTile extends StatelessWidget {
  const StorageMediaGridTile({
    super.key,
    required this.item,
    required this.extent,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  static const double radius = 12;

  final StorageMediaItemView item;
  final double extent;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final video = item.video;
    final thumbnail = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: StorageMediaThumb(
        entry: item.entry,
        masked: item.masked,
        extent: extent,
      ),
    );
    return Semantics(
      selected: selectionMode ? selected : null,
      child: ExpressiveStateBlend(
        active: selected,
        child: thumbnail,
        builder: (BuildContext context, double t, Widget? child) {
          final scheme = Theme.of(context).colorScheme;
          final fast = ExpressiveMotion.duration(
            context,
            ExpressiveMotion.fast,
          );
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              child!,
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: Color.lerp(
                      scheme.outlineVariant.withValues(alpha: 0.5),
                      scheme.primary,
                      t,
                    )!,
                    width: 0.8 + 1.7 * t,
                  ),
                ),
              ),
              Positioned(
                left: 6,
                bottom: 6,
                child: DiaryDayPhotoInfoPill(
                  label: l10n.formatByteSize(item.entry.bytes),
                ),
              ),
              if (video != null && video.durationMs > 0)
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: DiaryDayPhotoInfoPill(
                    label: dayPhotoDurationLabel(video.duration),
                    icon: FontAwesomeIcons.play,
                  ),
                ),
              if (item.compressible)
                Positioned(
                  left: 6,
                  top: 6,
                  child: DiaryDayPhotoInfoPill(
                    label: l10n.storageMgmtBadgeCompressShort,
                    icon: FontAwesomeIcons.compress,
                  ),
                ),
              Positioned(
                top: 6,
                right: 6,
                child: AnimatedOpacity(
                  opacity: selectionMode ? 1 : 0,
                  duration: fast,
                  curve: ExpressiveMotion.effects,
                  child: DiaryDayPhotoCheckBadge(t: t, inserted: false),
                ),
              ),
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(radius),
                  onTap: onTap,
                  onLongPress: onLongPress,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
