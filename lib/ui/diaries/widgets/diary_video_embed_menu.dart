import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/core/services/app_platform.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_video_export_controller.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_export_button.dart';
import 'package:node_diary/ui/widgets/app_modal/app_modal_bottom_sheet.dart';
import 'package:node_diary/ui/widgets/expressive_menu/expressive_menu.dart';

/// 编辑页里视频块的菜单动作（#252）：小图切换、调整大小、删除。只读正文
/// （预览页等）不给，视频卡片照旧只有导出按钮，小图点按直接播放。
///
/// 写正文的动作由媒体块执行（`DiaryVideoEmbedActions` /
/// `DiaryImageEmbedActions`），这里只是把菜单与执行接起来。
class DiaryVideoEmbedMenu {
  const DiaryVideoEmbedMenu({
    required this.thumbnail,
    required this.onToggleThumbnail,
    required this.onResize,
    required this.onDelete,
  });

  /// 视频当前是否为小图：决定切换项的文字，小图时没有“调整大小”（小图
  /// 尺寸固定，宽度上限不生效）。
  final bool thumbnail;
  final VoidCallback onToggleThumbnail;
  final VoidCallback onResize;
  final VoidCallback onDelete;
}

/// 视频菜单的条目（单行动作，最多四项，经 `ExpressiveMenuAnchor` 弹出）：
///
/// - 视频卡片：显示为小图、调整大小、保存到相册（桌面为“另存为…”）、删除；
/// - 小图：播放（[onPlay]；不能内嵌播放的平台为“用系统播放器打开”）、恢复
///   正常显示、保存到相册、删除。
///
/// [onExport] 为 null（导出进行中）时“保存到相册”停用。
List<Widget> diaryVideoMenuItems(
  BuildContext context, {
  required DiaryVideoEmbedMenu menu,
  required VoidCallback? onExport,
  VoidCallback? onPlay,
}) {
  final l10n = context.l10n;
  return <Widget>[
    if (onPlay != null)
      ExpressiveMenuItem(
        leadingIcon: FaIcon(
          AppPlatform.supportsInlineVideo
              ? FontAwesomeIcons.play
              : FontAwesomeIcons.arrowUpRightFromSquare,
        ),
        onPressed: onPlay,
        child: Text(
          AppPlatform.supportsInlineVideo
              ? l10n.videoPlay
              : l10n.videoOpenExternally,
        ),
      ),
    ExpressiveMenuItem(
      leadingIcon: FaIcon(
        menu.thumbnail ? FontAwesomeIcons.film : FontAwesomeIcons.compress,
      ),
      onPressed: menu.onToggleThumbnail,
      child: Text(
        menu.thumbnail
            ? l10n.diaryImageMenuFullSize
            : l10n.diaryImageMenuThumbnail,
      ),
    ),
    if (!menu.thumbnail)
      ExpressiveMenuItem(
        leadingIcon: const FaIcon(
          FontAwesomeIcons.upRightAndDownLeftFromCenter,
        ),
        onPressed: menu.onResize,
        child: Text(l10n.diaryImageMenuResize),
      ),
    ExpressiveMenuItem(
      leadingIcon: const FaIcon(FontAwesomeIcons.download),
      onPressed: onExport,
      // 桌面没有相册：同一动作弹出“另存为…”对话框。
      child: Text(
        AppPlatform.savesImagesToGallery
            ? l10n.imageViewerSaveToGallery
            : l10n.desktopSaveAs,
      ),
    ),
    ExpressiveMenuItem(
      leadingIcon: const FaIcon(FontAwesomeIcons.trashCan),
      destructive: true,
      onPressed: menu.onDelete,
      child: Text(l10n.commonDelete),
    ),
  ];
}

/// 视频卡片控件行里的 ⋮（编辑页）：取代只读时的导出按钮，菜单见
/// [diaryVideoMenuItems]；导出进行中换成等待指示（[DiaryVideoBusySwap]）。
class DiaryVideoMenuButton extends StatelessWidget {
  const DiaryVideoMenuButton({
    super.key,
    required this.video,
    required this.menu,
    required this.exportController,
  });

  final DiaryFileAttachment video;
  final DiaryVideoEmbedMenu menu;
  final DiaryVideoExportController exportController;

  @override
  Widget build(BuildContext context) => DiaryVideoBusySwap(
    controller: exportController,
    builder: (context) => ExpressiveMenuButton(
      // 按钮在正文编辑器里：打开菜单不抢焦点，键盘保持收起。
      takesFocus: false,
      tooltip: context.l10n.videoMoreActions,
      icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 16),
      items: diaryVideoMenuItems(
        context,
        menu: menu,
        onExport: exportController.isBusy
            ? null
            : () => unawaited(
                runDiaryVideoExport(
                  context,
                  video: video,
                  controller: exportController,
                ),
              ),
      ),
    ),
  );
}

/// 视频卡片的最小宽度：控件行（播放、进度条、⋮、全屏）还放得下。
const double kDiaryVideoMinWidth = 240;

/// 调整视频卡片宽度的面板：一条宽度滑条，拖动时经 [onPreview] 逐帧在原位
/// 预览（不写正文、不堆撤销记录），点“确认”返回新宽度；直接关闭返回 null，
/// 由调用方清除预览、恢复原宽度。高度随视频比例，不另设。
///
/// [current] 为现在的宽度（没设过时为 [maxWidth]），[maxWidth] 为正文列宽。
Future<double?> showDiaryVideoResizer(
  BuildContext context, {
  required double current,
  required double maxWidth,
  required ValueChanged<double> onPreview,
}) {
  final max = math.max(maxWidth, kDiaryVideoMinWidth + 1);
  var width = current.clamp(kDiaryVideoMinWidth, max).toDouble();
  return showAppModalBottomSheet<double>(
    context: context,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.diaryImageMenuResize,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Text(context.l10n.diaryEditorVideoWidth),
              Slider(
                value: width,
                min: kDiaryVideoMinWidth,
                max: max,
                label: '${width.round()}',
                onChanged: (value) {
                  setState(() => width = value);
                  onPreview(value);
                },
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context, width),
                  child: Text(context.l10n.commonConfirm),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
