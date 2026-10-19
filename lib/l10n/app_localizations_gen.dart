import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_gen_en.dart';
import 'app_localizations_gen_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations_gen.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// Auto-generated metadata for appTitle.
  ///
  /// In en, this message translates to:
  /// **'Jotsy'**
  String get appTitle;

  /// Auto-generated metadata for navDiaries.
  ///
  /// In en, this message translates to:
  /// **'Diaries'**
  String get navDiaries;

  /// Auto-generated metadata for navCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get navCalendar;

  /// Auto-generated metadata for navExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get navExplore;

  /// Auto-generated metadata for navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Auto-generated metadata for commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Auto-generated metadata for commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// Auto-generated metadata for commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// Auto-generated metadata for commonUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// Auto-generated metadata for commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// Auto-generated metadata for commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// Auto-generated metadata for commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// Auto-generated metadata for commonShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get commonShare;

  /// Auto-generated metadata for commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// Auto-generated metadata for commonCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get commonCreate;

  /// Auto-generated metadata for commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// Auto-generated metadata for commonNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get commonNew;

  /// Auto-generated metadata for commonReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get commonReset;

  /// Auto-generated metadata for commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// Hint text for editable location/weather fields in diary edit panel.
  ///
  /// In en, this message translates to:
  /// **'Enter weather/address, or tap the right button to auto-fetch'**
  String get contextFieldInputHint;

  /// Hint text for editable location field in diary panel.
  ///
  /// In en, this message translates to:
  /// **'Enter address, or tap the right button to auto-fetch'**
  String get contextLocationInputHint;

  /// Hint text for editable weather field in diary panel.
  ///
  /// In en, this message translates to:
  /// **'Enter weather, or tap the right button to auto-fetch'**
  String get contextWeatherInputHint;

  /// Auto-generated metadata for timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get timeJustNow;

  /// Auto-generated metadata for timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min ago'**
  String timeMinutesAgo(int minutes);

  /// Auto-generated metadata for timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours} hr ago'**
  String timeHoursAgo(int hours);

  /// Auto-generated metadata for timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days} days ago'**
  String timeDaysAgo(int days);

  /// Auto-generated metadata for updatedAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Updated {value}'**
  String updatedAtLabel(String value);

  /// Auto-generated metadata for startupPreloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Startup preload failed. Entered home anyway.'**
  String get startupPreloadFailed;

  /// Auto-generated metadata for homeInitFailed.
  ///
  /// In en, this message translates to:
  /// **'Initialization failed: {error}'**
  String homeInitFailed(String error);

  /// Auto-generated metadata for settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Auto-generated metadata for settingsThemeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsThemeMode;

  /// Title for theme color picker in settings.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsThemeColor;

  /// Title for font size setting in settings.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get settingsFontScale;

  /// Subtitle for font size setting in settings.
  ///
  /// In en, this message translates to:
  /// **'Adjust app UI font size'**
  String get settingsFontScaleSubtitle;

  /// Preview text shown in font scale dialog.
  ///
  /// In en, this message translates to:
  /// **'Preview: A short diary line for sizing.'**
  String get settingsFontScalePreview;

  /// Title for configuring how many tags are shown on each diary card.
  ///
  /// In en, this message translates to:
  /// **'Diary card tags'**
  String get settingsDiaryCardTagLimit;

  /// Semantic label announced while diary card display settings are loading.
  ///
  /// In en, this message translates to:
  /// **'Loading diary card settings'**
  String get settingsDiaryCardTagLimitLoading;

  /// Visible subtitle shown when diary card display settings cannot be loaded.
  ///
  /// In en, this message translates to:
  /// **'Setting unavailable'**
  String get settingsDiaryCardTagLimitUnavailable;

  /// Value label used when diary card tags are hidden.
  ///
  /// In en, this message translates to:
  /// **'Do not show tags'**
  String get settingsDiaryCardTagLimitHidden;

  /// Value label showing the maximum number of tags displayed on a diary card.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Show up to 1 tag} other{Show up to {count} tags}}'**
  String settingsDiaryCardTagLimitValue(int count);

  /// Title for selecting bottom tab switch animation curve.
  ///
  /// In en, this message translates to:
  /// **'Tab switch curve'**
  String get settingsTabSwitchCurve;

  /// Subtitle for tab switch curve selection setting.
  ///
  /// In en, this message translates to:
  /// **'Choose the animation feel when switching tabs'**
  String get settingsTabSwitchCurveSubtitle;

  /// Option label for easeOutCirc tab switch animation curve.
  ///
  /// In en, this message translates to:
  /// **'Smooth (Circ)'**
  String get settingsTabSwitchCurveEaseOutCirc;

  /// Option label for easeOutCubic tab switch animation curve.
  ///
  /// In en, this message translates to:
  /// **'Balanced (Cubic)'**
  String get settingsTabSwitchCurveEaseOutCubic;

  /// Option label for linear tab switch animation curve.
  ///
  /// In en, this message translates to:
  /// **'Linear'**
  String get settingsTabSwitchCurveLinear;

  /// Auto-generated metadata for settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// Auto-generated metadata for settingsLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Switch app language'**
  String get settingsLanguageSubtitle;

  /// Settings group title for appearance and language section.
  ///
  /// In en, this message translates to:
  /// **'Appearance & Language'**
  String get settingsAppearanceLanguage;

  /// Title for app lock switch in settings.
  ///
  /// In en, this message translates to:
  /// **'App Lock'**
  String get settingsAppLock;

  /// Subtitle for app lock switch in settings.
  ///
  /// In en, this message translates to:
  /// **'Require authentication every time the app enters foreground'**
  String get settingsAppLockSubtitle;

  /// Prompt shown when local authentication is unsupported.
  ///
  /// In en, this message translates to:
  /// **'This device does not support local authentication, so app lock cannot be enabled.'**
  String get appLockNotSupported;

  /// Title in app lock overlay.
  ///
  /// In en, this message translates to:
  /// **'App Locked'**
  String get appLockTitle;

  /// Subtitle in app lock overlay.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to continue'**
  String get appLockSubtitle;

  /// Manual unlock button label in app lock overlay.
  ///
  /// In en, this message translates to:
  /// **'Unlock Now'**
  String get appLockUnlockNow;

  /// Semantic label while app lock authentication is in progress.
  ///
  /// In en, this message translates to:
  /// **'Unlocking'**
  String get appLockUnlocking;

  /// System auth prompt reason before disabling app lock.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to disable app lock'**
  String get appLockDisableAuthReason;

  /// Message shown when disabling app lock fails verification.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. App lock remains enabled.'**
  String get appLockDisableVerifyFailed;

  /// Auto-generated metadata for settingsEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get settingsEditorTitle;

  /// Subtitle for editor settings entry on root settings page.
  ///
  /// In en, this message translates to:
  /// **'Fonts, spacing, toolbar, and mood emojis'**
  String get settingsEditorSubtitle;

  /// Settings group title for editor-related options.
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get settingsEditorGroup;

  /// Settings group title for editor toolbar and mood options.
  ///
  /// In en, this message translates to:
  /// **'Toolbar & mood'**
  String get settingsEditorToolsGroup;

  /// Setting title for customizing the fixed 10 mood emojis.
  ///
  /// In en, this message translates to:
  /// **'Mood emojis'**
  String get settingsMoodOptionsTitle;

  /// Subtitle for mood emoji setting entry.
  ///
  /// In en, this message translates to:
  /// **'Customize 10 mood choices'**
  String get settingsMoodOptionsSubtitle;

  /// Label for one mood emoji input slot.
  ///
  /// In en, this message translates to:
  /// **'Mood {index}'**
  String settingsMoodOptionsSlotLabel(String index);

  /// Helper text showing the default emoji for one slot.
  ///
  /// In en, this message translates to:
  /// **'Default: {emoji}'**
  String settingsMoodOptionsSlotHelper(String emoji);

  /// Error message when saving mood emoji settings fails.
  ///
  /// In en, this message translates to:
  /// **'Save mood emojis failed: {error}'**
  String settingsMoodOptionsSaveFailed(String error);

  /// Settings entry label for data and privacy section.
  ///
  /// In en, this message translates to:
  /// **'Data & Privacy'**
  String get settingsDataPrivacy;

  /// Settings entry subtitle for data and privacy section.
  ///
  /// In en, this message translates to:
  /// **'Manage backups, app lock, and recycle bin'**
  String get settingsDataPrivacySubtitle;

  /// Secondary page title for data and privacy.
  ///
  /// In en, this message translates to:
  /// **'Data & Privacy'**
  String get settingsDataPrivacyTitle;

  /// Auto-generated metadata for settingsDataManagement.
  ///
  /// In en, this message translates to:
  /// **'Data Management'**
  String get settingsDataManagement;

  /// Auto-generated metadata for settingsDataManagementSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Import/export backups and diary files'**
  String get settingsDataManagementSubtitle;

  /// Auto-generated metadata for settingsTagManagement.
  ///
  /// In en, this message translates to:
  /// **'Tag Management'**
  String get settingsTagManagement;

  /// Auto-generated metadata for settingsTagManagementSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Deleting a tag only unlinks it from diaries'**
  String get settingsTagManagementSubtitle;

  /// Setting title for enabling or disabling remembered diary tag filters.
  ///
  /// In en, this message translates to:
  /// **'Tag memory'**
  String get settingsTagMemory;

  /// Subtitle for tag memory setting explaining that selected diary tag filters are restored.
  ///
  /// In en, this message translates to:
  /// **'Remember selected diary tags and restore them next time'**
  String get settingsTagMemorySubtitle;

  /// Auto-generated metadata for settingsRecycleBin.
  ///
  /// In en, this message translates to:
  /// **'Recycle Bin'**
  String get settingsRecycleBin;

  /// Auto-generated metadata for settingsRecycleBinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore or permanently remove deleted diaries'**
  String get settingsRecycleBinSubtitle;

  /// Auto-generated metadata for settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// Auto-generated metadata for settingsAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'App info, repo, and version'**
  String get settingsAboutSubtitle;

  /// Auto-generated metadata for languageDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Select language'**
  String get languageDialogTitle;

  /// Auto-generated metadata for languageOptionChinese.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get languageOptionChinese;

  /// Auto-generated metadata for languageOptionEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageOptionEnglish;

  /// Auto-generated metadata for aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// Auto-generated metadata for aboutTagline.
  ///
  /// In en, this message translates to:
  /// **'Capture daily moments and feelings'**
  String get aboutTagline;

  /// Auto-generated metadata for aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get aboutVersion;

  /// Auto-generated metadata for aboutPackageName.
  ///
  /// In en, this message translates to:
  /// **'Package'**
  String get aboutPackageName;

  /// Auto-generated metadata for aboutRepository.
  ///
  /// In en, this message translates to:
  /// **'Repository'**
  String get aboutRepository;

  /// Auto-generated metadata for aboutCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get aboutCopied;

  /// Slogan shown in About page header.
  ///
  /// In en, this message translates to:
  /// **'A quiet corner that belongs only to you in a noisy world.'**
  String get aboutPageSlogan;

  /// Action title to open project repository.
  ///
  /// In en, this message translates to:
  /// **'Open-source repository'**
  String get aboutOpenSourceRepo;

  /// Action title to check latest release in About page.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get aboutCheckUpdate;

  /// 关于页“检查更新”行副标题：发现新版本。
  ///
  /// In en, this message translates to:
  /// **'{version} is available'**
  String aboutUpdateSubtitleAvailable(String version);

  /// 关于页“检查更新”行副标题：下载进度。
  ///
  /// In en, this message translates to:
  /// **'Downloading {percent}%'**
  String aboutUpdateSubtitleDownloading(int percent);

  /// 关于页“检查更新”行副标题：安装包已就绪。
  ///
  /// In en, this message translates to:
  /// **'Update downloaded, tap to install'**
  String get aboutUpdateSubtitleReady;

  /// 软件更新页标题。
  ///
  /// In en, this message translates to:
  /// **'App updates'**
  String get appUpdateTitle;

  /// 软件更新页与提示面板：本机已安装的版本。
  ///
  /// In en, this message translates to:
  /// **'Current version {version}'**
  String appUpdateCurrentVersion(String version);

  /// 软件更新页：检查中。
  ///
  /// In en, this message translates to:
  /// **'Checking for updates…'**
  String get appUpdateChecking;

  /// 软件更新页：检查中的说明。
  ///
  /// In en, this message translates to:
  /// **'Trying several routes at once and using the first to answer'**
  String get appUpdateCheckingHint;

  /// 软件更新页与关于页：没有新版本。
  ///
  /// In en, this message translates to:
  /// **'You\'re up to date'**
  String get appUpdateUpToDate;

  /// 软件更新页：上次检查的时间。
  ///
  /// In en, this message translates to:
  /// **'Last checked: {time}'**
  String appUpdateLastChecked(String time);

  /// 有新版本时的小胶囊标记。
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get appUpdateAvailableBadge;

  /// 软件更新页与启动提示：新版本标题。
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available'**
  String appUpdateAvailableTitle(String version);

  /// 新版本的发布日期。
  ///
  /// In en, this message translates to:
  /// **'Released {date}'**
  String appUpdatePublishedOn(String date);

  /// 软件更新页：新版本说明的分组标题。
  ///
  /// In en, this message translates to:
  /// **'What\'s new'**
  String get appUpdateReleaseNotesTitle;

  /// 软件更新页：已是最新时当前版本说明的分组标题。
  ///
  /// In en, this message translates to:
  /// **'In this version'**
  String get appUpdateCurrentNotesTitle;

  /// 版本没有更新说明时的占位文字。
  ///
  /// In en, this message translates to:
  /// **'No release notes for this version.'**
  String get appUpdateNoReleaseNotes;

  /// 在浏览器打开 Release 页面。
  ///
  /// In en, this message translates to:
  /// **'View on GitHub'**
  String get appUpdateViewOnGitHub;

  /// 软件更新页按钮：检查更新。
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get appUpdateActionCheck;

  /// 软件更新页按钮：下载新版本，附安装包大小。
  ///
  /// In en, this message translates to:
  /// **'Download and install ({size})'**
  String appUpdateActionDownload(String size);

  /// 软件更新页按钮：下载新版本（大小未知）。
  ///
  /// In en, this message translates to:
  /// **'Download and install'**
  String get appUpdateActionDownloadNoSize;

  /// 软件更新页按钮：继续取消过的下载。
  ///
  /// In en, this message translates to:
  /// **'Resume download ({percent}% done)'**
  String appUpdateActionResume(int percent);

  /// 软件更新页按钮：取消下载（已下载部分保留）。
  ///
  /// In en, this message translates to:
  /// **'Cancel download'**
  String get appUpdateActionCancel;

  /// 软件更新页按钮：打开系统安装器。
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get appUpdateActionInstall;

  /// 软件更新页按钮：重试失败的步骤。
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get appUpdateActionRetry;

  /// 软件更新页按钮：在浏览器打开 Release 页面。
  ///
  /// In en, this message translates to:
  /// **'Open download page'**
  String get appUpdateActionOpenReleasePage;

  /// 跳过当前新版本，自动检查不再提示。
  ///
  /// In en, this message translates to:
  /// **'Skip this version'**
  String get appUpdateActionSkip;

  /// 软件更新页：当前版本已被跳过。
  ///
  /// In en, this message translates to:
  /// **'Skipped: you won\'t be reminded at startup'**
  String get appUpdateSkippedHint;

  /// 下载进度：已下载 / 总大小。
  ///
  /// In en, this message translates to:
  /// **'{received} / {total}'**
  String appUpdateDownloadProgress(String received, String total);

  /// 下载速度。
  ///
  /// In en, this message translates to:
  /// **'{speed}/s'**
  String appUpdateDownloadSpeed(String speed);

  /// 下载所用线路。
  ///
  /// In en, this message translates to:
  /// **'via {route}'**
  String appUpdateDownloadVia(String route);

  /// 下载完成后校验 SHA-256 与签名。
  ///
  /// In en, this message translates to:
  /// **'Verifying the package…'**
  String get appUpdateVerifying;

  /// 安装包已就绪。
  ///
  /// In en, this message translates to:
  /// **'Downloaded and verified'**
  String get appUpdateReadyToInstall;

  /// 缺少“安装未知应用”权限时的标题。
  ///
  /// In en, this message translates to:
  /// **'Allow installing apps'**
  String get appUpdateInstallPermissionTitle;

  /// 缺少“安装未知应用”权限时的说明。
  ///
  /// In en, this message translates to:
  /// **'Android needs you to allow Jotsy to install unknown apps in system settings. Turn it on and come back here; installation continues automatically.'**
  String get appUpdateInstallPermissionMessage;

  /// 打开“安装未知应用”系统设置。
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get appUpdateInstallPermissionAction;

  /// 打不开系统设置时的提示。
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open system settings. Allow Jotsy to install unknown apps in Settings → Apps → Jotsy.'**
  String get appUpdateInstallPermissionSettingsFailed;

  /// 非 Android 平台的说明。
  ///
  /// In en, this message translates to:
  /// **'In-app installation isn\'t supported on this platform. Get the new version from the download page.'**
  String get appUpdateUnsupportedPlatform;

  /// 没有匹配本机 ABI 的安装包。
  ///
  /// In en, this message translates to:
  /// **'This release has no package for this device\'s processor. Pick one manually on the download page.'**
  String get appUpdateNoCompatibleApk;

  /// 检查失败的标题。
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check for updates'**
  String get appUpdateFailedCheckTitle;

  /// 下载或校验失败的标题。
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get appUpdateFailedDownloadTitle;

  /// 安装失败的标题。
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t install'**
  String get appUpdateFailedInstallTitle;

  /// 所有线路都连不上时的说明。
  ///
  /// In en, this message translates to:
  /// **'Every route failed. Try again later, or choose another route or a custom mirror under Download route below.'**
  String get appUpdateFailureNetwork;

  /// 没有找到已发布版本时的说明。
  ///
  /// In en, this message translates to:
  /// **'No published release was found.'**
  String get appUpdateFailureNotFound;

  /// SHA-256 或大小不符时的说明。
  ///
  /// In en, this message translates to:
  /// **'The download was incomplete or altered (checksum mismatch) and has been deleted. Try again or use another route.'**
  String get appUpdateFailureIntegrity;

  /// 签名或包名不符时的说明。
  ///
  /// In en, this message translates to:
  /// **'The package is signed differently from this app and can\'t replace it. Only download from the official release page.'**
  String get appUpdateFailureSignature;

  /// 安装包版本不高于本机时的说明。
  ///
  /// In en, this message translates to:
  /// **'The downloaded package isn\'t newer than this version.'**
  String get appUpdateFailureNotNewer;

  /// 写入缓存失败时的说明。
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the package. Check your device\'s free storage.'**
  String get appUpdateFailureStorage;

  /// 打不开系统安装器时的说明。
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the system installer. Install manually from the download page.'**
  String get appUpdateFailureInstallUnavailable;

  /// 软件更新页：设置分组标题。
  ///
  /// In en, this message translates to:
  /// **'Update settings'**
  String get appUpdateSettingsTitle;

  /// 软件更新页：自动检查开关。
  ///
  /// In en, this message translates to:
  /// **'Check automatically'**
  String get appUpdateAutoCheck;

  /// 自动检查开关的说明。
  ///
  /// In en, this message translates to:
  /// **'When you open or return to the app, at most every 2 hours; only reads public release info'**
  String get appUpdateAutoCheckSubtitle;

  /// 下载线路设置项与面板标题。
  ///
  /// In en, this message translates to:
  /// **'Download route'**
  String get appUpdateSource;

  /// 下载线路：自动测速择优。
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get appUpdateSourceAuto;

  /// 自动线路的说明。
  ///
  /// In en, this message translates to:
  /// **'Tests every route and uses the fastest; recommended in mainland China'**
  String get appUpdateSourceAutoDescription;

  /// 下载线路：不经镜像直连 GitHub。
  ///
  /// In en, this message translates to:
  /// **'GitHub direct'**
  String get appUpdateSourceDirect;

  /// GitHub 直连的说明。
  ///
  /// In en, this message translates to:
  /// **'No mirror; may be slow or unreachable in mainland China'**
  String get appUpdateSourceDirectDescription;

  /// 内置镜像的说明。
  ///
  /// In en, this message translates to:
  /// **'Public mirror'**
  String get appUpdateSourceMirrorDescription;

  /// 下载线路：用户填写的镜像。
  ///
  /// In en, this message translates to:
  /// **'Custom mirror'**
  String get appUpdateSourceCustom;

  /// 自定义镜像的说明。
  ///
  /// In en, this message translates to:
  /// **'When the built-in mirrors stop working, enter a GitHub proxy that works for you'**
  String get appUpdateSourceCustomDescription;

  /// 自定义镜像输入框提示。
  ///
  /// In en, this message translates to:
  /// **'e.g. https://mirror.example.com/'**
  String get appUpdateSourceCustomHint;

  /// 自定义镜像地址不合法。
  ///
  /// In en, this message translates to:
  /// **'Enter an address starting with https://'**
  String get appUpdateSourceCustomInvalid;

  /// 下载线路面板的说明。
  ///
  /// In en, this message translates to:
  /// **'Mirrors are third-party public services. Every package is checked against its SHA-256 and the app signature after download, so a mirror cannot swap in another app.'**
  String get appUpdateSourceSheetHint;

  /// 启动提示：进入更新页并开始下载。
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get appUpdatePromptUpdate;

  /// 启动提示：关闭，下次再提示。
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get appUpdatePromptLater;

  /// Action title to open issue feedback page.
  ///
  /// In en, this message translates to:
  /// **'Submit issue'**
  String get aboutSubmitIssue;

  /// Action title for copying the QQ feedback group number.
  ///
  /// In en, this message translates to:
  /// **'QQ feedback group'**
  String get aboutQqFeedbackGroup;

  /// QQ feedback group number shown on the About page.
  ///
  /// In en, this message translates to:
  /// **'678136434'**
  String get aboutQqFeedbackGroupSubtitle;

  /// Snackbar shown after copying the QQ feedback group number.
  ///
  /// In en, this message translates to:
  /// **'QQ group number copied to clipboard'**
  String get aboutQqFeedbackGroupCopied;

  /// Action title for privacy description dialog.
  ///
  /// In en, this message translates to:
  /// **'Privacy & data security'**
  String get aboutPrivacyAndData;

  /// Title for privacy description dialog.
  ///
  /// In en, this message translates to:
  /// **'Privacy & data security'**
  String get aboutPrivacyDialogTitle;

  /// Body message for privacy description dialog.
  ///
  /// In en, this message translates to:
  /// **'Your diaries, tags, and media files are stored locally on this device and are not uploaded to cloud services by default.'**
  String get aboutPrivacyDialogMessage;

  /// Action title to open Flutter license page.
  ///
  /// In en, this message translates to:
  /// **'Third-party open-source licenses'**
  String get aboutOpenSourceLicenses;

  /// Fallback snackbar when external link cannot be opened.
  ///
  /// In en, this message translates to:
  /// **'Unable to open link directly. The link has been copied.'**
  String get aboutOpenLinkFallbackCopied;

  /// Footer copyright line for About page.
  ///
  /// In en, this message translates to:
  /// **'© 2026 Jot Project'**
  String get aboutFooterCopyright;

  /// Auto-generated metadata for dataMgmtTitle.
  ///
  /// In en, this message translates to:
  /// **'Data Management'**
  String get dataMgmtTitle;

  /// Auto-generated metadata for dataMgmtExport.
  ///
  /// In en, this message translates to:
  /// **'Export Data'**
  String get dataMgmtExport;

  /// Auto-generated metadata for dataMgmtExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export a ZIP containing diaries, tags, settings, images, recordings, videos, and attachments'**
  String get dataMgmtExportSubtitle;

  /// Auto-generated metadata for dataMgmtImport.
  ///
  /// In en, this message translates to:
  /// **'Import Data'**
  String get dataMgmtImport;

  /// Auto-generated metadata for dataMgmtImportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Import a full backup or a diary file, merging or overwriting'**
  String get dataMgmtImportSubtitle;

  /// Auto-generated metadata for dataMgmtHint.
  ///
  /// In en, this message translates to:
  /// **'To export a single diary, use the More menu on its preview page. Merging only adds diaries this device doesn\'t have and never changes existing ones; overwriting permanently replaces data on this device, so export a backup first.'**
  String get dataMgmtHint;

  /// Auto-generated metadata for dataMgmtBusyExport.
  ///
  /// In en, this message translates to:
  /// **'Exporting data...'**
  String get dataMgmtBusyExport;

  /// Auto-generated metadata for dataMgmtBusyImport.
  ///
  /// In en, this message translates to:
  /// **'Importing data...'**
  String get dataMgmtBusyImport;

  /// Auto-generated metadata for dataMgmtSaveDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Save backup'**
  String get dataMgmtSaveDialogTitle;

  /// Auto-generated metadata for dataMgmtPickDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose backup file'**
  String get dataMgmtPickDialogTitle;

  /// Auto-generated metadata for dataMgmtExportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Data export completed'**
  String get dataMgmtExportSuccess;

  /// Auto-generated metadata for dataMgmtExportCanceled.
  ///
  /// In en, this message translates to:
  /// **'Export canceled'**
  String get dataMgmtExportCanceled;

  /// Auto-generated metadata for dataMgmtExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String dataMgmtExportFailed(String error);

  /// Auto-generated metadata for dataMgmtImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Data import completed'**
  String get dataMgmtImportSuccess;

  /// Auto-generated metadata for dataMgmtImportCanceled.
  ///
  /// In en, this message translates to:
  /// **'Import canceled'**
  String get dataMgmtImportCanceled;

  /// Auto-generated metadata for dataMgmtImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String dataMgmtImportFailed(String error);

  /// Auto-generated metadata for dataMgmtImportAction.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get dataMgmtImportAction;

  /// Auto-generated metadata for dataMgmtBusyLabel.
  ///
  /// In en, this message translates to:
  /// **'Processing data'**
  String get dataMgmtBusyLabel;

  /// Title of the optional export password dialog in data management.
  ///
  /// In en, this message translates to:
  /// **'Set export password (optional)'**
  String get dataMgmtExportPasswordTitle;

  /// Hint text for the export password field.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to skip encryption'**
  String get dataMgmtExportPasswordHint;

  /// Warning shown below the export password field.
  ///
  /// In en, this message translates to:
  /// **'Keep this password safe. Data is encrypted end-to-end on this device and we cannot recover the password. If you forget it, the exported data can never be restored.'**
  String get dataMgmtExportPasswordWarning;

  /// Title of the import password dialog in data management.
  ///
  /// In en, this message translates to:
  /// **'Import password'**
  String get dataMgmtImportPasswordTitle;

  /// Hint text for the import password field.
  ///
  /// In en, this message translates to:
  /// **'Enter the import password'**
  String get dataMgmtImportPasswordHint;

  /// Screen reader label for a color family swatch.
  ///
  /// In en, this message translates to:
  /// **'Palette {index}, {hex}'**
  String colorFamilySwatchLabel(int index, String hex);

  /// Screen reader label for a single color swatch.
  ///
  /// In en, this message translates to:
  /// **'Color {hex}'**
  String colorSwatchLabel(String hex);

  /// Tooltip for pinning the selected diaries.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get diaryPinSelected;

  /// Tooltip for unpinning the selected diaries.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get diaryUnpinSelected;

  /// Screen reader label for the clear button in the tag filter bar.
  ///
  /// In en, this message translates to:
  /// **'Clear tag filters'**
  String get tagFilterClearLabel;

  /// Screen reader label for removing a tag condition in search.
  ///
  /// In en, this message translates to:
  /// **'Remove tag {tagName}'**
  String searchRemoveTagCondition(String tagName);

  /// Tooltip for revealing a password field.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get passwordShow;

  /// Tooltip for hiding a password field.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get passwordHide;

  /// Generic screen reader label for in-page loading indicators.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get commonLoading;

  /// On-this-day memory label showing how many years ago it was.
  ///
  /// In en, this message translates to:
  /// **'{years, plural, =1{1 year ago today} other{{years} years ago today}}'**
  String exploreOnThisDayYearsAgo(int years);

  /// intl DateFormat pattern for date and time precise to the minute (publish time, capsule unlock time).
  ///
  /// In en, this message translates to:
  /// **'yyyy-MM-dd HH:mm'**
  String get dateTimeMinutePattern;

  /// Energy level description for the lowest range.
  ///
  /// In en, this message translates to:
  /// **'Exhausted'**
  String get energyLevelExhausted;

  /// Energy level description for the low range.
  ///
  /// In en, this message translates to:
  /// **'A bit tired'**
  String get energyLevelTired;

  /// Energy level description for the middle range.
  ///
  /// In en, this message translates to:
  /// **'So-so'**
  String get energyLevelSoSo;

  /// Energy level description for the high range.
  ///
  /// In en, this message translates to:
  /// **'Pretty good'**
  String get energyLevelGood;

  /// Energy level description for the highest range.
  ///
  /// In en, this message translates to:
  /// **'Fully charged'**
  String get energyLevelFull;

  /// Snackbar shown when the startup diary preload failed but home was opened.
  ///
  /// In en, this message translates to:
  /// **'Startup preload failed. Entered home anyway.'**
  String get startupPreloadFailedNotice;

  /// Full-screen message when app settings fail to initialize.
  ///
  /// In en, this message translates to:
  /// **'Initialization failed: {error}'**
  String startupInitFailed(String error);

  /// Reason shown in the system authentication prompt for app lock.
  ///
  /// In en, this message translates to:
  /// **'Please authenticate to unlock the app'**
  String get appLockAuthReason;

  /// Auto-generated metadata for autoT0001.
  ///
  /// In en, this message translates to:
  /// **'Loading app'**
  String get autoT0001;

  /// Auto-generated metadata for autoT0002.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get autoT0002;

  /// Auto-generated metadata for autoT0003.
  ///
  /// In en, this message translates to:
  /// **'Reset order'**
  String get autoT0003;

  /// Auto-generated metadata for autoT0004.
  ///
  /// In en, this message translates to:
  /// **'Save order failed: {p0}'**
  String autoT0004(String p0);

  /// Auto-generated metadata for autoT0005.
  ///
  /// In en, this message translates to:
  /// **'Toolbar order'**
  String get autoT0005;

  /// Auto-generated metadata for autoT0006.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get autoT0006;

  /// Auto-generated metadata for autoT0007.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get autoT0007;

  /// Auto-generated metadata for autoT0008.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get autoT0008;

  /// Auto-generated metadata for autoT0009.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get autoT0009;

  /// Auto-generated metadata for autoT0010.
  ///
  /// In en, this message translates to:
  /// **'Underline'**
  String get autoT0010;

  /// Auto-generated metadata for autoT0011.
  ///
  /// In en, this message translates to:
  /// **'Strikethrough'**
  String get autoT0011;

  /// Auto-generated metadata for autoT0012.
  ///
  /// In en, this message translates to:
  /// **'Inline code'**
  String get autoT0012;

  /// Auto-generated metadata for autoT0013.
  ///
  /// In en, this message translates to:
  /// **'Text color'**
  String get autoT0013;

  /// Auto-generated metadata for autoT0014.
  ///
  /// In en, this message translates to:
  /// **'Background color'**
  String get autoT0014;

  /// Auto-generated metadata for autoT0015.
  ///
  /// In en, this message translates to:
  /// **'Clear formatting'**
  String get autoT0015;

  /// Auto-generated metadata for autoT0016.
  ///
  /// In en, this message translates to:
  /// **'Insert image'**
  String get autoT0016;

  /// Auto-generated metadata for autoT0017.
  ///
  /// In en, this message translates to:
  /// **'Header style'**
  String get autoT0017;

  /// Auto-generated metadata for autoT0018.
  ///
  /// In en, this message translates to:
  /// **'Ordered list'**
  String get autoT0018;

  /// Auto-generated metadata for autoT0019.
  ///
  /// In en, this message translates to:
  /// **'Bullet list'**
  String get autoT0019;

  /// Auto-generated metadata for autoT0020.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get autoT0020;

  /// Auto-generated metadata for autoT0021.
  ///
  /// In en, this message translates to:
  /// **'Code block'**
  String get autoT0021;

  /// Auto-generated metadata for autoT0022.
  ///
  /// In en, this message translates to:
  /// **'Quote'**
  String get autoT0022;

  /// Auto-generated metadata for autoT0023.
  ///
  /// In en, this message translates to:
  /// **'Indent'**
  String get autoT0023;

  /// Auto-generated metadata for autoT0024.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get autoT0024;

  /// Auto-generated metadata for autoT0025.
  ///
  /// In en, this message translates to:
  /// **'Unknown deleted time'**
  String get autoT0025;

  /// Auto-generated metadata for autoT0026.
  ///
  /// In en, this message translates to:
  /// **'Some restores failed. Please retry.'**
  String get autoT0026;

  /// Auto-generated metadata for autoT0027.
  ///
  /// In en, this message translates to:
  /// **'Some deletions failed. Please retry.'**
  String get autoT0027;

  /// Auto-generated metadata for autoT0028.
  ///
  /// In en, this message translates to:
  /// **'Permanent delete'**
  String get autoT0028;

  /// Auto-generated metadata for autoT0029.
  ///
  /// In en, this message translates to:
  /// **'Recycle bin'**
  String get autoT0029;

  /// Auto-generated metadata for autoT0030.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get autoT0030;

  /// Auto-generated metadata for autoT0031.
  ///
  /// In en, this message translates to:
  /// **'Recycle bin load failed: {p0}'**
  String autoT0031(String p0);

  /// Auto-generated metadata for autoT0032.
  ///
  /// In en, this message translates to:
  /// **'Recycle bin is empty'**
  String get autoT0032;

  /// Auto-generated metadata for autoT0033.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get autoT0033;

  /// Auto-generated metadata for autoT0034.
  ///
  /// In en, this message translates to:
  /// **'Create tag failed: {p0}'**
  String autoT0034(String p0);

  /// Auto-generated metadata for autoT0035.
  ///
  /// In en, this message translates to:
  /// **'Edit tag failed: {p0}'**
  String autoT0035(String p0);

  /// Auto-generated metadata for autoT0036.
  ///
  /// In en, this message translates to:
  /// **'Delete tag failed: {p0}'**
  String autoT0036(String p0);

  /// Auto-generated metadata for autoT0037.
  ///
  /// In en, this message translates to:
  /// **'Save tag order failed: {p0}'**
  String autoT0037(String p0);

  /// Auto-generated metadata for autoT0038.
  ///
  /// In en, this message translates to:
  /// **'Delete tag'**
  String get autoT0038;

  /// Auto-generated metadata for autoT0039.
  ///
  /// In en, this message translates to:
  /// **'Tag management'**
  String get autoT0039;

  /// Auto-generated metadata for autoT0040.
  ///
  /// In en, this message translates to:
  /// **'Create tag'**
  String get autoT0040;

  /// Auto-generated metadata for autoT0041.
  ///
  /// In en, this message translates to:
  /// **'Create your first tag'**
  String get autoT0041;

  /// Auto-generated metadata for autoT0042.
  ///
  /// In en, this message translates to:
  /// **'Tag load failed: {p0}'**
  String autoT0042(String p0);

  /// Auto-generated metadata for autoT0043.
  ///
  /// In en, this message translates to:
  /// **'Toolbar order'**
  String get autoT0043;

  /// Auto-generated metadata for autoT0044.
  ///
  /// In en, this message translates to:
  /// **'Current top 4: {p0}'**
  String autoT0044(String p0);

  /// Auto-generated metadata for autoT0045.
  ///
  /// In en, this message translates to:
  /// **'Settings load failed: {p0}'**
  String autoT0045(String p0);

  /// Auto-generated metadata for autoT0046.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get autoT0046;

  /// Auto-generated metadata for autoT0047.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get autoT0047;

  /// Auto-generated metadata for autoT0048.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get autoT0048;

  /// Auto-generated metadata for autoT0049.
  ///
  /// In en, this message translates to:
  /// **'What unexpected good thing happened today?'**
  String get autoT0049;

  /// Auto-generated metadata for autoT0050.
  ///
  /// In en, this message translates to:
  /// **'If today had a title, what would it be?'**
  String get autoT0050;

  /// Auto-generated metadata for autoT0051.
  ///
  /// In en, this message translates to:
  /// **'What moment today is most worth remembering?'**
  String get autoT0051;

  /// Auto-generated metadata for autoT0052.
  ///
  /// In en, this message translates to:
  /// **'Media preview'**
  String get autoT0052;

  /// Auto-generated metadata for autoT0053.
  ///
  /// In en, this message translates to:
  /// **'No images to browse'**
  String get autoT0053;

  /// Auto-generated metadata for autoT0054.
  ///
  /// In en, this message translates to:
  /// **'Media gallery'**
  String get autoT0054;

  /// Auto-generated metadata for autoT0055.
  ///
  /// In en, this message translates to:
  /// **'No images to show yet'**
  String get autoT0055;

  /// Auto-generated metadata for autoT0056.
  ///
  /// In en, this message translates to:
  /// **'Load failed, tap to retry'**
  String get autoT0056;

  /// Auto-generated metadata for autoT0057.
  ///
  /// In en, this message translates to:
  /// **'No more images'**
  String get autoT0057;

  /// Auto-generated metadata for autoT0058.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get autoT0058;

  /// Auto-generated metadata for autoT0059.
  ///
  /// In en, this message translates to:
  /// **'Explore data is unavailable'**
  String get autoT0059;

  /// Auto-generated metadata for autoT0060.
  ///
  /// In en, this message translates to:
  /// **'Mood & energy trends'**
  String get autoT0060;

  /// Auto-generated metadata for autoT0061.
  ///
  /// In en, this message translates to:
  /// **'View all images'**
  String get autoT0061;

  /// Auto-generated metadata for autoT0062.
  ///
  /// In en, this message translates to:
  /// **'No images to show yet.'**
  String get autoT0062;

  /// Auto-generated metadata for autoT0063.
  ///
  /// In en, this message translates to:
  /// **'On this day'**
  String get autoT0063;

  /// Auto-generated metadata for autoT0064.
  ///
  /// In en, this message translates to:
  /// **'Write for today'**
  String get autoT0064;

  /// Auto-generated metadata for autoT0065.
  ///
  /// In en, this message translates to:
  /// **'Untitled diary'**
  String get autoT0065;

  /// Auto-generated metadata for autoT0066.
  ///
  /// In en, this message translates to:
  /// **'Total records'**
  String get autoT0066;

  /// Auto-generated metadata for autoT0067.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get autoT0067;

  /// Auto-generated metadata for autoT0068.
  ///
  /// In en, this message translates to:
  /// **'Words this month'**
  String get autoT0068;

  /// Auto-generated metadata for autoT0069.
  ///
  /// In en, this message translates to:
  /// **'Tag cloud'**
  String get autoT0069;

  /// Auto-generated metadata for autoT0070.
  ///
  /// In en, this message translates to:
  /// **'Delete diaries'**
  String get autoT0070;

  /// Auto-generated metadata for autoT0071.
  ///
  /// In en, this message translates to:
  /// **'Unarchive failed. Please try again.'**
  String get autoT0071;

  /// Auto-generated metadata for autoT0072.
  ///
  /// In en, this message translates to:
  /// **'Archive status restored'**
  String get autoT0072;

  /// Auto-generated metadata for autoT0073.
  ///
  /// In en, this message translates to:
  /// **'Delete failed. Please try again.'**
  String get autoT0073;

  /// Auto-generated metadata for autoT0074.
  ///
  /// In en, this message translates to:
  /// **'Deleted {p0} diaries'**
  String autoT0074(String p0);

  /// Auto-generated metadata for autoT0075.
  ///
  /// In en, this message translates to:
  /// **'Diary deleted'**
  String get autoT0075;

  /// Auto-generated metadata for autoT0076.
  ///
  /// In en, this message translates to:
  /// **'Deleted diary restored'**
  String get autoT0076;

  /// Auto-generated metadata for autoT0077.
  ///
  /// In en, this message translates to:
  /// **'Restore failed. Please try again.'**
  String get autoT0077;

  /// Auto-generated metadata for autoT0078.
  ///
  /// In en, this message translates to:
  /// **'Archive failed. Please try again.'**
  String get autoT0078;

  /// Auto-generated metadata for autoT0079.
  ///
  /// In en, this message translates to:
  /// **'Archived {p0} diaries'**
  String autoT0079(String p0);

  /// Auto-generated metadata for autoT0080.
  ///
  /// In en, this message translates to:
  /// **'Archived diary restored'**
  String get autoT0080;

  /// Auto-generated metadata for autoT0084.
  ///
  /// In en, this message translates to:
  /// **'Delete {p0} selected diaries?'**
  String autoT0084(String p0);

  /// Auto-generated metadata for autoT0085.
  ///
  /// In en, this message translates to:
  /// **'No street info'**
  String get autoT0085;

  /// Auto-generated metadata for autoT0086.
  ///
  /// In en, this message translates to:
  /// **'Title and content cannot both be empty'**
  String get autoT0086;

  /// Auto-generated metadata for autoT0087.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {p0}'**
  String autoT0087(String p0);

  /// Auto-generated metadata for autoT0088.
  ///
  /// In en, this message translates to:
  /// **'No valid cover path found'**
  String get autoT0088;

  /// Auto-generated metadata for autoT0092.
  ///
  /// In en, this message translates to:
  /// **'Please get current location first'**
  String get autoT0092;

  /// Auto-generated metadata for autoT0094.
  ///
  /// In en, this message translates to:
  /// **'Delete diary'**
  String get autoT0094;

  /// Auto-generated metadata for autoT0095.
  ///
  /// In en, this message translates to:
  /// **'Untitled diary'**
  String get autoT0095;

  /// Auto-generated metadata for autoT0096.
  ///
  /// In en, this message translates to:
  /// **'Select publish date'**
  String get autoT0096;

  /// Auto-generated metadata for autoT0097.
  ///
  /// In en, this message translates to:
  /// **'Select publish time'**
  String get autoT0097;

  /// Auto-generated metadata for autoT0099.
  ///
  /// In en, this message translates to:
  /// **'{p0} selected'**
  String autoT0099(String p0);

  /// Auto-generated metadata for autoT0100.
  ///
  /// In en, this message translates to:
  /// **'Archived diaries'**
  String get autoT0100;

  /// Auto-generated metadata for autoT0101.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get autoT0101;

  /// Auto-generated metadata for autoT0102.
  ///
  /// In en, this message translates to:
  /// **'Archived list load failed: {p0}'**
  String autoT0102(String p0);

  /// Auto-generated metadata for autoT0103.
  ///
  /// In en, this message translates to:
  /// **'No archived diaries'**
  String get autoT0103;

  /// Auto-generated metadata for autoT0104.
  ///
  /// In en, this message translates to:
  /// **'(No content)'**
  String get autoT0104;

  /// Auto-generated metadata for autoT0105.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get autoT0105;

  /// Auto-generated metadata for autoT0106.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get autoT0106;

  /// Auto-generated metadata for autoT0107.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get autoT0107;

  /// Auto-generated metadata for autoT0108.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get autoT0108;

  /// Auto-generated metadata for autoT0109.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get autoT0109;

  /// Auto-generated metadata for autoT0110.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get autoT0110;

  /// Auto-generated metadata for autoT0111.
  ///
  /// In en, this message translates to:
  /// **'Screenshot failed. Please try again.'**
  String get autoT0111;

  /// Auto-generated metadata for autoT0112.
  ///
  /// In en, this message translates to:
  /// **'Image share failed: {p0}'**
  String autoT0112(String p0);

  /// Auto-generated metadata for autoT0113.
  ///
  /// In en, this message translates to:
  /// **'Delete this diary?'**
  String get autoT0113;

  /// Auto-generated metadata for autoT0114.
  ///
  /// In en, this message translates to:
  /// **'Share image'**
  String get autoT0114;

  /// Auto-generated metadata for autoT0115.
  ///
  /// In en, this message translates to:
  /// **'Share as text'**
  String get autoT0115;

  /// Dialog title when saving an exported diary file.
  ///
  /// In en, this message translates to:
  /// **'Save export file'**
  String get previewExportSaveDialogTitle;

  /// SnackBar text when export is canceled.
  ///
  /// In en, this message translates to:
  /// **'Export canceled'**
  String get previewExportCanceled;

  /// SnackBar text when export fails.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String previewExportFailed(String error);

  /// Auto-generated metadata for autoT0116.
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get autoT0116;

  /// Auto-generated metadata for autoT0117.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get autoT0117;

  /// Auto-generated metadata for autoT0118.
  ///
  /// In en, this message translates to:
  /// **'Last edited'**
  String get autoT0118;

  /// Auto-generated metadata for autoT0119.
  ///
  /// In en, this message translates to:
  /// **'No content yet'**
  String get autoT0119;

  /// Auto-generated metadata for autoT0120.
  ///
  /// In en, this message translates to:
  /// **'Diary'**
  String get autoT0120;

  /// Auto-generated metadata for autoT0121.
  ///
  /// In en, this message translates to:
  /// **'Load failed: {p0}'**
  String autoT0121(String p0);

  /// Auto-generated metadata for autoT0122.
  ///
  /// In en, this message translates to:
  /// **'Diary no longer exists'**
  String get autoT0122;

  /// Auto-generated metadata for autoT0123.
  ///
  /// In en, this message translates to:
  /// **'Diary no longer exists, returning...'**
  String get autoT0123;

  /// Auto-generated metadata for autoT0124.
  ///
  /// In en, this message translates to:
  /// **'Diary not found'**
  String get autoT0124;

  /// Auto-generated metadata for autoT0125.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get autoT0125;

  /// Auto-generated metadata for autoT0126.
  ///
  /// In en, this message translates to:
  /// **'Tag {p0}'**
  String autoT0126(String p0);

  /// Auto-generated metadata for autoT0127.
  ///
  /// In en, this message translates to:
  /// **'Diary load failed: {p0}'**
  String autoT0127(String p0);

  /// Auto-generated metadata for autoT0128.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get autoT0128;

  /// Auto-generated metadata for autoT0129.
  ///
  /// In en, this message translates to:
  /// **'Search title or content'**
  String get autoT0129;

  /// Auto-generated metadata for autoT0130.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get autoT0130;

  /// Auto-generated metadata for autoT0131.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get autoT0131;

  /// Auto-generated metadata for autoT0132.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get autoT0132;

  /// Exit confirmation action that saves current diary changes and then exits the editor.
  ///
  /// In en, this message translates to:
  /// **'Save and exit'**
  String get editSaveAndExit;

  /// Auto-generated metadata for autoT0133.
  ///
  /// In en, this message translates to:
  /// **'Start writing...'**
  String get autoT0133;

  /// Auto-generated metadata for autoT0134.
  ///
  /// In en, this message translates to:
  /// **'New diary'**
  String get autoT0134;

  /// Auto-generated metadata for autoT0135.
  ///
  /// In en, this message translates to:
  /// **'Edit diary'**
  String get autoT0135;

  /// Auto-generated metadata for autoT0136.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get autoT0136;

  /// Auto-generated metadata for autoT0137.
  ///
  /// In en, this message translates to:
  /// **'Save diary'**
  String get autoT0137;

  /// Auto-generated metadata for autoT0138.
  ///
  /// In en, this message translates to:
  /// **'Publish diary'**
  String get autoT0138;

  /// Auto-generated metadata for autoT0139.
  ///
  /// In en, this message translates to:
  /// **'No content'**
  String get autoT0139;

  /// Auto-generated metadata for autoT0140.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get autoT0140;

  /// Auto-generated metadata for autoT0141.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get autoT0141;

  /// Auto-generated metadata for autoT0145.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get autoT0145;

  /// Auto-generated metadata for autoT0146.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get autoT0146;

  /// Auto-generated metadata for autoT0147.
  ///
  /// In en, this message translates to:
  /// **'Waterfall'**
  String get autoT0147;

  /// Auto-generated metadata for autoT0148.
  ///
  /// In en, this message translates to:
  /// **'Archived diaries'**
  String get autoT0148;

  /// Auto-generated metadata for autoT0149.
  ///
  /// In en, this message translates to:
  /// **'Edit tag'**
  String get autoT0149;

  /// Auto-generated metadata for autoT0150.
  ///
  /// In en, this message translates to:
  /// **'Tag name'**
  String get autoT0150;

  /// Auto-generated metadata for autoT0151.
  ///
  /// In en, this message translates to:
  /// **'Choose color'**
  String get autoT0151;

  /// Auto-generated metadata for autoT0152.
  ///
  /// In en, this message translates to:
  /// **'No diaries found'**
  String get autoT0152;

  /// Auto-generated metadata for autoT0153.
  ///
  /// In en, this message translates to:
  /// **'Try another keyword.'**
  String get autoT0153;

  /// Auto-generated metadata for autoT0154.
  ///
  /// In en, this message translates to:
  /// **'No diaries yet'**
  String get autoT0154;

  /// Auto-generated metadata for autoT0155.
  ///
  /// In en, this message translates to:
  /// **'Create diary'**
  String get autoT0155;

  /// Auto-generated metadata for autoT0156.
  ///
  /// In en, this message translates to:
  /// **'Cover load failed'**
  String get autoT0156;

  /// Auto-generated metadata for autoT0157.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get autoT0157;

  /// Auto-generated metadata for autoT0158.
  ///
  /// In en, this message translates to:
  /// **'Swipe up to expand'**
  String get autoT0158;

  /// Auto-generated metadata for autoT0159.
  ///
  /// In en, this message translates to:
  /// **'Swipe down to collapse'**
  String get autoT0159;

  /// Auto-generated metadata for autoT0160.
  ///
  /// In en, this message translates to:
  /// **'Choose tags'**
  String get autoT0160;

  /// Auto-generated metadata for autoT0161.
  ///
  /// In en, this message translates to:
  /// **'Tap to choose a cover (optional)'**
  String get autoT0161;

  /// Auto-generated metadata for autoT0162.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get autoT0162;

  /// Auto-generated metadata for autoT0163.
  ///
  /// In en, this message translates to:
  /// **'Clear cover'**
  String get autoT0163;

  /// Auto-generated metadata for autoT0164.
  ///
  /// In en, this message translates to:
  /// **'No tag selected'**
  String get autoT0164;

  /// Auto-generated metadata for autoT0165.
  ///
  /// In en, this message translates to:
  /// **'Failed to load tags: {p0}'**
  String autoT0165(String p0);

  /// Auto-generated metadata for autoT0166.
  ///
  /// In en, this message translates to:
  /// **'No tags yet, create one first'**
  String get autoT0166;

  /// Auto-generated metadata for autoT0167.
  ///
  /// In en, this message translates to:
  /// **'Here and now'**
  String get autoT0167;

  /// Auto-generated metadata for autoT0168.
  ///
  /// In en, this message translates to:
  /// **'Tap right button to fetch address'**
  String get autoT0168;

  /// Auto-generated metadata for autoT0169.
  ///
  /// In en, this message translates to:
  /// **'Get location'**
  String get autoT0169;

  /// Auto-generated metadata for autoT0170.
  ///
  /// In en, this message translates to:
  /// **'Tap right button to fetch weather'**
  String get autoT0170;

  /// Auto-generated metadata for autoT0171.
  ///
  /// In en, this message translates to:
  /// **'Get weather'**
  String get autoT0171;

  /// Auto-generated metadata for autoT0172.
  ///
  /// In en, this message translates to:
  /// **'Publish time'**
  String get autoT0172;

  /// Auto-generated metadata for autoT0173.
  ///
  /// In en, this message translates to:
  /// **'Auto use current time'**
  String get autoT0173;

  /// Auto-generated metadata for autoT0174.
  ///
  /// In en, this message translates to:
  /// **'Choose publish time'**
  String get autoT0174;

  /// Auto-generated metadata for autoT0175.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get autoT0175;

  /// Auto-generated metadata for autoT0176.
  ///
  /// In en, this message translates to:
  /// **'Publishing...'**
  String get autoT0176;

  /// Auto-generated metadata for autoT0177.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get autoT0177;

  /// Auto-generated metadata for autoT0178.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get autoT0178;

  /// Auto-generated metadata for autoT0179.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get autoT0179;

  /// Auto-generated metadata for autoT0180.
  ///
  /// In en, this message translates to:
  /// **'Back to today'**
  String get autoT0180;

  /// Auto-generated metadata for autoT0181.
  ///
  /// In en, this message translates to:
  /// **'Write for this day'**
  String get autoT0181;

  /// Auto-generated metadata for autoT0182.
  ///
  /// In en, this message translates to:
  /// **'This day is quiet, no records yet.'**
  String get autoT0182;

  /// Auto-generated metadata for autoT0183.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get autoT0183;

  /// Auto-generated metadata for autoT0184.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get autoT0184;

  /// Auto-generated metadata for autoT0185.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get autoT0185;

  /// Auto-generated metadata for autoT0186.
  ///
  /// In en, this message translates to:
  /// **'Recorded an entry'**
  String get autoT0186;

  /// Auto-generated metadata for autoT0187.
  ///
  /// In en, this message translates to:
  /// **'Reset toolbar order to defaults?'**
  String get autoT0187;

  /// Auto-generated metadata for autoT0188.
  ///
  /// In en, this message translates to:
  /// **'Apply inline code style to selected text'**
  String get autoT0188;

  /// Auto-generated metadata for autoT0189.
  ///
  /// In en, this message translates to:
  /// **'Insert or switch to code block'**
  String get autoT0189;

  /// Auto-generated metadata for autoT0190.
  ///
  /// In en, this message translates to:
  /// **'Shows both indent increase/decrease buttons'**
  String get autoT0190;

  /// Auto-generated metadata for autoT0191.
  ///
  /// In en, this message translates to:
  /// **'Restored {p0} diaries'**
  String autoT0191(String p0);

  /// Auto-generated metadata for autoT0192.
  ///
  /// In en, this message translates to:
  /// **'Permanently deleted {p0} diaries'**
  String autoT0192(String p0);

  /// Auto-generated metadata for autoT0193.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete {p0} selected diaries? This cannot be undone.'**
  String autoT0193(String p0);

  /// Auto-generated metadata for autoT0194.
  ///
  /// In en, this message translates to:
  /// **'Deleted at {p0}'**
  String autoT0194(String p0);

  /// Auto-generated metadata for autoT0195.
  ///
  /// In en, this message translates to:
  /// **'Delete tag \"{p0}\"?'**
  String autoT0195(String p0);

  /// Auto-generated metadata for autoT0196.
  ///
  /// In en, this message translates to:
  /// **'What person or thing are you most grateful for today?'**
  String get autoT0196;

  /// Auto-generated metadata for autoT0197.
  ///
  /// In en, this message translates to:
  /// **'Failed to load images. Please try again later.'**
  String get autoT0197;

  /// Auto-generated metadata for autoT0198.
  ///
  /// In en, this message translates to:
  /// **'Keep recording weather, tags, and mood to unlock deeper insights here.'**
  String get autoT0198;

  /// Auto-generated metadata for autoT0199.
  ///
  /// In en, this message translates to:
  /// **'No tag data yet. Try writing diaries with tags.'**
  String get autoT0199;

  /// Auto-generated metadata for autoT0200.
  ///
  /// In en, this message translates to:
  /// **'Delete {p0} selected archived diaries?'**
  String autoT0200(String p0);

  /// Auto-generated metadata for autoT0201.
  ///
  /// In en, this message translates to:
  /// **'Unarchived {p0} diaries'**
  String autoT0201(String p0);

  /// Auto-generated metadata for autoT0203.
  ///
  /// In en, this message translates to:
  /// **'metadata must be a valid JSON object'**
  String get autoT0203;

  /// Auto-generated metadata for autoT0204.
  ///
  /// In en, this message translates to:
  /// **'AMap Web API key missing, please configure amap.web.api.key'**
  String get autoT0204;

  /// Auto-generated metadata for autoT0205.
  ///
  /// In en, this message translates to:
  /// **'QWeather key missing, please configure qweather.api_key'**
  String get autoT0205;

  /// Auto-generated metadata for autoT0206.
  ///
  /// In en, this message translates to:
  /// **'This will soft-delete the diary and it can be restored later. Continue?'**
  String get autoT0206;

  /// Auto-generated metadata for autoT0207.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Exit anyway?'**
  String get autoT0207;

  /// Auto-generated metadata for autoT0208.
  ///
  /// In en, this message translates to:
  /// **'Header style (tap to cycle)'**
  String get autoT0208;

  /// Auto-generated metadata for autoT0210.
  ///
  /// In en, this message translates to:
  /// **'Calendar diaries load failed: {p0}'**
  String autoT0210(String p0);

  /// Auto-generated metadata for autoT0211.
  ///
  /// In en, this message translates to:
  /// **'Take it easy, this day\'s highlights haven\'t happened yet.'**
  String get autoT0211;

  /// Time capsule text for timeCapsuleTitle.
  ///
  /// In en, this message translates to:
  /// **'Time lock'**
  String get timeCapsuleTitle;

  /// Time capsule text for timeCapsuleUnset.
  ///
  /// In en, this message translates to:
  /// **'Not sealed'**
  String get timeCapsuleUnset;

  /// Time capsule text for timeCapsuleSet.
  ///
  /// In en, this message translates to:
  /// **'Unlocks {p0}'**
  String timeCapsuleSet(String p0);

  /// Time capsule text for timeCapsulePickTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose unlock time'**
  String get timeCapsulePickTitle;

  /// Time capsule text for timeCapsulePrecisionMinute.
  ///
  /// In en, this message translates to:
  /// **'Exact time'**
  String get timeCapsulePrecisionMinute;

  /// Time capsule text for timeCapsulePrecisionDate.
  ///
  /// In en, this message translates to:
  /// **'Date only'**
  String get timeCapsulePrecisionDate;

  /// Time capsule text for timeCapsuleQuickWeek.
  ///
  /// In en, this message translates to:
  /// **'One week'**
  String get timeCapsuleQuickWeek;

  /// Time capsule text for timeCapsuleQuickMonth.
  ///
  /// In en, this message translates to:
  /// **'One month'**
  String get timeCapsuleQuickMonth;

  /// Time capsule text for timeCapsuleQuickYear.
  ///
  /// In en, this message translates to:
  /// **'One year'**
  String get timeCapsuleQuickYear;

  /// Time capsule text for timeCapsuleClear.
  ///
  /// In en, this message translates to:
  /// **'Remove time lock'**
  String get timeCapsuleClear;

  /// Time capsule text for timeCapsuleLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Sleeping moment'**
  String get timeCapsuleLockedTitle;

  /// Time capsule text for timeCapsuleCountdownDays.
  ///
  /// In en, this message translates to:
  /// **'Unlocks in {p0}d'**
  String timeCapsuleCountdownDays(String p0);

  /// Time capsule text for timeCapsuleCountdownHours.
  ///
  /// In en, this message translates to:
  /// **'Unlocks in {p0}h'**
  String timeCapsuleCountdownHours(String p0);

  /// Time capsule text for timeCapsuleLockedHint.
  ///
  /// In en, this message translates to:
  /// **'This diary is sealed until {p0}. You can change the unlock time or delete it, but the content stays hidden.'**
  String timeCapsuleLockedHint(String p0);

  /// Time capsule text for timeCapsuleUpdateUnlock.
  ///
  /// In en, this message translates to:
  /// **'Change unlock time'**
  String get timeCapsuleUpdateUnlock;

  /// Time capsule text for timeCapsuleSealAction.
  ///
  /// In en, this message translates to:
  /// **'Seal diary'**
  String get timeCapsuleSealAction;

  /// Time capsule text for timeCapsuleSealing.
  ///
  /// In en, this message translates to:
  /// **'Sealing this moment...'**
  String get timeCapsuleSealing;

  /// Time capsule text for timeCapsuleSealDone.
  ///
  /// In en, this message translates to:
  /// **'Locked until {p0}'**
  String timeCapsuleSealDone(String p0);

  /// Time capsule text for timeCapsuleUnlockedInsight.
  ///
  /// In en, this message translates to:
  /// **'When you wrote this diary, you felt {p0}. How do you feel today?'**
  String timeCapsuleUnlockedInsight(String p0);

  /// Time capsule text for timeCapsuleUnlockedInsightNoMood.
  ///
  /// In en, this message translates to:
  /// **'This was sealed for your future self. How do you feel today?'**
  String get timeCapsuleUnlockedInsightNoMood;

  /// WebDAV server URL field label.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get webDavServerUrl;

  /// WebDAV server URL field hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. https://nas.example.com:5006/webdav/'**
  String get webDavServerUrlHint;

  /// WebDAV username field label.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get webDavUsername;

  /// WebDAV password/token field label.
  ///
  /// In en, this message translates to:
  /// **'Password or Token'**
  String get webDavPassword;

  /// WebDAV remote directory field label.
  ///
  /// In en, this message translates to:
  /// **'Remote directory'**
  String get webDavRemoteDirectory;

  /// WebDAV remote directory field hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. /jotsy/'**
  String get webDavRemoteDirectoryHint;

  /// WebDAV safety and behavior hint.
  ///
  /// In en, this message translates to:
  /// **'Create a dedicated Jotsy folder on your NAS and prefer an app password or token. Upload creates a full ZIP backup; when restoring you can merge into or overwrite local data.'**
  String get webDavHint;

  /// Semantic label for the save-to-gallery action in the image viewer top bar.
  ///
  /// In en, this message translates to:
  /// **'Save to gallery'**
  String get imageViewerSaveToGallery;

  /// Loading hint while saving an image to the gallery.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get imageViewerSaving;

  /// Hint shown after an image is saved to the gallery.
  ///
  /// In en, this message translates to:
  /// **'Saved to gallery'**
  String get imageViewerSaveSuccess;

  /// Hint shown when saving an image fails; error is the failure reason.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String imageViewerSaveFailed(String error);

  /// Hint shown when gallery write permission is denied.
  ///
  /// In en, this message translates to:
  /// **'Gallery permission denied, cannot save'**
  String get imageViewerGalleryPermissionDenied;

  /// Loading hint while preparing to share an image.
  ///
  /// In en, this message translates to:
  /// **'Preparing to share…'**
  String get imageViewerSharing;

  /// Hint shown when sharing an image fails; error is the failure reason.
  ///
  /// In en, this message translates to:
  /// **'Share failed: {error}'**
  String imageViewerShareFailed(String error);

  /// Hint shown when downloading a remote image fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to download image, please check your network and retry'**
  String get imageViewerDownloadFailed;

  /// Tooltip and settings-page label for the diary editor floating toolbar action that inserts the current system time.
  ///
  /// In en, this message translates to:
  /// **'Insert current time'**
  String get diaryToolbarInsertCurrentTime;

  /// Tooltip and settings label for the diary recording toolbar action.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get diaryToolbarRecording;

  /// Accessible label and tooltip for the centered microphone button.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get recordingStart;

  /// Tooltip for pausing microphone capture.
  ///
  /// In en, this message translates to:
  /// **'Pause recording'**
  String get recordingPause;

  /// Tooltip for resuming capture into the same audio file.
  ///
  /// In en, this message translates to:
  /// **'Resume recording'**
  String get recordingResume;

  /// Tooltip for stopping capture and immediately inserting the audio attachment.
  ///
  /// In en, this message translates to:
  /// **'Finish recording'**
  String get recordingFinish;

  /// Tooltip for closing the panel and discarding an uncommitted recording.
  ///
  /// In en, this message translates to:
  /// **'Close recording'**
  String get recordingClose;

  /// Status shown while recording is paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get recordingPaused;

  /// Shown only when the recording plugin confirms this app lacks microphone permission.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is not allowed'**
  String get recordingPermissionDenied;

  /// Shown when microphone capture cannot start or is unexpectedly interrupted.
  ///
  /// In en, this message translates to:
  /// **'Recording failed. Please try again.'**
  String get recordingFailed;

  /// Shown when the audio file cannot be saved or inserted into the document.
  ///
  /// In en, this message translates to:
  /// **'Recording could not be saved. Please try again.'**
  String get recordingSaveFailed;

  /// Title of the audio player embedded in a diary.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get recordingAttachment;

  /// Tooltip for the play button on a diary audio attachment.
  ///
  /// In en, this message translates to:
  /// **'Play recording'**
  String get recordingPlaybackPlay;

  /// Tooltip for the pause button on a diary audio attachment.
  ///
  /// In en, this message translates to:
  /// **'Pause playback'**
  String get recordingPlaybackPause;

  /// Shown for a missing or undecodable diary audio attachment.
  ///
  /// In en, this message translates to:
  /// **'Recording cannot be played'**
  String get recordingPlaybackFailed;

  /// Tooltip or dialog title for renaming an audio recording.
  ///
  /// In en, this message translates to:
  /// **'Rename recording'**
  String get recordingRename;

  /// Hint text for the text field in the rename recording dialog.
  ///
  /// In en, this message translates to:
  /// **'Enter recording name'**
  String get recordingNameHint;

  /// Default title shown for an unnamed audio recording.
  ///
  /// In en, this message translates to:
  /// **'Voice note'**
  String get recordingDefaultTitle;

  /// Status label shown next to the pulsing dot while microphone capture is running.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get recordingStatusRecording;

  /// Hint under the timer before a recording has started.
  ///
  /// In en, this message translates to:
  /// **'Tap the microphone to start'**
  String get recordingIdleHint;

  /// Tooltip for the tool parameter settings button on the toolbar order page.
  ///
  /// In en, this message translates to:
  /// **'Configure tool parameters'**
  String get diaryToolbarToolSettingsTooltip;

  /// Dialog title for configuring the insert-current-time toolbar tool format.
  ///
  /// In en, this message translates to:
  /// **'Configure time format'**
  String get diaryToolbarTimeFormatTitle;

  /// Input label for configuring the insert-current-time toolbar tool format.
  ///
  /// In en, this message translates to:
  /// **'Time format'**
  String get diaryToolbarTimeFormatLabel;

  /// Help text for configuring the insert-current-time toolbar tool format.
  ///
  /// In en, this message translates to:
  /// **'The default format is M月d日 HH:mm. You can use DateFormat tokens such as yyyy, MM, dd, HH, and mm, for example yyyy-MM-dd HH:mm.'**
  String get diaryToolbarTimeFormatHelp;

  /// Preview text in the insert-current-time toolbar tool format dialog.
  ///
  /// In en, this message translates to:
  /// **'Preview: {value}'**
  String diaryToolbarTimeFormatPreview(String value);

  /// Error shown when the insert-current-time toolbar tool format is invalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid time format. Please check the pattern.'**
  String get diaryToolbarTimeFormatInvalid;

  /// Action displayed in the footer of the expanded diary tag filter.
  ///
  /// In en, this message translates to:
  /// **'Collapse tags'**
  String get diaryTagCollapse;

  /// Gesture hint for collapsing tags from the footer without interrupting list scrolling.
  ///
  /// In en, this message translates to:
  /// **'Swipe up here or tap to collapse the tags'**
  String get diaryTagCollapseHint;

  /// Pinned micro-badge text displayed at the top of a diary card
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get diaryPinnedBadge;

  /// Text displayed in publish diary panel when energy level recording is disabled.
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get diaryEnergyUnrecorded;

  /// Accessibility tooltip for the energy toggle switch in publish diary panel.
  ///
  /// In en, this message translates to:
  /// **'Toggle energy level recording'**
  String get diaryEnergySwitchTooltip;

  /// Toolbar action for importing videos into diary content.
  ///
  /// In en, this message translates to:
  /// **'Insert video'**
  String get diaryToolbarInsertVideo;

  /// Toolbar action for importing any file as a diary attachment.
  ///
  /// In en, this message translates to:
  /// **'Insert attachment'**
  String get diaryToolbarInsertAttachment;

  /// Loading label while selected files are copied into application storage.
  ///
  /// In en, this message translates to:
  /// **'Importing files…'**
  String get diaryMediaImporting;

  /// Shown when picking, copying, or inserting diary media fails.
  ///
  /// In en, this message translates to:
  /// **'Files could not be imported. Please try again.'**
  String get diaryMediaImportFailed;

  /// Shown when local diary media import is requested on an unsupported platform.
  ///
  /// In en, this message translates to:
  /// **'File import is not available on this platform.'**
  String get diaryMediaImportUnsupported;

  /// Tooltip for opening a diary attachment with the system file handler.
  ///
  /// In en, this message translates to:
  /// **'Open attachment'**
  String get attachmentOpen;

  /// Subtitle for imported attachments without known file size.
  ///
  /// In en, this message translates to:
  /// **'Tap to open with another app'**
  String get attachmentOpenHint;

  /// Loading label while the system is opening an attachment.
  ///
  /// In en, this message translates to:
  /// **'Opening attachment…'**
  String get attachmentOpening;

  /// Shown for malformed or missing diary attachment files.
  ///
  /// In en, this message translates to:
  /// **'The attachment is missing or unavailable.'**
  String get attachmentFileMissing;

  /// Placeholder shown inside the diary body when an embedded image file is missing or cannot be decoded.
  ///
  /// In en, this message translates to:
  /// **'The image is missing or can\'t be loaded.'**
  String get imageLoadFailed;

  /// Shown when the system has no application for the attachment file type.
  ///
  /// In en, this message translates to:
  /// **'No installed app can open this file.'**
  String get attachmentNoApp;

  /// Shown when the native file handler rejects access to an attachment.
  ///
  /// In en, this message translates to:
  /// **'The attachment could not be accessed.'**
  String get attachmentPermissionDenied;

  /// Shown for unexpected errors when opening diary attachments.
  ///
  /// In en, this message translates to:
  /// **'The attachment could not be opened. Please try again.'**
  String get attachmentOpenFailed;

  /// Loading label while an inline diary video is initialized.
  ///
  /// In en, this message translates to:
  /// **'Loading video…'**
  String get videoLoading;

  /// Tooltip for playing an inline diary video.
  ///
  /// In en, this message translates to:
  /// **'Play video'**
  String get videoPlay;

  /// Tooltip for pausing an inline diary video.
  ///
  /// In en, this message translates to:
  /// **'Pause video'**
  String get videoPause;

  /// Accessibility label for the inline video seek slider.
  ///
  /// In en, this message translates to:
  /// **'Video progress'**
  String get videoProgress;

  /// Subtitle offering a system file handler when inline video playback fails.
  ///
  /// In en, this message translates to:
  /// **'Video cannot be played here. Tap to open with another app.'**
  String get videoPlaybackFailed;

  /// Tooltip for saving the diary video to the system gallery after confirmation.
  ///
  /// In en, this message translates to:
  /// **'Export video'**
  String get videoExport;

  /// Title of the confirmation dialog before exporting a video.
  ///
  /// In en, this message translates to:
  /// **'Export video'**
  String get videoExportConfirmTitle;

  /// Confirmation message naming the video that will be saved to the system gallery.
  ///
  /// In en, this message translates to:
  /// **'Save \"{name}\" to your gallery?'**
  String videoExportConfirmMessage(String name);

  /// Loading label while a confirmed video export is in progress.
  ///
  /// In en, this message translates to:
  /// **'Exporting video…'**
  String get videoExporting;

  /// Confirmation that the diary video has been saved to the system gallery.
  ///
  /// In en, this message translates to:
  /// **'Video saved to gallery'**
  String get videoExportSuccess;

  /// Shown when the video source cannot be found or is empty during export.
  ///
  /// In en, this message translates to:
  /// **'The video file is missing or empty.'**
  String get videoExportFileMissing;

  /// Shown when the system denies writing the exported video to the gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery access is not allowed. Video could not be exported.'**
  String get videoExportPermissionDenied;

  /// Shown when gallery video export fails because the device storage is full.
  ///
  /// In en, this message translates to:
  /// **'Not enough storage to export this video.'**
  String get videoExportNotEnoughSpace;

  /// Shown when the system gallery rejects the video's format.
  ///
  /// In en, this message translates to:
  /// **'This video format cannot be saved to the gallery.'**
  String get videoExportUnsupportedFormat;

  /// Shown when a remote video cannot be downloaded before gallery export.
  ///
  /// In en, this message translates to:
  /// **'Video download failed. Please try again.'**
  String get videoExportDownloadFailed;

  /// Shown for an unexpected error during video export.
  ///
  /// In en, this message translates to:
  /// **'Video could not be exported. Please try again.'**
  String get videoExportFailed;

  /// Tooltip and page title for fullscreen diary video playback.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen playback'**
  String get videoFullscreen;

  /// Tooltip for returning to the diary from fullscreen video playback.
  ///
  /// In en, this message translates to:
  /// **'Exit fullscreen'**
  String get videoExitFullscreen;

  /// Label for expanding the diary location address detail options.
  ///
  /// In en, this message translates to:
  /// **'Address detail'**
  String get locationPrecisionTitle;

  /// Address detail option showing only the city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get locationPrecisionCity;

  /// Address detail option including the district or county.
  ///
  /// In en, this message translates to:
  /// **'District / county'**
  String get locationPrecisionDistrict;

  /// Address detail option including the administrative subdistrict or township, rather than a road.
  ///
  /// In en, this message translates to:
  /// **'Subdistrict / town'**
  String get locationPrecisionTownship;

  /// Address detail option including the road name without a house number.
  ///
  /// In en, this message translates to:
  /// **'Road'**
  String get locationPrecisionStreet;

  /// Address detail option including the road and house number when available.
  ///
  /// In en, this message translates to:
  /// **'House number'**
  String get locationPrecisionAddress;

  /// Hint when automatic location is unavailable on the current platform.
  ///
  /// In en, this message translates to:
  /// **'Automatic location is not supported on this platform.'**
  String get locationUnsupported;

  /// Hint when foreground location permission is denied or undetermined.
  ///
  /// In en, this message translates to:
  /// **'Location permission was denied. Allow location access and try again; approximate location is also supported.'**
  String get locationPermissionDenied;

  /// Hint when the OS will no longer show a location permission prompt.
  ///
  /// In en, this message translates to:
  /// **'Location permission is blocked. Enable it in system settings, then return and try again.'**
  String get locationPermissionDeniedForever;

  /// Hint when the device location service is disabled, including during a request.
  ///
  /// In en, this message translates to:
  /// **'Location services are off. Turn them on in system settings, then try again.'**
  String get locationServiceDisabled;

  /// Hint when coordinate conversion or reverse geocoding fails due to a network error.
  ///
  /// In en, this message translates to:
  /// **'The address request failed or timed out. Check your connection and try again.'**
  String get locationNetworkError;

  /// Hint when the address API rejects a request; technical details stay in the service exception.
  ///
  /// In en, this message translates to:
  /// **'The address service is temporarily unavailable. Please try again later.'**
  String get locationApiError;

  /// Hint when the address service returns malformed or empty data.
  ///
  /// In en, this message translates to:
  /// **'No usable address was returned. Please try again later or enter a place manually.'**
  String get locationAddressInvalid;

  /// Hint after both fused and system location providers fail to return a usable position.
  ///
  /// In en, this message translates to:
  /// **'Could not get your location. Try again where the satellite signal is stronger, or enter a place manually.'**
  String get locationUnavailable;

  /// Diary list sort option that orders diaries by their last update time.
  ///
  /// In en, this message translates to:
  /// **'Date updated'**
  String get diarySortFieldUpdated;

  /// Diary list sort option that orders diaries by the publish time chosen when publishing (the unlock time for time capsules).
  ///
  /// In en, this message translates to:
  /// **'Date published'**
  String get diarySortFieldPublished;

  /// Diary list sort option that orders diaries by title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get diarySortFieldTitle;

  /// Diary list sort direction button for descending order (newest first, or titles Z to A).
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get diarySortDescending;

  /// Diary list sort direction button for ascending order (oldest first, or titles A to Z).
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get diarySortAscending;

  /// Explains the current diary list order: by update time, descending.
  ///
  /// In en, this message translates to:
  /// **'Most recently updated first'**
  String get diarySortHintUpdatedDesc;

  /// Explains the current diary list order: by update time, ascending.
  ///
  /// In en, this message translates to:
  /// **'Least recently updated first'**
  String get diarySortHintUpdatedAsc;

  /// Explains the current diary list order: by publish time, descending.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get diarySortHintPublishedDesc;

  /// Explains the current diary list order: by publish time, ascending.
  ///
  /// In en, this message translates to:
  /// **'Oldest first'**
  String get diarySortHintPublishedAsc;

  /// Explains the current diary list order: by title A to Z, with untitled diaries always last.
  ///
  /// In en, this message translates to:
  /// **'Titles A → Z, untitled last'**
  String get diarySortHintTitleAsc;

  /// Explains the current diary list order: by title Z to A, with untitled diaries always last.
  ///
  /// In en, this message translates to:
  /// **'Titles Z → A, untitled last'**
  String get diarySortHintTitleDesc;

  /// Tooltip of the editor floating toolbar button that expands the panel holding the tools that do not fit on the toolbar row.
  ///
  /// In en, this message translates to:
  /// **'More tools'**
  String get diaryToolbarMoreTools;

  /// Tooltip of the editor floating toolbar button while the panel of extra tools is expanded; tapping it collapses the panel.
  ///
  /// In en, this message translates to:
  /// **'Hide more tools'**
  String get diaryToolbarHideMoreTools;

  /// Accessibility value of the More tools button when a tool inside the collapsed panel is active at the cursor, e.g. a quote or a list.
  ///
  /// In en, this message translates to:
  /// **'Formatting in effect'**
  String get diaryToolbarMoreToolsActive;

  /// Divider in the toolbar order settings page. Tools above it stay on the editor toolbar row; tools below it are in the More panel, based on the current screen width.
  ///
  /// In en, this message translates to:
  /// **'Tools below go into More'**
  String get diaryToolbarOverflowDivider;

  /// Busy label while the selected backup or diary file is read and checked before choosing how to import it.
  ///
  /// In en, this message translates to:
  /// **'Reading file...'**
  String get backupBusyInspect;

  /// Title of the sheet that summarizes an import file and lets the user choose merge or overwrite.
  ///
  /// In en, this message translates to:
  /// **'How to import'**
  String get backupImportOptionsTitle;

  /// Import file type: a full backup with all diaries, tags, media and settings.
  ///
  /// In en, this message translates to:
  /// **'Full backup'**
  String get backupImportKindFull;

  /// Import file type: a diary file exported from a single diary, without app settings.
  ///
  /// In en, this message translates to:
  /// **'Diary file'**
  String get backupImportKindDiary;

  /// Counts of diaries and tags in the import file.
  ///
  /// In en, this message translates to:
  /// **'{diaries, plural, =1{1 diary} other{{diaries} diaries}} · {tags, plural, =1{1 tag} other{{tags} tags}}'**
  String backupImportSummary(int diaries, int tags);

  /// Note that a full backup also contains app settings.
  ///
  /// In en, this message translates to:
  /// **'Includes app settings'**
  String get backupImportIncludesSettings;

  /// How many diaries in the import file already exist on this device (same diary).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 of them is already on this device} other{{count} of them are already on this device}}'**
  String backupImportExistingCount(int count);

  /// Import option that keeps all local data and only adds diaries this device does not have.
  ///
  /// In en, this message translates to:
  /// **'Merge (recommended)'**
  String get backupImportModeMerge;

  /// Description of the merge import option.
  ///
  /// In en, this message translates to:
  /// **'Keeps everything on this device. Only diaries it doesn\'t have are added; existing ones stay as they are.'**
  String get backupImportModeMergeDescription;

  /// Import option that adds new diaries and replaces diaries that already exist on this device.
  ///
  /// In en, this message translates to:
  /// **'Overwrite existing diaries'**
  String get backupImportModeOverwriteExisting;

  /// Description of the overwrite-existing import option.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Adds new diaries and replaces the existing diary with the version in the file} other{Adds new diaries and replaces the {count} existing diaries with the versions in the file}}'**
  String backupImportModeOverwriteExistingDescription(int count);

  /// Import option that erases all local data and replaces it with the full backup.
  ///
  /// In en, this message translates to:
  /// **'Overwrite all data'**
  String get backupImportModeReplaceAll;

  /// Description of the overwrite-all import option.
  ///
  /// In en, this message translates to:
  /// **'Erases all diaries, tags, media and settings on this device and replaces them with the backup'**
  String get backupImportModeReplaceAllDescription;

  /// Title of the severe warning shown before an import replaces all local data.
  ///
  /// In en, this message translates to:
  /// **'Overwrite all data?'**
  String get backupOverwriteAllTitle;

  /// Title of the severe warning shown before an import replaces diaries that already exist on this device.
  ///
  /// In en, this message translates to:
  /// **'Overwrite existing diaries?'**
  String get backupOverwriteExistingTitle;

  /// Emphasized line in the overwrite warning.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone'**
  String get backupOverwriteIrreversible;

  /// Lead-in of the list of local data erased by an overwrite-all import.
  ///
  /// In en, this message translates to:
  /// **'The following data on this device will be permanently deleted and replaced with the backup:'**
  String get backupOverwriteAllLead;

  /// List item: how many local diaries an overwrite-all import deletes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 diary} other{{count} diaries}} (including archived and deleted ones)'**
  String backupOverwriteAllDiaries(int count);

  /// List item: how many local tags an overwrite-all import deletes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 tag} other{{count} tags}}'**
  String backupOverwriteAllTags(int count);

  /// List item: local media files deleted by an overwrite-all import.
  ///
  /// In en, this message translates to:
  /// **'All images, recordings, videos and attachments'**
  String get backupOverwriteAllMedia;

  /// List item: local settings and the new-diary draft replaced by an overwrite-all import.
  ///
  /// In en, this message translates to:
  /// **'App settings and the unpublished draft'**
  String get backupOverwriteAllSettings;

  /// Body of the warning shown before replacing diaries that already exist on this device.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The diary already on this device will be replaced entirely by the version in the file. Its local edits and tags will be lost for good.} other{The {count} diaries already on this device will be replaced entirely by the versions in the file. Their local edits and tags will be lost for good.}} Other diaries are not affected.'**
  String backupOverwriteExistingBody(int count);

  /// Suggestion in the overwrite warning to back up first.
  ///
  /// In en, this message translates to:
  /// **'To keep your current data, cancel and export a backup first.'**
  String get backupOverwriteBackupTip;

  /// Checkbox the user must tick before the overwrite can be confirmed.
  ///
  /// In en, this message translates to:
  /// **'I understand overwritten data can\'t be recovered'**
  String get backupOverwriteAcknowledge;

  /// Destructive confirm button of the overwrite warning.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get backupOverwriteConfirm;

  /// Destructive confirm button of the overwrite warning while it is still locked, with the remaining seconds.
  ///
  /// In en, this message translates to:
  /// **'Overwrite ({seconds})'**
  String backupOverwriteConfirmCountdown(int seconds);

  /// Result of a merge import without diaries that already existed.
  ///
  /// In en, this message translates to:
  /// **'{added, plural, =0{Import complete: no new diaries} =1{Import complete: 1 diary added} other{Import complete: {added} diaries added}}'**
  String backupImportMergeResult(int added);

  /// Result of a merge import that skipped diaries already on this device.
  ///
  /// In en, this message translates to:
  /// **'Import complete: {added} added, {skipped} skipped (already on this device)'**
  String backupImportMergeSkippedResult(int added, int skipped);

  /// Result of an import that overwrote diaries already on this device.
  ///
  /// In en, this message translates to:
  /// **'Import complete: {added} added, {replaced} overwritten'**
  String backupImportOverwriteResult(int added, int replaced);

  /// Confirm button of the optional password dialog when exporting a diary file.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get previewExportDiaryFileConfirm;

  /// SnackBar after a diary file is saved, telling where to import it.
  ///
  /// In en, this message translates to:
  /// **'Diary file exported. Import it from Data Management.'**
  String get previewExportDiaryFileSuccess;

  /// Data management entry for importing exports of other diary apps.
  ///
  /// In en, this message translates to:
  /// **'Import from other journal apps'**
  String get dataMgmtImportJournal;

  /// Subtitle listing the diary apps whose exports can be imported.
  ///
  /// In en, this message translates to:
  /// **'Day One, Evernote, Google Keep, Obsidian, Xiaomi Notes and 13 more'**
  String get dataMgmtImportJournalSubtitle;

  /// Title of the sheet that picks the app the export comes from.
  ///
  /// In en, this message translates to:
  /// **'Import from which app?'**
  String get journalImportSourceTitle;

  /// Hint above the list of importable diary apps.
  ///
  /// In en, this message translates to:
  /// **'Export your data in that app first, then choose the exported file here.'**
  String get journalImportSourceHint;

  /// Display name of Apple's Journal app.
  ///
  /// In en, this message translates to:
  /// **'Apple Journal'**
  String get journalImportAppleJournal;

  /// How to get an importable Day One export.
  ///
  /// In en, this message translates to:
  /// **'Export as JSON (.zip)'**
  String get journalImportDayOneHint;

  /// How to get an importable Journey export.
  ///
  /// In en, this message translates to:
  /// **'Export to ZIP (.zip)'**
  String get journalImportJourneyHint;

  /// Which Diarium files can be imported.
  ///
  /// In en, this message translates to:
  /// **'JSON export (.json) or backup file (.diary)'**
  String get journalImportDiariumHint;

  /// Which Daylio files can be imported.
  ///
  /// In en, this message translates to:
  /// **'Backup file (.daylio) or CSV export (.csv)'**
  String get journalImportDaylioHint;

  /// How to export Apple Journal entries.
  ///
  /// In en, this message translates to:
  /// **'On iPhone: Settings › Apps › Journal › Export All Journal Entries (.zip)'**
  String get journalImportAppleJournalHint;

  /// File picker title when importing another app's export.
  ///
  /// In en, this message translates to:
  /// **'Choose the {app} export'**
  String journalImportPickDialogTitle(String app);

  /// Shown when the chosen file doesn't match the selected app's export format.
  ///
  /// In en, this message translates to:
  /// **'This file isn\'t a recognized {app} export'**
  String journalImportUnrecognized(String app);

  /// Shown when an export is valid but contains no entries.
  ///
  /// In en, this message translates to:
  /// **'There are no diaries to import in this file'**
  String get journalImportNoEntries;

  /// Section title for journaling apps in the import source sheet.
  ///
  /// In en, this message translates to:
  /// **'Journaling apps'**
  String get journalImportGroupJournals;

  /// Section title for note-taking apps in the import source sheet.
  ///
  /// In en, this message translates to:
  /// **'Note apps'**
  String get journalImportGroupNotes;

  /// Section title for phone-maker and WPS notes read from their cloud after signing in.
  ///
  /// In en, this message translates to:
  /// **'Phone & WPS cloud notes'**
  String get journalImportGroupPhoneNotes;

  /// Explains that phone-maker and WPS notes are imported by signing in to the official cloud service in the app.
  ///
  /// In en, this message translates to:
  /// **'Sign in to the official cloud service inside the app to read notes, folders and image attachments directly. The sign-in is used only for this import and cleared afterwards.'**
  String get journalImportPhoneNotesHint;

  /// Which Diaro files can be imported.
  ///
  /// In en, this message translates to:
  /// **'Backup file (.zip, unencrypted)'**
  String get journalImportDiaroHint;

  /// Display name of Evernote.
  ///
  /// In en, this message translates to:
  /// **'Evernote'**
  String get journalImportEvernote;

  /// How to get an importable Evernote export.
  ///
  /// In en, this message translates to:
  /// **'Export notebooks as ENEX (.enex, or several in a .zip)'**
  String get journalImportEvernoteHint;

  /// How to get an importable Google Keep export.
  ///
  /// In en, this message translates to:
  /// **'Export Keep with Google Takeout (.zip)'**
  String get journalImportGoogleKeepHint;

  /// How to get an importable Joplin export.
  ///
  /// In en, this message translates to:
  /// **'Export as JEX (.jex)'**
  String get journalImportJoplinHint;

  /// How to get an importable Memos export.
  ///
  /// In en, this message translates to:
  /// **'Settings › Export & Import, v0.31 or later (.zip)'**
  String get journalImportMemosHint;

  /// Display name of the Markdown / plain-text import source.
  ///
  /// In en, this message translates to:
  /// **'Markdown / plain text'**
  String get journalImportMarkdown;

  /// Which Markdown and plain-text files can be imported.
  ///
  /// In en, this message translates to:
  /// **'.md / .txt files from Obsidian, Bear, Notion and more, or a .zip of them'**
  String get journalImportMarkdownHint;

  /// Display name of Xiaomi Notes.
  ///
  /// In en, this message translates to:
  /// **'Xiaomi Notes'**
  String get journalImportXiaomiNotes;

  /// Display name of Huawei Notepad.
  ///
  /// In en, this message translates to:
  /// **'Huawei Notepad'**
  String get journalImportHuaweiNotepad;

  /// Display name of OPPO Notes.
  ///
  /// In en, this message translates to:
  /// **'OPPO Notes'**
  String get journalImportOppoNotes;

  /// Display name of vivo Notes.
  ///
  /// In en, this message translates to:
  /// **'vivo Notes'**
  String get journalImportVivoNotes;

  /// Display name of HONOR Notes.
  ///
  /// In en, this message translates to:
  /// **'HONOR Notes'**
  String get journalImportHonorNotes;

  /// Display name of Meizu Notes.
  ///
  /// In en, this message translates to:
  /// **'Meizu Notes'**
  String get journalImportMeizuNotes;

  /// Display name of WPS Notes.
  ///
  /// In en, this message translates to:
  /// **'WPS Notes'**
  String get journalImportWpsNotes;

  /// Shown when the chosen file is an encrypted backup that can't be read.
  ///
  /// In en, this message translates to:
  /// **'Encrypted {app} backups can\'t be imported. Create an unencrypted backup in {app}'**
  String journalImportEncrypted(String app);

  /// Title of the cloud notes sign-in page.
  ///
  /// In en, this message translates to:
  /// **'Sign in to {app}'**
  String cloudLoginTitle(String app);

  /// Hint at the bottom of the cloud notes sign-in page.
  ///
  /// In en, this message translates to:
  /// **'Sign in on the official page above and open your notes, then tap Read notes. The sign-in is used only for this import and cleared afterwards.'**
  String get cloudLoginHint;

  /// Button that starts reading cloud notes after signing in.
  ///
  /// In en, this message translates to:
  /// **'Read notes'**
  String get cloudLoginRead;

  /// Tooltip of the button that reloads the sign-in page.
  ///
  /// In en, this message translates to:
  /// **'Reload page'**
  String get cloudLoginReload;

  /// Accessibility label while the cloud sign-in is checked.
  ///
  /// In en, this message translates to:
  /// **'Checking sign-in'**
  String get cloudLoginChecking;

  /// Shown when Read notes is tapped before signing in.
  ///
  /// In en, this message translates to:
  /// **'You\'re not signed in yet. Finish signing in on the page first'**
  String get cloudLoginNotSignedIn;

  /// Progress while the cloud note list is read.
  ///
  /// In en, this message translates to:
  /// **'Reading cloud notes ({count})'**
  String cloudBusyReading(int count);

  /// Progress while cloud note details and attachments are read.
  ///
  /// In en, this message translates to:
  /// **'Reading cloud notes ({done}/{total})'**
  String cloudBusyProgress(int done, int total);

  /// Shown when the cloud session expired during reading.
  ///
  /// In en, this message translates to:
  /// **'The sign-in has expired or needs verification. Please sign in again'**
  String get cloudErrorSession;

  /// Shown when a cloud request is forbidden.
  ///
  /// In en, this message translates to:
  /// **'The service denied access (HTTP 403). Check your account or the website'**
  String get cloudErrorForbidden;

  /// Shown when cloud requests are rate limited.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please try again later'**
  String get cloudErrorRateLimited;

  /// Shown when the cloud service returns server errors.
  ///
  /// In en, this message translates to:
  /// **'The service is temporarily unavailable. Please try again later'**
  String get cloudErrorServer;

  /// Shown when the cloud service rejects a request.
  ///
  /// In en, this message translates to:
  /// **'The service rejected the request. Check your account and try again'**
  String get cloudErrorRejected;

  /// Shown when a cloud request fails on the network.
  ///
  /// In en, this message translates to:
  /// **'Network request failed. Check your connection and try again'**
  String get cloudErrorNetwork;

  /// Shown when the cloud API response format is not recognized.
  ///
  /// In en, this message translates to:
  /// **'{app} returned data in an unknown format. Reading stopped so no note is missed'**
  String cloudErrorProtocol(String app);

  /// Shown when the cloud account state doesn't allow reading.
  ///
  /// In en, this message translates to:
  /// **'Notes in this {app} account are encrypted or can\'t be read yet'**
  String cloudErrorUnsupportedAccount(String app);

  /// Import summary title for another app's export.
  ///
  /// In en, this message translates to:
  /// **'{app} export'**
  String backupImportKindJournal(String app);

  /// How many referenced media files are not in the export and will be skipped.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 media file is missing from the export and will be skipped} other{{count} media files are missing from the export and will be skipped}}'**
  String backupImportMissingMedia(int count);

  /// How many notes from another app are encrypted or locked, cannot be read and will be skipped.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 encrypted or locked note can\'t be read and will be skipped} other{{count} encrypted or locked notes can\'t be read and will be skipped}}'**
  String backupImportSkippedEncrypted(int count);

  /// How many notes from another app are handwriting, mind maps or other proprietary types and will be skipped.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 handwritten note, mind map or other special note will be skipped} other{{count} handwritten notes, mind maps or other special notes will be skipped}}'**
  String backupImportSkippedUnsupported(int count);

  /// How many notes from another app lack a body or date or have an unrecognized structure and will be skipped.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 note is in a format that can\'t be recognized and will be skipped} other{{count} notes are in a format that can\'t be recognized and will be skipped}}'**
  String backupImportSkippedUnreadable(int count);

  /// How many notes from another app will be imported with only their list summary because the body could not be read.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The body of 1 note couldn\'t be read; only its summary will be imported} other{The bodies of {count} notes couldn\'t be read; only their summaries will be imported}}'**
  String backupImportSummaryOnly(int count);

  /// Notes with encrypted or undisplayable sections whose readable body and original data will be preserved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 note contains sections that cannot be decrypted or displayed; readable text and original data will be preserved} other{{count} notes contain sections that cannot be decrypted or displayed; readable text and original data will be preserved}}'**
  String backupImportPartialContent(int count);

  /// Tooltip of the calendar header button that opens the display options sheet.
  ///
  /// In en, this message translates to:
  /// **'Calendar display'**
  String get calendarDisplayOptionsTooltip;

  /// Title of the calendar display options sheet.
  ///
  /// In en, this message translates to:
  /// **'Calendar display'**
  String get calendarOptionsTitle;

  /// Button that restores every calendar display option to its default.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get calendarOptionsReset;

  /// Section header for choosing what each calendar day cell shows.
  ///
  /// In en, this message translates to:
  /// **'Day cells'**
  String get calendarOptionsCellStyle;

  /// Day cell style that draws one dot per entry.
  ///
  /// In en, this message translates to:
  /// **'Dots'**
  String get calendarCellStyleDot;

  /// Day cell style that shows the day's mood emoji.
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get calendarCellStyleMood;

  /// Day cell style that tints busier days darker.
  ///
  /// In en, this message translates to:
  /// **'Heat'**
  String get calendarCellStyleHeat;

  /// Day cell style that fills the cell with the day's photo.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get calendarCellStylePhoto;

  /// Day cell style that shows the colors of the day's tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get calendarCellStyleTags;

  /// Explains the dots day cell style.
  ///
  /// In en, this message translates to:
  /// **'One dot for each entry, up to three.'**
  String get calendarCellStyleDotDescription;

  /// Explains the mood day cell style.
  ///
  /// In en, this message translates to:
  /// **'The mood you picked for the day.'**
  String get calendarCellStyleMoodDescription;

  /// Explains the heatmap day cell style.
  ///
  /// In en, this message translates to:
  /// **'The more you wrote, the darker the day.'**
  String get calendarCellStyleHeatDescription;

  /// Explains the photos day cell style.
  ///
  /// In en, this message translates to:
  /// **'The cover, or the first photo in the entry, fills the day.'**
  String get calendarCellStylePhotoDescription;

  /// Explains the tag colors day cell style.
  ///
  /// In en, this message translates to:
  /// **'Colors of up to three tags used that day.'**
  String get calendarCellStyleTagsDescription;

  /// Mood style option: show the average mood when a day has several entries.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get calendarMoodAverage;

  /// Mood style option: show every entry's mood side by side.
  ///
  /// In en, this message translates to:
  /// **'Each entry'**
  String get calendarMoodEach;

  /// Heatmap option: shade days by the number of entries.
  ///
  /// In en, this message translates to:
  /// **'By entries'**
  String get calendarHeatBasisEntries;

  /// Heatmap option: shade days by how much text was written.
  ///
  /// In en, this message translates to:
  /// **'By words'**
  String get calendarHeatBasisWords;

  /// Section header for the small badges drawn on day cells.
  ///
  /// In en, this message translates to:
  /// **'Badges'**
  String get calendarOptionsBadges;

  /// Badge option: show how many entries a day has when there are two or more.
  ///
  /// In en, this message translates to:
  /// **'Entry count'**
  String get calendarBadgeCount;

  /// Badge option: show a lock on days with a sealed time capsule.
  ///
  /// In en, this message translates to:
  /// **'Sealed time capsules'**
  String get calendarBadgeCapsule;

  /// Badge option: show the day's weather icon.
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get calendarBadgeWeather;

  /// Section header for calendar layout options.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get calendarOptionsLayout;

  /// Label of the first-day-of-week option.
  ///
  /// In en, this message translates to:
  /// **'Week starts on'**
  String get calendarOptionsWeekStart;

  /// Week start option that follows the app language (Monday in Chinese, Sunday in English).
  ///
  /// In en, this message translates to:
  /// **'Language default'**
  String get calendarWeekStartLocale;

  /// Week start option: Monday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get calendarWeekStartMonday;

  /// Week start option: Sunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get calendarWeekStartSunday;

  /// Label of the option choosing month or week view when the calendar opens.
  ///
  /// In en, this message translates to:
  /// **'Open in'**
  String get calendarOptionsDefaultFormat;

  /// Open-in option: month view.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get calendarFormatMonth;

  /// Open-in option: week view.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get calendarFormatWeek;

  /// Open-in option: whichever of month or week view was used last.
  ///
  /// In en, this message translates to:
  /// **'Last used'**
  String get calendarFormatRemember;

  /// Switch that colors Saturdays and Sundays differently.
  ///
  /// In en, this message translates to:
  /// **'Highlight weekends'**
  String get calendarHighlightWeekends;

  /// Switch that shows ISO week numbers beside the grid.
  ///
  /// In en, this message translates to:
  /// **'Week numbers'**
  String get calendarShowWeekNumbers;

  /// Switch that keeps six rows in month view so the height never changes.
  ///
  /// In en, this message translates to:
  /// **'Always show 6 weeks'**
  String get calendarFixedSixWeeks;

  /// Explains the always-show-6-weeks switch.
  ///
  /// In en, this message translates to:
  /// **'Keeps the calendar height steady between months.'**
  String get calendarFixedSixWeeksDescription;

  /// Section header for toggling calendar page sections.
  ///
  /// In en, this message translates to:
  /// **'Sections'**
  String get calendarOptionsSections;

  /// Switch that shows the monthly summary under the calendar grid.
  ///
  /// In en, this message translates to:
  /// **'Monthly summary'**
  String get calendarShowMonthSummary;

  /// Explains what the monthly summary shows.
  ///
  /// In en, this message translates to:
  /// **'Entries, days written, words, top mood and longest streak for the month.'**
  String get calendarShowMonthSummaryDescription;

  /// Summary tooltip: number of entries in the month, year or selected range.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 entry} other{{count} entries}}'**
  String calendarSummaryEntries(int count);

  /// Monthly summary tooltip: days with entries out of days elapsed in the month.
  ///
  /// In en, this message translates to:
  /// **'Wrote on {recorded} of {elapsed} days'**
  String calendarSummaryDays(int recorded, int elapsed);

  /// Monthly summary tooltip for a future month: days with entries.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Wrote on 1 day} other{Wrote on {count} days}}'**
  String calendarSummaryDaysNoTotal(int count);

  /// Summary tooltip: total words written in the month, year or selected range (formatted number).
  ///
  /// In en, this message translates to:
  /// **'{count} words'**
  String calendarSummaryWords(String count);

  /// Monthly summary tooltip: the mood picked most often in the month.
  ///
  /// In en, this message translates to:
  /// **'Most frequent mood: {mood}'**
  String calendarSummaryMood(String mood);

  /// Monthly summary tooltip: longest run of consecutive days with entries in the month.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Longest streak: 1 day} other{Longest streak: {count} days}}'**
  String calendarSummaryStreak(int count);

  /// Monthly summary text when the month has no entries.
  ///
  /// In en, this message translates to:
  /// **'No entries this month yet'**
  String get calendarSummaryEmpty;

  /// Monthly summary text for a future month without entries.
  ///
  /// In en, this message translates to:
  /// **'This month hasn\'t started yet'**
  String get calendarSummaryFuture;

  /// Relative label next to the selected date: today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get calendarRelativeToday;

  /// Relative label next to the selected date: yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get calendarRelativeYesterday;

  /// Relative label next to the selected date: tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get calendarRelativeTomorrow;

  /// Relative label next to a past selected date.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String calendarRelativeDaysAgo(int count);

  /// Relative label next to a future selected date.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{in 1 day} other{in {count} days}}'**
  String calendarRelativeDaysLater(int count);

  /// Selected day stats: number of entries and words (formatted number).
  ///
  /// In en, this message translates to:
  /// **'{entries, plural, =1{1 entry} other{{entries} entries}} · {words} words'**
  String calendarDayStats(int entries, String words);

  /// Tooltip of the calendar month title, which zooms out to the year view.
  ///
  /// In en, this message translates to:
  /// **'Show the whole year'**
  String get calendarYearViewTooltip;

  /// Year view coloring option: color each day by its average mood.
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get calendarYearBasisMood;

  /// Year view coloring option: shade each day by its number of entries.
  ///
  /// In en, this message translates to:
  /// **'Entries'**
  String get calendarYearBasisEntries;

  /// Year view coloring option: shade each day by how much was written.
  ///
  /// In en, this message translates to:
  /// **'Words'**
  String get calendarYearBasisWords;

  /// Year view legend label at the light end of the scale.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get calendarYearLegendLess;

  /// Year view legend label at the dark end of the scale.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get calendarYearLegendMore;

  /// Year view legend entry for days with entries but no mood.
  ///
  /// In en, this message translates to:
  /// **'No mood'**
  String get calendarYearLegendNoMood;

  /// Tooltip of the button that exports the year view as an image.
  ///
  /// In en, this message translates to:
  /// **'Share this year'**
  String get calendarYearExport;

  /// Shown when exporting the year view image fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the image. Please try again.'**
  String get calendarYearExportFailed;

  /// Header of the list of entries written on the same date in other years.
  ///
  /// In en, this message translates to:
  /// **'On this day'**
  String get calendarOnThisDayTitle;

  /// On-this-day card label for an entry from an earlier year than the selected date.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 year ago} other{{count} years ago}}'**
  String calendarOnThisDayYearsAgo(int count);

  /// On-this-day card label for an entry from a later year than the selected date.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 year later} other{{count} years later}}'**
  String calendarOnThisDayYearsLater(int count);

  /// Long-press menu action that selects the pressed date.
  ///
  /// In en, this message translates to:
  /// **'Show this day'**
  String get calendarDayActionView;

  /// Long-press menu action that starts an entry dated on the pressed date.
  ///
  /// In en, this message translates to:
  /// **'Write for this day'**
  String get calendarDayActionWrite;

  /// Long-press menu action on a future date that starts a time capsule unlocking that day.
  ///
  /// In en, this message translates to:
  /// **'Write a time capsule'**
  String get calendarDayActionCapsule;

  /// Explains the time capsule action in the long-press menu.
  ///
  /// In en, this message translates to:
  /// **'It can only be opened on this day'**
  String get calendarDayActionCapsuleDescription;

  /// Button in the empty state of a future date that starts a time capsule unlocking that day.
  ///
  /// In en, this message translates to:
  /// **'Write a capsule for this day'**
  String get calendarFutureCapsuleAction;

  /// Label of the option choosing how the selected day's entries are shown.
  ///
  /// In en, this message translates to:
  /// **'Entries of the day'**
  String get calendarOptionsDayContent;

  /// Show the selected day's entries as a timeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get calendarDayContentTimeline;

  /// Show the selected day's entries as diary list cards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get calendarDayContentCards;

  /// Switch that shows the same date from other years under the day's entries.
  ///
  /// In en, this message translates to:
  /// **'On this day'**
  String get calendarShowOnThisDay;

  /// Explains the on-this-day switch.
  ///
  /// In en, this message translates to:
  /// **'Entries from the same date in other years.'**
  String get calendarShowOnThisDayDescription;

  /// Tooltip of the year view button that goes to the previous year.
  ///
  /// In en, this message translates to:
  /// **'Previous year'**
  String get calendarPreviousYear;

  /// Tooltip of the year view button that goes to the next year.
  ///
  /// In en, this message translates to:
  /// **'Next year'**
  String get calendarNextYear;

  /// Title of the lunar calendar option in the calendar display options sheet.
  ///
  /// In en, this message translates to:
  /// **'Lunar calendar'**
  String get calendarOptionsLunar;

  /// Explains the lunar calendar option.
  ///
  /// In en, this message translates to:
  /// **'Shows Chinese lunar dates, solar terms and festivals under each date.'**
  String get calendarOptionsLunarDescription;

  /// Lunar calendar option that follows the app language (shown in Chinese, hidden in English).
  ///
  /// In en, this message translates to:
  /// **'Language default'**
  String get calendarLunarLocale;

  /// Lunar calendar option: always show.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get calendarLunarAlways;

  /// Lunar calendar option: never show.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get calendarLunarNever;

  /// Lunar date under the selected day heading; date is the Chinese lunar month and day (e.g. 九月廿四).
  ///
  /// In en, this message translates to:
  /// **'Lunar {date}'**
  String calendarLunarDate(String date);

  /// Year view summary text when the year has no entries.
  ///
  /// In en, this message translates to:
  /// **'No entries this year yet'**
  String get calendarSummaryEmptyYear;

  /// Year view summary text for a future year without entries.
  ///
  /// In en, this message translates to:
  /// **'This year hasn\'t started yet'**
  String get calendarSummaryFutureYear;

  /// Range summary text when the selected dates have no entries.
  ///
  /// In en, this message translates to:
  /// **'No entries in this range'**
  String get calendarSummaryEmptyRange;

  /// Range summary text when every selected date is in the future.
  ///
  /// In en, this message translates to:
  /// **'This range hasn\'t started yet'**
  String get calendarSummaryFutureRange;

  /// Long-press day menu: start selecting a date range from this day.
  ///
  /// In en, this message translates to:
  /// **'Select a range from here'**
  String get calendarDayActionRange;

  /// Explains the select-a-range action.
  ///
  /// In en, this message translates to:
  /// **'Tap another date to see stats for the days in between'**
  String get calendarDayActionRangeDescription;

  /// Range summary title: start and end dates and the number of days including both ends.
  ///
  /// In en, this message translates to:
  /// **'{start} – {end} · {days, plural, =1{1 day} other{{days} days}}'**
  String calendarRangeTitle(String start, String end, int days);

  /// Range summary title while only the start date is chosen.
  ///
  /// In en, this message translates to:
  /// **'From {start} · tap an end date'**
  String calendarRangePickEnd(String start);

  /// Tooltip of the close button on the range summary.
  ///
  /// In en, this message translates to:
  /// **'Exit range selection'**
  String get calendarRangeExit;

  /// Tooltip of the filter button in the calendar header.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get calendarFilterTooltip;

  /// Title of the calendar filter sheet.
  ///
  /// In en, this message translates to:
  /// **'Filter calendar'**
  String get calendarFilterTitle;

  /// Button that clears the calendar filter.
  ///
  /// In en, this message translates to:
  /// **'Clear filter'**
  String get calendarFilterClear;

  /// Explains the calendar filter.
  ///
  /// In en, this message translates to:
  /// **'Dates and stats only count matching entries. Any choice within a group matches; when both mood and tags are set, an entry must match both.'**
  String get calendarFilterDescription;

  /// Mood group title in the calendar filter sheet.
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get calendarFilterMoods;

  /// Tag group title in the calendar filter sheet.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get calendarFilterTags;

  /// Shown in the filter sheet when there are no tags.
  ///
  /// In en, this message translates to:
  /// **'No tags yet'**
  String get calendarFilterNoTags;

  /// Screen reader prefix of the filter bar in the calendar card.
  ///
  /// In en, this message translates to:
  /// **'Filtered'**
  String get calendarFilterActive;

  /// Title of the lunar calendar and public holiday group in the calendar display options sheet.
  ///
  /// In en, this message translates to:
  /// **'Lunar & holidays'**
  String get calendarOptionsAlmanac;

  /// Title of the public holiday (day off / make-up workday) option.
  ///
  /// In en, this message translates to:
  /// **'Public holidays (China)'**
  String get calendarOptionsHolidays;

  /// Description of the public holiday option; year is the last year covered by the built-in holiday data.
  ///
  /// In en, this message translates to:
  /// **'Marks days off and make-up workdays in mainland China beside the date; weekend shading follows them. Data covers up to {year}.'**
  String calendarOptionsHolidaysDescription(int year);

  /// Description of the public holiday option when the built-in data does not cover the current year.
  ///
  /// In en, this message translates to:
  /// **'Marks days off and make-up workdays in mainland China beside the date; weekend shading follows them. This version doesn\'t include this year\'s schedule yet.'**
  String get calendarOptionsHolidaysDescriptionOutdated;

  /// Day-off mark beside the date number in a calendar cell; must be very short.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get calendarHolidayRestMark;

  /// Make-up workday mark beside the date number in a calendar cell; must be very short.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get calendarHolidayWorkMark;

  /// Day-off note at the end of the lunar line under the selected date heading.
  ///
  /// In en, this message translates to:
  /// **'Day off'**
  String get calendarHolidayDayOff;

  /// Make-up workday note at the end of the lunar line under the selected date heading.
  ///
  /// In en, this message translates to:
  /// **'Make-up workday'**
  String get calendarHolidayMakeUpWorkday;

  /// Import sheet file summary: number of anniversaries in the file.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 anniversary} other{{count} anniversaries}}'**
  String backupImportAnniversaryCount(int count);

  /// Import sheet file summary: anniversaries in the file that already exist on this device.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 anniversary is already on this device} other{{count} anniversaries are already on this device}}'**
  String backupImportExistingAnniversaryCount(int count);

  /// Description of the merge-and-overwrite mode when only anniversaries overlap.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Adds new items and replaces the existing anniversary with the version in the file} other{Adds new items and replaces the {count} existing anniversaries with the versions in the file}}'**
  String backupImportModeOverwriteAnniversariesOnly(int count);

  /// Extra line of the merge-and-overwrite mode description when anniversaries overlap as well as diaries.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Also replaces 1 existing anniversary} other{Also replaces {count} existing anniversaries}}'**
  String backupImportModeOverwriteAnniversariesExtra(int count);

  /// Bullet in the replace-everything warning: anniversaries that will be deleted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 anniversary} other{{count} anniversaries}}'**
  String backupOverwriteAllAnniversaries(int count);

  /// Merge-and-overwrite warning: anniversaries that will be replaced.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The anniversary already on this device will be replaced by the version in the file; local edits will be lost for good.} other{The {count} anniversaries already on this device will be replaced by the versions in the file; local edits will be lost for good.}}'**
  String backupOverwriteExistingAnniversariesBody(int count);

  /// Second line of the merge import result: anniversaries added.
  ///
  /// In en, this message translates to:
  /// **'{added, plural, =0{Anniversaries: none added} =1{Anniversaries: 1 added} other{Anniversaries: {added} added}}'**
  String backupImportAnniversaryMergeResult(int added);

  /// Second line of the merge import result: anniversaries added and skipped.
  ///
  /// In en, this message translates to:
  /// **'Anniversaries: {added} added, {skipped} skipped (already on this device)'**
  String backupImportAnniversaryMergeSkippedResult(int added, int skipped);

  /// Second line of the merge-and-overwrite import result: anniversaries added and overwritten.
  ///
  /// In en, this message translates to:
  /// **'Anniversaries: {added} added, {replaced} overwritten'**
  String backupImportAnniversaryOverwriteResult(int added, int replaced);

  /// Switch for anniversaries in the Sections group of the calendar display options.
  ///
  /// In en, this message translates to:
  /// **'Anniversaries'**
  String get calendarShowAnniversaries;

  /// Description of the anniversaries switch.
  ///
  /// In en, this message translates to:
  /// **'Marks anniversaries on the dates and shows their cards for the selected day.'**
  String get calendarShowAnniversariesDescription;

  /// Date long-press menu: create an anniversary on this day.
  ///
  /// In en, this message translates to:
  /// **'Add an anniversary'**
  String get calendarDayActionAnniversary;

  /// Description of Add an anniversary for today or past dates.
  ///
  /// In en, this message translates to:
  /// **'Remember this day; the calendar marks it every year'**
  String get calendarDayActionAnniversaryDescription;

  /// Description of Add an anniversary for future dates.
  ///
  /// In en, this message translates to:
  /// **'Count down to this day'**
  String get calendarDayActionCountdownDescription;

  /// Screen-reader title of the anniversary card under the selected day.
  ///
  /// In en, this message translates to:
  /// **'Anniversaries'**
  String get anniversarySectionTitle;

  /// Which anniversary this is, in years.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1-year anniversary} other{{count}-year anniversary}}'**
  String anniversaryOrdinal(int count);

  /// Anniversary count when it is today.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1-year anniversary today} other{{count}-year anniversary today}}'**
  String anniversaryTodayOrdinal(int count);

  /// Days until the next anniversary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day left} other{{count} days left}}'**
  String anniversaryDaysLeft(int count);

  /// Days since the first date.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day since} other{{count} days since}}'**
  String anniversaryDaysSince(int count);

  /// The first time of an anniversary.
  ///
  /// In en, this message translates to:
  /// **'The day it began'**
  String get anniversaryBaseDay;

  /// Label of a one-off anniversary that has not come yet.
  ///
  /// In en, this message translates to:
  /// **'Countdown'**
  String get anniversaryCountdownLabel;

  /// The anniversary is today.
  ///
  /// In en, this message translates to:
  /// **'It\'s today'**
  String get anniversaryIsToday;

  /// Note when the date does not exist this year (Feb 29, a missing leap month, the 30th of a short lunar month).
  ///
  /// In en, this message translates to:
  /// **'This year has no such date, so it moves to the nearest day'**
  String get anniversaryAdjustedNote;

  /// Anniversary editor title when creating.
  ///
  /// In en, this message translates to:
  /// **'New anniversary'**
  String get anniversaryNewTitle;

  /// Anniversary editor title when editing.
  ///
  /// In en, this message translates to:
  /// **'Edit anniversary'**
  String get anniversaryEditTitle;

  /// Anniversary editor: name field label.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get anniversaryFieldName;

  /// Hint of the anniversary name field.
  ///
  /// In en, this message translates to:
  /// **'e.g. Together, Mom\'s birthday, Exam day'**
  String get anniversaryNameHint;

  /// Error when the anniversary name is empty.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get anniversaryNameRequired;

  /// Anniversary editor: date field label.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get anniversaryFieldDate;

  /// Anniversary editor: repeat rule label.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get anniversaryFieldRepeat;

  /// Repeat rule: every year by the Gregorian calendar.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get anniversaryRepeatSolar;

  /// Repeat rule: every year by the Chinese lunar calendar.
  ///
  /// In en, this message translates to:
  /// **'Lunar yearly'**
  String get anniversaryRepeatLunar;

  /// Repeat rule: does not repeat.
  ///
  /// In en, this message translates to:
  /// **'Once'**
  String get anniversaryRepeatOnce;

  /// Description of yearly repetition; date is the month and day (e.g. Nov 20).
  ///
  /// In en, this message translates to:
  /// **'Marked every year on {date}'**
  String anniversaryRepeatSolarDescription(String date);

  /// Description of yearly repetition for Feb 29.
  ///
  /// In en, this message translates to:
  /// **'Every year on Feb 29; Feb 28 in common years'**
  String get anniversaryRepeatLeapDayDescription;

  /// Description of lunar yearly repetition; date is the lunar month and day.
  ///
  /// In en, this message translates to:
  /// **'Every year on lunar {date}, converted to that year\'s date'**
  String anniversaryRepeatLunarDescription(String date);

  /// Description of the one-off rule.
  ///
  /// In en, this message translates to:
  /// **'Just this day: counts down before it and counts up after'**
  String get anniversaryRepeatOnceDescription;

  /// Lunar date under the date field; year is the sexagenary year name, date the lunar month and day.
  ///
  /// In en, this message translates to:
  /// **'Lunar {year} year, {date}'**
  String anniversaryLunarYearDate(String year, String date);

  /// Anniversary editor: note field label.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get anniversaryFieldNote;

  /// Hint of the anniversary note field.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get anniversaryNoteHint;

  /// Anniversary editor pin switch; pin action on the list and detail pages.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get anniversaryPin;

  /// Description of the anniversary pin switch.
  ///
  /// In en, this message translates to:
  /// **'Keep it at the top of the anniversary list'**
  String get anniversaryPinDescription;

  /// Delete button at the bottom of the anniversary editor.
  ///
  /// In en, this message translates to:
  /// **'Delete anniversary'**
  String get anniversaryDelete;

  /// Title of the delete anniversary confirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete this anniversary?'**
  String get anniversaryDeleteConfirmTitle;

  /// Body of the delete anniversary confirmation; title is the anniversary name.
  ///
  /// In en, this message translates to:
  /// **'“{title}” will be removed from the calendar. Linked diaries are not affected.'**
  String anniversaryDeleteConfirmBody(String title);

  /// Message after deleting an anniversary.
  ///
  /// In en, this message translates to:
  /// **'Anniversary deleted'**
  String get anniversaryDeleted;

  /// Message after creating an anniversary.
  ///
  /// In en, this message translates to:
  /// **'Anniversary added'**
  String get anniversaryCreated;

  /// Message when saving an anniversary fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Try again.'**
  String get anniversarySaveFailed;

  /// Title of the anniversary list page and tooltip of the calendar header button.
  ///
  /// In en, this message translates to:
  /// **'Anniversaries'**
  String get anniversaryListTitle;

  /// Shown when the anniversary list is empty.
  ///
  /// In en, this message translates to:
  /// **'No anniversaries yet. Long-press a day in the calendar, or tap + to add one.'**
  String get anniversaryEmpty;

  /// Pinned capsule on an anniversary list card.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get anniversaryPinnedBadge;

  /// Caption under the big number on a list card: days until the next time.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{day to go} other{days to go}}'**
  String anniversaryDaysToGo(int count);

  /// Caption under the big number on a list card: days since a one-off day passed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{day ago} other{days ago}}'**
  String anniversaryDaysAgo(int count);

  /// Anniversary details: date of the next time.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get anniversaryDetailNext;

  /// Anniversary details: date of the first time.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get anniversaryDetailStart;

  /// Tooltip of the More button on the anniversary details page.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get anniversaryMoreActions;

  /// Anniversary details More sheet: unpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get anniversaryUnpin;

  /// Linked diary row in the editor and title of the picker sheet.
  ///
  /// In en, this message translates to:
  /// **'Linked diary'**
  String get anniversaryFieldLink;

  /// Diary picker: link no diary.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get anniversaryLinkNone;

  /// Anniversary details: button when nothing is linked.
  ///
  /// In en, this message translates to:
  /// **'Link a diary'**
  String get anniversaryLinkPick;

  /// Anniversary details: the linked diary is in the recycle bin or gone.
  ///
  /// In en, this message translates to:
  /// **'The linked diary was deleted'**
  String get anniversaryLinkMissing;

  /// Anniversary details: remove the link to a deleted diary.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get anniversaryUnlink;

  /// Anniversary details: linked diary section title.
  ///
  /// In en, this message translates to:
  /// **'Linked diary'**
  String get anniversaryLinkedDiaryTitle;

  /// Tooltip of the button at the end of a calendar anniversary row.
  ///
  /// In en, this message translates to:
  /// **'Open the linked diary'**
  String get anniversaryOpenLinkedDiary;

  /// Description in the diary picker sheet.
  ///
  /// In en, this message translates to:
  /// **'Diaries written within 7 days of the date'**
  String get anniversaryPickerHint;

  /// Diary picker sheet without candidates.
  ///
  /// In en, this message translates to:
  /// **'No diaries within a week of this date'**
  String get anniversaryPickerEmpty;

  /// Anniversary details: diaries written on each past occurrence.
  ///
  /// In en, this message translates to:
  /// **'On this day over the years'**
  String get anniversaryPastDiariesTitle;

  /// Anniversary details for a one-off day: diaries written that day.
  ///
  /// In en, this message translates to:
  /// **'Diaries from this day'**
  String get anniversaryBaseDayDiariesTitle;

  /// Anniversary details: no diaries on past occurrences.
  ///
  /// In en, this message translates to:
  /// **'No diaries on these days yet'**
  String get anniversaryPastDiariesEmpty;

  /// View action on the snack bar after making a diary an anniversary.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get anniversaryView;

  /// Diary preview More sheet: create an anniversary from this diary.
  ///
  /// In en, this message translates to:
  /// **'Make it an anniversary'**
  String get previewSetAsAnniversary;

  /// Settings: entry and page title for diary body font and layout.
  ///
  /// In en, this message translates to:
  /// **'Body font & layout'**
  String get diaryTypographyTitle;

  /// Settings: subtitle summarizing the current body font, size and line spacing.
  ///
  /// In en, this message translates to:
  /// **'{font} · Size {size} · Line spacing {lineHeight}'**
  String diaryTypographySummary(String font, String size, String lineHeight);

  /// Diary preview: tooltip of the font & layout button and title of its quick panel.
  ///
  /// In en, this message translates to:
  /// **'Font & layout'**
  String get diaryTypographyQuickTooltip;

  /// Body font & layout: font group title.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get diaryTypographyFontSection;

  /// Body font option: the bundled HarmonyOS Sans font.
  ///
  /// In en, this message translates to:
  /// **'HarmonyOS Sans'**
  String get diaryTypographyFontBundled;

  /// Body font option: use the device system font.
  ///
  /// In en, this message translates to:
  /// **'System font'**
  String get diaryTypographyFontSystem;

  /// Description of the system font option.
  ///
  /// In en, this message translates to:
  /// **'Follows the font your device uses'**
  String get diaryTypographyFontSystemHint;

  /// Body font & layout: notice shown when the selected imported font file is missing.
  ///
  /// In en, this message translates to:
  /// **'The selected font file is no longer on this device, so HarmonyOS Sans is used for now. Import it again or pick another font.'**
  String get diaryTypographyFontMissing;

  /// Body font & layout: import font file entry and file picker title.
  ///
  /// In en, this message translates to:
  /// **'Import font file'**
  String get diaryTypographyImportFont;

  /// Body font & layout: description of the import entry.
  ///
  /// In en, this message translates to:
  /// **'TTF, OTF or TTC; it becomes the body font once imported'**
  String get diaryTypographyImportFontHint;

  /// Body font & layout: busy label while importing a font.
  ///
  /// In en, this message translates to:
  /// **'Importing font…'**
  String get diaryTypographyImporting;

  /// Body font & layout: font imported successfully.
  ///
  /// In en, this message translates to:
  /// **'Imported and applied “{name}”'**
  String diaryTypographyImported(String name);

  /// Body font & layout: the picked file is not a supported font.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t a usable font file. Choose a TTF, OTF or TTC file.'**
  String get diaryTypographyImportUnsupported;

  /// Body font & layout: the picked file could not be read.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the selected file'**
  String get diaryTypographyImportUnreadable;

  /// Body font & layout: saving the font file failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t import the font. Check your storage space and try again.'**
  String get diaryTypographyImportFailed;

  /// Body font & layout: tooltip of the delete button on an imported font.
  ///
  /// In en, this message translates to:
  /// **'Delete font'**
  String get diaryTypographyDeleteFont;

  /// Title of the delete imported font confirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?'**
  String diaryTypographyDeleteFontTitle(String name);

  /// Body of the delete imported font confirmation.
  ///
  /// In en, this message translates to:
  /// **'The font file will be removed from this device. If it\'s in use, diaries switch back to HarmonyOS Sans.'**
  String get diaryTypographyDeleteFontMessage;

  /// Body font & layout: layout values group title.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get diaryTypographyLayoutSection;

  /// Body layout: font size slider label.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get diaryTypographyFontSize;

  /// Body layout: line spacing slider label.
  ///
  /// In en, this message translates to:
  /// **'Line spacing'**
  String get diaryTypographyLineHeight;

  /// Body layout: letter spacing slider label.
  ///
  /// In en, this message translates to:
  /// **'Letter spacing'**
  String get diaryTypographyLetterSpacing;

  /// Body layout: paragraph spacing slider label.
  ///
  /// In en, this message translates to:
  /// **'Paragraph spacing'**
  String get diaryTypographyParagraphSpacing;

  /// Body layout: tooltip of the decrease button; label is the value name.
  ///
  /// In en, this message translates to:
  /// **'{label}: decrease'**
  String diaryTypographyDecrease(String label);

  /// Body layout: tooltip of the increase button; label is the value name.
  ///
  /// In en, this message translates to:
  /// **'{label}: increase'**
  String diaryTypographyIncrease(String label);

  /// Body layout: reset size and spacing values to defaults (keeps the font).
  ///
  /// In en, this message translates to:
  /// **'Reset layout'**
  String get diaryTypographyReset;

  /// Body font & layout: footer explaining where the settings apply.
  ///
  /// In en, this message translates to:
  /// **'Applies when writing, reading and publishing diaries; the font is also used for titles.'**
  String get diaryTypographyScopeHint;

  /// Font & layout quick panel: button opening the full settings page.
  ///
  /// In en, this message translates to:
  /// **'More settings'**
  String get diaryTypographyMoreSettings;

  /// Body layout preview: sample title.
  ///
  /// In en, this message translates to:
  /// **'An evening after the rain'**
  String get diaryTypographySampleTitle;

  /// Body layout preview: sample body; newlines separate paragraphs to show paragraph spacing.
  ///
  /// In en, this message translates to:
  /// **'The rain stopped just before dusk, and the osmanthus downstairs smelled sweeter than ever.\nOn the way home I bought a bag of roasted chestnuts and peeled them as I walked; my hands stayed warm the whole time.\nNothing big happened today, but every moment felt steady, so I wanted to write it down.'**
  String get diaryTypographySampleBody;

  /// Diary card eyebrow: a date followed by its weekday (custom date formats).
  ///
  /// In en, this message translates to:
  /// **'{date} · {weekday}'**
  String diaryCardDateWithWeekday(String date, String weekday);

  /// Diary card eyebrow: a date followed by the time of day (HH:mm).
  ///
  /// In en, this message translates to:
  /// **'{date} {time}'**
  String diaryCardDateWithTime(String date, String time);

  /// Diary card footer: exact time of the last update.
  ///
  /// In en, this message translates to:
  /// **'Updated {time}'**
  String diaryCardFooterUpdated(String time);

  /// Diary card footer: when the diary was written.
  ///
  /// In en, this message translates to:
  /// **'Written {time}'**
  String diaryCardFooterCreated(String time);

  /// Diary card footer: word count of the entry (each Chinese character counts as one word; formatted number).
  ///
  /// In en, this message translates to:
  /// **'{count} words'**
  String diaryCardWordCount(String count);

  /// Screen-reader label of the diary card media badge: number of photos in the entry.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo} other{{count} photos}}'**
  String diaryCardMediaImages(int count);

  /// Screen-reader label of the diary card media badge: the entry has a voice recording.
  ///
  /// In en, this message translates to:
  /// **'Has a recording'**
  String get diaryCardMediaAudio;

  /// Screen-reader label of the diary card media badge: the entry has a video.
  ///
  /// In en, this message translates to:
  /// **'Has a video'**
  String get diaryCardMediaVideo;

  /// Screen-reader label of the diary card media badge: the entry has an attachment.
  ///
  /// In en, this message translates to:
  /// **'Has an attachment'**
  String get diaryCardMediaAttachment;

  /// Screen-reader label of the location on the diary card footer.
  ///
  /// In en, this message translates to:
  /// **'Location: {location}'**
  String diaryCardLocation(String location);

  /// Title of the diary card style page and its entry in Appearance settings.
  ///
  /// In en, this message translates to:
  /// **'Diary card style'**
  String get diaryCardStyleTitle;

  /// Subtitle of the card style entry in Appearance settings: the current style name.
  ///
  /// In en, this message translates to:
  /// **'Current: {name}'**
  String diaryCardStyleEntrySubtitle(String name);

  /// Name shown when the current card style matches no preset or saved style.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get styleEditorCustom;

  /// Diary card style settings: message after Reset (can be undone).
  ///
  /// In en, this message translates to:
  /// **'Restored the default style'**
  String get styleEditorResetDone;

  /// Diary card style settings: tooltip of the button that previews the light theme.
  ///
  /// In en, this message translates to:
  /// **'Light preview'**
  String get styleEditorPreviewLight;

  /// Diary card style settings: tooltip of the button that previews the dark theme.
  ///
  /// In en, this message translates to:
  /// **'Dark preview'**
  String get styleEditorPreviewDark;

  /// Diary card style settings: screen reader name of the options panel's drag handle (drag or tap to resize the panel).
  ///
  /// In en, this message translates to:
  /// **'Options panel'**
  String get styleEditorPanelHandle;

  /// Diary card style settings: screen reader state when the options panel is collapsed to its tab bar.
  ///
  /// In en, this message translates to:
  /// **'Collapsed'**
  String get styleEditorPanelCollapsed;

  /// Diary card style settings: screen reader state when the options panel shares the screen with the preview.
  ///
  /// In en, this message translates to:
  /// **'Half open'**
  String get styleEditorPanelHalf;

  /// Diary card style settings: screen reader state when the options panel is expanded over the preview.
  ///
  /// In en, this message translates to:
  /// **'Expanded'**
  String get styleEditorPanelExpanded;

  /// Diary card style settings: group title for options that apply to both list and waterfall layouts.
  ///
  /// In en, this message translates to:
  /// **'All layouts'**
  String get diaryCardStyleSharedGroup;

  /// Diary card style settings: group title for options that only apply to the list layout.
  ///
  /// In en, this message translates to:
  /// **'List layout only'**
  String get diaryCardStyleListGroup;

  /// Diary card style settings: group title for options that only apply to the waterfall layout.
  ///
  /// In en, this message translates to:
  /// **'Waterfall layout only'**
  String get diaryCardStyleWaterfallGroup;

  /// Diary card style settings: note below the layout-only groups.
  ///
  /// In en, this message translates to:
  /// **'Switch between list and waterfall above the preview to adjust the other layout'**
  String get diaryCardStyleModeFootnote;

  /// Diary card style settings: the “Presets” tab.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get diaryCardStyleTabPresets;

  /// Diary card style settings: the “Layout” tab.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get diaryCardStyleTabLayout;

  /// Diary card style settings: the “Cover” tab.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get diaryCardStyleTabCover;

  /// Diary card style settings: the “Content” tab.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get diaryCardStyleTabContent;

  /// Diary card style settings: the “Date” tab.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get diaryCardStyleTabDate;

  /// Diary card style settings: the “Order” tab.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get diaryCardStyleTabOrder;

  /// Diary card style settings: the “Text” tab.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get diaryCardStyleTabText;

  /// Diary card style settings: the “Color” tab.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get diaryCardStyleTabColor;

  /// Diary card style settings: the “Finish” tab.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get diaryCardStyleTabTexture;

  /// Diary card style settings: group title of the built-in presets.
  ///
  /// In en, this message translates to:
  /// **'Built-in styles'**
  String get styleEditorPresetsTitle;

  /// Diary card style settings: name of the “Classic” preset.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get diaryCardStylePresetClassic;

  /// Diary card style settings: one-line description of the “Classic” preset.
  ///
  /// In en, this message translates to:
  /// **'The default: a square cover on the left and a two-line excerpt'**
  String get diaryCardStylePresetClassicDesc;

  /// Diary card style settings: name of the “Compact” preset.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get diaryCardStylePresetCompact;

  /// Diary card style settings: one-line description of the “Compact” preset.
  ///
  /// In en, this message translates to:
  /// **'Small covers and one-line excerpts to fit more on screen'**
  String get diaryCardStylePresetCompactDesc;

  /// Diary card style settings: name of the “Magazine” preset.
  ///
  /// In en, this message translates to:
  /// **'Magazine'**
  String get diaryCardStylePresetMagazine;

  /// Diary card style settings: one-line description of the “Magazine” preset.
  ///
  /// In en, this message translates to:
  /// **'Full-width photos, larger titles and airy lines'**
  String get diaryCardStylePresetMagazineDesc;

  /// Diary card style settings: name of the “Minimal” preset.
  ///
  /// In en, this message translates to:
  /// **'Minimal'**
  String get diaryCardStylePresetMinimal;

  /// Diary card style settings: one-line description of the “Minimal” preset.
  ///
  /// In en, this message translates to:
  /// **'Just the words: no covers, borders or shadows'**
  String get diaryCardStylePresetMinimalDesc;

  /// Diary card style settings: name of the “Gallery” preset.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get diaryCardStylePresetGallery;

  /// Diary card style settings: one-line description of the “Gallery” preset.
  ///
  /// In en, this message translates to:
  /// **'Photos first, with collages and cover backgrounds'**
  String get diaryCardStylePresetGalleryDesc;

  /// Diary card style settings: name of the “Sticky note” preset.
  ///
  /// In en, this message translates to:
  /// **'Sticky note'**
  String get diaryCardStylePresetSticky;

  /// Diary card style settings: one-line description of the “Sticky note” preset.
  ///
  /// In en, this message translates to:
  /// **'Warm paper, a colored top strip and small corners'**
  String get diaryCardStylePresetStickyDesc;

  /// Diary card style settings: name of the “Journal” preset.
  ///
  /// In en, this message translates to:
  /// **'Journal'**
  String get diaryCardStylePresetJournal;

  /// Diary card style settings: one-line description of the “Journal” preset.
  ///
  /// In en, this message translates to:
  /// **'A side strip, and a date block when there is no cover'**
  String get diaryCardStylePresetJournalDesc;

  /// Diary card style settings: name of the “Mood colors” preset.
  ///
  /// In en, this message translates to:
  /// **'Mood colors'**
  String get diaryCardStylePresetMood;

  /// Diary card style settings: one-line description of the “Mood colors” preset.
  ///
  /// In en, this message translates to:
  /// **'Card colors follow the mood of each entry'**
  String get diaryCardStylePresetMoodDesc;

  /// Diary card style settings: message after applying a preset or saved style (can be undone).
  ///
  /// In en, this message translates to:
  /// **'Applied “{name}”'**
  String styleEditorApplied(String name);

  /// Diary card style settings: group title of the styles the user saved.
  ///
  /// In en, this message translates to:
  /// **'My styles'**
  String get styleEditorSavedTitle;

  /// Diary card style settings: hint shown before any style is saved.
  ///
  /// In en, this message translates to:
  /// **'Save a style you like to switch back in one tap'**
  String get styleEditorSavedEmpty;

  /// Diary card style settings: button that saves the current style to My styles.
  ///
  /// In en, this message translates to:
  /// **'Save current style'**
  String get styleEditorSaveCurrent;

  /// Diary card style settings: note shown when My styles is full.
  ///
  /// In en, this message translates to:
  /// **'You can save up to {count} styles'**
  String styleEditorSaveLimit(int count);

  /// Diary card style settings: title of the save style dialog.
  ///
  /// In en, this message translates to:
  /// **'Save style'**
  String get styleEditorSaveDialogTitle;

  /// Diary card style settings: title of the rename style dialog.
  ///
  /// In en, this message translates to:
  /// **'Rename style'**
  String get styleEditorRenameDialogTitle;

  /// Diary card style settings: label of the style name field.
  ///
  /// In en, this message translates to:
  /// **'Style name'**
  String get styleEditorNameLabel;

  /// Diary card style settings: prefilled name when saving a style; count is its number.
  ///
  /// In en, this message translates to:
  /// **'My style {count}'**
  String styleEditorDefaultName(int count);

  /// Diary card style settings: Rename item in the saved style menu.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get styleEditorRename;

  /// Diary card style settings: message after saving a style.
  ///
  /// In en, this message translates to:
  /// **'Saved “{name}”'**
  String styleEditorSavedDone(String name);

  /// Diary card style settings: message after deleting a saved style (can be undone).
  ///
  /// In en, this message translates to:
  /// **'Deleted “{name}”'**
  String styleEditorDeletedDone(String name);

  /// Diary card style settings: tooltip of the menu button on a saved style.
  ///
  /// In en, this message translates to:
  /// **'More actions for “{name}”'**
  String styleEditorSavedActions(String name);

  /// Diary card style settings: group title for sharing and importing style codes.
  ///
  /// In en, this message translates to:
  /// **'Share and import'**
  String get styleEditorShareTitle;

  /// Diary card style settings: copies the current style as a style code.
  ///
  /// In en, this message translates to:
  /// **'Copy style code'**
  String get styleEditorCopyCode;

  /// Diary card style settings: description of Copy style code.
  ///
  /// In en, this message translates to:
  /// **'Send it to a friend or keep it as a backup'**
  String get styleEditorCopyCodeSubtitle;

  /// Diary card style settings: imports a style code from the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Import from clipboard'**
  String get styleEditorImportCode;

  /// Diary card style settings: description of Import from clipboard.
  ///
  /// In en, this message translates to:
  /// **'Apply a style code someone shared'**
  String get styleEditorImportCodeSubtitle;

  /// Diary card style settings: message after copying the style code.
  ///
  /// In en, this message translates to:
  /// **'Style code copied'**
  String get styleEditorCodeCopied;

  /// Diary card style settings: message when the clipboard is empty on import.
  ///
  /// In en, this message translates to:
  /// **'The clipboard is empty'**
  String get styleEditorImportEmpty;

  /// Diary card style settings: message when the clipboard has no valid style code.
  ///
  /// In en, this message translates to:
  /// **'No valid style code in the clipboard'**
  String get styleEditorImportInvalid;

  /// Diary card style settings: message after importing a code from a newer app version (can be undone).
  ///
  /// In en, this message translates to:
  /// **'Imported. Some settings from a newer version may not apply'**
  String get styleEditorImportNewer;

  /// Diary card style settings: message after importing a style code (can be undone).
  ///
  /// In en, this message translates to:
  /// **'Style imported'**
  String get styleEditorImported;

  /// Diary card style settings: message after importing a named style code (can be undone).
  ///
  /// In en, this message translates to:
  /// **'Imported “{name}”'**
  String styleEditorImportedNamed(String name);

  /// Diary card style settings: card corner radius.
  ///
  /// In en, this message translates to:
  /// **'Card corners'**
  String get diaryCardStyleCornerRadius;

  /// Diary card style settings: alignment of the card text.
  ///
  /// In en, this message translates to:
  /// **'Text alignment'**
  String get diaryCardStyleTextAlign;

  /// Diary card style settings: text aligned to the start edge.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get diaryCardStyleAlignStart;

  /// Diary card style settings: centered text.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get diaryCardStyleAlignCenter;

  /// Diary card style settings: horizontal padding inside the card.
  ///
  /// In en, this message translates to:
  /// **'Side padding'**
  String get diaryCardStylePaddingH;

  /// Diary card style settings: vertical padding inside the card.
  ///
  /// In en, this message translates to:
  /// **'Top and bottom padding'**
  String get diaryCardStylePaddingV;

  /// Diary card style settings: spacing between the date, title, excerpt and other parts.
  ///
  /// In en, this message translates to:
  /// **'Content spacing'**
  String get diaryCardStyleElementGap;

  /// Diary card style settings: spacing between neighboring cards.
  ///
  /// In en, this message translates to:
  /// **'Card spacing'**
  String get diaryCardStyleCardGap;

  /// Diary card style settings: distance between the cards and the screen edges.
  ///
  /// In en, this message translates to:
  /// **'Screen margin'**
  String get diaryCardStyleSideMargin;

  /// Diary card style settings: number of waterfall columns.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get diaryCardStyleColumns;

  /// Diary card style settings: waterfall column count option.
  ///
  /// In en, this message translates to:
  /// **'{count} columns'**
  String diaryCardStyleColumnsValue(int count);

  /// Diary card style settings: note about the waterfall column count.
  ///
  /// In en, this message translates to:
  /// **'Fewer columns are used on narrow screens or with large text'**
  String get diaryCardStyleColumnsFootnote;

  /// Diary card style settings: where the cover sits on the card.
  ///
  /// In en, this message translates to:
  /// **'Cover position'**
  String get diaryCardStyleCoverPosition;

  /// Diary card style settings: cover on the left.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get diaryCardStyleCoverStart;

  /// Diary card style settings: cover on the right.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get diaryCardStyleCoverEnd;

  /// Diary card style settings: cover on top.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get diaryCardStyleCoverTop;

  /// Diary card style settings: cover as the card background.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get diaryCardStyleCoverBackground;

  /// Diary card style settings: no cover.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get diaryCardStyleCoverHidden;

  /// Diary card style settings: size of a side cover.
  ///
  /// In en, this message translates to:
  /// **'Cover size'**
  String get diaryCardStyleCoverSize;

  /// Diary card style settings: note about the cover size.
  ///
  /// In en, this message translates to:
  /// **'On narrow screens the cover shrinks to leave room for text'**
  String get diaryCardStyleCoverSizeFootnote;

  /// Diary card style settings: shape of a side cover.
  ///
  /// In en, this message translates to:
  /// **'Cover shape'**
  String get diaryCardStyleCoverShape;

  /// Diary card style settings: square cover.
  ///
  /// In en, this message translates to:
  /// **'Square'**
  String get diaryCardStyleShapeSquare;

  /// Diary card style settings: landscape (4:3) cover.
  ///
  /// In en, this message translates to:
  /// **'Landscape'**
  String get diaryCardStyleShapeLandscape;

  /// Diary card style settings: portrait (3:4) cover.
  ///
  /// In en, this message translates to:
  /// **'Portrait'**
  String get diaryCardStyleShapePortrait;

  /// Diary card style settings: circular cover.
  ///
  /// In en, this message translates to:
  /// **'Circle'**
  String get diaryCardStyleShapeCircle;

  /// Diary card style settings: cover corner radius.
  ///
  /// In en, this message translates to:
  /// **'Cover corners'**
  String get diaryCardStyleCoverRadius;

  /// Diary card style settings: height of a top cover, or the minimum height of a background-cover card.
  ///
  /// In en, this message translates to:
  /// **'Cover height'**
  String get diaryCardStyleCoverHeight;

  /// Diary card style settings: keeps a top cover inside the padding.
  ///
  /// In en, this message translates to:
  /// **'Inset cover'**
  String get diaryCardStyleCoverInset;

  /// Diary card style settings: description of Inset cover.
  ///
  /// In en, this message translates to:
  /// **'Keep a margin and rounded corners instead of running edge to edge'**
  String get diaryCardStyleCoverInsetSubtitle;

  /// Diary card style settings: thin line between a full-width top cover and the text.
  ///
  /// In en, this message translates to:
  /// **'Divider below the cover'**
  String get diaryCardStyleCoverDivider;

  /// Diary card style settings: spacing between the cover and the text.
  ///
  /// In en, this message translates to:
  /// **'Gap between cover and text'**
  String get diaryCardStyleCoverGap;

  /// Diary card style settings: opacity of the text panel over a background cover.
  ///
  /// In en, this message translates to:
  /// **'Text panel strength'**
  String get diaryCardStyleScrim;

  /// Diary card style settings: combines several photos in a top cover.
  ///
  /// In en, this message translates to:
  /// **'Photo collage'**
  String get diaryCardStyleCollage;

  /// Diary card style settings: description of Photo collage.
  ///
  /// In en, this message translates to:
  /// **'Top covers combine up to three photos from the entry'**
  String get diaryCardStyleCollageSubtitle;

  /// Diary card style settings: what fills the cover spot when an entry has no photo.
  ///
  /// In en, this message translates to:
  /// **'Without a cover'**
  String get diaryCardStyleCoverFallback;

  /// Diary card style settings: no placeholder without a cover.
  ///
  /// In en, this message translates to:
  /// **'Nothing'**
  String get diaryCardStyleFallbackNone;

  /// Diary card style settings: a large date without a cover.
  ///
  /// In en, this message translates to:
  /// **'Date block'**
  String get diaryCardStyleFallbackDate;

  /// Diary card style settings: the mood without a cover.
  ///
  /// In en, this message translates to:
  /// **'Mood tile'**
  String get diaryCardStyleFallbackMood;

  /// Diary card style settings: whether to show the entry title.
  ///
  /// In en, this message translates to:
  /// **'Show title'**
  String get diaryCardStyleShowTitle;

  /// Diary card style settings: whether entries without a title show the “Untitled” placeholder.
  ///
  /// In en, this message translates to:
  /// **'Show “Untitled” when there is no title'**
  String get diaryCardStyleShowUntitled;

  /// Diary card style settings: explanation of the “Untitled” placeholder switch.
  ///
  /// In en, this message translates to:
  /// **'When off, the title line is left out'**
  String get diaryCardStyleShowUntitledSubtitle;

  /// Diary card style settings: whether to show the text excerpt.
  ///
  /// In en, this message translates to:
  /// **'Show excerpt'**
  String get diaryCardStyleShowPreview;

  /// Diary card style settings: maximum lines for the title.
  ///
  /// In en, this message translates to:
  /// **'Title lines'**
  String get diaryCardStyleTitleLines;

  /// Diary card style settings: maximum lines for the excerpt.
  ///
  /// In en, this message translates to:
  /// **'Excerpt lines'**
  String get diaryCardStylePreviewLines;

  /// Diary card style settings: number of lines.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 line} other{{count} lines}}'**
  String diaryCardStyleLinesValue(int count);

  /// Diary card style settings: style of tags on the card.
  ///
  /// In en, this message translates to:
  /// **'Tag style'**
  String get diaryCardStyleTagStyle;

  /// Diary card style settings: tags as tinted chips.
  ///
  /// In en, this message translates to:
  /// **'Chips'**
  String get diaryCardStyleTagChip;

  /// Diary card style settings: tags as plain text.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get diaryCardStyleTagPlain;

  /// Diary card style settings: tags with colored dots.
  ///
  /// In en, this message translates to:
  /// **'Dots'**
  String get diaryCardStyleTagDot;

  /// Diary card style settings: badge style for pinned entries.
  ///
  /// In en, this message translates to:
  /// **'Pinned badge'**
  String get diaryCardStylePinnedBadge;

  /// Diary card style settings: pinned badge with the pin icon and label.
  ///
  /// In en, this message translates to:
  /// **'Icon and label'**
  String get diaryCardStylePinnedStandard;

  /// Diary card style settings: pinned badge with the pin icon only.
  ///
  /// In en, this message translates to:
  /// **'Icon only'**
  String get diaryCardStylePinnedIcon;

  /// Diary card style settings: no pinned badge.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get diaryCardStylePinnedHidden;

  /// Diary card style settings: gives pinned cards a light theme tint.
  ///
  /// In en, this message translates to:
  /// **'Tint pinned cards'**
  String get diaryCardStylePinnedTint;

  /// Diary card style settings: description of Tint pinned cards.
  ///
  /// In en, this message translates to:
  /// **'A light theme-colored fill and border'**
  String get diaryCardStylePinnedTintSubtitle;

  /// Diary card style settings: whether to show the mood.
  ///
  /// In en, this message translates to:
  /// **'Show mood'**
  String get diaryCardStyleShowMood;

  /// Diary card style settings: whether to show the weather.
  ///
  /// In en, this message translates to:
  /// **'Show weather'**
  String get diaryCardStyleShowWeather;

  /// Diary card style settings: group title and style option for mood and weather.
  ///
  /// In en, this message translates to:
  /// **'Mood and weather'**
  String get diaryCardStyleIndicatorStyle;

  /// Diary card style settings: mood and weather in a tinted stamp.
  ///
  /// In en, this message translates to:
  /// **'Stamp'**
  String get diaryCardStyleIndicatorStamp;

  /// Diary card style settings: mood and weather as icons only.
  ///
  /// In en, this message translates to:
  /// **'Icons only'**
  String get diaryCardStyleIndicatorPlain;

  /// Diary card style settings: where mood and weather appear on the card.
  ///
  /// In en, this message translates to:
  /// **'Mood and weather position'**
  String get diaryCardStyleMetaPosition;

  /// Diary card style settings: mood and weather on the date line.
  ///
  /// In en, this message translates to:
  /// **'Date line'**
  String get diaryCardStyleMetaEyebrow;

  /// Diary card style settings: mood and weather in the footer.
  ///
  /// In en, this message translates to:
  /// **'Footer'**
  String get diaryCardStyleMetaFooter;

  /// Diary card style settings: mood and weather on the cover.
  ///
  /// In en, this message translates to:
  /// **'On cover'**
  String get diaryCardStyleMetaCover;

  /// Diary card style settings: group title for extra details in the footer.
  ///
  /// In en, this message translates to:
  /// **'Footer details'**
  String get diaryCardStyleExtras;

  /// Diary card style settings: shows the location in the footer.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get diaryCardStyleShowLocation;

  /// Diary card style settings: shows the energy level in the footer.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get diaryCardStyleShowEnergy;

  /// Diary card style settings: shows the word count in the footer.
  ///
  /// In en, this message translates to:
  /// **'Word count'**
  String get diaryCardStyleShowWordCount;

  /// Diary card style settings: shows photo count and recording, video and attachment badges in the footer.
  ///
  /// In en, this message translates to:
  /// **'Photo and attachment badges'**
  String get diaryCardStyleShowMedia;

  /// Diary card style settings: whether to show the date on the date line.
  ///
  /// In en, this message translates to:
  /// **'Show date'**
  String get diaryCardStyleShowDate;

  /// Diary card style settings: how the date is written.
  ///
  /// In en, this message translates to:
  /// **'Date format'**
  String get diaryCardStyleDateFormat;

  /// Diary card style settings: date format: month and day (year added for other years).
  ///
  /// In en, this message translates to:
  /// **'Month and day'**
  String get diaryCardStyleDateEyebrow;

  /// Diary card style settings: date format: full date with the year.
  ///
  /// In en, this message translates to:
  /// **'Full date'**
  String get diaryCardStyleDateFull;

  /// Diary card style settings: date format: numbers only.
  ///
  /// In en, this message translates to:
  /// **'Numeric'**
  String get diaryCardStyleDateNumeric;

  /// Diary card style settings: date format: how long ago.
  ///
  /// In en, this message translates to:
  /// **'Relative'**
  String get diaryCardStyleDateRelative;

  /// Diary card style settings: adds the weekday after the date.
  ///
  /// In en, this message translates to:
  /// **'Show weekday'**
  String get diaryCardStyleShowWeekday;

  /// Diary card style settings: adds the time after the date.
  ///
  /// In en, this message translates to:
  /// **'Show time'**
  String get diaryCardStyleShowTime;

  /// Diary card style settings: note on the weekday and time switches when the date is relative.
  ///
  /// In en, this message translates to:
  /// **'Relative dates don\'t include the weekday or time'**
  String get diaryCardStyleRelativeNote;

  /// Diary card style settings: which time the date line shows.
  ///
  /// In en, this message translates to:
  /// **'Date shown'**
  String get diaryCardStyleDateSource;

  /// Diary card style settings: date shown: when the entry was written.
  ///
  /// In en, this message translates to:
  /// **'When written'**
  String get diaryCardStyleDateCreated;

  /// Diary card style settings: date shown: when the entry was last edited.
  ///
  /// In en, this message translates to:
  /// **'Last edited'**
  String get diaryCardStyleDateUpdated;

  /// Diary card style settings: the time shown in the footer.
  ///
  /// In en, this message translates to:
  /// **'Footer time'**
  String get diaryCardStyleFooterTime;

  /// Diary card style settings: footer time: how long since the last update.
  ///
  /// In en, this message translates to:
  /// **'Updated … ago'**
  String get diaryCardStyleFooterRelative;

  /// Diary card style settings: footer time: exact time of the last update.
  ///
  /// In en, this message translates to:
  /// **'Update time'**
  String get diaryCardStyleFooterUpdated;

  /// Diary card style settings: footer time: exact time the entry was written.
  ///
  /// In en, this message translates to:
  /// **'Written time'**
  String get diaryCardStyleFooterCreated;

  /// Diary card style settings: no time in the footer.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get diaryCardStyleFooterHidden;

  /// Diary card style settings: hint on the Order tab.
  ///
  /// In en, this message translates to:
  /// **'Drag the handles to change the order of a card\'s parts'**
  String get diaryCardStyleOrderHint;

  /// Diary card style settings: card part: the line with the date and pinned badge.
  ///
  /// In en, this message translates to:
  /// **'Date line'**
  String get diaryCardStyleBlockEyebrow;

  /// Diary card style settings: card part: title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get diaryCardStyleBlockTitle;

  /// Diary card style settings: card part: tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get diaryCardStyleBlockTags;

  /// Diary card style settings: card part: excerpt.
  ///
  /// In en, this message translates to:
  /// **'Excerpt'**
  String get diaryCardStyleBlockPreview;

  /// Diary card style settings: card part: footer.
  ///
  /// In en, this message translates to:
  /// **'Footer'**
  String get diaryCardStyleBlockFooter;

  /// Diary card style settings: button that restores the default order of card parts.
  ///
  /// In en, this message translates to:
  /// **'Restore default order'**
  String get diaryCardStyleOrderReset;

  /// Diary card style settings: screen-reader label of a card part drag handle.
  ///
  /// In en, this message translates to:
  /// **'Drag to move “{name}”'**
  String diaryCardStyleDragHandle(String name);

  /// Diary card style settings: title size scale.
  ///
  /// In en, this message translates to:
  /// **'Title size'**
  String get diaryCardStyleTitleSize;

  /// Diary card style settings: title font weight.
  ///
  /// In en, this message translates to:
  /// **'Title weight'**
  String get diaryCardStyleTitleWeight;

  /// Diary card style settings: regular weight.
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get diaryCardStyleWeightRegular;

  /// Diary card style settings: medium weight.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get diaryCardStyleWeightMedium;

  /// Diary card style settings: bold weight.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get diaryCardStyleWeightBold;

  /// Diary card style settings: excerpt size scale.
  ///
  /// In en, this message translates to:
  /// **'Excerpt size'**
  String get diaryCardStylePreviewSize;

  /// Diary card style settings: excerpt line spacing.
  ///
  /// In en, this message translates to:
  /// **'Excerpt line spacing'**
  String get diaryCardStyleLineHeight;

  /// Diary card style settings: compact line spacing.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get diaryCardStyleLineCompact;

  /// Diary card style settings: standard line spacing.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get diaryCardStyleLineStandard;

  /// Diary card style settings: relaxed line spacing.
  ///
  /// In en, this message translates to:
  /// **'Relaxed'**
  String get diaryCardStyleLineRelaxed;

  /// Diary card style settings: scale of small text such as the date, tags and footer.
  ///
  /// In en, this message translates to:
  /// **'Detail text size'**
  String get diaryCardStyleMetaSize;

  /// Diary card style settings: title text color.
  ///
  /// In en, this message translates to:
  /// **'Title color'**
  String get diaryCardStyleTitleColor;

  /// Diary card style settings: text color of the excerpt, date and footer.
  ///
  /// In en, this message translates to:
  /// **'Text color'**
  String get diaryCardStyleBodyColor;

  /// Diary card style settings: replaces text colors that are too faint.
  ///
  /// In en, this message translates to:
  /// **'Keep text readable'**
  String get diaryCardStyleEnsureContrast;

  /// Diary card style settings: description of Keep text readable.
  ///
  /// In en, this message translates to:
  /// **'When a text color blends into the card, use a clearer one'**
  String get diaryCardStyleEnsureContrastSubtitle;

  /// Diary card style settings: card background color.
  ///
  /// In en, this message translates to:
  /// **'Card color'**
  String get diaryCardStyleBackground;

  /// Diary card style settings: opacity of the card surface.
  ///
  /// In en, this message translates to:
  /// **'Card opacity'**
  String get diaryCardStyleOpacity;

  /// Diary card style settings: gradient card background.
  ///
  /// In en, this message translates to:
  /// **'Gradient'**
  String get diaryCardStyleGradient;

  /// Diary card style settings: description of Gradient.
  ///
  /// In en, this message translates to:
  /// **'Blend from the card color into a second color'**
  String get diaryCardStyleGradientSubtitle;

  /// Diary card style settings: end color of the gradient.
  ///
  /// In en, this message translates to:
  /// **'Second gradient color'**
  String get diaryCardStyleGradientEnd;

  /// Diary card style settings: gradient direction.
  ///
  /// In en, this message translates to:
  /// **'Gradient direction'**
  String get diaryCardStyleGradientDirection;

  /// Diary card style settings: top-to-bottom gradient.
  ///
  /// In en, this message translates to:
  /// **'Vertical'**
  String get diaryCardStyleDirectionVertical;

  /// Diary card style settings: side-to-side gradient.
  ///
  /// In en, this message translates to:
  /// **'Horizontal'**
  String get diaryCardStyleDirectionHorizontal;

  /// Diary card style settings: diagonal gradient.
  ///
  /// In en, this message translates to:
  /// **'Diagonal'**
  String get diaryCardStyleDirectionDiagonal;

  /// Diary card style settings: card border width.
  ///
  /// In en, this message translates to:
  /// **'Border width'**
  String get diaryCardStyleBorderWidth;

  /// Diary card style settings: card border color.
  ///
  /// In en, this message translates to:
  /// **'Border color'**
  String get diaryCardStyleBorderColor;

  /// Diary card style settings: colored strip on the card edge.
  ///
  /// In en, this message translates to:
  /// **'Accent strip'**
  String get diaryCardStyleAccentBar;

  /// Diary card style settings: no strip.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get diaryCardStyleAccentNone;

  /// Diary card style settings: strip on the start edge.
  ///
  /// In en, this message translates to:
  /// **'Side'**
  String get diaryCardStyleAccentStart;

  /// Diary card style settings: strip on the top edge.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get diaryCardStyleAccentTop;

  /// Diary card style settings: strip width.
  ///
  /// In en, this message translates to:
  /// **'Strip width'**
  String get diaryCardStyleAccentWidth;

  /// Diary card style settings: strip color.
  ///
  /// In en, this message translates to:
  /// **'Strip color'**
  String get diaryCardStyleAccentColor;

  /// Diary card style settings: card shadow style.
  ///
  /// In en, this message translates to:
  /// **'Shadow'**
  String get diaryCardStyleShadow;

  /// Diary card style settings: default shadow.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get diaryCardStyleShadowThemed;

  /// Diary card style settings: no shadow.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get diaryCardStyleShadowNone;

  /// Diary card style settings: soft shadow.
  ///
  /// In en, this message translates to:
  /// **'Soft'**
  String get diaryCardStyleShadowSoft;

  /// Diary card style settings: deep floating shadow.
  ///
  /// In en, this message translates to:
  /// **'Floating'**
  String get diaryCardStyleShadowFloating;

  /// Diary card style settings: custom shadow.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get diaryCardStyleShadowCustom;

  /// Diary card style settings: depth of a custom shadow.
  ///
  /// In en, this message translates to:
  /// **'Shadow depth'**
  String get diaryCardStyleShadowElevation;

  /// Diary card style settings: shadow color.
  ///
  /// In en, this message translates to:
  /// **'Shadow color'**
  String get diaryCardStyleShadowColor;

  /// Diary card style settings: color source: keep the default look.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get diaryCardStyleSourceTheme;

  /// Diary card style settings: color source: theme primary color.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get diaryCardStyleSourcePrimary;

  /// Diary card style settings: color source: theme secondary color.
  ///
  /// In en, this message translates to:
  /// **'Secondary'**
  String get diaryCardStyleSourceSecondary;

  /// Diary card style settings: color source: theme tertiary color.
  ///
  /// In en, this message translates to:
  /// **'Tertiary'**
  String get diaryCardStyleSourceTertiary;

  /// Diary card style settings: color source: based on the mood.
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get diaryCardStyleSourceMood;

  /// Diary card style settings: color source: the first tag's color.
  ///
  /// In en, this message translates to:
  /// **'First tag'**
  String get diaryCardStyleSourceTag;

  /// Diary card style settings: color source: a custom color.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get diaryCardStyleSourceCustom;

  /// Diary card style settings: note on the mood color source.
  ///
  /// In en, this message translates to:
  /// **'Uses each entry\'s mood, or the default color when there is none'**
  String get diaryCardStyleSourceMoodHint;

  /// Diary card style settings: note on the first-tag color source.
  ///
  /// In en, this message translates to:
  /// **'Uses the color of each entry\'s first tag'**
  String get diaryCardStyleSourceTagHint;

  /// Diary card style settings: color intensity (opacity).
  ///
  /// In en, this message translates to:
  /// **'Intensity'**
  String get diaryCardStyleStrength;

  /// Diary card style settings: picks the custom color again.
  ///
  /// In en, this message translates to:
  /// **'Edit color'**
  String get styleEditorEditColor;

  /// Diary card style settings: color dialog: derive the dark-mode color automatically.
  ///
  /// In en, this message translates to:
  /// **'Pick the dark color automatically'**
  String get styleEditorColorDarkAuto;

  /// Diary card style settings: description of the automatic dark color.
  ///
  /// In en, this message translates to:
  /// **'Derive a readable dark-mode color from the light one'**
  String get styleEditorColorDarkAutoSubtitle;

  /// Diary card style settings: label of the hex color field.
  ///
  /// In en, this message translates to:
  /// **'Hex color'**
  String get styleEditorHexLabel;

  /// Diary card style settings: error for an invalid hex color.
  ///
  /// In en, this message translates to:
  /// **'Enter a 6-digit hex color, such as FFB300'**
  String get styleEditorHexInvalid;

  /// Diary view options sheet: card style section title.
  ///
  /// In en, this message translates to:
  /// **'Card style'**
  String get diaryCardStyleSheetSection;

  /// Diary view options sheet: opens the card style settings.
  ///
  /// In en, this message translates to:
  /// **'Customize card style'**
  String get diaryCardStyleSheetEntry;

  /// Diary view options sheet: description of the card style entry.
  ///
  /// In en, this message translates to:
  /// **'Covers, text, colors and layout'**
  String get diaryCardStyleSheetEntrySubtitle;

  /// Diary card style settings: title of preview sample entry 1.
  ///
  /// In en, this message translates to:
  /// **'Sunset by the sea'**
  String get diaryCardStyleSampleTitle1;

  /// Diary card style settings: text of preview sample entry 1.
  ///
  /// In en, this message translates to:
  /// **'Walked along the shore until dusk. The waves kept rolling in while the sky slid from orange to lilac.'**
  String get diaryCardStyleSampleBody1;

  /// Diary card style settings: title of preview sample entry 2.
  ///
  /// In en, this message translates to:
  /// **'Weekend hike'**
  String get diaryCardStyleSampleTitle2;

  /// Diary card style settings: text of preview sample entry 2.
  ///
  /// In en, this message translates to:
  /// **'It was windy at the top. I took lots of photos and recorded the wind. My legs were shaking on the way down.'**
  String get diaryCardStyleSampleBody2;

  /// Diary card style settings: title of preview sample entry 3 (long, to show title truncation).
  ///
  /// In en, this message translates to:
  /// **'A rainy workday spent reworking this week’s plan at the cafe'**
  String get diaryCardStyleSampleTitle3;

  /// Diary card style settings: text of preview sample entry 3.
  ///
  /// In en, this message translates to:
  /// **'Reworked this week\'s to-dos and jotted down a few ideas. Early night tonight.'**
  String get diaryCardStyleSampleBody3;

  /// Diary card style settings: text of preview sample entry 4 (it has no title, to show the “Untitled” placeholder).
  ///
  /// In en, this message translates to:
  /// **'Saw a ginger cat napping in the sun on the steps on my way home. Just watching it made me relax.'**
  String get diaryCardStyleSampleBody4;

  /// Diary card style settings: title of the preview sample time capsule.
  ///
  /// In en, this message translates to:
  /// **'A letter to myself next year'**
  String get diaryCardStyleSampleCapsuleTitle;

  /// Diary card style settings: preview sample tag.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get diaryCardStyleSampleTag1;

  /// Diary card style settings: preview sample tag.
  ///
  /// In en, this message translates to:
  /// **'Life'**
  String get diaryCardStyleSampleTag2;

  /// Diary card style settings: preview sample tag.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get diaryCardStyleSampleTag3;

  /// Diary card style settings: location of a preview sample entry.
  ///
  /// In en, this message translates to:
  /// **'Seaside boardwalk'**
  String get diaryCardStyleSampleLocation;

  /// Diary card style settings: a value in dp.
  ///
  /// In en, this message translates to:
  /// **'{value}dp'**
  String diaryCardStyleValueDp(String value);

  /// Diary card style settings: a percentage value.
  ///
  /// In en, this message translates to:
  /// **'{value}%'**
  String diaryCardStyleValuePercent(String value);

  /// Preview page meta: word count of the entry; count selects the plural, formatted is the formatted number.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{formatted} word} other{{formatted} words}}'**
  String diaryPreviewWordCount(int count, String formatted);

  /// Preview page meta: estimated reading time in minutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{1 min read} other{{minutes} min read}}'**
  String diaryPreviewReadingTime(int minutes);

  /// Screen reader hint for the word count in the preview meta line.
  ///
  /// In en, this message translates to:
  /// **'Show word count details'**
  String get diaryWordCountOpen;

  /// Title of the word count detail sheet.
  ///
  /// In en, this message translates to:
  /// **'Word count'**
  String get diaryWordCountTitle;

  /// Unit shown after the big word count number.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{word} other{words}}'**
  String diaryWordCountUnit(int count);

  /// Word count sheet row: Chinese characters, including full-width punctuation.
  ///
  /// In en, this message translates to:
  /// **'Chinese characters'**
  String get diaryWordCountCjk;

  /// Word count sheet row: words in other scripts and numbers.
  ///
  /// In en, this message translates to:
  /// **'Non-Chinese words'**
  String get diaryWordCountLatin;

  /// Word count sheet row: characters without spaces.
  ///
  /// In en, this message translates to:
  /// **'Characters (no spaces)'**
  String get diaryWordCountCharacters;

  /// Word count sheet row: characters including spaces.
  ///
  /// In en, this message translates to:
  /// **'Characters (with spaces)'**
  String get diaryWordCountCharactersWithSpaces;

  /// Word count sheet row: paragraphs with text.
  ///
  /// In en, this message translates to:
  /// **'Paragraphs'**
  String get diaryWordCountParagraphs;

  /// Word count sheet row: number of photos in the entry.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get diaryWordCountImages;

  /// Word count sheet row: number of voice recordings.
  ///
  /// In en, this message translates to:
  /// **'Recordings'**
  String get diaryWordCountRecordings;

  /// Word count sheet row: number of videos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get diaryWordCountVideos;

  /// Word count sheet row: number of file attachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get diaryWordCountAttachments;

  /// Word count sheet row: estimated reading time.
  ///
  /// In en, this message translates to:
  /// **'Reading time'**
  String get diaryWordCountReading;

  /// Footnote of the word count sheet explaining the counting rule.
  ///
  /// In en, this message translates to:
  /// **'Each Chinese character or full-width punctuation mark counts as one word, other text counts by words, and spaces and line breaks are not counted.'**
  String get diaryWordCountRule;

  /// Preview page meta: prefix before the date when the date shown is the last update time.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get diaryPreviewUpdatedPrefix;

  /// Tooltip of the preview page button that scrolls back to the top.
  ///
  /// In en, this message translates to:
  /// **'Back to top'**
  String get diaryPreviewBackToTop;

  /// Diary preview style settings: page title and settings entry.
  ///
  /// In en, this message translates to:
  /// **'Diary preview page'**
  String get diaryPreviewStyleTitle;

  /// Diary preview style settings: entry subtitle with the current preset or saved style name.
  ///
  /// In en, this message translates to:
  /// **'Current: {name}'**
  String diaryPreviewStyleEntrySubtitle(String name);

  /// Diary preview style settings: item in the preview page More sheet that opens these settings.
  ///
  /// In en, this message translates to:
  /// **'Page style'**
  String get diaryPreviewStyleMoreEntry;

  /// Diary preview style settings: tab.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get diaryPreviewStyleTabPresets;

  /// Diary preview style settings: tab.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get diaryPreviewStyleTabPage;

  /// Diary preview style settings: tab.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get diaryPreviewStyleTabCover;

  /// Diary preview style settings: tab.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get diaryPreviewStyleTabTitle;

  /// Diary preview style settings: tab.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get diaryPreviewStyleTabMeta;

  /// Diary preview style settings: tab.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get diaryPreviewStyleTabBody;

  /// Diary preview style settings: preset name.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get diaryPreviewStylePresetClassic;

  /// Diary preview style settings: preset description.
  ///
  /// In en, this message translates to:
  /// **'The original look'**
  String get diaryPreviewStylePresetClassicDesc;

  /// Diary preview style settings: preset name.
  ///
  /// In en, this message translates to:
  /// **'Paper book'**
  String get diaryPreviewStylePresetPaper;

  /// Diary preview style settings: preset description.
  ///
  /// In en, this message translates to:
  /// **'Warm paper, centered title, inset cover'**
  String get diaryPreviewStylePresetPaperDesc;

  /// Diary preview style settings: preset name.
  ///
  /// In en, this message translates to:
  /// **'Magazine'**
  String get diaryPreviewStylePresetMagazine;

  /// Diary preview style settings: preset description.
  ///
  /// In en, this message translates to:
  /// **'Tall cover, large title, date on top'**
  String get diaryPreviewStylePresetMagazineDesc;

  /// Diary preview style settings: preset name.
  ///
  /// In en, this message translates to:
  /// **'Minimal'**
  String get diaryPreviewStylePresetMinimal;

  /// Diary preview style settings: preset description.
  ///
  /// In en, this message translates to:
  /// **'No cover, only the essentials'**
  String get diaryPreviewStylePresetMinimalDesc;

  /// Diary preview style settings: preset name.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get diaryPreviewStylePresetNight;

  /// Diary preview style settings: preset description.
  ///
  /// In en, this message translates to:
  /// **'Ink paper with a progress line'**
  String get diaryPreviewStylePresetNightDesc;

  /// Diary preview style settings: preset name.
  ///
  /// In en, this message translates to:
  /// **'Journal'**
  String get diaryPreviewStylePresetJournal;

  /// Diary preview style settings: preset description.
  ///
  /// In en, this message translates to:
  /// **'Tinted by mood, details in a card'**
  String get diaryPreviewStylePresetJournalDesc;

  /// Diary preview style settings: preset name.
  ///
  /// In en, this message translates to:
  /// **'Mood color'**
  String get diaryPreviewStylePresetMood;

  /// Diary preview style settings: preset description.
  ///
  /// In en, this message translates to:
  /// **'The page takes the entry’s mood color'**
  String get diaryPreviewStylePresetMoodDesc;

  /// Diary preview style settings: preset name.
  ///
  /// In en, this message translates to:
  /// **'Immersive'**
  String get diaryPreviewStylePresetImmersive;

  /// Diary preview style settings: preset description.
  ///
  /// In en, this message translates to:
  /// **'Full cover, progress and back-to-top'**
  String get diaryPreviewStylePresetImmersiveDesc;

  /// Diary preview style settings: group title.
  ///
  /// In en, this message translates to:
  /// **'Colors'**
  String get diaryPreviewStyleColorGroup;

  /// Diary preview style settings: setting title: which color the page is themed from.
  ///
  /// In en, this message translates to:
  /// **'Color basis'**
  String get diaryPreviewStyleColorSeed;

  /// Diary preview style settings: color basis option.
  ///
  /// In en, this message translates to:
  /// **'App theme'**
  String get diaryPreviewStyleSeedApp;

  /// Diary preview style settings: color basis option.
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get diaryPreviewStyleSeedMood;

  /// Diary preview style settings: color basis option.
  ///
  /// In en, this message translates to:
  /// **'First tag'**
  String get diaryPreviewStyleSeedTag;

  /// Diary preview style settings: color basis option.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get diaryPreviewStyleSeedCustom;

  /// Diary preview style settings: note under the color basis.
  ///
  /// In en, this message translates to:
  /// **'Entries without a mood or tag use the app color.'**
  String get diaryPreviewStyleSeedHint;

  /// Diary preview style settings: custom color basis picker.
  ///
  /// In en, this message translates to:
  /// **'Basis color'**
  String get diaryPreviewStyleSeedColor;

  /// Diary preview style settings: setting title: page background.
  ///
  /// In en, this message translates to:
  /// **'Paper'**
  String get diaryPreviewStylePaper;

  /// Diary preview style settings: paper option.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get diaryPreviewStylePaperTheme;

  /// Diary preview style settings: paper option.
  ///
  /// In en, this message translates to:
  /// **'Warm'**
  String get diaryPreviewStylePaperWarm;

  /// Diary preview style settings: paper option.
  ///
  /// In en, this message translates to:
  /// **'Sepia'**
  String get diaryPreviewStylePaperSepia;

  /// Diary preview style settings: paper option.
  ///
  /// In en, this message translates to:
  /// **'Mint'**
  String get diaryPreviewStylePaperMint;

  /// Diary preview style settings: paper option.
  ///
  /// In en, this message translates to:
  /// **'Gray'**
  String get diaryPreviewStylePaperGray;

  /// Diary preview style settings: paper option.
  ///
  /// In en, this message translates to:
  /// **'Ink'**
  String get diaryPreviewStylePaperInk;

  /// Diary preview style settings: paper option.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get diaryPreviewStylePaperCustom;

  /// Diary preview style settings: custom paper color picker.
  ///
  /// In en, this message translates to:
  /// **'Paper color'**
  String get diaryPreviewStylePaperColor;

  /// Diary preview style settings: note under the paper choice.
  ///
  /// In en, this message translates to:
  /// **'On paper darker or lighter than the theme, the whole page switches to match so text stays readable.'**
  String get diaryPreviewStylePaperHint;

  /// Diary preview style settings: switch for a custom body text color.
  ///
  /// In en, this message translates to:
  /// **'Custom text color'**
  String get diaryPreviewStyleTextColor;

  /// Diary preview style settings: note for custom text and title colors.
  ///
  /// In en, this message translates to:
  /// **'Falls back to the default color when contrast with the paper is too low.'**
  String get diaryPreviewStyleTextColorHint;

  /// Diary preview style settings: group title.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get diaryPreviewStyleLayoutGroup;

  /// Diary preview style settings: slider title.
  ///
  /// In en, this message translates to:
  /// **'Side margins'**
  String get diaryPreviewStylePadding;

  /// Diary preview style settings: switch title.
  ///
  /// In en, this message translates to:
  /// **'Limit text width'**
  String get diaryPreviewStyleLimitWidth;

  /// Diary preview style settings: switch subtitle.
  ///
  /// In en, this message translates to:
  /// **'Centers the text on tablets and in landscape'**
  String get diaryPreviewStyleLimitWidthSubtitle;

  /// Diary preview style settings: slider title.
  ///
  /// In en, this message translates to:
  /// **'Maximum text width'**
  String get diaryPreviewStyleContentWidth;

  /// Diary preview style settings: group title.
  ///
  /// In en, this message translates to:
  /// **'Top bar'**
  String get diaryPreviewStyleTopBarGroup;

  /// Diary preview style settings: top bar option: hides when scrolling down.
  ///
  /// In en, this message translates to:
  /// **'Hide on scroll'**
  String get diaryPreviewStyleTopBarFloating;

  /// Diary preview style settings: top bar option: always visible.
  ///
  /// In en, this message translates to:
  /// **'Always shown'**
  String get diaryPreviewStyleTopBarPinned;

  /// Diary preview style settings: setting title: what the top bar shows.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get diaryPreviewStyleTopBarTitle;

  /// Diary preview style settings: top bar title option: the entry date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get diaryPreviewStyleTopBarTitleDate;

  /// Diary preview style settings: top bar title option: no title.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get diaryPreviewStyleTopBarTitleNone;

  /// Diary preview style settings: switch for a top bar button.
  ///
  /// In en, this message translates to:
  /// **'Font and layout button'**
  String get diaryPreviewStyleShowTypographyButton;

  /// Diary preview style settings: switch for a top bar button.
  ///
  /// In en, this message translates to:
  /// **'Edit button'**
  String get diaryPreviewStyleShowEditButton;

  /// Diary preview style settings: switch for a top bar button.
  ///
  /// In en, this message translates to:
  /// **'Share button'**
  String get diaryPreviewStyleShowShareButton;

  /// Diary preview style settings: group title.
  ///
  /// In en, this message translates to:
  /// **'Reading aids'**
  String get diaryPreviewStyleReadingGroup;

  /// Diary preview style settings: switch title.
  ///
  /// In en, this message translates to:
  /// **'Reading progress line'**
  String get diaryPreviewStyleProgress;

  /// Diary preview style settings: switch subtitle.
  ///
  /// In en, this message translates to:
  /// **'A thin line at the top grows as you read'**
  String get diaryPreviewStyleProgressSubtitle;

  /// Diary preview style settings: switch title.
  ///
  /// In en, this message translates to:
  /// **'Back-to-top button'**
  String get diaryPreviewStyleBackToTop;

  /// Diary preview style settings: switch subtitle.
  ///
  /// In en, this message translates to:
  /// **'Shows up after a screen and a half'**
  String get diaryPreviewStyleBackToTopSubtitle;

  /// Diary preview style settings: cover display setting title.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get diaryPreviewStyleCoverMode;

  /// Diary preview style settings: cover option.
  ///
  /// In en, this message translates to:
  /// **'Full width'**
  String get diaryPreviewStyleCoverBanner;

  /// Diary preview style settings: cover option.
  ///
  /// In en, this message translates to:
  /// **'Inset'**
  String get diaryPreviewStyleCoverInset;

  /// Diary preview style settings: cover option.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get diaryPreviewStyleCoverHidden;

  /// Diary preview style settings: cover fit setting title.
  ///
  /// In en, this message translates to:
  /// **'Fit'**
  String get diaryPreviewStyleCoverFit;

  /// Diary preview style settings: cover fit option.
  ///
  /// In en, this message translates to:
  /// **'Whole photo'**
  String get diaryPreviewStyleCoverContain;

  /// Diary preview style settings: cover fit option.
  ///
  /// In en, this message translates to:
  /// **'Fill and crop'**
  String get diaryPreviewStyleCoverFill;

  /// Diary preview style settings: slider title.
  ///
  /// In en, this message translates to:
  /// **'Cover height'**
  String get diaryPreviewStyleCoverHeight;

  /// Diary preview style settings: footer of the cover group.
  ///
  /// In en, this message translates to:
  /// **'The cover never takes more than 70% of the screen height.'**
  String get diaryPreviewStyleCoverHeightHint;

  /// Diary preview style settings: slider title for the inset cover.
  ///
  /// In en, this message translates to:
  /// **'Corner radius'**
  String get diaryPreviewStyleCoverRadius;

  /// Diary preview style settings: switch title.
  ///
  /// In en, this message translates to:
  /// **'Fade on scroll'**
  String get diaryPreviewStyleCoverFade;

  /// Diary preview style settings: switch subtitle.
  ///
  /// In en, this message translates to:
  /// **'The cover fades and shrinks a little as you scroll up'**
  String get diaryPreviewStyleCoverFadeSubtitle;

  /// Diary preview style settings: switch title.
  ///
  /// In en, this message translates to:
  /// **'Use the first photo without a cover'**
  String get diaryPreviewStyleCoverFirstImage;

  /// Diary preview style settings: switch title.
  ///
  /// In en, this message translates to:
  /// **'Show title'**
  String get diaryPreviewStyleTitleVisible;

  /// Diary preview style settings: switch title.
  ///
  /// In en, this message translates to:
  /// **'Show “Untitled” when there is no title'**
  String get diaryPreviewStyleTitleUntitled;

  /// Diary preview style settings: switch subtitle.
  ///
  /// In en, this message translates to:
  /// **'When off, the title line is left out'**
  String get diaryPreviewStyleTitleUntitledSubtitle;

  /// Diary preview style settings: slider title.
  ///
  /// In en, this message translates to:
  /// **'Title size'**
  String get diaryPreviewStyleTitleScale;

  /// Diary preview style settings: setting title.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get diaryPreviewStyleTitleWeight;

  /// Diary preview style settings: title weight option.
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get diaryPreviewStyleWeightRegular;

  /// Diary preview style settings: title weight option.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get diaryPreviewStyleWeightMedium;

  /// Diary preview style settings: title weight option.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get diaryPreviewStyleWeightBold;

  /// Diary preview style settings: title weight option.
  ///
  /// In en, this message translates to:
  /// **'Heavy'**
  String get diaryPreviewStyleWeightHeavy;

  /// Diary preview style settings: setting title.
  ///
  /// In en, this message translates to:
  /// **'Alignment'**
  String get diaryPreviewStyleTitleAlign;

  /// Diary preview style settings: alignment option.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get diaryPreviewStyleAlignStart;

  /// Diary preview style settings: alignment option.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get diaryPreviewStyleAlignCenter;

  /// Diary preview style settings: switch for a custom title color.
  ///
  /// In en, this message translates to:
  /// **'Custom title color'**
  String get diaryPreviewStyleTitleColor;

  /// Diary preview style settings: setting title.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get diaryPreviewStyleMetaPosition;

  /// Diary preview style settings: details position option.
  ///
  /// In en, this message translates to:
  /// **'Above title'**
  String get diaryPreviewStyleMetaAbove;

  /// Diary preview style settings: details position option.
  ///
  /// In en, this message translates to:
  /// **'Below title'**
  String get diaryPreviewStyleMetaBelow;

  /// Diary preview style settings: details position option.
  ///
  /// In en, this message translates to:
  /// **'After text'**
  String get diaryPreviewStyleMetaEnd;

  /// Diary preview style settings: setting title.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get diaryPreviewStyleMetaLayout;

  /// Diary preview style settings: details layout option.
  ///
  /// In en, this message translates to:
  /// **'Stacked'**
  String get diaryPreviewStyleMetaStacked;

  /// Diary preview style settings: details layout option.
  ///
  /// In en, this message translates to:
  /// **'Inline'**
  String get diaryPreviewStyleMetaInline;

  /// Diary preview style settings: details layout option.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get diaryPreviewStyleMetaCard;

  /// Diary preview style settings: group title.
  ///
  /// In en, this message translates to:
  /// **'Shown details'**
  String get diaryPreviewStyleMetaItems;

  /// Diary preview style settings: details switch.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get diaryPreviewStyleShowDate;

  /// Diary preview style settings: details switch.
  ///
  /// In en, this message translates to:
  /// **'Word count'**
  String get diaryPreviewStyleShowWordCount;

  /// Diary preview style settings: details switch.
  ///
  /// In en, this message translates to:
  /// **'Reading time'**
  String get diaryPreviewStyleShowReadingTime;

  /// Diary preview style settings: details switch.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get diaryPreviewStyleShowLocation;

  /// Diary preview style settings: details switch.
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get diaryPreviewStyleShowWeather;

  /// Diary preview style settings: details switch.
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get diaryPreviewStyleShowMood;

  /// Diary preview style settings: details switch.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get diaryPreviewStyleShowEnergy;

  /// Diary preview style settings: details switch.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get diaryPreviewStyleShowTags;

  /// Diary preview style settings: switch title.
  ///
  /// In en, this message translates to:
  /// **'“Published / Updated” before the date'**
  String get diaryPreviewStyleDatePrefix;

  /// Diary preview style settings: group title.
  ///
  /// In en, this message translates to:
  /// **'Chips'**
  String get diaryPreviewStyleChipsGroup;

  /// Diary preview style settings: setting title: tag look.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get diaryPreviewStyleTagStyle;

  /// Diary preview style settings: setting title: mood and energy look.
  ///
  /// In en, this message translates to:
  /// **'Mood and energy'**
  String get diaryPreviewStyleChipStyle;

  /// Diary preview style settings: mood and energy look option.
  ///
  /// In en, this message translates to:
  /// **'Chip'**
  String get diaryPreviewStyleChipChip;

  /// Diary preview style settings: mood and energy look option.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get diaryPreviewStyleChipPlain;

  /// Diary preview style settings: entry to the body typography settings.
  ///
  /// In en, this message translates to:
  /// **'Font and layout'**
  String get diaryPreviewStyleTypographyEntry;

  /// Diary preview style settings: entry subtitle.
  ///
  /// In en, this message translates to:
  /// **'Shared with the editor'**
  String get diaryPreviewStyleTypographyEntrySubtitle;

  /// Diary preview style settings: switch title.
  ///
  /// In en, this message translates to:
  /// **'Hint when there is no text'**
  String get diaryPreviewStyleEmptyHint;

  /// Diary preview style settings: switch title.
  ///
  /// In en, this message translates to:
  /// **'Show “Last edited”'**
  String get diaryPreviewStyleLastEdited;

  /// Diary preview style settings: setting title.
  ///
  /// In en, this message translates to:
  /// **'Time format'**
  String get diaryPreviewStyleEditedFormat;

  /// Diary preview style settings: edited time option.
  ///
  /// In en, this message translates to:
  /// **'Precise'**
  String get diaryPreviewStyleEditedPrecise;

  /// Diary preview style settings: edited time option.
  ///
  /// In en, this message translates to:
  /// **'Relative'**
  String get diaryPreviewStyleEditedRelative;

  /// Diary preview style settings: edited time option.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get diaryPreviewStyleEditedFull;

  /// Diary preview style settings: switch title.
  ///
  /// In en, this message translates to:
  /// **'Unlocked capsule note'**
  String get diaryPreviewStyleCapsuleInsight;

  /// Diary preview style settings: group title.
  ///
  /// In en, this message translates to:
  /// **'Reading behavior'**
  String get diaryPreviewStyleBehaviorGroup;

  /// Diary preview style settings: footer of the behavior group.
  ///
  /// In en, this message translates to:
  /// **'Presets and style codes don’t change these.'**
  String get diaryPreviewStyleBehaviorFootnote;

  /// Diary preview style settings: switch title.
  ///
  /// In en, this message translates to:
  /// **'Tick to-dos while reading'**
  String get diaryPreviewStyleTodoToggle;

  /// Diary preview style settings: switch subtitle.
  ///
  /// In en, this message translates to:
  /// **'Ticks are saved automatically'**
  String get diaryPreviewStyleTodoToggleSubtitle;

  /// Diary preview style settings: switch title.
  ///
  /// In en, this message translates to:
  /// **'Select text by long-press'**
  String get diaryPreviewStyleTextSelection;

  /// Diary preview style settings: switch subtitle.
  ///
  /// In en, this message translates to:
  /// **'Select and copy parts of the entry'**
  String get diaryPreviewStyleTextSelectionSubtitle;

  /// Diary preview style settings: screen reader label of the sample indicator.
  ///
  /// In en, this message translates to:
  /// **'Sample {index} of {count}'**
  String diaryPreviewStyleSampleOf(int index, int count);

  /// Diary preview style settings: sample entry heading.
  ///
  /// In en, this message translates to:
  /// **'Small things today'**
  String get diaryPreviewStyleSampleHeading;

  /// Diary preview style settings: sample entry quote.
  ///
  /// In en, this message translates to:
  /// **'Slow down, it’s faster.'**
  String get diaryPreviewStyleSampleQuote;

  /// Diary preview style settings: sample entry to-do.
  ///
  /// In en, this message translates to:
  /// **'Buy some flowers'**
  String get diaryPreviewStyleSampleTodo1;

  /// Diary preview style settings: sample entry to-do.
  ///
  /// In en, this message translates to:
  /// **'Call home'**
  String get diaryPreviewStyleSampleTodo2;

  /// Diary preview style settings: long paragraph of a sample entry.
  ///
  /// In en, this message translates to:
  /// **'After the rain stopped the street went quiet. I sat by the window and wrote down three things I was grateful for, while leaves drifted past like the pages of an old book.'**
  String get diaryPreviewStyleSampleLong;

  /// Diary preview style settings: weather of a sample entry.
  ///
  /// In en, this message translates to:
  /// **'Sunny'**
  String get diaryPreviewStyleSampleWeather;

  /// Diary preview: edge hint when pulling past the first diary.
  ///
  /// In en, this message translates to:
  /// **'This is the first one'**
  String get diaryPreviewFirstDiary;

  /// Diary preview: edge hint when pulling past the last diary.
  ///
  /// In en, this message translates to:
  /// **'This is the last one'**
  String get diaryPreviewLastDiary;

  /// Diary preview: go to the previous diary (end-of-page card and screen reader action).
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get diaryPreviewPrevious;

  /// Diary preview: go to the next diary (end-of-page card and screen reader action).
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get diaryPreviewNext;

  /// Diary preview: top bar position title, e.g. "3 / 57".
  ///
  /// In en, this message translates to:
  /// **'{index} / {count}'**
  String diaryPreviewPosition(int index, int count);

  /// Diary preview: top bar position title while more diaries may still load.
  ///
  /// In en, this message translates to:
  /// **'{index} / {count}+'**
  String diaryPreviewPositionMore(int index, int count);

  /// Diary preview: screen reader text of the position title.
  ///
  /// In en, this message translates to:
  /// **'{index} of {count}'**
  String diaryPreviewPositionSemantics(int index, int count);

  /// Diary preview: screen reader text of the position title while more may load.
  ///
  /// In en, this message translates to:
  /// **'{index} of at least {count}'**
  String diaryPreviewPositionSemanticsMore(int index, int count);

  /// Diary preview style settings: Paging tab.
  ///
  /// In en, this message translates to:
  /// **'Paging'**
  String get diaryPreviewStyleTabPaging;

  /// Diary preview style settings: swipe between diaries switch.
  ///
  /// In en, this message translates to:
  /// **'Swipe between diaries'**
  String get diaryPreviewStyleSwipe;

  /// Diary preview style settings: subtitle of the swipe switch.
  ///
  /// In en, this message translates to:
  /// **'In the order of the list you opened it from'**
  String get diaryPreviewStyleSwipeSubtitle;

  /// Diary preview style settings: swipe sensitivity.
  ///
  /// In en, this message translates to:
  /// **'Sensitivity'**
  String get diaryPreviewStyleSwipeSensitivity;

  /// Diary preview style settings: sensitive swipe.
  ///
  /// In en, this message translates to:
  /// **'Sensitive'**
  String get diaryPreviewStyleSensitivitySensitive;

  /// Diary preview style settings: standard swipe.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get diaryPreviewStyleSensitivityStandard;

  /// Diary preview style settings: strict swipe.
  ///
  /// In en, this message translates to:
  /// **'Strict'**
  String get diaryPreviewStyleSensitivityStrict;

  /// Diary preview style settings: explanation of swipe sensitivity.
  ///
  /// In en, this message translates to:
  /// **'Further right needs a flatter swipe; Strict also needs a half-screen drag or a firm flick.'**
  String get diaryPreviewStyleSensitivityHint;

  /// Diary preview style settings: haptic feedback on page turn.
  ///
  /// In en, this message translates to:
  /// **'Vibrate when turning pages'**
  String get diaryPreviewStyleHapticOnPage;

  /// Diary preview style settings: page transition.
  ///
  /// In en, this message translates to:
  /// **'Transition'**
  String get diaryPreviewStyleTransition;

  /// Diary preview style settings: slide transition.
  ///
  /// In en, this message translates to:
  /// **'Slide'**
  String get diaryPreviewStyleTransitionSlide;

  /// Diary preview style settings: stack transition.
  ///
  /// In en, this message translates to:
  /// **'Stack'**
  String get diaryPreviewStyleTransitionStack;

  /// Diary preview style settings: fade transition.
  ///
  /// In en, this message translates to:
  /// **'Fade'**
  String get diaryPreviewStyleTransitionFade;

  /// Diary preview style settings: show previous and next cards at the end of the page.
  ///
  /// In en, this message translates to:
  /// **'Previous and next at the end'**
  String get diaryPreviewStyleNeighborCards;

  /// Diary preview style settings: edge hint switch.
  ///
  /// In en, this message translates to:
  /// **'Hint at either end'**
  String get diaryPreviewStyleEdgeHint;

  /// Diary preview style settings: subtitle of the edge hint switch.
  ///
  /// In en, this message translates to:
  /// **'When you pull past the first or last diary'**
  String get diaryPreviewStyleEdgeHintSubtitle;

  /// Diary preview style settings: top bar title shows the position (e.g. 3 / 57).
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get diaryPreviewStyleTopBarTitlePosition;

  /// Data management: cloud backup entry title.
  ///
  /// In en, this message translates to:
  /// **'Cloud backup'**
  String get dataMgmtCloudBackup;

  /// Data management: cloud backup entry subtitle.
  ///
  /// In en, this message translates to:
  /// **'Back up to cloud drives, WebDAV or object storage and restore from them'**
  String get dataMgmtCloudBackupSubtitle;

  /// Cloud backup page title.
  ///
  /// In en, this message translates to:
  /// **'Cloud backup'**
  String get cloudBackupTitle;

  /// Cloud backup page empty state.
  ///
  /// In en, this message translates to:
  /// **'No backup locations yet. Add a cloud drive, WebDAV server or object storage to upload full backups and restore them on a new device.'**
  String get cloudBackupEmpty;

  /// Cloud backup page: add location button.
  ///
  /// In en, this message translates to:
  /// **'Add backup location'**
  String get cloudBackupAdd;

  /// Cloud backup page footer note.
  ///
  /// In en, this message translates to:
  /// **'Addresses, passwords and drive authorizations stay on this device and are never written into backups. Uploads are full backup ZIPs, optionally encrypted.'**
  String get cloudBackupHint;

  /// Add-location sheet title.
  ///
  /// In en, this message translates to:
  /// **'Choose a backup location'**
  String get cloudBackupSheetTitle;

  /// Add-location sheet description.
  ///
  /// In en, this message translates to:
  /// **'Before restoring, the backup is checked and you choose whether to merge with or overwrite local data.'**
  String get cloudBackupSheetHint;

  /// Sheet group: cloud drives that use sign-in.
  ///
  /// In en, this message translates to:
  /// **'Cloud drives (sign in)'**
  String get cloudBackupGroupDrives;

  /// Cloud drives group description.
  ///
  /// In en, this message translates to:
  /// **'Authorize on the drive\'s official page; the app can only access its own backup folder.'**
  String get cloudBackupGroupDrivesHint;

  /// Sheet group: WebDAV.
  ///
  /// In en, this message translates to:
  /// **'WebDAV'**
  String get cloudBackupGroupWebDav;

  /// WebDAV group description.
  ///
  /// In en, this message translates to:
  /// **'Nutstore, NAS, Nextcloud, and any drive mounted through Alist / OpenList.'**
  String get cloudBackupGroupWebDavHint;

  /// Sheet group: S3-compatible object storage.
  ///
  /// In en, this message translates to:
  /// **'Object storage (S3-compatible)'**
  String get cloudBackupGroupS3;

  /// S3 group description.
  ///
  /// In en, this message translates to:
  /// **'Enter access keys; backups are stored in the bucket you choose.'**
  String get cloudBackupGroupS3Hint;

  /// Custom WebDAV option name.
  ///
  /// In en, this message translates to:
  /// **'Other WebDAV'**
  String get cloudBackupCustomWebDav;

  /// Custom S3 option name.
  ///
  /// In en, this message translates to:
  /// **'Other S3-compatible'**
  String get cloudBackupCustomS3;

  /// Baidu Netdisk name.
  ///
  /// In en, this message translates to:
  /// **'Baidu Netdisk'**
  String get cloudBackupBaiduPan;

  /// Alipan name.
  ///
  /// In en, this message translates to:
  /// **'Alipan (Aliyun Drive)'**
  String get cloudBackupAliyunDrive;

  /// Nutstore name.
  ///
  /// In en, this message translates to:
  /// **'Nutstore (Jianguoyun)'**
  String get cloudBackupJianguoyun;

  /// 123pan name.
  ///
  /// In en, this message translates to:
  /// **'123pan'**
  String get cloudBackup123pan;

  /// Synology NAS name.
  ///
  /// In en, this message translates to:
  /// **'Synology NAS'**
  String get cloudBackupSynology;

  /// QNAP NAS name.
  ///
  /// In en, this message translates to:
  /// **'QNAP NAS'**
  String get cloudBackupQnap;

  /// Alibaba Cloud OSS name.
  ///
  /// In en, this message translates to:
  /// **'Alibaba Cloud OSS'**
  String get cloudBackupAliyunOss;

  /// Tencent Cloud COS name.
  ///
  /// In en, this message translates to:
  /// **'Tencent Cloud COS'**
  String get cloudBackupTencentCos;

  /// Qiniu Kodo name.
  ///
  /// In en, this message translates to:
  /// **'Qiniu Kodo'**
  String get cloudBackupQiniuKodo;

  /// Huawei Cloud OBS name.
  ///
  /// In en, this message translates to:
  /// **'Huawei Cloud OBS'**
  String get cloudBackupHuaweiObs;

  /// Volcengine TOS name.
  ///
  /// In en, this message translates to:
  /// **'Volcengine TOS'**
  String get cloudBackupVolcengineTos;

  /// Baidu AI Cloud BOS name.
  ///
  /// In en, this message translates to:
  /// **'Baidu AI Cloud BOS'**
  String get cloudBackupBaiduBos;

  /// JD Cloud OSS name.
  ///
  /// In en, this message translates to:
  /// **'JD Cloud OSS'**
  String get cloudBackupJdcloudOss;

  /// AWS China regions name.
  ///
  /// In en, this message translates to:
  /// **'Amazon S3 (China)'**
  String get cloudBackupAwsChina;

  /// Nutstore setup note.
  ///
  /// In en, this message translates to:
  /// **'Use your Nutstore account as the username and an app password from Account Info → Security → Third-party apps. Free accounts allow 600 requests per 30 minutes.'**
  String get cloudBackupHintJianguoyun;

  /// 123pan setup note.
  ///
  /// In en, this message translates to:
  /// **'Copy the address and password shown under Tools → Third-party mount in 123pan (the password is shown only once).'**
  String get cloudBackupHint123pan;

  /// Alist / OpenList setup note.
  ///
  /// In en, this message translates to:
  /// **'Enter the Alist / OpenList address (default port 5244, path /dav/) and grant the user WebDAV read and manage permissions. Any drive mounted there can hold backups.'**
  String get cloudBackupHintOpenList;

  /// CloudDrive2 setup note.
  ///
  /// In en, this message translates to:
  /// **'Enter the CloudDrive2 address (default port 19798, path /dav) and your CloudDrive2 account.'**
  String get cloudBackupHintCloudDrive2;

  /// Nextcloud setup note.
  ///
  /// In en, this message translates to:
  /// **'Copy the address from Files settings → WebDAV in the web app; prefer an app password from Personal settings → Security.'**
  String get cloudBackupHintNextcloud;

  /// ownCloud setup note.
  ///
  /// In en, this message translates to:
  /// **'Prefer an app token as the password; on oCIS the administrator must enable app tokens.'**
  String get cloudBackupHintOwncloud;

  /// Seafile setup note.
  ///
  /// In en, this message translates to:
  /// **'SeafDAV must be enabled on the server; single sign-on accounts need a separate WebDAV password set on the web.'**
  String get cloudBackupHintSeafile;

  /// Synology setup note.
  ///
  /// In en, this message translates to:
  /// **'Install and enable WebDAV Server in DSM (HTTPS port 5006 by default) and sign in with a DSM account; the first level of the remote folder must be a shared folder.'**
  String get cloudBackupHintSynology;

  /// QNAP setup note.
  ///
  /// In en, this message translates to:
  /// **'Enable WebDAV in the Control Panel and end the address with the shared folder name.'**
  String get cloudBackupHintQnap;

  /// Koofr setup note.
  ///
  /// In en, this message translates to:
  /// **'You must use an app password from Koofr Settings → Passwords; repeated failed logins are temporarily blocked.'**
  String get cloudBackupHintKoofr;

  /// pCloud setup note.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your pCloud email and password; choose pCloud (EU) for European accounts.'**
  String get cloudBackupHintPcloud;

  /// InfiniCLOUD setup note.
  ///
  /// In en, this message translates to:
  /// **'Copy the address and the Apps Connection password from your InfiniCLOUD My Page.'**
  String get cloudBackupHintInfinicloud;

  /// Hetzner setup note.
  ///
  /// In en, this message translates to:
  /// **'Enable WebDAV and external access for the Storage Box in Hetzner Console.'**
  String get cloudBackupHintHetzner;

  /// kDrive setup note.
  ///
  /// In en, this message translates to:
  /// **'The Drive ID is in the kDrive web address; use an app password if two-factor authentication is on.'**
  String get cloudBackupHintKdrive;

  /// Yandex Disk setup note.
  ///
  /// In en, this message translates to:
  /// **'Requires a paid Yandex 360 plan and an app password of type WebDAV.'**
  String get cloudBackupHintYandex;

  /// Mail.ru setup note.
  ///
  /// In en, this message translates to:
  /// **'Use an app password created in your Mail.ru account settings.'**
  String get cloudBackupHintMailru;

  /// Generic S3 setup note.
  ///
  /// In en, this message translates to:
  /// **'The endpoint and region must match the bucket\'s location. Use a dedicated bucket and keys that can access only that bucket.'**
  String get cloudBackupS3Hint;

  /// Alibaba Cloud OSS setup note.
  ///
  /// In en, this message translates to:
  /// **'Use a RAM user AccessKey; the endpoint region must match the bucket. Accounts opened after March 2025 may be unable to use the default public endpoint in mainland China.'**
  String get cloudBackupHintAliyunOss;

  /// Tencent Cloud COS setup note.
  ///
  /// In en, this message translates to:
  /// **'The bucket name must include the APPID suffix (e.g. backup-1250000000); create keys under CAM → API keys.'**
  String get cloudBackupHintTencentCos;

  /// Qiniu Kodo setup note.
  ///
  /// In en, this message translates to:
  /// **'The S3 bucket name may differ from the Kodo space name; use the one shown in the console.'**
  String get cloudBackupHintQiniuKodo;

  /// Cloudflare R2 setup note.
  ///
  /// In en, this message translates to:
  /// **'Replace ACCOUNT_ID with your Cloudflare account ID, create a token under R2 → Manage API tokens and use its S3 credentials; keep the region as auto.'**
  String get cloudBackupHintR2;

  /// Backblaze B2 setup note.
  ///
  /// In en, this message translates to:
  /// **'Use the endpoint shown on the bucket page and its region part (e.g. us-west-004) as the region; use an Application Key.'**
  String get cloudBackupHintB2;

  /// DigitalOcean Spaces setup note.
  ///
  /// In en, this message translates to:
  /// **'Put the Spaces datacenter (e.g. nyc3) in the endpoint and keep the signing region as us-east-1.'**
  String get cloudBackupHintDigitalOcean;

  /// MinIO setup note.
  ///
  /// In en, this message translates to:
  /// **'Enter the MinIO API address (default port 9000) and keep path-style access on.'**
  String get cloudBackupHintMinio;

  /// Google Cloud Storage setup note.
  ///
  /// In en, this message translates to:
  /// **'Create HMAC keys under Cloud Storage → Settings → Interoperability.'**
  String get cloudBackupHintGcs;

  /// Oracle Cloud setup note.
  ///
  /// In en, this message translates to:
  /// **'Find NAMESPACE and REGION in the OCI console and use a Customer Secret Key.'**
  String get cloudBackupHintOracle;

  /// Google Drive storage note.
  ///
  /// In en, this message translates to:
  /// **'Backups are stored in the \"Jotsy\" folder of Google Drive; the app can only access files it created. Deleted backups skip the trash.'**
  String get cloudBackupFolderGoogleDrive;

  /// OneDrive storage note.
  ///
  /// In en, this message translates to:
  /// **'Backups are stored in this app\'s folder under Apps in OneDrive; the app can only access that folder. Deleted backups go to the OneDrive recycle bin.'**
  String get cloudBackupFolderOneDrive;

  /// Dropbox storage note.
  ///
  /// In en, this message translates to:
  /// **'Backups are stored in this app\'s folder under Apps in Dropbox; the app can only access that folder.'**
  String get cloudBackupFolderDropbox;

  /// Baidu Netdisk storage note.
  ///
  /// In en, this message translates to:
  /// **'Backups are stored in this app\'s folder under My App Data in Baidu Netdisk.'**
  String get cloudBackupFolderBaidu;

  /// Alipan storage note.
  ///
  /// In en, this message translates to:
  /// **'Backups are stored in the folder chosen during authorization (or \"Jotsy\" at the root). Deleted backups go to the trash. Re-authorize when Alipan ends the authorization.'**
  String get cloudBackupFolderAliyun;

  /// Location config section title.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get cloudBackupConfigSection;

  /// Save location config button.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get cloudBackupSaveConfig;

  /// Test connection button.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get cloudBackupTestConnection;

  /// Upload current backup button.
  ///
  /// In en, this message translates to:
  /// **'Upload backup'**
  String get cloudBackupUploadBackup;

  /// Refresh remote list button.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get cloudBackupRefreshBackups;

  /// Remote backup list title.
  ///
  /// In en, this message translates to:
  /// **'Remote backups'**
  String get cloudBackupBackupList;

  /// Remote backup list empty state.
  ///
  /// In en, this message translates to:
  /// **'No remote backups yet'**
  String get cloudBackupNoBackups;

  /// Remote backup time.
  ///
  /// In en, this message translates to:
  /// **'Time: {time}'**
  String cloudBackupBackupTime(String time);

  /// Remote backup size.
  ///
  /// In en, this message translates to:
  /// **'Size: {size}'**
  String cloudBackupBackupSize(String size);

  /// Restore remote backup action.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get cloudBackupRestoreAction;

  /// Delete remote backup action.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get cloudBackupDeleteAction;

  /// Delete remote backup dialog title.
  ///
  /// In en, this message translates to:
  /// **'Delete remote backup?'**
  String get cloudBackupDeleteConfirmTitle;

  /// Delete remote backup dialog body.
  ///
  /// In en, this message translates to:
  /// **'Delete {fileName} from this backup location? This cannot be undone.'**
  String cloudBackupDeleteConfirmContent(String fileName);

  /// Remove location button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove this location'**
  String get cloudBackupRemoveTarget;

  /// Remove location dialog title.
  ///
  /// In en, this message translates to:
  /// **'Remove backup location?'**
  String get cloudBackupRemoveTargetTitle;

  /// Remove location dialog body.
  ///
  /// In en, this message translates to:
  /// **'Only the connection details and authorization saved on this device are removed. Backups already stored there are kept, and you can add the location again later.'**
  String get cloudBackupRemoveTargetContent;

  /// Remove location confirm button.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get cloudBackupRemoveTargetAction;

  /// Location removed message.
  ///
  /// In en, this message translates to:
  /// **'Backup location removed'**
  String get cloudBackupRemoved;

  /// Config saved message.
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get cloudBackupConfigSaved;

  /// Connection test success message.
  ///
  /// In en, this message translates to:
  /// **'Connection successful'**
  String get cloudBackupConnectionOk;

  /// Upload success message.
  ///
  /// In en, this message translates to:
  /// **'Backup uploaded'**
  String get cloudBackupUploadSuccess;

  /// Restore success message.
  ///
  /// In en, this message translates to:
  /// **'Data restored from the remote backup'**
  String get cloudBackupRestoreSuccess;

  /// Delete success message.
  ///
  /// In en, this message translates to:
  /// **'Remote backup deleted'**
  String get cloudBackupDeleteSuccess;

  /// Authorized drive without an account name.
  ///
  /// In en, this message translates to:
  /// **'Authorized'**
  String get cloudBackupAccountAuthorized;

  /// Authorized drive account.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {account}'**
  String cloudBackupAccountConnected(String account);

  /// Re-authorize button.
  ///
  /// In en, this message translates to:
  /// **'Re-authorize'**
  String get cloudBackupReauthorize;

  /// Authorization success message.
  ///
  /// In en, this message translates to:
  /// **'Connected to {name}'**
  String cloudBackupAuthorized(String name);

  /// Authorization dialog title.
  ///
  /// In en, this message translates to:
  /// **'Authorize {name}'**
  String cloudBackupAuthorizeTitle(String name);

  /// Device code authorization instructions.
  ///
  /// In en, this message translates to:
  /// **'Open the authorization page, sign in and enter the code below. This continues automatically once you approve.'**
  String get cloudBackupDeviceCodeHint;

  /// Accessibility label of the device code.
  ///
  /// In en, this message translates to:
  /// **'Authorization code'**
  String get cloudBackupDeviceCodeLabel;

  /// Copy device code button.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get cloudBackupCopyCode;

  /// Device code copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get cloudBackupDeviceCodeCopied;

  /// Open authorization page button.
  ///
  /// In en, this message translates to:
  /// **'Open authorization page'**
  String get cloudBackupOpenAuthorizePage;

  /// Waiting for device authorization.
  ///
  /// In en, this message translates to:
  /// **'Waiting for authorization…'**
  String get cloudBackupWaitingAuthorization;

  /// Paste authorization code instructions.
  ///
  /// In en, this message translates to:
  /// **'After you authorize in the browser, the page shows an authorization code. Copy it and paste it here.'**
  String get cloudBackupCodePasteHint;

  /// Authorization code field label.
  ///
  /// In en, this message translates to:
  /// **'Authorization code'**
  String get cloudBackupCodeLabel;

  /// Submit authorization code button.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get cloudBackupCodeConfirm;

  /// Cloud backup busy overlay accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Cloud backup in progress'**
  String get cloudBackupBusyLabel;

  /// Saving config.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get cloudBackupBusySave;

  /// Testing connection.
  ///
  /// In en, this message translates to:
  /// **'Testing connection…'**
  String get cloudBackupBusyTest;

  /// Creating backup.
  ///
  /// In en, this message translates to:
  /// **'Creating backup…'**
  String get cloudBackupBusyUpload;

  /// Upload progress.
  ///
  /// In en, this message translates to:
  /// **'Uploading {percent}%'**
  String cloudBackupBusyUploadProgress(int percent);

  /// Downloading backup.
  ///
  /// In en, this message translates to:
  /// **'Downloading backup…'**
  String get cloudBackupBusyDownload;

  /// Download progress.
  ///
  /// In en, this message translates to:
  /// **'Downloading {percent}%'**
  String cloudBackupBusyDownloadProgress(int percent);

  /// Restoring data.
  ///
  /// In en, this message translates to:
  /// **'Restoring data…'**
  String get cloudBackupBusyRestore;

  /// Loading remote list.
  ///
  /// In en, this message translates to:
  /// **'Loading remote backups…'**
  String get cloudBackupBusyRefresh;

  /// Deleting remote backup.
  ///
  /// In en, this message translates to:
  /// **'Deleting remote backup…'**
  String get cloudBackupBusyDelete;

  /// Verifying authorization.
  ///
  /// In en, this message translates to:
  /// **'Verifying authorization…'**
  String get cloudBackupBusyAuthorize;

  /// Cloud backup failure message.
  ///
  /// In en, this message translates to:
  /// **'Operation failed: {detail}'**
  String cloudBackupOperationFailed(String detail);

  /// Config error.
  ///
  /// In en, this message translates to:
  /// **'Check that the address, bucket and folder settings are complete and correct'**
  String get cloudBackupErrorConfig;

  /// Missing app key.
  ///
  /// In en, this message translates to:
  /// **'This build has no app key for this drive, so it is unavailable'**
  String get cloudBackupErrorAppKeyMissing;

  /// Authentication failed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed or access denied; check the account, password or keys'**
  String get cloudBackupErrorAuth;

  /// Authorization expired.
  ///
  /// In en, this message translates to:
  /// **'The authorization has expired; please re-authorize'**
  String get cloudBackupErrorSessionExpired;

  /// Authorization declined.
  ///
  /// In en, this message translates to:
  /// **'Authorization was declined'**
  String get cloudBackupErrorAuthorizationDenied;

  /// Authorization code expired.
  ///
  /// In en, this message translates to:
  /// **'The code is invalid or expired; please get a new one'**
  String get cloudBackupErrorAuthorizationExpired;

  /// Remote not found.
  ///
  /// In en, this message translates to:
  /// **'The remote file or folder does not exist'**
  String get cloudBackupErrorNotFound;

  /// Out of space.
  ///
  /// In en, this message translates to:
  /// **'The backup location is out of space'**
  String get cloudBackupErrorStorageFull;

  /// File too large.
  ///
  /// In en, this message translates to:
  /// **'The backup exceeds the file size limit of this location'**
  String get cloudBackupErrorFileTooLarge;

  /// Rate limited.
  ///
  /// In en, this message translates to:
  /// **'Too many requests; please try again later'**
  String get cloudBackupErrorRateLimited;

  /// Network error.
  ///
  /// In en, this message translates to:
  /// **'Network request failed; check the network, address and certificate'**
  String get cloudBackupErrorNetwork;

  /// Unexpected response.
  ///
  /// In en, this message translates to:
  /// **'The backup location returned an unexpected response'**
  String get cloudBackupErrorProtocol;

  /// Wrong backup password.
  ///
  /// In en, this message translates to:
  /// **'Incorrect backup password'**
  String get cloudBackupErrorPassword;

  /// Damaged backup.
  ///
  /// In en, this message translates to:
  /// **'The backup is damaged or not a Jotsy backup'**
  String get cloudBackupErrorArchive;

  /// Local file error.
  ///
  /// In en, this message translates to:
  /// **'Failed to read or write a local temporary file; check free storage'**
  String get cloudBackupErrorLocalFile;

  /// Unknown error.
  ///
  /// In en, this message translates to:
  /// **'An unknown error occurred; please try again later'**
  String get cloudBackupErrorUnknown;

  /// S3 endpoint field label.
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get s3Endpoint;

  /// S3 endpoint field hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. https://s3.us-east-1.amazonaws.com'**
  String get s3EndpointHint;

  /// S3 region field label.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get s3Region;

  /// S3 region field hint.
  ///
  /// In en, this message translates to:
  /// **'Defaults to us-east-1'**
  String get s3RegionHint;

  /// S3 bucket field label.
  ///
  /// In en, this message translates to:
  /// **'Bucket'**
  String get s3Bucket;

  /// S3 access key ID field label.
  ///
  /// In en, this message translates to:
  /// **'Access Key ID'**
  String get s3AccessKeyId;

  /// S3 secret key field label.
  ///
  /// In en, this message translates to:
  /// **'Secret Access Key'**
  String get s3SecretAccessKey;

  /// S3 key prefix field label.
  ///
  /// In en, this message translates to:
  /// **'Backup folder (key prefix)'**
  String get s3Prefix;

  /// S3 key prefix field hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. jotsy/; leave empty for the bucket root'**
  String get s3PrefixHint;

  /// S3 path-style switch.
  ///
  /// In en, this message translates to:
  /// **'Path-style access'**
  String get s3PathStyle;

  /// S3 path-style switch description.
  ///
  /// In en, this message translates to:
  /// **'Usually required by self-hosted services such as MinIO'**
  String get s3PathStyleSubtitle;

  /// S3 path-style unavailable note.
  ///
  /// In en, this message translates to:
  /// **'This service only supports virtual-hosted-style access'**
  String get s3PathStyleLocked;

  /// System authorization unavailable and no fallback configured.
  ///
  /// In en, this message translates to:
  /// **'System account authorization is unavailable on this device (Google Play services required), and this build has no fallback'**
  String get cloudBackupErrorPlatformUnavailable;

  /// Publish page: hint shown when the time capsule's unlock time is no longer in the future at publish time.
  ///
  /// In en, this message translates to:
  /// **'The unlock time has passed. Choose a new one before sealing.'**
  String get timeCapsuleUnlockPassed;

  /// Weather fetch hint: the configured QWeather API host is invalid.
  ///
  /// In en, this message translates to:
  /// **'The weather service host is set up incorrectly. Check qweather.api_host.'**
  String get weatherInvalidHost;

  /// Weather fetch hint: network failure or timeout.
  ///
  /// In en, this message translates to:
  /// **'The weather request failed or timed out. Check your connection and try again.'**
  String get weatherNetworkError;

  /// Weather fetch hint: the weather service returned an error, or failed unexpectedly.
  ///
  /// In en, this message translates to:
  /// **'The weather service is temporarily unavailable. Please try again later.'**
  String get weatherApiError;

  /// Weather fetch hint: the response could not be understood.
  ///
  /// In en, this message translates to:
  /// **'No usable weather was returned. Please try again later or enter it manually.'**
  String get weatherParseError;

  /// Diary metadata panel hint: copying the picked cover image failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t import this picture as the cover. Please try another one.'**
  String get publishCoverImportFailed;

  /// Diary metadata panel hint: creating a tag inline failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the tag. Please try again.'**
  String get publishTagCreateFailed;

  /// Publish page hint: writing the new diary failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t publish the diary. Please try again.'**
  String get publishFailed;

  /// Publish panel: the publish time row while a time lock is set; the diary is dated at the unlock time.
  ///
  /// In en, this message translates to:
  /// **'Follows the time lock · {time}'**
  String publishTimeFollowsCapsule(String time);

  /// Diary metadata panel: hint next to the cover thumbnail once a cover is set.
  ///
  /// In en, this message translates to:
  /// **'Tap to change'**
  String get publishCoverChange;

  /// Publish panel collapsed bar: shown when no metadata has been chosen yet.
  ///
  /// In en, this message translates to:
  /// **'Add tags, mood, place…'**
  String get publishPanelSummaryEmpty;

  /// Publish panel collapsed bar: short label of the publish button.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get publishPanelPublishShort;

  /// Publish panel collapsed bar: short label of the publish button when a time lock is set.
  ///
  /// In en, this message translates to:
  /// **'Seal'**
  String get publishPanelSealShort;

  /// Preview page action sheet entry that opens the share sheet.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get previewShare;

  /// Title of the diary share sheet.
  ///
  /// In en, this message translates to:
  /// **'Share diary'**
  String get diaryShareSheetTitle;

  /// Share sheet section header for the content toggles.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get diaryShareContentSection;

  /// Share sheet toggle: include the title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get diaryShareOptionTitle;

  /// Share sheet toggle: include the body text.
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get diaryShareOptionBody;

  /// Share sheet toggle: include the date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get diaryShareOptionDate;

  /// Share sheet toggle: include mood and weather.
  ///
  /// In en, this message translates to:
  /// **'Mood & weather'**
  String get diaryShareOptionMoodWeather;

  /// Share sheet toggle: include the location (off by default).
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get diaryShareOptionLocation;

  /// Share sheet toggle: include tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get diaryShareOptionTags;

  /// Share sheet toggle: attach images.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get diaryShareOptionImages;

  /// Share sheet placeholder when the composed text is empty.
  ///
  /// In en, this message translates to:
  /// **'No text selected — only images will be shared'**
  String get diaryShareTextEmpty;

  /// Share sheet: number of selected images.
  ///
  /// In en, this message translates to:
  /// **'{selected} of {total} selected'**
  String diaryShareImagesSelected(int selected, int total);

  /// Share sheet: accessibility label of an image choice.
  ///
  /// In en, this message translates to:
  /// **'Image {index}'**
  String diaryShareImageLabel(int index);

  /// Share sheet section header for share targets; also the chooser title.
  ///
  /// In en, this message translates to:
  /// **'Share to'**
  String get diaryShareTargetsSection;

  /// Share target: Weibo.
  ///
  /// In en, this message translates to:
  /// **'Weibo'**
  String get diaryShareTargetWeibo;

  /// Share target: Xiaohongshu (RED).
  ///
  /// In en, this message translates to:
  /// **'Xiaohongshu'**
  String get diaryShareTargetXiaohongshu;

  /// Share target: WeChat.
  ///
  /// In en, this message translates to:
  /// **'WeChat'**
  String get diaryShareTargetWechat;

  /// Share target: WeChat Moments.
  ///
  /// In en, this message translates to:
  /// **'Moments'**
  String get diaryShareTargetWechatMoments;

  /// Share target: QQ.
  ///
  /// In en, this message translates to:
  /// **'QQ'**
  String get diaryShareTargetQq;

  /// Share target: Qzone.
  ///
  /// In en, this message translates to:
  /// **'Qzone'**
  String get diaryShareTargetQzone;

  /// Share target: the system share sheet.
  ///
  /// In en, this message translates to:
  /// **'More apps'**
  String get diaryShareTargetSystem;

  /// Share sheet action: copy the text only.
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get diaryShareCopyText;

  /// Share sheet note: text goes through the clipboard when images are attached.
  ///
  /// In en, this message translates to:
  /// **'When images are attached, the text is copied for you — just paste it into the post.'**
  String get diaryShareClipboardHint;

  /// Share sheet section header for other formats.
  ///
  /// In en, this message translates to:
  /// **'Other formats'**
  String get diaryShareMoreSection;

  /// Share sheet action: share the whole diary as one long image.
  ///
  /// In en, this message translates to:
  /// **'Share as long image'**
  String get diaryShareLongImage;

  /// Share sheet: subtitle of the long-image action.
  ///
  /// In en, this message translates to:
  /// **'Renders the diary as it looks in the preview'**
  String get diaryShareLongImageSubtitle;

  /// Share sheet hint when the target app needs an image.
  ///
  /// In en, this message translates to:
  /// **'{app} needs at least one image'**
  String diaryShareRequiresImage(String app);

  /// Share sheet hint when several installed target apps need an image.
  ///
  /// In en, this message translates to:
  /// **'Greyed-out apps need at least one image'**
  String get diaryShareRequiresImageSeveral;

  /// Share sheet hint when neither text nor images are selected.
  ///
  /// In en, this message translates to:
  /// **'Choose something to share first'**
  String get diaryShareNothingSelected;

  /// Loading overlay label while a share is prepared.
  ///
  /// In en, this message translates to:
  /// **'Preparing to share'**
  String get diaryShareInProgress;

  /// Hint after sharing images to an app: the text is on the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Text copied — paste it in {app}'**
  String diaryShareTextCopiedForApp(String app);

  /// Hint after sharing images via the system sheet: the text is on the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Text copied — paste it in the app you shared to'**
  String get diaryShareTextCopied;

  /// Hint after copying the text.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get diaryShareCopied;

  /// Hint when more images were selected than the target accepts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Only 1 image per share — the rest weren\'t sent} other{Up to {count} images per share — the rest weren\'t sent}}'**
  String diaryShareImagesTrimmed(int count);

  /// Hint when some images could not be read.
  ///
  /// In en, this message translates to:
  /// **'{count} image(s) could not be read and were left out'**
  String diaryShareImagesMissing(int count);

  /// Hint when the target app cannot receive the share.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open {app}. Make sure it is installed and up to date'**
  String diaryShareAppUnavailable(String app);

  /// Hint when there is nothing to share.
  ///
  /// In en, this message translates to:
  /// **'Nothing to share'**
  String get diaryShareNothingToShare;

  /// Hint when sharing fails.
  ///
  /// In en, this message translates to:
  /// **'Share failed: {error}'**
  String diaryShareFailed(String error);

  /// Preview action sheet entry that opens the export sheet.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get previewExport;

  /// Diary list selection bar: tooltip of the export button.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get diaryExportSelected;

  /// Data management entry that opens diary export.
  ///
  /// In en, this message translates to:
  /// **'Export diaries'**
  String get dataMgmtExportDiaries;

  /// Subtitle of the diary export entry in data management.
  ///
  /// In en, this message translates to:
  /// **'Export by date or tag as PDF, Word, Markdown, web page and more'**
  String get dataMgmtExportDiariesSubtitle;

  /// Title of the export sheet.
  ///
  /// In en, this message translates to:
  /// **'Export diaries'**
  String get diaryExportSheetTitle;

  /// Export sheet: number of diaries to export.
  ///
  /// In en, this message translates to:
  /// **'{count} diaries'**
  String diaryExportSheetCount(int count);

  /// Export sheet section header for formats.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get diaryExportFormatSection;

  /// Export sheet section header for options.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get diaryExportOptionsSection;

  /// Export format name: PDF.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get diaryExportFormatPdf;

  /// Export format description: PDF.
  ///
  /// In en, this message translates to:
  /// **'Fixed layout for reading and printing'**
  String get diaryExportFormatPdfDescription;

  /// Export format name: Word document.
  ///
  /// In en, this message translates to:
  /// **'Word document'**
  String get diaryExportFormatWord;

  /// Export format description: Word document.
  ///
  /// In en, this message translates to:
  /// **'.docx you can keep editing'**
  String get diaryExportFormatWordDescription;

  /// Export format name: Markdown.
  ///
  /// In en, this message translates to:
  /// **'Markdown'**
  String get diaryExportFormatMarkdown;

  /// Export format description: Markdown.
  ///
  /// In en, this message translates to:
  /// **'With front matter for Obsidian and other note apps; can be imported back into Jotsy'**
  String get diaryExportFormatMarkdownDescription;

  /// Export format name: Web page.
  ///
  /// In en, this message translates to:
  /// **'Web page'**
  String get diaryExportFormatHtml;

  /// Export format description: Web page.
  ///
  /// In en, this message translates to:
  /// **'Opens in any browser; several diaries with images come as a page plus an image folder'**
  String get diaryExportFormatHtmlDescription;

  /// Export format name: Plain text.
  ///
  /// In en, this message translates to:
  /// **'Plain text'**
  String get diaryExportFormatText;

  /// Export format description: Plain text.
  ///
  /// In en, this message translates to:
  /// **'.txt that opens anywhere'**
  String get diaryExportFormatTextDescription;

  /// Export format name: Spreadsheet (CSV).
  ///
  /// In en, this message translates to:
  /// **'Spreadsheet (CSV)'**
  String get diaryExportFormatCsv;

  /// Export format description: Spreadsheet (CSV).
  ///
  /// In en, this message translates to:
  /// **'One row per diary with mood, weather and more for Excel'**
  String get diaryExportFormatCsvDescription;

  /// Export format name: Jotsy diary file.
  ///
  /// In en, this message translates to:
  /// **'Jotsy diary file'**
  String get diaryExportFormatDiaryFile;

  /// Export format description: Jotsy diary file.
  ///
  /// In en, this message translates to:
  /// **'Keeps everything including media, optional password, lossless re-import'**
  String get diaryExportFormatDiaryFileDescription;

  /// Export option: include images.
  ///
  /// In en, this message translates to:
  /// **'Include images'**
  String get diaryExportIncludeImages;

  /// Export option (Markdown): bundle all media.
  ///
  /// In en, this message translates to:
  /// **'Include images, recordings, videos and attachments'**
  String get diaryExportIncludeMedia;

  /// Export option: include mood, weather, location and tags.
  ///
  /// In en, this message translates to:
  /// **'Include mood, weather, location and tags'**
  String get diaryExportIncludeMeta;

  /// Export option: oldest first.
  ///
  /// In en, this message translates to:
  /// **'Oldest first'**
  String get diaryExportOrderOldest;

  /// Export option: newest first.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get diaryExportOrderNewest;

  /// Export sheet: save button.
  ///
  /// In en, this message translates to:
  /// **'Save to files'**
  String get diaryExportSave;

  /// Loading overlay label while exporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting'**
  String get diaryExportInProgress;

  /// Hint after the export is saved.
  ///
  /// In en, this message translates to:
  /// **'Exported {count} diaries'**
  String diaryExportSaved(int count);

  /// Hint when sealed time capsules were skipped.
  ///
  /// In en, this message translates to:
  /// **'{count} sealed time capsules were not exported'**
  String diaryExportSkippedCapsules(int count);

  /// Hint when only sealed time capsules were selected.
  ///
  /// In en, this message translates to:
  /// **'Only sealed time capsules were selected — nothing to export'**
  String get diaryExportOnlyCapsules;

  /// Hint when no diary matches the export scope.
  ///
  /// In en, this message translates to:
  /// **'No diaries match'**
  String get diaryExportNothing;

  /// Title of the diary export page.
  ///
  /// In en, this message translates to:
  /// **'Export diaries'**
  String get diaryExportPageTitle;

  /// Export page section header for the date range.
  ///
  /// In en, this message translates to:
  /// **'Date range'**
  String get diaryExportRangeSection;

  /// Export page: all diaries.
  ///
  /// In en, this message translates to:
  /// **'All diaries'**
  String get diaryExportRangeAll;

  /// Export page: this year.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get diaryExportRangeThisYear;

  /// Export page: last 30 days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get diaryExportRangeLast30Days;

  /// Export page: custom date range.
  ///
  /// In en, this message translates to:
  /// **'Custom dates'**
  String get diaryExportRangeCustom;

  /// Export page: the chosen custom range.
  ///
  /// In en, this message translates to:
  /// **'{start} – {end}, tap to change'**
  String diaryExportRangeCustomValue(String start, String end);

  /// Export page section header for tag filters.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get diaryExportTagsSection;

  /// Export page: how tag filters combine.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for all tags; any selected tag matches'**
  String get diaryExportTagsHint;

  /// Export page: include archived diaries.
  ///
  /// In en, this message translates to:
  /// **'Include archived diaries'**
  String get diaryExportIncludeArchived;

  /// Export page: number of matching diaries.
  ///
  /// In en, this message translates to:
  /// **'{count} diaries will be exported'**
  String diaryExportMatchCount(int count);

  /// Export page note about sealed capsules.
  ///
  /// In en, this message translates to:
  /// **'Sealed time capsules are never exported'**
  String get diaryExportCapsuleNote;

  /// Export page: continue button.
  ///
  /// In en, this message translates to:
  /// **'Choose format and export'**
  String get diaryExportNext;

  /// Text written inside exported files: Untitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get diaryExportLabelUntitled;

  /// Text written inside exported files: Mood.
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get diaryExportLabelMood;

  /// Text written inside exported files: Energy.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get diaryExportLabelEnergy;

  /// Text written inside exported files: Weather.
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get diaryExportLabelWeather;

  /// Text written inside exported files: Location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get diaryExportLabelLocation;

  /// Text written inside exported files: Tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get diaryExportLabelTags;

  /// Text written inside exported files: Date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get diaryExportLabelDate;

  /// Text written inside exported files: Time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get diaryExportLabelTime;

  /// Text written inside exported files: Title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get diaryExportLabelTitle;

  /// Text written inside exported files: Content.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get diaryExportLabelContent;

  /// Text written inside exported files: Characters.
  ///
  /// In en, this message translates to:
  /// **'Characters'**
  String get diaryExportLabelWordCount;

  /// Text written inside exported files: Last edited.
  ///
  /// In en, this message translates to:
  /// **'Last edited'**
  String get diaryExportLabelUpdated;

  /// Text written inside exported files: Image.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get diaryExportLabelImage;

  /// Text written inside exported files: Recording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get diaryExportLabelAudio;

  /// Text written inside exported files: Video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get diaryExportLabelVideo;

  /// Text written inside exported files: Attachment.
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get diaryExportLabelAttachment;

  /// Text written inside exported files: Exported from Jotsy.
  ///
  /// In en, this message translates to:
  /// **'Exported from Jotsy'**
  String get diaryExportLabelExportedBy;

  /// Hint when a PDF export has too many images.
  ///
  /// In en, this message translates to:
  /// **'Too many images (about {size} MB) for one PDF. Narrow the date range or turn off “Include images” and try again'**
  String diaryExportTooLarge(int size);

  /// Backfill photo strip title: number of photos taken that day.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo} other{{count} photos}} from this day'**
  String diaryDayPhotosTitle(int count);

  /// Backfill photo strip title before photo access is granted.
  ///
  /// In en, this message translates to:
  /// **'Photos from this day'**
  String get diaryDayPhotosAccessTitle;

  /// Backfill photo strip: explanation for requesting photo access.
  ///
  /// In en, this message translates to:
  /// **'Allow photo access to see the photos you took on this day and add some to this entry.'**
  String get diaryDayPhotosAccessBody;

  /// Backfill photo strip: explanation after photo access was denied.
  ///
  /// In en, this message translates to:
  /// **'Photo access is off. You can turn it on in system settings.'**
  String get diaryDayPhotosDeniedBody;

  /// Backfill photo strip: button that requests photo access.
  ///
  /// In en, this message translates to:
  /// **'Allow access'**
  String get diaryDayPhotosAllowAccess;

  /// Backfill photo strip: button that opens system settings to grant photo access.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get diaryDayPhotosOpenSettings;

  /// Backfill photo strip: button that opens the grid of all photos from that day.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get diaryDayPhotosShowAll;

  /// Backfill photo strip: tooltip of the close button.
  ///
  /// In en, this message translates to:
  /// **'Hide for this entry'**
  String get diaryDayPhotosDismiss;

  /// Photos from this day: number of selected photos.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String diaryDayPhotosSelected(int count);

  /// Photos from this day: button that clears the selection.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get diaryDayPhotosClear;

  /// Photos from this day: button that inserts the selected photos into the entry.
  ///
  /// In en, this message translates to:
  /// **'Insert'**
  String get diaryDayPhotosInsert;

  /// Photos from this day sheet: insert button with the number of selected photos.
  ///
  /// In en, this message translates to:
  /// **'Insert {count}'**
  String diaryDayPhotosInsertCount(int count);

  /// Photos from this day: note shown when photo access is limited.
  ///
  /// In en, this message translates to:
  /// **'Showing only photos you allowed'**
  String get diaryDayPhotosLimited;

  /// Photos from this day: button that lets the user allow more photos under limited access.
  ///
  /// In en, this message translates to:
  /// **'Select more'**
  String get diaryDayPhotosManageLimited;

  /// Photos from this day: screen reader label of a photo.
  ///
  /// In en, this message translates to:
  /// **'Photo taken at {time}'**
  String diaryDayPhotosPhotoLabel(String time);

  /// Photos from this day: screen reader label of a photo already inserted.
  ///
  /// In en, this message translates to:
  /// **'Photo taken at {time}, added'**
  String diaryDayPhotosInsertedLabel(String time);

  /// Photos from this day sheet title; date is the day.
  ///
  /// In en, this message translates to:
  /// **'Photos from {date}'**
  String diaryDayPhotosSheetTitle(String date);

  /// Hint when some photos from that day couldn't be read while inserting.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo couldn\'t be read and was skipped} other{{count} photos couldn\'t be read and were skipped}}'**
  String diaryDayPhotosMissing(int count);

  /// Editor settings: title of the switch that automatically shows that day's photos under the title when backfilling.
  ///
  /// In en, this message translates to:
  /// **'Show that day\'s photos automatically'**
  String get settingsDayPhotoSuggestions;

  /// Editor settings: description of the backfill photo suggestion switch.
  ///
  /// In en, this message translates to:
  /// **'When backfilling a past day, list that day\'s photos under the title. When off, open them from the editor\'s top-right menu.'**
  String get settingsDayPhotoSuggestionsSubtitle;

  /// Photos from this day: button and menu item that makes a photo the entry cover.
  ///
  /// In en, this message translates to:
  /// **'Set as cover'**
  String get diaryDayPhotosSetCover;

  /// Photos from this day: button and menu item that removes the cover.
  ///
  /// In en, this message translates to:
  /// **'Remove cover'**
  String get diaryDayPhotosClearCover;

  /// Photos from this day: badge on the photo used as the cover.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get diaryDayPhotosCoverBadge;

  /// Photos from this day: screen reader label of the cover photo.
  ///
  /// In en, this message translates to:
  /// **'{label}, cover'**
  String diaryDayPhotosCoverLabel(String label);

  /// Photos from this day: hint after a photo becomes the cover.
  ///
  /// In en, this message translates to:
  /// **'Set as cover. You can see or change it on the publish page.'**
  String get diaryDayPhotosCoverSet;

  /// Photos from this day: hint after a photo becomes the cover while editing an existing diary (there is no publish page).
  ///
  /// In en, this message translates to:
  /// **'Cover set'**
  String get diaryDayPhotosCoverSetEdit;

  /// Editor top-bar menu item: opens the panel of photos taken on the diary's day.
  ///
  /// In en, this message translates to:
  /// **'Photos from this day'**
  String get diaryDayPhotosMenu;

  /// Photos from this day panel: shown when the gallery has no photos from that day.
  ///
  /// In en, this message translates to:
  /// **'No photos taken this day'**
  String get diaryDayPhotosEmpty;

  /// Badge in the corner of a folded long image (much taller than wide) in the diary body.
  ///
  /// In en, this message translates to:
  /// **'Long image'**
  String get diaryLongImageBadge;

  /// Title of the menu shown when tapping an image in the diary body.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get diaryImageMenuTitle;

  /// Image menu: open this image in the image viewer.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get diaryImageMenuView;

  /// Image menu: open the width/height sliders to resize the image.
  ///
  /// In en, this message translates to:
  /// **'Resize'**
  String get diaryImageMenuResize;

  /// Image menu: copy the image (paste it back into the body or another app).
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get diaryImageMenuCopy;

  /// Preview settings, Body tab: how long images show in the body.
  ///
  /// In en, this message translates to:
  /// **'Long images'**
  String get diaryPreviewStyleLongImage;

  /// Explanation under the long image setting.
  ///
  /// In en, this message translates to:
  /// **'At least 3 times as tall as wide, like long screenshots. Tap a folded one to see it all.'**
  String get diaryPreviewStyleLongImageSubtitle;

  /// Long images: fold to a portrait box showing the top.
  ///
  /// In en, this message translates to:
  /// **'Fold'**
  String get diaryPreviewStyleLongImageFold;

  /// Long images: show the whole image at column width.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get diaryPreviewStyleLongImageFull;

  /// Title of the drafts page; also the entry name in the home header and settings.
  ///
  /// In en, this message translates to:
  /// **'Drafts'**
  String get diaryDraftsTitle;

  /// Subtitle of the drafts entry in Settings → Data & privacy.
  ///
  /// In en, this message translates to:
  /// **'Unpublished entries you can keep writing or delete'**
  String get diaryDraftsSettingsSubtitle;

  /// Empty state of the drafts page.
  ///
  /// In en, this message translates to:
  /// **'No drafts yet. New entries you leave before publishing are kept here'**
  String get diaryDraftsEmpty;

  /// Draft row footer: last edit time and word count (formatted number).
  ///
  /// In en, this message translates to:
  /// **'Edited {time} · {words} words'**
  String diaryDraftEditedAt(String time, String words);

  /// Snackbar after swiping a draft away (with undo).
  ///
  /// In en, this message translates to:
  /// **'Draft deleted'**
  String get diaryDraftDeleted;

  /// Snackbar after deleting selected drafts (with undo).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Deleted 1 draft} other{Deleted {count} drafts}}'**
  String diaryDraftsDeleted(int count);

  /// Title of the confirm dialog for deleting selected drafts.
  ///
  /// In en, this message translates to:
  /// **'Delete drafts'**
  String get diaryDraftsDeleteTitle;

  /// Body of the confirm dialog for deleting selected drafts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delete the selected draft?} other{Delete the {count} selected drafts?}}'**
  String diaryDraftsDeleteMessage(int count);

  /// Snackbar when deleting drafts fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the drafts. Try again'**
  String get diaryDraftsDeleteFailed;

  /// Snackbar when restoring deleted drafts fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t undo. Try again'**
  String get diaryDraftsRestoreFailed;

  /// Title of the sheet shown on “New” when drafts exist.
  ///
  /// In en, this message translates to:
  /// **'Continue a draft'**
  String get diaryDraftPickerTitle;

  /// Draft picker: open the drafts page; the number is the total count.
  ///
  /// In en, this message translates to:
  /// **'View all drafts ({count})'**
  String diaryDraftPickerViewAll(int count);

  /// Draft picker: start a blank entry instead (drafts stay in the drafts box).
  ///
  /// In en, this message translates to:
  /// **'New blank entry'**
  String get diaryDraftPickerNewBlank;

  /// Hint text of the search pill in the home header.
  ///
  /// In en, this message translates to:
  /// **'Search in Jotsy'**
  String get diarySearchPreviewHint;

  /// Bullet in the replace-everything warning: user-made diary templates that will be deleted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 diary template} other{{count} diary templates}}'**
  String backupOverwriteAllTemplates(int count);

  /// Extra line of the merge import result: diary templates added (existing ones are never replaced).
  ///
  /// In en, this message translates to:
  /// **'{added, plural, =1{Templates: 1 added} other{Templates: {added} added}}'**
  String backupImportTemplateMergeResult(int added);

  /// Name of the built-in “Daily journal” diary template.
  ///
  /// In en, this message translates to:
  /// **'Daily journal'**
  String get diaryTemplateDailyName;

  /// One-line description of the built-in “Daily journal” template.
  ///
  /// In en, this message translates to:
  /// **'What happened today and how you feel right now'**
  String get diaryTemplateDailyDesc;

  /// Title pattern of the built-in “Daily journal” template. Placeholders receive variable tokens such as {{date}}, resolved when the template is applied.
  ///
  /// In en, this message translates to:
  /// **'{weekday}, {date}'**
  String diaryTemplateDailyTitle(String date, String weekday);

  /// Name of the built-in “Morning pages” diary template.
  ///
  /// In en, this message translates to:
  /// **'Morning pages'**
  String get diaryTemplateMorningName;

  /// One-line description of the built-in “Morning pages” template.
  ///
  /// In en, this message translates to:
  /// **'Set the tone for the day with a page in the morning'**
  String get diaryTemplateMorningDesc;

  /// Title pattern of the built-in “Morning pages” template. Placeholders receive variable tokens such as {{date}}, resolved when the template is applied.
  ///
  /// In en, this message translates to:
  /// **'Morning · {date}'**
  String diaryTemplateMorningTitle(String date);

  /// Name of the built-in “Evening review” diary template.
  ///
  /// In en, this message translates to:
  /// **'Evening review'**
  String get diaryTemplateEveningName;

  /// One-line description of the built-in “Evening review” template.
  ///
  /// In en, this message translates to:
  /// **'Look back on the day and plan tomorrow'**
  String get diaryTemplateEveningDesc;

  /// Title pattern of the built-in “Evening review” template. Placeholders receive variable tokens such as {{date}}, resolved when the template is applied.
  ///
  /// In en, this message translates to:
  /// **'Review · {date}'**
  String diaryTemplateEveningTitle(String date);

  /// Name of the built-in “Gratitude journal” diary template.
  ///
  /// In en, this message translates to:
  /// **'Gratitude journal'**
  String get diaryTemplateGratitudeName;

  /// One-line description of the built-in “Gratitude journal” template.
  ///
  /// In en, this message translates to:
  /// **'Three things you\'re grateful for'**
  String get diaryTemplateGratitudeDesc;

  /// Title pattern of the built-in “Gratitude journal” template. Placeholders receive variable tokens such as {{date}}, resolved when the template is applied.
  ///
  /// In en, this message translates to:
  /// **'Gratitude · {date}'**
  String diaryTemplateGratitudeTitle(String date);

  /// Name of the built-in “Question of the day” diary template.
  ///
  /// In en, this message translates to:
  /// **'Question of the day'**
  String get diaryTemplateQuestionName;

  /// One-line description of the built-in “Question of the day” template.
  ///
  /// In en, this message translates to:
  /// **'One question a day to see yourself from a new angle'**
  String get diaryTemplateQuestionDesc;

  /// Title pattern of the built-in “Question of the day” template. Placeholders receive variable tokens such as {{date}}, resolved when the template is applied.
  ///
  /// In en, this message translates to:
  /// **'Question of the day · {date}'**
  String diaryTemplateQuestionTitle(String date);

  /// Name of the built-in “Weekly review” diary template.
  ///
  /// In en, this message translates to:
  /// **'Weekly review'**
  String get diaryTemplateWeeklyName;

  /// One-line description of the built-in “Weekly review” template.
  ///
  /// In en, this message translates to:
  /// **'Highlights, wins and next week\'s plan'**
  String get diaryTemplateWeeklyDesc;

  /// Title pattern of the built-in “Weekly review” template. Placeholders receive variable tokens such as {{date}}, resolved when the template is applied.
  ///
  /// In en, this message translates to:
  /// **'Weekly review · {date}'**
  String diaryTemplateWeeklyTitle(String date);

  /// Name of the built-in “Untangle a feeling” diary template.
  ///
  /// In en, this message translates to:
  /// **'Untangle a feeling'**
  String get diaryTemplateEmotionName;

  /// One-line description of the built-in “Untangle a feeling” template.
  ///
  /// In en, this message translates to:
  /// **'Write a feeling down and see where it comes from'**
  String get diaryTemplateEmotionDesc;

  /// Title pattern of the built-in “Untangle a feeling” template. Placeholders receive variable tokens such as {{date}}, resolved when the template is applied.
  ///
  /// In en, this message translates to:
  /// **'Feelings · {date}'**
  String diaryTemplateEmotionTitle(String date);

  /// Name of the built-in “Reading notes” diary template.
  ///
  /// In en, this message translates to:
  /// **'Reading notes'**
  String get diaryTemplateReadingName;

  /// One-line description of the built-in “Reading notes” template.
  ///
  /// In en, this message translates to:
  /// **'Quotes and thoughts from what you read'**
  String get diaryTemplateReadingDesc;

  /// Title pattern of the built-in “Reading notes” template. Placeholders receive variable tokens such as {{date}}, resolved when the template is applied.
  ///
  /// In en, this message translates to:
  /// **'Reading notes · {date}'**
  String diaryTemplateReadingTitle(String date);

  /// Body line of a built-in diary template (Daily).
  ///
  /// In en, this message translates to:
  /// **'What happened today'**
  String get diaryTemplateDailyHappened;

  /// Body line of a built-in diary template (Daily).
  ///
  /// In en, this message translates to:
  /// **'The moment that stayed with me'**
  String get diaryTemplateDailyMoment;

  /// Body line of a built-in diary template (Daily).
  ///
  /// In en, this message translates to:
  /// **'How I feel right now'**
  String get diaryTemplateDailyMood;

  /// Body line of a built-in diary template (Morning). Placeholders receive template variable tokens.
  ///
  /// In en, this message translates to:
  /// **'Up at {time}.'**
  String diaryTemplateMorningWake(String time, String term);

  /// Body line of a built-in diary template (Morning).
  ///
  /// In en, this message translates to:
  /// **'Three things that matter most today'**
  String get diaryTemplateMorningTop3;

  /// Body line of a built-in diary template (Morning).
  ///
  /// In en, this message translates to:
  /// **'Something I\'m looking forward to'**
  String get diaryTemplateMorningLookForward;

  /// Body line of a built-in diary template (Morning).
  ///
  /// In en, this message translates to:
  /// **'A line for today'**
  String get diaryTemplateMorningWords;

  /// Body line of a built-in diary template (Evening).
  ///
  /// In en, this message translates to:
  /// **'Done today'**
  String get diaryTemplateEveningDone;

  /// Body line of a built-in diary template (Evening).
  ///
  /// In en, this message translates to:
  /// **'What went well'**
  String get diaryTemplateEveningWentWell;

  /// Body line of a built-in diary template (Evening).
  ///
  /// In en, this message translates to:
  /// **'What could be better'**
  String get diaryTemplateEveningBetter;

  /// Body line of a built-in diary template (Evening).
  ///
  /// In en, this message translates to:
  /// **'Plans for tomorrow'**
  String get diaryTemplateEveningTomorrow;

  /// Body line of a built-in diary template (Gratitude).
  ///
  /// In en, this message translates to:
  /// **'Three things I\'m grateful for today:'**
  String get diaryTemplateGratitudeThree;

  /// Body line of a built-in diary template (Gratitude).
  ///
  /// In en, this message translates to:
  /// **'Someone I\'d like to thank'**
  String get diaryTemplateGratitudeThanks;

  /// Body line of a built-in diary template (Weekly).
  ///
  /// In en, this message translates to:
  /// **'Highlights of the week'**
  String get diaryTemplateWeeklyHighlights;

  /// Body line of a built-in diary template (Weekly).
  ///
  /// In en, this message translates to:
  /// **'Done and learned'**
  String get diaryTemplateWeeklyWins;

  /// Body line of a built-in diary template (Weekly).
  ///
  /// In en, this message translates to:
  /// **'Still open'**
  String get diaryTemplateWeeklyOpen;

  /// Body line of a built-in diary template (Weekly).
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get diaryTemplateWeeklyNext;

  /// Body line of a built-in diary template (Emotion).
  ///
  /// In en, this message translates to:
  /// **'What happened'**
  String get diaryTemplateEmotionHappened;

  /// Body line of a built-in diary template (Emotion).
  ///
  /// In en, this message translates to:
  /// **'What I felt'**
  String get diaryTemplateEmotionFelt;

  /// Body line of a built-in diary template (Emotion).
  ///
  /// In en, this message translates to:
  /// **'Where it comes from'**
  String get diaryTemplateEmotionSource;

  /// Body line of a built-in diary template (Emotion).
  ///
  /// In en, this message translates to:
  /// **'What I need'**
  String get diaryTemplateEmotionNeed;

  /// Body line of a built-in diary template (Emotion).
  ///
  /// In en, this message translates to:
  /// **'One small next step'**
  String get diaryTemplateEmotionStep;

  /// Body line of a built-in diary template (Reading).
  ///
  /// In en, this message translates to:
  /// **'Book: '**
  String get diaryTemplateReadingBook;

  /// Body line of a built-in diary template (Reading).
  ///
  /// In en, this message translates to:
  /// **'Author: '**
  String get diaryTemplateReadingAuthor;

  /// Body line of a built-in diary template (Reading).
  ///
  /// In en, this message translates to:
  /// **'Read up to: '**
  String get diaryTemplateReadingProgress;

  /// Body line of a built-in diary template (Reading).
  ///
  /// In en, this message translates to:
  /// **'Quotes'**
  String get diaryTemplateReadingQuotes;

  /// Body line of a built-in diary template (Reading).
  ///
  /// In en, this message translates to:
  /// **'My thoughts'**
  String get diaryTemplateReadingThoughts;

  /// Tag name preset by a built-in diary template (created when missing).
  ///
  /// In en, this message translates to:
  /// **'Gratitude'**
  String get diaryTemplateTagGratitude;

  /// Tag name preset by a built-in diary template (created when missing).
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get diaryTemplateTagReading;

  /// One question in the built-in question bank used by the {{question}} template variable.
  ///
  /// In en, this message translates to:
  /// **'What small thing made you smile today?'**
  String get diaryTemplateQuestion01;

  /// One question in the built-in question bank used by the {{question}} template variable.
  ///
  /// In en, this message translates to:
  /// **'If you could redo today, what would you change?'**
  String get diaryTemplateQuestion02;

  /// One question in the built-in question bank used by the {{question}} template variable.
  ///
  /// In en, this message translates to:
  /// **'When did you last feel proud of yourself?'**
  String get diaryTemplateQuestion03;

  /// One question in the built-in question bank used by the {{question}} template variable.
  ///
  /// In en, this message translates to:
  /// **'Who would you most like to say something to right now?'**
  String get diaryTemplateQuestion04;

  /// One question in the built-in question bank used by the {{question}} template variable.
  ///
  /// In en, this message translates to:
  /// **'What is one new thing you learned today?'**
  String get diaryTemplateQuestion05;

  /// One question in the built-in question bank used by the {{question}} template variable.
  ///
  /// In en, this message translates to:
  /// **'What has been weighing on your mind lately?'**
  String get diaryTemplateQuestion06;

  /// One question in the built-in question bank used by the {{question}} template variable.
  ///
  /// In en, this message translates to:
  /// **'What does your ideal weekend look like?'**
  String get diaryTemplateQuestion07;

  /// One question in the built-in question bank used by the {{question}} template variable.
  ///
  /// In en, this message translates to:
  /// **'Was there a moment today when you felt understood?'**
  String get diaryTemplateQuestion08;

  /// One question in the built-in question bank used by the {{question}} template variable.
  ///
  /// In en, this message translates to:
  /// **'What are you reading, watching or listening to lately, and what does it give you?'**
  String get diaryTemplateQuestion09;

  /// One question in the built-in question bank used by the {{question}} template variable.
  ///
  /// In en, this message translates to:
  /// **'Do you need rest, company or a challenge right now?'**
  String get diaryTemplateQuestion10;

  /// One question in the built-in question bank used by the {{question}} template variable.
  ///
  /// In en, this message translates to:
  /// **'What were you worried about a year ago today? And now?'**
  String get diaryTemplateQuestion11;

  /// One question in the built-in question bank used by the {{question}} template variable.
  ///
  /// In en, this message translates to:
  /// **'What did you do for yourself today?'**
  String get diaryTemplateQuestion12;

  /// One question in the built-in question bank used by the {{question}} template variable.
  ///
  /// In en, this message translates to:
  /// **'What made you laugh out loud recently?'**
  String get diaryTemplateQuestion13;

  /// One question in the built-in question bank used by the {{question}} template variable.
  ///
  /// In en, this message translates to:
  /// **'Which habit would you like to start or let go of?'**
  String get diaryTemplateQuestion14;

  /// One question in the built-in question bank used by the {{question}} template variable.
  ///
  /// In en, this message translates to:
  /// **'Describe yourself today in three words.'**
  String get diaryTemplateQuestion15;

  /// One question in the built-in question bank used by the {{question}} template variable.
  ///
  /// In en, this message translates to:
  /// **'What was the hardest part of today, and how did you handle it?'**
  String get diaryTemplateQuestion16;

  /// One question in the built-in question bank used by the {{question}} template variable.
  ///
  /// In en, this message translates to:
  /// **'Who are you grateful for lately, and why?'**
  String get diaryTemplateQuestion17;

  /// One question in the built-in question bank used by the {{question}} template variable.
  ///
  /// In en, this message translates to:
  /// **'If you could do only one thing tomorrow, what would it be?'**
  String get diaryTemplateQuestion18;

  /// One question in the built-in question bank used by the {{question}} template variable.
  ///
  /// In en, this message translates to:
  /// **'What changed your mind about something recently?'**
  String get diaryTemplateQuestion19;

  /// One question in the built-in question bank used by the {{question}} template variable.
  ///
  /// In en, this message translates to:
  /// **'What does today\'s weather remind you of?'**
  String get diaryTemplateQuestion20;

  /// One question in the built-in question bank used by the {{question}} template variable.
  ///
  /// In en, this message translates to:
  /// **'When did you last step out of your comfort zone?'**
  String get diaryTemplateQuestion21;

  /// One question in the built-in question bank used by the {{question}} template variable.
  ///
  /// In en, this message translates to:
  /// **'How will you see today\'s worries ten years from now?'**
  String get diaryTemplateQuestion22;

  /// One question in the built-in question bank used by the {{question}} template variable.
  ///
  /// In en, this message translates to:
  /// **'Did anything someone said today stay with you?'**
  String get diaryTemplateQuestion23;

  /// One question in the built-in question bank used by the {{question}} template variable.
  ///
  /// In en, this message translates to:
  /// **'Where have you felt most at peace lately?'**
  String get diaryTemplateQuestion24;

  /// One question in the built-in question bank used by the {{question}} template variable.
  ///
  /// In en, this message translates to:
  /// **'What would you tell your younger self?'**
  String get diaryTemplateQuestion25;

  /// One question in the built-in question bank used by the {{question}} template variable.
  ///
  /// In en, this message translates to:
  /// **'Do you know yourself a little better than yesterday?'**
  String get diaryTemplateQuestion26;

  /// One question in the built-in question bank used by the {{question}} template variable.
  ///
  /// In en, this message translates to:
  /// **'What small progress is worth celebrating lately?'**
  String get diaryTemplateQuestion27;

  /// One question in the built-in question bank used by the {{question}} template variable.
  ///
  /// In en, this message translates to:
  /// **'What have you wanted to try but haven\'t started? What\'s holding you back?'**
  String get diaryTemplateQuestion28;

  /// One question in the built-in question bank used by the {{question}} template variable.
  ///
  /// In en, this message translates to:
  /// **'How did you look after your feelings today?'**
  String get diaryTemplateQuestion29;

  /// One question in the built-in question bank used by the {{question}} template variable.
  ///
  /// In en, this message translates to:
  /// **'If you rated today from 1 to 10, what would it be, and why?'**
  String get diaryTemplateQuestion30;

  /// Template variable name inserted between double braces for the diary's date. Must be one of the aliases the app recognises.
  ///
  /// In en, this message translates to:
  /// **'date'**
  String get diaryTemplateVarDateToken;

  /// Label of the template variable for the diary's date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get diaryTemplateVarDateLabel;

  /// Template variable name inserted between double braces for the weekday of the diary's date. Must be one of the aliases the app recognises.
  ///
  /// In en, this message translates to:
  /// **'weekday'**
  String get diaryTemplateVarWeekdayToken;

  /// Label of the template variable for the weekday of the diary's date.
  ///
  /// In en, this message translates to:
  /// **'Weekday'**
  String get diaryTemplateVarWeekdayLabel;

  /// Template variable name inserted between double braces for the current time. Must be one of the aliases the app recognises.
  ///
  /// In en, this message translates to:
  /// **'time'**
  String get diaryTemplateVarTimeToken;

  /// Label of the template variable for the current time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get diaryTemplateVarTimeLabel;

  /// Template variable name inserted between double braces for the year of the diary's date. Must be one of the aliases the app recognises.
  ///
  /// In en, this message translates to:
  /// **'year'**
  String get diaryTemplateVarYearToken;

  /// Label of the template variable for the year of the diary's date.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get diaryTemplateVarYearLabel;

  /// Template variable name inserted between double braces for the month of the diary's date. Must be one of the aliases the app recognises.
  ///
  /// In en, this message translates to:
  /// **'month'**
  String get diaryTemplateVarMonthToken;

  /// Label of the template variable for the month of the diary's date.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get diaryTemplateVarMonthLabel;

  /// Template variable name inserted between double braces for the day of the month. Must be one of the aliases the app recognises.
  ///
  /// In en, this message translates to:
  /// **'day'**
  String get diaryTemplateVarDayToken;

  /// Label of the template variable for the day of the month.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get diaryTemplateVarDayLabel;

  /// Template variable name inserted between double braces for the ISO week number. Must be one of the aliases the app recognises.
  ///
  /// In en, this message translates to:
  /// **'week'**
  String get diaryTemplateVarWeekToken;

  /// Label of the template variable for the ISO week number.
  ///
  /// In en, this message translates to:
  /// **'Week number'**
  String get diaryTemplateVarWeekLabel;

  /// Template variable name inserted between double braces for which day of the year it is. Must be one of the aliases the app recognises.
  ///
  /// In en, this message translates to:
  /// **'dayOfYear'**
  String get diaryTemplateVarDayOfYearToken;

  /// Label of the template variable for which day of the year it is.
  ///
  /// In en, this message translates to:
  /// **'Day of the year'**
  String get diaryTemplateVarDayOfYearLabel;

  /// Template variable name inserted between double braces for how much of the year has passed, as a percentage. Must be one of the aliases the app recognises.
  ///
  /// In en, this message translates to:
  /// **'yearProgress'**
  String get diaryTemplateVarYearProgressToken;

  /// Label of the template variable for how much of the year has passed, as a percentage.
  ///
  /// In en, this message translates to:
  /// **'Year progress'**
  String get diaryTemplateVarYearProgressLabel;

  /// Template variable name inserted between double braces for the Chinese lunar date. Must be one of the aliases the app recognises.
  ///
  /// In en, this message translates to:
  /// **'lunar'**
  String get diaryTemplateVarLunarToken;

  /// Label of the template variable for the Chinese lunar date.
  ///
  /// In en, this message translates to:
  /// **'Lunar date'**
  String get diaryTemplateVarLunarLabel;

  /// Template variable name inserted between double braces for the current solar term. Must be one of the aliases the app recognises.
  ///
  /// In en, this message translates to:
  /// **'solarTerm'**
  String get diaryTemplateVarSolarTermToken;

  /// Label of the template variable for the current solar term.
  ///
  /// In en, this message translates to:
  /// **'Solar term'**
  String get diaryTemplateVarSolarTermLabel;

  /// Template variable name inserted between double braces for a question from the built-in question bank. Must be one of the aliases the app recognises.
  ///
  /// In en, this message translates to:
  /// **'question'**
  String get diaryTemplateVarQuestionToken;

  /// Label of the template variable for a question from the built-in question bank.
  ///
  /// In en, this message translates to:
  /// **'Question of the day'**
  String get diaryTemplateVarQuestionLabel;

  /// Diary template category, used as a filter in the template picker.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get diaryTemplateCategoryDaily;

  /// Diary template category, used as a filter in the template picker.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get diaryTemplateCategoryReview;

  /// Diary template category, used as a filter in the template picker.
  ///
  /// In en, this message translates to:
  /// **'Feelings'**
  String get diaryTemplateCategoryMood;

  /// Diary template category, used as a filter in the template picker.
  ///
  /// In en, this message translates to:
  /// **'Life'**
  String get diaryTemplateCategoryLife;

  /// Diary template category, used as a filter in the template picker.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get diaryTemplateCategoryWork;

  /// Diary template category, used as a filter in the template picker.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get diaryTemplateCategoryOther;

  /// Header of the template suggestion strip under the title of a blank new entry.
  ///
  /// In en, this message translates to:
  /// **'Start from a template'**
  String get diaryTemplateStripTitle;

  /// Template suggestion strip: open the full template picker.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get diaryTemplateStripAll;

  /// Tooltip of the close button on the template suggestion strip (hides it for this entry).
  ///
  /// In en, this message translates to:
  /// **'Hide template suggestions'**
  String get diaryTemplateStripDismiss;

  /// Small badge on a template recommended for the current time or date.
  ///
  /// In en, this message translates to:
  /// **'Suggested'**
  String get diaryTemplateRecommended;

  /// Shown for a user template without a name.
  ///
  /// In en, this message translates to:
  /// **'Untitled template'**
  String get diaryTemplateUntitled;

  /// Snackbar after applying a template to a new entry, with an Undo action.
  ///
  /// In en, this message translates to:
  /// **'Applied “{name}”'**
  String diaryTemplateApplied(String name);

  /// Snackbar when a new entry opens with the auto-apply template already applied, with an Undo action.
  ///
  /// In en, this message translates to:
  /// **'Started with “{name}”'**
  String diaryTemplateAutoApplied(String name);

  /// Title of the template picker sheet.
  ///
  /// In en, this message translates to:
  /// **'Choose a template'**
  String get diaryTemplatePickerTitle;

  /// Template picker filter: every template.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get diaryTemplateFilterAll;

  /// Template picker filter: templates recommended right now.
  ///
  /// In en, this message translates to:
  /// **'Suggested'**
  String get diaryTemplateFilterRecommended;

  /// Template picker filter: the user's own templates.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get diaryTemplateFilterMine;

  /// Template picker: the selected filter has no templates.
  ///
  /// In en, this message translates to:
  /// **'No templates here'**
  String get diaryTemplatePickerEmpty;

  /// Template picker: placeholder of the search field.
  ///
  /// In en, this message translates to:
  /// **'Search templates'**
  String get diaryTemplatePickerSearchHint;

  /// Template picker: shown when the search has no results; {query} is the typed text.
  ///
  /// In en, this message translates to:
  /// **'No templates match “{query}”'**
  String diaryTemplatePickerSearchEmpty(String query);

  /// Template picker preview: apply the previewed template.
  ///
  /// In en, this message translates to:
  /// **'Use this template'**
  String get diaryTemplatePickerUse;

  /// Template picker preview: pick another question for the question-of-the-day variable.
  ///
  /// In en, this message translates to:
  /// **'Another question'**
  String get diaryTemplatePickerShuffle;

  /// Hint above the template preview explaining that variables are already resolved.
  ///
  /// In en, this message translates to:
  /// **'Dates and questions are filled in for this entry.'**
  String get diaryTemplatePickerPreviewHint;

  /// Preset summary chip: the template seals the entry as a time capsule; the placeholder is the duration such as “One year”.
  ///
  /// In en, this message translates to:
  /// **'Time capsule: {when}'**
  String diaryTemplatePresetCapsule(String when);

  /// Preset summary chip: the energy level the template sets.
  ///
  /// In en, this message translates to:
  /// **'Energy {level}/5'**
  String diaryTemplatePresetEnergy(int level);

  /// Small badge on a built-in template the user has hidden from the picker.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get diaryTemplateHiddenBadge;

  /// Draft picker: choose a template and start a new entry with it.
  ///
  /// In en, this message translates to:
  /// **'Start from a template'**
  String get diaryDraftPickerFromTemplate;

  /// Title of the diary template management page and its settings entry.
  ///
  /// In en, this message translates to:
  /// **'Diary templates'**
  String get diaryTemplatesTitle;

  /// Subtitle of the diary templates entry in editor settings.
  ///
  /// In en, this message translates to:
  /// **'{builtIn} built-in · {mine} of your own'**
  String diaryTemplatesSettingsSubtitle(int builtIn, int mine);

  /// Group title on the template page for how templates appear when starting an entry.
  ///
  /// In en, this message translates to:
  /// **'New entries'**
  String get diaryTemplatesNewEntryGroup;

  /// Switch (template page and editor settings): show the template suggestion strip in blank new entries.
  ///
  /// In en, this message translates to:
  /// **'Suggest templates for new entries'**
  String get diaryTemplatesStripSwitch;

  /// Subtitle of the suggestion strip switch.
  ///
  /// In en, this message translates to:
  /// **'Show “Start from a template” under the title of a blank entry'**
  String get diaryTemplatesStripSwitchSubtitle;

  /// Setting and page title: templates applied automatically to blank new entries.
  ///
  /// In en, this message translates to:
  /// **'Apply automatically'**
  String get diaryTemplatesAutoApply;

  /// Auto-apply setting value when no template is chosen.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get diaryTemplatesAutoApplyNone;

  /// Explanation at the top of the default auto-apply template picker.
  ///
  /// In en, this message translates to:
  /// **'Blank new entries start with this template outside every time range and when writing for another day. You can undo it each time.'**
  String get diaryTemplatesAutoApplyHint;

  /// Auto-apply setting subtitle when only time ranges are set.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 time range} other{{count} time ranges}}'**
  String diaryTemplatesAutoApplyRulesSummary(int count);

  /// Auto-apply setting subtitle when both time ranges and a default template are set.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 time range} other{{count} time ranges}} · otherwise “{name}”'**
  String diaryTemplatesAutoApplyRulesAndDefault(int count, String name);

  /// Explanation at the top of the auto-apply page.
  ///
  /// In en, this message translates to:
  /// **'Blank new entries start with a template, and you can undo it each time. Time ranges only apply when writing for today.'**
  String get diaryTemplatesAutoApplyIntro;

  /// Group title on the auto-apply page: rules by time range.
  ///
  /// In en, this message translates to:
  /// **'By time of day'**
  String get diaryTemplatesAutoApplyRulesGroup;

  /// Group title on the auto-apply page: the default template outside every time range.
  ///
  /// In en, this message translates to:
  /// **'Other times'**
  String get diaryTemplatesAutoApplyOtherGroup;

  /// Setting: the template applied outside every time range.
  ///
  /// In en, this message translates to:
  /// **'Default template'**
  String get diaryTemplatesAutoApplyDefault;

  /// Button and sheet title: add a new time-range auto-apply rule.
  ///
  /// In en, this message translates to:
  /// **'Add time range'**
  String get diaryTemplatesAutoApplyAddRule;

  /// Shown when the maximum number of time ranges has been reached.
  ///
  /// In en, this message translates to:
  /// **'Up to {max} time ranges'**
  String diaryTemplatesAutoApplyRuleLimit(int max);

  /// Footer on the auto-apply page explaining which overlapping range wins.
  ///
  /// In en, this message translates to:
  /// **'When ranges overlap, ones set to specific days win first, then the shorter one.'**
  String get diaryTemplatesAutoApplyOverlapHint;

  /// Time range rule title: start and end time.
  ///
  /// In en, this message translates to:
  /// **'{start} – {end}'**
  String diaryTemplatesAutoApplyRange(String start, String end);

  /// Title of an overnight time range rule that ends the next day.
  ///
  /// In en, this message translates to:
  /// **'{start} – {end} next day'**
  String diaryTemplatesAutoApplyRangeOvernight(String start, String end);

  /// Time range rule subtitle: which days it applies on and the template name.
  ///
  /// In en, this message translates to:
  /// **'{days} · {name}'**
  String diaryTemplatesAutoApplyRuleSubtitle(String days, String name);

  /// Days label for a time range rule that applies on every day.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get diaryTemplatesAutoApplyEveryDay;

  /// Days label for a time range rule set to exactly Monday to Friday.
  ///
  /// In en, this message translates to:
  /// **'Weekdays'**
  String get diaryTemplatesAutoApplyWorkdays;

  /// Days label for a time range rule set to exactly Saturday and Sunday.
  ///
  /// In en, this message translates to:
  /// **'Weekends'**
  String get diaryTemplatesAutoApplyWeekend;

  /// Separator between short weekday names in a list.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get diaryTemplatesAutoApplyDaySeparator;

  /// Shown when a time range rule points at a deleted template.
  ///
  /// In en, this message translates to:
  /// **'Template no longer exists'**
  String get diaryTemplatesAutoApplyMissing;

  /// Sheet title when editing a time range rule.
  ///
  /// In en, this message translates to:
  /// **'Edit time range'**
  String get diaryTemplatesAutoApplyEditRule;

  /// Small label on the start time button in the time range sheet.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get diaryTemplatesAutoApplyStart;

  /// Small label on the end time button in the time range sheet.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get diaryTemplatesAutoApplyEnd;

  /// Hint when the end time is before the start time, so the range crosses midnight.
  ///
  /// In en, this message translates to:
  /// **'Overnight, ends at {end} the next day'**
  String diaryTemplatesAutoApplyOvernightHint(String end);

  /// Error when the start and end times are equal.
  ///
  /// In en, this message translates to:
  /// **'Start and end can\'t be the same time'**
  String get diaryTemplatesAutoApplySameTime;

  /// Label above the weekday chips in the time range sheet.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get diaryTemplatesAutoApplyDays;

  /// Hint under the weekday chips: selecting none means every day.
  ///
  /// In en, this message translates to:
  /// **'Leave all unselected for every day'**
  String get diaryTemplatesAutoApplyDaysHint;

  /// Row in the time range sheet for choosing the template.
  ///
  /// In en, this message translates to:
  /// **'Template'**
  String get diaryTemplatesAutoApplyTemplate;

  /// Message after deleting a time range rule, with an undo button.
  ///
  /// In en, this message translates to:
  /// **'Time range deleted'**
  String get diaryTemplatesAutoApplyRuleDeleted;

  /// Group title: the user's own templates.
  ///
  /// In en, this message translates to:
  /// **'My templates'**
  String get diaryTemplatesMineGroup;

  /// Group title: templates that come with the app.
  ///
  /// In en, this message translates to:
  /// **'Built-in templates'**
  String get diaryTemplatesBuiltInGroup;

  /// Empty state of the user's template list.
  ///
  /// In en, this message translates to:
  /// **'No templates of your own yet. Create one with +, or copy a built-in one and change it.'**
  String get diaryTemplatesMineEmpty;

  /// Tooltip of the button that creates a template.
  ///
  /// In en, this message translates to:
  /// **'New template'**
  String get diaryTemplatesNew;

  /// Tooltip of the button that imports a template code from the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Import a template code'**
  String get diaryTemplatesImport;

  /// Tooltip of a template row's menu button.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get diaryTemplatesMoreActions;

  /// Accessibility label of the drag handle on a template row.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get diaryTemplatesDragHandle;

  /// Menu action: make a copy of the user's template.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get diaryTemplatesDuplicate;

  /// Action on a built-in template: copy it into the user's templates so it can be edited.
  ///
  /// In en, this message translates to:
  /// **'Copy to my templates'**
  String get diaryTemplatesCopyToMine;

  /// Menu action: copy the template as a shareable code.
  ///
  /// In en, this message translates to:
  /// **'Copy template code'**
  String get diaryTemplatesCopyCode;

  /// Menu action: hide a built-in template from the picker.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get diaryTemplatesHide;

  /// Menu action: show a hidden built-in template again.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get diaryTemplatesShow;

  /// Name given to a duplicated template.
  ///
  /// In en, this message translates to:
  /// **'{name} copy'**
  String diaryTemplatesCopyName(String name);

  /// Snackbar after deleting a template, with Undo.
  ///
  /// In en, this message translates to:
  /// **'Deleted “{name}”'**
  String diaryTemplatesDeleted(String name);

  /// Snackbar after hiding a built-in template, with Undo.
  ///
  /// In en, this message translates to:
  /// **'Hid “{name}”'**
  String diaryTemplatesHiddenDone(String name);

  /// Snackbar after copying a template code.
  ///
  /// In en, this message translates to:
  /// **'Template code copied'**
  String get diaryTemplatesCodeCopied;

  /// Snackbar when a template is too long to fit in a template code.
  ///
  /// In en, this message translates to:
  /// **'This template is too long for a template code'**
  String get diaryTemplatesCodeTooLong;

  /// Snackbar when importing finds an empty clipboard.
  ///
  /// In en, this message translates to:
  /// **'No template code in the clipboard'**
  String get diaryTemplatesImportEmpty;

  /// Snackbar when the clipboard holds no valid template code.
  ///
  /// In en, this message translates to:
  /// **'That\'s not a valid template code'**
  String get diaryTemplatesImportInvalid;

  /// Snackbar after importing a template code, with Undo.
  ///
  /// In en, this message translates to:
  /// **'Imported “{name}”'**
  String diaryTemplatesImported(String name);

  /// Snackbar after importing a code made by a newer app version, with Undo.
  ///
  /// In en, this message translates to:
  /// **'Imported “{name}”. It comes from a newer version, so some settings may not apply.'**
  String diaryTemplatesImportedNewer(String name);

  /// Snackbar when writing a template fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the template. Try again'**
  String get diaryTemplatesSaveFailed;

  /// Title of the template editor for a new template.
  ///
  /// In en, this message translates to:
  /// **'New template'**
  String get diaryTemplateEditorNewTitle;

  /// Title of the template editor for an existing template.
  ///
  /// In en, this message translates to:
  /// **'Edit template'**
  String get diaryTemplateEditorEditTitle;

  /// Template editor tab: title and body.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get diaryTemplateEditorTabContent;

  /// Template editor tab: name, look, presets and suggestions.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get diaryTemplateEditorTabSettings;

  /// Hint of the template's title field.
  ///
  /// In en, this message translates to:
  /// **'Title (variables allowed)'**
  String get diaryTemplateEditorTitleHint;

  /// Hint of the template's empty body.
  ///
  /// In en, this message translates to:
  /// **'Write the body. Headings, lists and to-dos are kept.'**
  String get diaryTemplateEditorBodyHint;

  /// Button that opens the full list of template variables.
  ///
  /// In en, this message translates to:
  /// **'All variables'**
  String get diaryTemplateEditorAllVariables;

  /// Title of the template variable sheet.
  ///
  /// In en, this message translates to:
  /// **'Insert a variable'**
  String get diaryTemplateEditorVariablesTitle;

  /// Explanation in the template variable sheet.
  ///
  /// In en, this message translates to:
  /// **'Variables are filled in from the entry\'s date when the template is applied. Lunar dates and solar terms use Chinese names.'**
  String get diaryTemplateEditorVariablesHint;

  /// Example value of a template variable, computed for today.
  ///
  /// In en, this message translates to:
  /// **'Today: {example}'**
  String diaryTemplateEditorVariableExample(String example);

  /// Label of the template name field.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get diaryTemplateEditorName;

  /// Error shown when saving a template without a name.
  ///
  /// In en, this message translates to:
  /// **'Give the template a name'**
  String get diaryTemplateEditorNameRequired;

  /// Label of the template description field.
  ///
  /// In en, this message translates to:
  /// **'Short description'**
  String get diaryTemplateEditorDescription;

  /// Group title: category, icon and color of a template.
  ///
  /// In en, this message translates to:
  /// **'Look'**
  String get diaryTemplateEditorLook;

  /// Label of the template category choice.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get diaryTemplateEditorCategory;

  /// Label of the template icon choice.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get diaryTemplateEditorIcon;

  /// Label of the template color choice.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get diaryTemplateEditorAccent;

  /// Color option: follow the app's theme color.
  ///
  /// In en, this message translates to:
  /// **'Theme color'**
  String get diaryTemplateEditorAccentTheme;

  /// Group title: tags, mood, energy and time capsule the template sets.
  ///
  /// In en, this message translates to:
  /// **'Also set when applied'**
  String get diaryTemplateEditorPresets;

  /// Label of the template's preset tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get diaryTemplateEditorTags;

  /// Button that adds a preset tag to the template.
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get diaryTemplateEditorAddTag;

  /// Option in the tag sheet: type a tag name that doesn't exist yet.
  ///
  /// In en, this message translates to:
  /// **'New tag'**
  String get diaryTemplateEditorNewTag;

  /// Explanation under the template's preset tags.
  ///
  /// In en, this message translates to:
  /// **'Tags are matched by name. Missing ones are created when the template is applied.'**
  String get diaryTemplateEditorTagsHint;

  /// Label of the template's preset mood.
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get diaryTemplateEditorMood;

  /// Option meaning the template doesn't set this value.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get diaryTemplateEditorNone;

  /// Label of the template's preset energy level.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get diaryTemplateEditorEnergy;

  /// Label of the template's preset time capsule.
  ///
  /// In en, this message translates to:
  /// **'Time capsule'**
  String get diaryTemplateEditorCapsule;

  /// Explanation under the template's preset time capsule.
  ///
  /// In en, this message translates to:
  /// **'Counted from the day the template is applied; you can still change it before publishing.'**
  String get diaryTemplateEditorCapsuleHint;

  /// Group title: when the template is suggested first.
  ///
  /// In en, this message translates to:
  /// **'When to suggest'**
  String get diaryTemplateEditorRecommend;

  /// Explanation of the template's suggestion rules.
  ///
  /// In en, this message translates to:
  /// **'The template moves to the front of the suggestions when every chosen group matches. Within a group, any choice is enough.'**
  String get diaryTemplateEditorRecommendHint;

  /// Label of the time-of-day suggestion rule.
  ///
  /// In en, this message translates to:
  /// **'Time of day'**
  String get diaryTemplateEditorSlots;

  /// Label of the weekday suggestion rule.
  ///
  /// In en, this message translates to:
  /// **'Days of the week'**
  String get diaryTemplateEditorWeekdays;

  /// Label of the month start/end suggestion rule.
  ///
  /// In en, this message translates to:
  /// **'Time of month'**
  String get diaryTemplateEditorMonth;

  /// Time of day 5:00–10:59.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get diaryTemplateSlotMorning;

  /// Time of day 11:00–16:59.
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get diaryTemplateSlotAfternoon;

  /// Time of day 17:00–21:59.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get diaryTemplateSlotEvening;

  /// Time of day 22:00–4:59.
  ///
  /// In en, this message translates to:
  /// **'Late night'**
  String get diaryTemplateSlotNight;

  /// Month rule: the first three days of a month.
  ///
  /// In en, this message translates to:
  /// **'First 3 days'**
  String get diaryTemplateMonthStart;

  /// Month rule: the last three days of a month.
  ///
  /// In en, this message translates to:
  /// **'Last 3 days'**
  String get diaryTemplateMonthEnd;

  /// Action that turns a diary (or the entry being written) into a new template.
  ///
  /// In en, this message translates to:
  /// **'Save as template'**
  String get diaryTemplateSaveAs;

  /// Hint when saving as a template removed media from the body.
  ///
  /// In en, this message translates to:
  /// **'Images, recordings and other media aren\'t kept in templates'**
  String get diaryTemplateSaveAsMediaDropped;

  /// Tooltip of the editor's top bar menu (choose a template, save as template, editor settings).
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get diaryEditorMoreActions;

  /// Top bar menu item of a new blank entry: opens the template picker and applies the chosen one, replacing a just-applied template that is still untouched.
  ///
  /// In en, this message translates to:
  /// **'Choose a template'**
  String get diaryTemplateChoose;

  /// Hint when "Choose a template" is tapped after the user has written in the title or body.
  ///
  /// In en, this message translates to:
  /// **'Templates can only be applied to a blank entry'**
  String get diaryTemplateNeedsBlankEntry;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
