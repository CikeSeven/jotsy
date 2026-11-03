import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
import '../../../core/services/cloud_backup_models.dart';
import '../../../core/services/cloud_backup_service.dart';
import '../../../l10n/app_localizations.dart';
import 'cloud_backup_failure.dart';

/// 网盘备份页面提供给流程的上下文、忙碌态与提示出口。
///
/// 流程开始时取一次 [context]，之后以 `context.mounted` 判断页面是否仍在。
abstract interface class CloudBackupHost {
  BuildContext get context;
  WidgetRef get ref;

  /// 是否已有操作在进行；进行中忽略新的点击。
  bool get busy;

  /// 切换忙碌遮罩；进行中可多次调用以更新文案（传输进度）。
  void setBusy(bool busy, [String text]);
  void showSnack(String message);
}

/// 网盘备份各流程共用的忙碌遮罩与进度换算（完整 ZIP 与增量备份）。
mixin CloudBackupBusyRunner {
  CloudBackupHost get host;

  Future<CloudBackupService> service() =>
      host.ref.read(cloudBackupServiceProvider.future);

  /// 进度只在百分比变化时刷新遮罩文案，避免每个数据块都重建页面。
  CloudBackupProgress progressLabel(String Function(int percent) label) {
    var last = -1;
    return (transferred, total) {
      if (total == null || total <= 0) return;
      final percent = (transferred * 100 ~/ total).clamp(0, 100);
      if (percent == last) return;
      last = percent;
      host.setBusy(true, label(percent));
    };
  }

  Future<bool> runBusy(String busyText, Future<void> Function() action) async {
    var ok = false;
    await runBusyResult(busyText, () async {
      await action();
      ok = true;
      return true;
    });
    return ok;
  }

  /// 在忙碌遮罩下执行；失败时提示并返回 null。
  Future<T?> runBusyResult<T>(
    String busyText,
    Future<T> Function() action,
  ) async {
    if (host.busy) return null;
    final context = host.context;
    host.setBusy(true, busyText);
    try {
      return await action();
    } catch (error) {
      if (context.mounted) {
        host.showSnack(describeCloudBackupError(context.l10n, error));
      }
      return null;
    } finally {
      host.setBusy(false);
    }
  }
}
