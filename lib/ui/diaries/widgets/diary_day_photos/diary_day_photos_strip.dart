import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/core/services/day_photo_library.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/expressive_motion.dart';
import '../../../../app/theme/expressive_surfaces.dart';
import '../../../app_surface/widgets/app_card_surface.dart';
import '../../../app_surface/widgets/app_glass_field.dart';
import '../../../app_surface/widgets/app_glass_scope.dart';
import '../../../app_surface/widgets/app_glass_surface.dart';
import '../../../widgets/glass/glass_reveal.dart';
import '../../controllers/diary_day_photos_controller.dart';
import 'diary_day_photo_tile.dart';
import 'diary_day_photos_limited_hint.dart';
import 'diary_day_photos_sheet.dart';
import '../../../widgets/desktop_horizontal_scroll.dart';

/// 补写日记时放在标题与正文之间的“这天拍的照片”提示条。
///
/// - 未授权：说明 + “允许访问”（拒绝过后改为“去设置”）；
/// - 有照片：横向缩略图，点按勾选；选中后底部出现“插入”；“全部”打开大图
///   网格面板（与提示条共用同一份勾选）；
/// - 其余情况（读取中、这天没照片、已关掉、不自动显示）整块收起，不占位置。
///
/// 出现与收起经 [AnimatedSize] 展开/折叠，正文平滑下移而不是一帧跳动。
/// 插入与设封面只回调 [onInsert] / [onSetCover] / [onClearCover]，复制
/// 文件、写正文与草稿由编辑页负责。
class DiaryDayPhotosStrip extends StatelessWidget {
  const DiaryDayPhotosStrip({
    super.key,
    required this.controller,
    required this.busy,
    required this.onInsert,
    required this.onSetCover,
    required this.onClearCover,
  });

  final DiaryDayPhotosController controller;

  /// 正在导入媒体或保存：“插入”不可点。
  final bool busy;
  final VoidCallback onInsert;
  final ValueChanged<DayPhoto> onSetCover;
  final VoidCallback onClearCover;

  static const double thumbnailSize = 76;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final phase = controller.phase;
        return AnimatedSize(
          duration: ExpressiveMotion.durationNonZero(
            context,
            ExpressiveMotion.medium,
          ),
          curve: ExpressiveMotion.effects,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
            switchInCurve: ExpressiveMotion.effects,
            switchOutCurve: ExpressiveMotion.exit,
            // 卡片为玻璃时提示条是玻璃表面，不能放进 FadeTransition（模糊会
            // 采不到页面），改经 GlassReveal 由玻璃自己淡入。
            transitionBuilder: AppCardSurface.isGlass(context)
                ? (Widget child, Animation<double> animation) =>
                      GlassRevealTransition(progress: animation, child: child)
                : AnimatedSwitcher.defaultTransitionBuilder,
            layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
              alignment: Alignment.topCenter,
              children: <Widget>[...previous, ?current],
            ),
            child: switch (phase) {
              DiaryDayPhotosPhase.hidden => const SizedBox(
                key: ValueKey<String>('hidden'),
                width: double.infinity,
              ),
              DiaryDayPhotosPhase.needsAccess => _AccessCard(
                key: const ValueKey<String>('access'),
                controller: controller,
              ),
              DiaryDayPhotosPhase.ready => _PhotosCard(
                key: const ValueKey<String>('photos'),
                controller: controller,
                busy: busy,
                onInsert: onInsert,
                onSetCover: onSetCover,
                onClearCover: onClearCover,
              ),
            },
          ),
        );
      },
    );
  }
}

/// 提示条外壳：卡片表面 + 0.8dp 微边框，与编辑页画布拉开一层。
class _StripSurface extends StatelessWidget {
  const _StripSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(AppRadii.input));
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.m,
      ),
      child: child,
    );
    // “卡片”为玻璃时为内容玻璃（切换的淡入见 transitionBuilder）。
    if (AppCardSurface.isGlass(context)) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.m),
        child: AppGlassSurface(
          component: AppGlassComponent.cards,
          borderRadius: radius,
          child: content,
        ),
      );
    }
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.m),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ExpressiveSurfaces.cardColor(colorScheme),
          borderRadius: radius,
          border: Border.fromBorderSide(
            ExpressiveSurfaces.cardBorderSide(colorScheme),
          ),
        ),
        child: content,
      ),
    );
  }
}

/// 表头：图标 + 标题 + 尾部动作 + 关闭。
class _StripHeader extends StatelessWidget {
  const _StripHeader({
    required this.title,
    required this.onDismiss,
    this.action,
  });

  final String title;
  final VoidCallback onDismiss;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    return Row(
      children: <Widget>[
        FaIcon(FontAwesomeIcons.images, size: 14, color: colorScheme.primary),
        const SizedBox(width: AppSpacing.s),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ?action,
        IconButton(
          tooltip: l10n.diaryDayPhotosDismiss,
          visualDensity: VisualDensity.compact,
          onPressed: onDismiss,
          icon: FaIcon(
            FontAwesomeIcons.xmark,
            size: 14,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _AccessCard extends StatelessWidget {
  const _AccessCard({super.key, required this.controller});

  final DiaryDayPhotosController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final openSettings = controller.shouldOpenSettings;
    return _StripSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _StripHeader(
            title: l10n.diaryDayPhotosAccessTitle,
            onDismiss: controller.dismiss,
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s),
            child: Text(
              openSettings
                  ? l10n.diaryDayPhotosDeniedBody
                  : l10n.diaryDayPhotosAccessBody,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.s),
              // 样式取提示条外壳之内的 context：外壳是玻璃时才认得出 OnGlass。
              child: Builder(
                builder: (BuildContext context) => FilledButton.tonal(
                  onPressed: controller.requestAccess,
                  style: AppGlassField.tonalButtonStyle(context),
                  child: Text(
                    openSettings
                        ? l10n.diaryDayPhotosOpenSettings
                        : l10n.diaryDayPhotosAllowAccess,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotosCard extends StatelessWidget {
  const _PhotosCard({
    super.key,
    required this.controller,
    required this.busy,
    required this.onInsert,
    required this.onSetCover,
    required this.onClearCover,
  });

  final DiaryDayPhotosController controller;
  final bool busy;
  final VoidCallback onInsert;
  final ValueChanged<DayPhoto> onSetCover;
  final VoidCallback onClearCover;

  Future<void> _showAll(BuildContext context) async {
    final insert = await showDiaryDayPhotosSheet(
      context,
      controller: controller,
      onSetCover: onSetCover,
      onClearCover: onClearCover,
    );
    if (insert == true) onInsert();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final photos = controller.photos;
    final selectedCount = controller.selectedCount;
    final timeFormat = DateFormat.Hm(l10n.localeName);
    return _StripSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _StripHeader(
            title: l10n.diaryDayPhotosTitle(photos.length),
            onDismiss: controller.dismiss,
            action: TextButton(
              onPressed: () => _showAll(context),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              child: Text(l10n.diaryDayPhotosShowAll),
            ),
          ),
          SizedBox(
            height: DiaryDayPhotosStrip.thumbnailSize,
            child: DesktopHorizontalScroll(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: AppSpacing.s),
                itemCount: photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s),
                itemBuilder: (BuildContext context, int index) {
                  final photo = photos[index];
                  return SizedBox.square(
                    dimension: DiaryDayPhotosStrip.thumbnailSize,
                    child: DiaryDayPhotoTile(
                      image: controller.thumbnailOf(photo),
                      selected: controller.isSelected(photo),
                      inserted: controller.isInserted(photo),
                      isCover: controller.isCover(photo),
                      onSetCover: () => onSetCover(photo),
                      onClearCover: onClearCover,
                      semanticLabel: dayPhotoSemanticLabel(
                        l10n,
                        photo,
                        timeFormat,
                        inserted: controller.isInserted(photo),
                      ),
                      onTap: () => controller.toggle(photo),
                    ),
                  );
                },
              ),
            ),
          ),
          if (controller.isLimited)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: DiaryDayPhotosLimitedHint(controller: controller),
            ),
          // 有勾选时展开操作行；勾选清空后收起，缩略图不跳。
          AnimatedSize(
            duration: ExpressiveMotion.durationNonZero(
              context,
              ExpressiveMotion.fast,
            ),
            curve: ExpressiveMotion.effects,
            alignment: Alignment.topCenter,
            child: selectedCount == 0
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.s,
                      right: AppSpacing.s,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            l10n.diaryDayPhotosSelected(selectedCount),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        DiaryDayPhotosSecondaryAction(
                          controller: controller,
                          onSetCover: onSetCover,
                          onClearCover: onClearCover,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Builder(
                          builder: (BuildContext context) => FilledButton.tonal(
                            onPressed: busy ? null : onInsert,
                            style: AppGlassField.tonalButtonStyle(context),
                            child: Text(l10n.diaryDayPhotosInsert),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
