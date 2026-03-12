import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/settings/pages/recycle_bin_page.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/ui/settings/pages/data_management_page.dart';
import 'package:node_diary/ui/settings/pages/tag_management_page.dart';
import 'package:node_diary/ui/settings/sections/settings_editor_section.dart';
import 'package:node_diary/ui/settings/sections/settings_theme_section.dart';

import '../../widgets/glass_bottom_nav.dart';
import '../../widgets/glass_page_header.dart';

/// 设置页：
/// 1. 主题模式切换；
/// 2. 标签删除管理。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 设置项分开监听，确保局部更新。
    final settingsAsync = ref.watch(settingsServiceProvider);
    final headerHeight =
        MediaQuery.paddingOf(context).top + GlassPageHeader.contentHeight;
    final listBottomPadding =
        MediaQuery.paddingOf(context).bottom +
        GlassBottomNav.navHeight +
        GlassBottomNav.navBottomInset +
        12;

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.only(
            top: headerHeight,
            bottom: listBottomPadding,
          ),
          children: <Widget>[
            const ListTile(title: Text('主题模式')),
            SettingsThemeSection(
              settingsAsync: settingsAsync,
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                '编辑器设置',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SettingsEditorSection(
              settingsAsync: settingsAsync,
            ),
            const Divider(),
            ListTile(
              title: const Text('数据管理'),
              subtitle: const Text('导入/导出 zip 备份文件'),
              trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) {
                      return const DataManagementPage();
                    },
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              title: Text('标签管理'),
              subtitle: Text('删除标签会自动解除与日记的关联关系'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) {
                      return const TagManagementPage();
                    },
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              title: const Text('回收站'),
              subtitle: const Text('管理已删除日记，可恢复或彻底删除'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) {
                      return const RecycleBinPage();
                    },
                  ),
                );
              },
            ),
          ],
        ),
        const GlassPageHeader(title: '设置'),
      ],
    );
  }
}
