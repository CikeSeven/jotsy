part of 'sync_apply.dart';

/// 设置的应用（规格 §6 第 5 步）：数据库事务提交之后，只应用本次变化的
/// 分面，失败时按快照回滚。settings 与 prefs 两种记录都走这里。
///
/// - 部分节点由 [syncSettingsRestoreNode] / [syncPrefsRestoreNode] 生成
///   （`tagOrderNames` 按写入后的标签表换回本地 id，背景图引用还原为文件名
///   ——文件在写入前已就位；功能开关与本机此刻的开关合并成整份原文，数据类
///   开关只打开不关闭）；
/// - 经 [BackupSettings.restore] 应用，`clearLegacyDraft: false`：覆盖恢复会
///   顺带清掉没迁移的旧版单份草稿（只有读不出来的旧草稿才会一直留着），
///   同步只是应用设置变化，不能删掉本机用户的数据；
/// - `restore` 对几个键的空值什么也不做（保留本机值），而同步要的是“与对方
///   相同”，这些情形直接调用对应的 setter（见 [_applyEmptyValues]）；否则
///   本机规范值不变，下次同步又判成差异；
/// - 任一步失败：[SettingsBackupSnapshot.restore] 回滚到应用前的值，返回
///   false（这条写入记为 [SyncSkipReason.settingsFailed]，下次同步再来）。
Future<bool> _applySyncSettings(
  SettingsService settings,
  SyncRecord record, {
  required Set<String> facets,
  required Map<String, int> tagIdsByName,
  required String dataRoot,
}) async {
  final node = record.key.entity == SyncEntity.prefs
      ? syncPrefsRestoreNode(
          record,
          facets: facets,
          tagIdsByName: tagIdsByName,
          localAppFeaturesRaw: settings.appFeaturesRaw,
        )
      : syncSettingsRestoreNode(
          record,
          facets: facets,
          dataRoot: dataRoot,
          localAppFeaturesRaw: settings.appFeaturesRaw,
        );
  final snapshot = settings.captureBackupSnapshot();
  try {
    await BackupSettings.restore(settings, node, clearLegacyDraft: false);
    await _applyEmptyValues(settings, node);
    return true;
  } catch (error, stack) {
    debugPrint('LAN sync settings apply failed: $error\n$stack');
    try {
      await snapshot.restore();
    } catch (rollbackError) {
      debugPrint('LAN sync settings rollback failed: $rollbackError');
    }
    return false;
  }
}

/// `BackupSettings.restore` 忽略的空值：
/// - `tagOrderRaw` 为空串（对方没有排过序，或排过的标签都不在了）；
/// - `diarySortModeRaw` / `diaryLayoutModeRaw` 为空串（读取时回落默认值，
///   只有被写成空串时才会出现）；
/// - `diaryToolbarOrderRaw` / `tagPickerSortRaw` / `diaryLocationPrecisionRaw`
///   为 null（对方从没设置过）或空串。
/// `appLocaleCode` 读出来从不为空，不需要处理。
Future<void> _applyEmptyValues(
  SettingsService settings,
  Map<String, Object?> node,
) async {
  for (final entry in node.entries) {
    final value = entry.value;
    final empty = value == null || value == '';
    if (!empty) continue;
    switch (entry.key) {
      case 'tagOrderRaw':
        await settings.setTagOrderRaw('');
      case 'diarySortModeRaw' when value == '':
        await settings.setDiarySortModeRaw('');
      case 'diaryLayoutModeRaw' when value == '':
        await settings.setDiaryLayoutModeRaw('');
      case 'diaryToolbarOrderRaw':
        value == null
            ? await settings.clearDiaryToolbarOrderRaw()
            : await settings.setDiaryToolbarOrderRaw('');
      case 'tagPickerSortRaw':
        value == null
            ? await settings.clearTagPickerSortRaw()
            : await settings.setTagPickerSortRaw('');
      case 'diaryLocationPrecisionRaw':
        value == null
            ? await settings.clearDiaryLocationPrecisionRaw()
            : await settings.setDiaryLocationPrecisionRaw('');
    }
  }
}

/// 设置记录里本次真正变化的分面（与写入前的本机哈希不同的）。规划器只在
/// 有分面不同时才写这条记录；只应用变化的键，避免把没变的键也“重放”一遍
/// （`restore` 对部分键会做归一化，重放没有好处）。
Set<String> _changedSettingsFacets(SyncWrite write) {
  final record = write.record!;
  final expected = write.expected;
  return <String>{
    for (final facet in record.facets.keys)
      if (expected == null || expected[facet] != record.hashes[facet]) facet,
  };
}
