import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';

/// 日记编辑器工具栏排序页（拖拽调整顺序）。
class DiaryToolbarOrderPage extends StatefulWidget {
  const DiaryToolbarOrderPage({super.key, required this.settingsService});

  final SettingsService settingsService;

  @override
  State<DiaryToolbarOrderPage> createState() => _DiaryToolbarOrderPageState();
}

class _DiaryToolbarOrderPageState extends State<DiaryToolbarOrderPage> {
  late List<DiaryToolbarItem> _order;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _order = decodeDiaryToolbarOrder(widget.settingsService.diaryToolbarOrderRaw);
  }

  void _handleReorder(int oldIndex, int newIndex) {
    setState(() {
      final adjustedNewIndex = oldIndex < newIndex ? newIndex - 1 : newIndex;
      final target = _order.removeAt(oldIndex);
      _order.insert(adjustedNewIndex, target);
    });
  }

  void _resetOrder() {
    setState(() {
      _order = List<DiaryToolbarItem>.from(kDefaultDiaryToolbarOrder);
    });
  }

  Future<void> _confirmResetOrder() async {
    final l10n = context.l10n;
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(l10n.tr('重置排序', en: 'Reset order')),
          content: Text(
            l10n.tr(
              '确认将工具栏顺序恢复为默认排序吗？',
              en: 'Reset toolbar order to defaults?',
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.primary,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.commonReset),
            ),
          ],
        );
      },
    );
    if (shouldReset == true && mounted) {
      _resetOrder();
    }
  }

  Future<void> _saveOrder() async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.settingsService.setDiaryToolbarOrderRaw(
        encodeDiaryToolbarOrder(_order),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      await HomeHintVisibilityScope.showTrackedSnackBar(
        context: context,
        snackBar: SnackBar(
          content: Text(
            context.l10n.tr('保存排序失败: $error', en: 'Save order failed: $error'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.commonBack,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
        ),
        title: Text(l10n.tr('工具栏顺序', en: 'Toolbar order')),
        actions: <Widget>[
          TextButton(
            onPressed: _saving ? null : _confirmResetOrder,
            child: Text(l10n.commonReset),
          ),
          TextButton(
            onPressed: _saving ? null : _saveOrder,
            child: Text(l10n.commonSave),
          ),
        ],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        buildDefaultDragHandles: false,
        itemCount: _order.length,
        onReorder: _handleReorder,
        itemBuilder: (BuildContext context, int index) {
          final item = _order[index];
          return ListTile(
            key: ValueKey<String>(item.storageKey),
            leading: FaIcon(item.iconData, size: 16),
            title: Text(_labelForItem(context, item)),
            subtitle:
                item == DiaryToolbarItem.inlineCode
                    ? Text(
                        l10n.tr(
                          '用于给选中文本添加行内代码样式',
                          en: 'Apply inline code style to selected text',
                        ),
                      )
                    : item == DiaryToolbarItem.codeBlock
                    ? Text(
                        l10n.tr(
                          '用于插入或切换为代码块',
                          en: 'Insert or switch to code block',
                        ),
                      )
                    : item == DiaryToolbarItem.indent
                    ? Text(
                        l10n.tr(
                          '该项会同时显示缩进增加/减少两个按钮',
                          en: 'Shows both indent increase/decrease buttons',
                        ),
                      )
                    : null,
            trailing: ReorderableDragStartListener(
              index: index,
              child: const SizedBox(
                width: 44,
                height: 40,
                child: ColoredBox(
                  color: Colors.transparent,
                  child: Center(child: _TripleBarDragHandle()),
                ),
              ),
            ),
          );
        },
      ),
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

/// 三竖线拖拽手柄（替代默认双竖线图标）。
class _TripleBarDragHandle extends StatelessWidget {
  const _TripleBarDragHandle();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return SizedBox(
      width: 16,
      height: 18,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          _buildBar(color),
          _buildBar(color),
          _buildBar(color),
        ],
      ),
    );
  }

  Widget _buildBar(Color color) {
    return Container(
      width: 2,
      height: 16,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(1.2),
      ),
    );
  }
}
