import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
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
    final l10n = context.l10n;
    return settingsAsync.when(
      data: (settingsService) {
        final order = decodeDiaryToolbarOrder(
          settingsService.diaryToolbarOrderRaw,
        );
        final preview = order
            .take(4)
            .map((DiaryToolbarItem item) => _labelForItem(context, item))
            .join(' · ');
        return ListTile(
          title: Text(l10n.tr('工具栏按钮排序', en: 'Toolbar order')),
          subtitle: Text(l10n.tr('当前前 4 项：$preview', en: 'Current top 4: $preview')),
          trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
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
          () => Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: LoadingIndicatorM3E(
                variant: LoadingIndicatorM3EVariant.contained,
                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                semanticLabel: l10n.dataMgmtBusyLabel,
              ),
            ),
          ),
      error:
           (Object error, StackTrace stackTrace) =>
              ListTile(title: Text(l10n.tr('设置加载失败: $error', en: 'Settings load failed: $error'))),
    );
  }

  String _labelForItem(BuildContext context, DiaryToolbarItem item) {
    final l10n = context.l10n;
    return switch (item) {
      DiaryToolbarItem.undo => l10n.tr('撤销', en: 'Undo'),
      DiaryToolbarItem.redo => l10n.tr('重做', en: 'Redo'),
      DiaryToolbarItem.bold => l10n.tr('加粗', en: 'Bold'),
      DiaryToolbarItem.italic => l10n.tr('斜体', en: 'Italic'),
      DiaryToolbarItem.underline => l10n.tr('下划线', en: 'Underline'),
      DiaryToolbarItem.strikeThrough => l10n.tr('删除线', en: 'Strikethrough'),
      DiaryToolbarItem.inlineCode => l10n.tr('行内代码（单行）', en: 'Inline code'),
      DiaryToolbarItem.textColor => l10n.tr('文字颜色', en: 'Text color'),
      DiaryToolbarItem.backgroundColor => l10n.tr('背景颜色', en: 'Background color'),
      DiaryToolbarItem.clearFormat => l10n.tr('清除格式', en: 'Clear formatting'),
      DiaryToolbarItem.image => l10n.tr('插入图片', en: 'Insert image'),
      DiaryToolbarItem.headerStyle => l10n.tr('标题样式', en: 'Header style'),
      DiaryToolbarItem.orderedList => l10n.tr('有序列表', en: 'Ordered list'),
      DiaryToolbarItem.bulletList => l10n.tr('无序列表', en: 'Bullet list'),
      DiaryToolbarItem.checkList => l10n.tr('待办列表', en: 'Checklist'),
      DiaryToolbarItem.codeBlock => l10n.tr('代码块（多行）', en: 'Code block'),
      DiaryToolbarItem.quote => l10n.tr('引用', en: 'Quote'),
      DiaryToolbarItem.indent => l10n.tr('缩进（增/减）', en: 'Indent'),
      DiaryToolbarItem.link => l10n.tr('链接', en: 'Link'),
    };
  }
}
