// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations_gen.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Jotsy';

  @override
  String get navDiaries => '日记';

  @override
  String get navCalendar => '日历';

  @override
  String get navExplore => '探索';

  @override
  String get navSettings => '设置';

  @override
  String get commonCancel => '取消';

  @override
  String get commonConfirm => '确认';

  @override
  String get commonDelete => '删除';

  @override
  String get commonUndo => '撤销';

  @override
  String get commonDragToReorder => '拖动排序';

  @override
  String get commonSelectAll => '全选';

  @override
  String get commonDeselectAll => '取消全选';

  @override
  String get commonBack => '返回';

  @override
  String get commonSave => '保存';

  @override
  String get commonEdit => '编辑';

  @override
  String get commonShare => '分享';

  @override
  String get commonContinue => '继续';

  @override
  String get commonCreate => '创建';

  @override
  String get commonClose => '关闭';

  @override
  String get commonNew => '新建';

  @override
  String get commonReset => '重置';

  @override
  String get commonRetry => '重试';

  @override
  String get contextFieldInputHint => '输入天气/地址，也可以点击右侧按钮自动获取';

  @override
  String get contextLocationInputHint => '输入地址，也可以点击右侧按钮自动获取';

  @override
  String get contextWeatherInputHint => '输入天气，也可以点击右侧按钮自动获取';

  @override
  String get timeJustNow => '刚刚';

  @override
  String timeMinutesAgo(int minutes) {
    return '$minutes分钟前';
  }

  @override
  String timeHoursAgo(int hours) {
    return '$hours小时前';
  }

  @override
  String timeDaysAgo(int days) {
    return '$days天前';
  }

  @override
  String updatedAtLabel(String value) {
    return '更新于 $value';
  }

  @override
  String get startupPreloadFailed => '启动时预加载日记失败，已进入主页。';

  @override
  String homeInitFailed(String error) {
    return '初始化失败: $error';
  }

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsFontScale => '字体大小';

  @override
  String get settingsFontScaleSubtitle => '调整应用界面字体大小';

  @override
  String get settingsFontScalePreview => '预览文字：今天也记下了一点生活。';

  @override
  String get settingsDiaryCardTagLimit => '日记卡片标签';

  @override
  String get settingsDiaryCardTagLimitLoading => '正在加载日记卡片设置';

  @override
  String get settingsDiaryCardTagLimitUnavailable => '设置暂不可用';

  @override
  String get settingsDiaryCardTagLimitHidden => '不显示标签';

  @override
  String settingsDiaryCardTagLimitValue(int count) {
    return '最多显示 $count 个标签';
  }

  @override
  String get settingsTabSwitchCurve => '标签页切换曲线';

  @override
  String get settingsTabSwitchCurveSubtitle => '选择底部标签页切换时的动画手感';

  @override
  String get settingsTabSwitchCurveEaseOutCirc => '顺滑（Circ）';

  @override
  String get settingsTabSwitchCurveEaseOutCubic => '均衡（Cubic）';

  @override
  String get settingsTabSwitchCurveLinear => '线性';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsAppLock => '应用锁';

  @override
  String get settingsAppLockSubtitle => '开启后打开应用时需要验证身份';

  @override
  String get appLockNotSupported => '这台设备没有设置锁屏密码，无法用系统验证启用应用锁。可以改用应用密码。';

  @override
  String get appLockTitle => '应用已锁定';

  @override
  String get appLockSubtitle => '请验证身份后继续使用';

  @override
  String get appLockUnlockNow => '立即解锁';

  @override
  String get appLockUnlocking => '正在解锁';

  @override
  String get appLockDisableAuthReason => '请验证身份后关闭应用锁';

  @override
  String get appLockDisableVerifyFailed => '身份验证未通过，应用锁未关闭。';

  @override
  String get settingsEditorTitle => '编辑器设置';

  @override
  String get settingsEditorSubtitle => '字体排版、工具栏与代码块';

  @override
  String get settingsMoodOptionsTitle => '心情符号';

  @override
  String settingsMoodOptionsSlotLabel(String index) {
    return '心情 $index';
  }

  @override
  String settingsMoodOptionsSlotHelper(String emoji) {
    return '默认：$emoji';
  }

  @override
  String settingsMoodOptionsColorLabel(String index) {
    return '心情 $index 的颜色';
  }

  @override
  String get settingsMoodOptionsColorsHint =>
      '颜色用于日记预览页的“心情”配色基调和日记卡片的心情色。点符号左侧的色块修改。';

  @override
  String settingsMoodOptionsSaveFailed(String error) {
    return '保存心情符号失败: $error';
  }

  @override
  String get settingsDataManagement => '数据管理';

  @override
  String get settingsDataManagementSubtitle => '备份与恢复、导入导出、网盘备份';

  @override
  String get settingsTagManagement => '标签管理';

  @override
  String get settingsTagMemory => '标签记忆';

  @override
  String get settingsTagMemorySubtitle => '记住日记列表已选标签，下次进入应用自动恢复';

  @override
  String get settingsRecycleBin => '回收站';

  @override
  String get settingsAbout => '关于';

  @override
  String get languageDialogTitle => '选择语言';

  @override
  String get languageOptionChinese => '中文';

  @override
  String get languageOptionEnglish => 'English';

  @override
  String get aboutTitle => '关于';

  @override
  String get aboutTagline => '记录每一天的小事与心情';

  @override
  String get aboutVersion => '应用版本';

  @override
  String get aboutPackageName => '应用包名';

  @override
  String get aboutRepository => '项目地址';

  @override
  String get aboutCopied => '已复制到剪贴板';

  @override
  String get aboutPageSlogan => '喧嚣世界里，只属于你的安静角落。';

  @override
  String get aboutOpenSourceRepo => '开源仓库';

  @override
  String get aboutCheckUpdate => '检查最新版本';

  @override
  String aboutUpdateSubtitleAvailable(String version) {
    return '$version 可更新';
  }

  @override
  String aboutUpdateSubtitleDownloading(int percent) {
    return '正在下载 $percent%';
  }

  @override
  String get aboutUpdateSubtitleReady => '新版本已下载，点按安装';

  @override
  String get appUpdateTitle => '软件更新';

  @override
  String appUpdateCurrentVersion(String version) {
    return '当前版本 $version';
  }

  @override
  String get appUpdateChecking => '正在检查更新…';

  @override
  String get appUpdateCheckingHint => '同时尝试多条线路，用最先响应的一条';

  @override
  String get appUpdateUpToDate => '已是最新版本';

  @override
  String appUpdateLastChecked(String time) {
    return '上次检查：$time';
  }

  @override
  String get appUpdateAvailableBadge => '新版本';

  @override
  String appUpdateAvailableTitle(String version) {
    return '发现新版本 $version';
  }

  @override
  String appUpdatePublishedOn(String date) {
    return '发布于 $date';
  }

  @override
  String get appUpdateReleaseNotesTitle => '更新内容';

  @override
  String get appUpdateCurrentNotesTitle => '本版本更新内容';

  @override
  String get appUpdateNoReleaseNotes => '这个版本没有填写更新说明。';

  @override
  String get appUpdateViewOnGitHub => '在 GitHub 查看';

  @override
  String get aboutChangelog => '更新日志';

  @override
  String get changelogTitle => '更新日志';

  @override
  String get changelogCurrentVersion => '当前版本';

  @override
  String get changelogShowAll => '展开全部';

  @override
  String get changelogCollapse => '收起';

  @override
  String get changelogEmpty => '暂时没有可显示的更新日志。';

  @override
  String get changelogAllReleases => '在 GitHub 查看全部版本';

  @override
  String get appUpdateActionCheck => '检查更新';

  @override
  String appUpdateActionDownload(String size) {
    return '下载并安装（$size）';
  }

  @override
  String get appUpdateActionDownloadNoSize => '下载并安装';

  @override
  String appUpdateActionResume(int percent) {
    return '继续下载（已完成 $percent%）';
  }

  @override
  String get appUpdateActionCancel => '取消下载';

  @override
  String get appUpdateActionInstall => '安装';

  @override
  String get appUpdateActionRetry => '重试';

  @override
  String get appUpdateActionOpenReleasePage => '前往下载页面';

  @override
  String get appUpdateActionSkip => '跳过此版本';

  @override
  String get appUpdateSkippedHint => '已跳过此版本，启动时不再提醒';

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
    return '经 $route';
  }

  @override
  String get appUpdateVerifying => '正在校验安装包…';

  @override
  String get appUpdateReadyToInstall => '安装包已下载并通过校验';

  @override
  String get appUpdateInstallPermissionTitle => '需要允许安装应用';

  @override
  String get appUpdateInstallPermissionMessage =>
      'Android 需要你在系统设置里允许 Jotsy“安装未知应用”。开启后返回这里，会自动继续安装。';

  @override
  String get appUpdateInstallPermissionAction => '去设置';

  @override
  String get appUpdateInstallPermissionSettingsFailed =>
      '无法打开系统设置，请在 设置 → 应用 → Jotsy 中允许安装未知应用';

  @override
  String get appUpdateUnsupportedPlatform => '当前平台不支持应用内安装，请前往下载页面获取新版本。';

  @override
  String get appUpdateNoCompatibleApk => '这个版本没有适合本机处理器架构的安装包，请前往下载页面手动选择。';

  @override
  String get appUpdateFailedCheckTitle => '检查更新失败';

  @override
  String get appUpdateFailedDownloadTitle => '下载失败';

  @override
  String get appUpdateFailedInstallTitle => '无法安装';

  @override
  String get appUpdateFailureNetwork =>
      '所有线路都连接失败。可以稍后重试，或在下方“下载线路”中换一条线路、填写自定义镜像。';

  @override
  String get appUpdateFailureNotFound => '没有找到已发布的版本。';

  @override
  String get appUpdateFailureIntegrity => '下载的文件不完整或被改动过（校验值不符），已删除。请重试或换一条线路。';

  @override
  String get appUpdateFailureSignature =>
      '安装包的签名与当前应用不同，无法覆盖安装。请只从官方 Release 页面下载。';

  @override
  String get appUpdateFailureNotNewer => '下载的安装包并不比当前版本新。';

  @override
  String get appUpdateFailureStorage => '无法保存安装包，请检查手机剩余空间。';

  @override
  String get appUpdateFailureInstallUnavailable => '无法打开系统安装器，请前往下载页面手动安装。';

  @override
  String get appUpdateSettingsTitle => '更新设置';

  @override
  String get appUpdateAutoCheck => '自动检查更新';

  @override
  String get appUpdateAutoCheckSubtitle => '打开或回到应用时检查，每 2 小时最多一次；只读取公开的版本信息';

  @override
  String get appUpdateSource => '下载线路';

  @override
  String get appUpdateSourceAuto => '自动选择';

  @override
  String get appUpdateSourceAutoDescription => '同时测速，使用最快的线路；国内网络推荐';

  @override
  String get appUpdateSourceDirect => 'GitHub 直连';

  @override
  String get appUpdateSourceDirectDescription => '不经镜像；国内网络下可能很慢或无法连接';

  @override
  String get appUpdateSourceMirrorDescription => '公共镜像加速';

  @override
  String get appUpdateSourceCustom => '自定义镜像';

  @override
  String get appUpdateSourceCustomDescription => '内置镜像都失效时，填写一个可用的 GitHub 加速地址';

  @override
  String get appUpdateSourceCustomHint => '例如 https://mirror.example.com/';

  @override
  String get appUpdateSourceCustomInvalid => '请输入以 https:// 开头的地址';

  @override
  String get appUpdateSourceSheetHint =>
      '镜像是第三方公共服务。安装包下载后都会核对 SHA-256 与应用签名，镜像无法把它换成别的应用。';

  @override
  String get appUpdatePromptUpdate => '立即更新';

  @override
  String get appUpdatePromptLater => '以后再说';

  @override
  String get appUpdateActionDesktopDownload => '前往下载';

  @override
  String get appUpdateDesktopHintWindows => '将在浏览器中下载安装程序，运行它即可覆盖安装，日记数据会保留。';

  @override
  String get appUpdateDesktopHintLinux =>
      '将在浏览器中下载 .tar.gz 压缩包，解压后运行其中的 install.sh 即可更新，日记数据会保留。';

  @override
  String get appUpdateNoDesktopPackage => '这个版本没有适合本机系统的安装包，请前往下载页面查看。';

  @override
  String get appUpdateSourceAutoDescriptionDesktop => '使用检查更新时最先响应的线路；国内网络推荐';

  @override
  String get appUpdateSourceSheetHintDesktop =>
      '镜像是第三方公共服务。下载后可用发布页面的 SHA256SUMS.txt 核对文件是否完整。';

  @override
  String get aboutSubmitIssue => '提交 Issue';

  @override
  String get aboutQqFeedbackGroup => 'QQ反馈群';

  @override
  String get aboutQqFeedbackGroupSubtitle => '678136434';

  @override
  String get aboutQqFeedbackGroupCopied => 'QQ群号已复制到剪贴板';

  @override
  String get aboutPrivacyAndData => '隐私与数据安全';

  @override
  String get aboutPrivacyDialogTitle => '隐私与数据安全';

  @override
  String get aboutPrivacyDialogMessage =>
      '你的日记、标签与媒体文件仅保存在本地设备，不会默认上传到云端。AI 助手默认关闭；开启后，只在你使用 AI 功能时把所需内容直接发给你自己配置的 AI 服务，密钥只保存在本机。';

  @override
  String get aboutOpenSourceLicenses => '第三方开源组件与协议';

  @override
  String get aboutOpenLinkFallbackCopied => '无法直接打开链接，已复制到剪贴板。';

  @override
  String get aboutFooterCopyright => '© 2026 Jot Project';

  @override
  String get dataMgmtTitle => '数据管理';

  @override
  String get dataMgmtExport => '导出数据';

  @override
  String get dataMgmtExportSubtitle => '导出为 zip，包含日记、标签、设置与本地图片、录音、视频和附件';

  @override
  String get dataMgmtImport => '导入数据';

  @override
  String get dataMgmtImportSubtitle => '导入完整备份或日记文件，可选择合并或覆盖';

  @override
  String get dataMgmtHint =>
      '单篇日记可在日记预览页的「更多」菜单中导出。合并导入只会添加本机没有的日记，不改动现有内容；覆盖导入会永久替换本机数据，操作前建议先导出备份。';

  @override
  String get dataMgmtBusyExport => '正在导出数据...';

  @override
  String get dataMgmtBusyImport => '正在导入数据...';

  @override
  String get dataMgmtSaveDialogTitle => '保存数据备份';

  @override
  String get dataMgmtPickDialogTitle => '选择备份文件';

  @override
  String get dataMgmtExportSuccess => '数据导出成功';

  @override
  String get dataMgmtExportCanceled => '已取消导出';

  @override
  String dataMgmtExportFailed(String error) {
    return '导出失败: $error';
  }

  @override
  String get dataMgmtImportSuccess => '数据导入完成';

  @override
  String get dataMgmtImportCanceled => '已取消导入';

  @override
  String dataMgmtImportFailed(String error) {
    return '导入失败: $error';
  }

  @override
  String get dataMgmtImportAction => '导入';

  @override
  String get dataMgmtBusyLabel => '数据处理中';

  @override
  String get dataMgmtExportPasswordTitle => '设置导出密码（可选）';

  @override
  String get dataMgmtExportPasswordHint => '不填写则不加密';

  @override
  String get dataMgmtExportPasswordWarning =>
      '请妥善保管此密码。本应用采用本地端到端加密，我们无法为您找回密码。一旦遗忘，导出的数据将永久无法恢复。';

  @override
  String get dataMgmtImportPasswordTitle => '导入密码';

  @override
  String get dataMgmtImportPasswordHint => '请输入导入密码';

  @override
  String colorFamilySwatchLabel(int index, String hex) {
    return '色系 $index，$hex';
  }

  @override
  String colorSwatchLabel(String hex) {
    return '颜色 $hex';
  }

  @override
  String get diaryPinSelected => '置顶';

  @override
  String get diaryUnpinSelected => '取消置顶';

  @override
  String get tagFilterClearLabel => '清除标签筛选';

  @override
  String searchRemoveTagCondition(String tagName) {
    return '移除标签 $tagName';
  }

  @override
  String get passwordShow => '显示密码';

  @override
  String get passwordHide => '隐藏密码';

  @override
  String get commonLoading => '加载中';

  @override
  String exploreOnThisDayYearsAgo(int years) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$years年前的今天',
    );
    return '$_temp0';
  }

  @override
  String get dateTimeMinutePattern => 'yyyy年MM月dd日 HH:mm';

  @override
  String get energyLevelExhausted => '疲惫不堪';

  @override
  String get energyLevelTired => '有点疲惫';

  @override
  String get energyLevelSoSo => '状态一般';

  @override
  String get energyLevelGood => '精力不错';

  @override
  String get energyLevelFull => '精力满满';

  @override
  String get startupPreloadFailedNotice => '启动时预加载日记失败，已进入主页。';

  @override
  String startupInitFailed(String error) {
    return '初始化失败: $error';
  }

  @override
  String get appLockAuthReason => '请验证身份以解锁应用';

  @override
  String get autoT0001 => '应用加载中';

  @override
  String get autoT0002 => '复制';

  @override
  String get autoT0003 => '重置排序';

  @override
  String autoT0004(String p0) {
    return '保存排序失败: $p0';
  }

  @override
  String get autoT0005 => '工具栏顺序';

  @override
  String get autoT0006 => '撤销';

  @override
  String get autoT0007 => '重做';

  @override
  String get autoT0008 => '加粗';

  @override
  String get autoT0009 => '斜体';

  @override
  String get autoT0010 => '下划线';

  @override
  String get autoT0011 => '删除线';

  @override
  String get autoT0012 => '行内代码（单行）';

  @override
  String get autoT0013 => '文字颜色';

  @override
  String get autoT0014 => '背景颜色';

  @override
  String get autoT0015 => '清除格式';

  @override
  String get autoT0016 => '插入图片';

  @override
  String get autoT0017 => '标题样式';

  @override
  String get autoT0018 => '有序列表';

  @override
  String get autoT0019 => '无序列表';

  @override
  String get autoT0020 => '待办列表';

  @override
  String get autoT0021 => '代码块（多行）';

  @override
  String get autoT0022 => '引用';

  @override
  String get autoT0023 => '缩进（增/减）';

  @override
  String get autoT0024 => '链接';

  @override
  String get autoT0025 => '删除时间未知';

  @override
  String get autoT0026 => '部分恢复失败，请重试';

  @override
  String get autoT0027 => '部分删除失败，请重试';

  @override
  String get autoT0028 => '彻底删除';

  @override
  String get autoT0029 => '回收站';

  @override
  String get autoT0030 => '恢复';

  @override
  String autoT0031(String p0) {
    return '回收站加载失败: $p0';
  }

  @override
  String get autoT0032 => '回收站为空';

  @override
  String get autoT0033 => '无标题';

  @override
  String autoT0034(String p0) {
    return '创建标签失败: $p0';
  }

  @override
  String autoT0035(String p0) {
    return '修改标签失败: $p0';
  }

  @override
  String autoT0036(String p0) {
    return '删除标签失败: $p0';
  }

  @override
  String autoT0037(String p0) {
    return '保存标签顺序失败: $p0';
  }

  @override
  String get autoT0038 => '删除标签';

  @override
  String get autoT0039 => '标签管理';

  @override
  String get autoT0040 => '新建标签';

  @override
  String get autoT0041 => '新建第一个标签';

  @override
  String autoT0042(String p0) {
    return '标签加载失败: $p0';
  }

  @override
  String get autoT0043 => '工具栏按钮排序';

  @override
  String autoT0044(String p0) {
    return '当前前 4 项：$p0';
  }

  @override
  String autoT0045(String p0) {
    return '设置加载失败: $p0';
  }

  @override
  String get autoT0046 => '系统';

  @override
  String get autoT0047 => '浅色';

  @override
  String get autoT0048 => '深色';

  @override
  String get autoT0049 => '今天发生了什么意料之外的好事？';

  @override
  String get autoT0050 => '如果给今天取个标题，你会写什么？';

  @override
  String get autoT0051 => '今天最值得记住的一瞬间是什么？';

  @override
  String get autoT0052 => '媒体预览';

  @override
  String get autoT0053 => '没有可浏览的图片';

  @override
  String get autoT0054 => '媒体画廊';

  @override
  String get autoT0055 => '还没有可展示的图片';

  @override
  String get autoT0056 => '加载失败，点击重试';

  @override
  String get autoT0057 => '没有更多图片了';

  @override
  String get autoT0058 => '探索';

  @override
  String get autoT0059 => '探索数据暂不可用';

  @override
  String get autoT0061 => '查看全部图片';

  @override
  String get autoT0062 => '还没有可展示的图片。';

  @override
  String get autoT0063 => '那年今日';

  @override
  String get autoT0064 => '补写今天';

  @override
  String get autoT0065 => '无标题日记';

  @override
  String get autoT0069 => '标签云';

  @override
  String get autoT0070 => '删除日记';

  @override
  String get autoT0071 => '取消归档失败，请重试';

  @override
  String get autoT0072 => '已恢复归档状态';

  @override
  String get autoT0073 => '删除失败，请重试';

  @override
  String autoT0074(String p0) {
    return '已删除 $p0 条日记';
  }

  @override
  String get autoT0075 => '已删除日记';

  @override
  String get autoT0076 => '已恢复删除的日记';

  @override
  String get autoT0077 => '恢复失败，请重试';

  @override
  String get autoT0078 => '归档失败，请重试';

  @override
  String autoT0079(String p0) {
    return '已归档 $p0 条日记';
  }

  @override
  String get autoT0080 => '已恢复归档的日记';

  @override
  String autoT0084(String p0) {
    return '确认删除已选择的 $p0 条日记吗？';
  }

  @override
  String get autoT0085 => '暂无街道信息';

  @override
  String get autoT0086 => '标题和正文不能同时为空';

  @override
  String autoT0087(String p0) {
    return '保存失败: $p0';
  }

  @override
  String get autoT0088 => '未获取到可用的封面路径';

  @override
  String get autoT0092 => '请先获取当前位置';

  @override
  String get autoT0094 => '删除日记';

  @override
  String get autoT0095 => '未命名日记';

  @override
  String get autoT0096 => '选择发表日期';

  @override
  String get autoT0097 => '选择发表时间';

  @override
  String autoT0099(String p0) {
    return '已选择 $p0 项';
  }

  @override
  String get autoT0100 => '归档日记';

  @override
  String get autoT0101 => '取消归档';

  @override
  String autoT0102(String p0) {
    return '归档加载失败: $p0';
  }

  @override
  String get autoT0103 => '暂无归档日记';

  @override
  String get autoT0104 => '（无正文）';

  @override
  String get autoT0105 => '无';

  @override
  String get autoT0106 => '标题';

  @override
  String get autoT0107 => '创建时间';

  @override
  String get autoT0108 => '更新时间';

  @override
  String get autoT0109 => '标签';

  @override
  String get autoT0110 => '正文';

  @override
  String get autoT0111 => '截图失败，请重试';

  @override
  String autoT0112(String p0) {
    return '图片分享失败: $p0';
  }

  @override
  String get autoT0113 => '确认删除这条日记吗？';

  @override
  String get autoT0114 => '分享图片';

  @override
  String get autoT0115 => '以文字形式分享';

  @override
  String get previewExportSaveDialogTitle => '保存导出文件';

  @override
  String get previewExportCanceled => '已取消导出';

  @override
  String previewExportFailed(String error) {
    return '导出失败: $error';
  }

  @override
  String get autoT0116 => '心情';

  @override
  String get autoT0117 => '发表于';

  @override
  String get autoT0118 => '最后编辑于';

  @override
  String get autoT0119 => '今天还没有写下正文';

  @override
  String get autoT0120 => '日记';

  @override
  String autoT0121(String p0) {
    return '加载失败: $p0';
  }

  @override
  String get autoT0122 => '日记已不存在';

  @override
  String get autoT0123 => '日记已不存在，正在返回...';

  @override
  String get autoT0124 => '日记不存在';

  @override
  String get autoT0125 => '更多';

  @override
  String autoT0126(String p0) {
    return '标签$p0';
  }

  @override
  String autoT0127(String p0) {
    return '日记加载失败: $p0';
  }

  @override
  String get autoT0128 => '取消搜索';

  @override
  String get autoT0129 => '搜索标题或内容';

  @override
  String get autoT0130 => '清空';

  @override
  String get autoT0131 => '未保存内容';

  @override
  String get autoT0132 => '退出';

  @override
  String get editSaveAndExit => '保存并退出';

  @override
  String get autoT0133 => '开始记录...';

  @override
  String get autoT0134 => '新建日记';

  @override
  String get autoT0135 => '编辑日记';

  @override
  String get autoT0136 => '发布';

  @override
  String get autoT0137 => '保存日记';

  @override
  String get autoT0138 => '发表日记';

  @override
  String get autoT0139 => '正文为空';

  @override
  String get autoT0140 => '归档';

  @override
  String get autoT0141 => '排序方式';

  @override
  String get autoT0145 => '显示布局';

  @override
  String get autoT0146 => '列表';

  @override
  String get autoT0147 => '瀑布流';

  @override
  String get autoT0149 => '编辑标签';

  @override
  String get autoT0150 => '标签名';

  @override
  String get autoT0151 => '选择颜色';

  @override
  String get autoT0152 => '没有搜索到日记';

  @override
  String get autoT0153 => '换个关键词再试试吧～';

  @override
  String get autoT0154 => '还没有日记';

  @override
  String get autoT0155 => '新建日记';

  @override
  String get autoT0156 => '封面加载失败';

  @override
  String get autoT0157 => '新建';

  @override
  String get autoT0158 => '上划展开';

  @override
  String get autoT0159 => '下滑收起';

  @override
  String get autoT0160 => '选择标签';

  @override
  String get autoT0161 => '点击选择封面（可选）';

  @override
  String get autoT0162 => '封面';

  @override
  String get autoT0163 => '清除封面';

  @override
  String get autoT0164 => '未选择标签';

  @override
  String autoT0165(String p0) {
    return '标签加载失败: $p0';
  }

  @override
  String get autoT0166 => '暂无标签，可先创建';

  @override
  String get autoT0167 => '此时此地';

  @override
  String get autoT0168 => '点击右侧获取当前地址';

  @override
  String get autoT0169 => '获取位置';

  @override
  String get autoT0170 => '点击右侧获取当前天气';

  @override
  String get autoT0171 => '获取天气';

  @override
  String get autoT0172 => '发表时间';

  @override
  String get autoT0173 => '自动获取当前时间';

  @override
  String get autoT0174 => '选择发表时间';

  @override
  String get autoT0175 => '精力';

  @override
  String get autoT0176 => '发布中...';

  @override
  String get autoT0177 => '选择日期';

  @override
  String get autoT0178 => '月视图';

  @override
  String get autoT0179 => '周视图';

  @override
  String get autoT0180 => '回到今天';

  @override
  String get autoT0181 => '补写日记';

  @override
  String get autoT0182 => '这一天很安静，没有任何记录。';

  @override
  String get autoT0183 => '日历';

  @override
  String get autoT0184 => '上个月';

  @override
  String get autoT0185 => '下个月';

  @override
  String get autoT0186 => '记录了一则内容';

  @override
  String get autoT0187 => '确认将工具栏顺序恢复为默认排序吗？';

  @override
  String get autoT0188 => '用于给选中文本添加行内代码样式';

  @override
  String get autoT0189 => '转为代码块；在代码块里点按可选语言、复制或退出';

  @override
  String get autoT0190 => '该项会同时显示缩进增加/减少两个按钮';

  @override
  String autoT0191(String p0) {
    return '已恢复 $p0 条日记';
  }

  @override
  String autoT0192(String p0) {
    return '已彻底删除 $p0 条日记';
  }

  @override
  String autoT0193(String p0) {
    return '确认彻底删除已选择的 $p0 条日记吗？删除后不可恢复。';
  }

  @override
  String autoT0194(String p0) {
    return '删除于 $p0';
  }

  @override
  String recycleBinEntryFooter(String date, String deletedAt) {
    return '$date · $deletedAt';
  }

  @override
  String autoT0195(String p0) {
    return '确认删除标签 \"$p0\" 吗？';
  }

  @override
  String get autoT0196 => '今天你最想感谢的人或事是什么？';

  @override
  String get autoT0197 => '加载图片失败，请稍后重试';

  @override
  String get autoT0199 => '还没有标签数据，写几篇带标签的日记试试。';

  @override
  String autoT0200(String p0) {
    return '确认删除已选择的 $p0 条归档日记吗？';
  }

  @override
  String autoT0201(String p0) {
    return '已取消归档 $p0 条日记';
  }

  @override
  String get autoT0203 => 'metadata 必须是合法 JSON 对象';

  @override
  String get autoT0204 => '未检测到高德 Web 服务 key，请先配置 amap.web.api.key';

  @override
  String get autoT0205 => '未检测到和风天气 key，请先配置 qweather.api_key';

  @override
  String get autoT0206 => '将执行软删除，后续可恢复。确定继续吗？';

  @override
  String get autoT0207 => '当前有未保存的内容，确定退出吗？';

  @override
  String get autoT0208 => '标题样式（点击切换）';

  @override
  String autoT0210(String p0) {
    return '日历日记加载失败: $p0';
  }

  @override
  String get autoT0211 => '别着急，属于这一天的精彩还没发生。';

  @override
  String get timeCapsuleTitle => '定时锁';

  @override
  String get timeCapsuleUnset => '未封存';

  @override
  String timeCapsuleSet(String p0) {
    return '$p0 解封';
  }

  @override
  String get timeCapsulePickTitle => '选择解封时间';

  @override
  String get timeCapsulePrecisionMinute => '精确到时间';

  @override
  String get timeCapsulePrecisionDate => '只按日期';

  @override
  String get timeCapsuleQuickWeek => '一周后';

  @override
  String get timeCapsuleQuickMonth => '一个月后';

  @override
  String get timeCapsuleQuickYear => '一年后';

  @override
  String get timeCapsuleClear => '移除定时锁';

  @override
  String get timeCapsuleLockedTitle => '沉睡时刻';

  @override
  String timeCapsuleCountdownDays(String p0) {
    return '$p0 天后解封';
  }

  @override
  String timeCapsuleCountdownHours(String p0) {
    return '$p0 小时后解封';
  }

  @override
  String timeCapsuleLockedHint(String p0) {
    return '这篇日记会在 $p0 解封。你可以调整解封时间或删除它，但正文会继续保密。';
  }

  @override
  String get timeCapsuleUpdateUnlock => '调整解封时间';

  @override
  String get timeCapsuleSealing => '正在封存此刻...';

  @override
  String timeCapsuleSealDone(String p0) {
    return '已锁定至 $p0';
  }

  @override
  String timeCapsuleUnlockedInsight(String p0) {
    return '写下这篇日记时，你是 $p0 的，今天感觉如何？';
  }

  @override
  String get timeCapsuleUnlockedInsightNoMood => '这是一封写给未来自己的日记，今天感觉如何？';

  @override
  String get webDavServerUrl => '服务器地址';

  @override
  String get webDavServerUrlHint => '例如 https://nas.example.com:5006/webdav/';

  @override
  String get webDavUsername => '用户名';

  @override
  String get webDavPassword => '密码或 Token';

  @override
  String get webDavRemoteDirectory => '远程目录';

  @override
  String get webDavRemoteDirectoryHint => '例如 /jotsy/';

  @override
  String get webDavHint =>
      '建议在 NAS 中为 Jotsy 创建独立目录，并优先使用应用专用密码或 Token。上传会生成完整 ZIP 备份；恢复时可选择合并或覆盖本地数据。';

  @override
  String get imageViewerSaveToGallery => '保存到相册';

  @override
  String get imageViewerSaving => '正在保存…';

  @override
  String get imageViewerSaveSuccess => '已保存到相册';

  @override
  String imageViewerSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String get imageViewerGalleryPermissionDenied => '未获得相册权限，无法保存';

  @override
  String get desktopSaveAs => '另存为…';

  @override
  String get desktopSaveImageDialogTitle => '保存图片';

  @override
  String get desktopSaveVideoDialogTitle => '保存视频';

  @override
  String desktopSavedTo(String path) {
    return '已保存到 $path';
  }

  @override
  String get diaryShareSaveImages => '保存图片…';

  @override
  String get diaryShareSaveImagesDialogTitle => '选择保存图片的文件夹';

  @override
  String diaryShareImagesSaved(int count, String path) {
    return '已把 $count 张图片保存到 $path';
  }

  @override
  String get diaryShareLongImageSave => '保存为长图…';

  @override
  String get videoOpenExternally => '用系统播放器打开';

  @override
  String get videoPosterHint => '点按用系统播放器打开';

  @override
  String get deviceAuthUnavailable => '这台设备没有系统身份验证。在 设置 → 应用锁与密码 里设置应用密码后即可上锁';

  @override
  String get calendarYearSaveImage => '保存这一年的图片…';

  @override
  String get imageViewerSharing => '正在准备分享…';

  @override
  String imageViewerShareFailed(String error) {
    return '分享失败：$error';
  }

  @override
  String get imageViewerDownloadFailed => '图片下载失败，请检查网络后重试';

  @override
  String get imageViewerOpenDiary => '打开日记';

  @override
  String get imageViewerImageUnreadable => '读取不到这张图片，无法分享';

  @override
  String get imageViewerMoreActions => '更多操作';

  @override
  String get imageViewerPrevious => '上一张';

  @override
  String get imageViewerNext => '下一张';

  @override
  String get diaryToolbarInsertCurrentTime => '插入当前时间';

  @override
  String get diaryToolbarRecording => '录音';

  @override
  String get recordingStart => '开始录音';

  @override
  String get recordingPause => '暂停录音';

  @override
  String get recordingResume => '继续录音';

  @override
  String get recordingFinish => '结束录音';

  @override
  String get recordingClose => '关闭录音';

  @override
  String get recordingPaused => '已暂停';

  @override
  String get recordingPermissionDenied => '未允许使用麦克风';

  @override
  String get recordingFailed => '录音失败，请重试';

  @override
  String get recordingSaveFailed => '录音保存失败，请重试';

  @override
  String get recordingAttachment => '录音';

  @override
  String get recordingPlaybackPlay => '播放录音';

  @override
  String get recordingPlaybackPause => '暂停播放';

  @override
  String get recordingPlaybackFailed => '录音无法播放';

  @override
  String get recordingRename => '重命名录音';

  @override
  String get recordingNameHint => '输入录音名称';

  @override
  String get recordingDefaultTitle => '语音备注';

  @override
  String get recordingStatusRecording => '录音中';

  @override
  String get recordingIdleHint => '点按麦克风开始录音';

  @override
  String get diaryToolbarToolSettingsTooltip => '配置工具参数';

  @override
  String get diaryToolbarTimeFormatTitle => '配置时间格式';

  @override
  String get diaryToolbarTimeFormatLabel => '时间格式';

  @override
  String get diaryToolbarTimeFormatHelp =>
      '默认格式为 M月d日 HH:mm。可使用 yyyy、MM、dd、HH、mm 等 DateFormat 格式符，例如 yyyy-MM-dd HH:mm。';

  @override
  String diaryToolbarTimeFormatPreview(String value) {
    return '预览：$value';
  }

  @override
  String get diaryToolbarTimeFormatInvalid => '时间格式无效，请检查格式符。';

  @override
  String get diaryTagCollapse => '收起标签';

  @override
  String get diaryTagCollapseHint => '在此处上滑或点击，收起标签列表';

  @override
  String diaryTagPullHint(int count) {
    return '下拉查看全部 $count 个标签';
  }

  @override
  String diaryTagPullHintDesktop(int count) {
    return '向下拖动或点按，查看全部 $count 个标签';
  }

  @override
  String get diaryTagExpand => '展开标签';

  @override
  String get diaryPinnedBadge => '置顶';

  @override
  String get diaryEnergyUnrecorded => '未记录';

  @override
  String get diaryEnergySwitchTooltip => '开启或关闭精力记录';

  @override
  String get diaryToolbarInsertVideo => '插入视频';

  @override
  String get diaryToolbarInsertAttachment => '插入附件';

  @override
  String get diaryMediaImporting => '正在导入文件…';

  @override
  String get diaryMediaImportFailed => '文件导入失败，请重试';

  @override
  String get diaryMediaImportPermissionDenied => '未获得所选文件的读取权限，请重新选择并允许访问';

  @override
  String get diaryMediaPickerUnavailable => '无法打开系统选择器，请确认设备已启用相册或文件管理器';

  @override
  String get diaryMediaImportUnsupported => '当前平台暂不支持文件导入';

  @override
  String get diaryMediaFromLibrary => '从相册选择';

  @override
  String get diaryMediaTakePhoto => '拍照';

  @override
  String get diaryMediaRecordVideo => '录像';

  @override
  String get diaryMediaCameraPermissionDenied => '没有相机权限，请在系统设置里允许 Jotsy 使用相机';

  @override
  String get diaryMediaCameraUnavailable => '没有找到可用的相机';

  @override
  String get attachmentOpen => '打开附件';

  @override
  String get attachmentOpenHint => '点击使用其他应用打开';

  @override
  String get attachmentOpening => '正在打开附件…';

  @override
  String get attachmentFileMissing => '附件文件不存在或无法访问';

  @override
  String get imageLoadFailed => '图片文件不存在或无法加载';

  @override
  String get imageHeifUnsupported => '这台电脑显示不了 HEIC 格式的图片';

  @override
  String get imageHeifUnsupportedHint =>
      '在手机上打开 Jotsy，它会自动把这张图转成 JPEG，再同步一次就能看到了。';

  @override
  String get imageOpenInOtherApp => '用其他应用打开';

  @override
  String get attachmentNoApp => '手机上没有可打开此文件的应用';

  @override
  String get attachmentPermissionDenied => '无法访问此附件文件';

  @override
  String get attachmentOpenFailed => '附件打开失败，请重试';

  @override
  String get videoLoading => '正在加载视频…';

  @override
  String get videoPlay => '播放视频';

  @override
  String get videoPause => '暂停视频';

  @override
  String get videoProgress => '视频播放进度';

  @override
  String get videoPlaybackFailed => '视频暂时无法播放，点击使用其他应用打开';

  @override
  String get videoExport => '导出视频';

  @override
  String get videoExportConfirmTitle => '导出视频';

  @override
  String videoExportConfirmMessage(String name) {
    return '确认将“$name”保存到手机相册？';
  }

  @override
  String get videoExporting => '正在导出视频…';

  @override
  String get videoExportSuccess => '视频已保存到相册';

  @override
  String get videoExportFileMissing => '视频文件不存在或为空，无法导出';

  @override
  String get videoExportPermissionDenied => '未获得相册权限，无法导出视频';

  @override
  String get videoExportNotEnoughSpace => '手机存储空间不足，无法导出视频';

  @override
  String get videoExportUnsupportedFormat => '此视频格式暂不支持保存到相册';

  @override
  String get videoExportDownloadFailed => '视频下载失败，请重试';

  @override
  String get videoExportFailed => '视频导出失败，请重试';

  @override
  String get videoFullscreen => '全屏播放';

  @override
  String get videoExitFullscreen => '退出全屏';

  @override
  String get locationPrecisionTitle => '地址层级';

  @override
  String get locationPrecisionCity => '城市';

  @override
  String get locationPrecisionDistrict => '区县';

  @override
  String get locationPrecisionTownship => '街道／乡镇';

  @override
  String get locationPrecisionStreet => '道路';

  @override
  String get locationPrecisionAddress => '门牌号';

  @override
  String get locationUnsupported => '当前平台暂不支持自动获取位置。';

  @override
  String get locationPermissionDenied => '未获得定位权限，请允许访问位置后重试；也支持仅授权大致位置。';

  @override
  String get locationPermissionDeniedForever => '定位权限已被禁止，请在系统设置中允许访问位置，再返回重试。';

  @override
  String get locationServiceDisabled => '系统定位服务未开启，请在系统设置中开启后重试。';

  @override
  String get locationNetworkError => '地址解析请求失败或超时，请检查网络后重试。';

  @override
  String get locationApiError => '地址服务暂时不可用，请稍后重试。';

  @override
  String get locationAddressInvalid => '未获取到有效地址，请稍后重试或手动填写地点。';

  @override
  String get locationUnavailable => '暂时无法获取位置，请到卫星信号较好的位置重试，或手动填写地点。';

  @override
  String get diarySortFieldUpdated => '更新时间';

  @override
  String get diarySortFieldPublished => '发表时间';

  @override
  String get diarySortFieldTitle => '标题';

  @override
  String get diarySortHintUpdatedDesc => '最近更新的在前';

  @override
  String get diarySortHintUpdatedAsc => '最早更新的在前';

  @override
  String get diarySortHintPublishedDesc => '最新发表的在前';

  @override
  String get diarySortHintPublishedAsc => '最早发表的在前';

  @override
  String get diarySortHintTitleAsc => '标题 A → Z，无标题的在最后';

  @override
  String get diarySortHintTitleDesc => '标题 Z → A，无标题的在最后';

  @override
  String get diaryToolbarMoreTools => '更多工具';

  @override
  String get diaryToolbarHideMoreTools => '收起更多工具';

  @override
  String get diaryToolbarMoreToolsActive => '有格式正在生效';

  @override
  String get diaryToolbarOverflowDivider => '以下收进「更多」';

  @override
  String get backupBusyInspect => '正在读取文件...';

  @override
  String get backupImportOptionsTitle => '选择导入方式';

  @override
  String get backupImportKindFull => '完整备份';

  @override
  String get backupImportKindDiary => '日记文件';

  @override
  String backupImportSummary(int diaries, int tags) {
    return '$diaries 篇日记 · $tags 个标签';
  }

  @override
  String get backupImportIncludesSettings => '包含应用设置';

  @override
  String backupImportExistingCount(int count) {
    return '其中 $count 篇本机已存在';
  }

  @override
  String get backupImportModeMerge => '合并（推荐）';

  @override
  String get backupImportModeMergeDescription =>
      '保留本机全部数据，只添加本机没有的日记，已存在的日记保持不变';

  @override
  String get backupImportModeOverwriteExisting => '覆盖已存在的日记';

  @override
  String backupImportModeOverwriteExistingDescription(int count) {
    return '添加新日记，并用文件中的版本替换本机已存在的 $count 篇日记';
  }

  @override
  String get backupImportModeReplaceAll => '覆盖全部数据';

  @override
  String get backupImportModeReplaceAllDescription =>
      '清空本机全部日记、标签、媒体与设置，替换为备份内容';

  @override
  String get backupOverwriteAllTitle => '覆盖全部数据？';

  @override
  String get backupOverwriteExistingTitle => '覆盖已存在的日记？';

  @override
  String get backupOverwriteIrreversible => '此操作无法撤销';

  @override
  String get backupOverwriteAllLead => '本机现有的以下数据将被永久删除，并替换为备份中的内容：';

  @override
  String backupOverwriteAllDiaries(int count) {
    return '$count 篇日记（含归档与回收站）';
  }

  @override
  String backupOverwriteAllTags(int count) {
    return '$count 个标签';
  }

  @override
  String get backupOverwriteAllMedia => '全部图片、录音、视频与附件';

  @override
  String get backupOverwriteAllSettings => '应用设置与未发布的草稿';

  @override
  String backupOverwriteExistingBody(int count) {
    return '本机已存在的 $count 篇日记将被文件中的版本整篇替换，它们在本机上的修改与标签都会永久丢失。其他日记不受影响。';
  }

  @override
  String get backupOverwriteBackupTip => '如需保留当前数据，请先取消并导出一份备份。';

  @override
  String get backupOverwriteAcknowledge => '我已了解被覆盖的数据无法恢复';

  @override
  String get backupOverwriteConfirm => '确认覆盖';

  @override
  String backupOverwriteConfirmCountdown(int seconds) {
    return '确认覆盖（$seconds）';
  }

  @override
  String backupImportMergeResult(int added) {
    return '导入完成：新增 $added 篇日记';
  }

  @override
  String backupImportMergeSkippedResult(int added, int skipped) {
    return '导入完成：新增 $added 篇，跳过 $skipped 篇本机已存在的日记';
  }

  @override
  String backupImportOverwriteResult(int added, int replaced) {
    return '导入完成：新增 $added 篇，覆盖 $replaced 篇日记';
  }

  @override
  String get previewExportDiaryFileConfirm => '导出';

  @override
  String get previewExportDiaryFileSuccess => '日记文件已导出，可在「数据管理」中导入';

  @override
  String get dataMgmtImportJournal => '从其他日记应用导入';

  @override
  String get dataMgmtImportJournalSubtitle =>
      '支持 Day One、Evernote、Google Keep、Obsidian、小米笔记、华为备忘录等 18 种来源';

  @override
  String get journalImportSourceTitle => '从哪个应用导入？';

  @override
  String get journalImportSourceHint => '先在原应用中导出数据，再在这里选择导出的文件。';

  @override
  String get journalImportAppleJournal => 'Apple 手记';

  @override
  String get journalImportDayOneHint => '导出为 JSON 格式（.zip）';

  @override
  String get journalImportJourneyHint => '导出为 ZIP（.zip）';

  @override
  String get journalImportDiariumHint => 'JSON 导出（.json）或备份文件（.diary）';

  @override
  String get journalImportDaylioHint => '备份文件（.daylio）或导出的 CSV（.csv）';

  @override
  String get journalImportAppleJournalHint =>
      '在 iPhone「设置 › App › 手记」中导出所有条目（.zip）';

  @override
  String journalImportPickDialogTitle(String app) {
    return '选择 $app 导出文件';
  }

  @override
  String journalImportUnrecognized(String app) {
    return '无法识别为 $app 的导出文件';
  }

  @override
  String get journalImportNoEntries => '文件中没有可导入的日记';

  @override
  String get journalImportGroupJournals => '日记应用';

  @override
  String get journalImportGroupNotes => '笔记应用';

  @override
  String get journalImportGroupPhoneNotes => '手机与 WPS 云笔记';

  @override
  String get journalImportPhoneNotesHint =>
      '在应用内登录官方云服务，直接读取云端笔记、分组与图片附件；登录状态只用于本次导入，结束后即清除。';

  @override
  String get journalImportDiaroHint => '备份文件（.zip，不能加密）';

  @override
  String get journalImportDurianDiary => '榴莲日记';

  @override
  String get journalImportDurianDiaryHint =>
      '「导入导出」中导出的压缩包（.lld），或压缩成 .zip 的备份文件夹';

  @override
  String get journalImportEvernote => '印象笔记 / Evernote';

  @override
  String get journalImportEvernoteHint => '导出笔记本为 ENEX（.enex，多个可打包成 .zip）';

  @override
  String get journalImportGoogleKeepHint => '在 Google Takeout 中导出 Keep（.zip）';

  @override
  String get journalImportJoplinHint => '导出为 JEX（.jex）';

  @override
  String get journalImportMemosHint => 'v0.31 起在「设置 › 导出与导入」中导出（.zip）';

  @override
  String get journalImportMarkdown => 'Markdown / 纯文本';

  @override
  String get journalImportMarkdownHint =>
      'Obsidian、Bear、Notion 等导出的 .md / .txt，或它们的 .zip';

  @override
  String get journalImportXiaomiNotes => '小米笔记';

  @override
  String get journalImportHuaweiNotepad => '华为备忘录';

  @override
  String get journalImportOppoNotes => 'OPPO 笔记';

  @override
  String get journalImportVivoNotes => 'vivo 笔记';

  @override
  String get journalImportHonorNotes => '荣耀笔记';

  @override
  String get journalImportMeizuNotes => '魅族笔记';

  @override
  String get journalImportWpsNotes => 'WPS 便签';

  @override
  String get journalImportSmartisanNotes => '锤子便签';

  @override
  String journalImportEncrypted(String app) {
    return '$app 的加密备份无法导入，请在原应用中创建未加密的备份';
  }

  @override
  String cloudLoginTitle(String app) {
    return '登录$app';
  }

  @override
  String get cloudLoginHint => '在上方官方网页中登录并进入笔记页面，再点「读取笔记」。登录状态只用于本次导入，结束后即清除。';

  @override
  String get cloudLoginRead => '读取笔记';

  @override
  String get cloudLoginReload => '刷新页面';

  @override
  String get cloudLoginChecking => '正在核对登录状态';

  @override
  String get cloudLoginNotSignedIn => '还没有登录，请先在页面中完成登录';

  @override
  String cloudBusyReading(int count) {
    return '正在读取云端笔记（$count 篇）';
  }

  @override
  String cloudBusyProgress(int done, int total) {
    return '正在读取云端笔记（$done/$total）';
  }

  @override
  String get cloudErrorSession => '登录已失效或需要二次验证，请重新登录';

  @override
  String get cloudErrorForbidden => '平台拒绝访问（HTTP 403），请核对账号权限或官网提示';

  @override
  String get cloudErrorRateLimited => '请求过于频繁，请稍后再试';

  @override
  String get cloudErrorServer => '平台服务暂时不可用，请稍后再试';

  @override
  String get cloudErrorRejected => '平台拒绝了请求，请检查账号权限后重试';

  @override
  String get cloudErrorNetwork => '网络请求失败，请检查网络连接后重试';

  @override
  String cloudErrorProtocol(String app) {
    return '$app 返回了无法识别的内容，已停止读取以免遗漏笔记';
  }

  @override
  String cloudErrorUnsupportedAccount(String app) {
    return '此 $app 账号的笔记已加密或暂不支持读取';
  }

  @override
  String backupImportKindJournal(String app) {
    return '$app 导出';
  }

  @override
  String backupImportMissingMedia(int count) {
    return '$count 个媒体文件不在导出中，将跳过';
  }

  @override
  String backupImportSkippedEncrypted(int count) {
    return '$count 篇加密或上锁的笔记读不到，将跳过';
  }

  @override
  String backupImportSkippedUnsupported(int count) {
    return '$count 篇手写、思维导图等专有格式的笔记将跳过';
  }

  @override
  String backupImportSkippedUnreadable(int count) {
    return '$count 篇笔记的格式无法识别，将跳过';
  }

  @override
  String backupImportSummaryOnly(int count) {
    return '$count 篇笔记的正文没能读取，只导入摘要';
  }

  @override
  String backupImportPartialContent(int count) {
    return '$count 篇笔记含无法解密或显示的片段，可读正文与原始信息将保留';
  }

  @override
  String get calendarDisplayOptionsTooltip => '调整日历';

  @override
  String get calendarOptionsTitle => '日历显示';

  @override
  String get calendarOptionsReset => '恢复默认';

  @override
  String get calendarOptionsCellStyle => '日期格';

  @override
  String get calendarCellStyleDot => '圆点';

  @override
  String get calendarCellStyleMood => '心情';

  @override
  String get calendarCellStyleHeat => '热力';

  @override
  String get calendarCellStylePhoto => '照片';

  @override
  String get calendarCellStyleTags => '标签色';

  @override
  String get calendarCellStyleDotDescription => '有几篇画几个点，最多 3 个。';

  @override
  String get calendarCellStyleMoodDescription => '当天记录的心情表情。';

  @override
  String get calendarCellStyleHeatDescription => '写得越多，格子颜色越深。';

  @override
  String get calendarCellStylePhotoDescription => '封面或正文第一张图铺满格子。';

  @override
  String get calendarCellStyleTagsDescription => '当天所用标签的颜色，最多 3 个。';

  @override
  String get calendarMoodAverage => '取平均';

  @override
  String get calendarMoodEach => '逐篇显示';

  @override
  String get calendarHeatBasisEntries => '按篇数';

  @override
  String get calendarHeatBasisWords => '按字数';

  @override
  String get calendarOptionsBadges => '角标';

  @override
  String get calendarBadgeCount => '篇数';

  @override
  String get calendarBadgeCapsule => '未解封的时间胶囊';

  @override
  String get calendarBadgeWeather => '天气';

  @override
  String get calendarOptionsLayout => '布局';

  @override
  String get calendarOptionsWeekStart => '一周起始日';

  @override
  String get calendarWeekStartLocale => '跟随语言';

  @override
  String get calendarWeekStartMonday => '周一';

  @override
  String get calendarWeekStartSunday => '周日';

  @override
  String get calendarOptionsDefaultFormat => '打开时显示';

  @override
  String get calendarFormatMonth => '月视图';

  @override
  String get calendarFormatWeek => '周视图';

  @override
  String get calendarFormatRemember => '上次的视图';

  @override
  String get calendarHighlightWeekends => '周末着色';

  @override
  String get calendarShowWeekNumbers => '显示周数';

  @override
  String get calendarFixedSixWeeks => '固定显示 6 行';

  @override
  String get calendarFixedSixWeeksDescription => '翻月时日历高度不再跳动。';

  @override
  String get calendarOptionsSections => '区块';

  @override
  String get calendarShowMonthSummary => '月度概览';

  @override
  String get calendarShowMonthSummaryDescription =>
      '本月篇数、记录天数、字数、最常见心情与最长连续天数。';

  @override
  String calendarSummaryEntries(int count) {
    return '共 $count 篇日记';
  }

  @override
  String calendarSummaryDays(int recorded, int elapsed) {
    return '$elapsed 天里记录了 $recorded 天';
  }

  @override
  String calendarSummaryDaysNoTotal(int count) {
    return '记录了 $count 天';
  }

  @override
  String calendarSummaryWords(String count) {
    return '共 $count 字';
  }

  @override
  String calendarSummaryMood(String mood) {
    return '最常见的心情：$mood';
  }

  @override
  String calendarSummaryStreak(int count) {
    return '最长连续记录 $count 天';
  }

  @override
  String get calendarSummaryEmpty => '这个月还没有日记';

  @override
  String get calendarSummaryFuture => '这个月还没开始';

  @override
  String get calendarRelativeToday => '今天';

  @override
  String get calendarRelativeYesterday => '昨天';

  @override
  String get calendarRelativeTomorrow => '明天';

  @override
  String calendarRelativeDaysAgo(int count) {
    return '$count 天前';
  }

  @override
  String calendarRelativeDaysLater(int count) {
    return '$count 天后';
  }

  @override
  String calendarDayStats(int entries, String words) {
    return '$entries 篇 · $words 字';
  }

  @override
  String get calendarYearViewTooltip => '查看全年';

  @override
  String get calendarYearBasisMood => '心情';

  @override
  String get calendarYearBasisEntries => '篇数';

  @override
  String get calendarYearBasisWords => '字数';

  @override
  String get calendarYearLegendLess => '少';

  @override
  String get calendarYearLegendMore => '多';

  @override
  String get calendarYearLegendNoMood => '未选心情';

  @override
  String get calendarYearExport => '分享这一年';

  @override
  String get calendarYearExportFailed => '图片生成失败，请重试';

  @override
  String get calendarOnThisDayTitle => '那年今日';

  @override
  String calendarOnThisDayYearsAgo(int count) {
    return '$count 年前';
  }

  @override
  String calendarOnThisDayYearsLater(int count) {
    return '$count 年后';
  }

  @override
  String get calendarDayActionView => '查看这一天';

  @override
  String get calendarDayActionWrite => '在这一天写日记';

  @override
  String get calendarDayActionCapsule => '写一封时间胶囊';

  @override
  String get calendarDayActionCapsuleDescription => '到这一天才能打开';

  @override
  String get calendarFutureCapsuleAction => '写给这一天的时间胶囊';

  @override
  String get calendarOptionsDayContent => '当天日记';

  @override
  String get calendarDayContentTimeline => '时间线';

  @override
  String get calendarDayContentCards => '卡片';

  @override
  String get calendarShowOnThisDay => '那年今日';

  @override
  String get calendarShowOnThisDayDescription => '其他年份的这一天写下的日记。';

  @override
  String get calendarPreviousYear => '上一年';

  @override
  String get calendarNextYear => '下一年';

  @override
  String get calendarOptionsLunar => '农历与节气';

  @override
  String get calendarOptionsLunarDescription => '在日期下方显示农历、节气与传统节日。';

  @override
  String get calendarLunarLocale => '跟随语言';

  @override
  String get calendarLunarAlways => '显示';

  @override
  String get calendarLunarNever => '隐藏';

  @override
  String calendarLunarDate(String date) {
    return '农历$date';
  }

  @override
  String get calendarSummaryEmptyYear => '这一年还没有日记';

  @override
  String get calendarSummaryFutureYear => '这一年还没开始';

  @override
  String get calendarSummaryEmptyRange => '这段时间没有日记';

  @override
  String get calendarSummaryFutureRange => '这段时间还没到';

  @override
  String get calendarDayActionRange => '从这天开始选择范围';

  @override
  String get calendarDayActionRangeDescription => '再点一个日期作为终点，统计这段时间';

  @override
  String calendarRangeTitle(String start, String end, int days) {
    return '$start – $end · $days 天';
  }

  @override
  String calendarRangePickEnd(String start) {
    return '$start 起 · 点按另一天作为终点';
  }

  @override
  String get calendarRangeExit => '退出范围选择';

  @override
  String get calendarFilterTooltip => '筛选';

  @override
  String get calendarFilterTitle => '筛选日历';

  @override
  String get calendarFilterNotebooks => '日记本';

  @override
  String get calendarFilterClear => '清除筛选';

  @override
  String get calendarFilterDescription =>
      '日期格与统计只算符合条件的日记。同一类里任选其一即可，选了多类时需同时满足。';

  @override
  String get calendarFilterMoods => '心情';

  @override
  String get calendarFilterTags => '标签';

  @override
  String get calendarFilterNoTags => '还没有标签';

  @override
  String get calendarFilterActive => '已筛选';

  @override
  String get calendarOptionsAlmanac => '农历与节假日';

  @override
  String get calendarOptionsHolidays => '法定节假日';

  @override
  String calendarOptionsHolidaysDescription(int year) {
    return '在日期左上标出放假（休）与调休上班（班），周末着色随之调整。数据收录到 $year 年。';
  }

  @override
  String get calendarOptionsHolidaysDescriptionOutdated =>
      '在日期左上标出放假（休）与调休上班（班），周末着色随之调整。当前版本还没有收录今年的放假安排。';

  @override
  String get calendarHolidayRestMark => '休';

  @override
  String get calendarHolidayWorkMark => '班';

  @override
  String get calendarHolidayDayOff => '休';

  @override
  String get calendarHolidayMakeUpWorkday => '调休上班';

  @override
  String backupImportAnniversaryCount(int count) {
    return '纪念日 $count 个';
  }

  @override
  String backupImportExistingAnniversaryCount(int count) {
    return '其中 $count 个纪念日本机已存在';
  }

  @override
  String backupImportModeOverwriteAnniversariesOnly(int count) {
    return '添加新内容，并用文件中的版本替换本机已存在的 $count 个纪念日';
  }

  @override
  String backupImportModeOverwriteAnniversariesExtra(int count) {
    return '同时替换本机已存在的 $count 个纪念日';
  }

  @override
  String backupOverwriteAllAnniversaries(int count) {
    return '$count 个纪念日';
  }

  @override
  String backupOverwriteExistingAnniversariesBody(int count) {
    return '本机已存在的 $count 个纪念日将被文件中的版本替换，本机上的修改会永久丢失。';
  }

  @override
  String backupImportAnniversaryMergeResult(int added) {
    return '纪念日：新增 $added 个';
  }

  @override
  String backupImportAnniversaryMergeSkippedResult(int added, int skipped) {
    return '纪念日：新增 $added 个，跳过 $skipped 个本机已存在的';
  }

  @override
  String backupImportAnniversaryOverwriteResult(int added, int replaced) {
    return '纪念日：新增 $added 个，覆盖 $replaced 个';
  }

  @override
  String get calendarShowAnniversaries => '纪念日';

  @override
  String get calendarShowAnniversariesDescription => '在日期上标出纪念日，选中那天时显示纪念日卡片。';

  @override
  String get calendarDayActionAnniversary => '添加纪念日';

  @override
  String get calendarDayActionAnniversaryDescription => '记下这一天，以后每年日历上都会标出它';

  @override
  String get calendarDayActionCountdownDescription => '倒数到这一天';

  @override
  String get anniversarySectionTitle => '纪念日';

  @override
  String anniversaryOrdinal(int count) {
    return '第 $count 周年';
  }

  @override
  String anniversaryTodayOrdinal(int count) {
    return '今天是第 $count 周年';
  }

  @override
  String anniversaryDaysLeft(int count) {
    return '还有 $count 天';
  }

  @override
  String anniversaryDaysSince(int count) {
    return '已经 $count 天';
  }

  @override
  String get anniversaryBaseDay => '开始的那一天';

  @override
  String get anniversaryCountdownLabel => '倒数日';

  @override
  String get anniversaryIsToday => '就是今天';

  @override
  String get anniversaryAdjustedNote => '今年没有这一天，顺延到相近的日子';

  @override
  String get anniversaryNewTitle => '新建纪念日';

  @override
  String get anniversaryEditTitle => '编辑纪念日';

  @override
  String get anniversaryFieldName => '名称';

  @override
  String get anniversaryNameHint => '如：在一起、妈妈生日、考研';

  @override
  String get anniversaryNameRequired => '请输入名称';

  @override
  String get anniversaryFieldDate => '日期';

  @override
  String get anniversaryFieldRepeat => '重复';

  @override
  String get anniversaryRepeatSolar => '每年';

  @override
  String get anniversaryRepeatLunar => '农历每年';

  @override
  String get anniversaryRepeatOnce => '不重复';

  @override
  String anniversaryRepeatSolarDescription(String date) {
    return '每年的 $date 都会标出这一天';
  }

  @override
  String get anniversaryRepeatLeapDayDescription => '每年的 2月29日，平年顺延到 2月28日';

  @override
  String anniversaryRepeatLunarDescription(String date) {
    return '每年农历$date，按农历换算到当年的日子';
  }

  @override
  String get anniversaryRepeatOnceDescription => '只记这一天：之前倒数还有几天，之后记已经几天';

  @override
  String anniversaryLunarYearDate(String year, String date) {
    return '农历$year年$date';
  }

  @override
  String get anniversaryFieldNote => '备注';

  @override
  String get anniversaryNoteHint => '写点什么（可选）';

  @override
  String get anniversaryPin => '置顶';

  @override
  String get anniversaryPinDescription => '在纪念日列表里排在最前';

  @override
  String get anniversaryDelete => '删除纪念日';

  @override
  String get anniversaryDeleteConfirmTitle => '删除纪念日？';

  @override
  String anniversaryDeleteConfirmBody(String title) {
    return '“$title”将从日历中移除，关联的日记不受影响。';
  }

  @override
  String get anniversaryDeleted => '已删除纪念日';

  @override
  String get anniversaryCreated => '已添加纪念日';

  @override
  String get anniversarySaveFailed => '保存失败，请重试';

  @override
  String get anniversaryListTitle => '纪念日';

  @override
  String get anniversaryEmpty => '还没有纪念日。长按日历上的某一天，或点右上角的“+”添加。';

  @override
  String get anniversaryPinnedBadge => '置顶';

  @override
  String anniversaryDaysToGo(int count) {
    return '天后';
  }

  @override
  String anniversaryDaysAgo(int count) {
    return '天前';
  }

  @override
  String get anniversaryDetailNext => '下一次';

  @override
  String get anniversaryDetailStart => '开始于';

  @override
  String get anniversaryMoreActions => '更多操作';

  @override
  String get anniversaryUnpin => '取消置顶';

  @override
  String get anniversaryFieldLink => '关联日记';

  @override
  String get anniversaryLinkNone => '不关联';

  @override
  String get anniversaryLinkPick => '关联一篇日记';

  @override
  String get anniversaryLinkMissing => '关联的日记已删除';

  @override
  String get anniversaryUnlink => '取消关联';

  @override
  String get anniversaryLinkedDiaryTitle => '关联的日记';

  @override
  String get anniversaryOpenLinkedDiary => '打开关联的日记';

  @override
  String get anniversaryPickerHint => '所选日期前后 7 天写下的日记';

  @override
  String get anniversaryPickerEmpty => '这一天前后一周没有日记';

  @override
  String get anniversaryPastDiariesTitle => '历年这一天';

  @override
  String get anniversaryBaseDayDiariesTitle => '这一天的日记';

  @override
  String get anniversaryPastDiariesEmpty => '这些日子还没有写过日记';

  @override
  String get anniversaryView => '查看';

  @override
  String get previewSetAsAnniversary => '设为纪念日';

  @override
  String get diaryTypographyTitle => '正文字体与排版';

  @override
  String diaryTypographySummary(String font, String size, String lineHeight) {
    return '$font · 字号 $size · 行距 $lineHeight';
  }

  @override
  String get diaryTypographyQuickTooltip => '字体与排版';

  @override
  String get diaryTypographyFontSection => '字体';

  @override
  String get diaryTypographyFontBundled => 'HarmonyOS Sans';

  @override
  String get diaryTypographyFontSystem => '系统字体';

  @override
  String get diaryTypographyFontSystemHint => '跟随手机当前使用的字体';

  @override
  String get diaryTypographyFontMissing =>
      '所选字体的文件已不在本机，正文暂按 HarmonyOS Sans 显示；可重新导入或改选其他字体。';

  @override
  String get diaryTypographyImportFont => '导入字体文件';

  @override
  String get diaryTypographyImportFontHint => '支持 TTF、OTF、TTC 格式，导入后即设为正文字体';

  @override
  String get diaryTypographyApplyToApp => '用于整个界面';

  @override
  String get diaryTypographyApplyToAppHint => '关闭时只用于日记标题、正文与日记卡片';

  @override
  String get diaryTypographyImporting => '正在导入字体…';

  @override
  String diaryTypographyImported(String name) {
    return '已导入并使用“$name”';
  }

  @override
  String get diaryTypographyImportUnsupported =>
      '这不是可用的字体文件，请选择 TTF、OTF 或 TTC 格式';

  @override
  String get diaryTypographyImportUnreadable => '无法读取所选文件';

  @override
  String get diaryTypographyImportFailed => '字体导入失败，请检查存储空间后重试';

  @override
  String get diaryTypographyDeleteFont => '删除字体';

  @override
  String diaryTypographyDeleteFontTitle(String name) {
    return '删除字体“$name”？';
  }

  @override
  String get diaryTypographyDeleteFontMessage =>
      '字体文件会从本机移除。正在使用这款字体时，正文改回 HarmonyOS Sans。';

  @override
  String get diaryTypographyLayoutSection => '排版';

  @override
  String get diaryTypographyFontSize => '字号';

  @override
  String get diaryTypographyLineHeight => '行距';

  @override
  String get diaryTypographyLetterSpacing => '字间距';

  @override
  String get diaryTypographyParagraphSpacing => '段间距';

  @override
  String get diaryTypographyFirstLineIndent => '首行缩进';

  @override
  String diaryTypographyFirstLineIndentValue(num count, String value) {
    return '$value 字';
  }

  @override
  String get diaryTypographyFirstLineIndentOff => '不缩进';

  @override
  String diaryTypographyDecrease(String label) {
    return '减小$label';
  }

  @override
  String diaryTypographyIncrease(String label) {
    return '增大$label';
  }

  @override
  String get diaryTypographyReset => '恢复默认排版';

  @override
  String get diaryTypographyScopeHint => '字号、行距等排版作用于日记的编辑、阅读与发布页面。';

  @override
  String get diaryTypographyMoreSettings => '更多设置';

  @override
  String get diaryTypographySampleTitle => '雨后的傍晚';

  @override
  String get diaryTypographySampleBody =>
      '傍晚雨停了，楼下的桂花被洗得格外香。\n回家路上买了一袋糖炒栗子，边走边剥，手心一直是暖的。\n今天没有什么大事，但每一刻都很踏实，想把它记下来。';

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
    return '更新于 $time';
  }

  @override
  String diaryCardFooterCreated(String time) {
    return '写于 $time';
  }

  @override
  String diaryCardWordCount(String count) {
    return '$count 字';
  }

  @override
  String diaryCardMediaImages(int count) {
    return '$count 张图片';
  }

  @override
  String get diaryCardMediaAudio => '含录音';

  @override
  String get diaryCardMediaVideo => '含视频';

  @override
  String get diaryCardMediaAttachment => '含附件';

  @override
  String diaryCardLocation(String location) {
    return '地点：$location';
  }

  @override
  String get diaryCardStyleTitle => '日记卡片样式';

  @override
  String diaryCardStyleEntrySubtitle(String name) {
    return '当前：$name';
  }

  @override
  String get styleEditorCustom => '自定义';

  @override
  String get styleEditorResetDone => '已恢复默认样式';

  @override
  String get styleEditorPreviewLight => '浅色预览';

  @override
  String get styleEditorPreviewDark => '深色预览';

  @override
  String get styleEditorPanelHandle => '选项面板';

  @override
  String get styleEditorPanelCollapsed => '已收起';

  @override
  String get styleEditorPanelHalf => '半展开';

  @override
  String get styleEditorPanelExpanded => '已展开';

  @override
  String get diaryCardStyleSharedGroup => '所有布局';

  @override
  String get diaryCardStyleListGroup => '列表专属';

  @override
  String get diaryCardStyleWaterfallGroup => '瀑布流专属';

  @override
  String get diaryCardStyleModeFootnote => '在预览上方切换列表或瀑布流，即可调整另一种布局';

  @override
  String get diaryCardStyleTabPresets => '预设';

  @override
  String get diaryCardStyleTabLayout => '布局';

  @override
  String get diaryCardStyleTabCover => '封面';

  @override
  String get diaryCardStyleTabContent => '内容';

  @override
  String get diaryCardStyleTabDate => '日期';

  @override
  String get diaryCardStyleTabOrder => '排序';

  @override
  String get diaryCardStyleTabText => '字体';

  @override
  String get diaryCardStyleTabColor => '色彩';

  @override
  String get diaryCardStyleTabTexture => '质感';

  @override
  String get styleEditorPresetsTitle => '内置风格';

  @override
  String get diaryCardStylePresetClassic => '经典';

  @override
  String get diaryCardStylePresetClassicDesc => '默认样式：左侧方图、两行摘要';

  @override
  String get diaryCardStylePresetCompact => '紧凑';

  @override
  String get diaryCardStylePresetCompactDesc => '小封面、单行摘要，一屏看到更多';

  @override
  String get diaryCardStylePresetMagazine => '杂志';

  @override
  String get diaryCardStylePresetMagazineDesc => '通栏大图、大标题与宽松行距';

  @override
  String get diaryCardStylePresetMinimal => '极简';

  @override
  String get diaryCardStylePresetMinimalDesc => '只留文字，没有封面、描边与阴影';

  @override
  String get diaryCardStylePresetGallery => '画廊';

  @override
  String get diaryCardStylePresetGalleryDesc => '照片优先：多图拼贴与封面背景';

  @override
  String get diaryCardStylePresetSticky => '便签';

  @override
  String get diaryCardStylePresetStickyDesc => '暖黄纸面、顶部色条与小圆角';

  @override
  String get diaryCardStylePresetJournal => '手账';

  @override
  String get diaryCardStylePresetJournalDesc => '侧边色条，没有封面时显示日期块';

  @override
  String get diaryCardStylePresetMood => '心情色';

  @override
  String get diaryCardStylePresetMoodDesc => '卡片底色与描边随当天心情变化';

  @override
  String get diaryCardStylePresetGlass => '玻璃';

  @override
  String get diaryCardStylePresetGlassDesc => '半透明磨砂卡片，透出页面背景图';

  @override
  String get diaryCardStyleMaterial => '材质';

  @override
  String get diaryCardStyleMaterialSolid => '实色';

  @override
  String get diaryCardStyleMaterialGlass => '玻璃';

  @override
  String get diaryCardStyleBlur => '模糊';

  @override
  String get diaryCardStyleBlurSubtitle => '页面设置了背景图时才有模糊效果';

  @override
  String styleEditorApplied(String name) {
    return '已套用「$name」';
  }

  @override
  String get styleEditorSavedTitle => '我的样式';

  @override
  String get styleEditorSavedEmpty => '把调好的样式保存下来，随时一键切换';

  @override
  String get styleEditorSaveCurrent => '保存当前样式';

  @override
  String styleEditorSaveLimit(int count) {
    return '最多保存 $count 个样式';
  }

  @override
  String get styleEditorSaveDialogTitle => '保存样式';

  @override
  String get styleEditorRenameDialogTitle => '重命名样式';

  @override
  String get styleEditorNameLabel => '样式名称';

  @override
  String styleEditorDefaultName(int count) {
    return '我的样式 $count';
  }

  @override
  String get styleEditorRename => '重命名';

  @override
  String styleEditorSavedDone(String name) {
    return '已保存「$name」';
  }

  @override
  String styleEditorDeletedDone(String name) {
    return '已删除「$name」';
  }

  @override
  String styleEditorSavedActions(String name) {
    return '「$name」的更多操作';
  }

  @override
  String get styleEditorShareTitle => '分享与导入';

  @override
  String get styleEditorCopyCode => '复制样式码';

  @override
  String get styleEditorCopyCodeSubtitle => '发给朋友，或留作这套样式的备份';

  @override
  String get styleEditorImportCode => '从剪贴板导入';

  @override
  String get styleEditorImportCodeSubtitle => '套用别人分享的样式码';

  @override
  String get styleEditorCodeCopied => '样式码已复制';

  @override
  String get styleEditorImportEmpty => '剪贴板是空的';

  @override
  String get styleEditorImportInvalid => '剪贴板里没有可用的样式码';

  @override
  String get styleEditorImportNewer => '已导入，部分来自新版本的设置可能未生效';

  @override
  String get styleEditorImported => '已导入样式';

  @override
  String styleEditorImportedNamed(String name) {
    return '已导入「$name」';
  }

  @override
  String get diaryCardStyleCornerRadius => '卡片圆角';

  @override
  String get diaryCardStyleTextAlign => '文字对齐';

  @override
  String get diaryCardStyleAlignStart => '居左';

  @override
  String get diaryCardStyleAlignCenter => '居中';

  @override
  String get diaryCardStylePaddingH => '左右内边距';

  @override
  String get diaryCardStylePaddingV => '上下内边距';

  @override
  String get diaryCardStyleElementGap => '内容间距';

  @override
  String get diaryCardStyleCardGap => '卡片间距';

  @override
  String get diaryCardStyleSideMargin => '屏幕边距';

  @override
  String get diaryCardStyleColumns => '列数';

  @override
  String diaryCardStyleColumnsValue(int count) {
    return '$count 列';
  }

  @override
  String get diaryCardStyleColumnsFootnote => '屏幕较窄或字号较大时会自动减少列数';

  @override
  String get diaryCardStyleCoverPosition => '封面位置';

  @override
  String get diaryCardStyleCoverStart => '左侧';

  @override
  String get diaryCardStyleCoverEnd => '右侧';

  @override
  String get diaryCardStyleCoverTop => '顶部';

  @override
  String get diaryCardStyleCoverBackground => '背景';

  @override
  String get diaryCardStyleCoverHidden => '隐藏';

  @override
  String get diaryCardStyleCoverSize => '封面大小';

  @override
  String get diaryCardStyleCoverSizeFootnote => '窄屏上封面会自动缩小，给文字留出空间';

  @override
  String get diaryCardStyleCoverShape => '封面形状';

  @override
  String get diaryCardStyleShapeSquare => '方形';

  @override
  String get diaryCardStyleShapeLandscape => '横向';

  @override
  String get diaryCardStyleShapePortrait => '竖向';

  @override
  String get diaryCardStyleShapeCircle => '圆形';

  @override
  String get diaryCardStyleCoverRadius => '封面圆角';

  @override
  String get diaryCardStyleCoverHeight => '封面高度';

  @override
  String get diaryCardStyleCoverInset => '内缩封面';

  @override
  String get diaryCardStyleCoverInsetSubtitle => '封面留出边距并带圆角，而不是贴边通栏';

  @override
  String get diaryCardStyleCoverDivider => '封面下的分隔线';

  @override
  String get diaryCardStyleCoverGap => '封面与文字的间距';

  @override
  String get diaryCardStyleScrim => '文字底板浓度';

  @override
  String get diaryCardStyleCollage => '多图拼贴';

  @override
  String get diaryCardStyleCollageSubtitle => '顶部封面最多拼入三张正文图片';

  @override
  String get diaryCardStyleCoverFallback => '没有封面时';

  @override
  String get diaryCardStyleFallbackNone => '留空';

  @override
  String get diaryCardStyleFallbackDate => '日期块';

  @override
  String get diaryCardStyleFallbackMood => '心情块';

  @override
  String get diaryCardStyleShowTitle => '显示标题';

  @override
  String get diaryCardStyleShowUntitled => '没有标题时用正文第一行作标题';

  @override
  String get diaryCardStyleShowUntitledSubtitle => '关闭后直接省略标题行';

  @override
  String get diaryCardStyleShowPreview => '显示摘要';

  @override
  String get diaryCardStyleTitleLines => '标题最多行数';

  @override
  String get diaryCardStylePreviewLines => '摘要最多行数';

  @override
  String diaryCardStyleLinesValue(int count) {
    return '$count 行';
  }

  @override
  String get diaryCardStyleTagStyle => '标签样式';

  @override
  String get diaryCardStyleTagChip => '胶囊';

  @override
  String get diaryCardStyleTagPlain => '文字';

  @override
  String get diaryCardStyleTagDot => '圆点';

  @override
  String get diaryCardStylePinnedBadge => '置顶标记';

  @override
  String get diaryCardStylePinnedStandard => '图标和文字';

  @override
  String get diaryCardStylePinnedIcon => '仅图标';

  @override
  String get diaryCardStylePinnedHidden => '不显示';

  @override
  String get diaryCardStylePinnedTint => '置顶卡片着色';

  @override
  String get diaryCardStylePinnedTintSubtitle => '淡淡的主题色底色与描边';

  @override
  String get diaryCardStyleShowMood => '显示心情';

  @override
  String get diaryCardStyleShowWeather => '显示天气';

  @override
  String get diaryCardStyleIndicatorStyle => '心情与天气';

  @override
  String get diaryCardStyleIndicatorStamp => '印章';

  @override
  String get diaryCardStyleIndicatorPlain => '仅图标';

  @override
  String get diaryCardStyleMetaPosition => '心情与天气位置';

  @override
  String get diaryCardStyleMetaEyebrow => '日期行';

  @override
  String get diaryCardStyleMetaFooter => '底栏';

  @override
  String get diaryCardStyleMetaCover => '封面上';

  @override
  String get diaryCardStyleExtras => '底栏附加信息';

  @override
  String get diaryCardStyleShowLocation => '地点';

  @override
  String get diaryCardStyleShowEnergy => '精力';

  @override
  String get diaryCardStyleShowWordCount => '字数';

  @override
  String get diaryCardStyleShowMedia => '图片与附件标记';

  @override
  String get diaryCardStyleShowDate => '显示日期';

  @override
  String get diaryCardStyleDateFormat => '日期格式';

  @override
  String get diaryCardStyleDateEyebrow => '月日';

  @override
  String get diaryCardStyleDateFull => '完整日期';

  @override
  String get diaryCardStyleDateNumeric => '数字日期';

  @override
  String get diaryCardStyleDateRelative => '相对时间';

  @override
  String get diaryCardStyleShowWeekday => '显示星期';

  @override
  String get diaryCardStyleShowTime => '显示时刻';

  @override
  String get diaryCardStyleRelativeNote => '相对时间不附带星期与时刻';

  @override
  String get diaryCardStyleDateSource => '日期依据';

  @override
  String get diaryCardStyleDateCreated => '写下的时间';

  @override
  String get diaryCardStyleDateUpdated => '最后修改';

  @override
  String get diaryCardStyleFooterTime => '底栏时间';

  @override
  String get diaryCardStyleFooterRelative => '多久前更新';

  @override
  String get diaryCardStyleFooterUpdated => '更新时间';

  @override
  String get diaryCardStyleFooterCreated => '写下时间';

  @override
  String get diaryCardStyleFooterHidden => '不显示';

  @override
  String get diaryCardStyleOrderHint => '拖动右侧手柄，调整卡片里各部分的上下顺序';

  @override
  String get diaryCardStyleBlockEyebrow => '日期行';

  @override
  String get diaryCardStyleBlockTitle => '标题';

  @override
  String get diaryCardStyleBlockTags => '标签';

  @override
  String get diaryCardStyleBlockPreview => '摘要';

  @override
  String get diaryCardStyleBlockFooter => '底栏';

  @override
  String get diaryCardStyleOrderReset => '恢复默认顺序';

  @override
  String diaryCardStyleDragHandle(String name) {
    return '拖动调整「$name」的位置';
  }

  @override
  String get diaryCardStyleTitleSize => '标题字号';

  @override
  String get diaryCardStyleTitleWeight => '标题字重';

  @override
  String get diaryCardStyleWeightRegular => '常规';

  @override
  String get diaryCardStyleWeightMedium => '中等';

  @override
  String get diaryCardStyleWeightBold => '粗体';

  @override
  String get diaryCardStylePreviewSize => '摘要字号';

  @override
  String get diaryCardStyleLineHeight => '摘要行距';

  @override
  String get diaryCardStyleLineCompact => '紧凑';

  @override
  String get diaryCardStyleLineStandard => '标准';

  @override
  String get diaryCardStyleLineRelaxed => '宽松';

  @override
  String get diaryCardStyleMetaSize => '辅助文字大小';

  @override
  String get diaryCardStyleTitleColor => '标题颜色';

  @override
  String get diaryCardStyleBodyColor => '正文颜色';

  @override
  String get diaryCardStyleEnsureContrast => '自动保证可读';

  @override
  String get diaryCardStyleEnsureContrastSubtitle => '文字颜色与卡片底色太接近时，自动换成清晰的颜色';

  @override
  String get diaryCardStyleBackground => '卡片底色';

  @override
  String get diaryCardStyleOpacity => '卡片不透明度';

  @override
  String get diaryCardStyleGradient => '渐变底色';

  @override
  String get diaryCardStyleGradientSubtitle => '从卡片底色过渡到第二种颜色';

  @override
  String get diaryCardStyleGradientEnd => '渐变的第二种颜色';

  @override
  String get diaryCardStyleGradientDirection => '渐变方向';

  @override
  String get diaryCardStyleDirectionVertical => '竖向';

  @override
  String get diaryCardStyleDirectionHorizontal => '横向';

  @override
  String get diaryCardStyleDirectionDiagonal => '斜向';

  @override
  String get diaryCardStyleBorderWidth => '描边粗细';

  @override
  String get diaryCardStyleBorderColor => '描边颜色';

  @override
  String get diaryCardStyleAccentBar => '强调色条';

  @override
  String get diaryCardStyleAccentNone => '无';

  @override
  String get diaryCardStyleAccentStart => '侧边';

  @override
  String get diaryCardStyleAccentTop => '顶部';

  @override
  String get diaryCardStyleAccentWidth => '色条宽度';

  @override
  String get diaryCardStyleAccentColor => '色条颜色';

  @override
  String get diaryCardStyleShadow => '阴影';

  @override
  String get diaryCardStyleShadowThemed => '默认';

  @override
  String get diaryCardStyleShadowNone => '无';

  @override
  String get diaryCardStyleShadowSoft => '柔和';

  @override
  String get diaryCardStyleShadowFloating => '悬浮';

  @override
  String get diaryCardStyleShadowCustom => '自定义';

  @override
  String get diaryCardStyleShadowElevation => '阴影高度';

  @override
  String get diaryCardStyleShadowColor => '阴影颜色';

  @override
  String get diaryCardStyleSourceTheme => '默认';

  @override
  String get diaryCardStyleSourcePrimary => '主色';

  @override
  String get diaryCardStyleSourceSecondary => '次色';

  @override
  String get diaryCardStyleSourceTertiary => '第三色';

  @override
  String get diaryCardStyleSourceMood => '心情';

  @override
  String get diaryCardStyleSourceTag => '首个标签';

  @override
  String get diaryCardStyleSourceCustom => '自定义';

  @override
  String get diaryCardStyleSourceMoodHint =>
      '按每篇日记的心情取色（颜色可在“心情符号”里修改）；没有心情时用默认颜色';

  @override
  String get diaryCardStyleSourceTagHint => '取每篇日记第一个标签的颜色';

  @override
  String get diaryCardStyleStrength => '浓度';

  @override
  String get styleEditorEditColor => '编辑颜色';

  @override
  String get styleEditorColorDarkAuto => '深色模式自动配色';

  @override
  String get styleEditorColorDarkAutoSubtitle => '按浅色值推导出暗色下易读的颜色';

  @override
  String get styleEditorHexLabel => 'HEX 颜色';

  @override
  String get styleEditorHexInvalid => '请输入 6 位十六进制颜色，如 FFB300';

  @override
  String get diaryCardStyleSheetSection => '卡片样式';

  @override
  String get diaryCardStyleSampleTitle1 => '海边的黄昏';

  @override
  String get diaryCardStyleSampleBody1 => '傍晚沿着海岸走了很久，浪声一阵一阵，天色从橙色慢慢变成淡紫。';

  @override
  String get diaryCardStyleSampleTitle2 => '周末去爬山';

  @override
  String get diaryCardStyleSampleBody2 => '山顶风很大，拍了好多照片，还录下了一段风声。下山时腿已经开始发软。';

  @override
  String get diaryCardStyleSampleTitle3 => '一个下雨的工作日，在咖啡馆里重新整理了这周的计划';

  @override
  String get diaryCardStyleSampleBody3 => '把这周要做的事重新排了一遍，顺手记下几个想法。晚上早点休息。';

  @override
  String get diaryCardStyleSampleBody4 =>
      '下班路上看见一只橘猫趴在台阶上晒太阳，眯着眼睛的样子让人也跟着放松下来。';

  @override
  String get diaryCardStyleSampleLead4 => '台阶上的橘猫';

  @override
  String get diaryCardStyleSampleCapsuleTitle => '写给一年后的自己';

  @override
  String get diaryCardStyleSampleTag1 => '旅行';

  @override
  String get diaryCardStyleSampleTag2 => '生活';

  @override
  String get diaryCardStyleSampleTag3 => '读书';

  @override
  String get diaryCardStyleSampleLocation => '海边栈道';

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
    return '$formatted 字';
  }

  @override
  String diaryPreviewReadingTime(int minutes) {
    return '约 $minutes 分钟';
  }

  @override
  String get diaryWordCountOpen => '查看字数统计';

  @override
  String get diaryWordCountTitle => '字数统计';

  @override
  String diaryWordCountUnit(int count) {
    return '字';
  }

  @override
  String get diaryWordCountCjk => '中文字符';

  @override
  String get diaryWordCountLatin => '非中文单词';

  @override
  String get diaryWordCountCharacters => '字符数（不计空格）';

  @override
  String get diaryWordCountCharactersWithSpaces => '字符数（计空格）';

  @override
  String get diaryWordCountParagraphs => '段落';

  @override
  String get diaryWordCountImages => '图片';

  @override
  String get diaryWordCountRecordings => '录音';

  @override
  String get diaryWordCountVideos => '视频';

  @override
  String get diaryWordCountAttachments => '附件';

  @override
  String get diaryWordCountReading => '预计阅读';

  @override
  String get diaryWordCountRule => '每个汉字与全角标点算 1 字，英文和数字按单词计，空格与换行不计。';

  @override
  String get diaryPreviewUpdatedPrefix => '更新于';

  @override
  String get diaryPreviewBackToTop => '回到顶部';

  @override
  String get diaryPreviewStyleTitle => '日记预览页';

  @override
  String diaryPreviewStyleEntrySubtitle(String name) {
    return '当前：$name';
  }

  @override
  String get diaryPreviewStyleMoreEntry => '页面样式';

  @override
  String get diaryPreviewStyleTabPresets => '预设';

  @override
  String get diaryPreviewStyleTabPage => '页面';

  @override
  String get diaryPreviewStyleTabCover => '头图';

  @override
  String get diaryPreviewStyleTabTitle => '标题';

  @override
  String get diaryPreviewStyleTabMeta => '信息';

  @override
  String get diaryPreviewStyleTabBody => '正文';

  @override
  String get diaryPreviewStylePresetClassic => '经典';

  @override
  String get diaryPreviewStylePresetClassicDesc => '改版前的样子';

  @override
  String get diaryPreviewStylePresetPaper => '纸书';

  @override
  String get diaryPreviewStylePresetPaperDesc => '暖白纸、居中标题与内嵌头图';

  @override
  String get diaryPreviewStylePresetMagazine => '杂志';

  @override
  String get diaryPreviewStylePresetMagazineDesc => '高大的头图、放大的标题，日期在上';

  @override
  String get diaryPreviewStylePresetMinimal => '极简';

  @override
  String get diaryPreviewStylePresetMinimalDesc => '不要头图，只留必要的信息';

  @override
  String get diaryPreviewStylePresetNight => '夜读';

  @override
  String get diaryPreviewStylePresetNightDesc => '墨色纸张与阅读进度线';

  @override
  String get diaryPreviewStylePresetJournal => '手账';

  @override
  String get diaryPreviewStylePresetJournalDesc => '按心情着色，信息收进卡片';

  @override
  String get diaryPreviewStylePresetMood => '心情色';

  @override
  String get diaryPreviewStylePresetMoodDesc => '整页与纸张跟着这篇的心情换颜色';

  @override
  String get diaryPreviewStylePresetImmersive => '沉浸';

  @override
  String get diaryPreviewStylePresetImmersiveDesc => '铺满的头图、进度线与回到顶部';

  @override
  String get diaryPreviewStyleColorGroup => '配色';

  @override
  String get diaryPreviewStyleColorSeed => '配色基调';

  @override
  String get diaryPreviewStyleSeedApp => '跟随应用';

  @override
  String get diaryPreviewStyleSeedMood => '心情';

  @override
  String get diaryPreviewStyleSeedTag => '首个标签';

  @override
  String get diaryPreviewStyleSeedCustom => '自定义';

  @override
  String get diaryPreviewStyleSeedColor => '基调颜色';

  @override
  String get diaryPreviewStyleSeedAppHint => '与应用主题色一致。';

  @override
  String get diaryPreviewStyleSeedMoodHint => '按这篇日记的心情取色，十种心情各有颜色。';

  @override
  String get diaryPreviewStyleSeedTagHint => '按这篇日记第一个标签的颜色。';

  @override
  String get diaryPreviewStyleSeedCustomHint => '每篇日记都用同一种颜色。';

  @override
  String get diaryPreviewStyleSeedIntensity => '着色强度';

  @override
  String get diaryPreviewStyleSeedIntensityHint =>
      '柔和与应用主题一样克制；原色贴近颜色本身的浓淡；鲜明最饱和。';

  @override
  String get diaryPreviewStyleSeedIntensitySoft => '柔和';

  @override
  String get diaryPreviewStyleSeedIntensityOriginal => '原色';

  @override
  String get diaryPreviewStyleSeedIntensityVivid => '鲜明';

  @override
  String get diaryPreviewStyleSeedFallback => '取不到颜色时';

  @override
  String get diaryPreviewStyleSeedFallbackHint => '没选心情或没有标签的日记用哪种配色。';

  @override
  String get diaryPreviewStyleSeedFallbackApp => '跟随应用';

  @override
  String get diaryPreviewStyleSeedFallbackNeutral => '中性灰';

  @override
  String get diaryPreviewStyleTintPaper => '纸张随基调染色';

  @override
  String get diaryPreviewStyleTintPaperHint => '页面底色带上一层淡淡的基调色';

  @override
  String get diaryPreviewStyleTintScrim => '背景遮罩随基调染色';

  @override
  String get diaryPreviewStyleTintScrimHint =>
      '有背景图片时，遮罩带上这篇的基调色（如心情颜色），深浅仍按背景与材质里的遮罩';

  @override
  String get diaryPreviewStyleMoodColors => '心情颜色';

  @override
  String get diaryPreviewStyleMoodColorsHint => '在“心情符号”里为每种心情换颜色';

  @override
  String get diaryPreviewStylePreviewMood => '预览心情';

  @override
  String get diaryPreviewStylePreviewMoodHint => '只换上方预览里示例的心情，看看每种心情的样子';

  @override
  String get diaryPreviewStylePreviewMoodSample => '按示例';

  @override
  String get diaryPreviewStylePaper => '纸张';

  @override
  String get diaryPreviewStylePaperTheme => '主题';

  @override
  String get diaryPreviewStylePaperWarm => '暖白';

  @override
  String get diaryPreviewStylePaperSepia => '米黄';

  @override
  String get diaryPreviewStylePaperMint => '护眼绿';

  @override
  String get diaryPreviewStylePaperGray => '浅灰';

  @override
  String get diaryPreviewStylePaperInk => '墨色';

  @override
  String get diaryPreviewStylePaperCustom => '自定义';

  @override
  String get diaryPreviewStylePaperColor => '纸张颜色';

  @override
  String get diaryPreviewStylePaperHint => '纸色与主题深浅相反时，整页换成相应的明暗，文字始终清楚。';

  @override
  String get diaryPreviewStyleTextColor => '自定义正文颜色';

  @override
  String get diaryPreviewStyleTextColorHint => '和纸张对比度不足时自动改用默认颜色。';

  @override
  String get diaryPreviewStyleLayoutGroup => '版式';

  @override
  String get diaryPreviewStylePadding => '左右边距';

  @override
  String get diaryPreviewStyleLimitWidth => '限制正文宽度';

  @override
  String get diaryPreviewStyleLimitWidthSubtitle => '平板和横屏时居中排版';

  @override
  String get diaryPreviewStyleContentWidth => '正文最大宽度';

  @override
  String get diaryPreviewStyleTopBarGroup => '顶栏';

  @override
  String get diaryPreviewStyleTopBarFloating => '随滚动隐藏';

  @override
  String get diaryPreviewStyleTopBarPinned => '固定';

  @override
  String get diaryPreviewStyleTopBarTitle => '标题';

  @override
  String get diaryPreviewStyleTopBarTitleDate => '日期';

  @override
  String get diaryPreviewStyleTopBarTitleNone => '不显示';

  @override
  String get diaryPreviewStyleShowTypographyButton => '字体与排版按钮';

  @override
  String get diaryPreviewStyleShowEditButton => '编辑按钮';

  @override
  String get diaryPreviewStyleShowShareButton => '分享按钮';

  @override
  String get diaryPreviewStyleReadingGroup => '阅读辅助';

  @override
  String get diaryPreviewStyleProgress => '阅读进度线';

  @override
  String get diaryPreviewStyleProgressSubtitle => '页面顶端的细线随阅读增长';

  @override
  String get diaryPreviewStyleBackToTop => '回到顶部按钮';

  @override
  String get diaryPreviewStyleBackToTopSubtitle => '滚过一屏半后出现';

  @override
  String get diaryPreviewStyleCoverMode => '显示方式';

  @override
  String get diaryPreviewStyleCoverBanner => '通栏';

  @override
  String get diaryPreviewStyleCoverInset => '内嵌';

  @override
  String get diaryPreviewStyleCoverHidden => '不显示';

  @override
  String get diaryPreviewStyleCoverFit => '适配';

  @override
  String get diaryPreviewStyleCoverContain => '完整显示';

  @override
  String get diaryPreviewStyleCoverFill => '填满裁切';

  @override
  String get diaryPreviewStyleCoverHeight => '头图高度';

  @override
  String get diaryPreviewStyleCoverHeightHint => '头图最高为屏幕高度的七成。';

  @override
  String get diaryPreviewStyleCoverRadius => '圆角';

  @override
  String get diaryPreviewStyleCoverFade => '滚动时淡出';

  @override
  String get diaryPreviewStyleCoverFadeSubtitle => '上滑时头图逐渐变淡并轻微缩小';

  @override
  String get diaryPreviewStyleCoverFirstImage => '没有封面时用正文第一张图';

  @override
  String get diaryPreviewStyleTitleVisible => '显示标题';

  @override
  String get diaryPreviewStyleTitleUntitled => '没有标题时显示“无标题”';

  @override
  String get diaryPreviewStyleTitleUntitledSubtitle => '关闭后直接省略标题行';

  @override
  String get diaryPreviewStyleTitleScale => '标题大小';

  @override
  String get diaryPreviewStyleTitleWeight => '字重';

  @override
  String get diaryPreviewStyleWeightRegular => '常规';

  @override
  String get diaryPreviewStyleWeightMedium => '中等';

  @override
  String get diaryPreviewStyleWeightBold => '粗';

  @override
  String get diaryPreviewStyleWeightHeavy => '特粗';

  @override
  String get diaryPreviewStyleTitleAlign => '对齐';

  @override
  String get diaryPreviewStyleAlignStart => '靠左';

  @override
  String get diaryPreviewStyleAlignCenter => '居中';

  @override
  String get diaryPreviewStyleTitleColor => '自定义标题颜色';

  @override
  String get diaryPreviewStyleTitleDivider => '标题下分隔线';

  @override
  String get diaryPreviewStyleTitleDividerSubtitle => '在标题与正文之间画一条浅色细线';

  @override
  String get diaryPreviewStyleTitleBodyGap => '标题与正文间距';

  @override
  String get diaryPreviewStyleTitleBodyGapSubtitle => '开启分隔线时，线的上下各留这段距离';

  @override
  String get diaryPreviewStyleMetaPosition => '位置';

  @override
  String get diaryPreviewStyleMetaAbove => '标题上方';

  @override
  String get diaryPreviewStyleMetaBelow => '标题下方';

  @override
  String get diaryPreviewStyleMetaEnd => '正文之后';

  @override
  String get diaryPreviewStyleMetaLayout => '版式';

  @override
  String get diaryPreviewStyleMetaStacked => '分行';

  @override
  String get diaryPreviewStyleMetaInline => '单行';

  @override
  String get diaryPreviewStyleMetaCard => '信息卡';

  @override
  String get diaryPreviewStyleMetaItems => '显示的信息';

  @override
  String get diaryPreviewStyleShowDate => '时间';

  @override
  String get diaryPreviewStyleShowWordCount => '字数';

  @override
  String get diaryPreviewStyleShowReadingTime => '阅读时长';

  @override
  String get diaryPreviewStyleShowLocation => '地点';

  @override
  String get diaryPreviewStyleShowWeather => '天气';

  @override
  String get diaryPreviewStyleShowMood => '心情';

  @override
  String get diaryPreviewStyleShowEnergy => '精力';

  @override
  String get diaryPreviewStyleShowTags => '标签';

  @override
  String get diaryPreviewStyleDatePrefix => '日期前加“发表于 / 更新于”';

  @override
  String get diaryPreviewStyleChipsGroup => '胶囊';

  @override
  String get diaryPreviewStyleTagStyle => '标签';

  @override
  String get diaryPreviewStyleChipStyle => '心情与精力';

  @override
  String get diaryPreviewStyleChipChip => '胶囊';

  @override
  String get diaryPreviewStyleChipPlain => '纯文字';

  @override
  String get diaryPreviewStyleTypographyEntry => '字体与排版';

  @override
  String get diaryPreviewStyleTypographyEntrySubtitle => '与编辑页共用';

  @override
  String get diaryPreviewStyleEmptyHint => '没有正文时显示提示';

  @override
  String get diaryPreviewStyleLastEdited => '显示“最后编辑于”';

  @override
  String get diaryPreviewStyleEditedFormat => '时间格式';

  @override
  String get diaryPreviewStyleEditedPrecise => '精确';

  @override
  String get diaryPreviewStyleEditedRelative => '相对';

  @override
  String get diaryPreviewStyleEditedFull => '完整';

  @override
  String get diaryPreviewStyleCapsuleInsight => '时间胶囊解封提示';

  @override
  String get diaryPreviewStyleBehaviorGroup => '阅读行为';

  @override
  String get diaryPreviewStyleBehaviorFootnote => '预设与样式码不会改变这些设置。';

  @override
  String get diaryPreviewStyleTodoToggle => '允许勾选待办';

  @override
  String get diaryPreviewStyleTodoToggleSubtitle => '勾选后自动保存';

  @override
  String get diaryPreviewStyleTextSelection => '允许长按选择文字';

  @override
  String get diaryPreviewStyleTextSelectionSubtitle => '选择后可以复制';

  @override
  String get diaryPreviewStyleDoubleTapEdit => '双击正文进入编辑';

  @override
  String get diaryPreviewStyleDoubleTapEditSubtitle => '光标会停在双击的位置';

  @override
  String diaryPreviewStyleSampleOf(int index, int count) {
    return '示例 $index/$count';
  }

  @override
  String get diaryPreviewStyleSampleHeading => '今天的小事';

  @override
  String get diaryPreviewStyleSampleQuote => '慢慢来，比较快。';

  @override
  String get diaryPreviewStyleSampleTodo1 => '买一束花';

  @override
  String get diaryPreviewStyleSampleTodo2 => '给家里打个电话';

  @override
  String get diaryPreviewStyleSampleLong =>
      '雨停以后，街道安静下来。I sat by the window and wrote down three things I was grateful for. 窗外的梧桐叶一片一片落下，像在翻一本很旧的书。';

  @override
  String get diaryPreviewStyleSampleWeather => '晴';

  @override
  String get diaryPreviewFirstDiary => '已经是第一篇';

  @override
  String get diaryPreviewLastDiary => '已经是最后一篇';

  @override
  String get diaryPreviewPrevious => '上一篇';

  @override
  String get diaryPreviewNext => '下一篇';

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
    return '第 $index 篇，共 $count 篇';
  }

  @override
  String diaryPreviewPositionSemanticsMore(int index, int count) {
    return '第 $index 篇，至少 $count 篇';
  }

  @override
  String get diaryDetailPaneEmpty => '选一篇日记来读';

  @override
  String diaryDetailPaneCreateHint(String shortcut) {
    return '按 $shortcut 写新日记';
  }

  @override
  String get diaryPreviewStyleTabPaging => '翻页';

  @override
  String get diaryPreviewStyleSwipe => '左右滑动切换日记';

  @override
  String get diaryPreviewStyleSwipeSubtitle => '按打开时所在列表的顺序';

  @override
  String get diaryPreviewStyleSwipeSensitivity => '翻页灵敏度';

  @override
  String get diaryPreviewStyleSensitivitySensitive => '灵敏';

  @override
  String get diaryPreviewStyleSensitivityStandard => '标准';

  @override
  String get diaryPreviewStyleSensitivityStrict => '防误触';

  @override
  String get diaryPreviewStyleSensitivityHint =>
      '越往后越需要更水平的滑动才翻页；“防误触”还要拖过半屏或用力一甩。';

  @override
  String get diaryPreviewStyleHapticOnPage => '翻页时轻震';

  @override
  String get diaryPreviewStyleTransition => '翻页效果';

  @override
  String get diaryPreviewStyleTransitionSlide => '平移';

  @override
  String get diaryPreviewStyleTransitionStack => '层叠';

  @override
  String get diaryPreviewStyleTransitionFade => '淡入';

  @override
  String get diaryPreviewStyleNeighborCards => '正文末尾显示上一篇 / 下一篇';

  @override
  String get diaryPreviewStyleEdgeHint => '到头时提示';

  @override
  String get diaryPreviewStyleEdgeHintSubtitle => '已经是第一篇或最后一篇还往外拉时提示';

  @override
  String get diaryPreviewStyleTopBarTitlePosition => '位置';

  @override
  String get dataMgmtCloudBackup => '网盘备份';

  @override
  String get dataMgmtCloudBackupSubtitle => '备份到网盘、WebDAV 或对象存储，并可从远程恢复';

  @override
  String get cloudBackupTitle => '网盘备份';

  @override
  String get cloudBackupEmpty =>
      '还没有备份位置。添加一个网盘、WebDAV 或对象存储，即可把数据备份到云端，换机或重装后从那里恢复。';

  @override
  String get cloudBackupAdd => '添加备份位置';

  @override
  String get cloudBackupHint =>
      '地址、密码与网盘授权只保存在本机，不会写入备份文件。“备份”是增量的：只上传新增与变化的内容，省流量；也可以上传一份完整 ZIP，可选加密。';

  @override
  String get cloudBackupSheetTitle => '选择备份位置';

  @override
  String get cloudBackupSheetHint => '恢复前会预检备份，并让你选择合并或覆盖本机数据。';

  @override
  String get cloudBackupGroupDrives => '网盘（授权登录）';

  @override
  String get cloudBackupGroupDrivesHint => '在网盘官方页面授权，应用只能访问它自己的备份目录。';

  @override
  String get cloudBackupGroupWebDav => 'WebDAV';

  @override
  String get cloudBackupGroupWebDavHint =>
      '坚果云、NAS、Nextcloud，以及经 Alist / OpenList 挂载的阿里云盘、夸克、115 等网盘。';

  @override
  String get cloudBackupGroupS3 => '对象存储（S3 兼容）';

  @override
  String get cloudBackupGroupS3Hint => '填写访问密钥，备份保存在你指定的存储桶。';

  @override
  String get cloudBackupCustomWebDav => '其他 WebDAV';

  @override
  String get cloudBackupCustomS3 => '其他 S3 兼容存储';

  @override
  String get cloudBackupBaiduPan => '百度网盘';

  @override
  String get cloudBackupAliyunDrive => '阿里云盘';

  @override
  String get cloudBackupJianguoyun => '坚果云';

  @override
  String get cloudBackup123pan => '123云盘';

  @override
  String get cloudBackupSynology => '群晖 NAS';

  @override
  String get cloudBackupQnap => '威联通 NAS';

  @override
  String get cloudBackupAliyunOss => '阿里云 OSS';

  @override
  String get cloudBackupTencentCos => '腾讯云 COS';

  @override
  String get cloudBackupQiniuKodo => '七牛云 Kodo';

  @override
  String get cloudBackupHuaweiObs => '华为云 OBS';

  @override
  String get cloudBackupVolcengineTos => '火山引擎 TOS';

  @override
  String get cloudBackupBaiduBos => '百度智能云 BOS';

  @override
  String get cloudBackupJdcloudOss => '京东云 OSS';

  @override
  String get cloudBackupAwsChina => 'Amazon S3（中国区）';

  @override
  String get cloudBackupHintJianguoyun =>
      '用户名填坚果云账号；密码填网页版「账户信息 → 安全选项 → 第三方应用管理」中生成的应用密码。免费账户每 30 分钟限 600 次请求。';

  @override
  String get cloudBackupHint123pan =>
      '地址与密码照抄 123云盘「工具中心 → 第三方挂载」页面显示的内容（密码只显示一次）。';

  @override
  String get cloudBackupHintOpenList =>
      '填写 Alist / OpenList 的地址（默认端口 5244，路径 /dav/），并在后台为该用户开启 WebDAV 读取与管理权限。经它挂载的各类网盘都可作为备份位置。';

  @override
  String get cloudBackupHintCloudDrive2 =>
      '填写 CloudDrive2 的地址（默认端口 19798，路径 /dav）与登录账号。';

  @override
  String get cloudBackupHintNextcloud =>
      '地址从网页版「文件设置 → WebDAV」复制；密码建议使用「个人设置 → 安全」中生成的应用密码。';

  @override
  String get cloudBackupHintOwncloud => '密码建议使用应用令牌；oCIS 需管理员开启应用令牌服务。';

  @override
  String get cloudBackupHintSeafile =>
      '需服务器开启 SeafDAV；使用单点登录的账号需在网页设置单独的 WebDAV 密码。';

  @override
  String get cloudBackupHintSynology =>
      '在 DSM 套件中心安装并启用 WebDAV Server（HTTPS 默认端口 5006），用 DSM 账号登录；远程目录的第一级须是共享文件夹。';

  @override
  String get cloudBackupHintQnap => '在控制台开启 WebDAV，地址末尾带上共享文件夹名称。';

  @override
  String get cloudBackupHintKoofr =>
      '必须使用 Koofr「设置 → 密码」中生成的应用密码；多次登录失败会被暂时封禁。';

  @override
  String get cloudBackupHintPcloud => '用 pCloud 账号邮箱与密码登录；欧洲区账号请选 pCloud (EU)。';

  @override
  String get cloudBackupHintInfinicloud =>
      '地址与 Apps Connection 密码从 InfiniCLOUD 的 My Page 复制。';

  @override
  String get cloudBackupHintHetzner =>
      '需在 Hetzner Console 为 Storage Box 开启 WebDAV 与外部访问。';

  @override
  String get cloudBackupHintKdrive =>
      '地址中的 Drive ID 见 kDrive 网页地址；开启了两步验证时需使用应用密码。';

  @override
  String get cloudBackupHintYandex => '需要付费的 Yandex 360，并使用类型为 WebDAV 的应用密码。';

  @override
  String get cloudBackupHintMailru => '需要使用 Mail.ru 账户设置中生成的应用密码。';

  @override
  String get cloudBackupS3Hint => '端点与区域需与存储桶所在地域一致。建议为备份单独创建存储桶，并使用只能访问该桶的密钥。';

  @override
  String get cloudBackupHintAliyunOss =>
      '使用 RAM 用户的 AccessKey；端点中的地域需与存储桶一致。2025 年 3 月后新开通的账号在中国内地可能无法用默认公网域名访问。';

  @override
  String get cloudBackupHintTencentCos =>
      '存储桶名称须带 APPID 后缀（如 backup-1250000000），密钥在「访问管理 → API 密钥」创建。';

  @override
  String get cloudBackupHintQiniuKodo => 'S3 访问用的存储桶名称可能与空间名不同，以控制台显示为准。';

  @override
  String get cloudBackupHintR2 =>
      '把地址中的 ACCOUNT_ID 换成 Cloudflare 账户 ID，并在 R2「管理 API 令牌」中创建令牌，使用其 S3 访问密钥；区域保持 auto。';

  @override
  String get cloudBackupHintB2 =>
      '端点以存储桶详情页显示的为准，区域填端点中的部分（如 us-west-004），密钥使用 Application Key。';

  @override
  String get cloudBackupHintDigitalOcean =>
      '端点中的区域填 Spaces 所在数据中心（如 nyc3），签名区域保持 us-east-1。';

  @override
  String get cloudBackupHintMinio => '填写 MinIO 的 API 地址（默认端口 9000），保持开启路径风格访问。';

  @override
  String get cloudBackupHintGcs => '在 Cloud Storage「设置 → 互操作性」中创建 HMAC 密钥。';

  @override
  String get cloudBackupHintOracle =>
      '端点中的 NAMESPACE 与 REGION 见 OCI 控制台，密钥使用「客户密钥（Customer Secret Key）」。';

  @override
  String get cloudBackupFolderGoogleDrive =>
      '备份保存在 Google Drive 的「Jotsy」文件夹；应用只能访问它自己创建的文件。删除的备份不进回收站。';

  @override
  String get cloudBackupFolderOneDrive =>
      '备份保存在 OneDrive「应用」文件夹中的本应用目录；应用只能访问这个目录。删除的备份进入 OneDrive 回收站。';

  @override
  String get cloudBackupFolderDropbox =>
      '备份保存在 Dropbox「应用」文件夹中的本应用目录；应用只能访问这个目录。';

  @override
  String get cloudBackupFolderBaidu => '备份保存在百度网盘「我的应用数据」中的本应用目录。';

  @override
  String get cloudBackupFolderAliyun =>
      '备份保存在授权时选择的文件夹（未选择时为根目录的「Jotsy」），删除的备份进入回收站。授权有效期以阿里云盘为准，到期后需重新授权。';

  @override
  String get cloudBackupConfigSection => '连接配置';

  @override
  String get cloudBackupSaveConfig => '保存配置';

  @override
  String get cloudBackupTestConnection => '测试连接';

  @override
  String get cloudBackupUploadBackup => '上传完整 ZIP';

  @override
  String get cloudBackupRefreshBackups => '刷新列表';

  @override
  String get cloudBackupBackupList => '远程备份';

  @override
  String get cloudBackupNoBackups => '暂无远程备份';

  @override
  String cloudBackupBackupTime(String time) {
    return '时间：$time';
  }

  @override
  String cloudBackupBackupSize(String size) {
    return '大小：$size';
  }

  @override
  String get cloudBackupRestoreAction => '恢复';

  @override
  String get cloudBackupDeleteAction => '删除';

  @override
  String get cloudBackupDeleteConfirmTitle => '删除远程备份？';

  @override
  String cloudBackupDeleteConfirmContent(String fileName) {
    return '将从备份位置删除 $fileName，此操作不可撤销。';
  }

  @override
  String get cloudBackupRemoveTarget => '移除此备份位置';

  @override
  String get cloudBackupRemoveTargetTitle => '移除备份位置？';

  @override
  String get cloudBackupRemoveTargetContent =>
      '只清除本机保存的连接信息与授权，备份位置里已有的备份文件不会被删除，之后可以重新添加。';

  @override
  String get cloudBackupRemoveTargetAction => '移除';

  @override
  String get cloudBackupRemoved => '已移除备份位置';

  @override
  String get cloudBackupConfigSaved => '配置已保存';

  @override
  String get cloudBackupConnectionOk => '连接成功';

  @override
  String get cloudBackupUploadSuccess => '备份已上传';

  @override
  String get cloudBackupRestoreSuccess => '已从远程备份恢复数据';

  @override
  String get cloudBackupDeleteSuccess => '远程备份已删除';

  @override
  String get cloudBackupAccountAuthorized => '已授权';

  @override
  String cloudBackupAccountConnected(String account) {
    return '已授权：$account';
  }

  @override
  String get cloudBackupReauthorize => '重新授权';

  @override
  String cloudBackupAuthorized(String name) {
    return '已连接 $name';
  }

  @override
  String cloudBackupAuthorizeTitle(String name) {
    return '授权 $name';
  }

  @override
  String get cloudBackupDeviceCodeHint => '打开授权页面，登录后输入下方代码。授权完成后这里会自动继续。';

  @override
  String get cloudBackupDeviceCodeLabel => '授权代码';

  @override
  String get cloudBackupCopyCode => '复制代码';

  @override
  String get cloudBackupDeviceCodeCopied => '已复制';

  @override
  String get cloudBackupOpenAuthorizePage => '打开授权页面';

  @override
  String get cloudBackupWaitingAuthorization => '等待授权完成…';

  @override
  String get cloudBackupCodePasteHint => '在浏览器中授权后，页面会显示一串授权码，复制后粘贴到这里。';

  @override
  String get cloudBackupCodeLabel => '授权码';

  @override
  String get cloudBackupCodeConfirm => '完成授权';

  @override
  String get cloudBackupBusyLabel => '网盘备份进行中';

  @override
  String get cloudBackupBusySave => '正在保存…';

  @override
  String get cloudBackupBusyTest => '正在测试连接…';

  @override
  String get cloudBackupBusyUpload => '正在生成备份…';

  @override
  String cloudBackupBusyUploadProgress(int percent) {
    return '正在上传 $percent%';
  }

  @override
  String get cloudBackupBusyDownload => '正在下载备份…';

  @override
  String cloudBackupBusyDownloadProgress(int percent) {
    return '正在下载 $percent%';
  }

  @override
  String get cloudBackupBusyRestore => '正在恢复数据…';

  @override
  String get cloudBackupBusyRefresh => '正在读取远程备份…';

  @override
  String get cloudBackupBusyDelete => '正在删除远程备份…';

  @override
  String get cloudBackupBusyAuthorize => '正在验证授权…';

  @override
  String cloudBackupOperationFailed(String detail) {
    return '操作失败：$detail';
  }

  @override
  String get cloudBackupErrorConfig => '请检查地址、存储桶、目录等配置是否完整正确';

  @override
  String get cloudBackupErrorAppKeyMissing => '此版本没有配置该网盘的应用密钥，暂不可用';

  @override
  String get cloudBackupErrorAuth => '认证失败或无权访问，请检查账号、密码或密钥';

  @override
  String get cloudBackupErrorSessionExpired => '授权已失效，请重新授权';

  @override
  String get cloudBackupErrorAuthorizationDenied => '授权被拒绝';

  @override
  String get cloudBackupErrorAuthorizationExpired => '授权码无效或已过期，请重新获取';

  @override
  String get cloudBackupErrorNotFound => '远程文件或目录不存在';

  @override
  String get cloudBackupErrorStorageFull => '备份位置的存储空间不足';

  @override
  String get cloudBackupErrorFileTooLarge => '备份文件超过了该备份位置允许的单文件大小';

  @override
  String get cloudBackupErrorRateLimited => '请求过于频繁，请稍后再试';

  @override
  String get cloudBackupErrorNetwork => '网络请求失败，请检查网络、地址与证书';

  @override
  String get cloudBackupErrorProtocol => '备份位置返回了无法识别的响应';

  @override
  String get cloudBackupErrorPassword => '备份密码错误';

  @override
  String get cloudBackupErrorArchive => '备份文件已损坏，或不是 Jotsy 的备份';

  @override
  String get cloudBackupErrorLocalFile => '读写本地临时文件失败，请检查存储空间';

  @override
  String get cloudBackupErrorUnknown => '发生未知错误，请稍后重试';

  @override
  String get s3Endpoint => '服务地址（Endpoint）';

  @override
  String get s3EndpointHint => '例如 https://s3.us-east-1.amazonaws.com';

  @override
  String get s3Region => '区域（Region）';

  @override
  String get s3RegionHint => '留空按 us-east-1';

  @override
  String get s3Bucket => '存储桶（Bucket）';

  @override
  String get s3AccessKeyId => 'Access Key ID';

  @override
  String get s3SecretAccessKey => 'Secret Access Key';

  @override
  String get s3Prefix => '备份目录（对象前缀）';

  @override
  String get s3PrefixHint => '例如 jotsy/，留空为存储桶根目录';

  @override
  String get s3PathStyle => '路径风格访问';

  @override
  String get s3PathStyleSubtitle => 'MinIO 等自建服务通常需要开启';

  @override
  String get s3PathStyleLocked => '该服务只支持虚拟主机风格访问';

  @override
  String get cloudBackupErrorPlatformUnavailable =>
      '本机无法使用系统账号授权（需要 Google Play 服务），此版本也没有配置备用的授权方式';

  @override
  String get weatherInvalidHost => '和风天气服务地址配置有误，请检查 qweather.api_host';

  @override
  String get weatherNetworkError => '天气请求失败或超时，请检查网络后重试。';

  @override
  String get weatherApiError => '天气服务暂时不可用，请稍后重试。';

  @override
  String get weatherParseError => '未获取到有效天气，请稍后重试或手动填写。';

  @override
  String get publishCoverImportFailed => '这张图片无法设为封面，请换一张再试';

  @override
  String get publishTagCreateFailed => '标签创建失败，请重试';

  @override
  String get publishFailed => '发表失败，请重试';

  @override
  String get publishSucceeded => '日记已发表';

  @override
  String get publishCapsuleExpired => '解封时间已经过去，已作为普通日记发表';

  @override
  String get publishSaveFailed => '保存失败，请重试';

  @override
  String publishTimeFollowsCapsule(String time) {
    return '跟随定时锁 · $time';
  }

  @override
  String get publishCoverChange => '点击更换';

  @override
  String get publishPanelSummaryEmpty => '添加标签、心情、地点…';

  @override
  String get previewShare => '分享';

  @override
  String get diaryShareSheetTitle => '分享日记';

  @override
  String get diaryShareContentSection => '分享内容';

  @override
  String get diaryShareOptionTitle => '标题';

  @override
  String get diaryShareOptionBody => '正文';

  @override
  String get diaryShareOptionDate => '日期';

  @override
  String get diaryShareOptionMoodWeather => '心情与天气';

  @override
  String get diaryShareOptionLocation => '地点';

  @override
  String get diaryShareOptionTags => '标签';

  @override
  String get diaryShareOptionImages => '图片';

  @override
  String get diaryShareTextEmpty => '未选择文字内容，将只分享图片';

  @override
  String diaryShareImagesSelected(int selected, int total) {
    return '已选 $selected/$total 张';
  }

  @override
  String diaryShareImageLabel(int index) {
    return '第 $index 张图片';
  }

  @override
  String get diaryShareTargetsSection => '分享到';

  @override
  String get diaryShareTargetWeibo => '微博';

  @override
  String get diaryShareTargetXiaohongshu => '小红书';

  @override
  String get diaryShareTargetWechat => '微信';

  @override
  String get diaryShareTargetWechatMoments => '朋友圈';

  @override
  String get diaryShareTargetQq => 'QQ';

  @override
  String get diaryShareTargetQzone => 'QQ空间';

  @override
  String get diaryShareTargetSystem => '更多应用';

  @override
  String get diaryShareCopyText => '复制文字';

  @override
  String get diaryShareClipboardHint => '带图分享时文字会自动复制，在发布页粘贴即可。';

  @override
  String get diaryShareMoreSection => '其他方式';

  @override
  String get diaryShareLongImage => '分享为长图';

  @override
  String get diaryShareLongImageSubtitle => '按预览页的样子生成一整张图片';

  @override
  String get diaryShareLongImageToGallery => '保存长图到相册';

  @override
  String get diaryShareLongImageToGallerySubtitle => '生成同样的长图，直接存进系统相册';

  @override
  String diaryShareRequiresImage(String app) {
    return '$app需要至少一张图片';
  }

  @override
  String get diaryShareRequiresImageSeveral => '置灰的应用需要至少一张图片';

  @override
  String get diaryShareNothingSelected => '先选择要分享的内容';

  @override
  String get diaryShareInProgress => '正在准备分享';

  @override
  String diaryShareTextCopiedForApp(String app) {
    return '文字已复制，在$app里粘贴即可';
  }

  @override
  String get diaryShareTextCopied => '文字已复制，可在目标应用中粘贴';

  @override
  String get diaryShareCopied => '已复制到剪贴板';

  @override
  String diaryShareImagesTrimmed(int count) {
    return '单次最多分享 $count 张图片，超出的没有发出';
  }

  @override
  String diaryShareImagesMissing(int count) {
    return '$count 张图片读取失败，未一并分享';
  }

  @override
  String diaryShareAppUnavailable(String app) {
    return '无法打开$app，请确认已安装并更新到最新版本';
  }

  @override
  String get diaryShareNothingToShare => '没有可分享的内容';

  @override
  String diaryShareFailed(String error) {
    return '分享失败：$error';
  }

  @override
  String get previewExport => '导出';

  @override
  String get diaryExportSelected => '导出';

  @override
  String get diaryTagBatchAction => '设置标签';

  @override
  String diaryTagBatchTitle(int count) {
    return '给 $count 篇日记设置标签';
  }

  @override
  String get diaryTagBatchDone => '完成';

  @override
  String diaryTagBatchUpdated(int count) {
    return '已更新 $count 篇日记的标签';
  }

  @override
  String get diaryTagBatchFailed => '标签更新失败，请重试';

  @override
  String get dataMgmtExportDiaries => '导出日记';

  @override
  String get dataMgmtExportDiariesSubtitle =>
      '按日期或标签导出为 PDF、Word、Markdown、网页等格式';

  @override
  String get diaryExportSheetTitle => '导出日记';

  @override
  String diaryExportSheetCount(int count) {
    return '共 $count 篇';
  }

  @override
  String get diaryExportFormatSection => '格式';

  @override
  String get diaryExportOptionsSection => '选项';

  @override
  String get diaryExportFormatPdf => 'PDF';

  @override
  String get diaryExportFormatPdfDescription => '版式固定，适合阅读与打印';

  @override
  String get diaryExportFormatWord => 'Word 文档';

  @override
  String get diaryExportFormatWordDescription => '.docx，可以继续编辑与排版';

  @override
  String get diaryExportFormatMarkdown => 'Markdown';

  @override
  String get diaryExportFormatMarkdownDescription =>
      '带 front matter，可导入 Obsidian 等笔记软件，也能导回 Jotsy';

  @override
  String get diaryExportFormatHtml => '网页';

  @override
  String get diaryExportFormatHtmlDescription => '浏览器直接打开；多篇带图时打包为网页加图片文件夹';

  @override
  String get diaryExportFormatText => '纯文本';

  @override
  String get diaryExportFormatTextDescription => '.txt，任何设备都能打开';

  @override
  String get diaryExportFormatCsv => '表格（CSV）';

  @override
  String get diaryExportFormatCsvDescription => '每篇一行，含心情、天气等，可用 Excel 统计';

  @override
  String get diaryExportFormatDiaryFile => 'Jotsy 日记文件';

  @override
  String get diaryExportFormatDiaryFileDescription =>
      '完整保留日记与媒体，可设密码，导回 Jotsy 不丢信息';

  @override
  String get diaryExportIncludeImages => '包含图片';

  @override
  String get diaryExportIncludeMedia => '包含图片、录音、视频与附件';

  @override
  String get diaryExportIncludeMeta => '包含心情、天气、地点与标签';

  @override
  String get diaryExportOrderOldest => '从旧到新';

  @override
  String get diaryExportOrderNewest => '从新到旧';

  @override
  String get diaryExportSave => '保存到文件';

  @override
  String get diaryExportInProgress => '正在导出';

  @override
  String diaryExportSaved(int count) {
    return '已导出 $count 篇日记';
  }

  @override
  String diaryExportSkippedCapsules(int count) {
    return '$count 篇未解封的时间胶囊没有导出';
  }

  @override
  String get diaryExportOnlyCapsules => '选中的都是未解封的时间胶囊，没有可导出的日记';

  @override
  String get diaryExportNothing => '没有符合条件的日记';

  @override
  String get diaryExportPageTitle => '导出日记';

  @override
  String get diaryExportRangeSection => '日期范围';

  @override
  String get diaryExportRangeAll => '全部日记';

  @override
  String get diaryExportRangeThisYear => '今年';

  @override
  String get diaryExportRangeLast30Days => '最近 30 天';

  @override
  String get diaryExportRangeCustom => '自定义日期';

  @override
  String diaryExportRangeCustomValue(String start, String end) {
    return '$start 至 $end，点按修改';
  }

  @override
  String get diaryExportTagsSection => '标签';

  @override
  String get diaryExportTagsHint => '不选则不限标签；选多个时带有任一标签即可';

  @override
  String get diaryExportIncludeArchived => '包含已归档的日记';

  @override
  String diaryExportMatchCount(int count) {
    return '将导出 $count 篇日记';
  }

  @override
  String get diaryExportCapsuleNote => '未解封的时间胶囊不会导出';

  @override
  String get diaryExportNext => '选择格式并导出';

  @override
  String get diaryExportLabelUntitled => '无标题';

  @override
  String get diaryExportLabelMood => '心情';

  @override
  String get diaryExportLabelEnergy => '精力';

  @override
  String get diaryExportLabelWeather => '天气';

  @override
  String get diaryExportLabelLocation => '地点';

  @override
  String get diaryExportLabelTags => '标签';

  @override
  String get diaryExportLabelDate => '日期';

  @override
  String get diaryExportLabelTime => '时间';

  @override
  String get diaryExportLabelTitle => '标题';

  @override
  String get diaryExportLabelContent => '正文';

  @override
  String get diaryExportLabelWordCount => '字数';

  @override
  String get diaryExportLabelUpdated => '最后编辑';

  @override
  String get diaryExportLabelImage => '图片';

  @override
  String get diaryExportLabelAudio => '录音';

  @override
  String get diaryExportLabelVideo => '视频';

  @override
  String get diaryExportLabelAttachment => '附件';

  @override
  String get diaryExportLabelExportedBy => '由 Jotsy 导出';

  @override
  String diaryExportTooLarge(int size) {
    return '图片太多（约 $size MB），PDF 无法一次生成。请缩小日期范围，或关闭“包含图片”后再试';
  }

  @override
  String diaryDayPhotosTitle(int count) {
    return '这天拍的 $count 张照片';
  }

  @override
  String get diaryDayPhotosAccessTitle => '这天拍的照片';

  @override
  String get diaryDayPhotosAccessBody => '允许读取相册后，这里会列出这天拍的照片和视频，可以挑一些插进日记。';

  @override
  String get diaryDayPhotosDeniedBody => '相册权限已关闭，可以在系统设置里开启。';

  @override
  String get diaryDayPhotosAllowAccess => '允许访问';

  @override
  String get diaryDayPhotosOpenSettings => '去设置';

  @override
  String get diaryDayPhotosShowAll => '全部';

  @override
  String get diaryDayPhotosDismiss => '本次不再显示';

  @override
  String diaryDayPhotosSelected(int count) {
    return '已选 $count 张';
  }

  @override
  String get diaryDayPhotosClear => '取消选择';

  @override
  String get diaryDayPhotosInsert => '插入';

  @override
  String diaryDayPhotosInsertCount(int count) {
    return '插入 $count 张';
  }

  @override
  String get diaryDayPhotosLimited => '只显示你允许访问的照片和视频';

  @override
  String get diaryDayPhotosManageLimited => '选择更多';

  @override
  String diaryDayPhotosPhotoLabel(String time) {
    return '$time 拍的照片';
  }

  @override
  String diaryDayPhotosInsertedLabel(String time) {
    return '$time 拍的照片，已插入';
  }

  @override
  String diaryDayPhotosSheetTitle(String date) {
    return '$date 拍的照片';
  }

  @override
  String diaryDayPhotosMissing(int count) {
    return '$count 项已无法读取，没有插入';
  }

  @override
  String get settingsDayPhotoSuggestions => '自动显示当天照片';

  @override
  String get settingsDayPhotoSuggestionsSubtitle =>
      '补写过去某天的日记时，在标题下列出这天拍的照片；关闭后仍可从编辑页右上角菜单查看';

  @override
  String get settingsToolbarAlwaysVisible => '始终显示工具栏';

  @override
  String get settingsToolbarAlwaysVisibleSubtitle =>
      '收起软键盘或连接实体键盘时，工具栏仍留在编辑页底部';

  @override
  String get settingsOpenDiaryInEditor => '打开日记时直接编辑';

  @override
  String get settingsOpenDiaryInEditorSubtitle => '点开日记直接编辑，版式与预览页相同';

  @override
  String get diaryReadingEditInfo => '编辑信息';

  @override
  String get diaryReadingDone => '完成';

  @override
  String get diaryReadingReloaded => '这篇在别处改过，已换成最新内容';

  @override
  String get diaryDayPhotosSetCover => '设为封面';

  @override
  String get diaryDayPhotosClearCover => '取消封面';

  @override
  String get diaryDayPhotosCoverBadge => '封面';

  @override
  String diaryDayPhotosCoverLabel(String label) {
    return '$label，封面';
  }

  @override
  String get diaryDayPhotosCoverSet => '已设为封面，发布页里可以查看或更换';

  @override
  String get diaryDayPhotosCoverSetEdit => '已设为封面';

  @override
  String get diaryDayPhotosMenu => '这天的照片';

  @override
  String get diaryDayPhotosEmpty => '这天没有拍照片或视频';

  @override
  String diaryDayPhotosTitleVideos(int count) {
    return '这天拍的 $count 段视频';
  }

  @override
  String diaryDayPhotosTitleMixed(int photos, int videos) {
    return '这天拍的 $photos 张照片、$videos 段视频';
  }

  @override
  String diaryDayPhotosSheetTitleMedia(String date) {
    return '$date 拍的照片和视频';
  }

  @override
  String diaryDayPhotosSelectedItems(int count) {
    return '已选 $count 项';
  }

  @override
  String diaryDayPhotosInsertCountItems(int count) {
    return '插入 $count 项';
  }

  @override
  String diaryDayPhotosVideoLabel(String time, String duration) {
    return '$time 拍的视频，时长 $duration';
  }

  @override
  String diaryDayPhotosVideoInsertedLabel(String time, String duration) {
    return '$time 拍的视频，时长 $duration，已插入';
  }

  @override
  String get diaryDayPhotosVideoAccess => '还不能读取这天的视频';

  @override
  String get diaryDayPhotosSelect => '选择';

  @override
  String get diaryDayPhotosDeselect => '取消选择';

  @override
  String get diaryDayPhotosInserted => '已插入';

  @override
  String get diaryDayPhotosPreview => '预览';

  @override
  String get diaryDayPhotosPreviewFailed => '无法显示这张照片';

  @override
  String get diaryLongImageBadge => '长图';

  @override
  String get diaryImageMenuTitle => '图片';

  @override
  String get diaryImageMenuView => '查看';

  @override
  String get diaryImageMenuResize => '调整大小';

  @override
  String get diaryImageMenuThumbnail => '显示为小图';

  @override
  String get diaryImageMenuFullSize => '恢复正常显示';

  @override
  String get diaryImageMenuCopy => '复制';

  @override
  String get diaryPreviewStyleLongImage => '长图显示';

  @override
  String get diaryPreviewStyleLongImageSubtitle =>
      '高是宽 3 倍以上的图片，如长截图；折叠时点按查看全图';

  @override
  String get diaryPreviewStyleLongImageFold => '折叠';

  @override
  String get diaryPreviewStyleLongImageFull => '完整显示';

  @override
  String get diaryDraftsTitle => '草稿箱';

  @override
  String get diaryDraftsEmpty => '还没有草稿。写到一半离开的新日记会自动存在这里';

  @override
  String diaryDraftEditedAt(String time, String words) {
    return '编辑于 $time · $words 字';
  }

  @override
  String get diaryDraftDeleted => '已删除草稿';

  @override
  String diaryDraftsDeleted(int count) {
    return '已删除 $count 份草稿';
  }

  @override
  String get diaryDraftsDeleteTitle => '删除草稿';

  @override
  String diaryDraftsDeleteMessage(int count) {
    return '将删除选中的 $count 份草稿。';
  }

  @override
  String get diaryDraftsDeleteFailed => '删除失败，请重试';

  @override
  String get diaryDraftsRestoreFailed => '撤销失败，请重试';

  @override
  String get diaryDraftPickerTitle => '继续写草稿';

  @override
  String diaryDraftPickerViewAll(int count) {
    return '查看全部草稿（$count）';
  }

  @override
  String get diaryDraftPickerNewBlank => '新建空白';

  @override
  String get diarySearchPreviewHint => '在 Jotsy 中搜索';

  @override
  String backupOverwriteAllTemplates(int count) {
    return '$count 个日记模板';
  }

  @override
  String backupImportTemplateMergeResult(int added) {
    return '日记模板：新增 $added 个';
  }

  @override
  String backupOverwriteAllNotebooks(int count) {
    return '$count 个日记本';
  }

  @override
  String backupImportNotebookMergeResult(int added) {
    return '日记本：新增 $added 个';
  }

  @override
  String backupImportModeOverwriteNotebooksExtra(int count) {
    return '同时替换本机已存在的 $count 个日记本的名称、封面与章节等设置';
  }

  @override
  String get diaryTemplateDailyName => '每日记录';

  @override
  String get diaryTemplateDailyDesc => '记下今天的故事，和此刻的心情';

  @override
  String diaryTemplateDailyTitle(String date, String weekday) {
    return '$date $weekday';
  }

  @override
  String get diaryTemplateMorningName => '晨间日记';

  @override
  String get diaryTemplateMorningDesc => '在清晨写下一页，给今天一个温柔的方向';

  @override
  String diaryTemplateMorningTitle(String date) {
    return '晨间 · $date';
  }

  @override
  String get diaryTemplateEveningName => '晚间复盘';

  @override
  String get diaryTemplateEveningDesc => '回看今天的得与失，把明天安排妥当';

  @override
  String diaryTemplateEveningTitle(String date) {
    return '复盘 · $date';
  }

  @override
  String get diaryTemplateGratitudeName => '感恩日记';

  @override
  String get diaryTemplateGratitudeDesc => '写下三件让你心怀感激的小事';

  @override
  String diaryTemplateGratitudeTitle(String date) {
    return '感恩 · $date';
  }

  @override
  String get diaryTemplateQuestionName => '每日一问';

  @override
  String get diaryTemplateQuestionDesc => '每天一个问题，换个角度认识自己';

  @override
  String diaryTemplateQuestionTitle(String date) {
    return '每日一问 · $date';
  }

  @override
  String get diaryTemplateWeeklyName => '周回顾';

  @override
  String get diaryTemplateWeeklyDesc => '收拢一周的亮点与收获，轻装走进下一周';

  @override
  String diaryTemplateWeeklyTitle(String date) {
    return '周回顾 · $date';
  }

  @override
  String get diaryTemplateEmotionName => '情绪梳理';

  @override
  String get diaryTemplateEmotionDesc => '把情绪写下来，看清它从哪里来';

  @override
  String diaryTemplateEmotionTitle(String date) {
    return '情绪梳理 · $date';
  }

  @override
  String get diaryTemplateReadingName => '读书笔记';

  @override
  String get diaryTemplateReadingDesc => '摘录与感想，留下读过的痕迹';

  @override
  String diaryTemplateReadingTitle(String date) {
    return '读书笔记 · $date';
  }

  @override
  String get diaryTemplateDailyHappened => '今天的故事：';

  @override
  String get diaryTemplateDailyMoment => '闪光的瞬间：';

  @override
  String get diaryTemplateDailyMood => '此刻的心情：';

  @override
  String get diaryTemplateDailyWords => '写给今天的一句话：';

  @override
  String diaryTemplateMorningWake(String time, String term) {
    return '$time 醒来 · $term';
  }

  @override
  String get diaryTemplateMorningTop3 => '今天最重要的三件事：';

  @override
  String get diaryTemplateMorningLookForward => '今天期待的小事：';

  @override
  String get diaryTemplateMorningWords => '给今天的一句话：';

  @override
  String get diaryTemplateEveningDone => '今天完成了：';

  @override
  String get diaryTemplateEveningWentWell => '做得好的地方：';

  @override
  String get diaryTemplateEveningBetter => '可以更好的地方：';

  @override
  String get diaryTemplateEveningTomorrow => '明天的安排：';

  @override
  String get diaryTemplateEveningNight => '睡前想对自己说：';

  @override
  String get diaryTemplateGratitudeThree => '今天让我心怀感激的三件事：';

  @override
  String get diaryTemplateGratitudeThanks => '想对谁说声谢谢：';

  @override
  String get diaryTemplateGratitudeSelf => '也谢谢今天的自己：';

  @override
  String get diaryTemplateQuestionPrompt => '今日一问：';

  @override
  String get diaryTemplateQuestionAnswer => '我的回答：';

  @override
  String diaryTemplateWeeklyProgress(String week, String progress) {
    return '第 $week 周 · 今年已走过 $progress';
  }

  @override
  String get diaryTemplateWeeklyHighlights => '本周亮点：';

  @override
  String get diaryTemplateWeeklyWins => '完成与收获：';

  @override
  String get diaryTemplateWeeklyOpen => '还没做完的事：';

  @override
  String get diaryTemplateWeeklyNext => '下周想做的事：';

  @override
  String get diaryTemplateWeeklyNote => '写给下周的自己：';

  @override
  String get diaryTemplateEmotionHappened => '发生了什么：';

  @override
  String get diaryTemplateEmotionFelt => '我感受到的情绪：';

  @override
  String get diaryTemplateEmotionSource => '它从哪里来：';

  @override
  String get diaryTemplateEmotionNeed => '我真正需要的是：';

  @override
  String get diaryTemplateEmotionStep => '接下来能做的一件小事：';

  @override
  String get diaryTemplateReadingBook => '书名：';

  @override
  String get diaryTemplateReadingAuthor => '作者：';

  @override
  String get diaryTemplateReadingProgress => '读到：';

  @override
  String get diaryTemplateReadingQuotes => '摘录：';

  @override
  String get diaryTemplateReadingThoughts => '我的想法：';

  @override
  String get diaryTemplateTagGratitude => '感恩';

  @override
  String get diaryTemplateTagReading => '读书';

  @override
  String get diaryTemplateQuestion01 => '今天让你微笑的一件小事是什么？';

  @override
  String get diaryTemplateQuestion02 => '如果今天可以重来，你会改变什么？';

  @override
  String get diaryTemplateQuestion03 => '最近一次感到自豪是什么时候？';

  @override
  String get diaryTemplateQuestion04 => '此刻你最想对谁说一句话？';

  @override
  String get diaryTemplateQuestion05 => '今天学到的一件新东西是什么？';

  @override
  String get diaryTemplateQuestion06 => '最近有什么事让你一直放不下？';

  @override
  String get diaryTemplateQuestion07 => '你理想中的周末是什么样子？';

  @override
  String get diaryTemplateQuestion08 => '今天有哪个瞬间让你觉得被理解？';

  @override
  String get diaryTemplateQuestion09 => '最近在读、在看或在听什么？它带给你什么？';

  @override
  String get diaryTemplateQuestion10 => '你现在最需要的是休息、陪伴还是挑战？';

  @override
  String get diaryTemplateQuestion11 => '一年前的今天你在担心什么？现在呢？';

  @override
  String get diaryTemplateQuestion12 => '今天你为自己做了什么？';

  @override
  String get diaryTemplateQuestion13 => '最近一次大笑是因为什么？';

  @override
  String get diaryTemplateQuestion14 => '有什么习惯是你想开始或想放下的？';

  @override
  String get diaryTemplateQuestion15 => '用三个词形容今天的自己。';

  @override
  String get diaryTemplateQuestion16 => '今天最大的困难是什么？你是怎么应对的？';

  @override
  String get diaryTemplateQuestion17 => '你最近感激的一个人是谁？为什么？';

  @override
  String get diaryTemplateQuestion18 => '如果明天只能做一件事，你会做什么？';

  @override
  String get diaryTemplateQuestion19 => '最近有什么让你改变了看法？';

  @override
  String get diaryTemplateQuestion20 => '今天的天气让你想起了什么？';

  @override
  String get diaryTemplateQuestion21 => '最近一次走出舒适区是什么时候？';

  @override
  String get diaryTemplateQuestion22 => '十年后的你会怎样看待今天的烦恼？';

  @override
  String get diaryTemplateQuestion23 => '今天有没有哪句话让你印象深刻？';

  @override
  String get diaryTemplateQuestion24 => '最近让你感到平静的地方是哪里？';

  @override
  String get diaryTemplateQuestion25 => '你想对小时候的自己说些什么？';

  @override
  String get diaryTemplateQuestion26 => '今天的你，比昨天多了解自己一点了吗？';

  @override
  String get diaryTemplateQuestion27 => '最近有什么值得庆祝的小进步？';

  @override
  String get diaryTemplateQuestion28 => '有什么事一直想尝试却还没开始？是什么在阻碍你？';

  @override
  String get diaryTemplateQuestion29 => '今天你是怎样照顾自己的情绪的？';

  @override
  String get diaryTemplateQuestion30 => '如果给今天打分（1–10），你会打几分？为什么？';

  @override
  String get diaryTemplateVarDateToken => '日期';

  @override
  String get diaryTemplateVarDateLabel => '日期';

  @override
  String get diaryTemplateVarWeekdayToken => '星期';

  @override
  String get diaryTemplateVarWeekdayLabel => '星期';

  @override
  String get diaryTemplateVarTimeToken => '时间';

  @override
  String get diaryTemplateVarTimeLabel => '时间';

  @override
  String get diaryTemplateVarTime12hLabel => '时间（12 小时制）';

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
  String get diaryTemplateVarWeekToken => '周数';

  @override
  String get diaryTemplateVarWeekLabel => '周数';

  @override
  String get diaryTemplateVarDayOfYearToken => '第几天';

  @override
  String get diaryTemplateVarDayOfYearLabel => '第几天';

  @override
  String get diaryTemplateVarYearProgressToken => '年进度';

  @override
  String get diaryTemplateVarYearProgressLabel => '年进度';

  @override
  String get diaryTemplateVarLunarToken => '农历';

  @override
  String get diaryTemplateVarLunarLabel => '农历';

  @override
  String get diaryTemplateVarSolarTermToken => '节气';

  @override
  String get diaryTemplateVarSolarTermLabel => '节气';

  @override
  String get diaryTemplateVarQuestionToken => '今日一问';

  @override
  String get diaryTemplateVarQuestionLabel => '今日一问';

  @override
  String get diaryTemplateCategoryDaily => '日常';

  @override
  String get diaryTemplateCategoryReview => '复盘';

  @override
  String get diaryTemplateCategoryMood => '情绪';

  @override
  String get diaryTemplateCategoryLife => '生活';

  @override
  String get diaryTemplateCategoryWork => '工作';

  @override
  String get diaryTemplateCategoryOther => '其他';

  @override
  String get diaryTemplateStripTitle => '从模板开始';

  @override
  String get diaryTemplateStripAll => '全部';

  @override
  String get diaryTemplateStripDismiss => '收起模板建议';

  @override
  String get diaryTemplateRecommended => '推荐';

  @override
  String get diaryTemplateUntitled => '未命名模板';

  @override
  String diaryTemplateApplied(String name) {
    return '已套用「$name」';
  }

  @override
  String diaryTemplateAutoApplied(String name) {
    return '已自动套用「$name」';
  }

  @override
  String get diaryTemplatePickerTitle => '选择模板';

  @override
  String get diaryTemplateFilterAll => '全部';

  @override
  String get diaryTemplateFilterRecommended => '推荐';

  @override
  String get diaryTemplateFilterMine => '我的';

  @override
  String get diaryTemplatePickerEmpty => '这里还没有模板';

  @override
  String get diaryTemplatePickerSearchHint => '搜索模板';

  @override
  String diaryTemplatePickerSearchEmpty(String query) {
    return '没有找到与「$query」相关的模板';
  }

  @override
  String get diaryTemplatePickerUse => '使用这个模板';

  @override
  String get diaryTemplatePickerShuffle => '换一题';

  @override
  String get diaryTemplatePickerPreviewHint => '日期与问题已按这篇日记填好。';

  @override
  String diaryTemplatePresetCapsule(String when) {
    return '时间胶囊 · $when';
  }

  @override
  String diaryTemplatePresetEnergy(int level) {
    return '精力 $level/5';
  }

  @override
  String get diaryTemplateEditedBadge => '已修改';

  @override
  String get diaryDraftPickerFromTemplate => '从模板新建';

  @override
  String get diaryTemplatesTitle => '日记模板';

  @override
  String diaryTemplatesSettingsSubtitle(int builtIn, int mine) {
    return '内置 $builtIn 个 · 我的 $mine 个';
  }

  @override
  String get diaryTemplatesNewEntryGroup => '新建日记时';

  @override
  String get diaryTemplatesStripSwitch => '新建时提示选择模板';

  @override
  String get diaryTemplatesStripSwitchSubtitle => '在空白日记的标题下显示「从模板开始」';

  @override
  String get diaryTemplatesAutoApply => '自动套用';

  @override
  String get diaryTemplatesAutoApplyNone => '不自动套用';

  @override
  String get diaryTemplatesAutoApplyHint =>
      '不在任何时间段内，或写其他日子的日记时，新建空白日记先套用这个模板，每次都可以撤销。';

  @override
  String diaryTemplatesAutoApplyRulesSummary(int count) {
    return '$count 个时间段';
  }

  @override
  String diaryTemplatesAutoApplyRulesAndDefault(int count, String name) {
    return '$count 个时间段 · 其他时间用「$name」';
  }

  @override
  String get diaryTemplatesAutoApplyIntro =>
      '新建空白日记时先套用模板，每次都可以撤销。时间段只在写今天的日记时生效。';

  @override
  String get diaryTemplatesAutoApplyRulesGroup => '按时间段';

  @override
  String get diaryTemplatesAutoApplyOtherGroup => '其他时间';

  @override
  String get diaryTemplatesAutoApplyDefault => '默认模板';

  @override
  String get diaryTemplatesAutoApplyAddRule => '添加时间段';

  @override
  String diaryTemplatesAutoApplyRuleLimit(int max) {
    return '最多 $max 个时间段';
  }

  @override
  String get diaryTemplatesAutoApplyOverlapHint => '时间段重叠时，指定了星期的优先，其次是时长更短的。';

  @override
  String diaryTemplatesAutoApplyRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String diaryTemplatesAutoApplyRangeOvernight(String start, String end) {
    return '$start – 次日 $end';
  }

  @override
  String diaryTemplatesAutoApplyRuleSubtitle(String days, String name) {
    return '$days · $name';
  }

  @override
  String get diaryTemplatesAutoApplyEveryDay => '每天';

  @override
  String get diaryTemplatesAutoApplyWorkdays => '工作日';

  @override
  String get diaryTemplatesAutoApplyWeekend => '周末';

  @override
  String get diaryTemplatesAutoApplyDaySeparator => '、';

  @override
  String get diaryTemplatesAutoApplyMissing => '模板已不存在';

  @override
  String get diaryTemplatesAutoApplyEditRule => '编辑时间段';

  @override
  String get diaryTemplatesAutoApplyStart => '开始';

  @override
  String get diaryTemplatesAutoApplyEnd => '结束';

  @override
  String diaryTemplatesAutoApplyOvernightHint(String end) {
    return '跨夜，到次日 $end 结束';
  }

  @override
  String get diaryTemplatesAutoApplySameTime => '开始和结束不能是同一时间';

  @override
  String get diaryTemplatesAutoApplyDays => '星期';

  @override
  String get diaryTemplatesAutoApplyDaysHint => '不选即每天';

  @override
  String get diaryTemplatesAutoApplyTemplate => '模板';

  @override
  String get diaryTemplatesAutoApplyRuleDeleted => '已删除时间段';

  @override
  String get diaryTemplatesMineGroup => '我的模板';

  @override
  String get diaryTemplatesBuiltInGroup => '内置模板';

  @override
  String get diaryTemplatesMineEmpty => '还没有自己的模板。点右上角 + 新建，内置模板也可以直接编辑。';

  @override
  String get diaryTemplatesNew => '新建模板';

  @override
  String get diaryTemplatesImport => '导入模板码';

  @override
  String get diaryTemplatesMoreActions => '更多操作';

  @override
  String get diaryTemplatesDuplicate => '复制';

  @override
  String get diaryTemplatesCopyCode => '复制模板码';

  @override
  String get diaryTemplatesResetBuiltIn => '恢复默认';

  @override
  String get diaryTemplatesRestoreDeleted => '恢复已删除的内置模板';

  @override
  String diaryTemplatesRestoreDeletedCount(int count) {
    return '$count 个';
  }

  @override
  String get diaryTemplatesRestoreSheetTitle => '已删除的内置模板';

  @override
  String get diaryTemplatesRestoreSheetHint => '恢复后回到内置模板列表，删除前改过的内容也一并回来。';

  @override
  String get diaryTemplatesRestore => '恢复';

  @override
  String get diaryTemplatesRestoreAll => '全部恢复';

  @override
  String diaryTemplatesCopyName(String name) {
    return '$name 副本';
  }

  @override
  String diaryTemplatesDeleted(String name) {
    return '已删除「$name」';
  }

  @override
  String diaryTemplatesResetDone(String name) {
    return '已恢复「$name」的默认内容';
  }

  @override
  String diaryTemplatesRestoredDone(String name) {
    return '已恢复「$name」';
  }

  @override
  String diaryTemplatesRestoredAllDone(int count) {
    return '已恢复 $count 个内置模板';
  }

  @override
  String get diaryTemplatesCodeCopied => '模板码已复制';

  @override
  String get diaryTemplatesCodeTooLong => '模板正文太长，无法生成模板码';

  @override
  String get diaryTemplatesImportEmpty => '剪贴板里没有模板码';

  @override
  String get diaryTemplatesImportInvalid => '这不是有效的模板码';

  @override
  String diaryTemplatesImported(String name) {
    return '已导入「$name」';
  }

  @override
  String diaryTemplatesImportedNewer(String name) {
    return '已导入「$name」。它来自新版本，部分设置可能未生效。';
  }

  @override
  String get diaryTemplatesSaveFailed => '模板保存失败，请重试';

  @override
  String get diaryTemplateEditorNewTitle => '新建模板';

  @override
  String get diaryTemplateEditorEditTitle => '编辑模板';

  @override
  String get diaryTemplateEditorTabContent => '内容';

  @override
  String get diaryTemplateEditorTabSettings => '设置';

  @override
  String get diaryTemplateEditorTitleHint => '标题（可插入变量）';

  @override
  String get diaryTemplateEditorBodyHint => '写下正文，小标题、列表与待办都会保留';

  @override
  String get diaryTemplateEditorAllVariables => '全部变量';

  @override
  String get diaryTemplateEditorVariablesTitle => '插入变量';

  @override
  String get diaryTemplateEditorVariablesHint =>
      '套用模板时按日记的日期替换成具体内容。农历与节气为中文名称。';

  @override
  String diaryTemplateEditorTimeFormatHint(String example) {
    return '时间可以在冒号后写格式，如 $example：H 为时（h 为 12 小时制）、mm 为分、ss 为秒、a 为上午 / 下午，其他字母要加单引号。格式认不出时原样保留。';
  }

  @override
  String diaryTemplateEditorVariableExample(String example) {
    return '今天：$example';
  }

  @override
  String get diaryTemplateEditorName => '名称';

  @override
  String get diaryTemplateEditorNameRequired => '请填写模板名称';

  @override
  String get diaryTemplateEditorDescription => '一句话说明';

  @override
  String get diaryTemplateEditorLook => '外观';

  @override
  String get diaryTemplateEditorCategory => '分类';

  @override
  String get diaryTemplateEditorIcon => '图标';

  @override
  String get diaryTemplateEditorAccent => '颜色';

  @override
  String get diaryTemplateEditorAccentTheme => '跟随主题';

  @override
  String get diaryTemplateEditorPresets => '套用时一并设置';

  @override
  String get diaryTemplateEditorTags => '标签';

  @override
  String get diaryTemplateEditorAddTag => '添加标签';

  @override
  String get diaryTemplateEditorNewTag => '新建标签';

  @override
  String get diaryTemplateEditorTagsHint => '按名称匹配，本机没有的标签会在套用时新建。';

  @override
  String get diaryTemplateEditorMood => '心情';

  @override
  String get diaryTemplateEditorNone => '不设';

  @override
  String get diaryTemplateEditorEnergy => '精力';

  @override
  String get diaryTemplateEditorCapsule => '时间胶囊';

  @override
  String get diaryTemplateEditorCapsuleHint => '从套用当天起算，发布前仍可修改。';

  @override
  String get diaryTemplateEditorRecommend => '推荐时间';

  @override
  String get diaryTemplateEditorRecommendHint =>
      '满足每一组选中的条件时，这个模板会排在建议的最前面；同一组里选多个表示任一即可。';

  @override
  String get diaryTemplateEditorSlots => '时段';

  @override
  String get diaryTemplateEditorWeekdays => '星期';

  @override
  String get diaryTemplateEditorMonth => '月份';

  @override
  String get diaryTemplateSlotMorning => '清晨';

  @override
  String get diaryTemplateSlotAfternoon => '午后';

  @override
  String get diaryTemplateSlotEvening => '傍晚';

  @override
  String get diaryTemplateSlotNight => '深夜';

  @override
  String get diaryTemplateMonthStart => '月初三天';

  @override
  String get diaryTemplateMonthEnd => '月末三天';

  @override
  String get diaryTemplateSaveAs => '存为模板';

  @override
  String get diaryTemplateSaveAsMediaDropped => '图片、录音等媒体不会存进模板';

  @override
  String get diaryEditorMoreActions => '更多';

  @override
  String get diaryTemplateChoose => '选择模板';

  @override
  String get diaryTemplateNeedsBlankEntry => '已经开始写了，模板只能套用在空白日记上';

  @override
  String get notebookTitle => '日记本';

  @override
  String get notebookNew => '新建日记本';

  @override
  String get notebookEditTitle => '编辑日记本';

  @override
  String get notebookManage => '管理';

  @override
  String get notebookSubSectionTitle => '子日记本';

  @override
  String get notebookSubCreateShort => '新建子本';

  @override
  String notebookSubMore(int count) {
    return '还有 $count 本';
  }

  @override
  String get notebookSubMoreHint => '展开';

  @override
  String notebookSubMoreSemantics(int count) {
    return '展开其余 $count 本子日记本';
  }

  @override
  String get notebookSubLess => '收起';

  @override
  String get notebookSubLessSemantics => '收起子日记本';

  @override
  String get notebookSubCreate => '新建子日记本';

  @override
  String notebookSubCountSemantics(int count) {
    return '含 $count 本子日记本';
  }

  @override
  String notebookNestGoUp(String name) {
    return '回到「$name」';
  }

  @override
  String get notebookNestPathSeparator => ' › ';

  @override
  String get notebookParentLabel => '上级日记本';

  @override
  String get notebookParentNone => '无（放在书架上）';

  @override
  String get notebookParentFooter =>
      '打开上级时也会看到这本里的日记。最多三层；智能日记本可以放在别的本子下，但不能再放子本。';

  @override
  String get notebookParentPickerEmpty => '没有能放进去的日记本：最多三层，智能日记本不能放子本';

  @override
  String notebookParentPrivacyHidden(String name) {
    return '上级「$name」不在全部日记中显示，这本也随之隐藏';
  }

  @override
  String notebookParentPrivacyLocked(String name) {
    return '上级「$name」已上锁，这本也随之上锁';
  }

  @override
  String get notebookNestMove => '移动到…';

  @override
  String get notebookNestMoveHint => '放到另一本日记本下，或放回书架';

  @override
  String notebookNestMoved(String name) {
    return '已移到「$name」下';
  }

  @override
  String get notebookNestMovedToShelf => '已放回书架';

  @override
  String notebookNestDeleteChildrenHint(int count) {
    return '$count 本子日记本会移到上一层，不会删除';
  }

  @override
  String get notebookAllDiaries => '全部日记';

  @override
  String get notebookUnfiled => '未收录';

  @override
  String get notebookSectionPinned => '置顶';

  @override
  String get notebookSectionMine => '我的日记本';

  @override
  String get notebookSectionSmart => '智能日记本';

  @override
  String get notebookSectionClosed => '已合上';

  @override
  String notebookEntryCount(int count) {
    return '$count 篇';
  }

  @override
  String get notebookSemanticsSeparator => '，';

  @override
  String get notebookEmptyHint => '把不同主题、不同时间的日记收进同一本';

  @override
  String get notebookMissing => '这本日记本已不存在';

  @override
  String get notebookNameLabel => '名称';

  @override
  String get notebookNameHint => '例如：旅行';

  @override
  String get notebookDescriptionLabel => '简介';

  @override
  String get notebookDescriptionHint => '用一句话介绍这本（可选）';

  @override
  String get notebookIconLabel => '图标';

  @override
  String get notebookIconMore => '更多图标';

  @override
  String get notebookIconLess => '收起';

  @override
  String get notebookColorLabel => '颜色';

  @override
  String get notebookColorFollowTheme => '跟随主题';

  @override
  String get notebookCoverLabel => '封面图';

  @override
  String get notebookCoverPick => '选择图片';

  @override
  String get notebookCoverRemove => '移除';

  @override
  String get notebookCoverSectionTitle => '封面';

  @override
  String get notebookCoverLayoutTitle => '版式';

  @override
  String get notebookCoverLayoutClassic => '经典';

  @override
  String get notebookCoverLayoutFullBleed => '满版';

  @override
  String get notebookCoverLayoutSpine => '书脊';

  @override
  String get notebookCoverLayoutPlate => '贴签';

  @override
  String get notebookCoverLayoutMinimal => '极简';

  @override
  String get notebookCoverTextureTitle => '纹理';

  @override
  String get notebookCoverTextureNone => '无';

  @override
  String get notebookCoverTextureDots => '圆点';

  @override
  String get notebookCoverTextureLines => '横线';

  @override
  String get notebookCoverTextureGrid => '方格';

  @override
  String get notebookCoverTextureDiagonal => '斜纹';

  @override
  String get notebookCoverFromDiaries => '从日记中选';

  @override
  String get notebookCoverAdjustCrop => '调整取景';

  @override
  String get notebookCoverCropDone => '完成';

  @override
  String get notebookCoverCropHint => '拖动移动图片，双指缩放';

  @override
  String get notebookCoverCropHintDesktop => '拖动移动图片，滚动滚轮缩放';

  @override
  String get notebookCoverCropZoom => '缩放';

  @override
  String get notebookCoverCropLoadFailed => '无法读取这张图片';

  @override
  String get notebookCoverPhotosTitle => '从日记中选封面';

  @override
  String get notebookCoverPhotosSubtitle => '本子里（含子日记本）的日记用到的图片，新的在前';

  @override
  String get notebookCoverPhotosEmpty => '这本日记本的日记里还没有图片';

  @override
  String notebookCoverPhotoItem(int index) {
    return '第 $index 张图片';
  }

  @override
  String get notebookTypeLabel => '类型';

  @override
  String get notebookTypeManual => '普通';

  @override
  String get notebookTypeSmart => '智能';

  @override
  String get notebookTypeManualHint => '自己挑选要收进来的日记';

  @override
  String get notebookTypeSmartHint => '按条件自动收录符合的日记';

  @override
  String get notebookPrivacyLabel => '隐私';

  @override
  String get notebookPrivacyNormal => '正常';

  @override
  String get notebookPrivacyHidden => '不在全部日记中显示';

  @override
  String get notebookPrivacyHiddenHint => '只在这本里看到';

  @override
  String get notebookPrivacyLocked => '上锁';

  @override
  String get notebookPrivacyLockedHint => '打开时验证身份，并且不在全部日记中显示';

  @override
  String get notebookSortLabel => '默认排序';

  @override
  String get notebookSortCreatedDesc => '发表时间 新→旧';

  @override
  String get notebookSortCreatedAsc => '发表时间 旧→新';

  @override
  String get notebookSortCreatedAscHint => '适合读成一本书';

  @override
  String get notebookSortUpdatedDesc => '最近编辑';

  @override
  String get notebookSortBook => '书序';

  @override
  String get notebookSortBookHint => '按目录手动排列';

  @override
  String get notebookTemplateLabel => '新建时套用模板';

  @override
  String get notebookTemplateNone => '不套用';

  @override
  String get notebookSaveFailed => '保存失败，请重试';

  @override
  String get notebookActionFailed => '操作失败，请重试';

  @override
  String get notebookMoreActions => '更多操作';

  @override
  String notebookSubCount(int count) {
    return '$count 本子本';
  }

  @override
  String get notebookSubCollapse => '收起子本';

  @override
  String get notebookSubExpand => '展开子本';

  @override
  String get notebookCollapseAll => '全部收起';

  @override
  String get notebookExpandAll => '全部展开';

  @override
  String get notebookStatePinned => '置顶';

  @override
  String get notebookStateSmart => '智能';

  @override
  String get notebookStateHidden => '隐藏';

  @override
  String get notebookStateLocked => '上锁';

  @override
  String get notebookStateClosed => '已合上';

  @override
  String get notebookActionPin => '置顶';

  @override
  String get notebookActionUnpin => '取消置顶';

  @override
  String get notebookActionClose => '合上';

  @override
  String get notebookActionCloseHint => '合上后收进书架的“已合上”，不再出现在收录选择里';

  @override
  String get notebookActionReopen => '重新打开';

  @override
  String get notebookActionMerge => '合并到…';

  @override
  String get notebookActionConvert => '转为普通日记本';

  @override
  String get notebookActionConvertHint => '收进现在符合条件的日记，之后不再自动更新';

  @override
  String get notebookMergeSheetTitle => '合并到哪一本';

  @override
  String get notebookMergeEmpty => '没有其他普通日记本可以并入';

  @override
  String get notebookMergeConfirmTitle => '合并日记本';

  @override
  String notebookMergeConfirm(String source, int count, String target) {
    return '把「$source」的 $count 篇日记并入「$target」并删除「$source」？';
  }

  @override
  String get notebookMergeAction => '合并';

  @override
  String notebookMerged(String target) {
    return '已并入「$target」';
  }

  @override
  String notebookDeleteTitle(String name) {
    return '删除「$name」？';
  }

  @override
  String get notebookDeleteKeepDiaries => '只删除日记本';

  @override
  String notebookDeleteKeepDiariesHint(int count) {
    return '$count 篇日记仍在全部日记里';
  }

  @override
  String get notebookDeleteWithDiaries => '连同日记移到回收站';

  @override
  String get notebookDeleteWithDiariesHint => '可在回收站恢复';

  @override
  String get notebookDeleteSmartHint => '日记不会受影响';

  @override
  String notebookDeleted(String name) {
    return '已删除「$name」';
  }

  @override
  String notebookSwitcherSemantics(String name) {
    return '切换日记本，当前：$name';
  }

  @override
  String get notebookScopeDeleted => '日记本已删除';

  @override
  String notebookSearchIn(String name) {
    return '在「$name」中搜索';
  }

  @override
  String notebookSearchRemoveScope(String name) {
    return '移除日记本条件：$name';
  }

  @override
  String notebookMetaWords(String words) {
    return '$words 字';
  }

  @override
  String notebookMetaSpan(String start, String end) {
    return '$start – $end';
  }

  @override
  String notebookMetaSpanOngoing(String start) {
    return '$start – 至今';
  }

  @override
  String get notebookHeaderSmartBadge => '智能日记本';

  @override
  String get notebookHeaderPrivateBadge => '仅在本日记本中显示';

  @override
  String get notebookEmptyTitle => '这本还空着';

  @override
  String get notebookEmptyCreateHint => '点下方的新建，写下第一篇';

  @override
  String notebookUnlockReason(String name) {
    return '解锁「$name」';
  }

  @override
  String get notebookLockUnsupportedTitle => '无法打开上锁的日记本';

  @override
  String get notebookLockUnsupportedMessage =>
      '这台设备没有设置锁屏密码，无法验证身份，上锁的日记本暂时打不开。在系统设置里设置锁屏密码，或在 设置 → 应用锁与密码 里改用应用密码后就能打开。';

  @override
  String get notebookLockUnsupportedAction => '知道了';

  @override
  String notebookLockedTitle(String name) {
    return '「$name」已上锁';
  }

  @override
  String get notebookLockedSubtitle => '离开应用后需要重新验证身份';

  @override
  String get notebookLockUnlock => '解锁';

  @override
  String get notebookLockBackToAll => '回到全部日记';

  @override
  String get notebookPrivateDiaryPlaceholder => '私密日记本中的日记';

  @override
  String get notebookAnniversaryLinkPrivate => '关联的日记在私密日记本中';

  @override
  String get backupImportFolderModeTitle => '原来的日记本 / 文件夹';

  @override
  String get backupImportFolderModeNotebooks => '日记本';

  @override
  String get backupImportFolderModeTags => '标签';

  @override
  String get backupImportFolderModeBoth => '两者';

  @override
  String backupImportFolderModeNotebooksHint(int count) {
    return '按来源的 $count 个笔记本 / 文件夹建成日记本，同名的并入本机已有的';
  }

  @override
  String get backupImportFolderModeTagsHint => '像以前一样，变成同名标签';

  @override
  String get backupImportFolderModeBothHint => '同时建日记本和同名标签';

  @override
  String get notebookEmptyManualHint => '写下第一篇，或从已有日记里挑几篇放进来';

  @override
  String get notebookEmptyWriteFirst => '写第一篇';

  @override
  String get notebookEmptyPickExisting => '从已有日记挑选';

  @override
  String get notebookAddDiaries => '添加日记';

  @override
  String get notebookExportAsBook => '导出成书';

  @override
  String notebookBookExportedOn(String date) {
    return '导出于 $date';
  }

  @override
  String get diaryExportBookStructure => '书籍结构';

  @override
  String get diaryExportBookStructureDescription => '扉页、目录与章节标题';

  @override
  String get notebookContentsUnassignedDropHint => '拖到这里移出章节';

  @override
  String get notebookChapterAll => '全部';

  @override
  String get notebookChapterUnassigned => '未分章';

  @override
  String notebookChapterChip(String title, int count) {
    return '$title · $count';
  }

  @override
  String get notebookContents => '目录';

  @override
  String get notebookContentsNewChapter => '新章节';

  @override
  String get notebookContentsSelect => '多选';

  @override
  String get notebookContentsSelectDone => '退出多选';

  @override
  String notebookContentsSelectedCount(int count) {
    return '已选 $count 篇';
  }

  @override
  String get notebookContentsNoChapterHint => '添加章节，把日记分成几部分';

  @override
  String get notebookContentsEmpty => '这本还没有日记';

  @override
  String get notebookContentsArchived => '已归档';

  @override
  String get notebookContentsSealed => '未解封的时间胶囊';

  @override
  String get notebookContentsChapterActions => '章节操作';

  @override
  String get notebookChapterRename => '重命名';

  @override
  String get notebookChapterRenameTitle => '重命名章节';

  @override
  String get notebookChapterMoveUp => '上移';

  @override
  String get notebookChapterMoveDown => '下移';

  @override
  String get notebookChapterCollapse => '收起本章';

  @override
  String get notebookChapterExpand => '展开本章';

  @override
  String get notebookChapterTitleLabel => '章节名称';

  @override
  String get notebookChapterTitleHint => '例如：东京';

  @override
  String notebookChapterDeleteConfirm(String title, int count) {
    return '删除章节「$title」？其中的 $count 篇回到未分章，日记不会被删除';
  }

  @override
  String get notebookContentsMoveToChapter => '移到章节…';

  @override
  String get notebookContentsMoveSheetTitle => '移到章节';

  @override
  String notebookContentsMoved(String title, int count) {
    return '已将 $count 篇移到「$title」';
  }

  @override
  String get notebookPickerTitle => '收进日记本';

  @override
  String get notebookPickerEmpty => '还没有可以收进的日记本';

  @override
  String get notebookPickerDone => '完成';

  @override
  String notebookPickerPrivateHint(String name) {
    return '已收进「$name」，这些日记只在该日记本中显示';
  }

  @override
  String get notebookSelectionMore => '更多操作';

  @override
  String get notebookRemoveFromCurrent => '从本日记本移出';

  @override
  String get notebookMoveTo => '移动到…';

  @override
  String notebookAddedToCount(int count) {
    return '已收进 $count 本日记本';
  }

  @override
  String get notebookMembershipUpdated => '已更新日记本';

  @override
  String notebookRemovedFrom(String name, int count) {
    return '已从「$name」移出 $count 篇';
  }

  @override
  String notebookMovedTo(String name, int count) {
    return '已将 $count 篇移到「$name」';
  }

  @override
  String get notebookPublishNone => '不收进日记本';

  @override
  String notebookWriteInto(String name) {
    return '写进「$name」';
  }

  @override
  String notebookAddPageTitle(String name) {
    return '添加到「$name」';
  }

  @override
  String notebookAddPageDone(int count) {
    return '完成 ($count)';
  }

  @override
  String get notebookAddSearchHint => '搜索日记';

  @override
  String get notebookAddFilterAll => '全部';

  @override
  String get notebookAddFilterRecent => '最近 30 天';

  @override
  String get notebookAddFilterThisYear => '今年';

  @override
  String get notebookAddAlreadyIn => '已在本子里';

  @override
  String notebookAddedCount(int count) {
    return '已添加 $count 篇';
  }

  @override
  String get notebookAddEmpty => '没有符合条件的日记';

  @override
  String get notebookPreviewNone => '还没有收进日记本';

  @override
  String get notebookListSeparator => '、';

  @override
  String notebookOpenNotebook(String name) {
    return '打开「$name」';
  }

  @override
  String get notebookRulesTitle => '条件';

  @override
  String get notebookRulesMatchAll => '全部满足';

  @override
  String get notebookRulesMatchAny => '任一满足';

  @override
  String notebookRulesMatchCount(int count) {
    return '符合条件：$count 篇';
  }

  @override
  String get notebookRulesNeedOne => '至少添加一个条件才能保存';

  @override
  String notebookRulesLimit(int max) {
    return '最多 $max 个条件';
  }

  @override
  String get notebookRulesExamples => '从示例开始';

  @override
  String get notebookRuleExampleRecent => '最近 30 天';

  @override
  String get notebookRuleExampleThisMonth => '每年这个月';

  @override
  String get notebookRuleExampleImages => '有图片的日记';

  @override
  String get notebookRuleExamplePinned => '置顶的日记';

  @override
  String get notebookRuleAdd => '添加条件';

  @override
  String get notebookRuleRemove => '移除条件';

  @override
  String get notebookRuleDone => '完成';

  @override
  String get notebookRuleTypeTags => '标签';

  @override
  String get notebookRuleTypeTagsHint => '带有或不带某些标签';

  @override
  String get notebookRuleTypeMood => '心情';

  @override
  String get notebookRuleTypeMoodHint => '心情是其中之一';

  @override
  String get notebookRuleTypeWeather => '天气';

  @override
  String get notebookRuleTypeWeatherHint => '天气包含某段文字';

  @override
  String get notebookRuleTypeLocation => '地点';

  @override
  String get notebookRuleTypeLocationHint => '地点包含某段文字';

  @override
  String get notebookRuleTypeKeyword => '关键词';

  @override
  String get notebookRuleTypeKeywordHint => '标题或正文包含某段文字';

  @override
  String get notebookRuleTypeDate => '日期';

  @override
  String get notebookRuleTypeDateHint => '一段日期、最近几天或每年的某个时候';

  @override
  String get notebookRuleTypeMedia => '图片与附件';

  @override
  String get notebookRuleTypeMediaHint => '正文里有图片、录音、视频或附件';

  @override
  String get notebookRuleTypeFlag => '封面与置顶';

  @override
  String get notebookRuleTypeFlagHint => '有封面或已置顶';

  @override
  String get notebookRuleTagAny => '含任一';

  @override
  String get notebookRuleTagAll => '全部都含';

  @override
  String get notebookRuleTagNone => '都不含';

  @override
  String get notebookRuleNoTags => '还没有标签';

  @override
  String get notebookRuleWeatherHint => '如：雨';

  @override
  String get notebookRuleLocationHint => '如：京都';

  @override
  String get notebookRuleKeywordHint => '标题或正文里的文字';

  @override
  String get notebookRuleDateBetween => '固定区间';

  @override
  String get notebookRuleDateLastDays => '最近几天';

  @override
  String get notebookRuleDateThisYear => '今年';

  @override
  String get notebookRuleDateMonth => '每年某月';

  @override
  String get notebookRuleDateToday => '每年的今天';

  @override
  String get notebookRuleDateTodayHint => '与今天同月同日的日记';

  @override
  String notebookRuleDaysValue(int days) {
    return '$days 天';
  }

  @override
  String get notebookRuleDaysDecrease => '减少一天';

  @override
  String get notebookRuleDaysIncrease => '增加一天';

  @override
  String get notebookRuleMediaImage => '有图片';

  @override
  String get notebookRuleMediaAudio => '有录音';

  @override
  String get notebookRuleMediaVideo => '有视频';

  @override
  String get notebookRuleMediaAttachment => '有附件';

  @override
  String get notebookRuleFlagCover => '有封面';

  @override
  String get notebookRuleFlagPinned => '已置顶';

  @override
  String notebookRuleSummaryTagsAny(String tags) {
    return '标签含任一：$tags';
  }

  @override
  String notebookRuleSummaryTagsAll(String tags) {
    return '标签全部都含：$tags';
  }

  @override
  String notebookRuleSummaryTagsNone(String tags) {
    return '标签都不含：$tags';
  }

  @override
  String notebookRuleSummaryMood(String moods) {
    return '心情：$moods';
  }

  @override
  String notebookRuleSummaryWeather(String text) {
    return '天气包含“$text”';
  }

  @override
  String notebookRuleSummaryLocation(String text) {
    return '地点包含“$text”';
  }

  @override
  String notebookRuleSummaryKeyword(String text) {
    return '标题或正文包含“$text”';
  }

  @override
  String notebookRuleSummaryRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String notebookRuleSummaryLastDays(int days) {
    return '最近 $days 天';
  }

  @override
  String notebookRuleSummaryMonth(int month, String monthName) {
    return '每年 $month 月';
  }

  @override
  String notebookRuleSummaryToday(String date) {
    return '每年的今天（$date）';
  }

  @override
  String get notebookRuleUnknown => '无法识别的条件（来自更新的版本）';

  @override
  String notebookConvertTitle(String name) {
    return '把「$name」转为普通日记本？';
  }

  @override
  String notebookConvertMessage(int count) {
    return '现在符合条件的 $count 篇日记会收进来（不含归档的），以后不再按条件自动更新。';
  }

  @override
  String get notebookConvertAction => '转换';

  @override
  String notebookConverted(int count) {
    return '已转为普通日记本，收进 $count 篇';
  }

  @override
  String get notebookSaveRange => '存为日记本';

  @override
  String get notebookSaveRangeSmartHint => '这段日期里的日记，之后补写的也会自动收进来';

  @override
  String notebookSaveRangeManualHint(int count) {
    return '收进现在这 $count 篇';
  }

  @override
  String get notebookSaveSearchAsSmart => '存为智能日记本';

  @override
  String get notebookSaveRangeSmart => '智能日记本';

  @override
  String get notebookSaveRangeManual => '普通日记本';

  @override
  String get notebookGoalLabel => '写作目标';

  @override
  String get notebookGoalEnable => '设置目标';

  @override
  String get notebookGoalEnableHint => '在日记本头部显示进度，不会发送提醒';

  @override
  String get notebookGoalDecrease => '少一篇';

  @override
  String get notebookGoalIncrease => '多一篇';

  @override
  String get notebookGoalPeriodDay => '每天';

  @override
  String get notebookGoalPeriodWeek => '每周';

  @override
  String get notebookGoalPeriodMonth => '每月';

  @override
  String notebookGoalSummaryDay(int count) {
    return '每天写 $count 篇';
  }

  @override
  String notebookGoalSummaryWeek(int count) {
    return '每周写 $count 篇';
  }

  @override
  String notebookGoalSummaryMonth(int count) {
    return '每月写 $count 篇';
  }

  @override
  String notebookGoalProgressDay(int current, int target) {
    return '今天 $current / $target 篇';
  }

  @override
  String notebookGoalProgressWeek(int current, int target) {
    return '本周 $current / $target 篇';
  }

  @override
  String notebookGoalProgressMonth(int current, int target) {
    return '本月 $current / $target 篇';
  }

  @override
  String get notebookGoalMetDay => '今天已完成 ✓';

  @override
  String get notebookGoalMetWeek => '本周已完成 ✓';

  @override
  String get notebookGoalMetMonth => '本月已完成 ✓';

  @override
  String notebookGoalStreakDay(int count) {
    return '连续达成 $count 天';
  }

  @override
  String notebookGoalStreakWeek(int count) {
    return '连续达成 $count 周';
  }

  @override
  String notebookGoalStreakMonth(int count) {
    return '连续达成 $count 个月';
  }

  @override
  String get notebookInsights => '统计';

  @override
  String get notebookInsightsEmpty => '这本还没有可统计的日记';

  @override
  String get notebookInsightsEntries => '篇数';

  @override
  String get notebookInsightsWords => '字数';

  @override
  String get notebookInsightsRecordedDays => '记录天数';

  @override
  String get notebookInsightsSpan => '时间跨度';

  @override
  String get notebookInsightsPhotos => '照片数';

  @override
  String get notebookInsightsLongestStreak => '最长连续';

  @override
  String notebookInsightsDays(int count) {
    return '$count 天';
  }

  @override
  String notebookInsightsSpanMonths(int months) {
    return '$months 个月';
  }

  @override
  String notebookInsightsSpanYears(int years) {
    return '$years 年';
  }

  @override
  String notebookInsightsSpanYearsMonths(int years, int months) {
    return '$years 年 $months 个月';
  }

  @override
  String get notebookInsightsMoods => '心情分布';

  @override
  String notebookInsightsMoodShare(int count, int percent) {
    return '$count 篇 · $percent%';
  }

  @override
  String get notebookInsightsTopTags => '常用标签';

  @override
  String get notebookInsightsRhythm => '写作节奏';

  @override
  String notebookInsightsRhythmBar(String month, int count) {
    return '$month：$count 篇';
  }

  @override
  String notebookInsightsGoalRecent(int met, int total) {
    return '最近 $total 个周期达成 $met 个';
  }

  @override
  String notebookInsightsGoalRecentCaption(int count) {
    return '最近 $count 个周期';
  }

  @override
  String get notebookInsightsRandom => '随机翻一篇';

  @override
  String get diaryColorPanelDefaultColor => '默认颜色';

  @override
  String get diaryColorPanelNoBackground => '无背景色';

  @override
  String get diaryColorPanelCustom => '自定义';

  @override
  String get diaryColorPanelEnterCode => '输入颜色代码';

  @override
  String get diaryColorPanelHexHint => 'RRGGBB';

  @override
  String get diaryColorPanelSwatches => '色板';

  @override
  String get diaryColorPanelSaturationValue => '饱和度与亮度';

  @override
  String get diaryColorPanelHue => '色相';

  @override
  String get diaryColorPanelOpacity => '不透明度';

  @override
  String get diaryColorRed => '红';

  @override
  String get diaryColorOrange => '橙';

  @override
  String get diaryColorYellow => '黄';

  @override
  String get diaryColorGreen => '绿';

  @override
  String get diaryColorTeal => '蓝绿';

  @override
  String get diaryColorBlue => '蓝';

  @override
  String get diaryColorIndigo => '靛';

  @override
  String get diaryColorPurple => '紫';

  @override
  String get diaryColorPink => '粉';

  @override
  String get diaryColorBrown => '棕';

  @override
  String get diaryColorGray => '灰';

  @override
  String get diaryColorPanelMaterial => '色系';

  @override
  String get diaryColorDeepPurple => '深紫';

  @override
  String get diaryColorLightBlue => '浅蓝';

  @override
  String get diaryColorCyan => '青';

  @override
  String get diaryColorLightGreen => '浅绿';

  @override
  String get diaryColorLime => '青柠';

  @override
  String get diaryColorAmber => '琥珀';

  @override
  String get diaryColorDeepOrange => '深橙';

  @override
  String get diaryColorBlueGray => '蓝灰';

  @override
  String get diaryColorWhite => '白';

  @override
  String get diaryColorBlack => '黑';

  @override
  String diaryColorShade(String family, String tone) {
    return '$family $tone';
  }

  @override
  String diaryColorPanelFamily(String family) {
    return '$family色系';
  }

  @override
  String get tagPickerSearchHint => '搜索标签';

  @override
  String get tagPickerSortTooltip => '排序方式';

  @override
  String get tagPickerSortCustom => '默认排序';

  @override
  String get tagPickerSortAlphabetical => '按字母排序';

  @override
  String tagPickerCreateNamed(String name) {
    return '新建「$name」';
  }

  @override
  String tagPickerSearchEmpty(String query) {
    return '没有找到「$query」';
  }

  @override
  String get settingsFeaturesTitle => '功能管理';

  @override
  String get settingsFeaturesSubtitle => '选择要用的页面和功能';

  @override
  String get settingsFeaturesPagesGroup => '页面';

  @override
  String get settingsFeaturesPagesFooter =>
      '日记始终保留，设置在日记页顶栏的“更多”菜单里。关闭的页面不再出现在底部导航，数据不受影响。';

  @override
  String get settingsFeaturesCalendarSubtitle => '按月查看日记，含农历、节假日与纪念日';

  @override
  String get settingsFeaturesExploreSubtitle => '统计、那年今日、心情趋势与照片墙';

  @override
  String get settingsFeaturesFeaturesGroup => '功能';

  @override
  String get settingsFeaturesFeaturesFooter =>
      '关闭后相关入口和选项都会隐藏，已有数据保留，重新开启即可恢复。';

  @override
  String get settingsFeaturesNotebooksSubtitle => '把日记收进不同的本子，分章节、导出成书';

  @override
  String get settingsFeaturesAnniversaries => '纪念日';

  @override
  String get settingsFeaturesAnniversariesSubtitle => '纪念日与倒数日，标在日历上';

  @override
  String get settingsFeaturesTemplates => '日记模板';

  @override
  String get settingsFeaturesTemplatesSubtitle => '新建日记时套用写好的格式';

  @override
  String get settingsFeaturesTimeCapsules => '时间胶囊';

  @override
  String get settingsFeaturesTimeCapsulesSubtitle => '写给未来，到期才能打开';

  @override
  String get settingsFeaturesSwipeArchive => '侧滑归档';

  @override
  String get settingsFeaturesSwipeArchiveSubtitle => '在日记列表左滑卡片归档，在归档页左滑取消归档';

  @override
  String get settingsFeaturesNotebooksOffTitle => '关闭日记本？';

  @override
  String settingsFeaturesNotebooksOffMessage(int count) {
    return '有 $count 本隐藏或上锁的日记本，关闭后其中的日记暂时看不到，重新开启日记本即可恢复。';
  }

  @override
  String get settingsFeaturesNotebooksOffConfirm => '关闭';

  @override
  String get supportDeveloperTitle => '支持开发者';

  @override
  String get supportDeveloperEntrySubtitle => '微信、支付宝自愿打赏';

  @override
  String get supportDeveloperIntro =>
      'Jotsy 免费开源，没有广告。如果它对你有帮助，欢迎打赏支持；打赏完全自愿，不会解锁任何功能。';

  @override
  String get supportDeveloperWeChat => '微信';

  @override
  String get supportDeveloperAlipay => '支付宝';

  @override
  String get supportDeveloperWeChatCodeLabel => '微信赞赏码';

  @override
  String get supportDeveloperAlipayCodeLabel => '支付宝收款码';

  @override
  String get supportDeveloperWeChatHint => '先把赞赏码保存到相册，再打开微信「扫一扫」，点右上角的相册选这张图。';

  @override
  String get supportDeveloperAlipayHint =>
      '点下方按钮直接进入支付宝付款；也可以保存收款码，在支付宝「扫一扫」里从相册选择。';

  @override
  String get supportDeveloperSaveCode => '保存到相册';

  @override
  String get supportDeveloperOpenWeChat => '打开微信';

  @override
  String get supportDeveloperOpenAlipay => '打开支付宝付款';

  @override
  String get supportDeveloperAlipayUnavailable =>
      '没能打开支付宝。可以保存收款码，用装有支付宝的手机扫码。';

  @override
  String get supportDeveloperWeChatUnavailable => '没能打开微信，请手动打开微信后扫码。';

  @override
  String get diaryColorPanelNewColor => '新建颜色';

  @override
  String get diaryColorPanelManageColors => '管理我的颜色';

  @override
  String get diaryColorPanelManageDone => '完成';

  @override
  String get diaryColorPanelSavedEmpty => '在「自定义」调出的颜色会保存在这里';

  @override
  String get diaryColorPanelSavedMark => '已保存';

  @override
  String diaryColorPanelSavedColor(String color) {
    return '我的颜色 $color';
  }

  @override
  String diaryColorPanelDocumentColor(String color) {
    return '本篇用过的颜色 $color';
  }

  @override
  String diaryColorPanelRemoveColor(String color) {
    return '移除 $color';
  }

  @override
  String diaryColorPanelKeepColor(String color) {
    return '保存 $color 到我的颜色';
  }

  @override
  String get homeBarStyleTitle => '导航栏样式';

  @override
  String homeBarStyleEntrySubtitle(String name) {
    return '当前：$name';
  }

  @override
  String get homeBarStyleTabPresets => '预设';

  @override
  String get homeBarStyleTabMaterial => '材质';

  @override
  String get homeBarStyleTabFloating => '悬浮栏';

  @override
  String get homeBarStyleTabItems => '导航项';

  @override
  String get homeBarStyleTabBehavior => '行为';

  @override
  String get homeBarStylePresetGlass => '玻璃';

  @override
  String get homeBarStylePresetGlassDesc => '磨砂悬浮栏，选中项用色块';

  @override
  String get homeBarStylePresetClear => '通透';

  @override
  String get homeBarStylePresetClearDesc => '更通透的玻璃，不加阴影';

  @override
  String get homeBarStylePresetFrosted => '浓雾';

  @override
  String get homeBarStylePresetFrostedDesc => '更浓的磨砂，文字最清楚';

  @override
  String get homeBarStylePresetTinted => '主题色';

  @override
  String get homeBarStylePresetTintedDesc => '玻璃里带一点主题色';

  @override
  String get homeBarStylePresetCompact => '紧凑';

  @override
  String get homeBarStylePresetCompactDesc => '更矮的悬浮栏，只有图标';

  @override
  String get homeBarStyleGlassFooter => '底栏悬浮在页面上，内容从栏下滚过时透出模糊。';

  @override
  String get homeBarStyleHighContrastNote => '系统开启了高对比度，玻璃暂时显示为不透明。';

  @override
  String get homeBarStyleGlassTopBars => '顶栏也用玻璃';

  @override
  String get homeBarStyleGlassTopBarsSubtitle => '日记、日历、探索、设置的顶栏一起变成磨砂';

  @override
  String get homeBarStyleTopBarHairline => '顶栏分隔线';

  @override
  String get homeBarStyleTopBarHairlineSubtitle => '玻璃顶栏底部的细线';

  @override
  String get homeBarStyleBlur => '模糊强度';

  @override
  String get homeBarStyleOpacity => '不透明度';

  @override
  String get homeBarStyleTint => '色调';

  @override
  String get homeBarStyleTintNeutral => '中性';

  @override
  String get homeBarStyleTintTheme => '主题色';

  @override
  String get homeBarStyleTintColor => '玻璃颜色';

  @override
  String get homeBarStyleBorder => '底栏描边';

  @override
  String get homeBarStyleBorderSubtitle => '悬浮栏边缘的细线';

  @override
  String get homeBarStyleOutlineGroup => '描边';

  @override
  String get homeBarStyleLineColor => '颜色';

  @override
  String get homeBarStyleLineColorTheme => '默认';

  @override
  String get homeBarStyleLineColorHighlight => '高光';

  @override
  String get homeBarStyleLineColorPrimary => '主题色';

  @override
  String get homeBarStyleLineCustomColor => '描边颜色';

  @override
  String get homeBarStyleLineWidth => '粗细';

  @override
  String get homeBarStyleShadow => '阴影';

  @override
  String get homeBarStyleShadowSubtitle => '悬浮栏下方的柔和投影';

  @override
  String get homeBarStyleSizeGroup => '尺寸';

  @override
  String get homeBarStyleHeight => '高度';

  @override
  String get homeBarStyleCornerRadius => '圆角';

  @override
  String get homeBarStyleSideMargin => '两侧边距';

  @override
  String get homeBarStyleBottomGap => '离底距离';

  @override
  String get homeBarStyleFabGroup => '新建按钮';

  @override
  String get homeBarStyleFabAbove => '栏上方';

  @override
  String get homeBarStyleFabInline => '栏右侧';

  @override
  String get homeBarStyleFabFooter => '只在日记页出现；放在栏右侧时只显示图标。';

  @override
  String get homeBarStyleLabels => '文字';

  @override
  String get homeBarStyleLabelsAlways => '始终显示';

  @override
  String get homeBarStyleLabelsSelected => '仅选中项';

  @override
  String get homeBarStyleLabelsNever => '不显示';

  @override
  String get homeBarStyleIconSize => '图标大小';

  @override
  String get homeBarStyleLabelGap => '图标与文字间距';

  @override
  String get homeBarStyleIndicator => '选中指示器';

  @override
  String get homeBarStyleIndicatorCapsule => '胶囊';

  @override
  String get homeBarStyleIndicatorBlock => '色块';

  @override
  String get homeBarStyleIndicatorNone => '无';

  @override
  String get homeBarStyleBlockPadding => '色块内边距';

  @override
  String get homeBarStyleItemsFooter => '切换到玻璃时，图标与文字间距会自动收紧一些。';

  @override
  String get homeBarStyleBehaviorFooter => '行为不随预设和样式码改变。';

  @override
  String get homeBarStyleHideOnScroll => '下滑时收起底栏';

  @override
  String get homeBarStyleHideOnScrollSubtitle => '往下浏览时让出空间，往上滑或回到顶部时出现';

  @override
  String get homeBarStyleIndicatorFollows => '指示器跟随滑动';

  @override
  String get homeBarStyleIndicatorFollowsSubtitle => '左右滑动切换页面时，选中指示器跟着手指移动';

  @override
  String get codeBlockPanelTitle => '代码块';

  @override
  String get codeBlockLanguageAuto => '自动识别';

  @override
  String codeBlockLanguageAutoDetected(String language) {
    return '自动 · $language';
  }

  @override
  String get codeBlockLanguageNone => '不指定';

  @override
  String get codeBlockLanguagePlain => '纯文本';

  @override
  String get codeBlockLabelGeneric => '代码';

  @override
  String get codeBlockCopy => '复制代码';

  @override
  String get codeBlockCopied => '已复制代码';

  @override
  String codeBlockCopySemantics(String language) {
    return '复制 $language 代码';
  }

  @override
  String get codeBlockExit => '退出代码块';

  @override
  String get codeBlockToText => '转为正文';

  @override
  String get codeBlockStyleTitle => '代码块样式';

  @override
  String get codeBlockStyleSubtitle => '配色主题、行号、字体与标题栏';

  @override
  String get codeBlockStyleTabTheme => '配色';

  @override
  String get codeBlockStyleTabDisplay => '显示';

  @override
  String get codeBlockStyleTabFont => '字体';

  @override
  String get codeBlockThemeFollowApp => '跟随应用';

  @override
  String get codeBlockBrightnessTitle => '明暗';

  @override
  String get codeBlockBrightnessSystem => '跟随主题';

  @override
  String get codeBlockBrightnessLight => '浅色';

  @override
  String get codeBlockBrightnessDark => '深色';

  @override
  String get codeBlockLineNumbersTitle => '显示行号';

  @override
  String get codeBlockLineNumbersSubtitle => '在每行代码左侧标出行号';

  @override
  String get codeBlockHeaderTitle => '显示标题栏';

  @override
  String get codeBlockHeaderSubtitle => '顶部显示语言名与复制按钮';

  @override
  String get codeBlockAutoDetectTitle => '自动识别语言';

  @override
  String get codeBlockAutoDetectSubtitle => '没有指定语言的代码块自动判断并高亮';

  @override
  String get codeBlockBorderTitle => '显示边框';

  @override
  String get codeBlockBorderSubtitle => '给代码块描一圈细边';

  @override
  String get codeBlockRadiusTitle => '圆角';

  @override
  String get codeBlockFontTitle => '代码字体';

  @override
  String get codeBlockFontMono => '系统等宽';

  @override
  String get codeBlockFontBody => '正文字体';

  @override
  String get codeBlockFontMissing =>
      '所选字体的文件已不在本机，代码暂按系统等宽字体显示；可在正文字体与排版里重新导入，或改选其他字体。';

  @override
  String get codeBlockFontSizeTitle => '字号';

  @override
  String codeBlockFontSizeValue(int percent) {
    return '$percent%';
  }

  @override
  String get codeBlockLineHeightTitle => '行距';

  @override
  String get codeBlockPreviewIntro => '代码块会按语言高亮，行内代码也跟随配色，例如 ';

  @override
  String get diaryEditorLinkUrl => '链接地址';

  @override
  String get diaryEditorInvalidLink => '请输入有效的链接地址';

  @override
  String get diaryEditorRemoveLink => '移除链接';

  @override
  String get diaryEditorMoveBlockUp => '上移';

  @override
  String get diaryEditorMoveBlockDown => '下移';

  @override
  String get diaryEditorBlockHandle => '选择段落，长按拖动';

  @override
  String diaryBlockSelectionCount(int count) {
    return '已选 $count 段';
  }

  @override
  String get diaryBlockSelectionNone => '未选择段落';

  @override
  String get diaryBlockSelectionDone => '完成';

  @override
  String get diaryBlockCopy => '复制';

  @override
  String get diaryBlockCut => '剪切';

  @override
  String get diaryBlockDuplicate => '创建副本';

  @override
  String get diaryBlockMoveToTop => '移到开头';

  @override
  String get diaryBlockMoveToBottom => '移到末尾';

  @override
  String diaryBlockCopied(int count) {
    return '已复制 $count 段';
  }

  @override
  String diaryBlockDeleted(int count) {
    return '已删除 $count 段';
  }

  @override
  String diaryBlockCutDone(int count) {
    return '已剪切 $count 段';
  }

  @override
  String get diaryBlockTurnInto => '转换';

  @override
  String get diaryBlockStyle => '样式';

  @override
  String get diaryBlockSplitLines => '拆分成段落';

  @override
  String get diaryBlockMerge => '合并成一段';

  @override
  String get diaryEditorSelectBlocks => '选择段落';

  @override
  String get diaryEditorParagraph => '正文';

  @override
  String get diaryEditorIndent => '增加缩进';

  @override
  String get diaryEditorOutdent => '减少缩进';

  @override
  String get diaryEditorSlashCommands => '插入区块';

  @override
  String get diaryEditorDivider => '分隔线';

  @override
  String get diaryEditorCallout => '提示块';

  @override
  String get diaryCalloutPlaceholder => '提示';

  @override
  String get diaryCalloutToText => '转为正文';

  @override
  String get diaryCalloutToneDefault => '默认';

  @override
  String get diaryCalloutToneYellow => '黄色';

  @override
  String get diaryCalloutToneGreen => '绿色';

  @override
  String get diaryCalloutToneBlue => '蓝色';

  @override
  String get diaryCalloutToneRed => '红色';

  @override
  String get diaryCalloutTonePurple => '紫色';

  @override
  String get diaryEditorUnsupportedBlock => '暂不支持的内容';

  @override
  String get diaryEditorToggleList => '折叠块';

  @override
  String get diaryToggleListPlaceholder => '折叠块';

  @override
  String get diaryToggleExpand => '展开';

  @override
  String get diaryToggleCollapse => '收起';

  @override
  String get diaryEditorImageWidth => '图片宽度';

  @override
  String get diaryEditorImageHeight => '图片高度';

  @override
  String get diaryEditorHeading1 => '一级标题';

  @override
  String get diaryEditorHeading2 => '二级标题';

  @override
  String get diaryEditorHeading3 => '三级标题';

  @override
  String get diaryEditorHeading4 => '四级标题';

  @override
  String get diaryEditorHeading5 => '五级标题';

  @override
  String get diaryEditorHeading6 => '六级标题';

  @override
  String get diaryToolbarAlign => '对齐';

  @override
  String get diaryToolbarFontSize => '字号';

  @override
  String get diaryToolbarSuperscript => '上标';

  @override
  String get diaryToolbarSubscript => '下标';

  @override
  String get diaryHeadingPanelTitle => '标题';

  @override
  String get diaryHeadingPanelBody => '正文';

  @override
  String get diaryAlignLeft => '左对齐';

  @override
  String get diaryAlignCenter => '居中';

  @override
  String get diaryAlignRight => '右对齐';

  @override
  String get diaryAlignJustify => '两端对齐';

  @override
  String get diaryFontSizeSmall => '小';

  @override
  String get diaryFontSizeNormal => '正文';

  @override
  String get diaryFontSizeLarge => '大';

  @override
  String get diaryFontSizeHuge => '特大';

  @override
  String get diaryEditorCommandGroupText => '文本';

  @override
  String get diaryEditorCommandGroupList => '列表';

  @override
  String get diaryEditorCommandGroupInsert => '插入';

  @override
  String get diaryEditorCommandEmpty => '没有匹配的区块';

  @override
  String get diaryEditorEmptyLineHint => '输入 / 插入区块';

  @override
  String get diaryEditorCommandTypeToFilter => '继续输入即可筛选';

  @override
  String get diaryCardMenuMoveToNotebook => '移动到日记本…';

  @override
  String get diaryCardMenuAddToNotebook => '收进日记本…';

  @override
  String get diaryEditorDropToInsert => '松开以插入';

  @override
  String get dayMoodAwful => '很糟';

  @override
  String get dayMoodBad => '不太好';

  @override
  String get dayMoodMeh => '一般';

  @override
  String get dayMoodGood => '不错';

  @override
  String get dayMoodGreat => '超棒';

  @override
  String get calendarDayMoodTitle => '这天的心情';

  @override
  String get calendarDayMoodClear => '清除';

  @override
  String get calendarDayMoodCleared => '已清除这天的心情';

  @override
  String get calendarDayMoodSaveFailed => '心情没有保存成功，请重试';

  @override
  String get calendarShowDayMoods => '这天的心情';

  @override
  String get calendarShowDayMoodsDescription => '长按日期记下这天的心情，日期格整格换成心情的样子。';

  @override
  String backupOverwriteAllDayMoods(int count) {
    return '$count 天的心情';
  }

  @override
  String backupOverwriteExistingDayMoodsBody(int count) {
    return '本机已记下的 $count 天心情将被文件中的心情替换。';
  }

  @override
  String backupImportModeOverwriteDayMoodsOnly(int count) {
    return '添加新内容，并用文件中的心情替换本机已记下的 $count 天心情';
  }

  @override
  String backupImportModeOverwriteDayMoodsExtra(int count) {
    return '同时替换本机已记下的 $count 天心情';
  }

  @override
  String backupImportDayMoodMergeResult(int added) {
    return '心情：新增 $added 天';
  }

  @override
  String backupImportDayMoodOverwriteResult(int added, int replaced) {
    return '心情：新增 $added 天，覆盖 $replaced 天';
  }

  @override
  String get appSurfaceTitle => '背景与材质';

  @override
  String get appSurfaceEntryDefault => '默认';

  @override
  String get appSurfaceEntryImage => '图片背景';

  @override
  String get appSurfaceEntryColor => '纯色背景';

  @override
  String get appSurfaceEntryGlass => '玻璃组件';

  @override
  String get appSurfaceEntryClassic => '经典组件';

  @override
  String appSurfaceEntryAreas(int count) {
    return '$count 个区域单独设置';
  }

  @override
  String get appSurfaceTabBackground => '背景';

  @override
  String get appSurfaceTabGlass => '玻璃';

  @override
  String get appSurfaceAreaGlobal => '全局';

  @override
  String get appSurfaceAreaDiaries => '日记';

  @override
  String get appSurfaceAreaCalendar => '日历';

  @override
  String get appSurfaceAreaExplore => '探索';

  @override
  String get appSurfaceAreaSettings => '设置';

  @override
  String get appSurfaceAreaEditor => '编辑';

  @override
  String get appSurfaceAreaPreview => '预览';

  @override
  String get appSurfaceAreaOther => '其他';

  @override
  String appSurfaceAreaCustomized(String area) {
    return '$area，已单独设置';
  }

  @override
  String get appSurfaceAreaModeFollow => '跟随全局';

  @override
  String get appSurfaceAreaModeOff => '不显示';

  @override
  String get appSurfaceAreaModeCustom => '单独设置';

  @override
  String appSurfaceAreaFollowNote(String kind) {
    return '跟随全局背景，当前全局为：$kind。';
  }

  @override
  String get appSurfaceAreaOffNote => '这个区域不显示背景，沿用主题底色。';

  @override
  String get appSurfaceAreaCustomNote => '这个区域使用下面单独设置的背景；图片与参数可以分别跟随全局或其他页面。';

  @override
  String get appSurfaceAreaPreviewNote => '仅在预览页纸张为“跟随主题”时显示。';

  @override
  String get appSurfaceGlobalBackground => '全局背景';

  @override
  String get appSurfaceGlobalFooter => '各区域默认跟随全局背景，可在上方选择区域单独设置。';

  @override
  String get appSurfaceAreaBackground => '单独设置的背景';

  @override
  String get appSurfaceKindNone => '无';

  @override
  String get appSurfaceKindColor => '颜色';

  @override
  String get appSurfaceKindImage => '图片';

  @override
  String get appSurfaceBackgroundColor => '背景颜色';

  @override
  String get appSurfaceImagePick => '选择图片';

  @override
  String get appSurfaceImageChange => '更换';

  @override
  String get appSurfaceImageRemove => '移除';

  @override
  String get appSurfaceImageEmpty => '还没有选择图片';

  @override
  String get appSurfaceImageMissing => '图片文件已不存在，请重新选择。';

  @override
  String get appSurfaceImageUnavailable => '无法读取所选图片，请选择存在本机上的图片。';

  @override
  String get appSurfaceImageImportFailed => '图片导入失败，请重试。';

  @override
  String get appSurfaceFocus => '焦点';

  @override
  String get appSurfaceFocusHint => '点按或拖动图片，选择裁切时保留的位置。';

  @override
  String appSurfaceFocusSemantics(String x, String y) {
    return '背景焦点：横向 $x%，纵向 $y%';
  }

  @override
  String get appSurfaceBlur => '模糊';

  @override
  String get appSurfaceScrimLight => '浅色遮罩';

  @override
  String get appSurfaceScrimDark => '深色遮罩';

  @override
  String get appSurfaceFollowSource => '跟随来源';

  @override
  String get appSurfaceFollowSourceHint =>
      '下方“图片”或“参数”打开跟随后，取所选页面当前显示的设置；那边改了，这里跟着变。';

  @override
  String appSurfaceSourceShows(String kind) {
    return '当前：$kind';
  }

  @override
  String get appSurfaceSourceLoop => '它的跟随来源会绕回这里，不能选';

  @override
  String get appSurfaceImageGroup => '图片';

  @override
  String get appSurfaceParamsGroup => '参数';

  @override
  String appSurfaceFollowImage(String source) {
    return '跟随「$source」的图片';
  }

  @override
  String appSurfaceFollowParams(String source) {
    return '跟随「$source」的参数';
  }

  @override
  String get appSurfaceFollowParamsHint => '焦点、模糊与遮罩一起跟随';

  @override
  String appSurfaceFollowImageNote(String source) {
    return '正在使用「$source」的图片';
  }

  @override
  String appSurfaceFollowImageNone(String source) {
    return '「$source」当前没有背景图片';
  }

  @override
  String get appSurfaceGlassStyle => '组件风格';

  @override
  String get appSurfaceGlassClassic => '经典';

  @override
  String get appSurfaceGlassGlass => '玻璃';

  @override
  String get appSurfaceGlassStyleFooter => '玻璃让组件透出下方的背景与内容，经典保持原来的实色。';

  @override
  String get appSurfaceGlassPerComponent => '分别设置';

  @override
  String get appSurfaceComponentTopBars => '二级页顶栏';

  @override
  String get appSurfaceComponentToolbar => '编辑器工具栏';

  @override
  String get appSurfaceComponentSheets => '底部面板';

  @override
  String get appSurfaceComponentDialogs => '对话框';

  @override
  String get appSurfaceComponentCards => '卡片与分组';

  @override
  String get appSurfaceComponentControls => '小控件与提示条';

  @override
  String get appSurfaceOverrideFollow => '跟随';

  @override
  String appSurfaceOverrideFollowResult(String material) {
    return '跟随（$material）';
  }

  @override
  String get appSurfaceGlassTexture => '玻璃质感';

  @override
  String get appSurfaceGlassOpacity => '不透明度';

  @override
  String get appSurfaceGlassTint => '底色';

  @override
  String get appSurfaceGlassTintNeutral => '中性';

  @override
  String get appSurfaceGlassTintTheme => '主题色';

  @override
  String get appSurfaceGlassTintColor => '玻璃底色';

  @override
  String get appSurfaceGlassBorder => '描边';

  @override
  String get appSurfaceGlassBorderSubtitle => '在与底色相近的背景上勾出组件边缘';

  @override
  String get appSurfaceGlassHighContrast => '高对比度模式下玻璃自动改为不透明。';

  @override
  String get appSurfacePreviewLabel => '背景与材质预览';

  @override
  String get appSurfacePreviewCardTitle1 => '午后的散步';

  @override
  String get appSurfacePreviewCardBody1 => '阳光正好，沿着河边走了一大圈。';

  @override
  String get appSurfacePreviewCardTitle2 => '读书笔记';

  @override
  String get appSurfacePreviewCardBody2 => '摘下几句喜欢的话，留着以后再读。';

  @override
  String get diaryToolbarSizeTitle => '工具栏大小';

  @override
  String get diaryToolbarSizeSubtitle => '按钮和图标一起缩放，变大后一排放不下的工具收进「更多」';

  @override
  String get diaryToolbarSizeSmall => '小';

  @override
  String get diaryToolbarSizeStandard => '标准';

  @override
  String get diaryToolbarSizeLarge => '大';

  @override
  String get diaryToolbarSizeExtraLarge => '特大';

  @override
  String get diaryListStyleNumberedTitle => '有序列表样式';

  @override
  String get diaryListStyleBulletedTitle => '无序列表样式';

  @override
  String get diaryListStyleAuto => '自动（按层级变化）';

  @override
  String get diaryListStyleDecimal => '数字 1. 2. 3.';

  @override
  String get diaryListStyleParenthesized => '括号数字 (1) (2) (3)';

  @override
  String get diaryListStyleCircled => '带圈数字 ① ② ③';

  @override
  String get diaryListStyleChinese => '中文数字 一、二、三、';

  @override
  String get diaryListStyleLowerAlpha => '小写字母 a. b. c.';

  @override
  String get diaryListStyleUpperAlpha => '大写字母 A. B. C.';

  @override
  String get diaryListStyleLowerRoman => '小写罗马数字 i. ii. iii.';

  @override
  String get diaryListStyleUpperRoman => '大写罗马数字 I. II. III.';

  @override
  String get diaryListStyleDisc => '实心圆点';

  @override
  String get diaryListStyleCircle => '空心圆';

  @override
  String get diaryListStyleSquare => '方块';

  @override
  String get diaryListStyleDiamond => '菱形';

  @override
  String get diaryListStyleStar => '星形';

  @override
  String get diaryListStyleArrow => '箭头';

  @override
  String get diaryListStyleDash => '短横线';

  @override
  String get diaryListToBulleted => '转为无序列表';

  @override
  String get diaryListToNumbered => '转为有序列表';

  @override
  String get diaryListToText => '转为正文';

  @override
  String get diaryFastScrollPinned => '置顶';

  @override
  String get diaryFastScrollUntitled => '无标题';

  @override
  String get exploreModuleGreeting => '今日问候';

  @override
  String get exploreModuleGreetingDesc => '按时段问候，显示农历节气、今天的记录与每日写作提示';

  @override
  String get exploreModuleOnThisDay => '那年今日';

  @override
  String get exploreModuleOnThisDayDesc => '往年同一天（或前后几天、同月）写下的日记';

  @override
  String get exploreModuleRandomMemory => '随机回顾';

  @override
  String get exploreModuleRandomMemoryDesc => '随机翻出一篇旧日记，可以换一篇';

  @override
  String get exploreModuleRecap => '周期回顾';

  @override
  String get exploreModuleRecapDesc => '本周、本月或今年的概况，并与上一期对比';

  @override
  String get exploreModuleMilestones => '里程碑';

  @override
  String get exploreModuleMilestonesDesc => '篇数、字数、连续天数等里程碑的进度';

  @override
  String get exploreModuleOverview => '数据看板';

  @override
  String get exploreModuleOverviewDesc => '篇数、字数、连续天数等数字，指标可自选';

  @override
  String get exploreModuleHeatmap => '写作热力图';

  @override
  String get exploreModuleHeatmapDesc => '按周排布的每日记录格子';

  @override
  String get exploreModuleRhythm => '写作节奏';

  @override
  String get exploreModuleRhythmDesc => '每月、每周或每天写了多少';

  @override
  String get exploreModuleHabits => '写作习惯';

  @override
  String get exploreModuleHabitsDesc => '你习惯在什么时段、星期几写日记';

  @override
  String get exploreModuleMoodTrend => '心情趋势';

  @override
  String get exploreModuleMoodTrendDesc => '最近每天的心情变化';

  @override
  String get exploreModuleMoodShare => '心情分布';

  @override
  String get exploreModuleMoodShareDesc => '各种心情出现的次数与占比';

  @override
  String get exploreModuleEnergy => '精力趋势';

  @override
  String get exploreModuleEnergyDesc => '最近每天的精力水平';

  @override
  String get exploreModuleTags => '标签';

  @override
  String get exploreModuleTagsDesc => '常用标签，点按即可搜索';

  @override
  String get exploreModuleMedia => '媒体画廊';

  @override
  String get exploreModuleMediaDesc => '日记里的图片';

  @override
  String get exploreModulePlaces => '足迹';

  @override
  String get exploreModulePlacesDesc => '写日记时最常在的地方';

  @override
  String get exploreModuleWeather => '天气';

  @override
  String get exploreModuleWeatherDesc => '写日记时的天气分布';

  @override
  String get exploreModuleAnniversaries => '纪念日';

  @override
  String get exploreModuleAnniversariesDesc => '即将到来的纪念日倒数';

  @override
  String get exploreModuleCapsules => '时间胶囊';

  @override
  String get exploreModuleCapsulesDesc => '等待开启的时间胶囊与最近开启的';

  @override
  String get exploreModuleNotebooks => '日记本';

  @override
  String get exploreModuleNotebooksDesc => '你的日记本书架';

  @override
  String get exploreModuleDrafts => '草稿箱';

  @override
  String get exploreModuleDraftsDesc => '有未写完的草稿时提醒你继续写';

  @override
  String get explorePeriodWeek => '本周';

  @override
  String get explorePeriodMonth => '本月';

  @override
  String get explorePeriodYear => '今年';

  @override
  String get explorePeriodAll => '全部';

  @override
  String get explorePeriodEmpty => '这段时间还没有日记';

  @override
  String get exploreNoModules => '探索页没有显示任何卡片';

  @override
  String get exploreModuleMenuHide => '隐藏此卡片';

  @override
  String exploreModuleHidden(String name) {
    return '已隐藏“$name”';
  }

  @override
  String get exploreGreetingMorning => '早上好';

  @override
  String get exploreGreetingNoon => '中午好';

  @override
  String get exploreGreetingAfternoon => '下午好';

  @override
  String get exploreGreetingEvening => '晚上好';

  @override
  String get exploreGreetingNight => '夜深了';

  @override
  String exploreGreetingToday(int count, String words) {
    return '今天写了 $count 篇 · $words 字';
  }

  @override
  String get exploreGreetingTodayEmpty => '今天还没有写日记';

  @override
  String get exploreGreetingWrite => '写日记';

  @override
  String get exploreGreetingNextPrompt => '换一个';

  @override
  String get explorePrompt01 => '今天让你会心一笑的瞬间是什么？';

  @override
  String get explorePrompt02 => '最近在反复想的一件事是什么？';

  @override
  String get explorePrompt03 => '今天学到了什么新东西？';

  @override
  String get explorePrompt04 => '如果能重来一次，今天你会做哪些不同的选择？';

  @override
  String get explorePrompt05 => '描述一下此刻窗外的样子。';

  @override
  String get explorePrompt06 => '今天吃到的最好吃的东西是什么？';

  @override
  String get explorePrompt07 => '最近读到或听到的话里，哪一句让你印象最深？';

  @override
  String get explorePrompt08 => '今天的你，比昨天多了一点什么？';

  @override
  String get explorePrompt09 => '写一写最近让你感到踏实的一件小事。';

  @override
  String get explorePrompt10 => '这周有什么想对自己说的话？';

  @override
  String get explorePrompt11 => '今天和谁聊了天？聊了些什么？';

  @override
  String get explorePrompt12 => '最近有什么期待的事情？';

  @override
  String get explorePrompt13 => '如果今天的心情是一种天气，会是什么？';

  @override
  String get explorePrompt14 => '写下三件今天值得感恩的小事。';

  @override
  String get explorePrompt15 => '最近有没有一首歌一直在单曲循环？';

  @override
  String get explorePrompt16 => '今天有什么事情比预想的更顺利？';

  @override
  String get explorePrompt17 => '如果给一年后的自己写一句话，你会写什么？';

  @override
  String get explorePrompt18 => '今天在哪里待得最久？那里是什么样子？';

  @override
  String get explorePrompt19 => '最近让你感到疲惫的是什么？可以怎样照顾自己？';

  @override
  String get explorePrompt20 => '最近一次大笑是因为什么？';

  @override
  String get exploreOnThisDayEmpty => '往年的这一天还没有日记，今天写下的会在明年出现在这里。';

  @override
  String get exploreRandomShuffle => '换一篇';

  @override
  String get exploreRandomEmpty => '还没有符合条件的旧日记';

  @override
  String get exploreRecapTitleWeek => '本周回顾';

  @override
  String get exploreRecapTitleMonth => '本月回顾';

  @override
  String get exploreRecapTitleYear => '今年回顾';

  @override
  String get exploreRecapTopMood => '最常见的心情';

  @override
  String get exploreRecapTopTag => '最常用的标签';

  @override
  String exploreRecapMore(int count) {
    return '比上期多 $count';
  }

  @override
  String exploreRecapFewer(int count) {
    return '比上期少 $count';
  }

  @override
  String get exploreRecapSame => '与上期持平';

  @override
  String get exploreMetricEntries => '日记篇数';

  @override
  String get exploreMetricWords => '字数';

  @override
  String get exploreMetricRecordedDays => '记录天数';

  @override
  String get exploreMetricCurrentStreak => '连续打卡';

  @override
  String get exploreMetricLongestStreak => '最长连续';

  @override
  String get exploreMetricAverageWords => '平均每篇';

  @override
  String get exploreMetricPhotos => '照片';

  @override
  String get exploreMetricTags => '用过的标签';

  @override
  String get exploreMetricSpan => '时间跨度';

  @override
  String get exploreMetricTodayWords => '今日字数';

  @override
  String get exploreMilestoneEntries => '篇数';

  @override
  String get exploreMilestoneWords => '字数';

  @override
  String get exploreMilestoneStreak => '最长连续';

  @override
  String get exploreMilestoneDays => '记录天数';

  @override
  String get exploreMilestoneYears => '坚持年数';

  @override
  String exploreMilestoneNext(String target, String remaining) {
    return '下一站 $target · 还差 $remaining';
  }

  @override
  String get exploreMilestoneAllDone => '已全部达成';

  @override
  String exploreMilestoneAchieved(int count) {
    return '已达成 $count 个';
  }

  @override
  String exploreUnitEntries(int count) {
    return '$count 篇';
  }

  @override
  String exploreUnitWords(String words) {
    return '$words 字';
  }

  @override
  String exploreUnitYears(int count) {
    return '$count 年';
  }

  @override
  String exploreUnitTimes(int count) {
    return '$count 次';
  }

  @override
  String exploreHeatmapSummary(int days, int weeks) {
    return '近 $weeks 周里有 $days 天写了日记';
  }

  @override
  String exploreHeatmapDay(String date, int count, String words) {
    return '$date · $count 篇 · $words 字';
  }

  @override
  String exploreHeatmapDayEmpty(String date) {
    return '$date · 没有日记';
  }

  @override
  String get exploreHeatmapLess => '少';

  @override
  String get exploreHeatmapMore => '多';

  @override
  String exploreTotalEntries(int count) {
    return '共 $count 篇';
  }

  @override
  String exploreTotalWords(String words) {
    return '共 $words 字';
  }

  @override
  String get exploreSlotLateNight => '凌晨';

  @override
  String get exploreSlotMorning => '早上';

  @override
  String get exploreSlotForenoon => '上午';

  @override
  String get exploreSlotAfternoon => '下午';

  @override
  String get exploreSlotEvening => '傍晚';

  @override
  String get exploreSlotNight => '夜晚';

  @override
  String exploreHabitsTopSlot(String slot) {
    return '最常在$slot写';
  }

  @override
  String exploreHabitsTopWeekday(String weekday) {
    return '$weekday写得最多';
  }

  @override
  String get exploreHabitsTimeOfDay => '时段';

  @override
  String get exploreHabitsWeekdays => '星期';

  @override
  String exploreLastDays(int days) {
    return '近 $days 天';
  }

  @override
  String exploreMoodAverage(String mood) {
    return '平均心情 $mood';
  }

  @override
  String get exploreMoodTrendEmpty => '最近还没有记录心情';

  @override
  String get exploreMoodShareEmpty => '这段时间还没有记录心情';

  @override
  String exploreEnergyAverage(String value) {
    return '平均 $value';
  }

  @override
  String get exploreEnergyEmpty => '最近还没有记录精力';

  @override
  String get explorePlacesEmpty => '写日记时添加地点后，这里会列出常去的地方。';

  @override
  String get exploreWeatherEmpty => '写日记时记录天气后，这里会显示天气分布。';

  @override
  String get exploreAnniversariesEmpty => '还没有纪念日';

  @override
  String get exploreAnniversariesAdd => '添加纪念日';

  @override
  String get exploreAnniversariesAll => '全部纪念日';

  @override
  String exploreCapsulesWaiting(int count) {
    return '$count 个时间胶囊等待开启';
  }

  @override
  String exploreCapsuleOpensIn(int count) {
    return '$count 天后开启';
  }

  @override
  String get exploreCapsuleOpensToday => '今天开启';

  @override
  String get exploreCapsulesRecent => '最近开启';

  @override
  String get exploreCapsulesEmpty => '还没有时间胶囊。发表日记时可以把它封存起来，寄给未来的自己。';

  @override
  String get exploreNotebooksEmpty => '还没有日记本';

  @override
  String get exploreNotebooksManage => '管理日记本';

  @override
  String exploreDraftsCount(int count) {
    return '草稿箱里有 $count 份草稿';
  }

  @override
  String get exploreDraftsContinue => '继续写';

  @override
  String get exploreDraftsManage => '管理';

  @override
  String get exploreCustomize => '自定义探索页';

  @override
  String get exploreModuleMenuSettings => '卡片设置';

  @override
  String get exploreGroupRecall => '回顾与灵感';

  @override
  String get exploreGroupStats => '统计图表';

  @override
  String get exploreGroupLife => '生活记录';

  @override
  String get exploreGroupLinked => '关联功能';

  @override
  String get exploreLayoutTabPresets => '预设';

  @override
  String get exploreLayoutTabCards => '卡片';

  @override
  String get exploreLayoutTabAppearance => '外观';

  @override
  String get exploreLayoutTabRange => '范围';

  @override
  String get exploreLayoutResetDone => '已恢复默认布局';

  @override
  String get exploreLayoutCardsHint => '拖动右侧手柄调整顺序，点按一行展开它的选项。';

  @override
  String get exploreLayoutCardsShowAll => '全部显示';

  @override
  String get exploreLayoutCardsDefaultOrder => '恢复默认顺序';

  @override
  String get exploreLayoutFeatureOff => '已在功能管理中关闭';

  @override
  String exploreLayoutDragHandle(String name) {
    return '拖动排序：$name';
  }

  @override
  String exploreLayoutShowModule(String name) {
    return '显示“$name”';
  }

  @override
  String exploreLayoutMultiHint(int max) {
    return '按点选的先后排列，最多 $max 个';
  }

  @override
  String get exploreLayoutSpan => '宽窗口下的宽度';

  @override
  String get exploreLayoutSpanFull => '整行';

  @override
  String get exploreLayoutSpanHalf => '半行';

  @override
  String get exploreLayoutPreviewMine => '我的数据';

  @override
  String get exploreLayoutPreviewSample => '示例数据';

  @override
  String get exploreLayoutCustom => '自定义';

  @override
  String get exploreSamplePlaceHome => '家';

  @override
  String get exploreSamplePlaceOffice => '公司';

  @override
  String get settingsExploreLayout => '探索页';

  @override
  String settingsExploreLayoutSubtitle(String name) {
    return '当前：$name';
  }

  @override
  String get exploreOptLunar => '农历与节气';

  @override
  String get exploreOptPrompt => '每日写作提示';

  @override
  String get exploreOptWrite => '“写日记”按钮';

  @override
  String get exploreOptMatch => '匹配方式';

  @override
  String get exploreOptStyle => '样式';

  @override
  String get exploreOptCount => '显示数量';

  @override
  String get exploreOptSource => '抽取范围';

  @override
  String get exploreOptPhotosOnly => '只抽有封面的';

  @override
  String get exploreOptDaily => '每天固定一篇';

  @override
  String get exploreOptRecapPeriod => '回顾周期';

  @override
  String get exploreOptCompare => '与上一期对比';

  @override
  String get exploreOptKinds => '里程碑类别';

  @override
  String get exploreOptAchieved => '显示已达成个数';

  @override
  String get exploreOptMetrics => '指标';

  @override
  String get exploreOptColumns => '列数';

  @override
  String get exploreOptHeatmapSpan => '时间跨度';

  @override
  String get exploreOptBasis => '着色依据';

  @override
  String get exploreOptWeekdayLabels => '星期标签';

  @override
  String get exploreOptLegend => '图例';

  @override
  String get exploreOptUnit => '粒度';

  @override
  String get exploreOptMetric => '统计';

  @override
  String get exploreOptTimeOfDay => '时段分布';

  @override
  String get exploreOptWeekdays => '星期分布';

  @override
  String get exploreOptDays => '时间范围';

  @override
  String get exploreOptChart => '图表';

  @override
  String get exploreOptDayMoods => '合并“这天的心情”';

  @override
  String get exploreOptSort => '排序';

  @override
  String get exploreOptPercent => '显示百分比';

  @override
  String get exploreOptInline => '包括正文里的图片';

  @override
  String get exploreOptRecent => '显示最近开启的';

  @override
  String get exploreValFollowLanguage => '跟随语言';

  @override
  String get exploreValShow => '显示';

  @override
  String get exploreValHide => '隐藏';

  @override
  String get exploreValSameDay => '同月同日';

  @override
  String get exploreValNearby => '前后 3 天';

  @override
  String get exploreValSameMonth => '同月';

  @override
  String get exploreValCarousel => '轮播';

  @override
  String get exploreValList => '列表';

  @override
  String get exploreValAll => '全部';

  @override
  String get exploreValMonthAgo => '一个月前';

  @override
  String get exploreValYearAgo => '一年前';

  @override
  String get exploreValWeeks12 => '12 周';

  @override
  String get exploreValHalfYear => '半年';

  @override
  String get exploreValYear => '一年';

  @override
  String get exploreValEntries => '篇数';

  @override
  String get exploreValWords => '字数';

  @override
  String get exploreValMood => '心情';

  @override
  String get exploreValByMonth => '按月';

  @override
  String get exploreValByWeek => '按周';

  @override
  String get exploreValByDay => '按天';

  @override
  String get exploreValPixels => '像素格';

  @override
  String get exploreValLine => '折线';

  @override
  String get exploreValBars => '柱状';

  @override
  String get exploreValByCount => '按次数';

  @override
  String get exploreValByMood => '按心情';

  @override
  String get exploreValRanking => '排行';

  @override
  String get exploreValManual => '手动顺序';

  @override
  String get exploreValRecent => '最近使用';

  @override
  String get exploreValStrip => '横条';

  @override
  String get exploreValGrid => '宫格';

  @override
  String get exploreValMosaic => '拼贴';

  @override
  String get exploreValIcons => '图标';

  @override
  String get exploreValShelf => '书架顺序';

  @override
  String get exploreValUpdated => '最近更新';

  @override
  String get exploreValByEntries => '按篇数';

  @override
  String get exploreValAuto => '自动';

  @override
  String exploreValColumns(int count) {
    return '$count 列';
  }

  @override
  String get explorePresetBalanced => '均衡';

  @override
  String get explorePresetBalancedDesc => '常用卡片，看一眼就知道最近的状态';

  @override
  String get explorePresetMinimal => '精简';

  @override
  String get explorePresetMinimalDesc => '只留问候、那年今日、数据看板与图片';

  @override
  String get explorePresetDataLover => '数据控';

  @override
  String get explorePresetDataLoverDesc => '统计图表全开：热力图、节奏、习惯、心情与精力';

  @override
  String get explorePresetMemories => '回忆';

  @override
  String get explorePresetMemoriesDesc => '那年今日、随机回顾、周期回顾、胶囊与纪念日';

  @override
  String get explorePresetEverything => '全部显示';

  @override
  String get explorePresetEverythingDesc => '20 张卡片全部打开';

  @override
  String get exploreLookCards => '卡片';

  @override
  String get exploreLookDensity => '密度';

  @override
  String get exploreLookCompact => '紧凑';

  @override
  String get exploreLookStandard => '标准';

  @override
  String get exploreLookRelaxed => '宽松';

  @override
  String get exploreLookRadius => '圆角';

  @override
  String get exploreLookSurface => '卡片表面';

  @override
  String get exploreLookFilled => '填充';

  @override
  String get exploreLookTonal => '色调';

  @override
  String get exploreLookOutlined => '描边';

  @override
  String get exploreLookSurfaceGlassNote => '材质设为玻璃时，卡片一律是玻璃。';

  @override
  String get exploreLookAccent => '强调色';

  @override
  String get exploreLookPrimary => '主色';

  @override
  String get exploreLookSecondary => '次要色';

  @override
  String get exploreLookTertiary => '第三色';

  @override
  String get exploreLookText => '标题与数字';

  @override
  String get exploreLookHeading => '卡片标题';

  @override
  String get exploreLookBadge => '徽章';

  @override
  String get exploreLookIcon => '图标';

  @override
  String get exploreLookTextOnly => '文字';

  @override
  String get exploreLookHidden => '隐藏';

  @override
  String get exploreLookCompactNumbers => '大数字缩写';

  @override
  String get exploreLookCompactNumbersSubtitle => '超过一万时写成 1.2万 这样';

  @override
  String get exploreLookAnimations => '图表动画';

  @override
  String get exploreLookAnimationsSubtitle => '首次出现时图表生长、数字递增';

  @override
  String get exploreLookWide => '宽窗口';

  @override
  String get exploreLookWideFooter => '手机等窄屏上始终是单列。';

  @override
  String get exploreLookColumns => '列数';

  @override
  String get exploreLookFlow => '排布';

  @override
  String get exploreLookRows => '对齐成行';

  @override
  String get exploreLookStaggered => '错落';

  @override
  String get exploreRangeBar => '显示统计范围条';

  @override
  String get exploreRangeBarSubtitle => '在探索页顶部切换本周、本月、今年与全部';

  @override
  String get exploreRangeCurrent => '统计范围';

  @override
  String get exploreRangeFooter =>
      '统计范围影响数据看板、标签、写作习惯、心情分布、足迹和天气；其他卡片有各自的时间范围。';

  @override
  String get exploreSampleWeatherSunny => '晴';

  @override
  String get exploreSampleWeatherCloudy => '多云';

  @override
  String get exploreSampleWeatherOvercast => '阴';

  @override
  String get exploreSampleWeatherRain => '小雨';

  @override
  String get exploreSampleWeatherFog => '雾';

  @override
  String get settingsFeaturesComments => '留言';

  @override
  String get settingsFeaturesCommentsSubtitle => '重读日记时在末尾写下回应，正文保持原样';

  @override
  String diaryCommentsHeading(int count) {
    return '留言 · $count';
  }

  @override
  String get diaryCommentsWrite => '写留言…';

  @override
  String diaryCommentsExpand(int count) {
    return '展开其余 $count 条';
  }

  @override
  String get diaryCommentsCollapse => '收起';

  @override
  String get diaryCommentEdited => '已编辑';

  @override
  String get diaryCommentSameDay => '当天写下';

  @override
  String diaryCommentDaysLater(int count) {
    return '写下后 $count 天';
  }

  @override
  String diaryCommentMonthsLater(int count) {
    return '写下后 $count 个月';
  }

  @override
  String diaryCommentYearsLater(int count) {
    return '写下后 $count 年';
  }

  @override
  String diaryCommentYearsMonthsLater(int years, int months) {
    return '写下后 $years 年 $months 个月';
  }

  @override
  String get diaryCommentSheetNew => '写留言';

  @override
  String get diaryCommentSheetEdit => '编辑留言';

  @override
  String get diaryCommentHint => '想对写下这篇的自己说点什么…';

  @override
  String get diaryCommentMoodLabel => '心情';

  @override
  String get diaryCommentMoodOptional => '可不选';

  @override
  String get diaryCommentCopy => '复制';

  @override
  String get diaryCommentCopied => '已复制留言';

  @override
  String get diaryCommentDeleted => '已删除留言';

  @override
  String get diaryCommentSaveFailed => '留言没有保存成功，请重试';

  @override
  String get diaryCommentActionsHint => '编辑、复制或删除';

  @override
  String get diaryCommentAddImages => '添加图片';

  @override
  String diaryCommentImagesFull(int max) {
    return '最多 $max 张图片';
  }

  @override
  String diaryCommentImagesTruncated(int max) {
    return '一条留言最多 $max 张图片，多选的没有加上';
  }

  @override
  String get diaryCommentImageAddFailed => '图片没有添加成功，请重试';

  @override
  String get diaryCommentImagePermissionDenied => '没有读取图片的权限';

  @override
  String get diaryCommentImageRemove => '移除这张图片';

  @override
  String get diaryCommentImageAdding => '正在添加图片';

  @override
  String diaryCommentImageCount(int count) {
    return '$count 张图片';
  }

  @override
  String diaryCommentImageLabel(int index, int count) {
    return '图片 $index/$count';
  }

  @override
  String diaryCommentsCount(int count) {
    return '$count 条留言';
  }

  @override
  String get diaryPreviewStyleShowComments => '留言数';

  @override
  String get diaryCardStyleShowComments => '留言数';

  @override
  String diarySearchCommentHit(String text) {
    return '留言中提到：$text';
  }

  @override
  String get exploreModuleComments => '最近的留言';

  @override
  String get exploreModuleCommentsDesc => '最近写下的留言与回看统计';

  @override
  String exploreCommentsDiaries(int count) {
    return '回应了 $count 篇';
  }

  @override
  String exploreCommentsAverageGap(int days) {
    return '平均隔 $days 天回看';
  }

  @override
  String get exploreCommentsEmpty => '在日记预览页末尾写下第一条留言';

  @override
  String get exploreSampleComment => '谢谢那时候没有放弃的自己。';

  @override
  String get diaryPreviewSampleComment1 => '回头再看，那天其实没有那么糟。';

  @override
  String get diaryPreviewSampleComment2 => '后来真的去了，比想象中还要好。';

  @override
  String get diaryExportIncludeComments => '包含留言';

  @override
  String get diaryExportCommentsHeading => '留言';

  @override
  String backupImportCommentMergeResult(int added) {
    return '留言：新增 $added 条';
  }

  @override
  String backupImportCommentOverwriteResult(int added, int replaced) {
    return '留言：新增 $added 条，覆盖 $replaced 条';
  }

  @override
  String get diaryEditorTable => '表格';

  @override
  String get diaryTableInsertRowAbove => '上方插入行';

  @override
  String get diaryTableInsertRowBelow => '下方插入行';

  @override
  String get diaryTableInsertColumnLeft => '左侧插入列';

  @override
  String get diaryTableInsertColumnRight => '右侧插入列';

  @override
  String get diaryTableDeleteRow => '删除行';

  @override
  String get diaryTableDeleteColumn => '删除列';

  @override
  String get diaryTableHeaderRow => '表头行';

  @override
  String get diaryTableDelete => '删除表格';

  @override
  String diaryLinkUntitled(String date) {
    return '$date 的日记';
  }

  @override
  String get diaryLinkGroupDiaries => '日记';

  @override
  String get diaryLinkGroupNotebooks => '日记本';

  @override
  String get diaryLinkGroupWeb => '网址';

  @override
  String get diaryLinkEmpty => '没有找到日记或日记本';

  @override
  String get diaryLinkMenuHint => '输入标题或日记本名搜索';

  @override
  String get diaryLinkMenuLabel => '链接日记或日记本';

  @override
  String get diaryLinkSearchDiaries => '搜索日记标题';

  @override
  String get diaryLinkSearchNotebooks => '搜索日记本';

  @override
  String get diaryLinkOpen => '打开';

  @override
  String get diaryLinkRemove => '移除链接';

  @override
  String get diaryLinkCurrentDiary => '链接到日记';

  @override
  String get diaryLinkCurrentNotebook => '链接到日记本';

  @override
  String get diaryLinkMissingDiary => '这篇日记不存在或已删除';

  @override
  String get diaryLinkMissingNotebook => '这本日记本不存在或已删除';

  @override
  String get diaryEditorDiaryCard => '日记卡片';

  @override
  String get diaryEditorNotebookCard => '日记本卡片';

  @override
  String get diaryLinkCardPrivate => '私密日记';

  @override
  String diaryLinkCardSealed(String date) {
    return '$date 解封';
  }

  @override
  String diaryLinkCardNotebookCount(int count) {
    return '$count 篇';
  }

  @override
  String get diaryLinkCardToInline => '转为行内链接';

  @override
  String get diaryLinkCardMenu => '卡片选项';

  @override
  String diaryBacklinksTitle(int count) {
    return '提到这篇的日记 · $count';
  }

  @override
  String diaryBacklinksShowAll(int count) {
    return '全部 $count 篇';
  }

  @override
  String notebookBacklinksChip(int count) {
    return '被 $count 篇日记提到';
  }

  @override
  String get notebookBacklinksTitle => '提到这本的日记';

  @override
  String get lanSyncTitle => '局域网同步';

  @override
  String get lanSyncEntrySubtitleUnpaired => '在同一 Wi-Fi 下的设备之间同步日记';

  @override
  String lanSyncEntrySubtitlePaired(int count, String ago) {
    return '已配对 $count 台 · $ago已同步';
  }

  @override
  String lanSyncEntrySubtitlePairedNever(int count) {
    return '已配对 $count 台 · 还没有同步过';
  }

  @override
  String get lanSyncEntrySubtitleAttention => '有一次同步需要你确认';

  @override
  String get lanSyncDefaultDeviceName => '这台设备';

  @override
  String lanSyncLocalPlatform(String platform) {
    return '本机 · $platform';
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
  String get lanSyncPlatformUnknown => '其他设备';

  @override
  String get lanSyncRenameTooltip => '修改设备名';

  @override
  String get lanSyncRenameTitle => '设备名称';

  @override
  String get lanSyncRenameHint => '附近的设备会看到这个名字';

  @override
  String get lanSyncDiscoverable => '可被发现';

  @override
  String get lanSyncNotDiscoverable => '不可被发现';

  @override
  String get lanSyncDiscoverableToggleHint => '切换是否可被附近的设备发现';

  @override
  String get lanSyncNoNetwork => '未连接局域网';

  @override
  String get lanSyncCopyAddressHint => '复制地址';

  @override
  String get lanSyncAddressCopied => '地址已复制';

  @override
  String get lanSyncScanQr => '扫码连接';

  @override
  String get lanSyncShowQr => '显示二维码';

  @override
  String get lanSyncManualAddress => '手动输入地址';

  @override
  String get lanSyncTroubleshoot => '找不到设备？';

  @override
  String get lanSyncSearchingNearbyJotsy => '正在寻找附近的 Jotsy…';

  @override
  String get lanSyncSectionMyDevices => '我的设备';

  @override
  String lanSyncDeviceCount(int count) {
    return '$count 台';
  }

  @override
  String get lanSyncSectionNearby => '附近的设备';

  @override
  String get lanSyncSearching => '正在寻找';

  @override
  String get lanSyncNearbyEmpty => '附近还没有发现其他 Jotsy，请在另一台设备上也打开这个页面。';

  @override
  String get lanSyncSectionOptions => '同步选项';

  @override
  String get lanSyncAutoSync => '自动同步';

  @override
  String get lanSyncAutoSyncSubtitle => '应用打开时与已配对的设备自动同步';

  @override
  String get lanSyncSyncSettings => '同步设置';

  @override
  String get lanSyncSyncSettingsSubtitle =>
      '两台设备都开启时，外观、编辑器等设置也一并同步。标签顺序和留言、日记本等功能的开启总会同步';

  @override
  String get lanSyncOnline => '在线';

  @override
  String get lanSyncOffline => '离线';

  @override
  String lanSyncSyncedAgo(String ago) {
    return '$ago已同步';
  }

  @override
  String get lanSyncNeverSynced => '还没有同步过';

  @override
  String lanSyncNearbySubtitle(String platform, String address) {
    return '$platform · $address';
  }

  @override
  String get lanSyncNeedsAttention => '需要你确认';

  @override
  String get lanSyncReview => '查看';

  @override
  String get lanSyncSyncButton => '同步';

  @override
  String get lanSyncPair => '配对';

  @override
  String get lanSyncStageConnecting => '正在连接…';

  @override
  String get lanSyncStageComparing => '正在比对…';

  @override
  String get lanSyncStageTransferring => '正在传输…';

  @override
  String get lanSyncStageMerging => '正在合并…';

  @override
  String get lanSyncFirstUseTitle => '还没有配对的设备';

  @override
  String get lanSyncFirstUseBody => '日记在同一局域网的设备之间直接传输，全程加密，不经过任何服务器。';

  @override
  String get lanSyncFirstUseStep1 => '两台设备连上同一个 Wi-Fi';

  @override
  String get lanSyncFirstUseStep2 => '在另一台设备上打开 设置 › 局域网同步';

  @override
  String get lanSyncFirstUseStep3 => '在「附近的设备」里点「配对」，或扫码连接';

  @override
  String lanSyncPortBusyNotice(int port) {
    return '发现端口 $port 被其他程序占用，这台设备暂时找不到别的设备，也无法被发现。仍可手动输入地址或扫码连接。';
  }

  @override
  String get lanSyncTipWifiTitle => '连上同一个 Wi-Fi';

  @override
  String get lanSyncTipWifiBody => '两台设备要在同一个网络里。访客网络或开启了 AP 隔离的路由器会挡住发现。';

  @override
  String get lanSyncTipVpnTitle => 'VPN / 代理';

  @override
  String get lanSyncTipVpnBody =>
      '任一台开着 VPN 或代理（如 Clash）时，局域网的连接可能被转进隧道，互相看不到或连不上。请暂时关闭 VPN，或在代理应用里打开“绕过私有网络 / 局域网”。';

  @override
  String get lanSyncTipOpenPageTitle => '另一台也打开同步页';

  @override
  String get lanSyncTipOpenPageBody => '同步页打开时设备会更频繁地广播自己，更快被找到。';

  @override
  String get lanSyncTipWindowsTitle => 'Windows 防火墙';

  @override
  String get lanSyncTipWindowsBody => '第一次打开时如果弹出防火墙提示，请允许 Jotsy 访问“专用网络”。';

  @override
  String get lanSyncTipLinuxTitle => 'Linux 防火墙';

  @override
  String lanSyncTipLinuxBody(int udpPort, int tcpPort) {
    return '如果开着防火墙，请放行 UDP $udpPort 与 TCP $tcpPort。';
  }

  @override
  String get lanSyncTipFallbackTitle => '还是找不到？';

  @override
  String get lanSyncTipFallbackBody => '直接输入另一台设备的地址，或扫描它显示的二维码。';

  @override
  String get lanSyncManualIntro => '在另一台设备的同步页上可以看到它的地址。连接后需要在两台设备上确认配对。';

  @override
  String get lanSyncManualHostLabel => '地址';

  @override
  String get lanSyncManualHostHint => '例如 192.168.1.23';

  @override
  String get lanSyncManualPortLabel => '端口';

  @override
  String get lanSyncManualHostInvalid => '请输入有效的 IP 地址或主机名';

  @override
  String get lanSyncManualPortInvalid => '端口应在 1–65535 之间';

  @override
  String get lanSyncManualConnect => '连接';

  @override
  String lanSyncAutoSyncApplied(String name, int count) {
    return '已从「$name」同步 $count 篇日记';
  }

  @override
  String lanSyncAutoSyncNeedsAttention(String name) {
    return '与「$name」的同步需要你确认';
  }

  @override
  String lanSyncPairConnecting(String name) {
    return '正在连接 $name…';
  }

  @override
  String lanSyncPairTitleOutgoing(String name) {
    return '与「$name」配对';
  }

  @override
  String lanSyncPairTitleIncoming(String name) {
    return '「$name」请求配对';
  }

  @override
  String get lanSyncPairSubtitle => '请确认两台设备上显示的数字一致';

  @override
  String lanSyncPairCodeSemantics(String first, String second) {
    return '配对码 $first $second';
  }

  @override
  String get lanSyncPairSafetyNote =>
      '配对后两台设备会双向合并全部日记（含私密日记本与回收站）。连接全程加密，不经过任何服务器。';

  @override
  String get lanSyncPairExportBackup => '先导出完整备份';

  @override
  String get lanSyncPairMismatch => '不一致';

  @override
  String get lanSyncPairConfirm => '一致，配对';

  @override
  String get lanSyncPairTimeoutNote => '60 秒内没有确认会自动取消';

  @override
  String get lanSyncPairWaitingPeer => '等待对方确认…';

  @override
  String lanSyncPairSucceeded(String name) {
    return '已与 $name 配对';
  }

  @override
  String get lanSyncPairSyncNow => '立即同步';

  @override
  String get lanSyncPairLater => '稍后';

  @override
  String get lanSyncPairFailedTitle => '配对没有完成';

  @override
  String lanSyncPairAuthReason(String name) {
    return '验证身份后确认与「$name」配对';
  }

  @override
  String get lanSyncPairAuthFailed => '身份验证没有通过，配对还没有确认';

  @override
  String get lanSyncPairAuthUnsupported =>
      '这台设备开启了应用锁或有上锁的日记本，但没有设置锁屏密码，无法验证身份。请先在系统里设置锁屏密码。';

  @override
  String get lanSyncPairFailUnreachable =>
      '连不上对方。请检查地址和端口，并确认两台设备连着同一个 Wi-Fi、没有开着 VPN。';

  @override
  String get lanSyncPairFailConnectionLost => '连接中断了，请重新配对。';

  @override
  String get lanSyncPairFailTimedOut => '没有在 60 秒内确认，配对已取消。';

  @override
  String get lanSyncPairFailDeclined => '对方取消了配对，或两边的数字不一致。';

  @override
  String get lanSyncPairFailCancelled => '配对已取消。';

  @override
  String get lanSyncPairFailIncompatible => '两台设备的 Jotsy 版本不兼容，请把旧的那台升级。';

  @override
  String get lanSyncPairFailUntrusted => '对方拒绝了这次连接，请在两台设备上重新配对。';

  @override
  String get lanSyncPairFailTicketExpired => '二维码已失效，请让对方换一张新码再扫。';

  @override
  String get lanSyncPairFailWriteFailed => '保存配对信息失败，请重试。';

  @override
  String get lanSyncPairFailUnknown => '配对没有完成，请重试。';

  @override
  String get lanSyncPairFailBusy => '正在进行另一次配对，请先完成或关闭它再试。';

  @override
  String get lanSyncQrTitle => '扫码配对';

  @override
  String get lanSyncQrSubtitle => '在另一台手机的 Jotsy 里点「扫码连接」';

  @override
  String get lanSyncQrSemantics => '配对二维码';

  @override
  String lanSyncQrCountdown(String time) {
    return '$time 后换一张新码';
  }

  @override
  String lanSyncQrDeviceLine(String name, String address) {
    return '$name · $address';
  }

  @override
  String get lanSyncQrSingleUse => '二维码只能用一次，扫过即失效';

  @override
  String get lanSyncQrPreparing => '正在准备二维码…';

  @override
  String get lanSyncQrUseCode => '改用核对码配对';

  @override
  String lanSyncQrUseCodeHint(String name) {
    return '在另一台设备的「附近的设备」里找到「$name」并点「配对」';
  }

  @override
  String get lanSyncScanHint => '对准另一台设备上的 Jotsy 二维码';

  @override
  String get lanSyncScanHintDetail => '在那台设备的同步页点「显示二维码」';

  @override
  String get lanSyncScanTorchOn => '打开手电筒';

  @override
  String get lanSyncScanTorchOff => '关闭手电筒';

  @override
  String get lanSyncScanManual => '没有二维码？手动输入地址';

  @override
  String get lanSyncScanNotJotsy => '这不是 Jotsy 的配对二维码';

  @override
  String get lanSyncScanNewerVersion => '这个二维码来自更新版本的 Jotsy，请先升级';

  @override
  String get lanSyncScanMalformed => '二维码不完整，请让对方换一张新码';

  @override
  String get lanSyncScanDeniedTitle => '需要相机权限';

  @override
  String get lanSyncScanDeniedBody =>
      '扫码连接要用相机读取另一台设备上的二维码。请在系统设置里允许 Jotsy 使用相机，或改用手动输入地址。';

  @override
  String get lanSyncScanOpenSettings => '去设置';

  @override
  String get lanSyncScanUnavailableTitle => '相机暂时无法使用';

  @override
  String get lanSyncScanUnavailableBody => '没有找到可用的相机，或相机正被其他应用占用。可以改用手动输入地址。';

  @override
  String get lanSyncFlowLocal => '本机';

  @override
  String lanSyncFlowSent(int count) {
    return '↑ 发送 $count 篇';
  }

  @override
  String lanSyncFlowReceived(int count) {
    return '↓ 接收 $count 篇';
  }

  @override
  String get lanSyncStepConnect => '连接';

  @override
  String get lanSyncStepCompare => '比对';

  @override
  String get lanSyncStepTransfer => '传输';

  @override
  String get lanSyncStepMerge => '合并';

  @override
  String get lanSyncMediaTransferring => '正在传输图片与录音';

  @override
  String lanSyncMediaFiles(int done, int total) {
    return '$done / $total 个文件';
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
    return '$stage，已完成 $percent%';
  }

  @override
  String get lanSyncSummaryTitle => '同步完成';

  @override
  String lanSyncSummarySubtitle(String name, int seconds) {
    return '与 $name · 用时 $seconds 秒';
  }

  @override
  String get lanSyncSummaryReceived => '↓ 收到';

  @override
  String get lanSyncSummarySent => '↑ 发出';

  @override
  String lanSyncSummaryDiaryUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '篇',
    );
    return '$_temp0';
  }

  @override
  String get lanSyncSummaryAdded => '新增';

  @override
  String get lanSyncSummaryUpdated => '更新';

  @override
  String get lanSyncSummaryDeleted => '删除';

  @override
  String get lanSyncSummaryMedia => '媒体';

  @override
  String lanSyncSummaryMediaValue(int count, String size) {
    return '$count 个 · $size';
  }

  @override
  String get lanSyncSummaryOthers => '其他';

  @override
  String lanSyncSummaryConflicts(int count) {
    return '$count 篇日记两边都改过，已保留两份';
  }

  @override
  String get lanSyncSummaryConflictHint => '原日记保留较新的版本';

  @override
  String get lanSyncUntitled => '无标题';

  @override
  String get lanSyncSummaryFootnote => '标签、日记本、留言与纪念日已一并合并';

  @override
  String lanSyncSummaryOtherDetail(String items) {
    return '其他变化：$items';
  }

  @override
  String get lanSyncSummaryDone => '完成';

  @override
  String get lanSyncSummaryUpToDate => '已经是最新的了';

  @override
  String get lanSyncSummaryFailedTitle => '同步没有完成';

  @override
  String get lanSyncSyncFailUnreachable =>
      '连不上对方。请确认两台设备连着同一个 Wi-Fi、没有开着 VPN，且对方打开着 Jotsy。';

  @override
  String get lanSyncSyncFailConnectionLost => '连接中断，已写入的部分下次会自动补齐。';

  @override
  String get lanSyncSyncFailTimedOut => '对方长时间没有回应，已写入的部分下次会自动补齐。';

  @override
  String get lanSyncSyncFailDeclined => '对方拒绝了这次同步。';

  @override
  String get lanSyncSyncFailCancelled => '同步已取消，已写入的部分下次会自动补齐。';

  @override
  String get lanSyncSyncFailIncompatible => '两台设备的 Jotsy 版本不兼容，请把旧的那台升级后再同步。';

  @override
  String get lanSyncSyncFailUntrusted => '对方已不再认识这台设备，请取消配对后重新配对。';

  @override
  String get lanSyncSyncFailTicketExpired => '二维码已失效，请重新扫码连接。';

  @override
  String get lanSyncSyncFailWriteFailed => '写入本机失败，可能是存储空间不足。请清理空间后重试。';

  @override
  String get lanSyncSyncFailUnknown => '同步没有完成，请重试。';

  @override
  String get lanSyncSyncFailBusy => '对方正在编辑日记。等对方关闭编辑页后再同步。';

  @override
  String get lanSyncSyncFailLocalEditing => '这台设备上有正在编辑的页面。请先关闭正在编辑的页面，再同步。';

  @override
  String get lanSyncSyncFailDeferred => '有一条可撤销的提示还开着，这次什么都没有写入。等提示消失后再同步。';

  @override
  String get lanSyncSyncFailNeedsConfirmation => '这次同步需要你确认。在设备列表里点“查看”继续。';

  @override
  String get lanSyncSyncReasonUnreachable => '连不上对方';

  @override
  String get lanSyncSyncReasonConnectionLost => '连接中断';

  @override
  String get lanSyncSyncReasonTimedOut => '对方没有回应';

  @override
  String get lanSyncSyncReasonDeclined => '对方拒绝了同步';

  @override
  String get lanSyncSyncReasonCancelled => '已取消';

  @override
  String get lanSyncSyncReasonIncompatible => '版本不兼容';

  @override
  String get lanSyncSyncReasonUntrusted => '对方不再认识本机';

  @override
  String get lanSyncSyncReasonTicketExpired => '二维码已失效';

  @override
  String get lanSyncSyncReasonWriteFailed => '写入本机失败';

  @override
  String get lanSyncSyncReasonUnknown => '同步失败';

  @override
  String get lanSyncSyncReasonBusy => '对方正在编辑';

  @override
  String get lanSyncSyncReasonLocalEditing => '本机正在编辑';

  @override
  String get lanSyncSyncReasonDeferred => '撤销提示还开着';

  @override
  String get lanSyncSyncReasonNeedsConfirmation => '需要确认';

  @override
  String lanSyncConflictCopySuffix(String device) {
    return '（冲突副本 · $device）';
  }

  @override
  String get lanSyncChooseSideTitle => '以哪边为准';

  @override
  String lanSyncChooseSideBody(String name, int count) {
    return '有 $count 篇日记在本机和「$name」上都改过，要怎么合并？';
  }

  @override
  String lanSyncChooseSideBodyItems(String name, String items) {
    return '以下内容在本机和「$name」上都改过：$items。要怎么合并？';
  }

  @override
  String get lanSyncItemDiaries => '日记';

  @override
  String get lanSyncItemTags => '标签';

  @override
  String get lanSyncItemNotebooks => '日记本';

  @override
  String get lanSyncItemComments => '留言';

  @override
  String get lanSyncItemTemplates => '模板';

  @override
  String get lanSyncItemAnniversaries => '纪念日';

  @override
  String get lanSyncItemDayMoods => '这天的心情';

  @override
  String get lanSyncItemTodos => '待办';

  @override
  String get lanSyncItemSettings => '设置';

  @override
  String lanSyncItemCount(String label, int count) {
    return '$label $count';
  }

  @override
  String get lanSyncChooseKeepBoth => '保留两份（推荐）';

  @override
  String get lanSyncChooseKeepBothDesc => '较新的版本留在原日记，另一份存为冲突副本';

  @override
  String get lanSyncChoosePreferLocal => '以本机为准';

  @override
  String get lanSyncChoosePreferLocalDesc => '用本机的版本覆盖对方的改动';

  @override
  String get lanSyncChoosePreferPeer => '以对方为准';

  @override
  String lanSyncChoosePreferPeerDesc(String name) {
    return '用「$name」的版本覆盖本机的改动';
  }

  @override
  String get lanSyncChooseSideNote => '三种方式都不会删除任何日记';

  @override
  String get lanSyncContinueSync => '继续同步';

  @override
  String get lanSyncDeletionTitle => '要彻底删除日记吗';

  @override
  String lanSyncDeletionBodyPeer(String name, int count) {
    return '这次同步会在「$name」上彻底删除 $count 篇日记（它们已在本机的回收站里清空）';
  }

  @override
  String lanSyncDeletionBodyLocal(String name, int count) {
    return '这次同步会在本机上彻底删除 $count 篇日记（它们已在「$name」的回收站里清空）';
  }

  @override
  String get lanSyncDeletionSync => '同步删除';

  @override
  String get lanSyncDeletionSyncDesc => '两台设备上都不再保留这些日记';

  @override
  String get lanSyncDeletionKeep => '保留，并恢复到另一台';

  @override
  String get lanSyncDeletionKeepDesc => '这些日记会恢复到清空它们的那台设备上';

  @override
  String get lanSyncDeviceTitle => '设备详情';

  @override
  String get lanSyncInfoLastSync => '上次同步';

  @override
  String get lanSyncInfoPairedAt => '配对于';

  @override
  String get lanSyncInfoAddress => '地址';

  @override
  String get lanSyncInfoNever => '还没有';

  @override
  String get lanSyncInfoNoAddress => '未知';

  @override
  String get lanSyncDeviceOffline => '设备不在线';

  @override
  String get lanSyncOfflineUseLastAddress => '对方不在线，会按上次的地址连接';

  @override
  String get lanSyncPeerAutoSyncSubtitle => '应用打开时自动与这台设备同步';

  @override
  String get lanSyncPeerAutoSyncGlobalOff => '“同步选项”里的自动同步已关闭，这里暂不生效';

  @override
  String get lanSyncAliasTitle => '备注名';

  @override
  String get lanSyncAliasNotSet => '未设置';

  @override
  String get lanSyncAliasLocalOnly => '只在本机显示';

  @override
  String lanSyncAliasDialogHint(String name) {
    return '留空则显示「$name」';
  }

  @override
  String get lanSyncHistoryTitle => '同步记录';

  @override
  String get lanSyncHistoryEmpty => '还没有与这台设备同步过';

  @override
  String get lanSyncHistoryAutomatic => '自动';

  @override
  String lanSyncHistoryDuration(int seconds) {
    return '$seconds 秒';
  }

  @override
  String lanSyncHistoryReceived(int count) {
    return '↓ 收到 $count 篇';
  }

  @override
  String lanSyncHistorySent(int count) {
    return '↑ 发出 $count 篇';
  }

  @override
  String lanSyncHistoryOthers(int count) {
    return '其他 $count 项';
  }

  @override
  String lanSyncHistoryMedia(String size) {
    return '媒体 $size';
  }

  @override
  String lanSyncHistoryConflicts(int count) {
    return '$count 篇冲突副本';
  }

  @override
  String get lanSyncForget => '取消配对';

  @override
  String lanSyncForgetTitle(String name) {
    return '取消与「$name」的配对？';
  }

  @override
  String get lanSyncForgetBody => '两台设备上的日记都不会被删除。之后要同步需要重新配对。';

  @override
  String get settingsFeaturesAi => 'AI 助手';

  @override
  String get settingsFeaturesAiSubtitle => '用你自己的 AI 接口写作、回应、回顾与对话';

  @override
  String get aiPersonaAssistantName => '日记助手';

  @override
  String get aiPersonaAssistantDesc => '客观清楚，适合问答与总结';

  @override
  String get aiPersonaAssistantPrompt =>
      '你是用户的日记助手，可以读到用户提供的日记。回答要以日记内容为依据，客观、清楚、有条理；不确定的地方直说，不要编造日记里没有的事。';

  @override
  String get aiPersonaListenerName => '温暖倾听者';

  @override
  String get aiPersonaListenerDesc => '先接住情绪，再温柔回应';

  @override
  String get aiPersonaListenerPrompt =>
      '你是一位温暖、耐心的倾听者。读完用户的日记后，先表达理解、接住其中的情绪，再温柔地回应。不评判、不说教，少给建议，多一些共情与肯定；可以在结尾提一个温和的问题，引导用户多想一点。';

  @override
  String get aiPersonaFriendName => '知心朋友';

  @override
  String get aiPersonaFriendDesc => '像老朋友一样轻松聊天';

  @override
  String get aiPersonaFriendPrompt =>
      '你是用户认识多年的好朋友，说话自然、轻松、真诚，会开玩笑也会认真。像朋友读了对方的日记后回一段话那样回应：聊聊你注意到的细节，说说你的感受，需要时再给点实在的建议。';

  @override
  String get aiPersonaCoachName => '成长教练';

  @override
  String get aiPersonaCoachDesc => '看到你的进步，找到下一步';

  @override
  String get aiPersonaCoachPrompt =>
      '你是一位积极务实的成长教练。从日记中找出用户的努力、进步与值得肯定的地方，指出可以改进的模式，并给出一到三个具体、可执行的小行动。语气鼓励但不空洞。';

  @override
  String get aiPersonaAnalystName => '理性分析师';

  @override
  String get aiPersonaAnalystDesc => '冷静梳理来龙去脉';

  @override
  String get aiPersonaAnalystPrompt =>
      '你是一位冷静、理性的分析者。帮助用户梳理日记中事情的来龙去脉、背后的原因与可能的选择，区分事实与感受，指出可能被忽略的角度。表达简洁、有结构。';

  @override
  String get aiPersonaCounselorName => '心理咨询风格';

  @override
  String get aiPersonaCounselorDesc => '用提问帮你看清自己的感受';

  @override
  String get aiPersonaCounselorPrompt =>
      '你以心理咨询师常用的方式回应：倾听、复述与澄清，用开放式问题帮助用户觉察自己的情绪与需要，不急于下结论或给建议。你不是专业的心理治疗；如果日记中出现伤害自己或他人的想法，要温和地建议用户向身边的人或专业机构求助。';

  @override
  String get aiPersonaPoetName => '诗人';

  @override
  String get aiPersonaPoetDesc => '用诗意的语言回应这一天';

  @override
  String get aiPersonaPoetPrompt =>
      '你是一位温柔的诗人。用富有意象、有诗意而不晦涩的语言回应用户的日记，可以写一小段散文诗或几行短诗，捕捉这一天的情绪与画面。';

  @override
  String get aiPersonaPhilosopherName => '哲学家';

  @override
  String get aiPersonaPhilosopherDesc => '从更大的视角想一想';

  @override
  String get aiPersonaPhilosopherPrompt =>
      '你是一位亲切的哲学家。从日记里具体的小事出发，联系到更大的问题（意义、选择、时间、关系），引用恰当的思想或比喻，但保持平易近人，最后回到用户自己的生活。';

  @override
  String get aiPersonaFutureSelfName => '未来的自己';

  @override
  String get aiPersonaFutureSelfDesc => '十年后的你写来的回信';

  @override
  String get aiPersonaFutureSelfPrompt =>
      '你是十年后的用户本人，正在重读这篇日记。用第一人称“我”给过去的自己写一段回信：温柔、了解一切来龙去脉，带着时间带来的释然与智慧，但不要编造具体的未来事件。';

  @override
  String get aiPersonaRoastName => '毒舌损友';

  @override
  String get aiPersonaRoastDesc => '嘴上不饶人，心里向着你';

  @override
  String get aiPersonaRoastPrompt =>
      '你是嘴上毒舌、心里向着用户的损友。用幽默、夸张、调侃的方式吐槽日记里的事，但不挖苦用户真正的痛处，不涉及外貌、身份等敏感话题；结尾要露出关心。';

  @override
  String get aiActionContinue => '续写';

  @override
  String get aiActionContinuePrompt =>
      '顺着下面这段日记的内容和语气，自然地往下写一段（约 100 到 200 字）。只写新的内容，不要重复原文。';

  @override
  String get aiActionPolish => '润色';

  @override
  String get aiActionPolishPrompt =>
      '润色下面的文字：让表达更流畅自然，修正不通顺的地方，保留原意、语气和第一人称视角，不要扩写。';

  @override
  String get aiActionExpand => '扩写';

  @override
  String get aiActionExpandPrompt =>
      '扩写下面的文字：补充细节、感受与画面，让内容更丰满，长度大约增加一倍，保持原来的语气和视角。';

  @override
  String get aiActionShorten => '精简';

  @override
  String get aiActionShortenPrompt => '精简下面的文字：保留关键信息和情绪，删去重复与啰嗦的部分，长度减半左右。';

  @override
  String get aiActionProofread => '纠错';

  @override
  String get aiActionProofreadPrompt => '修正下面文字中的错别字、标点和语法错误，其余内容保持原样，不要改写。';

  @override
  String get aiActionToneFormal => '正式一点';

  @override
  String get aiActionToneFormalPrompt => '把下面的文字改写得更正式、得体，保留原意。';

  @override
  String get aiActionToneCasual => '轻松一点';

  @override
  String get aiActionToneCasualPrompt => '把下面的文字改写得更轻松、口语化，像在和朋友聊天，保留原意。';

  @override
  String get aiActionToneWarm => '温暖一点';

  @override
  String get aiActionToneWarmPrompt => '把下面的文字改写得更温暖、柔和，多一些善意与体贴，保留原意。';

  @override
  String get aiActionToneHumor => '幽默一点';

  @override
  String get aiActionToneHumorPrompt => '把下面的文字改写得更幽默风趣，加一点俏皮的比喻或自嘲，保留原意。';

  @override
  String get aiActionToneLiterary => '文艺一点';

  @override
  String get aiActionToneLiteraryPrompt =>
      '把下面的文字改写得更有文学性：用更细腻的描写和恰当的修辞，但不要堆砌辞藻，保留原意。';

  @override
  String get aiActionTranslate => '翻译';

  @override
  String get aiActionTranslatePrompt =>
      '翻译下面的文字。如果原文主要是中文，就翻译成英文；否则翻译成简体中文。只输出译文。';

  @override
  String get aiActionSummarize => '总结';

  @override
  String get aiActionSummarizePrompt => '用两三句话总结下面这段文字的要点。';

  @override
  String get aiActionBulletPoints => '列成要点';

  @override
  String get aiActionBulletPointsPrompt =>
      '把下面的文字整理成条理清楚的要点列表（Markdown 无序列表），每条简短。';

  @override
  String get aiActionExtractTodos => '提取待办';

  @override
  String get aiActionExtractTodosPrompt =>
      '找出下面文字中提到的待办、计划或需要跟进的事，整理成 Markdown 任务列表，每行以“- [ ] ”开头。如果没有，就只回复一行说明没有找到。';

  @override
  String get aiActionPoem => '写成小诗';

  @override
  String get aiActionPoemPrompt => '把下面的内容写成一首简短的现代诗（4 到 12 行），保留其中的情绪与画面。';

  @override
  String get aiErrorNotConfigured => '还没有可用的 AI 模型，请先在 设置 → AI 助手 里添加服务商。';

  @override
  String get aiErrorNetwork => '连不上 AI 服务，请检查网络、接口地址或代理。';

  @override
  String get aiErrorTimeout => 'AI 服务响应超时。';

  @override
  String get aiErrorUnauthorized => 'API 密钥无效或没有填写。';

  @override
  String get aiErrorForbidden => '这个密钥没有该模型的权限，或服务在当前地区不可用。';

  @override
  String get aiErrorModelNotFound => '找不到模型或接口，请检查模型名与接口地址。';

  @override
  String get aiErrorRateLimited => '请求太频繁，请稍后再试。';

  @override
  String get aiErrorQuota => '账户余额或额度不足。';

  @override
  String get aiErrorContextTooLong =>
      '内容超过了模型能处理的长度。可以在 AI 隐私设置里调低字数上限，或换一个上下文更长的模型。';

  @override
  String get aiErrorContentFiltered => 'AI 服务按内容策略拒绝了这次请求。';

  @override
  String get aiErrorBadRequest => 'AI 服务不接受这次请求，请检查服务商的高级设置。';

  @override
  String get aiErrorServer => 'AI 服务出错或过载，请稍后再试。';

  @override
  String get aiErrorBadResponse => '无法识别返回的内容，接口地址可能填成了网页地址。';

  @override
  String get aiErrorCancelled => '已停止';

  @override
  String get aiErrorDetails => '查看详情';

  @override
  String get aiErrorOpenSettings => '去设置';

  @override
  String get aiSettingsTitle => 'AI 助手';

  @override
  String get aiSettingsEntrySubtitle => '服务商、模型、人设与隐私';

  @override
  String get aiSettingsFooter =>
      '开发者收不到任何内容：请求从这台设备直接发往你配置的服务商；API 密钥只保存在本机，不会进入备份或同步。';

  @override
  String get aiStatusNotConfiguredTitle => '还没有配置 AI 服务';

  @override
  String get aiStatusNotConfiguredBody =>
      '添加一个服务商并填入 API 密钥，AI 功能就会出现在编辑器、预览页和首页。内容只会发到你自己配置的服务。';

  @override
  String get aiStatusAddProvider => '添加服务商';

  @override
  String get aiStatusDefaultModel => '默认模型';

  @override
  String get aiStatusTest => '测试连接';

  @override
  String get aiStatusTesting => '正在测试…';

  @override
  String aiStatusTestOk(int ms) {
    return '连接成功 · $ms 毫秒';
  }

  @override
  String get aiGroupService => '服务';

  @override
  String get aiProvidersTitle => '服务商';

  @override
  String aiProvidersCount(int count) {
    return '$count 个服务商';
  }

  @override
  String get aiProvidersEmpty => '还没有添加';

  @override
  String get aiRoutingTitle => '模型分配';

  @override
  String get aiRoutingSubtitle => '为不同的功能选择不同的模型';

  @override
  String get aiGroupFeatures => '功能';

  @override
  String get aiGroupFeaturesFooter => '关闭只隐藏入口，已有的 AI 记录保留。';

  @override
  String get aiModuleWriting => '写作助手';

  @override
  String get aiModuleWritingSubtitle => '编辑器里续写、润色、改语气、翻译与自定义指令';

  @override
  String get aiModuleSuggest => '智能填写';

  @override
  String get aiModuleSuggestSubtitle => '生成标题，推荐标签与心情';

  @override
  String get aiModuleReply => '读后回应';

  @override
  String get aiModuleReplySubtitle => '在预览页让 AI 读完这篇日记后回应你';

  @override
  String get aiModulePrompts => '写作灵感';

  @override
  String get aiModulePromptsSubtitle => '不知道写什么时，给你几个问题';

  @override
  String get aiModuleRecap => '回顾与洞察';

  @override
  String get aiModuleRecapSubtitle => '按周、月、年或日记本生成总结';

  @override
  String get aiModuleChat => '对话与操作';

  @override
  String get aiModuleChatSubtitle => '问问你的日记，也能让 AI 帮你查找、统计、写日记、整理与修改设置';

  @override
  String get aiModuleVision => '图片理解';

  @override
  String get aiModuleVisionSubtitle => '把日记里的图片、对话里发的图片一起发给模型；模型不认图片时自动只发文字';

  @override
  String get aiOptionTitleButton => '标题旁显示“生成标题”';

  @override
  String get aiOptionAutoSuggest => '进入发布页时自动建议';

  @override
  String get aiOptionAutoSuggestSubtitle => '会发送一次正文来建议标题、标签与心情；点选后才会填入';

  @override
  String get aiOptionAutoReply => '发表后自动回应';

  @override
  String get aiOptionAutoReplySubtitle => '每发表一篇新日记就发送一次，自动生成回应';

  @override
  String get aiOptionPromptsStrip => '新建日记时显示灵感条';

  @override
  String get aiOptionPromptsStripSubtitle => '点了才会生成';

  @override
  String get aiOptionPromptsRecent => '参考最近的日记';

  @override
  String get aiOptionPromptsRecentSubtitle => '生成时附上最近几篇日记的摘录，问题更贴近你';

  @override
  String get aiOptionPromptStyle => '插入样式';

  @override
  String get aiPromptStyleCallout => '提示块';

  @override
  String get aiPromptStyleQuote => '引用';

  @override
  String get aiPromptStyleHeading => '小标题';

  @override
  String get aiOptionRecapSections => '回顾默认包含';

  @override
  String get aiRecapSectionMood => '心情走势';

  @override
  String get aiRecapSectionEvents => '重要的事';

  @override
  String get aiRecapSectionPeople => '身边的人';

  @override
  String get aiRecapSectionGratitude => '值得感恩';

  @override
  String get aiRecapSectionGrowth => '成长与变化';

  @override
  String get aiRecapSectionQuotes => '金句摘录';

  @override
  String get aiRecapSectionSuggestions => '下一步建议';

  @override
  String get aiOptionRetrieval => '查找相关日记';

  @override
  String get aiOptionRetrievalSubtitle =>
      '智能：先理解问题再查找；关键词：只按问题里的词查找；最近：只看最近一段时间';

  @override
  String get aiRetrievalSmart => '智能';

  @override
  String get aiRetrievalKeyword => '关键词';

  @override
  String get aiRetrievalRecent => '最近';

  @override
  String get aiOptionRecentDays => '最近多少天';

  @override
  String aiDays(int count) {
    return '$count 天';
  }

  @override
  String get aiOptionMaxCitations => '最多参考';

  @override
  String aiEntries(int count) {
    return '$count 篇';
  }

  @override
  String get aiOptionShowReasoning => '显示思考过程';

  @override
  String get aiOptionShowTokens => '显示用量';

  @override
  String get aiOptionAutoTitle => '自动给对话起标题';

  @override
  String get aiOptionVisionImages => '每次最多发送';

  @override
  String aiPhotos(int count) {
    return '$count 张';
  }

  @override
  String get aiOptionVisionSize => '图片尺寸';

  @override
  String get aiVisionSizeSmall => '小';

  @override
  String get aiVisionSizeMedium => '中';

  @override
  String get aiVisionSizeLarge => '大';

  @override
  String get aiGroupPersonal => '个性化';

  @override
  String get aiPersonasTitle => '人设';

  @override
  String get aiPersonasSubtitle => '回应、对话与回顾用谁的口吻';

  @override
  String get aiActionsTitle => '写作指令';

  @override
  String get aiActionsSubtitle => '排序、隐藏、改写提示词，或添加自己的指令';

  @override
  String get aiProfileTitle => '关于我与文风';

  @override
  String get aiProfileSubtitle => '让 AI 更了解你（可选）';

  @override
  String get aiOutputLanguage => '回答语言';

  @override
  String get aiLanguageFollowDiary => '跟随日记';

  @override
  String get aiLanguageFollowApp => '跟随界面';

  @override
  String get aiLanguageCustom => '指定';

  @override
  String get aiLanguageCustomHint => '如：English、日本語';

  @override
  String get aiResponseLength => '回答长度';

  @override
  String get aiLengthShort => '简短';

  @override
  String get aiLengthMedium => '适中';

  @override
  String get aiLengthLong => '详细';

  @override
  String get aiCreativity => '创造力';

  @override
  String get aiCreativitySubtitle => '只对接受温度参数的服务商生效';

  @override
  String get aiCreativityPrecise => '严谨';

  @override
  String get aiCreativityBalanced => '平衡';

  @override
  String get aiCreativityCreative => '发散';

  @override
  String get aiGroupPrivacy => '隐私与用量';

  @override
  String get aiPrivacyTitle => '隐私';

  @override
  String get aiPrivacySubtitle => '发送哪些信息、排除哪些日记';

  @override
  String get aiUsageTitle => '用量';

  @override
  String get aiUsageSubtitle => '本机记录的请求次数与 token';

  @override
  String get aiProvidersFooter => '没有指定默认模型时，用第一个可用的服务商，可以在“模型分配”里改。';

  @override
  String aiProviderModelsCount(int count) {
    return '$count 个模型';
  }

  @override
  String get aiProviderDisabled => '已停用';

  @override
  String get aiProviderNoKey => '未填密钥';

  @override
  String get aiPresetSheetTitle => '选择服务商';

  @override
  String get aiPresetGroupChina => '国内服务';

  @override
  String get aiPresetGroupInternational => '国际服务';

  @override
  String get aiPresetGroupLocal => '本地运行';

  @override
  String get aiPresetGroupCustom => '自定义接口';

  @override
  String get aiPresetNameDashscope => '通义千问（阿里云百炼）';

  @override
  String get aiPresetNameMoonshot => 'Kimi（月之暗面）';

  @override
  String get aiPresetNameZhipu => '智谱 GLM';

  @override
  String get aiPresetNameVolcengine => '豆包（火山方舟）';

  @override
  String get aiPresetNameSiliconflow => '硅基流动';

  @override
  String get aiPresetNameHunyuan => '腾讯混元';

  @override
  String get aiPresetNameCustomOpenAi => 'OpenAI 兼容接口';

  @override
  String get aiPresetNameCustomAnthropic => 'Anthropic 兼容接口';

  @override
  String get aiPresetNameCustomGemini => 'Gemini 接口';

  @override
  String get aiProtocolOpenAi => 'OpenAI 兼容';

  @override
  String get aiProtocolAnthropic => 'Anthropic（Claude）';

  @override
  String get aiProtocolGemini => 'Google Gemini';

  @override
  String get aiProviderEditTitleNew => '添加服务商';

  @override
  String get aiProviderEditTitle => '编辑服务商';

  @override
  String get aiProviderName => '名称';

  @override
  String get aiProviderProtocol => '接口格式';

  @override
  String get aiProviderBaseUrl => '接口地址';

  @override
  String get aiProviderBaseUrlHint => '例如 https://api.example.com/v1';

  @override
  String get aiProviderApiKey => 'API 密钥';

  @override
  String get aiProviderApiKeyOptional => 'API 密钥（本地服务可不填）';

  @override
  String get aiProviderGetKey => '获取密钥';

  @override
  String get aiProviderLocalHint =>
      '手机上连接电脑里的 Ollama / LM Studio 时，请把 localhost 换成电脑的局域网地址，并让服务监听 0.0.0.0。';

  @override
  String get aiProviderModels => '模型';

  @override
  String get aiProviderFetchModels => '获取模型列表';

  @override
  String get aiProviderAddModel => '手动添加';

  @override
  String get aiProviderModelsEmpty => '还没有模型。点“获取模型列表”从服务商读取，或手动添加模型名。';

  @override
  String get aiProviderModelIdHint => '模型名，如 deepseek-chat';

  @override
  String get aiModelVision => '看图';

  @override
  String get aiModelReasoning => '思考';

  @override
  String get aiModelEditTitle => '模型设置';

  @override
  String get aiModelDisplayName => '显示名（可选）';

  @override
  String get aiModelVisionToggle => '支持图片输入';

  @override
  String get aiModelReasoningToggle => '请求思考过程';

  @override
  String get aiModelReasoningSubtitle => '让模型返回思考过程；模型不支持时自动去掉再试';

  @override
  String get aiModelToolsToggle => '支持工具调用';

  @override
  String get aiModelToolsSubtitle => '让 AI 助手直接操作应用；模型不支持时自动改用检索问答';

  @override
  String get aiToolGetAppContext => '查看今天与应用状态';

  @override
  String get aiToolReadGuide => '查阅使用指南';

  @override
  String aiPromptAgentGuide(String index) {
    return '下面是使用指南的目录。用户问怎么用、在哪里、能不能做某事时，先用 read_guide 读相关文章再据实回答，不编造界面上没有的东西。\n$index';
  }

  @override
  String get aiHubQuickHelp => 'Jotsy 有哪些好用的功能？';

  @override
  String aiToolOpenPage(String page) {
    return '前往：$page';
  }

  @override
  String get aiToolPageUnavailable => '这个页面现在不可用（功能已关闭或本设备不支持）';

  @override
  String get aiToolSearchDiaries => '搜索日记';

  @override
  String aiToolSearchDiariesFor(String query) {
    return '搜索日记：$query';
  }

  @override
  String aiToolFoundEntries(int count) {
    return '找到 $count 篇';
  }

  @override
  String aiToolReadDiaries(int count) {
    return '读取 $count 篇日记';
  }

  @override
  String aiToolReadEntries(int count) {
    return '读了 $count 篇';
  }

  @override
  String get aiToolDiaryStats => '统计日记';

  @override
  String aiToolStatsEntries(int count) {
    return '共 $count 篇';
  }

  @override
  String get aiToolListTags => '查看标签';

  @override
  String aiToolTagCount(int count) {
    return '$count 个标签';
  }

  @override
  String get aiToolListNotebooks => '查看日记本';

  @override
  String aiToolNotebookCount(int count) {
    return '$count 个日记本';
  }

  @override
  String get aiToolCalendarDay => '查看今天的日历';

  @override
  String aiToolCalendarDayOf(String date) {
    return '查看 $date 的日历';
  }

  @override
  String get aiToolListTodos => '查看待办';

  @override
  String aiToolTodoCount(int count) {
    return '$count 项待办';
  }

  @override
  String get aiToolListAnniversaries => '查看纪念日';

  @override
  String aiToolAnniversaryCount(int count) {
    return '$count 个纪念日';
  }

  @override
  String get aiToolCreateDiary => '新建日记';

  @override
  String aiToolCreateDiaryNamed(String title) {
    return '新建日记：$title';
  }

  @override
  String aiToolDiaryCreated(String name) {
    return '已写好「$name」';
  }

  @override
  String get aiToolAppendDiary => '在日记末尾添加内容';

  @override
  String get aiToolUpdateDiary => '修改日记信息';

  @override
  String aiToolDiaryChanged(String name) {
    return '已修改「$name」';
  }

  @override
  String aiToolTagDiaries(int count) {
    return '给 $count 篇日记加减标签';
  }

  @override
  String aiToolEntriesChanged(int count) {
    return '改了 $count 篇';
  }

  @override
  String get aiToolPinDiaries => '置顶日记';

  @override
  String get aiToolUnpinDiaries => '取消置顶';

  @override
  String get aiToolArchiveDiaries => '归档日记';

  @override
  String get aiToolUnarchiveDiaries => '取消归档';

  @override
  String aiToolTrashDiaries(int count) {
    return '把 $count 篇日记移入回收站';
  }

  @override
  String aiToolEntriesTrashed(int count) {
    return '已移入回收站 $count 篇';
  }

  @override
  String get aiToolAddComment => '写一条留言';

  @override
  String aiToolCreateTag(String name) {
    return '新建标签：$name';
  }

  @override
  String aiToolRenameTag(String name) {
    return '修改标签：$name';
  }

  @override
  String aiToolMergeTags(String from, String into) {
    return '把 $from 合并到 $into';
  }

  @override
  String aiToolDeleteTag(String name) {
    return '删除标签 $name';
  }

  @override
  String aiToolCreateNotebook(String name) {
    return '新建日记本：$name';
  }

  @override
  String aiToolRenameNotebook(String name) {
    return '日记本改名为：$name';
  }

  @override
  String aiToolAddToNotebook(int count) {
    return '把 $count 篇日记收进日记本';
  }

  @override
  String aiToolRemoveFromNotebook(int count) {
    return '把 $count 篇日记移出日记本';
  }

  @override
  String aiToolCreateTodo(String title) {
    return '新建待办：$title';
  }

  @override
  String aiToolUpdateTodos(int count) {
    return '修改 $count 项待办';
  }

  @override
  String aiToolCompleteTodos(int count) {
    return '完成 $count 项待办';
  }

  @override
  String aiToolDeleteTodos(int count) {
    return '删除 $count 项待办';
  }

  @override
  String aiToolCreateAnniversary(String title) {
    return '新建纪念日：$title';
  }

  @override
  String get aiToolDeleteAnniversary => '删除纪念日';

  @override
  String aiToolSetDayMood(String date) {
    return '设置 $date 的心情';
  }

  @override
  String get aiToolSetTheme => '修改主题';

  @override
  String aiToolSetLanguage(String language) {
    return '界面语言改为 $language';
  }

  @override
  String get aiToolSetFontScale => '修改字体大小';

  @override
  String aiToolFeatureOn(String feature) {
    return '打开功能：$feature';
  }

  @override
  String aiToolFeatureOff(String feature) {
    return '关闭功能：$feature';
  }

  @override
  String get aiToolDone => '已完成';

  @override
  String get aiToolListTodoLists => '查看待办清单';

  @override
  String aiToolTodoListCount(int count) {
    return '$count 个清单';
  }

  @override
  String aiToolReopenTodos(int count) {
    return '把 $count 项待办改回未完成';
  }

  @override
  String get aiToolEditTodoSteps => '修改待办的步骤';

  @override
  String aiToolEditTodoStepsOf(String title) {
    return '修改步骤：$title';
  }

  @override
  String aiToolCreateTodoList(String name) {
    return '新建待办清单：$name';
  }

  @override
  String aiToolRenameTodoList(String name) {
    return '待办清单改名为：$name';
  }

  @override
  String aiToolDeleteTodoList(String name) {
    return '删除待办清单 $name';
  }

  @override
  String aiToolDeleteTodoListCount(int count) {
    return '其中的 $count 项待办会一起删除';
  }

  @override
  String get aiToolGetSettings => '查看设置';

  @override
  String get aiToolChangeSettingsAny => '修改设置';

  @override
  String aiToolChangeSetting(String name) {
    return '修改设置：$name';
  }

  @override
  String aiToolChangeSettings(int count) {
    return '修改 $count 项设置';
  }

  @override
  String aiToolSettingName(String page, String setting) {
    return '$page · $setting';
  }

  @override
  String get aiToolArgNone => '无';

  @override
  String get aiToolArgOn => '开';

  @override
  String get aiToolArgOff => '关';

  @override
  String get aiToolBlockedByEditor => '有页面正在编辑，先关掉再试';

  @override
  String get aiAgentConfirmDelete => '确认删除？';

  @override
  String get aiAgentConfirmChange => '确认执行这项改动？';

  @override
  String get aiAgentDelete => '删除';

  @override
  String get aiAgentProceed => '执行';

  @override
  String get aiAgentUndo => '撤销';

  @override
  String get aiAgentStepUndone => '已撤销';

  @override
  String aiAgentUndone(int count) {
    return '已撤销 $count 项改动';
  }

  @override
  String aiAgentUndoFailed(String error) {
    return '撤销没有成功：$error';
  }

  @override
  String get aiAgentUndoConflictTitle => '之后又改过';

  @override
  String get aiAgentUndoConflictBody =>
      '这项内容在 AI 改动之后又被修改过，撤销会把这些修改一起覆盖。仍要撤销吗？';

  @override
  String get aiAgentUndoConflictAction => '仍要撤销';

  @override
  String get aiOptionAgentChanges => '允许 AI 改动数据';

  @override
  String get aiOptionAgentChangesSubtitle =>
      '新建、修改日记，整理标签与日记本，加待办，改设置；改动都能撤销，删除前会先问你';

  @override
  String get aiOptionAgentConfirm => '每次改动前确认';

  @override
  String get aiOptionAgentConfirmSubtitle => '关掉时直接执行、事后可撤销；删除类无论如何都会先确认';

  @override
  String get aiDestinationDiary => '这篇日记';

  @override
  String get aiDestinationSearch => '搜索日记';

  @override
  String get aiAgentPreparing => '正在准备操作…';

  @override
  String get aiAgentStepFailed => '没有成功';

  @override
  String get aiAgentStepCancelled => '已停止';

  @override
  String get aiAgentStepInterrupted => '已中断';

  @override
  String aiAgentOpenPage(String page) {
    return '前往$page';
  }

  @override
  String get aiAgentStepsExhausted => '这次能用的操作步数用完了，可以说“继续”让 AI 接着做。';

  @override
  String get aiAgentIncomplete => '回答被截断了，其中的操作没有执行。';

  @override
  String get aiConfirmSendAgent => 'AI 会按需查找、读取你的日记（私密日记除外），之后不再逐次询问';

  @override
  String get aiConfirmSendAgentImages =>
      'AI 会按需查找、读取你的日记及其中的图片（私密日记除外），之后不再逐次询问';

  @override
  String get aiOptionAgent => '让 AI 使用工具';

  @override
  String get aiOptionAgentSubtitle => '按需查找和统计日记、查看日历与待办、打开页面；关掉或模型不支持时只做检索问答';

  @override
  String get aiOptionAgentSteps => '每次回答最多步数';

  @override
  String get aiOptionAgentStepsSubtitle => '每一步可以同时调用多个工具；最后一步只作答';

  @override
  String get aiPromptAgentSystem =>
      '你可以调用工具查询和修改用户在 Jotsy 里的数据、打开应用里的页面。\n- 需要用户的数据时先用工具去查，不要凭记忆或猜测回答；互不依赖的调用可以一次发出多个。\n- 只做用户明确要求的改动，拿不准改哪篇、改成什么时先问。改动都可以撤销；删除类工具由应用弹窗请用户确认，目标明确时直接调用，不必先在对话里再问一遍。\n- 回答下方的卡片只能由 open_page 生成，一次调用一张，卡片上写着那篇日记、那个日记本或页面的名字；要让用户点进几个目标，就给每个各调用一次。\n- 只说已经成功做到的事：没有成功调用对应的工具，就不要说“已打开”“已改好”或“卡片在下方”。不要在回答里写工具名、参数、id 或操作记录。\n- 和查询、修改类工具一起写的话会被折叠起来，用户看不到；和 open_page 一起写的话显示在卡片上方。结论、说明与操作步骤写在用户看得到的地方，同样的话不要说两遍。\n- 提到某篇日记时在句末写上工具结果里它的编号，如 [D3]（显示为可点开的小标签）。\n- 用户需要自己在页面里完成的事（备份、恢复、导入导出、分享、应用锁、密码、AI 服务商设置、彻底删除等），用 open_page 给出前往按钮并说明怎么做。\n- 工具报错时按错误说明改正或换个办法；确实做不到就直说。';

  @override
  String aiPromptAgentNow(String time) {
    return '现在是 $time。';
  }

  @override
  String get aiPromptAgentScopeDiary => '这次对话围绕下面这篇日记：';

  @override
  String aiPromptAgentScopeRange(String from, String to) {
    return '这次对话只关心 $from 到 $to 之间的日记，查日记时默认用这个范围。';
  }

  @override
  String aiPromptAgentImagesAttached(String refs) {
    return '这条消息附带的图片（按顺序）：$refs。可用 create_diary / append_to_diary 的 `images` 参数或正文里的 ![](P1) 把它们加进日记。';
  }

  @override
  String aiPromptImageNotSent(String label) {
    return '[图片 $label 没有发给你：当前模型或设置不发送图片]';
  }

  @override
  String aiPromptImageOmitted(String label) {
    return '[图片 $label 为控制请求大小未随本次请求发送；需要时调用 view_images 重看]';
  }

  @override
  String aiPromptImageUnavailable(String label) {
    return '[图片 $label 读不出来：文件已不在，或已不能再给 AI 看]';
  }

  @override
  String aiPromptImageRemoved(String label) {
    return '[图片 $label 已删除]';
  }

  @override
  String get aiPromptImagesRejected => '[图片没有发出：这个模型不接受图片]';

  @override
  String aiPromptDiaryImage(int index) {
    return '[图片 $index]';
  }

  @override
  String get aiToolViewImages => '查看图片';

  @override
  String aiToolViewedImages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '看了 $count 张图片',
      zero: '没有发出图片',
    );
    return '$_temp0';
  }

  @override
  String aiToolWithImages(int count) {
    return '附 $count 张图片';
  }

  @override
  String get aiModelMaxOutput => '最多输出（token）';

  @override
  String get aiModelContext => '上下文长度（token）';

  @override
  String get aiModelAuto => '自动';

  @override
  String get aiModelRemove => '移除模型';

  @override
  String get aiModelPickerTitle => '选择要使用的模型';

  @override
  String get aiModelPickerSearch => '搜索模型';

  @override
  String aiModelPickerAdd(int count) {
    return '添加 $count 个';
  }

  @override
  String get aiModelPickerEmpty => '服务商没有返回模型，请手动添加模型名。';

  @override
  String get aiProviderAdvanced => '高级';

  @override
  String get aiProviderProxy => 'HTTP 代理';

  @override
  String get aiProviderProxyHint => '主机:端口，如 127.0.0.1:7890；留空直连';

  @override
  String get aiProviderHeaders => '自定义请求头';

  @override
  String get aiProviderHeadersHint => '每行一个，格式为 名称: 值';

  @override
  String get aiProviderExtraBody => '额外请求参数（JSON）';

  @override
  String get aiProviderExtraBodyHint => '合并进每次请求的 JSON 对象，用于服务商特有的参数';

  @override
  String get aiProviderExtraBodyInvalid => '不是有效的 JSON 对象';

  @override
  String get aiProviderStream => '流式输出';

  @override
  String get aiProviderStreamSubtitle => '边生成边显示；个别转发服务不支持时关闭';

  @override
  String get aiProviderIncludeUsage => '请求用量统计';

  @override
  String get aiProviderIncludeUsageSubtitle => '流式时让服务端返回 token 用量；请求报错时关闭';

  @override
  String get aiProviderSendTemperature => '发送温度参数';

  @override
  String get aiProviderSendTemperatureSubtitle =>
      '较新的 Claude 模型不接受，Anthropic 默认关闭';

  @override
  String get aiProviderTimeout => '首字等待';

  @override
  String aiSeconds(int count) {
    return '$count 秒';
  }

  @override
  String get aiProviderRetries => '自动重试';

  @override
  String aiTimes(int count) {
    return '$count 次';
  }

  @override
  String get aiProviderEnabled => '启用';

  @override
  String get aiProviderDelete => '删除服务商';

  @override
  String aiProviderDeleteTitle(String name) {
    return '删除「$name」？';
  }

  @override
  String get aiProviderDeleteBody => '它的密钥与模型设置会一并移除，分配给它的功能恢复为默认模型。';

  @override
  String get aiProviderNameRequired => '请填写名称';

  @override
  String get aiProviderUrlInvalid => '请填写以 http:// 或 https:// 开头的地址';

  @override
  String get aiProviderNeedModel => '请先添加至少一个模型';

  @override
  String get aiProviderDiscardTitle => '放弃未保存的修改？';

  @override
  String get aiProviderDiscard => '放弃';

  @override
  String get aiRoutingDefault => '默认模型';

  @override
  String get aiRoutingDefaultSubtitle => '没有单独指定的功能都用它';

  @override
  String get aiRoutingFast => '快速模型';

  @override
  String get aiRoutingFastSubtitle => '智能填写、写作灵感等短任务优先用它，可以选一个便宜又快的模型';

  @override
  String get aiRoutingTasksGroup => '按功能指定';

  @override
  String get aiRoutingFollowDefault => '跟随默认';

  @override
  String get aiRoutingFollowFast => '跟随快速模型';

  @override
  String aiRoutingFirstUsable(String name) {
    return '第一个可用的（$name）';
  }

  @override
  String get aiRoutingNone => '未设置';

  @override
  String get aiRoutingPickTitle => '选择模型';

  @override
  String get aiTaskWriting => '写作助手';

  @override
  String get aiTaskSuggest => '智能填写';

  @override
  String get aiTaskReply => '读后回应';

  @override
  String get aiTaskPrompts => '写作灵感';

  @override
  String get aiTaskRecap => '回顾';

  @override
  String get aiTaskChat => '对话';

  @override
  String get aiTaskVision => '描述图片';

  @override
  String get aiTaskUtility => '内部小任务';

  @override
  String get aiTaskUtilitySubtitle => '对话标题、检索计划、长回顾的分段摘要';

  @override
  String get aiPersonasDefaultsGroup => '默认人设';

  @override
  String get aiPersonaUseReply => '读后回应';

  @override
  String get aiPersonaUseChat => '对话';

  @override
  String get aiPersonaUseRecap => '回顾';

  @override
  String get aiPersonasBuiltInGroup => '内置人设';

  @override
  String get aiPersonasMineGroup => '我的人设';

  @override
  String get aiPersonasMineEmpty => '还没有自己的人设。可以新建，也可以把内置人设复制过来再改。';

  @override
  String get aiPersonaAdd => '新建人设';

  @override
  String get aiPersonaDuplicate => '复制为我的人设';

  @override
  String get aiPersonaEditTitleNew => '新建人设';

  @override
  String get aiPersonaEditTitle => '编辑人设';

  @override
  String get aiPersonaName => '名称';

  @override
  String get aiPersonaEmoji => '表情';

  @override
  String get aiPersonaPrompt => '提示词';

  @override
  String get aiPersonaPromptHint => '描述 TA 是谁、怎么说话、怎么回应你的日记';

  @override
  String aiPersonaLimit(int count) {
    return '最多 $count 个人设';
  }

  @override
  String aiPersonaCopySuffix(String name) {
    return '$name（副本）';
  }

  @override
  String get aiCommonHidden => '已隐藏';

  @override
  String get aiCommonHide => '隐藏';

  @override
  String get aiCommonShow => '显示';

  @override
  String get aiCommonRestoreDefault => '恢复默认';

  @override
  String aiCommonDeleted(String name) {
    return '已删除「$name」';
  }

  @override
  String get aiActionsFooter => '拖动调整顺序，这里的顺序就是编辑器里指令的排列。';

  @override
  String get aiActionAdd => '新建指令';

  @override
  String get aiActionCustomized => '已改写';

  @override
  String get aiActionEditTitleNew => '新建指令';

  @override
  String get aiActionEditTitle => '编辑指令';

  @override
  String get aiActionName => '名称';

  @override
  String get aiActionEmoji => '图标';

  @override
  String get aiActionPrompt => '提示词';

  @override
  String get aiActionPromptHint => '告诉 AI 怎么处理这段文字';

  @override
  String get aiActionVariables => '插入变量';

  @override
  String get aiActionVariablesHelp => '提示词里没有“文字”变量时，作用的文字会自动附在提示词后面。';

  @override
  String get aiVariableText => '文字';

  @override
  String get aiVariableDiary => '全文';

  @override
  String get aiVariableTitle => '标题';

  @override
  String get aiVariableDate => '日期';

  @override
  String get aiVariableMood => '心情';

  @override
  String get aiActionOutput => '结果';

  @override
  String get aiOutputReplace => '替换原文';

  @override
  String get aiOutputInsertBelow => '插在下方';

  @override
  String get aiOutputPreview => '只预览';

  @override
  String aiActionLimit(int count) {
    return '最多 $count 个自定义指令';
  }

  @override
  String get aiActionResetPromptTitle => '恢复默认提示词？';

  @override
  String get aiProfileAboutMe => '关于我';

  @override
  String get aiProfileAboutMeHint => '比如你的身份、生活状态、在意的事，AI 回应时会参考';

  @override
  String get aiProfileStyle => '文风偏好';

  @override
  String get aiProfileStyleHint => '比如：简洁朴素、少用形容词、多用短句';

  @override
  String get aiProfileFooter => '这些内容会随每次请求一起发送；留空则不发送。';

  @override
  String get aiPrivacySendGroup => '随日记一起发送';

  @override
  String get aiPrivacySendFooter => '标题与正文总会发送；私密日记本、回收站与未解封的时间胶囊永远不会发送。';

  @override
  String get aiPrivacyDate => '日期';

  @override
  String get aiPrivacyMood => '心情';

  @override
  String get aiPrivacyTags => '标签';

  @override
  String get aiPrivacyWeather => '天气';

  @override
  String get aiPrivacyLocation => '地点';

  @override
  String get aiPrivacyScopeGroup => '对话与回顾的范围';

  @override
  String get aiPrivacyIncludeArchived => '包含已归档的日记';

  @override
  String get aiPrivacyExcludedNotebooks => '排除的日记本';

  @override
  String get aiPrivacyExcludedTags => '排除的标签';

  @override
  String get aiPrivacyExcludedNone => '无';

  @override
  String aiPrivacyExcludedCount(int count) {
    return '已选 $count 项';
  }

  @override
  String get aiPrivacyPickNotebooks => '选择要排除的日记本';

  @override
  String get aiPrivacyPickTags => '选择要排除的标签';

  @override
  String get aiPrivacyPickEmpty => '没有可选的项目';

  @override
  String get aiPrivacyBudget => '最多发送';

  @override
  String get aiPrivacyBudgetSubtitle => '每篇日记都整篇发送，一次请求合计超过这个字数时才截断。';

  @override
  String aiWords(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    return '$countString字';
  }

  @override
  String get aiPrivacyConfirmGroup => '发送前确认';

  @override
  String get aiPrivacyConfirmSubtitle =>
      '首次：每个服务商只问一次；多篇时：对话与回顾每次都显示要发送的篇数与字数；每次：所有请求都先确认。';

  @override
  String get aiConfirmFirstTime => '首次';

  @override
  String get aiConfirmMultiDiary => '多篇时';

  @override
  String get aiConfirmAlways => '每次';

  @override
  String get aiPrivacyAllowPrivate => '允许对私密日记使用 AI';

  @override
  String get aiPrivacyAllowPrivateSubtitle =>
      '打开后，私密日记本里的日记也能用写作助手与读后回应；对话与回顾仍然不会读取它们。';

  @override
  String get aiPrivacyResetHosts => '重置“不再提示”';

  @override
  String get aiPrivacyResetHostsSubtitle => '让每个服务商重新确认一次';

  @override
  String get aiPrivacyResetHostsDone => '已重置，下次发送前会再次确认。';

  @override
  String get aiUsageEmpty => '还没有用量记录';

  @override
  String aiUsageRequests(int count) {
    return '$count 次请求';
  }

  @override
  String aiUsageFailures(int count) {
    return '$count 次失败';
  }

  @override
  String aiUsageTokens(String input, String output) {
    return '输入 $input · 输出 $output';
  }

  @override
  String aiUsageTokensCached(String input, String cached, String output) {
    return '输入 $input（缓存 $cached）· 输出 $output';
  }

  @override
  String aiUsageMonthTotal(String tokens) {
    return '共 $tokens token';
  }

  @override
  String get aiUsageClear => '清除用量记录';

  @override
  String get aiUsageClearTitle => '清除用量记录？';

  @override
  String get aiUsageClearBody => '只清除本机的统计，不影响服务商那边的账单。';

  @override
  String get aiUsageFooter => '只统计从这台设备发出的请求，实际费用以服务商账单为准。';

  @override
  String get aiPrivacyRecordsGroup => 'AI 记录';

  @override
  String get aiPrivacyRecordsFooter => '对话、读后回应与回顾保存在这台设备上，随完整备份导出，不参与局域网同步。';

  @override
  String get aiPrivacyClearRecords => '清除全部 AI 记录';

  @override
  String aiPrivacyClearRecordsSubtitle(int count) {
    return '共 $count 条对话与结果';
  }

  @override
  String get aiPrivacyClearRecordsTitle => '清除全部 AI 记录？';

  @override
  String get aiPrivacyClearRecordsBody =>
      '所有对话、读后回应与回顾都会从这台设备删除，不能撤销。日记本身不受影响。';

  @override
  String get aiPrivacyClearRecordsDone => '已清除全部 AI 记录';

  @override
  String get aiPromptSystemBase =>
      '你是日记应用 Jotsy 里的 AI 助手，和你对话的是日记的作者本人。真诚、具体，不编造日记里没有的事实。';

  @override
  String aiPromptAboutUser(String text) {
    return '关于用户：$text';
  }

  @override
  String aiPromptWritingStyle(String text) {
    return '用户偏好的文风：$text';
  }

  @override
  String aiPromptRespondIn(String language) {
    return '请用$language回答。';
  }

  @override
  String get aiPromptRespondLikeDiary => '用日记所用的语言回答。';

  @override
  String get aiPromptLanguageChinese => '中文';

  @override
  String get aiPromptLanguageEnglish => '英文';

  @override
  String get aiPromptLanguageJapanese => '日语';

  @override
  String get aiPromptLanguageRussian => '俄语';

  @override
  String get aiPromptLengthShort => '回答尽量简短，三五句以内。';

  @override
  String get aiPromptLengthMedium => '回答长度适中。';

  @override
  String get aiPromptLengthLong => '可以写得详细一些。';

  @override
  String aiPromptPersona(String text) {
    return '你的身份：$text';
  }

  @override
  String get aiPromptFieldTitle => '标题';

  @override
  String get aiPromptFieldDate => '日期';

  @override
  String get aiPromptFieldMood => '心情';

  @override
  String get aiPromptFieldTags => '标签';

  @override
  String get aiPromptFieldWeather => '天气';

  @override
  String get aiPromptFieldLocation => '地点';

  @override
  String get aiPromptFieldBody => '正文';

  @override
  String get aiPromptTruncated => '（后文省略）';

  @override
  String aiPromptImagesAttached(int count) {
    return '日记附有 $count 张照片，一并参考。';
  }

  @override
  String get aiPromptWritingSystem =>
      '你是帮助用户修改自己日记的写作助手。只输出处理后的文字本身，不要解释、不要加引号或开场白；保持第一人称视角。可以使用 Markdown 的列表、加粗与任务列表，不要使用标题。';

  @override
  String get aiPromptWritingContext => '供参考的日记全文（不要重复它）：';

  @override
  String aiPromptCustomInstruction(String text) {
    return '按这条要求处理下面的文字：$text';
  }

  @override
  String get aiPromptReplyInstruction =>
      '下面是用户写下的一篇日记。请以你的身份读完后直接回应用户。不要复述日记内容，不要使用标题。';

  @override
  String get aiPromptSuggestInstruction =>
      '根据下面的日记给出建议：一个简短贴切的标题（不超过 20 字，不加引号或书名号）；从用户已有的标签里选 0 到 3 个；确有必要时再建议最多 2 个新标签（每个不超过 6 个字）；从给定的心情选项中选出最符合的一个，拿不准就留空。只输出一个 JSON 对象，严格按下面的格式：';

  @override
  String aiPromptSuggestTagsList(String tags) {
    return '用户已有的标签：$tags';
  }

  @override
  String aiPromptSuggestMoodList(String moods) {
    return '心情选项：$moods';
  }

  @override
  String get aiPromptPromptsInstruction =>
      '为用户今天的日记想 3 个具体、温和、容易下笔的问题，帮助用户开始写。每个问题一行，不要编号，不要其他内容。';

  @override
  String aiPromptPromptsToday(String date) {
    return '今天：$date';
  }

  @override
  String get aiPromptPromptsRecent => '用户最近几篇日记的摘录，可以借此让问题更贴近用户：';

  @override
  String aiPromptRecapInstruction(String period) {
    return '下面是用户在$period写下的日记。请写一份回顾，用 Markdown 小标题组织，包含以下部分：';
  }

  @override
  String get aiPromptRecapRules =>
      '只根据日记内容写，不要编造；提到具体的日子时写上日期。日记带有 [D编号] 的，可以在句末用 [D编号] 引用。';

  @override
  String get aiPromptRecapChunk =>
      '下面是用户一段时间内的日记。请用要点概括这段时间发生的事、情绪与想法，保留具体的日期与细节，供之后汇总成回顾。';

  @override
  String get aiPromptRecapFromSummaries => '以下是这段时间各部分的摘要，按时间先后：';

  @override
  String aiPromptRecapStats(int count, int words) {
    return '统计：共 $count 篇日记，$words 字。';
  }

  @override
  String aiPromptRecapMoods(String moods) {
    return '心情分布：$moods';
  }

  @override
  String aiPromptRecapTopTags(String tags) {
    return '常用标签：$tags';
  }

  @override
  String get aiPromptChatSystem =>
      '你可以读到用户的部分日记，每篇以 [D编号] 标记。回答用户的问题时以这些日记为依据；用到某篇日记时，在句末写上它的编号，如 [D3]。日记里没有的信息不要编造，找不到就直说。';

  @override
  String get aiPromptChatContextHeader => '以下是相关的日记：';

  @override
  String get aiPromptChatNoDiaries => '（没有找到与问题相关的日记。）';

  @override
  String aiPromptChatToday(String date) {
    return '今天是 $date。';
  }

  @override
  String get aiPromptChatTitle => '用不超过 12 个字概括这次对话的主题，只输出标题本身。';

  @override
  String aiPromptRetrievalPlan(String date) {
    return '把用户的问题转成日记检索计划。今天是 $date。给出最多 8 个可能出现在日记里的简短关键词（含近义词），只有问题隐含时间范围时才给出日期范围。只输出一个 JSON 对象，严格按下面的格式：';
  }

  @override
  String get aiPromptDescribeImage => '用一两句话描述这张照片的内容与氛围，作为日记里的图片说明。只输出描述本身。';

  @override
  String get aiToolbarLabel => 'AI 写作';

  @override
  String get aiPanelTitle => 'AI 写作';

  @override
  String get aiScopeSelection => '选中的文字';

  @override
  String get aiScopeParagraph => '当前段落';

  @override
  String get aiScopeBeforeCaret => '光标前的内容';

  @override
  String get aiScopeDocument => '全文';

  @override
  String aiScopeSummary(String scope, int words) {
    return '$scope · $words 字';
  }

  @override
  String get aiPanelInstructionHint => '告诉 AI 怎么改，比如“改得更口语一点”';

  @override
  String get aiPanelSend => '发送';

  @override
  String get aiPanelThinking => '正在思考…';

  @override
  String get aiPanelReplace => '替换';

  @override
  String get aiPanelInsertBelow => '插在下方';

  @override
  String get aiPanelCopy => '复制';

  @override
  String get aiPanelCopied => '已复制';

  @override
  String get aiPanelStop => '停止';

  @override
  String get aiPanelEmptyTarget => '还没有可处理的文字，先写一点或选中一段文字。';

  @override
  String get aiPanelReasoning => '思考过程';

  @override
  String get aiPanelPrivateBlocked => '这篇日记在私密日记本里。可以在 AI 隐私设置里允许对私密日记使用 AI。';

  @override
  String get aiSlashGroup => 'AI';

  @override
  String get aiSlashWrite => 'AI 写作…';

  @override
  String get aiSlashContinue => 'AI 续写';

  @override
  String get aiSlashPrompts => '写作灵感';

  @override
  String get aiSelectionMenu => 'AI…';

  @override
  String get aiImageDescribe => 'AI 描述图片';

  @override
  String get aiImageDescribing => '正在描述图片…';

  @override
  String get aiImageNoVision => '当前模型不支持看图。可以在“模型分配”里为“描述图片”选一个支持视觉的模型。';

  @override
  String get aiSuggestTitle => 'AI 生成标题';

  @override
  String get aiSuggestMeta => 'AI 推荐标签与心情';

  @override
  String get aiSuggesting => 'AI 正在想…';

  @override
  String get aiSuggestNeedContent => '先写点正文，AI 才好给建议。';

  @override
  String get aiSuggestTitleApplied => '已填入 AI 生成的标题';

  @override
  String get aiSuggestTagsHeader => 'AI 推荐';

  @override
  String aiSuggestNewTag(String name) {
    return '新建「$name」';
  }

  @override
  String get aiSuggestMoodButton => 'AI 识别';

  @override
  String get aiSuggestNothing => '这次没有合适的建议';

  @override
  String get aiSuggestApplied => '已应用 AI 的建议';

  @override
  String aiConfirmSendTitle(String host) {
    return '发送到 $host？';
  }

  @override
  String aiConfirmSendModel(String name) {
    return '由「$name」处理';
  }

  @override
  String aiConfirmSendEntries(int count, int words) {
    return '$count 篇日记，约 $words 字';
  }

  @override
  String aiConfirmSendText(int words) {
    return '约 $words 字的文字';
  }

  @override
  String aiConfirmSendImages(int count) {
    return '另附 $count 张照片';
  }

  @override
  String get aiConfirmSendNote => '内容从这台设备直接发出，开发者收不到；服务商会按它自己的隐私政策处理。';

  @override
  String get aiConfirmSendRemember => '以后发给这个服务商不再询问';

  @override
  String get aiConfirmSendAction => '发送';

  @override
  String aiRepliesHeading(int count) {
    return 'AI 回应 · $count';
  }

  @override
  String get aiReplyAsk => '让 AI 回应…';

  @override
  String get aiReplyMoreItem => 'AI 回应';

  @override
  String get aiReplyPickPersona => '请谁来回应？';

  @override
  String get aiReplyWriting => '正在读你的日记…';

  @override
  String get aiReplyRegenerate => '重新生成';

  @override
  String get aiReplySaveAsComment => '存为留言';

  @override
  String get aiReplyContinueChat => '继续聊聊';

  @override
  String get aiReplyDeleted => '已删除这条 AI 回应';

  @override
  String get aiReplyExpand => '展开';

  @override
  String get aiReplyCollapse => '收起';

  @override
  String get aiReplyStopped => '已停止，要再试一次吗？';

  @override
  String get aiReplyDismiss => '关闭';

  @override
  String get aiReplyAutoSkipped => '自动回应没有发送：请先手动请一次 AI 回应，确认这个服务商。';

  @override
  String get aiPromptsStripLabel => '来点写作灵感';

  @override
  String get aiPromptsLoading => '正在想问题…';

  @override
  String get aiPromptsRefresh => '换一批';

  @override
  String get aiPromptsTitle => '写作灵感';

  @override
  String get aiPromptsHint => '点一个问题，插进正文';

  @override
  String get aiPromptsEmpty => '这次没想出问题，再试一次？';

  @override
  String get aiPromptsClose => '收起灵感';

  @override
  String get aiReplySavedAsComment => '已存为留言';

  @override
  String get aiRecapTitle => 'AI 回顾';

  @override
  String get aiRecapRange => '范围';

  @override
  String get aiRecapThisWeek => '本周';

  @override
  String get aiRecapLastWeek => '上周';

  @override
  String get aiRecapThisMonth => '本月';

  @override
  String get aiRecapLastMonth => '上月';

  @override
  String get aiRecapThisYear => '今年';

  @override
  String get aiRecapCustom => '自定义…';

  @override
  String get aiRecapNotebook => '日记本';

  @override
  String get aiRecapAllNotebooks => '全部日记';

  @override
  String get aiRecapSections => '包含';

  @override
  String get aiRecapPersona => '口吻';

  @override
  String get aiRecapGenerate => '生成回顾';

  @override
  String get aiRecapNoEntries => '这段时间没有可以回顾的日记。';

  @override
  String aiRecapReading(int index, int total) {
    return '正在读第 $index 部分，共 $total 部分…';
  }

  @override
  String get aiRecapWriting => '正在写回顾…';

  @override
  String aiRecapStats(int count, int words) {
    return '$count 篇 · $words 字';
  }

  @override
  String get aiRecapSaved => '已保存到回顾记录';

  @override
  String get aiRecapSaveAsDiary => '另存为日记';

  @override
  String get aiRecapShare => '分享文字';

  @override
  String get aiRecapDeleted => '已删除这份回顾';

  @override
  String aiRecapPeriodRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String aiRecapDiaryTitle(String period) {
    return '$period 回顾';
  }

  @override
  String get aiHubQuickMonth => '这个月我过得怎么样？';

  @override
  String get aiHubQuickWorry => '我最近常为什么事烦恼？';

  @override
  String get aiHubQuickLastYear => '去年的这个时候我在做什么？';

  @override
  String get aiHubQuickHappy => '最近有哪些让我开心的小事？';

  @override
  String get aiHubQuickGrowth => '这半年我有哪些变化？';

  @override
  String get aiHubRecapMore => '更多范围…';

  @override
  String get aiHubSearchChats => '搜索对话';

  @override
  String get aiChatUntitled => '新对话';

  @override
  String get aiChatPin => '置顶';

  @override
  String get aiChatUnpin => '取消置顶';

  @override
  String get aiChatRename => '重命名';

  @override
  String get aiChatRenameTitle => '重命名对话';

  @override
  String get aiChatDeleted => '已删除对话';

  @override
  String get aiChatInputHint => '问点什么…';

  @override
  String get aiChatAttachImages => '添加图片';

  @override
  String aiChatImagesTruncated(int max) {
    return '一条消息最多 $max 张图片，多选的没有加上';
  }

  @override
  String get aiChatImagesNoVision => '当前模型看不到图片内容（或图片理解已关闭），但 AI 仍可以把图片加进日记';

  @override
  String aiChatImagesSummary(int count) {
    return '[$count 张图片]';
  }

  @override
  String aiChatImagesRemoved(int count) {
    return '$count 张图片已删除';
  }

  @override
  String get aiChatPlanning => '正在理解问题…';

  @override
  String get aiChatSearching => '正在查找相关的日记…';

  @override
  String aiChatCitations(int count) {
    return '参考了 $count 篇日记';
  }

  @override
  String get aiChatNoCitations => '没有找到相关的日记';

  @override
  String get aiChatScope => '范围';

  @override
  String get aiChatScopeAuto => '自动';

  @override
  String aiChatScopeRecent(int days) {
    return '最近 $days 天';
  }

  @override
  String get aiChatScopeAll => '全部日记';

  @override
  String get aiChatScopeRange => '时间范围…';

  @override
  String get aiChatScopeEntry => '这篇日记';

  @override
  String get aiChatPersona => '人设';

  @override
  String get aiChatModel => '模型';

  @override
  String aiChatModelDefault(String name) {
    return '默认（$name）';
  }

  @override
  String get aiChatEditResend => '编辑并重发';

  @override
  String get aiChatDeleteMessage => '删除这条';

  @override
  String get aiChatCitationMissing => '这篇日记已不存在';

  @override
  String aiChatAboutEntry(String title) {
    return '关于「$title」';
  }

  @override
  String get aiHubTooltip => 'AI 助手';

  @override
  String get exploreModuleAi => 'AI 洞察';

  @override
  String get exploreModuleAiDesc => '最近一次回顾，以及问问你的日记';

  @override
  String get aiExploreNoRecap => '还没有回顾，来一份本周回顾吧。';

  @override
  String get aiExploreWeekly => '生成本周回顾';

  @override
  String get aiExploreAsk => '问问我的日记';

  @override
  String get aiExploreNotConfigured => '配置好 AI 服务后可用';

  @override
  String get aiRecapStopped => '已停止，写了一半的回顾不会保存。';

  @override
  String get aiRecapHistory => '以前的回顾';

  @override
  String get aiRecapDeleteTitle => '删除这份回顾？';

  @override
  String get aiRecapNotebookPick => '选择日记本';

  @override
  String get aiRecapCustomRange => '选择日期';

  @override
  String get aiRecapShareUnavailable => '已复制，可以粘贴到想分享的地方。';

  @override
  String aiRecapModel(String model) {
    return '由 $model 生成';
  }

  @override
  String get aiChatMore => '更多';

  @override
  String get aiChatComposerAdd => '图片与对话选项';

  @override
  String get aiChatScrollToBottom => '回到底部';

  @override
  String get markdownCopyCode => '复制代码';

  @override
  String get markdownCodeCopied => '已复制';

  @override
  String aiChatTokens(String input, String output) {
    return '输入 $input · 输出 $output';
  }

  @override
  String aiChatTokensCached(String input, String cached, String output) {
    return '输入 $input（缓存 $cached）· 输出 $output';
  }

  @override
  String get aiChatStoppedLabel => '已停止';

  @override
  String get aiChatDeleteMessageTitle => '删除这条消息？';

  @override
  String get aiChatDeleteTitle => '删除这段对话？';

  @override
  String get aiChatDeleteBody => '其中的消息会一并删除，日记本身不受影响。';

  @override
  String get aiChatRangeTitle => '选择日期';

  @override
  String get aiChatScopeTitle => '在哪些日记里找';

  @override
  String get aiChatScopeAutoSubtitle => '按 AI 设置里的检索方式';

  @override
  String get aiSettingsOpenHub => '打开 AI 助手';

  @override
  String get aiSettingsOpenHubSubtitle => '问问你的日记、生成回顾';

  @override
  String get aiProtocolOpenAiResponses => 'OpenAI Responses';

  @override
  String get aiPresetNameCustomOpenAiResponses => 'OpenAI Responses 接口';

  @override
  String get cloudBackupBackupNow => '备份';

  @override
  String get cloudIncrementalBusyScan => '正在检查变化…';

  @override
  String get cloudIncrementalBusyCheck => '正在读取网盘上的备份…';

  @override
  String get cloudIncrementalBusyPrune => '正在清理旧备份…';

  @override
  String cloudIncrementalUploaded(String size) {
    return '已备份，本次上传 $size';
  }

  @override
  String get cloudIncrementalUnchanged => '数据没有变化，网盘上已是最新的备份';

  @override
  String get cloudIncrementalNewPasswordMessage =>
      '设置的密码会记在本机，之后的备份与自动备份都用它；换设备恢复时需要输入。留空则不加密。';

  @override
  String get cloudIncrementalExistingEncryptedMessage =>
      '网盘上已有加密的增量备份。输入它的密码接着备份，已上传的照片与媒体不用重传。';

  @override
  String get cloudIncrementalContinue => '继续';

  @override
  String get cloudIncrementalWrongPasswordTitle => '密码不对';

  @override
  String get cloudIncrementalWrongPasswordContent =>
      '这个密码打不开网盘上的增量备份。可以重新输入，或者开始新的一串增量备份（需要重新上传全部照片与媒体）。';

  @override
  String get cloudIncrementalRetry => '重新输入';

  @override
  String get cloudIncrementalStartNew => '开始新的一串';

  @override
  String get cloudIncrementalExistingPlainTitle => '接着已有的增量备份？';

  @override
  String get cloudIncrementalExistingPlainContent =>
      '网盘上已有不加密的增量备份。接着备份只上传新增的内容；想加密的话可以开始新的一串（需要重新上传全部照片与媒体）。';

  @override
  String get cloudIncrementalContinueExisting => '接着备份';

  @override
  String get cloudIncrementalRememberedMismatchContent =>
      '本机记住的密码打不开网盘上的增量备份，可能在另一台设备上换过密码。重新设置后，可以输入原来的密码接着备份，或开始新的一串。';

  @override
  String get cloudIncrementalRestorePasswordMessage => '这份增量备份已加密，请输入备份时设置的密码。';

  @override
  String get cloudIncrementalEntryTitle => '增量备份';

  @override
  String get cloudIncrementalEntryMissing => '快照文件缺失，无法恢复';

  @override
  String get cloudIncrementalDeleteTitle => '删除这份增量备份？';

  @override
  String cloudIncrementalDeleteContent(String time) {
    return '将删除 $time 的增量备份；只被它用到的照片与媒体会一并从网盘删除，其他备份不受影响。此操作不可撤销。';
  }

  @override
  String get cloudIncrementalSectionTitle => '增量备份';

  @override
  String get cloudIncrementalSectionHint =>
      '“备份”只上传新增的照片与变化的数据，已在网盘上的内容不再重复上传；在本机恢复时也只下载缺少的部分，省下网盘的流量额度。';

  @override
  String get cloudIncrementalKeepTitle => '保留份数';

  @override
  String get cloudIncrementalKeepSubtitle => '更早的增量备份自动删除，只被它们用到的照片与媒体一并清理';

  @override
  String get cloudIncrementalKeepAll => '全部';

  @override
  String cloudIncrementalKeepCount(int count) {
    return '$count 份';
  }

  @override
  String get cloudAutoBackupTitle => '自动备份';

  @override
  String get cloudAutoBackupSubtitle =>
      '打开或离开应用时，到时间就在后台静默备份；新增内容超过 50 MB 时留给你手动备份';

  @override
  String get cloudAutoBackupNeedsChain => '先点“备份”手动备份一次，之后才能开启';

  @override
  String get cloudAutoBackupIntervalTitle => '频率';

  @override
  String get cloudAutoBackupDaily => '每天';

  @override
  String get cloudAutoBackupWeekly => '每周';

  @override
  String cloudAutoBackupLastUploaded(String time, String size) {
    return '上次自动备份：$time，上传 $size';
  }

  @override
  String cloudAutoBackupLastUnchanged(String time) {
    return '上次自动备份：$time，数据没有变化';
  }

  @override
  String cloudAutoBackupLastNeedsManual(String time, String size) {
    return '$time：有 $size 新内容，请手动备份';
  }

  @override
  String cloudAutoBackupLastFailed(String time, String reason) {
    return '$time 自动备份失败：$reason';
  }

  @override
  String cloudAutoBackupTileOk(String time) {
    return '自动备份 · $time';
  }

  @override
  String get cloudAutoBackupTileNeedsManual => '需要手动备份';

  @override
  String get cloudAutoBackupTileFailed => '自动备份失败';

  @override
  String get cloudIncrementalForgetChain => '重新设置密码';

  @override
  String get cloudIncrementalForgetTitle => '重新设置增量备份密码？';

  @override
  String get cloudIncrementalForgetContent =>
      '本机会忘记现在的增量备份密码，自动备份随之暂停。下次备份时可以输入原来的密码接着备份，也可以设新密码重新开始（需要重新上传全部照片与媒体）。';

  @override
  String get cloudIncrementalForgotten => '已忘记增量备份密码';

  @override
  String get cloudIncrementalErrorPassword => '密码打不开这份增量备份';

  @override
  String get cloudIncrementalErrorMediaChanged => '备份期间有照片或附件发生了变化，请再试一次';

  @override
  String get textSelectionMenuMore => '更多';

  @override
  String get textSelectionMenuLess => '收起';

  @override
  String passcodeDotsSemantics(int filled, int total) {
    return '已输入 $filled 位，共 $total 位';
  }

  @override
  String get passcodeDelete => '删除';

  @override
  String get passcodePatternSemantics => '图案输入区：在九个点之间连线';

  @override
  String get passcodeUseBiometric => '使用指纹或面容';

  @override
  String passcodeWrongAttemptsLeft(int count) {
    return '不对，再错 $count 次需要等待';
  }

  @override
  String get passcodeWrongPin => '密码不对，请重新输入';

  @override
  String get passcodeWrongPattern => '图案不对，请重新绘制';

  @override
  String passcodePatternTooShort(int count) {
    return '点太少了，至少连接 $count 个点';
  }

  @override
  String passcodeLockedOutSeconds(int seconds) {
    return '请 $seconds 秒后再试';
  }

  @override
  String passcodeLockedOutMinutes(int minutes) {
    return '请 $minutes 分钟后再试';
  }

  @override
  String get passcodeUnavailable => '读取不到应用密码，请重启应用后再试';

  @override
  String get passcodeEnterPinTitle => '输入应用密码';

  @override
  String get passcodeDrawPatternTitle => '绘制解锁图案';

  @override
  String get passcodeForgot => '忘记密码？';

  @override
  String get passcodeForgotMessage =>
      '应用密码只保存在这台设备上，无法找回。只能清除应用数据或重新安装，再从备份恢复日记。';

  @override
  String get appLockPasscodeSubtitle => '验证应用密码后继续使用';

  @override
  String get passcodeVerifyTitle => '验证身份';

  @override
  String passcodeFormPin(int count) {
    return '$count 位数字';
  }

  @override
  String get passcodeFormPattern => '图案';

  @override
  String get passcodeConfirmPinTitle => '再输入一次';

  @override
  String get passcodeConfirmPatternTitle => '再画一次';

  @override
  String get passcodeConfirmMessage => '与上一步保持一致';

  @override
  String get passcodeSetupPinTitle => '设置数字密码';

  @override
  String passcodeSetupPinMessage(int count) {
    return '输入 $count 位数字';
  }

  @override
  String get passcodeSetupPatternTitle => '设置解锁图案';

  @override
  String passcodeSetupPatternMessage(int count) {
    return '一笔连接至少 $count 个点';
  }

  @override
  String get passcodeMismatch => '两次不一致，请重新设置';

  @override
  String get passcodeSaveFailed => '保存失败，请重试';

  @override
  String get passcodeChangeTitle => '修改应用密码';

  @override
  String get passcodeSetupTitle => '设置应用密码';

  @override
  String get passcodeNoRecoveryNote => '应用密码只保存在这台设备上，不随备份与同步，忘记后无法找回。';

  @override
  String get appLockSwitchToPasscodeReason => '验证身份以改用应用密码';

  @override
  String get appLockSwitchVerifyFailed => '验证未通过，验证方式没有改变';

  @override
  String get passcodeSetDone => '已设置应用密码';

  @override
  String get appLockSystemUnsupported => '这台设备不能使用系统验证（没有设置锁屏密码）';

  @override
  String get appLockSwitchToSystemReason => '验证应用密码以改用系统验证';

  @override
  String get appLockSwitchedToSystem => '已改用系统验证，应用密码已清除';

  @override
  String get passcodeChangeReason => '验证当前密码以修改应用密码';

  @override
  String get passcodeChangedDone => '已修改应用密码';

  @override
  String get passcodeBiometricEnableReason => '验证指纹或面容以开启快速解锁';

  @override
  String get passcodeBiometricFailed => '指纹或面容验证未通过';

  @override
  String get settingsAppLockAndPasscode => '应用锁与密码';

  @override
  String get appLockMethodTitle => '验证方式';

  @override
  String get appLockMethodFooter => '应用锁、上锁的日记本与局域网配对确认都使用这种方式验证。';

  @override
  String get appLockNeedsPasscode => '这台设备没有系统验证，请先在下方设置应用密码';

  @override
  String get appLockMethodSystem => '系统验证';

  @override
  String get appLockMethodSystemDescription => '指纹、面容或手机锁屏密码';

  @override
  String get appLockMethodSystemUnavailable => '这台设备没有系统验证';

  @override
  String get appLockMethodPasscode => '应用密码';

  @override
  String get appLockMethodPasscodeDescription => '数字密码或图案，与手机锁屏无关';

  @override
  String passcodeCurrentForm(String form) {
    return '当前：$form';
  }

  @override
  String get passcodeBiometric => '指纹 / 面容快速解锁';

  @override
  String get passcodeBiometricSubtitle => '解锁时可以用指纹或面容代替密码；关闭应用锁、修改密码仍需输入密码';

  @override
  String get appLockStatusPasscode => '已开启 · 应用密码';

  @override
  String get appLockStatusSystem => '已开启 · 系统验证';

  @override
  String get appLockStatusOffPasscode => '未开启 · 上锁的日记本使用应用密码';

  @override
  String get appLockStatusOff => '未开启';

  @override
  String get settingsGroupGeneral => '通用';

  @override
  String get settingsGroupWriting => '写日记';

  @override
  String get settingsGroupOrganize => '整理';

  @override
  String get settingsGroupDataSecurity => '数据与安全';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsAppearanceSubtitle => '主题、背景与各页样式';

  @override
  String get settingsEditor => '编辑器';

  @override
  String get settingsThemeGroup => '主题';

  @override
  String get settingsInterfaceGroup => '界面';

  @override
  String get settingsPageStylesGroup => '页面样式';

  @override
  String get settingsEditorBodyGroup => '正文';

  @override
  String get settingsEditorToolbarGroup => '工具栏';

  @override
  String get settingsEditorBehaviorGroup => '编辑行为';

  @override
  String get dataMgmtBackupGroup => '备份与恢复';

  @override
  String get dataMgmtFilesGroup => '导入导出';

  @override
  String get placeHistoryTitle => '用过的地点';

  @override
  String get placeHistorySearchHint => '搜索地点';

  @override
  String placeHistorySearchEmpty(String query) {
    return '没有找到「$query」';
  }

  @override
  String get placeHistoryEmptyTitle => '还没有用过的地点';

  @override
  String get placeHistoryEmptyBody => '写了地点的日记发表后，地点会出现在这里，下次点一下就能选用。';

  @override
  String placeHistoryUseCount(int count) {
    return '$count 篇';
  }

  @override
  String placeHistoryShowAll(int count) {
    return '全部 $count';
  }

  @override
  String get appLockAfterLeaving => '离开应用后上锁';

  @override
  String get appLockAfterLeavingHint =>
      '切到其他应用、回到桌面或最小化窗口都算离开；在应用里选图片、拍照、选文件或分享不算。打开应用时总是需要验证。';

  @override
  String get appLockDelayImmediately => '立即';

  @override
  String appLockDelayMinutes(int count) {
    return '$count 分钟后';
  }

  @override
  String appLockDelayHours(int count) {
    return '$count 小时后';
  }

  @override
  String get appLockAfterLeavingNever => '从不（只在打开应用时）';

  @override
  String get appLockOnScreenOff => '锁屏时上锁';

  @override
  String get appLockOnScreenOffSubtitle => '手机锁屏或熄屏后，回到应用需要验证';

  @override
  String get appLockWhenIdle => '闲置时上锁';

  @override
  String get appLockWhenIdleHint => '窗口开着、但一段时间没有用鼠标、触控板或键盘时上锁。';

  @override
  String get appLockWhenIdleOff => '关闭';

  @override
  String get appLockAutoPrompt => '自动弹出验证';

  @override
  String get appLockAutoPromptSubtitle => '锁屏出现时直接弹出指纹、面容或系统验证；关闭后点一下再验证';

  @override
  String get appLockPrivacyTitle => '隐私';

  @override
  String get appLockSecureScreen => '防截屏';

  @override
  String get appLockSecureScreenSubtitle => '禁止截屏和录屏，最近任务里也不显示应用内容';

  @override
  String get appLockLoosenReason => '验证身份以放宽应用锁';

  @override
  String get appLockLoosenVerifyFailed => '验证未通过，设置没有改变';

  @override
  String get diarySearchRecentTitle => '最近搜索';

  @override
  String get diarySearchClearRecent => '清空最近搜索';

  @override
  String diarySearchRecentRemove(String query) {
    return '删除搜索记录“$query”';
  }

  @override
  String get diarySearchSuggestedTags => '常用标签';

  @override
  String get diarySearchEmptyTip => '用空格分隔多个词，找出同时包含它们的日记';

  @override
  String diarySearchResultCount(int count) {
    return '共 $count 篇';
  }

  @override
  String get diarySearchClearFilters => '清除筛选';

  @override
  String get diarySearchIncludeArchived => '含归档';

  @override
  String diarySearchRemoveFilter(String label) {
    return '移除筛选 $label';
  }

  @override
  String get diarySearchSortTooltip => '结果排序';

  @override
  String get diarySearchSortUpdated => '最近更新';

  @override
  String get diarySearchSortNewest => '最新发表';

  @override
  String get diarySearchSortOldest => '最早发表';

  @override
  String get diarySearchTagSheetTitle => '按标签搜索';

  @override
  String get diarySearchTagSheetHint => '只显示同时带有所选全部标签的日记';

  @override
  String settingsStorageSubtitle(String size) {
    return '已用 $size';
  }

  @override
  String get storageMgmtTitle => '存储管理';

  @override
  String get storageMgmtTotalLabel => '共占用';

  @override
  String storageMgmtCleanUpAll(String size) {
    return '一键清理 · 可释放 $size';
  }

  @override
  String get storageMgmtRescan => '重新统计';

  @override
  String get storageMgmtScanFailed => '统计失败，请稍后再试';

  @override
  String get storageMgmtCategoryImages => '图片';

  @override
  String get storageMgmtCategoryVideos => '视频';

  @override
  String get storageMgmtCategoryAudio => '录音';

  @override
  String get storageMgmtCategoryAttachments => '附件';

  @override
  String get storageMgmtCategoryCovers => '封面';

  @override
  String get storageMgmtCategoryBackgrounds => '背景图';

  @override
  String get storageMgmtCategoryFonts => '字体';

  @override
  String get storageMgmtCategoryDatabase => '日记数据';

  @override
  String get storageMgmtCategoryCache => '缓存';

  @override
  String get storageMgmtCategoryUnused => '未使用的文件';

  @override
  String get storageMgmtCategoryOther => '其他';

  @override
  String get storageMgmtSuggestionsTitle => '可释放空间';

  @override
  String get storageMgmtSuggestCache => '缓存';

  @override
  String storageMgmtSuggestCacheSubtitle(String size) {
    return '可清理 $size，最近一小时内用到的会保留';
  }

  @override
  String get storageMgmtSuggestUnused => '未使用的文件';

  @override
  String storageMgmtSuggestUnusedSubtitle(int count, String size) {
    return '$count 个没有日记在用的文件，共 $size';
  }

  @override
  String get storageMgmtSuggestTrash => '回收站里的日记';

  @override
  String storageMgmtSuggestTrashSubtitle(int count, String size) {
    return '$count 个文件只被回收站里的日记使用，共 $size';
  }

  @override
  String get storageMgmtSuggestCompress => '可压缩的照片与视频';

  @override
  String storageMgmtSuggestCompressSubtitle(int count, String size) {
    return '$count 项，约可节省 $size';
  }

  @override
  String get storageMgmtSuggestDatabase => '整理日记数据';

  @override
  String storageMgmtSuggestDatabaseSubtitle(String size) {
    return '可释放已删除内容留下的 $size';
  }

  @override
  String get storageMgmtClear => '清理';

  @override
  String get storageMgmtCompact => '整理';

  @override
  String get storageMgmtAllClean => '已经很整洁了';

  @override
  String get storageMgmtAllCleanSubtitle => '现在没有可清理的缓存和未使用的文件';

  @override
  String get storageMgmtMediaTitle => '媒体文件';

  @override
  String get storageMgmtAllMedia => '全部媒体';

  @override
  String storageMgmtFileCount(int count) {
    return '$count 个文件';
  }

  @override
  String get storageMgmtLargeFiles => '大文件';

  @override
  String get storageMgmtOtherTitle => '其他数据';

  @override
  String get storageMgmtFooter =>
      '删除与压缩会在下次局域网同步时带到其他设备；网盘里较早的备份仍保留原文件，直到按保留份数清理。';

  @override
  String get storageMgmtCleaning => '正在清理…';

  @override
  String get storageMgmtDeleting => '正在删除…';

  @override
  String storageMgmtFreed(String size) {
    return '已释放 $size';
  }

  @override
  String get storageMgmtNothingFreed => '现在没有可清理的内容';

  @override
  String get storageMgmtBusyEditing => '有日记正在编辑，请先关闭编辑页再试';

  @override
  String get storageMgmtBusyUndo => '请等撤销提示消失后再试';

  @override
  String get storageMgmtCannotDelete => '它被日记的其他数据引用着，不能在这里删除';

  @override
  String storageMgmtDeleteTitle(int count) {
    return '删除 $count 个文件？';
  }

  @override
  String storageMgmtDeleteBody(String size) {
    return '将释放 $size，并从以下位置移除：';
  }

  @override
  String storageMgmtDeleteFromDiaries(int count) {
    return '$count 篇日记';
  }

  @override
  String storageMgmtDeleteFromNotebooks(int count) {
    return '$count 个日记本封面';
  }

  @override
  String storageMgmtDeleteFromComments(int count) {
    return '$count 条留言';
  }

  @override
  String storageMgmtDeleteFromDrafts(int count) {
    return '$count 份草稿';
  }

  @override
  String storageMgmtDeleteFromAiChats(int count) {
    return '$count 条 AI 对话消息';
  }

  @override
  String get storageMgmtDeleteCommentNote => '删除后既没有文字也没有图片的留言会一并删除。';

  @override
  String get storageMgmtDeleteAiChatNote => 'AI 对话里这些图片会显示为已删除，消息本身保留。';

  @override
  String get storageMgmtDeleteCapsuleNote => '其中包含尚未解封的时间胶囊里的内容。';

  @override
  String get storageMgmtDeleteIrreversible => '删除后无法恢复。';

  @override
  String storageMgmtDeleted(int count, String size) {
    return '已删除 $count 个文件，释放 $size';
  }

  @override
  String storageMgmtSkippedRows(int count) {
    return '$count 处内容刚被修改，已跳过。';
  }

  @override
  String get storageMgmtCompress => '压缩';

  @override
  String storageMgmtCompressTitle(int count) {
    return '压缩 $count 个文件';
  }

  @override
  String get storageMgmtCompressImages => '照片';

  @override
  String get storageMgmtCompressVideos => '视频';

  @override
  String get storageMgmtPresetHigh => '高清';

  @override
  String get storageMgmtPresetBalanced => '均衡';

  @override
  String get storageMgmtPresetCompact => '省空间';

  @override
  String storageMgmtImagePresetDetail(
    int maxSide,
    int quality,
    String estimate,
  ) {
    return '最长边 $maxSide px · 画质 $quality · $estimate';
  }

  @override
  String storageMgmtPresetEstimate(String before, String after) {
    return '$before → 约 $after';
  }

  @override
  String get storageMgmtPresetNoGain => '已经足够小，无需压缩';

  @override
  String storageMgmtCompressSummary(String before, String after, String saved) {
    return '$before → 约 $after，约节省 $saved';
  }

  @override
  String get storageMgmtCompressNothing => '这些文件都不需要压缩';

  @override
  String storageMgmtCompressSkipped(int count) {
    return '$count 个文件已经足够小或格式不适合压缩，会跳过。';
  }

  @override
  String get storageMgmtCompressNote => '压缩后会替换原文件，无法恢复；照片的拍摄时间和位置会保留。';

  @override
  String get storageMgmtCompressStart => '开始压缩';

  @override
  String get storageMgmtCompressing => '正在压缩';

  @override
  String get storageMgmtCompressPreparing => '正在准备…';

  @override
  String storageMgmtCompressStep(int index, int total, String name) {
    return '第 $index/$total 项 · $name';
  }

  @override
  String get storageMgmtCancelling => '正在停止…';

  @override
  String get storageMgmtCompressFinished => '压缩完成';

  @override
  String get storageMgmtCompressCancelled => '已停止压缩';

  @override
  String storageMgmtCompressDone(int count, String size) {
    return '已压缩 $count 个文件，节省 $size';
  }

  @override
  String storageMgmtCompressUnchanged(int count) {
    return '$count 个文件压缩后没有变小，已保留原文件。';
  }

  @override
  String storageMgmtCompressFailed(int count) {
    return '$count 个文件压缩失败。';
  }

  @override
  String get storageMgmtCompressNoneDone => '没有压缩任何文件。';

  @override
  String get storageMgmtDone => '完成';

  @override
  String storageMgmtCompressSaving(String size) {
    return '压缩 · 约省 $size';
  }

  @override
  String storageMgmtSelectedCount(int count) {
    return '已选择 $count 项';
  }

  @override
  String storageMgmtSelectionSummary(int count, String size) {
    return '已选 $count 项 · 共 $size';
  }

  @override
  String storageMgmtListSummary(int count, String size) {
    return '共 $count 项 · $size';
  }

  @override
  String get storageMgmtFilterAll => '全部';

  @override
  String get storageMgmtFilterLarge => '大文件';

  @override
  String get storageMgmtFilterCompressible => '可压缩';

  @override
  String get storageMgmtFilterTrash => '仅回收站';

  @override
  String get storageMgmtSort => '排序';

  @override
  String get storageMgmtSortLargest => '从大到小';

  @override
  String get storageMgmtSortNewest => '从新到旧';

  @override
  String get storageMgmtSortOldest => '从旧到新';

  @override
  String get storageMgmtViewGrid => '网格显示';

  @override
  String get storageMgmtViewList => '列表显示';

  @override
  String get storageMgmtEmpty => '这里没有文件';

  @override
  String storageMgmtPrivateHidden(int count) {
    return '$count 项来自私密日记，已隐藏预览';
  }

  @override
  String get storageMgmtReveal => '显示';

  @override
  String get storageMgmtRevealReason => '验证身份以显示私密日记里的媒体';

  @override
  String get storageMgmtRevealUnavailable => '这台设备无法验证身份，请先设置应用密码';

  @override
  String get storageMgmtBadgeTrash => '回收站';

  @override
  String storageMgmtBadgeCompressible(String size) {
    return '可省 $size';
  }

  @override
  String get storageMgmtBadgeCompressShort => '可压缩';

  @override
  String storageMgmtBadgeUsedIn(int count) {
    return '用在 $count 处';
  }

  @override
  String get storageMgmtBadgeLocked => '不可删除';

  @override
  String get storageMgmtUntitledDiary => '无标题日记';

  @override
  String get storageMgmtUntitledDraft => '无标题草稿';

  @override
  String storageMgmtRefComment(String title) {
    return '留言 · $title';
  }

  @override
  String storageMgmtRefAiChat(String title) {
    return 'AI 对话 · $title';
  }

  @override
  String storageMgmtRefDiaryCover(String title) {
    return '封面 · $title';
  }

  @override
  String storageMgmtRefNotebookCover(String name) {
    return '日记本封面 · $name';
  }

  @override
  String storageMgmtRefDraft(String title) {
    return '草稿 · $title';
  }

  @override
  String get storageMgmtRefOther => '被其他数据引用';

  @override
  String get storageMgmtMaskedPrivate => '私密日记里的内容';

  @override
  String get storageMgmtMaskedCapsule => '未解封的时间胶囊里的内容';

  @override
  String storageMgmtUsedIn(int count) {
    return '用在 $count 处';
  }

  @override
  String get diaryTagFilterMultiSelectSemanticHint => '同时选中多个标签';

  @override
  String get diaryTagFilterMultiSelectTip => '长按标签可以同时选多个';

  @override
  String diaryTagFilterMultiSelectTipDesktop(String key) {
    return '按住 $key 再点标签可以同时选多个';
  }

  @override
  String get settingsPublishOnLeave => '返回时直接发表新日记';

  @override
  String get settingsPublishOnLeaveSubtitle => '写新日记时按返回，直接存成日记，不进草稿箱';

  @override
  String get publishOnLeaveFailedKeptDraft => '发表失败，这篇已留在草稿箱';

  @override
  String get settingsManualSave => '手动保存修改';

  @override
  String get settingsManualSaveSubtitle => '改已有的日记时不自动保存，点保存才写入；有未保存的修改时返回会先询问';

  @override
  String get diaryEditSaved => '已保存';

  @override
  String get storageMgmtAppTitle => '应用占用';

  @override
  String get storageMgmtCategoryApp => '应用本体';

  @override
  String get storageMgmtDeviceTitle => '手机存储';

  @override
  String storageMgmtDeviceTotal(String size) {
    return '共 $size';
  }

  @override
  String get storageMgmtDeviceUsedLabel => '已用';

  @override
  String get storageMgmtDeviceApp => '本应用';

  @override
  String get storageMgmtDeviceOther => '其他应用与系统';

  @override
  String get storageMgmtDeviceFree => '可用';

  @override
  String storageMgmtShareOfDevice(String percent) {
    return '占手机 $percent';
  }

  @override
  String get storageMgmtDeviceShareLabel => '占手机';

  @override
  String get storageMgmtReclaimable => '可释放';

  @override
  String get storageMgmtTopTitle => '占用最多';

  @override
  String get storageMgmtSeeAll => '查看全部';

  @override
  String get storageMgmtGrowthTitle => '媒体增长';

  @override
  String get storageMgmtGrowthByYear => '按日记日期，每年新增';

  @override
  String get storageMgmtGrowthByMonth => '按日记日期，近 12 个月每月新增';

  @override
  String storageMgmtGrowthPeak(String period, String size) {
    return '$period 新增最多，共 $size';
  }

  @override
  String get storageMgmtOpenExternally => '用其他应用打开';

  @override
  String backupImportTodoCount(int count) {
    return '待办 $count 条';
  }

  @override
  String backupImportExistingTodoCount(int count) {
    return '其中 $count 条待办本机已存在';
  }

  @override
  String backupImportModeOverwriteTodosOnly(int count) {
    return '添加新内容，并用文件中的版本替换本机已存在的 $count 条待办';
  }

  @override
  String backupImportModeOverwriteTodosExtra(int count) {
    return '同时替换本机已存在的 $count 条待办';
  }

  @override
  String backupOverwriteAllTodos(int count) {
    return '$count 条待办';
  }

  @override
  String backupOverwriteExistingTodosBody(int count) {
    return '本机已存在的 $count 条待办将被文件中的版本替换。';
  }

  @override
  String backupImportTodoMergeResult(int added) {
    return '待办：新增 $added 条';
  }

  @override
  String backupImportTodoOverwriteResult(int added, int replaced) {
    return '待办：新增 $added 条，覆盖 $replaced 条';
  }

  @override
  String get navTodos => '待办';

  @override
  String get appSurfaceAreaTodos => '待办';

  @override
  String get settingsFeaturesTodosSubtitle => '独立于日记的待办、清单与提醒';

  @override
  String get todoViewToday => '今天';

  @override
  String get todoViewPlanned => '计划';

  @override
  String get todoViewImportant => '重要';

  @override
  String get todoViewAll => '全部';

  @override
  String get todoViewCompleted => '已完成';

  @override
  String get todoViewInbox => '收集箱';

  @override
  String get todoGroupOverdue => '已逾期';

  @override
  String get todoGroupToday => '今天';

  @override
  String get todoGroupTomorrow => '明天';

  @override
  String get todoGroupNextDays => '未来七天';

  @override
  String get todoGroupLater => '更晚';

  @override
  String get todoNew => '新待办';

  @override
  String get todoQuickAddHint => '要做什么？';

  @override
  String get todoQuickAddSubmit => '添加';

  @override
  String get todoSearchHint => '搜索待办';

  @override
  String get todoEmptyToday => '今天没有要做的事';

  @override
  String get todoEmptyList => '这里还没有待办';

  @override
  String get todoEmptyCompleted => '还没有完成的待办';

  @override
  String get todoEmptySearch => '没有找到相关的待办';

  @override
  String todoSortLabel(String mode) {
    return '排序：$mode';
  }

  @override
  String get todoSortManual => '手动';

  @override
  String get todoSortDue => '截止日期';

  @override
  String get todoSortPriority => '优先级';

  @override
  String get todoSortCreated => '创建时间';

  @override
  String get todoSortTitle => '排序方式';

  @override
  String get todoShowCompleted => '显示已完成';

  @override
  String get todoHideCompleted => '隐藏已完成';

  @override
  String get todoClearCompleted => '清除已完成';

  @override
  String get todoClearCompletedTitle => '清除已完成的待办？';

  @override
  String todoClearCompletedBody(int count) {
    return '将删除 $count 条已完成的待办，可以在提示里撤销。';
  }

  @override
  String todoClearedCount(int count) {
    return '已清除 $count 条';
  }

  @override
  String get todoCompletedNotice => '已完成';

  @override
  String todoCompletedNextNotice(String date) {
    return '已完成，下一次：$date';
  }

  @override
  String get todoDeletedNotice => '已删除待办';

  @override
  String get todoDelete => '删除待办';

  @override
  String get todoMarkDone => '标为完成';

  @override
  String get todoMarkUndone => '标为未完成';

  @override
  String get todoMore => '更多';

  @override
  String get todoListsSection => '清单';

  @override
  String get todoListNew => '新建清单';

  @override
  String get todoListEdit => '编辑清单';

  @override
  String get todoListNameHint => '清单名称';

  @override
  String get todoListManage => '管理清单';

  @override
  String get todoListDelete => '删除清单';

  @override
  String todoListDeleteTitle(String name) {
    return '删除「$name」？';
  }

  @override
  String todoListDeleteBody(int count) {
    return '清单里的 $count 条待办会一起删除，可以在提示里撤销。';
  }

  @override
  String get todoListDeletedNotice => '已删除清单';

  @override
  String get todoListColor => '颜色';

  @override
  String get todoListIcon => '图标';

  @override
  String get todoListEmptyManage => '还没有清单。把待办按工作、生活等分开放，会更好找。';

  @override
  String get todoNoteHint => '添加备注';

  @override
  String get todoStepAdd => '添加步骤';

  @override
  String get todoStepDelete => '删除步骤';

  @override
  String todoStepsProgress(int done, int total) {
    return '$done/$total';
  }

  @override
  String get todoFieldDue => '日期';

  @override
  String get todoFieldReminders => '提醒';

  @override
  String get todoFieldRepeat => '重复';

  @override
  String get todoFieldPriority => '优先级';

  @override
  String get todoFieldList => '清单';

  @override
  String get todoFieldDiary => '关联日记';

  @override
  String get todoFieldDiaryMissing => '日记不存在或已删除';

  @override
  String todoCreatedAt(String time) {
    return '创建于 $time';
  }

  @override
  String todoCompletedAt(String time) {
    return '完成于 $time';
  }

  @override
  String get todoNotFound => '这条待办已被删除';

  @override
  String get todoPriorityNone => '无';

  @override
  String get todoPriorityLow => '低';

  @override
  String get todoPriorityMedium => '中';

  @override
  String get todoPriorityHigh => '高';

  @override
  String get todoDueToday => '今天';

  @override
  String get todoDueTomorrow => '明天';

  @override
  String get todoDueYesterday => '昨天';

  @override
  String get todoDueNextWeek => '下周一';

  @override
  String get todoDuePickDate => '选择日期…';

  @override
  String get todoDueAllDay => '全天';

  @override
  String get todoDueSetTime => '设置时间';

  @override
  String get todoDueRemove => '移除日期';

  @override
  String todoDueWithTime(String date, String time) {
    return '$date $time';
  }

  @override
  String get todoReminderAtDue => '准时提醒';

  @override
  String todoReminderMinutesBefore(int count) {
    return '提前 $count 分钟';
  }

  @override
  String todoReminderHoursBefore(int count) {
    return '提前 $count 小时';
  }

  @override
  String todoReminderDaysBefore(int count) {
    return '提前 $count 天';
  }

  @override
  String todoReminderOnDayAt(String time) {
    return '当天 $time';
  }

  @override
  String todoReminderDaysBeforeAt(int count, String time) {
    return '提前 $count 天 $time';
  }

  @override
  String get todoReminderCustom => '自定义时间…';

  @override
  String todoReminderLimit(int count) {
    return '最多 $count 个提醒';
  }

  @override
  String get todoReminderRemove => '移除提醒';

  @override
  String get todoRepeatNone => '不重复';

  @override
  String get todoRepeatDaily => '每天';

  @override
  String get todoRepeatLegalWorkdays => '法定工作日';

  @override
  String todoRepeatWeeklyOn(String days) {
    return '每周$days';
  }

  @override
  String todoRepeatMonthlyOnDay(int day) {
    return '每月 $day 日';
  }

  @override
  String todoRepeatMonthlyOrdinal(String ordinal, String weekday) {
    return '每月第 $ordinal 个$weekday';
  }

  @override
  String get todoRepeatMonthlyLastDay => '每月最后一天';

  @override
  String todoRepeatYearlyOn(String date) {
    return '每年 $date';
  }

  @override
  String todoRepeatEveryDays(int count) {
    return '每 $count 天';
  }

  @override
  String todoRepeatEveryWeeks(int count) {
    return '每 $count 周';
  }

  @override
  String todoRepeatEveryMonths(int count) {
    return '每 $count 个月';
  }

  @override
  String todoRepeatEveryYears(int count) {
    return '每 $count 年';
  }

  @override
  String todoRepeatSummaryJoin(String a, String b) {
    return '$a · $b';
  }

  @override
  String get todoRepeatCustom => '自定义…';

  @override
  String get todoRepeatCustomTitle => '自定义重复';

  @override
  String get todoRepeatUnitDay => '天';

  @override
  String get todoRepeatUnitWeek => '周';

  @override
  String get todoRepeatUnitMonth => '月';

  @override
  String get todoRepeatUnitYear => '年';

  @override
  String get todoRepeatInterval => '间隔';

  @override
  String get todoRepeatOnDays => '在这几天';

  @override
  String get todoRepeatFromCompletion => '从完成那天起算';

  @override
  String get todoRepeatFromCompletionSubtitle => '适合浇花这类“做完隔几天再做”的事';

  @override
  String get todoRepeatEnds => '结束';

  @override
  String get todoRepeatEndsNever => '永不';

  @override
  String todoRepeatEndsOn(String date) {
    return '到 $date';
  }

  @override
  String todoRepeatEndsAfter(int count) {
    return '共 $count 次';
  }

  @override
  String get todoRepeatEndsOnPick => '到某一天';

  @override
  String get todoRepeatEndsAfterPick => '重复几次后';

  @override
  String get todoSettingsTitle => '待办';

  @override
  String get todoSettingsSubtitle => '清单、显示与提醒';

  @override
  String get todoSettingsDisplayGroup => '显示';

  @override
  String get todoSettingsShowCompletedSubtitle => '在清单和收集箱底部显示已完成的待办';

  @override
  String get todoSettingsDefaultList => '新待办默认放进';

  @override
  String get todoSettingsDefaultView => '打开时显示';

  @override
  String get todoNotificationChannel => '待办提醒';

  @override
  String get todoNotificationChannelDescription => '待办到了设定的提醒时间时通知你';

  @override
  String get todoNotificationComplete => '完成';

  @override
  String get todoNotificationSnooze => '稍后提醒';

  @override
  String get todoNotificationOpen => '打开';

  @override
  String get todoNotificationSnoozedBody => '稍后提醒';

  @override
  String get todoSettingsRemindersGroup => '提醒';

  @override
  String get todoSettingsPermission => '通知权限';

  @override
  String get todoSettingsPermissionOn => '已允许';

  @override
  String get todoSettingsPermissionOff => '未允许，点按开启';

  @override
  String get todoSettingsExactOff => '系统限制了准时闹钟，提醒可能晚几分钟';

  @override
  String get todoSettingsAllDayTime => '全天待办的提醒时刻';

  @override
  String get todoSettingsSnooze => '稍后提醒';

  @override
  String todoSettingsSnoozeMinutes(int count) {
    return '$count 分钟';
  }

  @override
  String get todoSettingsHideContent => '锁屏时隐藏内容';

  @override
  String get todoSettingsHideContentSubtitle => '锁屏上只显示有一条提醒，解锁后才看得到内容';

  @override
  String get todoSettingsDesktopNote => '电脑上只在 Jotsy 打开时提醒，关掉应用后到点的提醒不会弹出。';

  @override
  String get todoSettingsReliability => '提醒不准时？';

  @override
  String get todoSettingsReliabilityBody =>
      '部分手机系统会限制后台应用。如果提醒经常不响或延迟，请在系统设置里允许 Jotsy 自启动、关闭对 Jotsy 的电池优化，并确认“通知”和“闹钟和提醒”权限已开启。';

  @override
  String get todoReminderPermissionDenied => '通知权限未开启，提醒不会弹出';

  @override
  String get todoReminderPermissionAction => '去开启';

  @override
  String get calendarShowTodos => '显示待办';

  @override
  String get calendarShowTodosDescription => '在日期上标出有待办的日子，选中时列出这天的待办';

  @override
  String get calendarAddTodo => '添加待办';

  @override
  String get calendarTodoSectionTitle => '这天的待办';

  @override
  String get calendarTodoRepeatHint => '重复待办的这一次，到时候再勾选';

  @override
  String get diaryPreviewAddTodo => '添加待办';

  @override
  String get diaryPreviewConvertTodos => '转为独立待办';

  @override
  String get todoConvertTitle => '转为独立待办';

  @override
  String get todoConvertHint => '选中的项会加进待办并关联这篇日记，日记正文不变。';

  @override
  String todoConvertSubmit(int count) {
    return '添加 $count 条';
  }

  @override
  String todoConvertDone(int count) {
    return '已添加 $count 条待办';
  }

  @override
  String get diaryLinkedTodosTitle => '相关待办';

  @override
  String get todoBatchActionComplete => '完成';

  @override
  String get todoDuplicate => '复制为新待办';

  @override
  String todoDuplicateTitle(String title) {
    return '$title（副本）';
  }

  @override
  String get todoDuplicatedNotice => '已复制为新待办';

  @override
  String get todoGroupCompletedTitle => '已完成';

  @override
  String get todoGroupCompletedToday => '今天已完成';

  @override
  String get todoHeroAllDone => '今天的事都做完了';

  @override
  String get todoHeroNothing => '今天没有安排';

  @override
  String todoHeroDate(String weekday, String date) {
    return '$weekday · $date';
  }

  @override
  String todoHeroRemaining(int count) {
    return '还有 $count 件';
  }

  @override
  String todoHeroOverdue(int count) {
    return '逾期 $count';
  }

  @override
  String todoHeroDone(int count) {
    return '已完成 $count';
  }

  @override
  String todoHeroListProgress(int done, int total) {
    return '已完成 $done / $total';
  }

  @override
  String todoHeroOpenCount(int count) {
    return '$count 条未完成';
  }

  @override
  String todoHeroCompletedCount(int count) {
    return '最近完成 $count 条';
  }

  @override
  String get todoInlineAddHint => '添加待办';

  @override
  String get todoListManageShort => '管理';

  @override
  String get todoMoveOverdueToToday => '全部改到今天';

  @override
  String get todoMoveToToday => '改到今天';

  @override
  String get todoMoveToList => '移到清单…';

  @override
  String get todoNoteTitle => '备注';

  @override
  String get todoStepsTitle => '步骤';

  @override
  String todoStepsTitleProgress(int done, int total) {
    return '步骤 $done/$total';
  }

  @override
  String get todoOpenDiary => '打开日记';

  @override
  String get todoQuickParseDismiss => '移除';

  @override
  String todoRemindersCount(int count) {
    return '$count 个提醒';
  }

  @override
  String todoSelectedCount(int count) {
    return '已选 $count';
  }

  @override
  String get todoSelectionExit => '退出多选';

  @override
  String get todoViewSheetTitle => '切换视图';

  @override
  String todoBatchCompleted(int count) {
    return '已完成 $count 条';
  }

  @override
  String todoBatchDeleted(int count) {
    return '已删除 $count 条';
  }

  @override
  String todoBatchDueRemoved(int count) {
    return '已移除 $count 条的日期';
  }

  @override
  String todoBatchDueSet(int count, String date) {
    return '已将 $count 条改到$date';
  }

  @override
  String todoBatchMoved(int count, String list) {
    return '已将 $count 条移到「$list」';
  }

  @override
  String todoBatchPrioritySet(int count, String priority) {
    return '已将 $count 条设为$priority优先级';
  }

  @override
  String get todoSettingsSmartParse => '智能识别';

  @override
  String get todoSettingsSmartParseSubtitle => '把“明天下午3点 #工作 !!!”识别为日期、清单与优先级';

  @override
  String get aiToolOpenPageAny => '打开页面';

  @override
  String get aiToolOpensAfterReply => '回答后自动打开';

  @override
  String get aiListSeparator => '、';

  @override
  String aiToolNamesAndMore(String names, int count) {
    return '$names 等 $count 项';
  }

  @override
  String aiToolArgRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String aiToolArgSince(String date) {
    return '$date 起';
  }

  @override
  String aiToolArgUntil(String date) {
    return '到 $date';
  }

  @override
  String get aiToolArgYes => '是';

  @override
  String get aiToolArgNo => '否';

  @override
  String aiToolArgMinutes(int minutes) {
    return '$minutes 分钟';
  }

  @override
  String aiToolArgName(String key) {
    String _temp0 = intl.Intl.selectLogic(key, {
      'arg_date_range': '日期',
      'arg_due_range': '截止日期',
      'arg_merge_from': '合并这些标签',
      'arg_query': '关键词',
      'arg_tags': '标签',
      'arg_mood': '心情',
      'arg_include_archived': '包括已归档',
      'arg_sort': '排序',
      'arg_limit': '最多',
      'arg_group_by': '分组',
      'arg_date': '日期',
      'arg_time': '时间',
      'arg_title': '标题',
      'arg_name': '名称',
      'arg_note': '备注',
      'arg_color': '颜色',
      'arg_weather': '天气',
      'arg_location': '地点',
      'arg_text': '内容',
      'arg_body': '正文',
      'arg_priority': '优先级',
      'arg_list': '清单',
      'arg_status': '状态',
      'arg_scale': '字体大小',
      'arg_repeat': '重复',
      'arg_remove': '去掉的标签',
      'arg_add': '加上的标签',
      'arg_remind_before_minutes': '提前提醒',
      'arg_parent_id': '上级日记本',
      'arg_offset': '从第几个字读起',
      'arg_new_name': '新名称',
      'arg_mode': '外观',
      'arg_language': '语言',
      'arg_into': '合并到',
      'arg_feature': '功能',
      'arg_enabled': '开启',
      'arg_clear_due': '清除截止日期',
      'arg_kind_diary': '日记',
      'arg_kind_notebook': '日记本',
      'arg_kind_tag': '标签',
      'arg_kind_todo': '待办',
      'arg_kind_anniversary': '纪念日',
      'arg_kind_day': '日期',
      'arg_steps': '步骤',
      'arg_reminders': '提醒',
      'arg_add_steps': '添加步骤',
      'arg_check_steps': '勾选步骤',
      'arg_uncheck_steps': '取消勾选',
      'arg_remove_steps': '删除步骤',
      'arg_all_day': '全天',
      'arg_kind_todoList': '待办清单',
      'arg_images': '图片',
      'arg_attachments': '对话里的图片',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String aiToolArgValue(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'sort_relevant': '按相关程度',
      'sort_newest': '从新到旧',
      'sort_oldest': '从旧到新',
      'group_by_none': '不分组',
      'group_by_day': '按天',
      'group_by_week': '按周',
      'group_by_month': '按月',
      'group_by_year': '按年',
      'status_open': '未完成',
      'status_completed': '已完成',
      'status_all': '全部',
      'priority_none': '无',
      'priority_low': '低',
      'priority_medium': '中',
      'priority_high': '高',
      'repeat_once': '不重复',
      'repeat_yearly': '每年（公历）',
      'repeat_lunar_yearly': '每年（农历）',
      'mood_awful': '很糟',
      'mood_bad': '不好',
      'mood_meh': '一般',
      'mood_good': '不错',
      'mood_great': '很棒',
      'mood_clear': '清除',
      'mode_light': '浅色',
      'mode_dark': '深色',
      'mode_system': '跟随系统',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String aiToolAddToNotebookNamed(int count, String name) {
    return '把 $count 篇日记收进「$name」';
  }

  @override
  String aiToolRemoveFromNotebookNamed(int count, String name) {
    return '把 $count 篇日记移出「$name」';
  }

  @override
  String get aiChatReturnHint => '按返回键即可回到刚才的对话';

  @override
  String get aiChatReturnAction => '回到对话';

  @override
  String aiProcessThoughtFor(int seconds) {
    return '思考了 $seconds 秒';
  }

  @override
  String aiProcessThinkingFor(int seconds) {
    return '正在思考 · $seconds 秒';
  }

  @override
  String get aiProcessThought => '已思考';

  @override
  String aiProcessTools(int count) {
    return '调用了 $count 个工具';
  }

  @override
  String aiProcessFailed(int count) {
    return '$count 个未成功';
  }

  @override
  String get aiProcessSteps => '查看过程';

  @override
  String get aiToolDetailsInputs => '条件';

  @override
  String get aiToolDetailsResult => '结果';

  @override
  String get aiToolDetailsFailed => '这一步没有成功';

  @override
  String get aiToolDetailsTechnical => '技术信息';

  @override
  String aiCardEntries(int count) {
    return '$count 篇';
  }

  @override
  String aiCardTodoDue(String date) {
    return '$date截止';
  }

  @override
  String get aiCardTodoDone => '已完成';

  @override
  String aiCardSearchFor(String query) {
    return '搜索「$query」';
  }

  @override
  String get aiCardSectionHome => '首页';

  @override
  String get aiCardMissing => '已经不在了';

  @override
  String get aiCardFeatureOff => '功能已关闭';

  @override
  String aiChangeGroupTitle(int count) {
    return '做了 $count 项改动';
  }

  @override
  String get aiChangeUndoAll => '全部撤销';

  @override
  String get aiChatNewChat => '新对话';

  @override
  String get aiChatHistory => '对话记录';

  @override
  String get aiChatHistoryEmpty => '还没有对话';

  @override
  String get aiChatHistoryNoMatch => '没有找到相关的对话';

  @override
  String get aiChatGroupPinned => '置顶';

  @override
  String get aiChatGroupToday => '今天';

  @override
  String get aiChatGroupYesterday => '昨天';

  @override
  String get aiChatGroupWeek => '最近 7 天';

  @override
  String get aiChatGroupMonth => '最近 30 天';

  @override
  String get aiChatWelcomeTitle => '今天想聊点什么？';

  @override
  String get aiChatWelcomeAgent => '可以问我日记里的事，也可以让我帮你整理日记、记待办、打开页面。';

  @override
  String get aiChatWelcomeRetrieval => '可以问我日记里的事，我会先找到相关的日记再回答。';

  @override
  String get aiChatWelcomeRecaps => '回顾';

  @override
  String get aiChatWelcomeRecent => '最近的对话';

  @override
  String get aiChatWelcomeAllChats => '全部对话';

  @override
  String get aiChatModelSheetTitle => '模型与思考';

  @override
  String get aiChatThinking => '思考强度';

  @override
  String get aiThinkingAuto => '自动';

  @override
  String get aiThinkingOff => '关';

  @override
  String get aiThinkingLow => '低';

  @override
  String get aiThinkingMedium => '中';

  @override
  String get aiThinkingHigh => '高';

  @override
  String get aiThinkingAutoHint => '由模型自己决定要不要思考、想多久';

  @override
  String get aiThinkingOffHint => '不思考，直接回答，最快';

  @override
  String get aiThinkingLowHint => '简单想一想，适合日常问答';

  @override
  String get aiThinkingMediumHint => '多数问题的平衡之选';

  @override
  String get aiThinkingHighHint => '仔细推敲，适合整理、回顾与复杂的改动，最慢';

  @override
  String get aiThinkingDisabled => '这个模型在模型设置里关闭了思考';

  @override
  String aiChatMetaThinking(String level) {
    return '思考：$level';
  }

  @override
  String get aiChatOpenSettings => 'AI 设置';

  @override
  String get aiChatExport => '导出对话';

  @override
  String get aiChatExportFormat => '格式';

  @override
  String get aiChatExportMarkdown => 'Markdown';

  @override
  String get aiChatExportPlain => '纯文本';

  @override
  String get aiChatExportInclude => '包含';

  @override
  String get aiChatExportReasoning => '思考过程';

  @override
  String get aiChatExportSteps => '过程与操作';

  @override
  String get aiChatExportMessages => '选择消息';

  @override
  String aiChatExportSelected(int count, int total) {
    return '已选 $count / $total 条';
  }

  @override
  String get aiChatExportYou => '你';

  @override
  String get aiChatExportSave => '保存到文件';

  @override
  String get aiChatExportSaved => '对话已导出';

  @override
  String get aiChatExportFailed => '导出没有成功';

  @override
  String aiChatExportAt(String time, int count) {
    return '导出于 $time · 共 $count 条消息';
  }

  @override
  String get aiChatExportReferences => '参考的日记';

  @override
  String aiChatExportError(String reason) {
    return '出错：$reason';
  }

  @override
  String aiChatExportSubjects(String names) {
    return '：$names';
  }

  @override
  String get aiChatExportJson => 'JSON';
}
