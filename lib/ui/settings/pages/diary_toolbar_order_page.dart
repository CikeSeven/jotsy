import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/services/settings_service.dart';
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
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: const Text('重置排序'),
          content: const Text('确认将工具栏顺序恢复为默认排序吗？'),
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
                foregroundColor: colorScheme.primary,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('重置'),
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
        snackBar: SnackBar(content: Text('保存排序失败: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
        ),
        title: const Text('工具栏顺序'),
        actions: <Widget>[
          TextButton(
            onPressed: _saving ? null : _confirmResetOrder,
            child: const Text('重置'),
          ),
          TextButton(onPressed: _saving ? null : _saveOrder, child: const Text('保存')),
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
            title: Text(item.label),
            subtitle:
                item == DiaryToolbarItem.inlineCode
                    ? const Text('用于给选中文本添加行内代码样式')
                    : item == DiaryToolbarItem.codeBlock
                    ? const Text('用于插入或切换为代码块')
                    : item == DiaryToolbarItem.indent
                    ? const Text('该项会同时显示缩进增加/减少两个按钮')
                    : null,
            trailing: ReorderableDragStartListener(
              index: index,
              child: const _TripleBarDragHandle(),
            ),
          );
        },
      ),
    );
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
