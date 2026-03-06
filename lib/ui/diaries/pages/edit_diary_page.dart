import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/content_codec.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/ui/diaries/widgets/create_tag_dialog.dart';

/// 单条日记详情 provider（含标签聚合）。
final diaryDetailProvider = FutureProvider.family<DiaryWithTags?, int>((
  Ref ref,
  int diaryId,
) {
  final db = ref.watch(appDatabaseProvider);
  return db.getDiaryWithTagsById(diaryId);
});

/// 日记编辑页。
///
/// - `diaryId == null`：新建模式
/// - `diaryId != null`：编辑模式
class EditDiaryPage extends ConsumerStatefulWidget {
  const EditDiaryPage({super.key, this.diaryId});

  final int? diaryId;

  @override
  ConsumerState<EditDiaryPage> createState() => _EditDiaryPageState();
}

class _EditDiaryPageState extends ConsumerState<EditDiaryPage> {
  /// 表单控制器：标题 / 正文 / metadata。
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _metadataController = TextEditingController(text: '{}');
  final _formKey = GlobalKey<FormState>();

  /// 当前已选标签 id 集合。
  final Set<int> _selectedTagIds = <int>{};

  /// 是否完成编辑态初始化（防止重复回填）。
  bool _initialized = false;

  /// 保存中的互斥标志，防止重复提交。
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _metadataController.dispose();
    super.dispose();
  }

  /// 保存日记（新建或更新）。
  ///
  /// 流程：
  /// 1. 表单校验；
  /// 2. metadata JSON 校验；
  /// 3. 调用数据库写入；
  /// 4. 成功后返回上一页并触发列表刷新。
  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!isValidMetadataJsonObject(_metadataController.text)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('metadata 必须是合法 JSON 对象')));
      return;
    }

    setState(() => _saving = true);

    final db = ref.read(appDatabaseProvider);
    final title = _titleController.text;
    final content = _contentController.text;
    final metadataJson = _metadataController.text;

    try {
      if (widget.diaryId == null) {
        await db.createDiary(
          title: title,
          plainTextContent: content,
          metadataJson: metadataJson,
          tagIds: _selectedTagIds.toList(),
        );
      } else {
        await db.updateDiary(
          diaryId: widget.diaryId!,
          title: title,
          plainTextContent: content,
          metadataJson: metadataJson,
          tagIds: _selectedTagIds.toList(),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败: $error')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  /// 执行软删除并返回上一页。
  Future<void> _softDelete() async {
    final diaryId = widget.diaryId;
    if (diaryId == null || _saving) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('删除日记'),
          content: const Text('将执行软删除，后续可恢复。确定继续吗？'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final db = ref.read(appDatabaseProvider);
    await db.softDeleteDiary(diaryId);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  /// 弹窗内联创建标签，并自动加入当前已选集合。
  Future<void> _createTagInline() async {
    final draft = await showCreateTagDialog(context);
    if (draft == null) return;

    try {
      final db = ref.read(appDatabaseProvider);
      final tagId = await db.createTag(name: draft.name, color: draft.color);
      if (!mounted) return;
      setState(() => _selectedTagIds.add(tagId));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('标签创建失败: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 标签流用于渲染可选标签 Chip。
    final tagsAsync = ref.watch(tagListProvider);

    if (widget.diaryId == null) {
      _initialized = true;
    }

    final detailAsync =
        widget.diaryId == null
            ? const AsyncData<DiaryWithTags?>(null)
            : ref.watch(diaryDetailProvider(widget.diaryId!));

    return detailAsync.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (Object error, StackTrace stackTrace) => Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('加载失败: $error')),
          ),
      data: (DiaryWithTags? detail) {
        if (widget.diaryId != null && detail == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('日记不存在')),
          );
        }

        if (!_initialized && detail != null) {
          // 仅首次进入编辑态时回填，避免每次 build 覆盖用户输入。
          _titleController.text = detail.diary.title;
          _contentController.text = deltaJsonToPlainText(detail.diary.content);
          try {
            _metadataController.text = prettyMetadataJson(
              detail.diary.metadata,
            );
          } catch (_) {
            _metadataController.text = detail.diary.metadata;
          }
          _selectedTagIds
            ..clear()
            ..addAll(detail.tags.map((Tag t) => t.id));
          _initialized = true;
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.diaryId == null ? '新建日记' : '编辑日记'),
            actions: <Widget>[
              IconButton(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                tooltip: '保存',
              ),
              if (widget.diaryId != null)
                IconButton(
                  onPressed: _saving ? null : _softDelete,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '软删除',
                ),
            ],
          ),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              // 使用滚动容器避免输入法抬起时页面挤压溢出。
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: '标题',
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 200,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      labelText: '正文 (纯文本编辑，保存为 Delta JSON)',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    minLines: 10,
                    maxLines: 20,
                    validator: (String? value) {
                      final title = _titleController.text.trim();
                      final content = (value ?? '').trim();
                      if (title.isEmpty && content.isEmpty) {
                        return '标题和正文不能同时为空';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Text(
                        '标签',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _createTagInline,
                        icon: const Icon(Icons.add),
                        label: const Text('新建标签'),
                      ),
                    ],
                  ),
                  tagsAsync.when(
                    data: (List<Tag> tags) {
                      if (tags.isEmpty) {
                        return const Text('暂无标签，可先新建');
                      }
                      return Wrap(
                        spacing: 8,
                        runSpacing: -8,
                        children:
                            tags.map((Tag tag) {
                              return FilterChip(
                                selected: _selectedTagIds.contains(tag.id),
                                avatar: CircleAvatar(
                                  radius: 8,
                                  backgroundColor: Color(tag.color),
                                ),
                                label: Text(tag.name),
                                onSelected: (bool selected) {
                                  // 维护本地已选标签集合，保存时统一提交。
                                  setState(() {
                                    if (selected) {
                                      _selectedTagIds.add(tag.id);
                                    } else {
                                      _selectedTagIds.remove(tag.id);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                      );
                    },
                    loading:
                        () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                    error:
                        (Object error, StackTrace stackTrace) =>
                            Text('标签加载失败: $error'),
                  ),
                  const SizedBox(height: 12),
                  ExpansionTile(
                    // metadata 作为高级区，默认折叠避免干扰主编辑流程。
                    tilePadding: EdgeInsets.zero,
                    title: const Text('高级：Metadata JSON'),
                    subtitle: const Text('例如 {"weather":"rainy","mood":4}'),
                    children: <Widget>[
                      TextFormField(
                        controller: _metadataController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '{}',
                        ),
                        minLines: 4,
                        maxLines: 10,
                        validator: (String? value) {
                          if (!isValidMetadataJsonObject(value ?? '')) {
                            return '必须是 JSON 对象';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
