import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
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
      return context.l10n.autoT0025;
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
          context.l10n.autoT0191(targetIds.length.toString()),
        );
        return;
      }
      await _showHint(
        context.l10n.autoT0026,
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
          context.l10n.autoT0192(targetIds.length.toString()),
        );
        return;
      }
      await _showHint(
        context.l10n.autoT0027,
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
          title: Text(context.l10n.autoT0028),
          content: Text(
            context.l10n.autoT0193(count.toString()),
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
              ? l10n.autoT0099(_selectedDiaryIds.length.toString())
              : l10n.autoT0029,
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(
            l10n.autoT0031(error.toString()),
          ),
        ),
        data: (diaries) {
          if (diaries.isEmpty) {
            return Center(child: Text(l10n.autoT0032));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: diaries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) {
              final diary = diaries[index].diary;
              final selected = _selectedDiaryIds.contains(diary.diaryId);
              final title = diary.title.trim().isEmpty
                  ? l10n.autoT0033
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
                  l10n.autoT0194(_formatDeletedAt(diary.deletedAt)),
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
