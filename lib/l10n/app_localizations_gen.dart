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

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Jotsy'**
  String get appTitle;

  /// No description provided for @navDiaries.
  ///
  /// In en, this message translates to:
  /// **'Diaries'**
  String get navDiaries;

  /// No description provided for @navCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get navCalendar;

  /// No description provided for @navExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get navExplore;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get commonShare;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get commonCreate;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get commonNew;

  /// No description provided for @commonReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get commonReset;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min ago'**
  String timeMinutesAgo(int minutes);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours} hr ago'**
  String timeHoursAgo(int hours);

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days} days ago'**
  String timeDaysAgo(int days);

  /// No description provided for @updatedAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Updated {value}'**
  String updatedAtLabel(String value);

  /// No description provided for @startupPreloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Startup preload failed. Entered home anyway.'**
  String get startupPreloadFailed;

  /// No description provided for @homeInitFailed.
  ///
  /// In en, this message translates to:
  /// **'Initialization failed: {error}'**
  String homeInitFailed(String error);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsThemeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsThemeMode;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Switch app language'**
  String get settingsLanguageSubtitle;

  /// No description provided for @settingsEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get settingsEditorTitle;

  /// No description provided for @settingsDataManagement.
  ///
  /// In en, this message translates to:
  /// **'Data Management'**
  String get settingsDataManagement;

  /// No description provided for @settingsDataManagementSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Import/export ZIP backups'**
  String get settingsDataManagementSubtitle;

  /// No description provided for @settingsTagManagement.
  ///
  /// In en, this message translates to:
  /// **'Tag Management'**
  String get settingsTagManagement;

  /// No description provided for @settingsTagManagementSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Deleting a tag only unlinks it from diaries'**
  String get settingsTagManagementSubtitle;

  /// No description provided for @settingsRecycleBin.
  ///
  /// In en, this message translates to:
  /// **'Recycle Bin'**
  String get settingsRecycleBin;

  /// No description provided for @settingsRecycleBinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore or permanently remove deleted diaries'**
  String get settingsRecycleBinSubtitle;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'App info, repo, and version'**
  String get settingsAboutSubtitle;

  /// No description provided for @languageDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Select language'**
  String get languageDialogTitle;

  /// No description provided for @languageOptionChinese.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get languageOptionChinese;

  /// No description provided for @languageOptionEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageOptionEnglish;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @aboutTagline.
  ///
  /// In en, this message translates to:
  /// **'Capture daily moments and feelings'**
  String get aboutTagline;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get aboutVersion;

  /// No description provided for @aboutPackageName.
  ///
  /// In en, this message translates to:
  /// **'Package'**
  String get aboutPackageName;

  /// No description provided for @aboutRepository.
  ///
  /// In en, this message translates to:
  /// **'Repository'**
  String get aboutRepository;

  /// No description provided for @aboutCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get aboutCopied;

  /// No description provided for @dataMgmtTitle.
  ///
  /// In en, this message translates to:
  /// **'Data Management'**
  String get dataMgmtTitle;

  /// No description provided for @dataMgmtExport.
  ///
  /// In en, this message translates to:
  /// **'Export Data'**
  String get dataMgmtExport;

  /// No description provided for @dataMgmtExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export ZIP with diaries, tags, settings, and local media'**
  String get dataMgmtExportSubtitle;

  /// No description provided for @dataMgmtImport.
  ///
  /// In en, this message translates to:
  /// **'Import Data'**
  String get dataMgmtImport;

  /// No description provided for @dataMgmtImportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from ZIP and overwrite current data'**
  String get dataMgmtImportSubtitle;

  /// No description provided for @dataMgmtHint.
  ///
  /// In en, this message translates to:
  /// **'It is recommended to export a backup before importing.'**
  String get dataMgmtHint;

  /// No description provided for @dataMgmtBusyExport.
  ///
  /// In en, this message translates to:
  /// **'Exporting data...'**
  String get dataMgmtBusyExport;

  /// No description provided for @dataMgmtBusyImport.
  ///
  /// In en, this message translates to:
  /// **'Importing data...'**
  String get dataMgmtBusyImport;

  /// No description provided for @dataMgmtSaveDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Save backup'**
  String get dataMgmtSaveDialogTitle;

  /// No description provided for @dataMgmtPickDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose backup file'**
  String get dataMgmtPickDialogTitle;

  /// No description provided for @dataMgmtExportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Data export completed'**
  String get dataMgmtExportSuccess;

  /// No description provided for @dataMgmtExportCanceled.
  ///
  /// In en, this message translates to:
  /// **'Export canceled'**
  String get dataMgmtExportCanceled;

  /// No description provided for @dataMgmtExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String dataMgmtExportFailed(String error);

  /// No description provided for @dataMgmtImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Data import completed'**
  String get dataMgmtImportSuccess;

  /// No description provided for @dataMgmtImportCanceled.
  ///
  /// In en, this message translates to:
  /// **'Import canceled'**
  String get dataMgmtImportCanceled;

  /// No description provided for @dataMgmtImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String dataMgmtImportFailed(String error);

  /// No description provided for @dataMgmtImportConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Data'**
  String get dataMgmtImportConfirmTitle;

  /// No description provided for @dataMgmtImportConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'Import will overwrite current data. Continue?'**
  String get dataMgmtImportConfirmContent;

  /// No description provided for @dataMgmtImportAction.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get dataMgmtImportAction;

  /// No description provided for @dataMgmtBusyLabel.
  ///
  /// In en, this message translates to:
  /// **'Processing data'**
  String get dataMgmtBusyLabel;

  /// No description provided for @autoT0001.
  ///
  /// In en, this message translates to:
  /// **'Loading app'**
  String get autoT0001;

  /// No description provided for @autoT0002.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get autoT0002;

  /// No description provided for @autoT0003.
  ///
  /// In en, this message translates to:
  /// **'Reset order'**
  String get autoT0003;

  /// No description provided for @autoT0004.
  ///
  /// In en, this message translates to:
  /// **'Save order failed: {p0}'**
  String autoT0004(Object p0);

  /// No description provided for @autoT0005.
  ///
  /// In en, this message translates to:
  /// **'Toolbar order'**
  String get autoT0005;

  /// No description provided for @autoT0006.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get autoT0006;

  /// No description provided for @autoT0007.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get autoT0007;

  /// No description provided for @autoT0008.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get autoT0008;

  /// No description provided for @autoT0009.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get autoT0009;

  /// No description provided for @autoT0010.
  ///
  /// In en, this message translates to:
  /// **'Underline'**
  String get autoT0010;

  /// No description provided for @autoT0011.
  ///
  /// In en, this message translates to:
  /// **'Strikethrough'**
  String get autoT0011;

  /// No description provided for @autoT0012.
  ///
  /// In en, this message translates to:
  /// **'Inline code'**
  String get autoT0012;

  /// No description provided for @autoT0013.
  ///
  /// In en, this message translates to:
  /// **'Text color'**
  String get autoT0013;

  /// No description provided for @autoT0014.
  ///
  /// In en, this message translates to:
  /// **'Background color'**
  String get autoT0014;

  /// No description provided for @autoT0015.
  ///
  /// In en, this message translates to:
  /// **'Clear formatting'**
  String get autoT0015;

  /// No description provided for @autoT0016.
  ///
  /// In en, this message translates to:
  /// **'Insert image'**
  String get autoT0016;

  /// No description provided for @autoT0017.
  ///
  /// In en, this message translates to:
  /// **'Header style'**
  String get autoT0017;

  /// No description provided for @autoT0018.
  ///
  /// In en, this message translates to:
  /// **'Ordered list'**
  String get autoT0018;

  /// No description provided for @autoT0019.
  ///
  /// In en, this message translates to:
  /// **'Bullet list'**
  String get autoT0019;

  /// No description provided for @autoT0020.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get autoT0020;

  /// No description provided for @autoT0021.
  ///
  /// In en, this message translates to:
  /// **'Code block'**
  String get autoT0021;

  /// No description provided for @autoT0022.
  ///
  /// In en, this message translates to:
  /// **'Quote'**
  String get autoT0022;

  /// No description provided for @autoT0023.
  ///
  /// In en, this message translates to:
  /// **'Indent'**
  String get autoT0023;

  /// No description provided for @autoT0024.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get autoT0024;

  /// No description provided for @autoT0025.
  ///
  /// In en, this message translates to:
  /// **'Unknown deleted time'**
  String get autoT0025;

  /// No description provided for @autoT0026.
  ///
  /// In en, this message translates to:
  /// **'Some restores failed. Please retry.'**
  String get autoT0026;

  /// No description provided for @autoT0027.
  ///
  /// In en, this message translates to:
  /// **'Some deletions failed. Please retry.'**
  String get autoT0027;

  /// No description provided for @autoT0028.
  ///
  /// In en, this message translates to:
  /// **'Permanent delete'**
  String get autoT0028;

  /// No description provided for @autoT0029.
  ///
  /// In en, this message translates to:
  /// **'Recycle bin'**
  String get autoT0029;

  /// No description provided for @autoT0030.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get autoT0030;

  /// No description provided for @autoT0031.
  ///
  /// In en, this message translates to:
  /// **'Recycle bin load failed: {p0}'**
  String autoT0031(Object p0);

  /// No description provided for @autoT0032.
  ///
  /// In en, this message translates to:
  /// **'Recycle bin is empty'**
  String get autoT0032;

  /// No description provided for @autoT0033.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get autoT0033;

  /// No description provided for @autoT0034.
  ///
  /// In en, this message translates to:
  /// **'Create tag failed: {p0}'**
  String autoT0034(Object p0);

  /// No description provided for @autoT0035.
  ///
  /// In en, this message translates to:
  /// **'Edit tag failed: {p0}'**
  String autoT0035(Object p0);

  /// No description provided for @autoT0036.
  ///
  /// In en, this message translates to:
  /// **'Delete tag failed: {p0}'**
  String autoT0036(Object p0);

  /// No description provided for @autoT0037.
  ///
  /// In en, this message translates to:
  /// **'Save tag order failed: {p0}'**
  String autoT0037(Object p0);

  /// No description provided for @autoT0038.
  ///
  /// In en, this message translates to:
  /// **'Delete tag'**
  String get autoT0038;

  /// No description provided for @autoT0039.
  ///
  /// In en, this message translates to:
  /// **'Tag management'**
  String get autoT0039;

  /// No description provided for @autoT0040.
  ///
  /// In en, this message translates to:
  /// **'Create tag'**
  String get autoT0040;

  /// No description provided for @autoT0041.
  ///
  /// In en, this message translates to:
  /// **'Create your first tag'**
  String get autoT0041;

  /// No description provided for @autoT0042.
  ///
  /// In en, this message translates to:
  /// **'Tag load failed: {p0}'**
  String autoT0042(Object p0);

  /// No description provided for @autoT0043.
  ///
  /// In en, this message translates to:
  /// **'Toolbar order'**
  String get autoT0043;

  /// No description provided for @autoT0044.
  ///
  /// In en, this message translates to:
  /// **'Current top 4: {p0}'**
  String autoT0044(Object p0);

  /// No description provided for @autoT0045.
  ///
  /// In en, this message translates to:
  /// **'Settings load failed: {p0}'**
  String autoT0045(Object p0);

  /// No description provided for @autoT0046.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get autoT0046;

  /// No description provided for @autoT0047.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get autoT0047;

  /// No description provided for @autoT0048.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get autoT0048;

  /// No description provided for @autoT0049.
  ///
  /// In en, this message translates to:
  /// **'What unexpected good thing happened today?'**
  String get autoT0049;

  /// No description provided for @autoT0050.
  ///
  /// In en, this message translates to:
  /// **'If today had a title, what would it be?'**
  String get autoT0050;

  /// No description provided for @autoT0051.
  ///
  /// In en, this message translates to:
  /// **'What moment today is most worth remembering?'**
  String get autoT0051;

  /// No description provided for @autoT0052.
  ///
  /// In en, this message translates to:
  /// **'Media preview'**
  String get autoT0052;

  /// No description provided for @autoT0053.
  ///
  /// In en, this message translates to:
  /// **'No images to browse'**
  String get autoT0053;

  /// No description provided for @autoT0054.
  ///
  /// In en, this message translates to:
  /// **'Media gallery'**
  String get autoT0054;

  /// No description provided for @autoT0055.
  ///
  /// In en, this message translates to:
  /// **'No images to show yet'**
  String get autoT0055;

  /// No description provided for @autoT0056.
  ///
  /// In en, this message translates to:
  /// **'Load failed, tap to retry'**
  String get autoT0056;

  /// No description provided for @autoT0057.
  ///
  /// In en, this message translates to:
  /// **'No more images'**
  String get autoT0057;

  /// No description provided for @autoT0058.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get autoT0058;

  /// No description provided for @autoT0059.
  ///
  /// In en, this message translates to:
  /// **'Explore data is unavailable'**
  String get autoT0059;

  /// No description provided for @autoT0060.
  ///
  /// In en, this message translates to:
  /// **'Mood & energy trends'**
  String get autoT0060;

  /// No description provided for @autoT0061.
  ///
  /// In en, this message translates to:
  /// **'View all images'**
  String get autoT0061;

  /// No description provided for @autoT0062.
  ///
  /// In en, this message translates to:
  /// **'No images to show yet.'**
  String get autoT0062;

  /// No description provided for @autoT0063.
  ///
  /// In en, this message translates to:
  /// **'On this day'**
  String get autoT0063;

  /// No description provided for @autoT0064.
  ///
  /// In en, this message translates to:
  /// **'Write for today'**
  String get autoT0064;

  /// No description provided for @autoT0065.
  ///
  /// In en, this message translates to:
  /// **'Untitled diary'**
  String get autoT0065;

  /// No description provided for @autoT0066.
  ///
  /// In en, this message translates to:
  /// **'Total records'**
  String get autoT0066;

  /// No description provided for @autoT0067.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get autoT0067;

  /// No description provided for @autoT0068.
  ///
  /// In en, this message translates to:
  /// **'This month chars'**
  String get autoT0068;

  /// No description provided for @autoT0069.
  ///
  /// In en, this message translates to:
  /// **'Tag cloud'**
  String get autoT0069;

  /// No description provided for @autoT0070.
  ///
  /// In en, this message translates to:
  /// **'Delete diaries'**
  String get autoT0070;

  /// No description provided for @autoT0071.
  ///
  /// In en, this message translates to:
  /// **'Unarchive failed. Please try again.'**
  String get autoT0071;

  /// No description provided for @autoT0072.
  ///
  /// In en, this message translates to:
  /// **'Archive status restored'**
  String get autoT0072;

  /// No description provided for @autoT0073.
  ///
  /// In en, this message translates to:
  /// **'Delete failed. Please try again.'**
  String get autoT0073;

  /// No description provided for @autoT0074.
  ///
  /// In en, this message translates to:
  /// **'Deleted {p0} diaries'**
  String autoT0074(Object p0);

  /// No description provided for @autoT0075.
  ///
  /// In en, this message translates to:
  /// **'Diary deleted'**
  String get autoT0075;

  /// No description provided for @autoT0076.
  ///
  /// In en, this message translates to:
  /// **'Deleted diary restored'**
  String get autoT0076;

  /// No description provided for @autoT0077.
  ///
  /// In en, this message translates to:
  /// **'Restore failed. Please try again.'**
  String get autoT0077;

  /// No description provided for @autoT0078.
  ///
  /// In en, this message translates to:
  /// **'Archive failed. Please try again.'**
  String get autoT0078;

  /// No description provided for @autoT0079.
  ///
  /// In en, this message translates to:
  /// **'Archived {p0} diaries'**
  String autoT0079(Object p0);

  /// No description provided for @autoT0080.
  ///
  /// In en, this message translates to:
  /// **'Archived diary restored'**
  String get autoT0080;

  /// No description provided for @autoT0081.
  ///
  /// In en, this message translates to:
  /// **'Unsaved draft found'**
  String get autoT0081;

  /// No description provided for @autoT0082.
  ///
  /// In en, this message translates to:
  /// **'New empty note'**
  String get autoT0082;

  /// No description provided for @autoT0083.
  ///
  /// In en, this message translates to:
  /// **'Continue editing'**
  String get autoT0083;

  /// No description provided for @autoT0084.
  ///
  /// In en, this message translates to:
  /// **'Delete {p0} selected diaries?'**
  String autoT0084(Object p0);

  /// No description provided for @autoT0085.
  ///
  /// In en, this message translates to:
  /// **'No street info'**
  String get autoT0085;

  /// No description provided for @autoT0086.
  ///
  /// In en, this message translates to:
  /// **'Title and content cannot both be empty'**
  String get autoT0086;

  /// No description provided for @autoT0087.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {p0}'**
  String autoT0087(Object p0);

  /// No description provided for @autoT0088.
  ///
  /// In en, this message translates to:
  /// **'No valid cover path found'**
  String get autoT0088;

  /// No description provided for @autoT0089.
  ///
  /// In en, this message translates to:
  /// **'Cover import failed: {p0}'**
  String autoT0089(Object p0);

  /// No description provided for @autoT0090.
  ///
  /// In en, this message translates to:
  /// **'Tag creation failed: {p0}'**
  String autoT0090(Object p0);

  /// No description provided for @autoT0091.
  ///
  /// In en, this message translates to:
  /// **'Location failed: {p0}'**
  String autoT0091(Object p0);

  /// No description provided for @autoT0092.
  ///
  /// In en, this message translates to:
  /// **'Please get current location first'**
  String get autoT0092;

  /// No description provided for @autoT0093.
  ///
  /// In en, this message translates to:
  /// **'Weather fetch failed: {p0}'**
  String autoT0093(Object p0);

  /// No description provided for @autoT0094.
  ///
  /// In en, this message translates to:
  /// **'Delete diary'**
  String get autoT0094;

  /// No description provided for @autoT0095.
  ///
  /// In en, this message translates to:
  /// **'Untitled diary'**
  String get autoT0095;

  /// No description provided for @autoT0096.
  ///
  /// In en, this message translates to:
  /// **'Select publish date'**
  String get autoT0096;

  /// No description provided for @autoT0097.
  ///
  /// In en, this message translates to:
  /// **'Select publish time'**
  String get autoT0097;

  /// No description provided for @autoT0098.
  ///
  /// In en, this message translates to:
  /// **'Publish failed: {p0}'**
  String autoT0098(Object p0);

  /// No description provided for @autoT0099.
  ///
  /// In en, this message translates to:
  /// **'{p0} selected'**
  String autoT0099(Object p0);

  /// No description provided for @autoT0100.
  ///
  /// In en, this message translates to:
  /// **'Archived diaries'**
  String get autoT0100;

  /// No description provided for @autoT0101.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get autoT0101;

  /// No description provided for @autoT0102.
  ///
  /// In en, this message translates to:
  /// **'Archived list load failed: {p0}'**
  String autoT0102(Object p0);

  /// No description provided for @autoT0103.
  ///
  /// In en, this message translates to:
  /// **'No archived diaries'**
  String get autoT0103;

  /// No description provided for @autoT0104.
  ///
  /// In en, this message translates to:
  /// **'(No content)'**
  String get autoT0104;

  /// No description provided for @autoT0105.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get autoT0105;

  /// No description provided for @autoT0106.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get autoT0106;

  /// No description provided for @autoT0107.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get autoT0107;

  /// No description provided for @autoT0108.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get autoT0108;

  /// No description provided for @autoT0109.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get autoT0109;

  /// No description provided for @autoT0110.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get autoT0110;

  /// No description provided for @autoT0111.
  ///
  /// In en, this message translates to:
  /// **'Screenshot failed. Please try again.'**
  String get autoT0111;

  /// No description provided for @autoT0112.
  ///
  /// In en, this message translates to:
  /// **'Image share failed: {p0}'**
  String autoT0112(Object p0);

  /// No description provided for @autoT0113.
  ///
  /// In en, this message translates to:
  /// **'Delete this diary?'**
  String get autoT0113;

  /// No description provided for @autoT0114.
  ///
  /// In en, this message translates to:
  /// **'Share as image'**
  String get autoT0114;

  /// No description provided for @autoT0115.
  ///
  /// In en, this message translates to:
  /// **'Share as text'**
  String get autoT0115;

  /// No description provided for @autoT0116.
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get autoT0116;

  /// No description provided for @autoT0117.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get autoT0117;

  /// No description provided for @autoT0118.
  ///
  /// In en, this message translates to:
  /// **'Last edited'**
  String get autoT0118;

  /// No description provided for @autoT0119.
  ///
  /// In en, this message translates to:
  /// **'No content yet'**
  String get autoT0119;

  /// No description provided for @autoT0120.
  ///
  /// In en, this message translates to:
  /// **'Diary'**
  String get autoT0120;

  /// No description provided for @autoT0121.
  ///
  /// In en, this message translates to:
  /// **'Load failed: {p0}'**
  String autoT0121(Object p0);

  /// No description provided for @autoT0122.
  ///
  /// In en, this message translates to:
  /// **'Diary no longer exists'**
  String get autoT0122;

  /// No description provided for @autoT0123.
  ///
  /// In en, this message translates to:
  /// **'Diary no longer exists, returning...'**
  String get autoT0123;

  /// No description provided for @autoT0124.
  ///
  /// In en, this message translates to:
  /// **'Diary not found'**
  String get autoT0124;

  /// No description provided for @autoT0125.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get autoT0125;

  /// No description provided for @autoT0126.
  ///
  /// In en, this message translates to:
  /// **'Tag {p0}'**
  String autoT0126(Object p0);

  /// No description provided for @autoT0127.
  ///
  /// In en, this message translates to:
  /// **'Diary load failed: {p0}'**
  String autoT0127(Object p0);

  /// No description provided for @autoT0128.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get autoT0128;

  /// No description provided for @autoT0129.
  ///
  /// In en, this message translates to:
  /// **'Search title or content'**
  String get autoT0129;

  /// No description provided for @autoT0130.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get autoT0130;

  /// No description provided for @autoT0131.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get autoT0131;

  /// No description provided for @autoT0132.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get autoT0132;

  /// No description provided for @autoT0133.
  ///
  /// In en, this message translates to:
  /// **'Start writing...'**
  String get autoT0133;

  /// No description provided for @autoT0134.
  ///
  /// In en, this message translates to:
  /// **'New diary'**
  String get autoT0134;

  /// No description provided for @autoT0135.
  ///
  /// In en, this message translates to:
  /// **'Edit diary'**
  String get autoT0135;

  /// No description provided for @autoT0136.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get autoT0136;

  /// No description provided for @autoT0137.
  ///
  /// In en, this message translates to:
  /// **'Save diary'**
  String get autoT0137;

  /// No description provided for @autoT0138.
  ///
  /// In en, this message translates to:
  /// **'Publish diary'**
  String get autoT0138;

  /// No description provided for @autoT0139.
  ///
  /// In en, this message translates to:
  /// **'No content'**
  String get autoT0139;

  /// No description provided for @autoT0140.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get autoT0140;

  /// No description provided for @autoT0141.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get autoT0141;

  /// No description provided for @autoT0142.
  ///
  /// In en, this message translates to:
  /// **'Recently updated'**
  String get autoT0142;

  /// No description provided for @autoT0143.
  ///
  /// In en, this message translates to:
  /// **'Oldest updated'**
  String get autoT0143;

  /// No description provided for @autoT0144.
  ///
  /// In en, this message translates to:
  /// **'Title A-Z'**
  String get autoT0144;

  /// No description provided for @autoT0145.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get autoT0145;

  /// No description provided for @autoT0146.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get autoT0146;

  /// No description provided for @autoT0147.
  ///
  /// In en, this message translates to:
  /// **'Waterfall'**
  String get autoT0147;

  /// No description provided for @autoT0148.
  ///
  /// In en, this message translates to:
  /// **'Archived diaries'**
  String get autoT0148;

  /// No description provided for @autoT0149.
  ///
  /// In en, this message translates to:
  /// **'Edit tag'**
  String get autoT0149;

  /// No description provided for @autoT0150.
  ///
  /// In en, this message translates to:
  /// **'Tag name'**
  String get autoT0150;

  /// No description provided for @autoT0151.
  ///
  /// In en, this message translates to:
  /// **'Choose color'**
  String get autoT0151;

  /// No description provided for @autoT0152.
  ///
  /// In en, this message translates to:
  /// **'No diaries found'**
  String get autoT0152;

  /// No description provided for @autoT0153.
  ///
  /// In en, this message translates to:
  /// **'Try another keyword.'**
  String get autoT0153;

  /// No description provided for @autoT0154.
  ///
  /// In en, this message translates to:
  /// **'No diaries yet'**
  String get autoT0154;

  /// No description provided for @autoT0155.
  ///
  /// In en, this message translates to:
  /// **'Create diary'**
  String get autoT0155;

  /// No description provided for @autoT0156.
  ///
  /// In en, this message translates to:
  /// **'Cover load failed'**
  String get autoT0156;

  /// No description provided for @autoT0157.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get autoT0157;

  /// No description provided for @autoT0158.
  ///
  /// In en, this message translates to:
  /// **'Swipe up to expand'**
  String get autoT0158;

  /// No description provided for @autoT0159.
  ///
  /// In en, this message translates to:
  /// **'Swipe down to collapse'**
  String get autoT0159;

  /// No description provided for @autoT0160.
  ///
  /// In en, this message translates to:
  /// **'Choose tags'**
  String get autoT0160;

  /// No description provided for @autoT0161.
  ///
  /// In en, this message translates to:
  /// **'Tap to choose a cover (optional)'**
  String get autoT0161;

  /// No description provided for @autoT0162.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get autoT0162;

  /// No description provided for @autoT0163.
  ///
  /// In en, this message translates to:
  /// **'Clear cover'**
  String get autoT0163;

  /// No description provided for @autoT0164.
  ///
  /// In en, this message translates to:
  /// **'No tag selected'**
  String get autoT0164;

  /// No description provided for @autoT0165.
  ///
  /// In en, this message translates to:
  /// **'Failed to load tags: {p0}'**
  String autoT0165(Object p0);

  /// No description provided for @autoT0166.
  ///
  /// In en, this message translates to:
  /// **'No tags yet, create one first'**
  String get autoT0166;

  /// No description provided for @autoT0167.
  ///
  /// In en, this message translates to:
  /// **'Here and now'**
  String get autoT0167;

  /// No description provided for @autoT0168.
  ///
  /// In en, this message translates to:
  /// **'Tap right button to fetch address'**
  String get autoT0168;

  /// No description provided for @autoT0169.
  ///
  /// In en, this message translates to:
  /// **'Get location'**
  String get autoT0169;

  /// No description provided for @autoT0170.
  ///
  /// In en, this message translates to:
  /// **'Tap right button to fetch weather'**
  String get autoT0170;

  /// No description provided for @autoT0171.
  ///
  /// In en, this message translates to:
  /// **'Get weather'**
  String get autoT0171;

  /// No description provided for @autoT0172.
  ///
  /// In en, this message translates to:
  /// **'Publish time'**
  String get autoT0172;

  /// No description provided for @autoT0173.
  ///
  /// In en, this message translates to:
  /// **'Auto use current time'**
  String get autoT0173;

  /// No description provided for @autoT0174.
  ///
  /// In en, this message translates to:
  /// **'Choose publish time'**
  String get autoT0174;

  /// No description provided for @autoT0175.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get autoT0175;

  /// No description provided for @autoT0176.
  ///
  /// In en, this message translates to:
  /// **'Publishing...'**
  String get autoT0176;

  /// No description provided for @autoT0177.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get autoT0177;

  /// No description provided for @autoT0178.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get autoT0178;

  /// No description provided for @autoT0179.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get autoT0179;

  /// No description provided for @autoT0180.
  ///
  /// In en, this message translates to:
  /// **'Back to today'**
  String get autoT0180;

  /// No description provided for @autoT0181.
  ///
  /// In en, this message translates to:
  /// **'Write for this day'**
  String get autoT0181;

  /// No description provided for @autoT0182.
  ///
  /// In en, this message translates to:
  /// **'This day is quiet, no records yet.'**
  String get autoT0182;

  /// No description provided for @autoT0183.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get autoT0183;

  /// No description provided for @autoT0184.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get autoT0184;

  /// No description provided for @autoT0185.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get autoT0185;

  /// No description provided for @autoT0186.
  ///
  /// In en, this message translates to:
  /// **'Recorded an entry'**
  String get autoT0186;

  /// No description provided for @autoT0187.
  ///
  /// In en, this message translates to:
  /// **'Reset toolbar order to defaults?'**
  String get autoT0187;

  /// No description provided for @autoT0188.
  ///
  /// In en, this message translates to:
  /// **'Apply inline code style to selected text'**
  String get autoT0188;

  /// No description provided for @autoT0189.
  ///
  /// In en, this message translates to:
  /// **'Insert or switch to code block'**
  String get autoT0189;

  /// No description provided for @autoT0190.
  ///
  /// In en, this message translates to:
  /// **'Shows both indent increase/decrease buttons'**
  String get autoT0190;

  /// No description provided for @autoT0191.
  ///
  /// In en, this message translates to:
  /// **'Restored {p0} diaries'**
  String autoT0191(Object p0);

  /// No description provided for @autoT0192.
  ///
  /// In en, this message translates to:
  /// **'Permanently deleted {p0} diaries'**
  String autoT0192(Object p0);

  /// No description provided for @autoT0193.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete {p0} selected diaries? This cannot be undone.'**
  String autoT0193(Object p0);

  /// No description provided for @autoT0194.
  ///
  /// In en, this message translates to:
  /// **'Deleted at {p0}'**
  String autoT0194(Object p0);

  /// No description provided for @autoT0195.
  ///
  /// In en, this message translates to:
  /// **'Delete tag \"{p0}\"?'**
  String autoT0195(Object p0);

  /// No description provided for @autoT0196.
  ///
  /// In en, this message translates to:
  /// **'What person or thing are you most grateful for today?'**
  String get autoT0196;

  /// No description provided for @autoT0197.
  ///
  /// In en, this message translates to:
  /// **'Failed to load images. Please try again later.'**
  String get autoT0197;

  /// No description provided for @autoT0198.
  ///
  /// In en, this message translates to:
  /// **'Keep recording weather, tags, and mood to unlock deeper insights here.'**
  String get autoT0198;

  /// No description provided for @autoT0199.
  ///
  /// In en, this message translates to:
  /// **'No tag data yet. Try writing diaries with tags.'**
  String get autoT0199;

  /// No description provided for @autoT0200.
  ///
  /// In en, this message translates to:
  /// **'Delete {p0} selected archived diaries?'**
  String autoT0200(Object p0);

  /// No description provided for @autoT0201.
  ///
  /// In en, this message translates to:
  /// **'Unarchived {p0} diaries'**
  String autoT0201(Object p0);

  /// No description provided for @autoT0202.
  ///
  /// In en, this message translates to:
  /// **'An unfinished diary was found. Continue editing?'**
  String get autoT0202;

  /// No description provided for @autoT0203.
  ///
  /// In en, this message translates to:
  /// **'metadata must be a valid JSON object'**
  String get autoT0203;

  /// No description provided for @autoT0204.
  ///
  /// In en, this message translates to:
  /// **'AMap Web API key missing, please configure amap.web.api.key'**
  String get autoT0204;

  /// No description provided for @autoT0205.
  ///
  /// In en, this message translates to:
  /// **'QWeather key missing, please configure qweather.api_key'**
  String get autoT0205;

  /// No description provided for @autoT0206.
  ///
  /// In en, this message translates to:
  /// **'This will soft-delete the diary and it can be restored later. Continue?'**
  String get autoT0206;

  /// No description provided for @autoT0207.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Exit anyway?'**
  String get autoT0207;

  /// No description provided for @autoT0208.
  ///
  /// In en, this message translates to:
  /// **'Header style (tap to cycle)'**
  String get autoT0208;

  /// No description provided for @autoT0209.
  ///
  /// In en, this message translates to:
  /// **'An unfinished diary draft was found. Continue editing?'**
  String get autoT0209;

  /// No description provided for @autoT0210.
  ///
  /// In en, this message translates to:
  /// **'Calendar diaries load failed: {p0}'**
  String autoT0210(Object p0);

  /// No description provided for @autoT0211.
  ///
  /// In en, this message translates to:
  /// **'Take it easy, this day\'s highlights haven\'t happened yet.'**
  String get autoT0211;
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
