import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
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
      return '删除时间未知';
    }
    return DateFormat('yyyy-MM-dd HH:mm').format(deletedAt.toLocal());
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
        await _showHint('已恢复 ${targetIds.length} 条日记');
        return;
      }
      await _showHint('部分恢复失败，请重试');
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
        await _showHint('已彻底删除 ${targetIds.length} 条日记');
        return;
      }
      await _showHint('部分删除失败，请重试');
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
          title: const Text('彻底删除'),
          content: Text('确认彻底删除已选择的 $count 条日记吗？删除后不可恢复。'),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
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
    final deletedAsync = ref.watch(deletedDiariesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
        ),
        title: Text(_hasSelection ? '已选择 ${_selectedDiaryIds.length} 项' : '回收站'),
        actions: <Widget>[
          IconButton(
            tooltip: '恢复',
            onPressed: _hasSelection && !_operating ? _restoreSelected : null,
            icon: const FaIcon(FontAwesomeIcons.arrowRotateLeft, size: 16),
          ),
          IconButton(
            tooltip: '彻底删除',
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
        error: (error, stackTrace) => Center(child: Text('回收站加载失败: $error')),
        data: (diaries) {
          if (diaries.isEmpty) {
            return const Center(child: Text('回收站为空'));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: diaries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) {
              final diary = diaries[index].diary;
              final selected = _selectedDiaryIds.contains(diary.diaryId);
              final title = diary.title.trim().isEmpty ? '无标题' : diary.title.trim();
              return ListTile(
                onTap: () => _toggleSelection(diary.diaryId),
                onLongPress: () => _toggleSelection(diary.diaryId),
                leading: Checkbox(
                  value: selected,
                  onChanged: (_) => _toggleSelection(diary.diaryId),
                ),
                title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '删除于 ${_formatDeletedAt(diary.deletedAt)}',
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
