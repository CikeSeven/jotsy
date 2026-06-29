import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_to_pdf/flutter_quill_to_pdf.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:widget_screenshot_plus/widget_screenshot_plus.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/content_codec.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/precise_time_formatter.dart';
import '../../../utils/relative_time_formatter.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/qweather_icon.dart';
import '../providers/diary_detail_provider.dart';
import '../utils/diary_markdown_exporter.dart';
import '../widgets/diary_mobile_toolbar.dart';
import '../widgets/energy_battery_indicator.dart';
import '../widgets/publish_diary_cover_sliver.dart';
import '../../widgets/image_viewer_page.dart';
import 'edit_diary_page.dart';
import 'locked_diary_page.dart';
import '../models/time_capsule.dart';

/// 预览页返回结果。
enum DiaryPreviewResult { deleted }

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
  DiaryWithTags? _currentDetailForTodoSave;
  StreamSubscription<quill.DocChange>? _previewDocChangesSubscription;
  Timer? _todoAutoSaveDebounceTimer;
  bool _savingTodoState = false;
  bool _todoSaveQueued = false;
  bool _hadLoadedData = false;
  final GlobalKey _shareCaptureKey = GlobalKey();
  final ScrollController _previewScrollController = ScrollController();
  bool _isSharingImage = false;
  bool _shareCaptureStaticCover = false;
  bool _isExportingFile = false;
  pw.Font? _cachedPdfUnifiedFont;
  Future<pw.Font>? _pdfUnifiedFontLoading;
  bool _showActionLoading = false;
  String _actionLoadingLabel = '';

  Widget _buildBackLeading() {
    return IconButton(
      tooltip: context.l10n.commonBack,
      onPressed: () => Navigator.of(context).maybePop(),
      icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
    );
  }

  SliverAppBar _buildPreviewSliverAppBar({required DiaryWithTags detail}) {
    final colorScheme = Theme.of(context).colorScheme;
    return SliverAppBar(
      floating: true,
      pinned: false,
      centerTitle: true,
      automaticallyImplyLeading: false,
      leading: _buildBackLeading(),
      title: Text(context.l10n.autoT0120),
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
      foregroundColor: colorScheme.onSurface,
      backgroundColor: colorScheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    );
  }

  @override
  void dispose() {
    _todoAutoSaveDebounceTimer?.cancel();
    _previewDocChangesSubscription?.cancel();
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
    _previewDocChangesSubscription?.cancel();
    _previewController?.dispose();
    _boundContentRaw = contentRaw;
    _previewController = quill.QuillController(
      document: decodeDiaryContentToDocument(contentRaw),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
    _previewDocChangesSubscription = _previewController!.changes.listen((
      quill.DocChange change,
    ) {
      // 预览页是只读模式，唯一允许的本地变更是待办勾选状态。
      if (change.source != quill.ChangeSource.local) {
        return;
      }
      _scheduleTodoStateAutoSave();
    });
  }

  /// 待办状态自动保存（防抖）。
  ///
  /// 浏览页连续勾选多个待办时，不需要每次都立即写库，统一在短防抖窗口后提交。
  void _scheduleTodoStateAutoSave() {
    _todoAutoSaveDebounceTimer?.cancel();
    _todoAutoSaveDebounceTimer = Timer(
      const Duration(milliseconds: 260),
      _saveTodoStateIfNeeded,
    );
  }

  Future<void> _saveTodoStateIfNeeded() async {
    final detail = _currentDetailForTodoSave;
    final controller = _previewController;
    if (detail == null || controller == null) {
      return;
    }

    final contentDocJson = encodeDiaryDocumentToJson(controller.document);
    // 内容未变化直接跳过，减少无效写库。
    if (contentDocJson == detail.diary.content) {
      return;
    }

    if (_savingTodoState) {
      _todoSaveQueued = true;
      return;
    }

    _savingTodoState = true;
    try {
      final db = ref.read(appDatabaseProvider);
      await db.updateDiary(
        diaryId: detail.diary.diaryId,
        title: detail.diary.title,
        contentDocJson: contentDocJson,
        contentText: extractPlainTextFromDiaryDocument(controller.document),
        metadataJson: detail.diary.metadata,
        cover: detail.diary.cover,
        tagIds: detail.tags.map((tag) => tag.id).toList(growable: false),
      );
      if (mounted) {
        ref.invalidate(diaryDetailProvider(widget.diaryId));
      }
    } catch (_) {
      // 待办自动保存失败不打断阅读流程，仅静默跳过本次。
    } finally {
      _savingTodoState = false;
      if (_todoSaveQueued) {
        _todoSaveQueued = false;
        _scheduleTodoStateAutoSave();
      }
    }
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

  Future<void> _shareAsLongImage() async {
    if (_isSharingImage || _showActionLoading) {
      return;
    }
    await _runPreviewActionWithLoading(
      label: context.l10n.autoT0114,
      action: () async {
        final l10n = context.l10n;
        final surfaceColor = Theme.of(context).colorScheme.surface;
        final pixelRatio = MediaQuery.of(
          context,
        ).devicePixelRatio.clamp(1.0, 2.2);
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
          final renderObject =
              _shareCaptureKey.currentContext?.findRenderObject();
          if (renderObject is! WidgetShotPlusRenderRepaintBoundary) {
            throw Exception('截图节点未就绪');
          }
          final imageBytes = await renderObject.screenshot(
            scrollController:
                _previewScrollController.hasClients
                    ? _previewScrollController
                    : null,
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
      },
    );
  }

  /// 统一动作加载态：
  /// - 提供共享的遮罩 loading；
  /// - 限制最短可见时长，避免“闪现式”动画；
  /// - 在真正重任务前预留一帧，让动画先渲染出来。
  Future<void> _runPreviewActionWithLoading({
    required String label,
    required Future<void> Function() action,
  }) async {
    if (_showActionLoading) {
      return;
    }
    const minVisibleDuration = Duration(milliseconds: 320);
    final startedAt = DateTime.now();
    if (mounted) {
      setState(() {
        _showActionLoading = true;
        _actionLoadingLabel = label;
      });
    }

    // 先渲染 loading，再执行 IO/截图等重任务，避免动画“卡住不动”。
    await Future<void>.delayed(const Duration(milliseconds: 24));

    try {
      await action();
    } finally {
      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed < minVisibleDuration) {
        await Future<void>.delayed(minVisibleDuration - elapsed);
      }
      if (mounted) {
        setState(() {
          _showActionLoading = false;
          _actionLoadingLabel = '';
        });
      }
    }
  }

  String _buildExportFileBaseName(DiaryWithTags detail) {
    final rawTitle =
        detail.diary.title.trim().isEmpty ? 'diary' : detail.diary.title.trim();
    final normalized = rawTitle
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    final short =
        normalized.length > 24 ? normalized.substring(0, 24) : normalized;
    return short.isEmpty ? 'diary' : short;
  }

  /// 加载并缓存 PDF 统一字体。
  ///
  /// 说明：
  /// - 统一使用一套中文字体，避免中英混排时字体风格跳变；
  /// - `pw.Font.ttf` 会在生成时按实际字符做子集嵌入，减少体积；
  /// - 这里只保留一套 Regular 字体，避免多字重导致导出包体膨胀。
  Future<pw.Font> _loadPdfUnifiedFont() async {
    final cached = _cachedPdfUnifiedFont;
    if (cached != null) {
      return cached;
    }
    final loading = _pdfUnifiedFontLoading;
    if (loading != null) {
      return loading;
    }
    final task = () async {
      try {
        final data = await rootBundle.load(
          'assets/fonts/harmonyos_sans_sc/HarmonyOS_Sans_SC_Regular.ttf',
        );
        final font = pw.Font.ttf(data);
        _cachedPdfUnifiedFont = font;
        return font;
      } finally {
        _pdfUnifiedFontLoading = null;
      }
    }();
    _pdfUnifiedFontLoading = task;
    return task;
  }

  Future<bool> _saveExportBytes({
    required Uint8List bytes,
    required String fileName,
    required List<String> allowedExtensions,
  }) async {
    String? savePath;
    if (Platform.isAndroid || Platform.isIOS) {
      savePath = await FilePicker.platform.saveFile(
        dialogTitle: context.l10n.previewExportSaveDialogTitle,
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        bytes: bytes,
      );
    } else {
      savePath = await FilePicker.platform.saveFile(
        dialogTitle: context.l10n.previewExportSaveDialogTitle,
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
      );
      if (savePath != null && savePath.trim().isNotEmpty) {
        final outputFile = File(savePath);
        await outputFile.parent.create(recursive: true);
        await outputFile.writeAsBytes(bytes, flush: true);
      }
    }
    return savePath != null && savePath.trim().isNotEmpty;
  }

  Future<void> _exportMarkdown(DiaryWithTags detail) async {
    final controller = _previewController;
    if (controller == null || _isExportingFile || _showActionLoading) {
      return;
    }
    await _runPreviewActionWithLoading(
      label: context.l10n.previewExportMarkdown,
      action: () async {
        setState(() => _isExportingFile = true);
        try {
          final markdown = DiaryMarkdownExporter.build(
            title: detail.diary.title,
            createdAt: detail.diary.createdAt,
            updatedAt: detail.diary.updatedAt,
            tagNames: detail.tags
                .map((tag) => tag.name)
                .toList(growable: false),
            document: controller.document,
          );
          final bytes = Uint8List.fromList(utf8.encode(markdown));
          final fileName =
              '${_buildExportFileBaseName(detail)}_${DateTime.now().millisecondsSinceEpoch}.md';
          final saved = await _saveExportBytes(
            bytes: bytes,
            fileName: fileName,
            allowedExtensions: const <String>['md'],
          );
          if (!mounted) {
            return;
          }
          if (!saved) {
            _showHint(context.l10n.previewExportCanceled);
            return;
          }
          _showHint(context.l10n.previewExportSuccess);
        } catch (error) {
          if (!mounted) {
            return;
          }
          _showHint(context.l10n.previewExportFailed(error.toString()));
        } finally {
          if (mounted) {
            setState(() => _isExportingFile = false);
          }
        }
      },
    );
  }

  Future<void> _exportPdf(DiaryWithTags detail) async {
    final controller = _previewController;
    if (controller == null || _isExportingFile || _showActionLoading) {
      return;
    }
    final textDirection = Directionality.of(context);
    await _runPreviewActionWithLoading(
      label: context.l10n.previewExportPdf,
      action: () async {
        setState(() => _isExportingFile = true);
        try {
          final unifiedFont = await _loadPdfUnifiedFont();
          final unifiedTheme = pw.ThemeData.withFont(
            base: unifiedFont,
            bold: unifiedFont,
            italic: unifiedFont,
            boldItalic: unifiedFont,
            fontFallback: <pw.Font>[unifiedFont],
          );
          final converter = PDFConverter(
            pageFormat: PDFPageFormat.a4,
            document: controller.document.toDelta(),
            textDirection: textDirection,
            themeData: unifiedTheme,
            codeBlockFont: unifiedFont,
            fallbacks: <pw.Font>[unifiedFont],
            onRequestFontFamily: (FontFamilyRequest _) {
              return FontFamilyResponse(
                fontNormalV: unifiedFont,
                boldFontV: unifiedFont,
                italicFontV: unifiedFont,
                boldItalicFontV: unifiedFont,
                fallbacks: <pw.Font>[unifiedFont],
              );
            },
          );
          final doc = await converter.createDocument();
          if (doc == null) {
            throw Exception('PDF build failed');
          }
          final bytes = Uint8List.fromList(await doc.save());
          final fileName =
              '${_buildExportFileBaseName(detail)}_${DateTime.now().millisecondsSinceEpoch}.pdf';
          final saved = await _saveExportBytes(
            bytes: bytes,
            fileName: fileName,
            allowedExtensions: const <String>['pdf'],
          );
          if (!mounted) {
            return;
          }
          if (!saved) {
            _showHint(context.l10n.previewExportCanceled);
            return;
          }
          _showHint(context.l10n.previewExportSuccess);
        } catch (error) {
          if (!mounted) {
            return;
          }
          _showHint(context.l10n.previewExportFailed(error.toString()));
        } finally {
          if (mounted) {
            setState(() => _isExportingFile = false);
          }
        }
      },
    );
  }

  Widget _buildStaticShareCoverSliver(String source) {
    return SliverToBoxAdapter(
      child: SizedBox(
        width: double.infinity,
        height: 420,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
          ),
          child: _buildPreviewCoverImage(source),
        ),
      ),
    );
  }

  Widget _buildPreviewCoverImage(String source) {
    final uri = Uri.tryParse(source);
    final isRemote =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    // 预览封面框固定高 420，按设备像素比换算解码上限，
    // 避免把原图整张解码进内存（多图日记内存峰值会明显升高）。
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheHeight = (420 * dpr).round();
    if (isRemote) {
      return Image.network(
        source,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        cacheHeight: cacheHeight,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }

    return Image.file(
      File(source),
      fit: BoxFit.contain,
      alignment: Alignment.center,
      cacheHeight: cacheHeight,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }

  Widget _buildActionLoadingOverlay() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return IgnorePointer(
      ignoring: !_showActionLoading,
      child: AnimatedOpacity(
        opacity: _showActionLoading ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: ColoredBox(
          color: colorScheme.surface.withValues(alpha: 0.72),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                LoadingIndicatorM3E(
                  variant: LoadingIndicatorM3EVariant.contained,
                  constraints: const BoxConstraints.tightFor(
                    width: 72,
                    height: 72,
                  ),
                  semanticLabel: _actionLoadingLabel,
                ),
                const SizedBox(height: 10),
                Text(
                  _actionLoadingLabel,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showHint(String message) {
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: context,
        snackBar: SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      ),
    );
  }

  void _openImageViewer(List<String> sources, String initialSource) {
    final normalizedSources = <String>[];
    final seenSources = <String>{};
    for (final source in sources) {
      final normalized = source.trim();
      if (normalized.isEmpty || !seenSources.add(normalized)) {
        continue;
      }
      normalizedSources.add(normalized);
    }
    final normalizedInitialSource = initialSource.trim();
    if (normalizedInitialSource.isNotEmpty &&
        !seenSources.contains(normalizedInitialSource)) {
      normalizedSources.insert(0, normalizedInitialSource);
    }
    if (normalizedSources.isEmpty) {
      return;
    }

    final initialIndex = math.max(
      0,
      normalizedSources.indexOf(normalizedInitialSource),
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => ImageViewerPage(
              items: normalizedSources
                  .map((source) => ImageViewerItem(source: source))
                  .toList(growable: false),
              initialIndex: initialIndex,
            ),
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
              style: TextButton.styleFrom(foregroundColor: colorScheme.error),
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
                leading: const FaIcon(FontAwesomeIcons.fileLines, size: 16),
                title: Text(context.l10n.previewExportMarkdown),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _exportMarkdown(detail);
                },
              ),
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.filePdf, size: 16),
                title: Text(context.l10n.previewExportPdf),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _exportPdf(detail);
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
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.bodyLarge?.copyWith(color: colorScheme.error),
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

  /// 图片浏览来源优先级：
  /// 1) diary.cover；
  /// 2) 正文内所有图片。
  ///
  /// 预览页封面与正文图片共用同一组来源，点击任一图片可直接进入图片浏览页并左右切换。
  List<String> _resolvePreviewImages(Diary diary) {
    final sources = <String>[];
    final explicitCover = diary.cover?.trim();
    if (explicitCover != null && explicitCover.isNotEmpty) {
      sources.add(explicitCover);
    }
    sources.addAll(_extractImageSourcesFromContent(diary.content));
    return sources;
  }

  List<String> _extractImageSourcesFromContent(String contentJson) {
    final normalized = contentJson.trim();
    if (normalized.isEmpty) {
      return const <String>[];
    }

    try {
      final decoded = jsonDecode(normalized);
      final sources = <String>[];
      _collectImagesFromNode(decoded, sources);
      return sources;
    } catch (_) {
      return const <String>[];
    }
  }

  void _collectImagesFromNode(Object? node, List<String> sources) {
    if (node is List) {
      for (final item in node) {
        _collectImagesFromNode(item, sources);
      }
      return;
    }

    if (node is! Map) {
      return;
    }

    final insert = node['insert'];
    if (insert is Map) {
      final image = insert['image'];
      if (image is String && image.trim().isNotEmpty) {
        sources.add(image.trim());
      }
    }

    final type = node['type'];
    if (type == 'image') {
      final attributes = node['attributes'];
      if (attributes is Map) {
        final url = attributes['url'];
        if (url is String && url.trim().isNotEmpty) {
          sources.add(url.trim());
        }
      }
    }

    final root = node['root'];
    if (root != null) {
      _collectImagesFromNode(root, sources);
    }

    final children = node['children'];
    if (children != null) {
      _collectImagesFromNode(children, sources);
    }
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
        final normalizedEnergy = EnergyBatteryIndicator.normalizeValue(
          parsedEnergy,
        );
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
                for (
                  int index = 0;
                  index < locationWeatherItems.length;
                  index++
                ) ...<Widget>[
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

  Widget _buildCapsuleUnlockedInsight(DiaryWithTags detail) {
    final state = TimeCapsuleState.fromFields(
      lockedAt: detail.diary.capsuleLockedAt,
      unlockAt: detail.diary.capsuleUnlockAt,
      now: DateTime.now(),
    );
    if (!state.isCapsule || state.isLocked) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    final metadataContext = _extractContextMetadata(detail);
    final mood = metadataContext?['moodEmoji']?.toString().trim();
    final message =
        mood != null && mood.isNotEmpty
            ? context.l10n.timeCapsuleUnlockedInsight(mood)
            : context.l10n.timeCapsuleUnlockedInsightNoMood;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FaIcon(
            FontAwesomeIcons.unlockKeyhole,
            size: 16,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(_MetaChipItem item, ColorScheme colorScheme) {
    final isEnergyItem =
        item.kind == _MetaChipKind.energy && item.energyLevel != null;
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
            EnergyBatteryIndicator(value: item.energyLevel!, iconSize: 14)
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
        if (leading != null) leading else FaIcon(icon!, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
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
    final hasVisibleContent = diaryDocumentHasVisibleContent(
      controller.document,
    );
    final previewImages = _resolvePreviewImages(diary);
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
                embedBuilders: buildDiaryQuillEmbedBuilders(
                  onImageClicked: (imageSource) {
                    _openImageViewer(previewImages, imageSource);
                  },
                ),
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
          appBar: AppTopBar(
            centerTitle: true,
            title: Text(context.l10n.autoT0120),
            leading: _buildBackLeading(),
          ),
          body: const Center(child: CircularProgressIndicator()),
        );
      },
      error: (Object error, StackTrace stackTrace) {
        return Scaffold(
          appBar: AppTopBar(
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
              _showHint(context.l10n.autoT0122);
              Navigator.of(context).pop();
            });
            return Scaffold(
              appBar: AppTopBar(
                centerTitle: true,
                title: Text(context.l10n.autoT0120),
                leading: _buildBackLeading(),
              ),
              body: Center(child: Text(context.l10n.autoT0123)),
            );
          }

          return Scaffold(
            appBar: AppTopBar(
              centerTitle: true,
              title: Text(context.l10n.autoT0120),
              leading: _buildBackLeading(),
            ),
            body: Center(child: Text(context.l10n.autoT0124)),
          );
        }

        _hadLoadedData = true;
        final capsuleState = TimeCapsuleState.fromFields(
          lockedAt: detail.diary.capsuleLockedAt,
          unlockAt: detail.diary.capsuleUnlockAt,
          now: DateTime.now(),
        );
        if (capsuleState.isLocked) {
          return LockedDiaryPage(diaryId: widget.diaryId);
        }
        _currentDetailForTodoSave = detail;
        _bindPreviewController(detail.diary.content);
        final title =
            detail.diary.title.trim().isEmpty
                ? context.l10n.autoT0033
                : detail.diary.title.trim();
        final previewImages = _resolvePreviewImages(detail.diary);
        final coverSource = previewImages.firstOrNull;

        return Scaffold(
          body: SafeArea(
            top: true,
            child: Stack(
              children: <Widget>[
                WidgetShotPlus(
                  key: _shareCaptureKey,
                  child: CustomScrollView(
                    controller: _previewScrollController,
                    slivers: <Widget>[
                      _buildPreviewSliverAppBar(detail: detail),
                      if (coverSource != null)
                        _shareCaptureStaticCover
                            ? _buildStaticShareCoverSliver(coverSource)
                            : PublishDiaryCoverSliver(
                              cover: coverSource,
                              maxExtentHeight: 420,
                              padding: EdgeInsets.zero,
                              borderRadius: BorderRadius.zero,
                              onTap: () {
                                _openImageViewer(previewImages, coverSource);
                              },
                            ),

                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              _buildCapsuleUnlockedInsight(detail),
                              if (capsuleState.isCapsule)
                                const SizedBox(height: 14),
                              _buildContentSection(detail),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned.fill(child: _buildActionLoadingOverlay()),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum _MetaChipKind { tag, mood, energy }

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
