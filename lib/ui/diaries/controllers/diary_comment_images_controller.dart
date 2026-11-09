/// 写留言面板（以及 AI 对话输入栏）里的图片：从相册 / 文件选图 → 复制进
/// 托管目录 → 面板里增删，保存（发送）时交给写库流程。
///
/// 职责边界：不构建 UI、不写数据库。输入为编辑时原有的图片（[initial]）与
/// 用户的挑选；输出为当前的图片列表、复制中的张数与每次挑选的结果，经
/// [ChangeNotifier] 通知面板重建。
///
/// 文件的归属（为什么要分“原有”与“新导入”）：
/// - 编辑时原有的图片已被这条留言引用，面板里移除它只是改列表，文件由媒体
///   回收在确定没人引用、过了宽限期后删除（与正文删图同一做法）；
/// - 本次新复制进来的图片在保存之前没有任何引用：在面板里移除它、或面板
///   取消关闭（[dispose] 时还没 [handOff]），立即删掉文件，不留孤儿等回收；
/// - 保存时 [handOff] 把它们交给写库流程，之后 [dispose] 不再删除；写库失败
///   由流程经 [discardImages] 删掉；
/// - 面板关闭时还在复制的图片：复制完成后发现已释放，直接删掉。
library;

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/database/diary_comment_images.dart';
import '../../../core/database/file_embed_codec.dart';
import '../../../core/services/diary_media_storage_service.dart';

/// 选图来源：返回用户选中的文件，取消为 null 或空列表。
typedef DiaryCommentImagePicker = Future<List<PlatformFile>?> Function();

/// 把一份选中的文件复制进托管图片目录（HEIC 系图片在能转码的平台转成
/// JPEG），返回托管后的路径。
typedef DiaryCommentImageImporter = Future<String> Function(PlatformFile file);

/// 删除一份从未交给数据库的托管文件。
typedef DiaryCommentImageDiscarder = Future<void> Function(String path);

/// 一次挑选的结果，面板据此给出一行提示。
enum DiaryCommentImagePickResult {
  /// 选中的都加上了。
  added,

  /// 加上了一部分：超过 [kDiaryCommentMaxImages]，多选的没有加。
  truncated,

  /// 用户取消了，或面板已关闭。
  cancelled,

  /// 已经满了或正在复制上一批，没有打开选择器。
  busy,

  /// 没有读取图片的权限。
  permissionDenied,

  /// 拍照时没有相机权限。
  cameraPermissionDenied,

  /// 拍照时没有可用的相机或相机应用。
  cameraUnavailable,

  /// 选择器不可用或复制失败（已加上的保留）。
  failed,
}

class DiaryCommentImagesController extends ChangeNotifier {
  DiaryCommentImagesController({
    List<String> initial = const <String>[],
    DiaryCommentImagePicker? picker,
    DiaryCommentImageImporter? importer,
    DiaryCommentImageDiscarder? discarder,
    this.maxImages = kDiaryCommentMaxImages,
  }) : _images = normalizeDiaryCommentImages(initial).toList(),
       _picker = picker ?? _pickImages,
       _importer = importer ?? _importImage,
       _discarder =
           discarder ?? DiaryMediaStorageService.deleteManagedDiaryFile;

  /// 最多几张（留言 [kDiaryCommentMaxImages]，AI 对话的一条消息另定）。
  final int maxImages;

  final List<String> _images;
  final DiaryCommentImagePicker _picker;
  final DiaryCommentImageImporter _importer;
  final DiaryCommentImageDiscarder _discarder;

  /// 本次新复制进来、仍归面板所有的文件（见库注释）。
  final Set<String> _fresh = <String>{};

  bool _picking = false;
  int _pending = 0;
  bool _handedOff = false;
  bool _disposed = false;

  /// 当前的图片，按添加顺序。
  List<String> get images => List<String>.unmodifiable(_images);

  /// 正在复制的张数（面板里画成占位格）。
  int get pending => _pending;

  /// 正在打开选择器或复制：此时不能再选，也不能保存。
  bool get isBusy => _picking;

  /// 还能再加几张。
  int get remaining =>
      (maxImages - _images.length - _pending).clamp(0, maxImages);

  bool get canAdd => !_picking && remaining > 0;

  /// 打开选择器选图并逐张复制进来。复制是一张一张进行的：每复制完一张就
  /// 出现在面板里，大图或 HEIC 转码慢时用户能看到进度。
  ///
  /// [source] 给出时用它代替构造时的选图来源（例如 AI 对话里的“拍照”）。
  Future<DiaryCommentImagePickResult> pick({
    DiaryCommentImagePicker? source,
  }) async {
    if (_disposed || !canAdd) return DiaryCommentImagePickResult.busy;
    _picking = true;
    _notify();
    List<PlatformFile>? files;
    var result = DiaryCommentImagePickResult.added;
    try {
      files = await (source ?? _picker)();
      if (_disposed || files == null || files.isEmpty) {
        return DiaryCommentImagePickResult.cancelled;
      }
      final room = remaining;
      final taken = files.take(room).toList(growable: false);
      if (files.length > room) result = DiaryCommentImagePickResult.truncated;
      _pending = taken.length;
      _notify();
      for (final file in taken) {
        final String path;
        try {
          path = await _importer(file);
        } catch (error, stackTrace) {
          debugPrint('Comment image import failed: $error\n$stackTrace');
          // 已复制好的保留，其余放弃：多半是同一个原因（权限、空间）。
          return _failureOf(error);
        }
        if (_disposed) {
          // 面板已经关了：这份文件没有人会引用。
          unawaited(_discardQuietly(path));
          continue;
        }
        _pending--;
        if (_images.contains(path)) continue;
        _images.add(path);
        _fresh.add(path);
        _notify();
      }
      return _disposed ? DiaryCommentImagePickResult.cancelled : result;
    } catch (error, stackTrace) {
      debugPrint('Comment image picker failed: $error\n$stackTrace');
      return _failureOf(error);
    } finally {
      // 选择器在缓存里的中转副本无论成败都已无用。
      for (final file in files ?? const <PlatformFile>[]) {
        unawaited(DiaryMediaStorageService.discardPickerCopy(file.path));
      }
      _picking = false;
      _pending = 0;
      _notify();
    }
  }

  /// 从面板里移除一张；本次新复制的同时删掉文件，原有的只改列表。
  void remove(String path) {
    if (!_images.remove(path)) return;
    if (_fresh.remove(path)) unawaited(_discardQuietly(path));
    _notify();
  }

  /// 保存：把本次新复制、仍在列表里的图片交给调用方，之后 [dispose] 不再
  /// 删除它们。返回这些路径（写库失败时由调用方经 [discardImages] 删除）。
  List<String> handOff() {
    _handedOff = true;
    return List<String>.unmodifiable(
      _images.where(_fresh.contains).toList(growable: false),
    );
  }

  /// 删除从未写进数据库的托管图片（写库失败时由流程调用）。
  static Future<void> discardImages(
    Iterable<String> paths, {
    DiaryCommentImageDiscarder? discarder,
  }) async {
    final discard =
        discarder ?? DiaryMediaStorageService.deleteManagedDiaryFile;
    for (final path in paths) {
      try {
        await discard(path);
      } catch (error) {
        debugPrint('Comment image cleanup failed: $error');
      }
    }
  }

  DiaryCommentImagePickResult _failureOf(Object error) {
    if (error is PlatformException) {
      switch (error.code) {
        case 'permission_denied':
          return DiaryCommentImagePickResult.permissionDenied;
        case 'camera_permission_denied':
          return DiaryCommentImagePickResult.cameraPermissionDenied;
        case 'camera_unavailable':
          return DiaryCommentImagePickResult.cameraUnavailable;
      }
    }
    if (error is FileSystemException &&
        const <int>{1, 13}.contains(error.osError?.errorCode)) {
      return DiaryCommentImagePickResult.permissionDenied;
    }
    return DiaryCommentImagePickResult.failed;
  }

  Future<void> _discardQuietly(String path) async {
    try {
      await _discarder(path);
    } catch (error) {
      debugPrint('Comment image cleanup failed: $error');
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  static Future<List<PlatformFile>?> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: false,
      withReadStream: true,
    );
    return result?.files;
  }

  static Future<String> _importImage(PlatformFile file) async {
    final DiaryFileAttachment stored =
        await DiaryMediaStorageService.importFile(
          kind: DiaryMediaKind.image,
          fileName: file.name,
          sourcePath: file.path,
          readStream: file.readStream,
          bytes: file.bytes,
        );
    return stored.path;
  }

  @override
  void dispose() {
    _disposed = true;
    if (!_handedOff) {
      for (final path in _fresh) {
        unawaited(_discardQuietly(path));
      }
    }
    _fresh.clear();
    super.dispose();
  }
}
