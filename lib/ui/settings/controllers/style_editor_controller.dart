import 'package:flutter/foundation.dart';

import '../../diaries/models/style_library/saved_style.dart';
import '../../diaries/models/style_library/style_code.dart';

/// 样式编辑页（卡片样式、预览页样式）共用的业务编排。
///
/// 输入：持久化的 raw 字符串（经 [rawNotifier] 读取并监听）与它的解码、
/// 写入函数；输出：当前样式、预览明暗，以及套用、重置、保存/改名/删除
/// “我的样式”、样式码导入导出等动作。副作用：经 [persist] 写入设置。
///
/// 写入时机：
/// - 开关、单选与滑块松手（[commit]）即写入，真实页面随即生效；
/// - 滑块拖动中只更新草稿（[preview]），预览即时重绘但不写盘——否则每帧
///   一次写入，还会让后方的真实页面跟着逐帧重建。
///
/// 外部改动（备份恢复、失败回滚）经 [rawNotifier] 同步进来并丢弃草稿。写盘
/// 失败不打断编辑：内存里的样式已经生效，与日历显示选项的处理一致。
abstract class StyleEditorController<S, L extends StyleLibrary<S, L>>
    extends ChangeNotifier {
  StyleEditorController({
    required this.rawNotifier,
    required this.decode,
    required this.persist,
    required this.codeFormat,
    required this.defaultStyle,
  }) : _settings = decode(rawNotifier.value) {
    rawNotifier.addListener(_syncFromStorage);
  }

  final ValueListenable<String?> rawNotifier;
  final L Function(String? raw) decode;
  final Future<void> Function(L settings) persist;
  final StyleCodeFormat<S> codeFormat;
  final S defaultStyle;

  L _settings;
  S? _draft;
  Brightness? _previewBrightness;
  bool _disposed = false;

  L get settings => _settings;

  /// 预览与各分组展示的样式：拖动中的草稿优先。
  S get style => _draft ?? _settings.current;

  /// 预览的明暗；null 表示跟随应用当前主题。
  Brightness? get previewBrightness => _previewBrightness;

  set previewBrightness(Brightness? value) {
    if (value == _previewBrightness) {
      return;
    }
    _previewBrightness = value;
    notify();
  }

  /// 当前样式对应的“我的样式”；不是任何保存项时为 null。
  SavedStyle<S>? get matchingSaved =>
      SavedStyles.matching(_settings.saved, style);

  bool get canSaveMore => _settings.canSaveMore;

  /// 拖动中的即时预览，不写盘。
  void preview(S next) {
    if (next == style) {
      return;
    }
    _draft = next;
    notify();
  }

  /// 写入新样式（并丢弃草稿）。
  Future<void> commit(S next) {
    _draft = null;
    return save(_settings.withCurrent(next));
  }

  /// 整体替换当前样式（套用预设、我的样式、导入或撤销）；返回此前的样式。
  Future<S> applyStyle(S next) async {
    final previous = style;
    await commit(next);
    return previous;
  }

  /// 恢复默认样式；返回此前的样式供撤销。
  Future<S> reset() => applyStyle(defaultStyle);

  /// 把当前样式存为“我的样式”；已达上限或名字无效时返回 false。
  Future<bool> saveCurrentAs(String name) async {
    if (!_settings.canSaveMore) {
      return false;
    }
    final current = style;
    final next = _settings.addSaved(name, current);
    if (next == _settings) {
      return false;
    }
    _draft = null;
    await save(next.withCurrent(current));
    return true;
  }

  Future<void> renameSaved(String id, String name) =>
      save(_settings.renameSaved(id, name));

  /// 删除一份保存项；返回被删的条目与原位置供撤销。
  Future<(SavedStyle<S>, int)?> deleteSaved(String id) async {
    final index = _settings.saved.indexWhere((item) => item.id == id);
    if (index < 0) {
      return null;
    }
    final item = _settings.saved[index];
    await save(_settings.removeSaved(id));
    return (item, index);
  }

  Future<void> restoreSaved(SavedStyle<S> item, int index) =>
      save(_settings.restoreSaved(item, index));

  /// 当前样式的样式码（附带当前预设或保存项的名字，便于对方识别）。
  String exportCode({String? name}) =>
      codeFormat.encode(style, name: name ?? matchingSaved?.name);

  /// 解析并套用样式码；无法解析时不改动样式。返回解析结果与此前的样式。
  Future<(StyleCodeResult<S>, S?)> importCode(String? text) async {
    final result = codeFormat.decode(text);
    final imported = result.style;
    if (imported == null) {
      return (result, null);
    }
    final previous = await applyStyle(imported);
    return (result, previous);
  }

  /// 写入整体设置；与当前相同时只刷新监听者。
  @protected
  Future<void> save(L next) async {
    if (next == _settings) {
      notify();
      return;
    }
    _settings = next;
    notify();
    try {
      await persist(next);
    } catch (error, stackTrace) {
      // 外观偏好写盘失败不打断编辑：内存与真实页面已经生效。
      debugPrint('Failed to persist style settings: $error\n$stackTrace');
    }
  }

  @protected
  void notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _syncFromStorage() {
    final next = decode(rawNotifier.value);
    if (next == _settings) {
      return;
    }
    _settings = next;
    _draft = null;
    notify();
  }

  @override
  void dispose() {
    _disposed = true;
    rawNotifier.removeListener(_syncFromStorage);
    super.dispose();
  }
}
