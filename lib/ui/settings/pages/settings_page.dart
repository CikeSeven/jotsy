import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/ui/settings/sections/settings_editor_section.dart';
import 'package:node_diary/ui/settings/sections/settings_tag_management_section.dart';
import 'package:node_diary/ui/settings/sections/settings_theme_section.dart';

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
            SettingsThemeSection(
              settingsAsync: settingsAsync,
            ),
            const Divider(),
            const ListTile(
              title: Text('编辑器设置'),
              subtitle: Text('支持自定义富文本工具栏按钮顺序'),
            ),
            SettingsEditorSection(
              settingsAsync: settingsAsync,
            ),
            const Divider(),
            const ListTile(
              title: Text('标签管理'),
              subtitle: Text('删除标签会自动解除与日记的关联关系'),
            ),
            SettingsTagManagementSection(
              tagsAsync: tagsAsync,
              db: db,
            ),
          ],
        ),
        const GlassPageHeader(title: '设置'),
      ],
    );
  }
}
