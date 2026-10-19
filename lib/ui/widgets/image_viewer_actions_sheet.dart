import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../app/theme/app_radii.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/expressive_motion.dart';
import '../diaries/models/diary_share_target.dart';
import '../diaries/widgets/diary_share_widgets.dart';
import '../diaries/widgets/diary_sheet_controls.dart';

/// 看图页长按面板选中的动作，关闭面板后由看图页执行。
sealed class ImageViewerAction {
  const ImageViewerAction();
}

/// 分享到 [target]；[DiaryShareTarget.system] 即“更多应用”（系统分享面板）。
final class ImageViewerShareAction extends ImageViewerAction {
  const ImageViewerShareAction(this.target);

  final DiaryShareTarget target;
}

final class ImageViewerSaveAction extends ImageViewerAction {
  const ImageViewerSaveAction();
}

final class ImageViewerOpenDiaryAction extends ImageViewerAction {
  const ImageViewerOpenDiaryAction();
}

/// 打开看图页的长按面板，返回用户选中的动作；关闭面板返回 null。
///
/// 自上而下：“分享到”一组目标按钮（已安装的应用 + 末尾始终可用的“更多
/// 应用”，与日记分享面板同一套按钮与安装检测）→ 动作分组（保存到相册；
/// [canOpenDiary] 时再加“打开日记”）。面板只负责挑选，保存与分享由看图页在
/// 动作等待遮罩下执行，结果提示落在看图页上。
///
/// [installedTargets] 为看图页打开时就开始的安装检测；[initialTargets] 为
/// 检测已完成时的结果（通常长按前就已完成），首帧即可排好全部目标，不会先
/// 只有“更多应用”再跳出其他应用。
Future<ImageViewerAction?> showImageViewerActionsSheet(
  BuildContext context, {
  required Future<Set<DiaryShareTarget>> installedTargets,
  Set<DiaryShareTarget>? initialTargets,
  required bool canOpenDiary,
}) {
  return showModalBottomSheet<ImageViewerAction>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    // 底部面板默认滑入不读取系统“减少动态效果”；该模式下直接出现。
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) => ImageViewerActionsSheet(
      installedTargets: installedTargets,
      initialTargets: initialTargets,
      canOpenDiary: canOpenDiary,
    ),
  );
}

class ImageViewerActionsSheet extends StatelessWidget {
  const ImageViewerActionsSheet({
    super.key,
    required this.installedTargets,
    this.initialTargets,
    required this.canOpenDiary,
  });

  final Future<Set<DiaryShareTarget>> installedTargets;
  final Set<DiaryShareTarget>? initialTargets;
  final bool canOpenDiary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    void choose(ImageViewerAction action) => Navigator.of(context).pop(action);
    return SafeArea(
      top: false,
      // 横屏或矮屏放不下两行目标与动作分组时面板内滚动。
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            DiarySheetSectionHeader(
              icon: FontAwesomeIcons.shareNodes,
              label: l10n.diaryShareTargetsSection,
            ),
            const SizedBox(height: AppSpacing.m),
            FutureBuilder<Set<DiaryShareTarget>>(
              future: installedTargets,
              initialData: initialTargets,
              builder: (context, snapshot) {
                final installed = snapshot.data ?? const <DiaryShareTarget>{};
                // 检测完成前只有“更多应用”；其他应用出现时面板平滑长高。
                return AnimatedSize(
                  duration: ExpressiveMotion.durationNonZero(
                    context,
                    ExpressiveMotion.medium,
                  ),
                  curve: ExpressiveMotion.effects,
                  alignment: Alignment.topCenter,
                  child: _ShareTargetGrid(
                    targets: <DiaryShareTarget>[
                      ...DiaryShareTarget.appTargets.where(installed.contains),
                      DiaryShareTarget.system,
                    ],
                    onSelected: (DiaryShareTarget target) =>
                        choose(ImageViewerShareAction(target)),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            _ActionGroup(
              children: <Widget>[
                _ActionRow(
                  icon: FontAwesomeIcons.download,
                  label: l10n.imageViewerSaveToGallery,
                  onTap: () => choose(const ImageViewerSaveAction()),
                ),
                if (canOpenDiary)
                  _ActionRow(
                    icon: FontAwesomeIcons.bookOpen,
                    label: l10n.imageViewerOpenDiary,
                    navigates: true,
                    onTap: () => choose(const ImageViewerOpenDiaryAction()),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 分享目标按钮的网格：按可用宽度均分列（每格至少 [_minCellWidth]），按钮
/// 在格内居中，换行后上下两行对齐成列；目标少时靠左排开，不会被拉散。
class _ShareTargetGrid extends StatelessWidget {
  const _ShareTargetGrid({required this.targets, required this.onSelected});

  /// 略宽于按钮本身（68），名称两侧留出呼吸感；常见手机宽度下一行 4～5 个。
  static const double _minCellWidth = 72;

  final List<DiaryShareTarget> targets;
  final ValueChanged<DiaryShareTarget> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final columns = math.max(
          1,
          (constraints.maxWidth / _minCellWidth).floor(),
        );
        final cellWidth = constraints.maxWidth / columns;
        return Wrap(
          runSpacing: AppSpacing.m,
          children: <Widget>[
            for (final target in targets)
              SizedBox(
                width: cellWidth,
                child: Center(
                  child: DiaryShareTargetButton.forTarget(
                    l10n,
                    target,
                    onTap: () => onSelected(target),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 动作分组：输入框填充色的大圆角块，与面板表面拉开层次（面板与卡片同为
/// 纯净表面，卡片描边在面板上几乎看不见）；行间细分隔线与设置分组一致。
class _ActionGroup extends StatelessWidget {
  const _ActionGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = colorScheme.brightness == Brightness.light;
    return Material(
      color: isLight
          ? colorScheme.surfaceContainerLow
          : colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppRadii.card),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 0.6,
                // 从文字起点开始，图标列不被切断。
                indent: 56,
                endIndent: AppSpacing.l,
                color: colorScheme.outlineVariant.withValues(
                  alpha: isLight ? 0.35 : 0.18,
                ),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// 动作行：`primary` 色图标 + 名称；会离开看图页的动作（打开日记）行尾带
/// `angleRight`，与其他“进入下一页”的行一致。
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.navigates = false,
  });

  final FaIconData icon;
  final String label;
  final VoidCallback onTap;
  final bool navigates;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      minTileHeight: 56,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      // 主题给列表行 16 圆角；分组里的行按压高亮要铺满整行，由分组裁出外圆角。
      shape: const RoundedRectangleBorder(),
      titleAlignment: ListTileTitleAlignment.center,
      leading: SizedBox(
        width: 24,
        child: Center(
          child: FaIcon(icon, size: 18, color: colorScheme.primary),
        ),
      ),
      title: Text(label),
      trailing: navigates
          ? FaIcon(
              FontAwesomeIcons.angleRight,
              size: 14,
              color: colorScheme.onSurfaceVariant,
            )
          : null,
      onTap: onTap,
    );
  }
}
