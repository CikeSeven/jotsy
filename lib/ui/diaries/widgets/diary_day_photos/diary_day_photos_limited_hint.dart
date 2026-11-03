import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../controllers/diary_day_photos_controller.dart';

/// 部分授权提示：只看得到用户挑过的照片与视频，提供“选择更多”。
///
/// 提示条与“这天的照片”面板共用；[mainAxisAlignment] 让面板的空状态把这一行
/// 与上方说明一起居中，提示条与网格上方保持靠行首。
class DiaryDayPhotosLimitedHint extends StatelessWidget {
  const DiaryDayPhotosLimitedHint({
    super.key,
    required this.controller,
    this.mainAxisAlignment = MainAxisAlignment.start,
  });

  final DiaryDayPhotosController controller;
  final MainAxisAlignment mainAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _HintRow(
      message: l10n.diaryDayPhotosLimited,
      action: l10n.diaryDayPhotosManageLimited,
      onPressed: controller.manageLimitedSelection,
      mainAxisAlignment: mainAxisAlignment,
    );
  }
}

/// 视频未授权提示：只授权过图片的 Android 13+ 设备（升级前只申请图片权限）
/// 照常列出照片，这一行说明视频还读不到，点“允许访问”才申请（被拒后为
/// “去设置”）。与 [DiaryDayPhotosLimitedHint] 同一排布。
class DiaryDayPhotosVideoAccessHint extends StatelessWidget {
  const DiaryDayPhotosVideoAccessHint({
    super.key,
    required this.controller,
    this.mainAxisAlignment = MainAxisAlignment.start,
  });

  final DiaryDayPhotosController controller;
  final MainAxisAlignment mainAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _HintRow(
      message: l10n.diaryDayPhotosVideoAccess,
      action: controller.shouldOpenSettings
          ? l10n.diaryDayPhotosOpenSettings
          : l10n.diaryDayPhotosAllowAccess,
      onPressed: controller.requestAccess,
      mainAxisAlignment: mainAxisAlignment,
    );
  }
}

/// 一行次要说明 + 紧凑的文本按钮。
class _HintRow extends StatelessWidget {
  const _HintRow({
    required this.message,
    required this.action,
    required this.onPressed,
    required this.mainAxisAlignment,
  });

  final String message;
  final String action;
  final VoidCallback onPressed;
  final MainAxisAlignment mainAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      children: <Widget>[
        Flexible(
          child: Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          onPressed: onPressed,
          child: Text(action),
        ),
      ],
    );
  }
}
