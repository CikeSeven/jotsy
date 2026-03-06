import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_note/core/database/app_database.dart';
import 'package:node_note/core/database/content_codec.dart';
import 'package:node_note/core/services/app_service.dart';

final diaryDetailProvider = FutureProvider.family<DiaryWithTags?, int>((
  Ref ref,
  int diaryId,
) {
  final db = ref.watch(appDatabaseProvider);
  return db.getDiaryWithTagsById(diaryId);
});

class EditNotePage extends ConsumerStatefulWidget {
  const EditNotePage({super.key, this.diaryId});

  final int? diaryId;

  @override
  ConsumerState<EditNotePage> createState() => _EditNotePageState();
}

class _EditNotePageState extends ConsumerState<EditNotePage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _metadataController = TextEditingController(text: '{}');
  final _formKey = GlobalKey<FormState>();

  final Set<int> _selectedTagIds = <int>{};
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _metadataController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (!isValidMetadataJsonObject(_metadataController.text)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('metadata 必须是合法 JSON 对象')));
      return;
    }

    setState(() {
      _saving = true;
    });

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

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _softDelete() async {
    final diaryId = widget.diaryId;
    if (diaryId == null || _saving) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('删除日记'),
          content: const Text('将执行软删除，后续可恢复。确定继续吗？'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final db = ref.read(appDatabaseProvider);
    await db.softDeleteDiary(diaryId);

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _createTagInline() async {
    final nameController = TextEditingController();
    final colorController = TextEditingController(text: '#4CAF50');

    final draft = await showDialog<_NewTagDraft>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('新建标签'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: '标签名'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: colorController,
                decoration: const InputDecoration(
                  labelText: '颜色(HEX，如 #4CAF50)',
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  return;
                }
                final parsedColor = _parseHexColor(colorController.text);
                if (parsedColor == null) {
                  return;
                }
                Navigator.of(
                  context,
                ).pop(_NewTagDraft(name: name, color: parsedColor));
              },
              child: const Text('创建'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    colorController.dispose();

    if (draft == null) {
      return;
    }

    try {
      final db = ref.read(appDatabaseProvider);
      final tagId = await db.createTag(name: draft.name, color: draft.color);
      setState(() {
        _selectedTagIds.add(tagId);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('标签创建失败: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
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

  int? _parseHexColor(String raw) {
    final normalized = raw.trim().replaceFirst('#', '');
    if (normalized.length != 6 && normalized.length != 8) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('颜色格式错误，应为 #RRGGBB 或 #AARRGGBB')),
        );
      }
      return null;
    }

    final withAlpha = normalized.length == 6 ? 'FF$normalized' : normalized;
    final value = int.tryParse(withAlpha, radix: 16);
    if (value == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('颜色值解析失败')));
      }
      return null;
    }
    return value;
  }
}

class _NewTagDraft {
  const _NewTagDraft({required this.name, required this.color});

  final String name;
  final int color;
}
