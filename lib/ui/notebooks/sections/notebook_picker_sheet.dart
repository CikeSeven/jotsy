import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../models/notebook_pick_selection.dart';
import '../providers/notebook_providers.dart';
import '../viewmodels/notebook_view.dart';
import '../widgets/notebook_pick_row.dart';
import 'notebook_quick_create_dialog.dart';

export '../models/notebook_pick_selection.dart';

/// 收录选择器的两种用法。
///
/// - [multi]：勾选框语义，可多选，底部“完成”提交；批量时每本为三态；
/// - [single]：“移动到…”，点一本即选定返回（当前日记本不列出）。
enum NotebookPickerMode { multi, single }

/// 选择器里列出的日记本：没合上的普通日记本，按书架顺序。智能日记本按规则
/// 收录、合上的日记本不再接收新的日记，都不提供；[excludedIds] 另外排除
/// （“移动到…”排除当前这本）。
List<NotebookView> notebookPickCandidates(
  List<NotebookView> notebooks, {
  Set<String> excludedIds = const <String>{},
}) => <NotebookView>[
  for (final notebook in notebooks)
    if (notebook.isManual &&
        !notebook.isClosed &&
        !excludedIds.contains(notebook.id))
      notebook,
];

/// 打开收录选择器（底部面板）。
///
/// [initial] 为各本对这批日记的三态（见 [notebookPickStatesFor]），没列出的
/// 按“都不在”。返回只含变化的 [NotebookPickerResult]；关掉面板或没有任何
/// 改动时为 null。单选模式下结果的 `add` 恰好一本。
///
/// 面板只负责挑选，写库与提示由调用方完成（见 `NotebookMembershipOps`）。
Future<NotebookPickerResult?> showNotebookPickerSheet(
  BuildContext context, {
  NotebookPickerMode mode = NotebookPickerMode.multi,
  Map<String, NotebookPickState> initial = const <String, NotebookPickState>{},
  String? title,
  Set<String> excludedIds = const <String>{},
}) {
  return showAppModalBottomSheet<NotebookPickerResult>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    // 底部面板默认滑入不读取系统“减少动态效果”；该模式下直接出现。
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) => NotebookPickerSheet(
      mode: mode,
      initial: initial,
      title: title,
      excludedIds: excludedIds,
    ),
  );
}

/// 收进私密日记本后的提示：这些日记从此只在那本里显示（不在全部日记里）。
/// [added] 里没有隐藏或上锁的日记本时返回 null。
String? notebookPrivateAddedHint(
  AppLocalizations l10n,
  Iterable<String> added,
  List<NotebookView> notebooks,
) {
  for (final notebook in notebooks) {
    if (added.contains(notebook.id) &&
        notebook.visibility != NotebookVisibility.normal) {
      return l10n.notebookPickerPrivateHint(notebook.name);
    }
  }
  return null;
}

/// 收录选择器面板的内容：标题、“＋ 新建日记本”、日记本列表与底部“完成”。
/// 高度随内容，最高约屏高的 75%，列表在其中滚动。
class NotebookPickerSheet extends ConsumerStatefulWidget {
  const NotebookPickerSheet({
    super.key,
    required this.mode,
    this.initial = const <String, NotebookPickState>{},
    this.title,
    this.excludedIds = const <String>{},
  });

  final NotebookPickerMode mode;
  final Map<String, NotebookPickState> initial;
  final String? title;
  final Set<String> excludedIds;

  @override
  ConsumerState<NotebookPickerSheet> createState() =>
      _NotebookPickerSheetState();
}

class _NotebookPickerSheetState extends ConsumerState<NotebookPickerSheet> {
  late final NotebookPickSelection _selection = NotebookPickSelection(
    widget.initial,
  );

  bool get _single => widget.mode == NotebookPickerMode.single;

  void _tap(String notebookId) {
    if (_single) {
      Navigator.of(
        context,
      ).pop(NotebookPickerResult(add: <String>{notebookId}));
      return;
    }
    setState(() => _selection.toggle(notebookId));
  }

  /// 新建后直接选中：多选时勾上（列表随数据库流出现这一行），单选时就是
  /// 选定的目标。
  Future<void> _create() async {
    final id = await showQuickCreateNotebookDialog(context);
    if (id == null || !mounted) return;
    if (_single) {
      Navigator.of(context).pop(NotebookPickerResult(add: <String>{id}));
      return;
    }
    setState(() => _selection.select(id));
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
    final notebooks = ref.watch(notebooksProvider).value;
    final counts =
        ref.watch(notebookEntryCountsProvider).value ?? const <String, int>{};
    final candidates = notebooks == null
        ? null
        : notebookPickCandidates(notebooks, excludedIds: widget.excludedIds);
    final bottomInset = media.padding.bottom + AppSpacing.l;

    final Widget list;
    if (candidates == null) {
      list = const SizedBox(height: 160, child: DelayedLoadingIndicator());
    } else {
      list = ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          _single ? bottomInset : AppSpacing.s,
        ),
        children: <Widget>[
          NotebookPickCreateRow(onTap: () => unawaited(_create())),
          if (candidates.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.l,
              ),
              child: Text(
                l10n.notebookPickerEmpty,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          for (final notebook in candidates)
            NotebookPickRow(
              key: ValueKey<String>('notebook_pick_${notebook.id}'),
              notebook: notebook,
              count: counts[notebook.id] ?? 0,
              state: _selection.stateOf(notebook.id),
              showCheck: !_single,
              onTap: () => _tap(notebook.id),
            ),
        ],
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.75),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.m,
            ),
            child: Text(
              widget.title ?? l10n.notebookPickerTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Flexible(child: list),
          if (!_single)
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.l,
                AppSpacing.s,
                AppSpacing.l,
                bottomInset,
              ),
              child: FilledButton(
                onPressed: _done,
                child: Text(l10n.notebookPickerDone),
              ),
            ),
        ],
      ),
    );
  }
}
