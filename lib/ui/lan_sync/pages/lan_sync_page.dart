// 局域网同步页（设置 → 数据与隐私 → 局域网同步）：装配与生命周期。
//
// 页面可见性（决定 `attachPage` / `detachPage` 与雷达是否播放）由两件事共同
// 决定：应用在前台（生命周期不是 paused / hidden / detached），且所在路由
// 没有被别的不透明页面盖住（TickerMode 开着——Overlay 会给被盖住的路由关掉
// TickerMode）。任一变化都重新判断，变化时才调用 attach / detach，保证成对、
// 不重复；页面销毁时若仍处于 attach 状态则补一次 detach。
//
// 配对事件只在本页处理（[LanSyncPairingFlow]）：本页是当前路由时弹配对
// 面板，否则拒绝——对方发来的配对请求只在同步页打开时接受。配对面板里的
// “先导出完整备份”借用数据管理页的导出流程（[LanSyncBackupExport]），导出
// 期间本页盖一层 ActionLoadingOverlay。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/services/app_platform.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../widgets/action_loading_overlay.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/delayed_loading_gate.dart';
import '../../widgets/form_width.dart';
import '../controllers/lan_sync_backup_export.dart';
import '../controllers/lan_sync_page_flows.dart';
import '../controllers/lan_sync_pairing_auth_gate.dart';
import '../controllers/lan_sync_pairing_flow.dart';
import '../models/lan_sync_ui_controller.dart';
import '../models/lan_sync_view_state.dart';
import '../providers/lan_sync_providers.dart';
import '../sections/lan_sync_first_use_card.dart';
import '../sections/lan_sync_footer_links.dart';
import '../sections/lan_sync_hero_card.dart';
import '../sections/lan_sync_nearby_section.dart';
import '../sections/lan_sync_options_section.dart';
import '../sections/lan_sync_paired_section.dart';

class LanSyncPage extends ConsumerStatefulWidget {
  const LanSyncPage({super.key, this.clock = DateTime.now});

  /// 换算“X 前已同步”用的当前时间；测试可固定。
  final DateTime Function() clock;

  @override
  ConsumerState<LanSyncPage> createState() => _LanSyncPageState();
}

class _LanSyncPageState extends ConsumerState<LanSyncPage>
    with WidgetsBindingObserver {
  late final LanSyncUiController _controller = ref.read(
    lanSyncControllerProvider,
  );
  late final LanSyncBackupExport _backup = LanSyncBackupExport(
    contextOf: () => context,
    ref: ref,
  );
  late final LanSyncPairingFlow _pairing = LanSyncPairingFlow(
    controller: _controller,
    contextOf: () => mounted ? context : null,
    authGate: () => ref.read(lanSyncPairingAuthGateProvider),
    exportBackup: _backup.run,
    clock: widget.clock,
  );
  bool _foreground = true;
  bool _routeVisible = true;
  bool _attached = false;

  bool get _visible => _foreground && _routeVisible;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground = _isForeground(WidgetsBinding.instance.lifecycleState);
    // 立即订阅事件：配对事件不重放，晚订阅会漏掉。
    _pairing;
  }

  /// 生命周期未知（测试、首帧前）时按在前台处理；inactive（桌面窗口失焦、
  /// 来电浮层）页面仍看得见，也算前台。
  static bool _isForeground(AppLifecycleState? state) {
    return switch (state) {
      null || AppLifecycleState.resumed || AppLifecycleState.inactive => true,
      _ => false,
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeVisible = TickerMode.valuesOf(context).enabled;
    _syncAttachment();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = _isForeground(state);
    if (foreground == _foreground) return;
    setState(() => _foreground = foreground);
    _syncAttachment();
  }

  void _syncAttachment() {
    if (_visible == _attached) return;
    _attached = _visible;
    if (_attached) {
      _controller.attachPage();
    } else {
      _controller.detachPage();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_attached) _controller.detachPage();
    _pairing.dispose();
    _backup.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppPageBackground(
      area: AppBackgroundArea.settings,
      child: Builder(
        builder: (BuildContext context) => Scaffold(
          backgroundColor: AppPageBackdrop.pageColorOf(context),
          appBar: AppTopBar(
            contentMaxWidth: FormWidth.maxWidth,
            title: Text(l10n.lanSyncTitle),
            leading: IconButton(
              tooltip: l10n.commonBack,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
            ),
          ),
          body: Stack(
            children: <Widget>[
              ValueListenableBuilder<LanSyncViewState>(
                valueListenable: _controller.state,
                builder: (BuildContext context, LanSyncViewState state, _) =>
                    _buildBody(context, state),
              ),
              Positioned.fill(
                child: ValueListenableBuilder<String?>(
                  valueListenable: _backup.busyText,
                  builder: (BuildContext context, String? text, _) =>
                      ActionLoadingOverlay(
                        visible: text != null,
                        label: text ?? _backup.lastBusyText,
                        semanticLabel: l10n.dataMgmtBusyLabel,
                        revealDelay: DelayedLoadingGate.defaultDelay,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, LanSyncViewState state) {
    final controller = _controller;
    final local = state.local;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final side = FormWidth.gutter(constraints.maxWidth);
        final firstUse = state.peers.isEmpty;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            side,
            12,
            side,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          children: <Widget>[
            LanSyncHeroCard(
              local: local,
              collapsed: state.hasActiveSession,
              searchingFirstUse: firstUse && state.searching,
              animateRadar: local.discoverable && _visible,
              onRename: () => renameLanSyncDevice(context, controller),
              onCopyAddress: () {
                final address = local.primaryAddress;
                if (address == null) return;
                copyLanSyncAddress(context, address, port: local.port);
              },
              onToggleDiscoverable: () =>
                  controller.setDiscoverable(!local.discoverable),
              onShowQr: () => _pairing.showQr(context),
              onManualAddress: () =>
                  connectLanSyncByAddress(context, controller),
              onScanQr: AppPlatform.supportsQrScan
                  ? () => scanLanSyncQr(context, controller)
                  : null,
            ),
            const SizedBox(height: 24),
            if (firstUse)
              const LanSyncFirstUseCard()
            else
              LanSyncPairedSection(
                peers: state.peers,
                now: widget.clock(),
                onSync: controller.syncNow,
                onCancel: controller.cancelSync,
                onReview: controller.reviewPendingConfirmation,
              ),
            const SizedBox(height: 24),
            LanSyncNearbySection(
              nearby: state.nearby,
              searching: state.searching,
              onPair: controller.pairWith,
            ),
            const SizedBox(height: 24),
            LanSyncOptionsSection(
              autoSync: state.autoSyncEnabled,
              syncSettings: state.syncSettingsEnabled,
              onAutoSyncChanged: controller.setAutoSync,
              onSyncSettingsChanged: controller.setSyncSettings,
            ),
            const SizedBox(height: 16),
            LanSyncFooterLinks(
              onTroubleshoot: () =>
                  showLanSyncTroubleshooting(context, controller),
              onManualAddress: () =>
                  connectLanSyncByAddress(context, controller),
            ),
          ],
        );
      },
    );
  }
}
