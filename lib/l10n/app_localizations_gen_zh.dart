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
  String get settingsThemeMode => '主题模式';

  @override
  String get settingsThemeColor => '主题';

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
  String get settingsLanguageSubtitle => '切换应用语言';

  @override
  String get settingsAppearanceLanguage => '外观与语言';

  @override
  String get settingsAppLock => '应用锁';

  @override
  String get settingsAppLockSubtitle => '开启后每次进入应用都需要身份验证';

  @override
  String get appLockNotSupported => '当前设备不支持本地身份验证，无法启用应用锁。';

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
  String get settingsEditorSubtitle => '字体、行距、工具栏与心情符号';

  @override
  String get settingsEditorGroup => '编辑器';

  @override
  String get settingsEditorToolsGroup => '工具栏与心情';

  @override
  String get settingsMoodOptionsTitle => '心情符号';

  @override
  String get settingsMoodOptionsSubtitle => '自定义 10 个心情候选';

  @override
  String settingsMoodOptionsSlotLabel(String index) {
    return '心情 $index';
  }

  @override
  String settingsMoodOptionsSlotHelper(String emoji) {
    return '默认：$emoji';
  }

  @override
  String settingsMoodOptionsSaveFailed(String error) {
    return '保存心情符号失败: $error';
  }

  @override
  String get settingsDataPrivacy => '数据与隐私';

  @override
  String get settingsDataPrivacySubtitle => '管理备份、应用锁与回收站';

  @override
  String get settingsDataPrivacyTitle => '数据与隐私';

  @override
  String get settingsDataManagement => '数据管理';

  @override
  String get settingsDataManagementSubtitle => '导入/导出备份与日记文件';

  @override
  String get settingsTagManagement => '标签管理';

  @override
  String get settingsTagManagementSubtitle => '删除标签会自动解除与日记的关联关系';

  @override
  String get settingsTagMemory => '标签记忆';

  @override
  String get settingsTagMemorySubtitle => '记住日记列表已选标签，下次进入应用自动恢复';

  @override
  String get settingsRecycleBin => '回收站';

  @override
  String get settingsRecycleBinSubtitle => '管理已删除日记，可恢复或彻底删除';

  @override
  String get settingsAbout => '关于';

  @override
  String get settingsAboutSubtitle => '应用信息、项目地址与版本信息';

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
  String get aboutPrivacyDialogMessage => '你的日记、标签与媒体文件仅保存在本地设备，不会默认上传到云端。';

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
  String get autoT0060 => '情绪与精力趋势';

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
  String get autoT0066 => '总计记录';

  @override
  String get autoT0067 => '连续打卡';

  @override
  String get autoT0068 => '本月字数';

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
  String get autoT0148 => '已归档笔记';

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
  String get autoT0189 => '用于插入或切换为代码块';

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
  String autoT0195(String p0) {
    return '确认删除标签 \"$p0\" 吗？';
  }

  @override
  String get autoT0196 => '今天你最想感谢的人或事是什么？';

  @override
  String get autoT0197 => '加载图片失败，请稍后重试';

  @override
  String get autoT0198 => '继续记录天气、标签和心情后，这里会出现更具体的关联洞察。';

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
  String get timeCapsuleSealAction => '封存这篇日记';

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
  String get imageViewerSharing => '正在准备分享…';

  @override
  String imageViewerShareFailed(String error) {
    return '分享失败：$error';
  }

  @override
  String get imageViewerDownloadFailed => '图片下载失败，请检查网络后重试';

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
  String get diaryMediaImportUnsupported => '当前平台暂不支持文件导入';

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
  String get diarySortDescending => '倒序';

  @override
  String get diarySortAscending => '正序';

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
  String get calendarFilterClear => '清除筛选';

  @override
  String get calendarFilterDescription =>
      '日期格与统计只算符合条件的日记。同一类里任选其一即可，心情和标签都选时需同时满足。';

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
  String get diaryTypographyScopeHint => '作用于日记的编辑、阅读与发布页面；字体也用于日记标题。';

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
  String get diaryCardStyleShowUntitled => '没有标题时显示“无标题”';

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
  String get diaryCardStyleSourceMoodHint => '按每篇日记的心情取色；没有心情时用默认颜色';

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
  String get diaryCardStyleSheetEntry => '自定义卡片样式';

  @override
  String get diaryCardStyleSheetEntrySubtitle => '封面、文字、颜色与排版';

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
  String get diaryPreviewStylePresetMoodDesc => '整页跟着这篇的心情换颜色';

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
  String get diaryPreviewStyleSeedHint => '没有心情或标签的日记沿用应用主题色。';

  @override
  String get diaryPreviewStyleSeedColor => '基调颜色';

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
      '还没有备份位置。添加一个网盘、WebDAV 或对象存储，即可把完整备份上传到云端，换机或重装后从那里恢复。';

  @override
  String get cloudBackupAdd => '添加备份位置';

  @override
  String get cloudBackupHint => '地址、密码与网盘授权只保存在本机，不会写入备份文件；上传的是完整备份 ZIP，可选加密。';

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
  String get cloudBackupUploadBackup => '上传当前备份';

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
  String get timeCapsuleUnlockPassed => '解封时间已经过去，请重新选择后再封存';

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
  String publishTimeFollowsCapsule(String time) {
    return '跟随定时锁 · $time';
  }

  @override
  String get publishCoverChange => '点击更换';

  @override
  String get publishPanelSummaryEmpty => '添加标签、心情、地点…';

  @override
  String get publishPanelPublishShort => '发表';

  @override
  String get publishPanelSealShort => '封存';

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
  String get diaryDayPhotosAccessBody => '允许读取相册后，这里会列出这天拍的照片，可以挑几张插进日记。';

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
  String get diaryDayPhotosLimited => '只显示你允许访问的照片';

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
    return '$count 张照片已无法读取，没有插入';
  }

  @override
  String get settingsDayPhotoSuggestions => '自动显示当天照片';

  @override
  String get settingsDayPhotoSuggestionsSubtitle =>
      '补写过去某天的日记时，在标题下列出这天拍的照片；关闭后仍可从编辑页右上角菜单查看';

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
  String get diaryDayPhotosEmpty => '这天没有拍照片';

  @override
  String get diaryLongImageBadge => '长图';

  @override
  String get diaryImageMenuTitle => '图片';

  @override
  String get diaryImageMenuView => '查看';

  @override
  String get diaryImageMenuResize => '调整大小';

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
  String get diaryDraftsSettingsSubtitle => '未发布的新建日记，可继续编辑或删除';

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
  String get diaryTemplateDailyDesc => '记下今天发生的事和此刻的心情';

  @override
  String diaryTemplateDailyTitle(String date, String weekday) {
    return '$date $weekday';
  }

  @override
  String get diaryTemplateMorningName => '晨间日记';

  @override
  String get diaryTemplateMorningDesc => '用一页清晨的文字给今天定个方向';

  @override
  String diaryTemplateMorningTitle(String date) {
    return '晨间 · $date';
  }

  @override
  String get diaryTemplateEveningName => '晚间复盘';

  @override
  String get diaryTemplateEveningDesc => '回顾今天的得失，安排好明天';

  @override
  String diaryTemplateEveningTitle(String date) {
    return '复盘 · $date';
  }

  @override
  String get diaryTemplateGratitudeName => '感恩日记';

  @override
  String get diaryTemplateGratitudeDesc => '写下三件值得感谢的事';

  @override
  String diaryTemplateGratitudeTitle(String date) {
    return '感恩 · $date';
  }

  @override
  String get diaryTemplateQuestionName => '每日一问';

  @override
  String get diaryTemplateQuestionDesc => '每天一个问题，换个角度看自己';

  @override
  String diaryTemplateQuestionTitle(String date) {
    return '每日一问 · $date';
  }

  @override
  String get diaryTemplateWeeklyName => '周回顾';

  @override
  String get diaryTemplateWeeklyDesc => '一周的亮点、收获和下周计划';

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
  String get diaryTemplateDailyHappened => '今天发生了什么';

  @override
  String get diaryTemplateDailyMoment => '印象最深的一刻';

  @override
  String get diaryTemplateDailyMood => '此刻的心情';

  @override
  String diaryTemplateMorningWake(String time, String term) {
    return '$time 醒来，$term时节。';
  }

  @override
  String get diaryTemplateMorningTop3 => '今天最重要的三件事';

  @override
  String get diaryTemplateMorningLookForward => '我期待的事';

  @override
  String get diaryTemplateMorningWords => '给今天的一句话';

  @override
  String get diaryTemplateEveningDone => '今天完成了';

  @override
  String get diaryTemplateEveningWentWell => '做得好的地方';

  @override
  String get diaryTemplateEveningBetter => '可以更好的地方';

  @override
  String get diaryTemplateEveningTomorrow => '明天的安排';

  @override
  String get diaryTemplateGratitudeThree => '今天让我心怀感激的三件事：';

  @override
  String get diaryTemplateGratitudeThanks => '想对谁说声谢谢';

  @override
  String get diaryTemplateWeeklyHighlights => '本周亮点';

  @override
  String get diaryTemplateWeeklyWins => '完成与收获';

  @override
  String get diaryTemplateWeeklyOpen => '没做完的事';

  @override
  String get diaryTemplateWeeklyNext => '下周想做的事';

  @override
  String get diaryTemplateEmotionHappened => '发生了什么';

  @override
  String get diaryTemplateEmotionFelt => '我感受到的情绪';

  @override
  String get diaryTemplateEmotionSource => '它从哪里来';

  @override
  String get diaryTemplateEmotionNeed => '我需要什么';

  @override
  String get diaryTemplateEmotionStep => '接下来能做的一件小事';

  @override
  String get diaryTemplateReadingBook => '书名：';

  @override
  String get diaryTemplateReadingAuthor => '作者：';

  @override
  String get diaryTemplateReadingProgress => '读到：';

  @override
  String get diaryTemplateReadingQuotes => '摘录';

  @override
  String get diaryTemplateReadingThoughts => '我的想法';

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
  String get diaryTemplateHiddenBadge => '已隐藏';

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
  String get diaryTemplatesMineEmpty => '还没有自己的模板。点右上角 + 新建，或复制一个内置模板来改。';

  @override
  String get diaryTemplatesNew => '新建模板';

  @override
  String get diaryTemplatesImport => '导入模板码';

  @override
  String get diaryTemplatesMoreActions => '更多操作';

  @override
  String get diaryTemplatesDragHandle => '拖动排序';

  @override
  String get diaryTemplatesDuplicate => '复制';

  @override
  String get diaryTemplatesCopyToMine => '复制为我的模板';

  @override
  String get diaryTemplatesCopyCode => '复制模板码';

  @override
  String get diaryTemplatesHide => '隐藏';

  @override
  String get diaryTemplatesShow => '显示';

  @override
  String diaryTemplatesCopyName(String name) {
    return '$name 副本';
  }

  @override
  String diaryTemplatesDeleted(String name) {
    return '已删除「$name」';
  }

  @override
  String diaryTemplatesHiddenDone(String name) {
    return '已隐藏「$name」';
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
  String get notebookSettingsSubtitle => '整理、排序、合并你的日记本';

  @override
  String get notebookNew => '新建日记本';

  @override
  String get notebookEditTitle => '编辑日记本';

  @override
  String get notebookManage => '管理';

  @override
  String get notebookAllDiaries => '全部日记';

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
  String get notebookRulesPlaceholder => '规则：保存后在这里设置条件';

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
  String get notebookDragHandle => '拖动排序';

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
  String get notebookActionConvertHint => '规则设置完成后可用';

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
  String get notebookViewSortSection => '本日记本的排序';

  @override
  String get notebookViewOptionsEntry => '切换日记本';

  @override
  String get notebookViewOptionsEntrySubtitle => '只看某一本里的日记，或新建一本';

  @override
  String notebookUnlockReason(String name) {
    return '解锁「$name」';
  }

  @override
  String get notebookLockUnsupportedTitle => '无法打开上锁的日记本';

  @override
  String get notebookLockUnsupportedMessage =>
      '这台设备没有设置锁屏密码，无法验证身份，上锁的日记本暂时打不开。在系统设置里设置锁屏密码后就能打开。';

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
}
