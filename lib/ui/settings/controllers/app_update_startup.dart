import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../pages/app_update_page.dart';
import '../widgets/app_update_available_sheet.dart';
import 'app_update_controller.dart';

/// 冷启动后的自动检查与提示，由首页在启动揭幕结束后延迟调用。
///
/// - 是否请求由 [AppUpdateController.autoCheck] 决定（开关、间隔、平台）；
/// - 只在首页位于栈顶时弹出提示面板：用户已进入编辑页等页面时不打断，
///   设置页“关于”入口上的“新版本”标记仍会提示；
/// - “立即更新”进入更新页并直接开始下载，“跳过此版本”之后的自动检查
///   不再提示该版本，“以后再说”（含点遮罩关闭）下次冷启动到期再提示。
Future<void> runStartupUpdateCheck(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(appUpdateControllerProvider.notifier);
  final release = await controller.autoCheck(
    languageCode: context.l10n.isZh ? 'zh' : 'en',
  );
  if (release == null || !context.mounted) {
    return;
  }
  if (ModalRoute.of(context)?.isCurrent != true) {
    return;
  }
  final state = ref.read(appUpdateControllerProvider);
  final installed = state.installed;
  if (installed == null) {
    return;
  }
  final action = await showAppUpdateAvailableSheet(
    context,
    release: release,
    installed: installed.version,
    asset: state.asset,
  );
  if (!context.mounted) {
    return;
  }
  switch (action) {
    case AppUpdatePromptAction.update:
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              const AppUpdatePage(startDownload: true),
        ),
      );
    case AppUpdatePromptAction.skip:
      await controller.skipCurrentVersion();
    case AppUpdatePromptAction.later:
      break;
  }
}
