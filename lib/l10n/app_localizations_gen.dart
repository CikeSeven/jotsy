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

  /// Setting title for editor body font size.
  ///
  /// In en, this message translates to:
  /// **'Editor font size'**
  String get settingsEditorBodyFontSize;

  /// Subtitle for editor body font size setting.
  ///
  /// In en, this message translates to:
  /// **'Only affects editor body text'**
  String get settingsEditorBodyFontSizeSubtitle;

  /// Small option for editor body font size.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get settingsEditorBodyFontSizeSmall;

  /// Medium option for editor body font size.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get settingsEditorBodyFontSizeMedium;

  /// Large option for editor body font size.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get settingsEditorBodyFontSizeLarge;

  /// Setting title for editor body line height.
  ///
  /// In en, this message translates to:
  /// **'Body line height'**
  String get settingsEditorLineHeight;

  /// Subtitle for editor body line height setting.
  ///
  /// In en, this message translates to:
  /// **'Only affects editor body layout'**
  String get settingsEditorLineHeightSubtitle;

  /// Compact option for editor body line height.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get settingsEditorLineHeightCompact;

  /// Normal option for editor body line height.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get settingsEditorLineHeightNormal;

  /// Relaxed option for editor body line height.
  ///
  /// In en, this message translates to:
  /// **'Relaxed'**
  String get settingsEditorLineHeightRelaxed;

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

  /// Subtitle for update check action in About page.
  ///
  /// In en, this message translates to:
  /// **'Detect release and open APK download automatically'**
  String get aboutCheckUpdateSubtitle;

  /// Message shown when current version is already latest.
  ///
  /// In en, this message translates to:
  /// **'You are already on the latest version ({version})'**
  String aboutUpdateAlreadyLatest(String version);

  /// Message shown when new version is found and download link is opening.
  ///
  /// In en, this message translates to:
  /// **'New version found ({version}), opening download link'**
  String aboutUpdateOpeningDownload(String version);

  /// Message shown when browser launch fails after checking update.
  ///
  /// In en, this message translates to:
  /// **'Unable to open browser automatically, please try again later'**
  String get aboutUpdateOpenBrowserFailed;

  /// Message shown when update checking fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to check updates, please verify network and retry'**
  String get aboutUpdateCheckFailed;

  /// Message shown when release exists but APK assets are not found.
  ///
  /// In en, this message translates to:
  /// **'New version found, but no downloadable APK was resolved'**
  String get aboutUpdateNoApkFound;

  /// Title for update confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'New version found: {version}'**
  String aboutUpdateDialogTitle(String version);

  /// Fallback text when release notes are unavailable.
  ///
  /// In en, this message translates to:
  /// **'No release notes were provided for this version.'**
  String get aboutUpdateDialogNoNotes;

  /// Primary action label in update confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Download update'**
  String get aboutUpdateDialogConfirmDownload;

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
  /// **'This month chars'**
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

  /// Auto-generated metadata for autoT0081.
  ///
  /// In en, this message translates to:
  /// **'Unsaved draft found'**
  String get autoT0081;

  /// Auto-generated metadata for autoT0082.
  ///
  /// In en, this message translates to:
  /// **'New empty note'**
  String get autoT0082;

  /// Auto-generated metadata for autoT0083.
  ///
  /// In en, this message translates to:
  /// **'Continue editing'**
  String get autoT0083;

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

  /// Auto-generated metadata for autoT0089.
  ///
  /// In en, this message translates to:
  /// **'Cover import failed: {p0}'**
  String autoT0089(String p0);

  /// Auto-generated metadata for autoT0090.
  ///
  /// In en, this message translates to:
  /// **'Tag creation failed: {p0}'**
  String autoT0090(String p0);

  /// Auto-generated metadata for autoT0091.
  ///
  /// In en, this message translates to:
  /// **'Location failed: {p0}'**
  String autoT0091(String p0);

  /// Auto-generated metadata for autoT0092.
  ///
  /// In en, this message translates to:
  /// **'Please get current location first'**
  String get autoT0092;

  /// Auto-generated metadata for autoT0093.
  ///
  /// In en, this message translates to:
  /// **'Weather fetch failed: {p0}'**
  String autoT0093(String p0);

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

  /// Auto-generated metadata for autoT0098.
  ///
  /// In en, this message translates to:
  /// **'Publish failed: {p0}'**
  String autoT0098(String p0);

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

  /// Menu label for exporting diary as Markdown.
  ///
  /// In en, this message translates to:
  /// **'Export as Markdown'**
  String get previewExportMarkdown;

  /// Menu label for exporting diary as PDF.
  ///
  /// In en, this message translates to:
  /// **'Export as PDF'**
  String get previewExportPdf;

  /// Dialog title when saving an exported diary file.
  ///
  /// In en, this message translates to:
  /// **'Save export file'**
  String get previewExportSaveDialogTitle;

  /// SnackBar text when export completes.
  ///
  /// In en, this message translates to:
  /// **'Export succeeded'**
  String get previewExportSuccess;

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

  /// Auto-generated metadata for autoT0202.
  ///
  /// In en, this message translates to:
  /// **'An unfinished diary was found. Continue editing?'**
  String get autoT0202;

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

  /// Auto-generated metadata for autoT0209.
  ///
  /// In en, this message translates to:
  /// **'An unfinished diary draft was found. Continue editing?'**
  String get autoT0209;

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

  /// Data management WebDAV sync entry title.
  ///
  /// In en, this message translates to:
  /// **'WebDAV Sync'**
  String get dataMgmtWebDav;

  /// Data management WebDAV sync entry subtitle.
  ///
  /// In en, this message translates to:
  /// **'Back up to NAS / private WebDAV and restore from remote backups'**
  String get dataMgmtWebDavSubtitle;

  /// WebDAV sync page title.
  ///
  /// In en, this message translates to:
  /// **'WebDAV Sync'**
  String get webDavTitle;

  /// WebDAV connection section title.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get webDavConfigSection;

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

  /// Save WebDAV config button.
  ///
  /// In en, this message translates to:
  /// **'Save Config'**
  String get webDavSaveConfig;

  /// Test WebDAV connection button.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get webDavTestConnection;

  /// Upload current backup to WebDAV button.
  ///
  /// In en, this message translates to:
  /// **'Upload Current Backup'**
  String get webDavUploadBackup;

  /// Refresh WebDAV remote backup list button.
  ///
  /// In en, this message translates to:
  /// **'Refresh List'**
  String get webDavRefreshBackups;

  /// WebDAV remote backup list title.
  ///
  /// In en, this message translates to:
  /// **'Remote Backups'**
  String get webDavBackupList;

  /// WebDAV remote backup empty state.
  ///
  /// In en, this message translates to:
  /// **'No remote backups yet'**
  String get webDavNoBackups;

  /// WebDAV config saved hint.
  ///
  /// In en, this message translates to:
  /// **'WebDAV config saved'**
  String get webDavConfigSaved;

  /// WebDAV connection test success hint.
  ///
  /// In en, this message translates to:
  /// **'WebDAV connection succeeded'**
  String get webDavConnectionOk;

  /// WebDAV upload success hint.
  ///
  /// In en, this message translates to:
  /// **'Backup uploaded to WebDAV'**
  String get webDavUploadSuccess;

  /// WebDAV restore success hint.
  ///
  /// In en, this message translates to:
  /// **'Data restored from WebDAV backup'**
  String get webDavRestoreSuccess;

  /// WebDAV remote backup delete success hint.
  ///
  /// In en, this message translates to:
  /// **'Remote backup deleted'**
  String get webDavDeleteSuccess;

  /// WebDAV operation failed hint.
  ///
  /// In en, this message translates to:
  /// **'Operation failed: {error}'**
  String webDavOperationFailed(String error);

  /// WebDAV save config busy text.
  ///
  /// In en, this message translates to:
  /// **'Saving config...'**
  String get webDavBusySave;

  /// WebDAV test connection busy text.
  ///
  /// In en, this message translates to:
  /// **'Testing connection...'**
  String get webDavBusyTest;

  /// WebDAV upload backup busy text.
  ///
  /// In en, this message translates to:
  /// **'Uploading backup...'**
  String get webDavBusyUpload;

  /// WebDAV refresh list busy text.
  ///
  /// In en, this message translates to:
  /// **'Reading remote backups...'**
  String get webDavBusyRefresh;

  /// WebDAV restore backup busy text.
  ///
  /// In en, this message translates to:
  /// **'Restoring backup...'**
  String get webDavBusyRestore;

  /// WebDAV delete remote backup busy text.
  ///
  /// In en, this message translates to:
  /// **'Deleting remote backup...'**
  String get webDavBusyDelete;

  /// WebDAV loading indicator semantic label.
  ///
  /// In en, this message translates to:
  /// **'Processing WebDAV operation'**
  String get webDavBusyLabel;

  /// WebDAV safety and behavior hint.
  ///
  /// In en, this message translates to:
  /// **'Create a dedicated Jotsy folder on your NAS and prefer an app password or token. Upload creates a full ZIP backup; when restoring you can merge into or overwrite local data.'**
  String get webDavHint;

  /// WebDAV delete confirm dialog title.
  ///
  /// In en, this message translates to:
  /// **'Delete Remote Backup'**
  String get webDavDeleteConfirmTitle;

  /// WebDAV delete confirm dialog content.
  ///
  /// In en, this message translates to:
  /// **'Delete {fileName} from the WebDAV server? This cannot be undone.'**
  String webDavDeleteConfirmContent(String fileName);

  /// WebDAV restore action button.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get webDavRestoreAction;

  /// WebDAV delete action button.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get webDavDeleteAction;

  /// WebDAV backup size label.
  ///
  /// In en, this message translates to:
  /// **'Size: {size}'**
  String webDavBackupSize(String size);

  /// WebDAV backup time label.
  ///
  /// In en, this message translates to:
  /// **'Time: {time}'**
  String webDavBackupTime(String time);

  /// WebDAV backup password dialog title.
  ///
  /// In en, this message translates to:
  /// **'Backup Password'**
  String get webDavPasswordDialogTitle;

  /// WebDAV backup password field hint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for no encryption; enter the original password for encrypted restore'**
  String get webDavPasswordDialogHint;

  /// WebDAV backup password warning.
  ///
  /// In en, this message translates to:
  /// **'Keep this password safe. Encrypted backups cannot be restored if you forget it.'**
  String get webDavPasswordWarning;

  /// WebDAV backup password continue button.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get webDavContinueWithoutPassword;

  /// WebDAV missing config hint.
  ///
  /// In en, this message translates to:
  /// **'Fill and save WebDAV config first'**
  String get webDavConfigRequired;

  /// Localized WebDAV config error detail.
  ///
  /// In en, this message translates to:
  /// **'Check the WebDAV URL, account, password/token, and remote directory'**
  String get webDavErrorConfig;

  /// Localized WebDAV authentication error detail.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Check the username and password/token'**
  String get webDavErrorAuth;

  /// Localized WebDAV not found error detail.
  ///
  /// In en, this message translates to:
  /// **'Remote path not found. Check the NAS WebDAV directory'**
  String get webDavErrorNotFound;

  /// Localized WebDAV insufficient storage error detail.
  ///
  /// In en, this message translates to:
  /// **'The WebDAV server does not have enough storage space'**
  String get webDavErrorStorageFull;

  /// Localized WebDAV network error detail.
  ///
  /// In en, this message translates to:
  /// **'Network request failed. Check the server URL, certificate, and network status'**
  String get webDavErrorNetwork;

  /// Localized WebDAV unknown error detail.
  ///
  /// In en, this message translates to:
  /// **'Unknown error. Please try again later'**
  String get webDavErrorUnknown;

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

  /// Menu label for exporting a diary as a diary file (ZIP with its tags and media) that can be imported again.
  ///
  /// In en, this message translates to:
  /// **'Export as diary file'**
  String get previewExportDiaryFile;

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
  /// **'By length'**
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
  /// **'Entries, days written, length, top mood and longest streak for the month.'**
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

  /// Summary tooltip: total characters written in the month, year or selected range (formatted number).
  ///
  /// In en, this message translates to:
  /// **'{count} characters'**
  String calendarSummaryChars(String count);

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

  /// Selected day stats: number of entries and characters (formatted number).
  ///
  /// In en, this message translates to:
  /// **'{entries, plural, =1{1 entry} other{{entries} entries}} · {chars} chars'**
  String calendarDayStats(int entries, String chars);

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
  /// **'Length'**
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
