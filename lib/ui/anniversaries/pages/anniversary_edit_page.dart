import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../calendar/widgets/calendar_options_controls.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/expressive_button_group.dart';
import '../../widgets/route_entrance_waiter.dart';
import '../../widgets/unsaved_changes_dialog.dart';
import '../controllers/anniversary_edit_controller.dart';
import '../models/anniversary_draft.dart';
import '../viewmodels/anniversary_rule.dart';
import '../widgets/anniversary_date_field.dart';

/// 纪念日编辑页（新建 / 编辑）。
///
/// 输入：初始草稿与（编辑时）原纪念日；输出：经 Navigator 带回
/// [AnniversaryEditResult]，提示由打开方给出。写库经
/// [AnniversaryEditController]；有未保存的修改时拦截返回并确认。
class AnniversaryEditPage extends ConsumerStatefulWidget {
  const AnniversaryEditPage({
    super.key,
    required this.initialDraft,
    this.editing,
  });

  final AnniversaryDraft initialDraft;
  final Anniversary? editing;

  @override
  ConsumerState<AnniversaryEditPage> createState() =>
      _AnniversaryEditPageState();
}

class _AnniversaryEditPageState extends ConsumerState<AnniversaryEditPage> {
  late AnniversaryDraft _draft = widget.initialDraft;
  late final TextEditingController _title = TextEditingController(
    text: widget.initialDraft.title,
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.initialDraft.note,
  );
  final FocusNode _titleFocus = FocusNode();
  final RouteEntranceWaiter _entrance = RouteEntranceWaiter();

  /// 名称被清空过才提示“请输入名称”，新建时一进来不先报错。
  bool _titleTouched = false;
  bool _saving = false;

  bool get _dirty => _draft.differsFrom(widget.initialDraft);

  AnniversaryEditController get _controller =>
      AnniversaryEditController(ref.read(appDatabaseProvider));

  @override
  void initState() {
    super.initState();
    // 新建且名称为空时，入场转场结束后再聚焦，键盘不与页面滑入叠加。
    if (widget.editing == null && widget.initialDraft.title.isEmpty) {
      _entrance.schedule(this, _titleFocus.requestFocus);
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _title.dispose();
    _note.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  void _update(AnniversaryDraft next) => setState(() => _draft = next);

  Future<void> _save() async {
    if (_saving) return;
    if (!_draft.isValid) {
      setState(() => _titleTouched = true);
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await _controller.save(_draft, editing: widget.editing);
      if (mounted) Navigator.of(context).pop(result);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      unawaited(
        HomeHintVisibilityScope.showTrackedSnackBar(
          context: context,
          snackBar: SnackBar(content: Text(context.l10n.anniversarySaveFailed)),
        ),
      );
    }
  }

  Future<void> _delete() async {
    final editing = widget.editing;
    if (editing == null || _saving) return;
    final confirmed = await AnniversaryEditController.confirmDelete(
      context,
      editing.title,
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    final row = await _controller.delete(editing);
    if (!mounted) return;
    Navigator.of(context).pop(row == null ? null : AnniversaryDeleted(row));
  }

  Future<void> _attemptExit() async {
    if (_saving) return;
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final decision = await showUnsavedChangesDialog(context);
    if (!mounted) return;
    switch (decision) {
      case UnsavedChangesDecision.discard:
        Navigator.of(context).pop();
      case UnsavedChangesDecision.saveAndExit:
        await _save();
      case UnsavedChangesDecision.cancel:
        return;
    }
  }

  String _repeatDescription(AppLocalizations l10n) {
    final date = _draft.date;
    return switch (_draft.recurrence) {
      AnniversaryRecurrence.solarYearly
          when date.month == 2 && date.day == 29 =>
        l10n.anniversaryRepeatLeapDayDescription,
      AnniversaryRecurrence.solarYearly =>
        l10n.anniversaryRepeatSolarDescription(
          DateFormat.MMMd(l10n.localeName).format(date),
        ),
      AnniversaryRecurrence.lunarYearly =>
        l10n.anniversaryRepeatLunarDescription(LunarYmd.of(date).monthDayName),
      AnniversaryRecurrence.once => l10n.anniversaryRepeatOnceDescription,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final titleMissing = _titleTouched && !_draft.isValid;
    return PopScope(
      // 有未保存修改或正在保存时拦截系统返回，交给 _attemptExit；保存或
      // 删除成功后的 pop 不受限制。
      canPop: !_saving && !_dirty,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) unawaited(_attemptExit());
      },
      child: Scaffold(
        appBar: AppTopBar(
          leading: IconButton(
            tooltip: l10n.commonBack,
            onPressed: () => unawaited(_attemptExit()),
            icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
          ),
          title: Text(
            widget.editing == null
                ? l10n.anniversaryNewTitle
                : l10n.anniversaryEditTitle,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: _saving || !_draft.isValid ? null : _save,
              child: Text(l10n.commonSave),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.s,
            AppSpacing.l,
            AppSpacing.xxxl,
          ),
          children: <Widget>[
            CalendarOptionsFieldLabel(text: l10n.anniversaryFieldName),
            TextField(
              controller: _title,
              focusNode: _titleFocus,
              maxLength: AnniversaryDraft.maxTitleLength,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: l10n.anniversaryNameHint,
                errorText: titleMissing ? l10n.anniversaryNameRequired : null,
              ),
              onChanged: (String value) {
                if (value.trim().isEmpty) _titleTouched = true;
                _update(_draft.copyWith(title: value));
              },
              onSubmitted: (_) => _titleFocus.unfocus(),
            ),
            const SizedBox(height: AppSpacing.s),
            CalendarOptionsFieldLabel(text: l10n.anniversaryFieldDate),
            AnniversaryDateField(
              date: _draft.date,
              showLunar:
                  l10n.isZh ||
                  _draft.recurrence == AnniversaryRecurrence.lunarYearly,
              onChanged: (DateTime date) =>
                  _update(_draft.copyWith(date: date)),
            ),
            const SizedBox(height: AppSpacing.xl),
            CalendarOptionsFieldLabel(text: l10n.anniversaryFieldRepeat),
            ExpressiveButtonGroup<AnniversaryRecurrence>(
              segments: <ButtonSegment<AnniversaryRecurrence>>[
                ButtonSegment<AnniversaryRecurrence>(
                  value: AnniversaryRecurrence.solarYearly,
                  label: Text(l10n.anniversaryRepeatSolar),
                ),
                ButtonSegment<AnniversaryRecurrence>(
                  value: AnniversaryRecurrence.lunarYearly,
                  label: Text(l10n.anniversaryRepeatLunar),
                ),
                ButtonSegment<AnniversaryRecurrence>(
                  value: AnniversaryRecurrence.once,
                  label: Text(l10n.anniversaryRepeatOnce),
                ),
              ],
              selected: <AnniversaryRecurrence>{_draft.recurrence},
              onSelectionChanged: (Set<AnniversaryRecurrence> selection) =>
                  _update(_draft.copyWith(recurrence: selection.single)),
            ),
            const SizedBox(height: AppSpacing.s),
            // 说明长短不一：高度随之过渡，下方字段不在换字的一帧里跳动。
            AnimatedSize(
              duration: ExpressiveMotion.durationNonZero(
                context,
                ExpressiveMotion.fast,
              ),
              curve: ExpressiveMotion.effects,
              alignment: Alignment.topCenter,
              child: CalendarOptionsFadingText(text: _repeatDescription(l10n)),
            ),
            const SizedBox(height: AppSpacing.xl),
            CalendarOptionsFieldLabel(text: l10n.anniversaryFieldNote),
            TextField(
              controller: _note,
              maxLength: AnniversaryDraft.maxNoteLength,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(hintText: l10n.anniversaryNoteHint),
              onChanged: (String value) =>
                  _update(_draft.copyWith(note: value)),
            ),
            CalendarOptionSwitch(
              label: l10n.anniversaryPin,
              description: l10n.anniversaryPinDescription,
              value: _draft.isPinned,
              onChanged: (bool value) =>
                  _update(_draft.copyWith(isPinned: value)),
            ),
            if (widget.editing != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.error,
                  ),
                  onPressed: _saving ? null : _delete,
                  icon: const FaIcon(FontAwesomeIcons.trashCan, size: 15),
                  label: Text(l10n.anniversaryDelete),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
