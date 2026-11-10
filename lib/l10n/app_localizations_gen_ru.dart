// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations_gen.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Jotsy';

  @override
  String get navDiaries => 'Записи';

  @override
  String get navCalendar => 'Календарь';

  @override
  String get navExplore => 'Обзор';

  @override
  String get navSettings => 'Настройки';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonConfirm => 'ОК';

  @override
  String get commonDelete => 'Удалить';

  @override
  String get commonUndo => 'Отменить';

  @override
  String get commonDragToReorder => 'Перетащите, чтобы изменить порядок';

  @override
  String get commonSelectAll => 'Выбрать все';

  @override
  String get commonDeselectAll => 'Снять выделение';

  @override
  String get commonBack => 'Назад';

  @override
  String get commonSave => 'Сохранить';

  @override
  String get commonEdit => 'Изменить';

  @override
  String get commonShare => 'Поделиться';

  @override
  String get commonContinue => 'Продолжить';

  @override
  String get commonCreate => 'Создать';

  @override
  String get commonClose => 'Закрыть';

  @override
  String get commonNew => 'Создать';

  @override
  String get commonReset => 'Сбросить';

  @override
  String get commonRetry => 'Повторить';

  @override
  String get contextFieldInputHint =>
      'Введите погоду или адрес либо нажмите кнопку справа, чтобы определить автоматически';

  @override
  String get contextLocationInputHint =>
      'Введите адрес или нажмите кнопку справа, чтобы определить его автоматически';

  @override
  String get contextWeatherInputHint =>
      'Введите погоду или нажмите кнопку справа, чтобы определить её автоматически';

  @override
  String get timeJustNow => 'Только что';

  @override
  String timeMinutesAgo(int minutes) {
    return '$minutes мин назад';
  }

  @override
  String timeHoursAgo(int hours) {
    return '$hours ч назад';
  }

  @override
  String timeDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days дня назад',
      many: '$days дней назад',
      few: '$days дня назад',
      one: '$days день назад',
    );
    return '$_temp0';
  }

  @override
  String updatedAtLabel(String value) {
    return 'Обновлено $value';
  }

  @override
  String get startupPreloadFailed =>
      'Не удалось заранее загрузить записи при запуске. Открыта главная страница.';

  @override
  String homeInitFailed(String error) {
    return 'Ошибка инициализации: $error';
  }

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsFontScale => 'Размер шрифта';

  @override
  String get settingsFontScaleSubtitle =>
      'Размер шрифта в интерфейсе приложения';

  @override
  String get settingsFontScalePreview =>
      'Пример: ещё один день, ещё пара строк о жизни.';

  @override
  String get settingsDiaryCardTagLimit => 'Теги на карточках';

  @override
  String get settingsDiaryCardTagLimitLoading => 'Загрузка настроек карточек';

  @override
  String get settingsDiaryCardTagLimitUnavailable => 'Настройка недоступна';

  @override
  String get settingsDiaryCardTagLimitHidden => 'Не показывать теги';

  @override
  String settingsDiaryCardTagLimitValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Показывать до $count тега',
      many: 'Показывать до $count тегов',
      few: 'Показывать до $count тегов',
      one: 'Показывать до $count тега',
    );
    return '$_temp0';
  }

  @override
  String get settingsTabSwitchCurve => 'Анимация вкладок';

  @override
  String get settingsTabSwitchCurveSubtitle =>
      'Характер анимации при переключении нижних вкладок';

  @override
  String get settingsTabSwitchCurveEaseOutCirc => 'Плавная (Circ)';

  @override
  String get settingsTabSwitchCurveEaseOutCubic => 'Сбалансированная (Cubic)';

  @override
  String get settingsTabSwitchCurveLinear => 'Линейная';

  @override
  String get settingsLanguage => 'Язык';

  @override
  String get settingsAppLock => 'Блокировка приложения';

  @override
  String get settingsAppLockSubtitle =>
      'Запрашивать подтверждение личности при каждом входе в приложение';

  @override
  String get appLockNotSupported =>
      'На этом устройстве не настроена блокировка экрана, поэтому включить блокировку приложения через системную проверку нельзя. Используйте код приложения.';

  @override
  String get appLockTitle => 'Приложение заблокировано';

  @override
  String get appLockSubtitle => 'Подтвердите личность, чтобы продолжить';

  @override
  String get appLockUnlockNow => 'Разблокировать';

  @override
  String get appLockUnlocking => 'Разблокировка';

  @override
  String get appLockDisableAuthReason =>
      'Подтвердите личность, чтобы отключить блокировку приложения';

  @override
  String get appLockDisableVerifyFailed =>
      'Проверка не пройдена. Блокировка приложения осталась включённой.';

  @override
  String get settingsEditorTitle => 'Редактор';

  @override
  String get settingsEditorSubtitle =>
      'Шрифты, вёрстка, панель инструментов и блоки кода';

  @override
  String get settingsMoodOptionsTitle => 'Эмодзи настроения';

  @override
  String settingsMoodOptionsSlotLabel(String index) {
    return 'Настроение $index';
  }

  @override
  String settingsMoodOptionsSlotHelper(String emoji) {
    return 'По умолчанию: $emoji';
  }

  @override
  String settingsMoodOptionsColorLabel(String index) {
    return 'Цвет настроения $index';
  }

  @override
  String get settingsMoodOptionsColorsHint =>
      'Цвета используются в цветовой основе «Настроение» на странице просмотра и для цвета настроения на карточках записей. Чтобы изменить цвет, нажмите на образец рядом с эмодзи.';

  @override
  String settingsMoodOptionsSaveFailed(String error) {
    return 'Не удалось сохранить эмодзи настроения: $error';
  }

  @override
  String get settingsDataManagement => 'Управление данными';

  @override
  String get settingsDataManagementSubtitle =>
      'Резервные копии, импорт, экспорт и облако';

  @override
  String get settingsTagManagement => 'Управление тегами';

  @override
  String get settingsTagMemory => 'Запоминать теги';

  @override
  String get settingsTagMemorySubtitle =>
      'Запоминать выбранные в списке теги и восстанавливать их при следующем запуске';

  @override
  String get settingsRecycleBin => 'Корзина';

  @override
  String get settingsAbout => 'О приложении';

  @override
  String get languageDialogTitle => 'Выберите язык';

  @override
  String get languageOptionChinese => '中文';

  @override
  String get languageOptionEnglish => 'English';

  @override
  String get aboutTitle => 'О приложении';

  @override
  String get aboutTagline => 'Мелочи и чувства каждого дня';

  @override
  String get aboutVersion => 'Версия';

  @override
  String get aboutPackageName => 'Пакет';

  @override
  String get aboutRepository => 'Репозиторий';

  @override
  String get aboutCopied => 'Скопировано в буфер обмена';

  @override
  String get aboutPageSlogan =>
      'Тихий уголок в шумном мире, который принадлежит только вам.';

  @override
  String get aboutOpenSourceRepo => 'Репозиторий с открытым кодом';

  @override
  String get aboutCheckUpdate => 'Проверить обновления';

  @override
  String aboutUpdateSubtitleAvailable(String version) {
    return 'Доступна версия $version';
  }

  @override
  String aboutUpdateSubtitleDownloading(int percent) {
    return 'Загрузка: $percent%';
  }

  @override
  String get aboutUpdateSubtitleReady =>
      'Обновление загружено, нажмите, чтобы установить';

  @override
  String get appUpdateTitle => 'Обновления приложения';

  @override
  String appUpdateCurrentVersion(String version) {
    return 'Текущая версия: $version';
  }

  @override
  String get appUpdateChecking => 'Проверка обновлений…';

  @override
  String get appUpdateCheckingHint =>
      'Опрашиваем несколько источников сразу и берём тот, что ответит первым';

  @override
  String get appUpdateUpToDate => 'У вас последняя версия';

  @override
  String appUpdateLastChecked(String time) {
    return 'Последняя проверка: $time';
  }

  @override
  String get appUpdateAvailableBadge => 'Новая';

  @override
  String appUpdateAvailableTitle(String version) {
    return 'Доступна версия $version';
  }

  @override
  String appUpdatePublishedOn(String date) {
    return 'Выпущена $date';
  }

  @override
  String get appUpdateReleaseNotesTitle => 'Что нового';

  @override
  String get appUpdateCurrentNotesTitle => 'В этой версии';

  @override
  String get appUpdateNoReleaseNotes =>
      'Для этой версии нет описания изменений.';

  @override
  String get appUpdateViewOnGitHub => 'Открыть на GitHub';

  @override
  String get aboutChangelog => 'Список изменений';

  @override
  String get changelogTitle => 'Список изменений';

  @override
  String get changelogCurrentVersion => 'Текущая';

  @override
  String get changelogShowAll => 'Показать всё';

  @override
  String get changelogCollapse => 'Свернуть';

  @override
  String get changelogEmpty => 'Описаний изменений пока нет.';

  @override
  String get changelogAllReleases => 'Все версии на GitHub';

  @override
  String get appUpdateActionCheck => 'Проверить обновления';

  @override
  String appUpdateActionDownload(String size) {
    return 'Загрузить и установить ($size)';
  }

  @override
  String get appUpdateActionDownloadNoSize => 'Загрузить и установить';

  @override
  String appUpdateActionResume(int percent) {
    return 'Продолжить загрузку (готово $percent%)';
  }

  @override
  String get appUpdateActionCancel => 'Отменить загрузку';

  @override
  String get appUpdateActionInstall => 'Установить';

  @override
  String get appUpdateActionRetry => 'Повторить';

  @override
  String get appUpdateActionOpenReleasePage => 'Открыть страницу загрузки';

  @override
  String get appUpdateActionSkip => 'Пропустить эту версию';

  @override
  String get appUpdateSkippedHint =>
      'Версия пропущена: напоминаний при запуске не будет';

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
    return 'через $route';
  }

  @override
  String get appUpdateVerifying => 'Проверка пакета…';

  @override
  String get appUpdateReadyToInstall => 'Загружено и проверено';

  @override
  String get appUpdateInstallPermissionTitle =>
      'Разрешите установку приложений';

  @override
  String get appUpdateInstallPermissionMessage =>
      'Android требует разрешить Jotsy устанавливать неизвестные приложения в системных настройках. Включите разрешение и вернитесь сюда — установка продолжится автоматически.';

  @override
  String get appUpdateInstallPermissionAction => 'Открыть настройки';

  @override
  String get appUpdateInstallPermissionSettingsFailed =>
      'Не удалось открыть системные настройки. Разрешите Jotsy устанавливать неизвестные приложения в разделе «Настройки → Приложения → Jotsy».';

  @override
  String get appUpdateUnsupportedPlatform =>
      'На этой платформе установка из приложения не поддерживается. Скачайте новую версию на странице загрузки.';

  @override
  String get appUpdateNoCompatibleApk =>
      'В этом выпуске нет пакета для процессора вашего устройства. Выберите пакет вручную на странице загрузки.';

  @override
  String get appUpdateFailedCheckTitle => 'Не удалось проверить обновления';

  @override
  String get appUpdateFailedDownloadTitle => 'Ошибка загрузки';

  @override
  String get appUpdateFailedInstallTitle => 'Не удалось установить';

  @override
  String get appUpdateFailureNetwork =>
      'Ни один источник не ответил. Повторите попытку позже или выберите другой источник либо своё зеркало в разделе «Источник загрузки» ниже.';

  @override
  String get appUpdateFailureNotFound => 'Опубликованный выпуск не найден.';

  @override
  String get appUpdateFailureIntegrity =>
      'Загруженный файл неполный или изменён (контрольная сумма не совпадает) и был удалён. Повторите попытку или выберите другой источник.';

  @override
  String get appUpdateFailureSignature =>
      'Подпись пакета отличается от подписи этого приложения, поэтому установить его поверх нельзя. Скачивайте обновления только с официальной страницы выпусков.';

  @override
  String get appUpdateFailureNotNewer =>
      'Загруженный пакет не новее текущей версии.';

  @override
  String get appUpdateFailureStorage =>
      'Не удалось сохранить пакет. Проверьте, достаточно ли свободного места на устройстве.';

  @override
  String get appUpdateFailureInstallUnavailable =>
      'Не удалось открыть системный установщик. Установите обновление вручную со страницы загрузки.';

  @override
  String get appUpdateSettingsTitle => 'Настройки обновлений';

  @override
  String get appUpdateAutoCheck => 'Проверять автоматически';

  @override
  String get appUpdateAutoCheckSubtitle =>
      'При открытии приложения или возврате в него, не чаще раза в 2 часа; читаются только общедоступные сведения о версиях';

  @override
  String get appUpdateSource => 'Источник загрузки';

  @override
  String get appUpdateSourceAuto => 'Автоматически';

  @override
  String get appUpdateSourceAutoDescription =>
      'Проверяет скорость всех источников и выбирает самый быстрый; рекомендуется в материковом Китае';

  @override
  String get appUpdateSourceDirect => 'GitHub напрямую';

  @override
  String get appUpdateSourceDirectDescription =>
      'Без зеркала; в материковом Китае может работать медленно или быть недоступен';

  @override
  String get appUpdateSourceMirrorDescription => 'Общедоступное зеркало';

  @override
  String get appUpdateSourceCustom => 'Своё зеркало';

  @override
  String get appUpdateSourceCustomDescription =>
      'Если встроенные зеркала перестали работать, укажите доступный вам прокси для GitHub';

  @override
  String get appUpdateSourceCustomHint =>
      'например, https://mirror.example.com/';

  @override
  String get appUpdateSourceCustomInvalid =>
      'Введите адрес, начинающийся с https://';

  @override
  String get appUpdateSourceSheetHint =>
      'Зеркала — это сторонние общедоступные сервисы. После загрузки каждый пакет сверяется с SHA-256 и подписью приложения, поэтому зеркало не может подменить его другим приложением.';

  @override
  String get appUpdatePromptUpdate => 'Обновить';

  @override
  String get appUpdatePromptLater => 'Позже';

  @override
  String get appUpdateActionDesktopDownload => 'Скачать';

  @override
  String get appUpdateDesktopHintWindows =>
      'Установщик будет скачан в браузере. Запустите его, чтобы обновить приложение поверх текущего; записи сохранятся.';

  @override
  String get appUpdateDesktopHintLinux =>
      'Архив .tar.gz будет скачан в браузере. Распакуйте его и запустите install.sh, чтобы обновить приложение; записи сохранятся.';

  @override
  String get appUpdateNoDesktopPackage =>
      'В этом выпуске нет пакета для вашей системы. Загляните на страницу загрузки.';

  @override
  String get appUpdateSourceAutoDescriptionDesktop =>
      'Использует источник, который первым ответил при проверке обновлений; рекомендуется в материковом Китае';

  @override
  String get appUpdateSourceSheetHintDesktop =>
      'Зеркала — это сторонние общедоступные сервисы. После загрузки файл можно сверить с SHA256SUMS.txt на странице выпуска.';

  @override
  String get aboutSubmitIssue => 'Сообщить о проблеме';

  @override
  String get aboutQqFeedbackGroup => 'Группа обратной связи в QQ';

  @override
  String get aboutQqFeedbackGroupSubtitle => '678136434';

  @override
  String get aboutQqFeedbackGroupCopied =>
      'Номер группы QQ скопирован в буфер обмена';

  @override
  String get aboutPrivacyAndData => 'Конфиденциальность и безопасность данных';

  @override
  String get aboutPrivacyDialogTitle =>
      'Конфиденциальность и безопасность данных';

  @override
  String get aboutPrivacyDialogMessage =>
      'Ваши записи, теги и медиафайлы хранятся локально на этом устройстве и по умолчанию не загружаются в облако. ИИ-помощник по умолчанию выключен; если его включить, он отправляет только то, что нужно конкретной функции ИИ, и только напрямую в настроенный вами ИИ-сервис, а ключ остаётся на этом устройстве.';

  @override
  String get aboutOpenSourceLicenses => 'Лицензии стороннего открытого ПО';

  @override
  String get aboutOpenLinkFallbackCopied =>
      'Не удалось открыть ссылку. Она скопирована в буфер обмена.';

  @override
  String get aboutFooterCopyright => '© 2026 Jot Project';

  @override
  String get dataMgmtTitle => 'Управление данными';

  @override
  String get dataMgmtExport => 'Экспорт данных';

  @override
  String get dataMgmtExportSubtitle =>
      'ZIP-архив с записями, тегами, настройками, изображениями, аудиозаписями, видео и вложениями';

  @override
  String get dataMgmtImport => 'Импорт данных';

  @override
  String get dataMgmtImportSubtitle =>
      'Импорт полной резервной копии или файла записей с объединением или заменой';

  @override
  String get dataMgmtHint =>
      'Чтобы экспортировать одну запись, откройте её просмотр и воспользуйтесь меню «Ещё». Импорт с объединением лишь добавляет записи, которых нет на этом устройстве, и не меняет существующие; восстановление с заменой безвозвратно заменяет данные на этом устройстве, поэтому сначала экспортируйте резервную копию.';

  @override
  String get dataMgmtBusyExport => 'Экспорт данных…';

  @override
  String get dataMgmtBusyImport => 'Импорт данных…';

  @override
  String get dataMgmtSaveDialogTitle => 'Сохранить резервную копию';

  @override
  String get dataMgmtPickDialogTitle => 'Выберите файл резервной копии';

  @override
  String get dataMgmtExportSuccess => 'Экспорт данных завершён';

  @override
  String get dataMgmtExportCanceled => 'Экспорт отменён';

  @override
  String dataMgmtExportFailed(String error) {
    return 'Ошибка экспорта: $error';
  }

  @override
  String get dataMgmtImportSuccess => 'Импорт данных завершён';

  @override
  String get dataMgmtImportCanceled => 'Импорт отменён';

  @override
  String dataMgmtImportFailed(String error) {
    return 'Ошибка импорта: $error';
  }

  @override
  String get dataMgmtImportAction => 'Импортировать';

  @override
  String get dataMgmtBusyLabel => 'Обработка данных';

  @override
  String get dataMgmtExportPasswordTitle =>
      'Пароль для экспорта (необязательно)';

  @override
  String get dataMgmtExportPasswordHint =>
      'Оставьте пустым, чтобы не шифровать';

  @override
  String get dataMgmtExportPasswordWarning =>
      'Храните этот пароль в надёжном месте. Данные шифруются сквозным шифрованием на этом устройстве, и восстановить пароль мы не сможем. Если вы его забудете, экспортированные данные будет невозможно восстановить.';

  @override
  String get dataMgmtImportPasswordTitle => 'Пароль для импорта';

  @override
  String get dataMgmtImportPasswordHint => 'Введите пароль для импорта';

  @override
  String colorFamilySwatchLabel(int index, String hex) {
    return 'Палитра $index, $hex';
  }

  @override
  String colorSwatchLabel(String hex) {
    return 'Цвет $hex';
  }

  @override
  String get diaryPinSelected => 'Закрепить';

  @override
  String get diaryUnpinSelected => 'Открепить';

  @override
  String get tagFilterClearLabel => 'Сбросить фильтр по тегам';

  @override
  String searchRemoveTagCondition(String tagName) {
    return 'Убрать тег «$tagName»';
  }

  @override
  String get passwordShow => 'Показать пароль';

  @override
  String get passwordHide => 'Скрыть пароль';

  @override
  String get commonLoading => 'Загрузка';

  @override
  String exploreOnThisDayYearsAgo(int years) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$years года назад в этот день',
      many: '$years лет назад в этот день',
      few: '$years года назад в этот день',
      one: '$years год назад в этот день',
    );
    return '$_temp0';
  }

  @override
  String get dateTimeMinutePattern => 'dd.MM.yyyy HH:mm';

  @override
  String get energyLevelExhausted => 'Без сил';

  @override
  String get energyLevelTired => 'Небольшая усталость';

  @override
  String get energyLevelSoSo => 'Так себе';

  @override
  String get energyLevelGood => 'Довольно бодро';

  @override
  String get energyLevelFull => 'Энергии через край';

  @override
  String get startupPreloadFailedNotice =>
      'Не удалось заранее загрузить записи при запуске. Открыта главная страница.';

  @override
  String startupInitFailed(String error) {
    return 'Ошибка инициализации: $error';
  }

  @override
  String get appLockAuthReason =>
      'Подтвердите личность, чтобы разблокировать приложение';

  @override
  String get autoT0001 => 'Загрузка приложения';

  @override
  String get autoT0002 => 'Копировать';

  @override
  String get autoT0003 => 'Сбросить порядок';

  @override
  String autoT0004(String p0) {
    return 'Не удалось сохранить порядок: $p0';
  }

  @override
  String get autoT0005 => 'Порядок панели инструментов';

  @override
  String get autoT0006 => 'Отменить';

  @override
  String get autoT0007 => 'Повторить';

  @override
  String get autoT0008 => 'Жирный';

  @override
  String get autoT0009 => 'Курсив';

  @override
  String get autoT0010 => 'Подчёркнутый';

  @override
  String get autoT0011 => 'Зачёркнутый';

  @override
  String get autoT0012 => 'Встроенный код';

  @override
  String get autoT0013 => 'Цвет текста';

  @override
  String get autoT0014 => 'Цвет фона';

  @override
  String get autoT0015 => 'Очистить форматирование';

  @override
  String get autoT0016 => 'Вставить изображение';

  @override
  String get autoT0017 => 'Стиль заголовка';

  @override
  String get autoT0018 => 'Нумерованный список';

  @override
  String get autoT0019 => 'Маркированный список';

  @override
  String get autoT0020 => 'Список задач';

  @override
  String get autoT0021 => 'Блок кода';

  @override
  String get autoT0022 => 'Цитата';

  @override
  String get autoT0023 => 'Отступ';

  @override
  String get autoT0024 => 'Ссылка';

  @override
  String get autoT0025 => 'Время удаления неизвестно';

  @override
  String get autoT0026 =>
      'Не все записи удалось восстановить. Повторите попытку.';

  @override
  String get autoT0027 => 'Не все записи удалось удалить. Повторите попытку.';

  @override
  String get autoT0028 => 'Удалить навсегда';

  @override
  String get autoT0029 => 'Корзина';

  @override
  String get autoT0030 => 'Восстановить';

  @override
  String autoT0031(String p0) {
    return 'Не удалось загрузить корзину: $p0';
  }

  @override
  String get autoT0032 => 'Корзина пуста';

  @override
  String get autoT0033 => 'Без названия';

  @override
  String autoT0034(String p0) {
    return 'Не удалось создать тег: $p0';
  }

  @override
  String autoT0035(String p0) {
    return 'Не удалось изменить тег: $p0';
  }

  @override
  String autoT0036(String p0) {
    return 'Не удалось удалить тег: $p0';
  }

  @override
  String autoT0037(String p0) {
    return 'Не удалось сохранить порядок тегов: $p0';
  }

  @override
  String get autoT0038 => 'Удалить тег';

  @override
  String get autoT0039 => 'Управление тегами';

  @override
  String get autoT0040 => 'Создать тег';

  @override
  String get autoT0041 => 'Создайте первый тег';

  @override
  String autoT0042(String p0) {
    return 'Не удалось загрузить теги: $p0';
  }

  @override
  String get autoT0043 => 'Порядок кнопок панели';

  @override
  String autoT0044(String p0) {
    return 'Сейчас первые 4: $p0';
  }

  @override
  String autoT0045(String p0) {
    return 'Не удалось загрузить настройки: $p0';
  }

  @override
  String get autoT0046 => 'Системная';

  @override
  String get autoT0047 => 'Светлая';

  @override
  String get autoT0048 => 'Тёмная';

  @override
  String get autoT0049 => 'Что неожиданно хорошего случилось сегодня?';

  @override
  String get autoT0050 =>
      'Если бы у сегодняшнего дня был заголовок, каким бы он был?';

  @override
  String get autoT0051 =>
      'Какой момент сегодня больше всего хочется запомнить?';

  @override
  String get autoT0052 => 'Просмотр медиафайлов';

  @override
  String get autoT0053 => 'Нет изображений для просмотра';

  @override
  String get autoT0054 => 'Галерея медиафайлов';

  @override
  String get autoT0055 => 'Изображений пока нет';

  @override
  String get autoT0056 => 'Не удалось загрузить. Нажмите, чтобы повторить';

  @override
  String get autoT0057 => 'Больше изображений нет';

  @override
  String get autoT0058 => 'Обзор';

  @override
  String get autoT0059 => 'Данные обзора недоступны';

  @override
  String get autoT0061 => 'Все изображения';

  @override
  String get autoT0062 => 'Изображений пока нет.';

  @override
  String get autoT0063 => 'В этот день';

  @override
  String get autoT0064 => 'Написать за сегодня';

  @override
  String get autoT0065 => 'Запись без названия';

  @override
  String get autoT0069 => 'Облако тегов';

  @override
  String get autoT0070 => 'Удалить записи';

  @override
  String get autoT0071 => 'Не удалось вернуть из архива. Повторите попытку.';

  @override
  String get autoT0072 => 'Снова в архиве';

  @override
  String get autoT0073 => 'Не удалось удалить. Повторите попытку.';

  @override
  String autoT0074(String p0) {
    return 'Удалено записей: $p0';
  }

  @override
  String get autoT0075 => 'Запись удалена';

  @override
  String get autoT0076 => 'Удалённая запись восстановлена';

  @override
  String get autoT0077 => 'Не удалось восстановить. Повторите попытку.';

  @override
  String get autoT0078 => 'Не удалось архивировать. Повторите попытку.';

  @override
  String autoT0079(String p0) {
    return 'Перемещено в архив записей: $p0';
  }

  @override
  String get autoT0080 => 'Запись возвращена из архива';

  @override
  String autoT0084(String p0) {
    return 'Удалить выбранные записи ($p0)?';
  }

  @override
  String get autoT0085 => 'Нет данных об улице';

  @override
  String get autoT0086 =>
      'Заголовок и текст не могут быть пустыми одновременно';

  @override
  String autoT0087(String p0) {
    return 'Не удалось сохранить: $p0';
  }

  @override
  String get autoT0088 => 'Не найден допустимый путь к обложке';

  @override
  String get autoT0092 => 'Сначала определите текущее место';

  @override
  String get autoT0094 => 'Удалить запись';

  @override
  String get autoT0095 => 'Запись без названия';

  @override
  String get autoT0096 => 'Выберите дату публикации';

  @override
  String get autoT0097 => 'Выберите время публикации';

  @override
  String autoT0099(String p0) {
    return 'Выбрано: $p0';
  }

  @override
  String get autoT0100 => 'Архивные записи';

  @override
  String get autoT0101 => 'Вернуть из архива';

  @override
  String autoT0102(String p0) {
    return 'Не удалось загрузить архив: $p0';
  }

  @override
  String get autoT0103 => 'В архиве нет записей';

  @override
  String get autoT0104 => '(Нет текста)';

  @override
  String get autoT0105 => 'Нет';

  @override
  String get autoT0106 => 'Заголовок';

  @override
  String get autoT0107 => 'Создано';

  @override
  String get autoT0108 => 'Обновлено';

  @override
  String get autoT0109 => 'Теги';

  @override
  String get autoT0110 => 'Текст';

  @override
  String get autoT0111 => 'Не удалось сделать снимок. Повторите попытку.';

  @override
  String autoT0112(String p0) {
    return 'Не удалось поделиться изображением: $p0';
  }

  @override
  String get autoT0113 => 'Удалить эту запись?';

  @override
  String get autoT0114 => 'Поделиться изображением';

  @override
  String get autoT0115 => 'Поделиться текстом';

  @override
  String get previewExportSaveDialogTitle => 'Сохранить файл экспорта';

  @override
  String get previewExportCanceled => 'Экспорт отменён';

  @override
  String previewExportFailed(String error) {
    return 'Ошибка экспорта: $error';
  }

  @override
  String get autoT0116 => 'Настроение';

  @override
  String get autoT0117 => 'Опубликовано';

  @override
  String get autoT0118 => 'Последнее изменение';

  @override
  String get autoT0119 => 'Текста пока нет';

  @override
  String get autoT0120 => 'Запись';

  @override
  String autoT0121(String p0) {
    return 'Ошибка загрузки: $p0';
  }

  @override
  String get autoT0122 => 'Запись больше не существует';

  @override
  String get autoT0123 => 'Запись больше не существует, возвращаемся…';

  @override
  String get autoT0124 => 'Запись не найдена';

  @override
  String get autoT0125 => 'Ещё';

  @override
  String autoT0126(String p0) {
    return 'Тег $p0';
  }

  @override
  String autoT0127(String p0) {
    return 'Не удалось загрузить запись: $p0';
  }

  @override
  String get autoT0128 => 'Закрыть поиск';

  @override
  String get autoT0129 => 'Поиск по заголовку или тексту';

  @override
  String get autoT0130 => 'Очистить';

  @override
  String get autoT0131 => 'Несохранённые изменения';

  @override
  String get autoT0132 => 'Выйти';

  @override
  String get editSaveAndExit => 'Сохранить и выйти';

  @override
  String get autoT0133 => 'Начните писать…';

  @override
  String get autoT0134 => 'Новая запись';

  @override
  String get autoT0135 => 'Редактирование записи';

  @override
  String get autoT0136 => 'Опубликовать';

  @override
  String get autoT0137 => 'Сохранить запись';

  @override
  String get autoT0138 => 'Опубликовать запись';

  @override
  String get autoT0139 => 'Нет текста';

  @override
  String get autoT0140 => 'Архивировать';

  @override
  String get autoT0141 => 'Сортировка';

  @override
  String get autoT0145 => 'Вид';

  @override
  String get autoT0146 => 'Список';

  @override
  String get autoT0147 => 'Плитка';

  @override
  String get autoT0148 => 'Архив';

  @override
  String get autoT0149 => 'Изменить тег';

  @override
  String get autoT0150 => 'Название тега';

  @override
  String get autoT0151 => 'Выберите цвет';

  @override
  String get autoT0152 => 'Записи не найдены';

  @override
  String get autoT0153 => 'Попробуйте другое ключевое слово.';

  @override
  String get autoT0154 => 'Записей пока нет';

  @override
  String get autoT0155 => 'Создать запись';

  @override
  String get autoT0156 => 'Не удалось загрузить обложку';

  @override
  String get autoT0157 => 'Создать';

  @override
  String get autoT0158 => 'Проведите вверх, чтобы развернуть';

  @override
  String get autoT0159 => 'Проведите вниз, чтобы свернуть';

  @override
  String get autoT0160 => 'Выберите теги';

  @override
  String get autoT0161 => 'Нажмите, чтобы выбрать обложку (необязательно)';

  @override
  String get autoT0162 => 'Обложка';

  @override
  String get autoT0163 => 'Убрать обложку';

  @override
  String get autoT0164 => 'Теги не выбраны';

  @override
  String autoT0165(String p0) {
    return 'Не удалось загрузить теги: $p0';
  }

  @override
  String get autoT0166 => 'Тегов пока нет — сначала создайте тег';

  @override
  String get autoT0167 => 'Здесь и сейчас';

  @override
  String get autoT0168 => 'Нажмите кнопку справа, чтобы определить адрес';

  @override
  String get autoT0169 => 'Определить место';

  @override
  String get autoT0170 => 'Нажмите кнопку справа, чтобы узнать погоду';

  @override
  String get autoT0171 => 'Узнать погоду';

  @override
  String get autoT0172 => 'Время публикации';

  @override
  String get autoT0173 => 'Использовать текущее время';

  @override
  String get autoT0174 => 'Выберите время публикации';

  @override
  String get autoT0175 => 'Энергия';

  @override
  String get autoT0176 => 'Публикация…';

  @override
  String get autoT0177 => 'Выберите дату';

  @override
  String get autoT0178 => 'Месяц';

  @override
  String get autoT0179 => 'Неделя';

  @override
  String get autoT0180 => 'К сегодняшнему дню';

  @override
  String get autoT0181 => 'Написать за этот день';

  @override
  String get autoT0182 => 'Этот день прошёл тихо — записей нет.';

  @override
  String get autoT0183 => 'Календарь';

  @override
  String get autoT0184 => 'Предыдущий месяц';

  @override
  String get autoT0185 => 'Следующий месяц';

  @override
  String get autoT0186 => 'Сделана запись';

  @override
  String get autoT0187 => 'Вернуть порядок панели инструментов по умолчанию?';

  @override
  String get autoT0188 => 'Оформить выделенный текст как встроенный код';

  @override
  String get autoT0189 =>
      'Превратить в блок кода; внутри блока нажмите, чтобы выбрать язык, скопировать код или выйти из блока.';

  @override
  String get autoT0190 => 'Показывает обе кнопки: увеличить и уменьшить отступ';

  @override
  String autoT0191(String p0) {
    return 'Восстановлено записей: $p0';
  }

  @override
  String autoT0192(String p0) {
    return 'Удалено навсегда записей: $p0';
  }

  @override
  String autoT0193(String p0) {
    return 'Удалить навсегда выбранные записи ($p0)? Это действие нельзя отменить.';
  }

  @override
  String autoT0194(String p0) {
    return 'Удалено $p0';
  }

  @override
  String recycleBinEntryFooter(String date, String deletedAt) {
    return '$date · $deletedAt';
  }

  @override
  String autoT0195(String p0) {
    return 'Удалить тег «$p0»?';
  }

  @override
  String get autoT0196 => 'Кому или чему вы больше всего благодарны сегодня?';

  @override
  String get autoT0197 =>
      'Не удалось загрузить изображения. Повторите попытку позже.';

  @override
  String get autoT0199 =>
      'Данных о тегах пока нет. Напишите несколько записей с тегами.';

  @override
  String autoT0200(String p0) {
    return 'Удалить выбранные архивные записи ($p0)?';
  }

  @override
  String autoT0201(String p0) {
    return 'Возвращено из архива записей: $p0';
  }

  @override
  String get autoT0203 => 'metadata должен быть корректным объектом JSON';

  @override
  String get autoT0204 =>
      'Не найден ключ AMap Web API. Укажите amap.web.api.key';

  @override
  String get autoT0205 => 'Не найден ключ QWeather. Укажите qweather.api_key';

  @override
  String get autoT0206 =>
      'Запись будет перемещена в корзину, её можно будет восстановить. Продолжить?';

  @override
  String get autoT0207 => 'Есть несохранённые изменения. Всё равно выйти?';

  @override
  String get autoT0208 => 'Стиль заголовка (нажмите, чтобы сменить)';

  @override
  String autoT0210(String p0) {
    return 'Не удалось загрузить записи календаря: $p0';
  }

  @override
  String get autoT0211 =>
      'Не спешите: всё самое интересное в этом дне ещё впереди.';

  @override
  String get timeCapsuleTitle => 'Капсула времени';

  @override
  String get timeCapsuleUnset => 'Не запечатана';

  @override
  String timeCapsuleSet(String p0) {
    return 'Откроется $p0';
  }

  @override
  String get timeCapsulePickTitle => 'Выберите время открытия';

  @override
  String get timeCapsulePrecisionMinute => 'Точное время';

  @override
  String get timeCapsulePrecisionDate => 'Только дата';

  @override
  String get timeCapsuleQuickWeek => 'Через неделю';

  @override
  String get timeCapsuleQuickMonth => 'Через месяц';

  @override
  String get timeCapsuleQuickYear => 'Через год';

  @override
  String get timeCapsuleClear => 'Отменить капсулу времени';

  @override
  String get timeCapsuleLockedTitle => 'Спящее мгновение';

  @override
  String timeCapsuleCountdownDays(String p0) {
    return 'Откроется через $p0 дн.';
  }

  @override
  String timeCapsuleCountdownHours(String p0) {
    return 'Откроется через $p0 ч';
  }

  @override
  String timeCapsuleLockedHint(String p0) {
    return 'Эта запись запечатана до $p0. Можно изменить время открытия или удалить её, но текст останется скрытым.';
  }

  @override
  String get timeCapsuleUpdateUnlock => 'Изменить время открытия';

  @override
  String get timeCapsuleSealing => 'Запечатываем это мгновение…';

  @override
  String timeCapsuleSealDone(String p0) {
    return 'Запечатано до $p0';
  }

  @override
  String timeCapsuleUnlockedInsight(String p0) {
    return 'Когда вы писали эту запись, ваше настроение было $p0. А как вы сегодня?';
  }

  @override
  String get timeCapsuleUnlockedInsightNoMood =>
      'Эта запись ждала вас здесь, в будущем. Как вы себя чувствуете сегодня?';

  @override
  String get webDavServerUrl => 'URL сервера';

  @override
  String get webDavServerUrlHint =>
      'например, https://nas.example.com:5006/webdav/';

  @override
  String get webDavUsername => 'Имя пользователя';

  @override
  String get webDavPassword => 'Пароль или токен';

  @override
  String get webDavRemoteDirectory => 'Удалённая папка';

  @override
  String get webDavRemoteDirectoryHint => 'например, /jotsy/';

  @override
  String get webDavHint =>
      'Создайте на NAS отдельную папку для Jotsy и по возможности используйте пароль приложения или токен. При выгрузке создаётся полная резервная копия в ZIP; при восстановлении её можно объединить с данными на устройстве или заменить ими эти данные.';

  @override
  String get imageViewerSaveToGallery => 'Сохранить в галерею';

  @override
  String get imageViewerSaving => 'Сохранение…';

  @override
  String get imageViewerSaveSuccess => 'Сохранено в галерею';

  @override
  String imageViewerSaveFailed(String error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String get imageViewerGalleryPermissionDenied =>
      'Нет доступа к галерее, сохранить не удалось';

  @override
  String get desktopSaveAs => 'Сохранить как…';

  @override
  String get desktopSaveImageDialogTitle => 'Сохранить изображение';

  @override
  String get desktopSaveVideoDialogTitle => 'Сохранить видео';

  @override
  String desktopSavedTo(String path) {
    return 'Сохранено: $path';
  }

  @override
  String get diaryShareSaveImages => 'Сохранить изображения…';

  @override
  String get diaryShareSaveImagesDialogTitle =>
      'Выберите папку для изображений';

  @override
  String diaryShareImagesSaved(int count, String path) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count изображения сохранено в $path',
      many: '$count изображений сохранено в $path',
      few: '$count изображения сохранены в $path',
      one: '$count изображение сохранено в $path',
    );
    return '$_temp0';
  }

  @override
  String get diaryShareLongImageSave => 'Сохранить как длинное изображение…';

  @override
  String get videoOpenExternally => 'Открыть в системном плеере';

  @override
  String get videoPosterHint => 'Щёлкните, чтобы открыть в системном плеере';

  @override
  String get deviceAuthUnavailable =>
      'На этом устройстве нет системной проверки. Чтобы использовать блокировку, задайте код приложения в разделе Настройки → Блокировка и код';

  @override
  String get calendarYearSaveImage => 'Сохранить этот год как изображение…';

  @override
  String get imageViewerSharing => 'Подготовка к отправке…';

  @override
  String imageViewerShareFailed(String error) {
    return 'Не удалось поделиться: $error';
  }

  @override
  String get imageViewerDownloadFailed =>
      'Не удалось загрузить изображение. Проверьте подключение и повторите попытку';

  @override
  String get imageViewerOpenDiary => 'Открыть запись';

  @override
  String get imageViewerImageUnreadable =>
      'Не удалось прочитать изображение, поделиться им нельзя';

  @override
  String get imageViewerMoreActions => 'Другие действия';

  @override
  String get imageViewerPrevious => 'Предыдущее изображение';

  @override
  String get imageViewerNext => 'Следующее изображение';

  @override
  String get diaryToolbarInsertCurrentTime => 'Вставить текущее время';

  @override
  String get diaryToolbarRecording => 'Аудиозапись';

  @override
  String get recordingStart => 'Начать запись';

  @override
  String get recordingPause => 'Приостановить запись';

  @override
  String get recordingResume => 'Продолжить запись';

  @override
  String get recordingFinish => 'Завершить запись';

  @override
  String get recordingClose => 'Закрыть аудиозапись';

  @override
  String get recordingPaused => 'Пауза';

  @override
  String get recordingPermissionDenied => 'Нет доступа к микрофону';

  @override
  String get recordingFailed => 'Не удалось записать звук. Повторите попытку.';

  @override
  String get recordingSaveFailed =>
      'Не удалось сохранить аудиозапись. Повторите попытку.';

  @override
  String get recordingAttachment => 'Аудиозапись';

  @override
  String get recordingPlaybackPlay => 'Воспроизвести аудиозапись';

  @override
  String get recordingPlaybackPause => 'Приостановить воспроизведение';

  @override
  String get recordingPlaybackFailed => 'Не удаётся воспроизвести аудиозапись';

  @override
  String get recordingRename => 'Переименовать аудиозапись';

  @override
  String get recordingNameHint => 'Введите название аудиозаписи';

  @override
  String get recordingDefaultTitle => 'Голосовая заметка';

  @override
  String get recordingStatusRecording => 'Идёт запись';

  @override
  String get recordingIdleHint => 'Нажмите на микрофон, чтобы начать';

  @override
  String get diaryToolbarToolSettingsTooltip => 'Параметры инструмента';

  @override
  String get diaryToolbarTimeFormatTitle => 'Настройка формата времени';

  @override
  String get diaryToolbarTimeFormatLabel => 'Формат времени';

  @override
  String get diaryToolbarTimeFormatHelp =>
      'Формат по умолчанию — M月d日 HH:mm. Можно использовать обозначения DateFormat, такие как yyyy, MM, dd, HH и mm, например yyyy-MM-dd HH:mm.';

  @override
  String diaryToolbarTimeFormatPreview(String value) {
    return 'Предпросмотр: $value';
  }

  @override
  String get diaryToolbarTimeFormatInvalid =>
      'Неверный формат времени. Проверьте шаблон.';

  @override
  String get diaryTagCollapse => 'Свернуть теги';

  @override
  String get diaryTagCollapseHint =>
      'Проведите здесь вверх или нажмите, чтобы свернуть теги';

  @override
  String diaryTagPullHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Потяните вниз, чтобы увидеть все $count тега',
      many: 'Потяните вниз, чтобы увидеть все $count тегов',
      few: 'Потяните вниз, чтобы увидеть все $count тега',
      one: 'Потяните вниз, чтобы увидеть все $count тег',
    );
    return '$_temp0';
  }

  @override
  String diaryTagPullHintDesktop(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Потяните вниз или нажмите, чтобы увидеть все $count тега',
      many: 'Потяните вниз или нажмите, чтобы увидеть все $count тегов',
      few: 'Потяните вниз или нажмите, чтобы увидеть все $count тега',
      one: 'Потяните вниз или нажмите, чтобы увидеть все $count тег',
    );
    return '$_temp0';
  }

  @override
  String get diaryTagExpand => 'Развернуть теги';

  @override
  String get diaryPinnedBadge => 'Закреплено';

  @override
  String get diaryEnergyUnrecorded => 'Не указано';

  @override
  String get diaryEnergySwitchTooltip => 'Включить или выключить учёт энергии';

  @override
  String get diaryToolbarInsertVideo => 'Вставить видео';

  @override
  String get diaryToolbarInsertAttachment => 'Вставить вложение';

  @override
  String get diaryMediaImporting => 'Импорт файлов…';

  @override
  String get diaryMediaImportFailed =>
      'Не удалось импортировать файлы. Повторите попытку.';

  @override
  String get diaryMediaImportPermissionDenied =>
      'Нет доступа на чтение выбранных файлов. Выберите их снова и разрешите доступ.';

  @override
  String get diaryMediaPickerUnavailable =>
      'Не удалось открыть системный выбор файлов. Убедитесь, что на устройстве включена галерея или файловый менеджер.';

  @override
  String get diaryMediaImportUnsupported =>
      'На этой платформе импорт файлов недоступен.';

  @override
  String get diaryMediaFromLibrary => 'Выбрать из галереи';

  @override
  String get diaryMediaTakePhoto => 'Сделать фото';

  @override
  String get diaryMediaRecordVideo => 'Снять видео';

  @override
  String get diaryMediaCameraPermissionDenied =>
      'Нет доступа к камере. Разрешите Jotsy использовать камеру в системных настройках.';

  @override
  String get diaryMediaCameraUnavailable =>
      'На этом устройстве нет доступной камеры.';

  @override
  String get attachmentOpen => 'Открыть вложение';

  @override
  String get attachmentOpenHint => 'Нажмите, чтобы открыть в другом приложении';

  @override
  String get attachmentOpening => 'Открытие вложения…';

  @override
  String get attachmentFileMissing =>
      'Файл вложения отсутствует или недоступен.';

  @override
  String get imageLoadFailed => 'Изображение отсутствует или не загружается.';

  @override
  String get imageHeifUnsupported =>
      'На этом компьютере нельзя показать фото HEIC';

  @override
  String get imageHeifUnsupportedHint =>
      'Откройте Jotsy на телефоне — приложение само преобразует это фото в JPEG. После следующей синхронизации оно появится здесь.';

  @override
  String get imageOpenInOtherApp => 'Открыть в другом приложении';

  @override
  String get attachmentNoApp =>
      'Нет установленного приложения, которое может открыть этот файл.';

  @override
  String get attachmentPermissionDenied => 'Нет доступа к вложению.';

  @override
  String get attachmentOpenFailed =>
      'Не удалось открыть вложение. Повторите попытку.';

  @override
  String get videoLoading => 'Загрузка видео…';

  @override
  String get videoPlay => 'Воспроизвести видео';

  @override
  String get videoPause => 'Приостановить видео';

  @override
  String get videoProgress => 'Позиция воспроизведения';

  @override
  String get videoPlaybackFailed =>
      'Здесь видео не воспроизводится. Нажмите, чтобы открыть в другом приложении.';

  @override
  String get videoExport => 'Экспортировать видео';

  @override
  String get videoExportConfirmTitle => 'Экспорт видео';

  @override
  String videoExportConfirmMessage(String name) {
    return 'Сохранить «$name» в галерею?';
  }

  @override
  String get videoExporting => 'Экспорт видео…';

  @override
  String get videoExportSuccess => 'Видео сохранено в галерею';

  @override
  String get videoExportFileMissing => 'Видеофайл отсутствует или пуст.';

  @override
  String get videoExportPermissionDenied =>
      'Нет доступа к галерее. Не удалось экспортировать видео.';

  @override
  String get videoExportNotEnoughSpace =>
      'Недостаточно места для экспорта этого видео.';

  @override
  String get videoExportUnsupportedFormat =>
      'Видео в этом формате нельзя сохранить в галерею.';

  @override
  String get videoExportDownloadFailed =>
      'Не удалось загрузить видео. Повторите попытку.';

  @override
  String get videoExportFailed =>
      'Не удалось экспортировать видео. Повторите попытку.';

  @override
  String get videoFullscreen => 'Полноэкранный режим';

  @override
  String get videoExitFullscreen => 'Выйти из полноэкранного режима';

  @override
  String get locationPrecisionTitle => 'Точность адреса';

  @override
  String get locationPrecisionCity => 'Город';

  @override
  String get locationPrecisionDistrict => 'Район / округ';

  @override
  String get locationPrecisionTownship => 'Микрорайон / посёлок';

  @override
  String get locationPrecisionStreet => 'Улица';

  @override
  String get locationPrecisionAddress => 'Номер дома';

  @override
  String get locationUnsupported =>
      'На этой платформе автоматическое определение места не поддерживается.';

  @override
  String get locationPermissionDenied =>
      'Нет разрешения на доступ к местоположению. Разрешите доступ и повторите попытку; подойдёт и приблизительное местоположение.';

  @override
  String get locationPermissionDeniedForever =>
      'Доступ к местоположению запрещён. Разрешите его в системных настройках, затем вернитесь и повторите попытку.';

  @override
  String get locationServiceDisabled =>
      'Службы геолокации выключены. Включите их в системных настройках и повторите попытку.';

  @override
  String get locationNetworkError =>
      'Не удалось получить адрес или истекло время ожидания. Проверьте подключение и повторите попытку.';

  @override
  String get locationApiError =>
      'Сервис адресов временно недоступен. Повторите попытку позже.';

  @override
  String get locationAddressInvalid =>
      'Не удалось получить адрес. Повторите попытку позже или введите место вручную.';

  @override
  String get locationUnavailable =>
      'Не удалось определить местоположение. Попробуйте там, где лучше сигнал спутников, или введите место вручную.';

  @override
  String get diarySortFieldUpdated => 'Дата изменения';

  @override
  String get diarySortFieldPublished => 'Дата публикации';

  @override
  String get diarySortFieldTitle => 'Заголовок';

  @override
  String get diarySortHintUpdatedDesc => 'Сначала недавно изменённые';

  @override
  String get diarySortHintUpdatedAsc => 'Сначала давно изменённые';

  @override
  String get diarySortHintPublishedDesc => 'Сначала новые';

  @override
  String get diarySortHintPublishedAsc => 'Сначала старые';

  @override
  String get diarySortHintTitleAsc =>
      'Заголовки А → Я, без заголовка — в конце';

  @override
  String get diarySortHintTitleDesc =>
      'Заголовки Я → А, без заголовка — в конце';

  @override
  String get diaryToolbarMoreTools => 'Другие инструменты';

  @override
  String get diaryToolbarHideMoreTools => 'Скрыть другие инструменты';

  @override
  String get diaryToolbarMoreToolsActive => 'Применено форматирование';

  @override
  String get diaryToolbarOverflowDivider => 'Ниже — в панели «Ещё»';

  @override
  String get backupBusyInspect => 'Чтение файла...';

  @override
  String get backupImportOptionsTitle => 'Способ импорта';

  @override
  String get backupImportKindFull => 'Полная резервная копия';

  @override
  String get backupImportKindDiary => 'Файл записи';

  @override
  String backupImportSummary(int diaries, int tags) {
    String _temp0 = intl.Intl.pluralLogic(
      diaries,
      locale: localeName,
      other: '$diaries записи',
      many: '$diaries записей',
      few: '$diaries записи',
      one: '$diaries запись',
    );
    String _temp1 = intl.Intl.pluralLogic(
      tags,
      locale: localeName,
      other: '$tags тега',
      many: '$tags тегов',
      few: '$tags тега',
      one: '$tags тег',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get backupImportIncludesSettings => 'Включает настройки приложения';

  @override
  String backupImportExistingCount(int count) {
    return 'Из них уже есть на этом устройстве: $count';
  }

  @override
  String get backupImportModeMerge => 'Объединение (рекомендуется)';

  @override
  String get backupImportModeMergeDescription =>
      'Все данные на этом устройстве сохраняются. Добавляются только отсутствующие записи, существующие остаются без изменений.';

  @override
  String get backupImportModeOverwriteExisting =>
      'Заменить существующие записи';

  @override
  String backupImportModeOverwriteExistingDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Добавляет новые записи и заменяет $count существующие записи версиями из файла',
      many:
          'Добавляет новые записи и заменяет $count существующих записей версиями из файла',
      few:
          'Добавляет новые записи и заменяет $count существующие записи версиями из файла',
      one:
          'Добавляет новые записи и заменяет $count существующую запись версией из файла',
    );
    return '$_temp0';
  }

  @override
  String get backupImportModeReplaceAll => 'Заменить все данные';

  @override
  String get backupImportModeReplaceAllDescription =>
      'Все записи, теги, медиафайлы и настройки на этом устройстве будут удалены и заменены содержимым резервной копии';

  @override
  String get backupOverwriteAllTitle => 'Заменить все данные?';

  @override
  String get backupOverwriteExistingTitle => 'Заменить существующие записи?';

  @override
  String get backupOverwriteIrreversible => 'Это действие нельзя отменить';

  @override
  String get backupOverwriteAllLead =>
      'Следующие данные на этом устройстве будут безвозвратно удалены и заменены содержимым резервной копии:';

  @override
  String backupOverwriteAllDiaries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи',
      many: '$count записей',
      few: '$count записи',
      one: '$count запись',
    );
    return '$_temp0 (включая архив и корзину)';
  }

  @override
  String backupOverwriteAllTags(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count тега',
      many: '$count тегов',
      few: '$count тега',
      one: '$count тег',
    );
    return '$_temp0';
  }

  @override
  String get backupOverwriteAllMedia =>
      'Все изображения, аудиозаписи, видео и вложения';

  @override
  String get backupOverwriteAllSettings =>
      'Настройки приложения и неопубликованный черновик';

  @override
  String backupOverwriteExistingBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count записи, которые уже есть на этом устройстве, будут полностью заменены версиями из файла. Их изменения и теги на этом устройстве будут безвозвратно утеряны.',
      many:
          '$count записей, которые уже есть на этом устройстве, будут полностью заменены версиями из файла. Их изменения и теги на этом устройстве будут безвозвратно утеряны.',
      few:
          '$count записи, которые уже есть на этом устройстве, будут полностью заменены версиями из файла. Их изменения и теги на этом устройстве будут безвозвратно утеряны.',
      one:
          '$count запись, которая уже есть на этом устройстве, будет полностью заменена версией из файла. Её изменения и теги на этом устройстве будут безвозвратно утеряны.',
    );
    return '$_temp0 Остальные записи не затрагиваются.';
  }

  @override
  String get backupOverwriteBackupTip =>
      'Чтобы сохранить текущие данные, нажмите «Отмена» и сначала экспортируйте резервную копию.';

  @override
  String get backupOverwriteAcknowledge =>
      'Я понимаю, что заменённые данные нельзя восстановить';

  @override
  String get backupOverwriteConfirm => 'Заменить';

  @override
  String backupOverwriteConfirmCountdown(int seconds) {
    return 'Заменить ($seconds)';
  }

  @override
  String backupImportMergeResult(int added) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: 'Импорт завершён: добавлено $added записи',
      many: 'Импорт завершён: добавлено $added записей',
      few: 'Импорт завершён: добавлено $added записи',
      one: 'Импорт завершён: добавлена $added запись',
      zero: 'Импорт завершён: новых записей нет',
    );
    return '$_temp0';
  }

  @override
  String backupImportMergeSkippedResult(int added, int skipped) {
    return 'Импорт завершён. Добавлено: $added, пропущено: $skipped (уже есть на этом устройстве)';
  }

  @override
  String backupImportOverwriteResult(int added, int replaced) {
    return 'Импорт завершён. Добавлено: $added, заменено: $replaced';
  }

  @override
  String get previewExportDiaryFileConfirm => 'Экспортировать';

  @override
  String get previewExportDiaryFileSuccess =>
      'Файл записи экспортирован. Его можно импортировать в разделе «Управление данными».';

  @override
  String get dataMgmtImportJournal => 'Импорт из других приложений-дневников';

  @override
  String get dataMgmtImportJournalSubtitle =>
      'Day One, Evernote, Google Keep, Obsidian, Xiaomi Notes и ещё 13';

  @override
  String get journalImportSourceTitle => 'Из какого приложения импортировать?';

  @override
  String get journalImportSourceHint =>
      'Сначала экспортируйте данные в том приложении, затем выберите здесь полученный файл.';

  @override
  String get journalImportAppleJournal => '«Дневник» (Apple)';

  @override
  String get journalImportDayOneHint => 'Экспорт в JSON (.zip)';

  @override
  String get journalImportJourneyHint => 'Экспорт в ZIP (.zip)';

  @override
  String get journalImportDiariumHint =>
      'Экспорт в JSON (.json) или файл резервной копии (.diary)';

  @override
  String get journalImportDaylioHint =>
      'Файл резервной копии (.daylio) или экспорт в CSV (.csv)';

  @override
  String get journalImportAppleJournalHint =>
      'На iPhone: Настройки › Приложения › Дневник › экспорт всех записей (.zip)';

  @override
  String journalImportPickDialogTitle(String app) {
    return 'Выберите файл экспорта $app';
  }

  @override
  String journalImportUnrecognized(String app) {
    return 'Этот файл не распознан как экспорт $app';
  }

  @override
  String get journalImportNoEntries => 'В этом файле нет записей для импорта';

  @override
  String get journalImportGroupJournals => 'Приложения-дневники';

  @override
  String get journalImportGroupNotes => 'Приложения для заметок';

  @override
  String get journalImportGroupPhoneNotes => 'Облачные заметки телефонов и WPS';

  @override
  String get journalImportPhoneNotesHint =>
      'Войдите в официальный облачный сервис прямо в приложении, чтобы загрузить заметки, папки и вложенные изображения. Вход используется только для этого импорта и затем удаляется.';

  @override
  String get journalImportDiaroHint =>
      'Файл резервной копии (.zip, без шифрования)';

  @override
  String get journalImportDurianDiary => 'Durian Diary';

  @override
  String get journalImportDurianDiaryHint =>
      'Архив из раздела «Импорт и экспорт» (.lld) или папка резервной копии, сжатая в .zip';

  @override
  String get journalImportEvernote => 'Evernote';

  @override
  String get journalImportEvernoteHint =>
      'Экспорт блокнотов в ENEX (.enex; несколько файлов — в .zip)';

  @override
  String get journalImportGoogleKeepHint =>
      'Экспорт Keep через Google Takeout (.zip)';

  @override
  String get journalImportJoplinHint => 'Экспорт в JEX (.jex)';

  @override
  String get journalImportMemosHint =>
      'Настройки › Экспорт и импорт, версия 0.31 или новее (.zip)';

  @override
  String get journalImportMarkdown => 'Markdown / обычный текст';

  @override
  String get journalImportMarkdownHint =>
      'Файлы .md / .txt из Obsidian, Bear, Notion и других приложений или их .zip';

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
  String get journalImportSmartisanNotes => 'Smartisan Notes';

  @override
  String journalImportEncrypted(String app) {
    return 'Зашифрованные резервные копии $app нельзя импортировать. Создайте в $app резервную копию без шифрования';
  }

  @override
  String cloudLoginTitle(String app) {
    return 'Вход в $app';
  }

  @override
  String get cloudLoginHint =>
      'Войдите на официальной странице выше и откройте свои заметки, затем нажмите «Загрузить заметки». Вход используется только для этого импорта и затем удаляется.';

  @override
  String get cloudLoginRead => 'Загрузить заметки';

  @override
  String get cloudLoginReload => 'Обновить страницу';

  @override
  String get cloudLoginChecking => 'Проверка входа';

  @override
  String get cloudLoginNotSignedIn =>
      'Вы ещё не вошли. Сначала завершите вход на странице';

  @override
  String cloudBusyReading(int count) {
    return 'Загрузка заметок из облака ($count)';
  }

  @override
  String cloudBusyProgress(int done, int total) {
    return 'Загрузка заметок из облака ($done/$total)';
  }

  @override
  String get cloudErrorSession =>
      'Сеанс истёк или требуется дополнительная проверка. Войдите снова';

  @override
  String get cloudErrorForbidden =>
      'Сервис отказал в доступе (HTTP 403). Проверьте права аккаунта или сообщения на сайте';

  @override
  String get cloudErrorRateLimited =>
      'Слишком много запросов. Повторите попытку позже';

  @override
  String get cloudErrorServer =>
      'Сервис временно недоступен. Повторите попытку позже';

  @override
  String get cloudErrorRejected =>
      'Сервис отклонил запрос. Проверьте права аккаунта и повторите попытку';

  @override
  String get cloudErrorNetwork =>
      'Ошибка сетевого запроса. Проверьте подключение и повторите попытку';

  @override
  String cloudErrorProtocol(String app) {
    return 'Сервис $app вернул данные в неизвестном формате. Загрузка остановлена, чтобы не пропустить заметки';
  }

  @override
  String cloudErrorUnsupportedAccount(String app) {
    return 'Заметки в этом аккаунте $app зашифрованы или пока не поддерживаются';
  }

  @override
  String backupImportKindJournal(String app) {
    return 'Экспорт $app';
  }

  @override
  String backupImportMissingMedia(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Будут пропущены $count медиафайла: их нет в экспорте',
      many: 'Будут пропущены $count медиафайлов: их нет в экспорте',
      few: 'Будут пропущены $count медиафайла: их нет в экспорте',
      one: 'Будет пропущен $count медиафайл: его нет в экспорте',
    );
    return '$_temp0';
  }

  @override
  String backupImportSkippedEncrypted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Не удаётся прочитать $count зашифрованные или заблокированные заметки — они будут пропущены',
      many:
          'Не удаётся прочитать $count зашифрованных или заблокированных заметок — они будут пропущены',
      few:
          'Не удаётся прочитать $count зашифрованные или заблокированные заметки — они будут пропущены',
      one:
          'Не удаётся прочитать $count зашифрованную или заблокированную заметку — она будет пропущена',
    );
    return '$_temp0';
  }

  @override
  String backupImportSkippedUnsupported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Будут пропущены $count особые заметки (рукописные, интеллект-карты и т. п.)',
      many:
          'Будут пропущены $count особых заметок (рукописные, интеллект-карты и т. п.)',
      few:
          'Будут пропущены $count особые заметки (рукописные, интеллект-карты и т. п.)',
      one:
          'Будет пропущена $count особая заметка (рукописная, интеллект-карта и т. п.)',
    );
    return '$_temp0';
  }

  @override
  String backupImportSkippedUnreadable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Будут пропущены $count заметки в нераспознанном формате',
      many: 'Будут пропущены $count заметок в нераспознанном формате',
      few: 'Будут пропущены $count заметки в нераспознанном формате',
      one: 'Будет пропущена $count заметка в нераспознанном формате',
    );
    return '$_temp0';
  }

  @override
  String backupImportSummaryOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Не удалось прочитать текст $count заметки — будет импортировано только краткое содержание',
      many:
          'Не удалось прочитать текст $count заметок — будет импортировано только краткое содержание',
      few:
          'Не удалось прочитать текст $count заметок — будет импортировано только краткое содержание',
      one:
          'Не удалось прочитать текст $count заметки — будет импортировано только краткое содержание',
    );
    return '$_temp0';
  }

  @override
  String backupImportPartialContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count заметки содержат фрагменты, которые нельзя расшифровать или показать; читаемый текст и исходные данные будут сохранены',
      many:
          '$count заметок содержат фрагменты, которые нельзя расшифровать или показать; читаемый текст и исходные данные будут сохранены',
      few:
          '$count заметки содержат фрагменты, которые нельзя расшифровать или показать; читаемый текст и исходные данные будут сохранены',
      one:
          '$count заметка содержит фрагменты, которые нельзя расшифровать или показать; читаемый текст и исходные данные будут сохранены',
    );
    return '$_temp0';
  }

  @override
  String get calendarDisplayOptionsTooltip => 'Вид календаря';

  @override
  String get calendarOptionsTitle => 'Вид календаря';

  @override
  String get calendarOptionsReset => 'Сбросить';

  @override
  String get calendarOptionsCellStyle => 'Ячейки дней';

  @override
  String get calendarCellStyleDot => 'Точки';

  @override
  String get calendarCellStyleMood => 'Настроение';

  @override
  String get calendarCellStyleHeat => 'Тепловая карта';

  @override
  String get calendarCellStylePhoto => 'Фото';

  @override
  String get calendarCellStyleTags => 'Теги';

  @override
  String get calendarCellStyleDotDescription =>
      'По точке на каждую запись, не более трёх.';

  @override
  String get calendarCellStyleMoodDescription =>
      'Настроение, выбранное в этот день.';

  @override
  String get calendarCellStyleHeatDescription =>
      'Чем больше написано, тем темнее день.';

  @override
  String get calendarCellStylePhotoDescription =>
      'Обложка или первое фото записи заполняет ячейку дня.';

  @override
  String get calendarCellStyleTagsDescription =>
      'Цвета тегов, использованных в этот день (не более трёх).';

  @override
  String get calendarMoodAverage => 'Среднее';

  @override
  String get calendarMoodEach => 'Каждая запись';

  @override
  String get calendarHeatBasisEntries => 'По записям';

  @override
  String get calendarHeatBasisWords => 'По словам';

  @override
  String get calendarOptionsBadges => 'Значки';

  @override
  String get calendarBadgeCount => 'Число записей';

  @override
  String get calendarBadgeCapsule => 'Запечатанные капсулы времени';

  @override
  String get calendarBadgeWeather => 'Погода';

  @override
  String get calendarOptionsLayout => 'Макет';

  @override
  String get calendarOptionsWeekStart => 'Начало недели';

  @override
  String get calendarWeekStartLocale => 'По языку';

  @override
  String get calendarWeekStartMonday => 'Понедельник';

  @override
  String get calendarWeekStartSunday => 'Воскресенье';

  @override
  String get calendarOptionsDefaultFormat => 'Вид при открытии';

  @override
  String get calendarFormatMonth => 'Месяц';

  @override
  String get calendarFormatWeek => 'Неделя';

  @override
  String get calendarFormatRemember => 'Последний';

  @override
  String get calendarHighlightWeekends => 'Выделять выходные';

  @override
  String get calendarShowWeekNumbers => 'Номера недель';

  @override
  String get calendarFixedSixWeeks => 'Всегда 6 недель';

  @override
  String get calendarFixedSixWeeksDescription =>
      'Высота календаря не меняется при смене месяца.';

  @override
  String get calendarOptionsSections => 'Разделы';

  @override
  String get calendarShowMonthSummary => 'Итоги месяца';

  @override
  String get calendarShowMonthSummaryDescription =>
      'Записи, дни с записями, слова, самое частое настроение и самая длинная серия за месяц.';

  @override
  String calendarSummaryEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи',
      many: '$count записей',
      few: '$count записи',
      one: '$count запись',
    );
    return '$_temp0';
  }

  @override
  String calendarSummaryDays(int recorded, int elapsed) {
    return 'Дней с записями: $recorded из $elapsed';
  }

  @override
  String calendarSummaryDaysNoTotal(int count) {
    return 'Дней с записями: $count';
  }

  @override
  String calendarSummaryWords(String count) {
    return 'Слова: $count';
  }

  @override
  String calendarSummaryMood(String mood) {
    return 'Самое частое настроение: $mood';
  }

  @override
  String calendarSummaryStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Самая длинная серия: $count дня',
      many: 'Самая длинная серия: $count дней',
      few: 'Самая длинная серия: $count дня',
      one: 'Самая длинная серия: $count день',
    );
    return '$_temp0';
  }

  @override
  String get calendarSummaryEmpty => 'В этом месяце пока нет записей';

  @override
  String get calendarSummaryFuture => 'Этот месяц ещё не начался';

  @override
  String get calendarRelativeToday => 'Сегодня';

  @override
  String get calendarRelativeYesterday => 'Вчера';

  @override
  String get calendarRelativeTomorrow => 'Завтра';

  @override
  String calendarRelativeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня назад',
      many: '$count дней назад',
      few: '$count дня назад',
      one: '$count день назад',
    );
    return '$_temp0';
  }

  @override
  String calendarRelativeDaysLater(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'через $count дня',
      many: 'через $count дней',
      few: 'через $count дня',
      one: 'через $count день',
    );
    return '$_temp0';
  }

  @override
  String calendarDayStats(int entries, String words) {
    String _temp0 = intl.Intl.pluralLogic(
      entries,
      locale: localeName,
      other: '$entries записи',
      many: '$entries записей',
      few: '$entries записи',
      one: '$entries запись',
    );
    return '$_temp0 · слов: $words';
  }

  @override
  String get calendarYearViewTooltip => 'Показать весь год';

  @override
  String get calendarYearBasisMood => 'Настроение';

  @override
  String get calendarYearBasisEntries => 'Записи';

  @override
  String get calendarYearBasisWords => 'Слова';

  @override
  String get calendarYearLegendLess => 'Меньше';

  @override
  String get calendarYearLegendMore => 'Больше';

  @override
  String get calendarYearLegendNoMood => 'Без настроения';

  @override
  String get calendarYearExport => 'Поделиться годом';

  @override
  String get calendarYearExportFailed =>
      'Не удалось создать изображение. Повторите попытку.';

  @override
  String get calendarOnThisDayTitle => 'В этот день';

  @override
  String calendarOnThisDayYearsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count года назад',
      many: '$count лет назад',
      few: '$count года назад',
      one: '$count год назад',
    );
    return '$_temp0';
  }

  @override
  String calendarOnThisDayYearsLater(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count года спустя',
      many: '$count лет спустя',
      few: '$count года спустя',
      one: '$count год спустя',
    );
    return '$_temp0';
  }

  @override
  String get calendarDayActionView => 'Показать этот день';

  @override
  String get calendarDayActionWrite => 'Написать запись за этот день';

  @override
  String get calendarDayActionCapsule => 'Написать капсулу времени';

  @override
  String get calendarDayActionCapsuleDescription =>
      'Её можно будет открыть только в этот день';

  @override
  String get calendarFutureCapsuleAction =>
      'Написать капсулу времени на этот день';

  @override
  String get calendarOptionsDayContent => 'Записи дня';

  @override
  String get calendarDayContentTimeline => 'Хронология';

  @override
  String get calendarDayContentCards => 'Карточки';

  @override
  String get calendarShowOnThisDay => 'В этот день';

  @override
  String get calendarShowOnThisDayDescription =>
      'Записи за ту же дату в другие годы.';

  @override
  String get calendarPreviousYear => 'Предыдущий год';

  @override
  String get calendarNextYear => 'Следующий год';

  @override
  String get calendarOptionsLunar => 'Лунный календарь';

  @override
  String get calendarOptionsLunarDescription =>
      'Показывает под каждой датой день китайского лунного календаря, сезоны и традиционные праздники.';

  @override
  String get calendarLunarLocale => 'По языку';

  @override
  String get calendarLunarAlways => 'Показывать';

  @override
  String get calendarLunarNever => 'Скрывать';

  @override
  String calendarLunarDate(String date) {
    return 'По лунному календарю: $date';
  }

  @override
  String get calendarSummaryEmptyYear => 'В этом году пока нет записей';

  @override
  String get calendarSummaryFutureYear => 'Этот год ещё не начался';

  @override
  String get calendarSummaryEmptyRange => 'За этот период нет записей';

  @override
  String get calendarSummaryFutureRange => 'Этот период ещё не начался';

  @override
  String get calendarDayActionRange => 'Выбрать период отсюда';

  @override
  String get calendarDayActionRangeDescription =>
      'Нажмите на другую дату, чтобы увидеть статистику за период';

  @override
  String calendarRangeTitle(String start, String end, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days дня',
      many: '$days дней',
      few: '$days дня',
      one: '$days день',
    );
    return '$start – $end · $_temp0';
  }

  @override
  String calendarRangePickEnd(String start) {
    return 'С $start · выберите конечную дату';
  }

  @override
  String get calendarRangeExit => 'Выйти из выбора периода';

  @override
  String get calendarFilterTooltip => 'Фильтр';

  @override
  String get calendarFilterTitle => 'Фильтр календаря';

  @override
  String get calendarFilterNotebooks => 'Блокноты';

  @override
  String get calendarFilterClear => 'Сбросить фильтр';

  @override
  String get calendarFilterDescription =>
      'Даты и статистика учитывают только подходящие записи. Внутри группы достаточно совпадения с любым вариантом; если заданы несколько групп, запись должна подходить под все.';

  @override
  String get calendarFilterMoods => 'Настроение';

  @override
  String get calendarFilterTags => 'Теги';

  @override
  String get calendarFilterNoTags => 'Тегов пока нет';

  @override
  String get calendarFilterActive => 'Фильтр применён';

  @override
  String get calendarOptionsAlmanac => 'Лунный календарь и праздники';

  @override
  String get calendarOptionsHolidays => 'Праздники Китая';

  @override
  String calendarOptionsHolidaysDescription(int year) {
    return 'Отмечает рядом с датой выходные и рабочие дни по переносу в материковом Китае; выделение выходных учитывает их. Данные есть до $year года включительно.';
  }

  @override
  String get calendarOptionsHolidaysDescriptionOutdated =>
      'Отмечает рядом с датой выходные и рабочие дни по переносу в материковом Китае; выделение выходных учитывает их. В этой версии ещё нет графика праздников на текущий год.';

  @override
  String get calendarHolidayRestMark => 'Вых';

  @override
  String get calendarHolidayWorkMark => 'Раб';

  @override
  String get calendarHolidayDayOff => 'Выходной';

  @override
  String get calendarHolidayMakeUpWorkday => 'Рабочий день по переносу';

  @override
  String backupImportAnniversaryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count памятные даты',
      many: '$count памятных дат',
      few: '$count памятные даты',
      one: '$count памятная дата',
    );
    return '$_temp0';
  }

  @override
  String backupImportExistingAnniversaryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count памятные даты уже есть на этом устройстве',
      many: '$count памятных дат уже есть на этом устройстве',
      few: '$count памятные даты уже есть на этом устройстве',
      one: '$count памятная дата уже есть на этом устройстве',
    );
    return '$_temp0';
  }

  @override
  String backupImportModeOverwriteAnniversariesOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Добавляет новые элементы и заменяет $count существующие памятные даты версиями из файла',
      many:
          'Добавляет новые элементы и заменяет $count существующих памятных дат версиями из файла',
      few:
          'Добавляет новые элементы и заменяет $count существующие памятные даты версиями из файла',
      one:
          'Добавляет новые элементы и заменяет $count существующую памятную дату версией из файла',
    );
    return '$_temp0';
  }

  @override
  String backupImportModeOverwriteAnniversariesExtra(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Также заменяет $count существующие памятные даты',
      many: 'Также заменяет $count существующих памятных дат',
      few: 'Также заменяет $count существующие памятные даты',
      one: 'Также заменяет $count существующую памятную дату',
    );
    return '$_temp0';
  }

  @override
  String backupOverwriteAllAnniversaries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count памятные даты',
      many: '$count памятных дат',
      few: '$count памятные даты',
      one: '$count памятная дата',
    );
    return '$_temp0';
  }

  @override
  String backupOverwriteExistingAnniversariesBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count памятные даты, которые уже есть на этом устройстве, будут заменены версиями из файла; изменения на этом устройстве будут безвозвратно утеряны.',
      many:
          '$count памятных дат, которые уже есть на этом устройстве, будут заменены версиями из файла; изменения на этом устройстве будут безвозвратно утеряны.',
      few:
          '$count памятные даты, которые уже есть на этом устройстве, будут заменены версиями из файла; изменения на этом устройстве будут безвозвратно утеряны.',
      one:
          '$count памятная дата, которая уже есть на этом устройстве, будет заменена версией из файла; изменения на этом устройстве будут безвозвратно утеряны.',
    );
    return '$_temp0';
  }

  @override
  String backupImportAnniversaryMergeResult(int added) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: 'Памятные даты — добавлено: $added',
      many: 'Памятные даты — добавлено: $added',
      few: 'Памятные даты — добавлено: $added',
      one: 'Памятные даты — добавлено: $added',
      zero: 'Памятные даты: новых нет',
    );
    return '$_temp0';
  }

  @override
  String backupImportAnniversaryMergeSkippedResult(int added, int skipped) {
    return 'Памятные даты — добавлено: $added, пропущено: $skipped (уже есть на этом устройстве)';
  }

  @override
  String backupImportAnniversaryOverwriteResult(int added, int replaced) {
    return 'Памятные даты — добавлено: $added, заменено: $replaced';
  }

  @override
  String get calendarShowAnniversaries => 'Памятные даты';

  @override
  String get calendarShowAnniversariesDescription =>
      'Отмечает памятные даты в календаре и показывает их карточки для выбранного дня.';

  @override
  String get calendarDayActionAnniversary => 'Добавить памятную дату';

  @override
  String get calendarDayActionAnniversaryDescription =>
      'Запомните этот день — календарь будет отмечать его каждый год';

  @override
  String get calendarDayActionCountdownDescription =>
      'Обратный отсчёт до этого дня';

  @override
  String get anniversarySectionTitle => 'Памятные даты';

  @override
  String anniversaryOrdinal(int count) {
    return '$count-я годовщина';
  }

  @override
  String anniversaryTodayOrdinal(int count) {
    return 'Сегодня $count-я годовщина';
  }

  @override
  String anniversaryDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Осталось $count дня',
      many: 'Осталось $count дней',
      few: 'Осталось $count дня',
      one: 'Остался $count день',
    );
    return '$_temp0';
  }

  @override
  String anniversaryDaysSince(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Прошло $count дня',
      many: 'Прошло $count дней',
      few: 'Прошло $count дня',
      one: 'Прошёл $count день',
    );
    return '$_temp0';
  }

  @override
  String get anniversaryBaseDay => 'День, когда всё началось';

  @override
  String get anniversaryCountdownLabel => 'Обратный отсчёт';

  @override
  String get anniversaryIsToday => 'Это сегодня';

  @override
  String get anniversaryAdjustedNote =>
      'В этом году такой даты нет, поэтому она перенесена на ближайший день';

  @override
  String get anniversaryNewTitle => 'Новая памятная дата';

  @override
  String get anniversaryEditTitle => 'Изменить памятную дату';

  @override
  String get anniversaryFieldName => 'Название';

  @override
  String get anniversaryNameHint =>
      'Например: Мы вместе, день рождения мамы, экзамен';

  @override
  String get anniversaryNameRequired => 'Введите название';

  @override
  String get anniversaryFieldDate => 'Дата';

  @override
  String get anniversaryFieldRepeat => 'Повтор';

  @override
  String get anniversaryRepeatSolar => 'Ежегодно';

  @override
  String get anniversaryRepeatLunar => 'По лунному';

  @override
  String get anniversaryRepeatOnce => 'Один раз';

  @override
  String anniversaryRepeatSolarDescription(String date) {
    return 'Отмечается каждый год $date';
  }

  @override
  String get anniversaryRepeatLeapDayDescription =>
      'Каждый год 29 февраля, в невисокосные годы — 28 февраля';

  @override
  String anniversaryRepeatLunarDescription(String date) {
    return 'Каждый год $date по лунному календарю, с пересчётом на дату текущего года';
  }

  @override
  String get anniversaryRepeatOnceDescription =>
      'Только этот день: до него — обратный отсчёт, после — сколько дней прошло';

  @override
  String anniversaryLunarYearDate(String year, String date) {
    return 'По лунному календарю: год $year, $date';
  }

  @override
  String get anniversaryFieldNote => 'Заметка';

  @override
  String get anniversaryNoteHint => 'Необязательно';

  @override
  String get anniversaryPin => 'Закрепить';

  @override
  String get anniversaryPinDescription =>
      'Показывать вверху списка памятных дат';

  @override
  String get anniversaryDelete => 'Удалить памятную дату';

  @override
  String get anniversaryDeleteConfirmTitle => 'Удалить эту памятную дату?';

  @override
  String anniversaryDeleteConfirmBody(String title) {
    return 'Памятная дата «$title» будет удалена из календаря. Связанные записи не затрагиваются.';
  }

  @override
  String get anniversaryDeleted => 'Памятная дата удалена';

  @override
  String get anniversaryCreated => 'Памятная дата добавлена';

  @override
  String get anniversarySaveFailed =>
      'Не удалось сохранить. Повторите попытку.';

  @override
  String get anniversaryListTitle => 'Памятные даты';

  @override
  String get anniversaryEmpty =>
      'Памятных дат пока нет. Нажмите и удерживайте день в календаре или нажмите «+», чтобы добавить.';

  @override
  String get anniversaryPinnedBadge => 'Закреплено';

  @override
  String anniversaryDaysToGo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'дня осталось',
      many: 'дней осталось',
      few: 'дня осталось',
      one: 'день остался',
    );
    return '$_temp0';
  }

  @override
  String anniversaryDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'дня назад',
      many: 'дней назад',
      few: 'дня назад',
      one: 'день назад',
    );
    return '$_temp0';
  }

  @override
  String get anniversaryDetailNext => 'Следующая';

  @override
  String get anniversaryDetailStart => 'Начало';

  @override
  String get anniversaryMoreActions => 'Другие действия';

  @override
  String get anniversaryUnpin => 'Открепить';

  @override
  String get anniversaryFieldLink => 'Связанная запись';

  @override
  String get anniversaryLinkNone => 'Нет';

  @override
  String get anniversaryLinkPick => 'Связать с записью';

  @override
  String get anniversaryLinkMissing => 'Связанная запись удалена';

  @override
  String get anniversaryUnlink => 'Отвязать';

  @override
  String get anniversaryLinkedDiaryTitle => 'Связанная запись';

  @override
  String get anniversaryOpenLinkedDiary => 'Открыть связанную запись';

  @override
  String get anniversaryPickerHint =>
      'Записи в пределах 7 дней от выбранной даты';

  @override
  String get anniversaryPickerEmpty =>
      'В пределах недели от этой даты записей нет';

  @override
  String get anniversaryPastDiariesTitle => 'Этот день в разные годы';

  @override
  String get anniversaryBaseDayDiariesTitle => 'Записи этого дня';

  @override
  String get anniversaryPastDiariesEmpty => 'В эти дни записей пока нет';

  @override
  String get anniversaryView => 'Открыть';

  @override
  String get previewSetAsAnniversary => 'Сделать памятной датой';

  @override
  String get diaryTypographyTitle => 'Шрифт и оформление текста';

  @override
  String diaryTypographySummary(String font, String size, String lineHeight) {
    return '$font · Размер $size · Интервал $lineHeight';
  }

  @override
  String get diaryTypographyQuickTooltip => 'Шрифт и оформление';

  @override
  String get diaryTypographyFontSection => 'Шрифт';

  @override
  String get diaryTypographyFontBundled => 'HarmonyOS Sans';

  @override
  String get diaryTypographyFontSystem => 'Системный шрифт';

  @override
  String get diaryTypographyFontSystemHint =>
      'Шрифт, который используется на устройстве';

  @override
  String get diaryTypographyFontMissing =>
      'Файл выбранного шрифта больше не найден на этом устройстве, поэтому пока используется HarmonyOS Sans. Импортируйте его снова или выберите другой шрифт.';

  @override
  String get diaryTypographyImportFont => 'Импортировать файл шрифта';

  @override
  String get diaryTypographyImportFontHint =>
      'TTF, OTF или TTC; после импорта он станет шрифтом текста';

  @override
  String get diaryTypographyApplyToApp => 'Для всего приложения';

  @override
  String get diaryTypographyApplyToAppHint =>
      'Если выключено, шрифт используется только для заголовков, текста и карточек записей';

  @override
  String get diaryTypographyImporting => 'Импорт шрифта…';

  @override
  String diaryTypographyImported(String name) {
    return 'Шрифт «$name» импортирован и применён';
  }

  @override
  String get diaryTypographyImportUnsupported =>
      'Это неподходящий файл шрифта. Выберите файл TTF, OTF или TTC.';

  @override
  String get diaryTypographyImportUnreadable =>
      'Не удалось прочитать выбранный файл';

  @override
  String get diaryTypographyImportFailed =>
      'Не удалось импортировать шрифт. Проверьте свободное место и повторите попытку.';

  @override
  String get diaryTypographyDeleteFont => 'Удалить шрифт';

  @override
  String diaryTypographyDeleteFontTitle(String name) {
    return 'Удалить шрифт «$name»?';
  }

  @override
  String get diaryTypographyDeleteFontMessage =>
      'Файл шрифта будет удалён с этого устройства. Если шрифт используется, текст записей вернётся к HarmonyOS Sans.';

  @override
  String get diaryTypographyLayoutSection => 'Оформление';

  @override
  String get diaryTypographyFontSize => 'Размер шрифта';

  @override
  String get diaryTypographyLineHeight => 'Межстрочный интервал';

  @override
  String get diaryTypographyLetterSpacing => 'Межбуквенный интервал';

  @override
  String get diaryTypographyParagraphSpacing => 'Интервал между абзацами';

  @override
  String get diaryTypographyFirstLineIndent => 'Отступ первой строки';

  @override
  String diaryTypographyFirstLineIndentValue(num count, String value) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$value символа',
      many: '$value символов',
      few: '$value символа',
      one: '$value символ',
    );
    return '$_temp0';
  }

  @override
  String get diaryTypographyFirstLineIndentOff => 'Нет';

  @override
  String diaryTypographyDecrease(String label) {
    return '$label: уменьшить';
  }

  @override
  String diaryTypographyIncrease(String label) {
    return '$label: увеличить';
  }

  @override
  String get diaryTypographyReset => 'Сбросить оформление';

  @override
  String get diaryTypographyScopeHint =>
      'Размер, интервалы и отступы применяются при написании, чтении и публикации записей.';

  @override
  String get diaryTypographyMoreSettings => 'Другие настройки';

  @override
  String get diaryTypographySampleTitle => 'Вечер после дождя';

  @override
  String get diaryTypographySampleBody =>
      'Под вечер дождь утих, и османтус у дома пах сильнее, чем когда-либо.\nПо дороге домой — кулёк жареных каштанов: чищу их на ходу, и ладоням всё время тепло.\nНичего особенного сегодня не случилось, но каждая минута была спокойной, и захотелось это записать.';

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
    return 'Изменено $time';
  }

  @override
  String diaryCardFooterCreated(String time) {
    return 'Написано $time';
  }

  @override
  String diaryCardWordCount(String count) {
    return 'Слов: $count';
  }

  @override
  String diaryCardMediaImages(int count) {
    return 'Фото: $count';
  }

  @override
  String get diaryCardMediaAudio => 'Есть аудиозапись';

  @override
  String get diaryCardMediaVideo => 'Есть видео';

  @override
  String get diaryCardMediaAttachment => 'Есть вложение';

  @override
  String diaryCardLocation(String location) {
    return 'Место: $location';
  }

  @override
  String get diaryCardStyleTitle => 'Стиль карточек записей';

  @override
  String diaryCardStyleEntrySubtitle(String name) {
    return 'Текущий: $name';
  }

  @override
  String get styleEditorCustom => 'Пользовательский';

  @override
  String get styleEditorResetDone => 'Восстановлен стиль по умолчанию';

  @override
  String get styleEditorPreviewLight => 'Просмотр в светлой теме';

  @override
  String get styleEditorPreviewDark => 'Просмотр в тёмной теме';

  @override
  String get styleEditorPanelHandle => 'Панель параметров';

  @override
  String get styleEditorPanelCollapsed => 'Свёрнута';

  @override
  String get styleEditorPanelHalf => 'Развёрнута наполовину';

  @override
  String get styleEditorPanelExpanded => 'Развёрнута';

  @override
  String get diaryCardStyleSharedGroup => 'Все макеты';

  @override
  String get diaryCardStyleListGroup => 'Только для списка';

  @override
  String get diaryCardStyleWaterfallGroup => 'Только для плитки';

  @override
  String get diaryCardStyleModeFootnote =>
      'Переключите список или плитку над предпросмотром, чтобы настроить другой макет';

  @override
  String get diaryCardStyleTabPresets => 'Пресеты';

  @override
  String get diaryCardStyleTabLayout => 'Макет';

  @override
  String get diaryCardStyleTabCover => 'Обложка';

  @override
  String get diaryCardStyleTabContent => 'Содержимое';

  @override
  String get diaryCardStyleTabDate => 'Дата';

  @override
  String get diaryCardStyleTabOrder => 'Порядок';

  @override
  String get diaryCardStyleTabText => 'Текст';

  @override
  String get diaryCardStyleTabColor => 'Цвет';

  @override
  String get diaryCardStyleTabTexture => 'Фактура';

  @override
  String get styleEditorPresetsTitle => 'Встроенные стили';

  @override
  String get diaryCardStylePresetClassic => 'Классика';

  @override
  String get diaryCardStylePresetClassicDesc =>
      'По умолчанию: квадратная обложка слева и отрывок в две строки';

  @override
  String get diaryCardStylePresetCompact => 'Компакт';

  @override
  String get diaryCardStylePresetCompactDesc =>
      'Маленькие обложки и отрывок в одну строку — больше записей на экране';

  @override
  String get diaryCardStylePresetMagazine => 'Журнал';

  @override
  String get diaryCardStylePresetMagazineDesc =>
      'Фото во всю ширину, крупные заголовки и просторные строки';

  @override
  String get diaryCardStylePresetMinimal => 'Минимализм';

  @override
  String get diaryCardStylePresetMinimalDesc =>
      'Только текст: без обложек, рамок и теней';

  @override
  String get diaryCardStylePresetGallery => 'Галерея';

  @override
  String get diaryCardStylePresetGalleryDesc =>
      'Сначала фото: коллажи и обложка на фоне';

  @override
  String get diaryCardStylePresetSticky => 'Стикер';

  @override
  String get diaryCardStylePresetStickyDesc =>
      'Тёплая бумага, цветная полоса сверху и небольшие скругления';

  @override
  String get diaryCardStylePresetJournal => 'Ежедневник';

  @override
  String get diaryCardStylePresetJournalDesc =>
      'Цветная полоса сбоку, а без обложки — блок с датой';

  @override
  String get diaryCardStylePresetMood => 'Цвета настроения';

  @override
  String get diaryCardStylePresetMoodDesc =>
      'Цвета карточки зависят от настроения записи';

  @override
  String get diaryCardStylePresetGlass => 'Стекло';

  @override
  String get diaryCardStylePresetGlassDesc =>
      'Полупрозрачные матовые карточки поверх фона страницы';

  @override
  String get diaryCardStyleMaterial => 'Материал';

  @override
  String get diaryCardStyleMaterialSolid => 'Непрозрачный';

  @override
  String get diaryCardStyleMaterialGlass => 'Стекло';

  @override
  String get diaryCardStyleBlur => 'Размытие';

  @override
  String get diaryCardStyleBlurSubtitle =>
      'Размытие видно только на страницах с фоновым изображением';

  @override
  String styleEditorApplied(String name) {
    return 'Применён стиль «$name»';
  }

  @override
  String get styleEditorSavedTitle => 'Мои стили';

  @override
  String get styleEditorSavedEmpty =>
      'Сохраните понравившийся стиль, чтобы возвращаться к нему одним касанием';

  @override
  String get styleEditorSaveCurrent => 'Сохранить текущий стиль';

  @override
  String styleEditorSaveLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Можно сохранить не более $count стиля',
      many: 'Можно сохранить не более $count стилей',
      few: 'Можно сохранить не более $count стилей',
      one: 'Можно сохранить не более $count стиля',
    );
    return '$_temp0';
  }

  @override
  String get styleEditorSaveDialogTitle => 'Сохранение стиля';

  @override
  String get styleEditorRenameDialogTitle => 'Переименовать стиль';

  @override
  String get styleEditorNameLabel => 'Название стиля';

  @override
  String styleEditorDefaultName(int count) {
    return 'Мой стиль $count';
  }

  @override
  String get styleEditorRename => 'Переименовать';

  @override
  String styleEditorSavedDone(String name) {
    return 'Стиль «$name» сохранён';
  }

  @override
  String styleEditorDeletedDone(String name) {
    return 'Стиль «$name» удалён';
  }

  @override
  String styleEditorSavedActions(String name) {
    return 'Другие действия для «$name»';
  }

  @override
  String get styleEditorShareTitle => 'Обмен и импорт';

  @override
  String get styleEditorCopyCode => 'Скопировать код стиля';

  @override
  String get styleEditorCopyCodeSubtitle =>
      'Отправьте другу или сохраните как резервную копию этого стиля';

  @override
  String get styleEditorImportCode => 'Импортировать из буфера обмена';

  @override
  String get styleEditorImportCodeSubtitle =>
      'Применить код стиля, которым с вами поделились';

  @override
  String get styleEditorCodeCopied => 'Код стиля скопирован';

  @override
  String get styleEditorImportEmpty => 'Буфер обмена пуст';

  @override
  String get styleEditorImportInvalid =>
      'В буфере обмена нет подходящего кода стиля';

  @override
  String get styleEditorImportNewer =>
      'Импортировано. Некоторые настройки из более новой версии могут не примениться';

  @override
  String get styleEditorImported => 'Стиль импортирован';

  @override
  String styleEditorImportedNamed(String name) {
    return 'Стиль «$name» импортирован';
  }

  @override
  String get diaryCardStyleCornerRadius => 'Скругление карточек';

  @override
  String get diaryCardStyleTextAlign => 'Выравнивание текста';

  @override
  String get diaryCardStyleAlignStart => 'По левому краю';

  @override
  String get diaryCardStyleAlignCenter => 'По центру';

  @override
  String get diaryCardStylePaddingH => 'Боковые отступы';

  @override
  String get diaryCardStylePaddingV => 'Отступы сверху и снизу';

  @override
  String get diaryCardStyleElementGap => 'Интервал между элементами';

  @override
  String get diaryCardStyleCardGap => 'Интервал между карточками';

  @override
  String get diaryCardStyleSideMargin => 'Отступ от краёв экрана';

  @override
  String get diaryCardStyleColumns => 'Столбцы';

  @override
  String diaryCardStyleColumnsValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count столбца',
      many: '$count столбцов',
      few: '$count столбца',
      one: '$count столбец',
    );
    return '$_temp0';
  }

  @override
  String get diaryCardStyleColumnsFootnote =>
      'На узких экранах и при крупном шрифте столбцов становится меньше';

  @override
  String get diaryCardStyleCoverPosition => 'Положение обложки';

  @override
  String get diaryCardStyleCoverStart => 'Слева';

  @override
  String get diaryCardStyleCoverEnd => 'Справа';

  @override
  String get diaryCardStyleCoverTop => 'Сверху';

  @override
  String get diaryCardStyleCoverBackground => 'Фон';

  @override
  String get diaryCardStyleCoverHidden => 'Скрыта';

  @override
  String get diaryCardStyleCoverSize => 'Размер обложки';

  @override
  String get diaryCardStyleCoverSizeFootnote =>
      'На узких экранах обложка уменьшается, чтобы освободить место для текста';

  @override
  String get diaryCardStyleCoverShape => 'Форма обложки';

  @override
  String get diaryCardStyleShapeSquare => 'Квадратная';

  @override
  String get diaryCardStyleShapeLandscape => 'Альбомная';

  @override
  String get diaryCardStyleShapePortrait => 'Портретная';

  @override
  String get diaryCardStyleShapeCircle => 'Круглая';

  @override
  String get diaryCardStyleCoverRadius => 'Скругление обложки';

  @override
  String get diaryCardStyleCoverHeight => 'Высота обложки';

  @override
  String get diaryCardStyleCoverInset => 'Обложка с отступами';

  @override
  String get diaryCardStyleCoverInsetSubtitle =>
      'С полями и скруглёнными углами, а не от края до края';

  @override
  String get diaryCardStyleCoverDivider => 'Разделитель под обложкой';

  @override
  String get diaryCardStyleCoverGap => 'Отступ между обложкой и текстом';

  @override
  String get diaryCardStyleScrim => 'Плотность подложки текста';

  @override
  String get diaryCardStyleCollage => 'Коллаж из фото';

  @override
  String get diaryCardStyleCollageSubtitle =>
      'Верхняя обложка собирает до трёх фото из записи';

  @override
  String get diaryCardStyleCoverFallback => 'Если нет обложки';

  @override
  String get diaryCardStyleFallbackNone => 'Ничего';

  @override
  String get diaryCardStyleFallbackDate => 'Блок с датой';

  @override
  String get diaryCardStyleFallbackMood => 'Плитка настроения';

  @override
  String get diaryCardStyleShowTitle => 'Показывать заголовок';

  @override
  String get diaryCardStyleShowUntitled =>
      'Без заголовка показывать первую строку текста';

  @override
  String get diaryCardStyleShowUntitledSubtitle =>
      'Если выключено, строка заголовка пропускается';

  @override
  String get diaryCardStyleShowPreview => 'Показывать отрывок';

  @override
  String get diaryCardStyleTitleLines => 'Строк в заголовке';

  @override
  String get diaryCardStylePreviewLines => 'Строк в отрывке';

  @override
  String diaryCardStyleLinesValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count строки',
      many: '$count строк',
      few: '$count строки',
      one: '$count строка',
    );
    return '$_temp0';
  }

  @override
  String get diaryCardStyleTagStyle => 'Стиль тегов';

  @override
  String get diaryCardStyleTagChip => 'Плашки';

  @override
  String get diaryCardStyleTagPlain => 'Текст';

  @override
  String get diaryCardStyleTagDot => 'Точки';

  @override
  String get diaryCardStylePinnedBadge => 'Значок закрепления';

  @override
  String get diaryCardStylePinnedStandard => 'Значок и подпись';

  @override
  String get diaryCardStylePinnedIcon => 'Только значок';

  @override
  String get diaryCardStylePinnedHidden => 'Не показывать';

  @override
  String get diaryCardStylePinnedTint => 'Выделять закреплённые цветом';

  @override
  String get diaryCardStylePinnedTintSubtitle =>
      'Лёгкая заливка и обводка в цвете темы';

  @override
  String get diaryCardStyleShowMood => 'Показывать настроение';

  @override
  String get diaryCardStyleShowWeather => 'Показывать погоду';

  @override
  String get diaryCardStyleIndicatorStyle => 'Настроение и погода';

  @override
  String get diaryCardStyleIndicatorStamp => 'Штамп';

  @override
  String get diaryCardStyleIndicatorPlain => 'Только значки';

  @override
  String get diaryCardStyleMetaPosition => 'Где показывать настроение и погоду';

  @override
  String get diaryCardStyleMetaEyebrow => 'В строке даты';

  @override
  String get diaryCardStyleMetaFooter => 'Внизу';

  @override
  String get diaryCardStyleMetaCover => 'На обложке';

  @override
  String get diaryCardStyleExtras => 'Сведения внизу карточки';

  @override
  String get diaryCardStyleShowLocation => 'Место';

  @override
  String get diaryCardStyleShowEnergy => 'Энергия';

  @override
  String get diaryCardStyleShowWordCount => 'Количество слов';

  @override
  String get diaryCardStyleShowMedia => 'Значки фото и вложений';

  @override
  String get diaryCardStyleShowDate => 'Показывать дату';

  @override
  String get diaryCardStyleDateFormat => 'Формат даты';

  @override
  String get diaryCardStyleDateEyebrow => 'День и месяц';

  @override
  String get diaryCardStyleDateFull => 'Полная дата';

  @override
  String get diaryCardStyleDateNumeric => 'Цифрами';

  @override
  String get diaryCardStyleDateRelative => 'Относительная';

  @override
  String get diaryCardStyleShowWeekday => 'Показывать день недели';

  @override
  String get diaryCardStyleShowTime => 'Показывать время';

  @override
  String get diaryCardStyleRelativeNote =>
      'Относительная дата показывается без дня недели и времени';

  @override
  String get diaryCardStyleDateSource => 'Какую дату показывать';

  @override
  String get diaryCardStyleDateCreated => 'Когда написана';

  @override
  String get diaryCardStyleDateUpdated => 'Последнее изменение';

  @override
  String get diaryCardStyleFooterTime => 'Время внизу карточки';

  @override
  String get diaryCardStyleFooterRelative => 'Обновлено … назад';

  @override
  String get diaryCardStyleFooterUpdated => 'Время обновления';

  @override
  String get diaryCardStyleFooterCreated => 'Время написания';

  @override
  String get diaryCardStyleFooterHidden => 'Не показывать';

  @override
  String get diaryCardStyleOrderHint =>
      'Перетаскивайте маркеры справа, чтобы изменить порядок частей карточки';

  @override
  String get diaryCardStyleBlockEyebrow => 'Строка даты';

  @override
  String get diaryCardStyleBlockTitle => 'Заголовок';

  @override
  String get diaryCardStyleBlockTags => 'Теги';

  @override
  String get diaryCardStyleBlockPreview => 'Отрывок';

  @override
  String get diaryCardStyleBlockFooter => 'Нижняя строка';

  @override
  String get diaryCardStyleOrderReset => 'Вернуть исходный порядок';

  @override
  String diaryCardStyleDragHandle(String name) {
    return 'Перетащите, чтобы переместить «$name»';
  }

  @override
  String get diaryCardStyleTitleSize => 'Размер заголовка';

  @override
  String get diaryCardStyleTitleWeight => 'Насыщенность заголовка';

  @override
  String get diaryCardStyleWeightRegular => 'Обычная';

  @override
  String get diaryCardStyleWeightMedium => 'Средняя';

  @override
  String get diaryCardStyleWeightBold => 'Жирная';

  @override
  String get diaryCardStylePreviewSize => 'Размер отрывка';

  @override
  String get diaryCardStyleLineHeight => 'Межстрочный интервал отрывка';

  @override
  String get diaryCardStyleLineCompact => 'Плотный';

  @override
  String get diaryCardStyleLineStandard => 'Стандартный';

  @override
  String get diaryCardStyleLineRelaxed => 'Свободный';

  @override
  String get diaryCardStyleMetaSize => 'Размер вспомогательного текста';

  @override
  String get diaryCardStyleTitleColor => 'Цвет заголовка';

  @override
  String get diaryCardStyleBodyColor => 'Цвет текста';

  @override
  String get diaryCardStyleEnsureContrast => 'Сохранять читаемость';

  @override
  String get diaryCardStyleEnsureContrastSubtitle =>
      'Если цвет текста сливается с карточкой, заменять его на более контрастный';

  @override
  String get diaryCardStyleBackground => 'Цвет карточки';

  @override
  String get diaryCardStyleOpacity => 'Непрозрачность карточки';

  @override
  String get diaryCardStyleGradient => 'Градиент';

  @override
  String get diaryCardStyleGradientSubtitle =>
      'Плавный переход от цвета карточки ко второму цвету';

  @override
  String get diaryCardStyleGradientEnd => 'Второй цвет градиента';

  @override
  String get diaryCardStyleGradientDirection => 'Направление градиента';

  @override
  String get diaryCardStyleDirectionVertical => 'Вертикально';

  @override
  String get diaryCardStyleDirectionHorizontal => 'Горизонтально';

  @override
  String get diaryCardStyleDirectionDiagonal => 'По диагонали';

  @override
  String get diaryCardStyleBorderWidth => 'Толщина обводки';

  @override
  String get diaryCardStyleBorderColor => 'Цвет обводки';

  @override
  String get diaryCardStyleAccentBar => 'Акцентная полоса';

  @override
  String get diaryCardStyleAccentNone => 'Нет';

  @override
  String get diaryCardStyleAccentStart => 'Сбоку';

  @override
  String get diaryCardStyleAccentTop => 'Сверху';

  @override
  String get diaryCardStyleAccentWidth => 'Ширина полосы';

  @override
  String get diaryCardStyleAccentColor => 'Цвет полосы';

  @override
  String get diaryCardStyleShadow => 'Тень';

  @override
  String get diaryCardStyleShadowThemed => 'По умолчанию';

  @override
  String get diaryCardStyleShadowNone => 'Нет';

  @override
  String get diaryCardStyleShadowSoft => 'Мягкая';

  @override
  String get diaryCardStyleShadowFloating => 'Парящая';

  @override
  String get diaryCardStyleShadowCustom => 'Своя';

  @override
  String get diaryCardStyleShadowElevation => 'Глубина тени';

  @override
  String get diaryCardStyleShadowColor => 'Цвет тени';

  @override
  String get diaryCardStyleSourceTheme => 'По умолчанию';

  @override
  String get diaryCardStyleSourcePrimary => 'Основной';

  @override
  String get diaryCardStyleSourceSecondary => 'Вторичный';

  @override
  String get diaryCardStyleSourceTertiary => 'Третичный';

  @override
  String get diaryCardStyleSourceMood => 'Настроение';

  @override
  String get diaryCardStyleSourceTag => 'Первый тег';

  @override
  String get diaryCardStyleSourceCustom => 'Свой';

  @override
  String get diaryCardStyleSourceMoodHint =>
      'Цвет берётся из настроения каждой записи (его можно изменить в разделе «Эмодзи настроения»); если настроения нет — цвет по умолчанию';

  @override
  String get diaryCardStyleSourceTagHint =>
      'Используется цвет первого тега каждой записи';

  @override
  String get diaryCardStyleStrength => 'Интенсивность';

  @override
  String get styleEditorEditColor => 'Изменить цвет';

  @override
  String get styleEditorColorDarkAuto =>
      'Подбирать цвет для тёмной темы автоматически';

  @override
  String get styleEditorColorDarkAutoSubtitle =>
      'Вывести из светлого цвета хорошо читаемый цвет для тёмной темы';

  @override
  String get styleEditorHexLabel => 'Цвет в HEX';

  @override
  String get styleEditorHexInvalid =>
      'Введите шестизначный HEX-код цвета, например FFB300';

  @override
  String get diaryCardStyleSheetSection => 'Стиль карточек';

  @override
  String get diaryCardStyleSampleTitle1 => 'Закат у моря';

  @override
  String get diaryCardStyleSampleBody1 =>
      'Долгая прогулка вдоль берега до самых сумерек. Волны накатывали одна за другой, а небо медленно перетекало из оранжевого в сиреневый.';

  @override
  String get diaryCardStyleSampleTitle2 => 'Поход на выходных';

  @override
  String get diaryCardStyleSampleBody2 =>
      'На вершине дул сильный ветер. Мы сделали кучу фото и даже записали шум ветра. На спуске уже дрожали ноги.';

  @override
  String get diaryCardStyleSampleTitle3 =>
      'Дождливый будний день: сижу в кафе и заново расписываю планы на эту неделю';

  @override
  String get diaryCardStyleSampleBody3 =>
      'Дела на неделю расставлены заново, пара идей записана. Сегодня — пораньше спать.';

  @override
  String get diaryCardStyleSampleBody4 =>
      'По дороге домой на ступеньках грелся на солнце рыжий кот. От одного взгляда на него становилось спокойнее.';

  @override
  String get diaryCardStyleSampleLead4 => 'Рыжий кот на ступеньках';

  @override
  String get diaryCardStyleSampleCapsuleTitle => 'Письмо себе через год';

  @override
  String get diaryCardStyleSampleTag1 => 'Путешествия';

  @override
  String get diaryCardStyleSampleTag2 => 'Жизнь';

  @override
  String get diaryCardStyleSampleTag3 => 'Чтение';

  @override
  String get diaryCardStyleSampleLocation => 'Набережная у моря';

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
      other: '$formatted слова',
      many: '$formatted слов',
      few: '$formatted слова',
      one: '$formatted слово',
    );
    return '$_temp0';
  }

  @override
  String diaryPreviewReadingTime(int minutes) {
    return '$minutes мин чтения';
  }

  @override
  String get diaryWordCountOpen => 'Показать статистику слов';

  @override
  String get diaryWordCountTitle => 'Количество слов';

  @override
  String diaryWordCountUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'слова',
      many: 'слов',
      few: 'слова',
      one: 'слово',
    );
    return '$_temp0';
  }

  @override
  String get diaryWordCountCjk => 'Иероглифы (CJK)';

  @override
  String get diaryWordCountLatin => 'Прочие слова';

  @override
  String get diaryWordCountCharacters => 'Символы (без пробелов)';

  @override
  String get diaryWordCountCharactersWithSpaces => 'Символы (с пробелами)';

  @override
  String get diaryWordCountParagraphs => 'Абзацы';

  @override
  String get diaryWordCountImages => 'Фото';

  @override
  String get diaryWordCountRecordings => 'Аудиозаписи';

  @override
  String get diaryWordCountVideos => 'Видео';

  @override
  String get diaryWordCountAttachments => 'Вложения';

  @override
  String get diaryWordCountReading => 'Время чтения';

  @override
  String get diaryWordCountRule =>
      'Каждый иероглиф (китайский, японский, корейский) или полноширинный знак препинания считается одним словом, остальной текст — по словам; пробелы и переносы строк не учитываются.';

  @override
  String get diaryPreviewUpdatedPrefix => 'Обновлено';

  @override
  String get diaryPreviewBackToTop => 'Наверх';

  @override
  String get diaryPreviewStyleTitle => 'Страница просмотра записи';

  @override
  String diaryPreviewStyleEntrySubtitle(String name) {
    return 'Сейчас: $name';
  }

  @override
  String get diaryPreviewStyleMoreEntry => 'Стиль страницы';

  @override
  String get diaryPreviewStyleTabPresets => 'Наборы';

  @override
  String get diaryPreviewStyleTabPage => 'Страница';

  @override
  String get diaryPreviewStyleTabCover => 'Обложка';

  @override
  String get diaryPreviewStyleTabTitle => 'Заголовок';

  @override
  String get diaryPreviewStyleTabMeta => 'Сведения';

  @override
  String get diaryPreviewStyleTabBody => 'Текст';

  @override
  String get diaryPreviewStylePresetClassic => 'Классика';

  @override
  String get diaryPreviewStylePresetClassicDesc => 'Прежний вид';

  @override
  String get diaryPreviewStylePresetPaper => 'Бумажная книга';

  @override
  String get diaryPreviewStylePresetPaperDesc =>
      'Тёплая бумага, заголовок по центру, обложка с отступами';

  @override
  String get diaryPreviewStylePresetMagazine => 'Журнал';

  @override
  String get diaryPreviewStylePresetMagazineDesc =>
      'Высокая обложка, крупный заголовок, дата сверху';

  @override
  String get diaryPreviewStylePresetMinimal => 'Минимализм';

  @override
  String get diaryPreviewStylePresetMinimalDesc =>
      'Без обложки, только самое нужное';

  @override
  String get diaryPreviewStylePresetNight => 'Ночь';

  @override
  String get diaryPreviewStylePresetNightDesc =>
      'Чернильная бумага и линия прогресса чтения';

  @override
  String get diaryPreviewStylePresetJournal => 'Ежедневник';

  @override
  String get diaryPreviewStylePresetJournalDesc =>
      'Цвет по настроению, сведения в карточке';

  @override
  String get diaryPreviewStylePresetMood => 'Цвет настроения';

  @override
  String get diaryPreviewStylePresetMoodDesc =>
      'Страница и бумага окрашиваются в цвет настроения записи';

  @override
  String get diaryPreviewStylePresetImmersive => 'Погружение';

  @override
  String get diaryPreviewStylePresetImmersiveDesc =>
      'Обложка во весь экран, прогресс и кнопка «Наверх»';

  @override
  String get diaryPreviewStyleColorGroup => 'Цвета';

  @override
  String get diaryPreviewStyleColorSeed => 'Основа палитры';

  @override
  String get diaryPreviewStyleSeedApp => 'Тема приложения';

  @override
  String get diaryPreviewStyleSeedMood => 'Настроение';

  @override
  String get diaryPreviewStyleSeedTag => 'Первый тег';

  @override
  String get diaryPreviewStyleSeedCustom => 'Свой цвет';

  @override
  String get diaryPreviewStyleSeedColor => 'Базовый цвет';

  @override
  String get diaryPreviewStyleSeedAppHint =>
      'Совпадает с цветом темы приложения.';

  @override
  String get diaryPreviewStyleSeedMoodHint =>
      'Цвет берётся из настроения записи; у каждого из 10 настроений он свой.';

  @override
  String get diaryPreviewStyleSeedTagHint =>
      'Цвет берётся из первого тега записи.';

  @override
  String get diaryPreviewStyleSeedCustomHint =>
      'Для всех записей используется один и тот же цвет.';

  @override
  String get diaryPreviewStyleSeedIntensity => 'Насыщенность цвета';

  @override
  String get diaryPreviewStyleSeedIntensityHint =>
      '«Мягкая» сдержанна, как тема приложения; «Исходная» сохраняет собственную глубину цвета; «Яркая» — самая насыщенная.';

  @override
  String get diaryPreviewStyleSeedIntensitySoft => 'Мягкая';

  @override
  String get diaryPreviewStyleSeedIntensityOriginal => 'Исходная';

  @override
  String get diaryPreviewStyleSeedIntensityVivid => 'Яркая';

  @override
  String get diaryPreviewStyleSeedFallback => 'Если цвета нет';

  @override
  String get diaryPreviewStyleSeedFallbackHint =>
      'Цвета для записей без настроения или тегов.';

  @override
  String get diaryPreviewStyleSeedFallbackApp => 'Тема приложения';

  @override
  String get diaryPreviewStyleSeedFallbackNeutral => 'Нейтральный серый';

  @override
  String get diaryPreviewStyleTintPaper => 'Тонировать бумагу';

  @override
  String get diaryPreviewStyleTintPaperHint =>
      'Фон страницы получает лёгкий оттенок базового цвета';

  @override
  String get diaryPreviewStyleTintScrim => 'Тонировать вуаль фона';

  @override
  String get diaryPreviewStyleTintScrimHint =>
      'При фоновом изображении вуаль окрашивается в базовый цвет каждой записи (например, в цвет настроения); её плотность по-прежнему задаётся в разделе «Фон и материал»';

  @override
  String get diaryPreviewStyleMoodColors => 'Цвета настроений';

  @override
  String get diaryPreviewStyleMoodColorsHint =>
      'Цвет каждого настроения меняется в разделе «Эмодзи настроения»';

  @override
  String get diaryPreviewStylePreviewMood => 'Настроение образца';

  @override
  String get diaryPreviewStylePreviewMoodHint =>
      'Меняет только настроение образца в предпросмотре выше';

  @override
  String get diaryPreviewStylePreviewMoodSample => 'Как в образце';

  @override
  String get diaryPreviewStylePaper => 'Бумага';

  @override
  String get diaryPreviewStylePaperTheme => 'Тема';

  @override
  String get diaryPreviewStylePaperWarm => 'Тёплая';

  @override
  String get diaryPreviewStylePaperSepia => 'Сепия';

  @override
  String get diaryPreviewStylePaperMint => 'Мятная';

  @override
  String get diaryPreviewStylePaperGray => 'Серая';

  @override
  String get diaryPreviewStylePaperInk => 'Чернильная';

  @override
  String get diaryPreviewStylePaperCustom => 'Своя';

  @override
  String get diaryPreviewStylePaperColor => 'Цвет бумаги';

  @override
  String get diaryPreviewStylePaperHint =>
      'Если бумага темнее или светлее темы, вся страница переключается под неё, чтобы текст оставался читаемым.';

  @override
  String get diaryPreviewStyleTextColor => 'Свой цвет текста';

  @override
  String get diaryPreviewStyleTextColorHint =>
      'Если контраст с бумагой слишком низкий, используется цвет по умолчанию.';

  @override
  String get diaryPreviewStyleLayoutGroup => 'Макет';

  @override
  String get diaryPreviewStylePadding => 'Боковые поля';

  @override
  String get diaryPreviewStyleLimitWidth => 'Ограничить ширину текста';

  @override
  String get diaryPreviewStyleLimitWidthSubtitle =>
      'Текст по центру на планшетах и в альбомной ориентации';

  @override
  String get diaryPreviewStyleContentWidth => 'Максимальная ширина текста';

  @override
  String get diaryPreviewStyleTopBarGroup => 'Верхняя панель';

  @override
  String get diaryPreviewStyleTopBarFloating => 'Скрывать при прокрутке';

  @override
  String get diaryPreviewStyleTopBarPinned => 'Всегда видна';

  @override
  String get diaryPreviewStyleTopBarTitle => 'Заголовок';

  @override
  String get diaryPreviewStyleTopBarTitleDate => 'Дата';

  @override
  String get diaryPreviewStyleTopBarTitleNone => 'Нет';

  @override
  String get diaryPreviewStyleShowTypographyButton => 'Кнопка «Шрифт и макет»';

  @override
  String get diaryPreviewStyleShowEditButton => 'Кнопка «Изменить»';

  @override
  String get diaryPreviewStyleShowShareButton => 'Кнопка «Поделиться»';

  @override
  String get diaryPreviewStyleReadingGroup => 'Помощь при чтении';

  @override
  String get diaryPreviewStyleProgress => 'Линия прогресса чтения';

  @override
  String get diaryPreviewStyleProgressSubtitle =>
      'Тонкая линия вверху растёт по мере чтения';

  @override
  String get diaryPreviewStyleBackToTop => 'Кнопка «Наверх»';

  @override
  String get diaryPreviewStyleBackToTopSubtitle =>
      'Появляется после полутора экранов';

  @override
  String get diaryPreviewStyleCoverMode => 'Вид';

  @override
  String get diaryPreviewStyleCoverBanner => 'Во всю ширину';

  @override
  String get diaryPreviewStyleCoverInset => 'С отступами';

  @override
  String get diaryPreviewStyleCoverHidden => 'Скрыта';

  @override
  String get diaryPreviewStyleCoverFit => 'Масштаб';

  @override
  String get diaryPreviewStyleCoverContain => 'Фото целиком';

  @override
  String get diaryPreviewStyleCoverFill => 'Заполнить с обрезкой';

  @override
  String get diaryPreviewStyleCoverHeight => 'Высота обложки';

  @override
  String get diaryPreviewStyleCoverHeightHint =>
      'Обложка занимает не более 70% высоты экрана.';

  @override
  String get diaryPreviewStyleCoverRadius => 'Скругление углов';

  @override
  String get diaryPreviewStyleCoverFade => 'Затухание при прокрутке';

  @override
  String get diaryPreviewStyleCoverFadeSubtitle =>
      'При прокрутке вверх обложка бледнеет и немного уменьшается';

  @override
  String get diaryPreviewStyleCoverFirstImage =>
      'Без обложки — первое фото из записи';

  @override
  String get diaryPreviewStyleTitleVisible => 'Показывать заголовок';

  @override
  String get diaryPreviewStyleTitleUntitled =>
      'Показывать «Без названия», если нет заголовка';

  @override
  String get diaryPreviewStyleTitleUntitledSubtitle =>
      'Если выключено, строка заголовка пропускается';

  @override
  String get diaryPreviewStyleTitleScale => 'Размер заголовка';

  @override
  String get diaryPreviewStyleTitleWeight => 'Насыщенность';

  @override
  String get diaryPreviewStyleWeightRegular => 'Обычная';

  @override
  String get diaryPreviewStyleWeightMedium => 'Средняя';

  @override
  String get diaryPreviewStyleWeightBold => 'Жирная';

  @override
  String get diaryPreviewStyleWeightHeavy => 'Сверхжирная';

  @override
  String get diaryPreviewStyleTitleAlign => 'Выравнивание';

  @override
  String get diaryPreviewStyleAlignStart => 'По левому краю';

  @override
  String get diaryPreviewStyleAlignCenter => 'По центру';

  @override
  String get diaryPreviewStyleTitleColor => 'Свой цвет заголовка';

  @override
  String get diaryPreviewStyleTitleDivider => 'Линия под заголовком';

  @override
  String get diaryPreviewStyleTitleDividerSubtitle =>
      'Светлая тонкая линия между заголовком и текстом';

  @override
  String get diaryPreviewStyleTitleBodyGap => 'Отступ перед текстом';

  @override
  String get diaryPreviewStyleTitleBodyGapSubtitle =>
      'Если линия включена, такой отступ остаётся над ней и под ней';

  @override
  String get diaryPreviewStyleMetaPosition => 'Расположение';

  @override
  String get diaryPreviewStyleMetaAbove => 'Над заголовком';

  @override
  String get diaryPreviewStyleMetaBelow => 'Под заголовком';

  @override
  String get diaryPreviewStyleMetaEnd => 'После текста';

  @override
  String get diaryPreviewStyleMetaLayout => 'Макет';

  @override
  String get diaryPreviewStyleMetaStacked => 'Столбиком';

  @override
  String get diaryPreviewStyleMetaInline => 'В строку';

  @override
  String get diaryPreviewStyleMetaCard => 'Карточка';

  @override
  String get diaryPreviewStyleMetaItems => 'Что показывать';

  @override
  String get diaryPreviewStyleShowDate => 'Дата';

  @override
  String get diaryPreviewStyleShowWordCount => 'Слова';

  @override
  String get diaryPreviewStyleShowReadingTime => 'Время чтения';

  @override
  String get diaryPreviewStyleShowLocation => 'Место';

  @override
  String get diaryPreviewStyleShowWeather => 'Погода';

  @override
  String get diaryPreviewStyleShowMood => 'Настроение';

  @override
  String get diaryPreviewStyleShowEnergy => 'Энергия';

  @override
  String get diaryPreviewStyleShowTags => 'Теги';

  @override
  String get diaryPreviewStyleDatePrefix =>
      '«Опубликовано / Обновлено» перед датой';

  @override
  String get diaryPreviewStyleChipsGroup => 'Плашки';

  @override
  String get diaryPreviewStyleTagStyle => 'Теги';

  @override
  String get diaryPreviewStyleChipStyle => 'Настроение и энергия';

  @override
  String get diaryPreviewStyleChipChip => 'Плашка';

  @override
  String get diaryPreviewStyleChipPlain => 'Текст';

  @override
  String get diaryPreviewStyleTypographyEntry => 'Шрифт и макет';

  @override
  String get diaryPreviewStyleTypographyEntrySubtitle => 'Общие с редактором';

  @override
  String get diaryPreviewStyleEmptyHint => 'Подсказка, если нет текста';

  @override
  String get diaryPreviewStyleLastEdited => 'Показывать «Изменено»';

  @override
  String get diaryPreviewStyleEditedFormat => 'Формат времени';

  @override
  String get diaryPreviewStyleEditedPrecise => 'Точное';

  @override
  String get diaryPreviewStyleEditedRelative => 'Относительное';

  @override
  String get diaryPreviewStyleEditedFull => 'Полное';

  @override
  String get diaryPreviewStyleCapsuleInsight =>
      'Сообщение об открытии капсулы времени';

  @override
  String get diaryPreviewStyleBehaviorGroup => 'Поведение при чтении';

  @override
  String get diaryPreviewStyleBehaviorFootnote =>
      'Наборы и коды стилей не меняют эти настройки.';

  @override
  String get diaryPreviewStyleTodoToggle => 'Отмечать задачи при чтении';

  @override
  String get diaryPreviewStyleTodoToggleSubtitle =>
      'Отметки сохраняются автоматически';

  @override
  String get diaryPreviewStyleTextSelection =>
      'Выделение текста долгим нажатием';

  @override
  String get diaryPreviewStyleTextSelectionSubtitle =>
      'Можно выделить и скопировать часть записи';

  @override
  String get diaryPreviewStyleDoubleTapEdit => 'Правка двойным касанием';

  @override
  String get diaryPreviewStyleDoubleTapEditSubtitle =>
      'Редактор откроется с курсором в месте касания';

  @override
  String diaryPreviewStyleSampleOf(int index, int count) {
    return 'Образец $index из $count';
  }

  @override
  String get diaryPreviewStyleSampleHeading => 'Сегодняшние мелочи';

  @override
  String get diaryPreviewStyleSampleQuote => 'Тише едешь — дальше будешь.';

  @override
  String get diaryPreviewStyleSampleTodo1 => 'Купить цветы';

  @override
  String get diaryPreviewStyleSampleTodo2 => 'Позвонить домой';

  @override
  String get diaryPreviewStyleSampleLong =>
      'После дождя улица затихла. У окна нашлось время записать три вещи, за которые хочется сказать спасибо, а за стеклом один за другим падали листья, будто кто-то листал очень старую книгу.';

  @override
  String get diaryPreviewStyleSampleWeather => 'Солнечно';

  @override
  String get diaryPreviewFirstDiary => 'Это первая запись';

  @override
  String get diaryPreviewLastDiary => 'Это последняя запись';

  @override
  String get diaryPreviewPrevious => 'Предыдущая';

  @override
  String get diaryPreviewNext => 'Следующая';

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
    return '$index из $count';
  }

  @override
  String diaryPreviewPositionSemanticsMore(int index, int count) {
    return '$index из $count или более';
  }

  @override
  String get diaryDetailPaneEmpty => 'Выберите запись, чтобы прочитать её';

  @override
  String diaryDetailPaneCreateHint(String shortcut) {
    return 'Нажмите $shortcut, чтобы написать новую запись';
  }

  @override
  String get diaryPreviewStyleTabPaging => 'Листание';

  @override
  String get diaryPreviewStyleSwipe => 'Листать записи свайпом';

  @override
  String get diaryPreviewStyleSwipeSubtitle =>
      'В порядке списка, из которого открыта запись';

  @override
  String get diaryPreviewStyleSwipeSensitivity => 'Чувствительность';

  @override
  String get diaryPreviewStyleSensitivitySensitive => 'Высокая';

  @override
  String get diaryPreviewStyleSensitivityStandard => 'Обычная';

  @override
  String get diaryPreviewStyleSensitivityStrict => 'Строгая';

  @override
  String get diaryPreviewStyleSensitivityHint =>
      'Чем правее вариант, тем горизонтальнее должен быть свайп; для «Строгой» нужно ещё протянуть на полэкрана или резко смахнуть.';

  @override
  String get diaryPreviewStyleHapticOnPage => 'Вибрация при листании';

  @override
  String get diaryPreviewStyleTransition => 'Анимация перехода';

  @override
  String get diaryPreviewStyleTransitionSlide => 'Сдвиг';

  @override
  String get diaryPreviewStyleTransitionStack => 'Стопка';

  @override
  String get diaryPreviewStyleTransitionFade => 'Растворение';

  @override
  String get diaryPreviewStyleNeighborCards => 'Соседние записи в конце';

  @override
  String get diaryPreviewStyleEdgeHint => 'Подсказка на краях';

  @override
  String get diaryPreviewStyleEdgeHintSubtitle =>
      'Когда вы тянете дальше первой или последней записи';

  @override
  String get diaryPreviewStyleTopBarTitlePosition => 'Номер';

  @override
  String get dataMgmtCloudBackup => 'Резервное копирование в облако';

  @override
  String get dataMgmtCloudBackupSubtitle =>
      'Копирование в облачные хранилища, WebDAV или объектные хранилища и восстановление из них';

  @override
  String get cloudBackupTitle => 'Резервное копирование в облако';

  @override
  String get cloudBackupEmpty =>
      'Мест для резервного копирования пока нет. Добавьте облачное хранилище, сервер WebDAV или объектное хранилище, чтобы сохранять туда данные и восстанавливать их на новом устройстве.';

  @override
  String get cloudBackupAdd => 'Добавить место хранения';

  @override
  String get cloudBackupHint =>
      'Адреса, пароли и авторизация облачных хранилищ хранятся только на этом устройстве и никогда не попадают в резервные копии. Обычное резервное копирование — инкрементное: выгружается только новое и изменённое. Можно также выгрузить полный ZIP-архив, при желании с шифрованием.';

  @override
  String get cloudBackupSheetTitle => 'Выберите место хранения';

  @override
  String get cloudBackupSheetHint =>
      'Перед восстановлением копия проверяется, и вы выбираете: объединить её с данными на устройстве или заменить их.';

  @override
  String get cloudBackupGroupDrives => 'Облачные хранилища (вход в аккаунт)';

  @override
  String get cloudBackupGroupDrivesHint =>
      'Авторизация проходит на официальной странице хранилища; приложение получает доступ только к своей папке с копиями.';

  @override
  String get cloudBackupGroupWebDav => 'WebDAV';

  @override
  String get cloudBackupGroupWebDavHint =>
      'Nutstore, NAS, Nextcloud и любые хранилища, подключённые через Alist / OpenList.';

  @override
  String get cloudBackupGroupS3 => 'Объектное хранилище (совместимое с S3)';

  @override
  String get cloudBackupGroupS3Hint =>
      'Укажите ключи доступа; копии хранятся в выбранном бакете.';

  @override
  String get cloudBackupCustomWebDav => 'Другой WebDAV';

  @override
  String get cloudBackupCustomS3 => 'Другое S3-совместимое';

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
  String get cloudBackupAwsChina => 'Amazon S3 (Китай)';

  @override
  String get cloudBackupHintJianguoyun =>
      'Имя пользователя — ваш аккаунт Nutstore, пароль — пароль приложения из веб-версии: «Информация об аккаунте → Безопасность → Сторонние приложения». Бесплатные аккаунты ограничены 600 запросами за 30 минут.';

  @override
  String get cloudBackupHint123pan =>
      'Скопируйте адрес и пароль со страницы «Инструменты → Подключение сторонних программ» в 123pan (пароль показывается только один раз).';

  @override
  String get cloudBackupHintOpenList =>
      'Укажите адрес Alist / OpenList (порт по умолчанию 5244, путь /dav/) и выдайте пользователю права WebDAV на чтение и управление. Любое подключённое там хранилище можно использовать для копий.';

  @override
  String get cloudBackupHintCloudDrive2 =>
      'Укажите адрес CloudDrive2 (порт по умолчанию 19798, путь /dav) и данные аккаунта CloudDrive2.';

  @override
  String get cloudBackupHintNextcloud =>
      'Скопируйте адрес в веб-версии в разделе «Настройки файлов → WebDAV»; в качестве пароля лучше использовать пароль приложения из «Личные настройки → Безопасность».';

  @override
  String get cloudBackupHintOwncloud =>
      'В качестве пароля лучше использовать токен приложения; в oCIS токены приложений должен включить администратор.';

  @override
  String get cloudBackupHintSeafile =>
      'На сервере должен быть включён SeafDAV; для аккаунтов с единым входом (SSO) нужно задать отдельный пароль WebDAV в веб-версии.';

  @override
  String get cloudBackupHintSynology =>
      'Установите и включите WebDAV Server в DSM (HTTPS-порт по умолчанию 5006) и войдите с аккаунтом DSM; первый уровень удалённой папки должен быть общей папкой.';

  @override
  String get cloudBackupHintQnap =>
      'Включите WebDAV в панели управления и добавьте в конец адреса имя общей папки.';

  @override
  String get cloudBackupHintKoofr =>
      'Нужен пароль приложения из раздела «Настройки → Пароли» в Koofr; после нескольких неудачных попыток входа доступ временно блокируется.';

  @override
  String get cloudBackupHintPcloud =>
      'Войдите с адресом почты и паролем pCloud; для европейских аккаунтов выберите pCloud (EU).';

  @override
  String get cloudBackupHintInfinicloud =>
      'Скопируйте адрес и пароль Apps Connection со страницы My Page в InfiniCLOUD.';

  @override
  String get cloudBackupHintHetzner =>
      'Включите WebDAV и внешний доступ для Storage Box в Hetzner Console.';

  @override
  String get cloudBackupHintKdrive =>
      'Drive ID указан в веб-адресе kDrive; если включена двухфакторная аутентификация, используйте пароль приложения.';

  @override
  String get cloudBackupHintYandex =>
      'Нужна платная подписка Яндекс 360 и пароль приложения с типом WebDAV.';

  @override
  String get cloudBackupHintMailru =>
      'Используйте пароль приложения, созданный в настройках аккаунта Mail.ru.';

  @override
  String get cloudBackupS3Hint =>
      'Эндпоинт и регион должны соответствовать расположению бакета. Используйте отдельный бакет и ключи с доступом только к нему.';

  @override
  String get cloudBackupHintAliyunOss =>
      'Используйте AccessKey пользователя RAM; регион в эндпоинте должен совпадать с регионом бакета. Аккаунты, открытые после марта 2025 г., могут не иметь доступа к публичному эндпоинту по умолчанию из материкового Китая.';

  @override
  String get cloudBackupHintTencentCos =>
      'Имя бакета должно содержать суффикс APPID (например, backup-1250000000); ключи создаются в разделе CAM → API keys.';

  @override
  String get cloudBackupHintQiniuKodo =>
      'Имя бакета для S3 может отличаться от имени пространства Kodo; используйте то, что показано в консоли.';

  @override
  String get cloudBackupHintR2 =>
      'Замените ACCOUNT_ID на ID аккаунта Cloudflare, создайте токен в R2 → Manage API tokens и используйте его учётные данные S3; регион оставьте auto.';

  @override
  String get cloudBackupHintB2 =>
      'Используйте эндпоинт со страницы бакета, а в качестве региона — его часть (например, us-west-004); ключ — Application Key.';

  @override
  String get cloudBackupHintDigitalOcean =>
      'Укажите в эндпоинте дата-центр Spaces (например, nyc3), а регион подписи оставьте us-east-1.';

  @override
  String get cloudBackupHintMinio =>
      'Укажите адрес API MinIO (порт по умолчанию 9000) и не отключайте доступ в стиле пути (path-style).';

  @override
  String get cloudBackupHintGcs =>
      'Создайте ключи HMAC в Cloud Storage: «Настройки → Совместимость» (Interoperability).';

  @override
  String get cloudBackupHintOracle =>
      'NAMESPACE и REGION можно найти в консоли OCI; используйте Customer Secret Key.';

  @override
  String get cloudBackupFolderGoogleDrive =>
      'Копии хранятся в папке «Jotsy» на Google Drive; приложение имеет доступ только к созданным им файлам. Удалённые копии не попадают в корзину.';

  @override
  String get cloudBackupFolderOneDrive =>
      'Копии хранятся в папке этого приложения внутри папки «Приложения» в OneDrive; приложение имеет доступ только к ней. Удалённые копии попадают в корзину OneDrive.';

  @override
  String get cloudBackupFolderDropbox =>
      'Копии хранятся в папке этого приложения внутри папки «Приложения» в Dropbox; приложение имеет доступ только к ней.';

  @override
  String get cloudBackupFolderBaidu =>
      'Копии хранятся в папке этого приложения в разделе «Мои данные приложений» в Baidu Netdisk.';

  @override
  String get cloudBackupFolderAliyun =>
      'Копии хранятся в папке, выбранной при авторизации (или в папке «Jotsy» в корне). Удалённые копии попадают в корзину. Когда срок авторизации в Alipan истечёт, авторизуйтесь заново.';

  @override
  String get cloudBackupConfigSection => 'Подключение';

  @override
  String get cloudBackupSaveConfig => 'Сохранить';

  @override
  String get cloudBackupTestConnection => 'Проверить подключение';

  @override
  String get cloudBackupUploadBackup => 'Выгрузить полный ZIP';

  @override
  String get cloudBackupRefreshBackups => 'Обновить';

  @override
  String get cloudBackupBackupList => 'Копии в хранилище';

  @override
  String get cloudBackupNoBackups => 'В хранилище пока нет копий';

  @override
  String cloudBackupBackupTime(String time) {
    return 'Время: $time';
  }

  @override
  String cloudBackupBackupSize(String size) {
    return 'Размер: $size';
  }

  @override
  String get cloudBackupRestoreAction => 'Восстановить';

  @override
  String get cloudBackupDeleteAction => 'Удалить';

  @override
  String get cloudBackupDeleteConfirmTitle => 'Удалить копию из хранилища?';

  @override
  String cloudBackupDeleteConfirmContent(String fileName) {
    return 'Удалить $fileName из этого хранилища? Это действие нельзя отменить.';
  }

  @override
  String get cloudBackupRemoveTarget => 'Убрать это место хранения';

  @override
  String get cloudBackupRemoveTargetTitle => 'Убрать место хранения?';

  @override
  String get cloudBackupRemoveTargetContent =>
      'Будут удалены только данные подключения и авторизация, сохранённые на этом устройстве. Уже сохранённые там копии останутся, а место можно будет добавить снова.';

  @override
  String get cloudBackupRemoveTargetAction => 'Убрать';

  @override
  String get cloudBackupRemoved => 'Место хранения убрано';

  @override
  String get cloudBackupConfigSaved => 'Настройки сохранены';

  @override
  String get cloudBackupConnectionOk => 'Подключение установлено';

  @override
  String get cloudBackupUploadSuccess => 'Копия выгружена';

  @override
  String get cloudBackupRestoreSuccess =>
      'Данные восстановлены из копии в хранилище';

  @override
  String get cloudBackupDeleteSuccess => 'Копия удалена из хранилища';

  @override
  String get cloudBackupAccountAuthorized => 'Авторизовано';

  @override
  String cloudBackupAccountConnected(String account) {
    return 'Вход выполнен: $account';
  }

  @override
  String get cloudBackupReauthorize => 'Авторизоваться заново';

  @override
  String cloudBackupAuthorized(String name) {
    return 'Подключено: $name';
  }

  @override
  String cloudBackupAuthorizeTitle(String name) {
    return 'Авторизация: $name';
  }

  @override
  String get cloudBackupDeviceCodeHint =>
      'Откройте страницу авторизации, войдите и введите код ниже. После подтверждения всё продолжится автоматически.';

  @override
  String get cloudBackupDeviceCodeLabel => 'Код авторизации';

  @override
  String get cloudBackupCopyCode => 'Копировать код';

  @override
  String get cloudBackupDeviceCodeCopied => 'Скопировано';

  @override
  String get cloudBackupOpenAuthorizePage => 'Открыть страницу авторизации';

  @override
  String get cloudBackupWaitingAuthorization => 'Ожидание авторизации…';

  @override
  String get cloudBackupCodePasteHint =>
      'После авторизации в браузере на странице появится код. Скопируйте его и вставьте сюда.';

  @override
  String get cloudBackupCodeLabel => 'Код авторизации';

  @override
  String get cloudBackupCodeConfirm => 'Готово';

  @override
  String get cloudBackupBusyLabel => 'Идёт резервное копирование в облако';

  @override
  String get cloudBackupBusySave => 'Сохранение…';

  @override
  String get cloudBackupBusyTest => 'Проверка подключения…';

  @override
  String get cloudBackupBusyUpload => 'Создание копии…';

  @override
  String cloudBackupBusyUploadProgress(int percent) {
    return 'Выгрузка: $percent%';
  }

  @override
  String get cloudBackupBusyDownload => 'Загрузка копии…';

  @override
  String cloudBackupBusyDownloadProgress(int percent) {
    return 'Загрузка: $percent%';
  }

  @override
  String get cloudBackupBusyRestore => 'Восстановление данных…';

  @override
  String get cloudBackupBusyRefresh => 'Загрузка списка копий…';

  @override
  String get cloudBackupBusyDelete => 'Удаление копии из хранилища…';

  @override
  String get cloudBackupBusyAuthorize => 'Проверка авторизации…';

  @override
  String cloudBackupOperationFailed(String detail) {
    return 'Не удалось выполнить операцию: $detail';
  }

  @override
  String get cloudBackupErrorConfig =>
      'Проверьте, что адрес, бакет и папка указаны полностью и верно';

  @override
  String get cloudBackupErrorAppKeyMissing =>
      'В этой сборке нет ключа приложения для этого хранилища, поэтому оно недоступно';

  @override
  String get cloudBackupErrorAuth =>
      'Ошибка аутентификации или нет доступа. Проверьте учётную запись, пароль или ключи';

  @override
  String get cloudBackupErrorSessionExpired =>
      'Срок действия авторизации истёк. Авторизуйтесь заново';

  @override
  String get cloudBackupErrorAuthorizationDenied => 'В авторизации отказано';

  @override
  String get cloudBackupErrorAuthorizationExpired =>
      'Код недействителен или устарел. Получите новый';

  @override
  String get cloudBackupErrorNotFound =>
      'Удалённый файл или папка не существует';

  @override
  String get cloudBackupErrorStorageFull =>
      'В хранилище резервных копий закончилось место';

  @override
  String get cloudBackupErrorFileTooLarge =>
      'Резервная копия превышает допустимый размер файла для этого хранилища';

  @override
  String get cloudBackupErrorRateLimited =>
      'Слишком много запросов. Повторите попытку позже';

  @override
  String get cloudBackupErrorNetwork =>
      'Ошибка сетевого запроса. Проверьте подключение, адрес и сертификат';

  @override
  String get cloudBackupErrorProtocol =>
      'Хранилище резервных копий вернуло неожиданный ответ';

  @override
  String get cloudBackupErrorPassword => 'Неверный пароль резервной копии';

  @override
  String get cloudBackupErrorArchive =>
      'Резервная копия повреждена или создана не в Jotsy';

  @override
  String get cloudBackupErrorLocalFile =>
      'Не удалось прочитать или записать временный файл на устройстве. Проверьте, достаточно ли свободного места';

  @override
  String get cloudBackupErrorUnknown =>
      'Произошла неизвестная ошибка. Повторите попытку позже';

  @override
  String get s3Endpoint => 'Адрес сервиса (Endpoint)';

  @override
  String get s3EndpointHint => 'Например, https://s3.us-east-1.amazonaws.com';

  @override
  String get s3Region => 'Регион';

  @override
  String get s3RegionHint => 'По умолчанию us-east-1';

  @override
  String get s3Bucket => 'Бакет';

  @override
  String get s3AccessKeyId => 'Access Key ID';

  @override
  String get s3SecretAccessKey => 'Secret Access Key';

  @override
  String get s3Prefix => 'Папка резервных копий (префикс ключа)';

  @override
  String get s3PrefixHint =>
      'Например, jotsy/; оставьте пустым для корня бакета';

  @override
  String get s3PathStyle => 'Доступ в стиле пути (path-style)';

  @override
  String get s3PathStyleSubtitle =>
      'Обычно требуется для собственных серверов, например MinIO';

  @override
  String get s3PathStyleLocked =>
      'Этот сервис поддерживает только доступ в стиле виртуального хоста';

  @override
  String get cloudBackupErrorPlatformUnavailable =>
      'На этом устройстве недоступна авторизация через системную учётную запись (нужны сервисы Google Play), а запасного способа в этой сборке нет';

  @override
  String get weatherInvalidHost =>
      'Адрес сервиса погоды настроен неверно. Проверьте qweather.api_host.';

  @override
  String get weatherNetworkError =>
      'Не удалось получить погоду или истекло время ожидания. Проверьте подключение и повторите попытку.';

  @override
  String get weatherApiError =>
      'Сервис погоды временно недоступен. Повторите попытку позже.';

  @override
  String get weatherParseError =>
      'Не удалось получить данные о погоде. Повторите попытку позже или укажите погоду вручную.';

  @override
  String get publishCoverImportFailed =>
      'Не удалось сделать это изображение обложкой. Попробуйте другое.';

  @override
  String get publishTagCreateFailed =>
      'Не удалось создать тег. Повторите попытку.';

  @override
  String get publishFailed =>
      'Не удалось опубликовать запись. Повторите попытку.';

  @override
  String get publishSucceeded => 'Запись опубликована';

  @override
  String get publishCapsuleExpired =>
      'Время открытия уже прошло, поэтому запись опубликована как обычная.';

  @override
  String get publishSaveFailed =>
      'Не удалось сохранить изменения. Повторите попытку.';

  @override
  String publishTimeFollowsCapsule(String time) {
    return 'По времени открытия · $time';
  }

  @override
  String get publishCoverChange => 'Нажмите, чтобы изменить';

  @override
  String get publishPanelSummaryEmpty => 'Добавьте теги, настроение, место…';

  @override
  String get previewShare => 'Поделиться';

  @override
  String get diaryShareSheetTitle => 'Поделиться записью';

  @override
  String get diaryShareContentSection => 'Содержимое';

  @override
  String get diaryShareOptionTitle => 'Заголовок';

  @override
  String get diaryShareOptionBody => 'Текст';

  @override
  String get diaryShareOptionDate => 'Дата';

  @override
  String get diaryShareOptionMoodWeather => 'Настроение и погода';

  @override
  String get diaryShareOptionLocation => 'Место';

  @override
  String get diaryShareOptionTags => 'Теги';

  @override
  String get diaryShareOptionImages => 'Изображения';

  @override
  String get diaryShareTextEmpty =>
      'Текст не выбран — будут отправлены только изображения';

  @override
  String diaryShareImagesSelected(int selected, int total) {
    return 'Выбрано $selected из $total';
  }

  @override
  String diaryShareImageLabel(int index) {
    return 'Изображение $index';
  }

  @override
  String get diaryShareTargetsSection => 'Куда отправить';

  @override
  String get diaryShareTargetWeibo => 'Weibo';

  @override
  String get diaryShareTargetXiaohongshu => 'Xiaohongshu';

  @override
  String get diaryShareTargetWechat => 'WeChat';

  @override
  String get diaryShareTargetWechatMoments => 'Моменты';

  @override
  String get diaryShareTargetQq => 'QQ';

  @override
  String get diaryShareTargetQzone => 'Qzone';

  @override
  String get diaryShareTargetSystem => 'Другие приложения';

  @override
  String get diaryShareCopyText => 'Копировать текст';

  @override
  String get diaryShareClipboardHint =>
      'Если прикреплены изображения, текст копируется автоматически — просто вставьте его в публикацию.';

  @override
  String get diaryShareMoreSection => 'Другие форматы';

  @override
  String get diaryShareLongImage => 'Поделиться длинным изображением';

  @override
  String get diaryShareLongImageSubtitle =>
      'Запись целиком в том виде, как на странице просмотра';

  @override
  String get diaryShareLongImageToGallery =>
      'Сохранить длинное изображение в галерею';

  @override
  String get diaryShareLongImageToGallerySubtitle =>
      'То же изображение сразу сохраняется в галерею';

  @override
  String diaryShareRequiresImage(String app) {
    return 'Для $app нужно хотя бы одно изображение';
  }

  @override
  String get diaryShareRequiresImageSeveral =>
      'Для неактивных приложений нужно хотя бы одно изображение';

  @override
  String get diaryShareNothingSelected => 'Сначала выберите, чем поделиться';

  @override
  String get diaryShareInProgress => 'Подготовка к отправке';

  @override
  String diaryShareTextCopiedForApp(String app) {
    return 'Текст скопирован — вставьте его в $app';
  }

  @override
  String get diaryShareTextCopied =>
      'Текст скопирован — вставьте его в приложении, куда вы отправили запись';

  @override
  String get diaryShareCopied => 'Скопировано в буфер обмена';

  @override
  String diaryShareImagesTrimmed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'За раз можно отправить максимум $count изображения — остальные не отправлены',
      many:
          'За раз можно отправить максимум $count изображений — остальные не отправлены',
      few:
          'За раз можно отправить максимум $count изображения — остальные не отправлены',
      one:
          'За раз можно отправить максимум $count изображение — остальные не отправлены',
    );
    return '$_temp0';
  }

  @override
  String diaryShareImagesMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count изображения не удалось прочитать — они пропущены',
      many: '$count изображений не удалось прочитать — они пропущены',
      few: '$count изображения не удалось прочитать — они пропущены',
      one: '$count изображение не удалось прочитать — оно пропущено',
    );
    return '$_temp0';
  }

  @override
  String diaryShareAppUnavailable(String app) {
    return 'Не удалось открыть $app. Убедитесь, что приложение установлено и обновлено';
  }

  @override
  String get diaryShareNothingToShare => 'Нечем поделиться';

  @override
  String diaryShareFailed(String error) {
    return 'Не удалось поделиться: $error';
  }

  @override
  String get previewExport => 'Экспорт';

  @override
  String get diaryExportSelected => 'Экспорт';

  @override
  String get diaryTagBatchAction => 'Задать теги';

  @override
  String diaryTagBatchTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Теги для $count записи',
      many: 'Теги для $count записей',
      few: 'Теги для $count записей',
      one: 'Теги для $count записи',
    );
    return '$_temp0';
  }

  @override
  String get diaryTagBatchDone => 'Готово';

  @override
  String diaryTagBatchUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Теги обновлены в $count записи',
      many: 'Теги обновлены в $count записях',
      few: 'Теги обновлены в $count записях',
      one: 'Теги обновлены в $count записи',
    );
    return '$_temp0';
  }

  @override
  String get diaryTagBatchFailed =>
      'Не удалось обновить теги. Повторите попытку.';

  @override
  String get dataMgmtExportDiaries => 'Экспорт записей';

  @override
  String get dataMgmtExportDiariesSubtitle =>
      'По дате или тегам в PDF, Word, Markdown, веб-страницу и другие форматы';

  @override
  String get diaryExportSheetTitle => 'Экспорт записей';

  @override
  String diaryExportSheetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи',
      many: '$count записей',
      few: '$count записи',
      one: '$count запись',
    );
    return '$_temp0';
  }

  @override
  String get diaryExportFormatSection => 'Формат';

  @override
  String get diaryExportOptionsSection => 'Параметры';

  @override
  String get diaryExportFormatPdf => 'PDF';

  @override
  String get diaryExportFormatPdfDescription =>
      'Фиксированная вёрстка для чтения и печати';

  @override
  String get diaryExportFormatWord => 'Документ Word';

  @override
  String get diaryExportFormatWordDescription =>
      '.docx, который можно редактировать дальше';

  @override
  String get diaryExportFormatMarkdown => 'Markdown';

  @override
  String get diaryExportFormatMarkdownDescription =>
      'С front matter для Obsidian и других приложений для заметок; можно импортировать обратно в Jotsy';

  @override
  String get diaryExportFormatHtml => 'Веб-страница';

  @override
  String get diaryExportFormatHtmlDescription =>
      'Открывается в любом браузере; несколько записей с изображениями сохраняются как страница и папка с изображениями';

  @override
  String get diaryExportFormatText => 'Обычный текст';

  @override
  String get diaryExportFormatTextDescription =>
      '.txt, который откроется где угодно';

  @override
  String get diaryExportFormatCsv => 'Таблица (CSV)';

  @override
  String get diaryExportFormatCsvDescription =>
      'Строка на каждую запись с настроением, погодой и другими данными — для Excel';

  @override
  String get diaryExportFormatDiaryFile => 'Файл записей Jotsy';

  @override
  String get diaryExportFormatDiaryFileDescription =>
      'Сохраняет всё, включая медиафайлы; можно задать пароль; импорт обратно без потерь';

  @override
  String get diaryExportIncludeImages => 'Включить изображения';

  @override
  String get diaryExportIncludeMedia =>
      'Включить изображения, аудиозаписи, видео и вложения';

  @override
  String get diaryExportIncludeMeta =>
      'Включить настроение, погоду, место и теги';

  @override
  String get diaryExportOrderOldest => 'Сначала старые';

  @override
  String get diaryExportOrderNewest => 'Сначала новые';

  @override
  String get diaryExportSave => 'Сохранить в файлы';

  @override
  String get diaryExportInProgress => 'Идёт экспорт';

  @override
  String diaryExportSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Экспортировано $count записи',
      many: 'Экспортировано $count записей',
      few: 'Экспортировано $count записи',
      one: 'Экспортирована $count запись',
    );
    return '$_temp0';
  }

  @override
  String diaryExportSkippedCapsules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count запечатанной капсулы времени не экспортировано',
      many: '$count запечатанных капсул времени не экспортировано',
      few: '$count запечатанные капсулы времени не экспортированы',
      one: '$count запечатанная капсула времени не экспортирована',
    );
    return '$_temp0';
  }

  @override
  String get diaryExportOnlyCapsules =>
      'Выбраны только запечатанные капсулы времени — экспортировать нечего';

  @override
  String get diaryExportNothing => 'Нет подходящих записей';

  @override
  String get diaryExportPageTitle => 'Экспорт записей';

  @override
  String get diaryExportRangeSection => 'Период';

  @override
  String get diaryExportRangeAll => 'Все записи';

  @override
  String get diaryExportRangeThisYear => 'Этот год';

  @override
  String get diaryExportRangeLast30Days => 'Последние 30 дней';

  @override
  String get diaryExportRangeCustom => 'Выбрать даты';

  @override
  String diaryExportRangeCustomValue(String start, String end) {
    return '$start – $end, нажмите, чтобы изменить';
  }

  @override
  String get diaryExportTagsSection => 'Теги';

  @override
  String get diaryExportTagsHint =>
      'Если ничего не выбрано — любые теги; из выбранных достаточно любого';

  @override
  String get diaryExportIncludeArchived => 'Включить архивные записи';

  @override
  String diaryExportMatchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Будет экспортировано $count записи',
      many: 'Будет экспортировано $count записей',
      few: 'Будет экспортировано $count записи',
      one: 'Будет экспортирована $count запись',
    );
    return '$_temp0';
  }

  @override
  String get diaryExportCapsuleNote =>
      'Запечатанные капсулы времени не экспортируются';

  @override
  String get diaryExportNext => 'Выбрать формат и экспортировать';

  @override
  String get diaryExportLabelUntitled => 'Без названия';

  @override
  String get diaryExportLabelMood => 'Настроение';

  @override
  String get diaryExportLabelEnergy => 'Энергия';

  @override
  String get diaryExportLabelWeather => 'Погода';

  @override
  String get diaryExportLabelLocation => 'Место';

  @override
  String get diaryExportLabelTags => 'Теги';

  @override
  String get diaryExportLabelDate => 'Дата';

  @override
  String get diaryExportLabelTime => 'Время';

  @override
  String get diaryExportLabelTitle => 'Заголовок';

  @override
  String get diaryExportLabelContent => 'Текст';

  @override
  String get diaryExportLabelWordCount => 'Слова';

  @override
  String get diaryExportLabelUpdated => 'Последнее изменение';

  @override
  String get diaryExportLabelImage => 'Изображение';

  @override
  String get diaryExportLabelAudio => 'Аудиозапись';

  @override
  String get diaryExportLabelVideo => 'Видео';

  @override
  String get diaryExportLabelAttachment => 'Вложение';

  @override
  String get diaryExportLabelExportedBy => 'Экспортировано из Jotsy';

  @override
  String diaryExportTooLarge(int size) {
    return 'Слишком много изображений (около $size MB) для одного PDF. Сократите период или отключите «Включить изображения» и повторите попытку';
  }

  @override
  String diaryDayPhotosTitle(int count) {
    return '$count фото этого дня';
  }

  @override
  String get diaryDayPhotosAccessTitle => 'Фото этого дня';

  @override
  String get diaryDayPhotosAccessBody =>
      'Разрешите доступ к фото, чтобы видеть снимки и видео, сделанные в этот день, и добавлять их в запись.';

  @override
  String get diaryDayPhotosDeniedBody =>
      'Доступ к фото выключен. Его можно включить в настройках системы.';

  @override
  String get diaryDayPhotosAllowAccess => 'Разрешить доступ';

  @override
  String get diaryDayPhotosOpenSettings => 'Открыть настройки';

  @override
  String get diaryDayPhotosShowAll => 'Все';

  @override
  String get diaryDayPhotosDismiss => 'Скрыть для этой записи';

  @override
  String diaryDayPhotosSelected(int count) {
    return 'Выбрано: $count';
  }

  @override
  String get diaryDayPhotosClear => 'Снять выбор';

  @override
  String get diaryDayPhotosInsert => 'Вставить';

  @override
  String diaryDayPhotosInsertCount(int count) {
    return 'Вставить ($count)';
  }

  @override
  String get diaryDayPhotosLimited =>
      'Показаны только фото и видео, к которым вы разрешили доступ';

  @override
  String get diaryDayPhotosManageLimited => 'Выбрать ещё';

  @override
  String diaryDayPhotosPhotoLabel(String time) {
    return 'Фото, снятое в $time';
  }

  @override
  String diaryDayPhotosInsertedLabel(String time) {
    return 'Фото, снятое в $time, добавлено';
  }

  @override
  String diaryDayPhotosSheetTitle(String date) {
    return 'Фото за $date';
  }

  @override
  String diaryDayPhotosMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count файла не удалось прочитать — они пропущены',
      many: '$count файлов не удалось прочитать — они пропущены',
      few: '$count файла не удалось прочитать — они пропущены',
      one: '$count файл не удалось прочитать — он пропущен',
    );
    return '$_temp0';
  }

  @override
  String get settingsDayPhotoSuggestions => 'Показывать фото того дня';

  @override
  String get settingsDayPhotoSuggestionsSubtitle =>
      'Когда вы пишете запись за прошедший день, под заголовком появятся фото этого дня. Если выключено, их можно открыть из меню в правом верхнем углу редактора.';

  @override
  String get settingsToolbarAlwaysVisible =>
      'Всегда показывать панель инструментов';

  @override
  String get settingsToolbarAlwaysVisibleSubtitle =>
      'Панель инструментов остаётся внизу редактора, когда экранная клавиатура скрыта или вы печатаете на физической клавиатуре.';

  @override
  String get settingsOpenDiaryInEditor => 'Открывать записи в редакторе';

  @override
  String get settingsOpenDiaryInEditorSubtitle =>
      'Нажатие на запись сразу открывает её для правки — в том же оформлении, что и просмотр.';

  @override
  String get diaryReadingEditInfo => 'Изменить сведения';

  @override
  String get diaryReadingDone => 'Готово';

  @override
  String get diaryReadingReloaded =>
      'Запись изменили в другом месте — показана последняя версия.';

  @override
  String get diaryDayPhotosSetCover => 'Сделать обложкой';

  @override
  String get diaryDayPhotosClearCover => 'Убрать обложку';

  @override
  String get diaryDayPhotosCoverBadge => 'Обложка';

  @override
  String diaryDayPhotosCoverLabel(String label) {
    return '$label, обложка';
  }

  @override
  String get diaryDayPhotosCoverSet =>
      'Обложка установлена. Посмотреть или изменить её можно на странице публикации.';

  @override
  String get diaryDayPhotosCoverSetEdit => 'Обложка установлена';

  @override
  String get diaryDayPhotosMenu => 'Фото этого дня';

  @override
  String get diaryDayPhotosEmpty =>
      'В этот день не было снято ни фото, ни видео';

  @override
  String diaryDayPhotosTitleVideos(int count) {
    return '$count видео этого дня';
  }

  @override
  String diaryDayPhotosTitleMixed(int photos, int videos) {
    return '$photos фото и $videos видео этого дня';
  }

  @override
  String diaryDayPhotosSheetTitleMedia(String date) {
    return 'Фото и видео за $date';
  }

  @override
  String diaryDayPhotosSelectedItems(int count) {
    return 'Выбрано: $count';
  }

  @override
  String diaryDayPhotosInsertCountItems(int count) {
    return 'Вставить ($count)';
  }

  @override
  String diaryDayPhotosVideoLabel(String time, String duration) {
    return 'Видео, снятое в $time, длительность $duration';
  }

  @override
  String diaryDayPhotosVideoInsertedLabel(String time, String duration) {
    return 'Видео, снятое в $time, длительность $duration, добавлено';
  }

  @override
  String get diaryDayPhotosVideoAccess => 'Видео этого дня пока недоступны';

  @override
  String get diaryDayPhotosSelect => 'Выбрать';

  @override
  String get diaryDayPhotosDeselect => 'Снять выбор';

  @override
  String get diaryDayPhotosInserted => 'Добавлено';

  @override
  String get diaryDayPhotosPreview => 'Просмотр';

  @override
  String get diaryDayPhotosPreviewFailed => 'Не удаётся показать это фото';

  @override
  String get diaryLongImageBadge => 'Длинное изображение';

  @override
  String get diaryImageMenuTitle => 'Изображение';

  @override
  String get diaryImageMenuView => 'Открыть';

  @override
  String get diaryImageMenuResize => 'Изменить размер';

  @override
  String get diaryImageMenuThumbnail => 'Показывать миниатюрой';

  @override
  String get diaryImageMenuFullSize => 'Показывать в обычном размере';

  @override
  String get diaryImageMenuCopy => 'Копировать';

  @override
  String get diaryPreviewStyleLongImage => 'Длинные изображения';

  @override
  String get diaryPreviewStyleLongImageSubtitle =>
      'Изображения, высота которых минимум в 3 раза больше ширины, например длинные скриншоты. Нажмите на свёрнутое, чтобы увидеть его целиком.';

  @override
  String get diaryPreviewStyleLongImageFold => 'Свёрнуто';

  @override
  String get diaryPreviewStyleLongImageFull => 'Целиком';

  @override
  String get diaryDraftsTitle => 'Черновики';

  @override
  String get diaryDraftsEmpty =>
      'Черновиков пока нет. Сюда попадают новые записи, закрытые до публикации';

  @override
  String diaryDraftEditedAt(String time, String words) {
    return 'Изменено $time · слов: $words';
  }

  @override
  String get diaryDraftDeleted => 'Черновик удалён';

  @override
  String diaryDraftsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Удалено $count черновика',
      many: 'Удалено $count черновиков',
      few: 'Удалено $count черновика',
      one: 'Удалён $count черновик',
    );
    return '$_temp0';
  }

  @override
  String get diaryDraftsDeleteTitle => 'Удалить черновики';

  @override
  String diaryDraftsDeleteMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Удалить $count выбранного черновика?',
      many: 'Удалить $count выбранных черновиков?',
      few: 'Удалить $count выбранных черновика?',
      one: 'Удалить $count выбранный черновик?',
    );
    return '$_temp0';
  }

  @override
  String get diaryDraftsDeleteFailed =>
      'Не удалось удалить черновики. Повторите попытку';

  @override
  String get diaryDraftsRestoreFailed =>
      'Не удалось отменить. Повторите попытку';

  @override
  String get diaryDraftPickerTitle => 'Продолжить черновик';

  @override
  String diaryDraftPickerViewAll(int count) {
    return 'Все черновики ($count)';
  }

  @override
  String get diaryDraftPickerNewBlank => 'Новая пустая запись';

  @override
  String get diarySearchPreviewHint => 'Поиск в Jotsy';

  @override
  String backupOverwriteAllTemplates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count шаблона записей',
      many: '$count шаблонов записей',
      few: '$count шаблона записей',
      one: '$count шаблон записи',
    );
    return '$_temp0';
  }

  @override
  String backupImportTemplateMergeResult(int added) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: 'Шаблоны: добавлено $added',
      many: 'Шаблоны: добавлено $added',
      few: 'Шаблоны: добавлено $added',
      one: 'Шаблоны: добавлен $added',
    );
    return '$_temp0';
  }

  @override
  String backupOverwriteAllNotebooks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count блокнота',
      many: '$count блокнотов',
      few: '$count блокнота',
      one: '$count блокнот',
    );
    return '$_temp0';
  }

  @override
  String backupImportNotebookMergeResult(int added) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: 'Блокноты: добавлено $added',
      many: 'Блокноты: добавлено $added',
      few: 'Блокноты: добавлено $added',
      one: 'Блокноты: добавлен $added',
    );
    return '$_temp0';
  }

  @override
  String backupImportModeOverwriteNotebooksExtra(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Также заменяет название, обложку, главы и другие настройки $count блокнота, которые уже есть на устройстве',
      many:
          'Также заменяет название, обложку, главы и другие настройки $count блокнотов, которые уже есть на устройстве',
      few:
          'Также заменяет название, обложку, главы и другие настройки $count блокнотов, которые уже есть на устройстве',
      one:
          'Также заменяет название, обложку, главы и другие настройки $count блокнота, которые уже есть на устройстве',
    );
    return '$_temp0';
  }

  @override
  String get diaryTemplateDailyName => 'Ежедневная запись';

  @override
  String get diaryTemplateDailyDesc =>
      'История сегодняшнего дня и то, что вы чувствуете сейчас';

  @override
  String diaryTemplateDailyTitle(String date, String weekday) {
    return '$weekday, $date';
  }

  @override
  String get diaryTemplateMorningName => 'Утренние страницы';

  @override
  String get diaryTemplateMorningDesc =>
      'Страница на рассвете, чтобы мягко задать дню направление';

  @override
  String diaryTemplateMorningTitle(String date) {
    return 'Утро · $date';
  }

  @override
  String get diaryTemplateEveningName => 'Итоги дня';

  @override
  String get diaryTemplateEveningDesc =>
      'Оглянуться на прошедший день и подготовиться к завтрашнему';

  @override
  String diaryTemplateEveningTitle(String date) {
    return 'Итоги дня · $date';
  }

  @override
  String get diaryTemplateGratitudeName => 'Дневник благодарности';

  @override
  String get diaryTemplateGratitudeDesc =>
      'Три маленьких повода сказать спасибо';

  @override
  String diaryTemplateGratitudeTitle(String date) {
    return 'Благодарность · $date';
  }

  @override
  String get diaryTemplateQuestionName => 'Вопрос дня';

  @override
  String get diaryTemplateQuestionDesc =>
      'Один вопрос в день, чтобы взглянуть на себя по-новому';

  @override
  String diaryTemplateQuestionTitle(String date) {
    return 'Вопрос дня · $date';
  }

  @override
  String get diaryTemplateWeeklyName => 'Итоги недели';

  @override
  String get diaryTemplateWeeklyDesc =>
      'Соберите лучшие моменты недели и налегке шагните в следующую';

  @override
  String diaryTemplateWeeklyTitle(String date) {
    return 'Итоги недели · $date';
  }

  @override
  String get diaryTemplateEmotionName => 'Разобраться в чувствах';

  @override
  String get diaryTemplateEmotionDesc =>
      'Запишите своё чувство и поймите, откуда оно берётся';

  @override
  String diaryTemplateEmotionTitle(String date) {
    return 'Чувства · $date';
  }

  @override
  String get diaryTemplateReadingName => 'Читательский дневник';

  @override
  String get diaryTemplateReadingDesc => 'Цитаты и мысли о прочитанном';

  @override
  String diaryTemplateReadingTitle(String date) {
    return 'Читательский дневник · $date';
  }

  @override
  String get diaryTemplateDailyHappened => 'История дня:';

  @override
  String get diaryTemplateDailyMoment => 'Яркий момент:';

  @override
  String get diaryTemplateDailyMood => 'Что я чувствую сейчас:';

  @override
  String get diaryTemplateDailyWords => 'Одна строчка о сегодняшнем дне:';

  @override
  String diaryTemplateMorningWake(String time, String term) {
    return 'Подъём в $time';
  }

  @override
  String get diaryTemplateMorningTop3 => 'Три самых важных дела на сегодня:';

  @override
  String get diaryTemplateMorningLookForward =>
      'Маленькая радость, которую я жду сегодня:';

  @override
  String get diaryTemplateMorningWords => 'Напутствие на сегодня:';

  @override
  String get diaryTemplateEveningDone => 'Что сделано сегодня:';

  @override
  String get diaryTemplateEveningWentWell => 'Что получилось хорошо:';

  @override
  String get diaryTemplateEveningBetter => 'Что можно улучшить:';

  @override
  String get diaryTemplateEveningTomorrow => 'Планы на завтра:';

  @override
  String get diaryTemplateEveningNight => 'Перед сном хочу сказать себе:';

  @override
  String get diaryTemplateGratitudeThree =>
      'Три повода для благодарности сегодня:';

  @override
  String get diaryTemplateGratitudeThanks => 'Кого хочется поблагодарить:';

  @override
  String get diaryTemplateGratitudeSelf => 'И спасибо себе за сегодня:';

  @override
  String get diaryTemplateQuestionPrompt => 'Вопрос дня:';

  @override
  String get diaryTemplateQuestionAnswer => 'Мой ответ:';

  @override
  String diaryTemplateWeeklyProgress(String week, String progress) {
    return 'Неделя $week · позади уже $progress года';
  }

  @override
  String get diaryTemplateWeeklyHighlights => 'Лучшие моменты недели:';

  @override
  String get diaryTemplateWeeklyWins => 'Успехи и уроки:';

  @override
  String get diaryTemplateWeeklyOpen => 'Ещё в процессе:';

  @override
  String get diaryTemplateWeeklyNext => 'Планы на следующую неделю:';

  @override
  String get diaryTemplateWeeklyNote => 'Записка себе через неделю:';

  @override
  String get diaryTemplateEmotionHappened => 'Что произошло:';

  @override
  String get diaryTemplateEmotionFelt => 'Какие чувства возникли:';

  @override
  String get diaryTemplateEmotionSource => 'Откуда это чувство:';

  @override
  String get diaryTemplateEmotionNeed => 'Что мне на самом деле нужно:';

  @override
  String get diaryTemplateEmotionStep =>
      'Маленький шаг, который можно сделать:';

  @override
  String get diaryTemplateReadingBook => 'Книга: ';

  @override
  String get diaryTemplateReadingAuthor => 'Автор: ';

  @override
  String get diaryTemplateReadingProgress => 'Прочитано до: ';

  @override
  String get diaryTemplateReadingQuotes => 'Цитаты:';

  @override
  String get diaryTemplateReadingThoughts => 'Мои мысли:';

  @override
  String get diaryTemplateTagGratitude => 'Благодарность';

  @override
  String get diaryTemplateTagReading => 'Чтение';

  @override
  String get diaryTemplateQuestion01 =>
      'Какая мелочь заставила вас улыбнуться сегодня?';

  @override
  String get diaryTemplateQuestion02 =>
      'Если бы можно было прожить сегодняшний день заново, что бы вы изменили?';

  @override
  String get diaryTemplateQuestion03 =>
      'Когда вы в последний раз гордились собой?';

  @override
  String get diaryTemplateQuestion04 =>
      'Кому вам больше всего хочется что-то сказать прямо сейчас?';

  @override
  String get diaryTemplateQuestion05 => 'Что нового вы узнали сегодня?';

  @override
  String get diaryTemplateQuestion06 =>
      'Что в последнее время не даёт вам покоя?';

  @override
  String get diaryTemplateQuestion07 => 'Как выглядят ваши идеальные выходные?';

  @override
  String get diaryTemplateQuestion08 =>
      'Был ли сегодня момент, когда вы почувствовали, что вас понимают?';

  @override
  String get diaryTemplateQuestion09 =>
      'Что вы сейчас читаете, смотрите или слушаете? Что это вам даёт?';

  @override
  String get diaryTemplateQuestion10 =>
      'Что вам сейчас нужнее всего: отдых, общение или вызов?';

  @override
  String get diaryTemplateQuestion11 =>
      'О чём вы беспокоились ровно год назад? А сейчас?';

  @override
  String get diaryTemplateQuestion12 => 'Что вы сделали сегодня для себя?';

  @override
  String get diaryTemplateQuestion13 =>
      'Над чем вы в последний раз смеялись от души?';

  @override
  String get diaryTemplateQuestion14 =>
      'Какую привычку вам хотелось бы завести или оставить в прошлом?';

  @override
  String get diaryTemplateQuestion15 => 'Опишите себя сегодня тремя словами.';

  @override
  String get diaryTemplateQuestion16 =>
      'Что было самым трудным сегодня и как вы с этим справились?';

  @override
  String get diaryTemplateQuestion17 =>
      'Кому вы благодарны в последнее время и за что?';

  @override
  String get diaryTemplateQuestion18 =>
      'Если бы завтра можно было сделать только одно дело, что бы это было?';

  @override
  String get diaryTemplateQuestion19 =>
      'Что в последнее время заставило вас изменить своё мнение?';

  @override
  String get diaryTemplateQuestion20 =>
      'О чём вам напоминает сегодняшняя погода?';

  @override
  String get diaryTemplateQuestion21 =>
      'Когда вы в последний раз выходили из зоны комфорта?';

  @override
  String get diaryTemplateQuestion22 =>
      'Как вы будете смотреть на сегодняшние тревоги через десять лет?';

  @override
  String get diaryTemplateQuestion23 =>
      'Запомнились ли вам сегодня чьи-то слова?';

  @override
  String get diaryTemplateQuestion24 =>
      'Где вы в последнее время чувствовали себя спокойнее всего?';

  @override
  String get diaryTemplateQuestion25 => 'Что бы вы сказали себе в детстве?';

  @override
  String get diaryTemplateQuestion26 =>
      'Стали ли вы понимать себя хоть немного лучше, чем вчера?';

  @override
  String get diaryTemplateQuestion27 =>
      'Какой маленький успех последнего времени стоит отпраздновать?';

  @override
  String get diaryTemplateQuestion28 =>
      'Что вы давно хотите попробовать, но так и не начали? Что вас останавливает?';

  @override
  String get diaryTemplateQuestion29 =>
      'Как вы сегодня позаботились о своих чувствах?';

  @override
  String get diaryTemplateQuestion30 =>
      'Если оценить сегодняшний день от 1 до 10, какую оценку вы бы поставили и почему?';

  @override
  String get diaryTemplateVarDateToken => 'дата';

  @override
  String get diaryTemplateVarDateLabel => 'Дата';

  @override
  String get diaryTemplateVarWeekdayToken => 'день_недели';

  @override
  String get diaryTemplateVarWeekdayLabel => 'День недели';

  @override
  String get diaryTemplateVarTimeToken => 'время';

  @override
  String get diaryTemplateVarTimeLabel => 'Время';

  @override
  String get diaryTemplateVarTime12hLabel => 'Время (12-часовой формат)';

  @override
  String get diaryTemplateVarTime12hFormat => 'h:mm a';

  @override
  String get diaryTemplateVarYearToken => 'год';

  @override
  String get diaryTemplateVarYearLabel => 'Год';

  @override
  String get diaryTemplateVarMonthToken => 'месяц';

  @override
  String get diaryTemplateVarMonthLabel => 'Месяц';

  @override
  String get diaryTemplateVarDayToken => 'день';

  @override
  String get diaryTemplateVarDayLabel => 'День';

  @override
  String get diaryTemplateVarWeekToken => 'неделя';

  @override
  String get diaryTemplateVarWeekLabel => 'Номер недели';

  @override
  String get diaryTemplateVarDayOfYearToken => 'день_года';

  @override
  String get diaryTemplateVarDayOfYearLabel => 'День года';

  @override
  String get diaryTemplateVarYearProgressToken => 'прогресс_года';

  @override
  String get diaryTemplateVarYearProgressLabel => 'Прогресс года';

  @override
  String get diaryTemplateVarLunarToken => 'лунная_дата';

  @override
  String get diaryTemplateVarLunarLabel => 'По лунному календарю';

  @override
  String get diaryTemplateVarSolarTermToken => 'сезон';

  @override
  String get diaryTemplateVarSolarTermLabel => 'Сезон китайского календаря';

  @override
  String get diaryTemplateVarQuestionToken => 'вопрос_дня';

  @override
  String get diaryTemplateVarQuestionLabel => 'Вопрос дня';

  @override
  String get diaryTemplateCategoryDaily => 'Повседневное';

  @override
  String get diaryTemplateCategoryReview => 'Итоги';

  @override
  String get diaryTemplateCategoryMood => 'Чувства';

  @override
  String get diaryTemplateCategoryLife => 'Жизнь';

  @override
  String get diaryTemplateCategoryWork => 'Работа';

  @override
  String get diaryTemplateCategoryOther => 'Другое';

  @override
  String get diaryTemplateStripTitle => 'Начать с шаблона';

  @override
  String get diaryTemplateStripAll => 'Все';

  @override
  String get diaryTemplateStripDismiss => 'Скрыть предложения шаблонов';

  @override
  String get diaryTemplateRecommended => 'Рекомендуем';

  @override
  String get diaryTemplateUntitled => 'Шаблон без названия';

  @override
  String diaryTemplateApplied(String name) {
    return 'Применён шаблон «$name»';
  }

  @override
  String diaryTemplateAutoApplied(String name) {
    return 'Автоматически применён шаблон «$name»';
  }

  @override
  String get diaryTemplatePickerTitle => 'Выберите шаблон';

  @override
  String get diaryTemplateFilterAll => 'Все';

  @override
  String get diaryTemplateFilterRecommended => 'Рекомендуемые';

  @override
  String get diaryTemplateFilterMine => 'Мои';

  @override
  String get diaryTemplatePickerEmpty => 'Здесь пока нет шаблонов';

  @override
  String get diaryTemplatePickerSearchHint => 'Поиск шаблонов';

  @override
  String diaryTemplatePickerSearchEmpty(String query) {
    return 'Нет шаблонов по запросу «$query»';
  }

  @override
  String get diaryTemplatePickerUse => 'Использовать шаблон';

  @override
  String get diaryTemplatePickerShuffle => 'Другой вопрос';

  @override
  String get diaryTemplatePickerPreviewHint =>
      'Даты и вопросы уже подставлены для этой записи.';

  @override
  String diaryTemplatePresetCapsule(String when) {
    return 'Капсула времени: $when';
  }

  @override
  String diaryTemplatePresetEnergy(int level) {
    return 'Энергия $level/5';
  }

  @override
  String get diaryTemplateEditedBadge => 'Изменён';

  @override
  String get diaryDraftPickerFromTemplate => 'Создать из шаблона';

  @override
  String get diaryTemplatesTitle => 'Шаблоны записей';

  @override
  String diaryTemplatesSettingsSubtitle(int builtIn, int mine) {
    return 'Встроенных: $builtIn · своих: $mine';
  }

  @override
  String get diaryTemplatesNewEntryGroup => 'Новые записи';

  @override
  String get diaryTemplatesStripSwitch =>
      'Предлагать шаблоны для новых записей';

  @override
  String get diaryTemplatesStripSwitchSubtitle =>
      'Показывать «Начать с шаблона» под заголовком пустой записи';

  @override
  String get diaryTemplatesAutoApply => 'Применять автоматически';

  @override
  String get diaryTemplatesAutoApplyNone => 'Выключено';

  @override
  String get diaryTemplatesAutoApplyHint =>
      'Вне заданных интервалов времени, а также при записи за другой день новые пустые записи начинаются с этого шаблона. Каждый раз это можно отменить.';

  @override
  String diaryTemplatesAutoApplyRulesSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count интервала времени',
      many: '$count интервалов времени',
      few: '$count интервала времени',
      one: '$count интервал времени',
    );
    return '$_temp0';
  }

  @override
  String diaryTemplatesAutoApplyRulesAndDefault(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count интервала времени',
      many: '$count интервалов времени',
      few: '$count интервала времени',
      one: '$count интервал времени',
    );
    return '$_temp0 · в остальное время «$name»';
  }

  @override
  String get diaryTemplatesAutoApplyIntro =>
      'Новые пустые записи начинаются с шаблона, и каждый раз это можно отменить. Интервалы времени действуют, только когда вы пишете за сегодня.';

  @override
  String get diaryTemplatesAutoApplyRulesGroup => 'По времени суток';

  @override
  String get diaryTemplatesAutoApplyOtherGroup => 'В остальное время';

  @override
  String get diaryTemplatesAutoApplyDefault => 'Шаблон по умолчанию';

  @override
  String get diaryTemplatesAutoApplyAddRule => 'Добавить интервал';

  @override
  String diaryTemplatesAutoApplyRuleLimit(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'Не более $max интервала',
      many: 'Не более $max интервалов',
      few: 'Не более $max интервалов',
      one: 'Не более $max интервала',
    );
    return '$_temp0';
  }

  @override
  String get diaryTemplatesAutoApplyOverlapHint =>
      'Если интервалы пересекаются, приоритет у заданных на определённые дни недели, затем — у более коротких.';

  @override
  String diaryTemplatesAutoApplyRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String diaryTemplatesAutoApplyRangeOvernight(String start, String end) {
    return '$start – $end следующего дня';
  }

  @override
  String diaryTemplatesAutoApplyRuleSubtitle(String days, String name) {
    return '$days · $name';
  }

  @override
  String get diaryTemplatesAutoApplyEveryDay => 'Каждый день';

  @override
  String get diaryTemplatesAutoApplyWorkdays => 'Будни';

  @override
  String get diaryTemplatesAutoApplyWeekend => 'Выходные';

  @override
  String get diaryTemplatesAutoApplyDaySeparator => ', ';

  @override
  String get diaryTemplatesAutoApplyMissing => 'Шаблон больше не существует';

  @override
  String get diaryTemplatesAutoApplyEditRule => 'Изменить интервал';

  @override
  String get diaryTemplatesAutoApplyStart => 'Начало';

  @override
  String get diaryTemplatesAutoApplyEnd => 'Конец';

  @override
  String diaryTemplatesAutoApplyOvernightHint(String end) {
    return 'Через полночь, заканчивается в $end следующего дня';
  }

  @override
  String get diaryTemplatesAutoApplySameTime =>
      'Начало и конец не могут совпадать';

  @override
  String get diaryTemplatesAutoApplyDays => 'Дни недели';

  @override
  String get diaryTemplatesAutoApplyDaysHint =>
      'Если ничего не выбрано — каждый день';

  @override
  String get diaryTemplatesAutoApplyTemplate => 'Шаблон';

  @override
  String get diaryTemplatesAutoApplyRuleDeleted => 'Интервал удалён';

  @override
  String get diaryTemplatesMineGroup => 'Мои шаблоны';

  @override
  String get diaryTemplatesBuiltInGroup => 'Встроенные шаблоны';

  @override
  String get diaryTemplatesMineEmpty =>
      'Своих шаблонов пока нет. Создайте новый кнопкой «+» или отредактируйте встроенный.';

  @override
  String get diaryTemplatesNew => 'Новый шаблон';

  @override
  String get diaryTemplatesImport => 'Импортировать код шаблона';

  @override
  String get diaryTemplatesMoreActions => 'Другие действия';

  @override
  String get diaryTemplatesDuplicate => 'Дублировать';

  @override
  String get diaryTemplatesCopyCode => 'Копировать код шаблона';

  @override
  String get diaryTemplatesResetBuiltIn => 'Восстановить исходный';

  @override
  String get diaryTemplatesRestoreDeleted =>
      'Восстановить удалённые встроенные';

  @override
  String diaryTemplatesRestoreDeletedCount(int count) {
    return '$count';
  }

  @override
  String get diaryTemplatesRestoreSheetTitle => 'Удалённые встроенные шаблоны';

  @override
  String get diaryTemplatesRestoreSheetHint =>
      'Восстановленные шаблоны вернутся в список встроенных вместе со всеми изменениями, сделанными до удаления.';

  @override
  String get diaryTemplatesRestore => 'Восстановить';

  @override
  String get diaryTemplatesRestoreAll => 'Восстановить все';

  @override
  String diaryTemplatesCopyName(String name) {
    return '$name (копия)';
  }

  @override
  String diaryTemplatesDeleted(String name) {
    return 'Шаблон «$name» удалён';
  }

  @override
  String diaryTemplatesResetDone(String name) {
    return 'Шаблон «$name» восстановлен в исходном виде';
  }

  @override
  String diaryTemplatesRestoredDone(String name) {
    return 'Шаблон «$name» восстановлен';
  }

  @override
  String diaryTemplatesRestoredAllDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Восстановлено $count встроенного шаблона',
      many: 'Восстановлено $count встроенных шаблонов',
      few: 'Восстановлено $count встроенных шаблона',
      one: 'Восстановлен $count встроенный шаблон',
    );
    return '$_temp0';
  }

  @override
  String get diaryTemplatesCodeCopied => 'Код шаблона скопирован';

  @override
  String get diaryTemplatesCodeTooLong =>
      'Шаблон слишком длинный для кода шаблона';

  @override
  String get diaryTemplatesImportEmpty => 'В буфере обмена нет кода шаблона';

  @override
  String get diaryTemplatesImportInvalid => 'Это недействительный код шаблона';

  @override
  String diaryTemplatesImported(String name) {
    return 'Шаблон «$name» импортирован';
  }

  @override
  String diaryTemplatesImportedNewer(String name) {
    return 'Шаблон «$name» импортирован. Он создан в более новой версии приложения, поэтому некоторые настройки могут не примениться.';
  }

  @override
  String get diaryTemplatesSaveFailed =>
      'Не удалось сохранить шаблон. Повторите попытку';

  @override
  String get diaryTemplateEditorNewTitle => 'Новый шаблон';

  @override
  String get diaryTemplateEditorEditTitle => 'Изменить шаблон';

  @override
  String get diaryTemplateEditorTabContent => 'Содержимое';

  @override
  String get diaryTemplateEditorTabSettings => 'Настройки';

  @override
  String get diaryTemplateEditorTitleHint => 'Заголовок (можно с переменными)';

  @override
  String get diaryTemplateEditorBodyHint =>
      'Напишите текст. Подзаголовки, списки и списки задач сохранятся.';

  @override
  String get diaryTemplateEditorAllVariables => 'Все переменные';

  @override
  String get diaryTemplateEditorVariablesTitle => 'Вставить переменную';

  @override
  String get diaryTemplateEditorVariablesHint =>
      'При применении шаблона переменные заполняются по дате записи. Даты лунного календаря и сезоны китайского календаря выводятся на китайском.';

  @override
  String diaryTemplateEditorTimeFormatHint(String example) {
    return 'Для времени после двоеточия можно указать формат, например $example: H — часы (h — в 12-часовом формате), mm — минуты, ss — секунды, a — AM/PM; другие буквы заключайте в одинарные кавычки. Нераспознанный формат остаётся как есть.';
  }

  @override
  String diaryTemplateEditorVariableExample(String example) {
    return 'Сегодня: $example';
  }

  @override
  String get diaryTemplateEditorName => 'Название';

  @override
  String get diaryTemplateEditorNameRequired => 'Укажите название шаблона';

  @override
  String get diaryTemplateEditorDescription => 'Краткое описание';

  @override
  String get diaryTemplateEditorLook => 'Внешний вид';

  @override
  String get diaryTemplateEditorCategory => 'Категория';

  @override
  String get diaryTemplateEditorIcon => 'Значок';

  @override
  String get diaryTemplateEditorAccent => 'Цвет';

  @override
  String get diaryTemplateEditorAccentTheme => 'Цвет темы';

  @override
  String get diaryTemplateEditorPresets => 'Также задать при применении';

  @override
  String get diaryTemplateEditorTags => 'Теги';

  @override
  String get diaryTemplateEditorAddTag => 'Добавить тег';

  @override
  String get diaryTemplateEditorNewTag => 'Новый тег';

  @override
  String get diaryTemplateEditorTagsHint =>
      'Теги сопоставляются по названию. Отсутствующие будут созданы при применении шаблона.';

  @override
  String get diaryTemplateEditorMood => 'Настроение';

  @override
  String get diaryTemplateEditorNone => 'Не задано';

  @override
  String get diaryTemplateEditorEnergy => 'Энергия';

  @override
  String get diaryTemplateEditorCapsule => 'Капсула времени';

  @override
  String get diaryTemplateEditorCapsuleHint =>
      'Отсчитывается со дня применения шаблона; до публикации это можно изменить.';

  @override
  String get diaryTemplateEditorRecommend => 'Когда предлагать';

  @override
  String get diaryTemplateEditorRecommendHint =>
      'Шаблон поднимется в начало предложений, когда выполнены условия каждой выбранной группы. Внутри группы достаточно любого из выбранных вариантов.';

  @override
  String get diaryTemplateEditorSlots => 'Время суток';

  @override
  String get diaryTemplateEditorWeekdays => 'Дни недели';

  @override
  String get diaryTemplateEditorMonth => 'Часть месяца';

  @override
  String get diaryTemplateSlotMorning => 'Утро';

  @override
  String get diaryTemplateSlotAfternoon => 'День';

  @override
  String get diaryTemplateSlotEvening => 'Вечер';

  @override
  String get diaryTemplateSlotNight => 'Ночь';

  @override
  String get diaryTemplateMonthStart => 'Первые 3 дня';

  @override
  String get diaryTemplateMonthEnd => 'Последние 3 дня';

  @override
  String get diaryTemplateSaveAs => 'Сохранить как шаблон';

  @override
  String get diaryTemplateSaveAsMediaDropped =>
      'Изображения, аудиозаписи и другие медиафайлы не сохраняются в шаблонах';

  @override
  String get diaryEditorMoreActions => 'Ещё';

  @override
  String get diaryTemplateChoose => 'Выбрать шаблон';

  @override
  String get diaryTemplateNeedsBlankEntry =>
      'Шаблон можно применить только к пустой записи';

  @override
  String get notebookTitle => 'Блокноты';

  @override
  String get notebookNew => 'Новый блокнот';

  @override
  String get notebookEditTitle => 'Редактирование блокнота';

  @override
  String get notebookManage => 'Управление';

  @override
  String get notebookSubSectionTitle => 'Вложенные блокноты';

  @override
  String get notebookSubCreateShort => 'Создать';

  @override
  String notebookSubMore(int count) {
    return 'Ещё $count';
  }

  @override
  String get notebookSubMoreHint => 'Показать все';

  @override
  String notebookSubMoreSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count вложенного блокнота',
      many: '$count вложенных блокнотов',
      few: '$count вложенных блокнота',
      one: '$count вложенный блокнот',
    );
    return 'Показать ещё $_temp0';
  }

  @override
  String get notebookSubLess => 'Свернуть';

  @override
  String get notebookSubLessSemantics => 'Свернуть вложенные блокноты';

  @override
  String get notebookSubCreate => 'Создать вложенный блокнот';

  @override
  String notebookSubCountSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Содержит $count вложенного блокнота',
      many: 'Содержит $count вложенных блокнотов',
      few: 'Содержит $count вложенных блокнота',
      one: 'Содержит $count вложенный блокнот',
    );
    return '$_temp0';
  }

  @override
  String notebookNestGoUp(String name) {
    return 'Перейти в «$name»';
  }

  @override
  String get notebookNestPathSeparator => ' › ';

  @override
  String get notebookParentLabel => 'Родительский блокнот';

  @override
  String get notebookParentNone => 'Нет (на полке)';

  @override
  String get notebookParentFooter =>
      'Записи из этого блокнота видны и при открытии родительского. Не более трёх уровней; умный блокнот можно вложить в другой, но в него нельзя вкладывать блокноты.';

  @override
  String get notebookParentPickerEmpty =>
      'Некуда вложить: допускается не более трёх уровней, а в умные блокноты нельзя вкладывать другие';

  @override
  String notebookParentPrivacyHidden(String name) {
    return 'Родительский блокнот «$name» скрыт из раздела «Все записи», поэтому этот блокнот тоже скрыт';
  }

  @override
  String notebookParentPrivacyLocked(String name) {
    return 'Родительский блокнот «$name» заблокирован, поэтому этот блокнот тоже заблокирован';
  }

  @override
  String get notebookNestMove => 'Переместить…';

  @override
  String get notebookNestMoveHint =>
      'Вложить в другой блокнот или вернуть на полку';

  @override
  String notebookNestMoved(String name) {
    return 'Блокнот перемещён в «$name»';
  }

  @override
  String get notebookNestMovedToShelf => 'Блокнот возвращён на полку';

  @override
  String notebookNestDeleteChildrenHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count вложенного блокнота переместятся на уровень выше и не будут удалены',
      many:
          '$count вложенных блокнотов переместятся на уровень выше и не будут удалены',
      few:
          '$count вложенных блокнота переместятся на уровень выше и не будут удалены',
      one:
          '$count вложенный блокнот переместится на уровень выше и не будет удалён',
    );
    return '$_temp0';
  }

  @override
  String get notebookAllDiaries => 'Все записи';

  @override
  String get notebookUnfiled => 'Без блокнота';

  @override
  String get notebookSectionPinned => 'Закреплённые';

  @override
  String get notebookSectionMine => 'Мои блокноты';

  @override
  String get notebookSectionSmart => 'Умные блокноты';

  @override
  String get notebookSectionClosed => 'Закрытые';

  @override
  String notebookEntryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи',
      many: '$count записей',
      few: '$count записи',
      one: '$count запись',
    );
    return '$_temp0';
  }

  @override
  String get notebookSemanticsSeparator => ', ';

  @override
  String get notebookEmptyHint =>
      'Собирайте записи на разные темы и за разное время в одном блокноте';

  @override
  String get notebookMissing => 'Этот блокнот больше не существует';

  @override
  String get notebookNameLabel => 'Название';

  @override
  String get notebookNameHint => 'Например, «Путешествия»';

  @override
  String get notebookDescriptionLabel => 'Описание';

  @override
  String get notebookDescriptionHint =>
      'Опишите блокнот одним предложением (необязательно)';

  @override
  String get notebookIconLabel => 'Значок';

  @override
  String get notebookIconMore => 'Ещё значки';

  @override
  String get notebookIconLess => 'Свернуть';

  @override
  String get notebookColorLabel => 'Цвет';

  @override
  String get notebookColorFollowTheme => 'Как в теме';

  @override
  String get notebookCoverLabel => 'Изображение обложки';

  @override
  String get notebookCoverPick => 'Выбрать изображение';

  @override
  String get notebookCoverRemove => 'Удалить';

  @override
  String get notebookCoverSectionTitle => 'Обложка';

  @override
  String get notebookCoverLayoutTitle => 'Макет';

  @override
  String get notebookCoverLayoutClassic => 'Классический';

  @override
  String get notebookCoverLayoutFullBleed => 'Во всю обложку';

  @override
  String get notebookCoverLayoutSpine => 'Корешок';

  @override
  String get notebookCoverLayoutPlate => 'Этикетка';

  @override
  String get notebookCoverLayoutMinimal => 'Минимализм';

  @override
  String get notebookCoverTextureTitle => 'Текстура';

  @override
  String get notebookCoverTextureNone => 'Нет';

  @override
  String get notebookCoverTextureDots => 'Точки';

  @override
  String get notebookCoverTextureLines => 'Линейка';

  @override
  String get notebookCoverTextureGrid => 'Клетка';

  @override
  String get notebookCoverTextureDiagonal => 'Диагональ';

  @override
  String get notebookCoverFromDiaries => 'Из записей';

  @override
  String get notebookCoverAdjustCrop => 'Настроить кадр';

  @override
  String get notebookCoverCropDone => 'Готово';

  @override
  String get notebookCoverCropHint =>
      'Перетаскивайте, чтобы сдвинуть, и масштабируйте двумя пальцами';

  @override
  String get notebookCoverCropHintDesktop =>
      'Перетаскивайте, чтобы сдвинуть, и масштабируйте колёсиком мыши';

  @override
  String get notebookCoverCropZoom => 'Масштаб';

  @override
  String get notebookCoverCropLoadFailed => 'Не удалось загрузить изображение';

  @override
  String get notebookCoverPhotosTitle => 'Обложка из записей';

  @override
  String get notebookCoverPhotosSubtitle =>
      'Изображения из записей этого блокнота (включая вложенные), сначала новые';

  @override
  String get notebookCoverPhotosEmpty =>
      'В записях этого блокнота пока нет изображений';

  @override
  String notebookCoverPhotoItem(int index) {
    return 'Изображение $index';
  }

  @override
  String get notebookTypeLabel => 'Тип';

  @override
  String get notebookTypeManual => 'Обычный';

  @override
  String get notebookTypeSmart => 'Умный';

  @override
  String get notebookTypeManualHint =>
      'Вы сами выбираете, какие записи добавить';

  @override
  String get notebookTypeSmartHint =>
      'Автоматически собирает записи, подходящие под условия';

  @override
  String get notebookPrivacyLabel => 'Конфиденциальность';

  @override
  String get notebookPrivacyNormal => 'Без ограничений';

  @override
  String get notebookPrivacyHidden => 'Скрыть из раздела «Все записи»';

  @override
  String get notebookPrivacyHiddenHint =>
      'Записи видны только внутри этого блокнота';

  @override
  String get notebookPrivacyLocked => 'Блокировка';

  @override
  String get notebookPrivacyLockedHint =>
      'Для открытия нужно подтвердить личность; записи скрыты из раздела «Все записи»';

  @override
  String get notebookSortLabel => 'Порядок по умолчанию';

  @override
  String get notebookSortCreatedDesc => 'По дате публикации, сначала новые';

  @override
  String get notebookSortCreatedAsc => 'По дате публикации, сначала старые';

  @override
  String get notebookSortCreatedAscHint => 'Читается как книга';

  @override
  String get notebookSortUpdatedDesc => 'Недавно изменённые';

  @override
  String get notebookSortBook => 'Как в оглавлении';

  @override
  String get notebookSortBookHint => 'Порядок задаётся вручную в оглавлении';

  @override
  String get notebookTemplateLabel => 'Шаблон для новых записей';

  @override
  String get notebookTemplateNone => 'Без шаблона';

  @override
  String get notebookSaveFailed => 'Не удалось сохранить. Повторите попытку';

  @override
  String get notebookActionFailed => 'Что-то пошло не так. Повторите попытку';

  @override
  String get notebookMoreActions => 'Другие действия';

  @override
  String notebookSubCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count вложенного блокнота',
      many: '$count вложенных блокнотов',
      few: '$count вложенных блокнота',
      one: '$count вложенный блокнот',
    );
    return '$_temp0';
  }

  @override
  String get notebookSubCollapse => 'Свернуть вложенные блокноты';

  @override
  String get notebookSubExpand => 'Развернуть вложенные блокноты';

  @override
  String get notebookCollapseAll => 'Свернуть все';

  @override
  String get notebookExpandAll => 'Развернуть все';

  @override
  String get notebookStatePinned => 'Закреплён';

  @override
  String get notebookStateSmart => 'Умный';

  @override
  String get notebookStateHidden => 'Скрыт';

  @override
  String get notebookStateLocked => 'Заблокирован';

  @override
  String get notebookStateClosed => 'Закрыт';

  @override
  String get notebookActionPin => 'Закрепить';

  @override
  String get notebookActionUnpin => 'Открепить';

  @override
  String get notebookActionClose => 'Закрыть';

  @override
  String get notebookActionCloseHint =>
      'Блокнот уйдёт в «Закрытые» на полке и перестанет предлагаться при добавлении записей';

  @override
  String get notebookActionReopen => 'Открыть снова';

  @override
  String get notebookActionMerge => 'Объединить с…';

  @override
  String get notebookActionConvert => 'Преобразовать в обычный блокнот';

  @override
  String get notebookActionConvertHint =>
      'Добавит записи, подходящие сейчас, и перестанет обновляться автоматически';

  @override
  String get notebookMergeSheetTitle => 'С каким блокнотом объединить';

  @override
  String get notebookMergeEmpty =>
      'Нет другого обычного блокнота для объединения';

  @override
  String get notebookMergeConfirmTitle => 'Объединение блокнотов';

  @override
  String notebookMergeConfirm(String source, int count, String target) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи',
      many: '$count записей',
      few: '$count записи',
      one: '$count запись',
    );
    return 'Переместить $_temp0 из «$source» в «$target» и удалить «$source»?';
  }

  @override
  String get notebookMergeAction => 'Объединить';

  @override
  String notebookMerged(String target) {
    return 'Объединено с «$target»';
  }

  @override
  String notebookDeleteTitle(String name) {
    return 'Удалить «$name»?';
  }

  @override
  String get notebookDeleteKeepDiaries => 'Удалить только блокнот';

  @override
  String notebookDeleteKeepDiariesHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи останутся',
      many: '$count записей останутся',
      few: '$count записи останутся',
      one: '$count запись останется',
    );
    return '$_temp0 в разделе «Все записи»';
  }

  @override
  String get notebookDeleteWithDiaries => 'Переместить и записи в корзину';

  @override
  String get notebookDeleteWithDiariesHint =>
      'Их можно будет восстановить из корзины';

  @override
  String get notebookDeleteSmartHint => 'Записи не будут затронуты';

  @override
  String notebookDeleted(String name) {
    return 'Блокнот «$name» удалён';
  }

  @override
  String notebookSwitcherSemantics(String name) {
    return 'Сменить блокнот, текущий: $name';
  }

  @override
  String get notebookScopeDeleted => 'Блокнот удалён';

  @override
  String notebookSearchIn(String name) {
    return 'Поиск в «$name»';
  }

  @override
  String notebookSearchRemoveScope(String name) {
    return 'Убрать условие по блокноту: $name';
  }

  @override
  String notebookMetaWords(String words) {
    return 'Слов: $words';
  }

  @override
  String notebookMetaSpan(String start, String end) {
    return '$start – $end';
  }

  @override
  String notebookMetaSpanOngoing(String start) {
    return '$start – сейчас';
  }

  @override
  String get notebookHeaderSmartBadge => 'Умный блокнот';

  @override
  String get notebookHeaderPrivateBadge => 'Только в этом блокноте';

  @override
  String get notebookEmptyTitle => 'Блокнот пока пуст';

  @override
  String get notebookEmptyCreateHint =>
      'Нажмите кнопку внизу, чтобы написать первую запись';

  @override
  String notebookUnlockReason(String name) {
    return 'Разблокировать «$name»';
  }

  @override
  String get notebookLockUnsupportedTitle =>
      'Не удаётся открыть заблокированный блокнот';

  @override
  String get notebookLockUnsupportedMessage =>
      'На этом устройстве не настроена блокировка экрана, поэтому подтвердить личность невозможно и заблокированные блокноты не открываются. Настройте блокировку экрана в системных настройках или перейдите на код приложения в разделе Настройки → Блокировка и код.';

  @override
  String get notebookLockUnsupportedAction => 'Понятно';

  @override
  String notebookLockedTitle(String name) {
    return 'Блокнот «$name» заблокирован';
  }

  @override
  String get notebookLockedSubtitle =>
      'После выхода из приложения нужно снова подтвердить личность';

  @override
  String get notebookLockUnlock => 'Разблокировать';

  @override
  String get notebookLockBackToAll => 'Ко всем записям';

  @override
  String get notebookPrivateDiaryPlaceholder => 'Запись из личного блокнота';

  @override
  String get notebookAnniversaryLinkPrivate =>
      'Связанная запись находится в личном блокноте';

  @override
  String get backupImportFolderModeTitle => 'Исходные блокноты / папки';

  @override
  String get backupImportFolderModeNotebooks => 'Блокноты';

  @override
  String get backupImportFolderModeTags => 'Теги';

  @override
  String get backupImportFolderModeBoth => 'Оба';

  @override
  String backupImportFolderModeNotebooksHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Из исходных блокнотов / папок ($count) будут созданы блокноты; одноимённые объединятся с уже существующими',
      many:
          'Из исходных блокнотов / папок ($count) будут созданы блокноты; одноимённые объединятся с уже существующими',
      few:
          'Из исходных блокнотов / папок ($count) будут созданы блокноты; одноимённые объединятся с уже существующими',
      one:
          'Из исходных блокнотов / папок ($count) будут созданы блокноты; одноимённые объединятся с уже существующими',
    );
    return '$_temp0';
  }

  @override
  String get backupImportFolderModeTagsHint =>
      'Как и раньше, станут тегами с теми же названиями';

  @override
  String get backupImportFolderModeBothHint =>
      'Будут созданы блокноты и одноимённые теги';

  @override
  String get notebookEmptyManualHint =>
      'Напишите первую запись или выберите несколько из уже существующих';

  @override
  String get notebookEmptyWriteFirst => 'Написать первую запись';

  @override
  String get notebookEmptyPickExisting => 'Выбрать из существующих';

  @override
  String get notebookAddDiaries => 'Добавить записи';

  @override
  String get notebookExportAsBook => 'Экспортировать как книгу';

  @override
  String notebookBookExportedOn(String date) {
    return 'Экспортировано $date';
  }

  @override
  String get diaryExportBookStructure => 'Структура книги';

  @override
  String get diaryExportBookStructureDescription =>
      'Титульный лист, оглавление и заголовки глав';

  @override
  String get notebookContentsUnassignedDropHint =>
      'Перетащите сюда, чтобы убрать записи из глав';

  @override
  String get notebookChapterAll => 'Все';

  @override
  String get notebookChapterUnassigned => 'Без главы';

  @override
  String notebookChapterChip(String title, int count) {
    return '$title · $count';
  }

  @override
  String get notebookContents => 'Оглавление';

  @override
  String get notebookContentsNewChapter => 'Новая глава';

  @override
  String get notebookContentsSelect => 'Выбрать';

  @override
  String get notebookContentsSelectDone => 'Завершить выбор';

  @override
  String notebookContentsSelectedCount(int count) {
    return 'Выбрано: $count';
  }

  @override
  String get notebookContentsNoChapterHint =>
      'Добавьте главы, чтобы разделить блокнот на части';

  @override
  String get notebookContentsEmpty => 'В этом блокноте пока нет записей';

  @override
  String get notebookContentsArchived => 'В архиве';

  @override
  String get notebookContentsSealed => 'Запечатанная капсула времени';

  @override
  String get notebookContentsChapterActions => 'Действия с главой';

  @override
  String get notebookChapterRename => 'Переименовать';

  @override
  String get notebookChapterRenameTitle => 'Переименовать главу';

  @override
  String get notebookChapterMoveUp => 'Переместить вверх';

  @override
  String get notebookChapterMoveDown => 'Переместить вниз';

  @override
  String get notebookChapterCollapse => 'Свернуть главу';

  @override
  String get notebookChapterExpand => 'Развернуть главу';

  @override
  String get notebookChapterTitleLabel => 'Название главы';

  @override
  String get notebookChapterTitleHint => 'Например, «Токио»';

  @override
  String notebookChapterDeleteConfirm(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Удалить главу «$title»? Её $count записи вернутся в раздел «Без главы»; сами записи не удаляются.',
      many:
          'Удалить главу «$title»? Её $count записей вернутся в раздел «Без главы»; сами записи не удаляются.',
      few:
          'Удалить главу «$title»? Её $count записи вернутся в раздел «Без главы»; сами записи не удаляются.',
      one:
          'Удалить главу «$title»? Её $count запись вернётся в раздел «Без главы»; сами записи не удаляются.',
    );
    return '$_temp0';
  }

  @override
  String get notebookContentsMoveToChapter => 'Переместить в главу…';

  @override
  String get notebookContentsMoveSheetTitle => 'Переместить в главу';

  @override
  String notebookContentsMoved(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи перемещено в «$title»',
      many: '$count записей перемещено в «$title»',
      few: '$count записи перемещены в «$title»',
      one: '$count запись перемещена в «$title»',
    );
    return '$_temp0';
  }

  @override
  String get notebookPickerTitle => 'Добавить в блокнот';

  @override
  String get notebookPickerEmpty =>
      'Пока нет блокнотов, куда можно добавить записи';

  @override
  String get notebookPickerDone => 'Готово';

  @override
  String notebookPickerPrivateHint(String name) {
    return 'Добавлено в «$name». Теперь эти записи видны только в этом блокноте';
  }

  @override
  String get notebookSelectionMore => 'Другие действия';

  @override
  String get notebookRemoveFromCurrent => 'Убрать из этого блокнота';

  @override
  String get notebookMoveTo => 'Переместить в…';

  @override
  String notebookAddedToCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Добавлено в $count блокнота',
      many: 'Добавлено в $count блокнотов',
      few: 'Добавлено в $count блокнота',
      one: 'Добавлено в $count блокнот',
    );
    return '$_temp0';
  }

  @override
  String get notebookMembershipUpdated => 'Блокноты обновлены';

  @override
  String notebookRemovedFrom(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Из «$name» убрано $count записи',
      many: 'Из «$name» убрано $count записей',
      few: 'Из «$name» убраны $count записи',
      one: 'Из «$name» убрана $count запись',
    );
    return '$_temp0';
  }

  @override
  String notebookMovedTo(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи перемещено в «$name»',
      many: '$count записей перемещено в «$name»',
      few: '$count записи перемещены в «$name»',
      one: '$count запись перемещена в «$name»',
    );
    return '$_temp0';
  }

  @override
  String get notebookPublishNone => 'Без блокнота';

  @override
  String notebookWriteInto(String name) {
    return 'Написать в «$name»';
  }

  @override
  String notebookAddPageTitle(String name) {
    return 'Добавить в «$name»';
  }

  @override
  String notebookAddPageDone(int count) {
    return 'Готово ($count)';
  }

  @override
  String get notebookAddSearchHint => 'Поиск записей';

  @override
  String get notebookAddFilterAll => 'Все';

  @override
  String get notebookAddFilterRecent => 'За 30 дней';

  @override
  String get notebookAddFilterThisYear => 'Этот год';

  @override
  String get notebookAddAlreadyIn => 'Уже в этом блокноте';

  @override
  String notebookAddedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Добавлено $count записи',
      many: 'Добавлено $count записей',
      few: 'Добавлены $count записи',
      one: 'Добавлена $count запись',
    );
    return '$_temp0';
  }

  @override
  String get notebookAddEmpty => 'Нет подходящих записей';

  @override
  String get notebookPreviewNone => 'Пока не входит ни в один блокнот';

  @override
  String get notebookListSeparator => ', ';

  @override
  String notebookOpenNotebook(String name) {
    return 'Открыть «$name»';
  }

  @override
  String get notebookRulesTitle => 'Условия';

  @override
  String get notebookRulesMatchAll => 'Все условия';

  @override
  String get notebookRulesMatchAny => 'Любое условие';

  @override
  String notebookRulesMatchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Подходит $count записи',
      many: 'Подходит $count записей',
      few: 'Подходят $count записи',
      one: 'Подходит $count запись',
    );
    return '$_temp0';
  }

  @override
  String get notebookRulesNeedOne =>
      'Чтобы сохранить, добавьте хотя бы одно условие';

  @override
  String notebookRulesLimit(int max) {
    return 'Максимум условий: $max';
  }

  @override
  String get notebookRulesExamples => 'Начните с примера';

  @override
  String get notebookRuleExampleRecent => 'Последние 30 дней';

  @override
  String get notebookRuleExampleThisMonth => 'Этот месяц каждого года';

  @override
  String get notebookRuleExampleImages => 'Записи с фото';

  @override
  String get notebookRuleExamplePinned => 'Закреплённые записи';

  @override
  String get notebookRuleAdd => 'Добавить условие';

  @override
  String get notebookRuleRemove => 'Удалить условие';

  @override
  String get notebookRuleDone => 'Готово';

  @override
  String get notebookRuleTypeTags => 'Теги';

  @override
  String get notebookRuleTypeTagsHint =>
      'Содержит или не содержит определённые теги';

  @override
  String get notebookRuleTypeMood => 'Настроение';

  @override
  String get notebookRuleTypeMoodHint => 'Настроение — одно из выбранных';

  @override
  String get notebookRuleTypeWeather => 'Погода';

  @override
  String get notebookRuleTypeWeatherHint => 'Погода содержит указанный текст';

  @override
  String get notebookRuleTypeLocation => 'Место';

  @override
  String get notebookRuleTypeLocationHint => 'Место содержит указанный текст';

  @override
  String get notebookRuleTypeKeyword => 'Ключевое слово';

  @override
  String get notebookRuleTypeKeywordHint =>
      'Заголовок или текст содержит указанные слова';

  @override
  String get notebookRuleTypeDate => 'Дата';

  @override
  String get notebookRuleTypeDateHint =>
      'Диапазон дат, последние дни или период каждого года';

  @override
  String get notebookRuleTypeMedia => 'Медиафайлы';

  @override
  String get notebookRuleTypeMediaHint =>
      'Есть фото, аудиозаписи, видео или вложения';

  @override
  String get notebookRuleTypeFlag => 'Обложка и закрепление';

  @override
  String get notebookRuleTypeFlagHint => 'Есть обложка или запись закреплена';

  @override
  String get notebookRuleTagAny => 'Любой из';

  @override
  String get notebookRuleTagAll => 'Все из';

  @override
  String get notebookRuleTagNone => 'Ни один из';

  @override
  String get notebookRuleNoTags => 'Тегов пока нет';

  @override
  String get notebookRuleWeatherHint => 'Например, дождь';

  @override
  String get notebookRuleLocationHint => 'Например, Киото';

  @override
  String get notebookRuleKeywordHint => 'Слова из заголовка или текста';

  @override
  String get notebookRuleDateBetween => 'Диапазон дат';

  @override
  String get notebookRuleDateLastDays => 'Последние дни';

  @override
  String get notebookRuleDateThisYear => 'Этот год';

  @override
  String get notebookRuleDateMonth => 'Месяц каждого года';

  @override
  String get notebookRuleDateToday => 'Этот день каждого года';

  @override
  String get notebookRuleDateTodayHint =>
      'Записи за этот же день и месяц любого года';

  @override
  String notebookRuleDaysValue(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days дня',
      many: '$days дней',
      few: '$days дня',
      one: '$days день',
    );
    return '$_temp0';
  }

  @override
  String get notebookRuleDaysDecrease => 'На день меньше';

  @override
  String get notebookRuleDaysIncrease => 'На день больше';

  @override
  String get notebookRuleMediaImage => 'Есть фото';

  @override
  String get notebookRuleMediaAudio => 'Есть аудиозаписи';

  @override
  String get notebookRuleMediaVideo => 'Есть видео';

  @override
  String get notebookRuleMediaAttachment => 'Есть вложения';

  @override
  String get notebookRuleFlagCover => 'Есть обложка';

  @override
  String get notebookRuleFlagPinned => 'Закреплена';

  @override
  String notebookRuleSummaryTagsAny(String tags) {
    return 'Теги, любой из: $tags';
  }

  @override
  String notebookRuleSummaryTagsAll(String tags) {
    return 'Теги, все из: $tags';
  }

  @override
  String notebookRuleSummaryTagsNone(String tags) {
    return 'Теги, ни один из: $tags';
  }

  @override
  String notebookRuleSummaryMood(String moods) {
    return 'Настроение: $moods';
  }

  @override
  String notebookRuleSummaryWeather(String text) {
    return 'Погода содержит «$text»';
  }

  @override
  String notebookRuleSummaryLocation(String text) {
    return 'Место содержит «$text»';
  }

  @override
  String notebookRuleSummaryKeyword(String text) {
    return 'Заголовок или текст содержит «$text»';
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
      other: 'Последние $days дня',
      many: 'Последние $days дней',
      few: 'Последние $days дня',
      one: 'Последний $days день',
    );
    return '$_temp0';
  }

  @override
  String notebookRuleSummaryMonth(int month, String monthName) {
    return 'Каждый год: $monthName';
  }

  @override
  String notebookRuleSummaryToday(String date) {
    return 'Этот день каждого года ($date)';
  }

  @override
  String get notebookRuleUnknown =>
      'Неизвестное условие (из более новой версии)';

  @override
  String notebookConvertTitle(String name) {
    return 'Преобразовать «$name» в обычный блокнот?';
  }

  @override
  String notebookConvertMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Будет добавлено $count записи, подходящих сейчас (кроме архивных), а блокнот перестанет обновляться автоматически.',
      many:
          'Будет добавлено $count записей, подходящих сейчас (кроме архивных), а блокнот перестанет обновляться автоматически.',
      few:
          'Будут добавлены $count записи, подходящие сейчас (кроме архивных), а блокнот перестанет обновляться автоматически.',
      one:
          'Будет добавлена $count запись, подходящая сейчас (кроме архивных), а блокнот перестанет обновляться автоматически.',
    );
    return '$_temp0';
  }

  @override
  String get notebookConvertAction => 'Преобразовать';

  @override
  String notebookConverted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Преобразовано, добавлено $count записи',
      many: 'Преобразовано, добавлено $count записей',
      few: 'Преобразовано, добавлены $count записи',
      one: 'Преобразовано, добавлена $count запись',
    );
    return '$_temp0';
  }

  @override
  String get notebookSaveRange => 'Сохранить как блокнот';

  @override
  String get notebookSaveRangeSmartHint =>
      'Записи за эти даты; добавленные позже задним числом попадут сюда автоматически';

  @override
  String notebookSaveRangeManualHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Добавить $count имеющейся записи',
      many: 'Добавить $count имеющихся записей',
      few: 'Добавить $count имеющиеся записи',
      one: 'Добавить $count имеющуюся запись',
    );
    return '$_temp0';
  }

  @override
  String get notebookSaveSearchAsSmart => 'Сохранить как умный блокнот';

  @override
  String get notebookSaveRangeSmart => 'Умный блокнот';

  @override
  String get notebookSaveRangeManual => 'Обычный блокнот';

  @override
  String get notebookGoalLabel => 'Цель по записям';

  @override
  String get notebookGoalEnable => 'Задать цель';

  @override
  String get notebookGoalEnableHint =>
      'Прогресс отображается в шапке блокнота. Без напоминаний.';

  @override
  String get notebookGoalDecrease => 'На одну меньше';

  @override
  String get notebookGoalIncrease => 'На одну больше';

  @override
  String get notebookGoalPeriodDay => 'Ежедневно';

  @override
  String get notebookGoalPeriodWeek => 'Еженедельно';

  @override
  String get notebookGoalPeriodMonth => 'Ежемесячно';

  @override
  String notebookGoalSummaryDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи в день',
      many: '$count записей в день',
      few: '$count записи в день',
      one: '$count запись в день',
    );
    return '$_temp0';
  }

  @override
  String notebookGoalSummaryWeek(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи в неделю',
      many: '$count записей в неделю',
      few: '$count записи в неделю',
      one: '$count запись в неделю',
    );
    return '$_temp0';
  }

  @override
  String notebookGoalSummaryMonth(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи в месяц',
      many: '$count записей в месяц',
      few: '$count записи в месяц',
      one: '$count запись в месяц',
    );
    return '$_temp0';
  }

  @override
  String notebookGoalProgressDay(int current, int target) {
    return 'Сегодня: $current / $target';
  }

  @override
  String notebookGoalProgressWeek(int current, int target) {
    return 'На этой неделе: $current / $target';
  }

  @override
  String notebookGoalProgressMonth(int current, int target) {
    return 'В этом месяце: $current / $target';
  }

  @override
  String get notebookGoalMetDay => 'На сегодня выполнено ✓';

  @override
  String get notebookGoalMetWeek => 'На этой неделе выполнено ✓';

  @override
  String get notebookGoalMetMonth => 'В этом месяце выполнено ✓';

  @override
  String notebookGoalStreakDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Серия: $count дня',
      many: 'Серия: $count дней',
      few: 'Серия: $count дня',
      one: 'Серия: $count день',
    );
    return '$_temp0';
  }

  @override
  String notebookGoalStreakWeek(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Серия: $count недели',
      many: 'Серия: $count недель',
      few: 'Серия: $count недели',
      one: 'Серия: $count неделя',
    );
    return '$_temp0';
  }

  @override
  String notebookGoalStreakMonth(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Серия: $count месяца',
      many: 'Серия: $count месяцев',
      few: 'Серия: $count месяца',
      one: 'Серия: $count месяц',
    );
    return '$_temp0';
  }

  @override
  String get notebookInsights => 'Статистика';

  @override
  String get notebookInsightsEmpty =>
      'В этом блокноте пока нет записей для статистики';

  @override
  String get notebookInsightsEntries => 'Записи';

  @override
  String get notebookInsightsWords => 'Слова';

  @override
  String get notebookInsightsRecordedDays => 'Дни с записями';

  @override
  String get notebookInsightsSpan => 'Период';

  @override
  String get notebookInsightsPhotos => 'Фото';

  @override
  String get notebookInsightsLongestStreak => 'Самая длинная серия';

  @override
  String notebookInsightsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня',
      many: '$count дней',
      few: '$count дня',
      one: '$count день',
    );
    return '$_temp0';
  }

  @override
  String notebookInsightsSpanMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months месяца',
      many: '$months месяцев',
      few: '$months месяца',
      one: '$months месяц',
    );
    return '$_temp0';
  }

  @override
  String notebookInsightsSpanYears(int years) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$years года',
      many: '$years лет',
      few: '$years года',
      one: '$years год',
    );
    return '$_temp0';
  }

  @override
  String notebookInsightsSpanYearsMonths(int years, int months) {
    return '$years г. $months мес.';
  }

  @override
  String get notebookInsightsMoods => 'Настроения';

  @override
  String notebookInsightsMoodShare(int count, int percent) {
    return '$count · $percent%';
  }

  @override
  String get notebookInsightsTopTags => 'Частые теги';

  @override
  String get notebookInsightsRhythm => 'Ритм записей';

  @override
  String notebookInsightsRhythmBar(String month, int count) {
    return '$month: $count';
  }

  @override
  String notebookInsightsGoalRecent(int met, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total последних периодов',
      many: '$total последних периодов',
      few: '$total последних периодов',
      one: '$total последнего периода',
    );
    return 'Цель выполнена в $met из $_temp0';
  }

  @override
  String notebookInsightsGoalRecentCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Последние $count периода',
      many: 'Последние $count периодов',
      few: 'Последние $count периода',
      one: 'Последний $count период',
    );
    return '$_temp0';
  }

  @override
  String get notebookInsightsRandom => 'Открыть случайную запись';

  @override
  String get diaryColorPanelDefaultColor => 'Цвет по умолчанию';

  @override
  String get diaryColorPanelNoBackground => 'Без фона';

  @override
  String get diaryColorPanelCustom => 'Свой';

  @override
  String get diaryColorPanelEnterCode => 'Введите код цвета';

  @override
  String get diaryColorPanelHexHint => 'RRGGBB';

  @override
  String get diaryColorPanelSwatches => 'Образцы';

  @override
  String get diaryColorPanelSaturationValue => 'Насыщенность и яркость';

  @override
  String get diaryColorPanelHue => 'Оттенок';

  @override
  String get diaryColorPanelOpacity => 'Непрозрачность';

  @override
  String get diaryColorRed => 'Красный';

  @override
  String get diaryColorOrange => 'Оранжевый';

  @override
  String get diaryColorYellow => 'Жёлтый';

  @override
  String get diaryColorGreen => 'Зелёный';

  @override
  String get diaryColorTeal => 'Бирюзовый';

  @override
  String get diaryColorBlue => 'Синий';

  @override
  String get diaryColorIndigo => 'Индиго';

  @override
  String get diaryColorPurple => 'Фиолетовый';

  @override
  String get diaryColorPink => 'Розовый';

  @override
  String get diaryColorBrown => 'Коричневый';

  @override
  String get diaryColorGray => 'Серый';

  @override
  String get diaryColorPanelMaterial => 'Material';

  @override
  String get diaryColorDeepPurple => 'Тёмно-фиолетовый';

  @override
  String get diaryColorLightBlue => 'Голубой';

  @override
  String get diaryColorCyan => 'Циан';

  @override
  String get diaryColorLightGreen => 'Светло-зелёный';

  @override
  String get diaryColorLime => 'Лаймовый';

  @override
  String get diaryColorAmber => 'Янтарный';

  @override
  String get diaryColorDeepOrange => 'Тёмно-оранжевый';

  @override
  String get diaryColorBlueGray => 'Сине-серый';

  @override
  String get diaryColorWhite => 'Белый';

  @override
  String get diaryColorBlack => 'Чёрный';

  @override
  String diaryColorShade(String family, String tone) {
    return '$family $tone';
  }

  @override
  String diaryColorPanelFamily(String family) {
    return '$family: оттенки';
  }

  @override
  String get tagPickerSearchHint => 'Поиск тегов';

  @override
  String get tagPickerSortTooltip => 'Порядок сортировки';

  @override
  String get tagPickerSortCustom => 'Порядок по умолчанию';

  @override
  String get tagPickerSortAlphabetical => 'По алфавиту';

  @override
  String tagPickerCreateNamed(String name) {
    return 'Создать «$name»';
  }

  @override
  String tagPickerSearchEmpty(String query) {
    return 'Нет тегов по запросу «$query»';
  }

  @override
  String get settingsFeaturesTitle => 'Функции';

  @override
  String get settingsFeaturesSubtitle => 'Выберите нужные разделы и функции';

  @override
  String get settingsFeaturesPagesGroup => 'Разделы';

  @override
  String get settingsFeaturesPagesFooter =>
      '«Записи» и «Настройки» есть всегда. Отключённые разделы пропадут с нижней панели, а данные останутся без изменений.';

  @override
  String get settingsFeaturesCalendarSubtitle =>
      'Записи по месяцам с лунным календарём, праздниками и памятными датами';

  @override
  String get settingsFeaturesExploreSubtitle =>
      'Статистика, «В этот день», динамика настроения и фотостена';

  @override
  String get settingsFeaturesFeaturesGroup => 'Функции дневника';

  @override
  String get settingsFeaturesFeaturesFooter =>
      'При отключении функции её пункты и параметры скрываются. Данные сохраняются и вернутся, когда вы снова её включите.';

  @override
  String get settingsFeaturesNotebooksSubtitle =>
      'Распределяйте записи по блокнотам, делите на главы и экспортируйте в виде книги';

  @override
  String get settingsFeaturesAnniversaries => 'Памятные даты';

  @override
  String get settingsFeaturesAnniversariesSubtitle =>
      'Памятные даты и обратный отсчёт с отметками в календаре';

  @override
  String get settingsFeaturesTemplates => 'Шаблоны записей';

  @override
  String get settingsFeaturesTemplatesSubtitle =>
      'Начинайте новые записи с готовой структуры';

  @override
  String get settingsFeaturesTimeCapsules => 'Капсулы времени';

  @override
  String get settingsFeaturesTimeCapsulesSubtitle =>
      'Письма в будущее: открываются только в назначенный срок';

  @override
  String get settingsFeaturesSwipeArchive => 'Архивация смахиванием';

  @override
  String get settingsFeaturesSwipeArchiveSubtitle =>
      'Смахните карточку записи влево, чтобы архивировать её, или влево в «Архиве», чтобы вернуть';

  @override
  String get settingsFeaturesNotebooksOffTitle => 'Отключить блокноты?';

  @override
  String settingsFeaturesNotebooksOffMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'У вас $count скрытого или заблокированного блокнота. Их записи не будут видны, пока вы снова не включите блокноты.',
      many:
          'У вас $count скрытых или заблокированных блокнотов. Их записи не будут видны, пока вы снова не включите блокноты.',
      few:
          'У вас $count скрытых или заблокированных блокнота. Их записи не будут видны, пока вы снова не включите блокноты.',
      one:
          'У вас $count скрытый или заблокированный блокнот. Его записи не будут видны, пока вы снова не включите блокноты.',
    );
    return '$_temp0';
  }

  @override
  String get settingsFeaturesNotebooksOffConfirm => 'Отключить';

  @override
  String get supportDeveloperTitle => 'Поддержать разработчика';

  @override
  String get supportDeveloperEntrySubtitle => 'Чаевые через WeChat или Alipay';

  @override
  String get supportDeveloperIntro =>
      'Jotsy — бесплатное приложение с открытым исходным кодом и без рекламы. Если оно вам полезно, можете поддержать разработчика чаевыми. Это полностью добровольно и не открывает никаких функций.';

  @override
  String get supportDeveloperWeChat => 'WeChat';

  @override
  String get supportDeveloperAlipay => 'Alipay';

  @override
  String get supportDeveloperWeChatCodeLabel => 'Код для чаевых в WeChat';

  @override
  String get supportDeveloperAlipayCodeLabel => 'Код оплаты Alipay';

  @override
  String get supportDeveloperWeChatHint =>
      'Сохраните код в галерею, затем откройте «Сканировать» в WeChat и выберите это изображение из альбома в правом верхнем углу.';

  @override
  String get supportDeveloperAlipayHint =>
      'Нажмите кнопку ниже, чтобы оплатить прямо в Alipay, или сохраните код и выберите его из галереи в разделе «Сканировать» в Alipay.';

  @override
  String get supportDeveloperSaveCode => 'Сохранить в галерею';

  @override
  String get supportDeveloperOpenWeChat => 'Открыть WeChat';

  @override
  String get supportDeveloperOpenAlipay => 'Оплатить в Alipay';

  @override
  String get supportDeveloperAlipayUnavailable =>
      'Не удалось открыть Alipay. Сохраните код и отсканируйте его телефоном, на котором установлен Alipay.';

  @override
  String get supportDeveloperWeChatUnavailable =>
      'Не удалось открыть WeChat. Откройте его вручную и отсканируйте код.';

  @override
  String get diaryColorPanelNewColor => 'Новый цвет';

  @override
  String get diaryColorPanelManageColors => 'Управлять моими цветами';

  @override
  String get diaryColorPanelManageDone => 'Готово';

  @override
  String get diaryColorPanelSavedEmpty =>
      'Цвета, созданные на вкладке «Свой», сохраняются здесь';

  @override
  String get diaryColorPanelSavedMark => 'Сохранён';

  @override
  String diaryColorPanelSavedColor(String color) {
    return 'Мой цвет $color';
  }

  @override
  String diaryColorPanelDocumentColor(String color) {
    return 'Цвет из этой записи $color';
  }

  @override
  String diaryColorPanelRemoveColor(String color) {
    return 'Удалить $color';
  }

  @override
  String diaryColorPanelKeepColor(String color) {
    return 'Сохранить $color в «Мои цвета»';
  }

  @override
  String get homeBarStyleTitle => 'Стиль панели навигации';

  @override
  String homeBarStyleEntrySubtitle(String name) {
    return 'Сейчас: $name';
  }

  @override
  String homeBarStyleCustomName(String material) {
    return '$material — свой вариант';
  }

  @override
  String get homeBarStyleTabPresets => 'Пресеты';

  @override
  String get homeBarStyleTabMaterial => 'Материал';

  @override
  String get homeBarStyleTabFloating => 'Плавающая панель';

  @override
  String get homeBarStyleTabItems => 'Пункты';

  @override
  String get homeBarStyleTabBehavior => 'Поведение';

  @override
  String get homeBarStylePresetClassic => 'Классика';

  @override
  String get homeBarStylePresetClassicDesc =>
      'Сплошная нижняя панель, как до редизайна';

  @override
  String get homeBarStylePresetGlass => 'Стекло';

  @override
  String get homeBarStylePresetGlassDesc =>
      'Матовая плавающая панель с заливкой выбранного пункта';

  @override
  String get homeBarStylePresetClear => 'Прозрачность';

  @override
  String get homeBarStylePresetClearDesc => 'Более прозрачное стекло без тени';

  @override
  String get homeBarStylePresetFrosted => 'Туман';

  @override
  String get homeBarStylePresetFrostedDesc =>
      'Плотное матовое стекло, подписи читаются лучше всего';

  @override
  String get homeBarStylePresetTinted => 'Цвет темы';

  @override
  String get homeBarStylePresetTintedDesc =>
      'Стекло с лёгким оттенком цвета темы';

  @override
  String get homeBarStylePresetCompact => 'Компакт';

  @override
  String get homeBarStylePresetCompactDesc =>
      'Более низкая плавающая панель только со значками';

  @override
  String get homeBarStyleMaterialSolid => 'Сплошной цвет';

  @override
  String get homeBarStyleMaterialGlass => 'Стекло';

  @override
  String get homeBarStyleGlassFooter =>
      'Со стеклом нижняя панель парит над страницей, а содержимое, прокручиваемое под ней, просвечивает размытым.';

  @override
  String get homeBarStyleHighContrastNote =>
      'В системе включён высокий контраст, поэтому стекло пока отображается непрозрачным.';

  @override
  String get homeBarStyleGlassTopBars => 'Стеклянные верхние панели';

  @override
  String get homeBarStyleGlassTopBarsSubtitle =>
      'Верхние панели разделов «Записи», «Календарь», «Обзор» и «Настройки» тоже станут матовыми';

  @override
  String get homeBarStyleTopBarHairline => 'Разделитель верхней панели';

  @override
  String get homeBarStyleTopBarHairlineSubtitle =>
      'Тонкая линия по нижнему краю стеклянных верхних панелей';

  @override
  String get homeBarStyleBlur => 'Размытие';

  @override
  String get homeBarStyleOpacity => 'Непрозрачность';

  @override
  String get homeBarStyleTint => 'Оттенок';

  @override
  String get homeBarStyleTintNeutral => 'Нейтральный';

  @override
  String get homeBarStyleTintTheme => 'Цвет темы';

  @override
  String get homeBarStyleTintColor => 'Цвет стекла';

  @override
  String get homeBarStyleBorder => 'Контур нижней панели';

  @override
  String get homeBarStyleBorderSubtitle =>
      'Тонкая линия по краю плавающей панели';

  @override
  String get homeBarStyleOutlineGroup => 'Контуры';

  @override
  String get homeBarStyleLineColor => 'Цвет';

  @override
  String get homeBarStyleLineColorTheme => 'По умолчанию';

  @override
  String get homeBarStyleLineColorHighlight => 'Блик';

  @override
  String get homeBarStyleLineColorPrimary => 'Акцентный';

  @override
  String get homeBarStyleLineCustomColor => 'Цвет линии';

  @override
  String get homeBarStyleLineWidth => 'Толщина';

  @override
  String get homeBarStyleShadow => 'Тень';

  @override
  String get homeBarStyleShadowSubtitle => 'Мягкая тень под плавающей панелью';

  @override
  String get homeBarStyleFloatingSolidHint =>
      'Плавающая панель используется только со стеклянным материалом.';

  @override
  String get homeBarStyleSwitchToGlass => 'Выбрать стекло';

  @override
  String get homeBarStyleSizeGroup => 'Размер';

  @override
  String get homeBarStyleHeight => 'Высота';

  @override
  String get homeBarStyleCornerRadius => 'Скругление углов';

  @override
  String get homeBarStyleSideMargin => 'Отступы по бокам';

  @override
  String get homeBarStyleBottomGap => 'Отступ снизу';

  @override
  String get homeBarStyleFabGroup => 'Кнопка создания';

  @override
  String get homeBarStyleFabAbove => 'Над панелью';

  @override
  String get homeBarStyleFabInline => 'Рядом с панелью';

  @override
  String get homeBarStyleFabFooter =>
      'Показывается только в разделе «Записи»; рядом с панелью отображается только значок.';

  @override
  String get homeBarStyleLabels => 'Подписи';

  @override
  String get homeBarStyleLabelsAlways => 'Всегда';

  @override
  String get homeBarStyleLabelsSelected => 'Только у выбранного';

  @override
  String get homeBarStyleLabelsNever => 'Скрыты';

  @override
  String get homeBarStyleIconSize => 'Размер значков';

  @override
  String get homeBarStyleLabelGap => 'Отступ между значком и подписью';

  @override
  String get homeBarStyleIndicator => 'Индикатор выбора';

  @override
  String get homeBarStyleIndicatorCapsule => 'Капсула';

  @override
  String get homeBarStyleIndicatorBlock => 'Блок';

  @override
  String get homeBarStyleIndicatorNone => 'Нет';

  @override
  String get homeBarStyleBlockPadding => 'Внутренний отступ блока';

  @override
  String get homeBarStyleItemsFooter =>
      'При переключении на стекло отступ между значком и подписью немного уменьшается.';

  @override
  String get homeBarStyleBehaviorFooter =>
      'Поведение не меняется при выборе пресетов и кодов стиля.';

  @override
  String get homeBarStyleHideOnScroll => 'Скрывать панель при прокрутке вниз';

  @override
  String get homeBarStyleHideOnScrollSubtitle =>
      'Освобождает место при прокрутке вниз и появляется снова при прокрутке вверх или в начале страницы';

  @override
  String get homeBarStyleHideOnScrollSolidHint =>
      'Скрытие при прокрутке доступно только для стеклянной плавающей панели.';

  @override
  String get homeBarStyleIndicatorFollows => 'Индикатор следует за свайпом';

  @override
  String get homeBarStyleIndicatorFollowsSubtitle =>
      'При перелистывании страниц свайпом индикатор выбора движется вслед за пальцем';

  @override
  String get codeBlockPanelTitle => 'Блок кода';

  @override
  String get codeBlockLanguageAuto => 'Автоопределение';

  @override
  String codeBlockLanguageAutoDetected(String language) {
    return 'Авто · $language';
  }

  @override
  String get codeBlockLanguageNone => 'Не указан';

  @override
  String get codeBlockLanguagePlain => 'Обычный текст';

  @override
  String get codeBlockLabelGeneric => 'Код';

  @override
  String get codeBlockCopy => 'Копировать код';

  @override
  String get codeBlockCopied => 'Код скопирован';

  @override
  String codeBlockCopySemantics(String language) {
    return 'Копировать код $language';
  }

  @override
  String get codeBlockExit => 'Выйти из блока кода';

  @override
  String get codeBlockToText => 'Преобразовать в текст';

  @override
  String get codeBlockStyleTitle => 'Стиль блоков кода';

  @override
  String get codeBlockStyleSubtitle => 'Тема, номера строк, шрифт и заголовок';

  @override
  String get codeBlockStyleTabTheme => 'Тема';

  @override
  String get codeBlockStyleTabDisplay => 'Отображение';

  @override
  String get codeBlockStyleTabFont => 'Шрифт';

  @override
  String get codeBlockThemeFollowApp => 'Как в приложении';

  @override
  String get codeBlockBrightnessTitle => 'Светлая или тёмная';

  @override
  String get codeBlockBrightnessSystem => 'Как в теме';

  @override
  String get codeBlockBrightnessLight => 'Светлая';

  @override
  String get codeBlockBrightnessDark => 'Тёмная';

  @override
  String get codeBlockLineNumbersTitle => 'Номера строк';

  @override
  String get codeBlockLineNumbersSubtitle => 'Нумеровать каждую строку кода';

  @override
  String get codeBlockHeaderTitle => 'Панель заголовка';

  @override
  String get codeBlockHeaderSubtitle =>
      'Показывать сверху язык и кнопку копирования';

  @override
  String get codeBlockAutoDetectTitle => 'Определять язык';

  @override
  String get codeBlockAutoDetectSubtitle =>
      'Определять язык блоков кода, где он не указан, и подсвечивать синтаксис';

  @override
  String get codeBlockBorderTitle => 'Рамка';

  @override
  String get codeBlockBorderSubtitle => 'Обводить блоки кода тонкой рамкой';

  @override
  String get codeBlockRadiusTitle => 'Скругление углов';

  @override
  String get codeBlockFontTitle => 'Шрифт кода';

  @override
  String get codeBlockFontMono => 'Системный моноширинный';

  @override
  String get codeBlockFontBody => 'Шрифт основного текста';

  @override
  String get codeBlockFontMissing =>
      'Файла выбранного шрифта больше нет на этом устройстве, поэтому код пока отображается системным моноширинным шрифтом. Импортируйте шрифт заново в разделе «Шрифт и оформление текста» или выберите другой.';

  @override
  String get codeBlockFontSizeTitle => 'Размер шрифта';

  @override
  String codeBlockFontSizeValue(int percent) {
    return '$percent%';
  }

  @override
  String get codeBlockLineHeightTitle => 'Межстрочный интервал';

  @override
  String get codeBlockPreviewIntro =>
      'Блоки кода подсвечиваются по языку, а встроенный код тоже следует теме, например ';

  @override
  String get diaryEditorLinkUrl => 'URL ссылки';

  @override
  String get diaryEditorInvalidLink => 'Введите корректный URL ссылки';

  @override
  String get diaryEditorRemoveLink => 'Удалить ссылку';

  @override
  String get diaryEditorMoveBlockUp => 'Вверх';

  @override
  String get diaryEditorMoveBlockDown => 'Вниз';

  @override
  String get diaryEditorBlockHandle =>
      'Выбрать блок, удерживайте для перетаскивания';

  @override
  String diaryBlockSelectionCount(int count) {
    return 'Выбрано: $count';
  }

  @override
  String get diaryBlockSelectionNone => 'Блоки не выбраны';

  @override
  String get diaryBlockSelectionDone => 'Готово';

  @override
  String get diaryBlockCopy => 'Копировать';

  @override
  String get diaryBlockCut => 'Вырезать';

  @override
  String get diaryBlockDuplicate => 'Дублировать';

  @override
  String get diaryBlockMoveToTop => 'В начало';

  @override
  String get diaryBlockMoveToBottom => 'В конец';

  @override
  String diaryBlockCopied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Скопировано $count блока',
      many: 'Скопировано $count блоков',
      few: 'Скопировано $count блока',
      one: 'Скопирован $count блок',
    );
    return '$_temp0';
  }

  @override
  String diaryBlockDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Удалено $count блока',
      many: 'Удалено $count блоков',
      few: 'Удалено $count блока',
      one: 'Удалён $count блок',
    );
    return '$_temp0';
  }

  @override
  String diaryBlockCutDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Вырезано $count блока',
      many: 'Вырезано $count блоков',
      few: 'Вырезано $count блока',
      one: 'Вырезан $count блок',
    );
    return '$_temp0';
  }

  @override
  String get diaryBlockTurnInto => 'Тип';

  @override
  String get diaryBlockStyle => 'Стиль';

  @override
  String get diaryBlockSplitLines => 'Разбить на абзацы';

  @override
  String get diaryBlockMerge => 'Объединить в один';

  @override
  String get diaryEditorSelectBlocks => 'Выбрать блоки';

  @override
  String get diaryEditorParagraph => 'Текст';

  @override
  String get diaryEditorIndent => 'Увеличить отступ';

  @override
  String get diaryEditorOutdent => 'Уменьшить отступ';

  @override
  String get diaryEditorSlashCommands => 'Вставить блок';

  @override
  String get diaryEditorDivider => 'Разделитель';

  @override
  String get diaryEditorCallout => 'Выноска';

  @override
  String get diaryCalloutPlaceholder => 'Выноска';

  @override
  String get diaryCalloutToText => 'Преобразовать в текст';

  @override
  String get diaryCalloutToneDefault => 'По умолчанию';

  @override
  String get diaryCalloutToneYellow => 'Жёлтый';

  @override
  String get diaryCalloutToneGreen => 'Зелёный';

  @override
  String get diaryCalloutToneBlue => 'Синий';

  @override
  String get diaryCalloutToneRed => 'Красный';

  @override
  String get diaryCalloutTonePurple => 'Фиолетовый';

  @override
  String get diaryEditorUnsupportedBlock => 'Неподдерживаемое содержимое';

  @override
  String get diaryEditorToggleList => 'Раскрывающийся блок';

  @override
  String get diaryToggleListPlaceholder => 'Раскрывающийся блок';

  @override
  String get diaryToggleExpand => 'Развернуть';

  @override
  String get diaryToggleCollapse => 'Свернуть';

  @override
  String get diaryEditorImageWidth => 'Ширина изображения';

  @override
  String get diaryEditorImageHeight => 'Высота изображения';

  @override
  String get diaryEditorHeading1 => 'Заголовок 1';

  @override
  String get diaryEditorHeading2 => 'Заголовок 2';

  @override
  String get diaryEditorHeading3 => 'Заголовок 3';

  @override
  String get diaryEditorHeading4 => 'Заголовок 4';

  @override
  String get diaryEditorHeading5 => 'Заголовок 5';

  @override
  String get diaryEditorHeading6 => 'Заголовок 6';

  @override
  String get diaryToolbarAlign => 'Выравнивание';

  @override
  String get diaryToolbarFontSize => 'Размер шрифта';

  @override
  String get diaryToolbarSuperscript => 'Надстрочный';

  @override
  String get diaryToolbarSubscript => 'Подстрочный';

  @override
  String get diaryHeadingPanelTitle => 'Заголовок';

  @override
  String get diaryHeadingPanelBody => 'Обычный текст';

  @override
  String get diaryAlignLeft => 'По левому краю';

  @override
  String get diaryAlignCenter => 'По центру';

  @override
  String get diaryAlignRight => 'По правому краю';

  @override
  String get diaryAlignJustify => 'По ширине';

  @override
  String get diaryFontSizeSmall => 'Мелкий';

  @override
  String get diaryFontSizeNormal => 'Обычный';

  @override
  String get diaryFontSizeLarge => 'Крупный';

  @override
  String get diaryFontSizeHuge => 'Огромный';

  @override
  String get diaryEditorCommandGroupText => 'Текст';

  @override
  String get diaryEditorCommandGroupList => 'Списки';

  @override
  String get diaryEditorCommandGroupInsert => 'Вставка';

  @override
  String get diaryEditorCommandEmpty => 'Нет подходящих блоков';

  @override
  String get diaryEditorEmptyLineHint => 'Введите /, чтобы вставить блок';

  @override
  String get diaryEditorCommandTypeToFilter =>
      'Продолжайте вводить для фильтрации';

  @override
  String get diaryCardMenuMoveToNotebook => 'Переместить в блокнот…';

  @override
  String get diaryCardMenuAddToNotebook => 'Добавить в блокнот…';

  @override
  String get diaryEditorDropToInsert => 'Отпустите, чтобы вставить';

  @override
  String get dayMoodAwful => 'Ужасно';

  @override
  String get dayMoodBad => 'Плохо';

  @override
  String get dayMoodMeh => 'Так себе';

  @override
  String get dayMoodGood => 'Хорошо';

  @override
  String get dayMoodGreat => 'Отлично';

  @override
  String get calendarDayMoodTitle => 'Настроение дня';

  @override
  String get calendarDayMoodClear => 'Очистить';

  @override
  String get calendarDayMoodCleared => 'Настроение дня очищено';

  @override
  String get calendarDayMoodSaveFailed =>
      'Не удалось сохранить настроение. Повторите попытку.';

  @override
  String get calendarShowDayMoods => 'Настроение дня';

  @override
  String get calendarShowDayMoodsDescription =>
      'Удерживайте дату, чтобы отметить, каким был день, — вся ячейка даты примет вид этого настроения.';

  @override
  String backupOverwriteAllDayMoods(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Настроения за $count дня',
      many: 'Настроения за $count дней',
      few: 'Настроения за $count дня',
      one: 'Настроения за $count день',
    );
    return '$_temp0';
  }

  @override
  String backupOverwriteExistingDayMoodsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Настроения, уже отмеченные за $count дня, будут заменены настроениями из файла.',
      many:
          'Настроения, уже отмеченные за $count дней, будут заменены настроениями из файла.',
      few:
          'Настроения, уже отмеченные за $count дня, будут заменены настроениями из файла.',
      one:
          'Настроения, уже отмеченные за $count день, будут заменены настроениями из файла.',
    );
    return '$_temp0';
  }

  @override
  String backupImportModeOverwriteDayMoodsOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Добавляет новое и заменяет настроения, уже отмеченные за $count дня, настроениями из файла',
      many:
          'Добавляет новое и заменяет настроения, уже отмеченные за $count дней, настроениями из файла',
      few:
          'Добавляет новое и заменяет настроения, уже отмеченные за $count дня, настроениями из файла',
      one:
          'Добавляет новое и заменяет настроения, уже отмеченные за $count день, настроениями из файла',
    );
    return '$_temp0';
  }

  @override
  String backupImportModeOverwriteDayMoodsExtra(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Также заменяет настроения, отмеченные за $count дня',
      many: 'Также заменяет настроения, отмеченные за $count дней',
      few: 'Также заменяет настроения, отмеченные за $count дня',
      one: 'Также заменяет настроения, отмеченные за $count день',
    );
    return '$_temp0';
  }

  @override
  String backupImportDayMoodMergeResult(int added) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: 'Настроение дня: добавлено за $added дня',
      many: 'Настроение дня: добавлено за $added дней',
      few: 'Настроение дня: добавлено за $added дня',
      one: 'Настроение дня: добавлено за $added день',
    );
    return '$_temp0';
  }

  @override
  String backupImportDayMoodOverwriteResult(int added, int replaced) {
    return 'Настроение дня: добавлено $added, перезаписано $replaced';
  }

  @override
  String get appSurfaceTitle => 'Фон и материал';

  @override
  String get appSurfaceEntryDefault => 'По умолчанию';

  @override
  String get appSurfaceEntryImage => 'Фоновое изображение';

  @override
  String get appSurfaceEntryColor => 'Однотонный фон';

  @override
  String get appSurfaceEntryGlass => 'Стеклянные компоненты';

  @override
  String get appSurfaceEntryClassic => 'Классические компоненты';

  @override
  String appSurfaceEntryAreas(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count области настроены отдельно',
      many: '$count областей настроены отдельно',
      few: '$count области настроены отдельно',
      one: '$count область настроена отдельно',
    );
    return '$_temp0';
  }

  @override
  String get appSurfaceTabBackground => 'Фон';

  @override
  String get appSurfaceTabGlass => 'Стекло';

  @override
  String get appSurfaceAreaGlobal => 'Общий';

  @override
  String get appSurfaceAreaDiaries => 'Записи';

  @override
  String get appSurfaceAreaCalendar => 'Календарь';

  @override
  String get appSurfaceAreaExplore => 'Обзор';

  @override
  String get appSurfaceAreaSettings => 'Настройки';

  @override
  String get appSurfaceAreaEditor => 'Редактор';

  @override
  String get appSurfaceAreaPreview => 'Просмотр';

  @override
  String get appSurfaceAreaOther => 'Прочее';

  @override
  String appSurfaceAreaCustomized(String area) {
    return '$area, настроено отдельно';
  }

  @override
  String get appSurfaceAreaModeFollow => 'Как общий';

  @override
  String get appSurfaceAreaModeOff => 'Без фона';

  @override
  String get appSurfaceAreaModeCustom => 'Свой';

  @override
  String appSurfaceAreaFollowNote(String kind) {
    return 'Используется общий фон (сейчас: $kind).';
  }

  @override
  String get appSurfaceAreaOffNote =>
      'В этой области фон не показывается, остаётся цвет темы.';

  @override
  String get appSurfaceAreaCustomNote =>
      'В этой области используется свой фон, заданный ниже; изображение и параметры могут по отдельности брать значения из общего фона или с другой страницы.';

  @override
  String get appSurfaceAreaPreviewNote =>
      'Показывается, только если бумага на странице просмотра следует теме.';

  @override
  String get appSurfaceGlobalBackground => 'Общий фон';

  @override
  String get appSurfaceGlobalFooter =>
      'Все области используют общий фон, пока вы не выберете область выше и не настроите её отдельно.';

  @override
  String get appSurfaceAreaBackground => 'Свой фон';

  @override
  String get appSurfaceKindNone => 'Нет';

  @override
  String get appSurfaceKindColor => 'Цвет';

  @override
  String get appSurfaceKindImage => 'Изображение';

  @override
  String get appSurfaceBackgroundColor => 'Цвет фона';

  @override
  String get appSurfaceImagePick => 'Выбрать изображение';

  @override
  String get appSurfaceImageChange => 'Заменить';

  @override
  String get appSurfaceImageRemove => 'Удалить';

  @override
  String get appSurfaceImageEmpty => 'Изображение ещё не выбрано';

  @override
  String get appSurfaceImageMissing =>
      'Файл изображения не найден. Выберите его снова.';

  @override
  String get appSurfaceImageUnavailable =>
      'Не удалось прочитать изображение. Выберите файл, хранящийся на этом устройстве.';

  @override
  String get appSurfaceImageImportFailed =>
      'Не удалось импортировать изображение. Повторите попытку.';

  @override
  String get appSurfaceFocus => 'Фокус';

  @override
  String get appSurfaceFocusHint =>
      'Нажмите на изображение или проведите по нему, чтобы выбрать часть, которая останется видна при обрезке.';

  @override
  String appSurfaceFocusSemantics(String x, String y) {
    return 'Фокус фона: $x% по горизонтали, $y% по вертикали';
  }

  @override
  String get appSurfaceBlur => 'Размытие';

  @override
  String get appSurfaceScrimLight => 'Вуаль в светлой теме';

  @override
  String get appSurfaceScrimDark => 'Вуаль в тёмной теме';

  @override
  String get appSurfaceFollowSource => 'Источник';

  @override
  String get appSurfaceFollowSourceHint =>
      'Если ниже «Изображение» или «Параметры» берутся из источника, используется то, что сейчас показывает выбранная страница, и при её изменении меняется и здесь.';

  @override
  String appSurfaceSourceShows(String kind) {
    return 'Сейчас: $kind';
  }

  @override
  String get appSurfaceSourceLoop => 'Её источник ведёт обратно сюда';

  @override
  String get appSurfaceImageGroup => 'Изображение';

  @override
  String get appSurfaceParamsGroup => 'Параметры';

  @override
  String appSurfaceFollowImage(String source) {
    return 'Изображение из «$source»';
  }

  @override
  String appSurfaceFollowParams(String source) {
    return 'Параметры из «$source»';
  }

  @override
  String get appSurfaceFollowParamsHint =>
      'Фокус, размытие и вуали — все вместе';

  @override
  String appSurfaceFollowImageNote(String source) {
    return 'Используется изображение из «$source»';
  }

  @override
  String appSurfaceFollowImageNone(String source) {
    return 'В «$source» сейчас нет фонового изображения';
  }

  @override
  String get appSurfaceGlassStyle => 'Стиль компонентов';

  @override
  String get appSurfaceGlassClassic => 'Классика';

  @override
  String get appSurfaceGlassGlass => 'Стекло';

  @override
  String get appSurfaceGlassStyleFooter =>
      '«Стекло» позволяет фону и содержимому просвечивать сквозь компоненты; «Классика» оставляет их непрозрачными.';

  @override
  String get appSurfaceGlassPerComponent => 'По компонентам';

  @override
  String get appSurfaceComponentTopBars => 'Верхние панели страниц';

  @override
  String get appSurfaceComponentToolbar => 'Панель инструментов редактора';

  @override
  String get appSurfaceComponentSheets => 'Нижние панели';

  @override
  String get appSurfaceComponentDialogs => 'Диалоги';

  @override
  String get appSurfaceComponentCards => 'Карточки и группы';

  @override
  String get appSurfaceComponentControls => 'Элементы управления и уведомления';

  @override
  String get appSurfaceOverrideFollow => 'Как общий';

  @override
  String appSurfaceOverrideFollowResult(String material) {
    return 'Как общий ($material)';
  }

  @override
  String get appSurfaceGlassTexture => 'Фактура стекла';

  @override
  String get appSurfaceGlassOpacity => 'Непрозрачность';

  @override
  String get appSurfaceGlassTint => 'Оттенок';

  @override
  String get appSurfaceGlassTintNeutral => 'Нейтральный';

  @override
  String get appSurfaceGlassTintTheme => 'Цвет темы';

  @override
  String get appSurfaceGlassTintColor => 'Цвет стекла';

  @override
  String get appSurfaceGlassBorder => 'Контур';

  @override
  String get appSurfaceGlassBorderSubtitle =>
      'Обводит края компонентов на фоне близкого к ним цвета';

  @override
  String get appSurfaceGlassHighContrast =>
      'В режиме высокой контрастности стекло автоматически становится непрозрачным.';

  @override
  String get appSurfacePreviewLabel => 'Предпросмотр фона и материала';

  @override
  String get appSurfacePreviewCardTitle1 => 'Прогулка после обеда';

  @override
  String get appSurfacePreviewCardBody1 =>
      'Солнечный день — большой круг пешком вдоль реки.';

  @override
  String get appSurfacePreviewCardTitle2 => 'Заметки о прочитанном';

  @override
  String get appSurfacePreviewCardBody2 =>
      'Несколько понравившихся строк — чтобы потом перечитать.';

  @override
  String get diaryToolbarSizeTitle => 'Размер панели инструментов';

  @override
  String get diaryToolbarSizeSubtitle =>
      'Кнопки и значки масштабируются вместе. Инструменты, которые не помещаются в один ряд, уходят в «Другие инструменты».';

  @override
  String get diaryToolbarSizeSmall => 'Маленький';

  @override
  String get diaryToolbarSizeStandard => 'Стандартный';

  @override
  String get diaryToolbarSizeLarge => 'Большой';

  @override
  String get diaryToolbarSizeExtraLarge => 'Очень большой';

  @override
  String get diaryListStyleNumberedTitle => 'Стиль нумерованного списка';

  @override
  String get diaryListStyleBulletedTitle => 'Стиль маркированного списка';

  @override
  String get diaryListStyleAuto => 'Автоматически (зависит от уровня)';

  @override
  String get diaryListStyleDecimal => 'Цифры 1. 2. 3.';

  @override
  String get diaryListStyleParenthesized => 'Цифры в скобках (1) (2) (3)';

  @override
  String get diaryListStyleCircled => 'Цифры в кружках ① ② ③';

  @override
  String get diaryListStyleChinese => 'Китайские цифры 一、二、三、';

  @override
  String get diaryListStyleLowerAlpha => 'Строчные буквы a. b. c.';

  @override
  String get diaryListStyleUpperAlpha => 'Прописные буквы A. B. C.';

  @override
  String get diaryListStyleLowerRoman => 'Строчные римские цифры i. ii. iii.';

  @override
  String get diaryListStyleUpperRoman => 'Прописные римские цифры I. II. III.';

  @override
  String get diaryListStyleDisc => 'Закрашенный кружок';

  @override
  String get diaryListStyleCircle => 'Пустой кружок';

  @override
  String get diaryListStyleSquare => 'Квадрат';

  @override
  String get diaryListStyleDiamond => 'Ромб';

  @override
  String get diaryListStyleStar => 'Звезда';

  @override
  String get diaryListStyleArrow => 'Стрелка';

  @override
  String get diaryListStyleDash => 'Тире';

  @override
  String get diaryListToBulleted => 'В маркированный список';

  @override
  String get diaryListToNumbered => 'В нумерованный список';

  @override
  String get diaryListToText => 'Преобразовать в текст';

  @override
  String get diaryFastScrollPinned => 'Закреплённые';

  @override
  String get diaryFastScrollUntitled => 'Без названия';

  @override
  String get exploreModuleGreeting => 'Сегодня';

  @override
  String get exploreModuleGreetingDesc =>
      'Приветствие с датой по лунному календарю, итогами дня и темой дня';

  @override
  String get exploreModuleOnThisDay => 'В этот день';

  @override
  String get exploreModuleOnThisDayDesc =>
      'Записи за этот день (соседние дни или этот месяц) в прошлые годы';

  @override
  String get exploreModuleRandomMemory => 'Случайное воспоминание';

  @override
  String get exploreModuleRandomMemoryDesc =>
      'Показывает случайную старую запись';

  @override
  String get exploreModuleRecap => 'Итоги периода';

  @override
  String get exploreModuleRecapDesc =>
      'Неделя, месяц или год вкратце — в сравнении с предыдущим периодом';

  @override
  String get exploreModuleMilestones => 'Вехи';

  @override
  String get exploreModuleMilestonesDesc =>
      'Прогресс к вехам по числу записей, слов и длине серии';

  @override
  String get exploreModuleOverview => 'Сводка';

  @override
  String get exploreModuleOverviewDesc =>
      'Выбранные вами показатели: записи, слова, серии и другое';

  @override
  String get exploreModuleHeatmap => 'Тепловая карта записей';

  @override
  String get exploreModuleHeatmapDesc =>
      'Ячейки по дням, разложенные по неделям';

  @override
  String get exploreModuleRhythm => 'Ритм письма';

  @override
  String get exploreModuleRhythmDesc =>
      'Сколько вы писали за каждый месяц, неделю или день';

  @override
  String get exploreModuleHabits => 'Привычки письма';

  @override
  String get exploreModuleHabitsDesc =>
      'В какое время и в какие дни недели вы обычно пишете';

  @override
  String get exploreModuleMoodTrend => 'Динамика настроения';

  @override
  String get exploreModuleMoodTrendDesc =>
      'Как менялось ваше настроение день за днём';

  @override
  String get exploreModuleMoodShare => 'Распределение настроений';

  @override
  String get exploreModuleMoodShareDesc =>
      'Как часто встречается каждое настроение';

  @override
  String get exploreModuleEnergy => 'Динамика энергии';

  @override
  String get exploreModuleEnergyDesc => 'Ваш уровень энергии день за днём';

  @override
  String get exploreModuleTags => 'Теги';

  @override
  String get exploreModuleTagsDesc => 'Ваши теги; нажмите, чтобы найти записи';

  @override
  String get exploreModuleMedia => 'Медиагалерея';

  @override
  String get exploreModuleMediaDesc => 'Фото из вашего дневника';

  @override
  String get exploreModulePlaces => 'Места';

  @override
  String get exploreModulePlacesDesc => 'Где вы пишете чаще всего';

  @override
  String get exploreModuleWeather => 'Погода';

  @override
  String get exploreModuleWeatherDesc => 'Какая была погода, когда вы писали';

  @override
  String get exploreModuleAnniversaries => 'Памятные даты';

  @override
  String get exploreModuleAnniversariesDesc =>
      'Обратный отсчёт до ближайших памятных дат';

  @override
  String get exploreModuleCapsules => 'Капсулы времени';

  @override
  String get exploreModuleCapsulesDesc =>
      'Капсулы, которые ждут открытия, и недавно открытые';

  @override
  String get exploreModuleNotebooks => 'Блокноты';

  @override
  String get exploreModuleNotebooksDesc => 'Ваша полка с блокнотами';

  @override
  String get exploreModuleDrafts => 'Черновики';

  @override
  String get exploreModuleDraftsDesc =>
      'Напоминание, если есть незаконченные черновики';

  @override
  String get explorePeriodWeek => 'Эта неделя';

  @override
  String get explorePeriodMonth => 'Этот месяц';

  @override
  String get explorePeriodYear => 'Этот год';

  @override
  String get explorePeriodAll => 'За всё время';

  @override
  String get explorePeriodEmpty => 'За этот период записей пока нет';

  @override
  String get exploreNoModules => 'В «Обзоре» не показано ни одной карточки';

  @override
  String get exploreModuleMenuHide => 'Скрыть карточку';

  @override
  String exploreModuleHidden(String name) {
    return 'Карточка «$name» скрыта';
  }

  @override
  String get exploreGreetingMorning => 'Доброе утро';

  @override
  String get exploreGreetingNoon => 'Добрый день';

  @override
  String get exploreGreetingAfternoon => 'Добрый день';

  @override
  String get exploreGreetingEvening => 'Добрый вечер';

  @override
  String get exploreGreetingNight => 'Не спится?';

  @override
  String exploreGreetingToday(int count, String words) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи',
      many: '$count записей',
      few: '$count записи',
      one: '$count запись',
    );
    return 'Сегодня $_temp0 · слов: $words';
  }

  @override
  String get exploreGreetingTodayEmpty => 'Сегодня ещё ничего не написано';

  @override
  String get exploreGreetingWrite => 'Написать';

  @override
  String get exploreGreetingNextPrompt => 'Другая тема';

  @override
  String get explorePrompt01 => 'Что сегодня заставило вас улыбнуться?';

  @override
  String get explorePrompt02 => 'О чём вы в последнее время часто думаете?';

  @override
  String get explorePrompt03 => 'Что нового вы сегодня узнали?';

  @override
  String get explorePrompt04 =>
      'Если бы можно было прожить сегодняшний день заново, что бы вы сделали иначе?';

  @override
  String get explorePrompt05 => 'Опишите, что сейчас за вашим окном.';

  @override
  String get explorePrompt06 => 'Что самое вкусное вы сегодня ели?';

  @override
  String get explorePrompt07 =>
      'Какая фраза, прочитанная или услышанная недавно, запомнилась вам больше всего?';

  @override
  String get explorePrompt08 => 'Что есть у вас сегодня, чего не было вчера?';

  @override
  String get explorePrompt09 =>
      'Напишите о мелочи, которая помогла вам почувствовать опору.';

  @override
  String get explorePrompt10 => 'Что бы вы хотели сказать себе на этой неделе?';

  @override
  String get explorePrompt11 => 'С кем вы сегодня разговаривали и о чём?';

  @override
  String get explorePrompt12 => 'Чего вы сейчас ждёте с нетерпением?';

  @override
  String get explorePrompt13 =>
      'Если бы ваше сегодняшнее настроение было погодой, то какой?';

  @override
  String get explorePrompt14 =>
      'Запишите три мелочи, за которые вы сегодня благодарны.';

  @override
  String get explorePrompt15 =>
      'Есть ли песня, которую вы в последнее время слушаете на повторе?';

  @override
  String get explorePrompt16 => 'Что сегодня прошло лучше, чем вы ожидали?';

  @override
  String get explorePrompt17 =>
      'Если бы можно было оставить одну фразу себе через год, какой бы она была?';

  @override
  String get explorePrompt18 =>
      'Где вы провели большую часть дня? Каким было это место?';

  @override
  String get explorePrompt19 =>
      'Что вас в последнее время утомляет и как можно о себе позаботиться?';

  @override
  String get explorePrompt20 =>
      'Когда вы в последний раз смеялись в голос и почему?';

  @override
  String get exploreOnThisDayEmpty =>
      'В прошлые годы в этот день записей пока нет. То, что вы напишете сегодня, появится здесь через год.';

  @override
  String get exploreRandomShuffle => 'Другая запись';

  @override
  String get exploreRandomEmpty => 'Подходящих старых записей пока нет';

  @override
  String get exploreRecapTitleWeek => 'Итоги недели';

  @override
  String get exploreRecapTitleMonth => 'Итоги месяца';

  @override
  String get exploreRecapTitleYear => 'Итоги года';

  @override
  String get exploreRecapTopMood => 'Самое частое настроение';

  @override
  String get exploreRecapTopTag => 'Самый частый тег';

  @override
  String exploreRecapMore(int count) {
    return 'На $count больше, чем в прошлый раз';
  }

  @override
  String exploreRecapFewer(int count) {
    return 'На $count меньше, чем в прошлый раз';
  }

  @override
  String get exploreRecapSame => 'Столько же, сколько в прошлый раз';

  @override
  String get exploreMetricEntries => 'Записи';

  @override
  String get exploreMetricWords => 'Слова';

  @override
  String get exploreMetricRecordedDays => 'Дни с записями';

  @override
  String get exploreMetricCurrentStreak => 'Текущая серия';

  @override
  String get exploreMetricLongestStreak => 'Самая длинная серия';

  @override
  String get exploreMetricAverageWords => 'Слов на запись';

  @override
  String get exploreMetricPhotos => 'Фото';

  @override
  String get exploreMetricTags => 'Использовано тегов';

  @override
  String get exploreMetricSpan => 'Срок ведения';

  @override
  String get exploreMetricTodayWords => 'Слов сегодня';

  @override
  String get exploreMilestoneEntries => 'Записи';

  @override
  String get exploreMilestoneWords => 'Слова';

  @override
  String get exploreMilestoneStreak => 'Самая длинная серия';

  @override
  String get exploreMilestoneDays => 'Дни с записями';

  @override
  String get exploreMilestoneYears => 'Годы';

  @override
  String exploreMilestoneNext(String target, String remaining) {
    return 'Далее: $target · осталось $remaining';
  }

  @override
  String get exploreMilestoneAllDone => 'Все достигнуты';

  @override
  String exploreMilestoneAchieved(int count) {
    return 'Достигнуто: $count';
  }

  @override
  String exploreUnitEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи',
      many: '$count записей',
      few: '$count записи',
      one: '$count запись',
    );
    return '$_temp0';
  }

  @override
  String exploreUnitWords(String words) {
    return '$words сл.';
  }

  @override
  String exploreUnitYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count года',
      many: '$count лет',
      few: '$count года',
      one: '$count год',
    );
    return '$_temp0';
  }

  @override
  String exploreUnitTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count раза',
      many: '$count раз',
      few: '$count раза',
      one: '$count раз',
    );
    return '$_temp0';
  }

  @override
  String exploreHeatmapSummary(int days, int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days дня',
      many: '$days дней',
      few: '$days дня',
      one: '$days день',
    );
    return '$_temp0 с записями за последние $weeks нед.';
  }

  @override
  String exploreHeatmapDay(String date, int count, String words) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи',
      many: '$count записей',
      few: '$count записи',
      one: '$count запись',
    );
    return '$date · $_temp0 · слов: $words';
  }

  @override
  String exploreHeatmapDayEmpty(String date) {
    return '$date · Нет записей';
  }

  @override
  String get exploreHeatmapLess => 'Меньше';

  @override
  String get exploreHeatmapMore => 'Больше';

  @override
  String exploreTotalEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Всего $count записи',
      many: 'Всего $count записей',
      few: 'Всего $count записи',
      one: 'Всего $count запись',
    );
    return '$_temp0';
  }

  @override
  String exploreTotalWords(String words) {
    return 'Всего слов: $words';
  }

  @override
  String get exploreSlotLateNight => 'Глубокая ночь';

  @override
  String get exploreSlotMorning => 'Утро';

  @override
  String get exploreSlotForenoon => 'До полудня';

  @override
  String get exploreSlotAfternoon => 'День';

  @override
  String get exploreSlotEvening => 'Вечер';

  @override
  String get exploreSlotNight => 'Ночь';

  @override
  String exploreHabitsTopSlot(String slot) {
    return 'Чаще всего: $slot';
  }

  @override
  String exploreHabitsTopWeekday(String weekday) {
    return 'Самый активный день: $weekday';
  }

  @override
  String get exploreHabitsTimeOfDay => 'Время суток';

  @override
  String get exploreHabitsWeekdays => 'Дни недели';

  @override
  String exploreLastDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Последние $days дня',
      many: 'Последние $days дней',
      few: 'Последние $days дня',
      one: 'Последний $days день',
    );
    return '$_temp0';
  }

  @override
  String exploreMoodAverage(String mood) {
    return 'Среднее настроение: $mood';
  }

  @override
  String get exploreMoodTrendEmpty =>
      'В последнее время настроение не отмечалось';

  @override
  String get exploreMoodShareEmpty => 'За этот период настроение не отмечалось';

  @override
  String exploreEnergyAverage(String value) {
    return 'В среднем: $value';
  }

  @override
  String get exploreEnergyEmpty =>
      'В последнее время уровень энергии не отмечался';

  @override
  String get explorePlacesEmpty =>
      'Добавляйте место к записям — и здесь появятся ваши любимые места.';

  @override
  String get exploreWeatherEmpty =>
      'Отмечайте погоду в записях, чтобы видеть её здесь.';

  @override
  String get exploreAnniversariesEmpty => 'Памятных дат пока нет';

  @override
  String get exploreAnniversariesAdd => 'Добавить памятную дату';

  @override
  String get exploreAnniversariesAll => 'Все памятные даты';

  @override
  String exploreCapsulesWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count капсулы ждут открытия',
      many: '$count капсул ждут открытия',
      few: '$count капсулы ждут открытия',
      one: '$count капсула ждёт открытия',
    );
    return '$_temp0';
  }

  @override
  String exploreCapsuleOpensIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Откроется через $count дня',
      many: 'Откроется через $count дней',
      few: 'Откроется через $count дня',
      one: 'Откроется через $count день',
    );
    return '$_temp0';
  }

  @override
  String get exploreCapsuleOpensToday => 'Откроется сегодня';

  @override
  String get exploreCapsulesRecent => 'Недавно открытые';

  @override
  String get exploreCapsulesEmpty =>
      'Капсул времени пока нет. Запечатайте запись при публикации, чтобы отправить её себе в будущее.';

  @override
  String get exploreNotebooksEmpty => 'Блокнотов пока нет';

  @override
  String get exploreNotebooksManage => 'Управление блокнотами';

  @override
  String exploreDraftsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count черновика ждут продолжения',
      many: '$count черновиков ждут продолжения',
      few: '$count черновика ждут продолжения',
      one: '$count черновик ждёт продолжения',
    );
    return '$_temp0';
  }

  @override
  String get exploreDraftsContinue => 'Продолжить';

  @override
  String get exploreDraftsManage => 'Управление';

  @override
  String get exploreCustomize => 'Настроить «Обзор»';

  @override
  String get exploreModuleMenuSettings => 'Настройки карточки';

  @override
  String get exploreGroupRecall => 'Воспоминания и идеи';

  @override
  String get exploreGroupStats => 'Графики';

  @override
  String get exploreGroupLife => 'Повседневность';

  @override
  String get exploreGroupLinked => 'Связанные функции';

  @override
  String get exploreLayoutTabPresets => 'Наборы';

  @override
  String get exploreLayoutTabCards => 'Карточки';

  @override
  String get exploreLayoutTabAppearance => 'Вид';

  @override
  String get exploreLayoutTabRange => 'Период';

  @override
  String get exploreLayoutResetDone => 'Восстановлен макет по умолчанию';

  @override
  String get exploreLayoutCardsHint =>
      'Перетаскивайте маркер, чтобы изменить порядок; нажмите на строку, чтобы увидеть параметры.';

  @override
  String get exploreLayoutCardsShowAll => 'Показать все';

  @override
  String get exploreLayoutCardsDefaultOrder => 'Порядок по умолчанию';

  @override
  String get exploreLayoutFeatureOff => 'Отключено в разделе «Функции»';

  @override
  String exploreLayoutDragHandle(String name) {
    return 'Перетащите, чтобы переместить «$name»';
  }

  @override
  String exploreLayoutShowModule(String name) {
    return 'Показывать «$name»';
  }

  @override
  String exploreLayoutMultiHint(int max) {
    return 'В порядке выбора, не более $max';
  }

  @override
  String get exploreLayoutSpan => 'Ширина на широком экране';

  @override
  String get exploreLayoutSpanFull => 'Вся строка';

  @override
  String get exploreLayoutSpanHalf => 'Половина';

  @override
  String get exploreLayoutPreviewMine => 'Мои данные';

  @override
  String get exploreLayoutPreviewSample => 'Демо-данные';

  @override
  String get exploreLayoutCustom => 'Свой';

  @override
  String get exploreSamplePlaceHome => 'Дом';

  @override
  String get exploreSamplePlaceOffice => 'Офис';

  @override
  String get settingsExploreLayout => 'Страница «Обзор»';

  @override
  String settingsExploreLayoutSubtitle(String name) {
    return 'Сейчас: $name';
  }

  @override
  String get exploreOptLunar => 'Дата по лунному календарю';

  @override
  String get exploreOptPrompt => 'Тема дня';

  @override
  String get exploreOptWrite => 'Кнопка «Написать»';

  @override
  String get exploreOptMatch => 'Совпадение';

  @override
  String get exploreOptStyle => 'Стиль';

  @override
  String get exploreOptCount => 'Количество';

  @override
  String get exploreOptSource => 'Выбирать из';

  @override
  String get exploreOptPhotosOnly => 'Только записи с обложкой';

  @override
  String get exploreOptDaily => 'Одна запись на весь день';

  @override
  String get exploreOptRecapPeriod => 'Период';

  @override
  String get exploreOptCompare => 'Сравнивать с прошлым периодом';

  @override
  String get exploreOptKinds => 'Вехи';

  @override
  String get exploreOptAchieved => 'Показывать число достигнутых';

  @override
  String get exploreOptMetrics => 'Показатели';

  @override
  String get exploreOptColumns => 'Столбцы';

  @override
  String get exploreOptHeatmapSpan => 'Охват';

  @override
  String get exploreOptBasis => 'Окраска';

  @override
  String get exploreOptWeekdayLabels => 'Подписи дней недели';

  @override
  String get exploreOptLegend => 'Легенда';

  @override
  String get exploreOptUnit => 'Группировка';

  @override
  String get exploreOptMetric => 'Что считать';

  @override
  String get exploreOptTimeOfDay => 'Время суток';

  @override
  String get exploreOptWeekdays => 'Дни недели';

  @override
  String get exploreOptDays => 'Период';

  @override
  String get exploreOptChart => 'Диаграмма';

  @override
  String get exploreOptDayMoods => 'Учитывать настроение дня';

  @override
  String get exploreOptSort => 'Сортировка';

  @override
  String get exploreOptPercent => 'Показывать проценты';

  @override
  String get exploreOptInline => 'Учитывать фото в тексте записей';

  @override
  String get exploreOptRecent => 'Показывать недавно открытые';

  @override
  String get exploreValFollowLanguage => 'По языку';

  @override
  String get exploreValShow => 'Показать';

  @override
  String get exploreValHide => 'Скрыть';

  @override
  String get exploreValSameDay => 'Тот же день';

  @override
  String get exploreValNearby => 'В пределах 3 дней';

  @override
  String get exploreValSameMonth => 'Тот же месяц';

  @override
  String get exploreValCarousel => 'Карусель';

  @override
  String get exploreValList => 'Список';

  @override
  String get exploreValAll => 'Все';

  @override
  String get exploreValMonthAgo => 'Более месяца назад';

  @override
  String get exploreValYearAgo => 'Более года назад';

  @override
  String get exploreValWeeks12 => '12 недель';

  @override
  String get exploreValHalfYear => 'Полгода';

  @override
  String get exploreValYear => 'Год';

  @override
  String get exploreValEntries => 'Записи';

  @override
  String get exploreValWords => 'Слова';

  @override
  String get exploreValMood => 'Настроение';

  @override
  String get exploreValByMonth => 'По месяцам';

  @override
  String get exploreValByWeek => 'По неделям';

  @override
  String get exploreValByDay => 'По дням';

  @override
  String get exploreValPixels => 'Пиксели';

  @override
  String get exploreValLine => 'Линия';

  @override
  String get exploreValBars => 'Столбцы';

  @override
  String get exploreValByCount => 'По количеству';

  @override
  String get exploreValByMood => 'По настроению';

  @override
  String get exploreValRanking => 'Рейтинг';

  @override
  String get exploreValManual => 'Свой порядок';

  @override
  String get exploreValRecent => 'Недавние';

  @override
  String get exploreValStrip => 'Лента';

  @override
  String get exploreValGrid => 'Сетка';

  @override
  String get exploreValMosaic => 'Мозаика';

  @override
  String get exploreValIcons => 'Значки';

  @override
  String get exploreValShelf => 'Как на полке';

  @override
  String get exploreValUpdated => 'Недавно изменённые';

  @override
  String get exploreValByEntries => 'По числу записей';

  @override
  String get exploreValAuto => 'Авто';

  @override
  String exploreValColumns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count столбца',
      many: '$count столбцов',
      few: '$count столбца',
      one: '$count столбец',
    );
    return '$_temp0';
  }

  @override
  String get explorePresetBalanced => 'Сбалансированный';

  @override
  String get explorePresetBalancedDesc =>
      'Повседневный набор: с одного взгляда видно, как идут дела';

  @override
  String get explorePresetMinimal => 'Минимум';

  @override
  String get explorePresetMinimalDesc =>
      'Только приветствие, воспоминания, цифры и фото';

  @override
  String get explorePresetDataLover => 'Любитель данных';

  @override
  String get explorePresetDataLoverDesc =>
      'Все графики: тепловая карта, ритм, привычки, настроение и энергия';

  @override
  String get explorePresetMemories => 'Воспоминания';

  @override
  String get explorePresetMemoriesDesc =>
      'В этот день, случайные воспоминания, итоги, капсулы и памятные даты';

  @override
  String get explorePresetEverything => 'Всё';

  @override
  String get explorePresetEverythingDesc => 'Включены все 20 карточек';

  @override
  String get exploreLookCards => 'Карточки';

  @override
  String get exploreLookDensity => 'Плотность';

  @override
  String get exploreLookCompact => 'Компактно';

  @override
  String get exploreLookStandard => 'Стандартно';

  @override
  String get exploreLookRelaxed => 'Свободно';

  @override
  String get exploreLookRadius => 'Скругление углов';

  @override
  String get exploreLookSurface => 'Поверхность';

  @override
  String get exploreLookFilled => 'Заливка';

  @override
  String get exploreLookTonal => 'Тон';

  @override
  String get exploreLookOutlined => 'Контур';

  @override
  String get exploreLookSurfaceGlassNote =>
      'При материале «Стекло» карточки всегда стеклянные.';

  @override
  String get exploreLookAccent => 'Акцент';

  @override
  String get exploreLookPrimary => 'Основной';

  @override
  String get exploreLookSecondary => 'Дополнительный';

  @override
  String get exploreLookTertiary => 'Третий';

  @override
  String get exploreLookText => 'Заголовки и числа';

  @override
  String get exploreLookHeading => 'Заголовки карточек';

  @override
  String get exploreLookBadge => 'Бейдж';

  @override
  String get exploreLookIcon => 'Значок';

  @override
  String get exploreLookTextOnly => 'Текст';

  @override
  String get exploreLookHidden => 'Скрыто';

  @override
  String get exploreLookCompactNumbers => 'Сокращать большие числа';

  @override
  String get exploreLookCompactNumbersSubtitle =>
      'Показывать 12 345 как «12 тыс.»';

  @override
  String get exploreLookAnimations => 'Анимация графиков';

  @override
  String get exploreLookAnimationsSubtitle =>
      'При появлении графики вырастают, а числа нарастают';

  @override
  String get exploreLookWide => 'Широкие экраны';

  @override
  String get exploreLookWideFooter =>
      'На узких экранах, например на телефонах, всегда один столбец.';

  @override
  String get exploreLookColumns => 'Столбцы';

  @override
  String get exploreLookFlow => 'Расположение';

  @override
  String get exploreLookRows => 'Ряды';

  @override
  String get exploreLookStaggered => 'Каскад';

  @override
  String get exploreRangeBar => 'Показывать панель периода';

  @override
  String get exploreRangeBarSubtitle =>
      'Переключение между неделей, месяцем, годом и всем временем вверху «Обзора»';

  @override
  String get exploreRangeCurrent => 'Период';

  @override
  String get exploreRangeFooter =>
      'Период влияет на сводку, теги, привычки письма, распределение настроений, места и погоду; у остальных карточек свои временные рамки.';

  @override
  String get exploreSampleWeatherSunny => 'Солнечно';

  @override
  String get exploreSampleWeatherCloudy => 'Облачно';

  @override
  String get exploreSampleWeatherOvercast => 'Пасмурно';

  @override
  String get exploreSampleWeatherRain => 'Небольшой дождь';

  @override
  String get exploreSampleWeatherFog => 'Туман';

  @override
  String get settingsFeaturesComments => 'Комментарии';

  @override
  String get settingsFeaturesCommentsSubtitle =>
      'Оставляйте заметки в конце записи, когда перечитываете её; сама запись не меняется';

  @override
  String diaryCommentsHeading(int count) {
    return 'Комментарии · $count';
  }

  @override
  String get diaryCommentsWrite => 'Написать комментарий…';

  @override
  String diaryCommentsExpand(int count) {
    return 'Показать ещё $count';
  }

  @override
  String get diaryCommentsCollapse => 'Свернуть';

  @override
  String get diaryCommentEdited => 'Изменено';

  @override
  String get diaryCommentSameDay => 'В тот же день';

  @override
  String diaryCommentDaysLater(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Через $count дня',
      many: 'Через $count дней',
      few: 'Через $count дня',
      one: 'Через $count день',
    );
    return '$_temp0';
  }

  @override
  String diaryCommentMonthsLater(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Через $count месяца',
      many: 'Через $count месяцев',
      few: 'Через $count месяца',
      one: 'Через $count месяц',
    );
    return '$_temp0';
  }

  @override
  String diaryCommentYearsLater(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Через $count года',
      many: 'Через $count лет',
      few: 'Через $count года',
      one: 'Через $count год',
    );
    return '$_temp0';
  }

  @override
  String diaryCommentYearsMonthsLater(int years, int months) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$years года',
      many: '$years лет',
      few: '$years года',
      one: '$years год',
    );
    String _temp1 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months месяца',
      many: '$months месяцев',
      few: '$months месяца',
      one: '$months месяц',
    );
    return 'Через $_temp0 и $_temp1';
  }

  @override
  String get diaryCommentSheetNew => 'Написать комментарий';

  @override
  String get diaryCommentSheetEdit => 'Изменить комментарий';

  @override
  String get diaryCommentHint => 'Несколько слов себе из прошлого…';

  @override
  String get diaryCommentMoodLabel => 'Настроение';

  @override
  String get diaryCommentMoodOptional => 'Необязательно';

  @override
  String get diaryCommentCopy => 'Копировать';

  @override
  String get diaryCommentCopied => 'Комментарий скопирован';

  @override
  String get diaryCommentDeleted => 'Комментарий удалён';

  @override
  String get diaryCommentSaveFailed =>
      'Не удалось сохранить комментарий. Повторите попытку.';

  @override
  String get diaryCommentActionsHint => 'изменить, скопировать или удалить';

  @override
  String get diaryCommentAddImages => 'Добавить фото';

  @override
  String diaryCommentImagesFull(int max) {
    return 'Не более $max фото';
  }

  @override
  String diaryCommentImagesTruncated(int max) {
    return 'К комментарию можно добавить не более $max фото — лишние не добавлены';
  }

  @override
  String get diaryCommentImageAddFailed =>
      'Не удалось добавить фото. Повторите попытку.';

  @override
  String get diaryCommentImagePermissionDenied =>
      'Нет разрешения на доступ к фото';

  @override
  String get diaryCommentImageRemove => 'Удалить фото';

  @override
  String get diaryCommentImageAdding => 'Добавление фото';

  @override
  String diaryCommentImageCount(int count) {
    return '$count фото';
  }

  @override
  String diaryCommentImageLabel(int index, int count) {
    return 'Фото $index из $count';
  }

  @override
  String diaryCommentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count комментария',
      many: '$count комментариев',
      few: '$count комментария',
      one: '$count комментарий',
    );
    return '$_temp0';
  }

  @override
  String get diaryPreviewStyleShowComments => 'Число комментариев';

  @override
  String get diaryCardStyleShowComments => 'Число комментариев';

  @override
  String diarySearchCommentHit(String text) {
    return 'Упоминается в комментарии: $text';
  }

  @override
  String get exploreModuleComments => 'Недавние комментарии';

  @override
  String get exploreModuleCommentsDesc =>
      'Ваши последние комментарии и то, как вы возвращаетесь к записям';

  @override
  String exploreCommentsDiaries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'к $count записи',
      many: 'к $count записям',
      few: 'к $count записям',
      one: 'к $count записи',
    );
    return '$_temp0';
  }

  @override
  String exploreCommentsAverageGap(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'в среднем перечитываете через $days дня',
      many: 'в среднем перечитываете через $days дней',
      few: 'в среднем перечитываете через $days дня',
      one: 'в среднем перечитываете через $days день',
    );
    return '$_temp0';
  }

  @override
  String get exploreCommentsEmpty =>
      'Напишите первый комментарий в конце записи';

  @override
  String get exploreSampleComment => 'Спасибо себе из прошлого за упорство.';

  @override
  String get diaryPreviewSampleComment1 =>
      'Если оглянуться назад, тот день был не так уж плох.';

  @override
  String get diaryPreviewSampleComment2 =>
      'В итоге поездка всё-таки состоялась — и оказалась даже лучше, чем представлялось.';

  @override
  String get diaryExportIncludeComments => 'Включить комментарии';

  @override
  String get diaryExportCommentsHeading => 'Комментарии';

  @override
  String backupImportCommentMergeResult(int added) {
    return 'Комментарии: добавлено $added';
  }

  @override
  String backupImportCommentOverwriteResult(int added, int replaced) {
    return 'Комментарии: добавлено $added, перезаписано $replaced';
  }

  @override
  String get diaryEditorTable => 'Таблица';

  @override
  String get diaryTableInsertRowAbove => 'Строка выше';

  @override
  String get diaryTableInsertRowBelow => 'Строка ниже';

  @override
  String get diaryTableInsertColumnLeft => 'Столбец слева';

  @override
  String get diaryTableInsertColumnRight => 'Столбец справа';

  @override
  String get diaryTableDeleteRow => 'Удалить строку';

  @override
  String get diaryTableDeleteColumn => 'Удалить столбец';

  @override
  String get diaryTableHeaderRow => 'Строка заголовка';

  @override
  String get diaryTableDelete => 'Удалить таблицу';

  @override
  String diaryLinkUntitled(String date) {
    return 'Запись от $date';
  }

  @override
  String get diaryLinkGroupDiaries => 'Записи';

  @override
  String get diaryLinkGroupNotebooks => 'Блокноты';

  @override
  String get diaryLinkGroupWeb => 'Веб';

  @override
  String get diaryLinkEmpty => 'Нет подходящих записей или блокнотов';

  @override
  String get diaryLinkMenuHint =>
      'Начните вводить название записи или блокнота';

  @override
  String get diaryLinkMenuLabel => 'Ссылка на запись или блокнот';

  @override
  String get diaryLinkSearchDiaries => 'Поиск по заголовкам записей';

  @override
  String get diaryLinkSearchNotebooks => 'Поиск блокнотов';

  @override
  String get diaryLinkOpen => 'Открыть';

  @override
  String get diaryLinkRemove => 'Удалить ссылку';

  @override
  String get diaryLinkCurrentDiary => 'Ссылка на запись';

  @override
  String get diaryLinkCurrentNotebook => 'Ссылка на блокнот';

  @override
  String get diaryLinkMissingDiary => 'Эта запись больше не существует';

  @override
  String get diaryLinkMissingNotebook => 'Этот блокнот больше не существует';

  @override
  String get diaryEditorDiaryCard => 'Карточка записи';

  @override
  String get diaryEditorNotebookCard => 'Карточка блокнота';

  @override
  String get diaryLinkCardPrivate => 'Личная запись';

  @override
  String diaryLinkCardSealed(String date) {
    return 'Откроется $date';
  }

  @override
  String diaryLinkCardNotebookCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи',
      many: '$count записей',
      few: '$count записи',
      one: '$count запись',
    );
    return '$_temp0';
  }

  @override
  String get diaryLinkCardToInline => 'Преобразовать в ссылку в тексте';

  @override
  String get diaryLinkCardMenu => 'Параметры карточки';

  @override
  String diaryBacklinksTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Упоминается в $count записи',
      many: 'Упоминается в $count записях',
      few: 'Упоминается в $count записях',
      one: 'Упоминается в $count записи',
    );
    return '$_temp0';
  }

  @override
  String diaryBacklinksShowAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Показать все $count',
      many: 'Показать все $count',
      few: 'Показать все $count',
      one: 'Показать все $count',
    );
    return '$_temp0';
  }

  @override
  String notebookBacklinksChip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Упоминается в $count записи',
      many: 'Упоминается в $count записях',
      few: 'Упоминается в $count записях',
      one: 'Упоминается в $count записи',
    );
    return '$_temp0';
  }

  @override
  String get notebookBacklinksTitle =>
      'Записи, в которых упоминается этот блокнот';

  @override
  String get lanSyncTitle => 'Синхронизация по локальной сети';

  @override
  String get lanSyncEntrySubtitleUnpaired =>
      'Синхронизация записей между устройствами в одной сети Wi-Fi';

  @override
  String lanSyncEntrySubtitlePaired(int count, String ago) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Сопряжено $count устройства',
      many: 'Сопряжено $count устройств',
      few: 'Сопряжено $count устройства',
      one: 'Сопряжено $count устройство',
    );
    return '$_temp0 · синхронизировано $ago';
  }

  @override
  String lanSyncEntrySubtitlePairedNever(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Сопряжено $count устройства',
      many: 'Сопряжено $count устройств',
      few: 'Сопряжено $count устройства',
      one: 'Сопряжено $count устройство',
    );
    return '$_temp0 · ещё не синхронизировано';
  }

  @override
  String get lanSyncEntrySubtitleAttention =>
      'Синхронизация ждёт вашего подтверждения';

  @override
  String get lanSyncDefaultDeviceName => 'Это устройство';

  @override
  String lanSyncLocalPlatform(String platform) {
    return 'Это устройство · $platform';
  }

  @override
  String get lanSyncPlatformAndroid => 'Android';

  @override
  String get lanSyncPlatformIos => 'iOS';

  @override
  String get lanSyncPlatformLinux => 'Linux';

  @override
  String get lanSyncPlatformWindows => 'Windows';

  @override
  String get lanSyncPlatformMacos => 'macOS';

  @override
  String get lanSyncPlatformUnknown => 'Другое устройство';

  @override
  String get lanSyncRenameTooltip => 'Переименовать устройство';

  @override
  String get lanSyncRenameTitle => 'Имя устройства';

  @override
  String get lanSyncRenameHint => 'Это имя увидят устройства поблизости';

  @override
  String get lanSyncDiscoverable => 'Видно поблизости';

  @override
  String get lanSyncNotDiscoverable => 'Скрыто';

  @override
  String get lanSyncDiscoverableToggleHint =>
      'Изменить, могут ли устройства поблизости найти это устройство';

  @override
  String get lanSyncNoNetwork => 'Нет локальной сети';

  @override
  String get lanSyncCopyAddressHint => 'Копировать адрес';

  @override
  String get lanSyncAddressCopied => 'Адрес скопирован';

  @override
  String get lanSyncScanQr => 'Сканировать QR-код';

  @override
  String get lanSyncShowQr => 'Показать QR-код';

  @override
  String get lanSyncManualAddress => 'Ввести адрес';

  @override
  String get lanSyncTroubleshoot => 'Не удаётся найти устройство?';

  @override
  String get lanSyncSearchingNearbyJotsy => 'Ищем Jotsy поблизости…';

  @override
  String get lanSyncSectionMyDevices => 'Мои устройства';

  @override
  String lanSyncDeviceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count устройства',
      many: '$count устройств',
      few: '$count устройства',
      one: '$count устройство',
    );
    return '$_temp0';
  }

  @override
  String get lanSyncSectionNearby => 'Устройства поблизости';

  @override
  String get lanSyncSearching => 'Поиск';

  @override
  String get lanSyncNearbyEmpty =>
      'Других Jotsy поблизости пока не найдено. Откройте эту страницу и на другом устройстве.';

  @override
  String get lanSyncSectionOptions => 'Параметры синхронизации';

  @override
  String get lanSyncAutoSync => 'Автосинхронизация';

  @override
  String get lanSyncAutoSyncSubtitle =>
      'Синхронизироваться с сопряжёнными устройствами автоматически, пока Jotsy открыт';

  @override
  String get lanSyncSyncSettings => 'Синхронизировать настройки';

  @override
  String get lanSyncSyncSettingsSubtitle =>
      'Если включить на обоих устройствах, синхронизируются и настройки оформления, редактора и другие. Порядок тегов и включение функций вроде комментариев или блокнотов синхронизируются всегда';

  @override
  String get lanSyncOnline => 'В сети';

  @override
  String get lanSyncOffline => 'Не в сети';

  @override
  String lanSyncSyncedAgo(String ago) {
    return 'синхронизировано $ago';
  }

  @override
  String get lanSyncNeverSynced => 'ещё не синхронизировано';

  @override
  String lanSyncNearbySubtitle(String platform, String address) {
    return '$platform · $address';
  }

  @override
  String get lanSyncNeedsAttention => 'Требуется ваше подтверждение';

  @override
  String get lanSyncReview => 'Посмотреть';

  @override
  String get lanSyncSyncButton => 'Синхр.';

  @override
  String get lanSyncPair => 'Сопрячь';

  @override
  String get lanSyncStageConnecting => 'Подключение…';

  @override
  String get lanSyncStageComparing => 'Сравнение…';

  @override
  String get lanSyncStageTransferring => 'Передача…';

  @override
  String get lanSyncStageMerging => 'Объединение…';

  @override
  String get lanSyncFirstUseTitle => 'Сопряжённых устройств пока нет';

  @override
  String get lanSyncFirstUseBody =>
      'Записи передаются напрямую между вашими устройствами в локальной сети — с шифрованием на всём пути и без участия сервера.';

  @override
  String get lanSyncFirstUseStep1 =>
      'Подключите оба устройства к одной сети Wi-Fi';

  @override
  String get lanSyncFirstUseStep2 =>
      'На другом устройстве откройте «Настройки › Синхронизация по локальной сети»';

  @override
  String get lanSyncFirstUseStep3 =>
      'Нажмите «Сопрячь» в разделе «Устройства поблизости» или отсканируйте QR-код';

  @override
  String lanSyncPortBusyNotice(int port) {
    return 'Порт $port занят другим приложением, поэтому это устройство не может ни найти другие, ни быть найденным. Вы по-прежнему можете ввести адрес или отсканировать QR-код.';
  }

  @override
  String get lanSyncTipWifiTitle => 'Одна сеть Wi-Fi';

  @override
  String get lanSyncTipWifiBody =>
      'Оба устройства должны быть в одной сети. Гостевые сети и роутеры с включённой изоляцией клиентов (AP isolation) блокируют обнаружение.';

  @override
  String get lanSyncTipVpnTitle => 'VPN или прокси';

  @override
  String get lanSyncTipVpnBody =>
      'Если на одном из устройств работает VPN или прокси (например, Clash), трафик локальной сети может уходить в туннель, и устройства перестают видеть друг друга или подключаться. Временно отключите VPN или включите в приложении прокси параметр «Обход частных сетей / LAN».';

  @override
  String get lanSyncTipOpenPageTitle =>
      'Откройте эту страницу на другом устройстве';

  @override
  String get lanSyncTipOpenPageBody =>
      'Пока эта страница открыта, устройства чаще сообщают о себе и поэтому находятся быстрее.';

  @override
  String get lanSyncTipWindowsTitle => 'Брандмауэр Windows';

  @override
  String get lanSyncTipWindowsBody =>
      'Если при первом запуске Windows спросит о брандмауэре, разрешите Jotsy доступ к частным сетям.';

  @override
  String get lanSyncTipLinuxTitle => 'Брандмауэр Linux';

  @override
  String lanSyncTipLinuxBody(int udpPort, int tcpPort) {
    return 'Если брандмауэр включён, разрешите UDP $udpPort и TCP $tcpPort.';
  }

  @override
  String get lanSyncTipFallbackTitle => 'Всё ещё не находится?';

  @override
  String get lanSyncTipFallbackBody =>
      'Введите адрес другого устройства вручную или отсканируйте QR-код, который оно показывает.';

  @override
  String get lanSyncManualIntro =>
      'Адрес другого устройства указан на его странице синхронизации. После подключения подтвердите сопряжение на обоих устройствах.';

  @override
  String get lanSyncManualHostLabel => 'Адрес';

  @override
  String get lanSyncManualHostHint => 'например, 192.168.1.23';

  @override
  String get lanSyncManualPortLabel => 'Порт';

  @override
  String get lanSyncManualHostInvalid =>
      'Введите корректный IP-адрес или имя хоста';

  @override
  String get lanSyncManualPortInvalid => 'Порт должен быть от 1 до 65535';

  @override
  String get lanSyncManualConnect => 'Подключить';

  @override
  String lanSyncAutoSyncApplied(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи',
      many: '$count записей',
      few: '$count записи',
      one: '$count запись',
    );
    return 'Синхронизировано с «$name»: $_temp0';
  }

  @override
  String lanSyncAutoSyncNeedsAttention(String name) {
    return 'Синхронизация с «$name» требует вашего подтверждения';
  }

  @override
  String lanSyncPairConnecting(String name) {
    return 'Подключение к $name…';
  }

  @override
  String lanSyncPairTitleOutgoing(String name) {
    return 'Сопряжение с «$name»';
  }

  @override
  String lanSyncPairTitleIncoming(String name) {
    return '«$name» запрашивает сопряжение';
  }

  @override
  String get lanSyncPairSubtitle =>
      'Убедитесь, что на обоих устройствах показано одно и то же число';

  @override
  String lanSyncPairCodeSemantics(String first, String second) {
    return 'Код сопряжения $first $second';
  }

  @override
  String get lanSyncPairSafetyNote =>
      'После сопряжения все записи обоих устройств объединяются в обе стороны (включая личные блокноты и корзину). Соединение защищено сквозным шифрованием и никогда не проходит через сервер.';

  @override
  String get lanSyncPairExportBackup => 'Сначала экспортировать полную копию';

  @override
  String get lanSyncPairMismatch => 'Не совпадает';

  @override
  String get lanSyncPairConfirm => 'Совпадает, сопрячь';

  @override
  String get lanSyncPairTimeoutNote =>
      'Отменится автоматически, если не подтвердить в течение 60 секунд';

  @override
  String get lanSyncPairWaitingPeer => 'Ожидание другого устройства…';

  @override
  String lanSyncPairSucceeded(String name) {
    return 'Сопряжено с $name';
  }

  @override
  String get lanSyncPairSyncNow => 'Синхронизировать';

  @override
  String get lanSyncPairLater => 'Позже';

  @override
  String get lanSyncPairFailedTitle => 'Сопряжение не завершено';

  @override
  String lanSyncPairAuthReason(String name) {
    return 'Подтвердите личность, чтобы выполнить сопряжение с «$name»';
  }

  @override
  String get lanSyncPairAuthFailed =>
      'Проверка личности не пройдена, сопряжение ещё не подтверждено';

  @override
  String get lanSyncPairAuthUnsupported =>
      'На этом устройстве включена блокировка приложения или есть заблокированные блокноты, но не настроена блокировка экрана, поэтому подтвердить личность невозможно. Сначала настройте блокировку экрана в системных настройках.';

  @override
  String get lanSyncPairFailUnreachable =>
      'Не удалось связаться с другим устройством. Проверьте адрес и порт и убедитесь, что оба устройства подключены к одной сети Wi-Fi, а VPN выключен.';

  @override
  String get lanSyncPairFailConnectionLost =>
      'Соединение прервалось. Выполните сопряжение ещё раз.';

  @override
  String get lanSyncPairFailTimedOut =>
      'Сопряжение не подтвердили в течение 60 секунд, поэтому оно отменено.';

  @override
  String get lanSyncPairFailDeclined =>
      'Другое устройство отменило сопряжение, или числа не совпали.';

  @override
  String get lanSyncPairFailCancelled => 'Сопряжение отменено.';

  @override
  String get lanSyncPairFailIncompatible =>
      'На устройствах установлены несовместимые версии Jotsy. Обновите приложение на более старом.';

  @override
  String get lanSyncPairFailUntrusted =>
      'Другое устройство отклонило подключение. Выполните сопряжение заново на обоих устройствах.';

  @override
  String get lanSyncPairFailTicketExpired =>
      'Срок действия QR-кода истёк. Попросите показать новый и отсканируйте снова.';

  @override
  String get lanSyncPairFailWriteFailed =>
      'Не удалось сохранить сопряжение. Попробуйте ещё раз.';

  @override
  String get lanSyncPairFailUnknown =>
      'Сопряжение не завершено. Попробуйте ещё раз.';

  @override
  String get lanSyncPairFailBusy =>
      'Уже идёт другое сопряжение. Завершите или закройте его и попробуйте снова.';

  @override
  String get lanSyncQrTitle => 'Сопряжение по QR-коду';

  @override
  String get lanSyncQrSubtitle =>
      'На другом телефоне нажмите в Jotsy «Сканировать QR-код»';

  @override
  String get lanSyncQrSemantics => 'QR-код для сопряжения';

  @override
  String lanSyncQrCountdown(String time) {
    return 'Новый код через $time';
  }

  @override
  String lanSyncQrDeviceLine(String name, String address) {
    return '$name · $address';
  }

  @override
  String get lanSyncQrSingleUse =>
      'Каждый код действует один раз и перестаёт работать после сканирования';

  @override
  String get lanSyncQrPreparing => 'Подготовка QR-кода…';

  @override
  String get lanSyncQrUseCode => 'Сопряжение по коду';

  @override
  String lanSyncQrUseCodeHint(String name) {
    return 'На другом устройстве найдите «$name» в разделе «Устройства поблизости» и нажмите «Сопрячь»';
  }

  @override
  String get lanSyncScanHint =>
      'Наведите камеру на QR-код Jotsy на другом устройстве';

  @override
  String get lanSyncScanHintDetail =>
      'На том устройстве нажмите «Показать QR-код» на странице синхронизации';

  @override
  String get lanSyncScanTorchOn => 'Включить фонарик';

  @override
  String get lanSyncScanTorchOff => 'Выключить фонарик';

  @override
  String get lanSyncScanManual => 'Нет QR-кода? Введите адрес';

  @override
  String get lanSyncScanNotJotsy => 'Это не код сопряжения Jotsy';

  @override
  String get lanSyncScanNewerVersion =>
      'Этот код из более новой версии Jotsy. Сначала обновите приложение';

  @override
  String get lanSyncScanMalformed => 'Код повреждён. Попросите показать новый';

  @override
  String get lanSyncScanDeniedTitle => 'Нужен доступ к камере';

  @override
  String get lanSyncScanDeniedBody =>
      'Чтобы сканировать, камера считывает QR-код на другом устройстве. Разрешите Jotsy использовать камеру в системных настройках или введите адрес вручную.';

  @override
  String get lanSyncScanOpenSettings => 'Открыть настройки';

  @override
  String get lanSyncScanUnavailableTitle => 'Камера недоступна';

  @override
  String get lanSyncScanUnavailableBody =>
      'Подходящая камера не найдена, или её использует другое приложение. Можно ввести адрес вручную.';

  @override
  String get lanSyncFlowLocal => 'Это устройство';

  @override
  String lanSyncFlowSent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи',
      many: '$count записей',
      few: '$count записи',
      one: '$count запись',
    );
    return '↑ Отправлено: $_temp0';
  }

  @override
  String lanSyncFlowReceived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи',
      many: '$count записей',
      few: '$count записи',
      one: '$count запись',
    );
    return '↓ Получено: $_temp0';
  }

  @override
  String get lanSyncStepConnect => 'Подключение';

  @override
  String get lanSyncStepCompare => 'Сравнение';

  @override
  String get lanSyncStepTransfer => 'Передача';

  @override
  String get lanSyncStepMerge => 'Объединение';

  @override
  String get lanSyncMediaTransferring => 'Передача фото и аудиозаписей';

  @override
  String lanSyncMediaFiles(int done, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total файла',
      many: '$total файлов',
      few: '$total файла',
      one: '$total файл',
    );
    return '$done / $_temp0';
  }

  @override
  String lanSyncMediaBytes(String done, String total) {
    return '$done / $total';
  }

  @override
  String lanSyncMediaBytesSpeed(String done, String total, String speed) {
    return '$done / $total · $speed/s';
  }

  @override
  String lanSyncSessionSemantics(String stage, int percent) {
    return '$stage, выполнено $percent%';
  }

  @override
  String get lanSyncSummaryTitle => 'Синхронизация завершена';

  @override
  String lanSyncSummarySubtitle(String name, int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds секунды',
      many: '$seconds секунд',
      few: '$seconds секунды',
      one: '$seconds секунду',
    );
    return '$name · за $_temp0';
  }

  @override
  String get lanSyncSummaryReceived => '↓ Получено';

  @override
  String get lanSyncSummarySent => '↑ Отправлено';

  @override
  String lanSyncSummaryDiaryUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'записи',
      many: 'записей',
      few: 'записи',
      one: 'запись',
    );
    return '$_temp0';
  }

  @override
  String get lanSyncSummaryAdded => 'Добавлено';

  @override
  String get lanSyncSummaryUpdated => 'Обновлено';

  @override
  String get lanSyncSummaryDeleted => 'Удалено';

  @override
  String get lanSyncSummaryMedia => 'Медиафайлы';

  @override
  String lanSyncSummaryMediaValue(int count, String size) {
    return '$count · $size';
  }

  @override
  String get lanSyncSummaryOthers => 'Другое';

  @override
  String lanSyncSummaryConflicts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи изменено',
      many: '$count записей изменено',
      few: '$count записи изменены',
      one: '$count запись изменена',
    );
    return '$_temp0 на обоих устройствах — сохранены обе версии';
  }

  @override
  String get lanSyncSummaryConflictHint =>
      'В исходной записи осталась более новая версия';

  @override
  String get lanSyncUntitled => 'Без названия';

  @override
  String get lanSyncSummaryFootnote =>
      'Теги, блокноты, комментарии и памятные даты тоже объединены';

  @override
  String lanSyncSummaryOtherDetail(String items) {
    return 'Другие изменения: $items';
  }

  @override
  String get lanSyncSummaryDone => 'Готово';

  @override
  String get lanSyncSummaryUpToDate => 'Всё уже актуально';

  @override
  String get lanSyncSummaryFailedTitle => 'Синхронизация не завершена';

  @override
  String get lanSyncSyncFailUnreachable =>
      'Не удалось связаться с другим устройством. Убедитесь, что оба устройства подключены к одной сети Wi-Fi, VPN выключен, а на другом устройстве открыт Jotsy.';

  @override
  String get lanSyncSyncFailConnectionLost =>
      'Соединение прервалось. То, что уже записано, будет дополнено при следующей синхронизации.';

  @override
  String get lanSyncSyncFailTimedOut =>
      'Другое устройство перестало отвечать. То, что уже записано, будет дополнено при следующей синхронизации.';

  @override
  String get lanSyncSyncFailDeclined =>
      'Другое устройство отклонило эту синхронизацию.';

  @override
  String get lanSyncSyncFailCancelled =>
      'Синхронизация отменена. То, что уже записано, будет дополнено при следующей синхронизации.';

  @override
  String get lanSyncSyncFailIncompatible =>
      'На устройствах установлены несовместимые версии Jotsy. Обновите приложение на более старом и синхронизируйте снова.';

  @override
  String get lanSyncSyncFailUntrusted =>
      'Другое устройство больше не считает это устройство сопряжённым. Отмените сопряжение и выполните его заново.';

  @override
  String get lanSyncSyncFailTicketExpired =>
      'Срок действия QR-кода истёк. Отсканируйте новый, чтобы подключиться.';

  @override
  String get lanSyncSyncFailWriteFailed =>
      'Не удалось записать данные на это устройство — возможно, закончилось место. Освободите место и попробуйте снова.';

  @override
  String get lanSyncSyncFailUnknown =>
      'Синхронизация не завершена. Попробуйте ещё раз.';

  @override
  String get lanSyncSyncFailBusy =>
      'На другом устройстве сейчас редактируют запись. Синхронизируйте снова, когда там закроют редактор.';

  @override
  String get lanSyncSyncFailLocalEditing =>
      'На этом устройстве открыта страница редактирования. Закройте её, а затем синхронизируйте.';

  @override
  String get lanSyncSyncFailDeferred =>
      'Было открыто уведомление с отменой действия, поэтому ничего не записано. Синхронизируйте снова, когда оно исчезнет.';

  @override
  String get lanSyncSyncFailNeedsConfirmation =>
      'Эта синхронизация требует вашего подтверждения. Нажмите «Посмотреть» в списке устройств, чтобы продолжить.';

  @override
  String get lanSyncSyncReasonUnreachable => 'Устройство недоступно';

  @override
  String get lanSyncSyncReasonConnectionLost => 'Соединение прервалось';

  @override
  String get lanSyncSyncReasonTimedOut => 'Нет ответа';

  @override
  String get lanSyncSyncReasonDeclined => 'Отклонено другим устройством';

  @override
  String get lanSyncSyncReasonCancelled => 'Отменено';

  @override
  String get lanSyncSyncReasonIncompatible => 'Несовместимые версии';

  @override
  String get lanSyncSyncReasonUntrusted =>
      'Сопряжение удалено на другом устройстве';

  @override
  String get lanSyncSyncReasonTicketExpired => 'QR-код истёк';

  @override
  String get lanSyncSyncReasonWriteFailed =>
      'Не удалось записать на это устройство';

  @override
  String get lanSyncSyncReasonUnknown => 'Ошибка синхронизации';

  @override
  String get lanSyncSyncReasonBusy => 'На другом устройстве шло редактирование';

  @override
  String get lanSyncSyncReasonLocalEditing =>
      'На этом устройстве шло редактирование';

  @override
  String get lanSyncSyncReasonDeferred => 'Было открыто уведомление с отменой';

  @override
  String get lanSyncSyncReasonNeedsConfirmation => 'Требовалось подтверждение';

  @override
  String lanSyncConflictCopySuffix(String device) {
    return ' (конфликтная копия · $device)';
  }

  @override
  String get lanSyncChooseSideTitle => 'Какую версию оставить?';

  @override
  String lanSyncChooseSideBody(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи изменено',
      many: '$count записей изменено',
      few: '$count записи изменены',
      one: '$count запись изменена',
    );
    return '$_temp0 и здесь, и на устройстве «$name». Как их объединить?';
  }

  @override
  String lanSyncChooseSideBodyItems(String name, String items) {
    return 'Изменено и здесь, и на устройстве «$name»: $items. Как это объединить?';
  }

  @override
  String get lanSyncItemDiaries => 'Записи';

  @override
  String get lanSyncItemTags => 'Теги';

  @override
  String get lanSyncItemNotebooks => 'Блокноты';

  @override
  String get lanSyncItemComments => 'Комментарии';

  @override
  String get lanSyncItemTemplates => 'Шаблоны';

  @override
  String get lanSyncItemAnniversaries => 'Памятные даты';

  @override
  String get lanSyncItemDayMoods => 'Настроения дней';

  @override
  String get lanSyncItemTodos => 'Задачи';

  @override
  String get lanSyncItemSettings => 'Настройки';

  @override
  String lanSyncItemCount(String label, int count) {
    return '$label: $count';
  }

  @override
  String get lanSyncChooseKeepBoth => 'Сохранить обе (рекомендуется)';

  @override
  String get lanSyncChooseKeepBothDesc =>
      'Более новая версия остаётся в записи, другая сохраняется как конфликтная копия';

  @override
  String get lanSyncChoosePreferLocal => 'Версия этого устройства';

  @override
  String get lanSyncChoosePreferLocalDesc =>
      'Версия этого устройства заменит изменения на другом устройстве';

  @override
  String get lanSyncChoosePreferPeer => 'Версия другого устройства';

  @override
  String lanSyncChoosePreferPeerDesc(String name) {
    return 'Версия с устройства «$name» заменит изменения на этом устройстве';
  }

  @override
  String get lanSyncChooseSideNote => 'Ни один из вариантов не удаляет записи';

  @override
  String get lanSyncContinueSync => 'Продолжить';

  @override
  String get lanSyncDeletionTitle => 'Удалить записи навсегда?';

  @override
  String lanSyncDeletionBodyPeer(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи',
      many: '$count записей',
      few: '$count записи',
      one: '$count запись',
    );
    return 'Эта синхронизация навсегда удалит $_temp0 на устройстве «$name» (на этом устройстве они уже удалены из корзины).';
  }

  @override
  String lanSyncDeletionBodyLocal(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи',
      many: '$count записей',
      few: '$count записи',
      one: '$count запись',
    );
    return 'Эта синхронизация навсегда удалит $_temp0 на этом устройстве (на устройстве «$name» они уже удалены из корзины).';
  }

  @override
  String get lanSyncDeletionSync => 'Удалить везде';

  @override
  String get lanSyncDeletionSyncDesc =>
      'Записи не останутся ни на одном из устройств';

  @override
  String get lanSyncDeletionKeep =>
      'Оставить и восстановить на другом устройстве';

  @override
  String get lanSyncDeletionKeepDesc =>
      'Записи вернутся на устройство, где их удалили из корзины';

  @override
  String get lanSyncDeviceTitle => 'Об устройстве';

  @override
  String get lanSyncInfoLastSync => 'Последняя синхронизация';

  @override
  String get lanSyncInfoPairedAt => 'Сопряжено';

  @override
  String get lanSyncInfoAddress => 'Адрес';

  @override
  String get lanSyncInfoNever => 'Никогда';

  @override
  String get lanSyncInfoNoAddress => 'Неизвестно';

  @override
  String get lanSyncDeviceOffline => 'Устройство не в сети';

  @override
  String get lanSyncOfflineUseLastAddress =>
      'Не в сети — будет использован последний известный адрес';

  @override
  String get lanSyncPeerAutoSyncSubtitle =>
      'Синхронизироваться с этим устройством автоматически, пока приложение открыто';

  @override
  String get lanSyncPeerAutoSyncGlobalOff =>
      'Автосинхронизация выключена в «Параметрах синхронизации», поэтому пока это не действует';

  @override
  String get lanSyncAliasTitle => 'Псевдоним';

  @override
  String get lanSyncAliasNotSet => 'Не задан';

  @override
  String get lanSyncAliasLocalOnly => 'Виден только на этом устройстве';

  @override
  String lanSyncAliasDialogHint(String name) {
    return 'Оставьте пустым, чтобы показывать «$name»';
  }

  @override
  String get lanSyncHistoryTitle => 'История синхронизации';

  @override
  String get lanSyncHistoryEmpty =>
      'С этим устройством ещё не было синхронизаций';

  @override
  String get lanSyncHistoryAutomatic => 'Авто';

  @override
  String lanSyncHistoryDuration(int seconds) {
    return '$seconds с';
  }

  @override
  String lanSyncHistoryReceived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи',
      many: '$count записей',
      few: '$count записи',
      one: '$count запись',
    );
    return '↓ Получено: $_temp0';
  }

  @override
  String lanSyncHistorySent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи',
      many: '$count записей',
      few: '$count записи',
      one: '$count запись',
    );
    return '↑ Отправлено: $_temp0';
  }

  @override
  String lanSyncHistoryOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count другого изменения',
      many: '$count других изменений',
      few: '$count других изменения',
      one: '$count другое изменение',
    );
    return '$_temp0';
  }

  @override
  String lanSyncHistoryMedia(String size) {
    return 'Медиафайлы: $size';
  }

  @override
  String lanSyncHistoryConflicts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count конфликтной копии',
      many: '$count конфликтных копий',
      few: '$count конфликтные копии',
      one: '$count конфликтная копия',
    );
    return '$_temp0';
  }

  @override
  String get lanSyncForget => 'Отменить сопряжение';

  @override
  String lanSyncForgetTitle(String name) {
    return 'Отменить сопряжение с «$name»?';
  }

  @override
  String get lanSyncForgetBody =>
      'Записи не будут удалены ни на одном из устройств. Чтобы снова синхронизироваться, понадобится повторное сопряжение.';

  @override
  String get settingsFeaturesAi => 'ИИ-помощник';

  @override
  String get settingsFeaturesAiSubtitle =>
      'Письмо, отклики, итоги и чат через ваш собственный API ИИ';

  @override
  String get aiPersonaAssistantName => 'Помощник по дневнику';

  @override
  String get aiPersonaAssistantDesc =>
      'Чётко и объективно — для вопросов и кратких итогов';

  @override
  String get aiPersonaAssistantPrompt =>
      'Ты — помощник пользователя по дневнику. Тебе доступны записи, которыми делится пользователь. Опирайся в ответах на эти записи, отвечай ясно, объективно и структурированно. Если в чём-то нет уверенности, прямо скажи об этом и никогда не выдумывай того, чего нет в дневнике.';

  @override
  String get aiPersonaListenerName => 'Чуткий слушатель';

  @override
  String get aiPersonaListenerDesc => 'Сначала поймёт, потом мягко ответит';

  @override
  String get aiPersonaListenerPrompt =>
      'Ты — тёплый и терпеливый слушатель. Прочитав запись пользователя, сначала покажи, что понимаешь и принимаешь выраженные в ней чувства, а затем мягко ответь. Не осуждай и не поучай, советуй поменьше — вместо этого проявляй сочувствие и поддержку. В конце можно задать один мягкий вопрос, который побудит пользователя ещё немного поразмышлять.';

  @override
  String get aiPersonaFriendName => 'Близкий друг';

  @override
  String get aiPersonaFriendDesc => 'Болтает непринуждённо, как старый друг';

  @override
  String get aiPersonaFriendPrompt =>
      'Ты — друг, которого пользователь знает много лет. Ты говоришь естественно, непринуждённо и искренне, умеешь и пошутить, и поговорить всерьёз. Отвечай так, как ответил бы друг, прочитав дневник близкого человека: упомяни замеченные детали, поделись своими чувствами и давай практические советы, только когда это действительно поможет.';

  @override
  String get aiPersonaCoachName => 'Коуч по развитию';

  @override
  String get aiPersonaCoachDesc =>
      'Видит ваш прогресс и следующий маленький шаг';

  @override
  String get aiPersonaCoachPrompt =>
      'Ты — позитивный и практичный коуч по личностному росту. Найди в записи усилия, прогресс и то, за что стоит похвалить пользователя, укажи на закономерности, которые можно улучшить, и предложи от одного до трёх конкретных и выполнимых небольших действий. Подбадривай, но без пустых слов.';

  @override
  String get aiPersonaAnalystName => 'Вдумчивый аналитик';

  @override
  String get aiPersonaAnalystDesc =>
      'Спокойно разбирает, что случилось и почему';

  @override
  String get aiPersonaAnalystPrompt =>
      'Ты — спокойный, рациональный аналитик. Помоги пользователю разобраться, что произошло в записи, какие причины за этим стоят и какие есть варианты действий. Отделяй факты от чувств и указывай на стороны, которые могли остаться незамеченными. Пиши кратко и структурированно.';

  @override
  String get aiPersonaCounselorName => 'Как психолог';

  @override
  String get aiPersonaCounselorDesc =>
      'Вопросами помогает разобраться в своих чувствах';

  @override
  String get aiPersonaCounselorPrompt =>
      'Ты отвечаешь так, как это часто делает психолог-консультант: слушаешь, отражаешь и проясняешь сказанное и с помощью открытых вопросов помогаешь пользователю осознать свои эмоции и потребности, не торопясь с выводами и советами. Ты не заменяешь профессиональную психотерапию. Если в записи есть мысли о причинении вреда себе или другим, мягко посоветуй пользователю обратиться к близким людям или к специалистам.';

  @override
  String get aiPersonaPoetName => 'Поэт';

  @override
  String get aiPersonaPoetDesc => 'Отвечает на ваш день языком поэзии';

  @override
  String get aiPersonaPoetPrompt =>
      'Ты — нежный поэт. Отвечай на запись пользователя образным, поэтичным, но не туманным языком. Можно написать короткое стихотворение в прозе или несколько стихотворных строк, передающих настроение и образы этого дня.';

  @override
  String get aiPersonaPhilosopherName => 'Философ';

  @override
  String get aiPersonaPhilosopherDesc => 'Смотрит на всё шире';

  @override
  String get aiPersonaPhilosopherPrompt =>
      'Ты — доброжелательный философ. Начинай с маленьких конкретных вещей из записи и связывай их с большими вопросами — смыслом, выбором, временем, отношениями. Используй уместные идеи или метафоры, оставайся понятным и в конце возвращайся к жизни самого пользователя.';

  @override
  String get aiPersonaFutureSelfName => 'Я из будущего';

  @override
  String get aiPersonaFutureSelfDesc =>
      'Ответ от вас самих — десять лет спустя';

  @override
  String get aiPersonaFutureSelfPrompt =>
      'Ты — этот же пользователь, только десять лет спустя, и ты перечитываешь эту запись. Напиши от первого лица короткое письмо себе в прошлом: тёплое, с пониманием того, как всё сложилось потом, со спокойствием и мудростью, которые приносит время, но не выдумывай конкретных событий будущего.';

  @override
  String get aiPersonaRoastName => 'Друг-язва';

  @override
  String get aiPersonaRoastDesc => 'Язык острый, сердце доброе';

  @override
  String get aiPersonaRoastPrompt =>
      'Ты — друг с острым языком и добрым сердцем. С юмором и преувеличениями подшучивай над тем, что произошло в записи, но никогда не высмеивай настоящую боль пользователя и не касайся чувствительных тем вроде внешности или идентичности. В конце дай понять, что тебе не всё равно.';

  @override
  String get aiActionContinue => 'Дописать';

  @override
  String get aiActionContinuePrompt =>
      'Продолжи запись ниже в том же стиле и тоне одним естественным абзацем примерно на 80–150 слов. Пиши только новый текст и не повторяй уже написанное.';

  @override
  String get aiActionPolish => 'Улучшить текст';

  @override
  String get aiActionPolishPrompt =>
      'Отредактируй текст ниже, чтобы он читался плавнее и естественнее. Исправь неуклюжие формулировки, сохрани смысл, тон и повествование от первого лица и не делай текст длиннее.';

  @override
  String get aiActionExpand => 'Расширить';

  @override
  String get aiActionExpandPrompt =>
      'Расширь текст ниже, добавив деталей, чувств и образов, чтобы он стал богаче — примерно вдвое длиннее. Сохрани исходный тон и точку зрения.';

  @override
  String get aiActionShorten => 'Сократить';

  @override
  String get aiActionShortenPrompt =>
      'Сократи текст ниже примерно вдвое. Сохрани ключевую информацию и чувства, убери повторы и лишние слова.';

  @override
  String get aiActionProofread => 'Исправить ошибки';

  @override
  String get aiActionProofreadPrompt =>
      'Исправь орфографические, пунктуационные и грамматические ошибки в тексте ниже. Всё остальное оставь в точности как есть и не переписывай.';

  @override
  String get aiActionToneFormal => 'Официальнее';

  @override
  String get aiActionToneFormalPrompt =>
      'Перепиши текст ниже в более официальном и выдержанном тоне, сохранив смысл.';

  @override
  String get aiActionToneCasual => 'Непринуждённее';

  @override
  String get aiActionToneCasualPrompt =>
      'Перепиши текст ниже в более непринуждённом, разговорном тоне, будто это болтовня с другом, сохранив смысл.';

  @override
  String get aiActionToneWarm => 'Теплее';

  @override
  String get aiActionToneWarmPrompt =>
      'Перепиши текст ниже так, чтобы он звучал теплее и мягче, с большей добротой и заботой, сохранив смысл.';

  @override
  String get aiActionToneHumor => 'Смешнее';

  @override
  String get aiActionToneHumorPrompt =>
      'Перепиши текст ниже смешнее — с игривой метафорой или долей самоиронии, сохранив смысл.';

  @override
  String get aiActionToneLiterary => 'Литературнее';

  @override
  String get aiActionToneLiteraryPrompt =>
      'Перепиши текст ниже более литературным языком: с тонкими описаниями и уместными художественными приёмами, но без нагромождения вычурных слов. Сохрани смысл.';

  @override
  String get aiActionTranslate => 'Перевести';

  @override
  String get aiActionTranslatePrompt =>
      'Переведи текст ниже. Если он в основном на русском, переведи его на английский; иначе переведи на русский. Выведи только перевод.';

  @override
  String get aiActionSummarize => 'Кратко изложить';

  @override
  String get aiActionSummarizePrompt =>
      'Кратко изложи основные мысли текста ниже в двух-трёх предложениях.';

  @override
  String get aiActionBulletPoints => 'Список тезисов';

  @override
  String get aiActionBulletPointsPrompt =>
      'Преврати текст ниже в понятный маркированный список (неупорядоченный список Markdown) с короткими пунктами.';

  @override
  String get aiActionExtractTodos => 'Выделить задачи';

  @override
  String get aiActionExtractTodosPrompt =>
      'Найди в тексте ниже упомянутые задачи, планы и дела, которые требуют продолжения, и оформи их как список задач Markdown — по одной на строке, каждая начинается с «- [ ] ». Если ничего такого нет, ответь одной строкой, что задач не найдено.';

  @override
  String get aiActionPoem => 'Превратить в стих';

  @override
  String get aiActionPoemPrompt =>
      'Преврати текст ниже в короткое современное стихотворение из 4–12 строк, сохранив его настроение и образы.';

  @override
  String get aiErrorNotConfigured =>
      'ИИ-модель ещё не настроена. Добавьте провайдера в «Настройки → ИИ-помощник».';

  @override
  String get aiErrorNetwork =>
      'Не удалось связаться с ИИ-сервисом. Проверьте сеть, адрес API или прокси.';

  @override
  String get aiErrorTimeout => 'ИИ-сервис слишком долго не отвечал.';

  @override
  String get aiErrorUnauthorized => 'API-ключ недействителен или не указан.';

  @override
  String get aiErrorForbidden =>
      'У этого ключа нет доступа к модели, или сервис недоступен в вашем регионе.';

  @override
  String get aiErrorModelNotFound =>
      'Модель или адрес не найдены. Проверьте название модели и адрес API.';

  @override
  String get aiErrorRateLimited =>
      'Слишком много запросов. Попробуйте ещё раз чуть позже.';

  @override
  String get aiErrorQuota => 'На счёте закончились средства или квота.';

  @override
  String get aiErrorContextTooLong =>
      'Слишком много текста для этой модели. Уменьшите лимит слов в настройках конфиденциальности ИИ или выберите модель с более длинным контекстом.';

  @override
  String get aiErrorContentFiltered =>
      'ИИ-сервис отклонил этот запрос согласно своей политике в отношении контента.';

  @override
  String get aiErrorBadRequest =>
      'ИИ-сервис отклонил запрос. Проверьте дополнительные настройки провайдера.';

  @override
  String get aiErrorServer =>
      'В ИИ-сервисе произошёл сбой, или он перегружен. Попробуйте позже.';

  @override
  String get aiErrorBadResponse =>
      'Не удалось разобрать ответ. Возможно, адрес указывает на веб-страницу, а не на API.';

  @override
  String get aiErrorCancelled => 'Остановлено';

  @override
  String get aiErrorDetails => 'Подробнее';

  @override
  String get aiErrorOpenSettings => 'Открыть настройки';

  @override
  String get aiSettingsTitle => 'ИИ-помощник';

  @override
  String get aiSettingsEntrySubtitle =>
      'Провайдеры, модели, персоны и конфиденциальность';

  @override
  String get aiSettingsFooter =>
      'Ничего не проходит через разработчика: запросы идут напрямую с этого устройства к настроенному вами провайдеру. API-ключи хранятся только на этом устройстве и не попадают в резервные копии и синхронизацию.';

  @override
  String get aiStatusNotConfiguredTitle => 'ИИ-сервис не настроен';

  @override
  String get aiStatusNotConfiguredBody =>
      'Добавьте провайдера и его API-ключ — и функции ИИ появятся в редакторе, на странице просмотра и на главном экране. Содержимое отправляется только в настроенный вами сервис.';

  @override
  String get aiStatusAddProvider => 'Добавить провайдера';

  @override
  String get aiStatusDefaultModel => 'Модель по умолчанию';

  @override
  String get aiStatusTest => 'Проверить подключение';

  @override
  String get aiStatusTesting => 'Проверка…';

  @override
  String aiStatusTestOk(int ms) {
    return 'Подключено · $ms мс';
  }

  @override
  String get aiGroupService => 'Сервис';

  @override
  String get aiProvidersTitle => 'Провайдеры';

  @override
  String aiProvidersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count провайдера',
      many: '$count провайдеров',
      few: '$count провайдера',
      one: '$count провайдер',
    );
    return '$_temp0';
  }

  @override
  String get aiProvidersEmpty => 'Пока нет';

  @override
  String get aiRoutingTitle => 'Назначение моделей';

  @override
  String get aiRoutingSubtitle => 'Разные модели для разных функций';

  @override
  String get aiGroupFeatures => 'Функции';

  @override
  String get aiGroupFeaturesFooter =>
      'Выключение функции лишь скрывает её. Уже созданные ИИ материалы сохраняются.';

  @override
  String get aiModuleWriting => 'Помощник в письме';

  @override
  String get aiModuleWritingSubtitle =>
      'Продолжение, улучшение текста, смена тона, перевод и ваши команды в редакторе';

  @override
  String get aiModuleSuggest => 'Умное заполнение';

  @override
  String get aiModuleSuggestSubtitle =>
      'Генерация заголовков, подсказки тегов и настроения';

  @override
  String get aiModuleReply => 'Отклики ИИ';

  @override
  String get aiModuleReplySubtitle =>
      'ИИ прочитает запись и ответит вам на странице просмотра';

  @override
  String get aiModulePrompts => 'Идеи для письма';

  @override
  String get aiModulePromptsSubtitle =>
      'Несколько вопросов, когда не знаете, о чём написать';

  @override
  String get aiModuleRecap => 'Итоги и наблюдения';

  @override
  String get aiModuleRecapSubtitle =>
      'Сводки за неделю, месяц, год или по блокноту';

  @override
  String get aiModuleChat => 'Чат и действия';

  @override
  String get aiModuleChatSubtitle =>
      'Спрашивайте о дневнике или поручите ИИ искать, писать записи, наводить порядок и менять настройки';

  @override
  String get aiModuleVision => 'Распознавание изображений';

  @override
  String get aiModuleVisionSubtitle =>
      'Фото из записей и из чата отправляются вместе с текстом; если модель не принимает изображения — только текст';

  @override
  String get aiOptionTitleButton =>
      'Показывать «Создать заголовок» рядом с заголовком';

  @override
  String get aiOptionAutoSuggest => 'Подсказки на странице публикации';

  @override
  String get aiOptionAutoSuggestSubtitle =>
      'Запись отправляется один раз, чтобы предложить заголовок, теги и настроение; ничего не заполняется, пока вы не нажмёте';

  @override
  String get aiOptionAutoReply => 'Отклик после публикации';

  @override
  String get aiOptionAutoReplySubtitle =>
      'Каждая новая запись отправляется один раз для отклика';

  @override
  String get aiOptionPromptsStrip => 'Идеи в новых записях';

  @override
  String get aiOptionPromptsStripSubtitle =>
      'Ничего не отправляется, пока вы не нажмёте';

  @override
  String get aiOptionPromptsRecent => 'Учитывать недавние записи';

  @override
  String get aiOptionPromptsRecentSubtitle =>
      'Отправляются фрагменты последних записей, чтобы вопросы были более личными';

  @override
  String get aiOptionPromptStyle => 'Вставлять как';

  @override
  String get aiPromptStyleCallout => 'Выноска';

  @override
  String get aiPromptStyleQuote => 'Цитата';

  @override
  String get aiPromptStyleHeading => 'Заголовок';

  @override
  String get aiOptionRecapSections => 'Что включать в итоги';

  @override
  String get aiRecapSectionMood => 'Динамика настроения';

  @override
  String get aiRecapSectionEvents => 'Ключевые моменты';

  @override
  String get aiRecapSectionPeople => 'Люди рядом';

  @override
  String get aiRecapSectionGratitude => 'Благодарность';

  @override
  String get aiRecapSectionGrowth => 'Рост и перемены';

  @override
  String get aiRecapSectionQuotes => 'Запомнившиеся фразы';

  @override
  String get aiRecapSectionSuggestions => 'Следующие шаги';

  @override
  String get aiOptionRetrieval => 'Поиск записей';

  @override
  String get aiOptionRetrievalSubtitle =>
      'Умный поиск сначала разбирается в вопросе, поиск по ключевым словам ищет только совпадения слов, а недавние — читает лишь последние дни';

  @override
  String get aiRetrievalSmart => 'Умный';

  @override
  String get aiRetrievalKeyword => 'Ключевые слова';

  @override
  String get aiRetrievalRecent => 'Недавние';

  @override
  String get aiOptionRecentDays => 'Недавний период';

  @override
  String aiDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня',
      many: '$count дней',
      few: '$count дня',
      one: '$count день',
    );
    return '$_temp0';
  }

  @override
  String get aiOptionMaxCitations => 'Читать не более';

  @override
  String aiEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи',
      many: '$count записей',
      few: '$count записи',
      one: '$count запись',
    );
    return '$_temp0';
  }

  @override
  String get aiOptionShowReasoning => 'Показывать рассуждения';

  @override
  String get aiOptionShowTokens => 'Показывать расход токенов';

  @override
  String get aiOptionAutoTitle => 'Называть чаты автоматически';

  @override
  String get aiOptionVisionImages => 'Фото за один запрос';

  @override
  String aiPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count фото',
      many: '$count фото',
      few: '$count фото',
      one: '$count фото',
    );
    return '$_temp0';
  }

  @override
  String get aiOptionVisionSize => 'Размер фото';

  @override
  String get aiVisionSizeSmall => 'Маленький';

  @override
  String get aiVisionSizeMedium => 'Средний';

  @override
  String get aiVisionSizeLarge => 'Большой';

  @override
  String get aiGroupPersonal => 'Персонализация';

  @override
  String get aiPersonasTitle => 'Персоны';

  @override
  String get aiPersonasSubtitle => 'Чьим голосом звучат отклики, чат и итоги';

  @override
  String get aiActionsTitle => 'Команды для текста';

  @override
  String get aiActionsSubtitle =>
      'Порядок, скрытие, правка промптов и свои команды';

  @override
  String get aiProfileTitle => 'Обо мне и стиль';

  @override
  String get aiProfileSubtitle =>
      'Помогите ИИ лучше вас узнать (необязательно)';

  @override
  String get aiOutputLanguage => 'Язык ответов';

  @override
  String get aiLanguageFollowDiary => 'Как в записи';

  @override
  String get aiLanguageFollowApp => 'Как в приложении';

  @override
  String get aiLanguageCustom => 'Свой';

  @override
  String get aiLanguageCustomHint => 'Например: English, Français';

  @override
  String get aiResponseLength => 'Длина ответов';

  @override
  String get aiLengthShort => 'Кратко';

  @override
  String get aiLengthMedium => 'Средне';

  @override
  String get aiLengthLong => 'Подробно';

  @override
  String get aiCreativity => 'Креативность';

  @override
  String get aiCreativitySubtitle =>
      'Действует только у провайдеров, принимающих параметр temperature';

  @override
  String get aiCreativityPrecise => 'Точно';

  @override
  String get aiCreativityBalanced => 'Баланс';

  @override
  String get aiCreativityCreative => 'Творчески';

  @override
  String get aiGroupPrivacy => 'Конфиденциальность и расход';

  @override
  String get aiPrivacyTitle => 'Конфиденциальность';

  @override
  String get aiPrivacySubtitle => 'Что отправляется и какие записи исключены';

  @override
  String get aiUsageTitle => 'Расход';

  @override
  String get aiUsageSubtitle =>
      'Запросы и токены, отправленные с этого устройства';

  @override
  String get aiProvidersFooter =>
      'Если модель по умолчанию не выбрана, используется первый доступный провайдер. Изменить это можно в разделе «Назначение моделей».';

  @override
  String aiProviderModelsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count модели',
      many: '$count моделей',
      few: '$count модели',
      one: '$count модель',
      zero: 'Нет моделей',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderDisabled => 'Отключён';

  @override
  String get aiProviderNoKey => 'Нет ключа';

  @override
  String get aiPresetSheetTitle => 'Выберите провайдера';

  @override
  String get aiPresetGroupChina => 'Китайские сервисы';

  @override
  String get aiPresetGroupInternational => 'Международные сервисы';

  @override
  String get aiPresetGroupLocal => 'Локальный запуск';

  @override
  String get aiPresetGroupCustom => 'Свой API';

  @override
  String get aiPresetNameDashscope => 'Qwen (Alibaba Cloud)';

  @override
  String get aiPresetNameMoonshot => 'Kimi (Moonshot)';

  @override
  String get aiPresetNameZhipu => 'Zhipu GLM';

  @override
  String get aiPresetNameVolcengine => 'Doubao (Volcengine Ark)';

  @override
  String get aiPresetNameSiliconflow => 'SiliconFlow';

  @override
  String get aiPresetNameHunyuan => 'Tencent Hunyuan';

  @override
  String get aiPresetNameCustomOpenAi => 'API, совместимый с OpenAI';

  @override
  String get aiPresetNameCustomAnthropic => 'API, совместимый с Anthropic';

  @override
  String get aiPresetNameCustomGemini => 'Gemini API';

  @override
  String get aiProtocolOpenAi => 'Совместимый с OpenAI';

  @override
  String get aiProtocolAnthropic => 'Anthropic (Claude)';

  @override
  String get aiProtocolGemini => 'Google Gemini';

  @override
  String get aiProviderEditTitleNew => 'Добавить провайдера';

  @override
  String get aiProviderEditTitle => 'Изменить провайдера';

  @override
  String get aiProviderName => 'Название';

  @override
  String get aiProviderProtocol => 'Формат API';

  @override
  String get aiProviderBaseUrl => 'Адрес API';

  @override
  String get aiProviderBaseUrlHint => 'Например: https://api.example.com/v1';

  @override
  String get aiProviderApiKey => 'API-ключ';

  @override
  String get aiProviderApiKeyOptional =>
      'API-ключ (для локальных сервисов необязателен)';

  @override
  String get aiProviderGetKey => 'Получить ключ';

  @override
  String get aiProviderLocalHint =>
      'Чтобы подключиться с телефона к Ollama или LM Studio на компьютере, замените localhost на адрес компьютера в локальной сети и настройте сервер на прослушивание 0.0.0.0.';

  @override
  String get aiProviderModels => 'Модели';

  @override
  String get aiProviderFetchModels => 'Загрузить список моделей';

  @override
  String get aiProviderAddModel => 'Добавить вручную';

  @override
  String get aiProviderModelsEmpty =>
      'Моделей пока нет. Загрузите список у провайдера или добавьте название модели вручную.';

  @override
  String get aiProviderModelIdHint => 'Название модели, например deepseek-chat';

  @override
  String get aiModelVision => 'Изображения';

  @override
  String get aiModelReasoning => 'Рассуждения';

  @override
  String get aiModelEditTitle => 'Настройки модели';

  @override
  String get aiModelDisplayName => 'Отображаемое имя (необязательно)';

  @override
  String get aiModelVisionToggle => 'Принимает изображения';

  @override
  String get aiModelReasoningToggle => 'Запрашивать рассуждения';

  @override
  String get aiModelReasoningSubtitle =>
      'Просить модель показывать ход мыслей; если модель это не поддерживает, запрос повторяется без этого';

  @override
  String get aiModelToolsToggle => 'Поддерживает вызов инструментов';

  @override
  String get aiModelToolsSubtitle =>
      'Ассистент сможет сам выполнять действия в приложении; если модель это не поддерживает, остаются обычные ответы на вопросы';

  @override
  String get aiToolGetAppContext => 'Проверка даты и состояния приложения';

  @override
  String get aiToolReadGuide => 'Справка по приложению';

  @override
  String aiPromptAgentGuide(String index) {
    return 'Ниже — оглавление справки Jotsy. Когда пользователь спрашивает, как что-то сделать, где что находится или возможно ли это, сначала прочитай подходящую статью через read_guide и отвечай по ней; не выдумывай того, чего в приложении нет.\n$index';
  }

  @override
  String get aiHubQuickHelp => 'Что умеет Jotsy?';

  @override
  String aiToolOpenPage(String page) {
    return 'Открыть: $page';
  }

  @override
  String get aiToolPageUnavailable =>
      'Эта страница недоступна (функция выключена или не поддерживается на этом устройстве)';

  @override
  String get aiToolSearchDiaries => 'Поиск записей';

  @override
  String aiToolSearchDiariesFor(String query) {
    return 'Поиск записей: $query';
  }

  @override
  String aiToolFoundEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Найдено $count записи',
      many: 'Найдено $count записей',
      few: 'Найдено $count записи',
      one: 'Найдена $count запись',
      zero: 'Ничего не найдено',
    );
    return '$_temp0';
  }

  @override
  String aiToolReadDiaries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Чтение $count записи',
      many: 'Чтение $count записей',
      few: 'Чтение $count записей',
      one: 'Чтение $count записи',
    );
    return '$_temp0';
  }

  @override
  String aiToolReadEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Прочитано $count записи',
      many: 'Прочитано $count записей',
      few: 'Прочитано $count записи',
      one: 'Прочитана $count запись',
    );
    return '$_temp0';
  }

  @override
  String get aiToolDiaryStats => 'Статистика записей';

  @override
  String aiToolStatsEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи',
      many: '$count записей',
      few: '$count записи',
      one: '$count запись',
    );
    return '$_temp0';
  }

  @override
  String get aiToolListTags => 'Список тегов';

  @override
  String aiToolTagCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count тега',
      many: '$count тегов',
      few: '$count тега',
      one: '$count тег',
    );
    return '$_temp0';
  }

  @override
  String get aiToolListNotebooks => 'Список блокнотов';

  @override
  String aiToolNotebookCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count блокнота',
      many: '$count блокнотов',
      few: '$count блокнота',
      one: '$count блокнот',
    );
    return '$_temp0';
  }

  @override
  String get aiToolCalendarDay => 'Календарь на сегодня';

  @override
  String aiToolCalendarDayOf(String date) {
    return 'Календарь на $date';
  }

  @override
  String get aiToolListTodos => 'Список задач';

  @override
  String aiToolTodoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count задачи',
      many: '$count задач',
      few: '$count задачи',
      one: '$count задача',
    );
    return '$_temp0';
  }

  @override
  String get aiToolListAnniversaries => 'Список памятных дат';

  @override
  String aiToolAnniversaryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count памятной даты',
      many: '$count памятных дат',
      few: '$count памятные даты',
      one: '$count памятная дата',
    );
    return '$_temp0';
  }

  @override
  String get aiToolCreateDiary => 'Новая запись';

  @override
  String aiToolCreateDiaryNamed(String title) {
    return 'Новая запись: $title';
  }

  @override
  String aiToolDiaryCreated(String name) {
    return 'Сохранено: «$name»';
  }

  @override
  String get aiToolAppendDiary => 'Дописать в запись';

  @override
  String get aiToolUpdateDiary => 'Изменить данные записи';

  @override
  String aiToolDiaryChanged(String name) {
    return 'Изменено: «$name»';
  }

  @override
  String aiToolTagDiaries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Изменить теги $count записи',
      many: 'Изменить теги $count записей',
      few: 'Изменить теги $count записей',
      one: 'Изменить теги $count записи',
    );
    return '$_temp0';
  }

  @override
  String aiToolEntriesChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Изменено $count записи',
      many: 'Изменено $count записей',
      few: 'Изменено $count записи',
      one: 'Изменена $count запись',
    );
    return '$_temp0';
  }

  @override
  String get aiToolPinDiaries => 'Закрепить записи';

  @override
  String get aiToolUnpinDiaries => 'Открепить записи';

  @override
  String get aiToolArchiveDiaries => 'Архивировать записи';

  @override
  String get aiToolUnarchiveDiaries => 'Вернуть записи из архива';

  @override
  String aiToolTrashDiaries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Переместить $count записи в корзину',
      many: 'Переместить $count записей в корзину',
      few: 'Переместить $count записи в корзину',
      one: 'Переместить $count запись в корзину',
    );
    return '$_temp0';
  }

  @override
  String aiToolEntriesTrashed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'В корзине $count записи',
      many: 'В корзине $count записей',
      few: 'В корзине $count записи',
      one: 'В корзине $count запись',
    );
    return '$_temp0';
  }

  @override
  String get aiToolAddComment => 'Добавить комментарий';

  @override
  String aiToolCreateTag(String name) {
    return 'Создать тег: $name';
  }

  @override
  String aiToolRenameTag(String name) {
    return 'Изменить тег: $name';
  }

  @override
  String aiToolMergeTags(String from, String into) {
    return 'Объединить $from в $into';
  }

  @override
  String aiToolDeleteTag(String name) {
    return 'Удалить тег $name';
  }

  @override
  String aiToolCreateNotebook(String name) {
    return 'Создать блокнот: $name';
  }

  @override
  String aiToolRenameNotebook(String name) {
    return 'Переименовать блокнот: $name';
  }

  @override
  String aiToolAddToNotebook(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Добавить $count записи в блокнот',
      many: 'Добавить $count записей в блокнот',
      few: 'Добавить $count записи в блокнот',
      one: 'Добавить $count запись в блокнот',
    );
    return '$_temp0';
  }

  @override
  String aiToolRemoveFromNotebook(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Убрать $count записи из блокнота',
      many: 'Убрать $count записей из блокнота',
      few: 'Убрать $count записи из блокнота',
      one: 'Убрать $count запись из блокнота',
    );
    return '$_temp0';
  }

  @override
  String aiToolCreateTodo(String title) {
    return 'Новая задача: $title';
  }

  @override
  String aiToolUpdateTodos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Изменить $count задачи',
      many: 'Изменить $count задач',
      few: 'Изменить $count задачи',
      one: 'Изменить $count задачу',
    );
    return '$_temp0';
  }

  @override
  String aiToolCompleteTodos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Выполнить $count задачи',
      many: 'Выполнить $count задач',
      few: 'Выполнить $count задачи',
      one: 'Выполнить $count задачу',
    );
    return '$_temp0';
  }

  @override
  String aiToolDeleteTodos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Удалить $count задачи',
      many: 'Удалить $count задач',
      few: 'Удалить $count задачи',
      one: 'Удалить $count задачу',
    );
    return '$_temp0';
  }

  @override
  String aiToolCreateAnniversary(String title) {
    return 'Новая памятная дата: $title';
  }

  @override
  String get aiToolDeleteAnniversary => 'Удалить памятную дату';

  @override
  String aiToolSetDayMood(String date) {
    return 'Настроение на $date';
  }

  @override
  String get aiToolSetTheme => 'Изменить тему';

  @override
  String aiToolSetLanguage(String language) {
    return 'Язык интерфейса: $language';
  }

  @override
  String get aiToolSetFontScale => 'Изменить размер текста';

  @override
  String aiToolFeatureOn(String feature) {
    return 'Включить: $feature';
  }

  @override
  String aiToolFeatureOff(String feature) {
    return 'Выключить: $feature';
  }

  @override
  String get aiToolDone => 'Готово';

  @override
  String get aiToolListTodoLists => 'Списки задач';

  @override
  String aiToolTodoListCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count списка',
      many: '$count списков',
      few: '$count списка',
      one: '$count список',
    );
    return '$_temp0';
  }

  @override
  String aiToolReopenTodos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Вернуть $count задачи',
      many: 'Вернуть $count задач',
      few: 'Вернуть $count задачи',
      one: 'Вернуть $count задачу',
    );
    return '$_temp0';
  }

  @override
  String get aiToolEditTodoSteps => 'Изменить шаги задачи';

  @override
  String aiToolEditTodoStepsOf(String title) {
    return 'Изменить шаги: $title';
  }

  @override
  String aiToolCreateTodoList(String name) {
    return 'Создать список задач: $name';
  }

  @override
  String aiToolRenameTodoList(String name) {
    return 'Переименовать список задач: $name';
  }

  @override
  String aiToolDeleteTodoList(String name) {
    return 'Удалить список задач $name';
  }

  @override
  String aiToolDeleteTodoListCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Вместе с ним удалятся $count задачи',
      many: 'Вместе с ним удалятся $count задач',
      few: 'Вместе с ним удалятся $count задачи',
      one: 'Вместе с ним удалится $count задача',
    );
    return '$_temp0';
  }

  @override
  String get aiToolGetSettings => 'Посмотреть настройки';

  @override
  String get aiToolChangeSettingsAny => 'Изменить настройки';

  @override
  String aiToolChangeSetting(String name) {
    return 'Изменить настройку: $name';
  }

  @override
  String aiToolChangeSettings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Изменить $count настройки',
      many: 'Изменить $count настроек',
      few: 'Изменить $count настройки',
      one: 'Изменить $count настройку',
    );
    return '$_temp0';
  }

  @override
  String aiToolSettingName(String page, String setting) {
    return '$page · $setting';
  }

  @override
  String get aiToolArgNone => 'Нет';

  @override
  String get aiToolArgOn => 'Вкл.';

  @override
  String get aiToolArgOff => 'Выкл.';

  @override
  String get aiToolBlockedByEditor =>
      'Открыта страница редактирования — закройте её и повторите';

  @override
  String get aiAgentConfirmDelete => 'Удалить?';

  @override
  String get aiAgentConfirmChange => 'Внести это изменение?';

  @override
  String get aiAgentDelete => 'Удалить';

  @override
  String get aiAgentProceed => 'Выполнить';

  @override
  String get aiAgentUndo => 'Отменить';

  @override
  String get aiAgentStepUndone => 'Отменено';

  @override
  String aiAgentUndone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Отменено $count изменения',
      many: 'Отменено $count изменений',
      few: 'Отменено $count изменения',
      one: 'Отменено $count изменение',
    );
    return '$_temp0';
  }

  @override
  String aiAgentUndoFailed(String error) {
    return 'Не удалось отменить: $error';
  }

  @override
  String get aiAgentUndoConflictTitle => 'Изменено после этого';

  @override
  String get aiAgentUndoConflictBody =>
      'После изменения ИИ это редактировали ещё раз. Отмена перезапишет и эти правки. Всё равно отменить?';

  @override
  String get aiAgentUndoConflictAction => 'Всё равно отменить';

  @override
  String get aiOptionAgentChanges => 'Разрешить ИИ вносить изменения';

  @override
  String get aiOptionAgentChangesSubtitle =>
      'Создавать и править записи, упорядочивать теги и блокноты, добавлять задачи, менять настройки; любое изменение можно отменить, удаление — только после подтверждения';

  @override
  String get aiOptionAgentConfirm => 'Подтверждать каждое изменение';

  @override
  String get aiOptionAgentConfirmSubtitle =>
      'Если выключено, изменения выполняются сразу и их можно отменить; удаление всегда требует подтверждения';

  @override
  String get aiDestinationDiary => 'Эта запись';

  @override
  String get aiDestinationSearch => 'Поиск записей';

  @override
  String get aiAgentPreparing => 'Подготовка действия…';

  @override
  String get aiAgentStepFailed => 'Не получилось';

  @override
  String get aiAgentStepCancelled => 'Остановлено';

  @override
  String get aiAgentStepInterrupted => 'Прервано';

  @override
  String aiAgentOpenPage(String page) {
    return 'Открыть: $page';
  }

  @override
  String get aiAgentStepsExhausted =>
      'Лимит действий для этого ответа исчерпан. Напишите «продолжай», чтобы ИИ продолжил.';

  @override
  String get aiAgentIncomplete =>
      'Ответ оборвался, поэтому действия из него не выполнены.';

  @override
  String get aiConfirmSendAgent =>
      'ИИ будет при необходимости искать и читать записи (кроме приватных), не спрашивая каждый раз';

  @override
  String get aiConfirmSendAgentImages =>
      'ИИ будет при необходимости искать и читать записи и их фото (кроме приватных), не спрашивая каждый раз';

  @override
  String get aiOptionAgent => 'Разрешить ИИ использовать инструменты';

  @override
  String get aiOptionAgentSubtitle =>
      'Искать и считать записи, смотреть календарь и задачи, открывать страницы; если выключено или не поддерживается — только ответы по найденным записям';

  @override
  String get aiOptionAgentSteps => 'Максимум шагов на ответ';

  @override
  String get aiOptionAgentStepsSubtitle =>
      'За шаг можно вызвать несколько инструментов; последний шаг — только ответ';

  @override
  String get aiPromptAgentSystem =>
      'Ты можешь вызывать инструменты, чтобы смотреть и менять данные пользователя в Jotsy и открывать страницы приложения.\n- Когда нужны данные пользователя, сначала узнай их через инструменты, а не отвечай по памяти или наугад. Независимые вызовы можно отправлять вместе.\n- Делай только те изменения, о которых пользователь прямо попросил; если не ясно, какую запись или что менять, сначала спроси. Все изменения можно отменить; удаление приложение само просит подтвердить, поэтому если цель ясна, просто вызывай инструмент, не переспрашивая в чате.\n- Карточки под ответом создаёт только open_page: один вызов — одна карточка с названием записи, блокнота или страницы. Чтобы пользователь мог открыть несколько целей, вызови его для каждой.\n- Говори только о том, что действительно сделал: если нужный вызов не прошёл успешно, не пиши, что что-то открыто, изменено или что карточка ниже. Не пиши в ответе названия инструментов, аргументы, id или журнал своих действий.\n- Текст, написанный вместе с вызовами поиска или изменений, сворачивается, и пользователь его не видит; текст вместе с open_page показывается над карточками. Пиши выводы, пояснения и шаги там, где их видно, и не повторяй одно и то же дважды.\n- Упоминая запись, ставь в конце предложения её номер из результатов инструментов, например [D3] (он показывается как нажимаемая метка).\n- Для того, что пользователь должен сделать на странице сам (резервная копия, восстановление, импорт и экспорт, отправка, блокировка приложения, пароли, настройки поставщика ИИ, окончательное удаление и т. п.), дай кнопку перехода через open_page и объясни, что делать.\n- Если инструмент вернул ошибку, исправь вызов по её подсказке или попробуй иначе; если это правда невозможно, так и скажи.';

  @override
  String aiPromptAgentNow(String time) {
    return 'Сейчас $time.';
  }

  @override
  String get aiPromptAgentScopeDiary =>
      'Этот разговор посвящён следующей записи:';

  @override
  String aiPromptAgentScopeRange(String from, String to) {
    return 'Этот разговор касается только записей с $from по $to; используй этот период при поиске, если не сказано иначе.';
  }

  @override
  String aiPromptAgentImagesAttached(String refs) {
    return 'Фото, приложенные к этому сообщению, по порядку: $refs. Добавить их в записи можно параметром `images` у create_diary или append_to_diary либо через ![](P1) в тексте.';
  }

  @override
  String aiPromptImageNotSent(String label) {
    return '[Фото $label не отправлено: эта модель или настройки не разрешают изображения]';
  }

  @override
  String aiPromptImageOmitted(String label) {
    return '[Фото $label не включено в этот запрос, чтобы он не был слишком большим; чтобы снова его увидеть, вызови view_images]';
  }

  @override
  String aiPromptImageUnavailable(String label) {
    return '[Фото $label недоступно: файла нет или его больше нельзя показывать ИИ]';
  }

  @override
  String aiPromptImageRemoved(String label) {
    return '[Фото $label удалено]';
  }

  @override
  String get aiPromptImagesRejected =>
      '[Фото не отправлено: эта модель не принимает изображения]';

  @override
  String aiPromptDiaryImage(int index) {
    return '[Фото $index]';
  }

  @override
  String get aiToolViewImages => 'Посмотреть фото';

  @override
  String aiToolViewedImages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Просмотрено $count фото',
      many: 'Просмотрено $count фото',
      few: 'Просмотрено $count фото',
      one: 'Просмотрено $count фото',
      zero: 'Фото не отправлены',
    );
    return '$_temp0';
  }

  @override
  String aiToolWithImages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'С $count фото',
      many: 'С $count фото',
      few: 'С $count фото',
      one: 'С $count фото',
    );
    return '$_temp0';
  }

  @override
  String get aiModelMaxOutput => 'Максимум токенов в ответе';

  @override
  String get aiModelContext => 'Длина контекста (токены)';

  @override
  String get aiModelAuto => 'Авто';

  @override
  String get aiModelRemove => 'Удалить модель';

  @override
  String get aiModelPickerTitle => 'Выберите модели';

  @override
  String get aiModelPickerSearch => 'Поиск моделей';

  @override
  String aiModelPickerAdd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Добавить $count',
      many: 'Добавить $count',
      few: 'Добавить $count',
      one: 'Добавить $count',
      zero: 'Добавить',
    );
    return '$_temp0';
  }

  @override
  String get aiModelPickerEmpty =>
      'Провайдер не вернул ни одной модели. Добавьте название модели вручную.';

  @override
  String get aiProviderAdvanced => 'Дополнительно';

  @override
  String get aiProviderProxy => 'HTTP-прокси';

  @override
  String get aiProviderProxyHint =>
      'хост:порт, например 127.0.0.1:7890; пусто — без прокси';

  @override
  String get aiProviderHeaders => 'Свои заголовки';

  @override
  String get aiProviderHeadersHint =>
      'По одному на строку, в формате Имя: значение';

  @override
  String get aiProviderExtraBody => 'Дополнительные поля запроса (JSON)';

  @override
  String get aiProviderExtraBodyHint =>
      'JSON-объект, который добавляется в каждый запрос, — для особых параметров провайдера';

  @override
  String get aiProviderExtraBodyInvalid => 'Некорректный JSON-объект';

  @override
  String get aiProviderStream => 'Потоковый вывод';

  @override
  String get aiProviderStreamSubtitle =>
      'Показывать ответ по мере генерации; отключите, если промежуточный сервис это не поддерживает';

  @override
  String get aiProviderIncludeUsage => 'Запрашивать расход';

  @override
  String get aiProviderIncludeUsageSubtitle =>
      'Запрашивать расход токенов при потоковом выводе; отключите, если запросы завершаются ошибкой';

  @override
  String get aiProviderSendTemperature => 'Отправлять temperature';

  @override
  String get aiProviderSendTemperatureSubtitle =>
      'Новые модели Claude его не принимают, поэтому для Anthropic он выключен';

  @override
  String get aiProviderTimeout => 'Ожидание первого токена';

  @override
  String aiSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count секунды',
      many: '$count секунд',
      few: '$count секунды',
      one: '$count секунда',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderRetries => 'Повторные попытки';

  @override
  String aiTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count раза',
      many: '$count раз',
      few: '$count раза',
      one: '$count раз',
      zero: 'Выкл.',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderEnabled => 'Включён';

  @override
  String get aiProviderDelete => 'Удалить провайдера';

  @override
  String aiProviderDeleteTitle(String name) {
    return 'Удалить «$name»?';
  }

  @override
  String get aiProviderDeleteBody =>
      'Его ключ и настройки моделей будут удалены, а назначенные ему функции перейдут на модель по умолчанию.';

  @override
  String get aiProviderNameRequired => 'Введите название';

  @override
  String get aiProviderUrlInvalid =>
      'Введите адрес, начинающийся с http:// или https://';

  @override
  String get aiProviderNeedModel => 'Сначала добавьте хотя бы одну модель';

  @override
  String get aiProviderDiscardTitle => 'Не сохранять изменения?';

  @override
  String get aiProviderDiscard => 'Не сохранять';

  @override
  String get aiRoutingDefault => 'Модель по умолчанию';

  @override
  String get aiRoutingDefaultSubtitle =>
      'Используется всеми функциями, для которых не выбрана своя модель';

  @override
  String get aiRoutingFast => 'Быстрая модель';

  @override
  String get aiRoutingFastSubtitle =>
      'Используется в первую очередь для коротких задач — умного заполнения и идей для записи; выберите что-нибудь недорогое и быстрое';

  @override
  String get aiRoutingTasksGroup => 'По функциям';

  @override
  String get aiRoutingFollowDefault => 'Как по умолчанию';

  @override
  String get aiRoutingFollowFast => 'Как быстрая модель';

  @override
  String aiRoutingFirstUsable(String name) {
    return 'Первая доступная ($name)';
  }

  @override
  String get aiRoutingNone => 'Не задано';

  @override
  String get aiRoutingPickTitle => 'Выберите модель';

  @override
  String get aiTaskWriting => 'Помощник по тексту';

  @override
  String get aiTaskSuggest => 'Умное заполнение';

  @override
  String get aiTaskReply => 'Отклики ИИ';

  @override
  String get aiTaskPrompts => 'Идеи для записи';

  @override
  String get aiTaskRecap => 'Итоги периода';

  @override
  String get aiTaskChat => 'Чат';

  @override
  String get aiTaskVision => 'Описание изображений';

  @override
  String get aiTaskUtility => 'Мелкие фоновые задачи';

  @override
  String get aiTaskUtilitySubtitle =>
      'Названия чатов, планы поиска и промежуточные сводки длинных итогов';

  @override
  String get aiPersonasDefaultsGroup => 'По умолчанию';

  @override
  String get aiPersonaUseReply => 'Отклики ИИ';

  @override
  String get aiPersonaUseChat => 'Чат';

  @override
  String get aiPersonaUseRecap => 'Итоги периода';

  @override
  String get aiPersonasBuiltInGroup => 'Встроенные';

  @override
  String get aiPersonasMineGroup => 'Мои персоны';

  @override
  String get aiPersonasMineEmpty =>
      'Своих персон пока нет. Создайте новую или скопируйте встроенную и измените её.';

  @override
  String get aiPersonaAdd => 'Новая персона';

  @override
  String get aiPersonaDuplicate => 'Копировать в мои';

  @override
  String get aiPersonaEditTitleNew => 'Новая персона';

  @override
  String get aiPersonaEditTitle => 'Изменить персону';

  @override
  String get aiPersonaName => 'Имя';

  @override
  String get aiPersonaEmoji => 'Эмодзи';

  @override
  String get aiPersonaPrompt => 'Промпт';

  @override
  String get aiPersonaPromptHint =>
      'Опишите, кто это, как говорит и как откликается на ваши записи';

  @override
  String aiPersonaLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count персоны',
      many: '$count персон',
      few: '$count персоны',
      one: '$count персона',
    );
    return 'Максимум $_temp0';
  }

  @override
  String aiPersonaCopySuffix(String name) {
    return '$name (копия)';
  }

  @override
  String get aiCommonHidden => 'Скрыто';

  @override
  String get aiCommonHide => 'Скрыть';

  @override
  String get aiCommonShow => 'Показать';

  @override
  String get aiCommonRestoreDefault => 'Вернуть исходный';

  @override
  String aiCommonDeleted(String name) {
    return 'Удалено: «$name»';
  }

  @override
  String get aiActionsFooter =>
      'Перетаскивайте, чтобы изменить порядок. В редакторе команды идут в том же порядке.';

  @override
  String get aiActionAdd => 'Новая команда';

  @override
  String get aiActionCustomized => 'Изменена';

  @override
  String get aiActionEditTitleNew => 'Новая команда';

  @override
  String get aiActionEditTitle => 'Изменить команду';

  @override
  String get aiActionName => 'Название';

  @override
  String get aiActionEmoji => 'Значок';

  @override
  String get aiActionPrompt => 'Промпт';

  @override
  String get aiActionPromptHint => 'Объясните ИИ, что сделать с текстом';

  @override
  String get aiActionVariables => 'Вставить переменную';

  @override
  String get aiActionVariablesHelp =>
      'Если в промпте нет переменной «Текст», обрабатываемый текст автоматически добавляется после промпта.';

  @override
  String get aiVariableText => 'Текст';

  @override
  String get aiVariableDiary => 'Вся запись';

  @override
  String get aiVariableTitle => 'Заголовок';

  @override
  String get aiVariableDate => 'Дата';

  @override
  String get aiVariableMood => 'Настроение';

  @override
  String get aiActionOutput => 'Результат';

  @override
  String get aiOutputReplace => 'Заменить';

  @override
  String get aiOutputInsertBelow => 'Вставить ниже';

  @override
  String get aiOutputPreview => 'Только показать';

  @override
  String aiActionLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count команды',
      many: '$count команд',
      few: '$count команды',
      one: '$count команда',
    );
    return 'Максимум $_temp0';
  }

  @override
  String get aiActionResetPromptTitle => 'Вернуть исходный промпт?';

  @override
  String get aiProfileAboutMe => 'Обо мне';

  @override
  String get aiProfileAboutMeHint =>
      'Чем вы занимаетесь, как живёте сейчас, что для вас важно. ИИ будет это учитывать.';

  @override
  String get aiProfileStyle => 'Стиль письма';

  @override
  String get aiProfileStyleHint =>
      'Например: просто и без прикрас, мало прилагательных, короткие предложения';

  @override
  String get aiProfileFooter =>
      'Это отправляется с каждым запросом. Оставьте поля пустыми, чтобы ничего не отправлять.';

  @override
  String get aiPrivacySendGroup => 'Отправлять вместе с записями';

  @override
  String get aiPrivacySendFooter =>
      'Заголовки и текст отправляются всегда. Личные блокноты, корзина и ещё не открытые капсулы времени не отправляются никогда.';

  @override
  String get aiPrivacyDate => 'Дата';

  @override
  String get aiPrivacyMood => 'Настроение';

  @override
  String get aiPrivacyTags => 'Теги';

  @override
  String get aiPrivacyWeather => 'Погода';

  @override
  String get aiPrivacyLocation => 'Место';

  @override
  String get aiPrivacyScopeGroup => 'Чат и итоги';

  @override
  String get aiPrivacyIncludeArchived => 'Включать архивные записи';

  @override
  String get aiPrivacyExcludedNotebooks => 'Исключённые блокноты';

  @override
  String get aiPrivacyExcludedTags => 'Исключённые теги';

  @override
  String get aiPrivacyExcludedNone => 'Нет';

  @override
  String aiPrivacyExcludedCount(int count) {
    return 'Выбрано: $count';
  }

  @override
  String get aiPrivacyPickNotebooks => 'Какие блокноты исключить';

  @override
  String get aiPrivacyPickTags => 'Какие теги исключить';

  @override
  String get aiPrivacyPickEmpty => 'Выбирать не из чего';

  @override
  String get aiPrivacyBudget => 'Отправлять не более';

  @override
  String get aiPrivacyBudgetSubtitle =>
      'Записи отправляются целиком; текст обрезается, только если один запрос превысит этот объём.';

  @override
  String aiWords(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    return '$countString слов';
  }

  @override
  String get aiPrivacyConfirmGroup => 'Подтверждение перед отправкой';

  @override
  String get aiPrivacyConfirmSubtitle =>
      'Впервые — один раз для каждого провайдера. Если несколько — чат и итоги всегда показывают, сколько будет отправлено. Всегда — подтверждать каждый запрос.';

  @override
  String get aiConfirmFirstTime => 'Впервые';

  @override
  String get aiConfirmMultiDiary => 'Если несколько';

  @override
  String get aiConfirmAlways => 'Всегда';

  @override
  String get aiPrivacyAllowPrivate => 'Разрешить ИИ для личных записей';

  @override
  String get aiPrivacyAllowPrivateSubtitle =>
      'Помощник по тексту и отклики ИИ станут доступны в личных блокнотах. Чат и итоги по-прежнему их не читают.';

  @override
  String get aiPrivacyResetHosts => 'Снова спрашивать для всех провайдеров';

  @override
  String get aiPrivacyResetHostsSubtitle =>
      'Снова показывать подтверждение первой отправки';

  @override
  String get aiPrivacyResetHostsDone =>
      'Готово. В следующий раз подтверждение появится снова.';

  @override
  String get aiUsageEmpty => 'Статистики пока нет';

  @override
  String aiUsageRequests(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count запроса',
      many: '$count запросов',
      few: '$count запроса',
      one: '$count запрос',
    );
    return '$_temp0';
  }

  @override
  String aiUsageFailures(int count) {
    return 'Ошибок: $count';
  }

  @override
  String aiUsageTokens(String input, String output) {
    return 'Вход: $input · Выход: $output';
  }

  @override
  String aiUsageTokensCached(String input, String cached, String output) {
    return 'Ввод $input (из кэша $cached) · Вывод $output';
  }

  @override
  String aiUsageMonthTotal(String tokens) {
    return 'Токенов: $tokens';
  }

  @override
  String get aiUsageClear => 'Очистить статистику';

  @override
  String get aiUsageClearTitle => 'Очистить статистику расхода?';

  @override
  String get aiUsageClearBody =>
      'Очищается только статистика на этом устройстве; счета провайдера это не затрагивает.';

  @override
  String get aiUsageFooter =>
      'Учитываются только запросы с этого устройства. Фактические расходы смотрите в счетах провайдера.';

  @override
  String get aiPrivacyRecordsGroup => 'Данные ИИ';

  @override
  String get aiPrivacyRecordsFooter =>
      'Чаты, отклики ИИ и итоги хранятся на этом устройстве и в полных резервных копиях. Они никогда не синхронизируются по локальной сети.';

  @override
  String get aiPrivacyClearRecords => 'Очистить все данные ИИ';

  @override
  String aiPrivacyClearRecordsSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Чатов и результатов: $count',
      many: 'Чатов и результатов: $count',
      few: 'Чатов и результатов: $count',
      one: 'Чатов и результатов: $count',
      zero: 'Пока ничего не сохранено',
    );
    return '$_temp0';
  }

  @override
  String get aiPrivacyClearRecordsTitle => 'Очистить все данные ИИ?';

  @override
  String get aiPrivacyClearRecordsBody =>
      'Все чаты, отклики ИИ и итоги будут удалены с этого устройства. Это действие нельзя отменить. Ваши записи не затрагиваются.';

  @override
  String get aiPrivacyClearRecordsDone => 'Данные ИИ очищены';

  @override
  String get aiPromptSystemBase =>
      'Ты — ИИ-помощник в Jotsy, приложении для личного дневника. Твой собеседник — автор этого дневника. Будь искренним и конкретным и никогда не выдумывай фактов, которых нет в дневнике.';

  @override
  String aiPromptAboutUser(String text) {
    return 'О пользователе: $text';
  }

  @override
  String aiPromptWritingStyle(String text) {
    return 'Предпочитаемый стиль письма пользователя: $text';
  }

  @override
  String aiPromptRespondIn(String language) {
    return 'Отвечай на языке: $language.';
  }

  @override
  String get aiPromptRespondLikeDiary =>
      'Отвечай на том же языке, на котором написан дневник.';

  @override
  String get aiPromptLanguageChinese => 'китайский';

  @override
  String get aiPromptLanguageEnglish => 'английский';

  @override
  String get aiPromptLanguageJapanese => 'японский';

  @override
  String get aiPromptLanguageRussian => 'русский';

  @override
  String get aiPromptLengthShort =>
      'Отвечай коротко, в пределах нескольких предложений.';

  @override
  String get aiPromptLengthMedium => 'Ответ должен быть умеренной длины.';

  @override
  String get aiPromptLengthLong => 'Можно отвечать подробно.';

  @override
  String aiPromptPersona(String text) {
    return 'Твоя роль: $text';
  }

  @override
  String get aiPromptFieldTitle => 'Заголовок';

  @override
  String get aiPromptFieldDate => 'Дата';

  @override
  String get aiPromptFieldMood => 'Настроение';

  @override
  String get aiPromptFieldTags => 'Теги';

  @override
  String get aiPromptFieldWeather => 'Погода';

  @override
  String get aiPromptFieldLocation => 'Место';

  @override
  String get aiPromptFieldBody => 'Текст';

  @override
  String get aiPromptTruncated => '(остальное опущено)';

  @override
  String aiPromptImagesAttached(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'К записи приложено $count фотографии.',
      many: 'К записи приложено $count фотографий.',
      few: 'К записи приложены $count фотографии.',
      one: 'К записи приложена $count фотография.',
    );
    return '$_temp0';
  }

  @override
  String get aiPromptWritingSystem =>
      'Ты — помощник по тексту, который помогает пользователю редактировать его собственный дневник. Выводи только итоговый текст: без пояснений, кавычек и вступлений. Сохраняй повествование от первого лица. Можно использовать списки, полужирный шрифт и списки задач Markdown, но не заголовки.';

  @override
  String get aiPromptWritingContext =>
      'Для контекста — вся запись целиком (не повторяй её):';

  @override
  String aiPromptCustomInstruction(String text) {
    return 'Выполни это указание для текста ниже: $text';
  }

  @override
  String get aiPromptReplyInstruction =>
      'Ниже — запись, которую написал пользователь. Прочитай её от своего лица и ответь пользователю напрямую. Не пересказывай запись и не используй заголовки.';

  @override
  String get aiPromptSuggestInstruction =>
      'На основе записи ниже предложи: короткий подходящий заголовок не длиннее 20 символов, без кавычек; от 0 до 3 тегов из уже существующих у пользователя; не более 2 новых тегов длиной до 6 символов каждый — только если они действительно полезны; и одно самое подходящее настроение из предложенных вариантов (если уверенности нет, оставь пустым). Ответь только одним JSON-объектом строго в таком формате:';

  @override
  String aiPromptSuggestTagsList(String tags) {
    return 'Существующие теги пользователя: $tags';
  }

  @override
  String aiPromptSuggestMoodList(String moods) {
    return 'Варианты настроения: $moods';
  }

  @override
  String get aiPromptPromptsInstruction =>
      'Придумай 3 конкретных и мягких вопроса, которые помогут пользователю легко начать сегодняшнюю запись. По одному вопросу на строку, без нумерации и без чего-либо ещё.';

  @override
  String aiPromptPromptsToday(String date) {
    return 'Сегодня: $date';
  }

  @override
  String get aiPromptPromptsRecent =>
      'Отрывки из недавних записей пользователя — чтобы вопросы были более личными:';

  @override
  String aiPromptRecapInstruction(String period) {
    return 'Ниже — записи, которые пользователь написал за период $period. Напиши итоги, разбитые на разделы с подзаголовками Markdown, и охвати следующее:';
  }

  @override
  String get aiPromptRecapRules =>
      'Используй только то, что есть в записях. Упоминая конкретные дни, указывай даты. Если запись помечена [Dn], на неё можно сослаться как [Dn].';

  @override
  String get aiPromptRecapChunk =>
      'Ниже — записи за часть периода. Кратко по пунктам изложи, что происходило, какие были чувства и мысли, сохраняя конкретные даты и детали, — позже это будет объединено в итоги.';

  @override
  String get aiPromptRecapFromSummaries =>
      'Это сводки идущих подряд частей периода, от ранних к поздним:';

  @override
  String aiPromptRecapStats(int count, int words) {
    return 'Статистика: записей — $count, слов — $words.';
  }

  @override
  String aiPromptRecapMoods(String moods) {
    return 'Распределение настроений: $moods';
  }

  @override
  String aiPromptRecapTopTags(String tags) {
    return 'Самые частые теги: $tags';
  }

  @override
  String get aiPromptChatSystem =>
      'Тебе доступны некоторые записи из дневника пользователя, каждая помечена [Dn]. Отвечай на основе этих записей. Если используешь запись, указывай её метку в конце предложения, например [D3]. Не выдумывай того, чего нет в записях; если не можешь найти ответ, так и скажи.';

  @override
  String get aiPromptChatContextHeader => 'Подходящие записи из дневника:';

  @override
  String get aiPromptChatNoDiaries =>
      '(Записей, подходящих к этому вопросу, не найдено.)';

  @override
  String aiPromptChatToday(String date) {
    return 'Сегодня $date.';
  }

  @override
  String get aiPromptChatTitle =>
      'Сформулируй тему этого разговора не более чем в 8 словах. Выведи только название.';

  @override
  String aiPromptRetrievalPlan(String date) {
    return 'Преобразуй вопрос пользователя в план поиска по дневнику. Сегодня $date. Укажи до 8 коротких ключевых слов, которые, скорее всего, встречаются в записях (включая синонимы), и диапазон дат — только если вопрос его подразумевает. Ответь только одним JSON-объектом строго в таком формате:';
  }

  @override
  String get aiPromptDescribeImage =>
      'Опиши в одном-двух предложениях, что изображено на этой фотографии и какое у неё настроение, — как подпись к фото в дневнике. Выведи только описание.';

  @override
  String get aiToolbarLabel => 'Текст с ИИ';

  @override
  String get aiPanelTitle => 'Текст с ИИ';

  @override
  String get aiScopeSelection => 'Выделенный текст';

  @override
  String get aiScopeParagraph => 'Этот абзац';

  @override
  String get aiScopeBeforeCaret => 'Текст до курсора';

  @override
  String get aiScopeDocument => 'Вся запись';

  @override
  String aiScopeSummary(String scope, int words) {
    String _temp0 = intl.Intl.pluralLogic(
      words,
      locale: localeName,
      other: '$words слова',
      many: '$words слов',
      few: '$words слова',
      one: '$words слово',
    );
    return '$scope · $_temp0';
  }

  @override
  String get aiPanelInstructionHint =>
      'Скажите ИИ, что сделать, например: «сделай менее формально»';

  @override
  String get aiPanelSend => 'Отправить';

  @override
  String get aiPanelThinking => 'Думаю…';

  @override
  String get aiPanelReplace => 'Заменить';

  @override
  String get aiPanelInsertBelow => 'Вставить ниже';

  @override
  String get aiPanelCopy => 'Копировать';

  @override
  String get aiPanelCopied => 'Скопировано';

  @override
  String get aiPanelStop => 'Остановить';

  @override
  String get aiPanelEmptyTarget =>
      'Пока не с чем работать. Сначала напишите что-нибудь или выделите текст.';

  @override
  String get aiPanelReasoning => 'Рассуждения';

  @override
  String get aiPanelPrivateBlocked =>
      'Эта запись в личном блокноте. Разрешить ИИ для личных записей можно в настройках конфиденциальности ИИ.';

  @override
  String get aiSlashGroup => 'ИИ';

  @override
  String get aiSlashWrite => 'Текст с ИИ…';

  @override
  String get aiSlashContinue => 'Продолжить с ИИ';

  @override
  String get aiSlashPrompts => 'Идеи для записи';

  @override
  String get aiSelectionMenu => 'ИИ…';

  @override
  String get aiImageDescribe => 'Описать с ИИ';

  @override
  String get aiImageDescribing => 'Описываю фото…';

  @override
  String get aiImageNoVision =>
      'Текущая модель не видит изображения. Выберите модель с поддержкой изображений для задачи «Описание изображений» в разделе «Назначение моделей».';

  @override
  String get aiSuggestTitle => 'Придумать заголовок с ИИ';

  @override
  String get aiSuggestMeta => 'Подобрать теги и настроение с ИИ';

  @override
  String get aiSuggesting => 'ИИ думает…';

  @override
  String get aiSuggestNeedContent =>
      'Сначала напишите хоть немного, чтобы ИИ было от чего оттолкнуться.';

  @override
  String get aiSuggestTitleApplied => 'Заголовок заполнен ИИ';

  @override
  String get aiSuggestTagsHeader => 'ИИ предлагает';

  @override
  String aiSuggestNewTag(String name) {
    return 'Новый «$name»';
  }

  @override
  String get aiSuggestMoodButton => 'Выбор ИИ';

  @override
  String get aiSuggestNothing => 'На этот раз предложений нет';

  @override
  String get aiSuggestApplied => 'Предложения ИИ применены';

  @override
  String aiConfirmSendTitle(String host) {
    return 'Отправить на $host?';
  }

  @override
  String aiConfirmSendModel(String name) {
    return 'Обработает «$name»';
  }

  @override
  String aiConfirmSendEntries(int count, int words) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи',
      many: '$count записей',
      few: '$count записи',
      one: '$count запись',
    );
    String _temp1 = intl.Intl.pluralLogic(
      words,
      locale: localeName,
      other: '$words слова',
      many: '$words слов',
      few: '$words слов',
      one: '$words слова',
    );
    return '$_temp0, около $_temp1';
  }

  @override
  String aiConfirmSendText(int words) {
    String _temp0 = intl.Intl.pluralLogic(
      words,
      locale: localeName,
      other: '$words слова',
      many: '$words слов',
      few: '$words слов',
      one: '$words слова',
    );
    return 'Текст: около $_temp0';
  }

  @override
  String aiConfirmSendImages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'И ещё $count фото',
      many: 'И ещё $count фото',
      few: 'И ещё $count фото',
      one: 'И ещё $count фото',
    );
    return '$_temp0';
  }

  @override
  String get aiConfirmSendNote =>
      'Данные уходят прямо с этого устройства — разработчик их не видит. Провайдер обрабатывает их по своей политике конфиденциальности.';

  @override
  String get aiConfirmSendRemember =>
      'Больше не спрашивать для этого провайдера';

  @override
  String get aiConfirmSendAction => 'Отправить';

  @override
  String aiRepliesHeading(int count) {
    return 'Отклики ИИ · $count';
  }

  @override
  String get aiReplyAsk => 'Попросить ИИ откликнуться…';

  @override
  String get aiReplyMoreItem => 'Отклик ИИ';

  @override
  String get aiReplyPickPersona => 'Кто откликнется?';

  @override
  String get aiReplyWriting => 'Читаю вашу запись…';

  @override
  String get aiReplyRegenerate => 'Создать заново';

  @override
  String get aiReplySaveAsComment => 'Сохранить как комментарий';

  @override
  String get aiReplyContinueChat => 'Поговорить ещё';

  @override
  String get aiReplyDeleted => 'Отклик удалён';

  @override
  String get aiReplyExpand => 'Развернуть';

  @override
  String get aiReplyCollapse => 'Свернуть';

  @override
  String get aiReplyStopped => 'Остановлено. Попробовать снова?';

  @override
  String get aiReplyDismiss => 'Закрыть';

  @override
  String get aiReplyAutoSkipped =>
      'Автоматический отклик не отправлен: один раз запросите отклик вручную, чтобы подтвердить этого провайдера.';

  @override
  String get aiPromptsStripLabel => 'Нужна идея для записи?';

  @override
  String get aiPromptsLoading => 'Придумываю вопросы…';

  @override
  String get aiPromptsRefresh => 'Другие вопросы';

  @override
  String get aiPromptsTitle => 'Идеи для записи';

  @override
  String get aiPromptsHint => 'Нажмите на вопрос, чтобы добавить его в запись';

  @override
  String get aiPromptsEmpty => 'На этот раз вопросов нет. Попробовать снова?';

  @override
  String get aiPromptsClose => 'Скрыть идеи';

  @override
  String get aiReplySavedAsComment => 'Сохранено как комментарий';

  @override
  String get aiRecapTitle => 'Итоги от ИИ';

  @override
  String get aiRecapRange => 'Период';

  @override
  String get aiRecapThisWeek => 'Эта неделя';

  @override
  String get aiRecapLastWeek => 'Прошлая неделя';

  @override
  String get aiRecapThisMonth => 'Этот месяц';

  @override
  String get aiRecapLastMonth => 'Прошлый месяц';

  @override
  String get aiRecapThisYear => 'Этот год';

  @override
  String get aiRecapCustom => 'Свой период…';

  @override
  String get aiRecapNotebook => 'Блокнот';

  @override
  String get aiRecapAllNotebooks => 'Все записи';

  @override
  String get aiRecapSections => 'Что включить';

  @override
  String get aiRecapPersona => 'Голос';

  @override
  String get aiRecapGenerate => 'Подвести итоги';

  @override
  String get aiRecapNoEntries => 'За этот период нет записей для итогов.';

  @override
  String aiRecapReading(int index, int total) {
    return 'Читаю часть $index из $total…';
  }

  @override
  String get aiRecapWriting => 'Пишу итоги…';

  @override
  String aiRecapStats(int count, int words) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи',
      many: '$count записей',
      few: '$count записи',
      one: '$count запись',
    );
    String _temp1 = intl.Intl.pluralLogic(
      words,
      locale: localeName,
      other: '$words слова',
      many: '$words слов',
      few: '$words слова',
      one: '$words слово',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get aiRecapSaved => 'Сохранено в историю итогов';

  @override
  String get aiRecapSaveAsDiary => 'Сохранить как запись';

  @override
  String get aiRecapShare => 'Поделиться текстом';

  @override
  String get aiRecapDeleted => 'Итоги удалены';

  @override
  String aiRecapPeriodRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String aiRecapDiaryTitle(String period) {
    return 'Итоги: $period';
  }

  @override
  String get aiHubQuickMonth => 'Как у меня прошёл этот месяц?';

  @override
  String get aiHubQuickWorry => 'О чём я в последнее время беспокоюсь?';

  @override
  String get aiHubQuickLastYear =>
      'Что происходило у меня год назад в это время?';

  @override
  String get aiHubQuickHappy => 'Какие мелочи радовали меня в последнее время?';

  @override
  String get aiHubQuickGrowth => 'Что во мне изменилось за последние полгода?';

  @override
  String get aiHubRecapMore => 'Другие варианты…';

  @override
  String get aiHubSearchChats => 'Поиск по чатам';

  @override
  String get aiChatUntitled => 'Новый чат';

  @override
  String get aiChatPin => 'Закрепить';

  @override
  String get aiChatUnpin => 'Открепить';

  @override
  String get aiChatRename => 'Переименовать';

  @override
  String get aiChatRenameTitle => 'Переименовать чат';

  @override
  String get aiChatDeleted => 'Чат удалён';

  @override
  String get aiChatInputHint => 'Спросите что-нибудь…';

  @override
  String get aiChatAttachImages => 'Добавить фото';

  @override
  String aiChatImagesTruncated(int max) {
    return 'К сообщению можно приложить не больше $max фото; лишние не добавлены';
  }

  @override
  String get aiChatImagesNoVision =>
      'Эта модель не видит фото (или распознавание изображений выключено), но ИИ всё равно может добавить их в записи';

  @override
  String aiChatImagesSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '[$count фото]',
      many: '[$count фото]',
      few: '[$count фото]',
      one: '[$count фото]',
    );
    return '$_temp0';
  }

  @override
  String aiChatImagesRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count фото удалено',
      many: '$count фото удалены',
      few: '$count фото удалены',
      one: '$count фото удалено',
    );
    return '$_temp0';
  }

  @override
  String get aiChatPlanning => 'Разбираюсь в вопросе…';

  @override
  String get aiChatSearching => 'Ищу подходящие записи…';

  @override
  String aiChatCitations(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Использовано $count записи',
      many: 'Использовано $count записей',
      few: 'Использовано $count записи',
      one: 'Использована $count запись',
    );
    return '$_temp0';
  }

  @override
  String get aiChatNoCitations => 'Подходящих записей не найдено';

  @override
  String get aiChatScope => 'Область';

  @override
  String get aiChatScopeAuto => 'Авто';

  @override
  String aiChatScopeRecent(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Последние $days дня',
      many: 'Последние $days дней',
      few: 'Последние $days дня',
      one: 'Последний $days день',
    );
    return '$_temp0';
  }

  @override
  String get aiChatScopeAll => 'Все записи';

  @override
  String get aiChatScopeRange => 'Диапазон дат…';

  @override
  String get aiChatScopeEntry => 'Эта запись';

  @override
  String get aiChatPersona => 'Персона';

  @override
  String get aiChatModel => 'Модель';

  @override
  String aiChatModelDefault(String name) {
    return 'По умолчанию ($name)';
  }

  @override
  String get aiChatEditResend => 'Изменить и отправить снова';

  @override
  String get aiChatDeleteMessage => 'Удалить сообщение';

  @override
  String get aiChatCitationMissing => 'Этой записи больше нет';

  @override
  String aiChatAboutEntry(String title) {
    return 'О записи «$title»';
  }

  @override
  String get aiHubTooltip => 'ИИ-помощник';

  @override
  String get exploreModuleAi => 'Выводы ИИ';

  @override
  String get exploreModuleAiDesc => 'Последние итоги и вопросы к дневнику';

  @override
  String get aiExploreNoRecap => 'Итогов пока нет. Подвести итоги этой недели?';

  @override
  String get aiExploreWeekly => 'Итоги недели';

  @override
  String get aiExploreAsk => 'Спросить дневник';

  @override
  String get aiExploreNotConfigured =>
      'Настройте ИИ-сервис, чтобы пользоваться этим';

  @override
  String get aiRecapStopped =>
      'Остановлено. Незаконченные итоги не сохраняются.';

  @override
  String get aiRecapHistory => 'Прежние итоги';

  @override
  String get aiRecapDeleteTitle => 'Удалить эти итоги?';

  @override
  String get aiRecapNotebookPick => 'Выберите блокнот';

  @override
  String get aiRecapCustomRange => 'Выберите даты';

  @override
  String get aiRecapShareUnavailable =>
      'Скопировано. Вставьте туда, где хотите поделиться.';

  @override
  String aiRecapModel(String model) {
    return 'Написано моделью $model';
  }

  @override
  String get aiChatMore => 'Ещё';

  @override
  String get aiChatComposerAdd => 'Фото и параметры чата';

  @override
  String get aiChatScrollToBottom => 'К последнему сообщению';

  @override
  String get markdownCopyCode => 'Копировать код';

  @override
  String get markdownCodeCopied => 'Скопировано';

  @override
  String aiChatTokens(String input, String output) {
    return 'Вход: $input · Выход: $output';
  }

  @override
  String aiChatTokensCached(String input, String cached, String output) {
    return 'Ввод $input (из кэша $cached) · Вывод $output';
  }

  @override
  String get aiChatStoppedLabel => 'Остановлено';

  @override
  String get aiChatDeleteMessageTitle => 'Удалить это сообщение?';

  @override
  String get aiChatDeleteTitle => 'Удалить этот чат?';

  @override
  String get aiChatDeleteBody =>
      'Его сообщения тоже будут удалены. Ваши записи не затрагиваются.';

  @override
  String get aiChatRangeTitle => 'Выберите даты';

  @override
  String get aiChatScopeTitle => 'Где искать';

  @override
  String get aiChatScopeAutoSubtitle => 'По способу поиска из настроек ИИ';

  @override
  String get aiSettingsOpenHub => 'Открыть ИИ-помощника';

  @override
  String get aiSettingsOpenHubSubtitle => 'Вопросы к дневнику и итоги периода';

  @override
  String get aiProtocolOpenAiResponses => 'OpenAI Responses';

  @override
  String get aiPresetNameCustomOpenAiResponses => 'OpenAI Responses API';

  @override
  String get cloudBackupBackupNow => 'Создать копию';

  @override
  String get cloudIncrementalBusyScan => 'Проверка изменений…';

  @override
  String get cloudIncrementalBusyCheck =>
      'Чтение резервных копий в облачном хранилище…';

  @override
  String get cloudIncrementalBusyPrune => 'Удаление старых копий…';

  @override
  String cloudIncrementalUploaded(String size) {
    return 'Копия создана. В этот раз загружено $size';
  }

  @override
  String get cloudIncrementalUnchanged =>
      'Изменений нет. Копия в облачном хранилище актуальна';

  @override
  String get cloudIncrementalNewPasswordMessage =>
      'Пароль запоминается на этом устройстве и используется для следующих и автоматических копий. Он понадобится для восстановления на другом устройстве. Оставьте поле пустым, чтобы не шифровать.';

  @override
  String get cloudIncrementalExistingEncryptedMessage =>
      'В этом облачном хранилище уже есть зашифрованные инкрементные копии. Введите их пароль, чтобы продолжить без повторной загрузки фото и медиафайлов.';

  @override
  String get cloudIncrementalContinue => 'Продолжить';

  @override
  String get cloudIncrementalWrongPasswordTitle => 'Неверный пароль';

  @override
  String get cloudIncrementalWrongPasswordContent =>
      'Этот пароль не подходит к инкрементным копиям в облачном хранилище. Попробуйте ещё раз или начните новую серию инкрементных копий (все фото и медиафайлы будут загружены заново).';

  @override
  String get cloudIncrementalRetry => 'Ввести снова';

  @override
  String get cloudIncrementalStartNew => 'Начать новую серию';

  @override
  String get cloudIncrementalExistingPlainTitle =>
      'Продолжить имеющиеся копии?';

  @override
  String get cloudIncrementalExistingPlainContent =>
      'В этом облачном хранилище есть незашифрованные инкрементные копии. Если продолжить, будет загружено только новое. Чтобы включить шифрование, начните новую серию (все фото и медиафайлы будут загружены заново).';

  @override
  String get cloudIncrementalContinueExisting => 'Продолжить';

  @override
  String get cloudIncrementalRememberedMismatchContent =>
      'Сохранённый на этом устройстве пароль больше не подходит к инкрементным копиям в облачном хранилище — возможно, его сменили на другом устройстве. Сбросьте его, чтобы ввести исходный пароль или начать новую серию.';

  @override
  String get cloudIncrementalRestorePasswordMessage =>
      'Эта инкрементная копия зашифрована. Введите пароль, заданный при её создании.';

  @override
  String get cloudIncrementalEntryTitle => 'Инкрементная копия';

  @override
  String get cloudIncrementalEntryMissing =>
      'Файл снимка отсутствует, восстановление невозможно';

  @override
  String get cloudIncrementalDeleteTitle => 'Удалить эту инкрементную копию?';

  @override
  String cloudIncrementalDeleteContent(String time) {
    return 'Инкрементная копия от $time будет удалена. Фото и медиафайлы, которые используются только в ней, тоже будут удалены из облачного хранилища; другие копии не затрагиваются. Это действие нельзя отменить.';
  }

  @override
  String get cloudIncrementalSectionTitle => 'Инкрементное копирование';

  @override
  String get cloudIncrementalSectionHint =>
      '«Создать копию» загружает только новые фото и изменённые данные — то, что уже есть в облачном хранилище, повторно не загружается. При восстановлении на этом устройстве тоже скачивается только недостающее, что экономит трафик хранилища.';

  @override
  String get cloudIncrementalKeepTitle => 'Хранить';

  @override
  String get cloudIncrementalKeepSubtitle =>
      'Более старые инкрементные копии удаляются автоматически вместе с фото и медиафайлами, которые использовались только в них';

  @override
  String get cloudIncrementalKeepAll => 'Все';

  @override
  String cloudIncrementalKeepCount(int count) {
    return '$count';
  }

  @override
  String get cloudAutoBackupTitle => 'Автоматическое копирование';

  @override
  String get cloudAutoBackupSubtitle =>
      'Когда подходит срок, копия создаётся в фоне при открытии или закрытии приложения. Если нового больше 50 MB, копию нужно будет создать вручную';

  @override
  String get cloudAutoBackupNeedsChain =>
      'Перед включением один раз создайте копию вручную';

  @override
  String get cloudAutoBackupIntervalTitle => 'Частота';

  @override
  String get cloudAutoBackupDaily => 'Ежедневно';

  @override
  String get cloudAutoBackupWeekly => 'Еженедельно';

  @override
  String cloudAutoBackupLastUploaded(String time, String size) {
    return 'Последнее автокопирование: $time, загружено $size';
  }

  @override
  String cloudAutoBackupLastUnchanged(String time) {
    return 'Последнее автокопирование: $time, изменений нет';
  }

  @override
  String cloudAutoBackupLastNeedsManual(String time, String size) {
    return '$time: нового $size. Создайте копию вручную';
  }

  @override
  String cloudAutoBackupLastFailed(String time, String reason) {
    return 'Сбой автокопирования ($time): $reason';
  }

  @override
  String cloudAutoBackupTileOk(String time) {
    return 'Автокопирование · $time';
  }

  @override
  String get cloudAutoBackupTileNeedsManual => 'Создайте копию вручную';

  @override
  String get cloudAutoBackupTileFailed => 'Сбой автокопирования';

  @override
  String get cloudIncrementalForgetChain => 'Сбросить пароль';

  @override
  String get cloudIncrementalForgetTitle =>
      'Сбросить пароль инкрементных копий?';

  @override
  String get cloudIncrementalForgetContent =>
      'Устройство забудет текущий пароль инкрементных копий, а автоматическое копирование приостановится. При следующем копировании введите исходный пароль, чтобы продолжить, или задайте новый и начните сначала (все фото и медиафайлы будут загружены заново).';

  @override
  String get cloudIncrementalForgotten => 'Пароль инкрементных копий сброшен';

  @override
  String get cloudIncrementalErrorPassword =>
      'Пароль не подходит к этой инкрементной копии';

  @override
  String get cloudIncrementalErrorMediaChanged =>
      'Во время копирования изменилось фото или вложение. Попробуйте ещё раз';

  @override
  String get textSelectionMenuMore => 'Ещё';

  @override
  String get textSelectionMenuLess => 'Свернуть';

  @override
  String passcodeDotsSemantics(int filled, int total) {
    return 'Введено цифр: $filled из $total';
  }

  @override
  String get passcodeDelete => 'Удалить';

  @override
  String get passcodePatternSemantics =>
      'Поле графического ключа: соедините точки линией';

  @override
  String get passcodeUseBiometric => 'Использовать отпечаток или лицо';

  @override
  String passcodeWrongAttemptsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Неверно. Ещё $count ошибки — и придётся подождать',
      many: 'Неверно. Ещё $count ошибок — и придётся подождать',
      few: 'Неверно. Ещё $count ошибки — и придётся подождать',
      one: 'Неверно. Ещё $count ошибка — и придётся подождать',
    );
    return '$_temp0';
  }

  @override
  String get passcodeWrongPin => 'Неверный код, попробуйте ещё раз';

  @override
  String get passcodeWrongPattern => 'Неверный ключ, попробуйте ещё раз';

  @override
  String passcodePatternTooShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Слишком коротко. Соедините не менее $count точки',
      many: 'Слишком коротко. Соедините не менее $count точек',
      few: 'Слишком коротко. Соедините не менее $count точек',
      one: 'Слишком коротко. Соедините не менее $count точки',
    );
    return '$_temp0';
  }

  @override
  String passcodeLockedOutSeconds(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Повторите через $seconds секунды',
      many: 'Повторите через $seconds секунд',
      few: 'Повторите через $seconds секунды',
      one: 'Повторите через $seconds секунду',
    );
    return '$_temp0';
  }

  @override
  String passcodeLockedOutMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Повторите через $minutes минуты',
      many: 'Повторите через $minutes минут',
      few: 'Повторите через $minutes минуты',
      one: 'Повторите через $minutes минуту',
    );
    return '$_temp0';
  }

  @override
  String get passcodeUnavailable =>
      'Не удалось прочитать код приложения. Перезапустите приложение и попробуйте снова.';

  @override
  String get passcodeEnterPinTitle => 'Введите код приложения';

  @override
  String get passcodeDrawPatternTitle => 'Нарисуйте графический ключ';

  @override
  String get passcodeForgot => 'Забыли код?';

  @override
  String get passcodeForgotMessage =>
      'Код приложения хранится только на этом устройстве и не восстанавливается. Остаётся лишь очистить данные приложения или переустановить его, а затем восстановить дневник из резервной копии.';

  @override
  String get appLockPasscodeSubtitle =>
      'Подтвердите кодом приложения, чтобы продолжить';

  @override
  String get passcodeVerifyTitle => 'Подтверждение личности';

  @override
  String passcodeFormPin(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count цифры',
      many: '$count цифр',
      few: '$count цифры',
      one: '$count цифра',
    );
    return '$_temp0';
  }

  @override
  String get passcodeFormPattern => 'Графический ключ';

  @override
  String get passcodeConfirmPinTitle => 'Введите ещё раз';

  @override
  String get passcodeConfirmPatternTitle => 'Нарисуйте ещё раз';

  @override
  String get passcodeConfirmMessage =>
      'Повторите то же самое для подтверждения';

  @override
  String get passcodeSetupPinTitle => 'Задайте цифровой код';

  @override
  String passcodeSetupPinMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Введите $count цифры',
      many: 'Введите $count цифр',
      few: 'Введите $count цифры',
      one: 'Введите $count цифру',
    );
    return '$_temp0';
  }

  @override
  String get passcodeSetupPatternTitle => 'Задайте графический ключ';

  @override
  String passcodeSetupPatternMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Соедините не менее $count точки одним движением',
      many: 'Соедините не менее $count точек одним движением',
      few: 'Соедините не менее $count точек одним движением',
      one: 'Соедините не менее $count точки одним движением',
    );
    return '$_temp0';
  }

  @override
  String get passcodeMismatch => 'Не совпадает. Начните заново.';

  @override
  String get passcodeSaveFailed => 'Не удалось сохранить. Попробуйте ещё раз.';

  @override
  String get passcodeChangeTitle => 'Изменить код приложения';

  @override
  String get passcodeSetupTitle => 'Задать код приложения';

  @override
  String get passcodeNoRecoveryNote =>
      'Код приложения хранится только на этом устройстве, не попадает в резервные копии и синхронизацию и не восстанавливается, если вы его забудете.';

  @override
  String get appLockSwitchToPasscodeReason =>
      'Подтвердите личность, чтобы перейти на код приложения';

  @override
  String get appLockSwitchVerifyFailed =>
      'Проверка не пройдена. Способ не изменён.';

  @override
  String get passcodeSetDone => 'Код приложения задан';

  @override
  String get appLockSystemUnsupported =>
      'Системная проверка недоступна на этом устройстве (не настроена блокировка экрана)';

  @override
  String get appLockSwitchToSystemReason =>
      'Подтвердите кодом приложения, чтобы перейти на системную проверку';

  @override
  String get appLockSwitchedToSystem =>
      'Включена системная проверка, код приложения удалён';

  @override
  String get passcodeChangeReason =>
      'Подтвердите текущим кодом, чтобы изменить его';

  @override
  String get passcodeChangedDone => 'Код приложения изменён';

  @override
  String get passcodeBiometricEnableReason =>
      'Подтвердите отпечатком или лицом, чтобы включить быструю разблокировку';

  @override
  String get passcodeBiometricFailed =>
      'Проверка по отпечатку или лицу не пройдена';

  @override
  String get settingsAppLockAndPasscode => 'Блокировка и код';

  @override
  String get appLockMethodTitle => 'Способ проверки';

  @override
  String get appLockMethodFooter =>
      'Этот способ используется для блокировки приложения, заблокированных блокнотов и подтверждения сопряжения по локальной сети.';

  @override
  String get appLockNeedsPasscode =>
      'На устройстве нет системной проверки. Сначала задайте код приложения ниже.';

  @override
  String get appLockMethodSystem => 'Системная проверка';

  @override
  String get appLockMethodSystemDescription =>
      'Отпечаток, лицо или блокировка экрана телефона';

  @override
  String get appLockMethodSystemUnavailable => 'Недоступно на этом устройстве';

  @override
  String get appLockMethodPasscode => 'Код приложения';

  @override
  String get appLockMethodPasscodeDescription =>
      'Отдельный цифровой код или графический ключ, не связанный с блокировкой экрана';

  @override
  String passcodeCurrentForm(String form) {
    return 'Сейчас: $form';
  }

  @override
  String get passcodeBiometric => 'Быстрая разблокировка отпечатком или лицом';

  @override
  String get passcodeBiometricSubtitle =>
      'Разблокировка отпечатком или лицом вместо кода. Для отключения блокировки и смены кода по-прежнему нужен код.';

  @override
  String get appLockStatusPasscode => 'Вкл. · код приложения';

  @override
  String get appLockStatusSystem => 'Вкл. · системная проверка';

  @override
  String get appLockStatusOffPasscode =>
      'Выкл. · заблокированные блокноты открываются кодом приложения';

  @override
  String get appLockStatusOff => 'Выкл.';

  @override
  String get settingsGroupGeneral => 'Общие';

  @override
  String get settingsGroupWriting => 'Написание';

  @override
  String get settingsGroupOrganize => 'Организация';

  @override
  String get settingsGroupDataSecurity => 'Данные и безопасность';

  @override
  String get settingsAppearance => 'Оформление';

  @override
  String get settingsAppearanceSubtitle => 'Тема, фон и стили страниц';

  @override
  String get settingsEditor => 'Редактор';

  @override
  String get settingsThemeGroup => 'Тема';

  @override
  String get settingsInterfaceGroup => 'Интерфейс';

  @override
  String get settingsPageStylesGroup => 'Стили страниц';

  @override
  String get settingsEditorBodyGroup => 'Текст записи';

  @override
  String get settingsEditorToolbarGroup => 'Панель инструментов';

  @override
  String get settingsEditorBehaviorGroup => 'Поведение';

  @override
  String get dataMgmtBackupGroup => 'Резервное копирование';

  @override
  String get dataMgmtFilesGroup => 'Импорт и экспорт';

  @override
  String get placeHistoryTitle => 'Недавние места';

  @override
  String get placeHistorySearchHint => 'Поиск мест';

  @override
  String placeHistorySearchEmpty(String query) {
    return 'Нет мест по запросу «$query»';
  }

  @override
  String get placeHistoryEmptyTitle => 'Мест пока нет';

  @override
  String get placeHistoryEmptyBody =>
      'Здесь появятся места из ваших записей — в следующий раз выберите их одним касанием.';

  @override
  String placeHistoryUseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи',
      many: '$count записей',
      few: '$count записи',
      one: '$count запись',
    );
    return '$_temp0';
  }

  @override
  String placeHistoryShowAll(int count) {
    return 'Все $count';
  }

  @override
  String get appLockAfterLeaving => 'Блокировать после выхода';

  @override
  String get appLockAfterLeavingHint =>
      'Переход в другое приложение, на главный экран или сворачивание окна считается выходом; выбор фото, съёмка, выбор файлов и отправка из приложения — нет. При открытии приложения подтверждение требуется всегда.';

  @override
  String get appLockDelayImmediately => 'Сразу';

  @override
  String appLockDelayMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Через $count минуты',
      many: 'Через $count минут',
      few: 'Через $count минуты',
      one: 'Через $count минуту',
    );
    return '$_temp0';
  }

  @override
  String appLockDelayHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Через $count часа',
      many: 'Через $count часов',
      few: 'Через $count часа',
      one: 'Через $count час',
    );
    return '$_temp0';
  }

  @override
  String get appLockAfterLeavingNever => 'Никогда (только при запуске)';

  @override
  String get appLockOnScreenOff => 'Блокировать при блокировке экрана';

  @override
  String get appLockOnScreenOffSubtitle =>
      'После блокировки телефона или отключения экрана для возврата потребуется подтверждение';

  @override
  String get appLockWhenIdle => 'Блокировать при бездействии';

  @override
  String get appLockWhenIdleHint =>
      'Блокирует, если окно открыто, но мышь, тачпад и клавиатура какое-то время не используются.';

  @override
  String get appLockWhenIdleOff => 'Выкл.';

  @override
  String get appLockAutoPrompt => 'Сразу запрашивать подтверждение';

  @override
  String get appLockAutoPromptSubtitle =>
      'Сразу показывать проверку отпечатка, лица или системную проверку на экране блокировки. Если выключено — нажмите, чтобы подтвердить.';

  @override
  String get appLockPrivacyTitle => 'Конфиденциальность';

  @override
  String get appLockSecureScreen => 'Запретить скриншоты';

  @override
  String get appLockSecureScreenSubtitle =>
      'Скриншоты и запись экрана будут пустыми, а в недавних приложениях содержимое скрыто';

  @override
  String get appLockLoosenReason =>
      'Подтвердите личность, чтобы ослабить блокировку';

  @override
  String get appLockLoosenVerifyFailed =>
      'Проверка не пройдена. Настройка не изменена.';

  @override
  String get diarySearchRecentTitle => 'Недавние запросы';

  @override
  String get diarySearchClearRecent => 'Очистить недавние запросы';

  @override
  String diarySearchRecentRemove(String query) {
    return 'Удалить «$query» из недавних запросов';
  }

  @override
  String get diarySearchSuggestedTags => 'Частые теги';

  @override
  String get diarySearchEmptyTip =>
      'Разделяйте слова пробелами, чтобы найти записи со всеми словами';

  @override
  String diarySearchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи',
      many: '$count записей',
      few: '$count записи',
      one: '$count запись',
    );
    return '$_temp0';
  }

  @override
  String get diarySearchClearFilters => 'Сбросить фильтры';

  @override
  String get diarySearchIncludeArchived => 'С архивом';

  @override
  String diarySearchRemoveFilter(String label) {
    return 'Убрать фильтр «$label»';
  }

  @override
  String get diarySearchSortTooltip => 'Сортировка';

  @override
  String get diarySearchSortUpdated => 'Недавно изменённые';

  @override
  String get diarySearchSortNewest => 'Сначала новые';

  @override
  String get diarySearchSortOldest => 'Сначала старые';

  @override
  String get diarySearchTagSheetTitle => 'Поиск по тегам';

  @override
  String get diarySearchTagSheetHint =>
      'Показываются записи со всеми выбранными тегами';

  @override
  String settingsStorageSubtitle(String size) {
    return 'Занято $size';
  }

  @override
  String get storageMgmtTitle => 'Хранилище';

  @override
  String get storageMgmtTotalLabel => 'Всего занято';

  @override
  String storageMgmtCleanUpAll(String size) {
    return 'Очистить · освободить $size';
  }

  @override
  String get storageMgmtRescan => 'Пересчитать';

  @override
  String get storageMgmtScanFailed =>
      'Не удалось подсчитать место. Попробуйте позже';

  @override
  String get storageMgmtCategoryImages => 'Изображения';

  @override
  String get storageMgmtCategoryVideos => 'Видео';

  @override
  String get storageMgmtCategoryAudio => 'Записи';

  @override
  String get storageMgmtCategoryAttachments => 'Вложения';

  @override
  String get storageMgmtCategoryCovers => 'Обложки';

  @override
  String get storageMgmtCategoryBackgrounds => 'Фоны';

  @override
  String get storageMgmtCategoryFonts => 'Шрифты';

  @override
  String get storageMgmtCategoryDatabase => 'Данные дневника';

  @override
  String get storageMgmtCategoryCache => 'Кэш';

  @override
  String get storageMgmtCategoryUnused => 'Неиспользуемые файлы';

  @override
  String get storageMgmtCategoryOther => 'Прочее';

  @override
  String get storageMgmtSuggestionsTitle => 'Освободить место';

  @override
  String get storageMgmtSuggestCache => 'Кэш';

  @override
  String storageMgmtSuggestCacheSubtitle(String size) {
    return 'Можно очистить $size. Кэш за последний час сохранится';
  }

  @override
  String get storageMgmtSuggestUnused => 'Неиспользуемые файлы';

  @override
  String storageMgmtSuggestUnusedSubtitle(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count файла не используются ни одной записью, $size',
      many: '$count файлов не используются ни одной записью, $size',
      few: '$count файла не используются ни одной записью, $size',
      one: '$count файл не используется ни одной записью, $size',
    );
    return '$_temp0';
  }

  @override
  String get storageMgmtSuggestTrash => 'Записи в корзине';

  @override
  String storageMgmtSuggestTrashSubtitle(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count файла используются только записями в корзине, $size',
      many: '$count файлов используются только записями в корзине, $size',
      few: '$count файла используются только записями в корзине, $size',
      one: '$count файл используется только записями в корзине, $size',
    );
    return '$_temp0';
  }

  @override
  String get storageMgmtSuggestCompress => 'Фото и видео для сжатия';

  @override
  String storageMgmtSuggestCompressSubtitle(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count файла, экономия около $size',
      many: '$count файлов, экономия около $size',
      few: '$count файла, экономия около $size',
      one: '$count файл, экономия около $size',
    );
    return '$_temp0';
  }

  @override
  String get storageMgmtSuggestDatabase => 'Упорядочить данные дневника';

  @override
  String storageMgmtSuggestDatabaseSubtitle(String size) {
    return 'Освободит $size, оставшиеся от удалённого';
  }

  @override
  String get storageMgmtClear => 'Очистить';

  @override
  String get storageMgmtCompact => 'Упорядочить';

  @override
  String get storageMgmtAllClean => 'Всё в порядке';

  @override
  String get storageMgmtAllCleanSubtitle =>
      'Сейчас нечего очищать: нет кэша и неиспользуемых файлов';

  @override
  String get storageMgmtMediaTitle => 'Медиафайлы';

  @override
  String get storageMgmtAllMedia => 'Все медиафайлы';

  @override
  String storageMgmtFileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count файла',
      many: '$count файлов',
      few: '$count файла',
      one: '$count файл',
    );
    return '$_temp0';
  }

  @override
  String get storageMgmtLargeFiles => 'Большие файлы';

  @override
  String get storageMgmtOtherTitle => 'Другие данные';

  @override
  String get storageMgmtFooter =>
      'Удаление и сжатие попадут на другие устройства при следующей синхронизации по сети. Старые облачные копии хранят исходные файлы, пока не будут удалены по лимиту.';

  @override
  String get storageMgmtCleaning => 'Очистка…';

  @override
  String get storageMgmtDeleting => 'Удаление…';

  @override
  String storageMgmtFreed(String size) {
    return 'Освобождено $size';
  }

  @override
  String get storageMgmtNothingFreed => 'Сейчас нечего очищать';

  @override
  String get storageMgmtBusyEditing =>
      'Запись открыта для редактирования. Закройте её и повторите';

  @override
  String get storageMgmtBusyUndo =>
      'Дождитесь, пока исчезнет подсказка «Отменить», и повторите';

  @override
  String get storageMgmtCannotDelete =>
      'На файл ссылаются другие данные, удалить его здесь нельзя';

  @override
  String storageMgmtDeleteTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Удалить $count файла?',
      many: 'Удалить $count файлов?',
      few: 'Удалить $count файла?',
      one: 'Удалить $count файл?',
    );
    return '$_temp0';
  }

  @override
  String storageMgmtDeleteBody(String size) {
    return 'Освободится $size. Файлы будут удалены из:';
  }

  @override
  String storageMgmtDeleteFromDiaries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи',
      many: '$count записей',
      few: '$count записей',
      one: '$count записи',
    );
    return '$_temp0';
  }

  @override
  String storageMgmtDeleteFromNotebooks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count обложки блокнота',
      many: '$count обложек блокнотов',
      few: '$count обложек блокнотов',
      one: '$count обложки блокнота',
    );
    return '$_temp0';
  }

  @override
  String storageMgmtDeleteFromComments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count комментария',
      many: '$count комментариев',
      few: '$count комментариев',
      one: '$count комментария',
    );
    return '$_temp0';
  }

  @override
  String storageMgmtDeleteFromDrafts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count черновика',
      many: '$count черновиков',
      few: '$count черновиков',
      one: '$count черновика',
    );
    return '$_temp0';
  }

  @override
  String storageMgmtDeleteFromAiChats(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сообщения в чатах с ИИ',
      many: '$count сообщений в чатах с ИИ',
      few: '$count сообщений в чатах с ИИ',
      one: '$count сообщения в чатах с ИИ',
    );
    return '$_temp0';
  }

  @override
  String get storageMgmtDeleteCommentNote =>
      'Комментарии без текста и изображений тоже будут удалены.';

  @override
  String get storageMgmtDeleteAiChatNote =>
      'В чатах с ИИ удалённые изображения будут отмечены как удалённые, сами сообщения останутся.';

  @override
  String get storageMgmtDeleteCapsuleNote =>
      'Среди них есть содержимое ещё не открытых капсул времени.';

  @override
  String get storageMgmtDeleteIrreversible => 'Это действие нельзя отменить.';

  @override
  String storageMgmtDeleted(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Удалено $count файла, освобождено $size',
      many: 'Удалено $count файлов, освобождено $size',
      few: 'Удалено $count файла, освобождено $size',
      one: 'Удалён $count файл, освобождено $size',
    );
    return '$_temp0';
  }

  @override
  String storageMgmtSkippedRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count места изменились за это время и остались как есть.',
      many: '$count мест изменились за это время и остались как есть.',
      few: '$count места изменились за это время и остались как есть.',
      one: '$count место изменилось за это время и осталось как есть.',
    );
    return '$_temp0';
  }

  @override
  String get storageMgmtCompress => 'Сжать';

  @override
  String storageMgmtCompressTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Сжать $count файла',
      many: 'Сжать $count файлов',
      few: 'Сжать $count файла',
      one: 'Сжать $count файл',
    );
    return '$_temp0';
  }

  @override
  String get storageMgmtCompressImages => 'Фото';

  @override
  String get storageMgmtCompressVideos => 'Видео';

  @override
  String get storageMgmtPresetHigh => 'Высокое качество';

  @override
  String get storageMgmtPresetBalanced => 'Сбалансированно';

  @override
  String get storageMgmtPresetCompact => 'Экономия места';

  @override
  String storageMgmtImagePresetDetail(
    int maxSide,
    int quality,
    String estimate,
  ) {
    return 'Длинная сторона $maxSide пикс. · качество $quality · $estimate';
  }

  @override
  String storageMgmtPresetEstimate(String before, String after) {
    return '$before → около $after';
  }

  @override
  String get storageMgmtPresetNoGain => 'Уже достаточно маленькие';

  @override
  String storageMgmtCompressSummary(String before, String after, String saved) {
    return '$before → около $after, экономия около $saved';
  }

  @override
  String get storageMgmtCompressNothing => 'Эти файлы не нужно сжимать';

  @override
  String storageMgmtCompressSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count файла уже небольшие или в неподходящем формате и будут пропущены.',
      many:
          '$count файлов уже небольшие или в неподходящем формате и будут пропущены.',
      few:
          '$count файла уже небольшие или в неподходящем формате и будут пропущены.',
      one:
          '$count файл уже небольшой или в неподходящем формате и будет пропущен.',
    );
    return '$_temp0';
  }

  @override
  String get storageMgmtCompressNote =>
      'Сжатые файлы заменят исходные, восстановить их нельзя. У фото сохранятся время и место съёмки.';

  @override
  String get storageMgmtCompressStart => 'Сжать';

  @override
  String get storageMgmtCompressing => 'Сжатие';

  @override
  String get storageMgmtCompressPreparing => 'Подготовка…';

  @override
  String storageMgmtCompressStep(int index, int total, String name) {
    return '$index из $total · $name';
  }

  @override
  String get storageMgmtCancelling => 'Остановка…';

  @override
  String get storageMgmtCompressFinished => 'Сжатие завершено';

  @override
  String get storageMgmtCompressCancelled => 'Сжатие остановлено';

  @override
  String storageMgmtCompressDone(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Сжато $count файла, сэкономлено $size',
      many: 'Сжато $count файлов, сэкономлено $size',
      few: 'Сжато $count файла, сэкономлено $size',
      one: 'Сжат $count файл, сэкономлено $size',
    );
    return '$_temp0';
  }

  @override
  String storageMgmtCompressUnchanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count файла не стали меньше — оригиналы сохранены.',
      many: '$count файлов не стали меньше — оригиналы сохранены.',
      few: '$count файла не стали меньше — оригиналы сохранены.',
      one: '$count файл не стал меньше — оригинал сохранён.',
    );
    return '$_temp0';
  }

  @override
  String storageMgmtCompressFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Не удалось сжать $count файла.',
      many: 'Не удалось сжать $count файлов.',
      few: 'Не удалось сжать $count файла.',
      one: 'Не удалось сжать $count файл.',
    );
    return '$_temp0';
  }

  @override
  String get storageMgmtCompressNoneDone => 'Ничего не сжато.';

  @override
  String get storageMgmtDone => 'Готово';

  @override
  String storageMgmtCompressSaving(String size) {
    return 'Сжать · −$size';
  }

  @override
  String storageMgmtSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Выбрано $count',
      many: 'Выбрано $count',
      few: 'Выбрано $count',
      one: 'Выбран $count',
    );
    return '$_temp0';
  }

  @override
  String storageMgmtSelectionSummary(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Выбрано $count · $size',
      many: 'Выбрано $count · $size',
      few: 'Выбрано $count · $size',
      one: 'Выбран $count · $size',
    );
    return '$_temp0';
  }

  @override
  String storageMgmtListSummary(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count файла · $size',
      many: '$count файлов · $size',
      few: '$count файла · $size',
      one: '$count файл · $size',
    );
    return '$_temp0';
  }

  @override
  String get storageMgmtFilterAll => 'Все';

  @override
  String get storageMgmtFilterLarge => 'Большие';

  @override
  String get storageMgmtFilterCompressible => 'Можно сжать';

  @override
  String get storageMgmtFilterTrash => 'Только корзина';

  @override
  String get storageMgmtSort => 'Сортировка';

  @override
  String get storageMgmtSortLargest => 'Сначала большие';

  @override
  String get storageMgmtSortNewest => 'Сначала новые';

  @override
  String get storageMgmtSortOldest => 'Сначала старые';

  @override
  String get storageMgmtViewGrid => 'Сеткой';

  @override
  String get storageMgmtViewList => 'Списком';

  @override
  String get storageMgmtEmpty => 'Здесь нет файлов';

  @override
  String storageMgmtPrivateHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count файла из личных записей скрыты',
      many: '$count файлов из личных записей скрыты',
      few: '$count файла из личных записей скрыты',
      one: '$count файл из личных записей скрыт',
    );
    return '$_temp0';
  }

  @override
  String get storageMgmtReveal => 'Показать';

  @override
  String get storageMgmtRevealReason =>
      'Подтвердите личность, чтобы показать медиа из личных записей';

  @override
  String get storageMgmtRevealUnavailable =>
      'На этом устройстве нельзя подтвердить личность. Сначала задайте код приложения';

  @override
  String get storageMgmtBadgeTrash => 'В корзине';

  @override
  String storageMgmtBadgeCompressible(String size) {
    return '−$size';
  }

  @override
  String get storageMgmtBadgeCompressShort => 'Сжать';

  @override
  String storageMgmtBadgeUsedIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'В $count места',
      many: 'В $count местах',
      few: 'В $count местах',
      one: 'В $count месте',
    );
    return '$_temp0';
  }

  @override
  String get storageMgmtBadgeLocked => 'Нельзя удалить';

  @override
  String get storageMgmtUntitledDiary => 'Запись без названия';

  @override
  String get storageMgmtUntitledDraft => 'Черновик без названия';

  @override
  String storageMgmtRefComment(String title) {
    return 'Комментарий · $title';
  }

  @override
  String storageMgmtRefAiChat(String title) {
    return 'Чат с ИИ · $title';
  }

  @override
  String storageMgmtRefDiaryCover(String title) {
    return 'Обложка · $title';
  }

  @override
  String storageMgmtRefNotebookCover(String name) {
    return 'Обложка блокнота · $name';
  }

  @override
  String storageMgmtRefDraft(String title) {
    return 'Черновик · $title';
  }

  @override
  String get storageMgmtRefOther => 'Используется другими данными';

  @override
  String get storageMgmtMaskedPrivate => 'Содержимое личной записи';

  @override
  String get storageMgmtMaskedCapsule => 'Содержимое закрытой капсулы времени';

  @override
  String storageMgmtUsedIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Используется в $count места',
      many: 'Используется в $count местах',
      few: 'Используется в $count местах',
      one: 'Используется в $count месте',
    );
    return '$_temp0';
  }

  @override
  String get diaryTagFilterMultiSelectSemanticHint => 'выбрать несколько тегов';

  @override
  String get diaryTagFilterMultiSelectTip =>
      'Удерживайте тег, чтобы выбрать несколько';

  @override
  String diaryTagFilterMultiSelectTipDesktop(String key) {
    return 'Удерживайте $key и щёлкайте по тегам, чтобы выбрать несколько';
  }

  @override
  String get settingsPublishOnLeave => 'Публиковать новую запись при возврате';

  @override
  String get settingsPublishOnLeaveSubtitle =>
      'При возврате новая запись сохраняется как запись, а не как черновик';

  @override
  String get publishOnLeaveFailedKeptDraft =>
      'Не удалось опубликовать запись. Она осталась в черновиках.';

  @override
  String get settingsManualSave => 'Сохранять правки вручную';

  @override
  String get settingsManualSaveSubtitle =>
      'Правки в готовых записях сохраняются только по кнопке «Сохранить»; при возврате с несохранёнными правками появится вопрос';

  @override
  String get diaryEditSaved => 'Сохранено';

  @override
  String get storageMgmtAppTitle => 'Занято Jotsy';

  @override
  String get storageMgmtCategoryApp => 'Приложение';

  @override
  String get storageMgmtDeviceTitle => 'Память устройства';

  @override
  String storageMgmtDeviceTotal(String size) {
    return 'Всего $size';
  }

  @override
  String get storageMgmtDeviceUsedLabel => 'занято';

  @override
  String get storageMgmtDeviceApp => 'Jotsy';

  @override
  String get storageMgmtDeviceOther => 'Другие приложения и система';

  @override
  String get storageMgmtDeviceFree => 'Свободно';

  @override
  String storageMgmtShareOfDevice(String percent) {
    return '$percent памяти устройства';
  }

  @override
  String get storageMgmtDeviceShareLabel => 'Доля памяти';

  @override
  String get storageMgmtReclaimable => 'Можно освободить';

  @override
  String get storageMgmtTopTitle => 'Самые большие файлы';

  @override
  String get storageMgmtSeeAll => 'Показать все';

  @override
  String get storageMgmtGrowthTitle => 'Медиа по времени';

  @override
  String get storageMgmtGrowthByYear => 'Добавлено по годам, по дате записи';

  @override
  String get storageMgmtGrowthByMonth =>
      'Добавлено по месяцам за 12 месяцев, по дате записи';

  @override
  String storageMgmtGrowthPeak(String period, String size) {
    return 'Больше всего добавлено — $period: $size';
  }

  @override
  String get storageMgmtOpenExternally => 'Открыть в другом приложении';

  @override
  String backupImportTodoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count задачи',
      many: '$count задач',
      few: '$count задачи',
      one: '$count задача',
    );
    return '$_temp0';
  }

  @override
  String backupImportExistingTodoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count задачи уже есть на этом устройстве',
      many: '$count задач уже есть на этом устройстве',
      few: '$count задачи уже есть на этом устройстве',
      one: '$count задача уже есть на этом устройстве',
    );
    return '$_temp0';
  }

  @override
  String backupImportModeOverwriteTodosOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Добавляет новое и заменяет $count задачи, уже имеющиеся на устройстве, версиями из файла',
      many:
          'Добавляет новое и заменяет $count задач, уже имеющихся на устройстве, версиями из файла',
      few:
          'Добавляет новое и заменяет $count задачи, уже имеющиеся на устройстве, версиями из файла',
      one:
          'Добавляет новое и заменяет $count задачу, уже имеющуюся на устройстве, версией из файла',
    );
    return '$_temp0';
  }

  @override
  String backupImportModeOverwriteTodosExtra(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Также заменяет $count задачи, уже имеющиеся на устройстве',
      many: 'Также заменяет $count задач, уже имеющихся на устройстве',
      few: 'Также заменяет $count задачи, уже имеющиеся на устройстве',
      one: 'Также заменяет $count задачу, уже имеющуюся на устройстве',
    );
    return '$_temp0';
  }

  @override
  String backupOverwriteAllTodos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count задачи',
      many: '$count задач',
      few: '$count задачи',
      one: '$count задача',
    );
    return '$_temp0';
  }

  @override
  String backupOverwriteExistingTodosBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count задачи, уже имеющиеся на устройстве, будут заменены версиями из файла.',
      many:
          '$count задач, уже имеющихся на устройстве, будут заменены версиями из файла.',
      few:
          '$count задачи, уже имеющиеся на устройстве, будут заменены версиями из файла.',
      one:
          '$count задача, уже имеющаяся на устройстве, будет заменена версией из файла.',
    );
    return '$_temp0';
  }

  @override
  String backupImportTodoMergeResult(int added) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: 'Задачи: добавлено $added',
      many: 'Задачи: добавлено $added',
      few: 'Задачи: добавлено $added',
      one: 'Задачи: добавлена $added',
    );
    return '$_temp0';
  }

  @override
  String backupImportTodoOverwriteResult(int added, int replaced) {
    return 'Задачи: добавлено $added, перезаписано $replaced';
  }

  @override
  String get navTodos => 'Задачи';

  @override
  String get appSurfaceAreaTodos => 'Задачи';

  @override
  String get settingsFeaturesTodosSubtitle =>
      'Задачи, списки и напоминания отдельно от дневника';

  @override
  String get todoViewToday => 'Сегодня';

  @override
  String get todoViewPlanned => 'Запланировано';

  @override
  String get todoViewImportant => 'Важное';

  @override
  String get todoViewAll => 'Все';

  @override
  String get todoViewCompleted => 'Выполненные';

  @override
  String get todoViewInbox => 'Входящие';

  @override
  String get todoGroupOverdue => 'Просрочено';

  @override
  String get todoGroupToday => 'Сегодня';

  @override
  String get todoGroupTomorrow => 'Завтра';

  @override
  String get todoGroupNextDays => 'Ближайшие 7 дней';

  @override
  String get todoGroupLater => 'Позже';

  @override
  String get todoNew => 'Новая задача';

  @override
  String get todoQuickAddHint => 'Что нужно сделать?';

  @override
  String get todoQuickAddSubmit => 'Добавить';

  @override
  String get todoSearchHint => 'Поиск задач';

  @override
  String get todoEmptyToday => 'На сегодня задач нет';

  @override
  String get todoEmptyList => 'Здесь пока нет задач';

  @override
  String get todoEmptyCompleted => 'Выполненных задач пока нет';

  @override
  String get todoEmptySearch => 'Подходящих задач нет';

  @override
  String todoSortLabel(String mode) {
    return 'Сортировка: $mode';
  }

  @override
  String get todoSortManual => 'Вручную';

  @override
  String get todoSortDue => 'По сроку';

  @override
  String get todoSortPriority => 'По приоритету';

  @override
  String get todoSortCreated => 'По дате создания';

  @override
  String get todoSortTitle => 'Сортировка';

  @override
  String get todoShowCompleted => 'Показывать выполненные';

  @override
  String get todoHideCompleted => 'Скрыть выполненные';

  @override
  String get todoClearCompleted => 'Очистить выполненные';

  @override
  String get todoClearCompletedTitle => 'Очистить выполненные задачи?';

  @override
  String todoClearCompletedBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Будут удалены $count выполненные задачи. Это можно отменить в уведомлении.',
      many:
          'Будут удалены $count выполненных задач. Это можно отменить в уведомлении.',
      few:
          'Будут удалены $count выполненные задачи. Это можно отменить в уведомлении.',
      one:
          'Будет удалена $count выполненная задача. Это можно отменить в уведомлении.',
    );
    return '$_temp0';
  }

  @override
  String todoClearedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Удалено $count задачи',
      many: 'Удалено $count задач',
      few: 'Удалено $count задачи',
      one: 'Удалена $count задача',
    );
    return '$_temp0';
  }

  @override
  String get todoCompletedNotice => 'Выполнено';

  @override
  String todoCompletedNextNotice(String date) {
    return 'Выполнено. Следующий раз: $date';
  }

  @override
  String get todoDeletedNotice => 'Задача удалена';

  @override
  String get todoDelete => 'Удалить задачу';

  @override
  String get todoMarkDone => 'Отметить выполненной';

  @override
  String get todoMarkUndone => 'Отметить невыполненной';

  @override
  String get todoMore => 'Ещё';

  @override
  String get todoListsSection => 'Списки';

  @override
  String get todoListNew => 'Новый список';

  @override
  String get todoListEdit => 'Изменить список';

  @override
  String get todoListNameHint => 'Название списка';

  @override
  String get todoListManage => 'Управление списками';

  @override
  String get todoListDelete => 'Удалить список';

  @override
  String todoListDeleteTitle(String name) {
    return 'Удалить «$name»?';
  }

  @override
  String todoListDeleteBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Вместе со списком будут удалены $count задачи. Это можно отменить в уведомлении.',
      many:
          'Вместе со списком будут удалены $count задач. Это можно отменить в уведомлении.',
      few:
          'Вместе со списком будут удалены $count задачи. Это можно отменить в уведомлении.',
      one:
          'Вместе со списком будет удалена $count задача. Это можно отменить в уведомлении.',
    );
    return '$_temp0';
  }

  @override
  String get todoListDeletedNotice => 'Список удалён';

  @override
  String get todoListColor => 'Цвет';

  @override
  String get todoListIcon => 'Значок';

  @override
  String get todoListEmptyManage =>
      'Списков пока нет. Разделите задачи по работе, дому и т. д., чтобы находить их быстрее.';

  @override
  String get todoNoteHint => 'Добавить заметку';

  @override
  String get todoStepAdd => 'Добавить шаг';

  @override
  String get todoStepDelete => 'Удалить шаг';

  @override
  String todoStepsProgress(int done, int total) {
    return '$done/$total';
  }

  @override
  String get todoFieldDue => 'Дата';

  @override
  String get todoFieldReminders => 'Напоминания';

  @override
  String get todoFieldRepeat => 'Повтор';

  @override
  String get todoFieldPriority => 'Приоритет';

  @override
  String get todoFieldList => 'Список';

  @override
  String get todoFieldDiary => 'Связанная запись';

  @override
  String get todoFieldDiaryMissing => 'Запись не найдена или удалена';

  @override
  String todoCreatedAt(String time) {
    return 'Создано $time';
  }

  @override
  String todoCompletedAt(String time) {
    return 'Выполнено $time';
  }

  @override
  String get todoNotFound => 'Эта задача удалена';

  @override
  String get todoPriorityNone => 'Нет';

  @override
  String get todoPriorityLow => 'Низкий';

  @override
  String get todoPriorityMedium => 'Средний';

  @override
  String get todoPriorityHigh => 'Высокий';

  @override
  String get todoDueToday => 'Сегодня';

  @override
  String get todoDueTomorrow => 'Завтра';

  @override
  String get todoDueYesterday => 'Вчера';

  @override
  String get todoDueNextWeek => 'В следующий понедельник';

  @override
  String get todoDuePickDate => 'Выбрать дату…';

  @override
  String get todoDueAllDay => 'Весь день';

  @override
  String get todoDueSetTime => 'Указать время';

  @override
  String get todoDueRemove => 'Убрать дату';

  @override
  String todoDueWithTime(String date, String time) {
    return '$date, $time';
  }

  @override
  String get todoReminderAtDue => 'В срок';

  @override
  String todoReminderMinutesBefore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'За $count минуты',
      many: 'За $count минут',
      few: 'За $count минуты',
      one: 'За $count минуту',
    );
    return '$_temp0';
  }

  @override
  String todoReminderHoursBefore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'За $count часа',
      many: 'За $count часов',
      few: 'За $count часа',
      one: 'За $count час',
    );
    return '$_temp0';
  }

  @override
  String todoReminderDaysBefore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'За $count дня',
      many: 'За $count дней',
      few: 'За $count дня',
      one: 'За $count день',
    );
    return '$_temp0';
  }

  @override
  String todoReminderOnDayAt(String time) {
    return 'В тот же день в $time';
  }

  @override
  String todoReminderDaysBeforeAt(int count, String time) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'За $count дня в $time',
      many: 'За $count дней в $time',
      few: 'За $count дня в $time',
      one: 'За $count день в $time',
    );
    return '$_temp0';
  }

  @override
  String get todoReminderCustom => 'Своё время…';

  @override
  String todoReminderLimit(int count) {
    return 'Не более $count напоминаний';
  }

  @override
  String get todoReminderRemove => 'Удалить напоминание';

  @override
  String get todoRepeatNone => 'Не повторять';

  @override
  String get todoRepeatDaily => 'Ежедневно';

  @override
  String get todoRepeatLegalWorkdays => 'Рабочие дни (праздники Китая)';

  @override
  String todoRepeatWeeklyOn(String days) {
    return 'Еженедельно: $days';
  }

  @override
  String todoRepeatMonthlyOnDay(int day) {
    return 'Ежемесячно, $day-го числа';
  }

  @override
  String todoRepeatMonthlyOrdinal(String ordinal, String weekday) {
    return 'Ежемесячно: $weekday №$ordinal в месяце';
  }

  @override
  String get todoRepeatMonthlyLastDay => 'Ежемесячно в последний день';

  @override
  String todoRepeatYearlyOn(String date) {
    return 'Ежегодно, $date';
  }

  @override
  String todoRepeatEveryDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Каждые $count дня',
      many: 'Каждые $count дней',
      few: 'Каждые $count дня',
      one: 'Каждый $count день',
    );
    return '$_temp0';
  }

  @override
  String todoRepeatEveryWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Каждые $count недели',
      many: 'Каждые $count недель',
      few: 'Каждые $count недели',
      one: 'Каждую $count неделю',
    );
    return '$_temp0';
  }

  @override
  String todoRepeatEveryMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Каждые $count месяца',
      many: 'Каждые $count месяцев',
      few: 'Каждые $count месяца',
      one: 'Каждый $count месяц',
    );
    return '$_temp0';
  }

  @override
  String todoRepeatEveryYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Каждые $count года',
      many: 'Каждые $count лет',
      few: 'Каждые $count года',
      one: 'Каждый $count год',
    );
    return '$_temp0';
  }

  @override
  String todoRepeatSummaryJoin(String a, String b) {
    return '$a · $b';
  }

  @override
  String get todoRepeatCustom => 'Настроить…';

  @override
  String get todoRepeatCustomTitle => 'Свой повтор';

  @override
  String get todoRepeatUnitDay => 'День';

  @override
  String get todoRepeatUnitWeek => 'Неделя';

  @override
  String get todoRepeatUnitMonth => 'Месяц';

  @override
  String get todoRepeatUnitYear => 'Год';

  @override
  String get todoRepeatInterval => 'Интервал';

  @override
  String get todoRepeatOnDays => 'По дням';

  @override
  String get todoRepeatFromCompletion => 'Считать от выполнения';

  @override
  String get todoRepeatFromCompletionSubtitle =>
      'Для дел вроде полива: снова через время после выполнения';

  @override
  String get todoRepeatEnds => 'Окончание';

  @override
  String get todoRepeatEndsNever => 'Никогда';

  @override
  String todoRepeatEndsOn(String date) {
    return 'До $date';
  }

  @override
  String todoRepeatEndsAfter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count раза',
      many: '$count раз',
      few: '$count раза',
      one: '$count раз',
    );
    return '$_temp0';
  }

  @override
  String get todoRepeatEndsOnPick => 'В дату';

  @override
  String get todoRepeatEndsAfterPick => 'После количества повторов';

  @override
  String get todoSettingsTitle => 'Задачи';

  @override
  String get todoSettingsSubtitle => 'Списки, отображение и напоминания';

  @override
  String get todoSettingsDisplayGroup => 'Отображение';

  @override
  String get todoSettingsShowCompletedSubtitle =>
      'Показывать выполненные задачи внизу списков и входящих';

  @override
  String get todoSettingsDefaultList => 'Новые задачи попадают в';

  @override
  String get todoSettingsDefaultView => 'Открывать';

  @override
  String get todoNotificationChannel => 'Напоминания о задачах';

  @override
  String get todoNotificationChannelDescription =>
      'Уведомляет в заданное время напоминаний о задачах';

  @override
  String get todoNotificationComplete => 'Готово';

  @override
  String get todoNotificationSnooze => 'Отложить';

  @override
  String get todoNotificationOpen => 'Открыть';

  @override
  String get todoNotificationSnoozedBody => 'Отложенное напоминание';

  @override
  String get todoSettingsRemindersGroup => 'Напоминания';

  @override
  String get todoSettingsPermission => 'Разрешение на уведомления';

  @override
  String get todoSettingsPermissionOn => 'Разрешено';

  @override
  String get todoSettingsPermissionOff =>
      'Не разрешено. Нажмите, чтобы включить';

  @override
  String get todoSettingsExactOff =>
      'Система ограничила точные будильники, напоминания могут опаздывать на несколько минут';

  @override
  String get todoSettingsAllDayTime => 'Время напоминаний на весь день';

  @override
  String get todoSettingsSnooze => 'Отложить на';

  @override
  String todoSettingsSnoozeMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count минуты',
      many: '$count минут',
      few: '$count минуты',
      one: '$count минуту',
    );
    return '$_temp0';
  }

  @override
  String get todoSettingsHideContent => 'Скрывать текст на экране блокировки';

  @override
  String get todoSettingsHideContentSubtitle =>
      'На экране блокировки видно только, что есть напоминание; текст — после разблокировки';

  @override
  String get todoSettingsDesktopNote =>
      'На компьютере напоминания появляются, только пока Jotsy открыт. Пока приложение закрыто, напоминания не всплывают.';

  @override
  String get todoSettingsReliability =>
      'Напоминания опаздывают или не приходят?';

  @override
  String get todoSettingsReliabilityBody =>
      'Некоторые системы ограничивают фоновые приложения. Если напоминания часто не срабатывают или опаздывают, разрешите Jotsy автозапуск, отключите для Jotsy оптимизацию батареи и проверьте, что разрешения «Уведомления» и «Будильники и напоминания» включены в настройках системы.';

  @override
  String get todoReminderPermissionDenied =>
      'Уведомления выключены, напоминания не появятся';

  @override
  String get todoReminderPermissionAction => 'Включить';

  @override
  String get calendarShowTodos => 'Показывать задачи';

  @override
  String get calendarShowTodosDescription =>
      'Отмечать дни с задачами и показывать их при выборе дня';

  @override
  String get calendarAddTodo => 'Добавить задачу';

  @override
  String get calendarTodoSectionTitle => 'Задачи на этот день';

  @override
  String get calendarTodoRepeatHint =>
      'Будущий повтор задачи; отметите, когда наступит';

  @override
  String get diaryPreviewAddTodo => 'Добавить задачу';

  @override
  String get diaryPreviewConvertTodos => 'Перенести список в задачи';

  @override
  String get todoConvertTitle => 'Перенести в задачи';

  @override
  String get todoConvertHint =>
      'Выбранные пункты станут задачами, связанными с этой записью. Сама запись не изменится.';

  @override
  String todoConvertSubmit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Добавить $count',
      many: 'Добавить $count',
      few: 'Добавить $count',
      one: 'Добавить $count',
    );
    return '$_temp0';
  }

  @override
  String todoConvertDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Добавлено $count задачи',
      many: 'Добавлено $count задач',
      few: 'Добавлено $count задачи',
      one: 'Добавлена $count задача',
    );
    return '$_temp0';
  }

  @override
  String get diaryLinkedTodosTitle => 'Связанные задачи';

  @override
  String get todoBatchActionComplete => 'Выполнить';

  @override
  String get todoDuplicate => 'Дублировать';

  @override
  String todoDuplicateTitle(String title) {
    return '$title (копия)';
  }

  @override
  String get todoDuplicatedNotice => 'Скопировано в новую задачу';

  @override
  String get todoGroupCompletedTitle => 'Выполнено';

  @override
  String get todoGroupCompletedToday => 'Выполнено сегодня';

  @override
  String get todoHeroAllDone => 'На сегодня всё сделано';

  @override
  String get todoHeroNothing => 'На сегодня ничего не запланировано';

  @override
  String todoHeroDate(String weekday, String date) {
    return '$weekday · $date';
  }

  @override
  String todoHeroRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Осталось $count задачи',
      many: 'Осталось $count задач',
      few: 'Осталось $count задачи',
      one: 'Осталась $count задача',
    );
    return '$_temp0';
  }

  @override
  String todoHeroOverdue(int count) {
    return 'Просрочено: $count';
  }

  @override
  String todoHeroDone(int count) {
    return 'Выполнено: $count';
  }

  @override
  String todoHeroListProgress(int done, int total) {
    return 'Выполнено $done из $total';
  }

  @override
  String todoHeroOpenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Осталось $count задачи',
      many: 'Осталось $count задач',
      few: 'Осталось $count задачи',
      one: 'Осталась $count задача',
    );
    return '$_temp0';
  }

  @override
  String todoHeroCompletedCount(int count) {
    return 'Недавно выполнено: $count';
  }

  @override
  String get todoInlineAddHint => 'Добавить задачу';

  @override
  String get todoListManageShort => 'Изменить';

  @override
  String get todoMoveOverdueToToday => 'Всё на сегодня';

  @override
  String get todoMoveToToday => 'Перенести на сегодня';

  @override
  String get todoMoveToList => 'Переместить в список…';

  @override
  String get todoNoteTitle => 'Заметки';

  @override
  String get todoStepsTitle => 'Шаги';

  @override
  String todoStepsTitleProgress(int done, int total) {
    return 'Шаги $done/$total';
  }

  @override
  String get todoOpenDiary => 'Открыть запись';

  @override
  String get todoQuickParseDismiss => 'Убрать';

  @override
  String todoRemindersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count напоминания',
      many: '$count напоминаний',
      few: '$count напоминания',
      one: '$count напоминание',
    );
    return '$_temp0';
  }

  @override
  String todoSelectedCount(int count) {
    return 'Выбрано: $count';
  }

  @override
  String get todoSelectionExit => 'Выйти из выбора';

  @override
  String get todoViewSheetTitle => 'Выбор вида';

  @override
  String todoBatchCompleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Выполнено $count задачи',
      many: 'Выполнено $count задач',
      few: 'Выполнено $count задачи',
      one: 'Выполнена $count задача',
    );
    return '$_temp0';
  }

  @override
  String todoBatchDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Удалено $count задачи',
      many: 'Удалено $count задач',
      few: 'Удалено $count задачи',
      one: 'Удалена $count задача',
    );
    return '$_temp0';
  }

  @override
  String todoBatchDueRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Дата убрана у $count задачи',
      many: 'Дата убрана у $count задач',
      few: 'Дата убрана у $count задач',
      one: 'Дата убрана у $count задачи',
    );
    return '$_temp0';
  }

  @override
  String todoBatchDueSet(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count задачи перенесено на $date',
      many: '$count задач перенесено на $date',
      few: '$count задачи перенесены на $date',
      one: '$count задача перенесена на $date',
    );
    return '$_temp0';
  }

  @override
  String todoBatchMoved(int count, String list) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count задачи перемещено в «$list»',
      many: '$count задач перемещено в «$list»',
      few: '$count задачи перемещены в «$list»',
      one: '$count задача перемещена в «$list»',
    );
    return '$_temp0';
  }

  @override
  String todoBatchPrioritySet(int count, String priority) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Приоритет «$priority» у $count задачи',
      many: 'Приоритет «$priority» у $count задач',
      few: 'Приоритет «$priority» у $count задач',
      one: 'Приоритет «$priority» у $count задачи',
    );
    return '$_temp0';
  }

  @override
  String get todoSettingsSmartParse => 'Умное распознавание';

  @override
  String get todoSettingsSmartParseSubtitle =>
      'Распознавать «завтра в 15:00 #Работа !!!» как дату, список и приоритет';

  @override
  String get aiToolOpenPageAny => 'Открыть страницу';

  @override
  String get aiToolOpensAfterReply => 'Откроется после ответа';

  @override
  String get aiListSeparator => ', ';

  @override
  String aiToolNamesAndMore(String names, int count) {
    return '$names и др. (всего $count)';
  }

  @override
  String aiToolArgRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String aiToolArgSince(String date) {
    return 'С $date';
  }

  @override
  String aiToolArgUntil(String date) {
    return 'До $date';
  }

  @override
  String get aiToolArgYes => 'Да';

  @override
  String get aiToolArgNo => 'Нет';

  @override
  String aiToolArgMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes минуты',
      many: '$minutes минут',
      few: '$minutes минуты',
      one: '$minutes минута',
    );
    return '$_temp0';
  }

  @override
  String aiToolArgName(String key) {
    String _temp0 = intl.Intl.selectLogic(key, {
      'arg_date_range': 'Даты',
      'arg_due_range': 'Срок',
      'arg_merge_from': 'Объединяемые теги',
      'arg_query': 'Ключевые слова',
      'arg_tags': 'Теги',
      'arg_mood': 'Настроение',
      'arg_include_archived': 'Включая архив',
      'arg_sort': 'Порядок',
      'arg_limit': 'Не больше',
      'arg_group_by': 'Группировка',
      'arg_date': 'Дата',
      'arg_time': 'Время',
      'arg_title': 'Заголовок',
      'arg_name': 'Название',
      'arg_note': 'Заметка',
      'arg_color': 'Цвет',
      'arg_weather': 'Погода',
      'arg_location': 'Место',
      'arg_text': 'Текст',
      'arg_body': 'Текст записи',
      'arg_priority': 'Приоритет',
      'arg_list': 'Список',
      'arg_status': 'Статус',
      'arg_scale': 'Размер шрифта',
      'arg_repeat': 'Повтор',
      'arg_remove': 'Убрать теги',
      'arg_add': 'Добавить теги',
      'arg_remind_before_minutes': 'Напомнить заранее',
      'arg_parent_id': 'Родительский блокнот',
      'arg_offset': 'Начиная с символа',
      'arg_new_name': 'Новое название',
      'arg_mode': 'Оформление',
      'arg_language': 'Язык',
      'arg_into': 'Объединить в',
      'arg_feature': 'Функция',
      'arg_enabled': 'Включено',
      'arg_clear_due': 'Убрать срок',
      'arg_kind_diary': 'Запись',
      'arg_kind_notebook': 'Блокнот',
      'arg_kind_tag': 'Тег',
      'arg_kind_todo': 'Задача',
      'arg_kind_anniversary': 'Памятная дата',
      'arg_kind_day': 'День',
      'arg_steps': 'Шаги',
      'arg_reminders': 'Напоминания',
      'arg_add_steps': 'Добавить шаги',
      'arg_check_steps': 'Отметить шаги',
      'arg_uncheck_steps': 'Снять отметку',
      'arg_remove_steps': 'Удалить шаги',
      'arg_all_day': 'Весь день',
      'arg_kind_todoList': 'Список задач',
      'arg_images': 'Фото',
      'arg_attachments': 'Фото из чата',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String aiToolArgValue(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'sort_relevant': 'По релевантности',
      'sort_newest': 'Сначала новые',
      'sort_oldest': 'Сначала старые',
      'group_by_none': 'Без группировки',
      'group_by_day': 'По дням',
      'group_by_week': 'По неделям',
      'group_by_month': 'По месяцам',
      'group_by_year': 'По годам',
      'status_open': 'Открытые',
      'status_completed': 'Выполненные',
      'status_all': 'Все',
      'priority_none': 'Нет',
      'priority_low': 'Низкий',
      'priority_medium': 'Средний',
      'priority_high': 'Высокий',
      'repeat_once': 'Однократно',
      'repeat_yearly': 'Каждый год',
      'repeat_lunar_yearly': 'Каждый год (лунный)',
      'mood_awful': 'Ужасно',
      'mood_bad': 'Плохо',
      'mood_meh': 'Так себе',
      'mood_good': 'Хорошо',
      'mood_great': 'Отлично',
      'mood_clear': 'Очистить',
      'mode_light': 'Светлая',
      'mode_dark': 'Тёмная',
      'mode_system': 'Как в системе',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String aiToolAddToNotebookNamed(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Добавить $count записи в «$name»',
      many: 'Добавить $count записей в «$name»',
      few: 'Добавить $count записи в «$name»',
      one: 'Добавить $count запись в «$name»',
    );
    return '$_temp0';
  }

  @override
  String aiToolRemoveFromNotebookNamed(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Убрать $count записи из «$name»',
      many: 'Убрать $count записей из «$name»',
      few: 'Убрать $count записи из «$name»',
      one: 'Убрать $count запись из «$name»',
    );
    return '$_temp0';
  }

  @override
  String get aiChatReturnHint => 'Нажмите «Назад», чтобы вернуться к чату';

  @override
  String get aiChatReturnAction => 'К чату';

  @override
  String aiProcessThoughtFor(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Думал $seconds секунды',
      many: 'Думал $seconds секунд',
      few: 'Думал $seconds секунды',
      one: 'Думал $seconds секунду',
    );
    return '$_temp0';
  }

  @override
  String aiProcessThinkingFor(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Думает · $seconds секунды',
      many: 'Думает · $seconds секунд',
      few: 'Думает · $seconds секунды',
      one: 'Думает · $seconds секунда',
    );
    return '$_temp0';
  }

  @override
  String get aiProcessThought => 'Обдумано';

  @override
  String aiProcessTools(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Использовано $count инструмента',
      many: 'Использовано $count инструментов',
      few: 'Использовано $count инструмента',
      one: 'Использован $count инструмент',
    );
    return '$_temp0';
  }

  @override
  String aiProcessFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count не удались',
      many: '$count не удались',
      few: '$count не удались',
      one: '$count не удался',
    );
    return '$_temp0';
  }

  @override
  String get aiProcessSteps => 'Показать шаги';

  @override
  String get aiToolDetailsInputs => 'Параметры';

  @override
  String get aiToolDetailsResult => 'Результат';

  @override
  String get aiToolDetailsFailed => 'Этот шаг не удался';

  @override
  String get aiToolDetailsTechnical => 'Технические сведения';

  @override
  String aiCardEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи',
      many: '$count записей',
      few: '$count записи',
      one: '$count запись',
    );
    return '$_temp0';
  }

  @override
  String aiCardTodoDue(String date) {
    return 'Срок $date';
  }

  @override
  String get aiCardTodoDone => 'Выполнено';

  @override
  String aiCardSearchFor(String query) {
    return 'Поиск «$query»';
  }

  @override
  String get aiCardSectionHome => 'Главная';

  @override
  String get aiCardMissing => 'Больше не существует';

  @override
  String get aiCardFeatureOff => 'Функция выключена';

  @override
  String aiChangeGroupTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Сделано $count изменения',
      many: 'Сделано $count изменений',
      few: 'Сделано $count изменения',
      one: 'Сделано $count изменение',
    );
    return '$_temp0';
  }

  @override
  String get aiChangeUndoAll => 'Отменить все';

  @override
  String get aiChatNewChat => 'Новый чат';

  @override
  String get aiChatHistory => 'Чаты';

  @override
  String get aiChatHistoryEmpty => 'Чатов пока нет';

  @override
  String get aiChatHistoryNoMatch => 'Подходящих чатов нет';

  @override
  String get aiChatGroupPinned => 'Закреплённые';

  @override
  String get aiChatGroupToday => 'Сегодня';

  @override
  String get aiChatGroupYesterday => 'Вчера';

  @override
  String get aiChatGroupWeek => 'Последние 7 дней';

  @override
  String get aiChatGroupMonth => 'Последние 30 дней';

  @override
  String get aiChatWelcomeTitle => 'О чём поговорим?';

  @override
  String get aiChatWelcomeAgent =>
      'Спросите о дневнике или попросите разобрать записи, добавить задачи и открыть нужные страницы.';

  @override
  String get aiChatWelcomeRetrieval =>
      'Спросите о дневнике — я найду нужные записи и отвечу.';

  @override
  String get aiChatWelcomeRecaps => 'Обзоры';

  @override
  String get aiChatWelcomeRecent => 'Недавние чаты';

  @override
  String get aiChatWelcomeAllChats => 'Все чаты';

  @override
  String get aiChatModelSheetTitle => 'Модель и размышление';

  @override
  String get aiChatThinking => 'Глубина размышления';

  @override
  String get aiThinkingAuto => 'Авто';

  @override
  String get aiThinkingOff => 'Выкл.';

  @override
  String get aiThinkingLow => 'Низк.';

  @override
  String get aiThinkingMedium => 'Средн.';

  @override
  String get aiThinkingHigh => 'Высок.';

  @override
  String get aiThinkingAutoHint => 'Модель сама решает, думать ли и сколько';

  @override
  String get aiThinkingOffHint =>
      'Без размышлений, сразу отвечает — быстрее всего';

  @override
  String get aiThinkingLowHint => 'Немного подумать — для обычных вопросов';

  @override
  String get aiThinkingMediumHint => 'Баланс для большинства вопросов';

  @override
  String get aiThinkingHighHint =>
      'Тщательно — для разбора, обзоров и сложных изменений; медленнее всего';

  @override
  String get aiThinkingDisabled =>
      'Для этой модели размышление выключено в её настройках';

  @override
  String aiChatMetaThinking(String level) {
    return 'Размышление: $level';
  }

  @override
  String get aiChatOpenSettings => 'Настройки ИИ';

  @override
  String get aiChatExport => 'Экспорт чата';

  @override
  String get aiChatExportFormat => 'Формат';

  @override
  String get aiChatExportMarkdown => 'Markdown';

  @override
  String get aiChatExportPlain => 'Простой текст';

  @override
  String get aiChatExportInclude => 'Включить';

  @override
  String get aiChatExportReasoning => 'Размышления';

  @override
  String get aiChatExportSteps => 'Шаги и действия';

  @override
  String get aiChatExportMessages => 'Выберите сообщения';

  @override
  String aiChatExportSelected(int count, int total) {
    return 'Выбрано $count из $total';
  }

  @override
  String get aiChatExportYou => 'Вы';

  @override
  String get aiChatExportSave => 'Сохранить в файл';

  @override
  String get aiChatExportSaved => 'Чат экспортирован';

  @override
  String get aiChatExportFailed => 'Не удалось экспортировать чат';

  @override
  String aiChatExportAt(String time, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Экспорт $time · $count сообщения',
      many: 'Экспорт $time · $count сообщений',
      few: 'Экспорт $time · $count сообщения',
      one: 'Экспорт $time · $count сообщение',
    );
    return '$_temp0';
  }

  @override
  String get aiChatExportReferences => 'Использованные записи';

  @override
  String aiChatExportError(String reason) {
    return 'Ошибка: $reason';
  }

  @override
  String aiChatExportSubjects(String names) {
    return ': $names';
  }

  @override
  String get aiChatExportJson => 'JSON';
}
