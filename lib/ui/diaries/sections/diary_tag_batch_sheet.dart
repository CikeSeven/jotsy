import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../utils/tri_state_pick.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../controllers/tag_create_flow.dart';
import '../widgets/publish_panel/publish_tag_picker_page.dart';
import '../widgets/publish_panel/publish_tag_row.dart';

export '../../../utils/tri_state_pick.dart';

/// 打开多选日记的标签面板（底部面板）。
///
/// [initial] 为各标签对所选这批日记的三态（经 [triStatePicksFor] 由每篇现有
/// 的标签算出：都有 → 勾选，部分有 → 半选，都没有不列出 → 未选）；
/// [diaryCount] 只用于标题。返回只含变化的结果（`add` 要给每篇都加上，
/// `remove` 要从每篇都去掉）；关掉面板或没有任何改动时为 null。
///
/// 面板只负责挑选，写库、撤销与提示由调用方完成（见
/// `DiariesTagBatchController`）。
Future<TriStatePickResult<int>?> showDiaryTagBatchSheet(
  BuildContext context, {
  required int diaryCount,
  Map<int, TriStatePick> initial = const <int, TriStatePick>{},
}) {
  return showAppModalBottomSheet<TriStatePickResult<int>>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    // 底部面板默认滑入不读取系统“减少动态效果”；该模式下直接出现。
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) =>
        DiaryTagBatchSheet(diaryCount: diaryCount, initial: initial),
  );
}

/// 多选日记的标签面板：标题、检索框与排序、“新建”行、标签列表与底部
/// “完成”。
///
/// - 挑选区复用发布面板的标签子页（[PublishTagPickerPane]：检索、按字母
///   分组与索引条、排序记忆、新建行都与它一致），行为 [PublishTagRow] 的
///   三态；点按循环与日记本选本面板相同（[TriStatePickSelection]）：部分
///   有 → 全部加上 → 全部去掉 → 全部加上 → …，没点过的标签不出现在结果里；
/// - 从检索词新建标签走与发布面板相同的路径（[runCreateTagFlow]），新建
///   出来的标签直接勾选；
/// - 固定为屏高约 75% 的高度（检索使结果变少时面板不跳动），键盘弹出时
///   整块让到键盘上方、高度随之收缩。
class DiaryTagBatchSheet extends ConsumerStatefulWidget {
  const DiaryTagBatchSheet({
    super.key,
    required this.diaryCount,
    this.initial = const <int, TriStatePick>{},
  });

  final int diaryCount;
  final Map<int, TriStatePick> initial;

  @override
  ConsumerState<DiaryTagBatchSheet> createState() => _DiaryTagBatchSheetState();
}

class _DiaryTagBatchSheetState extends ConsumerState<DiaryTagBatchSheet> {
  late final TriStatePickSelection<int> _selection = TriStatePickSelection<int>(
    widget.initial,
  );

  void _toggle(int tagId) => setState(() => _selection.toggle(tagId));

  Future<void> _create(String? name) async {
    final tagId = await runCreateTagFlow(
      context,
      ref.read(appDatabaseProvider),
      initialName: name,
    );
    if (tagId == null || !mounted) return;
    setState(() => _selection.select(tagId));
  }

  void _done() {
    final result = _selection.result;
    Navigator.of(context).pop(result.isEmpty ? null : result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final tags = ref.watch(tagListProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) => SizedBox(
          height: math.min(media.size.height * 0.75, constraints.maxHeight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.xs,
                ),
                child: Text(
                  l10n.diaryTagBatchTitle(widget.diaryCount),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: PublishTagPickerPane(
                  tags: tags,
                  searchPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  onCreateTag: (name) => unawaited(_create(name)),
                  rowBuilder: (context, tag) {
                    final state = _selection.stateOf(tag.id);
                    return PublishTagRow(
                      key: ValueKey<String>('tag_batch_${tag.id}'),
                      tag: tag,
                      selected: state == TriStatePick.all,
                      partial: state == TriStatePick.some,
                      onToggle: (_) => _toggle(tag.id),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.l,
                  AppSpacing.s,
                  AppSpacing.l,
                  media.padding.bottom + AppSpacing.l,
                ),
                child: FilledButton(
                  onPressed: _done,
                  child: Text(l10n.diaryTagBatchDone),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
