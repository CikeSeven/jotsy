import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

typedef NativeFileOpener = Future<OpenResult> Function(String path);

enum FileOpenFailure { missingFile, noApp, permissionDenied, failed }

/// 把本地附件交给系统文件处理器；Android 使用插件的 FileProvider 临时读权限，
/// iOS 使用系统文档交互面板。输出语义错误，UI 不暴露原生异常或内部文件路径。
class FileOpenService {
  const FileOpenService({this.opener});

  final NativeFileOpener? opener;

  Future<FileOpenFailure?> open(String source) async {
    try {
      final normalized = source.trim();
      if (normalized.isEmpty) return FileOpenFailure.missingFile;
      final uri = Uri.tryParse(normalized);
      // 旧版导入可能保留远程文件引用，交由系统浏览器/已注册应用处理。
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication)
            ? null
            : FileOpenFailure.noApp;
      }
      final file = uri?.scheme == 'file'
          ? File.fromUri(uri!)
          : File(normalized);
      if (!await file.exists()) return FileOpenFailure.missingFile;
      final result = await (opener ?? _openNativeFile)(file.path);
      return switch (result.type) {
        ResultType.done => null,
        ResultType.fileNotFound => FileOpenFailure.missingFile,
        ResultType.noAppToOpen => FileOpenFailure.noApp,
        ResultType.permissionDenied => FileOpenFailure.permissionDenied,
        ResultType.error => FileOpenFailure.failed,
      };
    } catch (_) {
      return FileOpenFailure.failed;
    }
  }

  static Future<OpenResult> _openNativeFile(String path) =>
      OpenFilex.open(path);
}
