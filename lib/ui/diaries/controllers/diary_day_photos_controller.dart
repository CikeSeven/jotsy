import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:node_diary/core/services/day_photo_library.dart';

/// 补写日记时“这天拍的照片”提示条的状态。
enum DiaryDayPhotosPhase {
  /// 不显示：不自动显示（非补写或开关关闭）、已关掉、平台不支持、读取中或
  /// 这天没照片。
  hidden,

  /// 未授权读取相册：显示一行说明与“允许访问”按钮。
  needsAccess,

  /// 有照片可选。
  ready,
}

/// “这天的照片”面板（`DiaryDayPhotosSheet`）的状态。
///
/// 与提示条不同，面板是用户主动打开的，读取中与没有照片都要明确呈现，
/// 不能像提示条那样整块收起。
enum DiaryDayPhotosSheetPhase {
  /// 还不知道授权状态，或这天的照片正在读取且还没有可显示的照片。
  loading,

  /// 未授权读取相册。
  needsAccess,

  /// 已读取完，这天没有照片（读取失败也按没有照片处理）。
  empty,

  /// 有照片可选。
  ready,
}

/// 编排“这天拍的照片”：读取授权 → 查询当天照片 → 勾选 → 记录已插入。
///
/// 两个入口共用这一份状态（勾选、已插入、封面角标都共享）：
/// - 提示条：只在 [configure] 的 `autoShow` 为 true（新建、补写过去某天且
///   编辑器设置开着）且本次没关掉时自动读取并显示；
/// - 面板：用户从编辑页顶栏菜单打开时调用 [browse]，不论开关、模式与是否
///   关掉过提示条，都读取日记那天的照片。
///
/// 职责边界：
/// - 输入：日记那天、是否自动显示（[configure]）、用户点按；
/// - 输出：[phase]（提示条）、[sheetPhase]（面板）、照片列表、勾选与已插入
///   集合，变化经 [notifyListeners]；
/// - 副作用：只经 [DayPhotoLibrary] 读取相册与申请权限；不写正文、不复制
///   文件（插入由编辑页交给 DiaryMediaImportController 完成）。
///
/// 时序约束：
/// - 进入页面与打开面板都只“查询”授权状态，绝不主动弹系统权限框；弹框
///   只发生在用户点按“允许访问”时（[requestAccess]）。
/// - 只有“需要照片”（自动显示且没关掉，或本次换日期后打开过面板）时才读取；
///   [refresh]（回到前台，例如从系统设置开了权限回来）在同一条件下重新读取，
///   面板开着时授权后立即更新。
/// - 每次换日期或重新读取都递增 [_generation]，较早发出的异步结果回来时
///   代数不符直接丢弃，快速改日期也不会显示错天的照片。[dismiss] 只在没有
///   打开过面板时递增代数：关掉提示条不能打断面板正在进行的读取。
/// - 读取中不清空已有照片（回到前台刷新时不闪），只有换日期才清空；换日期
///   同时清掉“打开过面板”，新的一天要等再次打开面板（或自动显示）才读取。
/// - 勾选与已插入只存在于本次编辑页内存，不落盘：相册 id 换台设备就失效。
/// - 封面本身存在日记草稿里（拷贝到封面私有目录的路径）；这里只记“哪张
///   照片是当前封面”用于显示角标。草稿封面被别处换掉或清除时经
///   [syncCover] 对不上路径，角标随之消失。
class DiaryDayPhotosController extends ChangeNotifier {
  DiaryDayPhotosController({required this.library});

  final DayPhotoLibrary library;

  DateTime? _day;
  bool _autoShow = false;
  bool _dismissed = false;
  // 用户从菜单打开过面板（换日期时清掉）：此后即使不自动显示也照常读取。
  bool _browsing = false;
  DayPhotoAccess? _access;
  // 本次编辑页内已经弹过一次权限框：再点按钮改为打开系统设置（Android 在
  // 用户拒绝后可能不再弹框，继续请求会表现为“点了没反应”）。
  bool _requestedAccess = false;
  List<DayPhoto> _photos = const <DayPhoto>[];
  // 当前这天的照片已读取完一次（成功或失败）：面板据此区分“读取中”与
  // “没有照片”。换日期时复位。
  bool _photosLoaded = false;
  // 正在进行的读取所属的代数；与 [_generation] 相等才算“当前读取进行中”，
  // 代数被递增（换日期、关掉）后自动不再算数，无需另行复位。
  int? _loadingGeneration;
  final Set<String> _selected = <String>{};
  final Set<String> _inserted = <String>{};
  String? _coverPhotoId;
  String? _coverPath;
  int _generation = 0;
  bool _disposed = false;

  DateTime? get day => _day;
  List<DayPhoto> get photos => _photos;
  bool get isLimited => _access == DayPhotoAccess.limited;

  /// 已请求过权限仍被拒绝：按钮改为“去设置”。
  bool get shouldOpenSettings =>
      _requestedAccess && _access == DayPhotoAccess.denied;

  int get selectedCount => _selected.length;
  bool isSelected(DayPhoto photo) => _selected.contains(photo.id);
  bool isInserted(DayPhoto photo) => _inserted.contains(photo.id);
  bool isCover(DayPhoto photo) => _coverPhotoId == photo.id;

  /// 只勾选了一张时的那张：操作行据此提供“设为封面 / 取消封面”。
  DayPhoto? get singleSelection {
    if (_selected.length != 1) return null;
    final id = _selected.single;
    for (final photo in _photos) {
      if (photo.id == id) return photo;
    }
    return null;
  }

  /// 勾选的照片，按拍摄时间排列（与当天经过的顺序一致，而不是点按顺序）。
  List<DayPhoto> get selectedPhotos => <DayPhoto>[
    for (final photo in _photos)
      if (_selected.contains(photo.id)) photo,
  ];

  /// 能否打开面板：有日记那天（不晚于今天）且平台支持读取相册。
  bool get canBrowse => _day != null && library.isSupported;

  bool get _isLoading => _loadingGeneration == _generation;

  /// 是否需要读取照片：提示条在自动显示，或用户打开过面板。
  bool get _wantsPhotos => (_autoShow && !_dismissed) || _browsing;

  DiaryDayPhotosPhase get phase {
    if (!_autoShow || _day == null || _dismissed || !library.isSupported) {
      return DiaryDayPhotosPhase.hidden;
    }
    final access = _access;
    if (access == null) return DiaryDayPhotosPhase.hidden;
    if (!access.canRead) return DiaryDayPhotosPhase.needsAccess;
    return _photos.isEmpty
        ? DiaryDayPhotosPhase.hidden
        : DiaryDayPhotosPhase.ready;
  }

  DiaryDayPhotosSheetPhase get sheetPhase {
    // 不可能读到照片（没有日子或平台不支持）：直接按没有照片呈现，避免
    // 面板一直转圈。正常流程里这种情况不会打开面板（见 [canBrowse]）。
    if (!canBrowse) return DiaryDayPhotosSheetPhase.empty;
    final access = _access;
    if (access == null) {
      // 授权查询失败时没有结果可等，按没有照片处理。
      return _isLoading || !_photosLoaded
          ? DiaryDayPhotosSheetPhase.loading
          : DiaryDayPhotosSheetPhase.empty;
    }
    if (!access.canRead) return DiaryDayPhotosSheetPhase.needsAccess;
    if (_photos.isNotEmpty) return DiaryDayPhotosSheetPhase.ready;
    return _isLoading || !_photosLoaded
        ? DiaryDayPhotosSheetPhase.loading
        : DiaryDayPhotosSheetPhase.empty;
  }

  ImageProvider thumbnailOf(DayPhoto photo) => library.thumbnailOf(photo);

  /// 补写的日子：日期严格早于今天才算补写；今天与未来（时间胶囊）都不算。
  static DateTime? backfillDay(DateTime? date, {DateTime? now}) {
    final day = diaryDay(date, now: now);
    if (day == null) return null;
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    return day.isBefore(today) ? day : null;
  }

  /// 可以查看照片的日记那天：今天及以前的日子；未来（时间胶囊还没到的
  /// 日子）没有照片可看，返回 null。
  static DateTime? diaryDay(DateTime? date, {DateTime? now}) {
    if (date == null) return null;
    final day = DateTime(date.year, date.month, date.day);
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    return day.isAfter(today) ? null : day;
  }

  /// 同步日记那天与是否自动显示提示条；输入没变时什么也不做，可在每次变化
  /// 后放心调用。
  ///
  /// [day] 为 null 表示没有可查看的日子（未来日期、详情未加载）。
  /// [autoShow] 只决定提示条能否自动出现；面板经 [browse] 打开，与它无关。
  void configure({required DateTime? day, required bool autoShow}) {
    final normalized = day == null
        ? null
        : DateTime(day.year, day.month, day.day);
    if (normalized == _day && autoShow == _autoShow) return;
    final dayChanged = normalized != _day;
    // 同一天、之前就在读取：只是开关变化（如开关关了但面板打开过），不必
    // 重新读取。
    final wasWanted = !dayChanged && _wantsPhotos;
    _day = normalized;
    _autoShow = autoShow;
    if (dayChanged) {
      _photos = const <DayPhoto>[];
      _photosLoaded = false;
      _selected.clear();
      _browsing = false;
    }
    if (!_wantsPhotos || normalized == null || !library.isSupported) {
      _generation++;
      _notify();
      return;
    }
    _notify();
    if (!wasWanted) _reload();
  }

  /// 用户从菜单打开面板时调用：不论是否自动显示、提示条是否关掉过，都读取
  /// 这天的照片。只查询授权，从不弹系统权限框；当前代数已有读取在进行时
  /// 不重复发起，等它回来即可。
  void browse() {
    if (_disposed || !canBrowse) return;
    _browsing = true;
    if (_isLoading) return;
    _reload();
  }

  /// 回到前台或从系统设置返回后重新读取：权限与相册内容都可能变了。
  void refresh() {
    if (!_wantsPhotos || _day == null || !library.isSupported) return;
    _reload();
  }

  /// 用户点按“允许访问”：首次弹系统权限框，之后改为打开系统设置。
  Future<void> requestAccess() async {
    if (_disposed) return;
    if (shouldOpenSettings) {
      await library.openSettings();
      return;
    }
    _requestedAccess = true;
    final generation = ++_generation;
    try {
      final access = await library.requestAccess();
      if (_disposed || generation != _generation) return;
      _access = access;
      if (access.canRead) _loadingGeneration = generation;
      _notify();
      if (access.canRead) await _load(generation);
    } catch (error) {
      debugPrint('Day photo permission request failed: $error');
    }
  }

  /// 部分授权时让用户追加可访问的照片，选完重新读取。
  Future<void> manageLimitedSelection() async {
    try {
      await library.manageLimitedSelection();
    } catch (error) {
      debugPrint('Day photo limited selection failed: $error');
    }
    if (!_disposed) _reload();
  }

  void toggle(DayPhoto photo) {
    if (_inserted.contains(photo.id)) return;
    if (!_selected.remove(photo.id)) _selected.add(photo.id);
    _notify();
  }

  void clearSelection() {
    if (_selected.isEmpty) return;
    _selected.clear();
    _notify();
  }

  /// 插入正文成功后调用：这些照片标记为已插入，并移出勾选。
  void markInserted(Iterable<DayPhoto> photos) {
    for (final photo in photos) {
      _inserted.add(photo.id);
      _selected.remove(photo.id);
    }
    _notify();
  }

  /// [photo] 已拷贝为封面 [coverPath] 后调用，显示封面角标。
  void markCover(DayPhoto photo, String coverPath) {
    _coverPhotoId = photo.id;
    _coverPath = coverPath;
    _notify();
  }

  /// 草稿封面变化时调用：不再是这里设的那张（发布页换了封面或清除了）就
  /// 去掉角标。
  void syncCover(String? currentCoverPath) {
    if (_coverPath == null || currentCoverPath == _coverPath) return;
    _coverPhotoId = null;
    _coverPath = null;
    _notify();
  }

  /// 关掉提示条，本次编辑不再出现；长期关闭在编辑器设置里。
  ///
  /// 打开过面板时不递增代数：面板可能正等着这次读取的结果。
  void dismiss() {
    _dismissed = true;
    if (!_browsing) _generation++;
    _notify();
  }

  void _reload() {
    final generation = ++_generation;
    _loadingGeneration = generation;
    () async {
      try {
        final access = await library.checkAccess();
        if (_disposed || generation != _generation) return;
        _access = access;
        if (!access.canRead) {
          _photos = const <DayPhoto>[];
          _finishLoad(generation);
          return;
        }
        await _load(generation);
      } catch (error) {
        debugPrint('Day photo access check failed: $error');
        if (_disposed || generation != _generation) return;
        _finishLoad(generation);
      }
    }();
  }

  Future<void> _load(int generation) async {
    final day = _day;
    if (day == null) return;
    try {
      final photos = await library.photosOn(day);
      if (_disposed || generation != _generation) return;
      _photos = List<DayPhoto>.unmodifiable(photos);
      // 照片可能已在相册里被删掉：勾选只保留仍然存在的。
      final ids = {for (final photo in photos) photo.id};
      _selected.removeWhere((id) => !ids.contains(id));
      _finishLoad(generation);
    } catch (error) {
      // 读取失败按“没有照片”处理，不打断写日记。
      debugPrint('Day photo query failed: $error');
      if (_disposed || generation != _generation) return;
      _photos = const <DayPhoto>[];
      _finishLoad(generation);
    }
  }

  /// 当前代数的读取结束（成功、失败或未授权）：面板不再显示读取中。
  void _finishLoad(int generation) {
    if (_loadingGeneration == generation) _loadingGeneration = null;
    _photosLoaded = true;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
