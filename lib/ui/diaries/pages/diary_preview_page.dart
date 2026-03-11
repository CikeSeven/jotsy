import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/content_codec.dart';
import '../../../core/services/app_service.dart';
import '../providers/diary_detail_provider.dart';
import '../widgets/diary_mobile_toolbar.dart';
import '../widgets/publish_diary_cover_sliver.dart';
import 'edit_diary_page.dart';

/// 预览页返回结果。
enum DiaryPreviewResult {
  deleted,
}

/// 日记预览页（阅读优先）。
///
/// 视觉策略：
/// - 封面 + 标题 + 轻量元信息 + 正文直出；
/// - 避免“后台详情卡片”观感；
/// - 保留右上角动作菜单（分享/编辑/删除）。
class DiaryPreviewPage extends ConsumerStatefulWidget {
  const DiaryPreviewPage({super.key, required this.diaryId});

  final String diaryId;

  @override
  ConsumerState<DiaryPreviewPage> createState() => _DiaryPreviewPageState();
}

class _DiaryPreviewPageState extends ConsumerState<DiaryPreviewPage> {
  quill.QuillController? _previewController;
  String? _boundContentRaw;
  bool _hadLoadedData = false;

  Widget _buildBackLeading() {
    return IconButton(
      tooltip: '返回',
      onPressed: () => Navigator.of(context).maybePop(),
      icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
    );
  }

  @override
  void dispose() {
    _previewController?.dispose();
    super.dispose();
  }

  /// 根据正文 JSON 绑定只读控制器。
  ///
  /// 仅在内容变化时重建，避免 build 阶段重复构造 controller。
  void _bindPreviewController(String contentRaw) {
    if (_boundContentRaw == contentRaw && _previewController != null) {
      return;
    }
    _previewController?.dispose();
    _boundContentRaw = contentRaw;
    _previewController = quill.QuillController(
      document: decodeDiaryContentToDocument(contentRaw),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
  }

  String _formatDateTime(DateTime value) {
    return DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal());
  }

  String _buildShareCopyText(DiaryWithTags detail) {
    final title = detail.diary.title.trim().isEmpty ? '无标题' : detail.diary.title.trim();
    final content = detail.diary.contentText.trim().isEmpty
        ? '（无正文）'
        : detail.diary.contentText.trim();
    final tags = detail.tags.isEmpty
        ? '无'
        : detail.tags.map((tag) => tag.name).join('、');
    final createdAt = _formatDateTime(detail.diary.createdAt);
    final updatedAt = _formatDateTime(detail.diary.updatedAt);

    return '''
标题：$title
创建时间：$createdAt
更新时间：$updatedAt
标签：$tags

正文：
$content
''';
  }

  Future<void> _copyShareText(DiaryWithTags detail) async {
    await Clipboard.setData(ClipboardData(text: _buildShareCopyText(detail)));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openEditor() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return EditDiaryPage(
            diaryId: widget.diaryId,
            entryMode: EditDiaryEntryMode.edit,
          );
        },
      ),
    );
    if (!mounted) {
      return;
    }
    ref.invalidate(diaryDetailProvider(widget.diaryId));
  }

  Future<bool> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: const Text('删除日记'),
          content: const Text('确认删除这条日记吗？'),
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
                foregroundColor: colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Future<void> _deleteDiary() async {
    final shouldDelete = await _confirmDelete();
    if (!mounted || !shouldDelete) {
      return;
    }
    final db = ref.read(appDatabaseProvider);
    await db.softDeleteDiary(widget.diaryId, touchUpdatedAt: false);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(DiaryPreviewResult.deleted);
  }

  Future<void> _showActionBottomSheet(DiaryWithTags detail) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.shareNodes, size: 16),
                title: const Text('分享'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _copyShareText(detail);
                },
              ),
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.penToSquare, size: 16),
                title: const Text('编辑'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _openEditor();
                },
              ),
              ListTile(
                leading: FaIcon(
                  FontAwesomeIcons.trashCan,
                  size: 16,
                  color: colorScheme.error,
                ),
                title: Text(
                  '删除',
                  style: TextStyle(color: colorScheme.error),
                ),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _deleteDiary();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// 封面优先级：
  /// 1) diary.cover；
  /// 2) 正文第一张图片；
  /// 3) 无封面时返回 null。
  String? _resolvePreviewCover(Diary diary) {
    final explicitCover = diary.cover?.trim();
    if (explicitCover != null && explicitCover.isNotEmpty) {
      return explicitCover;
    }
    return _extractFirstImageFromContent(diary.content);
  }

  String? _extractFirstImageFromContent(String contentJson) {
    final normalized = contentJson.trim();
    if (normalized.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(normalized);
      return _extractImageFromNode(decoded);
    } catch (_) {
      return null;
    }
  }

  String? _extractImageFromNode(Object? node) {
    if (node is List) {
      for (final item in node) {
        final image = _extractImageFromNode(item);
        if (image != null) {
          return image;
        }
      }
      return null;
    }

    if (node is! Map) {
      return null;
    }

    final insert = node['insert'];
    if (insert is Map) {
      final image = insert['image'];
      if (image is String && image.trim().isNotEmpty) {
        return image.trim();
      }
    }

    final type = node['type'];
    if (type == 'image') {
      final attributes = node['attributes'];
      if (attributes is Map) {
        final url = attributes['url'];
        if (url is String && url.trim().isNotEmpty) {
          return url.trim();
        }
      }
    }

    final root = node['root'];
    if (root != null) {
      final image = _extractImageFromNode(root);
      if (image != null) {
        return image;
      }
    }

    final children = node['children'];
    if (children != null) {
      final image = _extractImageFromNode(children);
      if (image != null) {
        return image;
      }
    }
    return null;
  }

  List<_MetaItem> _buildMetaItems(DiaryWithTags detail) {
    final items = <_MetaItem>[
      _MetaItem(
        icon: FontAwesomeIcons.clock,
        label: '创建 ${_formatDateTime(detail.diary.createdAt)}',
      ),
      _MetaItem(
        icon: FontAwesomeIcons.arrowsRotate,
        label: '更新 ${_formatDateTime(detail.diary.updatedAt)}',
      ),
    ];

    if (detail.tags.isNotEmpty) {
      items.add(
        _MetaItem(
          icon: FontAwesomeIcons.tags,
          label: detail.tags.map((tag) => '# ${tag.name}').join('  '),
        ),
      );
    }

    try {
      final decoded = jsonDecode(detail.diary.metadata);
      if (decoded is Map<String, dynamic>) {
        final context = decoded['context'];
        if (context is Map<String, dynamic>) {
          final location = context['location']?.toString().trim();
          if (location != null && location.isNotEmpty) {
            items.add(
              _MetaItem(icon: FontAwesomeIcons.locationDot, label: location),
            );
          }
          final weather = context['weather']?.toString().trim();
          if (weather != null && weather.isNotEmpty) {
            items.add(
              _MetaItem(icon: FontAwesomeIcons.cloudSun, label: weather),
            );
          }
          final mood = context['moodEmoji']?.toString().trim();
          if (mood != null && mood.isNotEmpty) {
            items.add(
              _MetaItem(icon: FontAwesomeIcons.faceSmile, label: mood),
            );
          }
          final energy = context['energyLevel'];
          if (energy != null) {
            items.add(
              _MetaItem(
                icon: FontAwesomeIcons.batteryHalf,
                label: '精力 $energy',
              ),
            );
          }
        }
      }
    } catch (_) {}

    return items;
  }

  Widget _buildMetaSection(DiaryWithTags detail) {
    final colorScheme = Theme.of(context).colorScheme;
    final items = _buildMetaItems(detail);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FaIcon(
                item.icon,
                size: 12,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Text(
                  item.label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }

  Widget _buildContentSection(DiaryWithTags detail) {
    final controller = _previewController;
    if (controller == null) {
      return const SizedBox.shrink();
    }
    if (detail.diary.contentText.trim().isEmpty) {
      return Text(
        '今天还没有写下正文',
        style: Theme.of(context).textTheme.bodyLarge,
      );
    }
    return quill.QuillEditor.basic(
      controller: controller,
      config: quill.QuillEditorConfig(
        autoFocus: false,
        scrollable: false,
        padding: EdgeInsets.zero,
        embedBuilders: buildDiaryQuillEmbedBuilders(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(diaryDetailProvider(widget.diaryId));

    return detailAsync.when(
      loading: () {
        return Scaffold(
          appBar: AppBar(
            centerTitle: true,
            title: const Text('日记'),
            leading: _buildBackLeading(),
          ),
          body: const Center(child: CircularProgressIndicator()),
        );
      },
      error: (Object error, StackTrace stackTrace) {
        return Scaffold(
          appBar: AppBar(
            centerTitle: true,
            title: const Text('日记'),
            leading: _buildBackLeading(),
          ),
          body: Center(child: Text('加载失败: $error')),
        );
      },
      data: (DiaryWithTags? detail) {
        if (detail == null) {
          if (_hadLoadedData) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('日记已不存在'),
                  duration: Duration(seconds: 2),
                ),
              );
              Navigator.of(context).pop();
            });
            return Scaffold(
              appBar: AppBar(
                centerTitle: true,
                title: const Text('日记'),
                leading: _buildBackLeading(),
              ),
              body: const Center(child: Text('日记已不存在，正在返回...')),
            );
          }

          return Scaffold(
            appBar: AppBar(
              centerTitle: true,
              title: const Text('日记'),
              leading: _buildBackLeading(),
            ),
            body: const Center(child: Text('日记不存在')),
          );
        }

        _hadLoadedData = true;
        _bindPreviewController(detail.diary.content);
        final title = detail.diary.title.trim().isEmpty ? '无标题' : detail.diary.title.trim();
        final coverSource = _resolvePreviewCover(detail.diary);

        return Scaffold(
          appBar: AppBar(
            centerTitle: true,
            title: const Text('日记'),
            leading: _buildBackLeading(),
            actions: <Widget>[
              IconButton(
                tooltip: '更多',
                onPressed: () => _showActionBottomSheet(detail),
                icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 16),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: CustomScrollView(
              slivers: <Widget>[
                if (coverSource != null)
                  PublishDiaryCoverSliver(
                    cover: coverSource,
                    maxExtentHeight: 300,
                    padding: EdgeInsets.zero,
                    borderRadius: BorderRadius.zero,
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: _buildMetaSection(detail),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                    child: _buildContentSection(detail),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MetaItem {
  const _MetaItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}
