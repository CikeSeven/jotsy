import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';

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

  bool get _hasSelection => _selectedDiaryIds.isNotEmpty;

  String _formatDeletedAt(DateTime? deletedAt) {
    if (deletedAt == null) {
      return context.l10n.tr('删除时间未知', en: 'Unknown deleted time');
    }
    final locale = Localizations.localeOf(context);
    final pattern = locale.languageCode == 'zh' ? 'yyyy-MM-dd HH:mm' : 'yyyy-MM-dd HH:mm';
    return DateFormat(pattern, locale.toLanguageTag()).format(deletedAt.toLocal());
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
        _selectedDiaryIds.removeAll(targetIds.where((id) => !failedIds.contains(id)));
      });

      if (failedIds.isEmpty) {
        await _showHint(
          context.l10n.tr(
            '已恢复 ${targetIds.length} 条日记',
            en: 'Restored ${targetIds.length} diaries',
          ),
        );
        return;
      }
      await _showHint(
        context.l10n.tr('部分恢复失败，请重试', en: 'Some restores failed. Please retry.'),
      );
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
      final db = ref.read(appDatabaseProvider);
      final failedIds = <String>[];
      for (final diaryId in targetIds) {
        try {
          await db.hardDeleteDiary(diaryId);
        } catch (_) {
          failedIds.add(diaryId);
        }
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _selectedDiaryIds.removeAll(targetIds.where((id) => !failedIds.contains(id)));
      });

      if (failedIds.isEmpty) {
        await _showHint(
          context.l10n.tr(
            '已彻底删除 ${targetIds.length} 条日记',
            en: 'Permanently deleted ${targetIds.length} diaries',
          ),
        );
        return;
      }
      await _showHint(
        context.l10n.tr('部分删除失败，请重试', en: 'Some deletions failed. Please retry.'),
      );
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
          title: Text(context.l10n.tr('彻底删除', en: 'Permanent delete')),
          content: Text(
            context.l10n.tr(
              '确认彻底删除已选择的 $count 条日记吗？删除后不可恢复。',
              en: 'Permanently delete $count selected diaries? This cannot be undone.',
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.commonCancel),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.error,
              ),
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.commonBack,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
        ),
        title: Text(
          _hasSelection
              ? l10n.tr(
                  '已选择 ${_selectedDiaryIds.length} 项',
                  en: '${_selectedDiaryIds.length} selected',
                )
              : l10n.tr('回收站', en: 'Recycle bin'),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.tr('恢复', en: 'Restore'),
            onPressed: _hasSelection && !_operating ? _restoreSelected : null,
            icon: const FaIcon(FontAwesomeIcons.arrowRotateLeft, size: 16),
          ),
          IconButton(
            tooltip: l10n.tr('彻底删除', en: 'Permanent delete'),
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(
            l10n.tr('回收站加载失败: $error', en: 'Recycle bin load failed: $error'),
          ),
        ),
        data: (diaries) {
          if (diaries.isEmpty) {
            return Center(child: Text(l10n.tr('回收站为空', en: 'Recycle bin is empty')));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: diaries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) {
              final diary = diaries[index].diary;
              final selected = _selectedDiaryIds.contains(diary.diaryId);
              final title = diary.title.trim().isEmpty
                  ? l10n.tr('无标题', en: 'Untitled')
                  : diary.title.trim();
              return ListTile(
                onTap: () => _toggleSelection(diary.diaryId),
                onLongPress: () => _toggleSelection(diary.diaryId),
                leading: Checkbox(
                  value: selected,
                  onChanged: (_) => _toggleSelection(diary.diaryId),
                ),
                title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  l10n.tr(
                    '删除于 ${_formatDeletedAt(diary.deletedAt)}',
                    en: 'Deleted at ${_formatDeletedAt(diary.deletedAt)}',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
