import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/services/app_background_storage_service.dart';
import '../../../core/services/settings_service.dart';
import '../../app_surface/models/app_surface_settings.dart';
import '../../app_surface/providers/app_surface_settings_provider.dart';
import 'style_draft_controller.dart';

/// 选一张背景图并导入托管目录（可注入，便于测试成功 / 取消 / 失败分支）。
typedef AppBackgroundImagePicker = Future<AppBackgroundPickResult> Function();

/// 删除托管目录里不在 keep 中的背景图（可注入，测试里不碰真实目录）。
typedef AppBackgroundImageCleaner = Future<int> Function(Set<String> keep);

/// 把设置里的文件名解析成托管目录里的文件（可注入，测试里不碰真实目录）；
/// 名字不合法或文件已不存在时为 null。
typedef AppBackgroundImageResolver = Future<File?> Function(String? name);

/// 选图的结果（页面据此决定是否提示）。
enum AppSurfaceImagePickStatus {
  /// 已导入并写进设置。
  picked,

  /// 用户取消，什么都不做。
  cancelled,

  /// 选择器没给出本地路径（如部分云端文件）。
  unavailable,

  /// 拷贝进托管目录失败或选择器本身出错。
  failed,

  /// 页面已关闭或已有一次选图在进行，结果被丢弃。
  ignored,
}

/// “背景与材质”编辑页的业务编排。
///
/// 输入：设置服务（读写 `appSurfaceRaw`）、选图与清理函数（默认经
/// [AppBackgroundStorageService]）；输出：当前设置（含拖动中的草稿）、正在
/// 编辑的区域、选图中状态，以及背景 / 材质的预览、提交与重置动作（见
/// [StyleDraftController]）。副作用：写入设置、导入背景图、清理不再引用的
/// 背景图文件。
///
/// 正在编辑的区域 [area] 只在本页内存里：null 为全局背景，其余为某个区域。
/// 背景编辑器（全局与区域“单独设置”共用）一律经 [backgroundOf] /
/// [previewBackground] / [commitBackground] 读写，区域取的是 custom 一份。
///
/// 背景图文件的清理（[cleanUpImages]）：
/// - 只能在新设置写完之后用“已保存”的引用集合清理——先清理会删掉刚选、
///   还在写盘中的图片；因此先等进行中的写入结束再取引用；
/// - 重置后撤销窗口仍开着时（[holdUndo] … [releaseUndo]），撤销快照里的图片
///   也要保留，否则用户点撤销后背景指向一个已删除的文件；
/// - 选图进行中页面关闭：导入完成时控制器已释放，不再写入设置，留下的文件
///   由下次打开本页时的清理回收。
class AppSurfaceEditorController
    extends StyleDraftController<AppSurfaceSettings, AppSurfaceSettings> {
  AppSurfaceEditorController({
    required this.settingsService,
    AppBackgroundImagePicker? pickImage,
    AppBackgroundImageCleaner? deleteUnreferenced,
    AppBackgroundImageResolver? resolveImage,
    @visibleForTesting
    Future<void> Function(AppSurfaceSettings value)? persistOverride,
  }) : resolveImage = resolveImage ?? AppBackgroundStorageService.resolve,
       _pickImage = pickImage ?? AppBackgroundStorageService.pickAndImport,
       _deleteUnreferenced =
           deleteUnreferenced ?? AppBackgroundStorageService.deleteUnreferenced,
       super(
         rawNotifier: settingsService.appSurfaceRawNotifier,
         decode: AppSurfaceSettings.decode,
         persist:
             persistOverride ??
             (AppSurfaceSettings value) =>
                 saveAppSurfaceSettings(settingsService, value),
         currentOf: _identity,
         withCurrent: _replace,
         defaultStyle: AppSurfaceSettings.defaults,
       );

  final SettingsService settingsService;

  /// 缩略图与焦点取景器据此找到背景图文件。
  final AppBackgroundImageResolver resolveImage;
  final AppBackgroundImagePicker _pickImage;
  final AppBackgroundImageCleaner _deleteUnreferenced;

  static AppSurfaceSettings _identity(AppSurfaceSettings value) => value;

  static AppSurfaceSettings _replace(
    AppSurfaceSettings value,
    AppSurfaceSettings style,
  ) => style;

  AppBackgroundArea? _area;
  AppBackgroundArea? _previewArea;
  bool _picking = false;
  bool _released = false;
  Future<void> _pendingSave = Future<void>.value();
  final List<AppSurfaceSettings> _undoSnapshots = <AppSurfaceSettings>[];

  /// 背景标签页正在编辑的区域；null 为全局。
  AppBackgroundArea? get area => _area;

  set area(AppBackgroundArea? value) {
    if (value == _area) return;
    _area = value;
    _previewArea = value;
    notify();
  }

  /// 预览展示的区域：最后在背景标签页选过的区域（玻璃标签页沿用）；初始
  /// 为全局时按“日记”区域的版式展示。
  AppBackgroundArea get previewArea =>
      _previewArea ?? AppBackgroundArea.diaries;

  /// 预览里画的背景：编辑全局时直接看全局背景（即使“日记”区域单独设置
  /// 过，正在调的全局背景也要看得见），否则按该区域的实际取值。
  AppBackground get previewBackground {
    final area = _area;
    final value = style;
    return area == null ? value.global : value.backgroundFor(area);
  }

  /// 是否正在选图（按钮显示等待、防止重复点按）。
  bool get picking => _picking;

  /// 全局或某区域“单独设置”的那一份背景。
  AppBackground backgroundOf(AppBackgroundArea? area) =>
      area == null ? style.global : style.areaOf(area).custom;

  AppSurfaceSettings _withBackground(
    AppSurfaceSettings base,
    AppBackgroundArea? area,
    AppBackground value,
  ) {
    if (area == null) return base.withGlobal(value);
    return base.withArea(area, base.areaOf(area).copyWith(custom: value));
  }

  /// 拖动中（滑块、焦点取景器）只改草稿。
  void previewBackgroundOf(AppBackgroundArea? area, AppBackground value) =>
      preview(_withBackground(style, area, value));

  /// 写入全局或区域的背景。
  Future<void> commitBackground(AppBackgroundArea? area, AppBackground value) =>
      commit(_withBackground(style, area, value));

  /// 写入区域的取值方式（跟随全局 / 不显示 / 单独设置）；单独设置那一份
  /// 背景原样保留。
  Future<void> commitAreaMode(
    AppBackgroundArea area,
    AppAreaBackgroundMode mode,
  ) => commit(style.withArea(area, style.areaOf(area).copyWith(mode: mode)));

  /// 拖动中的材质预览。
  void previewGlass(AppGlassStyle value) => preview(style.withGlass(value));

  /// 写入材质设置。
  Future<void> commitGlass(AppGlassStyle value) =>
      commit(style.withGlass(value));

  /// 选一张图作为 [area] 的背景（null 为全局）。
  ///
  /// 成功时换上新图、种类改为图片，焦点回到正中（旧焦点对新图没有意义），
  /// 模糊与遮罩保留。旧图文件不在这里删：撤销、写盘失败时旧设置仍指向它，
  /// 统一由 [cleanUpImages] 按已保存的引用回收。
  Future<AppSurfaceImagePickStatus> pickImage(AppBackgroundArea? area) async {
    if (_picking || _released) return AppSurfaceImagePickStatus.ignored;
    _picking = true;
    notify();
    AppBackgroundPickResult result;
    try {
      result = await _pickImage();
    } catch (error, stackTrace) {
      // 选择器本身出错（平台异常等）与导入失败同样提示，不打断编辑。
      debugPrint('App background pick failed: $error\n$stackTrace');
      result = const AppBackgroundPickFailed();
    } finally {
      _picking = false;
      notify();
    }
    if (_released) return AppSurfaceImagePickStatus.ignored;
    switch (result) {
      case AppBackgroundPickCancelled():
        return AppSurfaceImagePickStatus.cancelled;
      case AppBackgroundPickMissingPath():
        return AppSurfaceImagePickStatus.unavailable;
      case AppBackgroundPickFailed():
        return AppSurfaceImagePickStatus.failed;
      case AppBackgroundPicked(:final name):
        await commitBackground(
          area,
          backgroundOf(area).copyWith(
            kind: AppBackgroundKind.image,
            image: () => name,
            alignX: 0,
            alignY: 0,
          ),
        );
        return AppSurfaceImagePickStatus.picked;
    }
  }

  /// 移除 [area] 的背景图：只清掉文件名，种类仍是图片（界面回到“选择图片”），
  /// 文件留给 [cleanUpImages] 在撤销窗口之外回收。
  Future<void> removeImage(AppBackgroundArea? area) =>
      commitBackground(area, backgroundOf(area).copyWith(image: () => null));

  /// 重置撤销窗口打开：窗口内 [snapshot] 引用的图片不清理。
  void holdUndo(AppSurfaceSettings snapshot) => _undoSnapshots.add(snapshot);

  /// 撤销窗口关闭（已撤销或已超时）。
  void releaseUndo(AppSurfaceSettings snapshot) =>
      _undoSnapshots.remove(snapshot);

  /// 删除不再被引用的背景图，返回删除的个数；出错时记日志并返回 0。
  ///
  /// 保留：已写入的设置（内存里的与存储里的，写盘失败时两者可能不同）、
  /// 撤销窗口内的快照。先等进行中的写入完成。
  Future<int> cleanUpImages() async {
    try {
      await _pendingSave;
      final keep = <String>{
        ...stored.referencedImages,
        ...AppSurfaceSettings.decode(rawNotifier.value).referencedImages,
        for (final snapshot in _undoSnapshots) ...snapshot.referencedImages,
      };
      return await _deleteUnreferenced(keep);
    } catch (error, stackTrace) {
      debugPrint('App background cleanup failed: $error\n$stackTrace');
      return 0;
    }
  }

  @override
  @protected
  Future<void> save(AppSurfaceSettings next) {
    // 记下这次写入：清理要在它之后进行（见类注释）。
    final pending = super.save(next);
    _pendingSave = _pendingSave.then((_) => pending);
    return pending;
  }

  @override
  void dispose() {
    _released = true;
    super.dispose();
  }
}
