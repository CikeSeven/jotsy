import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_note/core/database/app_database.dart';
import 'package:node_note/core/services/app_service.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsServiceProvider);
    final tagsAsync = ref.watch(tagListProvider);
    final db = ref.watch(appDatabaseProvider);

    return ListView(
      children: <Widget>[
        const ListTile(title: Text('主题模式')),
        settingsAsync.when(
          data: (settingsService) {
            return ValueListenableBuilder<ThemeMode>(
              valueListenable: settingsService.themeModeNotifier,
              builder: (BuildContext context, ThemeMode mode, Widget? child) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SegmentedButton<ThemeMode>(
                      selected: <ThemeMode>{mode},
                      onSelectionChanged: (Set<ThemeMode> selection) {
                        final next = selection.firstOrNull;
                        if (next != null) {
                          settingsService.setThemeMode(next);
                        }
                      },
                      segments: const <ButtonSegment<ThemeMode>>[
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.system,
                          label: Text('系统'),
                          icon: Icon(Icons.settings_suggest_outlined),
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.light,
                          label: Text('浅色'),
                          icon: Icon(Icons.light_mode_outlined),
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.dark,
                          label: Text('深色'),
                          icon: Icon(Icons.dark_mode_outlined),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          loading:
              () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
          error:
              (Object error, StackTrace stackTrace) =>
                  ListTile(title: Text('设置加载失败: $error')),
        ),
        const Divider(),
        const ListTile(
          title: Text('标签管理'),
          subtitle: Text('删除标签会自动解除与日记的关联关系'),
        ),
        tagsAsync.when(
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
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('删除标签'),
                                content: Text('确认删除标签 "${tag.name}" 吗？'),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(false),
                                    child: const Text('取消'),
                                  ),
                                  FilledButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(true),
                                    child: const Text('删除'),
                                  ),
                                ],
                              );
                            },
                          );

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
        ),
      ],
    );
  }
}
