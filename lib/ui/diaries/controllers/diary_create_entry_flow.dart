import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
import '../../diary_templates/models/diary_template_selection.dart';
import '../../diary_templates/sections/diary_template_picker_sheet.dart';
import '../pages/diary_drafts_page.dart';
import '../pages/edit_diary_page.dart';
import '../sections/diary_draft_picker_sheet.dart';
import '../viewmodels/diary_draft_list_item.dart';

/// 新建入口走完后的结果：[opened] 为是否打开过编辑页或草稿箱（打开者据此
/// 刷新列表；关掉选择面板时为 false），[createdDiaryId] 为在编辑页直接发布
/// 的新日记（首页据此播放新卡片的出现动画）。
typedef DiaryCreateEntryResult = ({bool opened, String? createdDiaryId});

/// 所有“新建日记”入口共用的流程（首页 FAB 与空列表、日历、探索）。
///
/// 1. 等旧版单份草稿迁移完成，读出最近编辑的几份草稿；
/// 2. 没有草稿：直接打开空白编辑页；
/// 3. 有草稿：弹出草稿选择面板——续写某一份、打开草稿箱、从模板新建，或
///    新建空白。新建空白不删除任何草稿：每次新建都是草稿箱里独立的一份。
///    从模板新建时再弹出模板面板，选好的模板交给编辑页直接套用；关掉模板
///    面板等同于什么也不做。没有草稿时模板经编辑页标题下的建议条选用。
///
/// [day] 为新建日记的发表日期（日历入口），[capsuleUnlockAt] 为预设的时间
/// 胶囊解封日。续写草稿时也一并传入：草稿自带日期或胶囊设置时以草稿为准
/// （见 EditDiaryPage）。
Future<DiaryCreateEntryResult> runDiaryCreateEntryFlow(
  BuildContext context,
  WidgetRef ref, {
  DateTime? day,
  DateTime? capsuleUnlockAt,
}) async {
  const dismissed = (opened: false, createdDiaryId: null);
  final database = ref.read(appDatabaseProvider);
  await ref.read(diaryDraftLegacyMigrationProvider.future);
  final recent = await database.getRecentDiaryDrafts(maxRecentDraftsInPicker);
  final total = recent.isEmpty ? 0 : await database.countDiaryDrafts();
  if (!context.mounted) return dismissed;

  Future<DiaryCreateEntryResult> openEditor(
    String? draftId, {
    DiaryTemplateSelection? template,
  }) => _openEditor(
    context,
    draftId: draftId,
    day: day,
    capsuleUnlockAt: capsuleUnlockAt,
    template: template,
  );
  if (recent.isEmpty) return openEditor(null);

  final pick = await showDiaryDraftPickerSheet(
    context,
    recent: recent.map(DiaryDraftListItem.of).toList(growable: false),
    total: total,
  );
  if (!context.mounted || pick == null) return dismissed;
  switch (pick) {
    case DiaryDraftPickBlank():
      return openEditor(null);
    case DiaryDraftPickDraft(:final draftId):
      return openEditor(draftId);
    case DiaryDraftPickTemplate():
      final template = await showDiaryTemplatePickerSheet(
        context,
        diaryDate: day ?? DateTime.now(),
      );
      if (!context.mounted || template == null) return dismissed;
      return openEditor(null, template: template);
    case DiaryDraftPickAll():
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const DiaryDraftsPage()),
      );
      return (opened: true, createdDiaryId: null);
  }
}

Future<DiaryCreateEntryResult> _openEditor(
  BuildContext context, {
  required String? draftId,
  required DateTime? day,
  required DateTime? capsuleUnlockAt,
  DiaryTemplateSelection? template,
}) async {
  final result = await Navigator.of(context).push<Object?>(
    MaterialPageRoute<Object?>(
      builder: (_) => EditDiaryPage(
        entryMode: EditDiaryEntryMode.create,
        createDraftId: draftId,
        createDateOverride: day,
        createCapsuleUnlockAt: capsuleUnlockAt,
        createTemplate: template,
      ),
    ),
  );
  return (opened: true, createdDiaryId: result is String ? result : null);
}
