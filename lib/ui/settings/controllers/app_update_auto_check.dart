import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../pages/app_update_page.dart';
import '../widgets/app_update_available_sheet.dart';
import '../widgets/external_link.dart';
import 'app_update_controller.dart';

/// 自动检查更新的触发时机：冷启动后与每次回到前台。
///
/// 由首页创建并销毁；只负责“什么时候试一次”，是否真的请求（开关、平台、
/// 距上次检查是否满 `AppUpdatePreferences.autoCheckInterval`）由
/// [AppUpdateController.autoCheck] 判断，所以回到前台再频繁也不会多发请求。
///
/// - 冷启动：延迟 [launchDelay]，避开启动揭幕与首屏数据加载；
/// - 回到前台：延迟 [resumeDelay]，让恢复后的首帧与应用锁验证先完成；
///   Android 进程常驻后台，只靠冷启动的话可能几天才检查一次；
/// - 进入后台时取消尚未触发的计时，避免在后台发请求；销毁时一并取消。
/// 这些都是非动画计时。
class AppUpdateAutoChecker with WidgetsBindingObserver {
  AppUpdateAutoChecker(this._run);

  static const Duration launchDelay = Duration(seconds: 4);
  static const Duration resumeDelay = Duration(seconds: 1);

  final Future<void> Function() _run;
  Timer? _timer;
  bool _started = false;

  void start() {
    if (_started) {
      return;
    }
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _schedule(launchDelay);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _schedule(resumeDelay);
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        _timer?.cancel();
        _timer = null;
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      _timer = null;
      unawaited(_run());
    });
  }
}

/// 一次自动检查与提示，由 [AppUpdateAutoChecker] 调用。
///
/// - 只在首页位于栈顶时弹出提示面板：用户已进入编辑页等页面时不打断，
///   设置页“关于”入口上的“新版本”标记仍会提示；
/// - 同一版本在本次进程内只提示一次（[AppUpdateController.markPrompted]）：
///   每 2 小时可能检查一次，“以后再说”之后不应每次回到应用都再弹；
/// - “立即更新”进入更新页并直接开始下载（已下载则直接安装），“跳过此版本”
///   之后的自动检查不再提示该版本；
/// - 桌面（Windows / Linux）的主操作为“前往下载”：直接在浏览器里打开本平台
///   安装包的下载地址（没有时为发布页面），不进入更新页。
Future<void> runAutoUpdateCheck(BuildContext context, WidgetRef ref) async {
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
  controller.markPrompted(release);
  final desktop = state.desktopTarget != null;
  final action = await showAppUpdateAvailableSheet(
    context,
    release: release,
    installed: installed.version,
    asset: desktop ? state.desktopAsset : state.asset,
    desktop: desktop,
  );
  if (!context.mounted) {
    return;
  }
  switch (action) {
    case AppUpdatePromptAction.update when desktop:
      await openExternalLink(
        context,
        controller.desktopDownloadUri().toString(),
      );
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
