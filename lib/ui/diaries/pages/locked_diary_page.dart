import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/qweather_icon.dart';
import '../models/time_capsule.dart';
import '../providers/diary_detail_provider.dart';
import '../widgets/diary_preview/diary_preview_host.dart';
import '../widgets/energy_battery_indicator.dart';
import '../../widgets/form_width.dart';

/// 未解封时间胶囊的封存页：只显示标题、倒计时与心情天气，可改解封时间或
/// 删除，正文不露出。
///
/// 嵌在宽窗口日记页的右栏里时传入 [host]：顶栏没有返回按钮，删除后交给
/// 宿主（移走选中并给出撤销），而不是自己提示并退出路由。
class LockedDiaryPage extends ConsumerWidget {
  const LockedDiaryPage({
    super.key,
    required this.diaryId,
    this.initialDetail,
    this.host,
  });

  final String diaryId;

  /// 入口已持有的同一篇日记；详情首查返回前直接用它渲染（见 DiaryPreviewPage）。
  final DiaryWithTags? initialDetail;

  /// 嵌在页面里时的宿主；独立路由时为 null。
  final DiaryPreviewHost? host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(diaryDetailProvider(diaryId));
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final seeded = initialDetail;
    if (seeded != null && !detailAsync.hasValue && !detailAsync.hasError) {
      return _LockedDiaryContent(detail: seeded, host: host);
    }
    return detailAsync.when(
      loading: () => Scaffold(
        backgroundColor: surfaceColor,
        appBar: _buildAppBar(context),
        body: const DelayedLoadingIndicator(),
      ),
      error: (error, stackTrace) => Scaffold(
        backgroundColor: surfaceColor,
        appBar: _buildAppBar(context),
        body: Center(child: Text(context.l10n.autoT0121(error.toString()))),
      ),
      data: (detail) {
        if (detail == null) {
          return Scaffold(
            backgroundColor: surfaceColor,
            appBar: _buildAppBar(context),
            body: Center(child: Text(context.l10n.autoT0124)),
          );
        }
        return _LockedDiaryContent(detail: detail, host: host);
      },
    );
  }

  AppTopBar _buildAppBar(BuildContext context) =>
      _lockedAppBar(context, embedded: host != null);
}

/// 封存页顶栏；嵌在页面里时没有返回按钮（右栏没有可返回的上一页）。
AppTopBar _lockedAppBar(BuildContext context, {required bool embedded}) {
  return AppTopBar(
    contentMaxWidth: FormWidth.maxWidth,
    automaticallyImplyLeading: !embedded,
    leading: embedded
        ? null
        : IconButton(
            tooltip: context.l10n.commonBack,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
          ),
    title: Text(context.l10n.timeCapsuleLockedTitle),
  );
}

class _LockedDiaryContent extends ConsumerWidget {
  const _LockedDiaryContent({required this.detail, this.host});

  final DiaryWithTags detail;
  final DiaryPreviewHost? host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final diary = detail.diary;
    final unlockAt = diary.capsuleUnlockAt;
    final state = TimeCapsuleState.fromFields(
      lockedAt: diary.capsuleLockedAt,
      unlockAt: unlockAt,
      now: DateTime.now(),
    );
    final title = diary.title.trim().isEmpty
        ? context.l10n.autoT0033
        : diary.title;
    final contextMeta = _extractContextMetadata(diary.metadata);
    final mood = contextMeta['moodEmoji']?.toString().trim();
    final weather = contextMeta['weather']?.toString().trim();
    final weatherIconCode = contextMeta['weatherIconCode']?.toString().trim();
    final energy = _parseEnergy(contextMeta['energyLevel']);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: _lockedAppBar(context, embedded: host != null),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final side = FormWidth.gutter(constraints.maxWidth, minGutter: 20);
          return ListView(
            padding: EdgeInsets.fromLTRB(side, 28, side, 28),
            children: <Widget>[
              Center(
                child: Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primaryContainer,
                  ),
                  alignment: Alignment.center,
                  child: FaIcon(
                    FontAwesomeIcons.lock,
                    size: 34,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _countdownLabel(context, state),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              if (unlockAt != null)
                Text(
                  context.l10n.timeCapsuleLockedHint(
                    _formatDateTime(context, unlockAt),
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  if (mood != null && mood.isNotEmpty) _MetaPill(label: mood),
                  if (weather != null && weather.isNotEmpty)
                    _MetaPill(
                      label: weather,
                      leading: QWeatherIcon(
                        iconCode: weatherIconCode,
                        weatherText: weather,
                        size: 14,
                      ),
                    ),
                  if (energy != null)
                    _MetaPill(
                      label: EnergyBatteryIndicator.descriptionForValue(
                        energy,
                        context.l10n,
                      ),
                      leading: EnergyBatteryIndicator(
                        value: energy,
                        iconSize: 18,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => _pickUnlockAt(context, ref, diary),
                icon: const FaIcon(FontAwesomeIcons.clock, size: 14),
                label: Text(context.l10n.timeCapsuleUpdateUnlock),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                onPressed: () => _deleteDiary(context, ref, diary.diaryId),
                icon: const FaIcon(FontAwesomeIcons.trashCan, size: 14),
                label: Text(context.l10n.commonDelete),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickUnlockAt(
    BuildContext context,
    WidgetRef ref,
    Diary diary,
  ) async {
    final now = DateTime.now();
    final current = diary.capsuleUnlockAt ?? now.add(const Duration(days: 1));
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: current.isAfter(now)
          ? current
          : now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(now.year + 10, now.month, now.day),
      helpText: context.l10n.timeCapsulePickTitle,
    );
    if (pickedDate == null || !context.mounted) {
      return;
    }
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (pickedTime == null || !context.mounted) {
      return;
    }
    final unlockAt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    await updateLockedDiaryUnlockAt(
      ref,
      diaryId: diary.diaryId,
      unlockAt: unlockAt,
    );
  }

  Future<void> _deleteDiary(
    BuildContext context,
    WidgetRef ref,
    String diaryId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.autoT0094),
          content: Text(l10n.autoT0113),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(
                  dialogContext,
                ).colorScheme.onSurfaceVariant,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.commonDelete),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    final db = ref.read(appDatabaseProvider);
    await db.softDeleteDiary(diaryId, touchUpdatedAt: false);
    // 嵌在页面里：撤销提示与选中的去向都由宿主处理，这里不提示也不退出。
    final host = this.host;
    if (host != null) {
      if (context.mounted) {
        host.onDeleted(diaryId);
      }
      return;
    }
    if (context.mounted) {
      var undoRequested = false;
      final undoClosed = HomeHintVisibilityScope.showTrackedSnackBar(
        context: context,
        snackBar: SnackBar(
          content: Text(context.l10n.autoT0075),
          duration: const Duration(seconds: 4),
          persist: false,
          action: SnackBarAction(
            label: context.l10n.commonUndo,
            onPressed: () => undoRequested = true,
          ),
        ),
      );
      Navigator.of(context).pop();
      unawaited(
        undoClosed.then((closedReason) async {
          if (undoRequested || closedReason == SnackBarClosedReason.action) {
            await db.restoreDiary(diaryId, touchUpdatedAt: false);
          }
        }),
      );
    }
  }

  Map<String, Object?> _extractContextMetadata(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final context = decoded['context'];
        if (context is Map<String, dynamic>) {
          return context;
        }
      }
    } catch (_) {
      return const <String, Object?>{};
    }
    return const <String, Object?>{};
  }

  double? _parseEnergy(Object? raw) {
    final parsed = switch (raw) {
      num value => value.toDouble(),
      String value => double.tryParse(value),
      _ => null,
    };
    return parsed == null
        ? null
        : EnergyBatteryIndicator.normalizeValue(parsed);
  }

  String _countdownLabel(BuildContext context, TimeCapsuleState state) {
    final hours = state.remainingDuration.inHours;
    if (hours > 0 && hours < 24) {
      return context.l10n.timeCapsuleCountdownHours(hours.toString());
    }
    return context.l10n.timeCapsuleCountdownDays(
      state.remainingDays.toString(),
    );
  }

  String _formatDateTime(BuildContext context, DateTime value) =>
      context.l10n.formatDateTimeMinute(value);
}

Future<void> updateLockedDiaryUnlockAt(
  WidgetRef ref, {
  required String diaryId,
  required DateTime unlockAt,
}) async {
  await ref
      .read(appDatabaseProvider)
      .updateDiaryCapsuleSchedule(diaryId: diaryId, unlockAt: unlockAt);
  ref.invalidate(diaryDetailProvider(diaryId));
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label, this.leading});

  final String label;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: ShapeDecoration(
        color: colorScheme.surfaceContainerHighest,
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (leading != null) ...<Widget>[leading!, const SizedBox(width: 6)],
          Text(label),
        ],
      ),
    );
  }
}
