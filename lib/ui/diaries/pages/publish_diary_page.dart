import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/content_codec.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/widgets/create_tag_dialog.dart';

class PublishDiaryPage extends ConsumerStatefulWidget {
  const PublishDiaryPage({super.key, required this.initialDraft});

  final NewDiaryDraft initialDraft;

  @override
  ConsumerState<PublishDiaryPage> createState() => _PublishDiaryPageState();
}

class _PublishDiaryPageState extends ConsumerState<PublishDiaryPage> {
  late final TextEditingController _metadataController;
  late final TextEditingController _coverController;
  late final Set<int> _selectedTagIds;
  bool _saving = false;

  String? get _normalizedCover {
    final normalized = _coverController.text.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  @override
  void initState() {
    super.initState();
    _coverController = TextEditingController(text: widget.initialDraft.cover ?? '');
    _metadataController = TextEditingController(
      text: widget.initialDraft.metadataJson,
    );
    _selectedTagIds = <int>{...widget.initialDraft.selectedTagIds};
  }

  @override
  void dispose() {
    _coverController.dispose();
    _metadataController.dispose();
    super.dispose();
  }

  Future<void> _createTagInline() async {
    final draft = await showCreateTagDialog(context);
    if (draft == null) {
      return;
    }

    try {
      final db = ref.read(appDatabaseProvider);
      final tagId = await db.createTag(name: draft.name, color: draft.color);
      if (!mounted) {
        return;
      }
      setState(() => _selectedTagIds.add(tagId));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('标签创建失败: $error')));
    }
  }

  Future<void> _publish() async {
    if (_saving) {
      return;
    }
    if (!isValidMetadataJsonObject(_metadataController.text)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('metadata 必须是合法 JSON 对象')));
      return;
    }

    setState(() => _saving = true);

    try {
      final db = ref.read(appDatabaseProvider);
      await db.createDiary(
        title: widget.initialDraft.title,
        contentDocJson: widget.initialDraft.contentDocJson,
        contentText: widget.initialDraft.contentText,
        cover: _normalizedCover,
        metadataJson: _metadataController.text,
        tagIds: _selectedTagIds.toList(),
      );
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
      ).showSnackBar(SnackBar(content: Text('发布失败: $error')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _closeWithDraft() {
    Navigator.of(context).pop(
      widget.initialDraft.copyWith(
        cover: _normalizedCover,
        metadataJson: _metadataController.text,
        selectedTagIds: <int>{..._selectedTagIds},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagListProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _closeWithDraft();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('发布日记'),
          leading: IconButton(
            onPressed: _closeWithDraft,
            icon: const Icon(Icons.arrow_back),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: _saving ? null : _publish,
              child: const Text('发布'),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.initialDraft.title.trim().isEmpty
                    ? '未命名日记'
                    : widget.initialDraft.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                widget.initialDraft.contentText.trim().isEmpty
                    ? '正文为空'
                    : widget.initialDraft.contentText,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Text(
                '封面',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _coverController,
                decoration: const InputDecoration(
                  hintText: '封面地址（可选，本地路径或 URL）',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Text(
                    '标签',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _createTagInline,
                    icon: const FaIcon(FontAwesomeIcons.plus, size: 14),
                    label: const Text('新建标签'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              tagsAsync.when(
                data: (List<Tag> tags) {
                  if (tags.isEmpty) {
                    return const Text('暂无标签，可先新建');
                  }
                  return Wrap(
                    spacing: 8,
                    runSpacing: -8,
                    children: tags.map((Tag tag) {
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
              const SizedBox(height: 20),
              Text(
                'Metadata',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _metadataController,
                decoration: const InputDecoration(hintText: '{}'),
                minLines: 4,
                maxLines: 10,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
