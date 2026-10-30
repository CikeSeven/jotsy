// 二维码面板（“显示二维码”，DESIGN.md §5.27“二维码面板”）。
//
// 生命周期：
// - 挂载时 `issueQrTicket()` 签发一张码，并监听 `qrTicket`：控制器到期或
//   被扫过后换发的新码经它送来，面板重绘二维码、倒计时环随之重置；
// - 每秒走一次倒计时（非动画计时）；到期那一刻若控制器还没有换码，面板
//   自己再调一次 `issueQrTicket()`（每张码只补一次，避免与控制器的换发
//   重复）；
// - 关闭（含被配对面板替换）时 `revokeQrTicket()`，当前的码立即作废；
// - 准备中的码（`LanSyncQrTicket.isPending`：控制器还不能签发）：底板里只
//   显示加载与“正在准备二维码…”，倒计时胶囊隐藏，真码经 `qrTicket` 到来后
//   交叉淡入（见 `LanSyncQrBoard.pending`）。
//
// 扫码对比度：二维码一律画成“浅底深点”。ML Kit（本应用的扫码器）不识别
// 浅点深底的反色码（mobile_scanner 的 `invertImage` 会整帧反色，正常的码
// 反而扫不出），暗色主题下的 `surfaceContainerLow` 底板配 `onSurface` 点
// 对比度虽够，却正好是反色码。因此暗色主题下底板这一块改用由应用种子色
// 推出的**浅色**配色（底板 `surfaceContainerLowest`、点 `onSurface`、定位角
// 与品牌块 `primary` / `primaryContainer`），浅色主题照设计稿取
// `surfaceContainerLow`；玻璃材质下底板为叠在不透明浅底上的 `OnGlass.wellColor`
// （半透明底板透出深色背景图同样会变成反色码）。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../models/lan_sync_qr_matrix.dart';
import '../models/lan_sync_qr_ticket.dart';
import '../models/lan_sync_ui_controller.dart';
import 'lan_sync_labels.dart';
import 'lan_sync_qr_board.dart';

/// 打开二维码面板。选了“改用核对码配对”时返回 true，其余关闭方式为 null。
/// [onRoute] 在面板挂载时收到它的路由（配对开始时调用方据此关掉面板）。
Future<bool?> showLanSyncQrSheet(
  BuildContext context, {
  required LanSyncUiController controller,
  DateTime Function() clock = DateTime.now,
  void Function(ModalRoute<Object?>? route)? onRoute,
}) {
  return showAppModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 640),
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (_) =>
        LanSyncQrSheet(controller: controller, clock: clock, onRoute: onRoute),
  );
}

/// 见文件头注释。
class LanSyncQrSheet extends ConsumerStatefulWidget {
  const LanSyncQrSheet({
    super.key,
    required this.controller,
    this.clock = DateTime.now,
    this.onRoute,
  });

  final LanSyncUiController controller;
  final DateTime Function() clock;
  final void Function(ModalRoute<Object?>? route)? onRoute;

  @override
  ConsumerState<LanSyncQrSheet> createState() => _LanSyncQrSheetState();
}

class _LanSyncQrSheetState extends ConsumerState<LanSyncQrSheet> {
  LanSyncQrTicket? _ticket;
  LanSyncQrMatrix? _matrix;
  String? _matrixPayload;
  double? _matrixCodeExtent;
  Timer? _ticker;
  bool _routeReported = false;

  /// 已经由面板补签过的那张码（每张只补一次）。
  LanSyncQrTicket? _reissuedFor;

  LanSyncUiController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.qrTicket.addListener(_onTicket);
    _ticket = _controller.issueQrTicket();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeReported) return;
    _routeReported = true;
    widget.onRoute?.call(ModalRoute.of(context));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.qrTicket.removeListener(_onTicket);
    _controller.revokeQrTicket();
    super.dispose();
  }

  void _onTicket() {
    final ticket = _controller.qrTicket.value;
    // 变成 null 只会是别处作废了码：保留上一张的画面，到期时照常补签。
    if (ticket == null || ticket == _ticket) return;
    setState(() => _ticket = ticket);
  }

  void _tick() {
    final ticket = _ticket;
    if (ticket == null) return;
    final expired = ticket.remainingAt(widget.clock()) == Duration.zero;
    if (expired && !identical(_reissuedFor, ticket)) {
      _reissuedFor = ticket;
      final next = _controller.issueQrTicket();
      setState(() => _ticket = next);
      return;
    }
    setState(() {});
  }

  /// 按载荷与码的边长缓存矩阵：换码或面板跨过宽 / 窄档时才重算（挖空的
  /// 模块数随码的边长变化）。
  LanSyncQrMatrix? _matrixFor(LanSyncQrTicket? ticket, double codeExtent) {
    if (ticket == null || ticket.isPending) return null;
    if (_matrixPayload != ticket.payload || _matrixCodeExtent != codeExtent) {
      _matrixPayload = ticket.payload;
      _matrixCodeExtent = codeExtent;
      _matrix = LanSyncQrMatrix.encode(
        ticket.payload,
        codeExtent: codeExtent,
        markExtent: LanSyncQrBoard.markExtent,
      );
    }
    return _matrix;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    final ticket = _ticket;
    final local = _controller.state.value.local;
    final name = lanSyncLocalName(l10n, local.name);
    final address = local.primaryAddress;
    final caption = theme.textTheme.bodySmall?.copyWith(
      fontSize: 13,
      color: colors.onSurfaceVariant,
    );
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        4,
        24,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            l10n.lanSyncQrTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.lanSyncQrSubtitle,
            textAlign: TextAlign.center,
            style: caption?.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final metrics = LanSyncQrBoardMetrics.forWidth(
                constraints.maxWidth,
              );
              return FittedBox(
                fit: BoxFit.scaleDown,
                child: LanSyncQrBoard(
                  matrix: _matrixFor(ticket, metrics.codeExtent),
                  metrics: metrics,
                  pending: ticket?.isPending ?? false,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // 准备中隐藏倒计时，但保留它的位置：真码到来时下面几行不跳动。
          if (ticket != null)
            Visibility(
              visible: !ticket.isPending,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: LanSyncQrCountdownPill(
                ticket: ticket,
                now: widget.clock(),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            address == null
                ? name
                : l10n.lanSyncQrDeviceLine(
                    name,
                    local.port == null ? address : '$address:${local.port}',
                  ),
            textAlign: TextAlign.center,
            style: caption?.copyWith(
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.lanSyncQrSingleUse,
            textAlign: TextAlign.center,
            style: caption,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.lanSyncQrUseCode),
          ),
        ],
      ),
    );
  }
}
