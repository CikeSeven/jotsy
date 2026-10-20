part of 'package:node_diary/ui/calendar/pages/calendar_page.dart';

/// 日历显示选项相关的流程：打开调整面板、保存选项、记录上次的网格格式。
///
/// 选项写入设置服务后经 [calendarDisplayOptionsProvider] 回推页面，页面
/// 不另存一份副本；网格格式属于页面状态，只在选项要求“上次的视图”时写回。
extension _CalendarDisplayOptionsActions on _CalendarPageController {
  /// 网格格式持久化值 → table_calendar 格式。
  CalendarFormat formatFor(CalendarGridFormat format) => switch (format) {
    CalendarGridFormat.month => CalendarFormat.month,
    CalendarGridFormat.week => CalendarFormat.week,
  };

  /// 打开调整面板；面板内每次修改即时保存，日历在遮罩后方同步重绘。
  Future<void> openDisplayOptions() {
    // 时间胶囊、纪念日功能关闭时隐藏对应选项，数据保留。
    final features = _state.ref.read(appFeaturesProvider);
    return showCalendarDisplayOptionsSheet(
      _state.context,
      options: _state._displayOptions,
      showCapsuleBadgeOption: features.timeCapsules,
      showAnniversariesOption: features.anniversariesEnabled,
      onChanged: (CalendarDisplayOptions next) {
        // 刚切到“上次的视图”时以当前格式为起点，否则会沿用很久以前的记录。
        final adjusted = next.defaultFormat == CalendarDefaultFormat.remember
            ? next.copyWith(
                rememberedFormat: _gridFormatOf(_state._calendarFormat),
              )
            : next;
        saveDisplayOptions(adjusted);
      },
    );
  }

  /// 网格格式变化后调用：仅在“打开时显示”为“上次的视图”时记录。
  void rememberFormat(CalendarFormat format) {
    final options = _state._displayOptions;
    final gridFormat = _gridFormatOf(format);
    if (options.defaultFormat != CalendarDefaultFormat.remember ||
        options.rememberedFormat == gridFormat) {
      return;
    }
    saveDisplayOptions(options.copyWith(rememberedFormat: gridFormat));
  }

  CalendarGridFormat _gridFormatOf(CalendarFormat format) =>
      format == CalendarFormat.week
      ? CalendarGridFormat.week
      : CalendarGridFormat.month;

  /// 显示选项只影响外观：设置服务先更新内存值（页面立即生效）再落盘，
  /// 落盘失败时本次会话照常使用新选项，不打断用户，也不弹错误提示。
  void saveDisplayOptions(CalendarDisplayOptions options) {
    unawaited(() async {
      try {
        final settings = await _state.ref.read(settingsServiceProvider.future);
        await saveCalendarDisplayOptions(settings, options);
      } catch (_) {
        // 见方法注释：外观偏好写盘失败不影响当前使用。
      }
    }());
  }
}
