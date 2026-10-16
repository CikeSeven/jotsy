import 'package:node_diary/l10n/app_localizations.dart';

import '../controllers/diary_share_controller.dart';
import '../models/diary_share_target.dart';

/// 分享目标的显示名称（分享面板按钮与结果提示共用）。
String diaryShareTargetLabel(AppLocalizations l10n, DiaryShareTarget target) {
  return switch (target) {
    DiaryShareTarget.weibo => l10n.diaryShareTargetWeibo,
    DiaryShareTarget.xiaohongshu => l10n.diaryShareTargetXiaohongshu,
    DiaryShareTarget.wechat => l10n.diaryShareTargetWechat,
    DiaryShareTarget.qq => l10n.diaryShareTargetQq,
    DiaryShareTarget.system => l10n.diaryShareTargetSystem,
  };
}

/// 把分享结果转成一条提示；顺利交给目标应用、也没有需要用户知道的事时
/// 返回 null（用户此时已在目标应用里，不必再弹提示）。
///
/// 主提示之后按行附上图片被截断、读取失败的说明：这两件事用户在目标
/// 应用里看得到结果，却不知道原因。
String? diaryShareResultMessage(
  AppLocalizations l10n,
  DiaryShareResult result, {
  DiaryShareTarget? target,
}) {
  final appName = target == null || target.packageName == null
      ? null
      : diaryShareTargetLabel(l10n, target);
  final primary = switch (result.outcome) {
    DiaryShareOutcome.copied => l10n.diaryShareCopied,
    DiaryShareOutcome.nothingToShare => l10n.diaryShareNothingToShare,
    DiaryShareOutcome.appUnavailable => l10n.diaryShareAppUnavailable(
      appName ?? l10n.diaryShareTargetSystem,
    ),
    DiaryShareOutcome.shared when result.textCopied =>
      appName == null
          ? l10n.diaryShareTextCopied
          : l10n.diaryShareTextCopiedForApp(appName),
    DiaryShareOutcome.shared => null,
  };
  final lines = <String>[
    ?primary,
    if (result.trimmedImages > 0 && target?.maxImages != null)
      l10n.diaryShareImagesTrimmed(target!.maxImages!),
    if (result.missingImages > 0)
      l10n.diaryShareImagesMissing(result.missingImages),
  ];
  return lines.isEmpty ? null : lines.join('\n');
}
