import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:widget_screenshot_plus/widget_screenshot_plus.dart';

import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/backup_password_dialog.dart';
import '../utils/diary_export_saver.dart';
import '../utils/diary_markdown_exporter.dart';
import '../utils/diary_pdf_exporter.dart';
import 'diary_file_export_controller.dart';

/// 预览页“更多”面板里的分享与导出：长图、Markdown、PDF 与日记文件。
///
/// 输入：截图节点 [captureKey] 与正文 [scrollController]（页面持有），以及
/// 每次调用时传入的 context、日记与 Quill 文档。输出：页面要显示的加载遮罩
/// 与静态头图状态（经 [ChangeNotifier] 通知），结果提示经 [onHint] 给出。
/// 副作用：写临时文件，调起系统分享与保存对话框。
///
/// 同一时刻只运行一个动作，进行中再次触发直接忽略。动作开始前先让加载遮罩
/// 真正绘制出来，并保证遮罩的最短可见时长，避免“闪现式”动画。调用方的
/// context 卸载后不再提示，也不再通知。
class DiaryPreviewExportController extends ChangeNotifier {
  DiaryPreviewExportController({
    required this.captureKey,
    required this.scrollController,
    required this.onHint,
  });

  /// 加载遮罩的最短可见时长（防闪，不是动画时长）。
  static const Duration _minLoadingVisible = Duration(milliseconds: 320);

  final GlobalKey captureKey;
  final ScrollController scrollController;
  final ValueChanged<String> onHint;

  bool _showLoading = false;
  String _loadingLabel = '';
  bool _sharingImage = false;
  bool _staticCover = false;
  bool _exportingFile = false;
  bool _disposed = false;
  final DiaryPdfExporter _pdf = DiaryPdfExporter();

  /// 是否显示动作加载遮罩。
  bool get showLoading => _showLoading;
  String get loadingLabel => _loadingLabel;

  /// 分享长图期间用静态头图替换会随滚动折叠的头图，避免长图拼接出现拖影。
  bool get staticCover => _staticCover;

  /// 正在执行任一动作（遮罩、截图或导出中）。
  bool get busy => _showLoading || _sharingImage || _exportingFile;

  void _update(VoidCallback change) {
    change();
    if (!_disposed) {
      notifyListeners();
    }
  }

  /// 分享整页长图。
  Future<void> shareLongImage(BuildContext context) async {
    if (_sharingImage || _showLoading) {
      return;
    }
    await _runWithLoading(
      context,
      label: context.l10n.autoT0114,
      action: () async {
        final l10n = context.l10n;
        final surfaceColor = Theme.of(context).colorScheme.surface;
        final pixelRatio = MediaQuery.of(
          context,
        ).devicePixelRatio.clamp(1.0, 2.2);
        _update(() {
          _sharingImage = true;
          // 分享截图时禁用封面折叠动画，避免长图拼接出现拖影。
          _staticCover = true;
        });
        try {
          // 等待 bottom sheet 完全关闭，避免截图带上遮罩层。
          await Future<void>.delayed(const Duration(milliseconds: 80));
          if (!context.mounted) {
            return;
          }
          if (scrollController.hasClients) {
            // 强制回到顶部，保证封面按“完整展开”形态进入截图。
            scrollController.jumpTo(0);
          }
          await Future<void>.delayed(const Duration(milliseconds: 60));
          final renderObject = captureKey.currentContext?.findRenderObject();
          if (renderObject is! WidgetShotPlusRenderRepaintBoundary) {
            throw Exception('截图节点未就绪');
          }
          final imageBytes = await renderObject.screenshot(
            scrollController: scrollController.hasClients
                ? scrollController
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
          if (!context.mounted) {
            return;
          }
          onHint(context.l10n.autoT0112(error.toString()));
        } finally {
          if (context.mounted) {
            _update(() {
              _sharingImage = false;
              _staticCover = false;
            });
          }
        }
      },
    );
  }

  /// 导出 Markdown。
  Future<void> exportMarkdown(
    BuildContext context, {
    required DiaryWithTags detail,
    required quill.Document document,
  }) {
    return _exportFile(
      context,
      label: context.l10n.previewExportMarkdown,
      extension: 'md',
      detail: detail,
      build: () async {
        final markdown = DiaryMarkdownExporter.build(
          title: detail.diary.title,
          createdAt: detail.diary.createdAt,
          updatedAt: detail.diary.updatedAt,
          tagNames: detail.tags.map((tag) => tag.name).toList(growable: false),
          document: document,
        );
        return Uint8List.fromList(utf8.encode(markdown));
      },
    );
  }

  /// 导出 PDF（统一中文字体，见 [DiaryPdfExporter]）。
  Future<void> exportPdf(
    BuildContext context, {
    required DiaryWithTags detail,
    required quill.Document document,
  }) {
    final textDirection = Directionality.of(context);
    return _exportFile(
      context,
      label: context.l10n.previewExportPdf,
      extension: 'pdf',
      detail: detail,
      build: () => _pdf.build(document, textDirection: textDirection),
    );
  }

  /// 导出为可重新导入的日记文件；密码可选，流程见 [DiaryFileExportController]。
  Future<void> exportDiaryFile(
    BuildContext context, {
    required DiaryWithTags detail,
    required AppDatabase database,
  }) async {
    if (_exportingFile || _showLoading) {
      return;
    }
    final password = await showBackupPasswordDialog(
      context,
      purpose: BackupPasswordPurpose.export,
      confirmLabel: context.l10n.previewExportDiaryFileConfirm,
    );
    if (!context.mounted || password == null) {
      return;
    }
    await _runWithLoading(
      context,
      label: context.l10n.previewExportDiaryFile,
      action: () async {
        _update(() => _exportingFile = true);
        try {
          final saved = await DiaryFileExportController.export(
            database: database,
            diaryId: detail.diary.diaryId,
            fileName:
                'jotsy_${exportFileBaseName(detail)}_${DateTime.now().millisecondsSinceEpoch}.zip',
            dialogTitle: context.l10n.previewExportSaveDialogTitle,
            password: password,
          );
          if (!context.mounted) {
            return;
          }
          onHint(
            saved
                ? context.l10n.previewExportDiaryFileSuccess
                : context.l10n.previewExportCanceled,
          );
        } catch (error) {
          if (!context.mounted) {
            return;
          }
          onHint(context.l10n.previewExportFailed(error.toString()));
        } finally {
          if (context.mounted) {
            _update(() => _exportingFile = false);
          }
        }
      },
    );
  }

  /// 导出文件名主体：标题去掉文件系统非法字符、空白换成下划线，截到 24 字；
  /// 没有标题时用 `diary`。
  static String exportFileBaseName(DiaryWithTags detail) {
    final rawTitle = detail.diary.title.trim().isEmpty
        ? 'diary'
        : detail.diary.title.trim();
    final normalized = rawTitle
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    final short = normalized.length > 24
        ? normalized.substring(0, 24)
        : normalized;
    return short.isEmpty ? 'diary' : short;
  }

  /// Markdown 与 PDF 共用的导出流程：生成字节 → 用户选择保存位置 → 提示
  /// 结果（保存、取消或失败）。
  Future<void> _exportFile(
    BuildContext context, {
    required String label,
    required String extension,
    required DiaryWithTags detail,
    required Future<Uint8List> Function() build,
  }) async {
    if (_exportingFile || _showLoading) {
      return;
    }
    await _runWithLoading(
      context,
      label: label,
      action: () async {
        _update(() => _exportingFile = true);
        try {
          final bytes = await build();
          if (!context.mounted) {
            return;
          }
          final saved = await saveDiaryExportBytes(
            dialogTitle: context.l10n.previewExportSaveDialogTitle,
            bytes: bytes,
            fileName:
                '${exportFileBaseName(detail)}_${DateTime.now().millisecondsSinceEpoch}.$extension',
            allowedExtensions: <String>[extension],
          );
          if (!context.mounted) {
            return;
          }
          onHint(
            saved
                ? context.l10n.previewExportSuccess
                : context.l10n.previewExportCanceled,
          );
        } catch (error) {
          if (!context.mounted) {
            return;
          }
          onHint(context.l10n.previewExportFailed(error.toString()));
        } finally {
          if (context.mounted) {
            _update(() => _exportingFile = false);
          }
        }
      },
    );
  }

  /// 统一动作加载态：共享的遮罩 loading，限制最短可见时长，并在真正的重
  /// 任务前预留一帧，让动画先渲染出来。
  Future<void> _runWithLoading(
    BuildContext context, {
    required String label,
    required Future<void> Function() action,
  }) async {
    if (_showLoading) {
      return;
    }
    final startedAt = DateTime.now();
    if (context.mounted) {
      _update(() {
        _showLoading = true;
        _loadingLabel = label;
      });
    }

    // 先渲染 loading，再执行 IO/截图等重任务，避免动画“卡住不动”。
    // 等到包含遮罩的那一帧真正提交，而不是猜一个固定毫秒数。
    await WidgetsBinding.instance.endOfFrame;

    try {
      await action();
    } finally {
      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed < _minLoadingVisible) {
        await Future<void>.delayed(_minLoadingVisible - elapsed);
      }
      if (context.mounted) {
        _update(() {
          _showLoading = false;
          _loadingLabel = '';
        });
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
