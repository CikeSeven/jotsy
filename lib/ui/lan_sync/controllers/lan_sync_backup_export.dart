// 配对面板“先导出完整备份”借用数据管理页的导出流程
// （`DataManagementController.exportAll`：可选密码 → 生成 ZIP → 系统保存），
// 不另写一份导出。
//
// - 输入：同步页的 context 取值、WidgetRef；
// - 输出：[busyText]——导出进行中为步骤文案，否则为 null，同步页据此画
//   `ActionLoadingOverlay`；
// - 副作用：弹密码对话框、写文件、经 showTrackedSnackBar 提示结果。
//
// 页面销毁后导出可能仍在进行：流程里每步都先看 `context.mounted`，这里的
// 忙碌态与提示在 [dispose] 之后一律忽略。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../settings/controllers/data_management_controller.dart';

/// 见文件头注释。
class LanSyncBackupExport implements DataManagementHost {
  LanSyncBackupExport({required this._contextOf, required this.ref});

  final BuildContext Function() _contextOf;

  @override
  final WidgetRef ref;

  /// 导出进行中的步骤文案；null 为空闲。
  final ValueNotifier<String?> busyText = ValueNotifier<String?>(null);

  /// 遮罩淡出期间保留上一条文案（与数据管理页相同）。
  String lastBusyText = '';

  bool _disposed = false;
  late final DataManagementController _controller = DataManagementController(
    this,
  );

  /// 开始导出；已有导出在进行时忽略。
  Future<void> run() => _controller.exportAll();

  @override
  BuildContext get context => _contextOf();

  @override
  bool get busy => busyText.value != null;

  @override
  void setBusy(bool busy, [String text = '']) {
    if (_disposed) return;
    if (busy) lastBusyText = text;
    busyText.value = busy ? text : null;
  }

  @override
  void showSnack(String message) {
    if (_disposed) return;
    final context = _contextOf();
    if (!context.mounted) return;
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: context,
        snackBar: SnackBar(content: Text(message)),
      ),
    );
  }

  void dispose() {
    _disposed = true;
    busyText.dispose();
  }
}
