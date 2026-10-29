import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/app_service.dart';
import '../core/services/editing_session_registry.dart';
import '../ui/diaries/providers/diary_detail_provider.dart';
import '../ui/diary_templates/providers/diary_template_providers.dart';
import '../ui/notebooks/providers/notebook_providers.dart';

/// 局域网同步写库之后，失效界面里一次性读取的 provider。
///
/// 输入：[EditingSessionRegistry.dataReplaced]；输出：无；副作用：每次事件
/// invalidate 下列 provider，正在显示的页面随之重新读取，没人用的 autoDispose
/// 实例本来就会在下次读取时重查。由应用根组件常驻监听（`NodeDiaryApp`）。
///
/// 为什么只需这几个：Drift `.watch()` 的实时查询在写库后自动重查；这里只管
/// 读一次就不再跟随数据库的读取。逐个审过 `lib/` 里的 provider：
///
/// 失效的（一次性读取同步实体）：
/// - [diaryDetailProvider]（整个 family）：预览页 / 宽窗口右栏、上锁日记页、
///   预览翻页预取、编辑页初值（编辑页是阻塞者，打开期间不会同步，失效无害）；
/// - [diaryNotebooksProvider]（整个 family）：预览页的日记本胶囊；
/// - [userDiaryTemplatesSnapshotProvider]：新建编辑页的模板建议条与面板；
/// - [tagListProvider]：虽然订阅标签表，但自定义顺序取自设置、只在标签表
///   推送时套用；同步改写标签顺序（设置分面 `tagOrderNames`）而标签行未变时
///   不会重排，故一并失效。
///
/// 有意不失效的：
/// - 基于 `.watch()` 的 StreamProvider（日记分页与时间轴、日记本与成员、
///   目录、留言、纪念日、这天的心情、探索、草稿、导出候选等）：自动刷新；
/// - 设置类 Notifier / StreamProvider（卡片、预览页、导航栏、探索、模板偏好、
///   功能开关、日历显示选项、心情选项、标签数量上限等）：桥接
///   `SettingsService` 的 ValueNotifier，同步经设置服务写入即会通知；
/// - 导入字体（`diaryImportedFontsProvider` 等）、更新日志、设置服务、定位、
///   天气、网盘备份：不属于同步数据；
/// - `startupDiariesProvider`：派生自实时的分页查询。
final syncedDataRefreshProvider = Provider<void>((Ref ref) {
  final subscription = EditingSessionRegistry.instance.dataReplaced.listen(
    (_) => _invalidateSyncedSnapshots(ref),
  );
  ref.onDispose(() => unawaited(subscription.cancel()));
});

/// 失效一次性读取的同步数据（清单见 [syncedDataRefreshProvider]）。
void _invalidateSyncedSnapshots(Ref ref) {
  ref
    ..invalidate(diaryDetailProvider)
    ..invalidate(diaryNotebooksProvider)
    ..invalidate(userDiaryTemplatesSnapshotProvider)
    ..invalidate(tagListProvider);
}
