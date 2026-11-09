// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations_gen.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Jotsy';

  @override
  String get navDiaries => '日記';

  @override
  String get navCalendar => 'カレンダー';

  @override
  String get navExplore => '探索';

  @override
  String get navSettings => '設定';

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get commonConfirm => 'OK';

  @override
  String get commonDelete => '削除';

  @override
  String get commonUndo => '元に戻す';

  @override
  String get commonDragToReorder => 'ドラッグして並べ替え';

  @override
  String get commonSelectAll => 'すべて選択';

  @override
  String get commonDeselectAll => 'すべての選択を解除';

  @override
  String get commonBack => '戻る';

  @override
  String get commonSave => '保存';

  @override
  String get commonEdit => '編集';

  @override
  String get commonShare => '共有';

  @override
  String get commonContinue => '続行';

  @override
  String get commonCreate => '作成';

  @override
  String get commonClose => '閉じる';

  @override
  String get commonNew => '新規作成';

  @override
  String get commonReset => 'リセット';

  @override
  String get commonRetry => '再試行';

  @override
  String get contextFieldInputHint => '天気や住所を入力するか、右のボタンをタップして自動取得します';

  @override
  String get contextLocationInputHint => '住所を入力するか、右のボタンをタップして自動取得します';

  @override
  String get contextWeatherInputHint => '天気を入力するか、右のボタンをタップして自動取得します';

  @override
  String get timeJustNow => 'たった今';

  @override
  String timeMinutesAgo(int minutes) {
    return '$minutes分前';
  }

  @override
  String timeHoursAgo(int hours) {
    return '$hours時間前';
  }

  @override
  String timeDaysAgo(int days) {
    return '$days日前';
  }

  @override
  String updatedAtLabel(String value) {
    return '$valueに更新';
  }

  @override
  String get startupPreloadFailed => '起動時に日記を事前に読み込めませんでしたが、ホームを表示しました。';

  @override
  String homeInitFailed(String error) {
    return '初期化に失敗しました：$error';
  }

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsFontScale => '文字サイズ';

  @override
  String get settingsFontScaleSubtitle => 'アプリ画面の文字サイズを調整';

  @override
  String get settingsFontScalePreview => 'プレビュー：今日も暮らしのひとコマを書き留めました。';

  @override
  String get settingsDiaryCardTagLimit => '日記カードのタグ';

  @override
  String get settingsDiaryCardTagLimitLoading => '日記カードの設定を読み込み中';

  @override
  String get settingsDiaryCardTagLimitUnavailable => 'この設定は現在利用できません';

  @override
  String get settingsDiaryCardTagLimitHidden => 'タグを表示しない';

  @override
  String settingsDiaryCardTagLimitValue(int count) {
    return 'タグを最大$count個表示';
  }

  @override
  String get settingsTabSwitchCurve => 'タブ切り替えのカーブ';

  @override
  String get settingsTabSwitchCurveSubtitle => '下部タブを切り替えるときのアニメーションの動きを選択';

  @override
  String get settingsTabSwitchCurveEaseOutCirc => 'なめらか（Circ）';

  @override
  String get settingsTabSwitchCurveEaseOutCubic => 'バランス（Cubic）';

  @override
  String get settingsTabSwitchCurveLinear => 'リニア';

  @override
  String get settingsLanguage => '言語';

  @override
  String get settingsAppLock => 'アプリロック';

  @override
  String get settingsAppLockSubtitle => 'オンにすると、アプリを開くたびに認証が必要になります';

  @override
  String get appLockNotSupported =>
      'この端末には画面ロックが設定されていないため、システム認証ではアプリロックを有効にできません。アプリのパスコードに切り替えてください。';

  @override
  String get appLockTitle => 'アプリはロックされています';

  @override
  String get appLockSubtitle => '続けるには認証してください';

  @override
  String get appLockUnlockNow => 'ロックを解除';

  @override
  String get appLockUnlocking => 'ロックを解除しています';

  @override
  String get appLockDisableAuthReason => 'アプリロックをオフにするには認証してください';

  @override
  String get appLockDisableVerifyFailed => '認証できませんでした。アプリロックはオンのままです。';

  @override
  String get settingsEditorTitle => 'エディター';

  @override
  String get settingsEditorSubtitle => 'フォントとレイアウト、ツールバー、コードブロック';

  @override
  String get settingsMoodOptionsTitle => '気分の絵文字';

  @override
  String settingsMoodOptionsSlotLabel(String index) {
    return '気分$index';
  }

  @override
  String settingsMoodOptionsSlotHelper(String emoji) {
    return 'デフォルト：$emoji';
  }

  @override
  String settingsMoodOptionsColorLabel(String index) {
    return '気分$indexの色';
  }

  @override
  String get settingsMoodOptionsColorsHint =>
      '色は、プレビュー画面の配色ベース「気分」と、日記カードの気分カラーに使われます。絵文字の左にある色見本をタップすると変更できます。';

  @override
  String settingsMoodOptionsSaveFailed(String error) {
    return '気分の絵文字を保存できませんでした：$error';
  }

  @override
  String get settingsDataManagement => 'データ管理';

  @override
  String get settingsDataManagementSubtitle =>
      'バックアップと復元、インポート／エクスポート、クラウドバックアップ';

  @override
  String get settingsTagManagement => 'タグ管理';

  @override
  String get settingsTagMemory => 'タグを記憶';

  @override
  String get settingsTagMemorySubtitle => '日記一覧で選んだタグを記憶し、次回起動時に復元します';

  @override
  String get settingsRecycleBin => 'ゴミ箱';

  @override
  String get settingsAbout => 'このアプリについて';

  @override
  String get languageDialogTitle => '言語を選択';

  @override
  String get languageOptionChinese => '中文';

  @override
  String get languageOptionEnglish => 'English';

  @override
  String get aboutTitle => 'このアプリについて';

  @override
  String get aboutTagline => '毎日の小さな出来事と気持ちを記録';

  @override
  String get aboutVersion => 'バージョン';

  @override
  String get aboutPackageName => 'パッケージ名';

  @override
  String get aboutRepository => 'リポジトリ';

  @override
  String get aboutCopied => 'クリップボードにコピーしました';

  @override
  String get aboutPageSlogan => '騒がしい世界の中にある、あなただけの静かな場所。';

  @override
  String get aboutOpenSourceRepo => 'オープンソースのリポジトリ';

  @override
  String get aboutCheckUpdate => 'アップデートを確認';

  @override
  String aboutUpdateSubtitleAvailable(String version) {
    return '$version が利用可能です';
  }

  @override
  String aboutUpdateSubtitleDownloading(int percent) {
    return 'ダウンロード中 $percent%';
  }

  @override
  String get aboutUpdateSubtitleReady => 'ダウンロード完了。タップしてインストール';

  @override
  String get appUpdateTitle => 'アプリのアップデート';

  @override
  String appUpdateCurrentVersion(String version) {
    return '現在のバージョン $version';
  }

  @override
  String get appUpdateChecking => 'アップデートを確認中…';

  @override
  String get appUpdateCheckingHint => '複数の接続先を同時に試し、最初に応答したものを使います';

  @override
  String get appUpdateUpToDate => '最新バージョンです';

  @override
  String appUpdateLastChecked(String time) {
    return '最終確認：$time';
  }

  @override
  String get appUpdateAvailableBadge => 'NEW';

  @override
  String appUpdateAvailableTitle(String version) {
    return 'バージョン $version が利用可能です';
  }

  @override
  String appUpdatePublishedOn(String date) {
    return 'リリース日：$date';
  }

  @override
  String get appUpdateReleaseNotesTitle => '更新内容';

  @override
  String get appUpdateCurrentNotesTitle => 'このバージョンの更新内容';

  @override
  String get appUpdateNoReleaseNotes => 'このバージョンには更新内容の説明がありません。';

  @override
  String get appUpdateViewOnGitHub => 'GitHub で見る';

  @override
  String get aboutChangelog => '更新履歴';

  @override
  String get changelogTitle => '更新履歴';

  @override
  String get changelogCurrentVersion => '使用中';

  @override
  String get changelogShowAll => 'すべて表示';

  @override
  String get changelogCollapse => '折りたたむ';

  @override
  String get changelogEmpty => '表示できる更新履歴はありません。';

  @override
  String get changelogAllReleases => 'GitHub ですべてのリリースを見る';

  @override
  String get appUpdateActionCheck => 'アップデートを確認';

  @override
  String appUpdateActionDownload(String size) {
    return 'ダウンロードしてインストール（$size）';
  }

  @override
  String get appUpdateActionDownloadNoSize => 'ダウンロードしてインストール';

  @override
  String appUpdateActionResume(int percent) {
    return 'ダウンロードを再開（$percent%完了）';
  }

  @override
  String get appUpdateActionCancel => 'ダウンロードをキャンセル';

  @override
  String get appUpdateActionInstall => 'インストール';

  @override
  String get appUpdateActionRetry => '再試行';

  @override
  String get appUpdateActionOpenReleasePage => 'ダウンロードページを開く';

  @override
  String get appUpdateActionSkip => 'このバージョンをスキップ';

  @override
  String get appUpdateSkippedHint => 'このバージョンはスキップしました。起動時には通知しません';

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
    return '$route 経由';
  }

  @override
  String get appUpdateVerifying => 'パッケージを検証中…';

  @override
  String get appUpdateReadyToInstall => 'ダウンロードと検証が完了しました';

  @override
  String get appUpdateInstallPermissionTitle => 'アプリのインストールを許可';

  @override
  String get appUpdateInstallPermissionMessage =>
      'Android のシステム設定で、Jotsy に「不明なアプリのインストール」を許可する必要があります。許可してからここに戻ると、自動的にインストールが続きます。';

  @override
  String get appUpdateInstallPermissionAction => '設定を開く';

  @override
  String get appUpdateInstallPermissionSettingsFailed =>
      'システム設定を開けませんでした。「設定 → アプリ → Jotsy」で不明なアプリのインストールを許可してください。';

  @override
  String get appUpdateUnsupportedPlatform =>
      'このプラットフォームではアプリ内インストールに対応していません。ダウンロードページから新しいバージョンを入手してください。';

  @override
  String get appUpdateNoCompatibleApk =>
      'このリリースには、この端末のプロセッサに対応するパッケージがありません。ダウンロードページで手動で選んでください。';

  @override
  String get appUpdateFailedCheckTitle => 'アップデートを確認できませんでした';

  @override
  String get appUpdateFailedDownloadTitle => 'ダウンロードに失敗しました';

  @override
  String get appUpdateFailedInstallTitle => 'インストールできませんでした';

  @override
  String get appUpdateFailureNetwork =>
      'すべての接続先に接続できませんでした。しばらくしてから再試行するか、下の「ダウンロード元」で別の接続先やカスタムミラーを選んでください。';

  @override
  String get appUpdateFailureNotFound => '公開済みのリリースが見つかりませんでした。';

  @override
  String get appUpdateFailureIntegrity =>
      'ダウンロードしたファイルが不完全か改変されていたため（チェックサム不一致）、削除しました。再試行するか、別の接続先を使ってください。';

  @override
  String get appUpdateFailureSignature =>
      'パッケージの署名がこのアプリと異なるため、上書きインストールできません。公式のリリースページからのみダウンロードしてください。';

  @override
  String get appUpdateFailureNotNewer => 'ダウンロードしたパッケージは、現在のバージョンより新しくありません。';

  @override
  String get appUpdateFailureStorage => 'パッケージを保存できませんでした。端末の空き容量を確認してください。';

  @override
  String get appUpdateFailureInstallUnavailable =>
      'システムのインストーラーを開けませんでした。ダウンロードページから手動でインストールしてください。';

  @override
  String get appUpdateSettingsTitle => 'アップデートの設定';

  @override
  String get appUpdateAutoCheck => '自動で確認';

  @override
  String get appUpdateAutoCheckSubtitle =>
      'アプリを開いたときや戻ったときに確認します（最大2時間に1回）。公開されているリリース情報だけを読み取ります';

  @override
  String get appUpdateSource => 'ダウンロード元';

  @override
  String get appUpdateSourceAuto => '自動';

  @override
  String get appUpdateSourceAutoDescription =>
      'すべての接続先の速度を測り、最も速いものを使います。中国本土でのご利用におすすめ';

  @override
  String get appUpdateSourceDirect => 'GitHub に直接接続';

  @override
  String get appUpdateSourceDirectDescription =>
      'ミラーを経由しません。中国本土では遅い、または接続できないことがあります';

  @override
  String get appUpdateSourceMirrorDescription => '公開ミラー';

  @override
  String get appUpdateSourceCustom => 'カスタムミラー';

  @override
  String get appUpdateSourceCustomDescription =>
      '内蔵のミラーが使えなくなったときに、利用できる GitHub プロキシを入力します';

  @override
  String get appUpdateSourceCustomHint => '例：https://mirror.example.com/';

  @override
  String get appUpdateSourceCustomInvalid => 'https:// で始まるアドレスを入力してください';

  @override
  String get appUpdateSourceSheetHint =>
      'ミラーはサードパーティの公開サービスです。ダウンロードしたパッケージはすべて SHA-256 とアプリの署名で照合されるため、ミラーが別のアプリにすり替えることはできません。';

  @override
  String get appUpdatePromptUpdate => '今すぐアップデート';

  @override
  String get appUpdatePromptLater => 'あとで';

  @override
  String get appUpdateActionDesktopDownload => 'ダウンロード';

  @override
  String get appUpdateDesktopHintWindows =>
      'ブラウザでインストーラーをダウンロードします。実行すると上書きでアップデートされ、日記はそのまま残ります。';

  @override
  String get appUpdateDesktopHintLinux =>
      'ブラウザで .tar.gz アーカイブをダウンロードします。展開して install.sh を実行するとアップデートされ、日記はそのまま残ります。';

  @override
  String get appUpdateNoDesktopPackage =>
      'このリリースには、このシステム向けのパッケージがありません。ダウンロードページを確認してください。';

  @override
  String get appUpdateSourceAutoDescriptionDesktop =>
      'アップデートの確認で最初に応答した接続先を使います。中国本土でのご利用におすすめ';

  @override
  String get appUpdateSourceSheetHintDesktop =>
      'ミラーはサードパーティの公開サービスです。ダウンロード後、リリースページの SHA256SUMS.txt でファイルを照合できます。';

  @override
  String get aboutSubmitIssue => 'Issue を報告';

  @override
  String get aboutQqFeedbackGroup => 'QQ フィードバックグループ';

  @override
  String get aboutQqFeedbackGroupSubtitle => '678136434';

  @override
  String get aboutQqFeedbackGroupCopied => 'QQ グループ番号をクリップボードにコピーしました';

  @override
  String get aboutPrivacyAndData => 'プライバシーとデータの安全性';

  @override
  String get aboutPrivacyDialogTitle => 'プライバシーとデータの安全性';

  @override
  String get aboutPrivacyDialogMessage =>
      '日記、タグ、メディアファイルはこの端末内に保存され、初期設定ではクラウドにアップロードされません。AI アシスタントは初期設定でオフです。オンにした場合も、AI 機能を使うときに必要な内容だけを、あなたが設定した AI サービスに直接送信します。キーはこの端末にのみ保存されます。';

  @override
  String get aboutOpenSourceLicenses => 'サードパーティのオープンソースライセンス';

  @override
  String get aboutOpenLinkFallbackCopied => 'リンクを直接開けなかったため、クリップボードにコピーしました。';

  @override
  String get aboutFooterCopyright => '© 2026 Jot Project';

  @override
  String get dataMgmtTitle => 'データ管理';

  @override
  String get dataMgmtExport => 'データをエクスポート';

  @override
  String get dataMgmtExportSubtitle =>
      '日記、タグ、設定、画像、録音、動画、添付ファイルを含む ZIP をエクスポートします';

  @override
  String get dataMgmtImport => 'データをインポート';

  @override
  String get dataMgmtImportSubtitle => '完全なバックアップや日記ファイルを、統合または上書きでインポートします';

  @override
  String get dataMgmtHint =>
      '1件の日記だけをエクスポートするには、その日記のプレビュー画面で「その他」メニューを使います。統合インポートはこの端末にない日記を追加するだけで、既存の日記は変更しません。上書き復元はこの端末のデータを完全に置き換えるため、先にバックアップをエクスポートしておいてください。';

  @override
  String get dataMgmtBusyExport => 'データをエクスポート中…';

  @override
  String get dataMgmtBusyImport => 'データをインポート中…';

  @override
  String get dataMgmtSaveDialogTitle => 'バックアップを保存';

  @override
  String get dataMgmtPickDialogTitle => 'バックアップファイルを選択';

  @override
  String get dataMgmtExportSuccess => 'データのエクスポートが完了しました';

  @override
  String get dataMgmtExportCanceled => 'エクスポートをキャンセルしました';

  @override
  String dataMgmtExportFailed(String error) {
    return 'エクスポートに失敗しました：$error';
  }

  @override
  String get dataMgmtImportSuccess => 'データのインポートが完了しました';

  @override
  String get dataMgmtImportCanceled => 'インポートをキャンセルしました';

  @override
  String dataMgmtImportFailed(String error) {
    return 'インポートに失敗しました：$error';
  }

  @override
  String get dataMgmtImportAction => 'インポート';

  @override
  String get dataMgmtBusyLabel => 'データを処理中';

  @override
  String get dataMgmtExportPasswordTitle => 'エクスポート用パスワードを設定（任意）';

  @override
  String get dataMgmtExportPasswordHint => '空欄のままにすると暗号化しません';

  @override
  String get dataMgmtExportPasswordWarning =>
      'このパスワードは大切に保管してください。データはこの端末上でエンドツーエンド暗号化されるため、パスワードを再発行することはできません。忘れてしまうと、エクスポートしたデータは二度と復元できません。';

  @override
  String get dataMgmtImportPasswordTitle => 'インポート用パスワード';

  @override
  String get dataMgmtImportPasswordHint => 'インポート用パスワードを入力';

  @override
  String colorFamilySwatchLabel(int index, String hex) {
    return 'カラーパレット$index、$hex';
  }

  @override
  String colorSwatchLabel(String hex) {
    return '色 $hex';
  }

  @override
  String get diaryPinSelected => 'ピン留め';

  @override
  String get diaryUnpinSelected => 'ピン留めを解除';

  @override
  String get tagFilterClearLabel => 'タグの絞り込みをクリア';

  @override
  String searchRemoveTagCondition(String tagName) {
    return 'タグ「$tagName」を条件から外す';
  }

  @override
  String get passwordShow => 'パスワードを表示';

  @override
  String get passwordHide => 'パスワードを非表示';

  @override
  String get commonLoading => '読み込み中';

  @override
  String exploreOnThisDayYearsAgo(int years) {
    return '$years年前の今日';
  }

  @override
  String get dateTimeMinutePattern => 'yyyy/MM/dd HH:mm';

  @override
  String get energyLevelExhausted => 'へとへと';

  @override
  String get energyLevelTired => 'ちょっと疲れ気味';

  @override
  String get energyLevelSoSo => 'まあまあ';

  @override
  String get energyLevelGood => 'わりと元気';

  @override
  String get energyLevelFull => '元気いっぱい';

  @override
  String get startupPreloadFailedNotice => '起動時に日記を事前に読み込めませんでしたが、ホームを表示しました。';

  @override
  String startupInitFailed(String error) {
    return '初期化に失敗しました：$error';
  }

  @override
  String get appLockAuthReason => 'アプリのロックを解除するには認証してください';

  @override
  String get autoT0001 => 'アプリを読み込み中';

  @override
  String get autoT0002 => 'コピー';

  @override
  String get autoT0003 => '並び順をリセット';

  @override
  String autoT0004(String p0) {
    return '並び順を保存できませんでした：$p0';
  }

  @override
  String get autoT0005 => 'ツールバーの並び順';

  @override
  String get autoT0006 => '元に戻す';

  @override
  String get autoT0007 => 'やり直す';

  @override
  String get autoT0008 => '太字';

  @override
  String get autoT0009 => '斜体';

  @override
  String get autoT0010 => '下線';

  @override
  String get autoT0011 => '取り消し線';

  @override
  String get autoT0012 => 'インラインコード';

  @override
  String get autoT0013 => '文字色';

  @override
  String get autoT0014 => '背景色';

  @override
  String get autoT0015 => '書式をクリア';

  @override
  String get autoT0016 => '画像を挿入';

  @override
  String get autoT0017 => '見出しのスタイル';

  @override
  String get autoT0018 => '番号付きリスト';

  @override
  String get autoT0019 => '箇条書き';

  @override
  String get autoT0020 => 'チェックリスト';

  @override
  String get autoT0021 => 'コードブロック';

  @override
  String get autoT0022 => '引用';

  @override
  String get autoT0023 => 'インデント';

  @override
  String get autoT0024 => 'リンク';

  @override
  String get autoT0025 => '削除日時不明';

  @override
  String get autoT0026 => '一部を復元できませんでした。もう一度お試しください。';

  @override
  String get autoT0027 => '一部を削除できませんでした。もう一度お試しください。';

  @override
  String get autoT0028 => '完全に削除';

  @override
  String get autoT0029 => 'ゴミ箱';

  @override
  String get autoT0030 => '復元';

  @override
  String autoT0031(String p0) {
    return 'ゴミ箱を読み込めませんでした：$p0';
  }

  @override
  String get autoT0032 => 'ゴミ箱は空です';

  @override
  String get autoT0033 => '無題';

  @override
  String autoT0034(String p0) {
    return 'タグを作成できませんでした：$p0';
  }

  @override
  String autoT0035(String p0) {
    return 'タグを編集できませんでした：$p0';
  }

  @override
  String autoT0036(String p0) {
    return 'タグを削除できませんでした：$p0';
  }

  @override
  String autoT0037(String p0) {
    return 'タグの並び順を保存できませんでした：$p0';
  }

  @override
  String get autoT0038 => 'タグを削除';

  @override
  String get autoT0039 => 'タグ管理';

  @override
  String get autoT0040 => 'タグを作成';

  @override
  String get autoT0041 => '最初のタグを作成';

  @override
  String autoT0042(String p0) {
    return 'タグを読み込めませんでした：$p0';
  }

  @override
  String get autoT0043 => 'ツールバーの並び順';

  @override
  String autoT0044(String p0) {
    return '現在の先頭4項目：$p0';
  }

  @override
  String autoT0045(String p0) {
    return '設定を読み込めませんでした：$p0';
  }

  @override
  String get autoT0046 => 'システム';

  @override
  String get autoT0047 => 'ライト';

  @override
  String get autoT0048 => 'ダーク';

  @override
  String get autoT0049 => '今日、思いがけずうれしかったことは？';

  @override
  String get autoT0050 => '今日にタイトルをつけるなら、何にしますか？';

  @override
  String get autoT0051 => '今日いちばん覚えておきたい瞬間は？';

  @override
  String get autoT0052 => 'メディアのプレビュー';

  @override
  String get autoT0053 => '表示できる画像がありません';

  @override
  String get autoT0054 => 'メディアギャラリー';

  @override
  String get autoT0055 => '表示できる画像はまだありません';

  @override
  String get autoT0056 => '読み込みに失敗しました。タップして再試行';

  @override
  String get autoT0057 => 'これ以上画像はありません';

  @override
  String get autoT0058 => '探索';

  @override
  String get autoT0059 => '探索のデータを利用できません';

  @override
  String get autoT0061 => 'すべての画像を見る';

  @override
  String get autoT0062 => '表示できる画像はまだありません。';

  @override
  String get autoT0063 => '過去の今日';

  @override
  String get autoT0064 => '今日の日記を書く';

  @override
  String get autoT0065 => '無題の日記';

  @override
  String get autoT0069 => 'タグクラウド';

  @override
  String get autoT0070 => '日記を削除';

  @override
  String get autoT0071 => 'アーカイブを解除できませんでした。もう一度お試しください。';

  @override
  String get autoT0072 => 'アーカイブ状態に戻しました';

  @override
  String get autoT0073 => '削除できませんでした。もう一度お試しください。';

  @override
  String autoT0074(String p0) {
    return '$p0件の日記を削除しました';
  }

  @override
  String get autoT0075 => '日記を削除しました';

  @override
  String get autoT0076 => '削除した日記を元に戻しました';

  @override
  String get autoT0077 => '復元できませんでした。もう一度お試しください。';

  @override
  String get autoT0078 => 'アーカイブできませんでした。もう一度お試しください。';

  @override
  String autoT0079(String p0) {
    return '$p0件の日記をアーカイブしました';
  }

  @override
  String get autoT0080 => 'アーカイブした日記を元に戻しました';

  @override
  String autoT0084(String p0) {
    return '選択した$p0件の日記を削除しますか？';
  }

  @override
  String get autoT0085 => '詳しい住所情報がありません';

  @override
  String get autoT0086 => 'タイトルと本文の両方を空にすることはできません';

  @override
  String autoT0087(String p0) {
    return '保存できませんでした：$p0';
  }

  @override
  String get autoT0088 => '有効な表紙のパスが見つかりませんでした';

  @override
  String get autoT0092 => '先に現在地を取得してください';

  @override
  String get autoT0094 => '日記を削除';

  @override
  String get autoT0095 => '無題の日記';

  @override
  String get autoT0096 => '投稿日を選択';

  @override
  String get autoT0097 => '投稿時刻を選択';

  @override
  String autoT0099(String p0) {
    return '$p0件選択中';
  }

  @override
  String get autoT0100 => 'アーカイブした日記';

  @override
  String get autoT0101 => 'アーカイブを解除';

  @override
  String autoT0102(String p0) {
    return 'アーカイブを読み込めませんでした：$p0';
  }

  @override
  String get autoT0103 => 'アーカイブした日記はありません';

  @override
  String get autoT0104 => '（本文なし）';

  @override
  String get autoT0105 => 'なし';

  @override
  String get autoT0106 => 'タイトル';

  @override
  String get autoT0107 => '作成日時';

  @override
  String get autoT0108 => '更新日時';

  @override
  String get autoT0109 => 'タグ';

  @override
  String get autoT0110 => '本文';

  @override
  String get autoT0111 => 'スクリーンショットを作成できませんでした。もう一度お試しください。';

  @override
  String autoT0112(String p0) {
    return '画像を共有できませんでした：$p0';
  }

  @override
  String get autoT0113 => 'この日記を削除しますか？';

  @override
  String get autoT0114 => '画像で共有';

  @override
  String get autoT0115 => 'テキストで共有';

  @override
  String get previewExportSaveDialogTitle => 'エクスポートファイルを保存';

  @override
  String get previewExportCanceled => 'エクスポートをキャンセルしました';

  @override
  String previewExportFailed(String error) {
    return 'エクスポートに失敗しました：$error';
  }

  @override
  String get autoT0116 => '気分';

  @override
  String get autoT0117 => '投稿日時';

  @override
  String get autoT0118 => '最終編集';

  @override
  String get autoT0119 => '本文はまだありません';

  @override
  String get autoT0120 => '日記';

  @override
  String autoT0121(String p0) {
    return '読み込めませんでした：$p0';
  }

  @override
  String get autoT0122 => 'この日記はもう存在しません';

  @override
  String get autoT0123 => 'この日記はもう存在しません。前の画面に戻ります…';

  @override
  String get autoT0124 => '日記が見つかりません';

  @override
  String get autoT0125 => 'その他';

  @override
  String autoT0126(String p0) {
    return 'タグ$p0';
  }

  @override
  String autoT0127(String p0) {
    return '日記を読み込めませんでした：$p0';
  }

  @override
  String get autoT0128 => '検索を閉じる';

  @override
  String get autoT0129 => 'タイトルや本文を検索';

  @override
  String get autoT0130 => 'クリア';

  @override
  String get autoT0131 => '未保存の変更';

  @override
  String get autoT0132 => '終了';

  @override
  String get editSaveAndExit => '保存して終了';

  @override
  String get autoT0133 => '書き始めましょう…';

  @override
  String get autoT0134 => '新しい日記';

  @override
  String get autoT0135 => '日記を編集';

  @override
  String get autoT0136 => '投稿';

  @override
  String get autoT0137 => '日記を保存';

  @override
  String get autoT0138 => '日記を投稿';

  @override
  String get autoT0139 => '本文がありません';

  @override
  String get autoT0140 => 'アーカイブ';

  @override
  String get autoT0141 => '並べ替え';

  @override
  String get autoT0145 => 'レイアウト';

  @override
  String get autoT0146 => 'リスト';

  @override
  String get autoT0147 => 'タイル';

  @override
  String get autoT0148 => 'アーカイブした日記';

  @override
  String get autoT0149 => 'タグを編集';

  @override
  String get autoT0150 => 'タグ名';

  @override
  String get autoT0151 => '色を選択';

  @override
  String get autoT0152 => '日記が見つかりませんでした';

  @override
  String get autoT0153 => '別のキーワードで試してみてください。';

  @override
  String get autoT0154 => 'まだ日記がありません';

  @override
  String get autoT0155 => '日記を書く';

  @override
  String get autoT0156 => '表紙を読み込めませんでした';

  @override
  String get autoT0157 => '新規作成';

  @override
  String get autoT0158 => '上にスワイプして展開';

  @override
  String get autoT0159 => '下にスワイプして折りたたむ';

  @override
  String get autoT0160 => 'タグを選択';

  @override
  String get autoT0161 => 'タップして表紙を選択（任意）';

  @override
  String get autoT0162 => '表紙';

  @override
  String get autoT0163 => '表紙を外す';

  @override
  String get autoT0164 => 'タグが選択されていません';

  @override
  String autoT0165(String p0) {
    return 'タグを読み込めませんでした：$p0';
  }

  @override
  String get autoT0166 => 'タグはまだありません。先に作成してください';

  @override
  String get autoT0167 => 'いま、ここ';

  @override
  String get autoT0168 => '右のボタンをタップして住所を取得';

  @override
  String get autoT0169 => '場所を取得';

  @override
  String get autoT0170 => '右のボタンをタップして天気を取得';

  @override
  String get autoT0171 => '天気を取得';

  @override
  String get autoT0172 => '投稿日時';

  @override
  String get autoT0173 => '現在時刻を自動で使用';

  @override
  String get autoT0174 => '投稿日時を選択';

  @override
  String get autoT0175 => 'エネルギー';

  @override
  String get autoT0176 => '投稿中…';

  @override
  String get autoT0177 => '日付を選択';

  @override
  String get autoT0178 => '月';

  @override
  String get autoT0179 => '週';

  @override
  String get autoT0180 => '今日に戻る';

  @override
  String get autoT0181 => 'この日の日記を書く';

  @override
  String get autoT0182 => 'この日は静かで、まだ何も記録されていません。';

  @override
  String get autoT0183 => 'カレンダー';

  @override
  String get autoT0184 => '前の月';

  @override
  String get autoT0185 => '次の月';

  @override
  String get autoT0186 => '記録を残しました';

  @override
  String get autoT0187 => 'ツールバーの並び順をデフォルトに戻しますか？';

  @override
  String get autoT0188 => '選択したテキストをインラインコードにします';

  @override
  String get autoT0189 =>
      'コードブロックに変換します。コードブロック内でタップすると、言語の選択、コピー、ブロックの終了ができます。';

  @override
  String get autoT0190 => 'インデントを増やす／減らすボタンを両方表示します';

  @override
  String autoT0191(String p0) {
    return '$p0件の日記を復元しました';
  }

  @override
  String autoT0192(String p0) {
    return '$p0件の日記を完全に削除しました';
  }

  @override
  String autoT0193(String p0) {
    return '選択した$p0件の日記を完全に削除しますか？この操作は元に戻せません。';
  }

  @override
  String autoT0194(String p0) {
    return '$p0に削除';
  }

  @override
  String recycleBinEntryFooter(String date, String deletedAt) {
    return '$date · $deletedAt';
  }

  @override
  String autoT0195(String p0) {
    return 'タグ「$p0」を削除しますか？';
  }

  @override
  String get autoT0196 => '今日いちばん感謝したい人や出来事は？';

  @override
  String get autoT0197 => '画像を読み込めませんでした。しばらくしてからもう一度お試しください。';

  @override
  String get autoT0199 => 'タグのデータはまだありません。タグを付けて日記を書いてみましょう。';

  @override
  String autoT0200(String p0) {
    return '選択した$p0件のアーカイブ済みの日記を削除しますか？';
  }

  @override
  String autoT0201(String p0) {
    return '$p0件の日記のアーカイブを解除しました';
  }

  @override
  String get autoT0203 => 'metadata は有効な JSON オブジェクトである必要があります';

  @override
  String get autoT0204 => 'AMap Web API キーがありません。amap.web.api.key を設定してください';

  @override
  String get autoT0205 => 'QWeather のキーがありません。qweather.api_key を設定してください';

  @override
  String get autoT0206 => '日記はゴミ箱に移動し、あとで復元できます。続けますか？';

  @override
  String get autoT0207 => '保存していない変更があります。終了しますか？';

  @override
  String get autoT0208 => '見出しのスタイル（タップで切り替え）';

  @override
  String autoT0210(String p0) {
    return 'カレンダーの日記を読み込めませんでした：$p0';
  }

  @override
  String get autoT0211 => 'あせらないで。この日のすてきな出来事は、まだこれからです。';

  @override
  String get timeCapsuleTitle => 'タイムカプセル';

  @override
  String get timeCapsuleUnset => '封印なし';

  @override
  String timeCapsuleSet(String p0) {
    return '$p0に開封';
  }

  @override
  String get timeCapsulePickTitle => '開封日時を選択';

  @override
  String get timeCapsulePrecisionMinute => '時刻まで指定';

  @override
  String get timeCapsulePrecisionDate => '日付のみ';

  @override
  String get timeCapsuleQuickWeek => '1週間後';

  @override
  String get timeCapsuleQuickMonth => '1か月後';

  @override
  String get timeCapsuleQuickYear => '1年後';

  @override
  String get timeCapsuleClear => 'タイムカプセルを解除';

  @override
  String get timeCapsuleLockedTitle => '眠っているひととき';

  @override
  String timeCapsuleCountdownDays(String p0) {
    return 'あと$p0日で開封';
  }

  @override
  String timeCapsuleCountdownHours(String p0) {
    return 'あと$p0時間で開封';
  }

  @override
  String timeCapsuleLockedHint(String p0) {
    return 'この日記は$p0まで封印されています。開封日時の変更や削除はできますが、本文は非表示のままです。';
  }

  @override
  String get timeCapsuleUpdateUnlock => '開封日時を変更';

  @override
  String get timeCapsuleSealing => 'このひとときを封印しています…';

  @override
  String timeCapsuleSealDone(String p0) {
    return '$p0まで封印しました';
  }

  @override
  String timeCapsuleUnlockedInsight(String p0) {
    return 'この日記を書いたとき、あなたの気分は $p0 でした。今日はどんな気分ですか？';
  }

  @override
  String get timeCapsuleUnlockedInsightNoMood =>
      '未来の自分に宛てて封印した日記です。今日はどんな気分ですか？';

  @override
  String get webDavServerUrl => 'サーバー URL';

  @override
  String get webDavServerUrlHint => '例：https://nas.example.com:5006/webdav/';

  @override
  String get webDavUsername => 'ユーザー名';

  @override
  String get webDavPassword => 'パスワードまたはトークン';

  @override
  String get webDavRemoteDirectory => 'リモートディレクトリ';

  @override
  String get webDavRemoteDirectoryHint => '例：/jotsy/';

  @override
  String get webDavHint =>
      'NAS に Jotsy 専用のフォルダーを作成し、できるだけアプリ用パスワードやトークンを使ってください。アップロードすると完全な ZIP バックアップが作成されます。復元時は、この端末のデータに統合するか上書きするかを選べます。';

  @override
  String get imageViewerSaveToGallery => 'ギャラリーに保存';

  @override
  String get imageViewerSaving => '保存中…';

  @override
  String get imageViewerSaveSuccess => 'ギャラリーに保存しました';

  @override
  String imageViewerSaveFailed(String error) {
    return '保存できませんでした：$error';
  }

  @override
  String get imageViewerGalleryPermissionDenied =>
      'ギャラリーへのアクセスが許可されていないため、保存できません';

  @override
  String get desktopSaveAs => '名前を付けて保存…';

  @override
  String get desktopSaveImageDialogTitle => '画像を保存';

  @override
  String get desktopSaveVideoDialogTitle => '動画を保存';

  @override
  String desktopSavedTo(String path) {
    return '$path に保存しました';
  }

  @override
  String get diaryShareSaveImages => '画像を保存…';

  @override
  String get diaryShareSaveImagesDialogTitle => '画像の保存先フォルダーを選択';

  @override
  String diaryShareImagesSaved(int count, String path) {
    return '$count枚の画像を $path に保存しました';
  }

  @override
  String get diaryShareLongImageSave => '長い画像として保存…';

  @override
  String get videoOpenExternally => 'システムのプレーヤーで開く';

  @override
  String get videoPosterHint => 'クリックしてシステムのプレーヤーで開く';

  @override
  String get deviceAuthUnavailable =>
      'この端末にはシステムの認証がありません。設定 → アプリロックとパスコード でアプリのパスコードを設定するとロックできます';

  @override
  String get calendarYearSaveImage => 'この1年を画像として保存…';

  @override
  String get imageViewerSharing => '共有の準備中…';

  @override
  String imageViewerShareFailed(String error) {
    return '共有できませんでした：$error';
  }

  @override
  String get imageViewerDownloadFailed =>
      '画像をダウンロードできませんでした。ネットワークを確認して再試行してください';

  @override
  String get imageViewerOpenDiary => '日記を開く';

  @override
  String get imageViewerImageUnreadable => 'この画像を読み込めないため、共有できません';

  @override
  String get imageViewerMoreActions => 'その他の操作';

  @override
  String get imageViewerPrevious => '前の画像';

  @override
  String get imageViewerNext => '次の画像';

  @override
  String get diaryToolbarInsertCurrentTime => '現在時刻を挿入';

  @override
  String get diaryToolbarRecording => '録音';

  @override
  String get recordingStart => '録音を開始';

  @override
  String get recordingPause => '録音を一時停止';

  @override
  String get recordingResume => '録音を再開';

  @override
  String get recordingFinish => '録音を終了';

  @override
  String get recordingClose => '録音を閉じる';

  @override
  String get recordingPaused => '一時停止中';

  @override
  String get recordingPermissionDenied => 'マイクへのアクセスが許可されていません';

  @override
  String get recordingFailed => '録音できませんでした。もう一度お試しください。';

  @override
  String get recordingSaveFailed => '録音を保存できませんでした。もう一度お試しください。';

  @override
  String get recordingAttachment => '録音';

  @override
  String get recordingPlaybackPlay => '録音を再生';

  @override
  String get recordingPlaybackPause => '再生を一時停止';

  @override
  String get recordingPlaybackFailed => '録音を再生できません';

  @override
  String get recordingRename => '録音の名前を変更';

  @override
  String get recordingNameHint => '録音の名前を入力';

  @override
  String get recordingDefaultTitle => 'ボイスメモ';

  @override
  String get recordingStatusRecording => '録音中';

  @override
  String get recordingIdleHint => 'マイクをタップして録音を開始';

  @override
  String get diaryToolbarToolSettingsTooltip => 'ツールの設定';

  @override
  String get diaryToolbarTimeFormatTitle => '時刻の形式を設定';

  @override
  String get diaryToolbarTimeFormatLabel => '時刻の形式';

  @override
  String get diaryToolbarTimeFormatHelp =>
      'デフォルトの形式は M月d日 HH:mm です。yyyy、MM、dd、HH、mm などの DateFormat 記号を使えます（例：yyyy-MM-dd HH:mm）。';

  @override
  String diaryToolbarTimeFormatPreview(String value) {
    return 'プレビュー：$value';
  }

  @override
  String get diaryToolbarTimeFormatInvalid => '時刻の形式が無効です。記号を確認してください。';

  @override
  String get diaryTagCollapse => 'タグを折りたたむ';

  @override
  String get diaryTagCollapseHint => 'ここを上にスワイプするかタップすると、タグを折りたたみます';

  @override
  String diaryTagPullHint(int count) {
    return '下に引くと、タグ$count個をすべて表示';
  }

  @override
  String diaryTagPullHintDesktop(int count) {
    return '下にドラッグするかクリックすると、タグ$count個をすべて表示';
  }

  @override
  String get diaryTagExpand => 'タグを展開';

  @override
  String get diaryPinnedBadge => 'ピン留め';

  @override
  String get diaryEnergyUnrecorded => '未記録';

  @override
  String get diaryEnergySwitchTooltip => 'エネルギーの記録をオン／オフ';

  @override
  String get diaryToolbarInsertVideo => '動画を挿入';

  @override
  String get diaryToolbarInsertAttachment => '添付ファイルを挿入';

  @override
  String get diaryMediaImporting => 'ファイルをインポート中…';

  @override
  String get diaryMediaImportFailed => 'ファイルをインポートできませんでした。もう一度お試しください。';

  @override
  String get diaryMediaImportPermissionDenied =>
      '選択したファイルの読み取りが許可されませんでした。もう一度選択して、アクセスを許可してください。';

  @override
  String get diaryMediaPickerUnavailable =>
      'システムの選択画面を開けませんでした。ギャラリーまたはファイルマネージャーが有効になっているか確認してください。';

  @override
  String get diaryMediaImportUnsupported => 'このプラットフォームではファイルのインポートに対応していません。';

  @override
  String get diaryMediaFromLibrary => 'ギャラリーから選択';

  @override
  String get diaryMediaTakePhoto => '写真を撮る';

  @override
  String get diaryMediaRecordVideo => '動画を撮る';

  @override
  String get diaryMediaCameraPermissionDenied =>
      'カメラへのアクセスがオフになっています。システム設定で Jotsy にカメラの使用を許可してください。';

  @override
  String get diaryMediaCameraUnavailable => 'この端末で使用できるカメラがありません。';

  @override
  String get attachmentOpen => '添付ファイルを開く';

  @override
  String get attachmentOpenHint => 'タップして別のアプリで開く';

  @override
  String get attachmentOpening => '添付ファイルを開いています…';

  @override
  String get attachmentFileMissing => '添付ファイルが見つからないか、アクセスできません。';

  @override
  String get imageLoadFailed => '画像が見つからないか、読み込めません。';

  @override
  String get imageHeifUnsupported => 'このパソコンでは HEIC 形式の写真を表示できません';

  @override
  String get imageHeifUnsupportedHint =>
      'スマートフォンで Jotsy を開くと、この写真が自動的に JPEG に変換されます。もう一度同期すると、ここに表示されます。';

  @override
  String get imageOpenInOtherApp => '別のアプリで開く';

  @override
  String get attachmentNoApp => 'このファイルを開けるアプリがインストールされていません。';

  @override
  String get attachmentPermissionDenied => '添付ファイルにアクセスできませんでした。';

  @override
  String get attachmentOpenFailed => '添付ファイルを開けませんでした。もう一度お試しください。';

  @override
  String get videoLoading => '動画を読み込み中…';

  @override
  String get videoPlay => '動画を再生';

  @override
  String get videoPause => '動画を一時停止';

  @override
  String get videoProgress => '動画の再生位置';

  @override
  String get videoPlaybackFailed => 'ここでは動画を再生できません。タップして別のアプリで開きます。';

  @override
  String get videoExport => '動画をエクスポート';

  @override
  String get videoExportConfirmTitle => '動画をエクスポート';

  @override
  String videoExportConfirmMessage(String name) {
    return '「$name」をギャラリーに保存しますか？';
  }

  @override
  String get videoExporting => '動画をエクスポート中…';

  @override
  String get videoExportSuccess => '動画をギャラリーに保存しました';

  @override
  String get videoExportFileMissing => '動画ファイルが見つからないか、空です。';

  @override
  String get videoExportPermissionDenied =>
      'ギャラリーへのアクセスが許可されていないため、動画をエクスポートできませんでした。';

  @override
  String get videoExportNotEnoughSpace => 'ストレージの空き容量が足りないため、この動画をエクスポートできません。';

  @override
  String get videoExportUnsupportedFormat => 'この動画形式はギャラリーに保存できません。';

  @override
  String get videoExportDownloadFailed => '動画をダウンロードできませんでした。もう一度お試しください。';

  @override
  String get videoExportFailed => '動画をエクスポートできませんでした。もう一度お試しください。';

  @override
  String get videoFullscreen => '全画面再生';

  @override
  String get videoExitFullscreen => '全画面を終了';

  @override
  String get locationPrecisionTitle => '住所の詳しさ';

  @override
  String get locationPrecisionCity => '都市';

  @override
  String get locationPrecisionDistrict => '区・郡';

  @override
  String get locationPrecisionTownship => '町・村';

  @override
  String get locationPrecisionStreet => '通り';

  @override
  String get locationPrecisionAddress => '番地';

  @override
  String get locationUnsupported => 'このプラットフォームでは位置情報の自動取得に対応していません。';

  @override
  String get locationPermissionDenied =>
      '位置情報の権限がありません。位置情報へのアクセスを許可してから再試行してください（おおよその位置情報のみの許可でも使えます）。';

  @override
  String get locationPermissionDeniedForever =>
      '位置情報の権限がブロックされています。システム設定で許可してから、戻って再試行してください。';

  @override
  String get locationServiceDisabled =>
      '位置情報サービスがオフになっています。システム設定でオンにしてから再試行してください。';

  @override
  String get locationNetworkError => '住所の取得に失敗したか、タイムアウトしました。接続を確認して再試行してください。';

  @override
  String get locationApiError => '住所サービスは一時的に利用できません。しばらくしてからもう一度お試しください。';

  @override
  String get locationAddressInvalid =>
      '有効な住所を取得できませんでした。しばらくしてからもう一度お試しいただくか、場所を手動で入力してください。';

  @override
  String get locationUnavailable =>
      '現在地を取得できませんでした。衛星の電波が届きやすい場所でもう一度お試しいただくか、場所を手動で入力してください。';

  @override
  String get diarySortFieldUpdated => '更新日時';

  @override
  String get diarySortFieldPublished => '投稿日時';

  @override
  String get diarySortFieldTitle => 'タイトル';

  @override
  String get diarySortDescending => '降順';

  @override
  String get diarySortAscending => '昇順';

  @override
  String get diarySortHintUpdatedDesc => '更新が新しい順';

  @override
  String get diarySortHintUpdatedAsc => '更新が古い順';

  @override
  String get diarySortHintPublishedDesc => '投稿が新しい順';

  @override
  String get diarySortHintPublishedAsc => '投稿が古い順';

  @override
  String get diarySortHintTitleAsc => 'タイトル A → Z、無題は最後';

  @override
  String get diarySortHintTitleDesc => 'タイトル Z → A、無題は最後';

  @override
  String get diaryToolbarMoreTools => 'その他のツール';

  @override
  String get diaryToolbarHideMoreTools => 'その他のツールを閉じる';

  @override
  String get diaryToolbarMoreToolsActive => '書式が適用されています';

  @override
  String get diaryToolbarOverflowDivider => 'これより下は「その他」に収納';

  @override
  String get backupBusyInspect => 'ファイルを読み込み中...';

  @override
  String get backupImportOptionsTitle => 'インポート方法';

  @override
  String get backupImportKindFull => 'フルバックアップ';

  @override
  String get backupImportKindDiary => '日記ファイル';

  @override
  String backupImportSummary(int diaries, int tags) {
    return '日記$diaries件 · タグ$tags個';
  }

  @override
  String get backupImportIncludesSettings => 'アプリの設定を含む';

  @override
  String backupImportExistingCount(int count) {
    return 'うち$count件はこの端末にすでにあります';
  }

  @override
  String get backupImportModeMerge => '統合（推奨）';

  @override
  String get backupImportModeMergeDescription =>
      'この端末のデータはすべて残し、この端末にない日記だけを追加します。既存の日記はそのままです。';

  @override
  String get backupImportModeOverwriteExisting => '既存の日記を上書き';

  @override
  String backupImportModeOverwriteExistingDescription(int count) {
    return '新しい日記を追加し、この端末にある$count件の日記をファイル内のバージョンで置き換えます';
  }

  @override
  String get backupImportModeReplaceAll => 'すべてのデータを上書き';

  @override
  String get backupImportModeReplaceAllDescription =>
      'この端末の日記、タグ、メディア、設定をすべて消去し、バックアップの内容に置き換えます';

  @override
  String get backupOverwriteAllTitle => 'すべてのデータを上書きしますか？';

  @override
  String get backupOverwriteExistingTitle => '既存の日記を上書きしますか？';

  @override
  String get backupOverwriteIrreversible => 'この操作は元に戻せません';

  @override
  String get backupOverwriteAllLead =>
      'この端末にある次のデータは完全に削除され、バックアップの内容に置き換えられます：';

  @override
  String backupOverwriteAllDiaries(int count) {
    return '日記$count件（アーカイブ済みとゴミ箱内のものを含む）';
  }

  @override
  String backupOverwriteAllTags(int count) {
    return 'タグ$count個';
  }

  @override
  String get backupOverwriteAllMedia => 'すべての画像、録音、動画、添付ファイル';

  @override
  String get backupOverwriteAllSettings => 'アプリの設定と未投稿の下書き';

  @override
  String backupOverwriteExistingBody(int count) {
    return 'この端末にある$count件の日記は、ファイル内のバージョンで丸ごと置き換えられます。この端末での編集内容とタグは完全に失われます。その他の日記には影響しません。';
  }

  @override
  String get backupOverwriteBackupTip =>
      '現在のデータを残したい場合は、いったんキャンセルして先にバックアップをエクスポートしてください。';

  @override
  String get backupOverwriteAcknowledge => '上書きされたデータは復元できないことを理解しました';

  @override
  String get backupOverwriteConfirm => '上書き';

  @override
  String backupOverwriteConfirmCountdown(int seconds) {
    return '上書き（$seconds）';
  }

  @override
  String backupImportMergeResult(int added) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: 'インポート完了：日記を$added件追加しました',
      zero: 'インポート完了：新しい日記はありません',
    );
    return '$_temp0';
  }

  @override
  String backupImportMergeSkippedResult(int added, int skipped) {
    return 'インポート完了：$added件を追加、この端末にすでにある$skipped件をスキップしました';
  }

  @override
  String backupImportOverwriteResult(int added, int replaced) {
    return 'インポート完了：$added件を追加、$replaced件を上書きしました';
  }

  @override
  String get previewExportDiaryFileConfirm => 'エクスポート';

  @override
  String get previewExportDiaryFileSuccess =>
      '日記ファイルをエクスポートしました。「データ管理」からインポートできます。';

  @override
  String get dataMgmtImportJournal => '他の日記アプリからインポート';

  @override
  String get dataMgmtImportJournalSubtitle =>
      'Day One、Evernote、Google Keep、Obsidian、Xiaomi Notes など18種類に対応';

  @override
  String get journalImportSourceTitle => 'どのアプリからインポートしますか？';

  @override
  String get journalImportSourceHint =>
      'まず元のアプリでデータをエクスポートしてから、ここでそのファイルを選択してください。';

  @override
  String get journalImportAppleJournal => 'ジャーナル（Apple）';

  @override
  String get journalImportDayOneHint => 'JSON 形式でエクスポート（.zip）';

  @override
  String get journalImportJourneyHint => 'ZIP 形式でエクスポート（.zip）';

  @override
  String get journalImportDiariumHint =>
      'JSON エクスポート（.json）またはバックアップファイル（.diary）';

  @override
  String get journalImportDaylioHint =>
      'バックアップファイル（.daylio）またはエクスポートした CSV（.csv）';

  @override
  String get journalImportAppleJournalHint =>
      'iPhone の「設定 › アプリ › ジャーナル」からすべての項目を書き出す（.zip）';

  @override
  String journalImportPickDialogTitle(String app) {
    return '$app のエクスポートファイルを選択';
  }

  @override
  String journalImportUnrecognized(String app) {
    return 'このファイルは $app のエクスポートとして認識できません';
  }

  @override
  String get journalImportNoEntries => 'このファイルにはインポートできる日記がありません';

  @override
  String get journalImportGroupJournals => '日記アプリ';

  @override
  String get journalImportGroupNotes => 'メモアプリ';

  @override
  String get journalImportGroupPhoneNotes => 'スマホと WPS のクラウドメモ';

  @override
  String get journalImportPhoneNotesHint =>
      'アプリ内で公式クラウドサービスにログインし、メモ、フォルダ、添付画像を直接読み込みます。ログイン状態は今回のインポートにのみ使われ、終了後に消去されます。';

  @override
  String get journalImportDiaroHint => 'バックアップファイル（.zip、暗号化なし）';

  @override
  String get journalImportDurianDiary => 'Durian Diary';

  @override
  String get journalImportDurianDiaryHint =>
      '「インポートとエクスポート」で書き出したアーカイブ（.lld）、または .zip に圧縮したバックアップフォルダ';

  @override
  String get journalImportEvernote => 'Evernote';

  @override
  String get journalImportEvernoteHint =>
      'ノートブックを ENEX 形式でエクスポート（.enex、複数ある場合は .zip にまとめる）';

  @override
  String get journalImportGoogleKeepHint =>
      'Google Takeout で Keep をエクスポート（.zip）';

  @override
  String get journalImportJoplinHint => 'JEX 形式でエクスポート（.jex）';

  @override
  String get journalImportMemosHint =>
      'v0.31 以降の「設定 › エクスポートとインポート」から書き出す（.zip）';

  @override
  String get journalImportMarkdown => 'Markdown / プレーンテキスト';

  @override
  String get journalImportMarkdownHint =>
      'Obsidian、Bear、Notion などから書き出した .md / .txt ファイル、またはそれらをまとめた .zip';

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
    return '$app の暗号化されたバックアップはインポートできません。$app で暗号化なしのバックアップを作成してください';
  }

  @override
  String cloudLoginTitle(String app) {
    return '$app にログイン';
  }

  @override
  String get cloudLoginHint =>
      '上の公式ページでログインしてメモの画面を開き、「メモを読み込む」をタップしてください。ログイン状態は今回のインポートにのみ使われ、終了後に消去されます。';

  @override
  String get cloudLoginRead => 'メモを読み込む';

  @override
  String get cloudLoginReload => 'ページを再読み込み';

  @override
  String get cloudLoginChecking => 'ログイン状態を確認中';

  @override
  String get cloudLoginNotSignedIn => 'まだログインしていません。先にページでログインを完了してください';

  @override
  String cloudBusyReading(int count) {
    return 'クラウドのメモを読み込み中（$count件）';
  }

  @override
  String cloudBusyProgress(int done, int total) {
    return 'クラウドのメモを読み込み中（$done/$total）';
  }

  @override
  String get cloudErrorSession => 'ログインの有効期限が切れたか、追加の認証が必要です。もう一度ログインしてください';

  @override
  String get cloudErrorForbidden =>
      'サービスへのアクセスが拒否されました（HTTP 403）。アカウントの権限や公式サイトの案内を確認してください';

  @override
  String get cloudErrorRateLimited => 'リクエストが多すぎます。しばらくしてからもう一度お試しください';

  @override
  String get cloudErrorServer => 'サービスが一時的に利用できません。しばらくしてからもう一度お試しください';

  @override
  String get cloudErrorRejected =>
      'サービスがリクエストを拒否しました。アカウントの権限を確認して、もう一度お試しください';

  @override
  String get cloudErrorNetwork => 'ネットワークリクエストに失敗しました。接続を確認して、もう一度お試しください';

  @override
  String cloudErrorProtocol(String app) {
    return '$app から認識できない形式のデータが返されました。メモの取りこぼしを防ぐため、読み込みを中止しました';
  }

  @override
  String cloudErrorUnsupportedAccount(String app) {
    return 'この $app アカウントのメモは暗号化されているか、まだ読み込みに対応していません';
  }

  @override
  String backupImportKindJournal(String app) {
    return '$app のエクスポート';
  }

  @override
  String backupImportMissingMedia(int count) {
    return 'メディアファイル$count個がエクスポートに含まれていないため、スキップします';
  }

  @override
  String backupImportSkippedEncrypted(int count) {
    return '暗号化またはロックされたメモ$count件は読み込めないため、スキップします';
  }

  @override
  String backupImportSkippedUnsupported(int count) {
    return '手書きメモやマインドマップなど特殊な形式のメモ$count件はスキップします';
  }

  @override
  String backupImportSkippedUnreadable(int count) {
    return '形式を認識できないメモ$count件はスキップします';
  }

  @override
  String backupImportSummaryOnly(int count) {
    return 'メモ$count件の本文を読み込めなかったため、概要のみインポートします';
  }

  @override
  String backupImportPartialContent(int count) {
    return 'メモ$count件に復号・表示できない部分があります。読める本文と元のデータは保持されます';
  }

  @override
  String get calendarDisplayOptionsTooltip => 'カレンダーの表示';

  @override
  String get calendarOptionsTitle => 'カレンダーの表示';

  @override
  String get calendarOptionsReset => 'リセット';

  @override
  String get calendarOptionsCellStyle => '日付セル';

  @override
  String get calendarCellStyleDot => 'ドット';

  @override
  String get calendarCellStyleMood => '気分';

  @override
  String get calendarCellStyleHeat => 'ヒートマップ';

  @override
  String get calendarCellStylePhoto => '写真';

  @override
  String get calendarCellStyleTags => 'タグの色';

  @override
  String get calendarCellStyleDotDescription => '日記1件ごとにドットを1つ表示します（最大3つ）。';

  @override
  String get calendarCellStyleMoodDescription => 'その日に記録した気分の絵文字。';

  @override
  String get calendarCellStyleHeatDescription => 'たくさん書いた日ほど色が濃くなります。';

  @override
  String get calendarCellStylePhotoDescription => '表紙、または本文の最初の写真がセル全体に表示されます。';

  @override
  String get calendarCellStyleTagsDescription => 'その日に使ったタグの色（最大3つ）。';

  @override
  String get calendarMoodAverage => '平均';

  @override
  String get calendarMoodEach => '日記ごと';

  @override
  String get calendarHeatBasisEntries => '件数';

  @override
  String get calendarHeatBasisWords => '文字数';

  @override
  String get calendarOptionsBadges => 'バッジ';

  @override
  String get calendarBadgeCount => '件数';

  @override
  String get calendarBadgeCapsule => '未開封のタイムカプセル';

  @override
  String get calendarBadgeWeather => '天気';

  @override
  String get calendarOptionsLayout => 'レイアウト';

  @override
  String get calendarOptionsWeekStart => '週の始まり';

  @override
  String get calendarWeekStartLocale => '言語に合わせる';

  @override
  String get calendarWeekStartMonday => '月曜日';

  @override
  String get calendarWeekStartSunday => '日曜日';

  @override
  String get calendarOptionsDefaultFormat => '開いたときの表示';

  @override
  String get calendarFormatMonth => '月';

  @override
  String get calendarFormatWeek => '週';

  @override
  String get calendarFormatRemember => '前回の表示';

  @override
  String get calendarHighlightWeekends => '週末を色分け';

  @override
  String get calendarShowWeekNumbers => '週番号を表示';

  @override
  String get calendarFixedSixWeeks => '常に6週分を表示';

  @override
  String get calendarFixedSixWeeksDescription => '月を切り替えてもカレンダーの高さが変わりません。';

  @override
  String get calendarOptionsSections => 'セクション';

  @override
  String get calendarShowMonthSummary => '月間サマリー';

  @override
  String get calendarShowMonthSummaryDescription =>
      'その月の件数、記録した日数、文字数、最も多い気分、最長の連続記録。';

  @override
  String calendarSummaryEntries(int count) {
    return '日記$count件';
  }

  @override
  String calendarSummaryDays(int recorded, int elapsed) {
    return '$elapsed日中$recorded日記録';
  }

  @override
  String calendarSummaryDaysNoTotal(int count) {
    return '$count日記録';
  }

  @override
  String calendarSummaryWords(String count) {
    return '$count文字';
  }

  @override
  String calendarSummaryMood(String mood) {
    return '最も多い気分：$mood';
  }

  @override
  String calendarSummaryStreak(int count) {
    return '最長連続記録：$count日';
  }

  @override
  String get calendarSummaryEmpty => 'この月はまだ日記がありません';

  @override
  String get calendarSummaryFuture => 'この月はまだ始まっていません';

  @override
  String get calendarRelativeToday => '今日';

  @override
  String get calendarRelativeYesterday => '昨日';

  @override
  String get calendarRelativeTomorrow => '明日';

  @override
  String calendarRelativeDaysAgo(int count) {
    return '$count日前';
  }

  @override
  String calendarRelativeDaysLater(int count) {
    return '$count日後';
  }

  @override
  String calendarDayStats(int entries, String words) {
    return '$entries件 · $words文字';
  }

  @override
  String get calendarYearViewTooltip => '1年分を表示';

  @override
  String get calendarYearBasisMood => '気分';

  @override
  String get calendarYearBasisEntries => '件数';

  @override
  String get calendarYearBasisWords => '文字数';

  @override
  String get calendarYearLegendLess => '少';

  @override
  String get calendarYearLegendMore => '多';

  @override
  String get calendarYearLegendNoMood => '気分なし';

  @override
  String get calendarYearExport => 'この1年を共有';

  @override
  String get calendarYearExportFailed => '画像を作成できませんでした。もう一度お試しください。';

  @override
  String get calendarOnThisDayTitle => '過去の今日';

  @override
  String calendarOnThisDayYearsAgo(int count) {
    return '$count年前';
  }

  @override
  String calendarOnThisDayYearsLater(int count) {
    return '$count年後';
  }

  @override
  String get calendarDayActionView => 'この日を表示';

  @override
  String get calendarDayActionWrite => 'この日の日記を書く';

  @override
  String get calendarDayActionCapsule => 'タイムカプセルを書く';

  @override
  String get calendarDayActionCapsuleDescription => 'この日になるまで開けません';

  @override
  String get calendarFutureCapsuleAction => 'この日に開くタイムカプセルを書く';

  @override
  String get calendarOptionsDayContent => 'その日の日記';

  @override
  String get calendarDayContentTimeline => 'タイムライン';

  @override
  String get calendarDayContentCards => 'カード';

  @override
  String get calendarShowOnThisDay => '過去の今日';

  @override
  String get calendarShowOnThisDayDescription => 'ほかの年の同じ日付に書いた日記。';

  @override
  String get calendarPreviousYear => '前の年';

  @override
  String get calendarNextYear => '次の年';

  @override
  String get calendarOptionsLunar => '旧暦と二十四節気';

  @override
  String get calendarOptionsLunarDescription =>
      '各日付の下に中国の旧暦、二十四節気、伝統的な祝祭日を表示します。';

  @override
  String get calendarLunarLocale => '言語に合わせる';

  @override
  String get calendarLunarAlways => '表示';

  @override
  String get calendarLunarNever => '非表示';

  @override
  String calendarLunarDate(String date) {
    return '旧暦$date';
  }

  @override
  String get calendarSummaryEmptyYear => 'この年はまだ日記がありません';

  @override
  String get calendarSummaryFutureYear => 'この年はまだ始まっていません';

  @override
  String get calendarSummaryEmptyRange => 'この期間には日記がありません';

  @override
  String get calendarSummaryFutureRange => 'この期間はまだ始まっていません';

  @override
  String get calendarDayActionRange => 'ここから範囲を選択';

  @override
  String get calendarDayActionRangeDescription => '別の日付をタップすると、その間の統計を表示します';

  @override
  String calendarRangeTitle(String start, String end, int days) {
    return '$start – $end · $days日間';
  }

  @override
  String calendarRangePickEnd(String start) {
    return '$startから · 終了日をタップ';
  }

  @override
  String get calendarRangeExit => '範囲選択を終了';

  @override
  String get calendarFilterTooltip => '絞り込み';

  @override
  String get calendarFilterTitle => 'カレンダーを絞り込み';

  @override
  String get calendarFilterNotebooks => '日記帳';

  @override
  String get calendarFilterClear => '絞り込みを解除';

  @override
  String get calendarFilterDescription =>
      '日付セルと統計には、条件に合う日記だけが含まれます。同じグループ内はいずれか1つに合えばよく、複数のグループを指定した場合はすべてに合う必要があります。';

  @override
  String get calendarFilterMoods => '気分';

  @override
  String get calendarFilterTags => 'タグ';

  @override
  String get calendarFilterNoTags => 'タグはまだありません';

  @override
  String get calendarFilterActive => '絞り込み中';

  @override
  String get calendarOptionsAlmanac => '旧暦と祝日';

  @override
  String get calendarOptionsHolidays => '中国の祝日';

  @override
  String calendarOptionsHolidaysDescription(int year) {
    return '中国本土の休日（休）と振替出勤日（出）を日付の横に表示し、週末の色分けもそれに合わせます。$year年までのデータを収録しています。';
  }

  @override
  String get calendarOptionsHolidaysDescriptionOutdated =>
      '中国本土の休日（休）と振替出勤日（出）を日付の横に表示し、週末の色分けもそれに合わせます。このバージョンには今年の休日データがまだ含まれていません。';

  @override
  String get calendarHolidayRestMark => '休';

  @override
  String get calendarHolidayWorkMark => '出';

  @override
  String get calendarHolidayDayOff => '休日';

  @override
  String get calendarHolidayMakeUpWorkday => '振替出勤日';

  @override
  String backupImportAnniversaryCount(int count) {
    return '記念日$count件';
  }

  @override
  String backupImportExistingAnniversaryCount(int count) {
    return 'うち記念日$count件はこの端末にすでにあります';
  }

  @override
  String backupImportModeOverwriteAnniversariesOnly(int count) {
    return '新しい項目を追加し、この端末にある記念日$count件をファイル内のバージョンで置き換えます';
  }

  @override
  String backupImportModeOverwriteAnniversariesExtra(int count) {
    return 'この端末にある記念日$count件も置き換えます';
  }

  @override
  String backupOverwriteAllAnniversaries(int count) {
    return '記念日$count件';
  }

  @override
  String backupOverwriteExistingAnniversariesBody(int count) {
    return 'この端末にある記念日$count件はファイル内のバージョンで置き換えられ、この端末での編集内容は完全に失われます。';
  }

  @override
  String backupImportAnniversaryMergeResult(int added) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '記念日：$added件を追加',
      zero: '記念日：追加なし',
    );
    return '$_temp0';
  }

  @override
  String backupImportAnniversaryMergeSkippedResult(int added, int skipped) {
    return '記念日：$added件を追加、この端末にすでにある$skipped件をスキップ';
  }

  @override
  String backupImportAnniversaryOverwriteResult(int added, int replaced) {
    return '記念日：$added件を追加、$replaced件を上書き';
  }

  @override
  String get calendarShowAnniversaries => '記念日';

  @override
  String get calendarShowAnniversariesDescription =>
      '日付に記念日の印を付け、選択した日の記念日カードを表示します。';

  @override
  String get calendarDayActionAnniversary => '記念日を追加';

  @override
  String get calendarDayActionAnniversaryDescription =>
      'この日を記録して、毎年カレンダーに表示します';

  @override
  String get calendarDayActionCountdownDescription => 'この日までカウントダウン';

  @override
  String get anniversarySectionTitle => '記念日';

  @override
  String anniversaryOrdinal(int count) {
    return '$count周年';
  }

  @override
  String anniversaryTodayOrdinal(int count) {
    return '今日で$count周年';
  }

  @override
  String anniversaryDaysLeft(int count) {
    return 'あと$count日';
  }

  @override
  String anniversaryDaysSince(int count) {
    return '$count日経過';
  }

  @override
  String get anniversaryBaseDay => '始まりの日';

  @override
  String get anniversaryCountdownLabel => 'カウントダウン';

  @override
  String get anniversaryIsToday => '今日がその日';

  @override
  String get anniversaryAdjustedNote => '今年はこの日付がないため、近い日に移動しています';

  @override
  String get anniversaryNewTitle => '新しい記念日';

  @override
  String get anniversaryEditTitle => '記念日を編集';

  @override
  String get anniversaryFieldName => '名前';

  @override
  String get anniversaryNameHint => '例：付き合った日、母の誕生日、試験日';

  @override
  String get anniversaryNameRequired => '名前を入力してください';

  @override
  String get anniversaryFieldDate => '日付';

  @override
  String get anniversaryFieldRepeat => '繰り返し';

  @override
  String get anniversaryRepeatSolar => '毎年';

  @override
  String get anniversaryRepeatLunar => '毎年（旧暦）';

  @override
  String get anniversaryRepeatOnce => '繰り返さない';

  @override
  String anniversaryRepeatSolarDescription(String date) {
    return '毎年$dateに表示します';
  }

  @override
  String get anniversaryRepeatLeapDayDescription => '毎年2月29日。平年は2月28日になります';

  @override
  String anniversaryRepeatLunarDescription(String date) {
    return '毎年旧暦$date。その年の日付に換算します';
  }

  @override
  String get anniversaryRepeatOnceDescription =>
      'この日だけ：それまではカウントダウン、過ぎたら経過日数を表示します';

  @override
  String anniversaryLunarYearDate(String year, String date) {
    return '旧暦$year年$date';
  }

  @override
  String get anniversaryFieldNote => 'メモ';

  @override
  String get anniversaryNoteHint => '任意';

  @override
  String get anniversaryPin => 'ピン留め';

  @override
  String get anniversaryPinDescription => '記念日リストの一番上に表示します';

  @override
  String get anniversaryDelete => '記念日を削除';

  @override
  String get anniversaryDeleteConfirmTitle => 'この記念日を削除しますか？';

  @override
  String anniversaryDeleteConfirmBody(String title) {
    return '「$title」はカレンダーから削除されます。関連付けた日記には影響しません。';
  }

  @override
  String get anniversaryDeleted => '記念日を削除しました';

  @override
  String get anniversaryCreated => '記念日を追加しました';

  @override
  String get anniversarySaveFailed => '保存できませんでした。もう一度お試しください。';

  @override
  String get anniversaryListTitle => '記念日';

  @override
  String get anniversaryEmpty =>
      '記念日はまだありません。カレンダーの日付を長押しするか、「+」をタップして追加してください。';

  @override
  String get anniversaryPinnedBadge => 'ピン留め';

  @override
  String anniversaryDaysToGo(int count) {
    return '日後';
  }

  @override
  String anniversaryDaysAgo(int count) {
    return '日前';
  }

  @override
  String get anniversaryDetailNext => '次回';

  @override
  String get anniversaryDetailStart => '開始日';

  @override
  String get anniversaryMoreActions => 'その他の操作';

  @override
  String get anniversaryUnpin => 'ピン留めを解除';

  @override
  String get anniversaryFieldLink => '関連日記';

  @override
  String get anniversaryLinkNone => 'なし';

  @override
  String get anniversaryLinkPick => '日記を関連付け';

  @override
  String get anniversaryLinkMissing => '関連付けた日記は削除されました';

  @override
  String get anniversaryUnlink => '関連付けを解除';

  @override
  String get anniversaryLinkedDiaryTitle => '関連日記';

  @override
  String get anniversaryOpenLinkedDiary => '関連日記を開く';

  @override
  String get anniversaryPickerHint => '選択した日付の前後7日間に書いた日記';

  @override
  String get anniversaryPickerEmpty => 'この日の前後1週間に日記はありません';

  @override
  String get anniversaryPastDiariesTitle => '毎年のこの日';

  @override
  String get anniversaryBaseDayDiariesTitle => 'この日の日記';

  @override
  String get anniversaryPastDiariesEmpty => 'これらの日にはまだ日記がありません';

  @override
  String get anniversaryView => '表示';

  @override
  String get previewSetAsAnniversary => '記念日にする';

  @override
  String get diaryTypographyTitle => '本文のフォントとレイアウト';

  @override
  String diaryTypographySummary(String font, String size, String lineHeight) {
    return '$font · サイズ$size · 行間$lineHeight';
  }

  @override
  String get diaryTypographyQuickTooltip => 'フォントとレイアウト';

  @override
  String get diaryTypographyFontSection => 'フォント';

  @override
  String get diaryTypographyFontBundled => 'HarmonyOS Sans';

  @override
  String get diaryTypographyFontSystem => 'システムフォント';

  @override
  String get diaryTypographyFontSystemHint => '端末で使用中のフォントに合わせます';

  @override
  String get diaryTypographyFontMissing =>
      '選択したフォントのファイルがこの端末に見つからないため、本文は一時的に HarmonyOS Sans で表示しています。もう一度インポートするか、別のフォントを選んでください。';

  @override
  String get diaryTypographyImportFont => 'フォントファイルをインポート';

  @override
  String get diaryTypographyImportFontHint =>
      'TTF、OTF、TTC 形式に対応。インポートすると本文フォントに設定されます';

  @override
  String get diaryTypographyApplyToApp => 'アプリ全体に使う';

  @override
  String get diaryTypographyApplyToAppHint => 'オフのときは日記のタイトル・本文・日記カードにだけ使われます';

  @override
  String get diaryTypographyImporting => 'フォントをインポート中…';

  @override
  String diaryTypographyImported(String name) {
    return '「$name」をインポートして適用しました';
  }

  @override
  String get diaryTypographyImportUnsupported =>
      '使用できるフォントファイルではありません。TTF、OTF、TTC 形式のファイルを選択してください。';

  @override
  String get diaryTypographyImportUnreadable => '選択したファイルを読み込めませんでした';

  @override
  String get diaryTypographyImportFailed =>
      'フォントをインポートできませんでした。空き容量を確認して、もう一度お試しください。';

  @override
  String get diaryTypographyDeleteFont => 'フォントを削除';

  @override
  String diaryTypographyDeleteFontTitle(String name) {
    return '「$name」を削除しますか？';
  }

  @override
  String get diaryTypographyDeleteFontMessage =>
      'フォントファイルがこの端末から削除されます。使用中の場合、本文は HarmonyOS Sans に戻ります。';

  @override
  String get diaryTypographyLayoutSection => 'レイアウト';

  @override
  String get diaryTypographyFontSize => '文字サイズ';

  @override
  String get diaryTypographyLineHeight => '行間';

  @override
  String get diaryTypographyLetterSpacing => '文字間隔';

  @override
  String get diaryTypographyParagraphSpacing => '段落の間隔';

  @override
  String get diaryTypographyFirstLineIndent => '字下げ';

  @override
  String diaryTypographyFirstLineIndentValue(num count, String value) {
    return '$value文字';
  }

  @override
  String get diaryTypographyFirstLineIndentOff => 'なし';

  @override
  String diaryTypographyDecrease(String label) {
    return '$labelを小さくする';
  }

  @override
  String diaryTypographyIncrease(String label) {
    return '$labelを大きくする';
  }

  @override
  String get diaryTypographyReset => 'レイアウトをリセット';

  @override
  String get diaryTypographyScopeHint => '文字サイズや行間などは日記の作成・閲覧・投稿画面に適用されます。';

  @override
  String get diaryTypographyMoreSettings => 'その他の設定';

  @override
  String get diaryTypographySampleTitle => '雨上がりの夕暮れ';

  @override
  String get diaryTypographySampleBody =>
      '夕方には雨がやみ、マンションの下の金木犀がいつにも増して香っていた。\n帰り道に甘栗をひと袋買って、歩きながらむいた。手のひらはずっと温かかった。\n今日は特別なことは何もなかったけれど、どの瞬間も穏やかで、書き留めておきたくなった。';

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
    return '$timeに更新';
  }

  @override
  String diaryCardFooterCreated(String time) {
    return '$timeに作成';
  }

  @override
  String diaryCardWordCount(String count) {
    return '$count文字';
  }

  @override
  String diaryCardMediaImages(int count) {
    return '写真$count枚';
  }

  @override
  String get diaryCardMediaAudio => '録音あり';

  @override
  String get diaryCardMediaVideo => '動画あり';

  @override
  String get diaryCardMediaAttachment => '添付ファイルあり';

  @override
  String diaryCardLocation(String location) {
    return '場所：$location';
  }

  @override
  String get diaryCardStyleTitle => '日記カードのスタイル';

  @override
  String diaryCardStyleEntrySubtitle(String name) {
    return '現在：$name';
  }

  @override
  String get styleEditorCustom => 'カスタム';

  @override
  String get styleEditorResetDone => 'デフォルトのスタイルに戻しました';

  @override
  String get styleEditorPreviewLight => 'ライトでプレビュー';

  @override
  String get styleEditorPreviewDark => 'ダークでプレビュー';

  @override
  String get styleEditorPanelHandle => 'オプションパネル';

  @override
  String get styleEditorPanelCollapsed => '折りたたみ済み';

  @override
  String get styleEditorPanelHalf => '半分展開';

  @override
  String get styleEditorPanelExpanded => '展開済み';

  @override
  String get diaryCardStyleSharedGroup => 'すべてのレイアウト';

  @override
  String get diaryCardStyleListGroup => 'リストレイアウトのみ';

  @override
  String get diaryCardStyleWaterfallGroup => 'タイルレイアウトのみ';

  @override
  String get diaryCardStyleModeFootnote =>
      'プレビュー上部でリストとウォーターフォールを切り替えると、もう一方のレイアウトを調整できます';

  @override
  String get diaryCardStyleTabPresets => 'プリセット';

  @override
  String get diaryCardStyleTabLayout => 'レイアウト';

  @override
  String get diaryCardStyleTabCover => '表紙';

  @override
  String get diaryCardStyleTabContent => '内容';

  @override
  String get diaryCardStyleTabDate => '日付';

  @override
  String get diaryCardStyleTabOrder => '順序';

  @override
  String get diaryCardStyleTabText => 'テキスト';

  @override
  String get diaryCardStyleTabColor => '色';

  @override
  String get diaryCardStyleTabTexture => '質感';

  @override
  String get styleEditorPresetsTitle => '組み込みスタイル';

  @override
  String get diaryCardStylePresetClassic => 'クラシック';

  @override
  String get diaryCardStylePresetClassicDesc => 'デフォルト：左に正方形の表紙、2行の抜粋';

  @override
  String get diaryCardStylePresetCompact => 'コンパクト';

  @override
  String get diaryCardStylePresetCompactDesc => '小さな表紙と1行の抜粋で、1画面により多く表示';

  @override
  String get diaryCardStylePresetMagazine => 'マガジン';

  @override
  String get diaryCardStylePresetMagazineDesc => '全幅の写真、大きなタイトル、ゆったりした行間';

  @override
  String get diaryCardStylePresetMinimal => 'ミニマル';

  @override
  String get diaryCardStylePresetMinimalDesc => '文字だけ：表紙、枠線、影なし';

  @override
  String get diaryCardStylePresetGallery => 'ギャラリー';

  @override
  String get diaryCardStylePresetGalleryDesc => '写真優先：複数写真のコラージュと表紙の背景';

  @override
  String get diaryCardStylePresetSticky => '付箋';

  @override
  String get diaryCardStylePresetStickyDesc => '温かみのある黄色い紙、上部のカラーバー、小さな角丸';

  @override
  String get diaryCardStylePresetJournal => '手帳';

  @override
  String get diaryCardStylePresetJournalDesc => 'サイドのカラーバー。表紙がないときは日付ブロックを表示';

  @override
  String get diaryCardStylePresetMood => '気分カラー';

  @override
  String get diaryCardStylePresetMoodDesc => 'カードの色と枠線が各日記の気分に合わせて変わります';

  @override
  String get diaryCardStylePresetGlass => 'ガラス';

  @override
  String get diaryCardStylePresetGlassDesc => 'ページの背景が透けて見える、すりガラスのカード';

  @override
  String get diaryCardStyleMaterial => 'マテリアル';

  @override
  String get diaryCardStyleMaterialSolid => '不透明';

  @override
  String get diaryCardStyleMaterialGlass => 'ガラス';

  @override
  String get diaryCardStyleBlur => 'ぼかし';

  @override
  String get diaryCardStyleBlurSubtitle => 'ぼかしは、ページに背景画像があるときだけ表示されます';

  @override
  String styleEditorApplied(String name) {
    return '「$name」を適用しました';
  }

  @override
  String get styleEditorSavedTitle => 'マイスタイル';

  @override
  String get styleEditorSavedEmpty => '気に入ったスタイルを保存すると、いつでもワンタップで切り替えられます';

  @override
  String get styleEditorSaveCurrent => '現在のスタイルを保存';

  @override
  String styleEditorSaveLimit(int count) {
    return '保存できるスタイルは最大$count個です';
  }

  @override
  String get styleEditorSaveDialogTitle => 'スタイルを保存';

  @override
  String get styleEditorRenameDialogTitle => 'スタイル名を変更';

  @override
  String get styleEditorNameLabel => 'スタイル名';

  @override
  String styleEditorDefaultName(int count) {
    return 'マイスタイル $count';
  }

  @override
  String get styleEditorRename => '名前を変更';

  @override
  String styleEditorSavedDone(String name) {
    return '「$name」を保存しました';
  }

  @override
  String styleEditorDeletedDone(String name) {
    return '「$name」を削除しました';
  }

  @override
  String styleEditorSavedActions(String name) {
    return '「$name」のその他の操作';
  }

  @override
  String get styleEditorShareTitle => '共有とインポート';

  @override
  String get styleEditorCopyCode => 'スタイルコードをコピー';

  @override
  String get styleEditorCopyCodeSubtitle => '友達に送ったり、このスタイルのバックアップとして残したりできます';

  @override
  String get styleEditorImportCode => 'クリップボードからインポート';

  @override
  String get styleEditorImportCodeSubtitle => '共有されたスタイルコードを適用します';

  @override
  String get styleEditorCodeCopied => 'スタイルコードをコピーしました';

  @override
  String get styleEditorImportEmpty => 'クリップボードが空です';

  @override
  String get styleEditorImportInvalid => 'クリップボードに有効なスタイルコードがありません';

  @override
  String get styleEditorImportNewer => 'インポートしました。新しいバージョンの設定の一部は反映されない場合があります';

  @override
  String get styleEditorImported => 'スタイルをインポートしました';

  @override
  String styleEditorImportedNamed(String name) {
    return '「$name」をインポートしました';
  }

  @override
  String get diaryCardStyleCornerRadius => 'カードの角丸';

  @override
  String get diaryCardStyleTextAlign => '文字の配置';

  @override
  String get diaryCardStyleAlignStart => '左揃え';

  @override
  String get diaryCardStyleAlignCenter => '中央揃え';

  @override
  String get diaryCardStylePaddingH => '左右の余白';

  @override
  String get diaryCardStylePaddingV => '上下の余白';

  @override
  String get diaryCardStyleElementGap => '要素の間隔';

  @override
  String get diaryCardStyleCardGap => 'カードの間隔';

  @override
  String get diaryCardStyleSideMargin => '画面端の余白';

  @override
  String get diaryCardStyleColumns => '列数';

  @override
  String diaryCardStyleColumnsValue(int count) {
    return '$count列';
  }

  @override
  String get diaryCardStyleColumnsFootnote =>
      '画面が狭いときや文字サイズが大きいときは、列数が自動的に減ります';

  @override
  String get diaryCardStyleCoverPosition => '表紙の位置';

  @override
  String get diaryCardStyleCoverStart => '左';

  @override
  String get diaryCardStyleCoverEnd => '右';

  @override
  String get diaryCardStyleCoverTop => '上';

  @override
  String get diaryCardStyleCoverBackground => '背景';

  @override
  String get diaryCardStyleCoverHidden => '非表示';

  @override
  String get diaryCardStyleCoverSize => '表紙のサイズ';

  @override
  String get diaryCardStyleCoverSizeFootnote =>
      '画面が狭いときは、文字のスペースを確保するため表紙が自動的に小さくなります';

  @override
  String get diaryCardStyleCoverShape => '表紙の形';

  @override
  String get diaryCardStyleShapeSquare => '正方形';

  @override
  String get diaryCardStyleShapeLandscape => '横長';

  @override
  String get diaryCardStyleShapePortrait => '縦長';

  @override
  String get diaryCardStyleShapeCircle => '円形';

  @override
  String get diaryCardStyleCoverRadius => '表紙の角丸';

  @override
  String get diaryCardStyleCoverHeight => '表紙の高さ';

  @override
  String get diaryCardStyleCoverInset => '表紙を内側に配置';

  @override
  String get diaryCardStyleCoverInsetSubtitle => '端まで広げず、余白と角丸を付けて表示します';

  @override
  String get diaryCardStyleCoverDivider => '表紙の下に区切り線';

  @override
  String get diaryCardStyleCoverGap => '表紙と本文の間隔';

  @override
  String get diaryCardStyleScrim => 'テキスト下地の濃さ';

  @override
  String get diaryCardStyleCollage => '写真のコラージュ';

  @override
  String get diaryCardStyleCollageSubtitle => '上部の表紙に本文の写真を最大3枚まで並べます';

  @override
  String get diaryCardStyleCoverFallback => '表紙がないとき';

  @override
  String get diaryCardStyleFallbackNone => '空白';

  @override
  String get diaryCardStyleFallbackDate => '日付ブロック';

  @override
  String get diaryCardStyleFallbackMood => '気分タイル';

  @override
  String get diaryCardStyleShowTitle => 'タイトルを表示';

  @override
  String get diaryCardStyleShowUntitled => 'タイトルがないときは本文の1行目をタイトルにする';

  @override
  String get diaryCardStyleShowUntitledSubtitle => 'オフにするとタイトル行を省略します';

  @override
  String get diaryCardStyleShowPreview => '抜粋を表示';

  @override
  String get diaryCardStyleTitleLines => 'タイトルの最大行数';

  @override
  String get diaryCardStylePreviewLines => '抜粋の最大行数';

  @override
  String diaryCardStyleLinesValue(int count) {
    return '$count行';
  }

  @override
  String get diaryCardStyleTagStyle => 'タグのスタイル';

  @override
  String get diaryCardStyleTagChip => 'チップ';

  @override
  String get diaryCardStyleTagPlain => 'テキスト';

  @override
  String get diaryCardStyleTagDot => 'ドット';

  @override
  String get diaryCardStylePinnedBadge => 'ピン留めマーク';

  @override
  String get diaryCardStylePinnedStandard => 'アイコンとラベル';

  @override
  String get diaryCardStylePinnedIcon => 'アイコンのみ';

  @override
  String get diaryCardStylePinnedHidden => '非表示';

  @override
  String get diaryCardStylePinnedTint => 'ピン留めカードに色を付ける';

  @override
  String get diaryCardStylePinnedTintSubtitle => 'テーマカラーの淡い塗りと枠線';

  @override
  String get diaryCardStyleShowMood => '気分を表示';

  @override
  String get diaryCardStyleShowWeather => '天気を表示';

  @override
  String get diaryCardStyleIndicatorStyle => '気分と天気';

  @override
  String get diaryCardStyleIndicatorStamp => 'スタンプ';

  @override
  String get diaryCardStyleIndicatorPlain => 'アイコンのみ';

  @override
  String get diaryCardStyleMetaPosition => '気分と天気の位置';

  @override
  String get diaryCardStyleMetaEyebrow => '日付行';

  @override
  String get diaryCardStyleMetaFooter => 'フッター';

  @override
  String get diaryCardStyleMetaCover => '表紙の上';

  @override
  String get diaryCardStyleExtras => 'フッターの追加情報';

  @override
  String get diaryCardStyleShowLocation => '場所';

  @override
  String get diaryCardStyleShowEnergy => 'エネルギー';

  @override
  String get diaryCardStyleShowWordCount => '文字数';

  @override
  String get diaryCardStyleShowMedia => '写真と添付ファイルのマーク';

  @override
  String get diaryCardStyleShowDate => '日付を表示';

  @override
  String get diaryCardStyleDateFormat => '日付の形式';

  @override
  String get diaryCardStyleDateEyebrow => '月日';

  @override
  String get diaryCardStyleDateFull => '年月日';

  @override
  String get diaryCardStyleDateNumeric => '数字';

  @override
  String get diaryCardStyleDateRelative => '相対表示';

  @override
  String get diaryCardStyleShowWeekday => '曜日を表示';

  @override
  String get diaryCardStyleShowTime => '時刻を表示';

  @override
  String get diaryCardStyleRelativeNote => '相対表示では曜日と時刻は付きません';

  @override
  String get diaryCardStyleDateSource => '表示する日付';

  @override
  String get diaryCardStyleDateCreated => '書いた日時';

  @override
  String get diaryCardStyleDateUpdated => '最終編集';

  @override
  String get diaryCardStyleFooterTime => 'フッターの時刻';

  @override
  String get diaryCardStyleFooterRelative => '…前に更新';

  @override
  String get diaryCardStyleFooterUpdated => '更新日時';

  @override
  String get diaryCardStyleFooterCreated => '書いた日時';

  @override
  String get diaryCardStyleFooterHidden => '非表示';

  @override
  String get diaryCardStyleOrderHint => '右側のハンドルをドラッグして、カード内の各要素の並び順を変更できます';

  @override
  String get diaryCardStyleBlockEyebrow => '日付行';

  @override
  String get diaryCardStyleBlockTitle => 'タイトル';

  @override
  String get diaryCardStyleBlockTags => 'タグ';

  @override
  String get diaryCardStyleBlockPreview => '抜粋';

  @override
  String get diaryCardStyleBlockFooter => 'フッター';

  @override
  String get diaryCardStyleOrderReset => '標準の並び順に戻す';

  @override
  String diaryCardStyleDragHandle(String name) {
    return 'ドラッグして「$name」を移動';
  }

  @override
  String get diaryCardStyleTitleSize => 'タイトルのサイズ';

  @override
  String get diaryCardStyleTitleWeight => 'タイトルの太さ';

  @override
  String get diaryCardStyleWeightRegular => '標準';

  @override
  String get diaryCardStyleWeightMedium => '中太';

  @override
  String get diaryCardStyleWeightBold => '太字';

  @override
  String get diaryCardStylePreviewSize => '抜粋のサイズ';

  @override
  String get diaryCardStyleLineHeight => '抜粋の行間';

  @override
  String get diaryCardStyleLineCompact => '狭め';

  @override
  String get diaryCardStyleLineStandard => '標準';

  @override
  String get diaryCardStyleLineRelaxed => '広め';

  @override
  String get diaryCardStyleMetaSize => '補助テキストのサイズ';

  @override
  String get diaryCardStyleTitleColor => 'タイトルの色';

  @override
  String get diaryCardStyleBodyColor => '本文の色';

  @override
  String get diaryCardStyleEnsureContrast => '読みやすさを自動で確保';

  @override
  String get diaryCardStyleEnsureContrastSubtitle =>
      '文字色がカードの色に近すぎるときは、読みやすい色に自動で切り替えます';

  @override
  String get diaryCardStyleBackground => 'カードの色';

  @override
  String get diaryCardStyleOpacity => 'カードの不透明度';

  @override
  String get diaryCardStyleGradient => 'グラデーション';

  @override
  String get diaryCardStyleGradientSubtitle => 'カードの色から2色目へなめらかに変化させます';

  @override
  String get diaryCardStyleGradientEnd => 'グラデーションの2色目';

  @override
  String get diaryCardStyleGradientDirection => 'グラデーションの方向';

  @override
  String get diaryCardStyleDirectionVertical => '縦';

  @override
  String get diaryCardStyleDirectionHorizontal => '横';

  @override
  String get diaryCardStyleDirectionDiagonal => '斜め';

  @override
  String get diaryCardStyleBorderWidth => '枠線の太さ';

  @override
  String get diaryCardStyleBorderColor => '枠線の色';

  @override
  String get diaryCardStyleAccentBar => 'アクセントバー';

  @override
  String get diaryCardStyleAccentNone => 'なし';

  @override
  String get diaryCardStyleAccentStart => 'サイド';

  @override
  String get diaryCardStyleAccentTop => '上部';

  @override
  String get diaryCardStyleAccentWidth => 'バーの幅';

  @override
  String get diaryCardStyleAccentColor => 'バーの色';

  @override
  String get diaryCardStyleShadow => '影';

  @override
  String get diaryCardStyleShadowThemed => 'デフォルト';

  @override
  String get diaryCardStyleShadowNone => 'なし';

  @override
  String get diaryCardStyleShadowSoft => 'ソフト';

  @override
  String get diaryCardStyleShadowFloating => 'フローティング';

  @override
  String get diaryCardStyleShadowCustom => 'カスタム';

  @override
  String get diaryCardStyleShadowElevation => '影の深さ';

  @override
  String get diaryCardStyleShadowColor => '影の色';

  @override
  String get diaryCardStyleSourceTheme => 'デフォルト';

  @override
  String get diaryCardStyleSourcePrimary => 'プライマリ';

  @override
  String get diaryCardStyleSourceSecondary => 'セカンダリ';

  @override
  String get diaryCardStyleSourceTertiary => 'ターシャリ';

  @override
  String get diaryCardStyleSourceMood => '気分';

  @override
  String get diaryCardStyleSourceTag => '最初のタグ';

  @override
  String get diaryCardStyleSourceCustom => 'カスタム';

  @override
  String get diaryCardStyleSourceMoodHint =>
      '日記ごとの気分の色を使います（色は「気分の絵文字」で変更できます）。気分がない場合はデフォルトの色になります';

  @override
  String get diaryCardStyleSourceTagHint => '日記ごとに最初のタグの色を使います';

  @override
  String get diaryCardStyleStrength => '濃さ';

  @override
  String get styleEditorEditColor => '色を編集';

  @override
  String get styleEditorColorDarkAuto => 'ダークモードの色を自動設定';

  @override
  String get styleEditorColorDarkAutoSubtitle =>
      'ライトモードの色をもとに、ダークモードでも読みやすい色を自動で作ります';

  @override
  String get styleEditorHexLabel => 'HEX カラー';

  @override
  String get styleEditorHexInvalid => '6桁の16進数カラーコードを入力してください（例：FFB300）';

  @override
  String get diaryCardStyleSheetSection => 'カードスタイル';

  @override
  String get diaryCardStyleSheetEntry => 'カードスタイルをカスタマイズ';

  @override
  String get diaryCardStyleSheetEntrySubtitle => '表紙、テキスト、色、レイアウト';

  @override
  String get diaryCardStyleSampleTitle1 => '海辺の夕暮れ';

  @override
  String get diaryCardStyleSampleBody1 =>
      '夕方、海岸沿いを長いこと歩いた。波の音が寄せては返し、空はオレンジから淡い紫へとゆっくり移ろっていった。';

  @override
  String get diaryCardStyleSampleTitle2 => '週末の山登り';

  @override
  String get diaryCardStyleSampleBody2 =>
      '山頂は風が強かった。写真をたくさん撮って、風の音も録音した。下山するころには足がガクガクだった。';

  @override
  String get diaryCardStyleSampleTitle3 => '雨の降る平日、カフェで今週の計画をもう一度じっくり練り直した';

  @override
  String get diaryCardStyleSampleBody3 =>
      '今週やることを並べ直して、ついでにいくつかアイデアをメモした。今夜は早めに寝よう。';

  @override
  String get diaryCardStyleSampleBody4 =>
      '帰り道、茶トラの猫が階段で日向ぼっこをしていた。目を細めている姿を見ていたら、こちらまで肩の力が抜けた。';

  @override
  String get diaryCardStyleSampleLead4 => '階段の上の茶トラ';

  @override
  String get diaryCardStyleSampleCapsuleTitle => '1年後の自分への手紙';

  @override
  String get diaryCardStyleSampleTag1 => '旅行';

  @override
  String get diaryCardStyleSampleTag2 => '暮らし';

  @override
  String get diaryCardStyleSampleTag3 => '読書';

  @override
  String get diaryCardStyleSampleLocation => '海辺の遊歩道';

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
    return '$formatted文字';
  }

  @override
  String diaryPreviewReadingTime(int minutes) {
    return '約$minutes分で読了';
  }

  @override
  String get diaryWordCountOpen => '文字数の詳細を表示';

  @override
  String get diaryWordCountTitle => '文字数';

  @override
  String diaryWordCountUnit(int count) {
    return '文字';
  }

  @override
  String get diaryWordCountCjk => '全角文字';

  @override
  String get diaryWordCountLatin => '英単語など';

  @override
  String get diaryWordCountCharacters => '文字数（スペースを除く）';

  @override
  String get diaryWordCountCharactersWithSpaces => '文字数（スペースを含む）';

  @override
  String get diaryWordCountParagraphs => '段落';

  @override
  String get diaryWordCountImages => '写真';

  @override
  String get diaryWordCountRecordings => '録音';

  @override
  String get diaryWordCountVideos => '動画';

  @override
  String get diaryWordCountAttachments => '添付ファイル';

  @override
  String get diaryWordCountReading => '読了時間の目安';

  @override
  String get diaryWordCountRule =>
      '漢字・かななどの全角文字と全角の句読点は1文字ずつ、それ以外のテキストは単語単位で数えます。スペースと改行は数えません。';

  @override
  String get diaryPreviewUpdatedPrefix => '更新';

  @override
  String get diaryPreviewBackToTop => 'トップへ戻る';

  @override
  String get diaryPreviewStyleTitle => '日記のプレビュー画面';

  @override
  String diaryPreviewStyleEntrySubtitle(String name) {
    return '現在：$name';
  }

  @override
  String get diaryPreviewStyleMoreEntry => 'ページのスタイル';

  @override
  String get diaryPreviewStyleTabPresets => 'プリセット';

  @override
  String get diaryPreviewStyleTabPage => 'ページ';

  @override
  String get diaryPreviewStyleTabCover => '表紙';

  @override
  String get diaryPreviewStyleTabTitle => 'タイトル';

  @override
  String get diaryPreviewStyleTabMeta => '情報';

  @override
  String get diaryPreviewStyleTabBody => '本文';

  @override
  String get diaryPreviewStylePresetClassic => 'クラシック';

  @override
  String get diaryPreviewStylePresetClassicDesc => '従来のデザイン';

  @override
  String get diaryPreviewStylePresetPaper => '紙の本';

  @override
  String get diaryPreviewStylePresetPaperDesc => '温かみのある紙、中央揃えのタイトル、内側に収めた表紙';

  @override
  String get diaryPreviewStylePresetMagazine => 'マガジン';

  @override
  String get diaryPreviewStylePresetMagazineDesc => '背の高い表紙、大きなタイトル、上部に日付';

  @override
  String get diaryPreviewStylePresetMinimal => 'ミニマル';

  @override
  String get diaryPreviewStylePresetMinimalDesc => '表紙なし、必要な情報だけ';

  @override
  String get diaryPreviewStylePresetNight => 'ナイト';

  @override
  String get diaryPreviewStylePresetNightDesc => '墨色の紙と読書の進捗ライン';

  @override
  String get diaryPreviewStylePresetJournal => '手帳';

  @override
  String get diaryPreviewStylePresetJournalDesc => '気分で色付けし、情報はカードにまとめて';

  @override
  String get diaryPreviewStylePresetMood => '気分カラー';

  @override
  String get diaryPreviewStylePresetMoodDesc => 'ページと紙が日記の気分の色に染まります';

  @override
  String get diaryPreviewStylePresetImmersive => '没入';

  @override
  String get diaryPreviewStylePresetImmersiveDesc => '全面の表紙、進捗ライン、トップへ戻るボタン';

  @override
  String get diaryPreviewStyleColorGroup => '配色';

  @override
  String get diaryPreviewStyleColorSeed => '配色のベース';

  @override
  String get diaryPreviewStyleSeedApp => 'アプリのテーマ';

  @override
  String get diaryPreviewStyleSeedMood => '気分';

  @override
  String get diaryPreviewStyleSeedTag => '最初のタグ';

  @override
  String get diaryPreviewStyleSeedCustom => 'カスタム';

  @override
  String get diaryPreviewStyleSeedColor => 'ベースカラー';

  @override
  String get diaryPreviewStyleSeedAppHint => 'アプリのテーマカラーと同じです。';

  @override
  String get diaryPreviewStyleSeedMoodHint =>
      '日記の気分から色を決めます。10種類の気分にはそれぞれの色があります。';

  @override
  String get diaryPreviewStyleSeedTagHint => '日記の最初のタグの色を使います。';

  @override
  String get diaryPreviewStyleSeedCustomHint => 'すべての日記で同じ色を使います。';

  @override
  String get diaryPreviewStyleSeedIntensity => '色の強さ';

  @override
  String get diaryPreviewStyleSeedIntensityHint =>
      '「ソフト」はアプリのテーマと同じく控えめ、「原色」は色本来の濃さに近く、「鮮やか」は最も彩度が高くなります。';

  @override
  String get diaryPreviewStyleSeedIntensitySoft => 'ソフト';

  @override
  String get diaryPreviewStyleSeedIntensityOriginal => '原色';

  @override
  String get diaryPreviewStyleSeedIntensityVivid => '鮮やか';

  @override
  String get diaryPreviewStyleSeedFallback => '色が決まらないとき';

  @override
  String get diaryPreviewStyleSeedFallbackHint => '気分やタグがない日記に使う配色です。';

  @override
  String get diaryPreviewStyleSeedFallbackApp => 'アプリのテーマ';

  @override
  String get diaryPreviewStyleSeedFallbackNeutral => 'ニュートラルグレー';

  @override
  String get diaryPreviewStyleTintPaper => '紙をベースカラーで染める';

  @override
  String get diaryPreviewStyleTintPaperHint => 'ページの背景にベースカラーを淡く重ねます';

  @override
  String get diaryPreviewStyleTintScrim => '背景のオーバーレイを染める';

  @override
  String get diaryPreviewStyleTintScrimHint =>
      '背景画像があるとき、オーバーレイに日記ごとのベースカラー（気分の色など）を重ねます。濃さは引き続き「背景とマテリアル」の設定に従います';

  @override
  String get diaryPreviewStyleMoodColors => '気分の色';

  @override
  String get diaryPreviewStyleMoodColorsHint => '各気分の色は「気分の絵文字」で変更できます';

  @override
  String get diaryPreviewStylePreviewMood => 'プレビューの気分';

  @override
  String get diaryPreviewStylePreviewMoodHint => '上のプレビューにあるサンプルの気分だけを切り替えます';

  @override
  String get diaryPreviewStylePreviewMoodSample => 'サンプルのまま';

  @override
  String get diaryPreviewStylePaper => '紙';

  @override
  String get diaryPreviewStylePaperTheme => 'テーマ';

  @override
  String get diaryPreviewStylePaperWarm => 'ウォーム';

  @override
  String get diaryPreviewStylePaperSepia => 'セピア';

  @override
  String get diaryPreviewStylePaperMint => 'ミント';

  @override
  String get diaryPreviewStylePaperGray => 'グレー';

  @override
  String get diaryPreviewStylePaperInk => '墨色';

  @override
  String get diaryPreviewStylePaperCustom => 'カスタム';

  @override
  String get diaryPreviewStylePaperColor => '紙の色';

  @override
  String get diaryPreviewStylePaperHint =>
      '紙の明暗がテーマと逆のときは、ページ全体の明暗を切り替えて文字を読みやすく保ちます。';

  @override
  String get diaryPreviewStyleTextColor => '本文の色をカスタマイズ';

  @override
  String get diaryPreviewStyleTextColorHint =>
      '紙とのコントラストが足りないときは、デフォルトの色に戻ります。';

  @override
  String get diaryPreviewStyleLayoutGroup => 'レイアウト';

  @override
  String get diaryPreviewStylePadding => '左右の余白';

  @override
  String get diaryPreviewStyleLimitWidth => '本文の幅を制限';

  @override
  String get diaryPreviewStyleLimitWidthSubtitle => 'タブレットや横向きのときに本文を中央に配置します';

  @override
  String get diaryPreviewStyleContentWidth => '本文の最大幅';

  @override
  String get diaryPreviewStyleTopBarGroup => 'トップバー';

  @override
  String get diaryPreviewStyleTopBarFloating => 'スクロールで隠す';

  @override
  String get diaryPreviewStyleTopBarPinned => '常に表示';

  @override
  String get diaryPreviewStyleTopBarTitle => 'タイトル';

  @override
  String get diaryPreviewStyleTopBarTitleDate => '日付';

  @override
  String get diaryPreviewStyleTopBarTitleNone => '非表示';

  @override
  String get diaryPreviewStyleShowTypographyButton => 'フォントとレイアウトのボタン';

  @override
  String get diaryPreviewStyleShowEditButton => '編集ボタン';

  @override
  String get diaryPreviewStyleShowShareButton => '共有ボタン';

  @override
  String get diaryPreviewStyleReadingGroup => '読書の補助';

  @override
  String get diaryPreviewStyleProgress => '読書の進捗ライン';

  @override
  String get diaryPreviewStyleProgressSubtitle => '読み進めるにつれて上端の細い線が伸びます';

  @override
  String get diaryPreviewStyleBackToTop => 'トップへ戻るボタン';

  @override
  String get diaryPreviewStyleBackToTopSubtitle => '1.5画面分スクロールすると表示されます';

  @override
  String get diaryPreviewStyleCoverMode => '表示方法';

  @override
  String get diaryPreviewStyleCoverBanner => '全幅';

  @override
  String get diaryPreviewStyleCoverInset => '内側に配置';

  @override
  String get diaryPreviewStyleCoverHidden => '非表示';

  @override
  String get diaryPreviewStyleCoverFit => '収め方';

  @override
  String get diaryPreviewStyleCoverContain => '写真全体';

  @override
  String get diaryPreviewStyleCoverFill => 'トリミングして全面';

  @override
  String get diaryPreviewStyleCoverHeight => '表紙の高さ';

  @override
  String get diaryPreviewStyleCoverHeightHint => '表紙の高さは最大で画面の70%までです。';

  @override
  String get diaryPreviewStyleCoverRadius => '角丸';

  @override
  String get diaryPreviewStyleCoverFade => 'スクロールでフェード';

  @override
  String get diaryPreviewStyleCoverFadeSubtitle =>
      '上にスクロールすると、表紙が徐々に薄くなり少し縮みます';

  @override
  String get diaryPreviewStyleCoverFirstImage => '表紙がないときは本文の最初の写真を使う';

  @override
  String get diaryPreviewStyleTitleVisible => 'タイトルを表示';

  @override
  String get diaryPreviewStyleTitleUntitled => 'タイトルがないときは「無題」と表示';

  @override
  String get diaryPreviewStyleTitleUntitledSubtitle => 'オフにするとタイトル行を省略します';

  @override
  String get diaryPreviewStyleTitleScale => 'タイトルのサイズ';

  @override
  String get diaryPreviewStyleTitleWeight => '太さ';

  @override
  String get diaryPreviewStyleWeightRegular => '標準';

  @override
  String get diaryPreviewStyleWeightMedium => '中太';

  @override
  String get diaryPreviewStyleWeightBold => '太字';

  @override
  String get diaryPreviewStyleWeightHeavy => '極太';

  @override
  String get diaryPreviewStyleTitleAlign => '配置';

  @override
  String get diaryPreviewStyleAlignStart => '左揃え';

  @override
  String get diaryPreviewStyleAlignCenter => '中央揃え';

  @override
  String get diaryPreviewStyleTitleColor => 'タイトルの色をカスタマイズ';

  @override
  String get diaryPreviewStyleTitleDivider => 'タイトル下の区切り線';

  @override
  String get diaryPreviewStyleTitleDividerSubtitle => 'タイトルと本文の間に、淡く細い線を引きます';

  @override
  String get diaryPreviewStyleTitleBodyGap => '本文との間隔';

  @override
  String get diaryPreviewStyleTitleBodyGapSubtitle =>
      '区切り線がオンのときは、線の上下にそれぞれこの間隔を空けます';

  @override
  String get diaryPreviewStyleMetaPosition => '位置';

  @override
  String get diaryPreviewStyleMetaAbove => 'タイトルの上';

  @override
  String get diaryPreviewStyleMetaBelow => 'タイトルの下';

  @override
  String get diaryPreviewStyleMetaEnd => '本文の後';

  @override
  String get diaryPreviewStyleMetaLayout => 'レイアウト';

  @override
  String get diaryPreviewStyleMetaStacked => '複数行';

  @override
  String get diaryPreviewStyleMetaInline => '1行';

  @override
  String get diaryPreviewStyleMetaCard => 'カード';

  @override
  String get diaryPreviewStyleMetaItems => '表示する情報';

  @override
  String get diaryPreviewStyleShowDate => '日付';

  @override
  String get diaryPreviewStyleShowWordCount => '文字数';

  @override
  String get diaryPreviewStyleShowReadingTime => '読了時間';

  @override
  String get diaryPreviewStyleShowLocation => '場所';

  @override
  String get diaryPreviewStyleShowWeather => '天気';

  @override
  String get diaryPreviewStyleShowMood => '気分';

  @override
  String get diaryPreviewStyleShowEnergy => 'エネルギー';

  @override
  String get diaryPreviewStyleShowTags => 'タグ';

  @override
  String get diaryPreviewStyleDatePrefix => '日付の前に「投稿／更新」を付ける';

  @override
  String get diaryPreviewStyleChipsGroup => 'チップ';

  @override
  String get diaryPreviewStyleTagStyle => 'タグ';

  @override
  String get diaryPreviewStyleChipStyle => '気分とエネルギー';

  @override
  String get diaryPreviewStyleChipChip => 'チップ';

  @override
  String get diaryPreviewStyleChipPlain => 'テキストのみ';

  @override
  String get diaryPreviewStyleTypographyEntry => 'フォントとレイアウト';

  @override
  String get diaryPreviewStyleTypographyEntrySubtitle => 'エディターと共通';

  @override
  String get diaryPreviewStyleEmptyHint => '本文がないときにヒントを表示';

  @override
  String get diaryPreviewStyleLastEdited => '「最終編集」を表示';

  @override
  String get diaryPreviewStyleEditedFormat => '時刻の形式';

  @override
  String get diaryPreviewStyleEditedPrecise => '正確';

  @override
  String get diaryPreviewStyleEditedRelative => '相対';

  @override
  String get diaryPreviewStyleEditedFull => '省略なし';

  @override
  String get diaryPreviewStyleCapsuleInsight => 'タイムカプセル開封のお知らせ';

  @override
  String get diaryPreviewStyleBehaviorGroup => '読むときの動作';

  @override
  String get diaryPreviewStyleBehaviorFootnote =>
      'プリセットやスタイルコードでは、これらの設定は変わりません。';

  @override
  String get diaryPreviewStyleTodoToggle => '読みながらチェックリストをチェック';

  @override
  String get diaryPreviewStyleTodoToggleSubtitle => 'チェックは自動で保存されます';

  @override
  String get diaryPreviewStyleTextSelection => '長押しでテキストを選択';

  @override
  String get diaryPreviewStyleTextSelectionSubtitle => '日記の一部を選択してコピーできます';

  @override
  String get diaryPreviewStyleDoubleTapEdit => 'ダブルタップで編集';

  @override
  String get diaryPreviewStyleDoubleTapEditSubtitle =>
      'タップした位置にカーソルを置いてエディターを開きます';

  @override
  String diaryPreviewStyleSampleOf(int index, int count) {
    return 'サンプル$index/$count';
  }

  @override
  String get diaryPreviewStyleSampleHeading => '今日のささやかなこと';

  @override
  String get diaryPreviewStyleSampleQuote => '急がば回れ。';

  @override
  String get diaryPreviewStyleSampleTodo1 => '花を買う';

  @override
  String get diaryPreviewStyleSampleTodo2 => '実家に電話する';

  @override
  String get diaryPreviewStyleSampleLong =>
      '雨がやむと、通りは静かになった。I sat by the window and wrote down three things I was grateful for. 窓の外ではプラタナスの葉が一枚、また一枚と舞い落ちて、とても古い本のページをめくっているようだった。';

  @override
  String get diaryPreviewStyleSampleWeather => '晴れ';

  @override
  String get diaryPreviewFirstDiary => 'これが最初の日記です';

  @override
  String get diaryPreviewLastDiary => 'これが最後の日記です';

  @override
  String get diaryPreviewPrevious => '前の日記';

  @override
  String get diaryPreviewNext => '次の日記';

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
    return '$count件中$index件目';
  }

  @override
  String diaryPreviewPositionSemanticsMore(int index, int count) {
    return '$count件以上中$index件目';
  }

  @override
  String get diaryDetailPaneEmpty => '読みたい日記を選んでください';

  @override
  String diaryDetailPaneCreateHint(String shortcut) {
    return '$shortcut で新しい日記を書けます';
  }

  @override
  String get diaryPreviewStyleTabPaging => 'ページ送り';

  @override
  String get diaryPreviewStyleSwipe => 'スワイプで日記を切り替え';

  @override
  String get diaryPreviewStyleSwipeSubtitle => '開いたときのリストの順番に従います';

  @override
  String get diaryPreviewStyleSwipeSensitivity => '感度';

  @override
  String get diaryPreviewStyleSensitivitySensitive => '高め';

  @override
  String get diaryPreviewStyleSensitivityStandard => '標準';

  @override
  String get diaryPreviewStyleSensitivityStrict => '誤操作防止';

  @override
  String get diaryPreviewStyleSensitivityHint =>
      '右の選択肢ほど水平に近いスワイプが必要です。「誤操作防止」では、さらに画面の半分以上ドラッグするか、勢いよくはじく必要があります。';

  @override
  String get diaryPreviewStyleHapticOnPage => 'ページ送りで振動';

  @override
  String get diaryPreviewStyleTransition => '切り替え効果';

  @override
  String get diaryPreviewStyleTransitionSlide => 'スライド';

  @override
  String get diaryPreviewStyleTransitionStack => '重ね';

  @override
  String get diaryPreviewStyleTransitionFade => 'フェード';

  @override
  String get diaryPreviewStyleNeighborCards => '末尾に前後の日記を表示';

  @override
  String get diaryPreviewStyleEdgeHint => '端でお知らせ';

  @override
  String get diaryPreviewStyleEdgeHintSubtitle =>
      '最初または最後の日記からさらに引っ張ったときに表示します';

  @override
  String get diaryPreviewStyleTopBarTitlePosition => '順番';

  @override
  String get dataMgmtCloudBackup => 'クラウドバックアップ';

  @override
  String get dataMgmtCloudBackupSubtitle =>
      'クラウドストレージ、WebDAV、オブジェクトストレージにバックアップし、そこから復元します';

  @override
  String get cloudBackupTitle => 'クラウドバックアップ';

  @override
  String get cloudBackupEmpty =>
      'バックアップ先がまだありません。クラウドストレージ、WebDAV サーバー、オブジェクトストレージを追加すると、データをバックアップして新しいデバイスで復元できます。';

  @override
  String get cloudBackupAdd => 'バックアップ先を追加';

  @override
  String get cloudBackupHint =>
      'アドレス、パスワード、クラウドストレージの認証情報はこのデバイスにだけ保存され、バックアップには書き込まれません。「バックアップ」は増分方式で、新規または変更された内容だけをアップロードします。完全な ZIP をアップロードすることもでき、暗号化も選べます。';

  @override
  String get cloudBackupSheetTitle => 'バックアップ先を選択';

  @override
  String get cloudBackupSheetHint =>
      '復元の前にバックアップを確認し、ローカルデータと統合するか上書きするかを選べます。';

  @override
  String get cloudBackupGroupDrives => 'クラウドストレージ（サインイン）';

  @override
  String get cloudBackupGroupDrivesHint =>
      'クラウドストレージの公式ページで認証します。アプリがアクセスできるのは専用のバックアップフォルダーだけです。';

  @override
  String get cloudBackupGroupWebDav => 'WebDAV';

  @override
  String get cloudBackupGroupWebDavHint =>
      'Nutstore、NAS、Nextcloud、および Alist / OpenList でマウントした各種クラウドストレージ。';

  @override
  String get cloudBackupGroupS3 => 'オブジェクトストレージ（S3 互換）';

  @override
  String get cloudBackupGroupS3Hint => 'アクセスキーを入力します。バックアップは指定したバケットに保存されます。';

  @override
  String get cloudBackupCustomWebDav => 'その他の WebDAV';

  @override
  String get cloudBackupCustomS3 => 'その他の S3 互換ストレージ';

  @override
  String get cloudBackupBaiduPan => 'Baidu Netdisk';

  @override
  String get cloudBackupAliyunDrive => 'Alipan（Aliyun Drive）';

  @override
  String get cloudBackupJianguoyun => 'Nutstore（Jianguoyun）';

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
  String get cloudBackupAwsChina => 'Amazon S3（中国リージョン）';

  @override
  String get cloudBackupHintJianguoyun =>
      'ユーザー名には Nutstore のアカウントを、パスワードには Web 版の「アカウント情報 → セキュリティ → サードパーティアプリ」で生成したアプリパスワードを入力します。無料アカウントは30分あたり600リクエストまでです。';

  @override
  String get cloudBackupHint123pan =>
      '123pan の「ツール → サードパーティマウント」に表示されるアドレスとパスワードをそのまま入力します（パスワードは一度しか表示されません）。';

  @override
  String get cloudBackupHintOpenList =>
      'Alist / OpenList のアドレス（デフォルトポート 5244、パス /dav/）を入力し、管理画面でそのユーザーに WebDAV の読み取りと管理の権限を付与してください。そこでマウントしたクラウドストレージはどれもバックアップ先として使えます。';

  @override
  String get cloudBackupHintCloudDrive2 =>
      'CloudDrive2 のアドレス（デフォルトポート 19798、パス /dav）と CloudDrive2 のアカウントを入力します。';

  @override
  String get cloudBackupHintNextcloud =>
      'アドレスは Web 版の「ファイル設定 → WebDAV」からコピーします。パスワードには「個人設定 → セキュリティ」で生成したアプリパスワードをおすすめします。';

  @override
  String get cloudBackupHintOwncloud =>
      'パスワードにはアプリトークンをおすすめします。oCIS では管理者がアプリトークンを有効にする必要があります。';

  @override
  String get cloudBackupHintSeafile =>
      'サーバーで SeafDAV を有効にする必要があります。シングルサインオンのアカウントは、Web で別途 WebDAV パスワードを設定してください。';

  @override
  String get cloudBackupHintSynology =>
      'DSM のパッケージセンターで WebDAV Server をインストールして有効にし（HTTPS のデフォルトポートは 5006）、DSM アカウントでサインインします。リモートフォルダーの第1階層は共有フォルダーである必要があります。';

  @override
  String get cloudBackupHintQnap =>
      'コントロールパネルで WebDAV を有効にし、アドレスの末尾に共有フォルダー名を付けてください。';

  @override
  String get cloudBackupHintKoofr =>
      'Koofr の「設定 → パスワード」で生成したアプリパスワードが必要です。ログインに何度も失敗すると一時的にブロックされます。';

  @override
  String get cloudBackupHintPcloud =>
      'pCloud のメールアドレスとパスワードでサインインします。ヨーロッパのアカウントは pCloud (EU) を選んでください。';

  @override
  String get cloudBackupHintInfinicloud =>
      'InfiniCLOUD のマイページから、アドレスと「外部アプリ接続」（Apps Connection）のパスワードをコピーします。';

  @override
  String get cloudBackupHintHetzner =>
      'Hetzner Console で Storage Box の WebDAV と外部アクセスを有効にしてください。';

  @override
  String get cloudBackupHintKdrive =>
      'Drive ID は kDrive の Web アドレスで確認できます。2段階認証を有効にしている場合はアプリパスワードを使用してください。';

  @override
  String get cloudBackupHintYandex =>
      '有料の Yandex 360 プランと、種類が WebDAV のアプリパスワードが必要です。';

  @override
  String get cloudBackupHintMailru => 'Mail.ru のアカウント設定で作成したアプリパスワードを使用してください。';

  @override
  String get cloudBackupS3Hint =>
      'エンドポイントとリージョンはバケットの所在地と一致させる必要があります。バックアップ専用のバケットと、そのバケットにしかアクセスできないキーの使用をおすすめします。';

  @override
  String get cloudBackupHintAliyunOss =>
      'RAM ユーザーの AccessKey を使用します。エンドポイントのリージョンはバケットと一致させてください。2025年3月以降に開設したアカウントは、中国本土ではデフォルトのパブリックエンドポイントを使えない場合があります。';

  @override
  String get cloudBackupHintTencentCos =>
      'バケット名には APPID のサフィックスが必要です（例：backup-1250000000）。キーは「CAM → API キー」で作成します。';

  @override
  String get cloudBackupHintQiniuKodo =>
      'S3 アクセス用のバケット名は Kodo のスペース名と異なる場合があります。コンソールに表示される名前を使ってください。';

  @override
  String get cloudBackupHintR2 =>
      'ACCOUNT_ID を Cloudflare のアカウント ID に置き換え、R2 の「API トークンの管理」でトークンを作成して、その S3 認証情報を使用します。リージョンは auto のままにしてください。';

  @override
  String get cloudBackupHintB2 =>
      'エンドポイントはバケットのページに表示されるものを使い、そのリージョン部分（例：us-west-004）をリージョンに入力します。キーには Application Key を使用します。';

  @override
  String get cloudBackupHintDigitalOcean =>
      'エンドポイントには Spaces のデータセンター（例：nyc3）を入れ、署名リージョンは us-east-1 のままにします。';

  @override
  String get cloudBackupHintMinio =>
      'MinIO の API アドレス（デフォルトポート 9000）を入力し、パス形式のアクセスはオンのままにします。';

  @override
  String get cloudBackupHintGcs =>
      'Cloud Storage の「設定 → 相互運用性」で HMAC キーを作成します。';

  @override
  String get cloudBackupHintOracle =>
      'NAMESPACE と REGION は OCI コンソールで確認し、顧客秘密キー（Customer Secret Key）を使用します。';

  @override
  String get cloudBackupFolderGoogleDrive =>
      'バックアップは Google Drive の「Jotsy」フォルダーに保存されます。アプリがアクセスできるのは自身が作成したファイルだけです。削除したバックアップはゴミ箱に入りません。';

  @override
  String get cloudBackupFolderOneDrive =>
      'バックアップは OneDrive の「アプリ」フォルダー内にある、このアプリ専用のフォルダーに保存されます。アプリはこのフォルダーにしかアクセスできません。削除したバックアップは OneDrive のゴミ箱に移動します。';

  @override
  String get cloudBackupFolderDropbox =>
      'バックアップは Dropbox の「アプリ」フォルダー内にある、このアプリ専用のフォルダーに保存されます。アプリはこのフォルダーにしかアクセスできません。';

  @override
  String get cloudBackupFolderBaidu =>
      'バックアップは Baidu Netdisk の「マイアプリデータ」内にある、このアプリ専用のフォルダーに保存されます。';

  @override
  String get cloudBackupFolderAliyun =>
      'バックアップは認証時に選んだフォルダー（未選択の場合はルートの「Jotsy」）に保存されます。削除したバックアップはゴミ箱に移動します。Alipan 側で認証の期限が切れたら、再認証してください。';

  @override
  String get cloudBackupConfigSection => '接続設定';

  @override
  String get cloudBackupSaveConfig => '保存';

  @override
  String get cloudBackupTestConnection => '接続テスト';

  @override
  String get cloudBackupUploadBackup => '完全な ZIP をアップロード';

  @override
  String get cloudBackupRefreshBackups => '再読み込み';

  @override
  String get cloudBackupBackupList => 'リモートのバックアップ';

  @override
  String get cloudBackupNoBackups => 'リモートのバックアップはまだありません';

  @override
  String cloudBackupBackupTime(String time) {
    return '日時：$time';
  }

  @override
  String cloudBackupBackupSize(String size) {
    return 'サイズ：$size';
  }

  @override
  String get cloudBackupRestoreAction => '復元';

  @override
  String get cloudBackupDeleteAction => '削除';

  @override
  String get cloudBackupDeleteConfirmTitle => 'リモートのバックアップを削除しますか？';

  @override
  String cloudBackupDeleteConfirmContent(String fileName) {
    return 'このバックアップ先から $fileName を削除しますか？この操作は元に戻せません。';
  }

  @override
  String get cloudBackupRemoveTarget => 'このバックアップ先の登録を解除';

  @override
  String get cloudBackupRemoveTargetTitle => 'バックアップ先の登録を解除しますか？';

  @override
  String get cloudBackupRemoveTargetContent =>
      'このデバイスに保存された接続情報と認証だけが削除されます。バックアップ先にすでにあるバックアップはそのまま残り、あとで再度追加することもできます。';

  @override
  String get cloudBackupRemoveTargetAction => '解除';

  @override
  String get cloudBackupRemoved => 'バックアップ先の登録を解除しました';

  @override
  String get cloudBackupConfigSaved => '設定を保存しました';

  @override
  String get cloudBackupConnectionOk => '接続に成功しました';

  @override
  String get cloudBackupUploadSuccess => 'バックアップをアップロードしました';

  @override
  String get cloudBackupRestoreSuccess => 'リモートのバックアップからデータを復元しました';

  @override
  String get cloudBackupDeleteSuccess => 'リモートのバックアップを削除しました';

  @override
  String get cloudBackupAccountAuthorized => '認証済み';

  @override
  String cloudBackupAccountConnected(String account) {
    return '$account としてサインイン中';
  }

  @override
  String get cloudBackupReauthorize => '再認証';

  @override
  String cloudBackupAuthorized(String name) {
    return '$name に接続しました';
  }

  @override
  String cloudBackupAuthorizeTitle(String name) {
    return '$name の認証';
  }

  @override
  String get cloudBackupDeviceCodeHint =>
      '認証ページを開いてサインインし、下のコードを入力してください。承認すると、ここで自動的に続行します。';

  @override
  String get cloudBackupDeviceCodeLabel => '認証コード';

  @override
  String get cloudBackupCopyCode => 'コードをコピー';

  @override
  String get cloudBackupDeviceCodeCopied => 'コピーしました';

  @override
  String get cloudBackupOpenAuthorizePage => '認証ページを開く';

  @override
  String get cloudBackupWaitingAuthorization => '認証を待っています…';

  @override
  String get cloudBackupCodePasteHint =>
      'ブラウザで認証すると、ページに認証コードが表示されます。それをコピーしてここに貼り付けてください。';

  @override
  String get cloudBackupCodeLabel => '認証コード';

  @override
  String get cloudBackupCodeConfirm => '完了';

  @override
  String get cloudBackupBusyLabel => 'クラウドバックアップを実行中';

  @override
  String get cloudBackupBusySave => '保存中…';

  @override
  String get cloudBackupBusyTest => '接続をテスト中…';

  @override
  String get cloudBackupBusyUpload => 'バックアップを作成中…';

  @override
  String cloudBackupBusyUploadProgress(int percent) {
    return 'アップロード中（$percent%）';
  }

  @override
  String get cloudBackupBusyDownload => 'バックアップをダウンロード中…';

  @override
  String cloudBackupBusyDownloadProgress(int percent) {
    return 'ダウンロード中（$percent%）';
  }

  @override
  String get cloudBackupBusyRestore => 'データを復元中…';

  @override
  String get cloudBackupBusyRefresh => 'リモートのバックアップを読み込み中…';

  @override
  String get cloudBackupBusyDelete => 'リモートのバックアップを削除中…';

  @override
  String get cloudBackupBusyAuthorize => '認証を確認中…';

  @override
  String cloudBackupOperationFailed(String detail) {
    return '操作に失敗しました：$detail';
  }

  @override
  String get cloudBackupErrorConfig =>
      'アドレス、バケット、フォルダーなどの設定が正しく入力されているか確認してください';

  @override
  String get cloudBackupErrorAppKeyMissing =>
      'このバージョンにはこのクラウドストレージのアプリキーが含まれていないため、利用できません';

  @override
  String get cloudBackupErrorAuth =>
      '認証に失敗したか、アクセスが拒否されました。アカウント、パスワード、またはキーを確認してください';

  @override
  String get cloudBackupErrorSessionExpired => '認証の有効期限が切れました。もう一度認証してください';

  @override
  String get cloudBackupErrorAuthorizationDenied => '認証が拒否されました';

  @override
  String get cloudBackupErrorAuthorizationExpired =>
      'コードが無効か期限切れです。新しいコードを取得してください';

  @override
  String get cloudBackupErrorNotFound => 'リモートのファイルまたはフォルダーが存在しません';

  @override
  String get cloudBackupErrorStorageFull => 'バックアップ先の空き容量が不足しています';

  @override
  String get cloudBackupErrorFileTooLarge => 'バックアップがこの保存先のファイルサイズ上限を超えています';

  @override
  String get cloudBackupErrorRateLimited => 'リクエストが多すぎます。しばらくしてからもう一度お試しください';

  @override
  String get cloudBackupErrorNetwork =>
      'ネットワークリクエストに失敗しました。ネットワーク、アドレス、証明書を確認してください';

  @override
  String get cloudBackupErrorProtocol => 'バックアップ先から想定外の応答が返されました';

  @override
  String get cloudBackupErrorPassword => 'バックアップのパスワードが正しくありません';

  @override
  String get cloudBackupErrorArchive => 'バックアップが破損しているか、Jotsy のバックアップではありません';

  @override
  String get cloudBackupErrorLocalFile =>
      '端末内の一時ファイルを読み書きできませんでした。空き容量を確認してください';

  @override
  String get cloudBackupErrorUnknown => '不明なエラーが発生しました。しばらくしてからもう一度お試しください';

  @override
  String get s3Endpoint => 'エンドポイント';

  @override
  String get s3EndpointHint => '例：https://s3.us-east-1.amazonaws.com';

  @override
  String get s3Region => 'リージョン';

  @override
  String get s3RegionHint => '空欄の場合は us-east-1';

  @override
  String get s3Bucket => 'バケット';

  @override
  String get s3AccessKeyId => 'Access Key ID';

  @override
  String get s3SecretAccessKey => 'Secret Access Key';

  @override
  String get s3Prefix => 'バックアップフォルダー（キーのプレフィックス）';

  @override
  String get s3PrefixHint => '例：jotsy/（空欄の場合はバケットのルート）';

  @override
  String get s3PathStyle => 'パス形式でアクセス';

  @override
  String get s3PathStyleSubtitle => 'MinIO などのセルフホスト型サービスでは通常オンにする必要があります';

  @override
  String get s3PathStyleLocked => 'このサービスは仮想ホスト形式のアクセスのみに対応しています';

  @override
  String get cloudBackupErrorPlatformUnavailable =>
      'この端末ではシステムアカウントによる認証を利用できません（Google Play 開発者サービスが必要です）。また、このビルドには代わりの認証方法がありません';

  @override
  String get weatherInvalidHost =>
      '天気サービスのホスト設定が正しくありません。qweather.api_host を確認してください。';

  @override
  String get weatherNetworkError =>
      '天気の取得に失敗したか、タイムアウトしました。接続を確認してもう一度お試しください。';

  @override
  String get weatherApiError => '天気サービスは一時的に利用できません。しばらくしてからもう一度お試しください。';

  @override
  String get weatherParseError =>
      '有効な天気情報を取得できませんでした。しばらくしてから再度お試しいただくか、手動で入力してください。';

  @override
  String get publishCoverImportFailed => 'この画像は表紙に設定できませんでした。別の画像でお試しください。';

  @override
  String get publishTagCreateFailed => 'タグを作成できませんでした。もう一度お試しください。';

  @override
  String get publishFailed => '日記を投稿できませんでした。もう一度お試しください。';

  @override
  String get publishSucceeded => '日記を投稿しました';

  @override
  String get publishCapsuleExpired => '開封日時を過ぎていたため、通常の日記として投稿しました。';

  @override
  String get publishSaveFailed => '変更を保存できませんでした。もう一度お試しください。';

  @override
  String publishTimeFollowsCapsule(String time) {
    return '開封日時に合わせる · $time';
  }

  @override
  String get publishCoverChange => 'タップして変更';

  @override
  String get publishPanelSummaryEmpty => 'タグ、気分、場所を追加…';

  @override
  String get previewShare => '共有';

  @override
  String get diaryShareSheetTitle => '日記を共有';

  @override
  String get diaryShareContentSection => '共有する内容';

  @override
  String get diaryShareOptionTitle => 'タイトル';

  @override
  String get diaryShareOptionBody => '本文';

  @override
  String get diaryShareOptionDate => '日付';

  @override
  String get diaryShareOptionMoodWeather => '気分と天気';

  @override
  String get diaryShareOptionLocation => '場所';

  @override
  String get diaryShareOptionTags => 'タグ';

  @override
  String get diaryShareOptionImages => '画像';

  @override
  String get diaryShareTextEmpty => 'テキストが選択されていません。画像のみを共有します';

  @override
  String diaryShareImagesSelected(int selected, int total) {
    return '$selected/$total枚を選択中';
  }

  @override
  String diaryShareImageLabel(int index) {
    return '$index枚目の画像';
  }

  @override
  String get diaryShareTargetsSection => '共有先';

  @override
  String get diaryShareTargetWeibo => 'Weibo';

  @override
  String get diaryShareTargetXiaohongshu => '小紅書';

  @override
  String get diaryShareTargetWechat => 'WeChat';

  @override
  String get diaryShareTargetWechatMoments => 'モーメンツ';

  @override
  String get diaryShareTargetQq => 'QQ';

  @override
  String get diaryShareTargetQzone => 'Qzone';

  @override
  String get diaryShareTargetSystem => 'その他のアプリ';

  @override
  String get diaryShareCopyText => 'テキストをコピー';

  @override
  String get diaryShareClipboardHint =>
      '画像付きで共有すると、テキストは自動でコピーされます。投稿画面で貼り付けてください。';

  @override
  String get diaryShareMoreSection => 'その他の形式';

  @override
  String get diaryShareLongImage => '長い画像として共有';

  @override
  String get diaryShareLongImageSubtitle => 'プレビュー画面の見た目のまま1枚の画像にします';

  @override
  String get diaryShareLongImageToGallery => '長い画像をギャラリーに保存';

  @override
  String get diaryShareLongImageToGallerySubtitle => '同じ長い画像をそのままギャラリーに保存します';

  @override
  String diaryShareRequiresImage(String app) {
    return '$appへの共有には画像が1枚以上必要です';
  }

  @override
  String get diaryShareRequiresImageSeveral => 'グレー表示のアプリへの共有には画像が1枚以上必要です';

  @override
  String get diaryShareNothingSelected => 'まず共有する内容を選択してください';

  @override
  String get diaryShareInProgress => '共有の準備中';

  @override
  String diaryShareTextCopiedForApp(String app) {
    return 'テキストをコピーしました。$appで貼り付けてください';
  }

  @override
  String get diaryShareTextCopied => 'テキストをコピーしました。共有先のアプリで貼り付けてください';

  @override
  String get diaryShareCopied => 'クリップボードにコピーしました';

  @override
  String diaryShareImagesTrimmed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '1回に共有できる画像は$count枚までです。残りは送信されませんでした',
      one: '1回に共有できる画像は1枚までです。残りは送信されませんでした',
    );
    return '$_temp0';
  }

  @override
  String diaryShareImagesMissing(int count) {
    return '$count枚の画像を読み込めなかったため、共有から除外しました';
  }

  @override
  String diaryShareAppUnavailable(String app) {
    return '$appを開けませんでした。インストール済みで最新版になっているか確認してください';
  }

  @override
  String get diaryShareNothingToShare => '共有できる内容がありません';

  @override
  String diaryShareFailed(String error) {
    return '共有に失敗しました：$error';
  }

  @override
  String get previewExport => 'エクスポート';

  @override
  String get diaryExportSelected => 'エクスポート';

  @override
  String get diaryTagBatchAction => 'タグを設定';

  @override
  String diaryTagBatchTitle(int count) {
    return '$count件の日記にタグを設定';
  }

  @override
  String get diaryTagBatchDone => '完了';

  @override
  String diaryTagBatchUpdated(int count) {
    return '$count件の日記のタグを更新しました';
  }

  @override
  String get diaryTagBatchFailed => 'タグを更新できませんでした。もう一度お試しください。';

  @override
  String get dataMgmtExportDiaries => '日記をエクスポート';

  @override
  String get dataMgmtExportDiariesSubtitle =>
      '日付やタグで絞り込み、PDF、Word、Markdown、Web ページなどの形式で書き出します';

  @override
  String get diaryExportSheetTitle => '日記をエクスポート';

  @override
  String diaryExportSheetCount(int count) {
    return '全$count件';
  }

  @override
  String get diaryExportFormatSection => '形式';

  @override
  String get diaryExportOptionsSection => 'オプション';

  @override
  String get diaryExportFormatPdf => 'PDF';

  @override
  String get diaryExportFormatPdfDescription => 'レイアウトが固定され、閲覧や印刷に最適';

  @override
  String get diaryExportFormatWord => 'Word 文書';

  @override
  String get diaryExportFormatWordDescription => '.docx 形式。あとから編集やレイアウト調整ができます';

  @override
  String get diaryExportFormatMarkdown => 'Markdown';

  @override
  String get diaryExportFormatMarkdownDescription =>
      'front matter 付き。Obsidian などのノートアプリに取り込めるほか、Jotsy にも再インポートできます';

  @override
  String get diaryExportFormatHtml => 'Web ページ';

  @override
  String get diaryExportFormatHtmlDescription =>
      'ブラウザでそのまま開けます。画像付きの日記が複数ある場合は、ページと画像フォルダーにまとめます';

  @override
  String get diaryExportFormatText => 'プレーンテキスト';

  @override
  String get diaryExportFormatTextDescription => '.txt 形式。どの端末でも開けます';

  @override
  String get diaryExportFormatCsv => '表計算（CSV）';

  @override
  String get diaryExportFormatCsvDescription =>
      '日記ごとに1行。気分や天気なども含まれ、Excel で集計できます';

  @override
  String get diaryExportFormatDiaryFile => 'Jotsy 日記ファイル';

  @override
  String get diaryExportFormatDiaryFileDescription =>
      '日記とメディアをそのまま保存。パスワードを設定でき、Jotsy に戻しても情報が失われません';

  @override
  String get diaryExportIncludeImages => '画像を含める';

  @override
  String get diaryExportIncludeMedia => '画像・録音・動画・添付ファイルを含める';

  @override
  String get diaryExportIncludeMeta => '気分・天気・場所・タグを含める';

  @override
  String get diaryExportOrderOldest => '古い順';

  @override
  String get diaryExportOrderNewest => '新しい順';

  @override
  String get diaryExportSave => 'ファイルに保存';

  @override
  String get diaryExportInProgress => 'エクスポート中';

  @override
  String diaryExportSaved(int count) {
    return '$count件の日記をエクスポートしました';
  }

  @override
  String diaryExportSkippedCapsules(int count) {
    return '未開封のタイムカプセル$count件はエクスポートされませんでした';
  }

  @override
  String get diaryExportOnlyCapsules =>
      '選択した日記はすべて未開封のタイムカプセルのため、エクスポートできるものがありません';

  @override
  String get diaryExportNothing => '条件に一致する日記がありません';

  @override
  String get diaryExportPageTitle => '日記をエクスポート';

  @override
  String get diaryExportRangeSection => '期間';

  @override
  String get diaryExportRangeAll => 'すべての日記';

  @override
  String get diaryExportRangeThisYear => '今年';

  @override
  String get diaryExportRangeLast30Days => '過去30日間';

  @override
  String get diaryExportRangeCustom => '期間を指定';

  @override
  String diaryExportRangeCustomValue(String start, String end) {
    return '$start～$end（タップして変更）';
  }

  @override
  String get diaryExportTagsSection => 'タグ';

  @override
  String get diaryExportTagsHint =>
      '未選択の場合はすべてのタグが対象です。複数選択すると、いずれかのタグが付いた日記が対象になります';

  @override
  String get diaryExportIncludeArchived => 'アーカイブ済みの日記を含める';

  @override
  String diaryExportMatchCount(int count) {
    return '$count件の日記をエクスポートします';
  }

  @override
  String get diaryExportCapsuleNote => '未開封のタイムカプセルはエクスポートされません';

  @override
  String get diaryExportNext => '形式を選んでエクスポート';

  @override
  String get diaryExportLabelUntitled => '無題';

  @override
  String get diaryExportLabelMood => '気分';

  @override
  String get diaryExportLabelEnergy => 'エネルギー';

  @override
  String get diaryExportLabelWeather => '天気';

  @override
  String get diaryExportLabelLocation => '場所';

  @override
  String get diaryExportLabelTags => 'タグ';

  @override
  String get diaryExportLabelDate => '日付';

  @override
  String get diaryExportLabelTime => '時刻';

  @override
  String get diaryExportLabelTitle => 'タイトル';

  @override
  String get diaryExportLabelContent => '本文';

  @override
  String get diaryExportLabelWordCount => '文字数';

  @override
  String get diaryExportLabelUpdated => '最終編集';

  @override
  String get diaryExportLabelImage => '画像';

  @override
  String get diaryExportLabelAudio => '録音';

  @override
  String get diaryExportLabelVideo => '動画';

  @override
  String get diaryExportLabelAttachment => '添付ファイル';

  @override
  String get diaryExportLabelExportedBy => 'Jotsy からエクスポート';

  @override
  String diaryExportTooLarge(int size) {
    return '画像が多すぎるため（約$size MB）、PDF を一度に作成できません。期間を狭めるか、「画像を含める」をオフにしてからもう一度お試しください';
  }

  @override
  String diaryDayPhotosTitle(int count) {
    return 'この日に撮った$count枚の写真';
  }

  @override
  String get diaryDayPhotosAccessTitle => 'この日に撮った写真';

  @override
  String get diaryDayPhotosAccessBody =>
      '写真へのアクセスを許可すると、この日に撮った写真や動画がここに表示され、日記に追加できます。';

  @override
  String get diaryDayPhotosDeniedBody => '写真へのアクセスがオフになっています。システム設定でオンにできます。';

  @override
  String get diaryDayPhotosAllowAccess => 'アクセスを許可';

  @override
  String get diaryDayPhotosOpenSettings => '設定を開く';

  @override
  String get diaryDayPhotosShowAll => 'すべて';

  @override
  String get diaryDayPhotosDismiss => 'この日記では表示しない';

  @override
  String diaryDayPhotosSelected(int count) {
    return '$count枚を選択中';
  }

  @override
  String get diaryDayPhotosClear => '選択を解除';

  @override
  String get diaryDayPhotosInsert => '挿入';

  @override
  String diaryDayPhotosInsertCount(int count) {
    return '$count枚を挿入';
  }

  @override
  String get diaryDayPhotosLimited => 'アクセスを許可した写真と動画のみを表示しています';

  @override
  String get diaryDayPhotosManageLimited => 'さらに選択';

  @override
  String diaryDayPhotosPhotoLabel(String time) {
    return '$timeに撮った写真';
  }

  @override
  String diaryDayPhotosInsertedLabel(String time) {
    return '$timeに撮った写真、挿入済み';
  }

  @override
  String diaryDayPhotosSheetTitle(String date) {
    return '$dateに撮った写真';
  }

  @override
  String diaryDayPhotosMissing(int count) {
    return '$count件を読み込めなかったため、スキップしました';
  }

  @override
  String get settingsDayPhotoSuggestions => 'その日の写真を自動で表示';

  @override
  String get settingsDayPhotoSuggestionsSubtitle =>
      '過去の日の日記をあとから書くとき、タイトルの下にその日の写真を表示します。オフにしても、エディター右上のメニューから開けます。';

  @override
  String get settingsToolbarAlwaysVisible => 'ツールバーを常に表示';

  @override
  String get settingsToolbarAlwaysVisibleSubtitle =>
      '画面キーボードを閉じているときや物理キーボードで入力するときも、エディターの下部にツールバーを表示します。';

  @override
  String get settingsOpenDiaryInEditor => '日記をエディターで開く';

  @override
  String get settingsOpenDiaryInEditorSubtitle =>
      '日記をタップするとすぐ編集できます。レイアウトはプレビューと同じです。';

  @override
  String get diaryReadingEditInfo => '情報を編集';

  @override
  String get diaryReadingDone => '完了';

  @override
  String get diaryReadingReloaded => 'この日記は別の画面で変更されたため、最新の内容を表示しています。';

  @override
  String get diaryDayPhotosSetCover => '表紙に設定';

  @override
  String get diaryDayPhotosClearCover => '表紙を解除';

  @override
  String get diaryDayPhotosCoverBadge => '表紙';

  @override
  String diaryDayPhotosCoverLabel(String label) {
    return '$label、表紙';
  }

  @override
  String get diaryDayPhotosCoverSet => '表紙に設定しました。投稿画面で確認・変更できます。';

  @override
  String get diaryDayPhotosCoverSetEdit => '表紙に設定しました';

  @override
  String get diaryDayPhotosMenu => 'この日の写真';

  @override
  String get diaryDayPhotosEmpty => 'この日に撮った写真や動画はありません';

  @override
  String diaryDayPhotosTitleVideos(int count) {
    return 'この日に撮った$count本の動画';
  }

  @override
  String diaryDayPhotosTitleMixed(int photos, int videos) {
    return 'この日に撮った写真$photos枚と動画$videos本';
  }

  @override
  String diaryDayPhotosSheetTitleMedia(String date) {
    return '$dateに撮った写真と動画';
  }

  @override
  String diaryDayPhotosSelectedItems(int count) {
    return '$count件を選択中';
  }

  @override
  String diaryDayPhotosInsertCountItems(int count) {
    return '$count件を挿入';
  }

  @override
  String diaryDayPhotosVideoLabel(String time, String duration) {
    return '$timeに撮った動画、長さ$duration';
  }

  @override
  String diaryDayPhotosVideoInsertedLabel(String time, String duration) {
    return '$timeに撮った動画、長さ$duration、挿入済み';
  }

  @override
  String get diaryDayPhotosVideoAccess => 'この日の動画はまだ読み込めません';

  @override
  String get diaryDayPhotosSelect => '選択';

  @override
  String get diaryDayPhotosDeselect => '選択を解除';

  @override
  String get diaryDayPhotosInserted => '挿入済み';

  @override
  String get diaryDayPhotosPreview => 'プレビュー';

  @override
  String get diaryDayPhotosPreviewFailed => 'この写真は表示できません';

  @override
  String get diaryLongImageBadge => '長い画像';

  @override
  String get diaryImageMenuTitle => '画像';

  @override
  String get diaryImageMenuView => '表示';

  @override
  String get diaryImageMenuResize => 'サイズを変更';

  @override
  String get diaryImageMenuThumbnail => 'サムネイルで表示';

  @override
  String get diaryImageMenuFullSize => '通常の大きさで表示';

  @override
  String get diaryImageMenuCopy => 'コピー';

  @override
  String get diaryPreviewStyleLongImage => '長い画像の表示';

  @override
  String get diaryPreviewStyleLongImageSubtitle =>
      '長いスクリーンショットなど、高さが幅の3倍以上ある画像です。折りたたみ時はタップすると全体を表示します。';

  @override
  String get diaryPreviewStyleLongImageFold => '折りたたむ';

  @override
  String get diaryPreviewStyleLongImageFull => '全体を表示';

  @override
  String get diaryDraftsTitle => '下書き';

  @override
  String get diaryDraftsEmpty => '下書きはまだありません。投稿せずに閉じた新しい日記は、ここに自動で保存されます';

  @override
  String diaryDraftEditedAt(String time, String words) {
    return '$timeに編集 · $words文字';
  }

  @override
  String get diaryDraftDeleted => '下書きを削除しました';

  @override
  String diaryDraftsDeleted(int count) {
    return '$count件の下書きを削除しました';
  }

  @override
  String get diaryDraftsDeleteTitle => '下書きを削除';

  @override
  String diaryDraftsDeleteMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '選択した$count件の下書きを削除しますか？',
      one: '選択した下書きを削除しますか？',
    );
    return '$_temp0';
  }

  @override
  String get diaryDraftsDeleteFailed => '下書きを削除できませんでした。もう一度お試しください';

  @override
  String get diaryDraftsRestoreFailed => '元に戻せませんでした。もう一度お試しください';

  @override
  String get diaryDraftPickerTitle => '下書きの続きを書く';

  @override
  String diaryDraftPickerViewAll(int count) {
    return 'すべての下書きを表示（$count）';
  }

  @override
  String get diaryDraftPickerNewBlank => '白紙から新規作成';

  @override
  String get diarySearchPreviewHint => 'Jotsy 内を検索';

  @override
  String backupOverwriteAllTemplates(int count) {
    return '$count個の日記テンプレート';
  }

  @override
  String backupImportTemplateMergeResult(int added) {
    return '日記テンプレート：$added個を追加';
  }

  @override
  String backupOverwriteAllNotebooks(int count) {
    return '$count冊の日記帳';
  }

  @override
  String backupImportNotebookMergeResult(int added) {
    return '日記帳：$added冊を追加';
  }

  @override
  String backupImportModeOverwriteNotebooksExtra(int count) {
    return 'この端末にすでにある$count冊の日記帳の名前、表紙、章などの設定も置き換えます';
  }

  @override
  String get diaryTemplateDailyName => '毎日の記録';

  @override
  String get diaryTemplateDailyDesc => '今日の出来事と、いまの気持ちを書き留めて';

  @override
  String diaryTemplateDailyTitle(String date, String weekday) {
    return '$date（$weekday）';
  }

  @override
  String get diaryTemplateMorningName => '朝の日記';

  @override
  String get diaryTemplateMorningDesc => '朝いちばんに1ページ、今日という日にやさしい道しるべを';

  @override
  String diaryTemplateMorningTitle(String date) {
    return '朝 · $date';
  }

  @override
  String get diaryTemplateEveningName => '夜の振り返り';

  @override
  String get diaryTemplateEveningDesc => '今日一日をふり返り、明日の準備を整える';

  @override
  String diaryTemplateEveningTitle(String date) {
    return '振り返り · $date';
  }

  @override
  String get diaryTemplateGratitudeName => '感謝日記';

  @override
  String get diaryTemplateGratitudeDesc => 'ありがたいと思えた小さなことを3つ';

  @override
  String diaryTemplateGratitudeTitle(String date) {
    return '感謝 · $date';
  }

  @override
  String get diaryTemplateQuestionName => '今日の質問';

  @override
  String get diaryTemplateQuestionDesc => '1日1つの問いで、まだ知らない自分に出会う';

  @override
  String diaryTemplateQuestionTitle(String date) {
    return '今日の質問 · $date';
  }

  @override
  String get diaryTemplateWeeklyName => '週の振り返り';

  @override
  String get diaryTemplateWeeklyDesc => '1週間のハイライトをまとめて、身軽に次の週へ';

  @override
  String diaryTemplateWeeklyTitle(String date) {
    return '週の振り返り · $date';
  }

  @override
  String get diaryTemplateEmotionName => '気持ちの整理';

  @override
  String get diaryTemplateEmotionDesc => '気持ちを書き出して、それがどこから来るのかを見つめる';

  @override
  String diaryTemplateEmotionTitle(String date) {
    return '気持ちの整理 · $date';
  }

  @override
  String get diaryTemplateReadingName => '読書ノート';

  @override
  String get diaryTemplateReadingDesc => '心に残った一節と感想を、読んだ証として';

  @override
  String diaryTemplateReadingTitle(String date) {
    return '読書ノート · $date';
  }

  @override
  String get diaryTemplateDailyHappened => '今日の出来事：';

  @override
  String get diaryTemplateDailyMoment => '輝いた瞬間：';

  @override
  String get diaryTemplateDailyMood => 'いまの気持ち：';

  @override
  String get diaryTemplateDailyWords => '今日に贈るひとこと：';

  @override
  String diaryTemplateMorningWake(String time, String term) {
    return '$timeに起床';
  }

  @override
  String get diaryTemplateMorningTop3 => '今日いちばん大切な3つのこと：';

  @override
  String get diaryTemplateMorningLookForward => '今日のささやかな楽しみ：';

  @override
  String get diaryTemplateMorningWords => '今日へのひとこと：';

  @override
  String get diaryTemplateEveningDone => '今日やり終えたこと：';

  @override
  String get diaryTemplateEveningWentWell => 'うまくいったこと：';

  @override
  String get diaryTemplateEveningBetter => 'もっと良くできること：';

  @override
  String get diaryTemplateEveningTomorrow => '明日の予定：';

  @override
  String get diaryTemplateEveningNight => '眠る前に自分へひとこと：';

  @override
  String get diaryTemplateGratitudeThree => '今日感謝したい3つのこと：';

  @override
  String get diaryTemplateGratitudeThanks => '「ありがとう」を伝えたい人：';

  @override
  String get diaryTemplateGratitudeSelf => '今日の自分にも、ありがとう：';

  @override
  String get diaryTemplateQuestionPrompt => '今日の質問：';

  @override
  String get diaryTemplateQuestionAnswer => '私の答え：';

  @override
  String diaryTemplateWeeklyProgress(String week, String progress) {
    return '第$week週 · 今年もすでに$progressが過ぎました';
  }

  @override
  String get diaryTemplateWeeklyHighlights => '今週のハイライト：';

  @override
  String get diaryTemplateWeeklyWins => 'できたことと学んだこと：';

  @override
  String get diaryTemplateWeeklyOpen => 'まだ終わっていないこと：';

  @override
  String get diaryTemplateWeeklyNext => '来週やりたいこと：';

  @override
  String get diaryTemplateWeeklyNote => '来週の自分へ：';

  @override
  String get diaryTemplateEmotionHappened => '何があったか：';

  @override
  String get diaryTemplateEmotionFelt => '感じた気持ち：';

  @override
  String get diaryTemplateEmotionSource => 'その気持ちはどこから来ているか：';

  @override
  String get diaryTemplateEmotionNeed => '本当に必要としているもの：';

  @override
  String get diaryTemplateEmotionStep => 'ここからできる小さな一歩：';

  @override
  String get diaryTemplateReadingBook => '書名：';

  @override
  String get diaryTemplateReadingAuthor => '著者：';

  @override
  String get diaryTemplateReadingProgress => '読んだところ：';

  @override
  String get diaryTemplateReadingQuotes => '抜き書き：';

  @override
  String get diaryTemplateReadingThoughts => '私の感想：';

  @override
  String get diaryTemplateTagGratitude => '感謝';

  @override
  String get diaryTemplateTagReading => '読書';

  @override
  String get diaryTemplateQuestion01 => '今日、思わずほほえんだ小さな出来事は？';

  @override
  String get diaryTemplateQuestion02 => '今日をやり直せるとしたら、何を変えたい？';

  @override
  String get diaryTemplateQuestion03 => '最後に自分を誇らしく思えたのはいつ？';

  @override
  String get diaryTemplateQuestion04 => 'いま、いちばん言葉をかけたい相手は誰？';

  @override
  String get diaryTemplateQuestion05 => '今日新しく知ったことを1つ挙げるなら？';

  @override
  String get diaryTemplateQuestion06 => '最近、ずっと心に引っかかっていることは？';

  @override
  String get diaryTemplateQuestion07 => 'あなたにとって理想の週末はどんなもの？';

  @override
  String get diaryTemplateQuestion08 => '今日、誰かにわかってもらえたと感じた瞬間はあった？';

  @override
  String get diaryTemplateQuestion09 =>
      '最近読んでいるもの、観ているもの、聴いているものは？それはあなたに何をくれている？';

  @override
  String get diaryTemplateQuestion10 => 'いまいちばん必要なのは、休息、誰かと過ごす時間、それとも挑戦？';

  @override
  String get diaryTemplateQuestion11 => '1年前の今日、何を心配していた？いまはどう？';

  @override
  String get diaryTemplateQuestion12 => '今日、自分のために何をした？';

  @override
  String get diaryTemplateQuestion13 => '最近、声を出して笑ったのはどんなとき？';

  @override
  String get diaryTemplateQuestion14 => '始めたい習慣、手放したい習慣は？';

  @override
  String get diaryTemplateQuestion15 => '今日の自分を3つの言葉で表すと？';

  @override
  String get diaryTemplateQuestion16 => '今日いちばん大変だったことは？どう乗り越えた？';

  @override
  String get diaryTemplateQuestion17 => '最近、感謝している人は誰？それはなぜ？';

  @override
  String get diaryTemplateQuestion18 => '明日1つのことしかできないとしたら、何をする？';

  @override
  String get diaryTemplateQuestion19 => '最近、何かへの見方が変わったきっかけはあった？';

  @override
  String get diaryTemplateQuestion20 => '今日の天気から、何を思い出す？';

  @override
  String get diaryTemplateQuestion21 => '最後にコンフォートゾーンから一歩踏み出したのはいつ？';

  @override
  String get diaryTemplateQuestion22 => '10年後の自分は、今日の悩みをどう振り返るだろう？';

  @override
  String get diaryTemplateQuestion23 => '今日、誰かの言葉で心に残ったものはある？';

  @override
  String get diaryTemplateQuestion24 => '最近、いちばん心が落ち着いた場所はどこ？';

  @override
  String get diaryTemplateQuestion25 => '子どものころの自分に、何と声をかけたい？';

  @override
  String get diaryTemplateQuestion26 => '昨日より、少しだけ自分のことがわかった？';

  @override
  String get diaryTemplateQuestion27 => '最近、お祝いしたくなるような小さな進歩は？';

  @override
  String get diaryTemplateQuestion28 => 'ずっと試してみたいのに、まだ始めていないことは？何がブレーキになっている？';

  @override
  String get diaryTemplateQuestion29 => '今日、自分の気持ちをどうやっていたわった？';

  @override
  String get diaryTemplateQuestion30 => '今日を1〜10で採点するなら何点？その理由は？';

  @override
  String get diaryTemplateVarDateToken => '日付';

  @override
  String get diaryTemplateVarDateLabel => '日付';

  @override
  String get diaryTemplateVarWeekdayToken => '曜日';

  @override
  String get diaryTemplateVarWeekdayLabel => '曜日';

  @override
  String get diaryTemplateVarTimeToken => '時刻';

  @override
  String get diaryTemplateVarTimeLabel => '時刻';

  @override
  String get diaryTemplateVarTime12hLabel => '時刻（12時間制）';

  @override
  String get diaryTemplateVarTime12hFormat => 'ah:mm';

  @override
  String get diaryTemplateVarYearToken => '年';

  @override
  String get diaryTemplateVarYearLabel => '年';

  @override
  String get diaryTemplateVarMonthToken => '月';

  @override
  String get diaryTemplateVarMonthLabel => '月';

  @override
  String get diaryTemplateVarDayToken => '日';

  @override
  String get diaryTemplateVarDayLabel => '日';

  @override
  String get diaryTemplateVarWeekToken => '週番号';

  @override
  String get diaryTemplateVarWeekLabel => '週番号';

  @override
  String get diaryTemplateVarDayOfYearToken => '通算日';

  @override
  String get diaryTemplateVarDayOfYearLabel => '年間の通算日';

  @override
  String get diaryTemplateVarYearProgressToken => '年間進捗';

  @override
  String get diaryTemplateVarYearProgressLabel => '今年の経過率';

  @override
  String get diaryTemplateVarLunarToken => '旧暦';

  @override
  String get diaryTemplateVarLunarLabel => '旧暦';

  @override
  String get diaryTemplateVarSolarTermToken => '節気';

  @override
  String get diaryTemplateVarSolarTermLabel => '二十四節気';

  @override
  String get diaryTemplateVarQuestionToken => '今日の質問';

  @override
  String get diaryTemplateVarQuestionLabel => '今日の質問';

  @override
  String get diaryTemplateCategoryDaily => '日常';

  @override
  String get diaryTemplateCategoryReview => '振り返り';

  @override
  String get diaryTemplateCategoryMood => '気持ち';

  @override
  String get diaryTemplateCategoryLife => '暮らし';

  @override
  String get diaryTemplateCategoryWork => '仕事';

  @override
  String get diaryTemplateCategoryOther => 'その他';

  @override
  String get diaryTemplateStripTitle => 'テンプレートから始める';

  @override
  String get diaryTemplateStripAll => 'すべて';

  @override
  String get diaryTemplateStripDismiss => 'テンプレートの提案を隠す';

  @override
  String get diaryTemplateRecommended => 'おすすめ';

  @override
  String get diaryTemplateUntitled => '無題のテンプレート';

  @override
  String diaryTemplateApplied(String name) {
    return '「$name」を適用しました';
  }

  @override
  String diaryTemplateAutoApplied(String name) {
    return '「$name」を自動で適用しました';
  }

  @override
  String get diaryTemplatePickerTitle => 'テンプレートを選択';

  @override
  String get diaryTemplateFilterAll => 'すべて';

  @override
  String get diaryTemplateFilterRecommended => 'おすすめ';

  @override
  String get diaryTemplateFilterMine => 'マイテンプレート';

  @override
  String get diaryTemplatePickerEmpty => 'ここにはまだテンプレートがありません';

  @override
  String get diaryTemplatePickerSearchHint => 'テンプレートを検索';

  @override
  String diaryTemplatePickerSearchEmpty(String query) {
    return '「$query」に一致するテンプレートはありません';
  }

  @override
  String get diaryTemplatePickerUse => 'このテンプレートを使う';

  @override
  String get diaryTemplatePickerShuffle => '別の質問にする';

  @override
  String get diaryTemplatePickerPreviewHint => '日付と質問は、この日記に合わせて入力済みです。';

  @override
  String diaryTemplatePresetCapsule(String when) {
    return 'タイムカプセル：$when';
  }

  @override
  String diaryTemplatePresetEnergy(int level) {
    return 'エネルギー$level/5';
  }

  @override
  String get diaryTemplateEditedBadge => '編集済み';

  @override
  String get diaryDraftPickerFromTemplate => 'テンプレートから新規作成';

  @override
  String get diaryTemplatesTitle => '日記テンプレート';

  @override
  String diaryTemplatesSettingsSubtitle(int builtIn, int mine) {
    return '標準$builtIn個 · マイテンプレート$mine個';
  }

  @override
  String get diaryTemplatesNewEntryGroup => '日記の新規作成時';

  @override
  String get diaryTemplatesStripSwitch => '新規作成時にテンプレートを提案';

  @override
  String get diaryTemplatesStripSwitchSubtitle =>
      '空白の日記のタイトルの下に「テンプレートから始める」を表示します';

  @override
  String get diaryTemplatesAutoApply => '自動適用';

  @override
  String get diaryTemplatesAutoApplyNone => 'オフ';

  @override
  String get diaryTemplatesAutoApplyHint =>
      'どの時間帯にも当てはまらないときや、別の日の日記を書くときは、空白の新しい日記にまずこのテンプレートを適用します。毎回元に戻せます。';

  @override
  String diaryTemplatesAutoApplyRulesSummary(int count) {
    return '$count個の時間帯';
  }

  @override
  String diaryTemplatesAutoApplyRulesAndDefault(int count, String name) {
    return '$count個の時間帯 · それ以外は「$name」';
  }

  @override
  String get diaryTemplatesAutoApplyIntro =>
      '空白の日記を新しく作成すると、まずテンプレートが適用されます。毎回元に戻せます。時間帯の設定は、今日の日記を書くときのみ有効です。';

  @override
  String get diaryTemplatesAutoApplyRulesGroup => '時間帯別';

  @override
  String get diaryTemplatesAutoApplyOtherGroup => 'その他の時間';

  @override
  String get diaryTemplatesAutoApplyDefault => 'デフォルトのテンプレート';

  @override
  String get diaryTemplatesAutoApplyAddRule => '時間帯を追加';

  @override
  String diaryTemplatesAutoApplyRuleLimit(int max) {
    return '時間帯は$max個まで設定できます';
  }

  @override
  String get diaryTemplatesAutoApplyOverlapHint =>
      '時間帯が重なる場合は、曜日を指定したものが優先され、次に時間の短いものが優先されます。';

  @override
  String diaryTemplatesAutoApplyRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String diaryTemplatesAutoApplyRangeOvernight(String start, String end) {
    return '$start – 翌日$end';
  }

  @override
  String diaryTemplatesAutoApplyRuleSubtitle(String days, String name) {
    return '$days · $name';
  }

  @override
  String get diaryTemplatesAutoApplyEveryDay => '毎日';

  @override
  String get diaryTemplatesAutoApplyWorkdays => '平日';

  @override
  String get diaryTemplatesAutoApplyWeekend => '週末';

  @override
  String get diaryTemplatesAutoApplyDaySeparator => '、';

  @override
  String get diaryTemplatesAutoApplyMissing => 'テンプレートが見つかりません';

  @override
  String get diaryTemplatesAutoApplyEditRule => '時間帯を編集';

  @override
  String get diaryTemplatesAutoApplyStart => '開始';

  @override
  String get diaryTemplatesAutoApplyEnd => '終了';

  @override
  String diaryTemplatesAutoApplyOvernightHint(String end) {
    return '日付をまたぎ、翌日の$endに終了します';
  }

  @override
  String get diaryTemplatesAutoApplySameTime => '開始と終了を同じ時刻にすることはできません';

  @override
  String get diaryTemplatesAutoApplyDays => '曜日';

  @override
  String get diaryTemplatesAutoApplyDaysHint => '何も選択しない場合は毎日';

  @override
  String get diaryTemplatesAutoApplyTemplate => 'テンプレート';

  @override
  String get diaryTemplatesAutoApplyRuleDeleted => '時間帯を削除しました';

  @override
  String get diaryTemplatesMineGroup => 'マイテンプレート';

  @override
  String get diaryTemplatesBuiltInGroup => '標準テンプレート';

  @override
  String get diaryTemplatesMineEmpty =>
      '自分のテンプレートはまだありません。右上の「+」で作成できます。標準テンプレートを直接編集することもできます。';

  @override
  String get diaryTemplatesNew => '新規テンプレート';

  @override
  String get diaryTemplatesImport => 'テンプレートコードをインポート';

  @override
  String get diaryTemplatesMoreActions => 'その他の操作';

  @override
  String get diaryTemplatesDuplicate => '複製';

  @override
  String get diaryTemplatesCopyCode => 'テンプレートコードをコピー';

  @override
  String get diaryTemplatesResetBuiltIn => '初期状態に戻す';

  @override
  String get diaryTemplatesRestoreDeleted => '削除した標準テンプレートを復元';

  @override
  String diaryTemplatesRestoreDeletedCount(int count) {
    return '$count個';
  }

  @override
  String get diaryTemplatesRestoreSheetTitle => '削除した標準テンプレート';

  @override
  String get diaryTemplatesRestoreSheetHint =>
      '復元したテンプレートは標準テンプレートの一覧に戻ります。削除前に加えた編集もそのまま戻ります。';

  @override
  String get diaryTemplatesRestore => '復元';

  @override
  String get diaryTemplatesRestoreAll => 'すべて復元';

  @override
  String diaryTemplatesCopyName(String name) {
    return '$nameのコピー';
  }

  @override
  String diaryTemplatesDeleted(String name) {
    return '「$name」を削除しました';
  }

  @override
  String diaryTemplatesResetDone(String name) {
    return '「$name」を初期状態に戻しました';
  }

  @override
  String diaryTemplatesRestoredDone(String name) {
    return '「$name」を復元しました';
  }

  @override
  String diaryTemplatesRestoredAllDone(int count) {
    return '$count個の標準テンプレートを復元しました';
  }

  @override
  String get diaryTemplatesCodeCopied => 'テンプレートコードをコピーしました';

  @override
  String get diaryTemplatesCodeTooLong => 'このテンプレートは長すぎるため、テンプレートコードを作成できません';

  @override
  String get diaryTemplatesImportEmpty => 'クリップボードにテンプレートコードがありません';

  @override
  String get diaryTemplatesImportInvalid => '有効なテンプレートコードではありません';

  @override
  String diaryTemplatesImported(String name) {
    return '「$name」をインポートしました';
  }

  @override
  String diaryTemplatesImportedNewer(String name) {
    return '「$name」をインポートしました。新しいバージョンで作成されたため、一部の設定が反映されない場合があります。';
  }

  @override
  String get diaryTemplatesSaveFailed => 'テンプレートを保存できませんでした。もう一度お試しください';

  @override
  String get diaryTemplateEditorNewTitle => '新規テンプレート';

  @override
  String get diaryTemplateEditorEditTitle => 'テンプレートを編集';

  @override
  String get diaryTemplateEditorTabContent => '内容';

  @override
  String get diaryTemplateEditorTabSettings => '設定';

  @override
  String get diaryTemplateEditorTitleHint => 'タイトル（変数を使用可）';

  @override
  String get diaryTemplateEditorBodyHint => '本文を入力。見出し、リスト、チェックリストもそのまま保存されます。';

  @override
  String get diaryTemplateEditorAllVariables => 'すべての変数';

  @override
  String get diaryTemplateEditorVariablesTitle => '変数を挿入';

  @override
  String get diaryTemplateEditorVariablesHint =>
      '変数は、テンプレートを適用するときに日記の日付に合わせて置き換えられます。旧暦と二十四節気は中国語で表示されます。';

  @override
  String diaryTemplateEditorTimeFormatHint(String example) {
    return '時刻はコロンの後に書式を指定できます（例：$example）。H は時（h は12時間制）、mm は分、ss は秒、a は午前／午後を表します。それ以外の文字はシングルクォートで囲んでください。読み取れない書式は、書いたとおりに残ります。';
  }

  @override
  String diaryTemplateEditorVariableExample(String example) {
    return '今日：$example';
  }

  @override
  String get diaryTemplateEditorName => '名前';

  @override
  String get diaryTemplateEditorNameRequired => 'テンプレートの名前を入力してください';

  @override
  String get diaryTemplateEditorDescription => 'ひとこと説明';

  @override
  String get diaryTemplateEditorLook => '外観';

  @override
  String get diaryTemplateEditorCategory => 'カテゴリ';

  @override
  String get diaryTemplateEditorIcon => 'アイコン';

  @override
  String get diaryTemplateEditorAccent => '色';

  @override
  String get diaryTemplateEditorAccentTheme => 'テーマカラー';

  @override
  String get diaryTemplateEditorPresets => '適用時にあわせて設定';

  @override
  String get diaryTemplateEditorTags => 'タグ';

  @override
  String get diaryTemplateEditorAddTag => 'タグを追加';

  @override
  String get diaryTemplateEditorNewTag => '新しいタグ';

  @override
  String get diaryTemplateEditorTagsHint =>
      'タグは名前で照合されます。この端末にないタグは、テンプレートの適用時に作成されます。';

  @override
  String get diaryTemplateEditorMood => '気分';

  @override
  String get diaryTemplateEditorNone => '設定しない';

  @override
  String get diaryTemplateEditorEnergy => 'エネルギー';

  @override
  String get diaryTemplateEditorCapsule => 'タイムカプセル';

  @override
  String get diaryTemplateEditorCapsuleHint =>
      'テンプレートを適用した日から数えます。投稿前に変更することもできます。';

  @override
  String get diaryTemplateEditorRecommend => 'おすすめするタイミング';

  @override
  String get diaryTemplateEditorRecommendHint =>
      '選択したすべてのグループの条件に合うと、このテンプレートが提案の先頭に表示されます。同じグループ内では、いずれか1つに合えば条件を満たします。';

  @override
  String get diaryTemplateEditorSlots => '時間帯';

  @override
  String get diaryTemplateEditorWeekdays => '曜日';

  @override
  String get diaryTemplateEditorMonth => '月内の時期';

  @override
  String get diaryTemplateSlotMorning => '朝';

  @override
  String get diaryTemplateSlotAfternoon => '昼';

  @override
  String get diaryTemplateSlotEvening => '夕方';

  @override
  String get diaryTemplateSlotNight => '深夜';

  @override
  String get diaryTemplateMonthStart => '月初の3日間';

  @override
  String get diaryTemplateMonthEnd => '月末の3日間';

  @override
  String get diaryTemplateSaveAs => 'テンプレートとして保存';

  @override
  String get diaryTemplateSaveAsMediaDropped => '画像や録音などのメディアはテンプレートに保存されません';

  @override
  String get diaryEditorMoreActions => 'その他';

  @override
  String get diaryTemplateChoose => 'テンプレートを選択';

  @override
  String get diaryTemplateNeedsBlankEntry => 'テンプレートは空白の日記にのみ適用できます';

  @override
  String get notebookTitle => '日記帳';

  @override
  String get notebookNew => '新しい日記帳';

  @override
  String get notebookEditTitle => '日記帳を編集';

  @override
  String get notebookManage => '管理';

  @override
  String get notebookSubSectionTitle => 'サブ日記帳';

  @override
  String get notebookSubCreateShort => '新規';

  @override
  String notebookSubMore(int count) {
    return 'ほか$count冊';
  }

  @override
  String get notebookSubMoreHint => 'すべて表示';

  @override
  String notebookSubMoreSemantics(int count) {
    return '残りのサブ日記帳$count冊を表示';
  }

  @override
  String get notebookSubLess => '折りたたむ';

  @override
  String get notebookSubLessSemantics => 'サブ日記帳を折りたたむ';

  @override
  String get notebookSubCreate => 'サブ日記帳を新規作成';

  @override
  String notebookSubCountSemantics(int count) {
    return 'サブ日記帳$count冊を含む';
  }

  @override
  String notebookNestGoUp(String name) {
    return '「$name」に戻る';
  }

  @override
  String get notebookNestPathSeparator => ' › ';

  @override
  String get notebookParentLabel => '親日記帳';

  @override
  String get notebookParentNone => 'なし（本棚に置く）';

  @override
  String get notebookParentFooter =>
      '親日記帳を開くと、この日記帳の日記も表示されます。最大3階層まで。スマート日記帳はほかの日記帳の中に置けますが、サブ日記帳を持つことはできません。';

  @override
  String get notebookParentPickerEmpty =>
      '移動できる日記帳がありません（最大3階層まで、スマート日記帳にはサブ日記帳を入れられません）';

  @override
  String notebookParentPrivacyHidden(String name) {
    return '親日記帳「$name」が「すべての日記」に表示されないため、この日記帳も非表示になります';
  }

  @override
  String notebookParentPrivacyLocked(String name) {
    return '親日記帳「$name」がロックされているため、この日記帳もロックされます';
  }

  @override
  String get notebookNestMove => '移動…';

  @override
  String get notebookNestMoveHint => '別の日記帳の中に入れるか、本棚に戻します';

  @override
  String notebookNestMoved(String name) {
    return '「$name」の中に移動しました';
  }

  @override
  String get notebookNestMovedToShelf => '本棚に戻しました';

  @override
  String notebookNestDeleteChildrenHint(int count) {
    return 'サブ日記帳$count冊は1つ上の階層に移動し、削除されません';
  }

  @override
  String get notebookAllDiaries => 'すべての日記';

  @override
  String get notebookUnfiled => '未分類';

  @override
  String get notebookSectionPinned => 'ピン留め';

  @override
  String get notebookSectionMine => 'マイ日記帳';

  @override
  String get notebookSectionSmart => 'スマート日記帳';

  @override
  String get notebookSectionClosed => '閉じた日記帳';

  @override
  String notebookEntryCount(int count) {
    return '$count件';
  }

  @override
  String get notebookSemanticsSeparator => '、';

  @override
  String get notebookEmptyHint => 'さまざまなテーマや時期の日記を、1冊の日記帳にまとめましょう';

  @override
  String get notebookMissing => 'この日記帳はもう存在しません';

  @override
  String get notebookNameLabel => '名前';

  @override
  String get notebookNameHint => '例：旅行';

  @override
  String get notebookDescriptionLabel => '説明';

  @override
  String get notebookDescriptionHint => 'この日記帳をひと言で紹介（任意）';

  @override
  String get notebookIconLabel => 'アイコン';

  @override
  String get notebookIconMore => 'その他のアイコン';

  @override
  String get notebookIconLess => '折りたたむ';

  @override
  String get notebookColorLabel => '色';

  @override
  String get notebookColorFollowTheme => 'テーマに合わせる';

  @override
  String get notebookCoverLabel => '表紙画像';

  @override
  String get notebookCoverPick => '画像を選択';

  @override
  String get notebookCoverRemove => '削除';

  @override
  String get notebookCoverSectionTitle => '表紙';

  @override
  String get notebookCoverLayoutTitle => 'レイアウト';

  @override
  String get notebookCoverLayoutClassic => 'クラシック';

  @override
  String get notebookCoverLayoutFullBleed => '全面';

  @override
  String get notebookCoverLayoutSpine => '背表紙';

  @override
  String get notebookCoverLayoutPlate => 'ラベル';

  @override
  String get notebookCoverLayoutMinimal => 'ミニマル';

  @override
  String get notebookCoverTextureTitle => 'テクスチャ';

  @override
  String get notebookCoverTextureNone => 'なし';

  @override
  String get notebookCoverTextureDots => 'ドット';

  @override
  String get notebookCoverTextureLines => '罫線';

  @override
  String get notebookCoverTextureGrid => '方眼';

  @override
  String get notebookCoverTextureDiagonal => '斜線';

  @override
  String get notebookCoverFromDiaries => '日記から選ぶ';

  @override
  String get notebookCoverAdjustCrop => '表示範囲を調整';

  @override
  String get notebookCoverCropDone => '完了';

  @override
  String get notebookCoverCropHint => 'ドラッグで移動、ピンチで拡大・縮小';

  @override
  String get notebookCoverCropHintDesktop => 'ドラッグで移動、スクロールで拡大・縮小';

  @override
  String get notebookCoverCropZoom => 'ズーム';

  @override
  String get notebookCoverCropLoadFailed => 'この画像を読み込めませんでした';

  @override
  String get notebookCoverPhotosTitle => '日記から表紙を選ぶ';

  @override
  String get notebookCoverPhotosSubtitle => 'この日記帳（サブ日記帳を含む）の日記で使われている画像（新しい順）';

  @override
  String get notebookCoverPhotosEmpty => 'この日記帳の日記にはまだ画像がありません';

  @override
  String notebookCoverPhotoItem(int index) {
    return '画像$index';
  }

  @override
  String get notebookTypeLabel => '種類';

  @override
  String get notebookTypeManual => '通常';

  @override
  String get notebookTypeSmart => 'スマート';

  @override
  String get notebookTypeManualHint => '追加する日記を自分で選びます';

  @override
  String get notebookTypeSmartHint => '条件に合う日記を自動で集めます';

  @override
  String get notebookPrivacyLabel => 'プライバシー';

  @override
  String get notebookPrivacyNormal => '通常';

  @override
  String get notebookPrivacyHidden => '「すべての日記」に表示しない';

  @override
  String get notebookPrivacyHiddenHint => 'この日記帳の中でのみ表示されます';

  @override
  String get notebookPrivacyLocked => 'ロック';

  @override
  String get notebookPrivacyLockedHint => '開くときに本人確認が必要になり、「すべての日記」にも表示されません';

  @override
  String get notebookSortLabel => 'デフォルトの並び順';

  @override
  String get notebookSortCreatedDesc => '投稿日（新しい順）';

  @override
  String get notebookSortCreatedAsc => '投稿日（古い順）';

  @override
  String get notebookSortCreatedAscHint => '1冊の本のように読めます';

  @override
  String get notebookSortUpdatedDesc => '最近編集した順';

  @override
  String get notebookSortBook => '目次順';

  @override
  String get notebookSortBookHint => '目次で手動で並べた順';

  @override
  String get notebookTemplateLabel => '新規日記のテンプレート';

  @override
  String get notebookTemplateNone => '使用しない';

  @override
  String get notebookSaveFailed => '保存できませんでした。もう一度お試しください。';

  @override
  String get notebookActionFailed => '問題が発生しました。もう一度お試しください。';

  @override
  String get notebookMoreActions => 'その他の操作';

  @override
  String notebookSubCount(int count) {
    return 'サブ日記帳$count冊';
  }

  @override
  String get notebookSubCollapse => 'サブ日記帳を折りたたむ';

  @override
  String get notebookSubExpand => 'サブ日記帳を展開';

  @override
  String get notebookCollapseAll => 'すべて折りたたむ';

  @override
  String get notebookExpandAll => 'すべて展開';

  @override
  String get notebookStatePinned => 'ピン留め';

  @override
  String get notebookStateSmart => 'スマート';

  @override
  String get notebookStateHidden => '非表示';

  @override
  String get notebookStateLocked => 'ロック中';

  @override
  String get notebookStateClosed => '閉じた日記帳';

  @override
  String get notebookActionPin => 'ピン留め';

  @override
  String get notebookActionUnpin => 'ピン留めを解除';

  @override
  String get notebookActionClose => '閉じる';

  @override
  String get notebookActionCloseHint => '本棚の「閉じた日記帳」に移り、日記の追加先に表示されなくなります';

  @override
  String get notebookActionReopen => '再び開く';

  @override
  String get notebookActionMerge => '別の日記帳に統合…';

  @override
  String get notebookActionConvert => '通常の日記帳に変換';

  @override
  String get notebookActionConvertHint => 'いま条件に合う日記を追加し、以降は自動で更新しません';

  @override
  String get notebookMergeSheetTitle => '統合先の日記帳を選択';

  @override
  String get notebookMergeEmpty => '統合先にできる通常の日記帳がほかにありません';

  @override
  String get notebookMergeConfirmTitle => '日記帳を統合';

  @override
  String notebookMergeConfirm(String source, int count, String target) {
    return '「$source」の日記$count件を「$target」に移動し、「$source」を削除しますか？';
  }

  @override
  String get notebookMergeAction => '統合';

  @override
  String notebookMerged(String target) {
    return '「$target」に統合しました';
  }

  @override
  String notebookDeleteTitle(String name) {
    return '「$name」を削除しますか？';
  }

  @override
  String get notebookDeleteKeepDiaries => '日記帳のみ削除';

  @override
  String notebookDeleteKeepDiariesHint(int count) {
    return '日記$count件は「すべての日記」に残ります';
  }

  @override
  String get notebookDeleteWithDiaries => '日記もゴミ箱に移動';

  @override
  String get notebookDeleteWithDiariesHint => 'ゴミ箱から復元できます';

  @override
  String get notebookDeleteSmartHint => '日記には影響しません';

  @override
  String notebookDeleted(String name) {
    return '「$name」を削除しました';
  }

  @override
  String notebookSwitcherSemantics(String name) {
    return '日記帳を切り替え（現在：$name）';
  }

  @override
  String get notebookScopeDeleted => '日記帳が削除されました';

  @override
  String notebookSearchIn(String name) {
    return '「$name」内を検索';
  }

  @override
  String notebookSearchRemoveScope(String name) {
    return '日記帳の条件を削除：$name';
  }

  @override
  String notebookMetaWords(String words) {
    return '$words文字';
  }

  @override
  String notebookMetaSpan(String start, String end) {
    return '$start – $end';
  }

  @override
  String notebookMetaSpanOngoing(String start) {
    return '$start – 現在';
  }

  @override
  String get notebookHeaderSmartBadge => 'スマート日記帳';

  @override
  String get notebookHeaderPrivateBadge => 'この日記帳でのみ表示';

  @override
  String get notebookEmptyTitle => 'この日記帳はまだ空です';

  @override
  String get notebookEmptyCreateHint => '下のボタンをタップして、最初の日記を書きましょう';

  @override
  String get notebookViewSortSection => 'この日記帳での並び順';

  @override
  String get notebookViewOptionsEntry => '日記帳を切り替え';

  @override
  String get notebookViewOptionsEntrySubtitle =>
      '1冊の日記帳の日記だけを表示するか、新しい日記帳を作成します';

  @override
  String notebookUnlockReason(String name) {
    return '「$name」のロックを解除';
  }

  @override
  String get notebookLockUnsupportedTitle => 'ロックされた日記帳を開けません';

  @override
  String get notebookLockUnsupportedMessage =>
      'このデバイスには画面ロックが設定されていないため、本人確認ができず、ロックされた日記帳を開けません。システム設定で画面ロックを設定するか、設定 → アプリロックとパスコード でアプリのパスコードに切り替えると開けるようになります。';

  @override
  String get notebookLockUnsupportedAction => 'わかりました';

  @override
  String notebookLockedTitle(String name) {
    return '「$name」はロックされています';
  }

  @override
  String get notebookLockedSubtitle => 'アプリを離れたあとは、もう一度本人確認が必要です';

  @override
  String get notebookLockUnlock => 'ロックを解除';

  @override
  String get notebookLockBackToAll => 'すべての日記に戻る';

  @override
  String get notebookPrivateDiaryPlaceholder => 'プライベート日記帳の日記';

  @override
  String get notebookAnniversaryLinkPrivate => 'リンク先の日記はプライベート日記帳にあります';

  @override
  String get backupImportFolderModeTitle => '元のノートブック / フォルダ';

  @override
  String get backupImportFolderModeNotebooks => '日記帳';

  @override
  String get backupImportFolderModeTags => 'タグ';

  @override
  String get backupImportFolderModeBoth => '両方';

  @override
  String backupImportFolderModeNotebooksHint(int count) {
    return '取り込み元のノートブック / フォルダ$count個を日記帳として作成します。同じ名前のものは既存の日記帳に統合されます';
  }

  @override
  String get backupImportFolderModeTagsHint => 'これまでどおり、同じ名前のタグになります';

  @override
  String get backupImportFolderModeBothHint => '日記帳と、同じ名前のタグを両方作成します';

  @override
  String get notebookEmptyManualHint => '最初の日記を書くか、既存の日記からいくつか選んで追加しましょう';

  @override
  String get notebookEmptyWriteFirst => '最初の日記を書く';

  @override
  String get notebookEmptyPickExisting => '既存の日記から選ぶ';

  @override
  String get notebookAddDiaries => '日記を追加';

  @override
  String get notebookExportAsBook => '本としてエクスポート';

  @override
  String notebookBookExportedOn(String date) {
    return 'エクスポート日：$date';
  }

  @override
  String get diaryExportBookStructure => '本の構成';

  @override
  String get diaryExportBookStructureDescription => '扉、目次、章見出し';

  @override
  String get notebookContentsUnassignedDropHint => 'ここにドラッグすると章から外れます';

  @override
  String get notebookChapterAll => 'すべて';

  @override
  String get notebookChapterUnassigned => '章なし';

  @override
  String notebookChapterChip(String title, int count) {
    return '$title · $count';
  }

  @override
  String get notebookContents => '目次';

  @override
  String get notebookContentsNewChapter => '新しい章';

  @override
  String get notebookContentsSelect => '選択';

  @override
  String get notebookContentsSelectDone => '選択を終了';

  @override
  String notebookContentsSelectedCount(int count) {
    return '$count件を選択中';
  }

  @override
  String get notebookContentsNoChapterHint => '章を追加して、この日記帳をいくつかのパートに分けましょう';

  @override
  String get notebookContentsEmpty => 'この日記帳にはまだ日記がありません';

  @override
  String get notebookContentsArchived => 'アーカイブ済み';

  @override
  String get notebookContentsSealed => '未開封のタイムカプセル';

  @override
  String get notebookContentsChapterActions => '章の操作';

  @override
  String get notebookChapterRename => '名前を変更';

  @override
  String get notebookChapterRenameTitle => '章の名前を変更';

  @override
  String get notebookChapterMoveUp => '上へ移動';

  @override
  String get notebookChapterMoveDown => '下へ移動';

  @override
  String get notebookChapterCollapse => '章を折りたたむ';

  @override
  String get notebookChapterExpand => '章を展開';

  @override
  String get notebookChapterTitleLabel => '章の名前';

  @override
  String get notebookChapterTitleHint => '例：東京';

  @override
  String notebookChapterDeleteConfirm(String title, int count) {
    return '章「$title」を削除しますか？含まれる日記$count件は「章なし」に戻ります。日記は削除されません。';
  }

  @override
  String get notebookContentsMoveToChapter => '章に移動…';

  @override
  String get notebookContentsMoveSheetTitle => '章に移動';

  @override
  String notebookContentsMoved(String title, int count) {
    return '日記$count件を「$title」に移動しました';
  }

  @override
  String get notebookPickerTitle => '日記帳に追加';

  @override
  String get notebookPickerEmpty => '追加できる日記帳がまだありません';

  @override
  String get notebookPickerDone => '完了';

  @override
  String notebookPickerPrivateHint(String name) {
    return '「$name」に追加しました。これらの日記はその日記帳の中でのみ表示されます';
  }

  @override
  String get notebookSelectionMore => 'その他の操作';

  @override
  String get notebookRemoveFromCurrent => 'この日記帳から外す';

  @override
  String get notebookMoveTo => '別の日記帳に移動…';

  @override
  String notebookAddedToCount(int count) {
    return '$count冊の日記帳に追加しました';
  }

  @override
  String get notebookMembershipUpdated => '日記帳を更新しました';

  @override
  String notebookRemovedFrom(String name, int count) {
    return '「$name」から日記$count件を外しました';
  }

  @override
  String notebookMovedTo(String name, int count) {
    return '日記$count件を「$name」に移動しました';
  }

  @override
  String get notebookPublishNone => '日記帳なし';

  @override
  String notebookWriteInto(String name) {
    return '「$name」に書く';
  }

  @override
  String notebookAddPageTitle(String name) {
    return '「$name」に追加';
  }

  @override
  String notebookAddPageDone(int count) {
    return '完了（$count）';
  }

  @override
  String get notebookAddSearchHint => '日記を検索';

  @override
  String get notebookAddFilterAll => 'すべて';

  @override
  String get notebookAddFilterRecent => '過去30日';

  @override
  String get notebookAddFilterThisYear => '今年';

  @override
  String get notebookAddAlreadyIn => 'この日記帳に追加済み';

  @override
  String notebookAddedCount(int count) {
    return '日記$count件を追加しました';
  }

  @override
  String get notebookAddEmpty => '一致する日記がありません';

  @override
  String get notebookPreviewNone => 'まだどの日記帳にも入っていません';

  @override
  String get notebookListSeparator => '、';

  @override
  String notebookOpenNotebook(String name) {
    return '「$name」を開く';
  }

  @override
  String get notebookRulesTitle => '条件';

  @override
  String get notebookRulesMatchAll => 'すべてに一致';

  @override
  String get notebookRulesMatchAny => 'いずれかに一致';

  @override
  String notebookRulesMatchCount(int count) {
    return '一致する日記：$count件';
  }

  @override
  String get notebookRulesNeedOne => '保存するには、条件を1つ以上追加してください';

  @override
  String notebookRulesLimit(int max) {
    return '条件は最大$max個まで';
  }

  @override
  String get notebookRulesExamples => '例から始める';

  @override
  String get notebookRuleExampleRecent => '過去30日';

  @override
  String get notebookRuleExampleThisMonth => '毎年の今月';

  @override
  String get notebookRuleExampleImages => '写真のある日記';

  @override
  String get notebookRuleExamplePinned => 'ピン留めした日記';

  @override
  String get notebookRuleAdd => '条件を追加';

  @override
  String get notebookRuleRemove => '条件を削除';

  @override
  String get notebookRuleDone => '完了';

  @override
  String get notebookRuleTypeTags => 'タグ';

  @override
  String get notebookRuleTypeTagsHint => '特定のタグを含む、または含まない';

  @override
  String get notebookRuleTypeMood => '気分';

  @override
  String get notebookRuleTypeMoodHint => '気分が指定したもののいずれか';

  @override
  String get notebookRuleTypeWeather => '天気';

  @override
  String get notebookRuleTypeWeatherHint => '天気に特定の文字を含む';

  @override
  String get notebookRuleTypeLocation => '場所';

  @override
  String get notebookRuleTypeLocationHint => '場所に特定の文字を含む';

  @override
  String get notebookRuleTypeKeyword => 'キーワード';

  @override
  String get notebookRuleTypeKeywordHint => 'タイトルや本文に特定の語句を含む';

  @override
  String get notebookRuleTypeDate => '日付';

  @override
  String get notebookRuleTypeDateHint => '期間、最近の日数、または毎年の特定の時期';

  @override
  String get notebookRuleTypeMedia => 'メディア';

  @override
  String get notebookRuleTypeMediaHint => '写真、録音、動画、添付ファイルを含む';

  @override
  String get notebookRuleTypeFlag => '表紙とピン留め';

  @override
  String get notebookRuleTypeFlagHint => '表紙がある、またはピン留めされている';

  @override
  String get notebookRuleTagAny => 'いずれかを含む';

  @override
  String get notebookRuleTagAll => 'すべて含む';

  @override
  String get notebookRuleTagNone => 'いずれも含まない';

  @override
  String get notebookRuleNoTags => 'タグがまだありません';

  @override
  String get notebookRuleWeatherHint => '例：雨';

  @override
  String get notebookRuleLocationHint => '例：京都';

  @override
  String get notebookRuleKeywordHint => 'タイトルや本文の語句';

  @override
  String get notebookRuleDateBetween => '期間指定';

  @override
  String get notebookRuleDateLastDays => '最近の日数';

  @override
  String get notebookRuleDateThisYear => '今年';

  @override
  String get notebookRuleDateMonth => '毎年の特定の月';

  @override
  String get notebookRuleDateToday => '毎年の今日';

  @override
  String get notebookRuleDateTodayHint => 'どの年でも、今日と同じ月日の日記';

  @override
  String notebookRuleDaysValue(int days) {
    return '$days日';
  }

  @override
  String get notebookRuleDaysDecrease => '1日減らす';

  @override
  String get notebookRuleDaysIncrease => '1日増やす';

  @override
  String get notebookRuleMediaImage => '写真あり';

  @override
  String get notebookRuleMediaAudio => '録音あり';

  @override
  String get notebookRuleMediaVideo => '動画あり';

  @override
  String get notebookRuleMediaAttachment => '添付ファイルあり';

  @override
  String get notebookRuleFlagCover => '表紙あり';

  @override
  String get notebookRuleFlagPinned => 'ピン留め済み';

  @override
  String notebookRuleSummaryTagsAny(String tags) {
    return 'タグ（いずれかを含む）：$tags';
  }

  @override
  String notebookRuleSummaryTagsAll(String tags) {
    return 'タグ（すべて含む）：$tags';
  }

  @override
  String notebookRuleSummaryTagsNone(String tags) {
    return 'タグ（いずれも含まない）：$tags';
  }

  @override
  String notebookRuleSummaryMood(String moods) {
    return '気分：$moods';
  }

  @override
  String notebookRuleSummaryWeather(String text) {
    return '天気に「$text」を含む';
  }

  @override
  String notebookRuleSummaryLocation(String text) {
    return '場所に「$text」を含む';
  }

  @override
  String notebookRuleSummaryKeyword(String text) {
    return 'タイトルや本文に「$text」を含む';
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
      other: '過去$days日',
      one: '今日',
    );
    return '$_temp0';
  }

  @override
  String notebookRuleSummaryMonth(int month, String monthName) {
    return '毎年$month月';
  }

  @override
  String notebookRuleSummaryToday(String date) {
    return '毎年の今日（$date）';
  }

  @override
  String get notebookRuleUnknown => '認識できない条件（新しいバージョンで作成）';

  @override
  String notebookConvertTitle(String name) {
    return '「$name」を通常の日記帳に変換しますか？';
  }

  @override
  String notebookConvertMessage(int count) {
    return 'いま条件に合う日記$count件（アーカイブ済みを除く）が追加され、以降は自動で更新されなくなります。';
  }

  @override
  String get notebookConvertAction => '変換';

  @override
  String notebookConverted(int count) {
    return '変換しました（日記$count件を追加）';
  }

  @override
  String get notebookSaveRange => '日記帳として保存';

  @override
  String get notebookSaveRangeSmartHint => 'この期間の日記を集めます。あとから書き足した日記も自動で追加されます';

  @override
  String notebookSaveRangeManualHint(int count) {
    return 'いまある日記$count件を追加します';
  }

  @override
  String get notebookSaveSearchAsSmart => 'スマート日記帳として保存';

  @override
  String get notebookSaveRangeSmart => 'スマート日記帳';

  @override
  String get notebookSaveRangeManual => '通常の日記帳';

  @override
  String get notebookGoalLabel => '執筆目標';

  @override
  String get notebookGoalEnable => '目標を設定';

  @override
  String get notebookGoalEnableHint => '日記帳のヘッダーに進捗を表示します。リマインダーは送信されません。';

  @override
  String get notebookGoalDecrease => '1件減らす';

  @override
  String get notebookGoalIncrease => '1件増やす';

  @override
  String get notebookGoalPeriodDay => '毎日';

  @override
  String get notebookGoalPeriodWeek => '毎週';

  @override
  String get notebookGoalPeriodMonth => '毎月';

  @override
  String notebookGoalSummaryDay(int count) {
    return '1日$count件';
  }

  @override
  String notebookGoalSummaryWeek(int count) {
    return '週$count件';
  }

  @override
  String notebookGoalSummaryMonth(int count) {
    return '月$count件';
  }

  @override
  String notebookGoalProgressDay(int current, int target) {
    return '今日：$current / $target件';
  }

  @override
  String notebookGoalProgressWeek(int current, int target) {
    return '今週：$current / $target件';
  }

  @override
  String notebookGoalProgressMonth(int current, int target) {
    return '今月：$current / $target件';
  }

  @override
  String get notebookGoalMetDay => '今日は達成 ✓';

  @override
  String get notebookGoalMetWeek => '今週は達成 ✓';

  @override
  String get notebookGoalMetMonth => '今月は達成 ✓';

  @override
  String notebookGoalStreakDay(int count) {
    return '$count日連続達成';
  }

  @override
  String notebookGoalStreakWeek(int count) {
    return '$count週連続達成';
  }

  @override
  String notebookGoalStreakMonth(int count) {
    return '$countか月連続達成';
  }

  @override
  String get notebookInsights => '統計';

  @override
  String get notebookInsightsEmpty => 'この日記帳にはまだ集計できる日記がありません';

  @override
  String get notebookInsightsEntries => '日記数';

  @override
  String get notebookInsightsWords => '文字数';

  @override
  String get notebookInsightsRecordedDays => '記録日数';

  @override
  String get notebookInsightsSpan => '期間';

  @override
  String get notebookInsightsPhotos => '写真';

  @override
  String get notebookInsightsLongestStreak => '最長連続記録';

  @override
  String notebookInsightsDays(int count) {
    return '$count日';
  }

  @override
  String notebookInsightsSpanMonths(int months) {
    return '$monthsか月';
  }

  @override
  String notebookInsightsSpanYears(int years) {
    return '$years年';
  }

  @override
  String notebookInsightsSpanYearsMonths(int years, int months) {
    return '$years年$monthsか月';
  }

  @override
  String get notebookInsightsMoods => '気分の分布';

  @override
  String notebookInsightsMoodShare(int count, int percent) {
    return '$count件 · $percent%';
  }

  @override
  String get notebookInsightsTopTags => 'よく使うタグ';

  @override
  String get notebookInsightsRhythm => '執筆のリズム';

  @override
  String notebookInsightsRhythmBar(String month, int count) {
    return '$month：$count件';
  }

  @override
  String notebookInsightsGoalRecent(int met, int total) {
    return '直近$total期間のうち$met回達成';
  }

  @override
  String notebookInsightsGoalRecentCaption(int count) {
    return '直近$count期間';
  }

  @override
  String get notebookInsightsRandom => 'ランダムに1件開く';

  @override
  String get diaryColorPanelDefaultColor => 'デフォルトの色';

  @override
  String get diaryColorPanelNoBackground => '背景色なし';

  @override
  String get diaryColorPanelCustom => 'カスタム';

  @override
  String get diaryColorPanelEnterCode => 'カラーコードを入力';

  @override
  String get diaryColorPanelHexHint => 'RRGGBB';

  @override
  String get diaryColorPanelSwatches => 'パレット';

  @override
  String get diaryColorPanelSaturationValue => '彩度と明度';

  @override
  String get diaryColorPanelHue => '色相';

  @override
  String get diaryColorPanelOpacity => '不透明度';

  @override
  String get diaryColorRed => '赤';

  @override
  String get diaryColorOrange => 'オレンジ';

  @override
  String get diaryColorYellow => '黄';

  @override
  String get diaryColorGreen => '緑';

  @override
  String get diaryColorTeal => '青緑';

  @override
  String get diaryColorBlue => '青';

  @override
  String get diaryColorIndigo => 'インディゴ';

  @override
  String get diaryColorPurple => '紫';

  @override
  String get diaryColorPink => 'ピンク';

  @override
  String get diaryColorBrown => '茶';

  @override
  String get diaryColorGray => 'グレー';

  @override
  String get diaryColorPanelMaterial => 'Material';

  @override
  String get diaryColorDeepPurple => '濃い紫';

  @override
  String get diaryColorLightBlue => '水色';

  @override
  String get diaryColorCyan => 'シアン';

  @override
  String get diaryColorLightGreen => '黄緑';

  @override
  String get diaryColorLime => 'ライム';

  @override
  String get diaryColorAmber => 'アンバー';

  @override
  String get diaryColorDeepOrange => '濃いオレンジ';

  @override
  String get diaryColorBlueGray => 'ブルーグレー';

  @override
  String get diaryColorWhite => '白';

  @override
  String get diaryColorBlack => '黒';

  @override
  String diaryColorShade(String family, String tone) {
    return '$family $tone';
  }

  @override
  String diaryColorPanelFamily(String family) {
    return '$family系の色';
  }

  @override
  String get tagPickerSearchHint => 'タグを検索';

  @override
  String get tagPickerSortTooltip => '並び順';

  @override
  String get tagPickerSortCustom => 'デフォルトの並び順';

  @override
  String get tagPickerSortAlphabetical => '名前順';

  @override
  String tagPickerCreateNamed(String name) {
    return '「$name」を作成';
  }

  @override
  String tagPickerSearchEmpty(String query) {
    return '「$query」に一致するタグはありません';
  }

  @override
  String get settingsFeaturesTitle => '機能管理';

  @override
  String get settingsFeaturesSubtitle => '使うページと機能を選びます';

  @override
  String get settingsFeaturesPagesGroup => 'ページ';

  @override
  String get settingsFeaturesPagesFooter =>
      '「日記」と「設定」は常に表示されます。オフにしたページは下部のナビゲーションバーから消えますが、データには影響しません。';

  @override
  String get settingsFeaturesCalendarSubtitle => '月ごとに日記を表示。旧暦・祝日・記念日も確認できます';

  @override
  String get settingsFeaturesExploreSubtitle => '統計、過去の今日、気分の推移、フォトウォール';

  @override
  String get settingsFeaturesFeaturesGroup => '日記の機能';

  @override
  String get settingsFeaturesFeaturesFooter =>
      'オフにすると、関連するメニューやオプションが非表示になります。データは保持され、再びオンにすると元に戻ります。';

  @override
  String get settingsFeaturesNotebooksSubtitle =>
      '日記を日記帳に分類。章分けや本としてのエクスポートもできます';

  @override
  String get settingsFeaturesAnniversaries => '記念日';

  @override
  String get settingsFeaturesAnniversariesSubtitle => '記念日とカウントダウンをカレンダーに表示';

  @override
  String get settingsFeaturesTemplates => '日記テンプレート';

  @override
  String get settingsFeaturesTemplatesSubtitle => '用意した書式から新しい日記を書き始めます';

  @override
  String get settingsFeaturesTimeCapsules => 'タイムカプセル';

  @override
  String get settingsFeaturesTimeCapsulesSubtitle =>
      '未来の自分に向けて書き、その日が来るまで開けません';

  @override
  String get settingsFeaturesSwipeArchive => 'スワイプでアーカイブ';

  @override
  String get settingsFeaturesSwipeArchiveSubtitle =>
      '日記カードを左にスワイプしてアーカイブ。「アーカイブ」ページで左にスワイプすると元に戻ります';

  @override
  String get settingsFeaturesNotebooksOffTitle => '日記帳をオフにしますか？';

  @override
  String settingsFeaturesNotebooksOffMessage(int count) {
    return '非表示またはロック中の日記帳が$count冊あります。日記帳を再びオンにするまで、その中の日記は表示されません。';
  }

  @override
  String get settingsFeaturesNotebooksOffConfirm => 'オフにする';

  @override
  String get supportDeveloperTitle => '開発者を支援';

  @override
  String get supportDeveloperEntrySubtitle => 'WeChat または Alipay でチップを送る';

  @override
  String get supportDeveloperIntro =>
      'Jotsy は無料のオープンソースアプリで、広告もありません。役に立ったと感じたら、チップで応援していただけるとうれしいです。チップは完全に任意で、何かの機能が解放されることはありません。';

  @override
  String get supportDeveloperWeChat => 'WeChat';

  @override
  String get supportDeveloperAlipay => 'Alipay';

  @override
  String get supportDeveloperWeChatCodeLabel => 'WeChat のチップ用コード';

  @override
  String get supportDeveloperAlipayCodeLabel => 'Alipay の支払い用コード';

  @override
  String get supportDeveloperWeChatHint =>
      'コードを写真に保存してから WeChat の「スキャン」を開き、右上のアルバムからこの画像を選んでください。';

  @override
  String get supportDeveloperAlipayHint =>
      '下のボタンをタップすると Alipay で直接支払えます。コードを保存して、Alipay の「スキャン」で写真から選ぶこともできます。';

  @override
  String get supportDeveloperSaveCode => '写真に保存';

  @override
  String get supportDeveloperOpenWeChat => 'WeChat を開く';

  @override
  String get supportDeveloperOpenAlipay => 'Alipay で支払う';

  @override
  String get supportDeveloperAlipayUnavailable =>
      'Alipay を開けませんでした。コードを保存して、Alipay が入ったスマートフォンでスキャンしてください。';

  @override
  String get supportDeveloperWeChatUnavailable =>
      'WeChat を開けませんでした。WeChat を手動で開いて、コードをスキャンしてください。';

  @override
  String get diaryColorPanelNewColor => '新しい色';

  @override
  String get diaryColorPanelManageColors => 'マイカラーを管理';

  @override
  String get diaryColorPanelManageDone => '完了';

  @override
  String get diaryColorPanelSavedEmpty => '「カスタム」で作った色はここに保存されます';

  @override
  String get diaryColorPanelSavedMark => '保存済み';

  @override
  String diaryColorPanelSavedColor(String color) {
    return 'マイカラー $color';
  }

  @override
  String diaryColorPanelDocumentColor(String color) {
    return 'この日記で使った色 $color';
  }

  @override
  String diaryColorPanelRemoveColor(String color) {
    return '$color を削除';
  }

  @override
  String diaryColorPanelKeepColor(String color) {
    return '$color をマイカラーに保存';
  }

  @override
  String get homeBarStyleTitle => 'ナビゲーションバーのスタイル';

  @override
  String homeBarStyleEntrySubtitle(String name) {
    return '現在：$name';
  }

  @override
  String homeBarStyleCustomName(String material) {
    return '$material（カスタム）';
  }

  @override
  String get homeBarStyleTabPresets => 'プリセット';

  @override
  String get homeBarStyleTabMaterial => '素材';

  @override
  String get homeBarStyleTabFloating => 'フローティングバー';

  @override
  String get homeBarStyleTabItems => '項目';

  @override
  String get homeBarStyleTabBehavior => '動作';

  @override
  String get homeBarStylePresetClassic => 'クラシック';

  @override
  String get homeBarStylePresetClassicDesc => 'リニューアル前の単色のボトムバー';

  @override
  String get homeBarStylePresetGlass => 'ガラス';

  @override
  String get homeBarStylePresetGlassDesc => 'すりガラスのフローティングバー。選択中の項目は塗りつぶしで表示';

  @override
  String get homeBarStylePresetClear => 'クリア';

  @override
  String get homeBarStylePresetClearDesc => '影のない、より透明なガラス';

  @override
  String get homeBarStylePresetFrosted => 'ミスト';

  @override
  String get homeBarStylePresetFrostedDesc => 'すりガラスを濃くして、文字を最も読みやすく';

  @override
  String get homeBarStylePresetTinted => 'テーマカラー';

  @override
  String get homeBarStylePresetTintedDesc => 'テーマカラーをほんのり加えたガラス';

  @override
  String get homeBarStylePresetCompact => 'コンパクト';

  @override
  String get homeBarStylePresetCompactDesc => 'アイコンだけの、低めのフローティングバー';

  @override
  String get homeBarStyleMaterialSolid => '単色';

  @override
  String get homeBarStyleMaterialGlass => 'ガラス';

  @override
  String get homeBarStyleGlassFooter =>
      'ガラスでは、ボトムバーがページの上に浮かび、その下をスクロールするコンテンツがぼやけて透けて見えます。';

  @override
  String get homeBarStyleHighContrastNote =>
      'システム設定でハイコントラストがオンになっているため、ガラスは現在不透明で表示されています。';

  @override
  String get homeBarStyleGlassTopBars => 'トップバーもガラスにする';

  @override
  String get homeBarStyleGlassTopBarsSubtitle =>
      '「日記」「カレンダー」「探索」「設定」のトップバーもすりガラスになります';

  @override
  String get homeBarStyleTopBarHairline => 'トップバーの区切り線';

  @override
  String get homeBarStyleTopBarHairlineSubtitle => 'ガラスのトップバーの下端に細い線を表示';

  @override
  String get homeBarStyleBlur => 'ぼかし';

  @override
  String get homeBarStyleOpacity => '不透明度';

  @override
  String get homeBarStyleTint => '色合い';

  @override
  String get homeBarStyleTintNeutral => 'ニュートラル';

  @override
  String get homeBarStyleTintTheme => 'テーマカラー';

  @override
  String get homeBarStyleTintColor => 'ガラスの色';

  @override
  String get homeBarStyleBorder => 'ボトムバーの枠線';

  @override
  String get homeBarStyleBorderSubtitle => 'フローティングバーの縁に細い線を表示';

  @override
  String get homeBarStyleOutlineGroup => '枠線';

  @override
  String get homeBarStyleLineColor => '色';

  @override
  String get homeBarStyleLineColorTheme => 'デフォルト';

  @override
  String get homeBarStyleLineColorHighlight => 'ハイライト';

  @override
  String get homeBarStyleLineColorPrimary => 'アクセント';

  @override
  String get homeBarStyleLineCustomColor => '線の色';

  @override
  String get homeBarStyleLineWidth => '太さ';

  @override
  String get homeBarStyleShadow => '影';

  @override
  String get homeBarStyleShadowSubtitle => 'フローティングバーの下にやわらかい影を表示';

  @override
  String get homeBarStyleFloatingSolidHint => 'フローティングバーはガラス素材でのみ使用されます。';

  @override
  String get homeBarStyleSwitchToGlass => 'ガラスに切り替え';

  @override
  String get homeBarStyleSizeGroup => 'サイズ';

  @override
  String get homeBarStyleHeight => '高さ';

  @override
  String get homeBarStyleCornerRadius => '角の丸み';

  @override
  String get homeBarStyleSideMargin => '左右の余白';

  @override
  String get homeBarStyleBottomGap => '下端からの距離';

  @override
  String get homeBarStyleFabGroup => '新規作成ボタン';

  @override
  String get homeBarStyleFabAbove => 'バーの上';

  @override
  String get homeBarStyleFabInline => 'バーの横';

  @override
  String get homeBarStyleFabFooter =>
      '「日記」ページでのみ表示されます。バーの横に置くと、アイコンだけが表示されます。';

  @override
  String get homeBarStyleLabels => 'ラベル';

  @override
  String get homeBarStyleLabelsAlways => '常に表示';

  @override
  String get homeBarStyleLabelsSelected => '選択中のみ';

  @override
  String get homeBarStyleLabelsNever => '非表示';

  @override
  String get homeBarStyleIconSize => 'アイコンのサイズ';

  @override
  String get homeBarStyleLabelGap => 'アイコンとラベルの間隔';

  @override
  String get homeBarStyleIndicator => '選択インジケーター';

  @override
  String get homeBarStyleIndicatorCapsule => 'カプセル';

  @override
  String get homeBarStyleIndicatorBlock => 'ブロック';

  @override
  String get homeBarStyleIndicatorNone => 'なし';

  @override
  String get homeBarStyleBlockPadding => 'ブロックの内側余白';

  @override
  String get homeBarStyleItemsFooter => 'ガラスに切り替えると、アイコンとラベルの間隔が少し狭くなります。';

  @override
  String get homeBarStyleBehaviorFooter => '動作はプリセットやスタイルコードでは変わりません。';

  @override
  String get homeBarStyleHideOnScroll => '下にスクロールするとバーを隠す';

  @override
  String get homeBarStyleHideOnScrollSubtitle =>
      '下にスクロールするとバーが隠れて表示領域が広がり、上にスクロールするか先頭に戻ると再び表示されます';

  @override
  String get homeBarStyleHideOnScrollSolidHint =>
      'スクロール時にバーを隠す機能は、ガラスのフローティングバーでのみ使用できます。';

  @override
  String get homeBarStyleIndicatorFollows => 'インジケーターをスワイプに追従';

  @override
  String get homeBarStyleIndicatorFollowsSubtitle =>
      '左右にスワイプしてページを切り替えるとき、選択インジケーターが指の動きに合わせて移動します';

  @override
  String get codeBlockPanelTitle => 'コードブロック';

  @override
  String get codeBlockLanguageAuto => '自動検出';

  @override
  String codeBlockLanguageAutoDetected(String language) {
    return '自動 · $language';
  }

  @override
  String get codeBlockLanguageNone => '指定なし';

  @override
  String get codeBlockLanguagePlain => 'プレーンテキスト';

  @override
  String get codeBlockLabelGeneric => 'コード';

  @override
  String get codeBlockCopy => 'コードをコピー';

  @override
  String get codeBlockCopied => 'コードをコピーしました';

  @override
  String codeBlockCopySemantics(String language) {
    return '$language のコードをコピー';
  }

  @override
  String get codeBlockExit => 'コードブロックを抜ける';

  @override
  String get codeBlockToText => '本文に変換';

  @override
  String get codeBlockStyleTitle => 'コードブロックのスタイル';

  @override
  String get codeBlockStyleSubtitle => '配色テーマ、行番号、フォント、ヘッダー';

  @override
  String get codeBlockStyleTabTheme => '配色';

  @override
  String get codeBlockStyleTabDisplay => '表示';

  @override
  String get codeBlockStyleTabFont => 'フォント';

  @override
  String get codeBlockThemeFollowApp => 'アプリに合わせる';

  @override
  String get codeBlockBrightnessTitle => '明暗';

  @override
  String get codeBlockBrightnessSystem => 'テーマに合わせる';

  @override
  String get codeBlockBrightnessLight => 'ライト';

  @override
  String get codeBlockBrightnessDark => 'ダーク';

  @override
  String get codeBlockLineNumbersTitle => '行番号';

  @override
  String get codeBlockLineNumbersSubtitle => 'コードの各行の左に行番号を表示';

  @override
  String get codeBlockHeaderTitle => 'ヘッダーバー';

  @override
  String get codeBlockHeaderSubtitle => '上部に言語名とコピーボタンを表示';

  @override
  String get codeBlockAutoDetectTitle => '言語を自動検出';

  @override
  String get codeBlockAutoDetectSubtitle =>
      '言語が指定されていないコードブロックの言語を推測してハイライトします';

  @override
  String get codeBlockBorderTitle => '枠線';

  @override
  String get codeBlockBorderSubtitle => 'コードブロックを細い枠線で囲みます';

  @override
  String get codeBlockRadiusTitle => '角の丸み';

  @override
  String get codeBlockFontTitle => 'コードのフォント';

  @override
  String get codeBlockFontMono => 'システムの等幅フォント';

  @override
  String get codeBlockFontBody => '本文のフォント';

  @override
  String get codeBlockFontMissing =>
      '選択したフォントのファイルがこのデバイスにないため、コードは一時的にシステムの等幅フォントで表示されています。「本文のフォントとレイアウト」で再度インポートするか、別のフォントを選んでください。';

  @override
  String get codeBlockFontSizeTitle => '文字サイズ';

  @override
  String codeBlockFontSizeValue(int percent) {
    return '$percent%';
  }

  @override
  String get codeBlockLineHeightTitle => '行間';

  @override
  String get codeBlockPreviewIntro =>
      'コードブロックは言語に応じてハイライトされ、インラインコードも配色に従います。例： ';

  @override
  String get diaryEditorLinkUrl => 'リンク URL';

  @override
  String get diaryEditorInvalidLink => '有効なリンク URL を入力してください';

  @override
  String get diaryEditorRemoveLink => 'リンクを削除';

  @override
  String get diaryEditorDragBlock => 'ブロックをドラッグ';

  @override
  String get diaryEditorDragBlockHold => '長押ししてドラッグ';

  @override
  String get diaryEditorDragBlockTip =>
      '「長押ししてドラッグ」を押したまま上下にスライドすると、ブロックが一緒に移動します。左側のハンドルを長押ししても移動できます。';

  @override
  String get diaryEditorMoveBlockUp => 'ブロックを上へ移動';

  @override
  String get diaryEditorMoveBlockDown => 'ブロックを下へ移動';

  @override
  String get diaryEditorParagraph => '本文';

  @override
  String get diaryEditorIndent => 'インデント';

  @override
  String get diaryEditorOutdent => 'インデント解除';

  @override
  String get diaryEditorSlashCommands => 'ブロックを挿入';

  @override
  String get diaryEditorDivider => '区切り線';

  @override
  String get diaryEditorCallout => 'コールアウト';

  @override
  String get diaryCalloutPlaceholder => 'コールアウト';

  @override
  String get diaryCalloutToText => '本文に変換';

  @override
  String get diaryCalloutToneDefault => 'デフォルト';

  @override
  String get diaryCalloutToneYellow => '黄色';

  @override
  String get diaryCalloutToneGreen => '緑';

  @override
  String get diaryCalloutToneBlue => '青';

  @override
  String get diaryCalloutToneRed => '赤';

  @override
  String get diaryCalloutTonePurple => '紫';

  @override
  String get diaryEditorUnsupportedBlock => '未対応のコンテンツ';

  @override
  String get diaryEditorToggleList => '折りたたみ';

  @override
  String get diaryToggleListPlaceholder => '折りたたみ';

  @override
  String get diaryToggleExpand => '展開';

  @override
  String get diaryToggleCollapse => '折りたたむ';

  @override
  String get diaryEditorImageWidth => '画像の幅';

  @override
  String get diaryEditorImageHeight => '画像の高さ';

  @override
  String get diaryEditorHeading1 => '見出し1';

  @override
  String get diaryEditorHeading2 => '見出し2';

  @override
  String get diaryEditorHeading3 => '見出し3';

  @override
  String get diaryEditorHeading4 => '見出し4';

  @override
  String get diaryEditorHeading5 => '見出し5';

  @override
  String get diaryEditorHeading6 => '見出し6';

  @override
  String get diaryToolbarAlign => '配置';

  @override
  String get diaryToolbarFontSize => '文字サイズ';

  @override
  String get diaryToolbarSuperscript => '上付き文字';

  @override
  String get diaryToolbarSubscript => '下付き文字';

  @override
  String get diaryHeadingPanelTitle => '見出し';

  @override
  String get diaryHeadingPanelBody => '本文';

  @override
  String get diaryAlignLeft => '左揃え';

  @override
  String get diaryAlignCenter => '中央揃え';

  @override
  String get diaryAlignRight => '右揃え';

  @override
  String get diaryAlignJustify => '両端揃え';

  @override
  String get diaryFontSizeSmall => '小';

  @override
  String get diaryFontSizeNormal => '標準';

  @override
  String get diaryFontSizeLarge => '大';

  @override
  String get diaryFontSizeHuge => '特大';

  @override
  String get diaryEditorCommandGroupText => 'テキスト';

  @override
  String get diaryEditorCommandGroupList => 'リスト';

  @override
  String get diaryEditorCommandGroupInsert => '挿入';

  @override
  String get diaryEditorCommandEmpty => '一致するブロックはありません';

  @override
  String get diaryEditorEmptyLineHint => '/ を入力してブロックを挿入';

  @override
  String get diaryEditorCommandTypeToFilter => '続けて入力すると絞り込めます';

  @override
  String get diaryCardMenuMoveToNotebook => '日記帳に移動…';

  @override
  String get diaryCardMenuAddToNotebook => '日記帳に追加…';

  @override
  String get diaryEditorDropToInsert => 'ドロップして挿入';

  @override
  String get dayMoodAwful => '最悪';

  @override
  String get dayMoodBad => 'いまいち';

  @override
  String get dayMoodMeh => 'ふつう';

  @override
  String get dayMoodGood => '良い';

  @override
  String get dayMoodGreat => '最高';

  @override
  String get calendarDayMoodTitle => 'この日の気分';

  @override
  String get calendarDayMoodClear => 'クリア';

  @override
  String get calendarDayMoodCleared => 'この日の気分をクリアしました';

  @override
  String get calendarDayMoodSaveFailed => '気分を保存できませんでした。もう一度お試しください。';

  @override
  String get calendarShowDayMoods => 'この日の気分';

  @override
  String get calendarShowDayMoodsDescription =>
      '日付を長押ししてその日の気分を記録すると、日付のマス全体がその気分の見た目に変わります。';

  @override
  String backupOverwriteAllDayMoods(int count) {
    return '$count日分の気分';
  }

  @override
  String backupOverwriteExistingDayMoodsBody(int count) {
    return 'この端末に記録済みの$count日分の気分が、ファイル内の気分に置き換えられます。';
  }

  @override
  String backupImportModeOverwriteDayMoodsOnly(int count) {
    return '新しい項目を追加し、この端末に記録済みの$count日分の気分をファイル内の気分に置き換えます';
  }

  @override
  String backupImportModeOverwriteDayMoodsExtra(int count) {
    return 'この端末に記録済みの$count日分の気分も置き換えます';
  }

  @override
  String backupImportDayMoodMergeResult(int added) {
    return 'この日の気分：$added日分を追加';
  }

  @override
  String backupImportDayMoodOverwriteResult(int added, int replaced) {
    return 'この日の気分：$added日分を追加、$replaced日分を上書き';
  }

  @override
  String get appSurfaceTitle => '背景とマテリアル';

  @override
  String get appSurfaceEntryDefault => 'デフォルト';

  @override
  String get appSurfaceEntryImage => '画像の背景';

  @override
  String get appSurfaceEntryColor => '単色の背景';

  @override
  String get appSurfaceEntryGlass => 'ガラスのコンポーネント';

  @override
  String get appSurfaceEntryClassic => 'クラシックのコンポーネント';

  @override
  String appSurfaceEntryAreas(int count) {
    return '$countか所のエリアを個別に設定';
  }

  @override
  String get appSurfaceTabBackground => '背景';

  @override
  String get appSurfaceTabGlass => 'ガラス';

  @override
  String get appSurfaceAreaGlobal => '全体';

  @override
  String get appSurfaceAreaDiaries => '日記';

  @override
  String get appSurfaceAreaCalendar => 'カレンダー';

  @override
  String get appSurfaceAreaExplore => '探索';

  @override
  String get appSurfaceAreaSettings => '設定';

  @override
  String get appSurfaceAreaEditor => '編集';

  @override
  String get appSurfaceAreaPreview => 'プレビュー';

  @override
  String get appSurfaceAreaOther => 'その他';

  @override
  String appSurfaceAreaCustomized(String area) {
    return '$area、個別に設定済み';
  }

  @override
  String get appSurfaceAreaModeFollow => '全体に合わせる';

  @override
  String get appSurfaceAreaModeOff => '表示しない';

  @override
  String get appSurfaceAreaModeCustom => '個別に設定';

  @override
  String appSurfaceAreaFollowNote(String kind) {
    return '全体の背景を使用します（現在：$kind）。';
  }

  @override
  String get appSurfaceAreaOffNote => 'このエリアには背景を表示せず、テーマの背景色をそのまま使います。';

  @override
  String get appSurfaceAreaCustomNote =>
      'このエリアには下で個別に設定した背景を使います。画像とパラメーターは、それぞれ全体または他のページに合わせることができます。';

  @override
  String get appSurfaceAreaPreviewNote => 'プレビューページの用紙が「テーマに合わせる」のときのみ表示されます。';

  @override
  String get appSurfaceGlobalBackground => '全体の背景';

  @override
  String get appSurfaceGlobalFooter =>
      '各エリアは全体の背景に合わせて表示されます。上でエリアを選ぶと個別に設定できます。';

  @override
  String get appSurfaceAreaBackground => '個別の背景';

  @override
  String get appSurfaceKindNone => 'なし';

  @override
  String get appSurfaceKindColor => '色';

  @override
  String get appSurfaceKindImage => '画像';

  @override
  String get appSurfaceBackgroundColor => '背景色';

  @override
  String get appSurfaceImagePick => '画像を選択';

  @override
  String get appSurfaceImageChange => '変更';

  @override
  String get appSurfaceImageRemove => '削除';

  @override
  String get appSurfaceImageEmpty => '画像がまだ選択されていません';

  @override
  String get appSurfaceImageMissing => '画像ファイルが見つかりません。もう一度選択してください。';

  @override
  String get appSurfaceImageUnavailable =>
      '選択した画像を読み込めませんでした。この端末に保存されている画像を選んでください。';

  @override
  String get appSurfaceImageImportFailed => '画像を取り込めませんでした。もう一度お試しください。';

  @override
  String get appSurfaceFocus => 'フォーカス位置';

  @override
  String get appSurfaceFocusHint => '画像をタップまたはドラッグして、切り抜かれるときに残す位置を選びます。';

  @override
  String appSurfaceFocusSemantics(String x, String y) {
    return '背景のフォーカス位置：横$x%、縦$y%';
  }

  @override
  String get appSurfaceBlur => 'ぼかし';

  @override
  String get appSurfaceScrimLight => 'ライトモードのオーバーレイ';

  @override
  String get appSurfaceScrimDark => 'ダークモードのオーバーレイ';

  @override
  String get appSurfaceFollowSource => '参照元';

  @override
  String get appSurfaceFollowSourceHint =>
      '下の「画像」または「パラメーター」を参照元に合わせると、選んだページで現在表示されている設定が使われ、そちらを変更するとこちらにも反映されます。';

  @override
  String appSurfaceSourceShows(String kind) {
    return '現在：$kind';
  }

  @override
  String get appSurfaceSourceLoop => '参照元がこのページに戻ってくるため選べません';

  @override
  String get appSurfaceImageGroup => '画像';

  @override
  String get appSurfaceParamsGroup => 'パラメーター';

  @override
  String appSurfaceFollowImage(String source) {
    return '「$source」の画像を使う';
  }

  @override
  String appSurfaceFollowParams(String source) {
    return '「$source」のパラメーターを使う';
  }

  @override
  String get appSurfaceFollowParamsHint => 'フォーカス位置、ぼかし、オーバーレイをまとめて合わせます';

  @override
  String appSurfaceFollowImageNote(String source) {
    return '「$source」の画像を使用中';
  }

  @override
  String appSurfaceFollowImageNone(String source) {
    return '「$source」には現在背景画像がありません';
  }

  @override
  String get appSurfaceGlassStyle => 'コンポーネントのスタイル';

  @override
  String get appSurfaceGlassClassic => 'クラシック';

  @override
  String get appSurfaceGlassGlass => 'ガラス';

  @override
  String get appSurfaceGlassStyleFooter =>
      'ガラスではコンポーネント越しに下の背景やコンテンツが透けて見え、クラシックでは従来どおり不透明のままです。';

  @override
  String get appSurfaceGlassPerComponent => 'コンポーネントごとの設定';

  @override
  String get appSurfaceComponentTopBars => 'ページのトップバー';

  @override
  String get appSurfaceComponentToolbar => 'エディターのツールバー';

  @override
  String get appSurfaceComponentSheets => 'ボトムシート';

  @override
  String get appSurfaceComponentDialogs => 'ダイアログ';

  @override
  String get appSurfaceComponentCards => 'カードとグループ';

  @override
  String get appSurfaceComponentControls => 'コントロールと通知バー';

  @override
  String get appSurfaceOverrideFollow => '全体に合わせる';

  @override
  String appSurfaceOverrideFollowResult(String material) {
    return '全体に合わせる（$material）';
  }

  @override
  String get appSurfaceGlassTexture => 'ガラスの質感';

  @override
  String get appSurfaceGlassOpacity => '不透明度';

  @override
  String get appSurfaceGlassTint => '色味';

  @override
  String get appSurfaceGlassTintNeutral => 'ニュートラル';

  @override
  String get appSurfaceGlassTintTheme => 'テーマカラー';

  @override
  String get appSurfaceGlassTintColor => 'ガラスの色';

  @override
  String get appSurfaceGlassBorder => '輪郭線';

  @override
  String get appSurfaceGlassBorderSubtitle => 'コンポーネントと似た色の背景でも縁がわかるよう線を描きます';

  @override
  String get appSurfaceGlassHighContrast => 'ハイコントラストモードでは、ガラスは自動的に不透明になります。';

  @override
  String get appSurfacePreviewLabel => '背景とマテリアルのプレビュー';

  @override
  String get appSurfacePreviewCardTitle1 => '午後の散歩';

  @override
  String get appSurfacePreviewCardBody1 => 'よく晴れていたので、川沿いをぐるっと長めに歩いた。';

  @override
  String get appSurfacePreviewCardTitle2 => '読書メモ';

  @override
  String get appSurfacePreviewCardBody2 => '気に入った言葉をいくつか書き留めた。また今度読み返そう。';

  @override
  String get diaryToolbarSizeTitle => 'ツールバーのサイズ';

  @override
  String get diaryToolbarSizeSubtitle =>
      'ボタンとアイコンが一緒に拡大・縮小されます。1列に収まらなくなったツールは「その他のツール」にまとめられます。';

  @override
  String get diaryToolbarSizeSmall => '小';

  @override
  String get diaryToolbarSizeStandard => '標準';

  @override
  String get diaryToolbarSizeLarge => '大';

  @override
  String get diaryToolbarSizeExtraLarge => '特大';

  @override
  String get diaryListStyleNumberedTitle => '番号付きリストのスタイル';

  @override
  String get diaryListStyleBulletedTitle => '箇条書きのスタイル';

  @override
  String get diaryListStyleAuto => '自動（階層ごとに変化）';

  @override
  String get diaryListStyleDecimal => '数字 1. 2. 3.';

  @override
  String get diaryListStyleParenthesized => 'かっこ付き数字 (1) (2) (3)';

  @override
  String get diaryListStyleCircled => '丸数字 ① ② ③';

  @override
  String get diaryListStyleChinese => '漢数字 一、二、三、';

  @override
  String get diaryListStyleLowerAlpha => '英小文字 a. b. c.';

  @override
  String get diaryListStyleUpperAlpha => '英大文字 A. B. C.';

  @override
  String get diaryListStyleLowerRoman => 'ローマ数字（小文字） i. ii. iii.';

  @override
  String get diaryListStyleUpperRoman => 'ローマ数字（大文字） I. II. III.';

  @override
  String get diaryListStyleDisc => '黒丸';

  @override
  String get diaryListStyleCircle => '白丸';

  @override
  String get diaryListStyleSquare => '四角';

  @override
  String get diaryListStyleDiamond => 'ひし形';

  @override
  String get diaryListStyleStar => '星';

  @override
  String get diaryListStyleArrow => '矢印';

  @override
  String get diaryListStyleDash => 'ダッシュ';

  @override
  String get diaryListToBulleted => '箇条書きに変換';

  @override
  String get diaryListToNumbered => '番号付きリストに変換';

  @override
  String get diaryListToText => '本文に変換';

  @override
  String get diaryFastScrollPinned => 'ピン留め';

  @override
  String get diaryFastScrollUntitled => '無題';

  @override
  String get exploreModuleGreeting => '今日';

  @override
  String get exploreModuleGreetingDesc => '旧暦の日付、今日の記録、今日のお題を添えたあいさつ';

  @override
  String get exploreModuleOnThisDay => '過去の今日';

  @override
  String get exploreModuleOnThisDayDesc => '過去の同じ日（または前後数日・同じ月）に書いた日記';

  @override
  String get exploreModuleRandomMemory => 'ランダムな思い出';

  @override
  String get exploreModuleRandomMemoryDesc => '昔の日記をランダムに1件表示します';

  @override
  String get exploreModuleRecap => '振り返り';

  @override
  String get exploreModuleRecapDesc => '今週・今月・今年の概要を、前の期間と比べて表示します';

  @override
  String get exploreModuleMilestones => 'マイルストーン';

  @override
  String get exploreModuleMilestonesDesc => '件数・文字数・連続記録のマイルストーンまでの進み具合';

  @override
  String get exploreModuleOverview => 'ダッシュボード';

  @override
  String get exploreModuleOverviewDesc => '件数、文字数、連続記録など、選んだ数値を表示します';

  @override
  String get exploreModuleHeatmap => '執筆ヒートマップ';

  @override
  String get exploreModuleHeatmapDesc => '日ごとのマスを週単位で並べて表示します';

  @override
  String get exploreModuleRhythm => '執筆のリズム';

  @override
  String get exploreModuleRhythmDesc => '月・週・日ごとにどれだけ書いたか';

  @override
  String get exploreModuleHabits => '執筆の習慣';

  @override
  String get exploreModuleHabitsDesc => 'よく書く時間帯と曜日';

  @override
  String get exploreModuleMoodTrend => '気分の推移';

  @override
  String get exploreModuleMoodTrendDesc => '日ごとの気分の移り変わり';

  @override
  String get exploreModuleMoodShare => '気分の内訳';

  @override
  String get exploreModuleMoodShareDesc => 'それぞれの気分が現れた回数と割合';

  @override
  String get exploreModuleEnergy => 'エネルギーの推移';

  @override
  String get exploreModuleEnergyDesc => '日ごとのエネルギーレベル';

  @override
  String get exploreModuleTags => 'タグ';

  @override
  String get exploreModuleTagsDesc => 'よく使うタグ。タップすると検索できます';

  @override
  String get exploreModuleMedia => 'メディアギャラリー';

  @override
  String get exploreModuleMediaDesc => '日記の中の写真';

  @override
  String get exploreModulePlaces => '場所';

  @override
  String get exploreModulePlacesDesc => '日記をよく書く場所';

  @override
  String get exploreModuleWeather => '天気';

  @override
  String get exploreModuleWeatherDesc => '日記を書いたときの天気';

  @override
  String get exploreModuleAnniversaries => '記念日';

  @override
  String get exploreModuleAnniversariesDesc => '近づいている記念日までのカウントダウン';

  @override
  String get exploreModuleCapsules => 'タイムカプセル';

  @override
  String get exploreModuleCapsulesDesc => '開封を待っているカプセルと、最近開封されたカプセル';

  @override
  String get exploreModuleNotebooks => '日記帳';

  @override
  String get exploreModuleNotebooksDesc => 'あなたの日記帳の本棚';

  @override
  String get exploreModuleDrafts => '下書き';

  @override
  String get exploreModuleDraftsDesc => '書きかけの下書きがあるときにお知らせします';

  @override
  String get explorePeriodWeek => '今週';

  @override
  String get explorePeriodMonth => '今月';

  @override
  String get explorePeriodYear => '今年';

  @override
  String get explorePeriodAll => '全期間';

  @override
  String get explorePeriodEmpty => 'この期間の日記はまだありません';

  @override
  String get exploreNoModules => '探索に表示されているカードはありません';

  @override
  String get exploreModuleMenuHide => 'このカードを非表示';

  @override
  String exploreModuleHidden(String name) {
    return '「$name」を非表示にしました';
  }

  @override
  String get exploreGreetingMorning => 'おはようございます';

  @override
  String get exploreGreetingNoon => 'こんにちは';

  @override
  String get exploreGreetingAfternoon => 'こんにちは';

  @override
  String get exploreGreetingEvening => 'こんばんは';

  @override
  String get exploreGreetingNight => '夜更かしですね';

  @override
  String exploreGreetingToday(int count, String words) {
    return '今日は$count件 · $words文字';
  }

  @override
  String get exploreGreetingTodayEmpty => '今日はまだ何も書いていません';

  @override
  String get exploreGreetingWrite => '書く';

  @override
  String get exploreGreetingNextPrompt => '別のお題';

  @override
  String get explorePrompt01 => '今日、思わず笑顔になったことは？';

  @override
  String get explorePrompt02 => '最近ずっと考えていることは？';

  @override
  String get explorePrompt03 => '今日、新しく学んだことは？';

  @override
  String get explorePrompt04 => '今日をやり直せるとしたら、何を変えますか？';

  @override
  String get explorePrompt05 => 'いま窓の外に見える景色を書いてみましょう。';

  @override
  String get explorePrompt06 => '今日食べた中でいちばんおいしかったものは？';

  @override
  String get explorePrompt07 => '最近読んだり聞いたりした言葉で、心に残っているものは？';

  @override
  String get explorePrompt08 => '昨日の自分になくて、今日の自分にあるものは？';

  @override
  String get explorePrompt09 => '最近、心が落ち着いた小さな出来事について書いてみましょう。';

  @override
  String get explorePrompt10 => '今週、自分にかけてあげたい言葉は？';

  @override
  String get explorePrompt11 => '今日は誰と話しましたか？どんな話をしましたか？';

  @override
  String get explorePrompt12 => '最近、楽しみにしていることは？';

  @override
  String get explorePrompt13 => '今日の気分を天気にたとえると？';

  @override
  String get explorePrompt14 => '今日感謝したい小さなことを3つ書いてみましょう。';

  @override
  String get explorePrompt15 => '最近ずっとリピートしている曲はありますか？';

  @override
  String get explorePrompt16 => '今日、思っていたよりうまくいったことは？';

  @override
  String get explorePrompt17 => '1年後の自分にひと言書くとしたら、何と書きますか？';

  @override
  String get explorePrompt18 => '今日いちばん長く過ごした場所はどこですか？どんなところでしたか？';

  @override
  String get explorePrompt19 => '最近疲れを感じている原因は何ですか？どうすれば自分をいたわれそうですか？';

  @override
  String get explorePrompt20 => '最近、声を出して笑ったのはどんなときでしたか？';

  @override
  String get exploreOnThisDayEmpty => '過去のこの日の日記はまだありません。今日書いた日記は、来年ここに表示されます。';

  @override
  String get exploreRandomShuffle => '別の日記';

  @override
  String get exploreRandomEmpty => '条件に合う昔の日記はまだありません';

  @override
  String get exploreRecapTitleWeek => '今週の振り返り';

  @override
  String get exploreRecapTitleMonth => '今月の振り返り';

  @override
  String get exploreRecapTitleYear => '今年の振り返り';

  @override
  String get exploreRecapTopMood => 'いちばん多かった気分';

  @override
  String get exploreRecapTopTag => 'いちばん使ったタグ';

  @override
  String exploreRecapMore(int count) {
    return '前回より$count多い';
  }

  @override
  String exploreRecapFewer(int count) {
    return '前回より$count少ない';
  }

  @override
  String get exploreRecapSame => '前回と同じ';

  @override
  String get exploreMetricEntries => '日記の件数';

  @override
  String get exploreMetricWords => '文字数';

  @override
  String get exploreMetricRecordedDays => '記録した日数';

  @override
  String get exploreMetricCurrentStreak => '現在の連続記録';

  @override
  String get exploreMetricLongestStreak => '最長の連続記録';

  @override
  String get exploreMetricAverageWords => '1件あたりの文字数';

  @override
  String get exploreMetricPhotos => '写真';

  @override
  String get exploreMetricTags => '使ったタグ';

  @override
  String get exploreMetricSpan => '記録期間';

  @override
  String get exploreMetricTodayWords => '今日の文字数';

  @override
  String get exploreMilestoneEntries => '件数';

  @override
  String get exploreMilestoneWords => '文字数';

  @override
  String get exploreMilestoneStreak => '最長の連続記録';

  @override
  String get exploreMilestoneDays => '記録した日数';

  @override
  String get exploreMilestoneYears => '継続年数';

  @override
  String exploreMilestoneNext(String target, String remaining) {
    return '次の目標：$target · あと$remaining';
  }

  @override
  String get exploreMilestoneAllDone => 'すべて達成';

  @override
  String exploreMilestoneAchieved(int count) {
    return '$count個達成';
  }

  @override
  String exploreUnitEntries(int count) {
    return '$count件';
  }

  @override
  String exploreUnitWords(String words) {
    return '$words文字';
  }

  @override
  String exploreUnitYears(int count) {
    return '$count年';
  }

  @override
  String exploreUnitTimes(int count) {
    return '$count回';
  }

  @override
  String exploreHeatmapSummary(int days, int weeks) {
    return '直近$weeks週間で$days日書きました';
  }

  @override
  String exploreHeatmapDay(String date, int count, String words) {
    return '$date · $count件 · $words文字';
  }

  @override
  String exploreHeatmapDayEmpty(String date) {
    return '$date · 日記なし';
  }

  @override
  String get exploreHeatmapLess => '少ない';

  @override
  String get exploreHeatmapMore => '多い';

  @override
  String exploreTotalEntries(int count) {
    return '合計$count件';
  }

  @override
  String exploreTotalWords(String words) {
    return '合計$words文字';
  }

  @override
  String get exploreSlotLateNight => '深夜';

  @override
  String get exploreSlotMorning => '朝';

  @override
  String get exploreSlotForenoon => '午前';

  @override
  String get exploreSlotAfternoon => '午後';

  @override
  String get exploreSlotEvening => '夕方';

  @override
  String get exploreSlotNight => '夜';

  @override
  String exploreHabitsTopSlot(String slot) {
    return 'よく書く時間帯：$slot';
  }

  @override
  String exploreHabitsTopWeekday(String weekday) {
    return 'いちばん多い曜日：$weekday';
  }

  @override
  String get exploreHabitsTimeOfDay => '時間帯';

  @override
  String get exploreHabitsWeekdays => '曜日';

  @override
  String exploreLastDays(int days) {
    return '直近$days日間';
  }

  @override
  String exploreMoodAverage(String mood) {
    return '平均の気分：$mood';
  }

  @override
  String get exploreMoodTrendEmpty => '最近は気分が記録されていません';

  @override
  String get exploreMoodShareEmpty => 'この期間に記録された気分はありません';

  @override
  String exploreEnergyAverage(String value) {
    return '平均：$value';
  }

  @override
  String get exploreEnergyEmpty => '最近はエネルギーが記録されていません';

  @override
  String get explorePlacesEmpty => '日記を書くときに場所を追加すると、よく行く場所がここに表示されます。';

  @override
  String get exploreWeatherEmpty => '日記を書くときに天気を記録すると、ここに表示されます。';

  @override
  String get exploreAnniversariesEmpty => '記念日はまだありません';

  @override
  String get exploreAnniversariesAdd => '記念日を追加';

  @override
  String get exploreAnniversariesAll => 'すべての記念日';

  @override
  String exploreCapsulesWaiting(int count) {
    return '$count個のタイムカプセルが開封待ち';
  }

  @override
  String exploreCapsuleOpensIn(int count) {
    return '$count日後に開封';
  }

  @override
  String get exploreCapsuleOpensToday => '今日開封';

  @override
  String get exploreCapsulesRecent => '最近開封';

  @override
  String get exploreCapsulesEmpty =>
      'タイムカプセルはまだありません。日記を投稿するときに封をすると、未来の自分に届けられます。';

  @override
  String get exploreNotebooksEmpty => '日記帳はまだありません';

  @override
  String get exploreNotebooksManage => '日記帳を管理';

  @override
  String exploreDraftsCount(int count) {
    return '$count件の下書きがあります';
  }

  @override
  String get exploreDraftsContinue => '続きを書く';

  @override
  String get exploreDraftsManage => '管理';

  @override
  String get exploreCustomize => '探索をカスタマイズ';

  @override
  String get exploreModuleMenuSettings => 'カードの設定';

  @override
  String get exploreGroupRecall => '思い出とひらめき';

  @override
  String get exploreGroupStats => 'グラフ';

  @override
  String get exploreGroupLife => '暮らしの記録';

  @override
  String get exploreGroupLinked => '連携機能';

  @override
  String get exploreLayoutTabPresets => 'プリセット';

  @override
  String get exploreLayoutTabCards => 'カード';

  @override
  String get exploreLayoutTabAppearance => '外観';

  @override
  String get exploreLayoutTabRange => '範囲';

  @override
  String get exploreLayoutResetDone => 'デフォルトのレイアウトに戻しました';

  @override
  String get exploreLayoutCardsHint =>
      'ハンドルをドラッグして並べ替えます。行をタップするとオプションが表示されます。';

  @override
  String get exploreLayoutCardsShowAll => 'すべて表示';

  @override
  String get exploreLayoutCardsDefaultOrder => 'デフォルトの順序';

  @override
  String get exploreLayoutFeatureOff => '「機能管理」でオフになっています';

  @override
  String exploreLayoutDragHandle(String name) {
    return 'ドラッグして「$name」を並べ替え';
  }

  @override
  String exploreLayoutShowModule(String name) {
    return '「$name」を表示';
  }

  @override
  String exploreLayoutMultiHint(int max) {
    return '選んだ順に表示されます（最大$max個）';
  }

  @override
  String get exploreLayoutSpan => 'ワイド画面での幅';

  @override
  String get exploreLayoutSpanFull => '全幅';

  @override
  String get exploreLayoutSpanHalf => '半分';

  @override
  String get exploreLayoutPreviewMine => '自分のデータ';

  @override
  String get exploreLayoutPreviewSample => 'サンプルデータ';

  @override
  String get exploreLayoutCustom => 'カスタム';

  @override
  String get exploreSamplePlaceHome => '自宅';

  @override
  String get exploreSamplePlaceOffice => '職場';

  @override
  String get settingsExploreLayout => '探索ページ';

  @override
  String settingsExploreLayoutSubtitle(String name) {
    return '現在：$name';
  }

  @override
  String get exploreOptLunar => '旧暦の日付';

  @override
  String get exploreOptPrompt => '今日のお題';

  @override
  String get exploreOptWrite => '「書く」ボタン';

  @override
  String get exploreOptMatch => '一致条件';

  @override
  String get exploreOptStyle => 'スタイル';

  @override
  String get exploreOptCount => '表示数';

  @override
  String get exploreOptSource => '選ぶ対象';

  @override
  String get exploreOptPhotosOnly => '表紙のある日記のみ';

  @override
  String get exploreOptDaily => '1日中同じ日記を表示';

  @override
  String get exploreOptRecapPeriod => '期間';

  @override
  String get exploreOptCompare => '前回と比較';

  @override
  String get exploreOptKinds => 'マイルストーン';

  @override
  String get exploreOptAchieved => '達成数を表示';

  @override
  String get exploreOptMetrics => '指標';

  @override
  String get exploreOptColumns => '列数';

  @override
  String get exploreOptHeatmapSpan => '期間';

  @override
  String get exploreOptBasis => '色分けの基準';

  @override
  String get exploreOptWeekdayLabels => '曜日ラベル';

  @override
  String get exploreOptLegend => '凡例';

  @override
  String get exploreOptUnit => '集計単位';

  @override
  String get exploreOptMetric => '集計対象';

  @override
  String get exploreOptTimeOfDay => '時間帯';

  @override
  String get exploreOptWeekdays => '曜日';

  @override
  String get exploreOptDays => '期間';

  @override
  String get exploreOptChart => 'グラフ';

  @override
  String get exploreOptDayMoods => '「この日の気分」を含める';

  @override
  String get exploreOptSort => '並べ替え';

  @override
  String get exploreOptPercent => '割合を表示';

  @override
  String get exploreOptInline => '本文中の写真を含める';

  @override
  String get exploreOptRecent => '最近開封したものを表示';

  @override
  String get exploreValFollowLanguage => '言語に合わせる';

  @override
  String get exploreValShow => '表示';

  @override
  String get exploreValHide => '非表示';

  @override
  String get exploreValSameDay => '同じ日';

  @override
  String get exploreValNearby => '前後3日';

  @override
  String get exploreValSameMonth => '同じ月';

  @override
  String get exploreValCarousel => 'カルーセル';

  @override
  String get exploreValList => 'リスト';

  @override
  String get exploreValAll => 'すべて';

  @override
  String get exploreValMonthAgo => '1か月以上前';

  @override
  String get exploreValYearAgo => '1年以上前';

  @override
  String get exploreValWeeks12 => '12週間';

  @override
  String get exploreValHalfYear => '半年';

  @override
  String get exploreValYear => '1年';

  @override
  String get exploreValEntries => '件数';

  @override
  String get exploreValWords => '文字数';

  @override
  String get exploreValMood => '気分';

  @override
  String get exploreValByMonth => '月ごと';

  @override
  String get exploreValByWeek => '週ごと';

  @override
  String get exploreValByDay => '日ごと';

  @override
  String get exploreValPixels => 'ピクセル';

  @override
  String get exploreValLine => '折れ線';

  @override
  String get exploreValBars => '棒グラフ';

  @override
  String get exploreValByCount => '回数';

  @override
  String get exploreValByMood => '気分';

  @override
  String get exploreValRanking => 'ランキング';

  @override
  String get exploreValManual => 'カスタム順';

  @override
  String get exploreValRecent => '最近使用';

  @override
  String get exploreValStrip => '横並び';

  @override
  String get exploreValGrid => 'グリッド';

  @override
  String get exploreValMosaic => 'モザイク';

  @override
  String get exploreValIcons => 'アイコン';

  @override
  String get exploreValShelf => '本棚の順';

  @override
  String get exploreValUpdated => '最近の更新順';

  @override
  String get exploreValByEntries => '件数順';

  @override
  String get exploreValAuto => '自動';

  @override
  String exploreValColumns(int count) {
    return '$count列';
  }

  @override
  String get explorePresetBalanced => 'バランス';

  @override
  String get explorePresetBalancedDesc => '定番のカードで、最近の様子がひと目でわかります';

  @override
  String get explorePresetMinimal => 'ミニマル';

  @override
  String get explorePresetMinimalDesc => 'あいさつ、過去の今日、ダッシュボード、写真だけ';

  @override
  String get explorePresetDataLover => 'データ好き';

  @override
  String get explorePresetDataLoverDesc => 'グラフをすべて表示：ヒートマップ、リズム、習慣、気分、エネルギー';

  @override
  String get explorePresetMemories => '思い出';

  @override
  String get explorePresetMemoriesDesc => '過去の今日、ランダムな思い出、振り返り、タイムカプセル、記念日';

  @override
  String get explorePresetEverything => 'すべて';

  @override
  String get explorePresetEverythingDesc => '20枚のカードをすべてオン';

  @override
  String get exploreLookCards => 'カード';

  @override
  String get exploreLookDensity => '密度';

  @override
  String get exploreLookCompact => 'コンパクト';

  @override
  String get exploreLookStandard => '標準';

  @override
  String get exploreLookRelaxed => 'ゆったり';

  @override
  String get exploreLookRadius => '角の丸み';

  @override
  String get exploreLookSurface => 'カードの表面';

  @override
  String get exploreLookFilled => '塗りつぶし';

  @override
  String get exploreLookTonal => 'トーン';

  @override
  String get exploreLookOutlined => '枠線';

  @override
  String get exploreLookSurfaceGlassNote => 'マテリアルがガラスのときは、カードは常にガラスになります。';

  @override
  String get exploreLookAccent => 'アクセントカラー';

  @override
  String get exploreLookPrimary => 'メインカラー';

  @override
  String get exploreLookSecondary => 'サブカラー';

  @override
  String get exploreLookTertiary => '第3カラー';

  @override
  String get exploreLookText => 'タイトルと数字';

  @override
  String get exploreLookHeading => 'カードのタイトル';

  @override
  String get exploreLookBadge => 'バッジ';

  @override
  String get exploreLookIcon => 'アイコン';

  @override
  String get exploreLookTextOnly => 'テキスト';

  @override
  String get exploreLookHidden => '非表示';

  @override
  String get exploreLookCompactNumbers => '大きな数字を省略表示';

  @override
  String get exploreLookCompactNumbersSubtitle => '1万を超える数を「1.2万」のように表示します';

  @override
  String get exploreLookAnimations => 'グラフのアニメーション';

  @override
  String get exploreLookAnimationsSubtitle => '表示されるときにグラフが伸び、数字がカウントアップします';

  @override
  String get exploreLookWide => 'ワイド画面';

  @override
  String get exploreLookWideFooter => 'スマートフォンなどの狭い画面では、常に1列で表示されます。';

  @override
  String get exploreLookColumns => '列数';

  @override
  String get exploreLookFlow => '配置';

  @override
  String get exploreLookRows => '行で揃える';

  @override
  String get exploreLookStaggered => '互い違い';

  @override
  String get exploreRangeBar => '期間バーを表示';

  @override
  String get exploreRangeBarSubtitle => '探索の上部で、今週・今月・今年・全期間を切り替えます';

  @override
  String get exploreRangeCurrent => '集計期間';

  @override
  String get exploreRangeFooter =>
      '集計期間は、ダッシュボード、タグ、執筆の習慣、気分の内訳、場所、天気に適用されます。その他のカードには、それぞれ独自の期間があります。';

  @override
  String get exploreSampleWeatherSunny => '晴れ';

  @override
  String get exploreSampleWeatherCloudy => '薄曇り';

  @override
  String get exploreSampleWeatherOvercast => '曇り';

  @override
  String get exploreSampleWeatherRain => '小雨';

  @override
  String get exploreSampleWeatherFog => '霧';

  @override
  String get settingsFeaturesComments => 'コメント';

  @override
  String get settingsFeaturesCommentsSubtitle =>
      '日記を読み返すときに末尾へコメントを残せます。本文は書いたときのまま保たれます';

  @override
  String diaryCommentsHeading(int count) {
    return 'コメント · $count';
  }

  @override
  String get diaryCommentsWrite => 'コメントを書く…';

  @override
  String diaryCommentsExpand(int count) {
    return 'さらに$count件を表示';
  }

  @override
  String get diaryCommentsCollapse => '折りたたむ';

  @override
  String get diaryCommentEdited => '編集済み';

  @override
  String get diaryCommentSameDay => '当日';

  @override
  String diaryCommentDaysLater(int count) {
    return '$count日後';
  }

  @override
  String diaryCommentMonthsLater(int count) {
    return '$countか月後';
  }

  @override
  String diaryCommentYearsLater(int count) {
    return '$count年後';
  }

  @override
  String diaryCommentYearsMonthsLater(int years, int months) {
    return '$years年$monthsか月後';
  }

  @override
  String get diaryCommentSheetNew => 'コメントを書く';

  @override
  String get diaryCommentSheetEdit => 'コメントを編集';

  @override
  String get diaryCommentHint => 'これを書いた自分に伝えたいことは…';

  @override
  String get diaryCommentMoodLabel => '気分';

  @override
  String get diaryCommentMoodOptional => '任意';

  @override
  String get diaryCommentCopy => 'コピー';

  @override
  String get diaryCommentCopied => 'コメントをコピーしました';

  @override
  String get diaryCommentDeleted => 'コメントを削除しました';

  @override
  String get diaryCommentSaveFailed => 'コメントを保存できませんでした。もう一度お試しください。';

  @override
  String get diaryCommentActionsHint => '編集、コピー、削除';

  @override
  String get diaryCommentAddImages => '写真を追加';

  @override
  String diaryCommentImagesFull(int max) {
    return '写真は最大$max枚までです';
  }

  @override
  String diaryCommentImagesTruncated(int max) {
    return '1件のコメントに追加できる写真は最大$max枚です。超えた分は追加されませんでした';
  }

  @override
  String get diaryCommentImageAddFailed => '写真を追加できませんでした。もう一度お試しください。';

  @override
  String get diaryCommentImagePermissionDenied => '写真を読み取る権限がありません';

  @override
  String get diaryCommentImageRemove => '写真を削除';

  @override
  String get diaryCommentImageAdding => '写真を追加中';

  @override
  String diaryCommentImageCount(int count) {
    return '写真$count枚';
  }

  @override
  String diaryCommentImageLabel(int index, int count) {
    return '写真 $index/$count';
  }

  @override
  String diaryCommentsCount(int count) {
    return 'コメント$count件';
  }

  @override
  String get diaryPreviewStyleShowComments => 'コメント数';

  @override
  String get diaryCardStyleShowComments => 'コメント数';

  @override
  String diarySearchCommentHit(String text) {
    return 'コメントで言及：$text';
  }

  @override
  String get exploreModuleComments => '最近のコメント';

  @override
  String get exploreModuleCommentsDesc => '最近書いたコメントと、読み返しの記録';

  @override
  String exploreCommentsDiaries(int count) {
    return '$count件の日記にコメント';
  }

  @override
  String exploreCommentsAverageGap(int days) {
    return '平均$days日後に読み返し';
  }

  @override
  String get exploreCommentsEmpty => '日記の末尾に最初のコメントを書いてみましょう';

  @override
  String get exploreSampleComment => 'あのとき諦めなかった自分、ありがとう。';

  @override
  String get diaryPreviewSampleComment1 => '振り返ってみると、あの日はそれほど悪くなかった。';

  @override
  String get diaryPreviewSampleComment2 => '結局行ってみたら、想像していた以上によかった。';

  @override
  String get diaryExportIncludeComments => 'コメントを含める';

  @override
  String get diaryExportCommentsHeading => 'コメント';

  @override
  String backupImportCommentMergeResult(int added) {
    return 'コメント：$added件を追加';
  }

  @override
  String backupImportCommentOverwriteResult(int added, int replaced) {
    return 'コメント：$added件を追加、$replaced件を上書き';
  }

  @override
  String get diaryEditorTable => '表';

  @override
  String get diaryTableInsertRowAbove => '上に行を挿入';

  @override
  String get diaryTableInsertRowBelow => '下に行を挿入';

  @override
  String get diaryTableInsertColumnLeft => '左に列を挿入';

  @override
  String get diaryTableInsertColumnRight => '右に列を挿入';

  @override
  String get diaryTableDeleteRow => '行を削除';

  @override
  String get diaryTableDeleteColumn => '列を削除';

  @override
  String get diaryTableHeaderRow => '見出し行';

  @override
  String get diaryTableDelete => '表を削除';

  @override
  String diaryLinkUntitled(String date) {
    return '$dateの日記';
  }

  @override
  String get diaryLinkGroupDiaries => '日記';

  @override
  String get diaryLinkGroupNotebooks => '日記帳';

  @override
  String get diaryLinkGroupWeb => 'ウェブ';

  @override
  String get diaryLinkEmpty => '一致する日記や日記帳はありません';

  @override
  String get diaryLinkMenuHint => '入力してタイトルや日記帳を検索';

  @override
  String get diaryLinkMenuLabel => '日記または日記帳をリンク';

  @override
  String get diaryLinkSearchDiaries => '日記のタイトルを検索';

  @override
  String get diaryLinkSearchNotebooks => '日記帳を検索';

  @override
  String get diaryLinkOpen => '開く';

  @override
  String get diaryLinkRemove => 'リンクを解除';

  @override
  String get diaryLinkCurrentDiary => '日記へのリンク';

  @override
  String get diaryLinkCurrentNotebook => '日記帳へのリンク';

  @override
  String get diaryLinkMissingDiary => 'この日記は存在しないか、削除されています';

  @override
  String get diaryLinkMissingNotebook => 'この日記帳は存在しないか、削除されています';

  @override
  String get diaryEditorDiaryCard => '日記カード';

  @override
  String get diaryEditorNotebookCard => '日記帳カード';

  @override
  String get diaryLinkCardPrivate => 'プライベートな日記';

  @override
  String diaryLinkCardSealed(String date) {
    return '$dateに開封';
  }

  @override
  String diaryLinkCardNotebookCount(int count) {
    return '$count件';
  }

  @override
  String get diaryLinkCardToInline => 'インラインリンクに変換';

  @override
  String get diaryLinkCardMenu => 'カードのオプション';

  @override
  String diaryBacklinksTitle(int count) {
    return '$count件の日記で言及';
  }

  @override
  String diaryBacklinksShowAll(int count) {
    return 'すべて表示（$count件）';
  }

  @override
  String notebookBacklinksChip(int count) {
    return '$count件の日記で言及';
  }

  @override
  String get notebookBacklinksTitle => 'この日記帳に言及している日記';

  @override
  String get lanSyncTitle => 'LAN 同期';

  @override
  String get lanSyncEntrySubtitleUnpaired => '同じ Wi-Fi に接続したデバイス間で日記を同期します';

  @override
  String lanSyncEntrySubtitlePaired(int count, String ago) {
    return '$count台をペアリング済み · $agoに同期';
  }

  @override
  String lanSyncEntrySubtitlePairedNever(int count) {
    return '$count台をペアリング済み · まだ同期していません';
  }

  @override
  String get lanSyncEntrySubtitleAttention => '確認が必要な同期があります';

  @override
  String get lanSyncDefaultDeviceName => 'このデバイス';

  @override
  String lanSyncLocalPlatform(String platform) {
    return 'このデバイス · $platform';
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
  String get lanSyncPlatformUnknown => 'その他のデバイス';

  @override
  String get lanSyncRenameTooltip => 'このデバイスの名前を変更';

  @override
  String get lanSyncRenameTitle => 'デバイス名';

  @override
  String get lanSyncRenameHint => '近くのデバイスにこの名前が表示されます';

  @override
  String get lanSyncDiscoverable => '検出可能';

  @override
  String get lanSyncNotDiscoverable => '検出不可';

  @override
  String get lanSyncDiscoverableToggleHint =>
      '近くのデバイスからこのデバイスを見つけられるかどうかを切り替えます';

  @override
  String get lanSyncNoNetwork => 'ローカルネットワーク未接続';

  @override
  String get lanSyncCopyAddressHint => 'アドレスをコピー';

  @override
  String get lanSyncAddressCopied => 'アドレスをコピーしました';

  @override
  String get lanSyncScanQr => 'QR コードをスキャン';

  @override
  String get lanSyncShowQr => 'QR コードを表示';

  @override
  String get lanSyncManualAddress => 'アドレスを入力';

  @override
  String get lanSyncTroubleshoot => 'デバイスが見つかりませんか？';

  @override
  String get lanSyncSearchingNearbyJotsy => '近くの Jotsy を探しています…';

  @override
  String get lanSyncSectionMyDevices => 'マイデバイス';

  @override
  String lanSyncDeviceCount(int count) {
    return '$count台';
  }

  @override
  String get lanSyncSectionNearby => '近くのデバイス';

  @override
  String get lanSyncSearching => '検索中';

  @override
  String get lanSyncNearbyEmpty =>
      '近くにほかの Jotsy はまだ見つかっていません。もう一方のデバイスでもこのページを開いてください。';

  @override
  String get lanSyncSectionOptions => '同期オプション';

  @override
  String get lanSyncAutoSync => '自動同期';

  @override
  String get lanSyncAutoSyncSubtitle => 'Jotsy を開いている間、ペアリング済みデバイスと自動で同期します';

  @override
  String get lanSyncSyncSettings => '設定を同期';

  @override
  String get lanSyncSyncSettingsSubtitle =>
      '両方のデバイスでオンにすると、外観やエディターなどの設定も同期されます。タグの並び順と、コメントや日記帳などの機能の有効化は常に同期されます';

  @override
  String get lanSyncOnline => 'オンライン';

  @override
  String get lanSyncOffline => 'オフライン';

  @override
  String lanSyncSyncedAgo(String ago) {
    return '$agoに同期';
  }

  @override
  String get lanSyncNeverSynced => '未同期';

  @override
  String lanSyncNearbySubtitle(String platform, String address) {
    return '$platform · $address';
  }

  @override
  String get lanSyncNeedsAttention => '確認が必要です';

  @override
  String get lanSyncReview => '確認';

  @override
  String get lanSyncSyncButton => '同期';

  @override
  String get lanSyncPair => 'ペアリング';

  @override
  String get lanSyncStageConnecting => '接続中…';

  @override
  String get lanSyncStageComparing => '比較中…';

  @override
  String get lanSyncStageTransferring => '転送中…';

  @override
  String get lanSyncStageMerging => '統合中…';

  @override
  String get lanSyncFirstUseTitle => 'ペアリング済みのデバイスはまだありません';

  @override
  String get lanSyncFirstUseBody =>
      '日記は同じローカルネットワーク内のデバイス間で直接やり取りされます。通信はすべて暗号化され、サーバーを経由することはありません。';

  @override
  String get lanSyncFirstUseStep1 => '両方のデバイスを同じ Wi-Fi に接続します';

  @override
  String get lanSyncFirstUseStep2 => 'もう一方のデバイスで「設定 › LAN 同期」を開きます';

  @override
  String get lanSyncFirstUseStep3 => '「近くのデバイス」で「ペアリング」をタップするか、QR コードをスキャンします';

  @override
  String lanSyncPortBusyNotice(int port) {
    return 'ポート $port がほかのアプリに使われているため、このデバイスはほかのデバイスを見つけることも、見つけてもらうこともできません。アドレスの入力や QR コードのスキャンでは接続できます。';
  }

  @override
  String get lanSyncTipWifiTitle => '同じ Wi-Fi に接続する';

  @override
  String get lanSyncTipWifiBody =>
      '両方のデバイスが同じネットワークにある必要があります。ゲストネットワークや、AP アイソレーションが有効なルーターでは検出がブロックされます。';

  @override
  String get lanSyncTipVpnTitle => 'VPN / プロキシ';

  @override
  String get lanSyncTipVpnBody =>
      'どちらかのデバイスで VPN やプロキシ（Clash など）を使っていると、LAN の通信がトンネルに送られ、デバイス同士が見つからなかったり接続できなかったりします。いったん VPN をオフにするか、プロキシアプリで「プライベートネットワーク / LAN をバイパス」を有効にしてください。';

  @override
  String get lanSyncTipOpenPageTitle => 'もう一方のデバイスでもこのページを開く';

  @override
  String get lanSyncTipOpenPageBody =>
      'このページを開いている間はデバイスが自分の存在をより頻繁に知らせるため、早く見つかります。';

  @override
  String get lanSyncTipWindowsTitle => 'Windows ファイアウォール';

  @override
  String get lanSyncTipWindowsBody =>
      '初回起動時に Windows からファイアウォールの確認が表示されたら、プライベートネットワークで Jotsy を許可してください。';

  @override
  String get lanSyncTipLinuxTitle => 'Linux ファイアウォール';

  @override
  String lanSyncTipLinuxBody(int udpPort, int tcpPort) {
    return 'ファイアウォールが有効な場合は、UDP $udpPort と TCP $tcpPort を許可してください。';
  }

  @override
  String get lanSyncTipFallbackTitle => 'それでも見つかりませんか？';

  @override
  String get lanSyncTipFallbackBody =>
      'もう一方のデバイスのアドレスを直接入力するか、そのデバイスに表示される QR コードをスキャンしてください。';

  @override
  String get lanSyncManualIntro =>
      'もう一方のデバイスのアドレスは、そのデバイスの同期ページで確認できます。接続後、両方のデバイスでペアリングを確定してください。';

  @override
  String get lanSyncManualHostLabel => 'アドレス';

  @override
  String get lanSyncManualHostHint => '例：192.168.1.23';

  @override
  String get lanSyncManualPortLabel => 'ポート';

  @override
  String get lanSyncManualHostInvalid => '有効な IP アドレスまたはホスト名を入力してください';

  @override
  String get lanSyncManualPortInvalid => 'ポートは 1～65535 の範囲で入力してください';

  @override
  String get lanSyncManualConnect => '接続';

  @override
  String lanSyncAutoSyncApplied(String name, int count) {
    return '「$name」から$count件の日記を同期しました';
  }

  @override
  String lanSyncAutoSyncNeedsAttention(String name) {
    return '「$name」との同期に確認が必要です';
  }

  @override
  String lanSyncPairConnecting(String name) {
    return '$name に接続中…';
  }

  @override
  String lanSyncPairTitleOutgoing(String name) {
    return '「$name」とペアリング';
  }

  @override
  String lanSyncPairTitleIncoming(String name) {
    return '「$name」がペアリングを求めています';
  }

  @override
  String get lanSyncPairSubtitle => '両方のデバイスに同じ数字が表示されていることを確認してください';

  @override
  String lanSyncPairCodeSemantics(String first, String second) {
    return 'ペアリングコード $first $second';
  }

  @override
  String get lanSyncPairSafetyNote =>
      'ペアリングすると、両方のデバイスのすべての日記が双方向に統合されます（プライベート日記帳とゴミ箱を含む）。接続はエンドツーエンドで暗号化され、サーバーを経由することはありません。';

  @override
  String get lanSyncPairExportBackup => '先に完全バックアップをエクスポート';

  @override
  String get lanSyncPairMismatch => '一致しない';

  @override
  String get lanSyncPairConfirm => '一致する・ペアリング';

  @override
  String get lanSyncPairTimeoutNote => '60秒以内に確定しないと自動的にキャンセルされます';

  @override
  String get lanSyncPairWaitingPeer => '相手のデバイスを待っています…';

  @override
  String lanSyncPairSucceeded(String name) {
    return '$name とペアリングしました';
  }

  @override
  String get lanSyncPairSyncNow => '今すぐ同期';

  @override
  String get lanSyncPairLater => '後で';

  @override
  String get lanSyncPairFailedTitle => 'ペアリングが完了しませんでした';

  @override
  String lanSyncPairAuthReason(String name) {
    return '「$name」とのペアリングを確定するには本人確認を行ってください';
  }

  @override
  String get lanSyncPairAuthFailed => '本人確認ができなかったため、ペアリングはまだ確定していません';

  @override
  String get lanSyncPairAuthUnsupported =>
      'このデバイスではアプリロックまたはロック中の日記帳を使っていますが、画面ロックが設定されていないため本人確認ができません。先にシステム設定で画面ロックを設定してください。';

  @override
  String get lanSyncPairFailUnreachable =>
      '相手のデバイスに接続できませんでした。アドレスとポートを確認し、両方のデバイスが同じ Wi-Fi に接続されていて VPN がオフになっていることを確かめてください。';

  @override
  String get lanSyncPairFailConnectionLost => '接続が切れました。もう一度ペアリングしてください。';

  @override
  String get lanSyncPairFailTimedOut => '60秒以内に確定されなかったため、ペアリングはキャンセルされました。';

  @override
  String get lanSyncPairFailDeclined => '相手のデバイスでキャンセルされたか、数字が一致しませんでした。';

  @override
  String get lanSyncPairFailCancelled => 'ペアリングはキャンセルされました。';

  @override
  String get lanSyncPairFailIncompatible =>
      '2台のデバイスの Jotsy のバージョンに互換性がありません。古いほうをアップデートしてください。';

  @override
  String get lanSyncPairFailUntrusted =>
      '相手のデバイスが接続を拒否しました。両方のデバイスでもう一度ペアリングしてください。';

  @override
  String get lanSyncPairFailTicketExpired =>
      'QR コードの有効期限が切れています。新しいコードを表示してもらい、もう一度スキャンしてください。';

  @override
  String get lanSyncPairFailWriteFailed => 'ペアリング情報を保存できませんでした。もう一度お試しください。';

  @override
  String get lanSyncPairFailUnknown => 'ペアリングが完了しませんでした。もう一度お試しください。';

  @override
  String get lanSyncPairFailBusy => '別のペアリングが進行中です。そちらを完了するか閉じてから、もう一度お試しください。';

  @override
  String get lanSyncQrTitle => 'QR コードでペアリング';

  @override
  String get lanSyncQrSubtitle =>
      'もう一方のスマートフォンの Jotsy で「QR コードをスキャン」をタップしてください';

  @override
  String get lanSyncQrSemantics => 'ペアリング用 QR コード';

  @override
  String lanSyncQrCountdown(String time) {
    return '$time後に新しいコードに切り替わります';
  }

  @override
  String lanSyncQrDeviceLine(String name, String address) {
    return '$name · $address';
  }

  @override
  String get lanSyncQrSingleUse => 'コードは1回限り有効で、スキャンすると無効になります';

  @override
  String get lanSyncQrPreparing => 'QR コードを準備しています…';

  @override
  String get lanSyncQrUseCode => '確認コードでペアリング';

  @override
  String lanSyncQrUseCodeHint(String name) {
    return 'もう一方のデバイスの「近くのデバイス」で「$name」を探し、「ペアリング」をタップしてください';
  }

  @override
  String get lanSyncScanHint => 'もう一方のデバイスに表示された Jotsy の QR コードにカメラを向けてください';

  @override
  String get lanSyncScanHintDetail => 'そのデバイスの同期ページで「QR コードを表示」をタップしてください';

  @override
  String get lanSyncScanTorchOn => 'ライトをオン';

  @override
  String get lanSyncScanTorchOff => 'ライトをオフ';

  @override
  String get lanSyncScanManual => 'QR コードがない場合はアドレスを入力';

  @override
  String get lanSyncScanNotJotsy => 'Jotsy のペアリングコードではありません';

  @override
  String get lanSyncScanNewerVersion => '新しいバージョンの Jotsy のコードです。先にアップデートしてください';

  @override
  String get lanSyncScanMalformed => 'コードが破損しています。新しいコードを表示してもらってください';

  @override
  String get lanSyncScanDeniedTitle => 'カメラへのアクセスが必要です';

  @override
  String get lanSyncScanDeniedBody =>
      'スキャンでは、カメラでもう一方のデバイスの QR コードを読み取ります。システム設定で Jotsy にカメラの使用を許可するか、代わりにアドレスを入力してください。';

  @override
  String get lanSyncScanOpenSettings => '設定を開く';

  @override
  String get lanSyncScanUnavailableTitle => 'カメラを使用できません';

  @override
  String get lanSyncScanUnavailableBody =>
      '使用できるカメラが見つからないか、ほかのアプリがカメラを使用中です。代わりにアドレスを入力できます。';

  @override
  String get lanSyncFlowLocal => 'このデバイス';

  @override
  String lanSyncFlowSent(int count) {
    return '↑ $count件送信';
  }

  @override
  String lanSyncFlowReceived(int count) {
    return '↓ $count件受信';
  }

  @override
  String get lanSyncStepConnect => '接続';

  @override
  String get lanSyncStepCompare => '比較';

  @override
  String get lanSyncStepTransfer => '転送';

  @override
  String get lanSyncStepMerge => '統合';

  @override
  String get lanSyncMediaTransferring => '写真と録音を転送中';

  @override
  String lanSyncMediaFiles(int done, int total) {
    return '$done / $totalファイル';
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
    return '$stage、$percent%完了';
  }

  @override
  String get lanSyncSummaryTitle => '同期完了';

  @override
  String lanSyncSummarySubtitle(String name, int seconds) {
    return '$name と同期 · 所要時間$seconds秒';
  }

  @override
  String get lanSyncSummaryReceived => '↓ 受信';

  @override
  String get lanSyncSummarySent => '↑ 送信';

  @override
  String lanSyncSummaryDiaryUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '件',
    );
    return '$_temp0';
  }

  @override
  String get lanSyncSummaryAdded => '追加';

  @override
  String get lanSyncSummaryUpdated => '更新';

  @override
  String get lanSyncSummaryDeleted => '削除';

  @override
  String get lanSyncSummaryMedia => 'メディア';

  @override
  String lanSyncSummaryMediaValue(int count, String size) {
    return '$count個 · $size';
  }

  @override
  String get lanSyncSummaryOthers => 'その他';

  @override
  String lanSyncSummaryConflicts(int count) {
    return '$count件の日記が両方のデバイスで変更されていたため、両方のバージョンを残しました';
  }

  @override
  String get lanSyncSummaryConflictHint => '元の日記には新しいほうのバージョンが残ります';

  @override
  String get lanSyncUntitled => '無題';

  @override
  String get lanSyncSummaryFootnote => 'タグ、日記帳、コメント、記念日も統合されました';

  @override
  String lanSyncSummaryOtherDetail(String items) {
    return 'その他の変更：$items';
  }

  @override
  String get lanSyncSummaryDone => '完了';

  @override
  String get lanSyncSummaryUpToDate => 'すでに最新の状態です';

  @override
  String get lanSyncSummaryFailedTitle => '同期が完了しませんでした';

  @override
  String get lanSyncSyncFailUnreachable =>
      '相手のデバイスに接続できませんでした。両方のデバイスが同じ Wi-Fi に接続されていて VPN がオフになっていること、相手側で Jotsy が開いていることを確認してください。';

  @override
  String get lanSyncSyncFailConnectionLost =>
      '接続が切れました。書き込み済みの部分は次回の同期で自動的に補完されます。';

  @override
  String get lanSyncSyncFailTimedOut =>
      '相手のデバイスから応答がなくなりました。書き込み済みの部分は次回の同期で自動的に補完されます。';

  @override
  String get lanSyncSyncFailDeclined => '相手のデバイスがこの同期を拒否しました。';

  @override
  String get lanSyncSyncFailCancelled =>
      '同期はキャンセルされました。書き込み済みの部分は次回の同期で自動的に補完されます。';

  @override
  String get lanSyncSyncFailIncompatible =>
      '2台のデバイスの Jotsy のバージョンに互換性がありません。古いほうをアップデートしてから、もう一度同期してください。';

  @override
  String get lanSyncSyncFailUntrusted =>
      '相手のデバイスがこのデバイスを認識しなくなりました。ペアリングを解除してから、もう一度ペアリングしてください。';

  @override
  String get lanSyncSyncFailTicketExpired =>
      'QR コードの有効期限が切れています。新しいコードをスキャンして接続してください。';

  @override
  String get lanSyncSyncFailWriteFailed =>
      'このデバイスに書き込めませんでした。ストレージの空き容量が不足している可能性があります。空き容量を確保してから、もう一度お試しください。';

  @override
  String get lanSyncSyncFailUnknown => '同期が完了しませんでした。もう一度お試しください。';

  @override
  String get lanSyncSyncFailBusy =>
      '相手のデバイスで日記が編集中です。相手側でエディターが閉じられてから、もう一度同期してください。';

  @override
  String get lanSyncSyncFailLocalEditing =>
      'このデバイスで編集中のページがあります。編集中のページを閉じてから同期してください。';

  @override
  String get lanSyncSyncFailDeferred =>
      '「元に戻す」の通知が表示されていたため、何も書き込まれませんでした。通知が消えてから、もう一度同期してください。';

  @override
  String get lanSyncSyncFailNeedsConfirmation =>
      'この同期には確認が必要です。デバイス一覧で「確認」をタップして続行してください。';

  @override
  String get lanSyncSyncReasonUnreachable => 'デバイスに接続できなかった';

  @override
  String get lanSyncSyncReasonConnectionLost => '接続が切れた';

  @override
  String get lanSyncSyncReasonTimedOut => '応答なし';

  @override
  String get lanSyncSyncReasonDeclined => '相手のデバイスが拒否';

  @override
  String get lanSyncSyncReasonCancelled => 'キャンセル済み';

  @override
  String get lanSyncSyncReasonIncompatible => 'バージョンの互換性なし';

  @override
  String get lanSyncSyncReasonUntrusted => '相手のデバイスでペアリングが解除済み';

  @override
  String get lanSyncSyncReasonTicketExpired => 'QR コードの期限切れ';

  @override
  String get lanSyncSyncReasonWriteFailed => 'このデバイスへの書き込みに失敗';

  @override
  String get lanSyncSyncReasonUnknown => '同期に失敗';

  @override
  String get lanSyncSyncReasonBusy => '相手のデバイスが編集中だった';

  @override
  String get lanSyncSyncReasonLocalEditing => 'このデバイスが編集中だった';

  @override
  String get lanSyncSyncReasonDeferred => '「元に戻す」の通知が表示中だった';

  @override
  String get lanSyncSyncReasonNeedsConfirmation => '確認が必要だった';

  @override
  String lanSyncConflictCopySuffix(String device) {
    return '（競合コピー · $device）';
  }

  @override
  String get lanSyncChooseSideTitle => 'どちらのバージョンを優先しますか？';

  @override
  String lanSyncChooseSideBody(String name, int count) {
    return '$count件の日記が、このデバイスと「$name」の両方で変更されています。どのように統合しますか？';
  }

  @override
  String lanSyncChooseSideBodyItems(String name, String items) {
    return '次の項目が、このデバイスと「$name」の両方で変更されています：$items。どのように統合しますか？';
  }

  @override
  String get lanSyncItemDiaries => '日記';

  @override
  String get lanSyncItemTags => 'タグ';

  @override
  String get lanSyncItemNotebooks => '日記帳';

  @override
  String get lanSyncItemComments => 'コメント';

  @override
  String get lanSyncItemTemplates => 'テンプレート';

  @override
  String get lanSyncItemAnniversaries => '記念日';

  @override
  String get lanSyncItemDayMoods => 'この日の気分';

  @override
  String get lanSyncItemTodos => 'ToDo';

  @override
  String get lanSyncItemSettings => '設定';

  @override
  String lanSyncItemCount(String label, int count) {
    return '$label $count';
  }

  @override
  String get lanSyncChooseKeepBoth => '両方を残す（おすすめ）';

  @override
  String get lanSyncChooseKeepBothDesc =>
      '新しいほうのバージョンを元の日記に残し、もう一方は競合コピーとして保存します';

  @override
  String get lanSyncChoosePreferLocal => 'このデバイスのバージョンを使う';

  @override
  String get lanSyncChoosePreferLocalDesc => 'このデバイスのバージョンで、相手のデバイスの変更を上書きします';

  @override
  String get lanSyncChoosePreferPeer => '相手のデバイスのバージョンを使う';

  @override
  String lanSyncChoosePreferPeerDesc(String name) {
    return '「$name」のバージョンで、このデバイスの変更を上書きします';
  }

  @override
  String get lanSyncChooseSideNote => 'どの方法を選んでも日記が削除されることはありません';

  @override
  String get lanSyncContinueSync => '同期を続ける';

  @override
  String get lanSyncDeletionTitle => '日記を完全に削除しますか？';

  @override
  String lanSyncDeletionBodyPeer(String name, int count) {
    return 'この同期により、「$name」上の$count件の日記が完全に削除されます（このデバイスのゴミ箱からはすでに削除されています）。';
  }

  @override
  String lanSyncDeletionBodyLocal(String name, int count) {
    return 'この同期により、このデバイス上の$count件の日記が完全に削除されます（「$name」のゴミ箱からはすでに削除されています）。';
  }

  @override
  String get lanSyncDeletionSync => '削除を同期';

  @override
  String get lanSyncDeletionSyncDesc => 'どちらのデバイスにもこれらの日記は残りません';

  @override
  String get lanSyncDeletionKeep => '残して、もう一方のデバイスに復元';

  @override
  String get lanSyncDeletionKeepDesc => 'これらの日記は、ゴミ箱から削除した側のデバイスに戻ります';

  @override
  String get lanSyncDeviceTitle => 'デバイスの詳細';

  @override
  String get lanSyncInfoLastSync => '前回の同期';

  @override
  String get lanSyncInfoPairedAt => 'ペアリング日';

  @override
  String get lanSyncInfoAddress => 'アドレス';

  @override
  String get lanSyncInfoNever => '未同期';

  @override
  String get lanSyncInfoNoAddress => '不明';

  @override
  String get lanSyncDeviceOffline => 'デバイスはオフラインです';

  @override
  String get lanSyncOfflineUseLastAddress => 'オフライン — 前回のアドレスで接続を試みます';

  @override
  String get lanSyncPeerAutoSyncSubtitle => 'アプリを開いている間、このデバイスと自動で同期します';

  @override
  String get lanSyncPeerAutoSyncGlobalOff => '「同期オプション」の自動同期がオフのため、現在は無効です';

  @override
  String get lanSyncAliasTitle => 'ニックネーム';

  @override
  String get lanSyncAliasNotSet => '未設定';

  @override
  String get lanSyncAliasLocalOnly => 'このデバイスでのみ表示されます';

  @override
  String lanSyncAliasDialogHint(String name) {
    return '空欄にすると「$name」と表示されます';
  }

  @override
  String get lanSyncHistoryTitle => '同期履歴';

  @override
  String get lanSyncHistoryEmpty => 'このデバイスとはまだ同期していません';

  @override
  String get lanSyncHistoryAutomatic => '自動';

  @override
  String lanSyncHistoryDuration(int seconds) {
    return '$seconds秒';
  }

  @override
  String lanSyncHistoryReceived(int count) {
    return '↓ $count件受信';
  }

  @override
  String lanSyncHistorySent(int count) {
    return '↑ $count件送信';
  }

  @override
  String lanSyncHistoryOthers(int count) {
    return 'その他の変更$count件';
  }

  @override
  String lanSyncHistoryMedia(String size) {
    return 'メディア $size';
  }

  @override
  String lanSyncHistoryConflicts(int count) {
    return '競合コピー$count件';
  }

  @override
  String get lanSyncForget => 'ペアリングを解除';

  @override
  String lanSyncForgetTitle(String name) {
    return '「$name」とのペアリングを解除しますか？';
  }

  @override
  String get lanSyncForgetBody =>
      'どちらのデバイスの日記も削除されません。再び同期するには、もう一度ペアリングする必要があります。';

  @override
  String get settingsFeaturesAi => 'AI アシスタント';

  @override
  String get settingsFeaturesAiSubtitle =>
      '自分の AI API を使って、執筆、感想、振り返り、チャットができます';

  @override
  String get aiPersonaAssistantName => '日記アシスタント';

  @override
  String get aiPersonaAssistantDesc => '客観的でわかりやすく、質問への回答や要約に最適';

  @override
  String get aiPersonaAssistantPrompt =>
      'あなたはユーザーの日記アシスタントです。ユーザーが共有した日記を読むことができます。回答はそれらの日記の内容に基づき、客観的でわかりやすく、整理されたものにしてください。確かでないことはそう正直に伝え、日記に書かれていないことを決して作り上げないでください。';

  @override
  String get aiPersonaListenerName => 'あたたかい聞き手';

  @override
  String get aiPersonaListenerDesc => 'まず気持ちを受け止め、やさしく応える';

  @override
  String get aiPersonaListenerPrompt =>
      'あなたはあたたかく辛抱強い聞き手です。ユーザーの日記を読んだら、まず理解を示し、そこに込められた気持ちを受け止めてから、やさしく応えてください。評価したり説教したりせず、アドバイスは控えめにして、共感と肯定を多めに伝えてください。最後に、ユーザーがもう少し考えを深められるような、やわらかな問いかけを1つ添えてもかまいません。';

  @override
  String get aiPersonaFriendName => '親友';

  @override
  String get aiPersonaFriendDesc => '古くからの友達のように気軽におしゃべり';

  @override
  String get aiPersonaFriendPrompt =>
      'あなたはユーザーと長年の付き合いがある友達です。自然体で気取らず、誠実に話し、冗談も言えば真剣にもなります。友達の日記を読んだあとに返事をするように応えてください。気づいた細かな点に触れ、自分の感じたことを伝え、役に立つときだけ実践的なアドバイスをしてください。';

  @override
  String get aiPersonaCoachName => '成長コーチ';

  @override
  String get aiPersonaCoachDesc => 'あなたの進歩と次の小さな一歩を見つける';

  @override
  String get aiPersonaCoachPrompt =>
      'あなたは前向きで実践的な成長コーチです。日記からユーザーの努力や進歩、認めるべき点を見つけ出し、改善できそうなパターンを指摘したうえで、具体的で実行しやすい小さな行動を1〜3つ提案してください。励ましながらも、中身のない言葉にならないようにしてください。';

  @override
  String get aiPersonaAnalystName => '理性的なアナリスト';

  @override
  String get aiPersonaAnalystDesc => '何が起きたのか、なぜなのかを冷静に整理';

  @override
  String get aiPersonaAnalystPrompt =>
      'あなたは冷静で理性的なアナリストです。日記に書かれた出来事の経緯、その背後にある理由、取りうる選択肢をユーザーが整理できるよう手助けしてください。事実と感情を区別し、見落としているかもしれない視点を指摘してください。簡潔に、構造立てて伝えてください。';

  @override
  String get aiPersonaCounselorName => 'カウンセラー風';

  @override
  String get aiPersonaCounselorDesc => '問いかけで自分の気持ちに気づかせてくれる';

  @override
  String get aiPersonaCounselorPrompt =>
      'あなたはカウンセラーがよく用いる方法で応答します。傾聴し、相手の言葉を繰り返して明確にし、開かれた質問を使ってユーザーが自分の感情や欲求に気づけるよう手助けします。結論やアドバイスを急いではいけません。あなたは専門的な心理療法の代わりではありません。日記に自分や他人を傷つけたいという考えが書かれていた場合は、身近な人や専門機関に助けを求めるよう、やさしく勧めてください。';

  @override
  String get aiPersonaPoetName => '詩人';

  @override
  String get aiPersonaPoetDesc => 'あなたの一日に詩的な言葉で応える';

  @override
  String get aiPersonaPoetPrompt =>
      'あなたはやさしい詩人です。ユーザーの日記に、イメージ豊かで詩的、それでいて難解ではない言葉で応えてください。その日の気分や情景をとらえた短い散文詩や、数行の詩を書いてもかまいません。';

  @override
  String get aiPersonaPhilosopherName => '哲学者';

  @override
  String get aiPersonaPhilosopherDesc => 'より広い視点から考える';

  @override
  String get aiPersonaPhilosopherPrompt =>
      'あなたは親しみやすい哲学者です。日記に書かれた具体的で小さな出来事から出発し、意味、選択、時間、人間関係といったより大きな問いへとつなげてください。ふさわしい思想や比喩を用いつつ親しみやすさを保ち、最後はユーザー自身の生活に立ち返ってください。';

  @override
  String get aiPersonaFutureSelfName => '未来の自分';

  @override
  String get aiPersonaFutureSelfDesc => '10年後のあなたからの返信';

  @override
  String get aiPersonaFutureSelfPrompt =>
      'あなたは10年後のユーザー本人で、この日記を読み返しています。一人称で、過去の自分に宛てた短い手紙を書いてください。やさしく、物事がその後どうなったかを知っていて、時間がもたらす落ち着きと知恵をたたえた語り口にしてください。ただし、具体的な未来の出来事を作り上げてはいけません。';

  @override
  String get aiPersonaRoastName => '毒舌な悪友';

  @override
  String get aiPersonaRoastDesc => '口は悪いけど、心はあなたの味方';

  @override
  String get aiPersonaRoastPrompt =>
      'あなたは口は悪いけれど根はやさしい悪友です。日記に書かれた出来事を、ユーモアと誇張を交えていじってください。ただし、ユーザーの本当の痛みをからかったり、容姿やアイデンティティなどのデリケートな話題に触れたりしてはいけません。最後には思いやりをのぞかせてください。';

  @override
  String get aiActionContinue => '続きを書く';

  @override
  String get aiActionContinuePrompt =>
      '以下の日記の続きを、同じ語り口と雰囲気のまま、自然な段落1つ分（150〜300文字程度）で書いてください。新しく書いた部分だけを出力し、すでにある内容は繰り返さないでください。';

  @override
  String get aiActionPolish => '推敲';

  @override
  String get aiActionPolishPrompt =>
      '以下の文章を、より読みやすく自然になるよう推敲してください。ぎこちない言い回しを直し、意味、トーン、一人称の視点はそのまま保ち、文章を長くしないでください。';

  @override
  String get aiActionExpand => '膨らませる';

  @override
  String get aiActionExpandPrompt =>
      '以下の文章に細部や気持ち、情景を書き加えて内容を豊かにし、長さをおよそ2倍にしてください。元のトーンと視点は保ってください。';

  @override
  String get aiActionShorten => '簡潔にする';

  @override
  String get aiActionShortenPrompt =>
      '以下の文章を半分ほどの長さに縮めてください。重要な情報と気持ちは残し、繰り返しや冗長な部分は削ってください。';

  @override
  String get aiActionProofread => '誤りを修正';

  @override
  String get aiActionProofreadPrompt =>
      '以下の文章の誤字脱字、句読点、文法の誤りを修正してください。それ以外はそのまま残し、書き換えないでください。';

  @override
  String get aiActionToneFormal => 'よりフォーマルに';

  @override
  String get aiActionToneFormalPrompt =>
      '以下の文章を、意味を保ったまま、よりフォーマルで洗練された語調に書き換えてください。';

  @override
  String get aiActionToneCasual => 'よりカジュアルに';

  @override
  String get aiActionToneCasualPrompt =>
      '以下の文章を、意味を保ったまま、友達とおしゃべりしているような、肩の力を抜いた話し言葉の語調に書き換えてください。';

  @override
  String get aiActionToneWarm => 'よりあたたかく';

  @override
  String get aiActionToneWarmPrompt =>
      '以下の文章を、意味を保ったまま、よりあたたかくやわらかい語調に書き換え、やさしさと思いやりを込めてください。';

  @override
  String get aiActionToneHumor => 'ユーモラスに';

  @override
  String get aiActionToneHumorPrompt =>
      '以下の文章を、意味を保ったまま、遊び心のある比喩やちょっとした自虐を交えて、よりユーモラスに書き換えてください。';

  @override
  String get aiActionToneLiterary => 'より文学的に';

  @override
  String get aiActionToneLiteraryPrompt =>
      '以下の文章を、より文学的な文体に書き換えてください。繊細な描写とふさわしい修辞を用いつつ、美辞麗句を並べ立てないようにしてください。意味は保ってください。';

  @override
  String get aiActionTranslate => '翻訳';

  @override
  String get aiActionTranslatePrompt =>
      '以下の文章を翻訳してください。主に日本語で書かれている場合は英語に、それ以外の場合は日本語に翻訳してください。訳文だけを出力してください。';

  @override
  String get aiActionSummarize => '要約';

  @override
  String get aiActionSummarizePrompt => '以下の文章の要点を2〜3文で要約してください。';

  @override
  String get aiActionBulletPoints => '箇条書き';

  @override
  String get aiActionBulletPointsPrompt =>
      '以下の文章を、短い項目からなるわかりやすい箇条書き（Markdown の順序なしリスト）にまとめてください。';

  @override
  String get aiActionExtractTodos => 'タスクを抽出';

  @override
  String get aiActionExtractTodosPrompt =>
      '以下の文章に出てくるタスク、予定、フォローアップが必要な事柄を見つけ、Markdown のタスクリストとして1行に1つずつ、「- [ ] 」で始めて書き出してください。見つからない場合は、その旨を1行だけで返してください。';

  @override
  String get aiActionPoem => '詩にする';

  @override
  String get aiActionPoemPrompt => '以下の内容を、その気分や情景を残したまま、4〜12行の短い現代詩にしてください。';

  @override
  String get aiErrorNotConfigured =>
      'AI モデルがまだ設定されていません。「設定 → AI アシスタント」でプロバイダーを追加してください。';

  @override
  String get aiErrorNetwork =>
      'AI サービスに接続できませんでした。ネットワーク、API アドレス、プロキシを確認してください。';

  @override
  String get aiErrorTimeout => 'AI サービスの応答がタイムアウトしました。';

  @override
  String get aiErrorUnauthorized => 'API キーが無効か、入力されていません。';

  @override
  String get aiErrorForbidden => 'このキーではこのモデルを利用できないか、お住まいの地域ではサービスを利用できません。';

  @override
  String get aiErrorModelNotFound =>
      'モデルまたはアドレスが見つかりません。モデル名と API アドレスを確認してください。';

  @override
  String get aiErrorRateLimited => 'リクエストが多すぎます。しばらくしてからもう一度お試しください。';

  @override
  String get aiErrorQuota => 'アカウントの残高または利用枠が不足しています。';

  @override
  String get aiErrorContextTooLong =>
      'このモデルで処理できる量を超えています。AI のプライバシー設定で文字数の上限を下げるか、より長いコンテキストに対応したモデルを選んでください。';

  @override
  String get aiErrorContentFiltered => 'AI サービスのコンテンツポリシーにより、このリクエストは拒否されました。';

  @override
  String get aiErrorBadRequest =>
      'AI サービスがリクエストを受け付けませんでした。プロバイダーの詳細設定を確認してください。';

  @override
  String get aiErrorServer => 'AI サービスで問題が発生しているか、混雑しています。しばらくしてからもう一度お試しください。';

  @override
  String get aiErrorBadResponse =>
      '応答の内容を解釈できませんでした。アドレスが API ではなくウェブページを指している可能性があります。';

  @override
  String get aiErrorCancelled => '停止しました';

  @override
  String get aiErrorDetails => '詳細';

  @override
  String get aiErrorOpenSettings => '設定を開く';

  @override
  String get aiSettingsTitle => 'AI アシスタント';

  @override
  String get aiSettingsEntrySubtitle => 'プロバイダー、モデル、ペルソナ、プライバシー';

  @override
  String get aiSettingsFooter =>
      '開発者を経由することは一切ありません。リクエストはこのデバイスから、設定したプロバイダーへ直接送られます。API キーはこのデバイスにのみ保存され、バックアップや同期に含まれることはありません。';

  @override
  String get aiStatusNotConfiguredTitle => 'AI サービスが未設定です';

  @override
  String get aiStatusNotConfiguredBody =>
      'プロバイダーを追加して API キーを入力すると、エディター、プレビュー、ホームに AI 機能が表示されます。内容は自分で設定したサービスにのみ送信されます。';

  @override
  String get aiStatusAddProvider => 'プロバイダーを追加';

  @override
  String get aiStatusDefaultModel => 'デフォルトのモデル';

  @override
  String get aiStatusTest => '接続テスト';

  @override
  String get aiStatusTesting => 'テスト中…';

  @override
  String aiStatusTestOk(int ms) {
    return '接続成功 · $ms ms';
  }

  @override
  String get aiGroupService => 'サービス';

  @override
  String get aiProvidersTitle => 'プロバイダー';

  @override
  String aiProvidersCount(int count) {
    return '$count件のプロバイダー';
  }

  @override
  String get aiProvidersEmpty => 'まだありません';

  @override
  String get aiRoutingTitle => 'モデルの割り当て';

  @override
  String get aiRoutingSubtitle => '機能ごとに異なるモデルを使用します';

  @override
  String get aiGroupFeatures => '機能';

  @override
  String get aiGroupFeaturesFooter => 'オフにしても入口が非表示になるだけで、既存の AI の記録は残ります。';

  @override
  String get aiModuleWriting => '執筆アシスタント';

  @override
  String get aiModuleWritingSubtitle => 'エディターでの続き書き、推敲、トーン変更、翻訳、カスタムコマンド';

  @override
  String get aiModuleSuggest => 'スマート入力';

  @override
  String get aiModuleSuggestSubtitle => 'タイトルの生成と、タグや気分の提案';

  @override
  String get aiModuleReply => 'AI の感想';

  @override
  String get aiModuleReplySubtitle => 'プレビューで AI に日記を読んでもらい、感想を返してもらいます';

  @override
  String get aiModulePrompts => '執筆のヒント';

  @override
  String get aiModulePromptsSubtitle => '何を書けばいいかわからないときに、いくつか質問を出します';

  @override
  String get aiModuleRecap => '振り返りと気づき';

  @override
  String get aiModuleRecapSubtitle => '週・月・年、または日記帳ごとにまとめを作成';

  @override
  String get aiModuleChat => '会話と操作';

  @override
  String get aiModuleChatSubtitle =>
      '日記について質問したり、AI に検索・集計・日記の作成・整理・設定の変更などを任せたりできます';

  @override
  String get aiModuleVision => '画像の理解';

  @override
  String get aiModuleVisionSubtitle =>
      '日記の写真を本文と一緒に送信します。モデルが画像に対応していない場合はテキストのみ送信します';

  @override
  String get aiOptionTitleButton => 'タイトルの横に「タイトルを生成」を表示';

  @override
  String get aiOptionAutoSuggest => '投稿ページで提案';

  @override
  String get aiOptionAutoSuggestSubtitle =>
      '日記を1回送信してタイトル、タグ、気分を提案します。タップするまで入力はされません';

  @override
  String get aiOptionAutoReply => '投稿後に感想を返す';

  @override
  String get aiOptionAutoReplySubtitle => '新しい日記を投稿するたびに1回送信し、感想を生成します';

  @override
  String get aiOptionPromptsStrip => '新規日記でヒントを表示';

  @override
  String get aiOptionPromptsStripSubtitle => 'タップするまで何も送信されません';

  @override
  String get aiOptionPromptsRecent => '最近の日記を参考にする';

  @override
  String get aiOptionPromptsRecentSubtitle => '最近の日記の抜粋を送信し、よりあなたに合った質問を作ります';

  @override
  String get aiOptionPromptStyle => '挿入形式';

  @override
  String get aiPromptStyleCallout => 'コールアウト';

  @override
  String get aiPromptStyleQuote => '引用';

  @override
  String get aiPromptStyleHeading => '見出し';

  @override
  String get aiOptionRecapSections => '振り返りに含める内容';

  @override
  String get aiRecapSectionMood => '気分の推移';

  @override
  String get aiRecapSectionEvents => '大切な出来事';

  @override
  String get aiRecapSectionPeople => '身近な人たち';

  @override
  String get aiRecapSectionGratitude => '感謝';

  @override
  String get aiRecapSectionGrowth => '成長と変化';

  @override
  String get aiRecapSectionQuotes => '心に残る言葉';

  @override
  String get aiRecapSectionSuggestions => '次のステップ';

  @override
  String get aiOptionRetrieval => '日記の探し方';

  @override
  String get aiOptionRetrievalSubtitle =>
      'スマートは質問を理解してから探し、キーワードは語句が一致するものだけを探し、最近は直近の数日分だけを読みます';

  @override
  String get aiRetrievalSmart => 'スマート';

  @override
  String get aiRetrievalKeyword => 'キーワード';

  @override
  String get aiRetrievalRecent => '最近';

  @override
  String get aiOptionRecentDays => 'さかのぼる日数';

  @override
  String aiDays(int count) {
    return '$count日間';
  }

  @override
  String get aiOptionMaxCitations => '最大参照数';

  @override
  String aiEntries(int count) {
    return '$count件';
  }

  @override
  String get aiOptionShowReasoning => '思考過程を表示';

  @override
  String get aiOptionShowTokens => 'トークン使用量を表示';

  @override
  String get aiOptionAutoTitle => 'チャットのタイトルを自動生成';

  @override
  String get aiOptionVisionImages => '1回に送る写真の上限';

  @override
  String aiPhotos(int count) {
    return '$count枚';
  }

  @override
  String get aiOptionVisionSize => '写真のサイズ';

  @override
  String get aiVisionSizeSmall => '小';

  @override
  String get aiVisionSizeMedium => '中';

  @override
  String get aiVisionSizeLarge => '大';

  @override
  String get aiGroupPersonal => 'パーソナライズ';

  @override
  String get aiPersonasTitle => 'ペルソナ';

  @override
  String get aiPersonasSubtitle => '感想・チャット・振り返りを誰の口調で書くか';

  @override
  String get aiActionsTitle => '執筆コマンド';

  @override
  String get aiActionsSubtitle => '並べ替え、非表示、プロンプトの書き換え、独自コマンドの追加';

  @override
  String get aiProfileTitle => '自分について・文体';

  @override
  String get aiProfileSubtitle => 'AI にあなたのことを知ってもらう（任意）';

  @override
  String get aiOutputLanguage => '回答の言語';

  @override
  String get aiLanguageFollowDiary => '日記と同じ';

  @override
  String get aiLanguageFollowApp => 'アプリと同じ';

  @override
  String get aiLanguageCustom => '指定';

  @override
  String get aiLanguageCustomHint => '例：English、Français';

  @override
  String get aiResponseLength => '回答の長さ';

  @override
  String get aiLengthShort => '短め';

  @override
  String get aiLengthMedium => '標準';

  @override
  String get aiLengthLong => '詳しく';

  @override
  String get aiCreativity => '創造性';

  @override
  String get aiCreativitySubtitle => '温度パラメーターに対応したプロバイダーでのみ有効です';

  @override
  String get aiCreativityPrecise => '厳密';

  @override
  String get aiCreativityBalanced => 'バランス';

  @override
  String get aiCreativityCreative => '創造的';

  @override
  String get aiGroupPrivacy => 'プライバシーと使用量';

  @override
  String get aiPrivacyTitle => 'プライバシー';

  @override
  String get aiPrivacySubtitle => '送信する情報と除外する日記';

  @override
  String get aiUsageTitle => '使用量';

  @override
  String get aiUsageSubtitle => 'このデバイスから送ったリクエスト数とトークン数';

  @override
  String get aiProvidersFooter =>
      'デフォルトモデルが未設定の場合は、最初に使用可能なプロバイダーを使います。「モデルの割り当て」で変更できます。';

  @override
  String aiProviderModelsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count個のモデル',
      zero: 'モデルなし',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderDisabled => '無効';

  @override
  String get aiProviderNoKey => 'キー未設定';

  @override
  String get aiPresetSheetTitle => 'プロバイダーを選択';

  @override
  String get aiPresetGroupChina => '中国のサービス';

  @override
  String get aiPresetGroupInternational => '国際サービス';

  @override
  String get aiPresetGroupLocal => 'ローカルで実行';

  @override
  String get aiPresetGroupCustom => 'カスタム API';

  @override
  String get aiPresetNameDashscope => 'Qwen（Alibaba Cloud）';

  @override
  String get aiPresetNameMoonshot => 'Kimi（Moonshot）';

  @override
  String get aiPresetNameZhipu => 'Zhipu GLM';

  @override
  String get aiPresetNameVolcengine => 'Doubao（Volcengine Ark）';

  @override
  String get aiPresetNameSiliconflow => 'SiliconFlow';

  @override
  String get aiPresetNameHunyuan => 'Tencent Hunyuan';

  @override
  String get aiPresetNameCustomOpenAi => 'OpenAI 互換 API';

  @override
  String get aiPresetNameCustomAnthropic => 'Anthropic 互換 API';

  @override
  String get aiPresetNameCustomGemini => 'Gemini API';

  @override
  String get aiProtocolOpenAi => 'OpenAI 互換';

  @override
  String get aiProtocolAnthropic => 'Anthropic（Claude）';

  @override
  String get aiProtocolGemini => 'Google Gemini';

  @override
  String get aiProviderEditTitleNew => 'プロバイダーを追加';

  @override
  String get aiProviderEditTitle => 'プロバイダーを編集';

  @override
  String get aiProviderName => '名前';

  @override
  String get aiProviderProtocol => 'API 形式';

  @override
  String get aiProviderBaseUrl => 'API の URL';

  @override
  String get aiProviderBaseUrlHint => '例：https://api.example.com/v1';

  @override
  String get aiProviderApiKey => 'API キー';

  @override
  String get aiProviderApiKeyOptional => 'API キー（ローカルサービスでは省略可）';

  @override
  String get aiProviderGetKey => 'キーを取得';

  @override
  String get aiProviderLocalHint =>
      'スマートフォンからパソコン上の Ollama や LM Studio に接続するには、localhost をパソコンの LAN アドレスに置き換え、サーバーが 0.0.0.0 で待ち受けるよう設定してください。';

  @override
  String get aiProviderModels => 'モデル';

  @override
  String get aiProviderFetchModels => 'モデル一覧を取得';

  @override
  String get aiProviderAddModel => '手動で追加';

  @override
  String get aiProviderModelsEmpty =>
      'モデルがまだありません。プロバイダーから一覧を取得するか、モデル名を手動で追加してください。';

  @override
  String get aiProviderModelIdHint => 'モデル名（例：deepseek-chat）';

  @override
  String get aiModelVision => '画像';

  @override
  String get aiModelReasoning => '思考';

  @override
  String get aiModelEditTitle => 'モデル設定';

  @override
  String get aiModelDisplayName => '表示名（任意）';

  @override
  String get aiModelVisionToggle => '画像入力に対応';

  @override
  String get aiModelReasoningToggle => '思考過程をリクエスト';

  @override
  String get aiModelReasoningSubtitle =>
      'モデルに思考過程を返してもらいます。非対応のモデルでは自動的に外して再試行します';

  @override
  String get aiModelToolsToggle => 'ツール呼び出しに対応';

  @override
  String get aiModelToolsSubtitle =>
      'AI アシスタントがアプリを直接操作できます。非対応のモデルでは通常の質問応答に切り替わります';

  @override
  String get aiToolGetAppContext => '今日の日付とアプリの状態を確認';

  @override
  String get aiToolReadGuide => '使い方ガイドを確認';

  @override
  String aiPromptAgentGuide(String index) {
    return '以下は Jotsy の使い方ガイドの目次です。使い方や場所、何ができるかを聞かれたら、まず read_guide で関連する記事を読み、その内容に沿って答えてください。アプリにないものを作り上げないでください。\n$index';
  }

  @override
  String get aiHubQuickHelp => 'Jotsy ではどんなことができますか？';

  @override
  String aiToolOpenPage(String page) {
    return '移動：$page';
  }

  @override
  String get aiToolPageUnavailable => 'このページは現在使えません（機能がオフか、この端末では非対応です）';

  @override
  String get aiToolSearchDiaries => '日記を検索';

  @override
  String aiToolSearchDiariesFor(String query) {
    return '日記を検索：$query';
  }

  @override
  String aiToolFoundEntries(int count) {
    return '$count 件見つかりました';
  }

  @override
  String aiToolReadDiaries(int count) {
    return '日記を $count 件読む';
  }

  @override
  String aiToolReadEntries(int count) {
    return '$count 件読みました';
  }

  @override
  String get aiToolDiaryStats => '日記を集計';

  @override
  String aiToolStatsEntries(int count) {
    return '合計 $count 件';
  }

  @override
  String get aiToolListTags => 'タグを確認';

  @override
  String aiToolTagCount(int count) {
    return 'タグ $count 個';
  }

  @override
  String get aiToolListNotebooks => '日記帳を確認';

  @override
  String aiToolNotebookCount(int count) {
    return '日記帳 $count 冊';
  }

  @override
  String get aiToolCalendarDay => '今日のカレンダーを確認';

  @override
  String aiToolCalendarDayOf(String date) {
    return '$date のカレンダーを確認';
  }

  @override
  String get aiToolListTodos => 'ToDo を確認';

  @override
  String aiToolTodoCount(int count) {
    return 'ToDo $count 件';
  }

  @override
  String get aiToolListAnniversaries => '記念日を確認';

  @override
  String aiToolAnniversaryCount(int count) {
    return '記念日 $count 件';
  }

  @override
  String get aiToolCreateDiary => '日記を新規作成';

  @override
  String aiToolCreateDiaryNamed(String title) {
    return '日記を新規作成：$title';
  }

  @override
  String aiToolDiaryCreated(String name) {
    return '「$name」を保存しました';
  }

  @override
  String get aiToolAppendDiary => '日記の末尾に追記';

  @override
  String get aiToolUpdateDiary => '日記の情報を変更';

  @override
  String aiToolDiaryChanged(String name) {
    return '「$name」を変更しました';
  }

  @override
  String aiToolTagDiaries(int count) {
    return '$count 件の日記のタグを変更';
  }

  @override
  String aiToolEntriesChanged(int count) {
    return '$count 件を変更しました';
  }

  @override
  String get aiToolPinDiaries => '日記をピン留め';

  @override
  String get aiToolUnpinDiaries => 'ピン留めを解除';

  @override
  String get aiToolArchiveDiaries => '日記をアーカイブ';

  @override
  String get aiToolUnarchiveDiaries => 'アーカイブから戻す';

  @override
  String aiToolTrashDiaries(int count) {
    return '$count 件の日記をごみ箱へ移動';
  }

  @override
  String aiToolEntriesTrashed(int count) {
    return '$count 件をごみ箱へ移動しました';
  }

  @override
  String get aiToolAddComment => 'コメントを追加';

  @override
  String aiToolCreateTag(String name) {
    return 'タグを作成：$name';
  }

  @override
  String aiToolRenameTag(String name) {
    return 'タグを変更：$name';
  }

  @override
  String aiToolMergeTags(String from, String into) {
    return '$from を $into に統合';
  }

  @override
  String aiToolDeleteTag(String name) {
    return 'タグ $name を削除';
  }

  @override
  String aiToolCreateNotebook(String name) {
    return '日記帳を作成：$name';
  }

  @override
  String aiToolRenameNotebook(String name) {
    return '日記帳の名前を変更：$name';
  }

  @override
  String aiToolAddToNotebook(int count) {
    return '$count 件の日記を日記帳に追加';
  }

  @override
  String aiToolRemoveFromNotebook(int count) {
    return '$count 件の日記を日記帳から外す';
  }

  @override
  String aiToolCreateTodo(String title) {
    return 'ToDo を追加：$title';
  }

  @override
  String aiToolUpdateTodos(int count) {
    return 'ToDo を $count 件変更';
  }

  @override
  String aiToolCompleteTodos(int count) {
    return 'ToDo を $count 件完了';
  }

  @override
  String aiToolDeleteTodos(int count) {
    return 'ToDo を $count 件削除';
  }

  @override
  String aiToolCreateAnniversary(String title) {
    return '記念日を追加：$title';
  }

  @override
  String get aiToolDeleteAnniversary => '記念日を削除';

  @override
  String aiToolSetDayMood(String date) {
    return '$date の気分を設定';
  }

  @override
  String get aiToolSetTheme => 'テーマを変更';

  @override
  String aiToolSetLanguage(String language) {
    return '表示言語を $language に変更';
  }

  @override
  String get aiToolSetFontScale => '文字サイズを変更';

  @override
  String aiToolFeatureOn(String feature) {
    return '機能をオン：$feature';
  }

  @override
  String aiToolFeatureOff(String feature) {
    return '機能をオフ：$feature';
  }

  @override
  String get aiToolDone => '完了しました';

  @override
  String get aiToolListTodoLists => 'ToDo リストを確認';

  @override
  String aiToolTodoListCount(int count) {
    return 'リスト $count 件';
  }

  @override
  String aiToolReopenTodos(int count) {
    return 'ToDo を $count 件未完了に戻す';
  }

  @override
  String get aiToolEditTodoSteps => 'ToDo のステップを編集';

  @override
  String aiToolEditTodoStepsOf(String title) {
    return 'ステップを編集：$title';
  }

  @override
  String aiToolCreateTodoList(String name) {
    return 'ToDo リストを作成：$name';
  }

  @override
  String aiToolRenameTodoList(String name) {
    return 'ToDo リストの名前を変更：$name';
  }

  @override
  String aiToolDeleteTodoList(String name) {
    return 'ToDo リスト $name を削除';
  }

  @override
  String aiToolDeleteTodoListCount(int count) {
    return '中の ToDo $count 件も一緒に削除されます';
  }

  @override
  String get aiToolGetSettings => '設定を確認';

  @override
  String get aiToolChangeSettingsAny => '設定を変更';

  @override
  String aiToolChangeSetting(String name) {
    return '設定を変更：$name';
  }

  @override
  String aiToolChangeSettings(int count) {
    return '設定を $count 件変更';
  }

  @override
  String aiToolSettingName(String page, String setting) {
    return '$page · $setting';
  }

  @override
  String get aiToolArgNone => 'なし';

  @override
  String get aiToolArgOn => 'オン';

  @override
  String get aiToolArgOff => 'オフ';

  @override
  String get aiToolBlockedByEditor => '編集中のページがあります。閉じてからもう一度お試しください';

  @override
  String get aiAgentConfirmDelete => '削除しますか？';

  @override
  String get aiAgentConfirmChange => 'この変更を行いますか？';

  @override
  String get aiAgentDelete => '削除';

  @override
  String get aiAgentProceed => '実行';

  @override
  String get aiAgentUndo => '元に戻す';

  @override
  String get aiAgentStepUndone => '元に戻しました';

  @override
  String aiAgentUndone(int count) {
    return '$count 件の変更を元に戻しました';
  }

  @override
  String aiAgentUndoFailed(String error) {
    return '元に戻せませんでした：$error';
  }

  @override
  String get aiAgentUndoConflictTitle => 'その後に変更されています';

  @override
  String get aiAgentUndoConflictBody =>
      'AI の変更のあとにさらに編集されています。元に戻すとその編集も上書きされます。それでも元に戻しますか？';

  @override
  String get aiAgentUndoConflictAction => 'それでも元に戻す';

  @override
  String get aiOptionAgentChanges => 'AI によるデータの変更を許可';

  @override
  String get aiOptionAgentChangesSubtitle =>
      '日記の作成・編集、タグや日記帳の整理、ToDo の追加、設定の変更など。変更はすべて元に戻せ、削除の前には確認します';

  @override
  String get aiOptionAgentConfirm => '変更のたびに確認';

  @override
  String get aiOptionAgentConfirmSubtitle =>
      'オフのときはすぐに実行し、あとから元に戻せます。削除は常に確認します';

  @override
  String get aiDestinationDiary => 'この日記';

  @override
  String get aiDestinationSearch => '日記を検索';

  @override
  String get aiAgentPreparing => '操作を準備中…';

  @override
  String get aiAgentStepFailed => '失敗しました';

  @override
  String get aiAgentStepCancelled => '停止しました';

  @override
  String get aiAgentStepInterrupted => '中断されました';

  @override
  String aiAgentOpenPage(String page) {
    return '$pageを開く';
  }

  @override
  String get aiAgentStepsExhausted => 'この回答で使える操作の回数を使い切りました。「続けて」と送ると続きを行います。';

  @override
  String get aiAgentIncomplete => '回答が途中で切れたため、その中の操作は実行していません。';

  @override
  String get aiConfirmSendAgent => 'AI は必要に応じて日記を検索・閲覧します（非公開の日記は除く）。毎回は確認しません';

  @override
  String get aiOptionAgent => 'AI にツールを使わせる';

  @override
  String get aiOptionAgentSubtitle =>
      '日記の検索・集計、カレンダーや ToDo の確認、ページを開くなどを必要に応じて行います。オフまたは非対応のモデルでは検索した日記をもとに答えるだけです';

  @override
  String get aiOptionAgentSteps => '1 回の回答の最大ステップ数';

  @override
  String get aiOptionAgentStepsSubtitle => '1 ステップで複数のツールを呼べます。最後のステップは回答のみ';

  @override
  String get aiPromptAgentSystem =>
      'ツールを呼び出して、Jotsy にあるユーザーのデータを調べたり変更したり、アプリのページを開いたりできます。\n- ユーザーのデータが必要なときは、記憶や推測で答えず先にツールで調べてください。互いに依存しない呼び出しはまとめて出せます。\n- ユーザーがはっきり頼んだ変更だけを行い、どの日記を何に変えるか迷うときは先に確認してください。変更はすべて元に戻せます。削除はアプリがユーザーに確認するので、対象がはっきりしていれば会話で聞き直さずにそのまま呼び出してください。\n- 回答の下のカードは open_page でしか作れません。一回の呼び出しで一枚、カードには日記・日記帳・ページの名前が表示されます。複数の対象を開けるようにするには、対象ごとに一回ずつ呼び出してください。\n- 実際に成功したことだけを伝えてください。対応するツール呼び出しが成功していないのに「開きました」「変更しました」「カードは下にあります」と言わないでください。回答にツール名、引数、ID、操作の記録を書かないでください。\n- 検索や変更のツールと一緒に書いた文は折りたたまれてユーザーには見えません。open_page と一緒に書いた文はカードの上に表示されます。結論・説明・手順はユーザーに見えるところに書き、同じことを二度言わないでください。\n- 日記に触れるときは、ツールの結果にある番号を文末に [D3] のように書いてください（タップできるラベルとして表示されます）。\n- ユーザー自身がページで行う必要があること（バックアップ、復元、インポート・エクスポート、共有、アプリロック、パスワード、AI プロバイダの設定、完全削除など）は、open_page で移動ボタンを示し、やり方を説明してください。\n- ツールがエラーを返したら、その説明に従って直すか別の方法を試してください。本当にできないときはそう伝えてください。';

  @override
  String aiPromptAgentNow(String time) {
    return '現在は $time です。';
  }

  @override
  String get aiPromptAgentScopeDiary => 'この会話は次の日記についてです：';

  @override
  String aiPromptAgentScopeRange(String from, String to) {
    return 'この会話は $from から $to までの日記だけが対象です。特に指示がなければ、検索にはこの期間を使ってください。';
  }

  @override
  String get aiModelMaxOutput => '最大出力トークン数';

  @override
  String get aiModelContext => 'コンテキスト長（トークン）';

  @override
  String get aiModelAuto => '自動';

  @override
  String get aiModelRemove => 'モデルを削除';

  @override
  String get aiModelPickerTitle => '使用するモデルを選択';

  @override
  String get aiModelPickerSearch => 'モデルを検索';

  @override
  String aiModelPickerAdd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count個を追加',
      zero: '追加',
    );
    return '$_temp0';
  }

  @override
  String get aiModelPickerEmpty => 'プロバイダーからモデルが返されませんでした。モデル名を手動で追加してください。';

  @override
  String get aiProviderAdvanced => '詳細設定';

  @override
  String get aiProviderProxy => 'HTTP プロキシ';

  @override
  String get aiProviderProxyHint => 'ホスト:ポート（例：127.0.0.1:7890）。空欄なら直接接続';

  @override
  String get aiProviderHeaders => 'カスタムヘッダー';

  @override
  String get aiProviderHeadersHint => '1行に1つ、「名前: 値」の形式で入力';

  @override
  String get aiProviderExtraBody => '追加のリクエストフィールド（JSON）';

  @override
  String get aiProviderExtraBodyHint =>
      'すべてのリクエストにマージされる JSON オブジェクト。プロバイダー固有のオプションに使います';

  @override
  String get aiProviderExtraBodyInvalid => '有効な JSON オブジェクトではありません';

  @override
  String get aiProviderStream => 'ストリーミング';

  @override
  String get aiProviderStreamSubtitle =>
      '生成しながら回答を表示します。中継サービスが対応していない場合はオフにしてください';

  @override
  String get aiProviderIncludeUsage => '使用量をリクエスト';

  @override
  String get aiProviderIncludeUsageSubtitle =>
      'ストリーミング中にトークン使用量を返してもらいます。リクエストが失敗する場合はオフにしてください';

  @override
  String get aiProviderSendTemperature => '温度パラメーターを送信';

  @override
  String get aiProviderSendTemperatureSubtitle =>
      '新しい Claude モデルは受け付けないため、Anthropic ではオフになっています';

  @override
  String get aiProviderTimeout => '最初の応答までの待ち時間';

  @override
  String aiSeconds(int count) {
    return '$count秒';
  }

  @override
  String get aiProviderRetries => '再試行回数';

  @override
  String aiTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count回',
      zero: 'オフ',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderEnabled => '有効';

  @override
  String get aiProviderDelete => 'プロバイダーを削除';

  @override
  String aiProviderDeleteTitle(String name) {
    return '「$name」を削除しますか？';
  }

  @override
  String get aiProviderDeleteBody =>
      'キーとモデルの設定も削除され、このプロバイダーに割り当てていた機能はデフォルトモデルに戻ります。';

  @override
  String get aiProviderNameRequired => '名前を入力してください';

  @override
  String get aiProviderUrlInvalid => 'http:// または https:// で始まるアドレスを入力してください';

  @override
  String get aiProviderNeedModel => '先にモデルを1つ以上追加してください';

  @override
  String get aiProviderDiscardTitle => '変更を破棄しますか？';

  @override
  String get aiProviderDiscard => '破棄';

  @override
  String get aiRoutingDefault => 'デフォルトモデル';

  @override
  String get aiRoutingDefaultSubtitle => '個別にモデルを指定していないすべての機能で使われます';

  @override
  String get aiRoutingFast => '高速モデル';

  @override
  String get aiRoutingFastSubtitle =>
      'スマート入力や執筆のヒントなど、短いタスクで優先的に使います。安くて速いモデルがおすすめです';

  @override
  String get aiRoutingTasksGroup => '機能ごとの指定';

  @override
  String get aiRoutingFollowDefault => 'デフォルトと同じ';

  @override
  String get aiRoutingFollowFast => '高速モデルと同じ';

  @override
  String aiRoutingFirstUsable(String name) {
    return '最初に使用可能なもの（$name）';
  }

  @override
  String get aiRoutingNone => '未設定';

  @override
  String get aiRoutingPickTitle => 'モデルを選択';

  @override
  String get aiTaskWriting => '執筆アシスタント';

  @override
  String get aiTaskSuggest => 'スマート入力';

  @override
  String get aiTaskReply => 'AI の感想';

  @override
  String get aiTaskPrompts => '執筆のヒント';

  @override
  String get aiTaskRecap => '振り返り';

  @override
  String get aiTaskChat => 'チャット';

  @override
  String get aiTaskVision => '画像の説明';

  @override
  String get aiTaskUtility => 'バックグラウンドの小さなタスク';

  @override
  String get aiTaskUtilitySubtitle => 'チャットのタイトル、検索プラン、長い振り返りの部分要約';

  @override
  String get aiPersonasDefaultsGroup => 'デフォルトのペルソナ';

  @override
  String get aiPersonaUseReply => 'AI の感想';

  @override
  String get aiPersonaUseChat => 'チャット';

  @override
  String get aiPersonaUseRecap => '振り返り';

  @override
  String get aiPersonasBuiltInGroup => '組み込みペルソナ';

  @override
  String get aiPersonasMineGroup => 'マイペルソナ';

  @override
  String get aiPersonasMineEmpty =>
      '自分のペルソナはまだありません。新しく作るか、組み込みペルソナをコピーして編集できます。';

  @override
  String get aiPersonaAdd => '新しいペルソナ';

  @override
  String get aiPersonaDuplicate => 'マイペルソナにコピー';

  @override
  String get aiPersonaEditTitleNew => '新しいペルソナ';

  @override
  String get aiPersonaEditTitle => 'ペルソナを編集';

  @override
  String get aiPersonaName => '名前';

  @override
  String get aiPersonaEmoji => '絵文字';

  @override
  String get aiPersonaPrompt => 'プロンプト';

  @override
  String get aiPersonaPromptHint => 'どんな人物か、どんな話し方をするか、あなたの日記にどう応えるかを書いてください';

  @override
  String aiPersonaLimit(int count) {
    return 'ペルソナは最大$count個までです';
  }

  @override
  String aiPersonaCopySuffix(String name) {
    return '$name（コピー）';
  }

  @override
  String get aiCommonHidden => '非表示';

  @override
  String get aiCommonHide => '非表示にする';

  @override
  String get aiCommonShow => '表示する';

  @override
  String get aiCommonRestoreDefault => 'デフォルトに戻す';

  @override
  String aiCommonDeleted(String name) {
    return '「$name」を削除しました';
  }

  @override
  String get aiActionsFooter => 'ドラッグで並べ替えられます。ここでの順番がエディターでのコマンドの並び順になります。';

  @override
  String get aiActionAdd => '新しいコマンド';

  @override
  String get aiActionCustomized => '編集済み';

  @override
  String get aiActionEditTitleNew => '新しいコマンド';

  @override
  String get aiActionEditTitle => 'コマンドを編集';

  @override
  String get aiActionName => '名前';

  @override
  String get aiActionEmoji => 'アイコン';

  @override
  String get aiActionPrompt => 'プロンプト';

  @override
  String get aiActionPromptHint => 'テキストをどう処理するか AI に指示してください';

  @override
  String get aiActionVariables => '変数を挿入';

  @override
  String get aiActionVariablesHelp =>
      'プロンプトに「テキスト」変数がない場合、対象のテキストはプロンプトの後ろに自動で付け加えられます。';

  @override
  String get aiVariableText => 'テキスト';

  @override
  String get aiVariableDiary => '全文';

  @override
  String get aiVariableTitle => 'タイトル';

  @override
  String get aiVariableDate => '日付';

  @override
  String get aiVariableMood => '気分';

  @override
  String get aiActionOutput => '結果の扱い';

  @override
  String get aiOutputReplace => '置き換え';

  @override
  String get aiOutputInsertBelow => '下に挿入';

  @override
  String get aiOutputPreview => 'プレビューのみ';

  @override
  String aiActionLimit(int count) {
    return 'コマンドは最大$count個までです';
  }

  @override
  String get aiActionResetPromptTitle => 'デフォルトのプロンプトに戻しますか？';

  @override
  String get aiProfileAboutMe => '自分について';

  @override
  String get aiProfileAboutMeHint => '仕事や今の暮らし、大切にしていることなど。AI が応答するときに参考にします。';

  @override
  String get aiProfileStyle => '好みの文体';

  @override
  String get aiProfileStyleHint => '例：シンプルで素朴に、形容詞は控えめ、短い文で';

  @override
  String get aiProfileFooter => 'これらはリクエストのたびに一緒に送信されます。空欄にすると送信されません。';

  @override
  String get aiPrivacySendGroup => '日記と一緒に送信する情報';

  @override
  String get aiPrivacySendFooter =>
      'タイトルと本文は常に送信されます。プライベート日記帳、ゴミ箱、開封前のタイムカプセルが送信されることはありません。';

  @override
  String get aiPrivacyDate => '日付';

  @override
  String get aiPrivacyMood => '気分';

  @override
  String get aiPrivacyTags => 'タグ';

  @override
  String get aiPrivacyWeather => '天気';

  @override
  String get aiPrivacyLocation => '場所';

  @override
  String get aiPrivacyScopeGroup => 'チャットと振り返りの範囲';

  @override
  String get aiPrivacyIncludeArchived => 'アーカイブした日記を含める';

  @override
  String get aiPrivacyExcludedNotebooks => '除外する日記帳';

  @override
  String get aiPrivacyExcludedTags => '除外するタグ';

  @override
  String get aiPrivacyExcludedNone => 'なし';

  @override
  String aiPrivacyExcludedCount(int count) {
    return '$count件選択中';
  }

  @override
  String get aiPrivacyPickNotebooks => '除外する日記帳を選択';

  @override
  String get aiPrivacyPickTags => '除外するタグを選択';

  @override
  String get aiPrivacyPickEmpty => '選択できる項目がありません';

  @override
  String get aiPrivacyBudget => '送信の上限';

  @override
  String get aiPrivacyBudgetSubtitle =>
      '日記は1件ずつ全文が送信されます。1回のリクエストの合計がこの文字数を超えるときだけ切り詰めます。';

  @override
  String aiWords(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    return '$countString文字';
  }

  @override
  String get aiPrivacyConfirmGroup => '送信前の確認';

  @override
  String get aiPrivacyConfirmSubtitle =>
      '初回：プロバイダーごとに1回だけ確認します。複数件のとき：チャットと振り返りでは送信する件数と文字数を毎回表示します。毎回：すべてのリクエストで確認します。';

  @override
  String get aiConfirmFirstTime => '初回';

  @override
  String get aiConfirmMultiDiary => '複数件のとき';

  @override
  String get aiConfirmAlways => '毎回';

  @override
  String get aiPrivacyAllowPrivate => 'プライベートな日記で AI を許可';

  @override
  String get aiPrivacyAllowPrivateSubtitle =>
      'プライベート日記帳でも執筆アシスタントと AI の感想が使えるようになります。チャットと振り返りでは引き続き読み込まれません。';

  @override
  String get aiPrivacyResetHosts => 'すべてのプロバイダーで再確認';

  @override
  String get aiPrivacyResetHostsSubtitle => '初回の確認をもう一度表示します';

  @override
  String get aiPrivacyResetHostsDone => 'リセットしました。次回の送信前にもう一度確認します。';

  @override
  String get aiUsageEmpty => '使用量の記録はまだありません';

  @override
  String aiUsageRequests(int count) {
    return '$count回のリクエスト';
  }

  @override
  String aiUsageFailures(int count) {
    return '$count回失敗';
  }

  @override
  String aiUsageTokens(String input, String output) {
    return '入力：$input · 出力：$output';
  }

  @override
  String aiUsageTokensCached(String input, String cached, String output) {
    return '入力 $input（キャッシュ $cached）· 出力 $output';
  }

  @override
  String aiUsageMonthTotal(String tokens) {
    return '合計$tokensトークン';
  }

  @override
  String get aiUsageClear => '使用量の記録を消去';

  @override
  String get aiUsageClearTitle => '使用量の記録を消去しますか？';

  @override
  String get aiUsageClearBody => 'このデバイスの統計だけが消去されます。プロバイダー側の請求には影響しません。';

  @override
  String get aiUsageFooter =>
      'このデバイスから送信したリクエストだけを集計しています。実際の費用はプロバイダーの請求をご確認ください。';

  @override
  String get aiPrivacyRecordsGroup => 'AI の記録';

  @override
  String get aiPrivacyRecordsFooter =>
      'チャット、AI の感想、振り返りはこのデバイスと完全バックアップに保存されます。LAN 同期の対象にはなりません。';

  @override
  String get aiPrivacyClearRecords => 'すべての AI の記録を消去';

  @override
  String aiPrivacyClearRecordsSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'チャットと結果$count件',
      zero: 'まだ何も保存されていません',
    );
    return '$_temp0';
  }

  @override
  String get aiPrivacyClearRecordsTitle => 'すべての AI の記録を消去しますか？';

  @override
  String get aiPrivacyClearRecordsBody =>
      'すべてのチャット、AI の感想、振り返りがこのデバイスから削除されます。この操作は元に戻せません。日記そのものには影響しません。';

  @override
  String get aiPrivacyClearRecordsDone => 'AI の記録を消去しました';

  @override
  String get aiPromptSystemBase =>
      'あなたは個人向け日記アプリ Jotsy に搭載された AI アシスタントです。対話の相手は日記の書き手本人です。誠実かつ具体的に応じ、日記に書かれていない事実を決して作り上げないでください。';

  @override
  String aiPromptAboutUser(String text) {
    return 'ユーザーについて：$text';
  }

  @override
  String aiPromptWritingStyle(String text) {
    return 'ユーザーが好む文体：$text';
  }

  @override
  String aiPromptRespondIn(String language) {
    return '$languageで回答してください。';
  }

  @override
  String get aiPromptRespondLikeDiary => '日記と同じ言語で回答してください。';

  @override
  String get aiPromptLanguageChinese => '中国語';

  @override
  String get aiPromptLanguageEnglish => '英語';

  @override
  String get aiPromptLanguageJapanese => '日本語';

  @override
  String get aiPromptLanguageRussian => 'ロシア語';

  @override
  String get aiPromptLengthShort => '回答は数文程度に短くまとめてください。';

  @override
  String get aiPromptLengthMedium => '回答は適度な長さにしてください。';

  @override
  String get aiPromptLengthLong => '詳しく回答してかまいません。';

  @override
  String aiPromptPersona(String text) {
    return 'あなたの役割：$text';
  }

  @override
  String get aiPromptFieldTitle => 'タイトル';

  @override
  String get aiPromptFieldDate => '日付';

  @override
  String get aiPromptFieldMood => '気分';

  @override
  String get aiPromptFieldTags => 'タグ';

  @override
  String get aiPromptFieldWeather => '天気';

  @override
  String get aiPromptFieldLocation => '場所';

  @override
  String get aiPromptFieldBody => '本文';

  @override
  String get aiPromptTruncated => '（以下省略）';

  @override
  String aiPromptImagesAttached(int count) {
    return '日記の写真が$count枚添付されています。';
  }

  @override
  String get aiPromptWritingSystem =>
      'あなたは、ユーザーが自分の日記に手を入れるのを手伝う執筆アシスタントです。処理後のテキストだけを出力し、説明・引用符・前置きは付けないでください。一人称の視点を保ってください。Markdown の箇条書き、太字、タスクリストは使ってかまいませんが、見出しは使わないでください。';

  @override
  String get aiPromptWritingContext => '参考として、日記の全文を示します（繰り返さないでください）：';

  @override
  String aiPromptCustomInstruction(String text) {
    return '次の指示に従って、以下のテキストを処理してください：$text';
  }

  @override
  String get aiPromptReplyInstruction =>
      '以下はユーザーが書いた日記です。あなた自身として読み、ユーザーに直接応答してください。日記の内容を言い直したり、見出しを使ったりしないでください。';

  @override
  String get aiPromptSuggestInstruction =>
      '以下の日記をもとに、次のものを提案してください：引用符を付けない20文字以内の短く的確なタイトル、ユーザーの既存のタグから0〜3個、本当に役立つ場合に限り各6文字以内の新しいタグを最大2個、そして与えられた選択肢から最も合う気分を1つ（確信が持てなければ空のまま）。次の形式どおりの JSON オブジェクトを1つだけ出力してください：';

  @override
  String aiPromptSuggestTagsList(String tags) {
    return 'ユーザーの既存のタグ：$tags';
  }

  @override
  String aiPromptSuggestMoodList(String moods) {
    return '気分の選択肢：$moods';
  }

  @override
  String get aiPromptPromptsInstruction =>
      'ユーザーが今日の日記を書き始めやすくなるような、具体的でやさしい質問を3つ考えてください。1行に1つの質問とし、番号は付けず、それ以外は何も書かないでください。';

  @override
  String aiPromptPromptsToday(String date) {
    return '今日：$date';
  }

  @override
  String get aiPromptPromptsRecent => '質問をよりユーザーに寄り添ったものにするための、最近の日記の抜粋：';

  @override
  String aiPromptRecapInstruction(String period) {
    return '以下は、ユーザーが$periodに書いた日記です。Markdown の小見出しで構成した振り返りを書いてください。次の項目を含めてください：';
  }

  @override
  String get aiPromptRecapRules =>
      '日記に書かれている内容だけを使い、作り上げないでください。特定の日に触れるときは日付を書いてください。[Dn] の印が付いた日記は、文末に [Dn] と書いて引用できます。';

  @override
  String get aiPromptRecapChunk =>
      '以下は、ある期間の一部分の日記です。起きたこと、気持ち、考えを箇条書きで要約してください。あとで振り返りにまとめられるよう、具体的な日付や細部は残してください。';

  @override
  String get aiPromptRecapFromSummaries => '以下は、この期間を連続する部分に分けた要約です（古い順）：';

  @override
  String aiPromptRecapStats(int count, int words) {
    return '統計：日記$count件、$words文字。';
  }

  @override
  String aiPromptRecapMoods(String moods) {
    return '気分の内訳：$moods';
  }

  @override
  String aiPromptRecapTopTags(String tags) {
    return 'よく使われたタグ：$tags';
  }

  @override
  String get aiPromptChatSystem =>
      'あなたはユーザーの日記の一部を読むことができます。各日記には [Dn] の印が付いています。これらの日記に基づいて回答してください。ある日記を使ったときは、[D3] のように文末にその印を書いてください。日記にないことは作り上げず、見つからなければそう伝えてください。';

  @override
  String get aiPromptChatContextHeader => '関連する日記：';

  @override
  String get aiPromptChatNoDiaries => '（この質問に一致する日記はありませんでした。）';

  @override
  String aiPromptChatToday(String date) {
    return '今日は$dateです。';
  }

  @override
  String get aiPromptChatTitle => 'この会話のテーマを15文字以内で要約してください。タイトルだけを出力してください。';

  @override
  String aiPromptRetrievalPlan(String date) {
    return 'ユーザーの質問を日記の検索プランに変換してください。今日は$dateです。日記に出てきそうな短いキーワードを最大8個（類義語を含む）挙げ、質問が期間を示唆している場合に限り日付範囲も示してください。次の形式どおりの JSON オブジェクトを1つだけ出力してください：';
  }

  @override
  String get aiPromptDescribeImage =>
      '日記の写真の説明として、この写真に写っているものとその雰囲気を1〜2文で描写してください。説明文だけを出力してください。';

  @override
  String get aiToolbarLabel => 'AI 執筆';

  @override
  String get aiPanelTitle => 'AI 執筆';

  @override
  String get aiScopeSelection => '選択したテキスト';

  @override
  String get aiScopeParagraph => 'この段落';

  @override
  String get aiScopeBeforeCaret => 'カーソルより前のテキスト';

  @override
  String get aiScopeDocument => '全文';

  @override
  String aiScopeSummary(String scope, int words) {
    return '$scope · $words文字';
  }

  @override
  String get aiPanelInstructionHint => 'AI への指示を入力（例：「もっとくだけた感じに」）';

  @override
  String get aiPanelSend => '送信';

  @override
  String get aiPanelThinking => '考え中…';

  @override
  String get aiPanelReplace => '置き換え';

  @override
  String get aiPanelInsertBelow => '下に挿入';

  @override
  String get aiPanelCopy => 'コピー';

  @override
  String get aiPanelCopied => 'コピーしました';

  @override
  String get aiPanelStop => '停止';

  @override
  String get aiPanelEmptyTarget => '処理するテキストがまだありません。先に何か書くか、テキストを選択してください。';

  @override
  String get aiPanelReasoning => '思考過程';

  @override
  String get aiPanelPrivateBlocked =>
      'この日記はプライベート日記帳にあります。AI のプライバシー設定で、プライベートな日記への AI の使用を許可できます。';

  @override
  String get aiSlashGroup => 'AI';

  @override
  String get aiSlashWrite => 'AI 執筆…';

  @override
  String get aiSlashContinue => 'AI で続きを書く';

  @override
  String get aiSlashPrompts => '執筆のヒント';

  @override
  String get aiSelectionMenu => 'AI…';

  @override
  String get aiImageDescribe => 'AI で画像を説明';

  @override
  String get aiImageDescribing => '写真を説明しています…';

  @override
  String get aiImageNoVision =>
      '現在のモデルは画像を扱えません。「モデルの割り当て」で「画像の説明」に画像対応のモデルを選んでください。';

  @override
  String get aiSuggestTitle => 'AI でタイトルを生成';

  @override
  String get aiSuggestMeta => 'AI でタグと気分を提案';

  @override
  String get aiSuggesting => 'AI が考えています…';

  @override
  String get aiSuggestNeedContent => 'AI が提案できるように、先に本文を少し書いてください。';

  @override
  String get aiSuggestTitleApplied => 'AI が生成したタイトルを入力しました';

  @override
  String get aiSuggestTagsHeader => 'AI のおすすめ';

  @override
  String aiSuggestNewTag(String name) {
    return '「$name」を作成';
  }

  @override
  String get aiSuggestMoodButton => 'AI で判定';

  @override
  String get aiSuggestNothing => '今回は提案がありませんでした';

  @override
  String get aiSuggestApplied => 'AI の提案を適用しました';

  @override
  String aiConfirmSendTitle(String host) {
    return '$host に送信しますか？';
  }

  @override
  String aiConfirmSendModel(String name) {
    return '「$name」が処理します';
  }

  @override
  String aiConfirmSendEntries(int count, int words) {
    return '日記$count件、約$words文字';
  }

  @override
  String aiConfirmSendText(int words) {
    return '約$words文字のテキスト';
  }

  @override
  String aiConfirmSendImages(int count) {
    return '写真$count枚も添付';
  }

  @override
  String get aiConfirmSendNote =>
      'このデバイスから直接送信され、開発者が目にすることはありません。プロバイダーは自社のプライバシーポリシーに従って取り扱います。';

  @override
  String get aiConfirmSendRemember => 'このプロバイダーには今後確認しない';

  @override
  String get aiConfirmSendAction => '送信';

  @override
  String aiRepliesHeading(int count) {
    return 'AI の感想 · $count';
  }

  @override
  String get aiReplyAsk => 'AI に感想を頼む…';

  @override
  String get aiReplyMoreItem => 'AI の感想';

  @override
  String get aiReplyPickPersona => '誰に感想を書いてもらいますか？';

  @override
  String get aiReplyWriting => '日記を読んでいます…';

  @override
  String get aiReplyRegenerate => '再生成';

  @override
  String get aiReplySaveAsComment => 'コメントとして保存';

  @override
  String get aiReplyContinueChat => '続けて話す';

  @override
  String get aiReplyDeleted => '感想を削除しました';

  @override
  String get aiReplyExpand => 'もっと見る';

  @override
  String get aiReplyCollapse => '折りたたむ';

  @override
  String get aiReplyStopped => '停止しました。もう一度試しますか？';

  @override
  String get aiReplyDismiss => '閉じる';

  @override
  String get aiReplyAutoSkipped =>
      '自動の感想は送信されませんでした。このプロバイダーを確認するため、まず一度手動で AI の感想を依頼してください。';

  @override
  String get aiPromptsStripLabel => '執筆のヒントをもらう';

  @override
  String get aiPromptsLoading => '質問を考えています…';

  @override
  String get aiPromptsRefresh => '別の質問';

  @override
  String get aiPromptsTitle => '執筆のヒント';

  @override
  String get aiPromptsHint => '質問をタップすると本文に追加されます';

  @override
  String get aiPromptsEmpty => '今回は質問が思いつきませんでした。もう一度試しますか？';

  @override
  String get aiPromptsClose => 'ヒントを閉じる';

  @override
  String get aiReplySavedAsComment => 'コメントとして保存しました';

  @override
  String get aiRecapTitle => 'AI 振り返り';

  @override
  String get aiRecapRange => '期間';

  @override
  String get aiRecapThisWeek => '今週';

  @override
  String get aiRecapLastWeek => '先週';

  @override
  String get aiRecapThisMonth => '今月';

  @override
  String get aiRecapLastMonth => '先月';

  @override
  String get aiRecapThisYear => '今年';

  @override
  String get aiRecapCustom => 'カスタム…';

  @override
  String get aiRecapNotebook => '日記帳';

  @override
  String get aiRecapAllNotebooks => 'すべての日記';

  @override
  String get aiRecapSections => '含める項目';

  @override
  String get aiRecapPersona => '口調';

  @override
  String get aiRecapGenerate => '振り返りを作成';

  @override
  String get aiRecapNoEntries => 'この期間には振り返る日記がありません。';

  @override
  String aiRecapReading(int index, int total) {
    return 'パート$index/$totalを読んでいます…';
  }

  @override
  String get aiRecapWriting => '振り返りを書いています…';

  @override
  String aiRecapStats(int count, int words) {
    return '$count件 · $words文字';
  }

  @override
  String get aiRecapSaved => '振り返りの記録に保存しました';

  @override
  String get aiRecapSaveAsDiary => '日記として保存';

  @override
  String get aiRecapShare => 'テキストを共有';

  @override
  String get aiRecapDeleted => '振り返りを削除しました';

  @override
  String aiRecapPeriodRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String aiRecapDiaryTitle(String period) {
    return '$periodの振り返り';
  }

  @override
  String get aiHubQuickMonth => '今月はどんなふうに過ごしていた？';

  @override
  String get aiHubQuickWorry => '最近、何に悩むことが多い？';

  @override
  String get aiHubQuickLastYear => '去年の今ごろ、何をしていた？';

  @override
  String get aiHubQuickHappy => '最近うれしかった小さなことは？';

  @override
  String get aiHubQuickGrowth => 'この半年で、私はどう変わった？';

  @override
  String get aiHubRecapMore => 'その他のオプション…';

  @override
  String get aiHubSearchChats => 'チャットを検索';

  @override
  String get aiChatUntitled => '新しいチャット';

  @override
  String get aiChatPin => 'ピン留め';

  @override
  String get aiChatUnpin => 'ピン留めを解除';

  @override
  String get aiChatRename => '名前を変更';

  @override
  String get aiChatRenameTitle => 'チャット名を変更';

  @override
  String get aiChatDeleted => 'チャットを削除しました';

  @override
  String get aiChatInputHint => '質問を入力…';

  @override
  String get aiChatPlanning => '質問を理解しています…';

  @override
  String get aiChatSearching => '関連する日記を探しています…';

  @override
  String aiChatCitations(int count) {
    return '日記$count件を参照';
  }

  @override
  String get aiChatNoCitations => '関連する日記は見つかりませんでした';

  @override
  String get aiChatScope => '範囲';

  @override
  String get aiChatScopeAuto => '自動';

  @override
  String aiChatScopeRecent(int days) {
    return '過去$days日間';
  }

  @override
  String get aiChatScopeAll => 'すべての日記';

  @override
  String get aiChatScopeRange => '期間を指定…';

  @override
  String get aiChatScopeEntry => 'この日記';

  @override
  String get aiChatPersona => 'ペルソナ';

  @override
  String get aiChatModel => 'モデル';

  @override
  String aiChatModelDefault(String name) {
    return 'デフォルト（$name）';
  }

  @override
  String get aiChatEditResend => '編集して再送信';

  @override
  String get aiChatDeleteMessage => 'メッセージを削除';

  @override
  String get aiChatCitationMissing => 'この日記はもう存在しません';

  @override
  String aiChatAboutEntry(String title) {
    return '「$title」について';
  }

  @override
  String get aiHubTooltip => 'AI アシスタント';

  @override
  String get exploreModuleAi => 'AI インサイト';

  @override
  String get exploreModuleAiDesc => '最新の振り返りと、日記への質問';

  @override
  String get aiExploreNoRecap => '振り返りはまだありません。今週の振り返りを作ってみませんか？';

  @override
  String get aiExploreWeekly => '今週の振り返り';

  @override
  String get aiExploreAsk => '日記に聞いてみる';

  @override
  String get aiExploreNotConfigured => 'AI サービスを設定すると使えます';

  @override
  String get aiRecapStopped => '停止しました。途中までの振り返りは保存されません。';

  @override
  String get aiRecapHistory => '過去の振り返り';

  @override
  String get aiRecapDeleteTitle => 'この振り返りを削除しますか？';

  @override
  String get aiRecapNotebookPick => '日記帳を選択';

  @override
  String get aiRecapCustomRange => '日付を選択';

  @override
  String get aiRecapShareUnavailable => 'コピーしました。共有したい場所に貼り付けてください。';

  @override
  String aiRecapModel(String model) {
    return '$model が作成';
  }

  @override
  String get aiChatMore => 'その他';

  @override
  String aiChatTokens(String input, String output) {
    return '入力：$input · 出力：$output';
  }

  @override
  String aiChatTokensCached(String input, String cached, String output) {
    return '入力 $input（キャッシュ $cached）· 出力 $output';
  }

  @override
  String get aiChatStoppedLabel => '停止済み';

  @override
  String get aiChatDeleteMessageTitle => 'このメッセージを削除しますか？';

  @override
  String get aiChatDeleteTitle => 'このチャットを削除しますか？';

  @override
  String get aiChatDeleteBody => 'チャット内のメッセージも削除されます。日記には影響しません。';

  @override
  String get aiChatRangeTitle => '日付を選択';

  @override
  String get aiChatScopeTitle => '検索する範囲';

  @override
  String get aiChatScopeAutoSubtitle => 'AI 設定の検索方法に従います';

  @override
  String get aiSettingsOpenHub => 'AI アシスタントを開く';

  @override
  String get aiSettingsOpenHubSubtitle => '日記への質問と振り返りの作成';

  @override
  String get aiProtocolOpenAiResponses => 'OpenAI Responses';

  @override
  String get aiPresetNameCustomOpenAiResponses => 'OpenAI Responses API';

  @override
  String get cloudBackupBackupNow => 'バックアップ';

  @override
  String get cloudIncrementalBusyScan => '変更を確認しています…';

  @override
  String get cloudIncrementalBusyCheck => 'クラウドストレージのバックアップを読み込んでいます…';

  @override
  String get cloudIncrementalBusyPrune => '古いバックアップを整理しています…';

  @override
  String cloudIncrementalUploaded(String size) {
    return 'バックアップしました。今回のアップロード：$size';
  }

  @override
  String get cloudIncrementalUnchanged => '変更はありません。クラウドストレージのバックアップは最新です';

  @override
  String get cloudIncrementalNewPasswordMessage =>
      'このパスワードはこのデバイスに記憶され、今後のバックアップと自動バックアップに使われます。別のデバイスで復元するときに必要です。空欄にすると暗号化しません。';

  @override
  String get cloudIncrementalExistingEncryptedMessage =>
      'このクラウドストレージには暗号化された増分バックアップがあります。パスワードを入力すると、写真やメディアを再アップロードせずに続けてバックアップできます。';

  @override
  String get cloudIncrementalContinue => '続ける';

  @override
  String get cloudIncrementalWrongPasswordTitle => 'パスワードが違います';

  @override
  String get cloudIncrementalWrongPasswordContent =>
      'このパスワードではクラウドストレージ上の増分バックアップを開けません。もう一度入力するか、新しい増分バックアップを開始してください（すべての写真とメディアが再アップロードされます）。';

  @override
  String get cloudIncrementalRetry => '再入力';

  @override
  String get cloudIncrementalStartNew => '新しく開始';

  @override
  String get cloudIncrementalExistingPlainTitle => '既存のバックアップを続けますか？';

  @override
  String get cloudIncrementalExistingPlainContent =>
      'このクラウドストレージには暗号化されていない増分バックアップがあります。続ける場合は新しい内容だけをアップロードします。暗号化したい場合は新しく開始してください（すべての写真とメディアが再アップロードされます）。';

  @override
  String get cloudIncrementalContinueExisting => '続ける';

  @override
  String get cloudIncrementalRememberedMismatchContent =>
      'このデバイスに記憶されているパスワードでは、クラウドストレージ上の増分バックアップを開けなくなりました。別のデバイスでパスワードが変更された可能性があります。リセットしてから、元のパスワードを入力するか新しく開始してください。';

  @override
  String get cloudIncrementalRestorePasswordMessage =>
      'この増分バックアップは暗号化されています。作成時に設定したパスワードを入力してください。';

  @override
  String get cloudIncrementalEntryTitle => '増分バックアップ';

  @override
  String get cloudIncrementalEntryMissing => 'スナップショットファイルがないため復元できません';

  @override
  String get cloudIncrementalDeleteTitle => 'この増分バックアップを削除しますか？';

  @override
  String cloudIncrementalDeleteContent(String time) {
    return '$timeの増分バックアップを削除します。このバックアップだけが使っている写真とメディアもクラウドストレージから削除されます。ほかのバックアップには影響しません。この操作は元に戻せません。';
  }

  @override
  String get cloudIncrementalSectionTitle => '増分バックアップ';

  @override
  String get cloudIncrementalSectionHint =>
      '「バックアップ」では新しい写真と変更されたデータだけをアップロードし、すでにクラウドストレージにあるものは再アップロードしません。このデバイスで復元するときも足りない分だけをダウンロードするので、クラウドストレージの転送量を節約できます。';

  @override
  String get cloudIncrementalKeepTitle => '保持数';

  @override
  String get cloudIncrementalKeepSubtitle =>
      '古い増分バックアップは自動的に削除され、それだけが使っていた写真とメディアも一緒に整理されます';

  @override
  String get cloudIncrementalKeepAll => 'すべて';

  @override
  String cloudIncrementalKeepCount(int count) {
    return '$count件';
  }

  @override
  String get cloudAutoBackupTitle => '自動バックアップ';

  @override
  String get cloudAutoBackupSubtitle =>
      '予定の時期になると、アプリを開いたときや閉じたときにバックグラウンドで自動的にバックアップします。新しい内容が 50 MB を超える場合は、手動でのバックアップを待ちます';

  @override
  String get cloudAutoBackupNeedsChain => 'オンにする前に、一度手動でバックアップしてください';

  @override
  String get cloudAutoBackupIntervalTitle => '頻度';

  @override
  String get cloudAutoBackupDaily => '毎日';

  @override
  String get cloudAutoBackupWeekly => '毎週';

  @override
  String cloudAutoBackupLastUploaded(String time, String size) {
    return '前回の自動バックアップ：$time、$sizeをアップロード';
  }

  @override
  String cloudAutoBackupLastUnchanged(String time) {
    return '前回の自動バックアップ：$time、変更なし';
  }

  @override
  String cloudAutoBackupLastNeedsManual(String time, String size) {
    return '$time：新しい内容が$sizeあります。手動でバックアップしてください';
  }

  @override
  String cloudAutoBackupLastFailed(String time, String reason) {
    return '$timeに自動バックアップが失敗しました：$reason';
  }

  @override
  String cloudAutoBackupTileOk(String time) {
    return '自動バックアップ · $time';
  }

  @override
  String get cloudAutoBackupTileNeedsManual => '手動バックアップが必要';

  @override
  String get cloudAutoBackupTileFailed => '自動バックアップに失敗';

  @override
  String get cloudIncrementalForgetChain => 'パスワードをリセット';

  @override
  String get cloudIncrementalForgetTitle => '増分バックアップのパスワードをリセットしますか？';

  @override
  String get cloudIncrementalForgetContent =>
      'このデバイスは現在の増分バックアップのパスワードを忘れ、自動バックアップは一時停止します。次回のバックアップ時に、元のパスワードを入力して続けるか、新しいパスワードを設定して最初からやり直せます（すべての写真とメディアが再アップロードされます）。';

  @override
  String get cloudIncrementalForgotten => '増分バックアップのパスワードを消去しました';

  @override
  String get cloudIncrementalErrorPassword => 'このパスワードではこの増分バックアップを開けません';

  @override
  String get cloudIncrementalErrorMediaChanged =>
      'バックアップ中に写真または添付ファイルが変更されました。もう一度お試しください';

  @override
  String get textSelectionMenuMore => 'その他';

  @override
  String get textSelectionMenuLess => '折りたたむ';

  @override
  String passcodeDotsSemantics(int filled, int total) {
    return '$total 桁中 $filled 桁入力済み';
  }

  @override
  String get passcodeDelete => '削除';

  @override
  String get passcodePatternSemantics => 'パターン入力：点を線でつないでください';

  @override
  String get passcodeUseBiometric => '指紋または顔で解除';

  @override
  String passcodeWrongAttemptsLeft(int count) {
    return '違います。あと $count 回間違えると待ち時間が発生します';
  }

  @override
  String get passcodeWrongPin => 'パスコードが違います。もう一度入力してください';

  @override
  String get passcodeWrongPattern => 'パターンが違います。もう一度描いてください';

  @override
  String passcodePatternTooShort(int count) {
    return '短すぎます。$count 個以上の点をつないでください';
  }

  @override
  String passcodeLockedOutSeconds(int seconds) {
    return '$seconds 秒後にもう一度お試しください';
  }

  @override
  String passcodeLockedOutMinutes(int minutes) {
    return '$minutes 分後にもう一度お試しください';
  }

  @override
  String get passcodeUnavailable => 'アプリのパスコードを読み込めませんでした。アプリを再起動してからお試しください';

  @override
  String get passcodeEnterPinTitle => 'アプリのパスコードを入力';

  @override
  String get passcodeDrawPatternTitle => 'パターンを描く';

  @override
  String get passcodeForgot => 'パスコードを忘れた場合';

  @override
  String get passcodeForgotMessage =>
      'アプリのパスコードはこの端末にのみ保存され、復元できません。アプリのデータを消去するか再インストールし、バックアップから日記を復元するしかありません。';

  @override
  String get appLockPasscodeSubtitle => 'アプリのパスコードで確認して続行します';

  @override
  String get passcodeVerifyTitle => '本人確認';

  @override
  String passcodeFormPin(int count) {
    return '$count 桁の数字';
  }

  @override
  String get passcodeFormPattern => 'パターン';

  @override
  String get passcodeConfirmPinTitle => 'もう一度入力';

  @override
  String get passcodeConfirmPatternTitle => 'もう一度描く';

  @override
  String get passcodeConfirmMessage => '確認のため、同じものをもう一度';

  @override
  String get passcodeSetupPinTitle => '数字のパスコードを設定';

  @override
  String passcodeSetupPinMessage(int count) {
    return '$count 桁の数字を入力してください';
  }

  @override
  String get passcodeSetupPatternTitle => '解除パターンを設定';

  @override
  String passcodeSetupPatternMessage(int count) {
    return '$count 個以上の点を一筆でつなぎます';
  }

  @override
  String get passcodeMismatch => '一致しませんでした。最初からやり直してください';

  @override
  String get passcodeSaveFailed => '保存できませんでした。もう一度お試しください';

  @override
  String get passcodeChangeTitle => 'アプリのパスコードを変更';

  @override
  String get passcodeSetupTitle => 'アプリのパスコードを設定';

  @override
  String get passcodeNoRecoveryNote =>
      'アプリのパスコードはこの端末にのみ保存され、バックアップや同期には含まれません。忘れると復元できません。';

  @override
  String get appLockSwitchToPasscodeReason => 'アプリのパスコードに切り替えるため本人確認します';

  @override
  String get appLockSwitchVerifyFailed => '認証できませんでした。認証方法は変更されていません';

  @override
  String get passcodeSetDone => 'アプリのパスコードを設定しました';

  @override
  String get appLockSystemUnsupported => 'この端末ではシステム認証を使えません（画面ロックが未設定）';

  @override
  String get appLockSwitchToSystemReason => 'システム認証に切り替えるため、アプリのパスコードで確認します';

  @override
  String get appLockSwitchedToSystem => 'システム認証に切り替え、アプリのパスコードを削除しました';

  @override
  String get passcodeChangeReason => '変更するため、現在のパスコードで確認します';

  @override
  String get passcodeChangedDone => 'アプリのパスコードを変更しました';

  @override
  String get passcodeBiometricEnableReason => 'クイック解除をオンにするため、指紋または顔で確認します';

  @override
  String get passcodeBiometricFailed => '指紋または顔の認証に失敗しました';

  @override
  String get settingsAppLockAndPasscode => 'アプリロックとパスコード';

  @override
  String get appLockMethodTitle => '認証方法';

  @override
  String get appLockMethodFooter =>
      'アプリロック、ロックした日記帳、LAN ペアリングの確認はすべてこの方法で認証します。';

  @override
  String get appLockNeedsPasscode =>
      'この端末にはシステム認証がありません。先に下でアプリのパスコードを設定してください';

  @override
  String get appLockMethodSystem => 'システム認証';

  @override
  String get appLockMethodSystemDescription => '指紋、顔、または端末の画面ロック';

  @override
  String get appLockMethodSystemUnavailable => 'この端末では使えません';

  @override
  String get appLockMethodPasscode => 'アプリのパスコード';

  @override
  String get appLockMethodPasscodeDescription => '画面ロックとは別の数字またはパターン';

  @override
  String passcodeCurrentForm(String form) {
    return '現在：$form';
  }

  @override
  String get passcodeBiometric => '指紋・顔でクイック解除';

  @override
  String get passcodeBiometricSubtitle =>
      '解除時にパスコードの代わりに指紋や顔を使えます。アプリロックのオフやパスコードの変更にはパスコードが必要です';

  @override
  String get appLockStatusPasscode => 'オン・アプリのパスコード';

  @override
  String get appLockStatusSystem => 'オン・システム認証';

  @override
  String get appLockStatusOffPasscode => 'オフ・ロックした日記帳はアプリのパスコードを使用';

  @override
  String get appLockStatusOff => 'オフ';

  @override
  String get settingsGroupGeneral => '一般';

  @override
  String get settingsGroupWriting => '書く';

  @override
  String get settingsGroupOrganize => '整理';

  @override
  String get settingsGroupDataSecurity => 'データとセキュリティ';

  @override
  String get settingsAppearance => '外観';

  @override
  String get settingsAppearanceSubtitle => 'テーマ、背景、各画面のスタイル';

  @override
  String get settingsEditor => 'エディター';

  @override
  String get settingsThemeGroup => 'テーマ';

  @override
  String get settingsInterfaceGroup => '画面';

  @override
  String get settingsPageStylesGroup => '画面のスタイル';

  @override
  String get settingsEditorBodyGroup => '本文';

  @override
  String get settingsEditorToolbarGroup => 'ツールバー';

  @override
  String get settingsEditorBehaviorGroup => '動作';

  @override
  String get dataMgmtBackupGroup => 'バックアップと復元';

  @override
  String get dataMgmtFilesGroup => 'インポートとエクスポート';

  @override
  String get placeHistoryTitle => '使った場所';

  @override
  String get placeHistorySearchHint => '場所を検索';

  @override
  String placeHistorySearchEmpty(String query) {
    return '「$query」に一致する場所はありません';
  }

  @override
  String get placeHistoryEmptyTitle => 'まだ場所がありません';

  @override
  String get placeHistoryEmptyBody => '場所を記録した日記を書くとここに表示され、次からはタップするだけで選べます。';

  @override
  String placeHistoryUseCount(int count) {
    return '$count 件';
  }

  @override
  String placeHistoryShowAll(int count) {
    return 'すべて $count';
  }

  @override
  String get appLockAfterLeaving => 'アプリを離れた後にロック';

  @override
  String get appLockAfterLeavingHint =>
      '他のアプリへの切り替え、ホーム画面に戻る、ウィンドウの最小化は「離れた」とみなします。アプリ内での写真の選択・撮影・ファイルの選択・共有は含みません。アプリを開くときは常に認証が必要です。';

  @override
  String get appLockDelayImmediately => 'すぐに';

  @override
  String appLockDelayMinutes(int count) {
    return '$count 分後';
  }

  @override
  String appLockDelayHours(int count) {
    return '$count 時間後';
  }

  @override
  String get appLockAfterLeavingNever => 'しない（アプリを開くときのみ）';

  @override
  String get appLockOnScreenOff => '画面ロック時にロック';

  @override
  String get appLockOnScreenOffSubtitle => '端末のロックや画面オフの後、アプリに戻るときに認証が必要です';

  @override
  String get appLockWhenIdle => '操作がないときにロック';

  @override
  String get appLockWhenIdleHint =>
      'ウィンドウが開いたまま、マウス・タッチパッド・キーボードが一定時間操作されないとロックします。';

  @override
  String get appLockWhenIdleOff => 'オフ';

  @override
  String get appLockAutoPrompt => '認証を自動で表示';

  @override
  String get appLockAutoPromptSubtitle =>
      'ロック画面が表示されたらすぐに指紋・顔・システム認証を表示します。オフのときはタップして認証します。';

  @override
  String get appLockPrivacyTitle => 'プライバシー';

  @override
  String get appLockSecureScreen => 'スクリーンショットを禁止';

  @override
  String get appLockSecureScreenSubtitle =>
      'スクリーンショットと画面録画を禁止し、最近使ったアプリにも内容を表示しません';

  @override
  String get appLockLoosenReason => 'アプリロックを緩めるには認証が必要です';

  @override
  String get appLockLoosenVerifyFailed => '認証に失敗しました。設定は変更されていません';

  @override
  String get diarySearchRecentTitle => '最近の検索';

  @override
  String get diarySearchClearRecent => '最近の検索を消去';

  @override
  String diarySearchRecentRemove(String query) {
    return '「$query」を検索履歴から削除';
  }

  @override
  String get diarySearchSuggestedTags => 'よく使うタグ';

  @override
  String get diarySearchEmptyTip => 'スペースで区切ると、すべての語を含む日記を探します';

  @override
  String diarySearchResultCount(int count) {
    return '$count 件';
  }

  @override
  String get diarySearchClearFilters => '絞り込みを解除';

  @override
  String get diarySearchIncludeArchived => 'アーカイブを含む';

  @override
  String diarySearchRemoveFilter(String label) {
    return '絞り込み「$label」を解除';
  }

  @override
  String get diarySearchSortTooltip => '並べ替え';

  @override
  String get diarySearchSortUpdated => '更新順';

  @override
  String get diarySearchSortNewest => '新しい順';

  @override
  String get diarySearchSortOldest => '古い順';

  @override
  String get diarySearchTagSheetTitle => 'タグで検索';

  @override
  String get diarySearchTagSheetHint => '選んだタグをすべて含む日記を表示します';

  @override
  String settingsStorageSubtitle(String size) {
    return '$size 使用中';
  }

  @override
  String get storageMgmtTitle => 'ストレージ管理';

  @override
  String get storageMgmtTotalLabel => '使用中の容量';

  @override
  String storageMgmtCleanUpAll(String size) {
    return 'まとめて整理・$size 解放';
  }

  @override
  String get storageMgmtRescan => '再計算';

  @override
  String get storageMgmtScanFailed => '容量を集計できませんでした。しばらくしてからもう一度お試しください';

  @override
  String get storageMgmtCategoryImages => '画像';

  @override
  String get storageMgmtCategoryVideos => '動画';

  @override
  String get storageMgmtCategoryAudio => '録音';

  @override
  String get storageMgmtCategoryAttachments => '添付ファイル';

  @override
  String get storageMgmtCategoryCovers => '表紙';

  @override
  String get storageMgmtCategoryBackgrounds => '背景画像';

  @override
  String get storageMgmtCategoryFonts => 'フォント';

  @override
  String get storageMgmtCategoryDatabase => '日記データ';

  @override
  String get storageMgmtCategoryCache => 'キャッシュ';

  @override
  String get storageMgmtCategoryUnused => '未使用のファイル';

  @override
  String get storageMgmtCategoryOther => 'その他';

  @override
  String get storageMgmtSuggestionsTitle => '空き容量を増やす';

  @override
  String get storageMgmtSuggestCache => 'キャッシュ';

  @override
  String storageMgmtSuggestCacheSubtitle(String size) {
    return '$size を削除できます。直近1時間に使ったものは残します';
  }

  @override
  String get storageMgmtSuggestUnused => '未使用のファイル';

  @override
  String storageMgmtSuggestUnusedSubtitle(int count, String size) {
    return 'どの日記にも使われていないファイル $count 個、$size';
  }

  @override
  String get storageMgmtSuggestTrash => 'ごみ箱の日記';

  @override
  String storageMgmtSuggestTrashSubtitle(int count, String size) {
    return 'ごみ箱の日記だけが使っているファイル $count 個、$size';
  }

  @override
  String get storageMgmtSuggestCompress => '圧縮できる写真と動画';

  @override
  String storageMgmtSuggestCompressSubtitle(int count, String size) {
    return '$count 件、約 $size 節約できます';
  }

  @override
  String get storageMgmtSuggestDatabase => '日記データを最適化';

  @override
  String storageMgmtSuggestDatabaseSubtitle(String size) {
    return '削除した内容が残した $size を解放できます';
  }

  @override
  String get storageMgmtClear => '削除';

  @override
  String get storageMgmtCompact => '最適化';

  @override
  String get storageMgmtAllClean => '整理済みです';

  @override
  String get storageMgmtAllCleanSubtitle => '今は削除できるキャッシュや未使用のファイルはありません';

  @override
  String get storageMgmtMediaTitle => 'メディア';

  @override
  String get storageMgmtAllMedia => 'すべてのメディア';

  @override
  String storageMgmtFileCount(int count) {
    return '$count 個のファイル';
  }

  @override
  String get storageMgmtLargeFiles => '大きなファイル';

  @override
  String get storageMgmtOtherTitle => 'その他のデータ';

  @override
  String get storageMgmtFooter =>
      '削除と圧縮は次回のLAN同期でほかの端末にも反映されます。クラウドの古いバックアップには、保持数に応じて整理されるまで元のファイルが残ります。';

  @override
  String get storageMgmtCleaning => '整理しています…';

  @override
  String get storageMgmtDeleting => '削除しています…';

  @override
  String storageMgmtFreed(String size) {
    return '$size を解放しました';
  }

  @override
  String get storageMgmtNothingFreed => '今は削除できるものはありません';

  @override
  String get storageMgmtBusyEditing => '編集中の日記があります。閉じてからもう一度お試しください';

  @override
  String get storageMgmtBusyUndo => '「元に戻す」の表示が消えてからもう一度お試しください';

  @override
  String get storageMgmtCannotDelete => '日記のほかのデータが参照しているため、ここでは削除できません';

  @override
  String storageMgmtDeleteTitle(int count) {
    return '$count 個のファイルを削除しますか？';
  }

  @override
  String storageMgmtDeleteBody(String size) {
    return '$size を解放します。次の場所から取り除かれます：';
  }

  @override
  String storageMgmtDeleteFromDiaries(int count) {
    return '日記 $count 件';
  }

  @override
  String storageMgmtDeleteFromNotebooks(int count) {
    return 'ノートの表紙 $count 件';
  }

  @override
  String storageMgmtDeleteFromComments(int count) {
    return 'コメント $count 件';
  }

  @override
  String storageMgmtDeleteFromDrafts(int count) {
    return '下書き $count 件';
  }

  @override
  String get storageMgmtDeleteCommentNote => '文字も画像もなくなったコメントは一緒に削除されます。';

  @override
  String get storageMgmtDeleteCapsuleNote => 'まだ開封されていないタイムカプセルの内容も含まれます。';

  @override
  String get storageMgmtDeleteIrreversible => '削除すると元に戻せません。';

  @override
  String storageMgmtDeleted(int count, String size) {
    return '$count 個のファイルを削除し、$size を解放しました';
  }

  @override
  String storageMgmtSkippedRows(int count) {
    return '$count 件の内容がその間に変更されたため、そのままにしました。';
  }

  @override
  String get storageMgmtCompress => '圧縮';

  @override
  String storageMgmtCompressTitle(int count) {
    return '$count 個のファイルを圧縮';
  }

  @override
  String get storageMgmtCompressImages => '写真';

  @override
  String get storageMgmtCompressVideos => '動画';

  @override
  String get storageMgmtPresetHigh => '高画質';

  @override
  String get storageMgmtPresetBalanced => 'バランス';

  @override
  String get storageMgmtPresetCompact => '容量優先';

  @override
  String storageMgmtImagePresetDetail(
    int maxSide,
    int quality,
    String estimate,
  ) {
    return '長辺 $maxSide px・画質 $quality・$estimate';
  }

  @override
  String storageMgmtPresetEstimate(String before, String after) {
    return '$before → 約 $after';
  }

  @override
  String get storageMgmtPresetNoGain => 'すでに十分小さいです';

  @override
  String storageMgmtCompressSummary(String before, String after, String saved) {
    return '$before → 約 $after、約 $saved 節約';
  }

  @override
  String get storageMgmtCompressNothing => '圧縮が必要なファイルはありません';

  @override
  String storageMgmtCompressSkipped(int count) {
    return '$count 個のファイルはすでに小さいか圧縮できない形式のため、スキップします。';
  }

  @override
  String get storageMgmtCompressNote =>
      '圧縮したファイルは元のファイルを置き換え、元に戻せません。写真の撮影日時と位置情報は残ります。';

  @override
  String get storageMgmtCompressStart => '圧縮する';

  @override
  String get storageMgmtCompressing => '圧縮しています';

  @override
  String get storageMgmtCompressPreparing => '準備しています…';

  @override
  String storageMgmtCompressStep(int index, int total, String name) {
    return '$index/$total 件目・$name';
  }

  @override
  String get storageMgmtCancelling => '停止しています…';

  @override
  String get storageMgmtCompressFinished => '圧縮が完了しました';

  @override
  String get storageMgmtCompressCancelled => '圧縮を停止しました';

  @override
  String storageMgmtCompressDone(int count, String size) {
    return '$count 個のファイルを圧縮し、$size 節約しました';
  }

  @override
  String storageMgmtCompressUnchanged(int count) {
    return '$count 個のファイルは小さくならなかったため、元のファイルを残しました。';
  }

  @override
  String storageMgmtCompressFailed(int count) {
    return '$count 個のファイルを圧縮できませんでした。';
  }

  @override
  String get storageMgmtCompressNoneDone => '圧縮したファイルはありません。';

  @override
  String get storageMgmtDone => '完了';

  @override
  String storageMgmtCompressSaving(String size) {
    return '圧縮・約 $size 節約';
  }

  @override
  String storageMgmtSelectedCount(int count) {
    return '$count 件を選択';
  }

  @override
  String storageMgmtSelectionSummary(int count, String size) {
    return '$count 件選択・合計 $size';
  }

  @override
  String storageMgmtListSummary(int count, String size) {
    return '$count 件・$size';
  }

  @override
  String get storageMgmtFilterAll => 'すべて';

  @override
  String get storageMgmtFilterLarge => '大きなファイル';

  @override
  String get storageMgmtFilterCompressible => '圧縮可能';

  @override
  String get storageMgmtFilterTrash => 'ごみ箱のみ';

  @override
  String get storageMgmtSort => '並べ替え';

  @override
  String get storageMgmtSortLargest => '大きい順';

  @override
  String get storageMgmtSortNewest => '新しい順';

  @override
  String get storageMgmtSortOldest => '古い順';

  @override
  String get storageMgmtViewGrid => 'グリッド表示';

  @override
  String get storageMgmtViewList => 'リスト表示';

  @override
  String get storageMgmtEmpty => 'ファイルはありません';

  @override
  String storageMgmtPrivateHidden(int count) {
    return '非公開の日記の $count 件はプレビューを隠しています';
  }

  @override
  String get storageMgmtReveal => '表示';

  @override
  String get storageMgmtRevealReason => '非公開の日記のメディアを表示するには認証してください';

  @override
  String get storageMgmtRevealUnavailable =>
      'この端末では認証できません。先にアプリのパスコードを設定してください';

  @override
  String get storageMgmtBadgeTrash => 'ごみ箱';

  @override
  String storageMgmtBadgeCompressible(String size) {
    return '$size 節約可';
  }

  @override
  String get storageMgmtBadgeCompressShort => '圧縮可';

  @override
  String storageMgmtBadgeUsedIn(int count) {
    return '$count か所で使用';
  }

  @override
  String get storageMgmtBadgeLocked => '削除不可';

  @override
  String get storageMgmtUntitledDiary => '無題の日記';

  @override
  String get storageMgmtUntitledDraft => '無題の下書き';

  @override
  String storageMgmtRefComment(String title) {
    return 'コメント・$title';
  }

  @override
  String storageMgmtRefDiaryCover(String title) {
    return '表紙・$title';
  }

  @override
  String storageMgmtRefNotebookCover(String name) {
    return 'ノートの表紙・$name';
  }

  @override
  String storageMgmtRefDraft(String title) {
    return '下書き・$title';
  }

  @override
  String get storageMgmtRefOther => 'ほかのデータが参照';

  @override
  String get storageMgmtMaskedPrivate => '非公開の日記の内容';

  @override
  String get storageMgmtMaskedCapsule => '未開封のタイムカプセルの内容';

  @override
  String storageMgmtUsedIn(int count) {
    return '$count か所で使用';
  }

  @override
  String get diaryTagFilterMultiSelectSemanticHint => '複数のタグを選択';

  @override
  String get diaryTagFilterMultiSelectTip => 'タグを長押しすると複数選択できます';

  @override
  String diaryTagFilterMultiSelectTipDesktop(String key) {
    return '$key を押しながらタグをクリックすると複数選択できます';
  }

  @override
  String get settingsPublishOnLeave => '戻るときに新しい日記を投稿';

  @override
  String get settingsPublishOnLeaveSubtitle => '新しい日記で戻ると、下書きにせず日記として保存します';

  @override
  String get publishOnLeaveFailedKeptDraft => '日記を投稿できませんでした。下書きに残しています。';

  @override
  String get storageMgmtAppTitle => 'Jotsy の使用量';

  @override
  String get storageMgmtCategoryApp => 'アプリ本体';

  @override
  String get storageMgmtDeviceTitle => '端末のストレージ';

  @override
  String storageMgmtDeviceTotal(String size) {
    return '合計 $size';
  }

  @override
  String get storageMgmtDeviceUsedLabel => '使用中';

  @override
  String get storageMgmtDeviceApp => 'このアプリ';

  @override
  String get storageMgmtDeviceOther => 'ほかのアプリとシステム';

  @override
  String get storageMgmtDeviceFree => '空き';

  @override
  String storageMgmtShareOfDevice(String percent) {
    return '端末の $percent';
  }

  @override
  String get storageMgmtDeviceShareLabel => '端末に占める割合';

  @override
  String get storageMgmtReclaimable => '解放できる容量';

  @override
  String get storageMgmtTopTitle => '容量の大きいファイル';

  @override
  String get storageMgmtSeeAll => 'すべて表示';

  @override
  String get storageMgmtGrowthTitle => 'メディアの推移';

  @override
  String get storageMgmtGrowthByYear => '日記の日付ごと・年別の追加量';

  @override
  String get storageMgmtGrowthByMonth => '日記の日付ごと・直近12か月の月別追加量';

  @override
  String storageMgmtGrowthPeak(String period, String size) {
    return '最も多いのは $period：$size';
  }

  @override
  String get storageMgmtOpenExternally => 'ほかのアプリで開く';

  @override
  String backupImportTodoCount(int count) {
    return 'ToDo $count件';
  }

  @override
  String backupImportExistingTodoCount(int count) {
    return 'うちToDo $count件はこの端末にすでにあります';
  }

  @override
  String backupImportModeOverwriteTodosOnly(int count) {
    return '新しい項目を追加し、この端末にすでにある$count件のToDoをファイル内の版に置き換えます';
  }

  @override
  String backupImportModeOverwriteTodosExtra(int count) {
    return 'この端末にすでにある$count件のToDoも置き換えます';
  }

  @override
  String backupOverwriteAllTodos(int count) {
    return 'ToDo $count件';
  }

  @override
  String backupOverwriteExistingTodosBody(int count) {
    return 'この端末にすでにある$count件のToDoが、ファイル内の版に置き換えられます。';
  }

  @override
  String backupImportTodoMergeResult(int added) {
    return 'ToDo：$added件を追加';
  }

  @override
  String backupImportTodoOverwriteResult(int added, int replaced) {
    return 'ToDo：$added件を追加、$replaced件を上書き';
  }

  @override
  String get navTodos => 'ToDo';

  @override
  String get appSurfaceAreaTodos => 'ToDo';

  @override
  String get settingsFeaturesTodosSubtitle => '日記とは別のToDo、リスト、リマインダー';

  @override
  String get todoViewToday => '今日';

  @override
  String get todoViewPlanned => '予定';

  @override
  String get todoViewImportant => '重要';

  @override
  String get todoViewAll => 'すべて';

  @override
  String get todoViewCompleted => '完了';

  @override
  String get todoViewInbox => '受信箱';

  @override
  String get todoGroupOverdue => '期限切れ';

  @override
  String get todoGroupToday => '今日';

  @override
  String get todoGroupTomorrow => '明日';

  @override
  String get todoGroupNextDays => '今後7日間';

  @override
  String get todoGroupLater => 'それ以降';

  @override
  String get todoNew => '新しいToDo';

  @override
  String get todoQuickAddHint => '何をしますか？';

  @override
  String get todoQuickAddSubmit => '追加';

  @override
  String get todoSearchHint => 'ToDoを検索';

  @override
  String get todoEmptyToday => '今日のToDoはありません';

  @override
  String get todoEmptyList => 'まだToDoはありません';

  @override
  String get todoEmptyCompleted => '完了したToDoはまだありません';

  @override
  String get todoEmptySearch => '一致するToDoはありません';

  @override
  String todoSortLabel(String mode) {
    return '並べ替え：$mode';
  }

  @override
  String get todoSortManual => '手動';

  @override
  String get todoSortDue => '期限';

  @override
  String get todoSortPriority => '優先度';

  @override
  String get todoSortCreated => '作成日';

  @override
  String get todoSortTitle => '並べ替え';

  @override
  String get todoShowCompleted => '完了を表示';

  @override
  String get todoHideCompleted => '完了を非表示';

  @override
  String get todoClearCompleted => '完了を消去';

  @override
  String get todoClearCompletedTitle => '完了したToDoを消去しますか？';

  @override
  String todoClearCompletedBody(int count) {
    return '完了したToDo $count件を削除します。通知から元に戻せます。';
  }

  @override
  String todoClearedCount(int count) {
    return '$count件を消去しました';
  }

  @override
  String get todoCompletedNotice => '完了しました';

  @override
  String todoCompletedNextNotice(String date) {
    return '完了しました。次回：$date';
  }

  @override
  String get todoDeletedNotice => 'ToDoを削除しました';

  @override
  String get todoDelete => 'ToDoを削除';

  @override
  String get todoMarkDone => '完了にする';

  @override
  String get todoMarkUndone => '未完了に戻す';

  @override
  String get todoMore => 'その他';

  @override
  String get todoListsSection => 'リスト';

  @override
  String get todoListNew => '新しいリスト';

  @override
  String get todoListEdit => 'リストを編集';

  @override
  String get todoListNameHint => 'リスト名';

  @override
  String get todoListManage => 'リストを管理';

  @override
  String get todoListDelete => 'リストを削除';

  @override
  String todoListDeleteTitle(String name) {
    return '「$name」を削除しますか？';
  }

  @override
  String todoListDeleteBody(int count) {
    return 'リスト内のToDo $count件も一緒に削除されます。通知から元に戻せます。';
  }

  @override
  String get todoListDeletedNotice => 'リストを削除しました';

  @override
  String get todoListColor => '色';

  @override
  String get todoListIcon => 'アイコン';

  @override
  String get todoListEmptyManage => 'まだリストはありません。仕事・生活などに分けると見つけやすくなります。';

  @override
  String get todoNoteHint => 'メモを追加';

  @override
  String get todoStepAdd => 'ステップを追加';

  @override
  String get todoStepDelete => 'ステップを削除';

  @override
  String todoStepsProgress(int done, int total) {
    return '$done/$total';
  }

  @override
  String get todoFieldDue => '日付';

  @override
  String get todoFieldReminders => 'リマインダー';

  @override
  String get todoFieldRepeat => '繰り返し';

  @override
  String get todoFieldPriority => '優先度';

  @override
  String get todoFieldList => 'リスト';

  @override
  String get todoFieldDiary => '関連する日記';

  @override
  String get todoFieldDiaryMissing => '日記が見つからないか削除されています';

  @override
  String todoCreatedAt(String time) {
    return '$time に作成';
  }

  @override
  String todoCompletedAt(String time) {
    return '$time に完了';
  }

  @override
  String get todoNotFound => 'このToDoは削除されました';

  @override
  String get todoPriorityNone => 'なし';

  @override
  String get todoPriorityLow => '低';

  @override
  String get todoPriorityMedium => '中';

  @override
  String get todoPriorityHigh => '高';

  @override
  String get todoDueToday => '今日';

  @override
  String get todoDueTomorrow => '明日';

  @override
  String get todoDueYesterday => '昨日';

  @override
  String get todoDueNextWeek => '来週の月曜日';

  @override
  String get todoDuePickDate => '日付を選択…';

  @override
  String get todoDueAllDay => '終日';

  @override
  String get todoDueSetTime => '時刻を設定';

  @override
  String get todoDueRemove => '日付を削除';

  @override
  String todoDueWithTime(String date, String time) {
    return '$date $time';
  }

  @override
  String get todoReminderAtDue => '期限の時刻';

  @override
  String todoReminderMinutesBefore(int count) {
    return '$count分前';
  }

  @override
  String todoReminderHoursBefore(int count) {
    return '$count時間前';
  }

  @override
  String todoReminderDaysBefore(int count) {
    return '$count日前';
  }

  @override
  String todoReminderOnDayAt(String time) {
    return '当日 $time';
  }

  @override
  String todoReminderDaysBeforeAt(int count, String time) {
    return '$count日前 $time';
  }

  @override
  String get todoReminderCustom => '時刻を指定…';

  @override
  String todoReminderLimit(int count) {
    return 'リマインダーは最大$count件です';
  }

  @override
  String get todoReminderRemove => 'リマインダーを削除';

  @override
  String get todoRepeatNone => '繰り返さない';

  @override
  String get todoRepeatDaily => '毎日';

  @override
  String get todoRepeatLegalWorkdays => '法定勤務日（中国の祝日）';

  @override
  String todoRepeatWeeklyOn(String days) {
    return '毎週$days';
  }

  @override
  String todoRepeatMonthlyOnDay(int day) {
    return '毎月$day日';
  }

  @override
  String todoRepeatMonthlyOrdinal(String ordinal, String weekday) {
    return '毎月第$ordinal$weekday';
  }

  @override
  String get todoRepeatMonthlyLastDay => '毎月末日';

  @override
  String todoRepeatYearlyOn(String date) {
    return '毎年$date';
  }

  @override
  String todoRepeatEveryDays(int count) {
    return '$count日ごと';
  }

  @override
  String todoRepeatEveryWeeks(int count) {
    return '$count週ごと';
  }

  @override
  String todoRepeatEveryMonths(int count) {
    return '$countか月ごと';
  }

  @override
  String todoRepeatEveryYears(int count) {
    return '$count年ごと';
  }

  @override
  String todoRepeatSummaryJoin(String a, String b) {
    return '$a · $b';
  }

  @override
  String get todoRepeatCustom => 'カスタム…';

  @override
  String get todoRepeatCustomTitle => '繰り返しのカスタム';

  @override
  String get todoRepeatUnitDay => '日';

  @override
  String get todoRepeatUnitWeek => '週';

  @override
  String get todoRepeatUnitMonth => '月';

  @override
  String get todoRepeatUnitYear => '年';

  @override
  String get todoRepeatInterval => '間隔';

  @override
  String get todoRepeatOnDays => '曜日';

  @override
  String get todoRepeatFromCompletion => '完了日から数える';

  @override
  String get todoRepeatFromCompletionSubtitle => '水やりのように「やってから数日後にまた」のこと向け';

  @override
  String get todoRepeatEnds => '終了';

  @override
  String get todoRepeatEndsNever => 'なし';

  @override
  String todoRepeatEndsOn(String date) {
    return '$dateまで';
  }

  @override
  String todoRepeatEndsAfter(int count) {
    return '$count回';
  }

  @override
  String get todoRepeatEndsOnPick => '日付で終了';

  @override
  String get todoRepeatEndsAfterPick => '回数で終了';

  @override
  String get todoSettingsTitle => 'ToDo';

  @override
  String get todoSettingsSubtitle => 'リスト、表示、リマインダー';

  @override
  String get todoSettingsDisplayGroup => '表示';

  @override
  String get todoSettingsShowCompletedSubtitle => 'リストと受信箱の下部に完了したToDoを表示';

  @override
  String get todoSettingsDefaultList => '新しいToDoの追加先';

  @override
  String get todoSettingsDefaultView => '起動時の表示';

  @override
  String get todoNotificationChannel => 'ToDoのリマインダー';

  @override
  String get todoNotificationChannelDescription => 'ToDoに設定したリマインダーの時刻にお知らせします';

  @override
  String get todoNotificationComplete => '完了';

  @override
  String get todoNotificationSnooze => 'スヌーズ';

  @override
  String get todoNotificationOpen => '開く';

  @override
  String get todoNotificationSnoozedBody => 'スヌーズしたリマインダー';

  @override
  String get todoSettingsRemindersGroup => 'リマインダー';

  @override
  String get todoSettingsPermission => '通知の許可';

  @override
  String get todoSettingsPermissionOn => '許可済み';

  @override
  String get todoSettingsPermissionOff => '未許可。タップしてオンに';

  @override
  String get todoSettingsExactOff =>
      'システムが正確なアラームを制限しているため、リマインダーが数分遅れることがあります';

  @override
  String get todoSettingsAllDayTime => '終日ToDoの通知時刻';

  @override
  String get todoSettingsSnooze => 'スヌーズの時間';

  @override
  String todoSettingsSnoozeMinutes(int count) {
    return '$count分';
  }

  @override
  String get todoSettingsHideContent => 'ロック画面で内容を隠す';

  @override
  String get todoSettingsHideContentSubtitle =>
      'ロック画面にはリマインダーがあることだけを表示し、内容はロック解除後に表示します';

  @override
  String get todoSettingsDesktopNote =>
      'パソコンではJotsyを開いている間だけ通知します。閉じている間に来たリマインダーは表示されません。';

  @override
  String get todoSettingsReliability => 'リマインダーが遅れる・届かない？';

  @override
  String get todoSettingsReliabilityBody =>
      '一部のスマートフォンはバックグラウンドのアプリを制限します。リマインダーが鳴らない・遅れる場合は、システム設定でJotsyの自動起動を許可し、Jotsyの電池最適化をオフにして、「通知」と「アラームとリマインダー」の許可がオンになっているか確認してください。';

  @override
  String get todoReminderPermissionDenied => '通知がオフのため、リマインダーは表示されません';

  @override
  String get todoReminderPermissionAction => 'オンにする';

  @override
  String get calendarShowTodos => 'ToDoを表示';

  @override
  String get calendarShowTodosDescription => 'ToDoのある日に印を付け、選んだ日のToDoを一覧表示します';

  @override
  String get calendarAddTodo => 'ToDoを追加';

  @override
  String get calendarTodoSectionTitle => 'この日のToDo';

  @override
  String get calendarTodoRepeatHint => '繰り返しToDoの今後の回です。その日になったらチェックします';

  @override
  String get diaryPreviewAddTodo => 'ToDoを追加';

  @override
  String get diaryPreviewConvertTodos => 'チェックリストをToDoにする';

  @override
  String get todoConvertTitle => 'ToDoにする';

  @override
  String get todoConvertHint => '選んだ項目をこの日記に関連付けたToDoとして追加します。日記本文は変わりません。';

  @override
  String todoConvertSubmit(int count) {
    return '$count件を追加';
  }

  @override
  String todoConvertDone(int count) {
    return 'ToDoを$count件追加しました';
  }

  @override
  String get diaryLinkedTodosTitle => '関連するToDo';

  @override
  String get todoBatchActionComplete => '完了';

  @override
  String get todoDuplicate => '複製';

  @override
  String todoDuplicateTitle(String title) {
    return '$title（コピー）';
  }

  @override
  String get todoDuplicatedNotice => '新しいToDoとして複製しました';

  @override
  String get todoGroupCompletedTitle => '完了';

  @override
  String get todoGroupCompletedToday => '今日完了';

  @override
  String get todoHeroAllDone => '今日のToDoはすべて完了';

  @override
  String get todoHeroNothing => '今日の予定はありません';

  @override
  String todoHeroDate(String weekday, String date) {
    return '$weekday · $date';
  }

  @override
  String todoHeroRemaining(int count) {
    return '残り $count件';
  }

  @override
  String todoHeroOverdue(int count) {
    return '期限切れ $count';
  }

  @override
  String todoHeroDone(int count) {
    return '完了 $count';
  }

  @override
  String todoHeroListProgress(int done, int total) {
    return '$total件中$done件完了';
  }

  @override
  String todoHeroOpenCount(int count) {
    return '未完了 $count件';
  }

  @override
  String todoHeroCompletedCount(int count) {
    return '最近の完了 $count件';
  }

  @override
  String get todoInlineAddHint => 'ToDoを追加';

  @override
  String get todoListManageShort => '管理';

  @override
  String get todoMoveOverdueToToday => 'すべて今日に';

  @override
  String get todoMoveToToday => '今日に移動';

  @override
  String get todoMoveToList => 'リストに移動…';

  @override
  String get todoNoteTitle => 'メモ';

  @override
  String get todoStepsTitle => 'ステップ';

  @override
  String todoStepsTitleProgress(int done, int total) {
    return 'ステップ $done/$total';
  }

  @override
  String get todoOpenDiary => '日記を開く';

  @override
  String get todoQuickParseDismiss => '取り消す';

  @override
  String todoRemindersCount(int count) {
    return 'リマインダー $count件';
  }

  @override
  String todoSelectedCount(int count) {
    return '$count件選択';
  }

  @override
  String get todoSelectionExit => '選択を終了';

  @override
  String get todoViewSheetTitle => '表示を切り替え';

  @override
  String todoBatchCompleted(int count) {
    return '$count件を完了しました';
  }

  @override
  String todoBatchDeleted(int count) {
    return '$count件を削除しました';
  }

  @override
  String todoBatchDueRemoved(int count) {
    return '$count件の日付を削除しました';
  }

  @override
  String todoBatchDueSet(int count, String date) {
    return '$count件を$dateに移動しました';
  }

  @override
  String todoBatchMoved(int count, String list) {
    return '$count件を「$list」に移動しました';
  }

  @override
  String todoBatchPrioritySet(int count, String priority) {
    return '$count件の優先度を「$priority」にしました';
  }

  @override
  String get todoSettingsSmartParse => 'スマート認識';

  @override
  String get todoSettingsSmartParseSubtitle =>
      '「明日 午後3時 #仕事 !!!」を日付・リスト・優先度として認識';

  @override
  String get aiToolOpenPageAny => 'ページを開く';

  @override
  String get aiToolOpensAfterReply => '回答のあとで開きます';

  @override
  String get aiListSeparator => '、';

  @override
  String aiToolNamesAndMore(String names, int count) {
    return '$names など計 $count 件';
  }

  @override
  String aiToolArgRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String aiToolArgSince(String date) {
    return '$date 以降';
  }

  @override
  String aiToolArgUntil(String date) {
    return '$date まで';
  }

  @override
  String get aiToolArgYes => 'はい';

  @override
  String get aiToolArgNo => 'いいえ';

  @override
  String aiToolArgMinutes(int minutes) {
    return '$minutes 分';
  }

  @override
  String aiToolArgName(String key) {
    String _temp0 = intl.Intl.selectLogic(key, {
      'arg_date_range': '日付',
      'arg_due_range': '期限',
      'arg_merge_from': '統合するタグ',
      'arg_query': 'キーワード',
      'arg_tags': 'タグ',
      'arg_mood': '気分',
      'arg_include_archived': 'アーカイブを含む',
      'arg_sort': '並び順',
      'arg_limit': '最大',
      'arg_group_by': 'まとめ方',
      'arg_date': '日付',
      'arg_time': '時刻',
      'arg_title': 'タイトル',
      'arg_name': '名前',
      'arg_note': 'メモ',
      'arg_color': '色',
      'arg_weather': '天気',
      'arg_location': '場所',
      'arg_text': '内容',
      'arg_body': '本文',
      'arg_priority': '優先度',
      'arg_list': 'リスト',
      'arg_status': '状態',
      'arg_scale': '文字サイズ',
      'arg_repeat': '繰り返し',
      'arg_remove': '外すタグ',
      'arg_add': '付けるタグ',
      'arg_remind_before_minutes': '事前通知',
      'arg_parent_id': '親の日記帳',
      'arg_offset': '読み始め位置',
      'arg_new_name': '新しい名前',
      'arg_mode': '外観',
      'arg_language': '言語',
      'arg_into': '統合先',
      'arg_feature': '機能',
      'arg_enabled': 'オン',
      'arg_clear_due': '期限を消す',
      'arg_kind_diary': '日記',
      'arg_kind_notebook': '日記帳',
      'arg_kind_tag': 'タグ',
      'arg_kind_todo': 'ToDo',
      'arg_kind_anniversary': '記念日',
      'arg_kind_day': '日',
      'arg_steps': 'ステップ',
      'arg_reminders': 'リマインダー',
      'arg_add_steps': '追加するステップ',
      'arg_check_steps': '完了にするステップ',
      'arg_uncheck_steps': '未完了に戻すステップ',
      'arg_remove_steps': '削除するステップ',
      'arg_all_day': '終日',
      'arg_kind_todoList': 'リスト',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String aiToolArgValue(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'sort_relevant': '関連度順',
      'sort_newest': '新しい順',
      'sort_oldest': '古い順',
      'group_by_none': 'まとめない',
      'group_by_day': '日ごと',
      'group_by_week': '週ごと',
      'group_by_month': '月ごと',
      'group_by_year': '年ごと',
      'status_open': '未完了',
      'status_completed': '完了',
      'status_all': 'すべて',
      'priority_none': 'なし',
      'priority_low': '低',
      'priority_medium': '中',
      'priority_high': '高',
      'repeat_once': '繰り返さない',
      'repeat_yearly': '毎年',
      'repeat_lunar_yearly': '毎年（旧暦）',
      'mood_awful': '最悪',
      'mood_bad': 'よくない',
      'mood_meh': 'ふつう',
      'mood_good': 'よい',
      'mood_great': '最高',
      'mood_clear': 'クリア',
      'mode_light': 'ライト',
      'mode_dark': 'ダーク',
      'mode_system': 'システムに合わせる',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String aiToolAddToNotebookNamed(int count, String name) {
    return '$count 件の日記を「$name」に追加';
  }

  @override
  String aiToolRemoveFromNotebookNamed(int count, String name) {
    return '$count 件の日記を「$name」から外す';
  }

  @override
  String get aiChatReturnHint => '戻るボタンで先ほどの会話に戻れます';

  @override
  String get aiChatReturnAction => '会話に戻る';

  @override
  String aiProcessThoughtFor(int seconds) {
    return '$seconds 秒考えました';
  }

  @override
  String aiProcessThinkingFor(int seconds) {
    return '考え中 · $seconds 秒';
  }

  @override
  String get aiProcessThought => '考えました';

  @override
  String aiProcessTools(int count) {
    return '$count 個のツールを使用';
  }

  @override
  String aiProcessFailed(int count) {
    return '$count 件失敗';
  }

  @override
  String get aiProcessSteps => '経過を見る';

  @override
  String get aiToolDetailsInputs => '条件';

  @override
  String get aiToolDetailsResult => '結果';

  @override
  String get aiToolDetailsFailed => 'このステップは失敗しました';

  @override
  String get aiToolDetailsTechnical => '技術情報';

  @override
  String aiCardEntries(int count) {
    return '$count 件';
  }

  @override
  String aiCardTodoDue(String date) {
    return '$date 期限';
  }

  @override
  String get aiCardTodoDone => '完了';

  @override
  String aiCardSearchFor(String query) {
    return '「$query」を検索';
  }

  @override
  String get aiCardSectionHome => 'ホーム';

  @override
  String get aiCardMissing => 'もう存在しません';

  @override
  String get aiCardFeatureOff => '機能がオフです';

  @override
  String aiChangeGroupTitle(int count) {
    return '$count 件の変更';
  }

  @override
  String get aiChangeUndoAll => 'すべて元に戻す';

  @override
  String get aiChatNewChat => '新しい会話';

  @override
  String get aiChatHistory => '会話履歴';

  @override
  String get aiChatHistoryEmpty => 'まだ会話はありません';

  @override
  String get aiChatHistoryNoMatch => '該当する会話はありません';

  @override
  String get aiChatGroupPinned => 'ピン留め';

  @override
  String get aiChatGroupToday => '今日';

  @override
  String get aiChatGroupYesterday => '昨日';

  @override
  String get aiChatGroupWeek => '過去 7 日間';

  @override
  String get aiChatGroupMonth => '過去 30 日間';

  @override
  String get aiChatWelcomeTitle => '今日は何を話しましょうか？';

  @override
  String get aiChatWelcomeAgent =>
      '日記のことを聞いたり、日記の整理や ToDo の追加、ページを開くことを頼んだりできます。';

  @override
  String get aiChatWelcomeRetrieval => '日記のことを聞いてください。関連する日記を探してから答えます。';

  @override
  String get aiChatWelcomeRecaps => '振り返り';

  @override
  String get aiChatWelcomeRecent => '最近の会話';

  @override
  String get aiChatWelcomeAllChats => 'すべての会話';

  @override
  String get aiChatModelSheetTitle => 'モデルと思考';

  @override
  String get aiChatThinking => '思考の深さ';

  @override
  String get aiThinkingAuto => '自動';

  @override
  String get aiThinkingOff => 'オフ';

  @override
  String get aiThinkingLow => '低';

  @override
  String get aiThinkingMedium => '中';

  @override
  String get aiThinkingHigh => '高';

  @override
  String get aiThinkingAutoHint => 'モデルが考えるかどうか、どれくらい考えるかを決めます';

  @override
  String get aiThinkingOffHint => '考えずにすぐ答えます。最速です';

  @override
  String get aiThinkingLowHint => '軽く考えます。日常的な質問向け';

  @override
  String get aiThinkingMediumHint => 'ほとんどの質問にちょうどよいバランス';

  @override
  String get aiThinkingHighHint => 'じっくり考えます。整理や振り返り、複雑な変更向け。最も遅いです';

  @override
  String get aiThinkingDisabled => 'このモデルはモデル設定で思考がオフになっています';

  @override
  String aiChatMetaThinking(String level) {
    return '思考：$level';
  }

  @override
  String get aiChatOpenSettings => 'AI 設定';

  @override
  String get aiChatExport => '会話をエクスポート';

  @override
  String get aiChatExportFormat => '形式';

  @override
  String get aiChatExportMarkdown => 'Markdown';

  @override
  String get aiChatExportPlain => 'プレーンテキスト';

  @override
  String get aiChatExportInclude => '含める内容';

  @override
  String get aiChatExportReasoning => '思考過程';

  @override
  String get aiChatExportSteps => '経過と操作';

  @override
  String get aiChatExportMessages => 'メッセージを選択';

  @override
  String aiChatExportSelected(int count, int total) {
    return '$count / $total 件を選択';
  }

  @override
  String get aiChatExportYou => 'あなた';

  @override
  String get aiChatExportSave => 'ファイルに保存';

  @override
  String get aiChatExportSaved => '会話をエクスポートしました';

  @override
  String get aiChatExportFailed => 'エクスポートできませんでした';

  @override
  String aiChatExportAt(String time, int count) {
    return '$time にエクスポート · $count 件のメッセージ';
  }

  @override
  String get aiChatExportReferences => '参照した日記';

  @override
  String aiChatExportError(String reason) {
    return 'エラー：$reason';
  }

  @override
  String aiChatExportSubjects(String names) {
    return '：$names';
  }

  @override
  String get aiChatExportJson => 'JSON';
}
