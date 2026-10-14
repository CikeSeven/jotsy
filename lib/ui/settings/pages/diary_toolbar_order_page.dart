import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';
import '../../widgets/expressive_reorder_proxy.dart';
import '../../widgets/unsaved_changes_dialog.dart';
import '../../../app/theme/expressive_motion.dart';

/// 日记编辑器工具栏排序页（拖拽调整顺序）。
class DiaryToolbarOrderPage extends StatefulWidget {
  const DiaryToolbarOrderPage({super.key, required this.settingsService});

  final SettingsService settingsService;

  @override
  State<DiaryToolbarOrderPage> createState() => _DiaryToolbarOrderPageState();
}

class _DiaryToolbarOrderPageState extends State<DiaryToolbarOrderPage> {
  late List<DiaryToolbarItem> _order;
  late Set<DiaryToolbarItem> _hiddenItems;
  late String _currentTimeFormatPattern;
  bool _saving = false;

  // 进入页面时已持久化的配置（编码后），用于判断是否存在未保存的修改。
  late final String _savedOrderRaw;
  late final String _savedHiddenItemsRaw;
  late final String _savedTimeFormatPattern;

  @override
  void initState() {
    super.initState();
    _order = decodeDiaryToolbarOrder(
      widget.settingsService.diaryToolbarOrderRaw,
    );
    _hiddenItems = decodeDiaryToolbarHiddenItems(
      widget.settingsService.diaryToolbarHiddenItemsRaw,
    );
    _currentTimeFormatPattern =
        widget.settingsService.diaryToolbarCurrentTimeFormatRaw ??
        kDefaultDiaryToolbarCurrentTimeFormat;
    // 以解码后再编码的结果作基准，避免原始字符串格式差异被误判为修改。
    _savedOrderRaw = encodeDiaryToolbarOrder(_order);
    _savedHiddenItemsRaw = encodeDiaryToolbarHiddenItems(_hiddenItems);
    _savedTimeFormatPattern = _currentTimeFormatPattern;
  }

  bool get _hasUnsavedChanges =>
      encodeDiaryToolbarOrder(_order) != _savedOrderRaw ||
      encodeDiaryToolbarHiddenItems(_hiddenItems) != _savedHiddenItemsRaw ||
      _currentTimeFormatPattern != _savedTimeFormatPattern;

  /// 返回键与标题栏返回统一入口：有未保存修改时先确认，避免拖拽排序、
  /// 启用开关与时间格式的调整被静默丢弃。
  Future<void> _attemptExit() async {
    if (_saving) {
      return;
    }
    if (!_hasUnsavedChanges) {
      Navigator.of(context).pop();
      return;
    }
    final decision = await showUnsavedChangesDialog(context);
    if (!mounted) {
      return;
    }
    switch (decision) {
      case UnsavedChangesDecision.discard:
        Navigator.of(context).pop();
      case UnsavedChangesDecision.saveAndExit:
        // 保存成功后 _saveOrder 自行返回上一页；失败则停留并提示。
        await _saveOrder();
      case UnsavedChangesDecision.cancel:
        return;
    }
  }

  void _handleReorder(int oldIndex, int newIndex) {
    setState(() {
      final adjustedNewIndex = oldIndex < newIndex ? newIndex - 1 : newIndex;
      final target = _order.removeAt(oldIndex);
      _order.insert(adjustedNewIndex, target);
    });
  }

  void _handleToggleEnabled(DiaryToolbarItem item, bool? enabled) {
    setState(() {
      if (enabled ?? true) {
        _hiddenItems.remove(item);
      } else {
        _hiddenItems.add(item);
      }
    });
  }

  /// 每次恢复默认递增：列表以新 key 交叉淡入，而不是所有条目一帧跳回默认顺序。
  int _resetGeneration = 0;

  void _resetOrder() {
    setState(() {
      _resetGeneration++;
      _order = List<DiaryToolbarItem>.from(kDefaultDiaryToolbarOrder);
      _hiddenItems = <DiaryToolbarItem>{};
      _currentTimeFormatPattern = kDefaultDiaryToolbarCurrentTimeFormat;
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
          content: Text(l10n.autoT0187),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
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

  Future<void> _openToolSettings(DiaryToolbarItem item) async {
    switch (item) {
      case DiaryToolbarItem.currentTime:
        await _openCurrentTimeFormatDialog();
      case _:
        return;
    }
  }

  Future<void> _openCurrentTimeFormatDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _CurrentTimeFormatDialog(
          initialPattern: _currentTimeFormatPattern,
        );
      },
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() => _currentTimeFormatPattern = result);
  }

  bool _hasToolSettings(DiaryToolbarItem item) {
    return switch (item) {
      DiaryToolbarItem.currentTime => true,
      _ => false,
    };
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
      await widget.settingsService.setDiaryToolbarHiddenItemsRaw(
        encodeDiaryToolbarHiddenItems(_hiddenItems),
      );
      await widget.settingsService.setDiaryToolbarCurrentTimeFormatRaw(
        _currentTimeFormatPattern,
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
          content: Text(context.l10n.autoT0004(error.toString())),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      // 有未保存修改或正在保存时拦截系统返回，交给 _attemptExit 处理；
      // 保存成功后的 Navigator.pop 为直接出栈，不受此处限制。
      canPop: !_saving && !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_attemptExit());
        }
      },
      child: Scaffold(
        appBar: AppTopBar(
          leading: IconButton(
            tooltip: l10n.commonBack,
            onPressed: () => unawaited(_attemptExit()),
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
        body: AnimatedSwitcher(
          duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
          switchInCurve: ExpressiveMotion.effects,
          switchOutCurve: ExpressiveMotion.exit,
          child: KeyedSubtree(
            key: ValueKey<int>(_resetGeneration),
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              buildDefaultDragHandles: false,
              proxyDecorator: expressiveReorderProxyDecorator,
              itemCount: _order.length,
              // 拖拽手柄立即拖动、不经过长按，系统不会反馈；拿起时补一次触觉。
              onReorderStart: (_) => unawaited(HapticFeedback.mediumImpact()),
              onReorder: _handleReorder,
              itemBuilder: (BuildContext context, int index) {
                final item = _order[index];
                final enabled = !_hiddenItems.contains(item);
                return ListTile(
                  key: ValueKey<String>(item.storageKey),
                  onTap: _saving
                      ? null
                      : () => _handleToggleEnabled(item, !enabled),
                  leading: SizedBox(
                    width: 80,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Checkbox(
                          value: enabled,
                          onChanged: _saving
                              ? null
                              : (value) => _handleToggleEnabled(item, value),
                        ),
                        const SizedBox(width: 8),
                        FaIcon(
                          item.iconData,
                          size: 16,
                          color: enabled
                              ? null
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                  title: Text(
                    _labelForItem(context, item),
                    style: enabled
                        ? null
                        : TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                  ),
                  subtitle: item == DiaryToolbarItem.inlineCode
                      ? Text(l10n.autoT0188)
                      : item == DiaryToolbarItem.codeBlock
                      ? Text(l10n.autoT0189)
                      : item == DiaryToolbarItem.indent
                      ? Text(l10n.autoT0190)
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (_hasToolSettings(item))
                        IconButton(
                          tooltip: l10n.diaryToolbarToolSettingsTooltip,
                          onPressed: _saving
                              ? null
                              : () => _openToolSettings(item),
                          icon: const FaIcon(FontAwesomeIcons.gear, size: 14),
                        ),
                      ReorderableDragStartListener(
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
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _labelForItem(BuildContext context, DiaryToolbarItem item) =>
      item.label(context.l10n);
}

/// 当前时间工具的格式配置弹窗。
///
/// TextField 的 controller 必须跟随弹窗 widget 生命周期释放；不能在
/// `showDialog` 的 Future 返回后立刻 dispose，因为关闭动画期间 TextField
/// 仍可能 rebuild 并继续监听 controller。
class _CurrentTimeFormatDialog extends StatefulWidget {
  const _CurrentTimeFormatDialog({required this.initialPattern});

  final String initialPattern;

  @override
  State<_CurrentTimeFormatDialog> createState() =>
      _CurrentTimeFormatDialogState();
}

class _CurrentTimeFormatDialogState extends State<_CurrentTimeFormatDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialPattern);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final preview = _previewFor(l10n, _controller.text);
    return AlertDialog(
      title: Text(l10n.diaryToolbarTimeFormatTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.diaryToolbarTimeFormatLabel,
              hintText: kDefaultDiaryToolbarCurrentTimeFormat,
              errorText: _errorText,
            ),
            onChanged: (_) => setState(() => _errorText = null),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.diaryToolbarTimeFormatHelp,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.diaryToolbarTimeFormatPreview(preview),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.onSurfaceVariant,
          ),
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.onSurfaceVariant,
          ),
          onPressed: () =>
              Navigator.of(context).pop(kDefaultDiaryToolbarCurrentTimeFormat),
          child: Text(l10n.commonReset),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
          onPressed: () {
            final normalized = _controller.text.trim();
            if (!isValidDiaryToolbarCurrentTimeFormat(l10n, normalized)) {
              setState(() {
                _errorText = l10n.diaryToolbarTimeFormatInvalid;
              });
              return;
            }
            Navigator.of(context).pop(
              normalized.isEmpty
                  ? kDefaultDiaryToolbarCurrentTimeFormat
                  : normalized,
            );
          },
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }

  String _previewFor(AppLocalizations l10n, String pattern) {
    try {
      return formatDiaryToolbarCurrentTime(
        l10n,
        DateTime(2026, 3, 11, 21, 30),
        customPattern: pattern,
      );
    } catch (_) {
      return l10n.diaryToolbarTimeFormatInvalid;
    }
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
