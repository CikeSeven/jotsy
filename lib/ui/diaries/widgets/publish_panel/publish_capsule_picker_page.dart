import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/app_surface/widgets/on_glass.dart';
import 'package:node_diary/ui/diaries/models/time_capsule.dart';
import 'package:node_diary/ui/widgets/expressive_button_group.dart';

/// 面板的时间胶囊子页：快捷预设、精度（只按日期 / 精确到时间）、日期滚轮、
/// 取消与确认。
///
/// 自己持有待选值，确认时才交给 [onConfirm]；每次打开都以新的 key 重建，
/// 从 [initial] 重新开始。
class PublishCapsulePickerPage extends StatefulWidget {
  const PublishCapsulePickerPage({
    super.key,
    required this.initial,
    required this.onConfirm,
    required this.onCancel,
  });

  final TimeCapsuleSchedule? initial;
  final ValueChanged<TimeCapsuleSchedule> onConfirm;
  final VoidCallback onCancel;

  @override
  State<PublishCapsulePickerPage> createState() =>
      _PublishCapsulePickerPageState();
}

class _PublishCapsulePickerPageState extends State<PublishCapsulePickerPage> {
  // 打开时冻结的“现在”：选择器的上下限按它算，不在每次构建时重取，否则
  // 滚轮停在下限、过一分钟再重建时初始值会早于新下限而断言。
  late final DateTime _openedAt;
  late DateTime _pendingUnlockAt;
  late TimeCapsulePrecision _precision;
  // CupertinoDatePicker 只在创建时读取初始值与模式：快捷预设递增它换 key
  // 重建，让滚轮跳到新值（精度变化同样在 key 里）。
  int _pickerGeneration = 0;

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
    _precision = widget.initial?.precision ?? TimeCapsulePrecision.date;
    _pendingUnlockAt = TimeCapsuleSchedule.initialPendingUnlockAt(
      widget.initial,
      _openedAt,
    );
  }

  DateTime _clamp(DateTime value, {DateTime? now}) =>
      TimeCapsuleSchedule.clampUnlockAt(
        value,
        precision: _precision,
        now: now ?? _openedAt,
      );

  void _applyPreset(TimeCapsulePreset preset) {
    setState(() {
      _pendingUnlockAt = _clamp(
        TimeCapsuleSchedule.presetUnlockAt(preset, DateTime.now()),
      );
      _pickerGeneration++;
    });
  }

  void _changePrecision(TimeCapsulePrecision precision) {
    setState(() {
      _precision = precision;
      // 分钟 → 日期时下限推到明天零点，先夹到范围内再交给新选择器。
      _pendingUnlockAt = _clamp(_pendingUnlockAt);
    });
  }

  void _confirm() {
    widget.onConfirm(
      TimeCapsuleSchedule(
        // 在选择页停留期间下限可能已经过去（滚轮停在最早一分钟/明天）：按
        // 确认这一刻重新夹一次，用户选的“最早”仍是最早，而不是过去的时刻。
        unlockAt: _clamp(_pendingUnlockAt, now: DateTime.now()),
        precision: _precision,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    // 快捷预设胶囊的主题底色不透明，在玻璃面板上换成半透明凹槽色。
    final chipColor = OnGlass.of(context)
        ? OnGlass.wellColor(colorScheme)
        : null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ActionChip(
                backgroundColor: chipColor,
                label: Text(l10n.timeCapsuleQuickWeek),
                onPressed: () => _applyPreset(TimeCapsulePreset.week),
              ),
              ActionChip(
                backgroundColor: chipColor,
                label: Text(l10n.timeCapsuleQuickMonth),
                onPressed: () => _applyPreset(TimeCapsulePreset.month),
              ),
              ActionChip(
                backgroundColor: chipColor,
                label: Text(l10n.timeCapsuleQuickYear),
                onPressed: () => _applyPreset(TimeCapsulePreset.year),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ExpressiveButtonGroup<TimeCapsulePrecision>(
            segments: <ButtonSegment<TimeCapsulePrecision>>[
              ButtonSegment<TimeCapsulePrecision>(
                value: TimeCapsulePrecision.date,
                label: Text(l10n.timeCapsulePrecisionDate),
              ),
              ButtonSegment<TimeCapsulePrecision>(
                value: TimeCapsulePrecision.minute,
                label: Text(l10n.timeCapsulePrecisionMinute),
              ),
            ],
            selected: <TimeCapsulePrecision>{_precision},
            onSelectionChanged: (values) => _changePrecision(values.single),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 184,
            child: CupertinoDatePicker(
              key: ValueKey<(TimeCapsulePrecision, int)>((
                _precision,
                _pickerGeneration,
              )),
              // “只按日期”只给日期滚轮，避免让用户调一个会被丢掉的时分。
              mode: _precision == TimeCapsulePrecision.date
                  ? CupertinoDatePickerMode.date
                  : CupertinoDatePickerMode.dateAndTime,
              minimumDate: TimeCapsuleSchedule.earliestUnlockAt(
                _precision,
                _openedAt,
              ),
              maximumDate: TimeCapsuleSchedule.latestUnlockAt(_openedAt),
              initialDateTime: _clamp(_pendingUnlockAt),
              use24hFormat: true,
              onDateTimeChanged: (value) => _pendingUnlockAt = value,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: widget.onCancel,
                  child: Text(l10n.commonCancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _confirm,
                  child: Text(l10n.commonConfirm),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
