import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../core/services/settings_service.dart';
import '../../diaries/models/diary_card_style/diary_card_style.dart';
import '../../diaries/models/diary_card_style/diary_card_style_code.dart';
import '../../diaries/models/diary_card_style/diary_card_style_presets.dart';
import '../../diaries/models/diary_card_style/diary_card_style_settings.dart';
import '../../diaries/providers/diary_card_style_provider.dart';

/// 日记卡片样式编辑页的业务编排。
///
/// 输入：设置服务（读写 `diaryCardStyleRaw` 与独立的标签上限）；输出：当前
/// 样式、预览模式与明暗，以及套用预设、保存/删除“我的样式”、样式码导入
/// 导出等动作。副作用：写入设置（经 [saveDiaryCardStyleSettings]，与默认
/// 相同时删除键）。
///
/// 写入时机：
/// - 开关、单选与滑块松手（[commit]）即写入，日记列表随即生效；
/// - 滑块拖动中只更新草稿（[preview]），预览即时重绘但不写盘——否则每帧
///   一次写入，还会让后方的日记列表跟着逐帧重建。
///
/// 外部改动（备份恢复、失败回滚）经 raw notifier 同步进来并丢弃草稿。写盘
/// 失败不打断编辑：内存里的样式已生效，与日历显示选项的处理一致。
class DiaryCardStyleEditorController extends ChangeNotifier {
  DiaryCardStyleEditorController({
    required this.settingsService,
    DiaryCardMode initialMode = DiaryCardMode.list,
  }) : _settings = DiaryCardStyleSettings.decode(
         settingsService.diaryCardStyleRaw,
       ),
       _mode = initialMode,
       _tagLimit = settingsService.diaryCardTagLimit {
    settingsService.diaryCardStyleRawNotifier.addListener(_syncFromStorage);
    settingsService.diaryCardTagLimitNotifier.addListener(_syncTagLimit);
  }

  final SettingsService settingsService;

  DiaryCardStyleSettings _settings;
  DiaryCardStyle? _draft;
  DiaryCardMode _mode;
  Brightness? _previewBrightness;
  int _tagLimit;
  bool _disposed = false;

  DiaryCardStyleSettings get settings => _settings;

  /// 预览与各分组展示的样式：拖动中的草稿优先。
  DiaryCardStyle get style => _draft ?? _settings.current;

  /// 正在编辑（也正在预览）的布局模式；“专属”分组改的就是它。
  DiaryCardMode get mode => _mode;
  DiaryCardModeStyle get modeStyle => style.mode(_mode);

  /// 预览的明暗；null 表示跟随应用当前主题。
  Brightness? get previewBrightness => _previewBrightness;

  /// 卡片标签显示上限（独立的旧设置，预览同步使用）。
  int get tagLimit => _tagLimit;

  /// 当前样式对应的内置预设；不是任何预设时为 null。
  DiaryCardPresetId? get matchingPreset => DiaryCardPresets.match(style);

  /// 当前样式对应的“我的样式”；不是任何保存项时为 null。
  DiaryCardSavedStyle? get matchingSaved {
    for (final item in _settings.saved) {
      if (item.style == style) {
        return item;
      }
    }
    return null;
  }

  set mode(DiaryCardMode value) {
    if (value == _mode) {
      return;
    }
    _mode = value;
    _notify();
  }

  set previewBrightness(Brightness? value) {
    if (value == _previewBrightness) {
      return;
    }
    _previewBrightness = value;
    _notify();
  }

  /// 拖动中的即时预览，不写盘。
  void preview(DiaryCardStyle next) {
    if (next == style) {
      return;
    }
    _draft = next;
    _notify();
  }

  /// 写入新样式（并丢弃草稿）。
  Future<void> commit(DiaryCardStyle next) {
    _draft = null;
    return _save(_settings.withCurrent(next));
  }

  /// 便捷写法：改当前模式的专属样式。
  Future<void> commitMode(
    DiaryCardModeStyle Function(DiaryCardModeStyle current) update,
  ) => commit(style.withMode(_mode, update(modeStyle)));

  void previewMode(
    DiaryCardModeStyle Function(DiaryCardModeStyle current) update,
  ) => preview(style.withMode(_mode, update(modeStyle)));

  /// 套用内置预设；返回此前的样式供撤销。
  Future<DiaryCardStyle> applyPreset(DiaryCardPresetId id) =>
      applyStyle(DiaryCardPresets.styleOf(id));

  /// 整体替换当前样式（套用预设、我的样式、导入或撤销）；返回此前的样式。
  Future<DiaryCardStyle> applyStyle(DiaryCardStyle next) async {
    final previous = style;
    await commit(next);
    return previous;
  }

  /// 恢复默认样式；返回此前的样式供撤销。
  Future<DiaryCardStyle> reset() => applyStyle(DiaryCardStyle.defaults);

  bool get canSaveMore => _settings.canSaveMore;

  /// 把当前样式存为“我的样式”；已达上限时返回 false。
  Future<bool> saveCurrentAs(String name) async {
    if (!_settings.canSaveMore) {
      return false;
    }
    final next = _settings.addSaved(name, style);
    if (next == _settings) {
      return false;
    }
    _draft = null;
    await _save(next.withCurrent(style));
    return true;
  }

  Future<void> renameSaved(String id, String name) =>
      _save(_settings.renameSaved(id, name));

  /// 删除一份保存项；返回被删的条目与原位置供撤销。
  Future<(DiaryCardSavedStyle, int)?> deleteSaved(String id) async {
    final index = _settings.saved.indexWhere((item) => item.id == id);
    if (index < 0) {
      return null;
    }
    final item = _settings.saved[index];
    await _save(_settings.removeSaved(id));
    return (item, index);
  }

  Future<void> restoreSaved(DiaryCardSavedStyle item, int index) =>
      _save(_settings.restoreSaved(item, index));

  /// 当前样式的样式码（附带当前预设或保存项的名字，便于对方识别）。
  String exportCode({String? name}) =>
      DiaryCardStyleCode.encode(style, name: name ?? matchingSaved?.name);

  /// 解析并套用样式码；无法解析时不改动样式。返回解析结果与此前的样式。
  Future<(DiaryCardStyleCodeResult, DiaryCardStyle?)> importCode(
    String? text,
  ) async {
    final result = DiaryCardStyleCode.decode(text);
    final imported = result.style;
    if (imported == null) {
      return (result, null);
    }
    final previous = await applyStyle(imported);
    return (result, previous);
  }

  Future<void> setTagLimit(int value) async {
    _tagLimit = value;
    _notify();
    await settingsService.setDiaryCardTagLimit(value);
  }

  Future<void> _save(DiaryCardStyleSettings next) async {
    if (next == _settings) {
      _notify();
      return;
    }
    _settings = next;
    _notify();
    try {
      await saveDiaryCardStyleSettings(settingsService, next);
    } catch (error, stackTrace) {
      // 外观偏好写盘失败不打断编辑：内存与列表已经生效。
      debugPrint('Failed to persist diary card style: $error\n$stackTrace');
    }
  }

  void _syncFromStorage() {
    final next = DiaryCardStyleSettings.decode(
      settingsService.diaryCardStyleRaw,
    );
    if (next == _settings) {
      return;
    }
    _settings = next;
    _draft = null;
    _notify();
  }

  void _syncTagLimit() {
    final next = settingsService.diaryCardTagLimit;
    if (next == _tagLimit) {
      return;
    }
    _tagLimit = next;
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    settingsService.diaryCardStyleRawNotifier.removeListener(_syncFromStorage);
    settingsService.diaryCardTagLimitNotifier.removeListener(_syncTagLimit);
    super.dispose();
  }
}
