// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations_gen.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Jotsy';

  @override
  String get navDiaries => 'Diaries';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navExplore => 'Explore';

  @override
  String get navSettings => 'Settings';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonUndo => 'Undo';

  @override
  String get commonBack => 'Back';

  @override
  String get commonSave => 'Save';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonShare => 'Share';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonClose => 'Close';

  @override
  String get commonNew => 'New';

  @override
  String get commonReset => 'Reset';

  @override
  String get commonRetry => 'Retry';

  @override
  String get timeJustNow => 'Just now';

  @override
  String timeMinutesAgo(int minutes) {
    return '$minutes min ago';
  }

  @override
  String timeHoursAgo(int hours) {
    return '$hours hr ago';
  }

  @override
  String timeDaysAgo(int days) {
    return '$days days ago';
  }

  @override
  String updatedAtLabel(String value) {
    return 'Updated $value';
  }

  @override
  String get startupPreloadFailed =>
      'Startup preload failed. Entered home anyway.';

  @override
  String homeInitFailed(String error) {
    return 'Initialization failed: $error';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsThemeMode => 'Theme';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSubtitle => 'Switch app language';

  @override
  String get settingsEditorTitle => 'Editor';

  @override
  String get settingsDataManagement => 'Data Management';

  @override
  String get settingsDataManagementSubtitle => 'Import/export ZIP backups';

  @override
  String get settingsTagManagement => 'Tag Management';

  @override
  String get settingsTagManagementSubtitle =>
      'Deleting a tag only unlinks it from diaries';

  @override
  String get settingsRecycleBin => 'Recycle Bin';

  @override
  String get settingsRecycleBinSubtitle =>
      'Restore or permanently remove deleted diaries';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsAboutSubtitle => 'App info, repo, and version';

  @override
  String get languageDialogTitle => 'Select language';

  @override
  String get languageOptionChinese => '中文';

  @override
  String get languageOptionEnglish => 'English';

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutTagline => 'Capture daily moments and feelings';

  @override
  String get aboutVersion => 'Version';

  @override
  String get aboutPackageName => 'Package';

  @override
  String get aboutRepository => 'Repository';

  @override
  String get aboutCopied => 'Copied to clipboard';

  @override
  String get dataMgmtTitle => 'Data Management';

  @override
  String get dataMgmtExport => 'Export Data';

  @override
  String get dataMgmtExportSubtitle =>
      'Export ZIP with diaries, tags, settings, and local media';

  @override
  String get dataMgmtImport => 'Import Data';

  @override
  String get dataMgmtImportSubtitle =>
      'Restore from ZIP and overwrite current data';

  @override
  String get dataMgmtHint =>
      'It is recommended to export a backup before importing.';

  @override
  String get dataMgmtBusyExport => 'Exporting data...';

  @override
  String get dataMgmtBusyImport => 'Importing data...';

  @override
  String get dataMgmtSaveDialogTitle => 'Save backup';

  @override
  String get dataMgmtPickDialogTitle => 'Choose backup file';

  @override
  String get dataMgmtExportSuccess => 'Data export completed';

  @override
  String get dataMgmtExportCanceled => 'Export canceled';

  @override
  String dataMgmtExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get dataMgmtImportSuccess => 'Data import completed';

  @override
  String get dataMgmtImportCanceled => 'Import canceled';

  @override
  String dataMgmtImportFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get dataMgmtImportConfirmTitle => 'Import Data';

  @override
  String get dataMgmtImportConfirmContent =>
      'Import will overwrite current data. Continue?';

  @override
  String get dataMgmtImportAction => 'Import';

  @override
  String get dataMgmtBusyLabel => 'Processing data';
}
