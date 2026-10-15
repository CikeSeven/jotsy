import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../models/calendar_display_options.dart';

/// 日历显示选项 provider。
///
/// 把 SettingsService 的 ValueNotifier 桥接为 StreamProvider：调整面板写入
/// 后日历网格即时重绘，备份恢复改写该键时也会同步。相同选项不重复推送，
/// 避免“记住上次格式”这类写入引起无意义的整页重建。
final calendarDisplayOptionsProvider = StreamProvider<CalendarDisplayOptions>((
  Ref ref,
) async* {
  final settings = await ref.watch(settingsServiceProvider.future);
  var current = CalendarDisplayOptions.decode(
    settings.calendarDisplayOptionsRaw,
  );
  final controller = StreamController<CalendarDisplayOptions>();
  void listener() {
    final next = CalendarDisplayOptions.decode(
      settings.calendarDisplayOptionsRaw,
    );
    if (next == current) {
      return;
    }
    current = next;
    controller.add(next);
  }

  settings.calendarDisplayOptionsRawNotifier.addListener(listener);
  ref.onDispose(() {
    settings.calendarDisplayOptionsRawNotifier.removeListener(listener);
    unawaited(controller.close());
  });

  yield current;
  yield* controller.stream;
});

/// 持久化日历显示选项；与默认选项相同则移除该键，备份里不留冗余配置。
Future<void> saveCalendarDisplayOptions(
  SettingsService settings,
  CalendarDisplayOptions options,
) {
  return settings.setCalendarDisplayOptionsRaw(
    options == const CalendarDisplayOptions() ? null : options.encode(),
  );
}
