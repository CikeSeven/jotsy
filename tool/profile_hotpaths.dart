import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_codec.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations_gen_en.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/explore/controllers/explore_computation_controller.dart';
import 'package:node_diary/ui/explore/models/explore_computation_input.dart';
import 'package:node_diary/ui/explore/models/explore_layout.dart';
import 'package:node_diary/ui/explore/models/explore_period.dart';
import 'package:node_diary/ui/explore/viewmodels/explore_entry.dart';

/// Android AOT/profile 合成负载：只创建内存对象，不打开应用数据库、设置、
/// 媒体或网络。显式以此文件为 target 构建，经 adb install -r 安装同签名包。
/// 测完需重新覆盖安装正常 main.dart 包。不能用 flutter run 的安装失败回退
/// 代替手动覆盖安装，更不能清空用户应用。
///
/// 日志只输出数量/耗时/帧分位数。reference 直接重放改动前的同步实现，
/// 与当前生产入口在同一 AOT 包内对照；不把微基准当作应用端到端 FPS。
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: _ProfilePulse()));
}

class _ProfilePulse extends StatefulWidget {
  const _ProfilePulse();

  @override
  State<_ProfilePulse> createState() => _ProfilePulseState();
}

class _ProfilePulseState extends State<_ProfilePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run()));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final duration = ExpressiveMotion.duration(context, ExpressiveMotion.long);
    if (duration == Duration.zero) {
      _pulse.stop();
    } else {
      _pulse.duration = duration;
      _pulse.repeat();
    }
  }

  Future<void> _run() async {
    try {
      await initializeDateFormatting('en');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await _profileExplore();
      await _profileSnapshots();
      debugPrint('PERF_DEVICE_DONE');
    } catch (error, stack) {
      debugPrint('PERF_DEVICE_ERROR $error\n$stack');
    } finally {
      if (mounted) _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surface,
    child: Center(
      child: RotationTransition(
        turns: _pulse,
        child: FaIcon(
          FontAwesomeIcons.compass,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    ),
  );
}

Future<void> _measure(String name, FutureOr<int> Function() action) async {
  final frames = <FrameTiming>[];
  void record(List<FrameTiming> batch) => frames.addAll(batch);
  WidgetsBinding.instance.addTimingsCallback(record);
  final heartbeat = Stopwatch()..start();
  var lastTick = 0;
  var maxGap = 0;
  final timer = Timer.periodic(const Duration(milliseconds: 5), (_) {
    final tick = heartbeat.elapsedMicroseconds;
    final gap = tick - lastTick;
    if (gap > maxGap) maxGap = gap;
    lastTick = tick;
  });
  await Future<void>.delayed(const Duration(milliseconds: 30));
  final watch = Stopwatch()..start();
  final checksum = await action();
  final elapsed = watch.elapsedMicroseconds;
  // FrameTiming 按批回传，留出收尾窗口；心跳仍记录同步任务阻塞的那一段。
  await Future<void>.delayed(const Duration(milliseconds: 200));
  timer.cancel();
  WidgetsBinding.instance.removeTimingsCallback(record);
  debugPrint(
    'PERF_DEVICE ${jsonEncode({'scenario': name, 'elapsedUs': elapsed, 'maxHeartbeatGapUs': maxGap, 'checksum': checksum, 'frames': frames.length, 'uiUs': _percentiles(frames.map((f) => f.buildDuration.inMicroseconds)), 'rasterUs': _percentiles(frames.map((f) => f.rasterDuration.inMicroseconds)), 'totalSpanUs': _percentiles(frames.map((f) => f.totalSpan.inMicroseconds))})}',
  );
}

Map<String, int> _percentiles(Iterable<int> values) {
  final sorted = values.toList()..sort();
  if (sorted.isEmpty) return const {};
  int at(double quantile) => sorted[((sorted.length - 1) * quantile).round()];
  return {'p50': at(.5), 'p95': at(.95), 'p99': at(.99), 'max': sorted.last};
}

Future<void> _profileExplore() async {
  final now = DateTime(2026, 11, 7, 12);
  final text = '今天阳光明媚，hello 世界。\n' * 100;
  final metadata = jsonEncode({
    'context': {'moodEmoji': '😊', 'energyLevel': 3},
    'other': 'metadata ' * 40,
  });
  final rows = List.generate(
    10000,
    (i) => ExploreDiaryOverview(
      diaryId: 'synthetic-$i',
      title: 'Entry $i',
      contentText: text,
      metadata: metadata,
      tags: const [],
      createdAt: now.subtract(Duration(days: i % 3650)),
      updatedAt: now.subtract(Duration(minutes: i)),
    ),
  );
  final layout = ExploreLayout.defaults;
  final input = ExploreComputationInput(
    diaries: rows,
    layout: layout,
    modules: {
      for (final config in layout.modules)
        if (config.visible) config.id,
    },
    period: ExplorePeriod.all,
    now: now,
    firstWeekday: DateTime.monday,
    moodOptions: SettingsService.defaultMoodOptions,
    l10n: AppLocalizationsEn(),
  );
  for (var sample = 0; sample < 5; sample++) {
    await _measure(
      'explore.reference.$sample',
      () => input.build(ExploreEntryCache()).totalEntries,
    );
    final controller = ExploreComputationController();
    final ready = Completer<void>();
    controller.addListener(() => ready.complete());
    await _measure('explore.worker.$sample', () async {
      controller.resolve(input);
      await ready.future;
      final data = controller.resolve(input);
      if (data == null) throw StateError('Explore worker: ${controller.error}');
      return data.totalEntries;
    });
    controller.dispose();
  }
}

Future<void> _profileSnapshots() async {
  final document = jsonEncode({
    'document': {
      'type': 'page',
      'children': List.generate(
        10000,
        (_) => {
          'type': 'paragraph',
          'data': {
            'delta': [
              {'insert': '今天hello ' * 12},
            ],
          },
        },
      ),
    },
  });
  final controller = DiaryEditorController.fromContent(document);
  int reference() =>
      encodeDiaryBlocks(controller.document.toJson()).length +
      diaryBlocksPlainText(controller.document.toJson()).length;
  int current() => controller.contentJson.length + controller.plainText.length;
  await _measure('snapshot.current.cold', current);
  for (var sample = 0; sample < 5; sample++) {
    await _measure('snapshot.reference.$sample', reference);
    await _measure('snapshot.reused.$sample', current);
  }
  controller.dispose();
}
