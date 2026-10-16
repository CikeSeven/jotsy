import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../l10n/app_localizations.dart';

/// 预览页“更多”面板：分享长图、三种导出、设为纪念日、页面样式与删除。
///
/// 每一项先关闭面板，再执行对应动作（长图截图要等面板完全退场，见
/// `DiaryPreviewExportController.shareLongImage`）。
Future<void> showDiaryPreviewActionsSheet(
  BuildContext context, {
  required Future<void> Function() onShareImage,
  required Future<void> Function() onExportMarkdown,
  required Future<void> Function() onExportPdf,
  required Future<void> Function() onExportDiaryFile,
  required Future<void> Function() onSetAsAnniversary,
  required Future<void> Function() onDelete,
  Future<void> Function()? onOpenStyle,
}) {
  final l10n = context.l10n;
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    // 底部面板默认滑入不读取系统“减少动态效果”；该模式下直接出现。
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) {
      final colorScheme = Theme.of(sheetContext).colorScheme;
      Widget item({
        required FaIcon icon,
        required Widget title,
        required Future<void> Function() action,
      }) {
        return ListTile(
          leading: icon,
          title: title,
          onTap: () async {
            Navigator.of(sheetContext).pop();
            await action();
          },
        );
      }

      return SafeArea(
        top: false,
        // 面板高度上限约 9/16 屏高，矮屏或横屏放不下全部操作时可滚动。
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              item(
                icon: const FaIcon(FontAwesomeIcons.image, size: 16),
                title: Text(l10n.autoT0114),
                action: onShareImage,
              ),
              item(
                icon: const FaIcon(FontAwesomeIcons.fileLines, size: 16),
                title: Text(l10n.previewExportMarkdown),
                action: onExportMarkdown,
              ),
              item(
                icon: const FaIcon(FontAwesomeIcons.filePdf, size: 16),
                title: Text(l10n.previewExportPdf),
                action: onExportPdf,
              ),
              item(
                icon: const FaIcon(FontAwesomeIcons.fileZipper, size: 16),
                title: Text(l10n.previewExportDiaryFile),
                action: onExportDiaryFile,
              ),
              item(
                icon: const FaIcon(FontAwesomeIcons.heart, size: 16),
                title: Text(l10n.previewSetAsAnniversary),
                action: onSetAsAnniversary,
              ),
              if (onOpenStyle != null)
                item(
                  icon: const FaIcon(FontAwesomeIcons.swatchbook, size: 16),
                  title: Text(l10n.diaryPreviewStyleMoreEntry),
                  action: onOpenStyle,
                ),
              item(
                icon: FaIcon(
                  FontAwesomeIcons.trashCan,
                  size: 16,
                  color: colorScheme.error,
                ),
                title: Text(
                  l10n.commonDelete,
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.bodyLarge?.copyWith(color: colorScheme.error),
                ),
                action: onDelete,
              ),
            ],
          ),
        ),
      );
    },
  );
}
