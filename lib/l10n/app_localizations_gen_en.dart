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
  String get settingsDiaryCardTagLimit => 'Diary card tags';

  @override
  String get settingsDiaryCardTagLimitLoading => 'Loading diary card settings';

  @override
  String get settingsDiaryCardTagLimitUnavailable => 'Setting unavailable';

  @override
  String get settingsDiaryCardTagLimitHidden => 'Do not show tags';

  @override
  String settingsDiaryCardTagLimitValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show up to $count tags',
      one: 'Show up to 1 tag',
    );
    return '$_temp0';
  }

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
  String get settingsEditorSubtitle =>
      'Fonts, spacing, toolbar, and mood emojis';

  @override
  String get settingsEditorGroup => 'Editor';

  @override
  String get settingsEditorToolsGroup => 'Toolbar & mood';

  @override
  String get settingsMoodOptionsTitle => 'Mood emojis';

  @override
  String get settingsMoodOptionsSubtitle => 'Customize 10 mood choices';

  @override
  String settingsMoodOptionsSlotLabel(String index) {
    return 'Mood $index';
  }

  @override
  String settingsMoodOptionsSlotHelper(String emoji) {
    return 'Default: $emoji';
  }

  @override
  String settingsMoodOptionsSaveFailed(String error) {
    return 'Save mood emojis failed: $error';
  }

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
  String get settingsDataManagementSubtitle =>
      'Import/export backups and diary files';

  @override
  String get settingsTagManagement => 'Tag Management';

  @override
  String get settingsTagManagementSubtitle =>
      'Deleting a tag only unlinks it from diaries';

  @override
  String get settingsTagMemory => 'Tag memory';

  @override
  String get settingsTagMemorySubtitle =>
      'Remember selected diary tags and restore them next time';

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
  String get aboutQqFeedbackGroup => 'QQ feedback group';

  @override
  String get aboutQqFeedbackGroupSubtitle => '678136434';

  @override
  String get aboutQqFeedbackGroupCopied =>
      'QQ group number copied to clipboard';

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
  String get aboutFooterCopyright => '© 2026 Jot Project';

  @override
  String get dataMgmtTitle => 'Data Management';

  @override
  String get dataMgmtExport => 'Export Data';

  @override
  String get dataMgmtExportSubtitle =>
      'Export a ZIP containing diaries, tags, settings, images, recordings, videos, and attachments';

  @override
  String get dataMgmtImport => 'Import Data';

  @override
  String get dataMgmtImportSubtitle =>
      'Import a full backup or a diary file, merging or overwriting';

  @override
  String get dataMgmtHint =>
      'To export a single diary, use the More menu on its preview page. Merging only adds diaries this device doesn\'t have and never changes existing ones; overwriting permanently replaces data on this device, so export a backup first.';

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
  String get dataMgmtImportAction => 'Import';

  @override
  String get dataMgmtBusyLabel => 'Processing data';

  @override
  String get dataMgmtExportPasswordTitle => 'Set export password (optional)';

  @override
  String get dataMgmtExportPasswordHint => 'Leave empty to skip encryption';

  @override
  String get dataMgmtExportPasswordWarning =>
      'Keep this password safe. Data is encrypted end-to-end on this device and we cannot recover the password. If you forget it, the exported data can never be restored.';

  @override
  String get dataMgmtImportPasswordTitle => 'Import password';

  @override
  String get dataMgmtImportPasswordHint => 'Enter the import password';

  @override
  String colorFamilySwatchLabel(int index, String hex) {
    return 'Palette $index, $hex';
  }

  @override
  String colorSwatchLabel(String hex) {
    return 'Color $hex';
  }

  @override
  String get diaryPinSelected => 'Pin';

  @override
  String get diaryUnpinSelected => 'Unpin';

  @override
  String get tagFilterClearLabel => 'Clear tag filters';

  @override
  String searchRemoveTagCondition(String tagName) {
    return 'Remove tag $tagName';
  }

  @override
  String get passwordShow => 'Show password';

  @override
  String get passwordHide => 'Hide password';

  @override
  String get commonLoading => 'Loading';

  @override
  String exploreOnThisDayYearsAgo(int years) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$years years ago today',
      one: '1 year ago today',
    );
    return '$_temp0';
  }

  @override
  String get dateTimeMinutePattern => 'yyyy-MM-dd HH:mm';

  @override
  String get energyLevelExhausted => 'Exhausted';

  @override
  String get energyLevelTired => 'A bit tired';

  @override
  String get energyLevelSoSo => 'So-so';

  @override
  String get energyLevelGood => 'Pretty good';

  @override
  String get energyLevelFull => 'Fully charged';

  @override
  String get startupPreloadFailedNotice =>
      'Startup preload failed. Entered home anyway.';

  @override
  String startupInitFailed(String error) {
    return 'Initialization failed: $error';
  }

  @override
  String get appLockAuthReason => 'Please authenticate to unlock the app';

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
  String get webDavHint =>
      'Create a dedicated Jotsy folder on your NAS and prefer an app password or token. Upload creates a full ZIP backup; when restoring you can merge into or overwrite local data.';

  @override
  String get imageViewerSaveToGallery => 'Save to gallery';

  @override
  String get imageViewerSaving => 'Saving…';

  @override
  String get imageViewerSaveSuccess => 'Saved to gallery';

  @override
  String imageViewerSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get imageViewerGalleryPermissionDenied =>
      'Gallery permission denied, cannot save';

  @override
  String get imageViewerSharing => 'Preparing to share…';

  @override
  String imageViewerShareFailed(String error) {
    return 'Share failed: $error';
  }

  @override
  String get imageViewerDownloadFailed =>
      'Failed to download image, please check your network and retry';

  @override
  String get diaryToolbarInsertCurrentTime => 'Insert current time';

  @override
  String get diaryToolbarRecording => 'Recording';

  @override
  String get recordingStart => 'Start recording';

  @override
  String get recordingPause => 'Pause recording';

  @override
  String get recordingResume => 'Resume recording';

  @override
  String get recordingFinish => 'Finish recording';

  @override
  String get recordingClose => 'Close recording';

  @override
  String get recordingPaused => 'Paused';

  @override
  String get recordingPermissionDenied => 'Microphone access is not allowed';

  @override
  String get recordingFailed => 'Recording failed. Please try again.';

  @override
  String get recordingSaveFailed =>
      'Recording could not be saved. Please try again.';

  @override
  String get recordingAttachment => 'Recording';

  @override
  String get recordingPlaybackPlay => 'Play recording';

  @override
  String get recordingPlaybackPause => 'Pause playback';

  @override
  String get recordingPlaybackFailed => 'Recording cannot be played';

  @override
  String get recordingRename => 'Rename recording';

  @override
  String get recordingNameHint => 'Enter recording name';

  @override
  String get recordingDefaultTitle => 'Voice note';

  @override
  String get recordingStatusRecording => 'Recording';

  @override
  String get recordingIdleHint => 'Tap the microphone to start';

  @override
  String get diaryToolbarToolSettingsTooltip => 'Configure tool parameters';

  @override
  String get diaryToolbarTimeFormatTitle => 'Configure time format';

  @override
  String get diaryToolbarTimeFormatLabel => 'Time format';

  @override
  String get diaryToolbarTimeFormatHelp =>
      'The default format is M月d日 HH:mm. You can use DateFormat tokens such as yyyy, MM, dd, HH, and mm, for example yyyy-MM-dd HH:mm.';

  @override
  String diaryToolbarTimeFormatPreview(String value) {
    return 'Preview: $value';
  }

  @override
  String get diaryToolbarTimeFormatInvalid =>
      'Invalid time format. Please check the pattern.';

  @override
  String get diaryTagCollapse => 'Collapse tags';

  @override
  String get diaryTagCollapseHint =>
      'Swipe up here or tap to collapse the tags';

  @override
  String get diaryPinnedBadge => 'Pinned';

  @override
  String get diaryEnergyUnrecorded => 'Not recorded';

  @override
  String get diaryEnergySwitchTooltip => 'Toggle energy level recording';

  @override
  String get diaryToolbarInsertVideo => 'Insert video';

  @override
  String get diaryToolbarInsertAttachment => 'Insert attachment';

  @override
  String get diaryMediaImporting => 'Importing files…';

  @override
  String get diaryMediaImportFailed =>
      'Files could not be imported. Please try again.';

  @override
  String get diaryMediaImportUnsupported =>
      'File import is not available on this platform.';

  @override
  String get attachmentOpen => 'Open attachment';

  @override
  String get attachmentOpenHint => 'Tap to open with another app';

  @override
  String get attachmentOpening => 'Opening attachment…';

  @override
  String get attachmentFileMissing =>
      'The attachment is missing or unavailable.';

  @override
  String get imageLoadFailed => 'The image is missing or can\'t be loaded.';

  @override
  String get attachmentNoApp => 'No installed app can open this file.';

  @override
  String get attachmentPermissionDenied =>
      'The attachment could not be accessed.';

  @override
  String get attachmentOpenFailed =>
      'The attachment could not be opened. Please try again.';

  @override
  String get videoLoading => 'Loading video…';

  @override
  String get videoPlay => 'Play video';

  @override
  String get videoPause => 'Pause video';

  @override
  String get videoProgress => 'Video progress';

  @override
  String get videoPlaybackFailed =>
      'Video cannot be played here. Tap to open with another app.';

  @override
  String get videoExport => 'Export video';

  @override
  String get videoExportConfirmTitle => 'Export video';

  @override
  String videoExportConfirmMessage(String name) {
    return 'Save \"$name\" to your gallery?';
  }

  @override
  String get videoExporting => 'Exporting video…';

  @override
  String get videoExportSuccess => 'Video saved to gallery';

  @override
  String get videoExportFileMissing => 'The video file is missing or empty.';

  @override
  String get videoExportPermissionDenied =>
      'Gallery access is not allowed. Video could not be exported.';

  @override
  String get videoExportNotEnoughSpace =>
      'Not enough storage to export this video.';

  @override
  String get videoExportUnsupportedFormat =>
      'This video format cannot be saved to the gallery.';

  @override
  String get videoExportDownloadFailed =>
      'Video download failed. Please try again.';

  @override
  String get videoExportFailed =>
      'Video could not be exported. Please try again.';

  @override
  String get videoFullscreen => 'Fullscreen playback';

  @override
  String get videoExitFullscreen => 'Exit fullscreen';

  @override
  String get locationPrecisionTitle => 'Address detail';

  @override
  String get locationPrecisionCity => 'City';

  @override
  String get locationPrecisionDistrict => 'District / county';

  @override
  String get locationPrecisionTownship => 'Subdistrict / town';

  @override
  String get locationPrecisionStreet => 'Road';

  @override
  String get locationPrecisionAddress => 'House number';

  @override
  String get locationUnsupported =>
      'Automatic location is not supported on this platform.';

  @override
  String get locationPermissionDenied =>
      'Location permission was denied. Allow location access and try again; approximate location is also supported.';

  @override
  String get locationPermissionDeniedForever =>
      'Location permission is blocked. Enable it in system settings, then return and try again.';

  @override
  String get locationServiceDisabled =>
      'Location services are off. Turn them on in system settings, then try again.';

  @override
  String get locationNetworkError =>
      'The address request failed or timed out. Check your connection and try again.';

  @override
  String get locationApiError =>
      'The address service is temporarily unavailable. Please try again later.';

  @override
  String get locationAddressInvalid =>
      'No usable address was returned. Please try again later or enter a place manually.';

  @override
  String get locationUnavailable =>
      'Could not get your location. Try again where the satellite signal is stronger, or enter a place manually.';

  @override
  String get diarySortFieldUpdated => 'Date updated';

  @override
  String get diarySortFieldPublished => 'Date published';

  @override
  String get diarySortFieldTitle => 'Title';

  @override
  String get diarySortDescending => 'Descending';

  @override
  String get diarySortAscending => 'Ascending';

  @override
  String get diarySortHintUpdatedDesc => 'Most recently updated first';

  @override
  String get diarySortHintUpdatedAsc => 'Least recently updated first';

  @override
  String get diarySortHintPublishedDesc => 'Newest first';

  @override
  String get diarySortHintPublishedAsc => 'Oldest first';

  @override
  String get diarySortHintTitleAsc => 'Titles A → Z, untitled last';

  @override
  String get diarySortHintTitleDesc => 'Titles Z → A, untitled last';

  @override
  String get diaryToolbarMoreTools => 'More tools';

  @override
  String get diaryToolbarHideMoreTools => 'Hide more tools';

  @override
  String get diaryToolbarMoreToolsActive => 'Formatting in effect';

  @override
  String get diaryToolbarOverflowDivider => 'Tools below go into More';

  @override
  String get backupBusyInspect => 'Reading file...';

  @override
  String get backupImportOptionsTitle => 'How to import';

  @override
  String get backupImportKindFull => 'Full backup';

  @override
  String get backupImportKindDiary => 'Diary file';

  @override
  String backupImportSummary(int diaries, int tags) {
    String _temp0 = intl.Intl.pluralLogic(
      diaries,
      locale: localeName,
      other: '$diaries diaries',
      one: '1 diary',
    );
    String _temp1 = intl.Intl.pluralLogic(
      tags,
      locale: localeName,
      other: '$tags tags',
      one: '1 tag',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get backupImportIncludesSettings => 'Includes app settings';

  @override
  String backupImportExistingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count of them are already on this device',
      one: '1 of them is already on this device',
    );
    return '$_temp0';
  }

  @override
  String get backupImportModeMerge => 'Merge (recommended)';

  @override
  String get backupImportModeMergeDescription =>
      'Keeps everything on this device. Only diaries it doesn\'t have are added; existing ones stay as they are.';

  @override
  String get backupImportModeOverwriteExisting => 'Overwrite existing diaries';

  @override
  String backupImportModeOverwriteExistingDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Adds new diaries and replaces the $count existing diaries with the versions in the file',
      one:
          'Adds new diaries and replaces the existing diary with the version in the file',
    );
    return '$_temp0';
  }

  @override
  String get backupImportModeReplaceAll => 'Overwrite all data';

  @override
  String get backupImportModeReplaceAllDescription =>
      'Erases all diaries, tags, media and settings on this device and replaces them with the backup';

  @override
  String get backupOverwriteAllTitle => 'Overwrite all data?';

  @override
  String get backupOverwriteExistingTitle => 'Overwrite existing diaries?';

  @override
  String get backupOverwriteIrreversible => 'This can\'t be undone';

  @override
  String get backupOverwriteAllLead =>
      'The following data on this device will be permanently deleted and replaced with the backup:';

  @override
  String backupOverwriteAllDiaries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count diaries',
      one: '1 diary',
    );
    return '$_temp0 (including archived and deleted ones)';
  }

  @override
  String backupOverwriteAllTags(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tags',
      one: '1 tag',
    );
    return '$_temp0';
  }

  @override
  String get backupOverwriteAllMedia =>
      'All images, recordings, videos and attachments';

  @override
  String get backupOverwriteAllSettings =>
      'App settings and the unpublished draft';

  @override
  String backupOverwriteExistingBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'The $count diaries already on this device will be replaced entirely by the versions in the file. Their local edits and tags will be lost for good.',
      one:
          'The diary already on this device will be replaced entirely by the version in the file. Its local edits and tags will be lost for good.',
    );
    return '$_temp0 Other diaries are not affected.';
  }

  @override
  String get backupOverwriteBackupTip =>
      'To keep your current data, cancel and export a backup first.';

  @override
  String get backupOverwriteAcknowledge =>
      'I understand overwritten data can\'t be recovered';

  @override
  String get backupOverwriteConfirm => 'Overwrite';

  @override
  String backupOverwriteConfirmCountdown(int seconds) {
    return 'Overwrite ($seconds)';
  }

  @override
  String backupImportMergeResult(int added) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: 'Import complete: $added diaries added',
      one: 'Import complete: 1 diary added',
      zero: 'Import complete: no new diaries',
    );
    return '$_temp0';
  }

  @override
  String backupImportMergeSkippedResult(int added, int skipped) {
    return 'Import complete: $added added, $skipped skipped (already on this device)';
  }

  @override
  String backupImportOverwriteResult(int added, int replaced) {
    return 'Import complete: $added added, $replaced overwritten';
  }

  @override
  String get previewExportDiaryFile => 'Export as diary file';

  @override
  String get previewExportDiaryFileConfirm => 'Export';

  @override
  String get previewExportDiaryFileSuccess =>
      'Diary file exported. Import it from Data Management.';

  @override
  String get dataMgmtImportJournal => 'Import from other journal apps';

  @override
  String get dataMgmtImportJournalSubtitle =>
      'Day One, Evernote, Google Keep, Obsidian, Xiaomi Notes and 13 more';

  @override
  String get journalImportSourceTitle => 'Import from which app?';

  @override
  String get journalImportSourceHint =>
      'Export your data in that app first, then choose the exported file here.';

  @override
  String get journalImportAppleJournal => 'Apple Journal';

  @override
  String get journalImportDayOneHint => 'Export as JSON (.zip)';

  @override
  String get journalImportJourneyHint => 'Export to ZIP (.zip)';

  @override
  String get journalImportDiariumHint =>
      'JSON export (.json) or backup file (.diary)';

  @override
  String get journalImportDaylioHint =>
      'Backup file (.daylio) or CSV export (.csv)';

  @override
  String get journalImportAppleJournalHint =>
      'On iPhone: Settings › Apps › Journal › Export All Journal Entries (.zip)';

  @override
  String journalImportPickDialogTitle(String app) {
    return 'Choose the $app export';
  }

  @override
  String journalImportUnrecognized(String app) {
    return 'This file isn\'t a recognized $app export';
  }

  @override
  String get journalImportNoEntries =>
      'There are no diaries to import in this file';

  @override
  String get journalImportGroupJournals => 'Journaling apps';

  @override
  String get journalImportGroupNotes => 'Note apps';

  @override
  String get journalImportGroupPhoneNotes => 'Phone & WPS cloud notes';

  @override
  String get journalImportPhoneNotesHint =>
      'Sign in to the official cloud service inside the app to read notes, folders and image attachments directly. The sign-in is used only for this import and cleared afterwards.';

  @override
  String get journalImportDiaroHint => 'Backup file (.zip, unencrypted)';

  @override
  String get journalImportEvernote => 'Evernote';

  @override
  String get journalImportEvernoteHint =>
      'Export notebooks as ENEX (.enex, or several in a .zip)';

  @override
  String get journalImportGoogleKeepHint =>
      'Export Keep with Google Takeout (.zip)';

  @override
  String get journalImportJoplinHint => 'Export as JEX (.jex)';

  @override
  String get journalImportMemosHint =>
      'Settings › Export & Import, v0.31 or later (.zip)';

  @override
  String get journalImportMarkdown => 'Markdown / plain text';

  @override
  String get journalImportMarkdownHint =>
      '.md / .txt files from Obsidian, Bear, Notion and more, or a .zip of them';

  @override
  String get journalImportXiaomiNotes => 'Xiaomi Notes';

  @override
  String get journalImportHuaweiNotepad => 'Huawei Notepad';

  @override
  String get journalImportOppoNotes => 'OPPO Notes';

  @override
  String get journalImportVivoNotes => 'vivo Notes';

  @override
  String get journalImportHonorNotes => 'HONOR Notes';

  @override
  String get journalImportMeizuNotes => 'Meizu Notes';

  @override
  String get journalImportWpsNotes => 'WPS Notes';

  @override
  String journalImportEncrypted(String app) {
    return 'Encrypted $app backups can\'t be imported. Create an unencrypted backup in $app';
  }

  @override
  String cloudLoginTitle(String app) {
    return 'Sign in to $app';
  }

  @override
  String get cloudLoginHint =>
      'Sign in on the official page above and open your notes, then tap Read notes. The sign-in is used only for this import and cleared afterwards.';

  @override
  String get cloudLoginRead => 'Read notes';

  @override
  String get cloudLoginReload => 'Reload page';

  @override
  String get cloudLoginChecking => 'Checking sign-in';

  @override
  String get cloudLoginNotSignedIn =>
      'You\'re not signed in yet. Finish signing in on the page first';

  @override
  String cloudBusyReading(int count) {
    return 'Reading cloud notes ($count)';
  }

  @override
  String cloudBusyProgress(int done, int total) {
    return 'Reading cloud notes ($done/$total)';
  }

  @override
  String get cloudErrorSession =>
      'The sign-in has expired or needs verification. Please sign in again';

  @override
  String get cloudErrorForbidden =>
      'The service denied access (HTTP 403). Check your account or the website';

  @override
  String get cloudErrorRateLimited =>
      'Too many requests. Please try again later';

  @override
  String get cloudErrorServer =>
      'The service is temporarily unavailable. Please try again later';

  @override
  String get cloudErrorRejected =>
      'The service rejected the request. Check your account and try again';

  @override
  String get cloudErrorNetwork =>
      'Network request failed. Check your connection and try again';

  @override
  String cloudErrorProtocol(String app) {
    return '$app returned data in an unknown format. Reading stopped so no note is missed';
  }

  @override
  String cloudErrorUnsupportedAccount(String app) {
    return 'Notes in this $app account are encrypted or can\'t be read yet';
  }

  @override
  String backupImportKindJournal(String app) {
    return '$app export';
  }

  @override
  String backupImportMissingMedia(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count media files are missing from the export and will be skipped',
      one: '1 media file is missing from the export and will be skipped',
    );
    return '$_temp0';
  }

  @override
  String get calendarDisplayOptionsTooltip => 'Calendar display';

  @override
  String get calendarOptionsTitle => 'Calendar display';

  @override
  String get calendarOptionsReset => 'Reset';

  @override
  String get calendarOptionsCellStyle => 'Day cells';

  @override
  String get calendarCellStyleDot => 'Dots';

  @override
  String get calendarCellStyleMood => 'Mood';

  @override
  String get calendarCellStyleHeat => 'Heat';

  @override
  String get calendarCellStylePhoto => 'Photos';

  @override
  String get calendarCellStyleTags => 'Tags';

  @override
  String get calendarCellStyleDotDescription =>
      'One dot for each entry, up to three.';

  @override
  String get calendarCellStyleMoodDescription =>
      'The mood you picked for the day.';

  @override
  String get calendarCellStyleHeatDescription =>
      'The more you wrote, the darker the day.';

  @override
  String get calendarCellStylePhotoDescription =>
      'The cover, or the first photo in the entry, fills the day.';

  @override
  String get calendarCellStyleTagsDescription =>
      'Colors of up to three tags used that day.';

  @override
  String get calendarMoodAverage => 'Average';

  @override
  String get calendarMoodEach => 'Each entry';

  @override
  String get calendarHeatBasisEntries => 'By entries';

  @override
  String get calendarHeatBasisWords => 'By length';

  @override
  String get calendarOptionsBadges => 'Badges';

  @override
  String get calendarBadgeCount => 'Entry count';

  @override
  String get calendarBadgeCapsule => 'Sealed time capsules';

  @override
  String get calendarBadgeWeather => 'Weather';

  @override
  String get calendarOptionsLayout => 'Layout';

  @override
  String get calendarOptionsWeekStart => 'Week starts on';

  @override
  String get calendarWeekStartLocale => 'Language default';

  @override
  String get calendarWeekStartMonday => 'Monday';

  @override
  String get calendarWeekStartSunday => 'Sunday';

  @override
  String get calendarOptionsDefaultFormat => 'Open in';

  @override
  String get calendarFormatMonth => 'Month';

  @override
  String get calendarFormatWeek => 'Week';

  @override
  String get calendarFormatRemember => 'Last used';

  @override
  String get calendarHighlightWeekends => 'Highlight weekends';

  @override
  String get calendarShowWeekNumbers => 'Week numbers';

  @override
  String get calendarFixedSixWeeks => 'Always show 6 weeks';

  @override
  String get calendarFixedSixWeeksDescription =>
      'Keeps the calendar height steady between months.';

  @override
  String get calendarOptionsSections => 'Sections';

  @override
  String get calendarShowMonthSummary => 'Monthly summary';

  @override
  String get calendarShowMonthSummaryDescription =>
      'Entries, days written, length, top mood and longest streak for the month.';

  @override
  String calendarSummaryEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
    );
    return '$_temp0';
  }

  @override
  String calendarSummaryDays(int recorded, int elapsed) {
    return 'Wrote on $recorded of $elapsed days';
  }

  @override
  String calendarSummaryDaysNoTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Wrote on $count days',
      one: 'Wrote on 1 day',
    );
    return '$_temp0';
  }

  @override
  String calendarSummaryChars(String count) {
    return '$count characters';
  }

  @override
  String calendarSummaryMood(String mood) {
    return 'Most frequent mood: $mood';
  }

  @override
  String calendarSummaryStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Longest streak: $count days',
      one: 'Longest streak: 1 day',
    );
    return '$_temp0';
  }

  @override
  String get calendarSummaryEmpty => 'No entries this month yet';

  @override
  String get calendarSummaryFuture => 'This month hasn\'t started yet';

  @override
  String get calendarRelativeToday => 'Today';

  @override
  String get calendarRelativeYesterday => 'Yesterday';

  @override
  String get calendarRelativeTomorrow => 'Tomorrow';

  @override
  String calendarRelativeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String calendarRelativeDaysLater(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count days',
      one: 'in 1 day',
    );
    return '$_temp0';
  }

  @override
  String calendarDayStats(int entries, String chars) {
    String _temp0 = intl.Intl.pluralLogic(
      entries,
      locale: localeName,
      other: '$entries entries',
      one: '1 entry',
    );
    return '$_temp0 · $chars chars';
  }

  @override
  String get calendarYearViewTooltip => 'Show the whole year';

  @override
  String get calendarYearBasisMood => 'Mood';

  @override
  String get calendarYearBasisEntries => 'Entries';

  @override
  String get calendarYearBasisWords => 'Length';

  @override
  String get calendarYearLegendLess => 'Less';

  @override
  String get calendarYearLegendMore => 'More';

  @override
  String get calendarYearLegendNoMood => 'No mood';

  @override
  String get calendarYearExport => 'Share this year';

  @override
  String get calendarYearExportFailed =>
      'Couldn\'t create the image. Please try again.';

  @override
  String get calendarOnThisDayTitle => 'On this day';

  @override
  String calendarOnThisDayYearsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years ago',
      one: '1 year ago',
    );
    return '$_temp0';
  }

  @override
  String calendarOnThisDayYearsLater(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years later',
      one: '1 year later',
    );
    return '$_temp0';
  }

  @override
  String get calendarDayActionView => 'Show this day';

  @override
  String get calendarDayActionWrite => 'Write for this day';

  @override
  String get calendarDayActionCapsule => 'Write a time capsule';

  @override
  String get calendarDayActionCapsuleDescription =>
      'It can only be opened on this day';

  @override
  String get calendarFutureCapsuleAction => 'Write a capsule for this day';

  @override
  String get calendarOptionsDayContent => 'Entries of the day';

  @override
  String get calendarDayContentTimeline => 'Timeline';

  @override
  String get calendarDayContentCards => 'Cards';

  @override
  String get calendarShowOnThisDay => 'On this day';

  @override
  String get calendarShowOnThisDayDescription =>
      'Entries from the same date in other years.';

  @override
  String get calendarPreviousYear => 'Previous year';

  @override
  String get calendarNextYear => 'Next year';

  @override
  String get calendarOptionsLunar => 'Lunar calendar';

  @override
  String get calendarOptionsLunarDescription =>
      'Shows Chinese lunar dates, solar terms and festivals under each date.';

  @override
  String get calendarLunarLocale => 'Language default';

  @override
  String get calendarLunarAlways => 'Show';

  @override
  String get calendarLunarNever => 'Hide';

  @override
  String calendarLunarDate(String date) {
    return 'Lunar $date';
  }

  @override
  String get calendarSummaryEmptyYear => 'No entries this year yet';

  @override
  String get calendarSummaryFutureYear => 'This year hasn\'t started yet';

  @override
  String get calendarSummaryEmptyRange => 'No entries in this range';

  @override
  String get calendarSummaryFutureRange => 'This range hasn\'t started yet';

  @override
  String get calendarDayActionRange => 'Select a range from here';

  @override
  String get calendarDayActionRangeDescription =>
      'Tap another date to see stats for the days in between';

  @override
  String calendarRangeTitle(String start, String end, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$start – $end · $_temp0';
  }

  @override
  String calendarRangePickEnd(String start) {
    return 'From $start · tap an end date';
  }

  @override
  String get calendarRangeExit => 'Exit range selection';

  @override
  String get calendarFilterTooltip => 'Filter';

  @override
  String get calendarFilterTitle => 'Filter calendar';

  @override
  String get calendarFilterClear => 'Clear filter';

  @override
  String get calendarFilterDescription =>
      'Dates and stats only count matching entries. Any choice within a group matches; when both mood and tags are set, an entry must match both.';

  @override
  String get calendarFilterMoods => 'Mood';

  @override
  String get calendarFilterTags => 'Tags';

  @override
  String get calendarFilterNoTags => 'No tags yet';

  @override
  String get calendarFilterActive => 'Filtered';

  @override
  String get calendarOptionsAlmanac => 'Lunar & holidays';

  @override
  String get calendarOptionsHolidays => 'Public holidays (China)';

  @override
  String calendarOptionsHolidaysDescription(int year) {
    return 'Marks days off and make-up workdays in mainland China beside the date; weekend shading follows them. Data covers up to $year.';
  }

  @override
  String get calendarOptionsHolidaysDescriptionOutdated =>
      'Marks days off and make-up workdays in mainland China beside the date; weekend shading follows them. This version doesn\'t include this year\'s schedule yet.';

  @override
  String get calendarHolidayRestMark => 'Off';

  @override
  String get calendarHolidayWorkMark => 'Work';

  @override
  String get calendarHolidayDayOff => 'Day off';

  @override
  String get calendarHolidayMakeUpWorkday => 'Make-up workday';

  @override
  String backupImportAnniversaryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anniversaries',
      one: '1 anniversary',
    );
    return '$_temp0';
  }

  @override
  String backupImportExistingAnniversaryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anniversaries are already on this device',
      one: '1 anniversary is already on this device',
    );
    return '$_temp0';
  }

  @override
  String backupImportModeOverwriteAnniversariesOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Adds new items and replaces the $count existing anniversaries with the versions in the file',
      one:
          'Adds new items and replaces the existing anniversary with the version in the file',
    );
    return '$_temp0';
  }

  @override
  String backupImportModeOverwriteAnniversariesExtra(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Also replaces $count existing anniversaries',
      one: 'Also replaces 1 existing anniversary',
    );
    return '$_temp0';
  }

  @override
  String backupOverwriteAllAnniversaries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anniversaries',
      one: '1 anniversary',
    );
    return '$_temp0';
  }

  @override
  String backupOverwriteExistingAnniversariesBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'The $count anniversaries already on this device will be replaced by the versions in the file; local edits will be lost for good.',
      one:
          'The anniversary already on this device will be replaced by the version in the file; local edits will be lost for good.',
    );
    return '$_temp0';
  }

  @override
  String backupImportAnniversaryMergeResult(int added) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: 'Anniversaries: $added added',
      one: 'Anniversaries: 1 added',
      zero: 'Anniversaries: none added',
    );
    return '$_temp0';
  }

  @override
  String backupImportAnniversaryMergeSkippedResult(int added, int skipped) {
    return 'Anniversaries: $added added, $skipped skipped (already on this device)';
  }

  @override
  String backupImportAnniversaryOverwriteResult(int added, int replaced) {
    return 'Anniversaries: $added added, $replaced overwritten';
  }

  @override
  String get calendarShowAnniversaries => 'Anniversaries';

  @override
  String get calendarShowAnniversariesDescription =>
      'Marks anniversaries on the dates and shows their cards for the selected day.';

  @override
  String get calendarDayActionAnniversary => 'Add an anniversary';

  @override
  String get calendarDayActionAnniversaryDescription =>
      'Remember this day; the calendar marks it every year';

  @override
  String get calendarDayActionCountdownDescription => 'Count down to this day';

  @override
  String get anniversarySectionTitle => 'Anniversaries';

  @override
  String anniversaryOrdinal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count-year anniversary',
      one: '1-year anniversary',
    );
    return '$_temp0';
  }

  @override
  String anniversaryTodayOrdinal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count-year anniversary today',
      one: '1-year anniversary today',
    );
    return '$_temp0';
  }

  @override
  String anniversaryDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left',
      one: '1 day left',
    );
    return '$_temp0';
  }

  @override
  String anniversaryDaysSince(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days since',
      one: '1 day since',
    );
    return '$_temp0';
  }

  @override
  String get anniversaryBaseDay => 'The day it began';

  @override
  String get anniversaryCountdownLabel => 'Countdown';

  @override
  String get anniversaryIsToday => 'It\'s today';

  @override
  String get anniversaryAdjustedNote =>
      'This year has no such date, so it moves to the nearest day';

  @override
  String get anniversaryNewTitle => 'New anniversary';

  @override
  String get anniversaryEditTitle => 'Edit anniversary';

  @override
  String get anniversaryFieldName => 'Name';

  @override
  String get anniversaryNameHint => 'e.g. Together, Mom\'s birthday, Exam day';

  @override
  String get anniversaryNameRequired => 'Enter a name';

  @override
  String get anniversaryFieldDate => 'Date';

  @override
  String get anniversaryFieldRepeat => 'Repeat';

  @override
  String get anniversaryRepeatSolar => 'Yearly';

  @override
  String get anniversaryRepeatLunar => 'Lunar yearly';

  @override
  String get anniversaryRepeatOnce => 'Once';

  @override
  String anniversaryRepeatSolarDescription(String date) {
    return 'Marked every year on $date';
  }

  @override
  String get anniversaryRepeatLeapDayDescription =>
      'Every year on Feb 29; Feb 28 in common years';

  @override
  String anniversaryRepeatLunarDescription(String date) {
    return 'Every year on lunar $date, converted to that year\'s date';
  }

  @override
  String get anniversaryRepeatOnceDescription =>
      'Just this day: counts down before it and counts up after';

  @override
  String anniversaryLunarYearDate(String year, String date) {
    return 'Lunar $year year, $date';
  }

  @override
  String get anniversaryFieldNote => 'Note';

  @override
  String get anniversaryNoteHint => 'Optional';

  @override
  String get anniversaryPin => 'Pin';

  @override
  String get anniversaryPinDescription =>
      'Keep it at the top of the anniversary list';

  @override
  String get anniversaryDelete => 'Delete anniversary';

  @override
  String get anniversaryDeleteConfirmTitle => 'Delete this anniversary?';

  @override
  String anniversaryDeleteConfirmBody(String title) {
    return '“$title” will be removed from the calendar. Linked diaries are not affected.';
  }

  @override
  String get anniversaryDeleted => 'Anniversary deleted';

  @override
  String get anniversaryCreated => 'Anniversary added';

  @override
  String get anniversarySaveFailed => 'Couldn\'t save. Try again.';

  @override
  String get anniversaryListTitle => 'Anniversaries';

  @override
  String get anniversaryEmpty =>
      'No anniversaries yet. Long-press a day in the calendar, or tap + to add one.';

  @override
  String get anniversaryPinnedBadge => 'Pinned';

  @override
  String anniversaryDaysToGo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'days to go',
      one: 'day to go',
    );
    return '$_temp0';
  }

  @override
  String anniversaryDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'days ago',
      one: 'day ago',
    );
    return '$_temp0';
  }

  @override
  String get anniversaryDetailNext => 'Next';

  @override
  String get anniversaryDetailStart => 'Started';

  @override
  String get anniversaryMoreActions => 'More actions';

  @override
  String get anniversaryUnpin => 'Unpin';

  @override
  String get anniversaryFieldLink => 'Linked diary';

  @override
  String get anniversaryLinkNone => 'None';

  @override
  String get anniversaryLinkPick => 'Link a diary';

  @override
  String get anniversaryLinkMissing => 'The linked diary was deleted';

  @override
  String get anniversaryUnlink => 'Unlink';

  @override
  String get anniversaryLinkedDiaryTitle => 'Linked diary';

  @override
  String get anniversaryOpenLinkedDiary => 'Open the linked diary';

  @override
  String get anniversaryPickerHint =>
      'Diaries written within 7 days of the date';

  @override
  String get anniversaryPickerEmpty => 'No diaries within a week of this date';

  @override
  String get anniversaryPastDiariesTitle => 'On this day over the years';

  @override
  String get anniversaryBaseDayDiariesTitle => 'Diaries from this day';

  @override
  String get anniversaryPastDiariesEmpty => 'No diaries on these days yet';

  @override
  String get anniversaryView => 'View';

  @override
  String get previewSetAsAnniversary => 'Make it an anniversary';

  @override
  String get diaryTypographyTitle => 'Body font & layout';

  @override
  String diaryTypographySummary(String font, String size, String lineHeight) {
    return '$font · Size $size · Line spacing $lineHeight';
  }

  @override
  String get diaryTypographyQuickTooltip => 'Font & layout';

  @override
  String get diaryTypographyFontSection => 'Font';

  @override
  String get diaryTypographyFontBundled => 'HarmonyOS Sans';

  @override
  String get diaryTypographyFontSystem => 'System font';

  @override
  String get diaryTypographyFontSystemHint =>
      'Follows the font your device uses';

  @override
  String get diaryTypographyFontMissing =>
      'The selected font file is no longer on this device, so HarmonyOS Sans is used for now. Import it again or pick another font.';

  @override
  String get diaryTypographyImportFont => 'Import font file';

  @override
  String get diaryTypographyImportFontHint =>
      'TTF, OTF or TTC; it becomes the body font once imported';

  @override
  String get diaryTypographyImporting => 'Importing font…';

  @override
  String diaryTypographyImported(String name) {
    return 'Imported and applied “$name”';
  }

  @override
  String get diaryTypographyImportUnsupported =>
      'This isn\'t a usable font file. Choose a TTF, OTF or TTC file.';

  @override
  String get diaryTypographyImportUnreadable =>
      'Couldn\'t read the selected file';

  @override
  String get diaryTypographyImportFailed =>
      'Couldn\'t import the font. Check your storage space and try again.';

  @override
  String get diaryTypographyDeleteFont => 'Delete font';

  @override
  String diaryTypographyDeleteFontTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String get diaryTypographyDeleteFontMessage =>
      'The font file will be removed from this device. If it\'s in use, diaries switch back to HarmonyOS Sans.';

  @override
  String get diaryTypographyLayoutSection => 'Layout';

  @override
  String get diaryTypographyFontSize => 'Font size';

  @override
  String get diaryTypographyLineHeight => 'Line spacing';

  @override
  String get diaryTypographyLetterSpacing => 'Letter spacing';

  @override
  String get diaryTypographyParagraphSpacing => 'Paragraph spacing';

  @override
  String diaryTypographyDecrease(String label) {
    return '$label: decrease';
  }

  @override
  String diaryTypographyIncrease(String label) {
    return '$label: increase';
  }

  @override
  String get diaryTypographyReset => 'Reset layout';

  @override
  String get diaryTypographyScopeHint =>
      'Applies when writing, reading and publishing diaries; the font is also used for titles.';

  @override
  String get diaryTypographyMoreSettings => 'More settings';

  @override
  String get diaryTypographySampleTitle => 'An evening after the rain';

  @override
  String get diaryTypographySampleBody =>
      'The rain stopped just before dusk, and the osmanthus downstairs smelled sweeter than ever.\nOn the way home I bought a bag of roasted chestnuts and peeled them as I walked; my hands stayed warm the whole time.\nNothing big happened today, but every moment felt steady, so I wanted to write it down.';

  @override
  String diaryCardDateWithWeekday(String date, String weekday) {
    return '$date · $weekday';
  }

  @override
  String diaryCardDateWithTime(String date, String time) {
    return '$date $time';
  }

  @override
  String diaryCardFooterUpdated(String time) {
    return 'Updated $time';
  }

  @override
  String diaryCardFooterCreated(String time) {
    return 'Written $time';
  }

  @override
  String diaryCardCharCount(String count) {
    return '$count chars';
  }

  @override
  String diaryCardMediaImages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
    );
    return '$_temp0';
  }

  @override
  String get diaryCardMediaAudio => 'Has a recording';

  @override
  String get diaryCardMediaVideo => 'Has a video';

  @override
  String get diaryCardMediaAttachment => 'Has an attachment';

  @override
  String diaryCardLocation(String location) {
    return 'Location: $location';
  }

  @override
  String get diaryCardStyleTitle => 'Diary card style';

  @override
  String diaryCardStyleEntrySubtitle(String name) {
    return 'Current: $name';
  }

  @override
  String get diaryCardStyleCustom => 'Custom';

  @override
  String get diaryCardStyleResetDone => 'Restored the default style';

  @override
  String get diaryCardStylePreviewLight => 'Light preview';

  @override
  String get diaryCardStylePreviewDark => 'Dark preview';

  @override
  String get diaryCardStylePanelHandle => 'Options panel';

  @override
  String get diaryCardStylePanelCollapsed => 'Collapsed';

  @override
  String get diaryCardStylePanelHalf => 'Half open';

  @override
  String get diaryCardStylePanelExpanded => 'Expanded';

  @override
  String get diaryCardStyleSharedGroup => 'All layouts';

  @override
  String get diaryCardStyleListGroup => 'List layout only';

  @override
  String get diaryCardStyleWaterfallGroup => 'Waterfall layout only';

  @override
  String get diaryCardStyleModeFootnote =>
      'Switch between list and waterfall above the preview to adjust the other layout';

  @override
  String get diaryCardStyleTabPresets => 'Presets';

  @override
  String get diaryCardStyleTabLayout => 'Layout';

  @override
  String get diaryCardStyleTabCover => 'Cover';

  @override
  String get diaryCardStyleTabContent => 'Content';

  @override
  String get diaryCardStyleTabDate => 'Date';

  @override
  String get diaryCardStyleTabOrder => 'Order';

  @override
  String get diaryCardStyleTabText => 'Text';

  @override
  String get diaryCardStyleTabColor => 'Color';

  @override
  String get diaryCardStyleTabTexture => 'Finish';

  @override
  String get diaryCardStylePresetsTitle => 'Built-in styles';

  @override
  String get diaryCardStylePresetClassic => 'Classic';

  @override
  String get diaryCardStylePresetClassicDesc =>
      'The default: a square cover on the left and a two-line excerpt';

  @override
  String get diaryCardStylePresetCompact => 'Compact';

  @override
  String get diaryCardStylePresetCompactDesc =>
      'Small covers and one-line excerpts to fit more on screen';

  @override
  String get diaryCardStylePresetMagazine => 'Magazine';

  @override
  String get diaryCardStylePresetMagazineDesc =>
      'Full-width photos, larger titles and airy lines';

  @override
  String get diaryCardStylePresetMinimal => 'Minimal';

  @override
  String get diaryCardStylePresetMinimalDesc =>
      'Just the words: no covers, borders or shadows';

  @override
  String get diaryCardStylePresetGallery => 'Gallery';

  @override
  String get diaryCardStylePresetGalleryDesc =>
      'Photos first, with collages and cover backgrounds';

  @override
  String get diaryCardStylePresetSticky => 'Sticky note';

  @override
  String get diaryCardStylePresetStickyDesc =>
      'Warm paper, a colored top strip and small corners';

  @override
  String get diaryCardStylePresetJournal => 'Journal';

  @override
  String get diaryCardStylePresetJournalDesc =>
      'A side strip, and a date block when there is no cover';

  @override
  String get diaryCardStylePresetMood => 'Mood colors';

  @override
  String get diaryCardStylePresetMoodDesc =>
      'Card colors follow the mood of each entry';

  @override
  String diaryCardStyleApplied(String name) {
    return 'Applied “$name”';
  }

  @override
  String get diaryCardStyleSavedTitle => 'My styles';

  @override
  String get diaryCardStyleSavedEmpty =>
      'Save a style you like to switch back in one tap';

  @override
  String get diaryCardStyleSaveCurrent => 'Save current style';

  @override
  String diaryCardStyleSaveLimit(int count) {
    return 'You can save up to $count styles';
  }

  @override
  String get diaryCardStyleSaveDialogTitle => 'Save style';

  @override
  String get diaryCardStyleRenameDialogTitle => 'Rename style';

  @override
  String get diaryCardStyleNameLabel => 'Style name';

  @override
  String diaryCardStyleDefaultName(int count) {
    return 'My style $count';
  }

  @override
  String get diaryCardStyleRename => 'Rename';

  @override
  String diaryCardStyleSavedDone(String name) {
    return 'Saved “$name”';
  }

  @override
  String diaryCardStyleDeletedDone(String name) {
    return 'Deleted “$name”';
  }

  @override
  String diaryCardStyleSavedActions(String name) {
    return 'More actions for “$name”';
  }

  @override
  String get diaryCardStyleShareTitle => 'Share and import';

  @override
  String get diaryCardStyleCopyCode => 'Copy style code';

  @override
  String get diaryCardStyleCopyCodeSubtitle =>
      'Send it to a friend or keep it as a backup';

  @override
  String get diaryCardStyleImportCode => 'Import from clipboard';

  @override
  String get diaryCardStyleImportCodeSubtitle =>
      'Apply a style code someone shared';

  @override
  String get diaryCardStyleCodeCopied => 'Style code copied';

  @override
  String get diaryCardStyleImportEmpty => 'The clipboard is empty';

  @override
  String get diaryCardStyleImportInvalid =>
      'No valid style code in the clipboard';

  @override
  String get diaryCardStyleImportNewer =>
      'Imported. Some settings from a newer version may not apply';

  @override
  String get diaryCardStyleImported => 'Style imported';

  @override
  String diaryCardStyleImportedNamed(String name) {
    return 'Imported “$name”';
  }

  @override
  String get diaryCardStyleCornerRadius => 'Card corners';

  @override
  String get diaryCardStyleTextAlign => 'Text alignment';

  @override
  String get diaryCardStyleAlignStart => 'Start';

  @override
  String get diaryCardStyleAlignCenter => 'Center';

  @override
  String get diaryCardStylePaddingH => 'Side padding';

  @override
  String get diaryCardStylePaddingV => 'Top and bottom padding';

  @override
  String get diaryCardStyleElementGap => 'Content spacing';

  @override
  String get diaryCardStyleCardGap => 'Card spacing';

  @override
  String get diaryCardStyleSideMargin => 'Screen margin';

  @override
  String get diaryCardStyleColumns => 'Columns';

  @override
  String diaryCardStyleColumnsValue(int count) {
    return '$count columns';
  }

  @override
  String get diaryCardStyleColumnsFootnote =>
      'Fewer columns are used on narrow screens or with large text';

  @override
  String get diaryCardStyleCoverPosition => 'Cover position';

  @override
  String get diaryCardStyleCoverStart => 'Left';

  @override
  String get diaryCardStyleCoverEnd => 'Right';

  @override
  String get diaryCardStyleCoverTop => 'Top';

  @override
  String get diaryCardStyleCoverBackground => 'Background';

  @override
  String get diaryCardStyleCoverHidden => 'Hidden';

  @override
  String get diaryCardStyleCoverSize => 'Cover size';

  @override
  String get diaryCardStyleCoverSizeFootnote =>
      'On narrow screens the cover shrinks to leave room for text';

  @override
  String get diaryCardStyleCoverShape => 'Cover shape';

  @override
  String get diaryCardStyleShapeSquare => 'Square';

  @override
  String get diaryCardStyleShapeLandscape => 'Landscape';

  @override
  String get diaryCardStyleShapePortrait => 'Portrait';

  @override
  String get diaryCardStyleShapeCircle => 'Circle';

  @override
  String get diaryCardStyleCoverRadius => 'Cover corners';

  @override
  String get diaryCardStyleCoverHeight => 'Cover height';

  @override
  String get diaryCardStyleCoverInset => 'Inset cover';

  @override
  String get diaryCardStyleCoverInsetSubtitle =>
      'Keep a margin and rounded corners instead of running edge to edge';

  @override
  String get diaryCardStyleCoverDivider => 'Divider below the cover';

  @override
  String get diaryCardStyleCoverGap => 'Gap between cover and text';

  @override
  String get diaryCardStyleScrim => 'Text panel strength';

  @override
  String get diaryCardStyleCollage => 'Photo collage';

  @override
  String get diaryCardStyleCollageSubtitle =>
      'Top covers combine up to three photos from the entry';

  @override
  String get diaryCardStyleCoverFallback => 'Without a cover';

  @override
  String get diaryCardStyleFallbackNone => 'Nothing';

  @override
  String get diaryCardStyleFallbackDate => 'Date block';

  @override
  String get diaryCardStyleFallbackMood => 'Mood tile';

  @override
  String get diaryCardStyleShowTitle => 'Show title';

  @override
  String get diaryCardStyleShowUntitled =>
      'Show “Untitled” when there is no title';

  @override
  String get diaryCardStyleShowUntitledSubtitle =>
      'When off, the title line is left out';

  @override
  String get diaryCardStyleShowPreview => 'Show excerpt';

  @override
  String get diaryCardStyleTitleLines => 'Title lines';

  @override
  String get diaryCardStylePreviewLines => 'Excerpt lines';

  @override
  String diaryCardStyleLinesValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines',
      one: '1 line',
    );
    return '$_temp0';
  }

  @override
  String get diaryCardStyleTagStyle => 'Tag style';

  @override
  String get diaryCardStyleTagChip => 'Chips';

  @override
  String get diaryCardStyleTagPlain => 'Text';

  @override
  String get diaryCardStyleTagDot => 'Dots';

  @override
  String get diaryCardStylePinnedBadge => 'Pinned badge';

  @override
  String get diaryCardStylePinnedStandard => 'Icon and label';

  @override
  String get diaryCardStylePinnedIcon => 'Icon only';

  @override
  String get diaryCardStylePinnedHidden => 'Hidden';

  @override
  String get diaryCardStylePinnedTint => 'Tint pinned cards';

  @override
  String get diaryCardStylePinnedTintSubtitle =>
      'A light theme-colored fill and border';

  @override
  String get diaryCardStyleShowMood => 'Show mood';

  @override
  String get diaryCardStyleShowWeather => 'Show weather';

  @override
  String get diaryCardStyleIndicatorStyle => 'Mood and weather';

  @override
  String get diaryCardStyleIndicatorStamp => 'Stamp';

  @override
  String get diaryCardStyleIndicatorPlain => 'Icons only';

  @override
  String get diaryCardStyleMetaPosition => 'Mood and weather position';

  @override
  String get diaryCardStyleMetaEyebrow => 'Date line';

  @override
  String get diaryCardStyleMetaFooter => 'Footer';

  @override
  String get diaryCardStyleMetaCover => 'On cover';

  @override
  String get diaryCardStyleExtras => 'Footer details';

  @override
  String get diaryCardStyleShowLocation => 'Location';

  @override
  String get diaryCardStyleShowEnergy => 'Energy';

  @override
  String get diaryCardStyleShowWordCount => 'Character count';

  @override
  String get diaryCardStyleShowMedia => 'Photo and attachment badges';

  @override
  String get diaryCardStyleShowDate => 'Show date';

  @override
  String get diaryCardStyleDateFormat => 'Date format';

  @override
  String get diaryCardStyleDateEyebrow => 'Month and day';

  @override
  String get diaryCardStyleDateFull => 'Full date';

  @override
  String get diaryCardStyleDateNumeric => 'Numeric';

  @override
  String get diaryCardStyleDateRelative => 'Relative';

  @override
  String get diaryCardStyleShowWeekday => 'Show weekday';

  @override
  String get diaryCardStyleShowTime => 'Show time';

  @override
  String get diaryCardStyleRelativeNote =>
      'Relative dates don\'t include the weekday or time';

  @override
  String get diaryCardStyleDateSource => 'Date shown';

  @override
  String get diaryCardStyleDateCreated => 'When written';

  @override
  String get diaryCardStyleDateUpdated => 'Last edited';

  @override
  String get diaryCardStyleFooterTime => 'Footer time';

  @override
  String get diaryCardStyleFooterRelative => 'Updated … ago';

  @override
  String get diaryCardStyleFooterUpdated => 'Update time';

  @override
  String get diaryCardStyleFooterCreated => 'Written time';

  @override
  String get diaryCardStyleFooterHidden => 'Hidden';

  @override
  String get diaryCardStyleOrderHint =>
      'Drag the handles to change the order of a card\'s parts';

  @override
  String get diaryCardStyleBlockEyebrow => 'Date line';

  @override
  String get diaryCardStyleBlockTitle => 'Title';

  @override
  String get diaryCardStyleBlockTags => 'Tags';

  @override
  String get diaryCardStyleBlockPreview => 'Excerpt';

  @override
  String get diaryCardStyleBlockFooter => 'Footer';

  @override
  String get diaryCardStyleOrderReset => 'Restore default order';

  @override
  String diaryCardStyleDragHandle(String name) {
    return 'Drag to move “$name”';
  }

  @override
  String get diaryCardStyleTitleSize => 'Title size';

  @override
  String get diaryCardStyleTitleWeight => 'Title weight';

  @override
  String get diaryCardStyleWeightRegular => 'Regular';

  @override
  String get diaryCardStyleWeightMedium => 'Medium';

  @override
  String get diaryCardStyleWeightBold => 'Bold';

  @override
  String get diaryCardStylePreviewSize => 'Excerpt size';

  @override
  String get diaryCardStyleLineHeight => 'Excerpt line spacing';

  @override
  String get diaryCardStyleLineCompact => 'Compact';

  @override
  String get diaryCardStyleLineStandard => 'Standard';

  @override
  String get diaryCardStyleLineRelaxed => 'Relaxed';

  @override
  String get diaryCardStyleMetaSize => 'Detail text size';

  @override
  String get diaryCardStyleTitleColor => 'Title color';

  @override
  String get diaryCardStyleBodyColor => 'Text color';

  @override
  String get diaryCardStyleEnsureContrast => 'Keep text readable';

  @override
  String get diaryCardStyleEnsureContrastSubtitle =>
      'When a text color blends into the card, use a clearer one';

  @override
  String get diaryCardStyleBackground => 'Card color';

  @override
  String get diaryCardStyleOpacity => 'Card opacity';

  @override
  String get diaryCardStyleGradient => 'Gradient';

  @override
  String get diaryCardStyleGradientSubtitle =>
      'Blend from the card color into a second color';

  @override
  String get diaryCardStyleGradientEnd => 'Second gradient color';

  @override
  String get diaryCardStyleGradientDirection => 'Gradient direction';

  @override
  String get diaryCardStyleDirectionVertical => 'Vertical';

  @override
  String get diaryCardStyleDirectionHorizontal => 'Horizontal';

  @override
  String get diaryCardStyleDirectionDiagonal => 'Diagonal';

  @override
  String get diaryCardStyleBorderWidth => 'Border width';

  @override
  String get diaryCardStyleBorderColor => 'Border color';

  @override
  String get diaryCardStyleAccentBar => 'Accent strip';

  @override
  String get diaryCardStyleAccentNone => 'None';

  @override
  String get diaryCardStyleAccentStart => 'Side';

  @override
  String get diaryCardStyleAccentTop => 'Top';

  @override
  String get diaryCardStyleAccentWidth => 'Strip width';

  @override
  String get diaryCardStyleAccentColor => 'Strip color';

  @override
  String get diaryCardStyleShadow => 'Shadow';

  @override
  String get diaryCardStyleShadowThemed => 'Default';

  @override
  String get diaryCardStyleShadowNone => 'None';

  @override
  String get diaryCardStyleShadowSoft => 'Soft';

  @override
  String get diaryCardStyleShadowFloating => 'Floating';

  @override
  String get diaryCardStyleShadowCustom => 'Custom';

  @override
  String get diaryCardStyleShadowElevation => 'Shadow depth';

  @override
  String get diaryCardStyleShadowColor => 'Shadow color';

  @override
  String get diaryCardStyleSourceTheme => 'Default';

  @override
  String get diaryCardStyleSourcePrimary => 'Primary';

  @override
  String get diaryCardStyleSourceSecondary => 'Secondary';

  @override
  String get diaryCardStyleSourceTertiary => 'Tertiary';

  @override
  String get diaryCardStyleSourceMood => 'Mood';

  @override
  String get diaryCardStyleSourceTag => 'First tag';

  @override
  String get diaryCardStyleSourceCustom => 'Custom';

  @override
  String get diaryCardStyleSourceMoodHint =>
      'Uses each entry\'s mood, or the default color when there is none';

  @override
  String get diaryCardStyleSourceTagHint =>
      'Uses the color of each entry\'s first tag';

  @override
  String get diaryCardStyleStrength => 'Intensity';

  @override
  String get diaryCardStyleEditColor => 'Edit color';

  @override
  String get diaryCardStyleColorDarkAuto => 'Pick the dark color automatically';

  @override
  String get diaryCardStyleColorDarkAutoSubtitle =>
      'Derive a readable dark-mode color from the light one';

  @override
  String get diaryCardStyleHexLabel => 'Hex color';

  @override
  String get diaryCardStyleHexInvalid =>
      'Enter a 6-digit hex color, such as FFB300';

  @override
  String get diaryCardStyleSheetSection => 'Card style';

  @override
  String get diaryCardStyleSheetEntry => 'Customize card style';

  @override
  String get diaryCardStyleSheetEntrySubtitle =>
      'Covers, text, colors and layout';

  @override
  String get diaryCardStyleSampleTitle1 => 'Sunset by the sea';

  @override
  String get diaryCardStyleSampleBody1 =>
      'Walked along the shore until dusk. The waves kept rolling in while the sky slid from orange to lilac.';

  @override
  String get diaryCardStyleSampleTitle2 => 'Weekend hike';

  @override
  String get diaryCardStyleSampleBody2 =>
      'It was windy at the top. I took lots of photos and recorded the wind. My legs were shaking on the way down.';

  @override
  String get diaryCardStyleSampleTitle3 =>
      'A rainy workday spent reworking this week’s plan at the cafe';

  @override
  String get diaryCardStyleSampleBody3 =>
      'Reworked this week\'s to-dos and jotted down a few ideas. Early night tonight.';

  @override
  String get diaryCardStyleSampleBody4 =>
      'Saw a ginger cat napping in the sun on the steps on my way home. Just watching it made me relax.';

  @override
  String get diaryCardStyleSampleCapsuleTitle => 'A letter to myself next year';

  @override
  String get diaryCardStyleSampleTag1 => 'Travel';

  @override
  String get diaryCardStyleSampleTag2 => 'Life';

  @override
  String get diaryCardStyleSampleTag3 => 'Reading';

  @override
  String get diaryCardStyleSampleLocation => 'Seaside boardwalk';

  @override
  String diaryCardStyleValueDp(String value) {
    return '${value}dp';
  }

  @override
  String diaryCardStyleValuePercent(String value) {
    return '$value%';
  }

  @override
  String get dataMgmtCloudBackup => 'Cloud backup';

  @override
  String get dataMgmtCloudBackupSubtitle =>
      'Back up to cloud drives, WebDAV or object storage and restore from them';

  @override
  String get cloudBackupTitle => 'Cloud backup';

  @override
  String get cloudBackupEmpty =>
      'No backup locations yet. Add a cloud drive, WebDAV server or object storage to upload full backups and restore them on a new device.';

  @override
  String get cloudBackupAdd => 'Add backup location';

  @override
  String get cloudBackupHint =>
      'Addresses, passwords and drive authorizations stay on this device and are never written into backups. Uploads are full backup ZIPs, optionally encrypted.';

  @override
  String get cloudBackupSheetTitle => 'Choose a backup location';

  @override
  String get cloudBackupSheetHint =>
      'Before restoring, the backup is checked and you choose whether to merge with or overwrite local data.';

  @override
  String get cloudBackupGroupDrives => 'Cloud drives (sign in)';

  @override
  String get cloudBackupGroupDrivesHint =>
      'Authorize on the drive\'s official page; the app can only access its own backup folder.';

  @override
  String get cloudBackupGroupWebDav => 'WebDAV';

  @override
  String get cloudBackupGroupWebDavHint =>
      'Nutstore, NAS, Nextcloud, and any drive mounted through Alist / OpenList.';

  @override
  String get cloudBackupGroupS3 => 'Object storage (S3-compatible)';

  @override
  String get cloudBackupGroupS3Hint =>
      'Enter access keys; backups are stored in the bucket you choose.';

  @override
  String get cloudBackupCustomWebDav => 'Other WebDAV';

  @override
  String get cloudBackupCustomS3 => 'Other S3-compatible';

  @override
  String get cloudBackupBaiduPan => 'Baidu Netdisk';

  @override
  String get cloudBackupAliyunDrive => 'Alipan (Aliyun Drive)';

  @override
  String get cloudBackupJianguoyun => 'Nutstore (Jianguoyun)';

  @override
  String get cloudBackup123pan => '123pan';

  @override
  String get cloudBackupSynology => 'Synology NAS';

  @override
  String get cloudBackupQnap => 'QNAP NAS';

  @override
  String get cloudBackupAliyunOss => 'Alibaba Cloud OSS';

  @override
  String get cloudBackupTencentCos => 'Tencent Cloud COS';

  @override
  String get cloudBackupQiniuKodo => 'Qiniu Kodo';

  @override
  String get cloudBackupHuaweiObs => 'Huawei Cloud OBS';

  @override
  String get cloudBackupVolcengineTos => 'Volcengine TOS';

  @override
  String get cloudBackupBaiduBos => 'Baidu AI Cloud BOS';

  @override
  String get cloudBackupJdcloudOss => 'JD Cloud OSS';

  @override
  String get cloudBackupAwsChina => 'Amazon S3 (China)';

  @override
  String get cloudBackupHintJianguoyun =>
      'Use your Nutstore account as the username and an app password from Account Info → Security → Third-party apps. Free accounts allow 600 requests per 30 minutes.';

  @override
  String get cloudBackupHint123pan =>
      'Copy the address and password shown under Tools → Third-party mount in 123pan (the password is shown only once).';

  @override
  String get cloudBackupHintOpenList =>
      'Enter the Alist / OpenList address (default port 5244, path /dav/) and grant the user WebDAV read and manage permissions. Any drive mounted there can hold backups.';

  @override
  String get cloudBackupHintCloudDrive2 =>
      'Enter the CloudDrive2 address (default port 19798, path /dav) and your CloudDrive2 account.';

  @override
  String get cloudBackupHintNextcloud =>
      'Copy the address from Files settings → WebDAV in the web app; prefer an app password from Personal settings → Security.';

  @override
  String get cloudBackupHintOwncloud =>
      'Prefer an app token as the password; on oCIS the administrator must enable app tokens.';

  @override
  String get cloudBackupHintSeafile =>
      'SeafDAV must be enabled on the server; single sign-on accounts need a separate WebDAV password set on the web.';

  @override
  String get cloudBackupHintSynology =>
      'Install and enable WebDAV Server in DSM (HTTPS port 5006 by default) and sign in with a DSM account; the first level of the remote folder must be a shared folder.';

  @override
  String get cloudBackupHintQnap =>
      'Enable WebDAV in the Control Panel and end the address with the shared folder name.';

  @override
  String get cloudBackupHintKoofr =>
      'You must use an app password from Koofr Settings → Passwords; repeated failed logins are temporarily blocked.';

  @override
  String get cloudBackupHintPcloud =>
      'Sign in with your pCloud email and password; choose pCloud (EU) for European accounts.';

  @override
  String get cloudBackupHintInfinicloud =>
      'Copy the address and the Apps Connection password from your InfiniCLOUD My Page.';

  @override
  String get cloudBackupHintHetzner =>
      'Enable WebDAV and external access for the Storage Box in Hetzner Console.';

  @override
  String get cloudBackupHintKdrive =>
      'The Drive ID is in the kDrive web address; use an app password if two-factor authentication is on.';

  @override
  String get cloudBackupHintYandex =>
      'Requires a paid Yandex 360 plan and an app password of type WebDAV.';

  @override
  String get cloudBackupHintMailru =>
      'Use an app password created in your Mail.ru account settings.';

  @override
  String get cloudBackupS3Hint =>
      'The endpoint and region must match the bucket\'s location. Use a dedicated bucket and keys that can access only that bucket.';

  @override
  String get cloudBackupHintAliyunOss =>
      'Use a RAM user AccessKey; the endpoint region must match the bucket. Accounts opened after March 2025 may be unable to use the default public endpoint in mainland China.';

  @override
  String get cloudBackupHintTencentCos =>
      'The bucket name must include the APPID suffix (e.g. backup-1250000000); create keys under CAM → API keys.';

  @override
  String get cloudBackupHintQiniuKodo =>
      'The S3 bucket name may differ from the Kodo space name; use the one shown in the console.';

  @override
  String get cloudBackupHintR2 =>
      'Replace ACCOUNT_ID with your Cloudflare account ID, create a token under R2 → Manage API tokens and use its S3 credentials; keep the region as auto.';

  @override
  String get cloudBackupHintB2 =>
      'Use the endpoint shown on the bucket page and its region part (e.g. us-west-004) as the region; use an Application Key.';

  @override
  String get cloudBackupHintDigitalOcean =>
      'Put the Spaces datacenter (e.g. nyc3) in the endpoint and keep the signing region as us-east-1.';

  @override
  String get cloudBackupHintMinio =>
      'Enter the MinIO API address (default port 9000) and keep path-style access on.';

  @override
  String get cloudBackupHintGcs =>
      'Create HMAC keys under Cloud Storage → Settings → Interoperability.';

  @override
  String get cloudBackupHintOracle =>
      'Find NAMESPACE and REGION in the OCI console and use a Customer Secret Key.';

  @override
  String get cloudBackupFolderGoogleDrive =>
      'Backups are stored in the \"Jotsy\" folder of Google Drive; the app can only access files it created. Deleted backups skip the trash.';

  @override
  String get cloudBackupFolderOneDrive =>
      'Backups are stored in this app\'s folder under Apps in OneDrive; the app can only access that folder. Deleted backups go to the OneDrive recycle bin.';

  @override
  String get cloudBackupFolderDropbox =>
      'Backups are stored in this app\'s folder under Apps in Dropbox; the app can only access that folder.';

  @override
  String get cloudBackupFolderBaidu =>
      'Backups are stored in this app\'s folder under My App Data in Baidu Netdisk.';

  @override
  String get cloudBackupFolderAliyun =>
      'Backups are stored in the folder chosen during authorization (or \"Jotsy\" at the root). Deleted backups go to the trash. Re-authorize when Alipan ends the authorization.';

  @override
  String get cloudBackupConfigSection => 'Connection';

  @override
  String get cloudBackupSaveConfig => 'Save';

  @override
  String get cloudBackupTestConnection => 'Test connection';

  @override
  String get cloudBackupUploadBackup => 'Upload backup';

  @override
  String get cloudBackupRefreshBackups => 'Refresh';

  @override
  String get cloudBackupBackupList => 'Remote backups';

  @override
  String get cloudBackupNoBackups => 'No remote backups yet';

  @override
  String cloudBackupBackupTime(String time) {
    return 'Time: $time';
  }

  @override
  String cloudBackupBackupSize(String size) {
    return 'Size: $size';
  }

  @override
  String get cloudBackupRestoreAction => 'Restore';

  @override
  String get cloudBackupDeleteAction => 'Delete';

  @override
  String get cloudBackupDeleteConfirmTitle => 'Delete remote backup?';

  @override
  String cloudBackupDeleteConfirmContent(String fileName) {
    return 'Delete $fileName from this backup location? This cannot be undone.';
  }

  @override
  String get cloudBackupRemoveTarget => 'Remove this location';

  @override
  String get cloudBackupRemoveTargetTitle => 'Remove backup location?';

  @override
  String get cloudBackupRemoveTargetContent =>
      'Only the connection details and authorization saved on this device are removed. Backups already stored there are kept, and you can add the location again later.';

  @override
  String get cloudBackupRemoveTargetAction => 'Remove';

  @override
  String get cloudBackupRemoved => 'Backup location removed';

  @override
  String get cloudBackupConfigSaved => 'Settings saved';

  @override
  String get cloudBackupConnectionOk => 'Connection successful';

  @override
  String get cloudBackupUploadSuccess => 'Backup uploaded';

  @override
  String get cloudBackupRestoreSuccess =>
      'Data restored from the remote backup';

  @override
  String get cloudBackupDeleteSuccess => 'Remote backup deleted';

  @override
  String get cloudBackupAccountAuthorized => 'Authorized';

  @override
  String cloudBackupAccountConnected(String account) {
    return 'Signed in as $account';
  }

  @override
  String get cloudBackupReauthorize => 'Re-authorize';

  @override
  String cloudBackupAuthorized(String name) {
    return 'Connected to $name';
  }

  @override
  String cloudBackupAuthorizeTitle(String name) {
    return 'Authorize $name';
  }

  @override
  String get cloudBackupDeviceCodeHint =>
      'Open the authorization page, sign in and enter the code below. This continues automatically once you approve.';

  @override
  String get cloudBackupDeviceCodeLabel => 'Authorization code';

  @override
  String get cloudBackupCopyCode => 'Copy code';

  @override
  String get cloudBackupDeviceCodeCopied => 'Copied';

  @override
  String get cloudBackupOpenAuthorizePage => 'Open authorization page';

  @override
  String get cloudBackupWaitingAuthorization => 'Waiting for authorization…';

  @override
  String get cloudBackupCodePasteHint =>
      'After you authorize in the browser, the page shows an authorization code. Copy it and paste it here.';

  @override
  String get cloudBackupCodeLabel => 'Authorization code';

  @override
  String get cloudBackupCodeConfirm => 'Finish';

  @override
  String get cloudBackupBusyLabel => 'Cloud backup in progress';

  @override
  String get cloudBackupBusySave => 'Saving…';

  @override
  String get cloudBackupBusyTest => 'Testing connection…';

  @override
  String get cloudBackupBusyUpload => 'Creating backup…';

  @override
  String cloudBackupBusyUploadProgress(int percent) {
    return 'Uploading $percent%';
  }

  @override
  String get cloudBackupBusyDownload => 'Downloading backup…';

  @override
  String cloudBackupBusyDownloadProgress(int percent) {
    return 'Downloading $percent%';
  }

  @override
  String get cloudBackupBusyRestore => 'Restoring data…';

  @override
  String get cloudBackupBusyRefresh => 'Loading remote backups…';

  @override
  String get cloudBackupBusyDelete => 'Deleting remote backup…';

  @override
  String get cloudBackupBusyAuthorize => 'Verifying authorization…';

  @override
  String cloudBackupOperationFailed(String detail) {
    return 'Operation failed: $detail';
  }

  @override
  String get cloudBackupErrorConfig =>
      'Check that the address, bucket and folder settings are complete and correct';

  @override
  String get cloudBackupErrorAppKeyMissing =>
      'This build has no app key for this drive, so it is unavailable';

  @override
  String get cloudBackupErrorAuth =>
      'Authentication failed or access denied; check the account, password or keys';

  @override
  String get cloudBackupErrorSessionExpired =>
      'The authorization has expired; please re-authorize';

  @override
  String get cloudBackupErrorAuthorizationDenied =>
      'Authorization was declined';

  @override
  String get cloudBackupErrorAuthorizationExpired =>
      'The code is invalid or expired; please get a new one';

  @override
  String get cloudBackupErrorNotFound =>
      'The remote file or folder does not exist';

  @override
  String get cloudBackupErrorStorageFull =>
      'The backup location is out of space';

  @override
  String get cloudBackupErrorFileTooLarge =>
      'The backup exceeds the file size limit of this location';

  @override
  String get cloudBackupErrorRateLimited =>
      'Too many requests; please try again later';

  @override
  String get cloudBackupErrorNetwork =>
      'Network request failed; check the network, address and certificate';

  @override
  String get cloudBackupErrorProtocol =>
      'The backup location returned an unexpected response';

  @override
  String get cloudBackupErrorPassword => 'Incorrect backup password';

  @override
  String get cloudBackupErrorArchive =>
      'The backup is damaged or not a Jotsy backup';

  @override
  String get cloudBackupErrorLocalFile =>
      'Failed to read or write a local temporary file; check free storage';

  @override
  String get cloudBackupErrorUnknown =>
      'An unknown error occurred; please try again later';

  @override
  String get s3Endpoint => 'Endpoint';

  @override
  String get s3EndpointHint => 'e.g. https://s3.us-east-1.amazonaws.com';

  @override
  String get s3Region => 'Region';

  @override
  String get s3RegionHint => 'Defaults to us-east-1';

  @override
  String get s3Bucket => 'Bucket';

  @override
  String get s3AccessKeyId => 'Access Key ID';

  @override
  String get s3SecretAccessKey => 'Secret Access Key';

  @override
  String get s3Prefix => 'Backup folder (key prefix)';

  @override
  String get s3PrefixHint => 'e.g. jotsy/; leave empty for the bucket root';

  @override
  String get s3PathStyle => 'Path-style access';

  @override
  String get s3PathStyleSubtitle =>
      'Usually required by self-hosted services such as MinIO';

  @override
  String get s3PathStyleLocked =>
      'This service only supports virtual-hosted-style access';
}
