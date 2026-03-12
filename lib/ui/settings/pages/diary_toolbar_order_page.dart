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
          title: Text(l10n.autoT0003),
          content: Text(
            l10n.autoT0187,
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
            context.l10n.autoT0004(error.toString()),
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
        title: Text(l10n.autoT0005),
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
                        l10n.autoT0188,
                      )
                    : item == DiaryToolbarItem.codeBlock
                    ? Text(
                        l10n.autoT0189,
                      )
                    : item == DiaryToolbarItem.indent
                    ? Text(
                        l10n.autoT0190,
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
      DiaryToolbarItem.undo => l10n.autoT0006,
      DiaryToolbarItem.redo => l10n.autoT0007,
      DiaryToolbarItem.bold => l10n.autoT0008,
      DiaryToolbarItem.italic => l10n.autoT0009,
      DiaryToolbarItem.underline => l10n.autoT0010,
      DiaryToolbarItem.strikeThrough => l10n.autoT0011,
      DiaryToolbarItem.inlineCode => l10n.autoT0012,
      DiaryToolbarItem.textColor => l10n.autoT0013,
      DiaryToolbarItem.backgroundColor => l10n.autoT0014,
      DiaryToolbarItem.clearFormat => l10n.autoT0015,
      DiaryToolbarItem.image => l10n.autoT0016,
      DiaryToolbarItem.headerStyle => l10n.autoT0017,
      DiaryToolbarItem.orderedList => l10n.autoT0018,
      DiaryToolbarItem.bulletList => l10n.autoT0019,
      DiaryToolbarItem.checkList => l10n.autoT0020,
      DiaryToolbarItem.codeBlock => l10n.autoT0021,
      DiaryToolbarItem.quote => l10n.autoT0022,
      DiaryToolbarItem.indent => l10n.autoT0023,
      DiaryToolbarItem.link => l10n.autoT0024,
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
