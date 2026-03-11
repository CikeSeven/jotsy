import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/core/database/app_database.dart';

/// 设置页标签管理区块。
///
/// 职责：
/// - 展示标签列表；
/// - 承接删除确认交互；
/// - 执行标签删除。
class SettingsTagManagementSection extends StatelessWidget {
  const SettingsTagManagementSection({
    super.key,
    required this.tagsAsync,
    required this.db,
  });

  final AsyncValue<List<Tag>> tagsAsync;
  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    return tagsAsync.when(
      data: (List<Tag> tags) {
        if (tags.isEmpty) {
          return const ListTile(title: Text('暂无标签'));
        }

        return Column(
          children:
              tags.map((Tag tag) {
                return ListTile(
                  leading: CircleAvatar(backgroundColor: Color(tag.color)),
                  title: Text(tag.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: '删除标签',
                    onPressed: () async {
                      final confirmed = await _confirmDeleteTag(context, tag);
                      if (confirmed == true) {
                        await db.deleteTag(tag.id);
                      }
                    },
                  ),
                );
              }).toList(),
        );
      },
      loading:
          () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
      error:
          (Object error, StackTrace stackTrace) =>
              ListTile(title: Text('标签加载失败: $error')),
    );
  }

  Future<bool?> _confirmDeleteTag(BuildContext context, Tag tag) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('删除标签'),
          content: Text('确认删除标签 "${tag.name}" 吗？'),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor:
                    Theme.of(dialogContext).colorScheme.onSurfaceVariant,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }
}
