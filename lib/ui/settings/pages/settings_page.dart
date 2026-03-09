import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:node_diary/ui/settings/pages/diary_toolbar_order_page.dart';

import '../../widgets/glass_page_header.dart';

/// 设置页：
/// 1. 主题模式切换；
/// 2. 标签删除管理。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 设置与标签分开监听，确保局部更新。
    final settingsAsync = ref.watch(settingsServiceProvider);
    final tagsAsync = ref.watch(tagListProvider);
    final db = ref.watch(appDatabaseProvider);
    final headerHeight =
        MediaQuery.paddingOf(context).top + GlassPageHeader.contentHeight;

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.only(top: headerHeight),
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
              title: Text('编辑器设置'),
              subtitle: Text('支持自定义富文本工具栏按钮顺序'),
            ),
            settingsAsync.when(
              data: (settingsService) {
                final order = decodeDiaryToolbarOrder(
                  settingsService.diaryToolbarOrderRaw,
                );
                final preview = order
                    .take(4)
                    .map((DiaryToolbarItem item) => item.label)
                    .join(' · ');
                return ListTile(
                  title: const Text('工具栏按钮排序'),
                  subtitle: Text('当前前 4 项：$preview'),
                  trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 14),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) {
                          return DiaryToolbarOrderPage(
                            settingsService: settingsService,
                          );
                        },
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
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                        ),
                                        onPressed:
                                            () => Navigator.of(context).pop(false),
                                        child: const Text('取消'),
                                      ),
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              Theme.of(context).colorScheme.error,
                                        ),
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
        ),
        const GlassPageHeader(title: '设置'),
      ],
    );
  }
}
