import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../controllers/diary_day_photos_controller.dart';
import 'diary_day_photos_limited_hint.dart';

// “这天的照片”面板在没有网格时的两种主体：未授权与这天没有照片。读取中
// 直接用 DelayedLoadingIndicator，网格与底栏留在 diary_day_photos_sheet.dart。

/// 面板里没有网格时的居中说明：图标 + 一段文字 + 可选的动作。
class _SheetMessage extends StatelessWidget {
  const _SheetMessage({required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final action = this.action;
    return SafeArea(
      top: false,
      child: Center(
        // 小屏或大字号下说明可能放不下：允许内部滚动而不是溢出。
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FaIcon(
                FontAwesomeIcons.images,
                size: 32,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.m),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              if (action != null) ...<Widget>[
                const SizedBox(height: AppSpacing.l),
                action,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 未授权：说明与“允许访问”（拒绝过后为“去设置”），与提示条同一套文案与
/// 逻辑；只有点按才会弹系统权限框。
class DiaryDayPhotosSheetAccess extends StatelessWidget {
  const DiaryDayPhotosSheetAccess({super.key, required this.controller});

  final DiaryDayPhotosController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final openSettings = controller.shouldOpenSettings;
    return _SheetMessage(
      message: openSettings
          ? l10n.diaryDayPhotosDeniedBody
          : l10n.diaryDayPhotosAccessBody,
      action: FilledButton.tonal(
        onPressed: controller.requestAccess,
        child: Text(
          openSettings
              ? l10n.diaryDayPhotosOpenSettings
              : l10n.diaryDayPhotosAllowAccess,
        ),
      ),
    );
  }
}

/// 这天没有照片；部分授权时可能只是没被允许访问，给出“选择更多”。
class DiaryDayPhotosSheetEmpty extends StatelessWidget {
  const DiaryDayPhotosSheetEmpty({super.key, required this.controller});

  final DiaryDayPhotosController controller;

  @override
  Widget build(BuildContext context) {
    return _SheetMessage(
      message: context.l10n.diaryDayPhotosEmpty,
      action: controller.isLimited
          ? DiaryDayPhotosLimitedHint(
              controller: controller,
              mainAxisAlignment: MainAxisAlignment.center,
            )
          : null,
    );
  }
}
