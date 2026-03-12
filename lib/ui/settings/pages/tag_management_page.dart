import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/tag_order_codec.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/create_tag_dialog.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';

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
  bool _operating = false;
  List<Tag> _displayTags = <Tag>[];
  bool _displayTagsInitialized = false;

  Future<void> _createTag() async {
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
      final createdId = await db.createTag(name: draft.name, color: draft.color);
      final settings = await ref.read(settingsServiceProvider.future);
      final order = decodeTagOrder(settings.tagOrderRaw);
      if (!order.contains(createdId)) {
        order.add(createdId);
        await settings.setTagOrderRaw(encodeTagOrder(order));
      }
      ref.invalidate(tagListProvider);
    } catch (error) {
      await _showHint(
        context.l10n.tr('创建标签失败: $error', en: 'Create tag failed: $error'),
      );
    } finally {
      if (mounted) {
        setState(() => _operating = false);
      }
    }
  }

  Future<void> _editTag(Tag tag) async {
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
      await db.updateTag(
        tagId: tag.id,
        name: draft.name,
        color: draft.color,
      );
    } catch (error) {
      await _showHint(
        context.l10n.tr('修改标签失败: $error', en: 'Edit tag failed: $error'),
      );
    } finally {
      if (mounted) {
        setState(() => _operating = false);
      }
    }
  }

  Future<void> _deleteTag(Tag tag) async {
    if (_operating) {
      return;
    }

    final confirmed = await _confirmDeleteTag(tag);
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _operating = true);
    try {
      final db = ref.read(appDatabaseProvider);
      final settings = await ref.read(settingsServiceProvider.future);
      final order = decodeTagOrder(settings.tagOrderRaw)
        ..removeWhere((id) => id == tag.id);
      await settings.setTagOrderRaw(encodeTagOrder(order));
      await db.deleteTag(tag.id);
      ref.invalidate(tagListProvider);
    } catch (error) {
      await _showHint(
        context.l10n.tr('删除标签失败: $error', en: 'Delete tag failed: $error'),
      );
    } finally {
      if (mounted) {
        setState(() => _operating = false);
      }
    }
  }

  Future<void> _reorderTags(List<Tag> tags, int oldIndex, int newIndex) async {
    if (_savingOrder || _operating) {
      return;
    }
    if (oldIndex == newIndex) {
      return;
    }

    final adjustedNewIndex = oldIndex < newIndex ? newIndex - 1 : newIndex;
    final reordered = List<Tag>.from(tags);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(adjustedNewIndex, moved);

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
      await _showHint(
        context.l10n.tr('保存标签顺序失败: $error', en: 'Save tag order failed: $error'),
      );
      if (mounted) {
        setState(() => _savingOrder = false);
      }
    }
  }

  Future<bool?> _confirmDeleteTag(Tag tag) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(context.l10n.tr('删除标签', en: 'Delete tag')),
          content: Text(
            context.l10n.tr(
              '确认删除标签 "${tag.name}" 吗？',
              en: 'Delete tag "${tag.name}"?',
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.commonCancel),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.error,
              ),
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

  /// 同步流式标签数据到页面可视列表。
  ///
  /// - 常规状态：跟随 provider 输出；
  /// - 排序保存中：保留当前可视顺序，避免拖拽落地后瞬间回弹闪动。
  void _syncDisplayTags(List<Tag> incomingTags) {
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.commonBack,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
        ),
        title: Text(l10n.tr('标签管理', en: 'Tag management')),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.tr('新建标签', en: 'Create tag'),
            onPressed: _operating ? null : _createTag,
            icon: const FaIcon(FontAwesomeIcons.plus, size: 16),
          ),
        ],
      ),
      body: tagsAsync.when(
        data: (tags) {
          _syncDisplayTags(tags);
          final displayTags = _displayTags;
          if (displayTags.isEmpty) {
            return Center(
              child: TextButton(
                onPressed: _operating ? null : _createTag,
                child: Text(l10n.tr('新建第一个标签', en: 'Create your first tag')),
              ),
            );
          }

          return ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            buildDefaultDragHandles: false,
            itemCount: displayTags.length,
            onReorder: (oldIndex, newIndex) {
              _reorderTags(displayTags, oldIndex, newIndex);
            },
            itemBuilder: (BuildContext context, int index) {
              final tag = displayTags[index];
              return ListTile(
                key: ValueKey<int>(tag.id),
                onTap: _operating ? null : () => _editTag(tag),
                leading: CircleAvatar(backgroundColor: Color(tag.color)),
                title: Text(tag.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      tooltip: l10n.tr('删除标签', en: 'Delete tag'),
                      onPressed: _operating ? null : () => _deleteTag(tag),
                      icon: const FaIcon(FontAwesomeIcons.trashCan, size: 14),
                    ),
                    const SizedBox(width: 12),
                    ReorderableDragStartListener(
                      index: index,
                      child: const SizedBox(
                        width: 44,
                        height: 40,
                        child: ColoredBox(
                          color: Colors.transparent,
                          child: Center(child: _TagDragHandle()),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading:
            () => const Center(
              child: CircularProgressIndicator(),
            ),
        error: (error, stackTrace) {
          return Center(
            child: Text(
              l10n.tr('标签加载失败: $error', en: 'Tag load failed: $error'),
            ),
          );
        },
      ),
    );
  }
}

class _TagDragHandle extends StatelessWidget {
  const _TagDragHandle();

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
