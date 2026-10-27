import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:node_diary/ui/widgets/delayed_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/tag_order_codec.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/create_tag_dialog.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/app_modal/app_dialog.dart';
import '../../widgets/expressive_reorder_proxy.dart';
import '../../widgets/list_item_presence.dart';
import '../widgets/tag_management_tile.dart';
import '../../widgets/form_width.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_enums.dart';
import 'package:node_diary/ui/app_surface/widgets/app_page_background.dart';

/// 标签管理页：
/// 1. 标签排序（拖拽）；
/// 2. 标签编辑（复用新建标签弹窗样式）；
/// 3. 标签删除。
class TagManagementPage extends ConsumerStatefulWidget {
  const TagManagementPage({super.key});

  @override
  ConsumerState<TagManagementPage> createState() => _TagManagementPageState();
}

class _TagManagementPageState extends ConsumerState<TagManagementPage> {
  bool _savingOrder = false;

  /// 新建/编辑/删除进行中：各入口据此直接忽略重复触发。按钮本身保持可用，
  /// 不再随每次操作整体变灰闪一下。
  bool _operating = false;
  List<Tag> _displayTags = <Tag>[];
  bool _displayTagsInitialized = false;

  /// 正在收起、等待写库删除的标签：数据流移除它们时行高已是 0，不再硬跳。
  final Set<int> _pendingRemovalTagIds = <int>{};

  /// 新建后以展开动画出现的标签。只在该行首次构建时生效，留在集合里无副作用。
  final Set<int> _appearingTagIds = <int>{};

  Future<void> _createTag() async {
    final l10n = context.l10n;
    if (_operating) {
      return;
    }

    final draft = await showCreateTagDialog(context);
    if (draft == null || !mounted) {
      return;
    }

    setState(() => _operating = true);
    try {
      final db = ref.read(appDatabaseProvider);
      final createdId = await db.createTag(
        name: draft.name,
        color: draft.color,
      );
      if (mounted) {
        setState(() => _appearingTagIds.add(createdId));
      }
      final settings = await ref.read(settingsServiceProvider.future);
      final order = decodeTagOrder(settings.tagOrderRaw);
      if (!order.contains(createdId)) {
        order.add(createdId);
        await settings.setTagOrderRaw(encodeTagOrder(order));
      }
      ref.invalidate(tagListProvider);
    } catch (error) {
      await _showHint(l10n.autoT0034(error.toString()));
    } finally {
      if (mounted) {
        setState(() => _operating = false);
      }
    }
  }

  Future<void> _editTag(Tag tag) async {
    final l10n = context.l10n;
    if (_operating) {
      return;
    }

    final draft = await showEditTagDialog(
      context,
      initialName: tag.name,
      initialColor: tag.color,
    );
    if (draft == null || !mounted) {
      return;
    }

    setState(() => _operating = true);
    try {
      final db = ref.read(appDatabaseProvider);
      await db.updateTag(tagId: tag.id, name: draft.name, color: draft.color);
    } catch (error) {
      await _showHint(l10n.autoT0035(error.toString()));
    } finally {
      if (mounted) {
        setState(() => _operating = false);
      }
    }
  }

  Future<void> _deleteTag(Tag tag) async {
    final l10n = context.l10n;
    if (_operating) {
      return;
    }

    final confirmed = await _confirmDeleteTag(tag);
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _operating = true);
    try {
      // 先收起再提交：行在写库前收成 0 高度，数据流移除它时列表不再硬跳。
      setState(() => _pendingRemovalTagIds.add(tag.id));
      await Future<void>.delayed(
        ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      );
      if (!mounted) {
        return;
      }
      final db = ref.read(appDatabaseProvider);
      final settings = await ref.read(settingsServiceProvider.future);
      final order = decodeTagOrder(settings.tagOrderRaw)
        ..removeWhere((id) => id == tag.id);
      await settings.setTagOrderRaw(encodeTagOrder(order));
      final rememberedTagIds = decodeTagOrder(
        settings.rememberedTagFilterIdsRaw,
      )..removeWhere((id) => id == tag.id);
      await settings.setRememberedTagFilterIdsRaw(
        encodeTagOrder(rememberedTagIds),
      );
      await db.deleteTag(tag.id);
      final activeTagIds = ref.read(diaryFilterProvider).selectedTagIds;
      if (activeTagIds.contains(tag.id)) {
        ref
            .read(diaryFilterProvider.notifier)
            .setTags(activeTagIds.where((id) => id != tag.id));
      }
      ref.invalidate(tagListProvider);
    } catch (error) {
      // 删除失败：标签仍在数据里，取消收起使其重新展开。
      if (mounted) {
        setState(() => _pendingRemovalTagIds.remove(tag.id));
      }
      await _showHint(l10n.autoT0036(error.toString()));
    } finally {
      if (mounted) {
        setState(() => _operating = false);
      }
    }
  }

  Future<void> _reorderTags(List<Tag> tags, int oldIndex, int newIndex) async {
    final l10n = context.l10n;
    if (_savingOrder || _operating) {
      return;
    }
    // onReorderItem 给出的 newIndex 已按移除 oldIndex 后的列表修正，原位放下
    // 时两者相等，直接跳过保存。
    if (oldIndex == newIndex) {
      return;
    }

    final reordered = List<Tag>.from(tags);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    setState(() {
      _displayTags = reordered;
      _displayTagsInitialized = true;
      _savingOrder = true;
    });
    try {
      final settings = await ref.read(settingsServiceProvider.future);
      await settings.setTagOrderRaw(
        encodeTagOrder(reordered.map((tag) => tag.id).toList(growable: false)),
      );
      ref.invalidate(tagListProvider);
    } catch (error) {
      await _showHint(l10n.autoT0037(error.toString()));
      if (mounted) {
        setState(() => _savingOrder = false);
      }
    }
  }

  Widget _buildTagList(BuildContext context, List<Tag> displayTags) {
    final l10n = context.l10n;
    final itemDuration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    return LayoutBuilder(
      key: const ValueKey<String>('tags_list'),
      builder: (BuildContext context, BoxConstraints constraints) {
        final side = FormWidth.extra(constraints.maxWidth);
        return ReorderableListView.builder(
          padding: EdgeInsets.symmetric(horizontal: side, vertical: 12),
          buildDefaultDragHandles: false,
          proxyDecorator: expressiveReorderProxyDecorator,
          itemCount: displayTags.length,
          // 拿起条目即生效的瞬间给一次触觉：拖拽手柄是立即拖动，不经过长按，系统
          // 不会自动反馈。
          onReorderStart: (_) => unawaited(HapticFeedback.mediumImpact()),
          onReorderItem: (oldIndex, newIndex) {
            _reorderTags(displayTags, oldIndex, newIndex);
          },
          itemBuilder: (BuildContext context, int index) {
            final tag = displayTags[index];
            final removing = _pendingRemovalTagIds.contains(tag.id);
            // 可排序列表要求每项最外层带稳定 key；进出场容器结构恒定，删除收起、
            // 新建展开都不会重新挂载整行。
            return ListItemPresence(
              key: ValueKey<int>(tag.id),
              visible: !removing,
              appearing: _appearingTagIds.contains(tag.id),
              duration: itemDuration,
              child: TagManagementTile(
                tag: tag,
                index: index,
                deleteTooltip: l10n.autoT0038,
                dragEnabled: !removing,
                onEdit: () => _editTag(tag),
                onDelete: () => _deleteTag(tag),
              ),
            );
          },
        );
      },
    );
  }

  Future<bool?> _confirmDeleteTag(Tag tag) {
    return showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(context.l10n.autoT0038),
          content: Text(context.l10n.autoT0195(tag.name)),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.commonCancel),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: colorScheme.error),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(context.l10n.commonDelete),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showHint(String message) async {
    await HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(content: Text(message)),
    );
  }

  Future<void> _setTagFilterMemoryEnabled(
    SettingsService settings,
    bool enabled,
  ) async {
    await settings.setTagFilterMemoryEnabled(enabled);
    if (!enabled) {
      return;
    }
    final currentTagIds = ref.read(diaryFilterProvider).selectedTagIds;
    if (currentTagIds.isEmpty) {
      return;
    }
    final sortedTagIds = currentTagIds.toList(growable: false)..sort();
    await settings.setRememberedTagFilterIdsRaw(encodeTagOrder(sortedTagIds));
  }

  /// 同步流式标签数据到页面可视列表。
  ///
  /// - 常规状态：跟随 provider 输出；
  /// - 排序保存中：保留当前可视顺序，避免拖拽落地后瞬间回弹闪动。
  void _syncDisplayTags(List<Tag> incomingTags) {
    // 已从数据中消失的标签不再需要收起标记。
    _pendingRemovalTagIds.removeWhere(
      (id) => !incomingTags.any((tag) => tag.id == id),
    );
    if (!_displayTagsInitialized) {
      _displayTags = List<Tag>.from(incomingTags);
      _displayTagsInitialized = true;
      return;
    }

    if (!_savingOrder) {
      _displayTags = List<Tag>.from(incomingTags);
      return;
    }

    final incomingById = <int, Tag>{
      for (final tag in incomingTags) tag.id: tag,
    };
    final merged = <Tag>[];
    final seen = <int>{};

    for (final old in _displayTags) {
      final updated = incomingById[old.id];
      if (updated == null || !seen.add(updated.id)) {
        continue;
      }
      merged.add(updated);
    }
    for (final tag in incomingTags) {
      if (seen.add(tag.id)) {
        merged.add(tag);
      }
    }
    _displayTags = merged;

    // 仅当 provider 层顺序已经与当前可视顺序一致时，才结束“排序保存中”状态。
    // 这样可以避免拖拽放下后出现“先回弹旧顺序，再跳回新顺序”的闪动。
    if (_isSameTagOrder(incomingTags, _displayTags)) {
      _savingOrder = false;
    }
  }

  bool _isSameTagOrder(List<Tag> a, List<Tag> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tagsAsync = ref.watch(tagListProvider);
    final settingsAsync = ref.watch(settingsServiceProvider);

    return AppPageBackground(
      area: AppBackgroundArea.settings,
      child: Builder(
        builder: (BuildContext context) => Scaffold(
          backgroundColor: AppPageBackdrop.pageColorOf(context),
          appBar: AppTopBar(
            contentMaxWidth: FormWidth.maxWidth,
            leading: IconButton(
              tooltip: l10n.commonBack,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
            ),
            title: Text(l10n.autoT0039),
            actions: <Widget>[
              IconButton(
                tooltip: l10n.autoT0040,
                onPressed: _createTag,
                icon: const FaIcon(FontAwesomeIcons.plus, size: 16),
              ),
            ],
          ),
          body: settingsAsync.when(
            data: (settings) {
              return Column(
                children: <Widget>[
                  _TagFilterMemorySwitch(
                    settings: settings,
                    onChanged: (enabled) => unawaited(
                      _setTagFilterMemoryEnabled(settings, enabled),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: tagsAsync.when(
                      data: (tags) {
                        _syncDisplayTags(tags);
                        final displayTags = _displayTags;
                        // 最后一个标签被删除后与空态交叉淡入，而不是硬切。
                        return AnimatedSwitcher(
                          duration: ExpressiveMotion.duration(
                            context,
                            ExpressiveMotion.medium,
                          ),
                          switchInCurve: ExpressiveMotion.effects,
                          switchOutCurve: ExpressiveMotion.exit,
                          child: displayTags.isEmpty
                              ? Center(
                                  key: const ValueKey<String>('tags_empty'),
                                  child: TextButton(
                                    onPressed: _createTag,
                                    child: Text(l10n.autoT0041),
                                  ),
                                )
                              : _buildTagList(context, displayTags),
                        );
                      },
                      loading: () => const DelayedLoadingIndicator(size: 32),
                      error: (error, stackTrace) {
                        return Center(
                          child: Text(l10n.autoT0042(error.toString())),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
            loading: () => const DelayedLoadingIndicator(size: 32),
            error: (error, stackTrace) =>
                Center(child: Text(l10n.autoT0045(error.toString()))),
          ),
        ),
      ),
    );
  }
}

class _TagFilterMemorySwitch extends StatelessWidget {
  const _TagFilterMemorySwitch({
    required this.settings,
    required this.onChanged,
  });

  final SettingsService settings;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ValueListenableBuilder<bool>(
      valueListenable: settings.tagFilterMemoryEnabledNotifier,
      builder: (BuildContext context, bool enabled, Widget? child) {
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) =>
              SwitchListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: FormWidth.gutter(constraints.maxWidth),
                ),
                value: enabled,
                title: Text(l10n.settingsTagMemory),
                subtitle: Text(l10n.settingsTagMemorySubtitle),
                onChanged: onChanged,
              ),
        );
      },
    );
  }
}
