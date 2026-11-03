import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/services/diary_media_storage_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/expressive_menu/expressive_menu.dart';

/// 画工具按钮本身：[onPressed] 开合来源菜单，[menuOpen] 为菜单正开着
/// （按钮与面板开着时一样显示选中态）。
typedef DiaryToolbarMediaButtonBuilder =
    Widget Function(
      BuildContext context,
      VoidCallback onPressed,
      bool menuOpen,
    );

/// 工具栏图片 / 视频按钮在能拍摄的平台（`AppPlatform.supportsCameraCapture`）
/// 上的来源菜单：点按先弹出“从相册选择 / 拍照”（视频为“录像”），选了再交给
/// 编辑页的选文件或拍摄流程；不能拍摄的平台不套这一层，按钮仍直接打开选择器。
///
/// 只有两项单行动作，按规范用锚定弹出菜单（[ExpressiveMenuAnchor]），不另开
/// 面板。菜单用 `toggle` 打开、不抢焦点，正文与软键盘保持原样，工具栏不会因
/// 焦点离开正文而卸载；菜单落在工具栏上方（下方是键盘）。按钮本身（停用、
/// 导入中的加载图标、尺寸）仍由 [builder] 经 `buildDiaryToolbarItem` 画出。
class DiaryToolbarMediaSourceButton extends StatelessWidget {
  const DiaryToolbarMediaSourceButton({
    super.key,
    required this.kind,
    required this.onPickFromLibrary,
    required this.onCapture,
    required this.builder,
  }) : assert(kind != DiaryMediaKind.attachment);

  final DiaryMediaKind kind;
  final VoidCallback onPickFromLibrary;
  final VoidCallback onCapture;
  final DiaryToolbarMediaButtonBuilder builder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final video = kind == DiaryMediaKind.video;
    return ExpressiveMenuAnchor(
      placement: ExpressiveMenuPlacement.start,
      menuChildren: [
        ExpressiveMenuItem(
          leadingIcon: FaIcon(
            video ? FontAwesomeIcons.film : FontAwesomeIcons.images,
          ),
          onPressed: onPickFromLibrary,
          child: Text(l10n.diaryMediaFromLibrary),
        ),
        ExpressiveMenuItem(
          leadingIcon: FaIcon(
            video ? FontAwesomeIcons.video : FontAwesomeIcons.camera,
          ),
          onPressed: onCapture,
          child: Text(
            video ? l10n.diaryMediaRecordVideo : l10n.diaryMediaTakePhoto,
          ),
        ),
      ],
      builder: (context, menu, _) =>
          builder(context, menu.toggle, menu.isExpanded),
    );
  }
}
