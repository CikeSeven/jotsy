import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../core/database/mind_map/mind_map_document.dart';
import '../../../core/database/mind_map/mind_map_ops.dart';
import '../../../core/database/mind_map/mind_map_text.dart';
import '../../../core/services/backup_file_save_service.dart';
import '../../../core/services/image_export_service.dart';
import '../../../core/services/mind_map_io/mind_map_file_formats.dart';
import '../../../core/services/mind_map_io/mind_map_markdown_io.dart';
import '../../../core/services/mind_map_io/mind_map_xml_formats.dart';
import '../../../core/services/mind_map_io/mind_map_xmind_io.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../widgets/action_loading_overlay.dart';
import '../../widgets/app_modal/app_dialog.dart';
import '../../widgets/image_export_messages.dart';
import '../layout/mind_map_layout.dart';
import '../layout/mind_map_text_cache.dart';
import '../viewmodels/mind_map_frame.dart';
import '../viewmodels/mind_map_labels.dart';
import '../viewmodels/mind_map_look.dart';
import '../widgets/mind_map_painter.dart';
import 'mind_map_editing_controller.dart';

/// 导图的导出与导入流程。
///
/// 导出：图片（PNG，按当前明暗与配色、带页面底色，最长边不超过
/// [_maxImageSide] 像素）、PDF（一页，页面按导图大小）、XMind、Markdown、
/// OPML、FreeMind，或复制为大纲文字。文件先写到缓存目录
/// `mind_map_export/`（每次导出前清掉上次的暂存），再交给系统分享、保存
/// 对话框（`BackupFileSaveService.saveFile`）或相册（手机，只对图片）。
/// 导入：选一个 XMind / OPML / FreeMind / Markdown / 纯文本文件，按扩展名
/// 解析；当前导图已经写了东西时先确认替换（替换是一步撤销）。结果都用提示
/// 条告知。

/// 导出的去处。
enum MindMapDelivery { share, save, gallery }

/// 导出的种类（文件格式之外还有图片与 PDF）。
enum MindMapExportKind {
  image('png', 'image/png'),
  pdf('pdf', 'application/pdf'),
  xmind('xmind', 'application/vnd.xmind.workbook'),
  markdown('md', 'text/markdown'),
  opml('opml', 'text/x-opml'),
  freeMind('mm', 'application/x-freemind');

  const MindMapExportKind(this.extension, this.mimeType);

  final String extension;
  final String mimeType;
}

const double _maxImageSide = 8192;
const String _stagingDirectory = 'mind_map_export';

/// 把导图画成 PNG（[pixelRatio] 倍，最长边受限）。画在当前主题下，底色为
/// 页面底色。
Future<Uint8List> renderMindMapPng(
  BuildContext context,
  MindMapDocument document, {
  double pixelRatio = 2,
}) async {
  final look = MindMapLook.of(context, document);
  final background = Theme.of(context).colorScheme.surface;
  final texts = MindMapTextCache();
  try {
    final scene = layoutMindMap(document, look.config(texts));
    final bounds = scene.bounds.inflate(40);
    var scale = pixelRatio;
    final longest = math.max(bounds.width, bounds.height) * scale;
    if (longest > _maxImageSide) scale *= _maxImageSide / longest;
    final width = math.max(1, (bounds.width * scale).ceil());
    final height = math.max(1, (bounds.height * scale).ceil());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawRect(
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        Paint()..color = background,
      )
      ..scale(scale)
      ..translate(-bounds.left, -bounds.top);
    paintMindMap(
      canvas,
      MindMapFrame.still(scene),
      MindMapPaintOptions(palette: look.palette),
      zoom: scale,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  } finally {
    texts.dispose();
  }
}

/// 一页 PDF：页面按图片大小（逻辑像素 × 0.75 换成点），图片铺满。
Future<Uint8List> renderMindMapPdf(
  BuildContext context,
  MindMapDocument document,
) async {
  final png = await renderMindMapPng(context, document, pixelRatio: 2);
  final image = pw.MemoryImage(png);
  final width = (image.width ?? 1) / 2 * 0.75;
  final height = (image.height ?? 1) / 2 * 0.75;
  final pdf = pw.Document()
    ..addPage(
      pw.Page(
        pageFormat: PdfPageFormat(width, height),
        build: (_) => pw.Image(image, fit: pw.BoxFit.contain),
      ),
    );
  return pdf.save();
}

/// 生成 [kind] 的文件字节。
Future<Uint8List> buildMindMapExport(
  BuildContext context,
  MindMapDocument document,
  MindMapExportKind kind,
) async {
  final untitled = context.l10n.mindMapUntitled;
  return switch (kind) {
    MindMapExportKind.image => renderMindMapPng(context, document),
    MindMapExportKind.pdf => renderMindMapPdf(context, document),
    MindMapExportKind.xmind => mindMapToXmind(document, untitled: untitled),
    MindMapExportKind.markdown => _utf8(
      mindMapToMarkdown(document, untitled: untitled),
    ),
    MindMapExportKind.opml => _utf8(
      mindMapToOpml(document, untitled: untitled),
    ),
    MindMapExportKind.freeMind => _utf8(
      mindMapToFreeMind(document, untitled: untitled),
    ),
  };
}

Uint8List _utf8(String text) => Uint8List.fromList(utf8.encode(text));

/// 文件名：中心主题（去掉不能做文件名的字符，最长 60）+ 扩展名。
String mindMapExportFileName(
  AppLocalizations l10n,
  MindMapDocument document,
  MindMapExportKind kind,
) {
  var base = mindMapTitle(
    l10n,
    document.root.text,
  ).replaceAll(RegExp(r'[\\/:*?"<>|\n\r\t]'), ' ').trim();
  if (base.length > 60) base = base.substring(0, 60).trim();
  return '$base.${kind.extension}';
}

/// 导出并交给 [delivery]。
Future<void> exportMindMap(
  BuildContext context,
  MindMapDocument document,
  MindMapExportKind kind,
  MindMapDelivery delivery,
) async {
  final l10n = context.l10n;
  final fileName = mindMapExportFileName(l10n, document, kind);
  File? staged;
  try {
    // 大导图画 PNG / PDF 要一会儿：期间盖统一的等待遮罩（也挡住重复点按）。
    final bytes = await runWithActionLoadingOverlay(
      context,
      label: l10n.diaryExportInProgress,
      task: () => context.mounted
          ? buildMindMapExport(context, document, kind)
          : Future<Uint8List>.error(StateError('page closed')),
    );
    if (!context.mounted) return;
    switch (delivery) {
      case MindMapDelivery.gallery:
        await ImageExportService().saveBytesToGallery(
          bytes,
          name: p.basenameWithoutExtension(fileName),
        );
        if (context.mounted) _hint(context, l10n.mindMapExportSavedGallery);
      case MindMapDelivery.share:
        staged = await _stage(bytes, fileName);
        await Share.shareXFiles(<XFile>[
          XFile(staged.path, mimeType: kind.mimeType),
        ]);
        staged = null;
      case MindMapDelivery.save:
        staged = await _stage(bytes, fileName);
        final saved = await BackupFileSaveService.saveFile(
          file: staged,
          fileName: fileName,
          dialogTitle: l10n.mindMapExport,
          mimeType: kind.mimeType,
          extension: kind.extension,
        );
        if (context.mounted && saved != null && saved.trim().isNotEmpty) {
          _hint(context, l10n.mindMapExportSaved);
        }
    }
  } catch (error) {
    debugPrint('Mind map export failed: $error');
    if (context.mounted) {
      _hint(
        context,
        error is ImageExportException
            ? imageExportErrorMessage(l10n, error)
            : l10n.mindMapExportFailed,
      );
    }
  } finally {
    // 分享的暂存留到下次导出再清（分享面板读文件是异步的）。
    final parent = staged?.parent;
    if (parent != null) {
      try {
        await parent.delete(recursive: true);
      } on FileSystemException {
        // 系统会回收缓存目录。
      }
    }
  }
}

/// 复制为大纲文字。
Future<void> copyMindMapOutline(
  BuildContext context,
  MindMapDocument document,
) async {
  final l10n = context.l10n;
  await Clipboard.setData(
    ClipboardData(
      text: mindMapOutlineText(document, untitled: l10n.mindMapUntitled),
    ),
  );
  if (context.mounted) _hint(context, l10n.mindMapCopied);
}

Future<File> _stage(Uint8List bytes, String fileName) async {
  final root = Directory(
    p.join((await getTemporaryDirectory()).path, _stagingDirectory),
  );
  if (await root.exists()) {
    try {
      await root.delete(recursive: true);
    } on FileSystemException {
      // 清不掉上次的暂存不影响这次导出。
    }
  }
  final file = File(
    p.join(root.path, '${DateTime.now().microsecondsSinceEpoch}', fileName),
  );
  await file.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

void _hint(BuildContext context, String message) {
  HomeHintVisibilityScope.showTrackedSnackBar(
    context: context,
    snackBar: SnackBar(content: Text(message)),
  );
}

/// 选一个文件导入到 [controller] 的导图里（替换整棵树，一步撤销）。
/// 返回是否导入了。
Future<bool> importMindMapFromFile(
  BuildContext context,
  MindMapEditingController controller,
) async {
  final l10n = context.l10n;
  // 用“任意文件”再按扩展名检查：Android 上认不出 .xmind / .opml / .mm 的
  // 类型，按扩展名过滤会让这些文件选不了。
  final result = await FilePicker.platform.pickFiles(
    type: FileType.any,
    withData: true,
  );
  final file = result?.files.firstOrNull;
  if (file == null || !context.mounted) return false;
  final dot = file.name.lastIndexOf('.');
  final extension = dot < 0 ? '' : file.name.substring(dot + 1).toLowerCase();
  final bytes = file.bytes;
  final imported =
      bytes == null || !MindMapFileFormat.importExtensions.contains(extension)
      ? null
      : importMindMapFile(file.name, bytes);
  if (imported == null) {
    _hint(context, l10n.mindMapImportFailed);
    return false;
  }
  if (!mindMapHasOnlyRoot(controller.document)) {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.mindMapImportReplaceTitle),
        content: Text(l10n.mindMapImportReplaceBody),
        actions: <Widget>[
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(
                dialogContext,
              ).colorScheme.onSurfaceVariant,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.mindMapImportReplaceConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return false;
  }
  var next = MindMapOps.replaceRoot(controller.document, imported.root);
  if (imported.structure case final structure?) {
    next = next.copyWith(structure: structure);
  }
  controller.stopEditing();
  controller.commit(next, select: null);
  _hint(context, l10n.mindMapImported);
  return true;
}
