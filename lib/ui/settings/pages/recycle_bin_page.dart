import 'dart:async';

import 'package:flutter/material.dart';
import 'package:node_diary/ui/widgets/delayed_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/notebooks/providers/notebook_providers.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';
import 'package:node_diary/ui/widgets/empty_hint.dart';
import 'package:node_diary/ui/widgets/list_item_presence.dart';

/// 回收站页面：
/// - 展示已软删除日记；
/// - 支持多选恢复；
/// - 支持多选彻底删除。
class RecycleBinPage extends ConsumerStatefulWidget {
  const RecycleBinPage({super.key});

  @override
  ConsumerState<RecycleBinPage> createState() => _RecycleBinPageState();
}

class _RecycleBinPageState extends ConsumerState<RecycleBinPage> {
  final Set<String> _selectedDiaryIds = <String>{};
  bool _operating = false;

  /// 恢复/彻底删除时正在播放收起动画、等待提交的条目；数据流确认移除后在
  /// build 中清理，提交失败的条目会重新展开。
  final Set<String> _pendingHideDiaryIds = <String>{};

  /// 先收起条目再提交数据库：数据流随后移除条目时它已收成 0 高度，列表不会
  /// 硬跳；减少动画时时长为 0，立即提交。
  Future<void> _collapseBeforeCommit(List<String> diaryIds) async {
    setState(() => _pendingHideDiaryIds.addAll(diaryIds));
    await Future<void>.delayed(
      ExpressiveMotion.duration(context, ExpressiveMotion.medium),
    );
  }

  bool get _hasSelection => _selectedDiaryIds.isNotEmpty;

  String _formatDeletedAt(DateTime? deletedAt) {
    if (deletedAt == null) {
      return context.l10n.autoT0025;
    }
    return DateFormat(
      'yyyy-MM-dd HH:mm',
      Localizations.localeOf(context).toLanguageTag(),
    ).format(deletedAt.toLocal());
  }

  void _toggleSelection(String diaryId) {
    if (_operating) {
      return;
    }
    setState(() {
      if (_selectedDiaryIds.contains(diaryId)) {
        _selectedDiaryIds.remove(diaryId);
      } else {
        _selectedDiaryIds.add(diaryId);
      }
    });
  }

  Future<void> _restoreSelected() async {
    if (!_hasSelection || _operating) {
      return;
    }
    final targetIds = _selectedDiaryIds.toList(growable: false);
    setState(() => _operating = true);
    try {
      await _collapseBeforeCommit(targetIds);
      if (!mounted) {
        return;
      }
      final db = ref.read(appDatabaseProvider);
      final failedIds = <String>[];
      for (final diaryId in targetIds) {
        try {
          await db.restoreDiary(diaryId, touchUpdatedAt: false);
        } catch (_) {
          failedIds.add(diaryId);
        }
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _selectedDiaryIds.removeAll(
          targetIds.where((id) => !failedIds.contains(id)),
        );
        // 提交失败的条目仍在数据中，取消收起使其重新展开。
        _pendingHideDiaryIds.removeAll(failedIds);
      });

      if (failedIds.isEmpty) {
        await _showHint(context.l10n.autoT0191(targetIds.length.toString()));
        return;
      }
      await _showHint(context.l10n.autoT0026);
    } finally {
      if (mounted) {
        setState(() => _operating = false);
      }
    }
  }

  Future<void> _purgeSelected() async {
    if (!_hasSelection || _operating) {
      return;
    }
    final targetIds = _selectedDiaryIds.toList(growable: false);
    final confirmed = await _confirmPurge(targetIds.length);
    if (!mounted || !confirmed) {
      return;
    }

    setState(() => _operating = true);
    try {
      await _collapseBeforeCommit(targetIds);
      if (!mounted) {
        return;
      }
      final db = ref.read(appDatabaseProvider);
      // 先取出服务：循环期间页面可能已销毁，之后不能再使用 ref。
      final mediaCleanup = ref.read(diaryMediaCleanupServiceProvider);
      final failedIds = <String>[];
      for (final diaryId in targetIds) {
        try {
          await db.hardDeleteDiary(diaryId);
        } catch (_) {
          failedIds.add(diaryId);
        }
      }
      // 彻底删除只移除记录，文件按引用在后台回收，不阻塞删除结果提示。
      if (failedIds.length < targetIds.length) {
        unawaited(mediaCleanup.sweep());
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _selectedDiaryIds.removeAll(
          targetIds.where((id) => !failedIds.contains(id)),
        );
        // 提交失败的条目仍在数据中，取消收起使其重新展开。
        _pendingHideDiaryIds.removeAll(failedIds);
      });

      if (failedIds.isEmpty) {
        await _showHint(context.l10n.autoT0192(targetIds.length.toString()));
        return;
      }
      await _showHint(context.l10n.autoT0027);
    } finally {
      if (mounted) {
        setState(() => _operating = false);
      }
    }
  }

  Future<bool> _confirmPurge(int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(context.l10n.autoT0028),
          content: Text(context.l10n.autoT0193(count.toString())),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.commonCancel),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: colorScheme.error),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(context.l10n.commonDelete),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Future<void> _showHint(String message) async {
    await HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final deletedAsync = ref.watch(deletedDiariesProvider);
    // 私密日记本里的日记不露出标题，只显示占位（仍可勾选恢复或彻底删除）。
    final privateIds =
        ref.watch(privateDiaryIdsProvider).value ?? const <String>{};

    return Scaffold(
      appBar: AppTopBar(
        leading: IconButton(
          tooltip: l10n.commonBack,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
        ),
        // 进入/退出多选、选择数量变化时标题淡入淡出，而不是硬切。
        title: AnimatedSwitcher(
          duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
          switchInCurve: ExpressiveMotion.effects,
          switchOutCurve: ExpressiveMotion.exit,
          child: Text(
            _hasSelection
                ? l10n.autoT0099(_selectedDiaryIds.length.toString())
                : l10n.autoT0029,
            key: ValueKey<int>(_hasSelection ? _selectedDiaryIds.length : -1),
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.autoT0030,
            onPressed: _hasSelection && !_operating ? _restoreSelected : null,
            icon: const FaIcon(FontAwesomeIcons.arrowRotateLeft, size: 16),
          ),
          IconButton(
            tooltip: l10n.autoT0028,
            onPressed: _hasSelection && !_operating ? _purgeSelected : null,
            icon: FaIcon(
              FontAwesomeIcons.trashCan,
              size: 16,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
      body: deletedAsync.when(
        loading: () => const DelayedLoadingIndicator(),
        error: (error, stackTrace) =>
            Center(child: Text(l10n.autoT0031(error.toString()))),
        data: (diaries) {
          final currentIds = <String>{
            for (final diary in diaries) diary.diary.diaryId,
          };
          _pendingHideDiaryIds.removeWhere((id) => !currentIds.contains(id));
          final itemDuration = ExpressiveMotion.duration(
            context,
            ExpressiveMotion.medium,
          );
          // 最后一条移走后与空态交叉淡入。
          return AnimatedSwitcher(
            duration: itemDuration,
            switchInCurve: ExpressiveMotion.effects,
            switchOutCurve: ExpressiveMotion.exit,
            child: diaries.isEmpty
                ? EmptyHint(
                    key: const ValueKey<String>('recycle_empty'),
                    icon: FontAwesomeIcons.trashCan,
                    message: l10n.autoT0032,
                  )
                : ListView.separated(
                    key: const ValueKey<String>('recycle_list'),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: diaries.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (BuildContext context, int index) {
                      final diary = diaries[index].diary;
                      final selected = _selectedDiaryIds.contains(
                        diary.diaryId,
                      );
                      final isPrivate = privateIds.contains(diary.diaryId);
                      final title = isPrivate
                          ? l10n.notebookPrivateDiaryPlaceholder
                          : diary.title.trim().isEmpty
                          ? l10n.autoT0033
                          : diary.title.trim();
                      return ListItemPresence(
                        key: ValueKey<String>('recycle_${diary.diaryId}'),
                        visible: !_pendingHideDiaryIds.contains(diary.diaryId),
                        appearing: false,
                        duration: itemDuration,
                        child: ListTile(
                          onTap: () => _toggleSelection(diary.diaryId),
                          onLongPress: () => _toggleSelection(diary.diaryId),
                          leading: Checkbox(
                            value: selected,
                            onChanged: (_) => _toggleSelection(diary.diaryId),
                          ),
                          title: Row(
                            children: <Widget>[
                              if (isPrivate) ...<Widget>[
                                FaIcon(
                                  FontAwesomeIcons.lock,
                                  size: 13,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            l10n.autoT0194(_formatDeletedAt(diary.deletedAt)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
