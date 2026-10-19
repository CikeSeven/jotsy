import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../calendar/models/calendar_display_enums.dart';
import '../../calendar/providers/calendar_display_options_provider.dart';
import '../../explore/controllers/explore_content_extractor.dart';
import '../viewmodels/notebook_goal_progress.dart';
import '../viewmodels/notebook_view.dart';
import 'notebook_providers.dart';

/// 日记本统计页与写作目标的数据来源。

/// 统计页的日记概览：含归档，不含已删除与未解封的胶囊（与探索页同一口径，
/// 胶囊在解封前不贡献心情、字数与日期）。
final notebookInsightsOverviewsProvider = StreamProvider.autoDispose
    .family<List<ExploreDiaryOverview>, DiaryListScope>(
      (Ref ref, DiaryListScope scope) => ref
          .watch(appDatabaseProvider)
          .watchExploreDiaryOverviews(scope: scope),
    );

/// 统计页的照片数：范围内封面与正文图片的去重来源数（同一张图用在多篇里
/// 只算一次，与探索页媒体画廊的去重一致）。
final notebookPhotoCountProvider = StreamProvider.autoDispose
    .family<int, DiaryListScope>((Ref ref, DiaryListScope scope) {
      const extractor = ExploreContentExtractor();
      return ref.watch(appDatabaseProvider).watchScopedMediaContents(scope).map(
        (List<DiaryMediaContent> rows) {
          final sources = <String>{};
          for (final row in rows) {
            sources.addAll(
              extractor.resolveMediaSourcesFrom(
                cover: row.cover,
                content: row.content,
              ),
            );
          }
          return sources.length;
        },
      );
    });

/// 写作目标里“每周”从星期几开始：沿用日历显示选项的每周起始日，跟随语言
/// 时取本地化的首日（`firstDayOfWeekIndex`，0 为周日）。返回
/// `DateTime.monday`..`DateTime.sunday`。须在 build 期间调用。
int watchGoalFirstWeekday(BuildContext context, WidgetRef ref) {
  final weekStart =
      ref.watch(calendarDisplayOptionsProvider).value?.weekStart ??
      CalendarWeekStart.locale;
  return switch (weekStart) {
    CalendarWeekStart.monday => DateTime.monday,
    CalendarWeekStart.sunday => DateTime.sunday,
    CalendarWeekStart.locale => switch (MaterialLocalizations.of(
      context,
    ).firstDayOfWeekIndex) {
      0 => DateTime.sunday,
      final int index => index,
    },
  };
}

/// [notebook] 的写作目标进度；没有目标、不是普通日记本或数据还没读到时为
/// null。须在 build 期间调用。
///
/// 成员日期取目录页的同一条查询（[notebookContentsProvider]：含归档与未解封
/// 的胶囊，不含回收站），所以没有目标的本子不会多挂任何查询。
NotebookGoalProgress? watchNotebookGoalProgress(
  BuildContext context,
  WidgetRef ref,
  NotebookView notebook, {
  DateTime? now,
}) {
  final goal = notebook.payload.goal;
  if (goal == null || !notebook.isManual) return null;
  final entries = ref.watch(notebookContentsProvider(notebook.id)).value;
  if (entries == null) return null;
  return NotebookGoalProgress.compute(
    goal,
    entries.map((NotebookContentsEntry entry) => entry.createdAt),
    now: now ?? DateTime.now(),
    firstWeekday: watchGoalFirstWeekday(context, ref),
  );
}
