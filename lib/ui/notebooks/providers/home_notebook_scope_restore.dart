import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_features.dart';
import '../../../core/services/app_service.dart';
import '../controllers/notebook_lock_flow.dart';
import '../models/home_notebook_scope_memory.dart';
import '../viewmodels/notebook_tree.dart';
import 'home_notebook_scope_provider.dart';

/// 冷启动时恢复首页“日记”页上次所在的范围（[HomeNotebookScopeMemory]）。
///
/// 输入：设置服务（本机偏好 `app.settings.home_last_scope` 与功能开关）、
/// 数据库里的书架（只读一次）。输出：恢复后的范围解析（与日记页实时解析
/// 同一口径，见 [resolveHomeNotebookScope]）；无副作用，结果由
/// `HomeNotebookScopeNotifier` 采用、启动预热 `startupDiariesProvider` 按它
/// 查询首屏，启动门控因此等它完成才显示首页。
///
/// 恢复规则（任何一条不满足都静默回到全部日记，不提示“日记本已删除”）：
/// - 没有记录、记录认不出、日记本功能已关闭；
/// - 日记本已不存在（删除、并入别的本子、覆盖恢复了别的数据）；
/// - 记下的章节已不存在时只回到这本的全部章节，本子没有章节时“未分章”
///   同样作废；
/// - 生效可见性为上锁（含上级上了锁的子本）时以重锁状态恢复：
///   `NotebookLockLayer` 从首帧起盖住整个应用，验证通过才揭开，选“回到全部
///   日记”或连续验证失败则回到全部日记。隐藏的本子不需要验证，照常恢复。
///
/// 只算一次：只订阅设置服务本身（加载后实例不变），功能开关与书架都只读
/// 当时的值——之后它们怎么变都不该让它重算，否则采用它的范围会被重置。
/// 读失败一律按全部日记处理。
final homeNotebookScopeRestoreProvider =
    FutureProvider<HomeNotebookScopeResolution>((Ref ref) async {
      try {
        final settings = await ref.watch(settingsServiceProvider.future);
        final memory = HomeNotebookScopeMemory.decode(
          settings.homeLastScopeRaw,
        );
        if (memory == null ||
            !AppFeatures.decode(
              settings.appFeaturesRawNotifier.value,
            ).notebooks) {
          return HomeNotebookScopeResolution.all;
        }
        if (memory.unfiled) {
          return resolveHomeNotebookScope(HomeNotebookScope.unfiledScope, null);
        }
        final tree = NotebookTree(
          await ref.read(appDatabaseProvider).getNotebooks(),
        );
        final notebook = tree[memory.notebookId!];
        if (notebook == null) {
          return HomeNotebookScopeResolution.all;
        }
        final chapters = notebook.payload.chapters;
        final chapterId = chapters.any((c) => c.id == memory.chapterId)
            ? memory.chapterId
            : null;
        return resolveHomeNotebookScope(
          HomeNotebookScope(
            notebookId: notebook.id,
            chapterId: chapterId,
            unassignedChapterOnly:
                chapterId == null &&
                memory.unassignedChapterOnly &&
                chapters.isNotEmpty,
            relocked: notebookRequiresAuth(notebook),
          ),
          tree,
        );
      } catch (error) {
        debugPrint('Restoring the home notebook scope failed: $error');
        return HomeNotebookScopeResolution.all;
      }
    });
