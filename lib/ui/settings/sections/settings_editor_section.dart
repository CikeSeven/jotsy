import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:node_diary/ui/settings/pages/diary_toolbar_order_page.dart';

/// 设置页编辑器配置区块。
class SettingsEditorSection extends StatelessWidget {
  const SettingsEditorSection({
    super.key,
    required this.settingsAsync,
  });

  final AsyncValue<SettingsService> settingsAsync;

  @override
  Widget build(BuildContext context) {
    return settingsAsync.when(
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
    );
  }
}
