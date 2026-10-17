import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/services/app_update_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../widgets/app_top_bar.dart';
import '../controllers/app_update_controller.dart';
import '../models/app_update_state.dart';
import '../sections/app_update_action_bar.dart';
import '../sections/app_update_notes_section.dart';
import '../sections/app_update_preferences_section.dart';
import '../sections/app_update_status_section.dart';
import '../widgets/app_update_source_sheet.dart';
import '../widgets/external_link.dart';

/// 设置 → 关于 → 检查更新：软件更新页（只负责装配）。
///
/// - 进入时读取偏好；本次启动还没检查、已是最新或上次检查失败时重新检查，
///   下载中 / 有新版本 / 待安装时沿用全局状态（离开页面后下载不中断）；
/// - [startDownload] 来自启动提示的“立即更新”：有新版本时进入即开始下载，
///   已下载过则直接打开安装器；
/// - 回到前台时交给控制器，用户在系统设置里允许“安装未知应用”后自动继续。
class AppUpdatePage extends ConsumerStatefulWidget {
  const AppUpdatePage({super.key, this.startDownload = false});

  final bool startDownload;

  @override
  ConsumerState<AppUpdatePage> createState() => _AppUpdatePageState();
}

class _AppUpdatePageState extends ConsumerState<AppUpdatePage>
    with WidgetsBindingObserver {
  AppUpdateController get _controller =>
      ref.read(appUpdateControllerProvider.notifier);

  String get _languageCode => context.l10n.isZh ? 'zh' : 'en';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_controller.handleAppResumed());
    }
  }

  Future<void> _start() async {
    if (!mounted) {
      return;
    }
    final languageCode = _languageCode;
    await _controller.loadPreferences();
    if (!mounted) {
      return;
    }
    final state = ref.read(appUpdateControllerProvider);
    final stale =
        state.phase == AppUpdatePhase.idle ||
        state.phase == AppUpdatePhase.upToDate ||
        (state.phase == AppUpdatePhase.failed &&
            state.failure?.stage == AppUpdateStage.check);
    if (stale) {
      await _controller.check(languageCode: languageCode);
    } else if (widget.startDownload) {
      switch (state.phase) {
        case AppUpdatePhase.available:
          await _controller.download();
        case AppUpdatePhase.readyToInstall:
          // 之前已下载并校验过：直接打开安装器，不再多点一次。
          await _controller.install();
        default:
          break;
      }
    }
  }

  Future<void> _pickSource() async {
    final preferences = ref.read(appUpdateControllerProvider).preferences;
    final choice = await showAppUpdateSourceSheet(
      context,
      preferences: preferences,
    );
    if (choice == null) {
      return;
    }
    await _controller.setSource(
      choice.sourceId,
      customMirror: choice.customMirror,
    );
  }

  Future<void> _grantInstallPermission() async {
    final opened = await _controller.openInstallPermissionSettings();
    if (opened || !mounted) {
      return;
    }
    await HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(
        content: Text(context.l10n.appUpdateInstallPermissionSettingsFailed),
      ),
    );
  }

  Future<void> _openReleasePage() {
    final release = ref.read(appUpdateControllerProvider).release;
    return openExternalLink(
      context,
      (release?.pageUrl ?? AppUpdateEndpoints.latestReleasePage).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(appUpdateControllerProvider);
    return Scaffold(
      appBar: AppTopBar(
        title: Text(l10n.appUpdateTitle),
        leading: IconButton(
          tooltip: l10n.commonBack,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
        children: <Widget>[
          AppUpdateStatusSection(state: state),
          AppUpdateNotesSection(state: state),
          AppUpdatePreferencesSection(
            preferences: state.preferences,
            onAutoCheckChanged: (value) =>
                unawaited(_controller.setAutoCheck(value)),
            onPickSource: _pickSource,
          ),
        ],
      ),
      bottomNavigationBar: AppUpdateActionBar(
        state: state,
        onCheck: () =>
            unawaited(_controller.retry(languageCode: _languageCode)),
        onDownload: () => unawaited(_controller.download()),
        onCancelDownload: _controller.cancelDownload,
        onInstall: () => unawaited(_controller.install()),
        onGrantInstallPermission: _grantInstallPermission,
        onOpenReleasePage: _openReleasePage,
        onSkip: () => unawaited(_controller.skipCurrentVersion()),
      ),
    );
  }
}
