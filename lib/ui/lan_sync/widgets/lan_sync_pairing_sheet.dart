// 配对面板（DESIGN.md §5.28“配对面板”）：随 `LanSyncPairingEvent.phase`
// 切换内容的底部面板，只负责展示与收集点按。
//
// 状态机（phase → 内容）：
// - Connecting → 加载指示 +“正在连接 X…”；
// - AwaitingUser(code) → 核对码 + 安全说明 +“不一致 / 一致，配对”；
// - AwaitingPeer(code) → 同一块核对码，按钮区换成“等待对方确认…”
//   （与上一阶段共用同一个 key，核对码不重新弹入）；
// - Succeeded(peerId) → 对勾徽章 +“立即同步 / 稍后”，进入时 lightImpact；
// - Failed(reason) → 错误图标 + 原因 +“关闭”。
// 扫码配对没有核对码：Connecting 直接到 Succeeded。阶段之间内容交叉淡入
// （`fast`），面板高度补间（`medium`）。
//
// 关闭面板的结果交给调用方（lan_sync_pairing_flow.dart）：返回
// [LanSyncPairingSheetAction]，或 null（不一致、稍后、关闭、下滑关掉）。
// 面板自己从不调用 `respond(false)`——放弃配对统一由调用方在面板关闭后按
// 当时的阶段决定，下滑关掉与点“不一致”走同一条路。

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/expressive_motion.dart';
import '../models/lan_sync_pairing_auth.dart';
import '../models/lan_sync_platform.dart';
import '../models/lan_sync_ui_events.dart';
import 'lan_sync_pairing_phases.dart';

/// 面板关闭时要调用方接着做的事。
enum LanSyncPairingSheetAction {
  /// 成功态的“立即同步”。
  syncNow,

  /// 核对码阶段的“先导出完整备份”：先放弃这次配对，再导出。
  exportBackup,
}

/// 配对面板本体；由 `showAppModalBottomSheet` 承载。
class LanSyncPairingSheet extends StatefulWidget {
  const LanSyncPairingSheet({
    super.key,
    required this.event,
    required this.localPlatform,
    required this.onConfirm,
  });

  final LanSyncPairingEvent event;
  final LanSyncPlatform localPlatform;

  /// 用户点了“一致，配对”：调用方先按需验证身份，通过后 `respond(true)`。
  /// 返回验证结果；不是 allowed 时面板停在核对码上并提示。
  final Future<LanSyncPairingAuthOutcome> Function() onConfirm;

  @override
  State<LanSyncPairingSheet> createState() => _LanSyncPairingSheetState();
}

class _LanSyncPairingSheetState extends State<LanSyncPairingSheet> {
  bool _confirming = false;
  String? _hint;

  ValueListenable<LanSyncPairingPhase> get _phase => widget.event.phase;

  @override
  void initState() {
    super.initState();
    _phase.addListener(_onPhaseChanged);
    // 扫码配对可能在面板弹出之前就已经成功。
    if (_phase.value is LanSyncPairingSucceeded) {
      HapticFeedback.lightImpact();
    }
  }

  @override
  void dispose() {
    _phase.removeListener(_onPhaseChanged);
    super.dispose();
  }

  void _onPhaseChanged() {
    // 配对“生效”的那一刻轻震一下（DESIGN §4.3）；其余阶段变化只重建。
    if (_phase.value is LanSyncPairingSucceeded) {
      HapticFeedback.lightImpact();
    }
    setState(() {});
  }

  Future<void> _confirm() async {
    if (_confirming) return;
    final l10n = context.l10n;
    setState(() {
      _confirming = true;
      _hint = null;
    });
    final outcome = await widget.onConfirm();
    if (!mounted) return;
    setState(() {
      _confirming = false;
      _hint = switch (outcome) {
        LanSyncPairingAuthOutcome.allowed => null,
        LanSyncPairingAuthOutcome.failed => l10n.lanSyncPairAuthFailed,
        LanSyncPairingAuthOutcome.unsupported =>
          l10n.lanSyncPairAuthUnsupported,
      };
    });
  }

  void _close([LanSyncPairingSheetAction? action]) =>
      Navigator.of(context).pop(action);

  Widget _bodyFor(LanSyncPairingPhase phase) {
    final event = widget.event;
    final l10n = context.l10n;
    // 握手之后用对方自报的名字（按地址连接时开始只知道 IP）。
    final peerName = phase.peerName ?? event.peerName;
    switch (phase) {
      case LanSyncPairingConnecting():
        return LanSyncPairingConnectingBody(
          key: const ValueKey<String>('connecting'),
          peerName: event.peerName,
        );
      case LanSyncPairingAwaitingUser(:final code):
      case LanSyncPairingAwaitingPeer(:final code):
        return LanSyncPairingCodeBody(
          key: const ValueKey<String>('code'),
          title: event.direction == LanSyncPairingDirection.incoming
              ? l10n.lanSyncPairTitleIncoming(peerName)
              : l10n.lanSyncPairTitleOutgoing(peerName),
          code: code,
          localPlatform: widget.localPlatform,
          peerPlatform: event.platform,
          waitingPeer: phase is LanSyncPairingAwaitingPeer,
          busy: _confirming,
          hint: _hint,
          onMismatch: _close,
          onConfirm: _confirm,
          onExportBackup: () => _close(LanSyncPairingSheetAction.exportBackup),
        );
      case LanSyncPairingSucceeded():
        return LanSyncPairingSuccessBody(
          key: const ValueKey<String>('succeeded'),
          peerName: peerName,
          onSyncNow: () => _close(LanSyncPairingSheetAction.syncNow),
          onLater: _close,
        );
      case LanSyncPairingFailed(:final reason):
        return LanSyncPairingFailureBody(
          key: const ValueKey<String>('failed'),
          reason: reason,
          onClose: _close,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        4,
        24,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: AnimatedSize(
        duration: ExpressiveMotion.durationNonZero(
          context,
          ExpressiveMotion.medium,
        ),
        curve: ExpressiveMotion.effects,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
          switchInCurve: ExpressiveMotion.effects,
          switchOutCurve: ExpressiveMotion.exit,
          layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
            alignment: Alignment.topCenter,
            children: <Widget>[...previous, ?current],
          ),
          child: _bodyFor(_phase.value),
        ),
      ),
    );
  }
}
