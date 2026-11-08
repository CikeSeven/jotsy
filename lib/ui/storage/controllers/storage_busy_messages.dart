import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/services/storage/storage_media_service.dart';

/// 守卫拒绝时给用户的说明（有编辑页开着，或撤销提示还没消失）。
String storageBusyMessage(AppLocalizations l10n, StorageBusyReason reason) =>
    switch (reason) {
      StorageBusyReason.editing => l10n.storageMgmtBusyEditing,
      StorageBusyReason.undoWindow => l10n.storageMgmtBusyUndo,
    };
