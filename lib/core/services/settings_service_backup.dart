part of 'settings_service.dart';

/// 备份导入前保留设置的原始值和通知状态，失败时恢复“未设置”与已有值。
/// 只覆盖备份会写入的键，不触碰连接凭据或其他不在备份中的偏好。
extension SettingsServiceBackup on SettingsService {
  SettingsBackupSnapshot captureBackupSnapshot() {
    const keys = [
      SettingsService._keyThemeMode,
      SettingsService._keyThemeSeedColorValue,
      SettingsService._keyHomeTabSwitchCurve,
      SettingsService._keyEditorBodyFontSizePreset,
      SettingsService._keyEditorBodyLineHeightPreset,
      SettingsService._keyFontScale,
      SettingsService._keyDiarySortMode,
      SettingsService._keyDiaryLayoutMode,
      SettingsService._keyDiaryToolbarOrder,
      SettingsService._keyDiaryToolbarHiddenItems,
      SettingsService._keyDiaryToolbarCurrentTimeFormat,
      SettingsService._keyDiaryCardTagLimit,
      SettingsService._keyTagOrder,
      SettingsService._keyTagFilterMemoryEnabled,
      SettingsService._keyRememberedTagFilterIds,
      SettingsService._keyCreateDiaryDraft,
      SettingsService._keyReleaseMirrorStartIndex,
      SettingsService._keyAppLocaleCode,
      SettingsService._keyAppLockEnabled,
    ];
    return SettingsBackupSnapshot._(
      _prefs,
      {for (final key in keys) key: _prefs.get(key)},
      [
        _notifierRollback(themeModeNotifier),
        _notifierRollback(themeSeedColorNotifier),
        _notifierRollback(homeTabSwitchCurveNotifier),
        _notifierRollback(editorBodyFontSizePresetNotifier),
        _notifierRollback(editorBodyLineHeightPresetNotifier),
        _notifierRollback(fontScaleNotifier),
        _notifierRollback(localeNotifier),
        _notifierRollback(appLockEnabledNotifier),
        _notifierRollback(tagFilterMemoryEnabledNotifier),
        _notifierRollback(diaryCardTagLimitNotifier),
        _notifierRollback(diaryToolbarOrderRawNotifier),
        _notifierRollback(diaryToolbarHiddenItemsRawNotifier),
        _notifierRollback(diaryToolbarCurrentTimeFormatRawNotifier),
      ],
    );
  }
}

class SettingsBackupSnapshot {
  SettingsBackupSnapshot._(this._prefs, this._values, this._restoreNotifiers);

  final SharedPreferences _prefs;
  final Map<String, Object?> _values;
  final List<VoidCallback> _restoreNotifiers;

  Future<void> restore() async {
    Object? firstError;
    StackTrace? firstStack;
    for (final entry in _values.entries) {
      if (_prefs.get(entry.key) == entry.value) continue;
      try {
        final result = switch (entry.value) {
          null => _prefs.remove(entry.key),
          bool value => _prefs.setBool(entry.key, value),
          int value => _prefs.setInt(entry.key, value),
          double value => _prefs.setDouble(entry.key, value),
          String value => _prefs.setString(entry.key, value),
          List<String> value => _prefs.setStringList(entry.key, value),
          _ => throw StateError('Unsupported preference value'),
        };
        await _writePreference(result);
      } catch (error, stack) {
        // 一个偏好写入失败不应阻止其他键及内存状态恢复。
        firstError ??= error;
        firstStack ??= stack;
      }
    }
    for (final restore in _restoreNotifiers) {
      restore();
    }
    if (firstError != null) Error.throwWithStackTrace(firstError, firstStack!);
  }
}

VoidCallback _notifierRollback<T>(ValueNotifier<T> notifier) {
  final original = notifier.value;
  return () => notifier.value = original;
}

/// SharedPreferences 也可能以 false 返回失败，不能把这种导入当作成功提交。
Future<void> _writePreference(Future<bool> result) async {
  if (!await result) throw StateError('Failed to persist application settings');
}
