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
  String get commonSelectAll => 'Select all';

  @override
  String get commonDeselectAll => 'Deselect all';

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
  String aboutUpdateSubtitleAvailable(String version) {
    return '$version is available';
  }

  @override
  String aboutUpdateSubtitleDownloading(int percent) {
    return 'Downloading $percent%';
  }

  @override
  String get aboutUpdateSubtitleReady => 'Update downloaded, tap to install';

  @override
  String get appUpdateTitle => 'App updates';

  @override
  String appUpdateCurrentVersion(String version) {
    return 'Current version $version';
  }

  @override
  String get appUpdateChecking => 'Checking for updates…';

  @override
  String get appUpdateCheckingHint =>
      'Trying several routes at once and using the first to answer';

  @override
  String get appUpdateUpToDate => 'You\'re up to date';

  @override
  String appUpdateLastChecked(String time) {
    return 'Last checked: $time';
  }

  @override
  String get appUpdateAvailableBadge => 'New';

  @override
  String appUpdateAvailableTitle(String version) {
    return 'Version $version is available';
  }

  @override
  String appUpdatePublishedOn(String date) {
    return 'Released $date';
  }

  @override
  String get appUpdateReleaseNotesTitle => 'What\'s new';

  @override
  String get appUpdateCurrentNotesTitle => 'In this version';

  @override
  String get appUpdateNoReleaseNotes => 'No release notes for this version.';

  @override
  String get appUpdateViewOnGitHub => 'View on GitHub';

  @override
  String get appUpdateActionCheck => 'Check for updates';

  @override
  String appUpdateActionDownload(String size) {
    return 'Download and install ($size)';
  }

  @override
  String get appUpdateActionDownloadNoSize => 'Download and install';

  @override
  String appUpdateActionResume(int percent) {
    return 'Resume download ($percent% done)';
  }

  @override
  String get appUpdateActionCancel => 'Cancel download';

  @override
  String get appUpdateActionInstall => 'Install';

  @override
  String get appUpdateActionRetry => 'Try again';

  @override
  String get appUpdateActionOpenReleasePage => 'Open download page';

  @override
  String get appUpdateActionSkip => 'Skip this version';

  @override
  String get appUpdateSkippedHint =>
      'Skipped: you won\'t be reminded at startup';

  @override
  String appUpdateDownloadProgress(String received, String total) {
    return '$received / $total';
  }

  @override
  String appUpdateDownloadSpeed(String speed) {
    return '$speed/s';
  }

  @override
  String appUpdateDownloadVia(String route) {
    return 'via $route';
  }

  @override
  String get appUpdateVerifying => 'Verifying the package…';

  @override
  String get appUpdateReadyToInstall => 'Downloaded and verified';

  @override
  String get appUpdateInstallPermissionTitle => 'Allow installing apps';

  @override
  String get appUpdateInstallPermissionMessage =>
      'Android needs you to allow Jotsy to install unknown apps in system settings. Turn it on and come back here; installation continues automatically.';

  @override
  String get appUpdateInstallPermissionAction => 'Open settings';

  @override
  String get appUpdateInstallPermissionSettingsFailed =>
      'Couldn\'t open system settings. Allow Jotsy to install unknown apps in Settings → Apps → Jotsy.';

  @override
  String get appUpdateUnsupportedPlatform =>
      'In-app installation isn\'t supported on this platform. Get the new version from the download page.';

  @override
  String get appUpdateNoCompatibleApk =>
      'This release has no package for this device\'s processor. Pick one manually on the download page.';

  @override
  String get appUpdateFailedCheckTitle => 'Couldn\'t check for updates';

  @override
  String get appUpdateFailedDownloadTitle => 'Download failed';

  @override
  String get appUpdateFailedInstallTitle => 'Couldn\'t install';

  @override
  String get appUpdateFailureNetwork =>
      'Every route failed. Try again later, or choose another route or a custom mirror under Download route below.';

  @override
  String get appUpdateFailureNotFound => 'No published release was found.';

  @override
  String get appUpdateFailureIntegrity =>
      'The download was incomplete or altered (checksum mismatch) and has been deleted. Try again or use another route.';

  @override
  String get appUpdateFailureSignature =>
      'The package is signed differently from this app and can\'t replace it. Only download from the official release page.';

  @override
  String get appUpdateFailureNotNewer =>
      'The downloaded package isn\'t newer than this version.';

  @override
  String get appUpdateFailureStorage =>
      'Couldn\'t save the package. Check your device\'s free storage.';

  @override
  String get appUpdateFailureInstallUnavailable =>
      'Couldn\'t open the system installer. Install manually from the download page.';

  @override
  String get appUpdateSettingsTitle => 'Update settings';

  @override
  String get appUpdateAutoCheck => 'Check automatically';

  @override
  String get appUpdateAutoCheckSubtitle =>
      'When you open or return to the app, at most every 2 hours; only reads public release info';

  @override
  String get appUpdateSource => 'Download route';

  @override
  String get appUpdateSourceAuto => 'Automatic';

  @override
  String get appUpdateSourceAutoDescription =>
      'Tests every route and uses the fastest; recommended in mainland China';

  @override
  String get appUpdateSourceDirect => 'GitHub direct';

  @override
  String get appUpdateSourceDirectDescription =>
      'No mirror; may be slow or unreachable in mainland China';

  @override
  String get appUpdateSourceMirrorDescription => 'Public mirror';

  @override
  String get appUpdateSourceCustom => 'Custom mirror';

  @override
  String get appUpdateSourceCustomDescription =>
      'When the built-in mirrors stop working, enter a GitHub proxy that works for you';

  @override
  String get appUpdateSourceCustomHint => 'e.g. https://mirror.example.com/';

  @override
  String get appUpdateSourceCustomInvalid =>
      'Enter an address starting with https://';

  @override
  String get appUpdateSourceSheetHint =>
      'Mirrors are third-party public services. Every package is checked against its SHA-256 and the app signature after download, so a mirror cannot swap in another app.';

  @override
  String get appUpdatePromptUpdate => 'Update now';

  @override
  String get appUpdatePromptLater => 'Later';

  @override
  String get appUpdateActionDesktopDownload => 'Download';

  @override
  String get appUpdateDesktopHintWindows =>
      'Downloads the installer in your browser. Run it to update in place; your diaries are kept.';

  @override
  String get appUpdateDesktopHintLinux =>
      'Downloads a .tar.gz archive in your browser. Extract it and run install.sh to update; your diaries are kept.';

  @override
  String get appUpdateNoDesktopPackage =>
      'This release has no package for this system. Check the download page.';

  @override
  String get appUpdateSourceAutoDescriptionDesktop =>
      'Uses the route that answered the update check first; recommended in mainland China';

  @override
  String get appUpdateSourceSheetHintDesktop =>
      'Mirrors are third-party public services. After downloading, you can verify the file against SHA256SUMS.txt on the release page.';

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
  String get autoT0068 => 'Words this month';

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
  String get autoT0092 => 'Please get current location first';

  @override
  String get autoT0094 => 'Delete diary';

  @override
  String get autoT0095 => 'Untitled diary';

  @override
  String get autoT0096 => 'Select publish date';

  @override
  String get autoT0097 => 'Select publish time';

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
  String get previewExportSaveDialogTitle => 'Save export file';

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
  String get autoT0189 =>
      'Turn into a code block; inside one, tap to pick a language, copy or exit.';

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
  String recycleBinEntryFooter(String date, String deletedAt) {
    return '$date · $deletedAt';
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
  String get desktopSaveAs => 'Save as…';

  @override
  String get desktopSaveImageDialogTitle => 'Save image';

  @override
  String get desktopSaveVideoDialogTitle => 'Save video';

  @override
  String desktopSavedTo(String path) {
    return 'Saved to $path';
  }

  @override
  String get diaryShareSaveImages => 'Save images…';

  @override
  String get diaryShareSaveImagesDialogTitle =>
      'Choose a folder for the images';

  @override
  String diaryShareImagesSaved(int count, String path) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Saved $count images to $path',
      one: 'Saved 1 image to $path',
    );
    return '$_temp0';
  }

  @override
  String get diaryShareLongImageSave => 'Save as a long image…';

  @override
  String get videoOpenExternally => 'Open in system player';

  @override
  String get videoPosterHint => 'Click to open in the system player';

  @override
  String get deviceAuthUnavailable =>
      'This device has no system verification (fingerprint, face or password), so locking isn\'t available';

  @override
  String get calendarYearSaveImage => 'Save this year as an image…';

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
  String get imageViewerOpenDiary => 'Open diary';

  @override
  String get imageViewerImageUnreadable =>
      'Couldn\'t read this image to share it';

  @override
  String get imageViewerMoreActions => 'More actions';

  @override
  String get imageViewerPrevious => 'Previous image';

  @override
  String get imageViewerNext => 'Next image';

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
  String get diaryMediaImportPermissionDenied =>
      'Read access to the selected files was denied. Select them again and allow access.';

  @override
  String get diaryMediaPickerUnavailable =>
      'The system picker could not be opened. Make sure a gallery or file manager is enabled on your device.';

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
  String backupImportSkippedEncrypted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count encrypted or locked notes can\'t be read and will be skipped',
      one: '1 encrypted or locked note can\'t be read and will be skipped',
    );
    return '$_temp0';
  }

  @override
  String backupImportSkippedUnsupported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count handwritten notes, mind maps or other special notes will be skipped',
      one: '1 handwritten note, mind map or other special note will be skipped',
    );
    return '$_temp0';
  }

  @override
  String backupImportSkippedUnreadable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count notes are in a format that can\'t be recognized and will be skipped',
      one:
          '1 note is in a format that can\'t be recognized and will be skipped',
    );
    return '$_temp0';
  }

  @override
  String backupImportSummaryOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'The bodies of $count notes couldn\'t be read; only their summaries will be imported',
      one:
          'The body of 1 note couldn\'t be read; only its summary will be imported',
    );
    return '$_temp0';
  }

  @override
  String backupImportPartialContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count notes contain sections that cannot be decrypted or displayed; readable text and original data will be preserved',
      one:
          '1 note contains sections that cannot be decrypted or displayed; readable text and original data will be preserved',
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
  String get calendarHeatBasisWords => 'By words';

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
      'Entries, days written, words, top mood and longest streak for the month.';

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
  String calendarSummaryWords(String count) {
    return '$count words';
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
  String calendarDayStats(int entries, String words) {
    String _temp0 = intl.Intl.pluralLogic(
      entries,
      locale: localeName,
      other: '$entries entries',
      one: '1 entry',
    );
    return '$_temp0 · $words words';
  }

  @override
  String get calendarYearViewTooltip => 'Show the whole year';

  @override
  String get calendarYearBasisMood => 'Mood';

  @override
  String get calendarYearBasisEntries => 'Entries';

  @override
  String get calendarYearBasisWords => 'Words';

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
  String get calendarFilterNotebooks => 'Notebooks';

  @override
  String get calendarFilterClear => 'Clear filter';

  @override
  String get calendarFilterDescription =>
      'Dates and stats only count matching entries. Any choice within a group matches; when several groups are set, an entry must match all of them.';

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
  String diaryCardWordCount(String count) {
    return '$count words';
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
  String get styleEditorCustom => 'Custom';

  @override
  String get styleEditorResetDone => 'Restored the default style';

  @override
  String get styleEditorPreviewLight => 'Light preview';

  @override
  String get styleEditorPreviewDark => 'Dark preview';

  @override
  String get styleEditorPanelHandle => 'Options panel';

  @override
  String get styleEditorPanelCollapsed => 'Collapsed';

  @override
  String get styleEditorPanelHalf => 'Half open';

  @override
  String get styleEditorPanelExpanded => 'Expanded';

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
  String get styleEditorPresetsTitle => 'Built-in styles';

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
  String get diaryCardStylePresetGlass => 'Glass';

  @override
  String get diaryCardStylePresetGlassDesc =>
      'Frosted translucent cards over the page background';

  @override
  String get diaryCardStyleMaterial => 'Material';

  @override
  String get diaryCardStyleMaterialSolid => 'Solid';

  @override
  String get diaryCardStyleMaterialGlass => 'Glass';

  @override
  String get diaryCardStyleBlur => 'Blur';

  @override
  String get diaryCardStyleBlurSubtitle =>
      'Blur shows only on pages with a background image';

  @override
  String styleEditorApplied(String name) {
    return 'Applied “$name”';
  }

  @override
  String get styleEditorSavedTitle => 'My styles';

  @override
  String get styleEditorSavedEmpty =>
      'Save a style you like to switch back in one tap';

  @override
  String get styleEditorSaveCurrent => 'Save current style';

  @override
  String styleEditorSaveLimit(int count) {
    return 'You can save up to $count styles';
  }

  @override
  String get styleEditorSaveDialogTitle => 'Save style';

  @override
  String get styleEditorRenameDialogTitle => 'Rename style';

  @override
  String get styleEditorNameLabel => 'Style name';

  @override
  String styleEditorDefaultName(int count) {
    return 'My style $count';
  }

  @override
  String get styleEditorRename => 'Rename';

  @override
  String styleEditorSavedDone(String name) {
    return 'Saved “$name”';
  }

  @override
  String styleEditorDeletedDone(String name) {
    return 'Deleted “$name”';
  }

  @override
  String styleEditorSavedActions(String name) {
    return 'More actions for “$name”';
  }

  @override
  String get styleEditorShareTitle => 'Share and import';

  @override
  String get styleEditorCopyCode => 'Copy style code';

  @override
  String get styleEditorCopyCodeSubtitle =>
      'Send it to a friend or keep it as a backup';

  @override
  String get styleEditorImportCode => 'Import from clipboard';

  @override
  String get styleEditorImportCodeSubtitle =>
      'Apply a style code someone shared';

  @override
  String get styleEditorCodeCopied => 'Style code copied';

  @override
  String get styleEditorImportEmpty => 'The clipboard is empty';

  @override
  String get styleEditorImportInvalid => 'No valid style code in the clipboard';

  @override
  String get styleEditorImportNewer =>
      'Imported. Some settings from a newer version may not apply';

  @override
  String get styleEditorImported => 'Style imported';

  @override
  String styleEditorImportedNamed(String name) {
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
  String get diaryCardStyleShowWordCount => 'Word count';

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
  String get styleEditorEditColor => 'Edit color';

  @override
  String get styleEditorColorDarkAuto => 'Pick the dark color automatically';

  @override
  String get styleEditorColorDarkAutoSubtitle =>
      'Derive a readable dark-mode color from the light one';

  @override
  String get styleEditorHexLabel => 'Hex color';

  @override
  String get styleEditorHexInvalid =>
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
  String diaryPreviewWordCount(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted words',
      one: '$formatted word',
    );
    return '$_temp0';
  }

  @override
  String diaryPreviewReadingTime(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes min read',
      one: '1 min read',
    );
    return '$_temp0';
  }

  @override
  String get diaryWordCountOpen => 'Show word count details';

  @override
  String get diaryWordCountTitle => 'Word count';

  @override
  String diaryWordCountUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'words',
      one: 'word',
    );
    return '$_temp0';
  }

  @override
  String get diaryWordCountCjk => 'Chinese characters';

  @override
  String get diaryWordCountLatin => 'Non-Chinese words';

  @override
  String get diaryWordCountCharacters => 'Characters (no spaces)';

  @override
  String get diaryWordCountCharactersWithSpaces => 'Characters (with spaces)';

  @override
  String get diaryWordCountParagraphs => 'Paragraphs';

  @override
  String get diaryWordCountImages => 'Photos';

  @override
  String get diaryWordCountRecordings => 'Recordings';

  @override
  String get diaryWordCountVideos => 'Videos';

  @override
  String get diaryWordCountAttachments => 'Attachments';

  @override
  String get diaryWordCountReading => 'Reading time';

  @override
  String get diaryWordCountRule =>
      'Each Chinese character or full-width punctuation mark counts as one word, other text counts by words, and spaces and line breaks are not counted.';

  @override
  String get diaryPreviewUpdatedPrefix => 'Updated';

  @override
  String get diaryPreviewBackToTop => 'Back to top';

  @override
  String get diaryPreviewStyleTitle => 'Diary preview page';

  @override
  String diaryPreviewStyleEntrySubtitle(String name) {
    return 'Current: $name';
  }

  @override
  String get diaryPreviewStyleMoreEntry => 'Page style';

  @override
  String get diaryPreviewStyleTabPresets => 'Presets';

  @override
  String get diaryPreviewStyleTabPage => 'Page';

  @override
  String get diaryPreviewStyleTabCover => 'Cover';

  @override
  String get diaryPreviewStyleTabTitle => 'Title';

  @override
  String get diaryPreviewStyleTabMeta => 'Details';

  @override
  String get diaryPreviewStyleTabBody => 'Text';

  @override
  String get diaryPreviewStylePresetClassic => 'Classic';

  @override
  String get diaryPreviewStylePresetClassicDesc => 'The original look';

  @override
  String get diaryPreviewStylePresetPaper => 'Paper book';

  @override
  String get diaryPreviewStylePresetPaperDesc =>
      'Warm paper, centered title, inset cover';

  @override
  String get diaryPreviewStylePresetMagazine => 'Magazine';

  @override
  String get diaryPreviewStylePresetMagazineDesc =>
      'Tall cover, large title, date on top';

  @override
  String get diaryPreviewStylePresetMinimal => 'Minimal';

  @override
  String get diaryPreviewStylePresetMinimalDesc =>
      'No cover, only the essentials';

  @override
  String get diaryPreviewStylePresetNight => 'Night';

  @override
  String get diaryPreviewStylePresetNightDesc =>
      'Ink paper with a progress line';

  @override
  String get diaryPreviewStylePresetJournal => 'Journal';

  @override
  String get diaryPreviewStylePresetJournalDesc =>
      'Tinted by mood, details in a card';

  @override
  String get diaryPreviewStylePresetMood => 'Mood color';

  @override
  String get diaryPreviewStylePresetMoodDesc =>
      'The page takes the entry’s mood color';

  @override
  String get diaryPreviewStylePresetImmersive => 'Immersive';

  @override
  String get diaryPreviewStylePresetImmersiveDesc =>
      'Full cover, progress and back-to-top';

  @override
  String get diaryPreviewStyleColorGroup => 'Colors';

  @override
  String get diaryPreviewStyleColorSeed => 'Color basis';

  @override
  String get diaryPreviewStyleSeedApp => 'App theme';

  @override
  String get diaryPreviewStyleSeedMood => 'Mood';

  @override
  String get diaryPreviewStyleSeedTag => 'First tag';

  @override
  String get diaryPreviewStyleSeedCustom => 'Custom';

  @override
  String get diaryPreviewStyleSeedHint =>
      'Entries without a mood or tag use the app color.';

  @override
  String get diaryPreviewStyleSeedColor => 'Basis color';

  @override
  String get diaryPreviewStylePaper => 'Paper';

  @override
  String get diaryPreviewStylePaperTheme => 'Theme';

  @override
  String get diaryPreviewStylePaperWarm => 'Warm';

  @override
  String get diaryPreviewStylePaperSepia => 'Sepia';

  @override
  String get diaryPreviewStylePaperMint => 'Mint';

  @override
  String get diaryPreviewStylePaperGray => 'Gray';

  @override
  String get diaryPreviewStylePaperInk => 'Ink';

  @override
  String get diaryPreviewStylePaperCustom => 'Custom';

  @override
  String get diaryPreviewStylePaperColor => 'Paper color';

  @override
  String get diaryPreviewStylePaperHint =>
      'On paper darker or lighter than the theme, the whole page switches to match so text stays readable.';

  @override
  String get diaryPreviewStyleTextColor => 'Custom text color';

  @override
  String get diaryPreviewStyleTextColorHint =>
      'Falls back to the default color when contrast with the paper is too low.';

  @override
  String get diaryPreviewStyleLayoutGroup => 'Layout';

  @override
  String get diaryPreviewStylePadding => 'Side margins';

  @override
  String get diaryPreviewStyleLimitWidth => 'Limit text width';

  @override
  String get diaryPreviewStyleLimitWidthSubtitle =>
      'Centers the text on tablets and in landscape';

  @override
  String get diaryPreviewStyleContentWidth => 'Maximum text width';

  @override
  String get diaryPreviewStyleTopBarGroup => 'Top bar';

  @override
  String get diaryPreviewStyleTopBarFloating => 'Hide on scroll';

  @override
  String get diaryPreviewStyleTopBarPinned => 'Always shown';

  @override
  String get diaryPreviewStyleTopBarTitle => 'Title';

  @override
  String get diaryPreviewStyleTopBarTitleDate => 'Date';

  @override
  String get diaryPreviewStyleTopBarTitleNone => 'None';

  @override
  String get diaryPreviewStyleShowTypographyButton => 'Font and layout button';

  @override
  String get diaryPreviewStyleShowEditButton => 'Edit button';

  @override
  String get diaryPreviewStyleShowShareButton => 'Share button';

  @override
  String get diaryPreviewStyleReadingGroup => 'Reading aids';

  @override
  String get diaryPreviewStyleProgress => 'Reading progress line';

  @override
  String get diaryPreviewStyleProgressSubtitle =>
      'A thin line at the top grows as you read';

  @override
  String get diaryPreviewStyleBackToTop => 'Back-to-top button';

  @override
  String get diaryPreviewStyleBackToTopSubtitle =>
      'Shows up after a screen and a half';

  @override
  String get diaryPreviewStyleCoverMode => 'Style';

  @override
  String get diaryPreviewStyleCoverBanner => 'Full width';

  @override
  String get diaryPreviewStyleCoverInset => 'Inset';

  @override
  String get diaryPreviewStyleCoverHidden => 'Hidden';

  @override
  String get diaryPreviewStyleCoverFit => 'Fit';

  @override
  String get diaryPreviewStyleCoverContain => 'Whole photo';

  @override
  String get diaryPreviewStyleCoverFill => 'Fill and crop';

  @override
  String get diaryPreviewStyleCoverHeight => 'Cover height';

  @override
  String get diaryPreviewStyleCoverHeightHint =>
      'The cover never takes more than 70% of the screen height.';

  @override
  String get diaryPreviewStyleCoverRadius => 'Corner radius';

  @override
  String get diaryPreviewStyleCoverFade => 'Fade on scroll';

  @override
  String get diaryPreviewStyleCoverFadeSubtitle =>
      'The cover fades and shrinks a little as you scroll up';

  @override
  String get diaryPreviewStyleCoverFirstImage =>
      'Use the first photo without a cover';

  @override
  String get diaryPreviewStyleTitleVisible => 'Show title';

  @override
  String get diaryPreviewStyleTitleUntitled =>
      'Show “Untitled” when there is no title';

  @override
  String get diaryPreviewStyleTitleUntitledSubtitle =>
      'When off, the title line is left out';

  @override
  String get diaryPreviewStyleTitleScale => 'Title size';

  @override
  String get diaryPreviewStyleTitleWeight => 'Weight';

  @override
  String get diaryPreviewStyleWeightRegular => 'Regular';

  @override
  String get diaryPreviewStyleWeightMedium => 'Medium';

  @override
  String get diaryPreviewStyleWeightBold => 'Bold';

  @override
  String get diaryPreviewStyleWeightHeavy => 'Heavy';

  @override
  String get diaryPreviewStyleTitleAlign => 'Alignment';

  @override
  String get diaryPreviewStyleAlignStart => 'Start';

  @override
  String get diaryPreviewStyleAlignCenter => 'Center';

  @override
  String get diaryPreviewStyleTitleColor => 'Custom title color';

  @override
  String get diaryPreviewStyleMetaPosition => 'Position';

  @override
  String get diaryPreviewStyleMetaAbove => 'Above title';

  @override
  String get diaryPreviewStyleMetaBelow => 'Below title';

  @override
  String get diaryPreviewStyleMetaEnd => 'After text';

  @override
  String get diaryPreviewStyleMetaLayout => 'Layout';

  @override
  String get diaryPreviewStyleMetaStacked => 'Stacked';

  @override
  String get diaryPreviewStyleMetaInline => 'Inline';

  @override
  String get diaryPreviewStyleMetaCard => 'Card';

  @override
  String get diaryPreviewStyleMetaItems => 'Shown details';

  @override
  String get diaryPreviewStyleShowDate => 'Date';

  @override
  String get diaryPreviewStyleShowWordCount => 'Word count';

  @override
  String get diaryPreviewStyleShowReadingTime => 'Reading time';

  @override
  String get diaryPreviewStyleShowLocation => 'Location';

  @override
  String get diaryPreviewStyleShowWeather => 'Weather';

  @override
  String get diaryPreviewStyleShowMood => 'Mood';

  @override
  String get diaryPreviewStyleShowEnergy => 'Energy';

  @override
  String get diaryPreviewStyleShowTags => 'Tags';

  @override
  String get diaryPreviewStyleDatePrefix =>
      '“Published / Updated” before the date';

  @override
  String get diaryPreviewStyleChipsGroup => 'Chips';

  @override
  String get diaryPreviewStyleTagStyle => 'Tags';

  @override
  String get diaryPreviewStyleChipStyle => 'Mood and energy';

  @override
  String get diaryPreviewStyleChipChip => 'Chip';

  @override
  String get diaryPreviewStyleChipPlain => 'Text';

  @override
  String get diaryPreviewStyleTypographyEntry => 'Font and layout';

  @override
  String get diaryPreviewStyleTypographyEntrySubtitle =>
      'Shared with the editor';

  @override
  String get diaryPreviewStyleEmptyHint => 'Hint when there is no text';

  @override
  String get diaryPreviewStyleLastEdited => 'Show “Last edited”';

  @override
  String get diaryPreviewStyleEditedFormat => 'Time format';

  @override
  String get diaryPreviewStyleEditedPrecise => 'Precise';

  @override
  String get diaryPreviewStyleEditedRelative => 'Relative';

  @override
  String get diaryPreviewStyleEditedFull => 'Full';

  @override
  String get diaryPreviewStyleCapsuleInsight => 'Unlocked capsule note';

  @override
  String get diaryPreviewStyleBehaviorGroup => 'Reading behavior';

  @override
  String get diaryPreviewStyleBehaviorFootnote =>
      'Presets and style codes don’t change these.';

  @override
  String get diaryPreviewStyleTodoToggle => 'Tick to-dos while reading';

  @override
  String get diaryPreviewStyleTodoToggleSubtitle =>
      'Ticks are saved automatically';

  @override
  String get diaryPreviewStyleTextSelection => 'Select text by long-press';

  @override
  String get diaryPreviewStyleTextSelectionSubtitle =>
      'Select and copy parts of the entry';

  @override
  String diaryPreviewStyleSampleOf(int index, int count) {
    return 'Sample $index of $count';
  }

  @override
  String get diaryPreviewStyleSampleHeading => 'Small things today';

  @override
  String get diaryPreviewStyleSampleQuote => 'Slow down, it’s faster.';

  @override
  String get diaryPreviewStyleSampleTodo1 => 'Buy some flowers';

  @override
  String get diaryPreviewStyleSampleTodo2 => 'Call home';

  @override
  String get diaryPreviewStyleSampleLong =>
      'After the rain stopped the street went quiet. I sat by the window and wrote down three things I was grateful for, while leaves drifted past like the pages of an old book.';

  @override
  String get diaryPreviewStyleSampleWeather => 'Sunny';

  @override
  String get diaryPreviewFirstDiary => 'This is the first one';

  @override
  String get diaryPreviewLastDiary => 'This is the last one';

  @override
  String get diaryPreviewPrevious => 'Previous';

  @override
  String get diaryPreviewNext => 'Next';

  @override
  String diaryPreviewPosition(int index, int count) {
    return '$index / $count';
  }

  @override
  String diaryPreviewPositionMore(int index, int count) {
    return '$index / $count+';
  }

  @override
  String diaryPreviewPositionSemantics(int index, int count) {
    return '$index of $count';
  }

  @override
  String diaryPreviewPositionSemanticsMore(int index, int count) {
    return '$index of at least $count';
  }

  @override
  String get diaryDetailPaneEmpty => 'Pick an entry to read';

  @override
  String diaryDetailPaneCreateHint(String shortcut) {
    return 'Press $shortcut to write a new one';
  }

  @override
  String get diaryPreviewStyleTabPaging => 'Paging';

  @override
  String get diaryPreviewStyleSwipe => 'Swipe between diaries';

  @override
  String get diaryPreviewStyleSwipeSubtitle =>
      'In the order of the list you opened it from';

  @override
  String get diaryPreviewStyleSwipeSensitivity => 'Sensitivity';

  @override
  String get diaryPreviewStyleSensitivitySensitive => 'Sensitive';

  @override
  String get diaryPreviewStyleSensitivityStandard => 'Standard';

  @override
  String get diaryPreviewStyleSensitivityStrict => 'Strict';

  @override
  String get diaryPreviewStyleSensitivityHint =>
      'Further right needs a flatter swipe; Strict also needs a half-screen drag or a firm flick.';

  @override
  String get diaryPreviewStyleHapticOnPage => 'Vibrate when turning pages';

  @override
  String get diaryPreviewStyleTransition => 'Transition';

  @override
  String get diaryPreviewStyleTransitionSlide => 'Slide';

  @override
  String get diaryPreviewStyleTransitionStack => 'Stack';

  @override
  String get diaryPreviewStyleTransitionFade => 'Fade';

  @override
  String get diaryPreviewStyleNeighborCards => 'Previous and next at the end';

  @override
  String get diaryPreviewStyleEdgeHint => 'Hint at either end';

  @override
  String get diaryPreviewStyleEdgeHintSubtitle =>
      'When you pull past the first or last diary';

  @override
  String get diaryPreviewStyleTopBarTitlePosition => 'Position';

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

  @override
  String get cloudBackupErrorPlatformUnavailable =>
      'System account authorization is unavailable on this device (Google Play services required), and this build has no fallback';

  @override
  String get weatherInvalidHost =>
      'The weather service host is set up incorrectly. Check qweather.api_host.';

  @override
  String get weatherNetworkError =>
      'The weather request failed or timed out. Check your connection and try again.';

  @override
  String get weatherApiError =>
      'The weather service is temporarily unavailable. Please try again later.';

  @override
  String get weatherParseError =>
      'No usable weather was returned. Please try again later or enter it manually.';

  @override
  String get publishCoverImportFailed =>
      'Couldn\'t import this picture as the cover. Please try another one.';

  @override
  String get publishTagCreateFailed =>
      'Couldn\'t create the tag. Please try again.';

  @override
  String get publishFailed => 'Couldn\'t publish the diary. Please try again.';

  @override
  String get publishSucceeded => 'Diary published';

  @override
  String get publishCapsuleExpired =>
      'The unlock time had passed, so the diary was published without a time lock.';

  @override
  String get publishSaveFailed =>
      'Couldn\'t save your changes. Please try again.';

  @override
  String publishTimeFollowsCapsule(String time) {
    return 'Follows the time lock · $time';
  }

  @override
  String get publishCoverChange => 'Tap to change';

  @override
  String get publishPanelSummaryEmpty => 'Add tags, mood, place…';

  @override
  String get previewShare => 'Share';

  @override
  String get diaryShareSheetTitle => 'Share diary';

  @override
  String get diaryShareContentSection => 'Content';

  @override
  String get diaryShareOptionTitle => 'Title';

  @override
  String get diaryShareOptionBody => 'Body';

  @override
  String get diaryShareOptionDate => 'Date';

  @override
  String get diaryShareOptionMoodWeather => 'Mood & weather';

  @override
  String get diaryShareOptionLocation => 'Location';

  @override
  String get diaryShareOptionTags => 'Tags';

  @override
  String get diaryShareOptionImages => 'Images';

  @override
  String get diaryShareTextEmpty =>
      'No text selected — only images will be shared';

  @override
  String diaryShareImagesSelected(int selected, int total) {
    return '$selected of $total selected';
  }

  @override
  String diaryShareImageLabel(int index) {
    return 'Image $index';
  }

  @override
  String get diaryShareTargetsSection => 'Share to';

  @override
  String get diaryShareTargetWeibo => 'Weibo';

  @override
  String get diaryShareTargetXiaohongshu => 'Xiaohongshu';

  @override
  String get diaryShareTargetWechat => 'WeChat';

  @override
  String get diaryShareTargetWechatMoments => 'Moments';

  @override
  String get diaryShareTargetQq => 'QQ';

  @override
  String get diaryShareTargetQzone => 'Qzone';

  @override
  String get diaryShareTargetSystem => 'More apps';

  @override
  String get diaryShareCopyText => 'Copy text';

  @override
  String get diaryShareClipboardHint =>
      'When images are attached, the text is copied for you — just paste it into the post.';

  @override
  String get diaryShareMoreSection => 'Other formats';

  @override
  String get diaryShareLongImage => 'Share as long image';

  @override
  String get diaryShareLongImageSubtitle =>
      'Renders the diary as it looks in the preview';

  @override
  String diaryShareRequiresImage(String app) {
    return '$app needs at least one image';
  }

  @override
  String get diaryShareRequiresImageSeveral =>
      'Greyed-out apps need at least one image';

  @override
  String get diaryShareNothingSelected => 'Choose something to share first';

  @override
  String get diaryShareInProgress => 'Preparing to share';

  @override
  String diaryShareTextCopiedForApp(String app) {
    return 'Text copied — paste it in $app';
  }

  @override
  String get diaryShareTextCopied =>
      'Text copied — paste it in the app you shared to';

  @override
  String get diaryShareCopied => 'Copied to clipboard';

  @override
  String diaryShareImagesTrimmed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Up to $count images per share — the rest weren\'t sent',
      one: 'Only 1 image per share — the rest weren\'t sent',
    );
    return '$_temp0';
  }

  @override
  String diaryShareImagesMissing(int count) {
    return '$count image(s) could not be read and were left out';
  }

  @override
  String diaryShareAppUnavailable(String app) {
    return 'Couldn\'t open $app. Make sure it is installed and up to date';
  }

  @override
  String get diaryShareNothingToShare => 'Nothing to share';

  @override
  String diaryShareFailed(String error) {
    return 'Share failed: $error';
  }

  @override
  String get previewExport => 'Export';

  @override
  String get diaryExportSelected => 'Export';

  @override
  String get dataMgmtExportDiaries => 'Export diaries';

  @override
  String get dataMgmtExportDiariesSubtitle =>
      'Export by date or tag as PDF, Word, Markdown, web page and more';

  @override
  String get diaryExportSheetTitle => 'Export diaries';

  @override
  String diaryExportSheetCount(int count) {
    return '$count diaries';
  }

  @override
  String get diaryExportFormatSection => 'Format';

  @override
  String get diaryExportOptionsSection => 'Options';

  @override
  String get diaryExportFormatPdf => 'PDF';

  @override
  String get diaryExportFormatPdfDescription =>
      'Fixed layout for reading and printing';

  @override
  String get diaryExportFormatWord => 'Word document';

  @override
  String get diaryExportFormatWordDescription => '.docx you can keep editing';

  @override
  String get diaryExportFormatMarkdown => 'Markdown';

  @override
  String get diaryExportFormatMarkdownDescription =>
      'With front matter for Obsidian and other note apps; can be imported back into Jotsy';

  @override
  String get diaryExportFormatHtml => 'Web page';

  @override
  String get diaryExportFormatHtmlDescription =>
      'Opens in any browser; several diaries with images come as a page plus an image folder';

  @override
  String get diaryExportFormatText => 'Plain text';

  @override
  String get diaryExportFormatTextDescription => '.txt that opens anywhere';

  @override
  String get diaryExportFormatCsv => 'Spreadsheet (CSV)';

  @override
  String get diaryExportFormatCsvDescription =>
      'One row per diary with mood, weather and more for Excel';

  @override
  String get diaryExportFormatDiaryFile => 'Jotsy diary file';

  @override
  String get diaryExportFormatDiaryFileDescription =>
      'Keeps everything including media, optional password, lossless re-import';

  @override
  String get diaryExportIncludeImages => 'Include images';

  @override
  String get diaryExportIncludeMedia =>
      'Include images, recordings, videos and attachments';

  @override
  String get diaryExportIncludeMeta =>
      'Include mood, weather, location and tags';

  @override
  String get diaryExportOrderOldest => 'Oldest first';

  @override
  String get diaryExportOrderNewest => 'Newest first';

  @override
  String get diaryExportSave => 'Save to files';

  @override
  String get diaryExportInProgress => 'Exporting';

  @override
  String diaryExportSaved(int count) {
    return 'Exported $count diaries';
  }

  @override
  String diaryExportSkippedCapsules(int count) {
    return '$count sealed time capsules were not exported';
  }

  @override
  String get diaryExportOnlyCapsules =>
      'Only sealed time capsules were selected — nothing to export';

  @override
  String get diaryExportNothing => 'No diaries match';

  @override
  String get diaryExportPageTitle => 'Export diaries';

  @override
  String get diaryExportRangeSection => 'Date range';

  @override
  String get diaryExportRangeAll => 'All diaries';

  @override
  String get diaryExportRangeThisYear => 'This year';

  @override
  String get diaryExportRangeLast30Days => 'Last 30 days';

  @override
  String get diaryExportRangeCustom => 'Custom dates';

  @override
  String diaryExportRangeCustomValue(String start, String end) {
    return '$start – $end, tap to change';
  }

  @override
  String get diaryExportTagsSection => 'Tags';

  @override
  String get diaryExportTagsHint =>
      'Leave empty for all tags; any selected tag matches';

  @override
  String get diaryExportIncludeArchived => 'Include archived diaries';

  @override
  String diaryExportMatchCount(int count) {
    return '$count diaries will be exported';
  }

  @override
  String get diaryExportCapsuleNote =>
      'Sealed time capsules are never exported';

  @override
  String get diaryExportNext => 'Choose format and export';

  @override
  String get diaryExportLabelUntitled => 'Untitled';

  @override
  String get diaryExportLabelMood => 'Mood';

  @override
  String get diaryExportLabelEnergy => 'Energy';

  @override
  String get diaryExportLabelWeather => 'Weather';

  @override
  String get diaryExportLabelLocation => 'Location';

  @override
  String get diaryExportLabelTags => 'Tags';

  @override
  String get diaryExportLabelDate => 'Date';

  @override
  String get diaryExportLabelTime => 'Time';

  @override
  String get diaryExportLabelTitle => 'Title';

  @override
  String get diaryExportLabelContent => 'Content';

  @override
  String get diaryExportLabelWordCount => 'Characters';

  @override
  String get diaryExportLabelUpdated => 'Last edited';

  @override
  String get diaryExportLabelImage => 'Image';

  @override
  String get diaryExportLabelAudio => 'Recording';

  @override
  String get diaryExportLabelVideo => 'Video';

  @override
  String get diaryExportLabelAttachment => 'Attachment';

  @override
  String get diaryExportLabelExportedBy => 'Exported from Jotsy';

  @override
  String diaryExportTooLarge(int size) {
    return 'Too many images (about $size MB) for one PDF. Narrow the date range or turn off “Include images” and try again';
  }

  @override
  String diaryDayPhotosTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
    );
    return '$_temp0 from this day';
  }

  @override
  String get diaryDayPhotosAccessTitle => 'Photos from this day';

  @override
  String get diaryDayPhotosAccessBody =>
      'Allow photo access to see the photos you took on this day and add some to this entry.';

  @override
  String get diaryDayPhotosDeniedBody =>
      'Photo access is off. You can turn it on in system settings.';

  @override
  String get diaryDayPhotosAllowAccess => 'Allow access';

  @override
  String get diaryDayPhotosOpenSettings => 'Open settings';

  @override
  String get diaryDayPhotosShowAll => 'All';

  @override
  String get diaryDayPhotosDismiss => 'Hide for this entry';

  @override
  String diaryDayPhotosSelected(int count) {
    return '$count selected';
  }

  @override
  String get diaryDayPhotosClear => 'Clear';

  @override
  String get diaryDayPhotosInsert => 'Insert';

  @override
  String diaryDayPhotosInsertCount(int count) {
    return 'Insert $count';
  }

  @override
  String get diaryDayPhotosLimited => 'Showing only photos you allowed';

  @override
  String get diaryDayPhotosManageLimited => 'Select more';

  @override
  String diaryDayPhotosPhotoLabel(String time) {
    return 'Photo taken at $time';
  }

  @override
  String diaryDayPhotosInsertedLabel(String time) {
    return 'Photo taken at $time, added';
  }

  @override
  String diaryDayPhotosSheetTitle(String date) {
    return 'Photos from $date';
  }

  @override
  String diaryDayPhotosMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos couldn\'t be read and were skipped',
      one: '1 photo couldn\'t be read and was skipped',
    );
    return '$_temp0';
  }

  @override
  String get settingsDayPhotoSuggestions =>
      'Show that day\'s photos automatically';

  @override
  String get settingsDayPhotoSuggestionsSubtitle =>
      'When backfilling a past day, list that day\'s photos under the title. When off, open them from the editor\'s top-right menu.';

  @override
  String get settingsToolbarAlwaysVisible => 'Always show toolbar';

  @override
  String get settingsToolbarAlwaysVisibleSubtitle =>
      'Keep the toolbar at the bottom of the editor when the on-screen keyboard is hidden or you type on a physical keyboard.';

  @override
  String get settingsOpenDiaryInEditor => 'Open diaries in the editor';

  @override
  String get settingsOpenDiaryInEditorSubtitle =>
      'Tap a diary to start editing right away instead of opening the preview first.';

  @override
  String get diaryDayPhotosSetCover => 'Set as cover';

  @override
  String get diaryDayPhotosClearCover => 'Remove cover';

  @override
  String get diaryDayPhotosCoverBadge => 'Cover';

  @override
  String diaryDayPhotosCoverLabel(String label) {
    return '$label, cover';
  }

  @override
  String get diaryDayPhotosCoverSet =>
      'Set as cover. You can see or change it on the publish page.';

  @override
  String get diaryDayPhotosCoverSetEdit => 'Cover set';

  @override
  String get diaryDayPhotosMenu => 'Photos from this day';

  @override
  String get diaryDayPhotosEmpty => 'No photos taken this day';

  @override
  String get diaryLongImageBadge => 'Long image';

  @override
  String get diaryImageMenuTitle => 'Image';

  @override
  String get diaryImageMenuView => 'View';

  @override
  String get diaryImageMenuResize => 'Resize';

  @override
  String get diaryImageMenuCopy => 'Copy';

  @override
  String get diaryPreviewStyleLongImage => 'Long images';

  @override
  String get diaryPreviewStyleLongImageSubtitle =>
      'At least 3 times as tall as wide, like long screenshots. Tap a folded one to see it all.';

  @override
  String get diaryPreviewStyleLongImageFold => 'Fold';

  @override
  String get diaryPreviewStyleLongImageFull => 'Full';

  @override
  String get diaryDraftsTitle => 'Drafts';

  @override
  String get diaryDraftsSettingsSubtitle =>
      'Unpublished entries you can keep writing or delete';

  @override
  String get diaryDraftsEmpty =>
      'No drafts yet. New entries you leave before publishing are kept here';

  @override
  String diaryDraftEditedAt(String time, String words) {
    return 'Edited $time · $words words';
  }

  @override
  String get diaryDraftDeleted => 'Draft deleted';

  @override
  String diaryDraftsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Deleted $count drafts',
      one: 'Deleted 1 draft',
    );
    return '$_temp0';
  }

  @override
  String get diaryDraftsDeleteTitle => 'Delete drafts';

  @override
  String diaryDraftsDeleteMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete the $count selected drafts?',
      one: 'Delete the selected draft?',
    );
    return '$_temp0';
  }

  @override
  String get diaryDraftsDeleteFailed =>
      'Couldn\'t delete the drafts. Try again';

  @override
  String get diaryDraftsRestoreFailed => 'Couldn\'t undo. Try again';

  @override
  String get diaryDraftPickerTitle => 'Continue a draft';

  @override
  String diaryDraftPickerViewAll(int count) {
    return 'View all drafts ($count)';
  }

  @override
  String get diaryDraftPickerNewBlank => 'New blank entry';

  @override
  String get diarySearchPreviewHint => 'Search in Jotsy';

  @override
  String backupOverwriteAllTemplates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count diary templates',
      one: '1 diary template',
    );
    return '$_temp0';
  }

  @override
  String backupImportTemplateMergeResult(int added) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: 'Templates: $added added',
      one: 'Templates: 1 added',
    );
    return '$_temp0';
  }

  @override
  String backupOverwriteAllNotebooks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notebooks',
      one: '1 notebook',
    );
    return '$_temp0';
  }

  @override
  String backupImportNotebookMergeResult(int added) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: 'Notebooks: $added added',
      one: 'Notebooks: 1 added',
    );
    return '$_temp0';
  }

  @override
  String backupImportModeOverwriteNotebooksExtra(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Also replaces the name, cover, chapters and other settings of $count existing notebooks',
      one:
          'Also replaces the name, cover, chapters and other settings of 1 existing notebook',
    );
    return '$_temp0';
  }

  @override
  String get diaryTemplateDailyName => 'Daily journal';

  @override
  String get diaryTemplateDailyDesc =>
      'Today\'s story, and how you feel right now';

  @override
  String diaryTemplateDailyTitle(String date, String weekday) {
    return '$weekday, $date';
  }

  @override
  String get diaryTemplateMorningName => 'Morning pages';

  @override
  String get diaryTemplateMorningDesc =>
      'A page at dawn to give the day a gentle direction';

  @override
  String diaryTemplateMorningTitle(String date) {
    return 'Morning · $date';
  }

  @override
  String get diaryTemplateEveningName => 'Evening review';

  @override
  String get diaryTemplateEveningDesc =>
      'Look back on the day and set up tomorrow';

  @override
  String diaryTemplateEveningTitle(String date) {
    return 'Review · $date';
  }

  @override
  String get diaryTemplateGratitudeName => 'Gratitude journal';

  @override
  String get diaryTemplateGratitudeDesc =>
      'Three small things you\'re grateful for';

  @override
  String diaryTemplateGratitudeTitle(String date) {
    return 'Gratitude · $date';
  }

  @override
  String get diaryTemplateQuestionName => 'Question of the day';

  @override
  String get diaryTemplateQuestionDesc =>
      'One question a day to see yourself anew';

  @override
  String diaryTemplateQuestionTitle(String date) {
    return 'Question of the day · $date';
  }

  @override
  String get diaryTemplateWeeklyName => 'Weekly review';

  @override
  String get diaryTemplateWeeklyDesc =>
      'Gather the week\'s highlights and step lightly into the next';

  @override
  String diaryTemplateWeeklyTitle(String date) {
    return 'Weekly review · $date';
  }

  @override
  String get diaryTemplateEmotionName => 'Untangle a feeling';

  @override
  String get diaryTemplateEmotionDesc =>
      'Write a feeling down and see where it comes from';

  @override
  String diaryTemplateEmotionTitle(String date) {
    return 'Feelings · $date';
  }

  @override
  String get diaryTemplateReadingName => 'Reading notes';

  @override
  String get diaryTemplateReadingDesc =>
      'Passages and thoughts from what you read';

  @override
  String diaryTemplateReadingTitle(String date) {
    return 'Reading notes · $date';
  }

  @override
  String get diaryTemplateDailyHappened => 'Today\'s story:';

  @override
  String get diaryTemplateDailyMoment => 'A moment that shone:';

  @override
  String get diaryTemplateDailyMood => 'How I feel right now:';

  @override
  String get diaryTemplateDailyWords => 'One line for today:';

  @override
  String diaryTemplateMorningWake(String time, String term) {
    return 'Up at $time';
  }

  @override
  String get diaryTemplateMorningTop3 => 'Three things that matter most today:';

  @override
  String get diaryTemplateMorningLookForward =>
      'Something small to look forward to:';

  @override
  String get diaryTemplateMorningWords => 'A word for today:';

  @override
  String get diaryTemplateEveningDone => 'What I got done:';

  @override
  String get diaryTemplateEveningWentWell => 'What went well:';

  @override
  String get diaryTemplateEveningBetter => 'What could be better:';

  @override
  String get diaryTemplateEveningTomorrow => 'Plans for tomorrow:';

  @override
  String get diaryTemplateEveningNight => 'Before I sleep:';

  @override
  String get diaryTemplateGratitudeThree =>
      'Three things I\'m grateful for today:';

  @override
  String get diaryTemplateGratitudeThanks => 'Someone I\'d like to thank:';

  @override
  String get diaryTemplateGratitudeSelf => 'And a thank-you to myself:';

  @override
  String get diaryTemplateQuestionPrompt => 'Today\'s question:';

  @override
  String get diaryTemplateQuestionAnswer => 'My answer:';

  @override
  String diaryTemplateWeeklyProgress(String week, String progress) {
    return 'Week $week · $progress of the year behind us';
  }

  @override
  String get diaryTemplateWeeklyHighlights => 'Highlights of the week:';

  @override
  String get diaryTemplateWeeklyWins => 'Wins and lessons:';

  @override
  String get diaryTemplateWeeklyOpen => 'Still in progress:';

  @override
  String get diaryTemplateWeeklyNext => 'Next week:';

  @override
  String get diaryTemplateWeeklyNote => 'A note to next week\'s me:';

  @override
  String get diaryTemplateEmotionHappened => 'What happened:';

  @override
  String get diaryTemplateEmotionFelt => 'What I felt:';

  @override
  String get diaryTemplateEmotionSource => 'Where it comes from:';

  @override
  String get diaryTemplateEmotionNeed => 'What I really need:';

  @override
  String get diaryTemplateEmotionStep => 'One small step from here:';

  @override
  String get diaryTemplateReadingBook => 'Book: ';

  @override
  String get diaryTemplateReadingAuthor => 'Author: ';

  @override
  String get diaryTemplateReadingProgress => 'Read up to: ';

  @override
  String get diaryTemplateReadingQuotes => 'Passages:';

  @override
  String get diaryTemplateReadingThoughts => 'My thoughts:';

  @override
  String get diaryTemplateTagGratitude => 'Gratitude';

  @override
  String get diaryTemplateTagReading => 'Reading';

  @override
  String get diaryTemplateQuestion01 =>
      'What small thing made you smile today?';

  @override
  String get diaryTemplateQuestion02 =>
      'If you could redo today, what would you change?';

  @override
  String get diaryTemplateQuestion03 =>
      'When did you last feel proud of yourself?';

  @override
  String get diaryTemplateQuestion04 =>
      'Who would you most like to say something to right now?';

  @override
  String get diaryTemplateQuestion05 =>
      'What is one new thing you learned today?';

  @override
  String get diaryTemplateQuestion06 =>
      'What has been weighing on your mind lately?';

  @override
  String get diaryTemplateQuestion07 =>
      'What does your ideal weekend look like?';

  @override
  String get diaryTemplateQuestion08 =>
      'Was there a moment today when you felt understood?';

  @override
  String get diaryTemplateQuestion09 =>
      'What are you reading, watching or listening to lately, and what does it give you?';

  @override
  String get diaryTemplateQuestion10 =>
      'Do you need rest, company or a challenge right now?';

  @override
  String get diaryTemplateQuestion11 =>
      'What were you worried about a year ago today? And now?';

  @override
  String get diaryTemplateQuestion12 => 'What did you do for yourself today?';

  @override
  String get diaryTemplateQuestion13 =>
      'What made you laugh out loud recently?';

  @override
  String get diaryTemplateQuestion14 =>
      'Which habit would you like to start or let go of?';

  @override
  String get diaryTemplateQuestion15 =>
      'Describe yourself today in three words.';

  @override
  String get diaryTemplateQuestion16 =>
      'What was the hardest part of today, and how did you handle it?';

  @override
  String get diaryTemplateQuestion17 =>
      'Who are you grateful for lately, and why?';

  @override
  String get diaryTemplateQuestion18 =>
      'If you could do only one thing tomorrow, what would it be?';

  @override
  String get diaryTemplateQuestion19 =>
      'What changed your mind about something recently?';

  @override
  String get diaryTemplateQuestion20 =>
      'What does today\'s weather remind you of?';

  @override
  String get diaryTemplateQuestion21 =>
      'When did you last step out of your comfort zone?';

  @override
  String get diaryTemplateQuestion22 =>
      'How will you see today\'s worries ten years from now?';

  @override
  String get diaryTemplateQuestion23 =>
      'Did anything someone said today stay with you?';

  @override
  String get diaryTemplateQuestion24 =>
      'Where have you felt most at peace lately?';

  @override
  String get diaryTemplateQuestion25 =>
      'What would you tell your younger self?';

  @override
  String get diaryTemplateQuestion26 =>
      'Do you know yourself a little better than yesterday?';

  @override
  String get diaryTemplateQuestion27 =>
      'What small progress is worth celebrating lately?';

  @override
  String get diaryTemplateQuestion28 =>
      'What have you wanted to try but haven\'t started? What\'s holding you back?';

  @override
  String get diaryTemplateQuestion29 =>
      'How did you look after your feelings today?';

  @override
  String get diaryTemplateQuestion30 =>
      'If you rated today from 1 to 10, what would it be, and why?';

  @override
  String get diaryTemplateVarDateToken => 'date';

  @override
  String get diaryTemplateVarDateLabel => 'Date';

  @override
  String get diaryTemplateVarWeekdayToken => 'weekday';

  @override
  String get diaryTemplateVarWeekdayLabel => 'Weekday';

  @override
  String get diaryTemplateVarTimeToken => 'time';

  @override
  String get diaryTemplateVarTimeLabel => 'Time';

  @override
  String get diaryTemplateVarYearToken => 'year';

  @override
  String get diaryTemplateVarYearLabel => 'Year';

  @override
  String get diaryTemplateVarMonthToken => 'month';

  @override
  String get diaryTemplateVarMonthLabel => 'Month';

  @override
  String get diaryTemplateVarDayToken => 'day';

  @override
  String get diaryTemplateVarDayLabel => 'Day';

  @override
  String get diaryTemplateVarWeekToken => 'week';

  @override
  String get diaryTemplateVarWeekLabel => 'Week number';

  @override
  String get diaryTemplateVarDayOfYearToken => 'dayOfYear';

  @override
  String get diaryTemplateVarDayOfYearLabel => 'Day of the year';

  @override
  String get diaryTemplateVarYearProgressToken => 'yearProgress';

  @override
  String get diaryTemplateVarYearProgressLabel => 'Year progress';

  @override
  String get diaryTemplateVarLunarToken => 'lunar';

  @override
  String get diaryTemplateVarLunarLabel => 'Lunar date';

  @override
  String get diaryTemplateVarSolarTermToken => 'solarTerm';

  @override
  String get diaryTemplateVarSolarTermLabel => 'Solar term';

  @override
  String get diaryTemplateVarQuestionToken => 'question';

  @override
  String get diaryTemplateVarQuestionLabel => 'Question of the day';

  @override
  String get diaryTemplateCategoryDaily => 'Daily';

  @override
  String get diaryTemplateCategoryReview => 'Review';

  @override
  String get diaryTemplateCategoryMood => 'Feelings';

  @override
  String get diaryTemplateCategoryLife => 'Life';

  @override
  String get diaryTemplateCategoryWork => 'Work';

  @override
  String get diaryTemplateCategoryOther => 'Other';

  @override
  String get diaryTemplateStripTitle => 'Start from a template';

  @override
  String get diaryTemplateStripAll => 'All';

  @override
  String get diaryTemplateStripDismiss => 'Hide template suggestions';

  @override
  String get diaryTemplateRecommended => 'Suggested';

  @override
  String get diaryTemplateUntitled => 'Untitled template';

  @override
  String diaryTemplateApplied(String name) {
    return 'Applied “$name”';
  }

  @override
  String diaryTemplateAutoApplied(String name) {
    return 'Started with “$name”';
  }

  @override
  String get diaryTemplatePickerTitle => 'Choose a template';

  @override
  String get diaryTemplateFilterAll => 'All';

  @override
  String get diaryTemplateFilterRecommended => 'Suggested';

  @override
  String get diaryTemplateFilterMine => 'Mine';

  @override
  String get diaryTemplatePickerEmpty => 'No templates here';

  @override
  String get diaryTemplatePickerSearchHint => 'Search templates';

  @override
  String diaryTemplatePickerSearchEmpty(String query) {
    return 'No templates match “$query”';
  }

  @override
  String get diaryTemplatePickerUse => 'Use this template';

  @override
  String get diaryTemplatePickerShuffle => 'Another question';

  @override
  String get diaryTemplatePickerPreviewHint =>
      'Dates and questions are filled in for this entry.';

  @override
  String diaryTemplatePresetCapsule(String when) {
    return 'Time capsule: $when';
  }

  @override
  String diaryTemplatePresetEnergy(int level) {
    return 'Energy $level/5';
  }

  @override
  String get diaryTemplateEditedBadge => 'Edited';

  @override
  String get diaryDraftPickerFromTemplate => 'Start from a template';

  @override
  String get diaryTemplatesTitle => 'Diary templates';

  @override
  String diaryTemplatesSettingsSubtitle(int builtIn, int mine) {
    return '$builtIn built-in · $mine of your own';
  }

  @override
  String get diaryTemplatesNewEntryGroup => 'New entries';

  @override
  String get diaryTemplatesStripSwitch => 'Suggest templates for new entries';

  @override
  String get diaryTemplatesStripSwitchSubtitle =>
      'Show “Start from a template” under the title of a blank entry';

  @override
  String get diaryTemplatesAutoApply => 'Apply automatically';

  @override
  String get diaryTemplatesAutoApplyNone => 'Off';

  @override
  String get diaryTemplatesAutoApplyHint =>
      'Blank new entries start with this template outside every time range and when writing for another day. You can undo it each time.';

  @override
  String diaryTemplatesAutoApplyRulesSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count time ranges',
      one: '1 time range',
    );
    return '$_temp0';
  }

  @override
  String diaryTemplatesAutoApplyRulesAndDefault(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count time ranges',
      one: '1 time range',
    );
    return '$_temp0 · otherwise “$name”';
  }

  @override
  String get diaryTemplatesAutoApplyIntro =>
      'Blank new entries start with a template, and you can undo it each time. Time ranges only apply when writing for today.';

  @override
  String get diaryTemplatesAutoApplyRulesGroup => 'By time of day';

  @override
  String get diaryTemplatesAutoApplyOtherGroup => 'Other times';

  @override
  String get diaryTemplatesAutoApplyDefault => 'Default template';

  @override
  String get diaryTemplatesAutoApplyAddRule => 'Add time range';

  @override
  String diaryTemplatesAutoApplyRuleLimit(int max) {
    return 'Up to $max time ranges';
  }

  @override
  String get diaryTemplatesAutoApplyOverlapHint =>
      'When ranges overlap, ones set to specific days win first, then the shorter one.';

  @override
  String diaryTemplatesAutoApplyRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String diaryTemplatesAutoApplyRangeOvernight(String start, String end) {
    return '$start – $end next day';
  }

  @override
  String diaryTemplatesAutoApplyRuleSubtitle(String days, String name) {
    return '$days · $name';
  }

  @override
  String get diaryTemplatesAutoApplyEveryDay => 'Every day';

  @override
  String get diaryTemplatesAutoApplyWorkdays => 'Weekdays';

  @override
  String get diaryTemplatesAutoApplyWeekend => 'Weekends';

  @override
  String get diaryTemplatesAutoApplyDaySeparator => ', ';

  @override
  String get diaryTemplatesAutoApplyMissing => 'Template no longer exists';

  @override
  String get diaryTemplatesAutoApplyEditRule => 'Edit time range';

  @override
  String get diaryTemplatesAutoApplyStart => 'Starts';

  @override
  String get diaryTemplatesAutoApplyEnd => 'Ends';

  @override
  String diaryTemplatesAutoApplyOvernightHint(String end) {
    return 'Overnight, ends at $end the next day';
  }

  @override
  String get diaryTemplatesAutoApplySameTime =>
      'Start and end can\'t be the same time';

  @override
  String get diaryTemplatesAutoApplyDays => 'Days';

  @override
  String get diaryTemplatesAutoApplyDaysHint =>
      'Leave all unselected for every day';

  @override
  String get diaryTemplatesAutoApplyTemplate => 'Template';

  @override
  String get diaryTemplatesAutoApplyRuleDeleted => 'Time range deleted';

  @override
  String get diaryTemplatesMineGroup => 'My templates';

  @override
  String get diaryTemplatesBuiltInGroup => 'Built-in templates';

  @override
  String get diaryTemplatesMineEmpty =>
      'No templates of your own yet. Create one with +, or edit a built-in one directly.';

  @override
  String get diaryTemplatesNew => 'New template';

  @override
  String get diaryTemplatesImport => 'Import a template code';

  @override
  String get diaryTemplatesMoreActions => 'More actions';

  @override
  String get diaryTemplatesDragHandle => 'Drag to reorder';

  @override
  String get diaryTemplatesDuplicate => 'Duplicate';

  @override
  String get diaryTemplatesCopyCode => 'Copy template code';

  @override
  String get diaryTemplatesResetBuiltIn => 'Restore original';

  @override
  String get diaryTemplatesRestoreDeleted => 'Restore deleted built-ins';

  @override
  String diaryTemplatesRestoreDeletedCount(int count) {
    return '$count';
  }

  @override
  String get diaryTemplatesRestoreSheetTitle => 'Deleted built-in templates';

  @override
  String get diaryTemplatesRestoreSheetHint =>
      'Restored templates go back to the built-in list, along with any edits made before deleting them.';

  @override
  String get diaryTemplatesRestore => 'Restore';

  @override
  String get diaryTemplatesRestoreAll => 'Restore all';

  @override
  String diaryTemplatesCopyName(String name) {
    return '$name copy';
  }

  @override
  String diaryTemplatesDeleted(String name) {
    return 'Deleted “$name”';
  }

  @override
  String diaryTemplatesResetDone(String name) {
    return 'Restored the original “$name”';
  }

  @override
  String diaryTemplatesRestoredDone(String name) {
    return 'Restored “$name”';
  }

  @override
  String diaryTemplatesRestoredAllDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Restored $count built-in templates',
      one: 'Restored 1 built-in template',
    );
    return '$_temp0';
  }

  @override
  String get diaryTemplatesCodeCopied => 'Template code copied';

  @override
  String get diaryTemplatesCodeTooLong =>
      'This template is too long for a template code';

  @override
  String get diaryTemplatesImportEmpty => 'No template code in the clipboard';

  @override
  String get diaryTemplatesImportInvalid => 'That\'s not a valid template code';

  @override
  String diaryTemplatesImported(String name) {
    return 'Imported “$name”';
  }

  @override
  String diaryTemplatesImportedNewer(String name) {
    return 'Imported “$name”. It comes from a newer version, so some settings may not apply.';
  }

  @override
  String get diaryTemplatesSaveFailed =>
      'Couldn\'t save the template. Try again';

  @override
  String get diaryTemplateEditorNewTitle => 'New template';

  @override
  String get diaryTemplateEditorEditTitle => 'Edit template';

  @override
  String get diaryTemplateEditorTabContent => 'Content';

  @override
  String get diaryTemplateEditorTabSettings => 'Settings';

  @override
  String get diaryTemplateEditorTitleHint => 'Title (variables allowed)';

  @override
  String get diaryTemplateEditorBodyHint =>
      'Write the body. Headings, lists and to-dos are kept.';

  @override
  String get diaryTemplateEditorAllVariables => 'All variables';

  @override
  String get diaryTemplateEditorVariablesTitle => 'Insert a variable';

  @override
  String get diaryTemplateEditorVariablesHint =>
      'Variables are filled in from the entry\'s date when the template is applied. Lunar dates and solar terms use Chinese names.';

  @override
  String diaryTemplateEditorVariableExample(String example) {
    return 'Today: $example';
  }

  @override
  String get diaryTemplateEditorName => 'Name';

  @override
  String get diaryTemplateEditorNameRequired => 'Give the template a name';

  @override
  String get diaryTemplateEditorDescription => 'Short description';

  @override
  String get diaryTemplateEditorLook => 'Look';

  @override
  String get diaryTemplateEditorCategory => 'Category';

  @override
  String get diaryTemplateEditorIcon => 'Icon';

  @override
  String get diaryTemplateEditorAccent => 'Color';

  @override
  String get diaryTemplateEditorAccentTheme => 'Theme color';

  @override
  String get diaryTemplateEditorPresets => 'Also set when applied';

  @override
  String get diaryTemplateEditorTags => 'Tags';

  @override
  String get diaryTemplateEditorAddTag => 'Add tag';

  @override
  String get diaryTemplateEditorNewTag => 'New tag';

  @override
  String get diaryTemplateEditorTagsHint =>
      'Tags are matched by name. Missing ones are created when the template is applied.';

  @override
  String get diaryTemplateEditorMood => 'Mood';

  @override
  String get diaryTemplateEditorNone => 'None';

  @override
  String get diaryTemplateEditorEnergy => 'Energy';

  @override
  String get diaryTemplateEditorCapsule => 'Time capsule';

  @override
  String get diaryTemplateEditorCapsuleHint =>
      'Counted from the day the template is applied; you can still change it before publishing.';

  @override
  String get diaryTemplateEditorRecommend => 'When to suggest';

  @override
  String get diaryTemplateEditorRecommendHint =>
      'The template moves to the front of the suggestions when every chosen group matches. Within a group, any choice is enough.';

  @override
  String get diaryTemplateEditorSlots => 'Time of day';

  @override
  String get diaryTemplateEditorWeekdays => 'Days of the week';

  @override
  String get diaryTemplateEditorMonth => 'Time of month';

  @override
  String get diaryTemplateSlotMorning => 'Morning';

  @override
  String get diaryTemplateSlotAfternoon => 'Afternoon';

  @override
  String get diaryTemplateSlotEvening => 'Evening';

  @override
  String get diaryTemplateSlotNight => 'Late night';

  @override
  String get diaryTemplateMonthStart => 'First 3 days';

  @override
  String get diaryTemplateMonthEnd => 'Last 3 days';

  @override
  String get diaryTemplateSaveAs => 'Save as template';

  @override
  String get diaryTemplateSaveAsMediaDropped =>
      'Images, recordings and other media aren\'t kept in templates';

  @override
  String get diaryEditorMoreActions => 'More';

  @override
  String get diaryTemplateChoose => 'Choose a template';

  @override
  String get diaryTemplateNeedsBlankEntry =>
      'Templates can only be applied to a blank entry';

  @override
  String get notebookTitle => 'Notebooks';

  @override
  String get notebookSettingsSubtitle =>
      'Organize, reorder and merge your notebooks';

  @override
  String get notebookNew => 'New notebook';

  @override
  String get notebookEditTitle => 'Edit notebook';

  @override
  String get notebookManage => 'Manage';

  @override
  String get notebookSubSectionTitle => 'Sub-notebooks';

  @override
  String get notebookSubCreateShort => 'New';

  @override
  String get notebookSubCreate => 'New sub-notebook';

  @override
  String notebookSubCountSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Contains $count sub-notebooks',
      one: 'Contains 1 sub-notebook',
    );
    return '$_temp0';
  }

  @override
  String notebookNestGoUp(String name) {
    return 'Go to \"$name\"';
  }

  @override
  String get notebookNestPathSeparator => ' › ';

  @override
  String get notebookParentLabel => 'Parent notebook';

  @override
  String get notebookParentNone => 'None (on the shelf)';

  @override
  String get notebookParentFooter =>
      'Its entries also show up when you open the parent. Up to three levels; smart notebooks can sit inside another notebook but can\'t hold sub-notebooks.';

  @override
  String get notebookParentPickerEmpty =>
      'No notebook can hold this one: up to three levels, and smart notebooks can\'t hold sub-notebooks';

  @override
  String notebookParentPrivacyHidden(String name) {
    return 'The parent \"$name\" is hidden from All entries, so this notebook is hidden too';
  }

  @override
  String notebookParentPrivacyLocked(String name) {
    return 'The parent \"$name\" is locked, so this notebook is locked too';
  }

  @override
  String get notebookNestMove => 'Move to…';

  @override
  String get notebookNestMoveHint =>
      'Put it inside another notebook or back on the shelf';

  @override
  String notebookNestMoved(String name) {
    return 'Moved into \"$name\"';
  }

  @override
  String get notebookNestMovedToShelf => 'Moved back to the shelf';

  @override
  String notebookNestDeleteChildrenHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Its $count sub-notebooks move up a level and aren\'t deleted',
      one: 'Its sub-notebook moves up a level and isn\'t deleted',
    );
    return '$_temp0';
  }

  @override
  String get notebookAllDiaries => 'All entries';

  @override
  String get notebookUnfiled => 'Not in a notebook';

  @override
  String get notebookSectionPinned => 'Pinned';

  @override
  String get notebookSectionMine => 'My notebooks';

  @override
  String get notebookSectionSmart => 'Smart notebooks';

  @override
  String get notebookSectionClosed => 'Closed';

  @override
  String notebookEntryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
    );
    return '$_temp0';
  }

  @override
  String get notebookSemanticsSeparator => ', ';

  @override
  String get notebookEmptyHint =>
      'Collect entries from different topics and times into one notebook';

  @override
  String get notebookMissing => 'This notebook no longer exists';

  @override
  String get notebookNameLabel => 'Name';

  @override
  String get notebookNameHint => 'e.g. Travel';

  @override
  String get notebookDescriptionLabel => 'Description';

  @override
  String get notebookDescriptionHint =>
      'Describe this notebook in a sentence (optional)';

  @override
  String get notebookIconLabel => 'Icon';

  @override
  String get notebookIconMore => 'More icons';

  @override
  String get notebookIconLess => 'Show less';

  @override
  String get notebookColorLabel => 'Color';

  @override
  String get notebookColorFollowTheme => 'Follow theme';

  @override
  String get notebookCoverLabel => 'Cover image';

  @override
  String get notebookCoverPick => 'Choose image';

  @override
  String get notebookCoverRemove => 'Remove';

  @override
  String get notebookCoverSectionTitle => 'Cover';

  @override
  String get notebookCoverLayoutTitle => 'Layout';

  @override
  String get notebookCoverLayoutClassic => 'Classic';

  @override
  String get notebookCoverLayoutFullBleed => 'Full bleed';

  @override
  String get notebookCoverLayoutSpine => 'Spine';

  @override
  String get notebookCoverLayoutPlate => 'Label';

  @override
  String get notebookCoverLayoutMinimal => 'Minimal';

  @override
  String get notebookCoverTextureTitle => 'Texture';

  @override
  String get notebookCoverTextureNone => 'None';

  @override
  String get notebookCoverTextureDots => 'Dots';

  @override
  String get notebookCoverTextureLines => 'Lines';

  @override
  String get notebookCoverTextureGrid => 'Grid';

  @override
  String get notebookCoverTextureDiagonal => 'Diagonal';

  @override
  String get notebookCoverFromDiaries => 'From diaries';

  @override
  String get notebookCoverAdjustCrop => 'Adjust framing';

  @override
  String get notebookCoverCropDone => 'Done';

  @override
  String get notebookCoverCropHint => 'Drag to move, pinch to zoom';

  @override
  String get notebookCoverCropHintDesktop => 'Drag to move, scroll to zoom';

  @override
  String get notebookCoverCropZoom => 'Zoom';

  @override
  String get notebookCoverCropLoadFailed => 'Couldn\'t load this image';

  @override
  String get notebookCoverPhotosTitle => 'Choose a cover from diaries';

  @override
  String get notebookCoverPhotosSubtitle =>
      'Images used in this notebook\'s diaries (sub-notebooks included), newest first';

  @override
  String get notebookCoverPhotosEmpty =>
      'No images in this notebook\'s diaries yet';

  @override
  String notebookCoverPhotoItem(int index) {
    return 'Image $index';
  }

  @override
  String get notebookTypeLabel => 'Type';

  @override
  String get notebookTypeManual => 'Regular';

  @override
  String get notebookTypeSmart => 'Smart';

  @override
  String get notebookTypeManualHint => 'Pick the entries to add yourself';

  @override
  String get notebookTypeSmartHint =>
      'Automatically collects entries that match your conditions';

  @override
  String get notebookPrivacyLabel => 'Privacy';

  @override
  String get notebookPrivacyNormal => 'Normal';

  @override
  String get notebookPrivacyHidden => 'Hide from All entries';

  @override
  String get notebookPrivacyHiddenHint => 'Only visible inside this notebook';

  @override
  String get notebookPrivacyLocked => 'Lock';

  @override
  String get notebookPrivacyLockedHint =>
      'Verify your identity to open, and hide from All entries';

  @override
  String get notebookSortLabel => 'Default order';

  @override
  String get notebookSortCreatedDesc => 'Date published, newest first';

  @override
  String get notebookSortCreatedAsc => 'Date published, oldest first';

  @override
  String get notebookSortCreatedAscHint => 'Reads like a book';

  @override
  String get notebookSortUpdatedDesc => 'Recently edited';

  @override
  String get notebookSortBook => 'Book order';

  @override
  String get notebookSortBookHint =>
      'Arranged by hand in the table of contents';

  @override
  String get notebookTemplateLabel => 'Template for new entries';

  @override
  String get notebookTemplateNone => 'None';

  @override
  String get notebookSaveFailed => 'Couldn\'t save. Please try again';

  @override
  String get notebookActionFailed => 'Something went wrong. Please try again';

  @override
  String get notebookMoreActions => 'More actions';

  @override
  String get notebookDragHandle => 'Drag to reorder';

  @override
  String get notebookStatePinned => 'Pinned';

  @override
  String get notebookStateSmart => 'Smart';

  @override
  String get notebookStateHidden => 'Hidden';

  @override
  String get notebookStateLocked => 'Locked';

  @override
  String get notebookStateClosed => 'Closed';

  @override
  String get notebookActionPin => 'Pin';

  @override
  String get notebookActionUnpin => 'Unpin';

  @override
  String get notebookActionClose => 'Close';

  @override
  String get notebookActionCloseHint =>
      'Moves to Closed on the shelf and no longer appears when adding entries';

  @override
  String get notebookActionReopen => 'Reopen';

  @override
  String get notebookActionMerge => 'Merge into…';

  @override
  String get notebookActionConvert => 'Convert to regular notebook';

  @override
  String get notebookActionConvertHint =>
      'Adds the entries that match now; stops updating automatically';

  @override
  String get notebookMergeSheetTitle => 'Merge into which notebook';

  @override
  String get notebookMergeEmpty =>
      'There is no other regular notebook to merge into';

  @override
  String get notebookMergeConfirmTitle => 'Merge notebooks';

  @override
  String notebookMergeConfirm(String source, int count, String target) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
    );
    return 'Move $_temp0 from \"$source\" into \"$target\" and delete \"$source\"?';
  }

  @override
  String get notebookMergeAction => 'Merge';

  @override
  String notebookMerged(String target) {
    return 'Merged into \"$target\"';
  }

  @override
  String notebookDeleteTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get notebookDeleteKeepDiaries => 'Delete notebook only';

  @override
  String notebookDeleteKeepDiariesHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries stay',
      one: '1 entry stays',
    );
    return '$_temp0 in All entries';
  }

  @override
  String get notebookDeleteWithDiaries => 'Also move entries to trash';

  @override
  String get notebookDeleteWithDiariesHint => 'You can restore them from trash';

  @override
  String get notebookDeleteSmartHint => 'Your entries are not affected';

  @override
  String notebookDeleted(String name) {
    return 'Deleted \"$name\"';
  }

  @override
  String notebookSwitcherSemantics(String name) {
    return 'Switch notebook, current: $name';
  }

  @override
  String get notebookScopeDeleted => 'Notebook deleted';

  @override
  String notebookSearchIn(String name) {
    return 'Search in \"$name\"';
  }

  @override
  String notebookSearchRemoveScope(String name) {
    return 'Remove notebook condition: $name';
  }

  @override
  String notebookMetaWords(String words) {
    return '$words words';
  }

  @override
  String notebookMetaSpan(String start, String end) {
    return '$start – $end';
  }

  @override
  String notebookMetaSpanOngoing(String start) {
    return '$start – now';
  }

  @override
  String get notebookHeaderSmartBadge => 'Smart notebook';

  @override
  String get notebookHeaderPrivateBadge => 'Only shown in this notebook';

  @override
  String get notebookEmptyTitle => 'This notebook is empty';

  @override
  String get notebookEmptyCreateHint =>
      'Tap New below to write the first entry';

  @override
  String get notebookViewSortSection => 'Sort in this notebook';

  @override
  String get notebookViewOptionsEntry => 'Switch notebook';

  @override
  String get notebookViewOptionsEntrySubtitle =>
      'Show only one notebook\'s entries, or create one';

  @override
  String notebookUnlockReason(String name) {
    return 'Unlock \"$name\"';
  }

  @override
  String get notebookLockUnsupportedTitle => 'Can\'t open locked notebook';

  @override
  String get notebookLockUnsupportedMessage =>
      'This device has no screen lock, so your identity can\'t be verified and locked notebooks can\'t be opened. Set a screen lock in system settings to open them.';

  @override
  String get notebookLockUnsupportedAction => 'Got it';

  @override
  String notebookLockedTitle(String name) {
    return '\"$name\" is locked';
  }

  @override
  String get notebookLockedSubtitle =>
      'Verify your identity again after leaving the app';

  @override
  String get notebookLockUnlock => 'Unlock';

  @override
  String get notebookLockBackToAll => 'Back to all diaries';

  @override
  String get notebookPrivateDiaryPlaceholder => 'Entry in a private notebook';

  @override
  String get notebookAnniversaryLinkPrivate =>
      'The linked entry is in a private notebook';

  @override
  String get backupImportFolderModeTitle => 'Original notebooks / folders';

  @override
  String get backupImportFolderModeNotebooks => 'Notebooks';

  @override
  String get backupImportFolderModeTags => 'Tags';

  @override
  String get backupImportFolderModeBoth => 'Both';

  @override
  String backupImportFolderModeNotebooksHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Turns the $count source notebooks / folders into notebooks; ones with the same name join your existing notebooks',
      one:
          'Turns the source notebook / folder into a notebook; one with the same name joins your existing notebook',
    );
    return '$_temp0';
  }

  @override
  String get backupImportFolderModeTagsHint =>
      'As before, they become tags with the same names';

  @override
  String get backupImportFolderModeBothHint =>
      'Creates notebooks and tags with the same names';

  @override
  String get notebookEmptyManualHint =>
      'Write the first entry, or pick a few existing ones';

  @override
  String get notebookEmptyWriteFirst => 'Write the first entry';

  @override
  String get notebookEmptyPickExisting => 'Pick existing entries';

  @override
  String get notebookAddDiaries => 'Add entries';

  @override
  String get notebookExportAsBook => 'Export as book';

  @override
  String notebookBookExportedOn(String date) {
    return 'Exported on $date';
  }

  @override
  String get diaryExportBookStructure => 'Book structure';

  @override
  String get diaryExportBookStructureDescription =>
      'Title page, contents and chapter headings';

  @override
  String get notebookContentsUnassignedDropHint =>
      'Drag here to take entries out of chapters';

  @override
  String get notebookChapterAll => 'All';

  @override
  String get notebookChapterUnassigned => 'No chapter';

  @override
  String notebookChapterChip(String title, int count) {
    return '$title · $count';
  }

  @override
  String get notebookContents => 'Contents';

  @override
  String get notebookContentsNewChapter => 'New chapter';

  @override
  String get notebookContentsSelect => 'Select';

  @override
  String get notebookContentsSelectDone => 'Done selecting';

  @override
  String notebookContentsSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
    );
    return '$_temp0';
  }

  @override
  String get notebookContentsNoChapterHint =>
      'Add chapters to split this notebook into parts';

  @override
  String get notebookContentsEmpty => 'No entries in this notebook yet';

  @override
  String get notebookContentsArchived => 'Archived';

  @override
  String get notebookContentsSealed => 'Sealed time capsule';

  @override
  String get notebookContentsDragHandle => 'Drag to reorder';

  @override
  String get notebookContentsChapterActions => 'Chapter actions';

  @override
  String get notebookChapterRename => 'Rename';

  @override
  String get notebookChapterRenameTitle => 'Rename chapter';

  @override
  String get notebookChapterMoveUp => 'Move up';

  @override
  String get notebookChapterMoveDown => 'Move down';

  @override
  String get notebookChapterTitleLabel => 'Chapter name';

  @override
  String get notebookChapterTitleHint => 'e.g. Tokyo';

  @override
  String notebookChapterDeleteConfirm(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Delete chapter \"$title\"? Its $count entries go back to No chapter; no entries are deleted.',
      one:
          'Delete chapter \"$title\"? Its 1 entry goes back to No chapter; no entries are deleted.',
    );
    return '$_temp0';
  }

  @override
  String get notebookContentsMoveToChapter => 'Move to chapter…';

  @override
  String get notebookContentsMoveSheetTitle => 'Move to chapter';

  @override
  String notebookContentsMoved(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Moved $count entries to \"$title\"',
      one: 'Moved 1 entry to \"$title\"',
    );
    return '$_temp0';
  }

  @override
  String get notebookPickerTitle => 'Add to notebook';

  @override
  String get notebookPickerEmpty => 'No notebooks to add to yet';

  @override
  String get notebookPickerDone => 'Done';

  @override
  String notebookPickerPrivateHint(String name) {
    return 'Added to \"$name\". These entries now only show in that notebook';
  }

  @override
  String get notebookSelectionMore => 'More actions';

  @override
  String get notebookRemoveFromCurrent => 'Remove from this notebook';

  @override
  String get notebookMoveTo => 'Move to…';

  @override
  String notebookAddedToCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added to $count notebooks',
      one: 'Added to 1 notebook',
    );
    return '$_temp0';
  }

  @override
  String get notebookMembershipUpdated => 'Notebooks updated';

  @override
  String notebookRemovedFrom(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Removed $count entries from \"$name\"',
      one: 'Removed 1 entry from \"$name\"',
    );
    return '$_temp0';
  }

  @override
  String notebookMovedTo(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Moved $count entries to \"$name\"',
      one: 'Moved 1 entry to \"$name\"',
    );
    return '$_temp0';
  }

  @override
  String get notebookPublishNone => 'Not in a notebook';

  @override
  String notebookWriteInto(String name) {
    return 'Write in $name';
  }

  @override
  String notebookAddPageTitle(String name) {
    return 'Add to \"$name\"';
  }

  @override
  String notebookAddPageDone(int count) {
    return 'Done ($count)';
  }

  @override
  String get notebookAddSearchHint => 'Search entries';

  @override
  String get notebookAddFilterAll => 'All';

  @override
  String get notebookAddFilterRecent => 'Last 30 days';

  @override
  String get notebookAddFilterThisYear => 'This year';

  @override
  String get notebookAddAlreadyIn => 'Already in this notebook';

  @override
  String notebookAddedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count entries',
      one: 'Added 1 entry',
    );
    return '$_temp0';
  }

  @override
  String get notebookAddEmpty => 'No matching entries';

  @override
  String get notebookPreviewNone => 'Not in any notebook yet';

  @override
  String get notebookListSeparator => ', ';

  @override
  String notebookOpenNotebook(String name) {
    return 'Open \"$name\"';
  }

  @override
  String get notebookRulesTitle => 'Rules';

  @override
  String get notebookRulesMatchAll => 'Match all';

  @override
  String get notebookRulesMatchAny => 'Match any';

  @override
  String notebookRulesMatchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Matches $count entries',
      one: 'Matches 1 entry',
    );
    return '$_temp0';
  }

  @override
  String get notebookRulesNeedOne => 'Add at least one rule to save';

  @override
  String notebookRulesLimit(int max) {
    return 'Up to $max rules';
  }

  @override
  String get notebookRulesExamples => 'Start from an example';

  @override
  String get notebookRuleExampleRecent => 'Last 30 days';

  @override
  String get notebookRuleExampleThisMonth => 'This month every year';

  @override
  String get notebookRuleExampleImages => 'Entries with photos';

  @override
  String get notebookRuleExamplePinned => 'Pinned entries';

  @override
  String get notebookRuleAdd => 'Add rule';

  @override
  String get notebookRuleRemove => 'Remove rule';

  @override
  String get notebookRuleDone => 'Done';

  @override
  String get notebookRuleTypeTags => 'Tags';

  @override
  String get notebookRuleTypeTagsHint => 'Has, or lacks, certain tags';

  @override
  String get notebookRuleTypeMood => 'Mood';

  @override
  String get notebookRuleTypeMoodHint => 'Mood is one of these';

  @override
  String get notebookRuleTypeWeather => 'Weather';

  @override
  String get notebookRuleTypeWeatherHint => 'Weather contains some text';

  @override
  String get notebookRuleTypeLocation => 'Location';

  @override
  String get notebookRuleTypeLocationHint => 'Location contains some text';

  @override
  String get notebookRuleTypeKeyword => 'Keyword';

  @override
  String get notebookRuleTypeKeywordHint => 'Title or text contains some words';

  @override
  String get notebookRuleTypeDate => 'Date';

  @override
  String get notebookRuleTypeDateHint =>
      'A date range, recent days or a time every year';

  @override
  String get notebookRuleTypeMedia => 'Media';

  @override
  String get notebookRuleTypeMediaHint =>
      'Has photos, recordings, videos or attachments';

  @override
  String get notebookRuleTypeFlag => 'Cover & pin';

  @override
  String get notebookRuleTypeFlagHint => 'Has a cover or is pinned';

  @override
  String get notebookRuleTagAny => 'Any of';

  @override
  String get notebookRuleTagAll => 'All of';

  @override
  String get notebookRuleTagNone => 'None of';

  @override
  String get notebookRuleNoTags => 'No tags yet';

  @override
  String get notebookRuleWeatherHint => 'e.g. rain';

  @override
  String get notebookRuleLocationHint => 'e.g. Kyoto';

  @override
  String get notebookRuleKeywordHint => 'Words in the title or text';

  @override
  String get notebookRuleDateBetween => 'Date range';

  @override
  String get notebookRuleDateLastDays => 'Recent days';

  @override
  String get notebookRuleDateThisYear => 'This year';

  @override
  String get notebookRuleDateMonth => 'A month every year';

  @override
  String get notebookRuleDateToday => 'This day every year';

  @override
  String get notebookRuleDateTodayHint =>
      'Entries from this month and day in any year';

  @override
  String notebookRuleDaysValue(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get notebookRuleDaysDecrease => 'One day fewer';

  @override
  String get notebookRuleDaysIncrease => 'One day more';

  @override
  String get notebookRuleMediaImage => 'Has photos';

  @override
  String get notebookRuleMediaAudio => 'Has recordings';

  @override
  String get notebookRuleMediaVideo => 'Has videos';

  @override
  String get notebookRuleMediaAttachment => 'Has attachments';

  @override
  String get notebookRuleFlagCover => 'Has a cover';

  @override
  String get notebookRuleFlagPinned => 'Pinned';

  @override
  String notebookRuleSummaryTagsAny(String tags) {
    return 'Tags, any of: $tags';
  }

  @override
  String notebookRuleSummaryTagsAll(String tags) {
    return 'Tags, all of: $tags';
  }

  @override
  String notebookRuleSummaryTagsNone(String tags) {
    return 'Tags, none of: $tags';
  }

  @override
  String notebookRuleSummaryMood(String moods) {
    return 'Mood: $moods';
  }

  @override
  String notebookRuleSummaryWeather(String text) {
    return 'Weather contains \"$text\"';
  }

  @override
  String notebookRuleSummaryLocation(String text) {
    return 'Location contains \"$text\"';
  }

  @override
  String notebookRuleSummaryKeyword(String text) {
    return 'Title or text contains \"$text\"';
  }

  @override
  String notebookRuleSummaryRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String notebookRuleSummaryLastDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Last $days days',
      one: 'Today',
    );
    return '$_temp0';
  }

  @override
  String notebookRuleSummaryMonth(int month, String monthName) {
    return '$monthName every year';
  }

  @override
  String notebookRuleSummaryToday(String date) {
    return 'This day every year ($date)';
  }

  @override
  String get notebookRuleUnknown => 'Unrecognized rule (from a newer version)';

  @override
  String notebookConvertTitle(String name) {
    return 'Convert \"$name\" to a regular notebook?';
  }

  @override
  String notebookConvertMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'The $count entries that match now will be added (archived entries excluded), and the notebook will stop updating automatically.',
      one:
          'The 1 entry that matches now will be added (archived entries excluded), and the notebook will stop updating automatically.',
    );
    return '$_temp0';
  }

  @override
  String get notebookConvertAction => 'Convert';

  @override
  String notebookConverted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Converted; $count entries added',
      one: 'Converted; 1 entry added',
    );
    return '$_temp0';
  }

  @override
  String get notebookSaveRange => 'Save as notebook';

  @override
  String get notebookSaveRangeSmartHint =>
      'Entries in these dates; ones you backfill later join automatically';

  @override
  String notebookSaveRangeManualHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add the $count entries there now',
      one: 'Add the 1 entry there now',
    );
    return '$_temp0';
  }

  @override
  String get notebookSaveSearchAsSmart => 'Save as smart notebook';

  @override
  String get notebookSaveRangeSmart => 'Smart notebook';

  @override
  String get notebookSaveRangeManual => 'Regular notebook';

  @override
  String get notebookGoalLabel => 'Writing goal';

  @override
  String get notebookGoalEnable => 'Set a goal';

  @override
  String get notebookGoalEnableHint =>
      'Shows progress on the notebook header. No reminders.';

  @override
  String get notebookGoalDecrease => 'One fewer';

  @override
  String get notebookGoalIncrease => 'One more';

  @override
  String get notebookGoalPeriodDay => 'Daily';

  @override
  String get notebookGoalPeriodWeek => 'Weekly';

  @override
  String get notebookGoalPeriodMonth => 'Monthly';

  @override
  String notebookGoalSummaryDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries a day',
      one: '1 entry a day',
    );
    return '$_temp0';
  }

  @override
  String notebookGoalSummaryWeek(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries a week',
      one: '1 entry a week',
    );
    return '$_temp0';
  }

  @override
  String notebookGoalSummaryMonth(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries a month',
      one: '1 entry a month',
    );
    return '$_temp0';
  }

  @override
  String notebookGoalProgressDay(int current, int target) {
    return 'Today $current / $target';
  }

  @override
  String notebookGoalProgressWeek(int current, int target) {
    return 'This week $current / $target';
  }

  @override
  String notebookGoalProgressMonth(int current, int target) {
    return 'This month $current / $target';
  }

  @override
  String get notebookGoalMetDay => 'Done for today ✓';

  @override
  String get notebookGoalMetWeek => 'Done this week ✓';

  @override
  String get notebookGoalMetMonth => 'Done this month ✓';

  @override
  String notebookGoalStreakDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count-day streak',
      one: '1-day streak',
    );
    return '$_temp0';
  }

  @override
  String notebookGoalStreakWeek(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count-week streak',
      one: '1-week streak',
    );
    return '$_temp0';
  }

  @override
  String notebookGoalStreakMonth(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count-month streak',
      one: '1-month streak',
    );
    return '$_temp0';
  }

  @override
  String get notebookInsights => 'Stats';

  @override
  String get notebookInsightsEmpty =>
      'No entries to count in this notebook yet';

  @override
  String get notebookInsightsEntries => 'Entries';

  @override
  String get notebookInsightsWords => 'Words';

  @override
  String get notebookInsightsRecordedDays => 'Days written';

  @override
  String get notebookInsightsSpan => 'Time span';

  @override
  String get notebookInsightsPhotos => 'Photos';

  @override
  String get notebookInsightsLongestStreak => 'Longest streak';

  @override
  String notebookInsightsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String notebookInsightsSpanMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String notebookInsightsSpanYears(int years) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$years years',
      one: '1 year',
    );
    return '$_temp0';
  }

  @override
  String notebookInsightsSpanYearsMonths(int years, int months) {
    return '$years yr $months mo';
  }

  @override
  String get notebookInsightsMoods => 'Moods';

  @override
  String notebookInsightsMoodShare(int count, int percent) {
    return '$count · $percent%';
  }

  @override
  String get notebookInsightsTopTags => 'Top tags';

  @override
  String get notebookInsightsRhythm => 'Writing rhythm';

  @override
  String notebookInsightsRhythmBar(String month, int count) {
    return '$month: $count';
  }

  @override
  String notebookInsightsGoalRecent(int met, int total) {
    return 'Met in $met of the last $total periods';
  }

  @override
  String notebookInsightsGoalRecentCaption(int count) {
    return 'Last $count periods';
  }

  @override
  String get notebookInsightsRandom => 'Open a random entry';

  @override
  String get diaryColorPanelDefaultColor => 'Default color';

  @override
  String get diaryColorPanelNoBackground => 'No background';

  @override
  String get diaryColorPanelCustom => 'Custom';

  @override
  String get diaryColorPanelEnterCode => 'Enter color code';

  @override
  String get diaryColorPanelHexHint => 'RRGGBB';

  @override
  String get diaryColorPanelSwatches => 'Swatches';

  @override
  String get diaryColorPanelSaturationValue => 'Saturation and brightness';

  @override
  String get diaryColorPanelHue => 'Hue';

  @override
  String get diaryColorPanelOpacity => 'Opacity';

  @override
  String get diaryColorRed => 'Red';

  @override
  String get diaryColorOrange => 'Orange';

  @override
  String get diaryColorYellow => 'Yellow';

  @override
  String get diaryColorGreen => 'Green';

  @override
  String get diaryColorTeal => 'Teal';

  @override
  String get diaryColorBlue => 'Blue';

  @override
  String get diaryColorIndigo => 'Indigo';

  @override
  String get diaryColorPurple => 'Purple';

  @override
  String get diaryColorPink => 'Pink';

  @override
  String get diaryColorBrown => 'Brown';

  @override
  String get diaryColorGray => 'Gray';

  @override
  String get diaryColorPanelMaterial => 'Material';

  @override
  String get diaryColorDeepPurple => 'Deep purple';

  @override
  String get diaryColorLightBlue => 'Light blue';

  @override
  String get diaryColorCyan => 'Cyan';

  @override
  String get diaryColorLightGreen => 'Light green';

  @override
  String get diaryColorLime => 'Lime';

  @override
  String get diaryColorAmber => 'Amber';

  @override
  String get diaryColorDeepOrange => 'Deep orange';

  @override
  String get diaryColorBlueGray => 'Blue gray';

  @override
  String get diaryColorWhite => 'White';

  @override
  String get diaryColorBlack => 'Black';

  @override
  String diaryColorShade(String family, String tone) {
    return '$family $tone';
  }

  @override
  String diaryColorPanelFamily(String family) {
    return '$family shades';
  }

  @override
  String get tagPickerSearchHint => 'Search tags';

  @override
  String get tagPickerSortTooltip => 'Sort order';

  @override
  String get tagPickerSortCustom => 'Default order';

  @override
  String get tagPickerSortAlphabetical => 'Alphabetical';

  @override
  String tagPickerCreateNamed(String name) {
    return 'Create “$name”';
  }

  @override
  String tagPickerSearchEmpty(String query) {
    return 'No tags match “$query”';
  }

  @override
  String get settingsFeaturesTitle => 'Features';

  @override
  String get settingsFeaturesSubtitle =>
      'Choose the pages and features you use';

  @override
  String get settingsFeaturesPagesGroup => 'Pages';

  @override
  String get settingsFeaturesPagesFooter =>
      'Diaries and Settings always stay. Pages you turn off leave the bottom bar; your data isn\'t affected.';

  @override
  String get settingsFeaturesCalendarSubtitle =>
      'View diaries by month, with lunar dates, holidays and anniversaries';

  @override
  String get settingsFeaturesExploreSubtitle =>
      'Stats, on this day, mood trends and photo wall';

  @override
  String get settingsFeaturesFeaturesGroup => 'Diary features';

  @override
  String get settingsFeaturesFeaturesFooter =>
      'Turning a feature off hides its entries and options. Your data stays and returns when you turn it back on.';

  @override
  String get settingsFeaturesNotebooksSubtitle =>
      'Sort diaries into notebooks, with chapters and book export';

  @override
  String get settingsFeaturesAnniversaries => 'Anniversaries';

  @override
  String get settingsFeaturesAnniversariesSubtitle =>
      'Anniversaries and countdowns, marked on the calendar';

  @override
  String get settingsFeaturesTemplates => 'Diary templates';

  @override
  String get settingsFeaturesTemplatesSubtitle =>
      'Start new diaries from a ready-made format';

  @override
  String get settingsFeaturesTimeCapsules => 'Time capsules';

  @override
  String get settingsFeaturesTimeCapsulesSubtitle =>
      'Write to the future; opens only when it\'s due';

  @override
  String get settingsFeaturesSwipeArchive => 'Swipe to archive';

  @override
  String get settingsFeaturesSwipeArchiveSubtitle =>
      'Swipe a diary card left to archive it, or left in Archive to restore it';

  @override
  String get settingsFeaturesNotebooksOffTitle => 'Turn off notebooks?';

  @override
  String settingsFeaturesNotebooksOffMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'You have $count hidden or locked notebooks. Their diaries stay out of sight until you turn notebooks back on.',
      one:
          'You have 1 hidden or locked notebook. Its diaries stay out of sight until you turn notebooks back on.',
    );
    return '$_temp0';
  }

  @override
  String get settingsFeaturesNotebooksOffConfirm => 'Turn off';

  @override
  String get supportDeveloperTitle => 'Support the developer';

  @override
  String get supportDeveloperEntrySubtitle =>
      'Leave a tip via WeChat or Alipay';

  @override
  String get supportDeveloperIntro =>
      'Jotsy is free, open source and ad-free. If it helps you, you\'re welcome to leave a tip. Tips are entirely voluntary and don\'t unlock anything.';

  @override
  String get supportDeveloperWeChat => 'WeChat';

  @override
  String get supportDeveloperAlipay => 'Alipay';

  @override
  String get supportDeveloperWeChatCodeLabel => 'WeChat tip code';

  @override
  String get supportDeveloperAlipayCodeLabel => 'Alipay payment code';

  @override
  String get supportDeveloperWeChatHint =>
      'Save the code to your photos, then open Scan in WeChat and pick it from the album in the top-right corner.';

  @override
  String get supportDeveloperAlipayHint =>
      'Tap the button below to pay in Alipay directly, or save the code and pick it from your photos in Alipay\'s Scan.';

  @override
  String get supportDeveloperSaveCode => 'Save to photos';

  @override
  String get supportDeveloperOpenWeChat => 'Open WeChat';

  @override
  String get supportDeveloperOpenAlipay => 'Pay in Alipay';

  @override
  String get supportDeveloperAlipayUnavailable =>
      'Couldn\'t open Alipay. Save the code and scan it with a phone that has Alipay.';

  @override
  String get supportDeveloperWeChatUnavailable =>
      'Couldn\'t open WeChat. Open it yourself and scan the code.';

  @override
  String get diaryColorPanelNewColor => 'New color';

  @override
  String get diaryColorPanelManageColors => 'Manage my colors';

  @override
  String get diaryColorPanelManageDone => 'Done';

  @override
  String get diaryColorPanelSavedEmpty =>
      'Colors you mix in Custom are kept here';

  @override
  String get diaryColorPanelSavedMark => 'Saved';

  @override
  String diaryColorPanelSavedColor(String color) {
    return 'My color $color';
  }

  @override
  String diaryColorPanelDocumentColor(String color) {
    return 'Used in this entry $color';
  }

  @override
  String diaryColorPanelRemoveColor(String color) {
    return 'Remove $color';
  }

  @override
  String diaryColorPanelKeepColor(String color) {
    return 'Save $color to my colors';
  }

  @override
  String get homeBarStyleTitle => 'Navigation bar style';

  @override
  String homeBarStyleEntrySubtitle(String name) {
    return 'Current: $name';
  }

  @override
  String homeBarStyleCustomName(String material) {
    return '$material (custom)';
  }

  @override
  String get homeBarStyleTabPresets => 'Presets';

  @override
  String get homeBarStyleTabMaterial => 'Material';

  @override
  String get homeBarStyleTabFloating => 'Floating bar';

  @override
  String get homeBarStyleTabItems => 'Items';

  @override
  String get homeBarStyleTabBehavior => 'Behavior';

  @override
  String get homeBarStylePresetClassic => 'Classic';

  @override
  String get homeBarStylePresetClassicDesc =>
      'The solid bottom bar from before the redesign';

  @override
  String get homeBarStylePresetGlass => 'Glass';

  @override
  String get homeBarStylePresetGlassDesc =>
      'A frosted floating bar with a filled selection';

  @override
  String get homeBarStylePresetClear => 'Clear';

  @override
  String get homeBarStylePresetClearDesc => 'Clearer glass without a shadow';

  @override
  String get homeBarStylePresetFrosted => 'Misty';

  @override
  String get homeBarStylePresetFrostedDesc =>
      'Heavier frost for the clearest labels';

  @override
  String get homeBarStylePresetTinted => 'Tinted';

  @override
  String get homeBarStylePresetTintedDesc =>
      'Glass with a hint of the theme color';

  @override
  String get homeBarStylePresetCompact => 'Compact';

  @override
  String get homeBarStylePresetCompactDesc =>
      'A shorter floating bar with icons only';

  @override
  String get homeBarStyleMaterialSolid => 'Solid';

  @override
  String get homeBarStyleMaterialGlass => 'Glass';

  @override
  String get homeBarStyleGlassFooter =>
      'With glass, the bottom bar floats over the page, and content scrolling beneath it shows through blurred.';

  @override
  String get homeBarStyleHighContrastNote =>
      'High contrast is on in system settings, so the glass shows as opaque for now.';

  @override
  String get homeBarStyleGlassTopBars => 'Glass top bars too';

  @override
  String get homeBarStyleGlassTopBarsSubtitle =>
      'The Diaries, Calendar, Explore and Settings top bars turn frosted as well';

  @override
  String get homeBarStyleTopBarHairline => 'Top bar divider';

  @override
  String get homeBarStyleTopBarHairlineSubtitle =>
      'A thin line along the bottom of the glass top bars';

  @override
  String get homeBarStyleBlur => 'Blur';

  @override
  String get homeBarStyleOpacity => 'Opacity';

  @override
  String get homeBarStyleTint => 'Tint';

  @override
  String get homeBarStyleTintNeutral => 'Neutral';

  @override
  String get homeBarStyleTintTheme => 'Theme';

  @override
  String get homeBarStyleTintColor => 'Glass color';

  @override
  String get homeBarStyleBorder => 'Bottom bar outline';

  @override
  String get homeBarStyleBorderSubtitle =>
      'A thin line along the edge of the floating bar';

  @override
  String get homeBarStyleOutlineGroup => 'Outlines';

  @override
  String get homeBarStyleLineColor => 'Color';

  @override
  String get homeBarStyleLineColorTheme => 'Default';

  @override
  String get homeBarStyleLineColorHighlight => 'Highlight';

  @override
  String get homeBarStyleLineColorPrimary => 'Accent';

  @override
  String get homeBarStyleLineCustomColor => 'Line color';

  @override
  String get homeBarStyleLineWidth => 'Width';

  @override
  String get homeBarStyleShadow => 'Shadow';

  @override
  String get homeBarStyleShadowSubtitle =>
      'A soft shadow beneath the floating bar';

  @override
  String get homeBarStyleFloatingSolidHint =>
      'The floating bar is only used with the glass material.';

  @override
  String get homeBarStyleSwitchToGlass => 'Switch to glass';

  @override
  String get homeBarStyleSizeGroup => 'Size';

  @override
  String get homeBarStyleHeight => 'Height';

  @override
  String get homeBarStyleCornerRadius => 'Corner radius';

  @override
  String get homeBarStyleSideMargin => 'Side margins';

  @override
  String get homeBarStyleBottomGap => 'Distance from bottom';

  @override
  String get homeBarStyleFabGroup => 'New button';

  @override
  String get homeBarStyleFabAbove => 'Above the bar';

  @override
  String get homeBarStyleFabInline => 'Beside the bar';

  @override
  String get homeBarStyleFabFooter =>
      'Only shown on the Diaries page; beside the bar it shows just the icon.';

  @override
  String get homeBarStyleLabels => 'Labels';

  @override
  String get homeBarStyleLabelsAlways => 'Always';

  @override
  String get homeBarStyleLabelsSelected => 'Selected only';

  @override
  String get homeBarStyleLabelsNever => 'Hidden';

  @override
  String get homeBarStyleIconSize => 'Icon size';

  @override
  String get homeBarStyleLabelGap => 'Icon to label spacing';

  @override
  String get homeBarStyleIndicator => 'Selection indicator';

  @override
  String get homeBarStyleIndicatorCapsule => 'Capsule';

  @override
  String get homeBarStyleIndicatorBlock => 'Block';

  @override
  String get homeBarStyleIndicatorNone => 'None';

  @override
  String get homeBarStyleBlockPadding => 'Block padding';

  @override
  String get homeBarStyleItemsFooter =>
      'Switching to glass tightens the icon to label spacing a little.';

  @override
  String get homeBarStyleBehaviorFooter =>
      'Behavior doesn\'t change with presets or style codes.';

  @override
  String get homeBarStyleHideOnScroll => 'Hide the bar when scrolling down';

  @override
  String get homeBarStyleHideOnScrollSubtitle =>
      'Makes room while you scroll down, and comes back when you scroll up or reach the top';

  @override
  String get homeBarStyleHideOnScrollSolidHint =>
      'Hiding on scroll is only available with the floating glass bar.';

  @override
  String get homeBarStyleIndicatorFollows => 'Indicator follows swipes';

  @override
  String get homeBarStyleIndicatorFollowsSubtitle =>
      'When swiping between pages, the selection indicator moves with your finger';

  @override
  String get codeBlockPanelTitle => 'Code block';

  @override
  String get codeBlockLanguageAuto => 'Auto detect';

  @override
  String codeBlockLanguageAutoDetected(String language) {
    return 'Auto · $language';
  }

  @override
  String get codeBlockLanguageNone => 'Unspecified';

  @override
  String get codeBlockLanguagePlain => 'Plain text';

  @override
  String get codeBlockLabelGeneric => 'Code';

  @override
  String get codeBlockCopy => 'Copy code';

  @override
  String get codeBlockCopied => 'Code copied';

  @override
  String codeBlockCopySemantics(String language) {
    return 'Copy $language code';
  }

  @override
  String get codeBlockExit => 'Exit code block';

  @override
  String get codeBlockToText => 'Convert to text';

  @override
  String get codeBlockStyleTitle => 'Code block style';

  @override
  String get codeBlockStyleSubtitle => 'Theme, line numbers, font and header';

  @override
  String get codeBlockStyleTabTheme => 'Theme';

  @override
  String get codeBlockStyleTabDisplay => 'Display';

  @override
  String get codeBlockStyleTabFont => 'Font';

  @override
  String get codeBlockThemeFollowApp => 'Match app';

  @override
  String get codeBlockBrightnessTitle => 'Brightness';

  @override
  String get codeBlockBrightnessSystem => 'Follow theme';

  @override
  String get codeBlockBrightnessLight => 'Light';

  @override
  String get codeBlockBrightnessDark => 'Dark';

  @override
  String get codeBlockLineNumbersTitle => 'Line numbers';

  @override
  String get codeBlockLineNumbersSubtitle => 'Number each line of code';

  @override
  String get codeBlockHeaderTitle => 'Header bar';

  @override
  String get codeBlockHeaderSubtitle =>
      'Show the language and a copy button on top';

  @override
  String get codeBlockAutoDetectTitle => 'Detect language';

  @override
  String get codeBlockAutoDetectSubtitle =>
      'Guess the language of code blocks that don\'t have one';

  @override
  String get codeBlockBorderTitle => 'Border';

  @override
  String get codeBlockBorderSubtitle =>
      'Outline code blocks with a thin border';

  @override
  String get codeBlockRadiusTitle => 'Corner radius';

  @override
  String get codeBlockFontTitle => 'Code font';

  @override
  String get codeBlockFontMono => 'System monospace';

  @override
  String get codeBlockFontBody => 'Body font';

  @override
  String get codeBlockFontMissing =>
      'The selected font file is no longer on this device, so code uses the system monospace font for now. Import it again in Body font & layout, or pick another font.';

  @override
  String get codeBlockFontSizeTitle => 'Font size';

  @override
  String codeBlockFontSizeValue(int percent) {
    return '$percent%';
  }

  @override
  String get codeBlockLineHeightTitle => 'Line height';

  @override
  String get codeBlockPreviewIntro =>
      'Code blocks are highlighted by language, and inline code follows the theme too, like ';

  @override
  String get diaryEditorLinkUrl => 'Link URL';

  @override
  String get diaryEditorInvalidLink => 'Enter a valid link URL';

  @override
  String get diaryEditorRemoveLink => 'Remove link';

  @override
  String get diaryEditorDragBlock => 'Drag block';

  @override
  String get diaryEditorDragBlockHold => 'Hold to drag';

  @override
  String get diaryEditorDragBlockTip =>
      'Hold “Hold to drag”, then slide up or down and the block follows. You can also hold the handle.';

  @override
  String get diaryEditorMoveBlockUp => 'Move block up';

  @override
  String get diaryEditorMoveBlockDown => 'Move block down';

  @override
  String get diaryEditorParagraph => 'Paragraph';

  @override
  String get diaryEditorIndent => 'Indent';

  @override
  String get diaryEditorOutdent => 'Outdent';

  @override
  String get diaryEditorSlashCommands => 'Insert block';

  @override
  String get diaryEditorDivider => 'Divider';

  @override
  String get diaryEditorUnsupportedBlock => 'Unsupported content';

  @override
  String get diaryEditorImageWidth => 'Image width';

  @override
  String get diaryEditorImageHeight => 'Image height';

  @override
  String get diaryEditorHeading1 => 'Heading 1';

  @override
  String get diaryEditorHeading2 => 'Heading 2';

  @override
  String get diaryEditorHeading3 => 'Heading 3';

  @override
  String get diaryEditorCommandGroupText => 'Text';

  @override
  String get diaryEditorCommandGroupList => 'Lists';

  @override
  String get diaryEditorCommandGroupInsert => 'Insert';

  @override
  String get diaryEditorCommandEmpty => 'No matching blocks';

  @override
  String get diaryEditorEmptyLineHint => 'Type / to insert a block';

  @override
  String get diaryEditorCommandTypeToFilter => 'Keep typing to filter';

  @override
  String get diaryCardMenuMoveToNotebook => 'Move to notebook…';

  @override
  String get diaryCardMenuAddToNotebook => 'Add to notebook…';

  @override
  String get diaryEditorDropToInsert => 'Drop to insert';

  @override
  String get dayMoodAwful => 'Awful';

  @override
  String get dayMoodBad => 'Bad';

  @override
  String get dayMoodMeh => 'Meh';

  @override
  String get dayMoodGood => 'Good';

  @override
  String get dayMoodGreat => 'Great';

  @override
  String get calendarDayMoodTitle => 'Mood of the day';

  @override
  String get calendarDayMoodClear => 'Clear';

  @override
  String get calendarDayMoodCleared => 'Mood cleared';

  @override
  String get calendarDayMoodSaveFailed => 'Couldn\'t save the mood. Try again.';

  @override
  String get calendarShowDayMoods => 'Mood of the day';

  @override
  String get calendarShowDayMoodsDescription =>
      'Long-press a date to note how the day felt; the whole date cell turns into that mood.';

  @override
  String backupOverwriteAllDayMoods(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Moods for $count days',
      one: 'Mood for 1 day',
    );
    return '$_temp0';
  }

  @override
  String backupOverwriteExistingDayMoodsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'The moods already noted for $count days will be replaced by the ones in the file.',
      one:
          'The mood already noted for 1 day will be replaced by the one in the file.',
    );
    return '$_temp0';
  }

  @override
  String backupImportModeOverwriteDayMoodsOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Adds new items and replaces the moods already noted for $count days with the ones in the file',
      one:
          'Adds new items and replaces the mood already noted for 1 day with the one in the file',
    );
    return '$_temp0';
  }

  @override
  String backupImportModeOverwriteDayMoodsExtra(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Also replaces the moods noted for $count days',
      one: 'Also replaces the mood noted for 1 day',
    );
    return '$_temp0';
  }

  @override
  String backupImportDayMoodMergeResult(int added) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: 'Day moods: $added added',
      one: 'Day moods: 1 added',
    );
    return '$_temp0';
  }

  @override
  String backupImportDayMoodOverwriteResult(int added, int replaced) {
    return 'Day moods: $added added, $replaced overwritten';
  }

  @override
  String get appSurfaceTitle => 'Background & Material';

  @override
  String get appSurfaceEntryDefault => 'Default';

  @override
  String get appSurfaceEntryImage => 'Image background';

  @override
  String get appSurfaceEntryColor => 'Color background';

  @override
  String get appSurfaceEntryGlass => 'Glass components';

  @override
  String get appSurfaceEntryClassic => 'Classic components';

  @override
  String appSurfaceEntryAreas(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count areas set separately',
      one: '1 area set separately',
    );
    return '$_temp0';
  }

  @override
  String get appSurfaceTabBackground => 'Background';

  @override
  String get appSurfaceTabGlass => 'Glass';

  @override
  String get appSurfaceAreaGlobal => 'Global';

  @override
  String get appSurfaceAreaDiaries => 'Diaries';

  @override
  String get appSurfaceAreaCalendar => 'Calendar';

  @override
  String get appSurfaceAreaExplore => 'Explore';

  @override
  String get appSurfaceAreaSettings => 'Settings';

  @override
  String get appSurfaceAreaEditor => 'Editor';

  @override
  String get appSurfaceAreaPreview => 'Preview';

  @override
  String get appSurfaceAreaOther => 'Other';

  @override
  String appSurfaceAreaCustomized(String area) {
    return '$area, set separately';
  }

  @override
  String get appSurfaceAreaModeFollow => 'Follow global';

  @override
  String get appSurfaceAreaModeOff => 'None';

  @override
  String get appSurfaceAreaModeCustom => 'Custom';

  @override
  String appSurfaceAreaFollowNote(String kind) {
    return 'Uses the global background (currently: $kind).';
  }

  @override
  String get appSurfaceAreaOffNote =>
      'This area shows no background and keeps the theme color.';

  @override
  String get appSurfaceAreaCustomNote =>
      'This area uses its own background set below.';

  @override
  String get appSurfaceAreaPreviewNote =>
      'Only shown when the preview page\'s paper follows the theme.';

  @override
  String get appSurfaceGlobalBackground => 'Global background';

  @override
  String get appSurfaceGlobalFooter =>
      'Every area follows the global background unless you pick it above and set it separately.';

  @override
  String get appSurfaceAreaBackground => 'Own background';

  @override
  String get appSurfaceKindNone => 'None';

  @override
  String get appSurfaceKindColor => 'Color';

  @override
  String get appSurfaceKindImage => 'Image';

  @override
  String get appSurfaceBackgroundColor => 'Background color';

  @override
  String get appSurfaceImagePick => 'Choose image';

  @override
  String get appSurfaceImageChange => 'Change';

  @override
  String get appSurfaceImageRemove => 'Remove';

  @override
  String get appSurfaceImageEmpty => 'No image chosen yet';

  @override
  String get appSurfaceImageMissing =>
      'The image file is missing. Choose it again.';

  @override
  String get appSurfaceImageUnavailable =>
      'Couldn\'t read that image. Choose one stored on this device.';

  @override
  String get appSurfaceImageImportFailed =>
      'Couldn\'t import the image. Try again.';

  @override
  String get appSurfaceFocus => 'Focus';

  @override
  String get appSurfaceFocusHint =>
      'Tap or drag on the image to choose which part stays in view when it\'s cropped.';

  @override
  String appSurfaceFocusSemantics(String x, String y) {
    return 'Background focus: $x% across, $y% down';
  }

  @override
  String get appSurfaceBlur => 'Blur';

  @override
  String get appSurfaceScrimLight => 'Light mode veil';

  @override
  String get appSurfaceScrimDark => 'Dark mode veil';

  @override
  String get appSurfaceGlassStyle => 'Component style';

  @override
  String get appSurfaceGlassClassic => 'Classic';

  @override
  String get appSurfaceGlassGlass => 'Glass';

  @override
  String get appSurfaceGlassStyleFooter =>
      'Glass lets the background and content show through components; Classic keeps them solid.';

  @override
  String get appSurfaceGlassPerComponent => 'Per component';

  @override
  String get appSurfaceComponentTopBars => 'Page top bars';

  @override
  String get appSurfaceComponentToolbar => 'Editor toolbar';

  @override
  String get appSurfaceComponentSheets => 'Bottom sheets';

  @override
  String get appSurfaceComponentDialogs => 'Dialogs';

  @override
  String get appSurfaceComponentCards => 'Cards & groups';

  @override
  String get appSurfaceComponentControls => 'Controls & toasts';

  @override
  String get appSurfaceOverrideFollow => 'Follow';

  @override
  String appSurfaceOverrideFollowResult(String material) {
    return 'Follow ($material)';
  }

  @override
  String get appSurfaceGlassTexture => 'Glass texture';

  @override
  String get appSurfaceGlassOpacity => 'Opacity';

  @override
  String get appSurfaceGlassTint => 'Tint';

  @override
  String get appSurfaceGlassTintNeutral => 'Neutral';

  @override
  String get appSurfaceGlassTintTheme => 'Theme';

  @override
  String get appSurfaceGlassTintColor => 'Glass color';

  @override
  String get appSurfaceGlassBorder => 'Outline';

  @override
  String get appSurfaceGlassBorderSubtitle =>
      'Outlines components on backgrounds close to their color';

  @override
  String get appSurfaceGlassHighContrast =>
      'In high contrast mode, glass automatically turns opaque.';

  @override
  String get appSurfacePreviewLabel => 'Background and material preview';

  @override
  String get appSurfacePreviewCardTitle1 => 'An afternoon walk';

  @override
  String get appSurfacePreviewCardBody1 =>
      'Sunny out, so I took a long loop along the river.';

  @override
  String get appSurfacePreviewCardTitle2 => 'Reading notes';

  @override
  String get appSurfacePreviewCardBody2 =>
      'Saved a few lines I liked to read again later.';

  @override
  String get diaryToolbarSizeTitle => 'Toolbar size';

  @override
  String get diaryToolbarSizeSubtitle =>
      'Buttons and icons scale together. Tools that no longer fit in one row go into More.';

  @override
  String get diaryToolbarSizeSmall => 'Small';

  @override
  String get diaryToolbarSizeStandard => 'Standard';

  @override
  String get diaryToolbarSizeLarge => 'Large';

  @override
  String get diaryToolbarSizeExtraLarge => 'Extra large';

  @override
  String get diaryListStyleNumberedTitle => 'Numbered list style';

  @override
  String get diaryListStyleBulletedTitle => 'Bulleted list style';

  @override
  String get diaryListStyleAuto => 'Automatic (changes with level)';

  @override
  String get diaryListStyleDecimal => 'Numbers 1. 2. 3.';

  @override
  String get diaryListStyleParenthesized =>
      'Numbers in parentheses (1) (2) (3)';

  @override
  String get diaryListStyleCircled => 'Circled numbers ① ② ③';

  @override
  String get diaryListStyleChinese => 'Chinese numerals 一、二、三、';

  @override
  String get diaryListStyleLowerAlpha => 'Lowercase letters a. b. c.';

  @override
  String get diaryListStyleUpperAlpha => 'Uppercase letters A. B. C.';

  @override
  String get diaryListStyleLowerRoman => 'Lowercase Roman numerals i. ii. iii.';

  @override
  String get diaryListStyleUpperRoman => 'Uppercase Roman numerals I. II. III.';

  @override
  String get diaryListStyleDisc => 'Filled dot';

  @override
  String get diaryListStyleCircle => 'Hollow circle';

  @override
  String get diaryListStyleSquare => 'Square';

  @override
  String get diaryListStyleDiamond => 'Diamond';

  @override
  String get diaryListStyleStar => 'Star';

  @override
  String get diaryListStyleArrow => 'Arrow';

  @override
  String get diaryListStyleDash => 'Dash';

  @override
  String get diaryListToBulleted => 'To bulleted list';

  @override
  String get diaryListToNumbered => 'To numbered list';

  @override
  String get diaryListToText => 'Convert to text';
}
