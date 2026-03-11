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
import '../../../l10n/app_localizations.dart';
import '../../../utils/precise_time_formatter.dart';
import '../../../utils/relative_time_formatter.dart';
import '../providers/diary_detail_provider.dart';
import '../widgets/diary_mobile_toolbar.dart';
import '../widgets/energy_battery_indicator.dart';
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

  String _formatRelativeTime(DateTime value) {
    return RelativeTimeFormatter.formatUpdatedAt(
      updatedAt: value,
      now: DateTime.now(),
      l10n: context.l10n,
    );
  }

  /// 用于“最后编辑于”文案的精确时间（分钟级）。
  String _formatPreciseTime(DateTime value) {
    return PreciseTimeFormatter.format(
      target: value,
      now: DateTime.now(),
    );
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

  Map<String, dynamic>? _extractContextMetadata(DiaryWithTags detail) {
    try {
      final decoded = jsonDecode(detail.diary.metadata);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final context = decoded['context'];
      if (context is! Map<String, dynamic>) {
        return null;
      }
      return context;
    } catch (_) {
      return null;
    }
  }

  String? _extractLocationLabel(DiaryWithTags detail) {
    final context = _extractContextMetadata(detail);
    final location = context?['location']?.toString().trim();
    if (location == null || location.isEmpty) {
      return null;
    }
    return location;
  }

  String? _extractWeatherLabel(DiaryWithTags detail) {
    final context = _extractContextMetadata(detail);
    final weather = context?['weather']?.toString().trim();
    if (weather == null || weather.isEmpty) {
      return null;
    }
    return weather;
  }

  List<_MetaChipItem> _buildMetaChipItems(DiaryWithTags detail) {
    final items = <_MetaChipItem>[];
    final context = _extractContextMetadata(detail);
    if (context != null) {
      final mood = context['moodEmoji']?.toString().trim();
      if (mood != null && mood.isNotEmpty) {
        items.add(
          _MetaChipItem(
            kind: _MetaChipKind.mood,
            label: '心情 $mood',
          ),
        );
      }
      final energyRaw = context['energyLevel'];
      final parsedEnergy = switch (energyRaw) {
        num value => value.toDouble(),
        String value => double.tryParse(value),
        _ => null,
      };
      if (parsedEnergy != null) {
        final normalizedEnergy = EnergyBatteryIndicator.normalizeValue(parsedEnergy);
        items.add(
          _MetaChipItem(
            kind: _MetaChipKind.energy,
            label: EnergyBatteryIndicator.descriptionForValue(normalizedEnergy),
            energyLevel: normalizedEnergy,
          ),
        );
      }
    }

    if (detail.tags.isNotEmpty) {
      for (final tag in detail.tags) {
        items.add(
          _MetaChipItem(
            kind: _MetaChipKind.tag,
            label: tag.name,
            tagColor: tag.color,
          ),
        );
      }
    }

    return items;
  }

  Widget _buildMetaSection(DiaryWithTags detail) {
    final colorScheme = Theme.of(context).colorScheme;
    final chips = _buildMetaChipItems(detail);
    final relativeCreated = _formatRelativeTime(detail.diary.createdAt);
    final location = _extractLocationLabel(detail);
    final weather = _extractWeatherLabel(detail);
    final inlineItems = <Widget>[
      _buildMetaInlineItem(
        icon: FontAwesomeIcons.clock,
        label: '发表于$relativeCreated',
        color: colorScheme.onSurfaceVariant,
      ),
      if (location != null && location.isNotEmpty)
        _buildMetaInlineItem(
          icon: FontAwesomeIcons.locationDot,
          label: location,
          color: colorScheme.onSurfaceVariant,
        ),
      if (weather != null && weather.isNotEmpty)
        _buildMetaInlineItem(
          icon: FontAwesomeIcons.cloudSun,
          label: weather,
          color: colorScheme.onSurfaceVariant,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (int index = 0; index < inlineItems.length; index++) ...<Widget>[
                if (index > 0) const SizedBox(width: 12),
                inlineItems[index],
              ],
            ],
          ),
        ),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips
                .map((item) => _buildMetaChip(item, colorScheme))
                .toList(growable: false),
          ),
        ],
      ],
    );
  }

  Widget _buildMetaChip(_MetaChipItem item, ColorScheme colorScheme) {
    final isEnergyItem = item.kind == _MetaChipKind.energy && item.energyLevel != null;
    final isTagItem = item.kind == _MetaChipKind.tag && item.tagColor != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (isEnergyItem)
            EnergyBatteryIndicator(
              value: item.energyLevel!,
              iconSize: 14,
            )
          else if (isTagItem)
            Text(
              '#',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Color(item.tagColor!),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          if (isEnergyItem || isTagItem) const SizedBox(width: 6),
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
  }

  Widget _buildMetaInlineItem({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FaIcon(
          icon,
          size: 12,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color,
              ),
        ),
      ],
    );
  }

  Widget _buildContentSection(DiaryWithTags detail) {
    final controller = _previewController;
    if (controller == null) {
      return const SizedBox.shrink();
    }
    final diary = detail.diary;
    final hasBeenEdited = !diary.updatedAt.isAtSameMomentAs(diary.createdAt);
    final editedText =
        hasBeenEdited ? '最后编辑于 ${_formatPreciseTime(diary.updatedAt)}' : null;

    final contentBody =
        detail.diary.contentText.trim().isEmpty
            ? Text(
              '今天还没有写下正文',
              style: Theme.of(context).textTheme.bodyLarge,
            )
            : quill.QuillEditor.basic(
              controller: controller,
              config: quill.QuillEditorConfig(
                autoFocus: false,
                scrollable: false,
                padding: EdgeInsets.zero,
                embedBuilders: buildDiaryQuillEmbedBuilders(),
              ),
            );

    if (editedText == null) {
      return contentBody;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        contentBody,
        const SizedBox(height: 16),
        Text(
          editedText,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
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
                    maxExtentHeight: 420,
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

enum _MetaChipKind {
  tag,
  mood,
  energy,
}

class _MetaChipItem {
  const _MetaChipItem({
    required this.kind,
    required this.label,
    this.energyLevel,
    this.tagColor,
  });

  final _MetaChipKind kind;
  final String label;
  final double? energyLevel;
  final int? tagColor;
}
