import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/app_platform.dart';
import '../../../core/services/desktop_save_service.dart';
import '../../../core/services/diary_share_channel.dart';
import '../../../core/services/image_export_service.dart';
import '../models/diary_share_target.dart';

typedef DiaryShareClipboardWriter = Future<void> Function(String text);
typedef DiarySystemShare =
    Future<void> Function({required List<String> imagePaths, String? text});

enum DiaryShareOutcome {
  /// 已交给目标应用或系统分享面板。
  shared,

  /// 只复制了文字。
  copied,

  /// 目标应用没有能接收这些内容的入口（已卸载或版本过旧）。
  appUnavailable,

  /// 没有文字，勾选的图片也一张都读不到；或目标必须带图而图片读不到。
  nothingToShare,
}

/// 一次分享的结果，预览页据此给出提示。
@immutable
class DiaryShareResult {
  const DiaryShareResult(
    this.outcome, {
    this.textCopied = false,
    this.trimmedImages = 0,
    this.missingImages = 0,
  });

  final DiaryShareOutcome outcome;

  /// 带图分享时正文已复制到剪贴板，需提示用户去粘贴。
  final bool textCopied;

  /// 超出目标单次上限、没有发出去的图片张数。
  final int trimmedImages;

  /// 原图已删除、下载失败等读不到的图片张数。
  final int missingImages;
}

/// 没有系统分享的平台（Linux）上“保存图片…”的结果。
@immutable
class DiarySaveImagesResult {
  const DiarySaveImagesResult({
    required this.path,
    required this.saved,
    required this.missing,
  });

  /// 保存的文件（一张时）或文件夹（多张时）；用户取消对话框时为 null。
  final String? path;

  /// 写出的张数。
  final int saved;

  /// 原图已删除、下载失败等读不到的张数。
  final int missing;
}

/// 分享日记的执行链路。
///
/// 流程（[share]）：
/// 1. 按目标上限截取勾选的图片（微信等 9 张，朋友圈 1 张，微博不限）；
/// 2. 把图片复制到应用缓存 `diary_share/<时间戳>/`：原生侧只经 FileProvider
///    暴露这个目录，日记原图所在的私有目录不对外开放；网络图片先下载，
///    data URI 先解码；读不到的图片跳过并计数，不中断整次分享；
/// 3. 带图且有文字时先把文字复制到剪贴板——这些应用会丢掉随图片传入的
///    文字，用户到发布页粘贴即可；只有文字时直接把文字发给目标；
/// 4. 指定应用经 [DiaryShareChannel] 发出，系统分享经 share_plus。
///
/// 暂存目录每次分享前整体清空、只保留本次：目标应用在被拉起时读取图片，
/// 上一次分享早已完成，缓存不会随分享次数累积。
///
/// 没有系统分享的平台（Linux，[AppPlatform.supportsSystemFileShare] 为
/// false）面板只提供复制文字与 [saveImages]；系统分享在这些平台直接抛
/// [UnsupportedError]，不会走到 share_plus 未实现的 `shareXFiles`。
class DiaryShareController {
  DiaryShareController({
    this._channel = const DiaryShareChannel(),
    this._imageService = const ImageExportService(),
    this._cacheDirectory = getTemporaryDirectory,
    this._desktopSaver = const DesktopSaveService(),
    DiaryShareClipboardWriter? writeClipboard,
    DiarySystemShare? systemShare,
  }) : _writeClipboard = writeClipboard ?? _copyToClipboard,
       _systemShare = systemShare ?? _shareWithSystemSheet;

  /// 须与原生 `res/xml/diary_share_paths.xml` 的 cache-path 一致。
  static const String stagingDirectoryName = 'diary_share';

  final DiaryShareChannel _channel;
  final ImageExportService _imageService;
  final Future<Directory> Function() _cacheDirectory;
  final DesktopSaveService _desktopSaver;
  final DiaryShareClipboardWriter _writeClipboard;
  final DiarySystemShare _systemShare;

  /// 已安装、能接收分享的应用目标（不含始终可用的系统分享）。
  Future<Set<DiaryShareTarget>> availableTargets() async {
    final targets = DiaryShareTarget.appTargets;
    final available = await _channel.availableComponents(
      targets.map((DiaryShareTarget target) => target.component!),
    );
    return targets
        .where(
          (DiaryShareTarget target) => available.contains(target.component),
        )
        .toSet();
  }

  Future<DiaryShareResult> copyText(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return const DiaryShareResult(DiaryShareOutcome.nothingToShare);
    }
    await _writeClipboard(normalized);
    return const DiaryShareResult(DiaryShareOutcome.copied, textCopied: true);
  }

  /// 把勾选的 [images] 保存到用户选的位置（代替系统分享）：一张时弹出
  /// “另存为…”对话框（[fileDialogTitle]），多张时选一个文件夹
  /// （[folderDialogTitle]）按面板顺序编号写入，不覆盖文件夹里的同名文件。
  ///
  /// 图片先经与分享相同的暂存（网络图片下载、data URI 解码），读不到的跳过
  /// 并计入 [DiarySaveImagesResult.missing]；一张都读不到时不弹对话框。
  Future<DiarySaveImagesResult> saveImages(
    List<String> images, {
    required String fileDialogTitle,
    required String folderDialogTitle,
  }) async {
    final staged = await _stageImages(images);
    final missing = images.length - staged.length;
    if (staged.isEmpty) {
      return DiarySaveImagesResult(path: null, saved: 0, missing: missing);
    }
    final files = staged.map(File.new).toList(growable: false);
    final names = staged.map(p.basename).toList(growable: false);
    final path = files.length == 1
        ? await _desktopSaver.saveFile(
            files.single,
            fileName: names.single,
            dialogTitle: fileDialogTitle,
          )
        : await _desktopSaver.saveFilesToDirectory(
            files,
            fileNames: names,
            dialogTitle: folderDialogTitle,
          );
    return DiarySaveImagesResult(
      path: path,
      saved: path == null ? 0 : files.length,
      missing: missing,
    );
  }

  /// 把 [text] 与 [images] 分享到 [target]，[chooserTitle] 用于目标应用
  /// 有多个分享入口时系统列出的选择面板标题。
  Future<DiaryShareResult> share(
    DiaryShareTarget target, {
    required String text,
    required List<String> images,
    String? chooserTitle,
  }) async {
    final cap = target.maxImages;
    final chosen = cap == null || images.length <= cap
        ? images
        : images.sublist(0, cap);
    final trimmed = images.length - chosen.length;
    final staged = await _stageImages(chosen);
    final missing = chosen.length - staged.length;
    final normalizedText = text.trim();

    if ((staged.isEmpty && normalizedText.isEmpty) ||
        (target.requiresImages && staged.isEmpty)) {
      return DiaryShareResult(
        DiaryShareOutcome.nothingToShare,
        missingImages: missing,
      );
    }

    final copyText = staged.isNotEmpty && normalizedText.isNotEmpty;
    if (copyText) {
      await _writeClipboard(normalizedText);
    }

    final component = target.component;
    if (component == null) {
      // 系统分享另把文字一并传入：邮件、便签等应用会读取它。
      await _systemShare(
        imagePaths: staged,
        text: normalizedText.isEmpty ? null : normalizedText,
      );
    } else {
      final launched = await _channel.shareTo(
        component,
        text: staged.isEmpty ? normalizedText : null,
        imagePaths: staged,
        chooserTitle: chooserTitle,
      );
      if (!launched) {
        return DiaryShareResult(
          DiaryShareOutcome.appUnavailable,
          textCopied: copyText,
        );
      }
    }
    return DiaryShareResult(
      DiaryShareOutcome.shared,
      textCopied: copyText,
      trimmedImages: trimmed,
      missingImages: missing,
    );
  }

  Future<List<String>> _stageImages(List<String> sources) async {
    if (sources.isEmpty) {
      return const <String>[];
    }
    final root = Directory(
      p.join((await _cacheDirectory()).path, stagingDirectoryName),
    );
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
    final directory = Directory(
      p.join(root.path, '${DateTime.now().microsecondsSinceEpoch}'),
    );
    await directory.create(recursive: true);
    final staged = <String>[];
    for (var i = 0; i < sources.length; i++) {
      try {
        final file = await _stageImage(sources[i], directory, i + 1);
        if (file != null) {
          staged.add(file.path);
        }
      } on Exception {
        // 单张读取失败只计入 missing，其余图片照常分享。
      }
    }
    return staged;
  }

  /// 暂存文件按序号命名：部分应用按文件名排序展示多图，序号保证顺序与
  /// 面板中一致，也不会把日记原文件名带出去。
  Future<File?> _stageImage(String source, Directory directory, int index) {
    String name(String extension) => p.join(
      directory.path,
      'jotsy_${index.toString().padLeft(2, '0')}$extension',
    );

    final dataUri = _DataImage.tryParse(source);
    if (dataUri != null) {
      return File(
        name(dataUri.extension),
      ).writeAsBytes(dataUri.bytes, flush: true);
    }
    if (ImageExportService.isRemoteSource(source)) {
      return _imageService
          .downloadRemoteImage(source)
          .then((File file) => file.copy(name(_extensionOf(file.path))));
    }
    final file = source.startsWith('file:')
        ? File.fromUri(Uri.parse(source))
        : File(source);
    return file.exists().then(
      (bool exists) => exists ? file.copy(name(_extensionOf(file.path))) : null,
    );
  }

  static String _extensionOf(String path) {
    final extension = p.extension(path).toLowerCase();
    return extension.isEmpty ? '.jpg' : extension;
  }

  static Future<void> _copyToClipboard(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  static Future<void> _shareWithSystemSheet({
    required List<String> imagePaths,
    String? text,
  }) async {
    // share_plus 在 Linux 上没有实现文件分享；界面不提供系统分享，这里兜底，
    // 调用方按分享失败提示。
    if (!AppPlatform.supportsSystemFileShare) {
      throw UnsupportedError('System share is unavailable on this platform');
    }
    if (imagePaths.isEmpty) {
      await Share.share(text ?? '');
      return;
    }
    await Share.shareXFiles(
      imagePaths.map(XFile.new).toList(growable: false),
      text: text,
    );
  }
}

/// `data:image/png;base64,...` 形式的内嵌图片。
class _DataImage {
  const _DataImage(this.bytes, this.extension);

  final List<int> bytes;
  final String extension;

  static _DataImage? tryParse(String source) {
    if (!source.startsWith('data:')) {
      return null;
    }
    const marker = ';base64,';
    final separator = source.indexOf(marker);
    if (separator < 0) {
      return null;
    }
    final mimeType = source.substring(5, separator).toLowerCase();
    final extension = switch (mimeType) {
      'image/png' => '.png',
      'image/gif' => '.gif',
      'image/webp' => '.webp',
      'image/bmp' => '.bmp',
      _ => '.jpg',
    };
    try {
      return _DataImage(
        base64Decode(source.substring(separator + marker.length)),
        extension,
      );
    } on FormatException {
      return null;
    }
  }
}
