import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

// “这天的照片”格子与预览页共用的小角标：勾选圈、封面胶囊、拍摄时间与
// 视频时长胶囊。只负责画，不处理点按。

/// 勾选圈：[t] 为选中程度（0 未选、1 已选，由 ExpressiveStateBlend 补间），
/// 已插入时换成次要色的实心勾。
///
/// 格子里叠在照片上，未选时为表面色半透明底、表面色描边；预览页顶栏里
/// 叠在表面色上，表面色描边看不见，经 [idleBorder] 换成可见的描边色。
class DiaryDayPhotoCheckBadge extends StatelessWidget {
  const DiaryDayPhotoCheckBadge({
    super.key,
    required this.t,
    required this.inserted,
    this.size = 20,
    this.idleBorder,
  });

  final double t;
  final bool inserted;
  final double size;
  final Color? idleBorder;

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
        : Color.lerp(
            idleBorder ?? colorScheme.surface,
            colorScheme.primary,
            t,
          )!;
    final iconOpacity = inserted ? 1.0 : t;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: border, width: size * 0.07),
      ),
      alignment: Alignment.center,
      child: Opacity(
        opacity: iconOpacity,
        child: FaIcon(
          FontAwesomeIcons.check,
          size: size / 2,
          color: inserted ? colorScheme.onSecondary : colorScheme.onPrimary,
        ),
      ),
    );
  }
}

/// “封面”胶囊：主色容器底，与勾选圈、时间胶囊区分开。
class DiaryDayPhotoCoverPill extends StatelessWidget {
  const DiaryDayPhotoCoverPill({super.key});

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

/// 照片上的小胶囊（拍摄时间、视频时长）：表面色半透明底，明暗主题下都与
/// 照片拉开对比。[icon] 给出时放在文字前（视频的播放三角）。
class DiaryDayPhotoInfoPill extends StatelessWidget {
  const DiaryDayPhotoInfoPill({super.key, required this.label, this.icon});

  final String label;
  final FaIconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final icon = this.icon;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              FaIcon(icon, size: 7, color: colorScheme.onSurface),
              const SizedBox(width: 3),
            ],
            Text(
              label,
              maxLines: 1,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurface,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 视频时长的显示：不足一小时为 `m:ss`，否则为 `h:mm:ss`（与相册一致）。
String dayPhotoDurationLabel(Duration duration) {
  final seconds = duration.inSeconds;
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final rest = (seconds % 60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$rest';
  }
  return '$minutes:$rest';
}
