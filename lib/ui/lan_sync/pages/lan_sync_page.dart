// 局域网同步页（设置 → 数据与隐私 → 局域网同步）：装配与生命周期。
//
// 页面可见性（决定 `attachPage` / `detachPage` 与雷达是否播放）由两件事共同
// 决定：应用在前台（生命周期不是 paused / hidden / detached），且所在路由
// 没有被别的不透明页面盖住（TickerMode 开着——Overlay 会给被盖住的路由关掉
// TickerMode）。任一变化都重新判断，变化时才调用 attach / detach，保证成对、
// 不重复；页面销毁时若仍处于 attach 状态则补一次 detach。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/form_width.dart';
import '../controllers/lan_sync_page_flows.dart';
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
  bool _foreground = true;
  bool _routeVisible = true;
  bool _attached = false;

  bool get _visible => _foreground && _routeVisible;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground = _isForeground(WidgetsBinding.instance.lifecycleState);
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
          body: ValueListenableBuilder<LanSyncViewState>(
            valueListenable: _controller.state,
            builder: (BuildContext context, LanSyncViewState state, _) =>
                _buildBody(context, state),
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
              onShowQr: controller.issueQrTicket,
              onManualAddress: () =>
                  connectLanSyncByAddress(context, controller),
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
