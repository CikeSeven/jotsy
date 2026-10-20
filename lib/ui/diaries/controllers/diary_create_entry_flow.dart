import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../diary_templates/providers/diary_template_providers.dart';
import '../../diary_templates/models/diary_template_selection.dart';
import '../../diary_templates/sections/diary_template_picker_sheet.dart';
import '../../settings/providers/app_features_provider.dart';
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
///
/// [notebookId]（首页停在某本普通日记本里）：新建空白或从模板新建的日记
/// 预先收进这本，[chapterId] 为首页正停在的章节；新建空白时还套用这本的
/// 默认模板（`NotebookPayload.templateId`，优先于按时间段自动套用；用户在
/// 草稿面板里选了“从模板新建”时以用户所选为准）。续写已有草稿时原样打开，
/// 草稿自带它的日记本。
///
/// 功能管理（[appFeaturesProvider]）关闭的功能隐藏入口，数据保留：
/// - 日记模板关闭：草稿面板没有“从模板新建”，新建空白不套用日记本的默认
///   模板（`templateId` 原样留在日记本里，重新开启即恢复）；
/// - 时间胶囊关闭：忽略入口带来的 [capsuleUnlockAt]，不预设胶囊。入口本身
///   （日历“写时间胶囊”）已隐藏，这里兜底，免得经看不到的设置封存日记。
Future<DiaryCreateEntryResult> runDiaryCreateEntryFlow(
  BuildContext context,
  WidgetRef ref, {
  DateTime? day,
  DateTime? capsuleUnlockAt,
  String? notebookId,
  String? chapterId,
}) async {
  const dismissed = (opened: false, createdDiaryId: null);
  final database = ref.read(appDatabaseProvider);
  await ref.read(diaryDraftLegacyMigrationProvider.future);
  // 迁移等过设置服务就绪，此后读到的功能开关才是用户的设置（未就绪时
  // appFeaturesProvider 给全部开启的默认值）。
  final features = ref.read(appFeaturesProvider);
  final presetCapsuleUnlockAt = features.timeCapsules ? capsuleUnlockAt : null;
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
    capsuleUnlockAt: presetCapsuleUnlockAt,
    template: template,
    notebookId: draftId == null ? notebookId : null,
    chapterId: draftId == null ? chapterId : null,
  );

  /// 新建空白：在日记本里时带上这本的默认模板（读不到、或模板功能关闭时
  /// 照常空白）。
  Future<DiaryCreateEntryResult> openBlank() async {
    final template = notebookId == null || !features.templates
        ? null
        : await _notebookDefaultTemplate(database, context.l10n, notebookId);
    if (!context.mounted) return dismissed;
    return openEditor(null, template: template);
  }

  if (recent.isEmpty) return openBlank();

  final pick = await showDiaryDraftPickerSheet(
    context,
    recent: recent.map(DiaryDraftListItem.of).toList(growable: false),
    total: total,
    showFromTemplate: features.templates,
  );
  if (!context.mounted || pick == null) return dismissed;
  switch (pick) {
    case DiaryDraftPickBlank():
      return openBlank();
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

/// 日记本的默认模板：这本不存在、没设模板或模板已被删除时为 null。
Future<DiaryTemplateSelection?> _notebookDefaultTemplate(
  AppDatabase database,
  AppLocalizations l10n,
  String notebookId,
) async {
  try {
    final row = await database.getNotebook(notebookId);
    final templateId = row?.parsedPayload.templateId;
    if (templateId == null) return null;
    final template = await loadDiaryTemplate(database, l10n, templateId);
    return template == null ? null : DiaryTemplateSelection(template);
  } catch (error) {
    debugPrint('Loading notebook template failed: $error');
    return null;
  }
}

Future<DiaryCreateEntryResult> _openEditor(
  BuildContext context, {
  required String? draftId,
  required DateTime? day,
  required DateTime? capsuleUnlockAt,
  DiaryTemplateSelection? template,
  String? notebookId,
  String? chapterId,
}) async {
  final result = await Navigator.of(context).push<Object?>(
    MaterialPageRoute<Object?>(
      builder: (_) => EditDiaryPage(
        entryMode: EditDiaryEntryMode.create,
        createDraftId: draftId,
        createDateOverride: day,
        createCapsuleUnlockAt: capsuleUnlockAt,
        createTemplate: template,
        createNotebookId: notebookId,
        createNotebookChapterId: chapterId,
      ),
    ),
  );
  return (opened: true, createdDiaryId: result is String ? result : null);
}
