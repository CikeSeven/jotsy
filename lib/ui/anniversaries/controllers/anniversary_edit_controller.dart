import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../widgets/app_modal/app_dialog.dart';
import '../models/anniversary_draft.dart';

/// 编辑页关闭时带回的结果，由打开方决定给什么提示。
sealed class AnniversaryEditResult {
  const AnniversaryEditResult();
}

final class AnniversaryCreated extends AnniversaryEditResult {
  const AnniversaryCreated(this.anniversaryId);

  final String anniversaryId;
}

final class AnniversaryUpdated extends AnniversaryEditResult {
  const AnniversaryUpdated();
}

/// 已删除；[row] 是删除前的整行，用于撤销。
final class AnniversaryDeleted extends AnniversaryEditResult {
  const AnniversaryDeleted(this.row);

  final Anniversary row;
}

/// 纪念日的保存与删除。
///
/// 输入：草稿与（编辑时）原纪念日；输出：写库结果。只做数据操作与确认框，
/// 页面导航与提示由调用方处理。
class AnniversaryEditController {
  const AnniversaryEditController(this._database);

  final AppDatabase _database;

  /// 新建或更新；返回带回给打开方的结果。草稿无效时抛 [FormatException]。
  Future<AnniversaryEditResult> save(
    AnniversaryDraft draft, {
    Anniversary? editing,
  }) async {
    if (!draft.isValid) {
      throw const FormatException('纪念日名称不能为空');
    }
    if (editing == null) {
      final id = await _database.createAnniversary(
        title: draft.title,
        baseDate: draft.date,
        recurrence: draft.recurrence,
        lunar: draft.lunarSnapshot,
        linkedDiaryId: draft.linkedDiaryId,
        note: draft.note,
        isPinned: draft.isPinned,
      );
      return AnniversaryCreated(id);
    }
    await _database.updateAnniversary(
      editing.anniversaryId,
      title: draft.title,
      baseDate: draft.date,
      recurrence: draft.recurrence,
      lunar: draft.lunarSnapshot,
      linkedDiaryId: draft.linkedDiaryId,
      note: draft.note,
      isPinned: draft.isPinned,
    );
    return const AnniversaryUpdated();
  }

  /// 删除并返回删除前的整行；已不存在时为 null。
  Future<Anniversary?> delete(Anniversary row) =>
      _database.deleteAnniversary(row.anniversaryId);

  /// 删除确认：左侧灰色取消，右侧 error 色删除。
  static Future<bool> confirmDelete(BuildContext context, String title) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final l10n = dialogContext.l10n;
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(l10n.anniversaryDeleteConfirmTitle),
          content: Text(l10n.anniversaryDeleteConfirmBody(title)),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: colorScheme.error),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.commonDelete),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }
}
