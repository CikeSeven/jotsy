// 启动器小组件列表里的生成预览（Android 15+）：按界面语言与主题色建一份示例快照
// （`buildHomeWidgetSampleSnapshot`，不含用户数据），交给原生发布。
//
// 口径（语言、主题色、快照格式版本）不变就不再发：系统对发布限流，原生也按口径跳过已
// 发布的种类。被限流（[HomeWidgetPreviewPublish.pending]）时至少 [_retryDelay] 后再试；
// 不支持（Android 15 以下）时这次运行不再尝试，静态预览图（`previewImage`）兜底。
// 由同步控制器在每次同步时调用，桌面上没有小组件时也照常发布（列表里的预览给还没用过
// 小组件的人看）。

import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

import '../../../core/services/home_widgets/home_widget_gateway.dart';
import '../../../l10n/app_localizations.dart';
import '../../calendar/models/calendar_display_options.dart';
import '../viewmodels/home_widget_sample_data.dart';
import '../viewmodels/home_widget_snapshot_builder.dart';

/// 被限流后多久再试（非动画计时）。
const Duration _retryDelay = Duration(minutes: 30);

class HomeWidgetPreviewPublisher {
  HomeWidgetPreviewPublisher(this.gateway);

  final HomeWidgetGateway gateway;

  /// 已经发布完（或确认不支持）的口径。
  String? _settled;
  DateTime? _retryAt;

  Future<void> publish({
    required DateTime now,
    required AppLocalizations l10n,
    required Color appSeed,
    required CalendarWeekStart weekStart,
  }) async {
    final key =
        '${l10n.localeName}|${appSeed.toARGB32()}|${weekStart.name}|'
        'v$kHomeWidgetSnapshotVersion';
    if (key == _settled) return;
    final retryAt = _retryAt;
    if (retryAt != null && now.isBefore(retryAt)) return;
    try {
      final sample = await buildHomeWidgetSampleSnapshot(
        now: now,
        l10n: l10n,
        appSeed: appSeed,
        weekStart: weekStart,
      );
      final outcome = await gateway.publishPreviews(jsonEncode(sample), key);
      if (outcome == HomeWidgetPreviewPublish.pending) {
        _retryAt = now.add(_retryDelay);
      } else {
        _settled = key;
        _retryAt = null;
      }
    } catch (error) {
      // 发布不了只是列表里的预览旧一点或用静态图，不影响小组件本身。
      debugPrint('home widgets: publishing previews failed: $error');
      _retryAt = now.add(_retryDelay);
    }
  }
}
