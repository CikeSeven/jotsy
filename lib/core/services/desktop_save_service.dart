import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

/// 弹出“另存为”对话框，返回用户选的完整路径；取消返回 null。
typedef DesktopSavePathPicker =
    Future<String?> Function({
      required String dialogTitle,
      required String fileName,
      required String extension,
    });

/// 弹出“选择文件夹”对话框，返回文件夹路径；取消返回 null。
typedef DesktopDirectoryPicker =
    Future<String?> Function({required String dialogTitle});

/// 桌面端的“另存为…”：代替手机上的“保存到相册”与系统分享。
///
/// - 输入：要保存的源文件或内存字节、建议文件名与对话框标题；
/// - 输出：实际写入的路径；用户取消对话框时为 null（调用方不提示）；
/// - 副作用：只写用户在对话框里选的位置，源文件只读、不移动。
///
/// 对话框经 file_picker（Linux 为 xdg-desktop-portal，Windows 为系统对话框）
/// 只取得路径，文件由这里自己复制：大文件（视频、导出包）走文件复制而不是
/// 读进内存再交给插件写出。失败直接抛出底层异常，由调用方映射成提示。
class DesktopSaveService {
  const DesktopSaveService({
    DesktopSavePathPicker? pickPath,
    DesktopDirectoryPicker? pickDirectory,
  }) : _pickPath = pickPath ?? _pickPathWithFilePicker,
       _pickDirectory = pickDirectory ?? _pickDirectoryWithFilePicker;

  final DesktopSavePathPicker _pickPath;
  final DesktopDirectoryPicker _pickDirectory;

  /// 把 [source] 另存为用户选的文件；[fileName] 为对话框里的默认文件名，
  /// [extension] 缺省时取 [fileName] 的扩展名，作为对话框的类型过滤。
  Future<String?> saveFile(
    File source, {
    required String fileName,
    required String dialogTitle,
    String? extension,
  }) async {
    final target = await _choose(fileName, dialogTitle, extension);
    if (target == null) return null;
    await File(target).parent.create(recursive: true);
    // 用户可能直接选了源文件本身（如在应用数据目录里“另存为”同名），
    // 复制到自己会把文件截成空，这种情况已经“保存”好了。
    if (!p.equals(p.normalize(source.absolute.path), p.normalize(target))) {
      await source.copy(target);
    }
    return target;
  }

  /// 把内存中的 [bytes] 另存为用户选的文件，其余同 [saveFile]。
  Future<String?> saveBytes(
    Uint8List bytes, {
    required String fileName,
    required String dialogTitle,
    String? extension,
  }) async {
    final target = await _choose(fileName, dialogTitle, extension);
    if (target == null) return null;
    final file = File(target);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return target;
  }

  /// 让用户选一个文件夹，把 [sources] 按 [fileNames] 依次复制进去，返回
  /// 文件夹路径；取消返回 null。文件夹里已有同名文件时加序号，不覆盖用户
  /// 原有的文件。
  Future<String?> saveFilesToDirectory(
    List<File> sources, {
    required List<String> fileNames,
    required String dialogTitle,
  }) async {
    assert(sources.length == fileNames.length);
    final directory = await _pickDirectory(dialogTitle: dialogTitle);
    if (directory == null || directory.trim().isEmpty) return null;
    await Directory(directory).create(recursive: true);
    for (var i = 0; i < sources.length; i++) {
      await sources[i].copy(await _uniquePath(directory, fileNames[i]));
    }
    return directory;
  }

  Future<String?> _choose(
    String fileName,
    String dialogTitle,
    String? extension,
  ) async {
    final path = await _pickPath(
      dialogTitle: dialogTitle,
      fileName: fileName,
      extension: (extension ?? p.extension(fileName)).replaceFirst('.', ''),
    );
    if (path == null || path.trim().isEmpty) return null;
    return path;
  }

  static Future<String> _uniquePath(String directory, String fileName) async {
    final stem = p.basenameWithoutExtension(fileName);
    final extension = p.extension(fileName);
    var candidate = p.join(directory, fileName);
    for (var n = 2; await File(candidate).exists(); n++) {
      candidate = p.join(directory, '$stem ($n)$extension');
    }
    return candidate;
  }

  static Future<String?> _pickPathWithFilePicker({
    required String dialogTitle,
    required String fileName,
    required String extension,
  }) {
    return FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      // 没有扩展名时不加过滤：空过滤在 Windows 对话框里会让什么都选不了。
      type: extension.isEmpty ? FileType.any : FileType.custom,
      allowedExtensions: extension.isEmpty ? null : <String>[extension],
    );
  }

  static Future<String?> _pickDirectoryWithFilePicker({
    required String dialogTitle,
  }) {
    return FilePicker.platform.getDirectoryPath(dialogTitle: dialogTitle);
  }
}
