// 已配对设备的详情页（同步页 → 点按“我的设备”里的一行）：装配与生命周期。
//
// - 读同一份 `LanSyncUiController.state`，按 [LanSyncDevicePage.peerId] 找到
//   这台设备；可见性与 attach / detach 同同步页（[LanSyncPageAttachment]，
//   盖在同步页上时同步页 detach、本页 attach，发现仍保持快节奏）；
// - 同步确认对话框与完成摘要经本页自己的 [LanSyncSessionFlow]：用户停在
//   本页时由本页弹出（同步页此时不是当前路由，不会重复弹）；
// - 设备从状态里消失（本页“取消配对”之后，或别处忘掉了它）时本页自行
//   关闭：是当前路由就 pop，被盖住时直接移出路由栈（不能 pop，那会关掉盖在
//   上面的对话框）。消失后到关闭前的那一帧仍按最后一次见到的设备绘制。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/form_width.dart';
import '../controllers/lan_sync_page_attachment.dart';
import '../controllers/lan_sync_page_flows.dart';
import '../controllers/lan_sync_session_flow.dart';
import '../models/lan_sync_ui_controller.dart';
import '../models/lan_sync_view_state.dart';
import '../providers/lan_sync_providers.dart';
import '../sections/lan_sync_device_hero.dart';
import '../sections/lan_sync_device_settings.dart';
import '../sections/lan_sync_history_section.dart';

class LanSyncDevicePage extends ConsumerStatefulWidget {
  const LanSyncDevicePage({
    super.key,
    required this.peerId,
    this.clock = DateTime.now,
  });

  /// 设备详情页的路由。
  static Route<void> route(String peerId, {DateTime Function()? clock}) {
    return MaterialPageRoute<void>(
      builder: (BuildContext context) =>
          LanSyncDevicePage(peerId: peerId, clock: clock ?? DateTime.now),
    );
  }

  final String peerId;

  /// 换算“X 前”的当前时间；测试可固定。
  final DateTime Function() clock;

  @override
  ConsumerState<LanSyncDevicePage> createState() => _LanSyncDevicePageState();
}

class _LanSyncDevicePageState extends ConsumerState<LanSyncDevicePage>
    with WidgetsBindingObserver, LanSyncPageAttachment<LanSyncDevicePage> {
  late final LanSyncUiController _controller = ref.read(
    lanSyncControllerProvider,
  );
  late final LanSyncSessionFlow _session = LanSyncSessionFlow(
    controller: _controller,
    contextOf: () => mounted ? context : null,
    openDiary: (BuildContext context, String diaryId) =>
        ref.read(lanSyncOpenDiaryProvider)(context, ref, diaryId),
  );

  /// 最后一次在状态里见到的这台设备（消失后关闭前仍按它绘制）。
  LanSyncPeerView? _peer;

  /// 已经在关闭本页：消失检测与“取消配对”只关一次。
  bool _leaving = false;

  @override
  LanSyncUiController get lanSyncController => _controller;

  @override
  void initState() {
    super.initState();
    // 立即订阅：确认与完成事件不重放。
    _session;
    _peer = _find(_controller.state.value);
    _controller.state.addListener(_onState);
    if (_peer == null) {
      // 打开时就已经没有这台设备（极少见）：等首帧挂好路由再关。
      WidgetsBinding.instance.addPostFrameCallback((_) => _leave());
    }
  }

  LanSyncPeerView? _find(LanSyncViewState state) {
    for (final peer in state.peers) {
      if (peer.deviceId == widget.peerId) return peer;
    }
    return null;
  }

  void _onState() {
    final peer = _find(_controller.state.value);
    if (peer != null) {
      _peer = peer;
      return;
    }
    // 状态变化可能发生在构建期间以外的任何时刻；路由操作放到帧后执行。
    WidgetsBinding.instance.addPostFrameCallback((_) => _leave());
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// 关闭本页（见文件头注释）。
  void _leave() {
    if (_leaving || !mounted) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    _leaving = true;
    final navigator = Navigator.of(context);
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  }

  @override
  void dispose() {
    _controller.state.removeListener(_onState);
    _session.dispose();
    super.dispose();
  }

  Future<void> _forget(LanSyncPeerView peer) async {
    final forgotten = await forgetLanSyncPeer(context, _controller, peer);
    if (forgotten) _leave();
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
            title: Text(l10n.lanSyncDeviceTitle),
            leading: IconButton(
              tooltip: l10n.commonBack,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
            ),
          ),
          body: ValueListenableBuilder<LanSyncViewState>(
            valueListenable: _controller.state,
            builder: (BuildContext context, LanSyncViewState state, _) {
              final peer = _find(state) ?? _peer;
              if (peer == null) return const SizedBox.shrink();
              return _buildBody(context, state, peer);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    LanSyncViewState state,
    LanSyncPeerView peer,
  ) {
    final colors = Theme.of(context).colorScheme;
    final now = widget.clock();
    final controller = _controller;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final side = FormWidth.gutter(constraints.maxWidth);
        return ListView(
          padding: EdgeInsets.fromLTRB(
            side,
            12,
            side,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          children: <Widget>[
            LanSyncDeviceHero(
              peer: peer,
              localPlatform: state.local.platform,
              now: now,
              onSyncNow: () => controller.syncNow(peer.deviceId),
              onCancel: () => controller.cancelSync(peer.deviceId),
            ),
            const SizedBox(height: 24),
            LanSyncDeviceSettings(
              peer: peer,
              globalAutoSync: state.autoSyncEnabled,
              onAutoSyncChanged: (bool enabled) =>
                  controller.setPeerAutoSync(peer.deviceId, enabled),
              onEditAlias: () =>
                  editLanSyncPeerAlias(context, controller, peer),
            ),
            const SizedBox(height: 24),
            LanSyncHistorySection(history: peer.history, now: now),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: colors.error,
                  minimumSize: const Size(0, 48),
                ),
                onPressed: () => _forget(peer),
                child: Text(context.l10n.lanSyncForget),
              ),
            ),
          ],
        );
      },
    );
  }
}
