import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:widget_screenshot_plus/widget_screenshot_plus.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/content_codec.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/precise_time_formatter.dart';
import '../../../utils/relative_time_formatter.dart';
import '../../widgets/qweather_icon.dart';
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
  final GlobalKey _shareCaptureKey = GlobalKey();
  final ScrollController _previewScrollController = ScrollController();
  bool _isSharingImage = false;
  bool _shareCaptureStaticCover = false;

  Widget _buildBackLeading() {
    return IconButton(
      tooltip: context.l10n.commonBack,
      onPressed: () => Navigator.of(context).maybePop(),
      icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
    );
  }

  @override
  void dispose() {
    _previewController?.dispose();
    _previewScrollController.dispose();
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
      l10n: context.l10n,
    );
  }

  String _buildShareCopyText(DiaryWithTags detail) {
    final l10n = context.l10n;
    final title = detail.diary.title.trim().isEmpty
        ? l10n.autoT0033
        : detail.diary.title.trim();
    final content = detail.diary.contentText.trim().isEmpty
        ? l10n.autoT0104
        : detail.diary.contentText.trim();
    final tags = detail.tags.isEmpty
        ? l10n.autoT0105
        : detail.tags.map((tag) => tag.name).join('、');
    final createdAt = _formatDateTime(detail.diary.createdAt);
    final updatedAt = _formatDateTime(detail.diary.updatedAt);

    return '''
${l10n.autoT0106}: $title
${l10n.autoT0107}: $createdAt
${l10n.autoT0108}: $updatedAt
${l10n.autoT0109}: $tags

${l10n.autoT0110}:
$content
''';
  }

  Future<void> _shareTextDirectly(DiaryWithTags detail) async {
    await Share.share(_buildShareCopyText(detail));
  }

  Future<void> _shareAsLongImage() async {
    if (_isSharingImage) {
      return;
    }
    final l10n = context.l10n;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final pixelRatio = MediaQuery.of(context).devicePixelRatio.clamp(1.0, 2.2);
    setState(() {
      _isSharingImage = true;
      // 分享截图时禁用封面折叠动画，避免长图拼接出现拖影。
      _shareCaptureStaticCover = true;
    });
    try {
      // 等待 bottom sheet 完全关闭，避免截图带上遮罩层。
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted) {
        return;
      }
      if (_previewScrollController.hasClients) {
        // 强制回到顶部，保证封面按“完整展开”形态进入截图。
        _previewScrollController.jumpTo(0);
      }
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final renderObject = _shareCaptureKey.currentContext?.findRenderObject();
      if (renderObject is! WidgetShotPlusRenderRepaintBoundary) {
        throw Exception('截图节点未就绪');
      }
      final imageBytes = await renderObject.screenshot(
        scrollController:
            _previewScrollController.hasClients ? _previewScrollController : null,
        format: ShotFormat.png,
        quality: 100,
        maxHeight: 22000,
        backgroundColor: surfaceColor,
        pixelRatio: pixelRatio,
      );
      if (imageBytes == null || imageBytes.isEmpty) {
        throw Exception(l10n.autoT0111);
      }
      final tempDirectory = await getTemporaryDirectory();
      final imagePath = p.join(
        tempDirectory.path,
        'diary_share_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(imageBytes, flush: true);

      await Share.shareXFiles(<XFile>[XFile(imageFile.path)]);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showHint(context.l10n.autoT0112(error.toString()));
    } finally {
      if (mounted) {
        setState(() {
          _isSharingImage = false;
          _shareCaptureStaticCover = false;
        });
      }
    }
  }

  Widget _buildStaticShareCoverSliver(String source) {
    return SliverToBoxAdapter(
      child: SizedBox(
        width: double.infinity,
        height: 420,
        child: DecoratedBox(
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
          child: _buildPreviewCoverImage(source),
        ),
      ),
    );
  }

  Widget _buildPreviewCoverImage(String source) {
    final uri = Uri.tryParse(source);
    final isRemote = uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    if (isRemote) {
      return Image.network(
        source,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }

    return Image.file(
      File(source),
      fit: BoxFit.contain,
      alignment: Alignment.center,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }

  void _showHint(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
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
          title: Text(context.l10n.autoT0094),
          content: Text(context.l10n.autoT0113),
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
                leading: const FaIcon(FontAwesomeIcons.image, size: 16),
                title: Text(context.l10n.autoT0114),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _shareAsLongImage();
                },
              ),
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.font, size: 16),
                title: Text(context.l10n.autoT0115),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _shareTextDirectly(detail);
                },
              ),
              ListTile(
                leading: FaIcon(
                  FontAwesomeIcons.trashCan,
                  size: 16,
                  color: colorScheme.error,
                ),
                title: Text(
                  context.l10n.commonDelete,
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

  String? _extractWeatherIconCode(DiaryWithTags detail) {
    final context = _extractContextMetadata(detail);
    final iconCode = context?['weatherIconCode']?.toString().trim();
    if (iconCode == null || iconCode.isEmpty) {
      return null;
    }
    return iconCode;
  }

  List<_MetaChipItem> _buildMetaChipItems(DiaryWithTags detail) {
    final items = <_MetaChipItem>[];
    final metadataContext = _extractContextMetadata(detail);
    if (metadataContext != null) {
      final mood = metadataContext['moodEmoji']?.toString().trim();
      if (mood != null && mood.isNotEmpty) {
        items.add(
            _MetaChipItem(
              kind: _MetaChipKind.mood,
              label: '${context.l10n.autoT0116} $mood',
            ),
        );
      }
      final energyRaw = metadataContext['energyLevel'];
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
            label: EnergyBatteryIndicator.descriptionForValue(
              normalizedEnergy,
              isZh: context.l10n.isZh,
            ),
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
    final weatherIconCode = _extractWeatherIconCode(detail);
    final locationWeatherItems = <Widget>[
      if (location != null && location.isNotEmpty)
        _buildMetaInlineItem(
          icon: FontAwesomeIcons.locationDot,
          label: location,
          color: colorScheme.onSurfaceVariant,
        ),
      if (weather != null && weather.isNotEmpty)
        _buildMetaInlineItem(
          leading: QWeatherIcon(
            iconCode: weatherIconCode,
            weatherText: weather,
            size: 12,
          ),
          label: weather,
          color: colorScheme.onSurfaceVariant,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildMetaInlineItem(
          icon: FontAwesomeIcons.clock,
          label: '${context.l10n.autoT0117} $relativeCreated',
          color: colorScheme.onSurfaceVariant,
        ),
        if (locationWeatherItems.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (int index = 0;
                    index < locationWeatherItems.length;
                    index++) ...<Widget>[
                  if (index > 0) const SizedBox(width: 12),
                  locationWeatherItems[index],
                ],
              ],
            ),
          ),
        ],
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
    IconData? icon,
    Widget? leading,
    required String label,
    required Color color,
  }) {
    assert(icon != null || leading != null);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (leading != null)
          leading
        else
          FaIcon(
            icon!,
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
        hasBeenEdited
            ? '${context.l10n.autoT0118} ${_formatPreciseTime(diary.updatedAt)}'
            : null;

    // 这里不能只看 contentText（纯文本镜像），否则“仅图片正文”会被误判为空。
    // 统一按 Quill 文档是否存在可见内容判断，图片/视频/嵌入都属于正文内容。
    final hasVisibleContent = diaryDocumentHasVisibleContent(controller.document);
    final contentBody =
        hasVisibleContent
            ? quill.QuillEditor.basic(
              controller: controller,
              config: quill.QuillEditorConfig(
                autoFocus: false,
                scrollable: false,
                padding: EdgeInsets.zero,
                showCursor: false,
                checkBoxReadOnly: false,
                embedBuilders: buildDiaryQuillEmbedBuilders(),
              ),
            )
            : Text(
              context.l10n.autoT0119,
              style: Theme.of(context).textTheme.bodyLarge,
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
            title: Text(context.l10n.autoT0120),
            leading: _buildBackLeading(),
          ),
          body: const Center(child: CircularProgressIndicator()),
        );
      },
      error: (Object error, StackTrace stackTrace) {
        return Scaffold(
          appBar: AppBar(
            centerTitle: true,
            title: Text(context.l10n.autoT0120),
            leading: _buildBackLeading(),
          ),
          body: Center(child: Text(context.l10n.autoT0121(error.toString()))),
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
                SnackBar(
                  content: Text(context.l10n.autoT0122),
                  duration: const Duration(seconds: 2),
                ),
              );
              Navigator.of(context).pop();
            });
            return Scaffold(
              appBar: AppBar(
                centerTitle: true,
                title: Text(context.l10n.autoT0120),
                leading: _buildBackLeading(),
              ),
              body: Center(child: Text(context.l10n.autoT0123)),
            );
          }

          return Scaffold(
            appBar: AppBar(
              centerTitle: true,
              title: Text(context.l10n.autoT0120),
              leading: _buildBackLeading(),
            ),
            body: Center(child: Text(context.l10n.autoT0124)),
          );
        }

        _hadLoadedData = true;
        _bindPreviewController(detail.diary.content);
        final title = detail.diary.title.trim().isEmpty
            ? context.l10n.autoT0033
            : detail.diary.title.trim();
        final coverSource = _resolvePreviewCover(detail.diary);

        return Scaffold(
          appBar: AppBar(
            centerTitle: true,
            title: Text(context.l10n.autoT0120),
            leading: _buildBackLeading(),
            actions: <Widget>[
              IconButton(
                tooltip: context.l10n.commonEdit,
                onPressed: _openEditor,
                icon: const FaIcon(FontAwesomeIcons.penToSquare, size: 16),
              ),
              IconButton(
                tooltip: context.l10n.autoT0125,
                onPressed: () => _showActionBottomSheet(detail),
                icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 16),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: WidgetShotPlus(
              key: _shareCaptureKey,
              child: CustomScrollView(
                controller: _previewScrollController,
                slivers: <Widget>[
                  if (coverSource != null)
                    _shareCaptureStaticCover
                        ? _buildStaticShareCoverSliver(coverSource)
                        : PublishDiaryCoverSliver(
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
