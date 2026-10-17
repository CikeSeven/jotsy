import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:node_diary/core/services/day_photo_library.dart';

/// 补写日记时“这天拍的照片”提示条的状态。
enum DiaryDayPhotosPhase {
  /// 不显示：没有补写日期、功能关闭、已关掉、平台不支持、读取中或这天没照片。
  hidden,

  /// 未授权读取相册：显示一行说明与“允许访问”按钮。
  needsAccess,

  /// 有照片可选。
  ready,
}

/// 编排“这天拍的照片”：读取授权 → 查询当天照片 → 勾选 → 记录已插入。
///
/// 职责边界：
/// - 输入：补写日期与功能开关（[configure]）、用户点按；
/// - 输出：[phase]、照片列表、勾选与已插入集合，变化经 [notifyListeners]；
/// - 副作用：只经 [DayPhotoLibrary] 读取相册与申请权限；不写正文、不复制
///   文件（插入由编辑页交给 DiaryMediaImportController 完成）。
///
/// 时序约束：
/// - 进入页面只“查询”授权状态，绝不主动弹系统权限框；弹框只发生在用户
///   点按“允许访问”时（[requestAccess]）。
/// - 每次换日期或重新读取都递增 [_generation]，较早发出的异步结果回来时
///   代数不符直接丢弃，快速改日期也不会显示错天的照片。
/// - 读取中不清空已有照片（回到前台刷新时不闪），只有换日期才清空。
/// - 勾选与已插入只存在于本次编辑页内存，不落盘：相册 id 换台设备就失效。
/// - 封面本身存在日记草稿里（拷贝到封面私有目录的路径）；这里只记“哪张
///   照片是当前封面”用于显示角标。草稿封面被别处换掉或清除时经
///   [syncCover] 对不上路径，角标随之消失。
class DiaryDayPhotosController extends ChangeNotifier {
  DiaryDayPhotosController({required this.library});

  final DayPhotoLibrary library;

  DateTime? _day;
  bool _enabled = false;
  bool _dismissed = false;
  DayPhotoAccess? _access;
  // 本次编辑页内已经弹过一次权限框：再点按钮改为打开系统设置（Android 在
  // 用户拒绝后可能不再弹框，继续请求会表现为“点了没反应”）。
  bool _requestedAccess = false;
  List<DayPhoto> _photos = const <DayPhoto>[];
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

  DiaryDayPhotosPhase get phase {
    if (!_enabled || _day == null || _dismissed || !library.isSupported) {
      return DiaryDayPhotosPhase.hidden;
    }
    final access = _access;
    if (access == null) return DiaryDayPhotosPhase.hidden;
    if (!access.canRead) return DiaryDayPhotosPhase.needsAccess;
    return _photos.isEmpty
        ? DiaryDayPhotosPhase.hidden
        : DiaryDayPhotosPhase.ready;
  }

  ImageProvider thumbnailOf(DayPhoto photo) => library.thumbnailOf(photo);

  /// 补写的日子：日期严格早于今天才算补写；今天与未来（时间胶囊）都不算。
  static DateTime? backfillDay(DateTime? date, {DateTime? now}) {
    if (date == null) return null;
    final day = DateTime(date.year, date.month, date.day);
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    return day.isBefore(today) ? day : null;
  }

  /// 同步补写日期与功能开关；输入没变时什么也不做，可在每次变化后放心调用。
  void configure({required DateTime? day, required bool enabled}) {
    final normalized = day == null
        ? null
        : DateTime(day.year, day.month, day.day);
    if (normalized == _day && enabled == _enabled) return;
    final dayChanged = normalized != _day;
    _day = normalized;
    _enabled = enabled;
    if (dayChanged) {
      _photos = const <DayPhoto>[];
      _selected.clear();
    }
    if (!enabled || normalized == null || !library.isSupported) {
      _generation++;
      _notify();
      return;
    }
    _notify();
    _reload();
  }

  /// 回到前台或从系统设置返回后重新读取：权限与相册内容都可能变了。
  void refresh() {
    if (_dismissed || !_enabled || _day == null || !library.isSupported) {
      return;
    }
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
  void dismiss() {
    _dismissed = true;
    _generation++;
    _notify();
  }

  void _reload() {
    final generation = ++_generation;
    () async {
      try {
        final access = await library.checkAccess();
        if (_disposed || generation != _generation) return;
        _access = access;
        if (!access.canRead) {
          _photos = const <DayPhoto>[];
          _notify();
          return;
        }
        await _load(generation);
      } catch (error) {
        debugPrint('Day photo access check failed: $error');
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
      _notify();
    } catch (error) {
      // 读取失败按“没有照片”处理，不打断写日记。
      debugPrint('Day photo query failed: $error');
      if (_disposed || generation != _generation) return;
      _photos = const <DayPhoto>[];
      _notify();
    }
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
