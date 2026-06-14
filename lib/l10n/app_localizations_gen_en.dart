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
  String get contextFieldInputHint =>
      'Enter weather/address, or tap the right button to auto-fetch';

  @override
  String get contextLocationInputHint =>
      'Enter address, or tap the right button to auto-fetch';

  @override
  String get contextWeatherInputHint =>
      'Enter weather, or tap the right button to auto-fetch';

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
  String get settingsThemeColor => 'Theme';

  @override
  String get settingsFontScale => 'Font size';

  @override
  String get settingsFontScaleSubtitle => 'Adjust app UI font size';

  @override
  String get settingsFontScalePreview =>
      'Preview: A short diary line for sizing.';

  @override
  String get settingsTabSwitchCurve => 'Tab switch curve';

  @override
  String get settingsTabSwitchCurveSubtitle =>
      'Choose the animation feel when switching tabs';

  @override
  String get settingsTabSwitchCurveEaseOutCirc => 'Smooth (Circ)';

  @override
  String get settingsTabSwitchCurveEaseOutCubic => 'Balanced (Cubic)';

  @override
  String get settingsTabSwitchCurveLinear => 'Linear';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSubtitle => 'Switch app language';

  @override
  String get settingsAppearanceLanguage => 'Appearance & Language';

  @override
  String get settingsAppLock => 'App Lock';

  @override
  String get settingsAppLockSubtitle =>
      'Require authentication every time the app enters foreground';

  @override
  String get appLockNotSupported =>
      'This device does not support local authentication, so app lock cannot be enabled.';

  @override
  String get appLockTitle => 'App Locked';

  @override
  String get appLockSubtitle => 'Authenticate to continue';

  @override
  String get appLockUnlockNow => 'Unlock Now';

  @override
  String get appLockUnlocking => 'Unlocking';

  @override
  String get appLockDisableAuthReason => 'Authenticate to disable app lock';

  @override
  String get appLockDisableVerifyFailed =>
      'Authentication failed. App lock remains enabled.';

  @override
  String get settingsEditorTitle => 'Editor';

  @override
  String get settingsEditorSubtitle => 'Fonts, spacing, and toolbar';

  @override
  String get settingsEditorGroup => 'Editor';

  @override
  String get settingsEditorBodyFontSize => 'Editor font size';

  @override
  String get settingsEditorBodyFontSizeSubtitle =>
      'Only affects editor body text';

  @override
  String get settingsEditorBodyFontSizeSmall => 'Small';

  @override
  String get settingsEditorBodyFontSizeMedium => 'Medium';

  @override
  String get settingsEditorBodyFontSizeLarge => 'Large';

  @override
  String get settingsEditorLineHeight => 'Body line height';

  @override
  String get settingsEditorLineHeightSubtitle =>
      'Only affects editor body layout';

  @override
  String get settingsEditorLineHeightCompact => 'Compact';

  @override
  String get settingsEditorLineHeightNormal => 'Normal';

  @override
  String get settingsEditorLineHeightRelaxed => 'Relaxed';

  @override
  String get settingsDataPrivacy => 'Data & Privacy';

  @override
  String get settingsDataPrivacySubtitle =>
      'Manage backups, app lock, and recycle bin';

  @override
  String get settingsDataPrivacyTitle => 'Data & Privacy';

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
  String get aboutPageSlogan =>
      'A quiet corner that belongs only to you in a noisy world.';

  @override
  String get aboutOpenSourceRepo => 'Open-source repository';

  @override
  String get aboutCheckUpdate => 'Check for updates';

  @override
  String get aboutCheckUpdateSubtitle =>
      'Detect release and open APK download automatically';

  @override
  String aboutUpdateAlreadyLatest(String version) {
    return 'You are already on the latest version ($version)';
  }

  @override
  String aboutUpdateOpeningDownload(String version) {
    return 'New version found ($version), opening download link';
  }

  @override
  String get aboutUpdateOpenBrowserFailed =>
      'Unable to open browser automatically, please try again later';

  @override
  String get aboutUpdateCheckFailed =>
      'Failed to check updates, please verify network and retry';

  @override
  String get aboutUpdateNoApkFound =>
      'New version found, but no downloadable APK was resolved';

  @override
  String aboutUpdateDialogTitle(String version) {
    return 'New version found: $version';
  }

  @override
  String get aboutUpdateDialogNoNotes =>
      'No release notes were provided for this version.';

  @override
  String get aboutUpdateDialogConfirmDownload => 'Download update';

  @override
  String get aboutSubmitIssue => 'Submit issue';

  @override
  String get aboutPrivacyAndData => 'Privacy & data security';

  @override
  String get aboutPrivacyDialogTitle => 'Privacy & data security';

  @override
  String get aboutPrivacyDialogMessage =>
      'Your diaries, tags, and media files are stored locally on this device and are not uploaded to cloud services by default.';

  @override
  String get aboutOpenSourceLicenses => 'Third-party open-source licenses';

  @override
  String get aboutOpenLinkFallbackCopied =>
      'Unable to open link directly. The link has been copied.';

  @override
  String get aboutFooterMadeWith => 'Made by 柒月';

  @override
  String get aboutFooterCopyright => '© 2026 Jot Project';

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

  @override
  String get autoT0001 => 'Loading app';

  @override
  String get autoT0002 => 'Copy';

  @override
  String get autoT0003 => 'Reset order';

  @override
  String autoT0004(String p0) {
    return 'Save order failed: $p0';
  }

  @override
  String get autoT0005 => 'Toolbar order';

  @override
  String get autoT0006 => 'Undo';

  @override
  String get autoT0007 => 'Redo';

  @override
  String get autoT0008 => 'Bold';

  @override
  String get autoT0009 => 'Italic';

  @override
  String get autoT0010 => 'Underline';

  @override
  String get autoT0011 => 'Strikethrough';

  @override
  String get autoT0012 => 'Inline code';

  @override
  String get autoT0013 => 'Text color';

  @override
  String get autoT0014 => 'Background color';

  @override
  String get autoT0015 => 'Clear formatting';

  @override
  String get autoT0016 => 'Insert image';

  @override
  String get autoT0017 => 'Header style';

  @override
  String get autoT0018 => 'Ordered list';

  @override
  String get autoT0019 => 'Bullet list';

  @override
  String get autoT0020 => 'Checklist';

  @override
  String get autoT0021 => 'Code block';

  @override
  String get autoT0022 => 'Quote';

  @override
  String get autoT0023 => 'Indent';

  @override
  String get autoT0024 => 'Link';

  @override
  String get autoT0025 => 'Unknown deleted time';

  @override
  String get autoT0026 => 'Some restores failed. Please retry.';

  @override
  String get autoT0027 => 'Some deletions failed. Please retry.';

  @override
  String get autoT0028 => 'Permanent delete';

  @override
  String get autoT0029 => 'Recycle bin';

  @override
  String get autoT0030 => 'Restore';

  @override
  String autoT0031(String p0) {
    return 'Recycle bin load failed: $p0';
  }

  @override
  String get autoT0032 => 'Recycle bin is empty';

  @override
  String get autoT0033 => 'Untitled';

  @override
  String autoT0034(String p0) {
    return 'Create tag failed: $p0';
  }

  @override
  String autoT0035(String p0) {
    return 'Edit tag failed: $p0';
  }

  @override
  String autoT0036(String p0) {
    return 'Delete tag failed: $p0';
  }

  @override
  String autoT0037(String p0) {
    return 'Save tag order failed: $p0';
  }

  @override
  String get autoT0038 => 'Delete tag';

  @override
  String get autoT0039 => 'Tag management';

  @override
  String get autoT0040 => 'Create tag';

  @override
  String get autoT0041 => 'Create your first tag';

  @override
  String autoT0042(String p0) {
    return 'Tag load failed: $p0';
  }

  @override
  String get autoT0043 => 'Toolbar order';

  @override
  String autoT0044(String p0) {
    return 'Current top 4: $p0';
  }

  @override
  String autoT0045(String p0) {
    return 'Settings load failed: $p0';
  }

  @override
  String get autoT0046 => 'System';

  @override
  String get autoT0047 => 'Light';

  @override
  String get autoT0048 => 'Dark';

  @override
  String get autoT0049 => 'What unexpected good thing happened today?';

  @override
  String get autoT0050 => 'If today had a title, what would it be?';

  @override
  String get autoT0051 => 'What moment today is most worth remembering?';

  @override
  String get autoT0052 => 'Media preview';

  @override
  String get autoT0053 => 'No images to browse';

  @override
  String get autoT0054 => 'Media gallery';

  @override
  String get autoT0055 => 'No images to show yet';

  @override
  String get autoT0056 => 'Load failed, tap to retry';

  @override
  String get autoT0057 => 'No more images';

  @override
  String get autoT0058 => 'Explore';

  @override
  String get autoT0059 => 'Explore data is unavailable';

  @override
  String get autoT0060 => 'Mood & energy trends';

  @override
  String get autoT0061 => 'View all images';

  @override
  String get autoT0062 => 'No images to show yet.';

  @override
  String get autoT0063 => 'On this day';

  @override
  String get autoT0064 => 'Write for today';

  @override
  String get autoT0065 => 'Untitled diary';

  @override
  String get autoT0066 => 'Total records';

  @override
  String get autoT0067 => 'Streak';

  @override
  String get autoT0068 => 'This month chars';

  @override
  String get autoT0069 => 'Tag cloud';

  @override
  String get autoT0070 => 'Delete diaries';

  @override
  String get autoT0071 => 'Unarchive failed. Please try again.';

  @override
  String get autoT0072 => 'Archive status restored';

  @override
  String get autoT0073 => 'Delete failed. Please try again.';

  @override
  String autoT0074(String p0) {
    return 'Deleted $p0 diaries';
  }

  @override
  String get autoT0075 => 'Diary deleted';

  @override
  String get autoT0076 => 'Deleted diary restored';

  @override
  String get autoT0077 => 'Restore failed. Please try again.';

  @override
  String get autoT0078 => 'Archive failed. Please try again.';

  @override
  String autoT0079(String p0) {
    return 'Archived $p0 diaries';
  }

  @override
  String get autoT0080 => 'Archived diary restored';

  @override
  String get autoT0081 => 'Unsaved draft found';

  @override
  String get autoT0082 => 'New empty note';

  @override
  String get autoT0083 => 'Continue editing';

  @override
  String autoT0084(String p0) {
    return 'Delete $p0 selected diaries?';
  }

  @override
  String get autoT0085 => 'No street info';

  @override
  String get autoT0086 => 'Title and content cannot both be empty';

  @override
  String autoT0087(String p0) {
    return 'Save failed: $p0';
  }

  @override
  String get autoT0088 => 'No valid cover path found';

  @override
  String autoT0089(String p0) {
    return 'Cover import failed: $p0';
  }

  @override
  String autoT0090(String p0) {
    return 'Tag creation failed: $p0';
  }

  @override
  String autoT0091(String p0) {
    return 'Location failed: $p0';
  }

  @override
  String get autoT0092 => 'Please get current location first';

  @override
  String autoT0093(String p0) {
    return 'Weather fetch failed: $p0';
  }

  @override
  String get autoT0094 => 'Delete diary';

  @override
  String get autoT0095 => 'Untitled diary';

  @override
  String get autoT0096 => 'Select publish date';

  @override
  String get autoT0097 => 'Select publish time';

  @override
  String autoT0098(String p0) {
    return 'Publish failed: $p0';
  }

  @override
  String autoT0099(String p0) {
    return '$p0 selected';
  }

  @override
  String get autoT0100 => 'Archived diaries';

  @override
  String get autoT0101 => 'Unarchive';

  @override
  String autoT0102(String p0) {
    return 'Archived list load failed: $p0';
  }

  @override
  String get autoT0103 => 'No archived diaries';

  @override
  String get autoT0104 => '(No content)';

  @override
  String get autoT0105 => 'None';

  @override
  String get autoT0106 => 'Title';

  @override
  String get autoT0107 => 'Created';

  @override
  String get autoT0108 => 'Updated';

  @override
  String get autoT0109 => 'Tags';

  @override
  String get autoT0110 => 'Content';

  @override
  String get autoT0111 => 'Screenshot failed. Please try again.';

  @override
  String autoT0112(String p0) {
    return 'Image share failed: $p0';
  }

  @override
  String get autoT0113 => 'Delete this diary?';

  @override
  String get autoT0114 => 'Share image';

  @override
  String get autoT0115 => 'Share as text';

  @override
  String get previewExportMarkdown => 'Export as Markdown';

  @override
  String get previewExportPdf => 'Export as PDF';

  @override
  String get previewExportSaveDialogTitle => 'Save export file';

  @override
  String get previewExportSuccess => 'Export succeeded';

  @override
  String get previewExportCanceled => 'Export canceled';

  @override
  String previewExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get autoT0116 => 'Mood';

  @override
  String get autoT0117 => 'Published';

  @override
  String get autoT0118 => 'Last edited';

  @override
  String get autoT0119 => 'No content yet';

  @override
  String get autoT0120 => 'Diary';

  @override
  String autoT0121(String p0) {
    return 'Load failed: $p0';
  }

  @override
  String get autoT0122 => 'Diary no longer exists';

  @override
  String get autoT0123 => 'Diary no longer exists, returning...';

  @override
  String get autoT0124 => 'Diary not found';

  @override
  String get autoT0125 => 'More';

  @override
  String autoT0126(String p0) {
    return 'Tag $p0';
  }

  @override
  String autoT0127(String p0) {
    return 'Diary load failed: $p0';
  }

  @override
  String get autoT0128 => 'Close search';

  @override
  String get autoT0129 => 'Search title or content';

  @override
  String get autoT0130 => 'Clear';

  @override
  String get autoT0131 => 'Unsaved changes';

  @override
  String get autoT0132 => 'Exit';

  @override
  String get editSaveAndExit => 'Save and exit';

  @override
  String get autoT0133 => 'Start writing...';

  @override
  String get autoT0134 => 'New diary';

  @override
  String get autoT0135 => 'Edit diary';

  @override
  String get autoT0136 => 'Publish';

  @override
  String get autoT0137 => 'Save diary';

  @override
  String get autoT0138 => 'Publish diary';

  @override
  String get autoT0139 => 'No content';

  @override
  String get autoT0140 => 'Archive';

  @override
  String get autoT0141 => 'Sort';

  @override
  String get autoT0142 => 'Recently updated';

  @override
  String get autoT0143 => 'Oldest updated';

  @override
  String get autoT0144 => 'Title A-Z';

  @override
  String get autoT0145 => 'Layout';

  @override
  String get autoT0146 => 'List';

  @override
  String get autoT0147 => 'Waterfall';

  @override
  String get autoT0148 => 'Archived diaries';

  @override
  String get autoT0149 => 'Edit tag';

  @override
  String get autoT0150 => 'Tag name';

  @override
  String get autoT0151 => 'Choose color';

  @override
  String get autoT0152 => 'No diaries found';

  @override
  String get autoT0153 => 'Try another keyword.';

  @override
  String get autoT0154 => 'No diaries yet';

  @override
  String get autoT0155 => 'Create diary';

  @override
  String get autoT0156 => 'Cover load failed';

  @override
  String get autoT0157 => 'Create';

  @override
  String get autoT0158 => 'Swipe up to expand';

  @override
  String get autoT0159 => 'Swipe down to collapse';

  @override
  String get autoT0160 => 'Choose tags';

  @override
  String get autoT0161 => 'Tap to choose a cover (optional)';

  @override
  String get autoT0162 => 'Cover';

  @override
  String get autoT0163 => 'Clear cover';

  @override
  String get autoT0164 => 'No tag selected';

  @override
  String autoT0165(String p0) {
    return 'Failed to load tags: $p0';
  }

  @override
  String get autoT0166 => 'No tags yet, create one first';

  @override
  String get autoT0167 => 'Here and now';

  @override
  String get autoT0168 => 'Tap right button to fetch address';

  @override
  String get autoT0169 => 'Get location';

  @override
  String get autoT0170 => 'Tap right button to fetch weather';

  @override
  String get autoT0171 => 'Get weather';

  @override
  String get autoT0172 => 'Publish time';

  @override
  String get autoT0173 => 'Auto use current time';

  @override
  String get autoT0174 => 'Choose publish time';

  @override
  String get autoT0175 => 'Energy';

  @override
  String get autoT0176 => 'Publishing...';

  @override
  String get autoT0177 => 'Select date';

  @override
  String get autoT0178 => 'Month';

  @override
  String get autoT0179 => 'Week';

  @override
  String get autoT0180 => 'Back to today';

  @override
  String get autoT0181 => 'Write for this day';

  @override
  String get autoT0182 => 'This day is quiet, no records yet.';

  @override
  String get autoT0183 => 'Calendar';

  @override
  String get autoT0184 => 'Previous month';

  @override
  String get autoT0185 => 'Next month';

  @override
  String get autoT0186 => 'Recorded an entry';

  @override
  String get autoT0187 => 'Reset toolbar order to defaults?';

  @override
  String get autoT0188 => 'Apply inline code style to selected text';

  @override
  String get autoT0189 => 'Insert or switch to code block';

  @override
  String get autoT0190 => 'Shows both indent increase/decrease buttons';

  @override
  String autoT0191(String p0) {
    return 'Restored $p0 diaries';
  }

  @override
  String autoT0192(String p0) {
    return 'Permanently deleted $p0 diaries';
  }

  @override
  String autoT0193(String p0) {
    return 'Permanently delete $p0 selected diaries? This cannot be undone.';
  }

  @override
  String autoT0194(String p0) {
    return 'Deleted at $p0';
  }

  @override
  String autoT0195(String p0) {
    return 'Delete tag \"$p0\"?';
  }

  @override
  String get autoT0196 =>
      'What person or thing are you most grateful for today?';

  @override
  String get autoT0197 => 'Failed to load images. Please try again later.';

  @override
  String get autoT0198 =>
      'Keep recording weather, tags, and mood to unlock deeper insights here.';

  @override
  String get autoT0199 => 'No tag data yet. Try writing diaries with tags.';

  @override
  String autoT0200(String p0) {
    return 'Delete $p0 selected archived diaries?';
  }

  @override
  String autoT0201(String p0) {
    return 'Unarchived $p0 diaries';
  }

  @override
  String get autoT0202 => 'An unfinished diary was found. Continue editing?';

  @override
  String get autoT0203 => 'metadata must be a valid JSON object';

  @override
  String get autoT0204 =>
      'AMap Web API key missing, please configure amap.web.api.key';

  @override
  String get autoT0205 =>
      'QWeather key missing, please configure qweather.api_key';

  @override
  String get autoT0206 =>
      'This will soft-delete the diary and it can be restored later. Continue?';

  @override
  String get autoT0207 => 'You have unsaved changes. Exit anyway?';

  @override
  String get autoT0208 => 'Header style (tap to cycle)';

  @override
  String get autoT0209 =>
      'An unfinished diary draft was found. Continue editing?';

  @override
  String autoT0210(String p0) {
    return 'Calendar diaries load failed: $p0';
  }

  @override
  String get autoT0211 =>
      'Take it easy, this day\'s highlights haven\'t happened yet.';

  @override
  String get timeCapsuleTitle => 'Time lock';

  @override
  String get timeCapsuleUnset => 'Not sealed';

  @override
  String timeCapsuleSet(String p0) {
    return 'Unlocks $p0';
  }

  @override
  String get timeCapsulePickTitle => 'Choose unlock time';

  @override
  String get timeCapsulePrecisionMinute => 'Exact time';

  @override
  String get timeCapsulePrecisionDate => 'Date only';

  @override
  String get timeCapsuleQuickWeek => 'One week';

  @override
  String get timeCapsuleQuickMonth => 'One month';

  @override
  String get timeCapsuleQuickYear => 'One year';

  @override
  String get timeCapsuleClear => 'Remove time lock';

  @override
  String get timeCapsuleLockedTitle => 'Sleeping moment';

  @override
  String timeCapsuleCountdownDays(String p0) {
    return 'Unlocks in ${p0}d';
  }

  @override
  String timeCapsuleCountdownHours(String p0) {
    return 'Unlocks in ${p0}h';
  }

  @override
  String timeCapsuleLockedHint(String p0) {
    return 'This diary is sealed until $p0. You can change the unlock time or delete it, but the content stays hidden.';
  }

  @override
  String get timeCapsuleUpdateUnlock => 'Change unlock time';

  @override
  String get timeCapsuleSealAction => 'Seal diary';

  @override
  String get timeCapsuleSealing => 'Sealing this moment...';

  @override
  String timeCapsuleSealDone(String p0) {
    return 'Locked until $p0';
  }

  @override
  String timeCapsuleUnlockedInsight(String p0) {
    return 'When you wrote this diary, you felt $p0. How do you feel today?';
  }

  @override
  String get timeCapsuleUnlockedInsightNoMood =>
      'This was sealed for your future self. How do you feel today?';

  @override
  String get dataMgmtWebDav => 'WebDAV Sync';

  @override
  String get dataMgmtWebDavSubtitle =>
      'Back up to NAS / private WebDAV and restore from remote backups';

  @override
  String get webDavTitle => 'WebDAV Sync';

  @override
  String get webDavConfigSection => 'Connection';

  @override
  String get webDavServerUrl => 'Server URL';

  @override
  String get webDavServerUrlHint => 'e.g. https://nas.example.com:5006/webdav/';

  @override
  String get webDavUsername => 'Username';

  @override
  String get webDavPassword => 'Password or Token';

  @override
  String get webDavRemoteDirectory => 'Remote directory';

  @override
  String get webDavRemoteDirectoryHint => 'e.g. /jotsy/';

  @override
  String get webDavSaveConfig => 'Save Config';

  @override
  String get webDavTestConnection => 'Test Connection';

  @override
  String get webDavUploadBackup => 'Upload Current Backup';

  @override
  String get webDavRefreshBackups => 'Refresh List';

  @override
  String get webDavBackupList => 'Remote Backups';

  @override
  String get webDavNoBackups => 'No remote backups yet';

  @override
  String get webDavConfigSaved => 'WebDAV config saved';

  @override
  String get webDavConnectionOk => 'WebDAV connection succeeded';

  @override
  String get webDavUploadSuccess => 'Backup uploaded to WebDAV';

  @override
  String get webDavRestoreSuccess => 'Data restored from WebDAV backup';

  @override
  String get webDavDeleteSuccess => 'Remote backup deleted';

  @override
  String webDavOperationFailed(String error) {
    return 'Operation failed: $error';
  }

  @override
  String get webDavBusySave => 'Saving config...';

  @override
  String get webDavBusyTest => 'Testing connection...';

  @override
  String get webDavBusyUpload => 'Uploading backup...';

  @override
  String get webDavBusyRefresh => 'Reading remote backups...';

  @override
  String get webDavBusyRestore => 'Restoring backup...';

  @override
  String get webDavBusyDelete => 'Deleting remote backup...';

  @override
  String get webDavBusyLabel => 'Processing WebDAV operation';

  @override
  String get webDavHint =>
      'Create a dedicated Jotsy folder on your NAS and prefer an app password or token. Upload creates a full ZIP backup; restore overwrites local data.';

  @override
  String get webDavRestoreConfirmTitle => 'Restore Remote Backup';

  @override
  String get webDavRestoreConfirmContent =>
      'Restore will overwrite local data. Upload or export your current data first. Continue?';

  @override
  String get webDavDeleteConfirmTitle => 'Delete Remote Backup';

  @override
  String webDavDeleteConfirmContent(String fileName) {
    return 'Delete $fileName from the WebDAV server? This cannot be undone.';
  }

  @override
  String get webDavRestoreAction => 'Restore';

  @override
  String get webDavDeleteAction => 'Delete';

  @override
  String webDavBackupSize(String size) {
    return 'Size: $size';
  }

  @override
  String webDavBackupTime(String time) {
    return 'Time: $time';
  }

  @override
  String get webDavPasswordDialogTitle => 'Backup Password';

  @override
  String get webDavPasswordDialogHint =>
      'Leave empty for no encryption; enter the original password for encrypted restore';

  @override
  String get webDavPasswordWarning =>
      'Keep this password safe. Encrypted backups cannot be restored if you forget it.';

  @override
  String get webDavContinueWithoutPassword => 'Continue';

  @override
  String get webDavConfigRequired => 'Fill and save WebDAV config first';
}
