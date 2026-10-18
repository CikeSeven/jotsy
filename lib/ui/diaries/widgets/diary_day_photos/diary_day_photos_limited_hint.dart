import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../controllers/diary_day_photos_controller.dart';

/// 部分授权提示：只看得到用户挑过的照片，提供“选择更多”。
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
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      children: <Widget>[
        Flexible(
          child: Text(
            l10n.diaryDayPhotosLimited,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          onPressed: controller.manageLimitedSelection,
          child: Text(l10n.diaryDayPhotosManageLimited),
        ),
      ],
    );
  }
}
