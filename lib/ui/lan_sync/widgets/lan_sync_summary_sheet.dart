// 同步完成摘要（DESIGN.md §5.28“同步完成摘要”）：手动同步结束时的底部面板，
// 只负责展示与收集点按。按摘要分三种内容（各自的画法在
// lan_sync_summary_bodies.dart）：
// - 成功且有变化：对勾徽章、“同步完成”、“与 X · 用时 N 秒”、收到 / 发出
//   两列统计卡、冲突副本（有时）、“标签、日记本…已一并合并”、整宽“完成”；
// - 成功但两边都没变化：只有对勾、“已经是最新的了”与“完成”；
// - 失败：`error` 色 `circleExclamation`、“同步没有完成”、原因与下一步、
//   “重试”与“关闭”。
// 成功时面板出现的那一刻 `lightImpact`（同步“生效”，DESIGN §4.3），对勾的
// 弹性放大由 [LanSyncSuccessBadge] 自己播放。
//
// 关闭面板的结果交给调用方（lan_sync_session_flow.dart）：
// [LanSyncSummaryOutcome]，或 null（完成、关闭、下滑关掉）。打开冲突副本
// 也先关掉面板再由调用方经 `openDiaryPage` 打开，预览页不叠在面板下面。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../models/lan_sync_session_summary.dart';
import 'lan_sync_summary_bodies.dart';

/// 面板关闭后要调用方接着做的事。
@immutable
sealed class LanSyncSummaryOutcome {
  const LanSyncSummaryOutcome();
}

/// 失败面板的“重试”。
final class LanSyncSummaryRetry extends LanSyncSummaryOutcome {
  const LanSyncSummaryRetry();
}

/// 点了一条冲突副本。
final class LanSyncSummaryOpenCopy extends LanSyncSummaryOutcome {
  const LanSyncSummaryOpenCopy(this.diaryId);

  final String diaryId;
}

/// 弹出摘要面板；返回关闭时选的后续动作。
Future<LanSyncSummaryOutcome?> showLanSyncSummarySheet(
  BuildContext context, {
  required LanSyncSessionSummary summary,
}) {
  return showAppModalBottomSheet<LanSyncSummaryOutcome>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 640),
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext context) => LanSyncSummarySheet(summary: summary),
  );
}

/// 摘要面板本体；由 [showLanSyncSummarySheet] 承载。
class LanSyncSummarySheet extends StatefulWidget {
  const LanSyncSummarySheet({super.key, required this.summary});

  final LanSyncSessionSummary summary;

  @override
  State<LanSyncSummarySheet> createState() => _LanSyncSummarySheetState();
}

class _LanSyncSummarySheetState extends State<LanSyncSummarySheet> {
  @override
  void initState() {
    super.initState();
    if (widget.summary.succeeded) HapticFeedback.lightImpact();
  }

  void _close([LanSyncSummaryOutcome? outcome]) =>
      Navigator.of(context).pop(outcome);

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final reason = summary.failureReason;
    final Widget body;
    if (reason != null) {
      body = LanSyncSummaryFailureBody(
        reason: reason,
        onRetry: () => _close(const LanSyncSummaryRetry()),
        onClose: _close,
      );
    } else if (summary.upToDate) {
      body = LanSyncSummaryUpToDateBody(onDone: _close);
    } else {
      body = LanSyncSummarySuccessBody(
        summary: summary,
        onOpenCopy: (String id) => _close(LanSyncSummaryOpenCopy(id)),
        onDone: _close,
      );
    }
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        4,
        24,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: body,
    );
  }
}
