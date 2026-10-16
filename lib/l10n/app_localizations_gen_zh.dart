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
  String get aboutCheckUpdateSubtitle => '自动检测 Release 并跳转下载 APK';

  @override
  String aboutUpdateAlreadyLatest(String version) {
    return '当前已是最新版本（$version）';
  }

  @override
  String aboutUpdateOpeningDownload(String version) {
    return '发现新版本（$version），正在打开下载链接';
  }

  @override
  String get aboutUpdateOpenBrowserFailed => '无法自动打开浏览器，请稍后重试';

  @override
  String get aboutUpdateCheckFailed => '检查更新失败，请检查网络后重试';

  @override
  String get aboutUpdateNoApkFound => '已发现新版本，但未解析到可下载 APK';

  @override
  String aboutUpdateDialogTitle(String version) {
    return '发现新版本 $version';
  }

  @override
  String get aboutUpdateDialogNoNotes => '该版本暂无更新说明。';

  @override
  String get aboutUpdateDialogConfirmDownload => '下载更新';

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
  String get autoT0081 => '发现未完成日记';

  @override
  String get autoT0082 => '新建空笔记';

  @override
  String get autoT0083 => '继续编辑';

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
  String autoT0089(String p0) {
    return '封面导入失败: $p0';
  }

  @override
  String autoT0090(String p0) {
    return '标签创建失败: $p0';
  }

  @override
  String autoT0091(String p0) {
    return '获取位置失败: $p0';
  }

  @override
  String get autoT0092 => '请先获取当前位置';

  @override
  String autoT0093(String p0) {
    return '获取天气失败: $p0';
  }

  @override
  String get autoT0094 => '删除日记';

  @override
  String get autoT0095 => '未命名日记';

  @override
  String get autoT0096 => '选择发表日期';

  @override
  String get autoT0097 => '选择发表时间';

  @override
  String autoT0098(String p0) {
    return '发布失败: $p0';
  }

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
  String get previewExportMarkdown => '导出为 Markdown';

  @override
  String get previewExportPdf => '导出为 PDF';

  @override
  String get previewExportSaveDialogTitle => '保存导出文件';

  @override
  String get previewExportSuccess => '导出成功';

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
  String get autoT0202 => '检测到你上次有未保存的日记，是否继续编辑？';

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
  String get autoT0209 => '检测到你上次有未保存的日记，是否继续编辑？';

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
  String get dataMgmtWebDav => 'WebDAV 同步';

  @override
  String get dataMgmtWebDavSubtitle => '备份到 NAS / 私有 WebDAV，并可从远程恢复';

  @override
  String get webDavTitle => 'WebDAV 同步';

  @override
  String get webDavConfigSection => '连接配置';

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
  String get webDavSaveConfig => '保存配置';

  @override
  String get webDavTestConnection => '测试连接';

  @override
  String get webDavUploadBackup => '上传当前备份';

  @override
  String get webDavRefreshBackups => '刷新列表';

  @override
  String get webDavBackupList => '远程备份';

  @override
  String get webDavNoBackups => '暂无远程备份';

  @override
  String get webDavConfigSaved => 'WebDAV 配置已保存';

  @override
  String get webDavConnectionOk => 'WebDAV 连接成功';

  @override
  String get webDavUploadSuccess => '备份已上传到 WebDAV';

  @override
  String get webDavRestoreSuccess => '已从 WebDAV 备份恢复数据';

  @override
  String get webDavDeleteSuccess => '远程备份已删除';

  @override
  String webDavOperationFailed(String error) {
    return '操作失败：$error';
  }

  @override
  String get webDavBusySave => '正在保存配置...';

  @override
  String get webDavBusyTest => '正在测试连接...';

  @override
  String get webDavBusyUpload => '正在上传备份...';

  @override
  String get webDavBusyRefresh => '正在读取远程备份...';

  @override
  String get webDavBusyRestore => '正在恢复备份...';

  @override
  String get webDavBusyDelete => '正在删除远程备份...';

  @override
  String get webDavBusyLabel => 'WebDAV 操作处理中';

  @override
  String get webDavHint =>
      '建议在 NAS 中为 Jotsy 创建独立目录，并优先使用应用专用密码或 Token。上传会生成完整 ZIP 备份；恢复时可选择合并或覆盖本地数据。';

  @override
  String get webDavDeleteConfirmTitle => '删除远程备份';

  @override
  String webDavDeleteConfirmContent(String fileName) {
    return '将从 WebDAV 服务器删除 $fileName，此操作不可撤销。';
  }

  @override
  String get webDavRestoreAction => '恢复';

  @override
  String get webDavDeleteAction => '删除';

  @override
  String webDavBackupSize(String size) {
    return '大小：$size';
  }

  @override
  String webDavBackupTime(String time) {
    return '时间：$time';
  }

  @override
  String get webDavPasswordDialogTitle => '备份密码';

  @override
  String get webDavPasswordDialogHint => '不填写则不加密；恢复加密备份时请输入原密码';

  @override
  String get webDavPasswordWarning => '请妥善保管备份密码。遗忘后无法恢复加密备份。';

  @override
  String get webDavContinueWithoutPassword => '继续';

  @override
  String get webDavConfigRequired => '请先填写并保存 WebDAV 配置';

  @override
  String get webDavErrorConfig => '请检查 WebDAV 地址、账号、密码和远程目录';

  @override
  String get webDavErrorAuth => '认证失败，请检查用户名和密码/Token';

  @override
  String get webDavErrorNotFound => '远程路径不存在，请检查 NAS WebDAV 目录';

  @override
  String get webDavErrorStorageFull => 'WebDAV 服务器存储空间不足';

  @override
  String get webDavErrorNetwork => '网络请求失败，请检查服务器地址、证书和网络状态';

  @override
  String get webDavErrorUnknown => '发生未知错误，请稍后重试';

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
  String get previewExportDiaryFile => '导出为日记文件';

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
  String calendarSummaryChars(String count) {
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
  String calendarDayStats(int entries, String chars) {
    return '$entries 篇 · $chars 字';
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
  String diaryCardCharCount(String count) {
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
  String get diaryCardStyleCustom => '自定义';

  @override
  String get diaryCardStyleResetDone => '已恢复默认样式';

  @override
  String get diaryCardStylePreviewLight => '浅色预览';

  @override
  String get diaryCardStylePreviewDark => '深色预览';

  @override
  String get diaryCardStylePanelHandle => '选项面板';

  @override
  String get diaryCardStylePanelCollapsed => '已收起';

  @override
  String get diaryCardStylePanelHalf => '半展开';

  @override
  String get diaryCardStylePanelExpanded => '已展开';

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
  String get diaryCardStylePresetsTitle => '内置风格';

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
  String diaryCardStyleApplied(String name) {
    return '已套用「$name」';
  }

  @override
  String get diaryCardStyleSavedTitle => '我的样式';

  @override
  String get diaryCardStyleSavedEmpty => '把调好的样式保存下来，随时一键切换';

  @override
  String get diaryCardStyleSaveCurrent => '保存当前样式';

  @override
  String diaryCardStyleSaveLimit(int count) {
    return '最多保存 $count 个样式';
  }

  @override
  String get diaryCardStyleSaveDialogTitle => '保存样式';

  @override
  String get diaryCardStyleRenameDialogTitle => '重命名样式';

  @override
  String get diaryCardStyleNameLabel => '样式名称';

  @override
  String diaryCardStyleDefaultName(int count) {
    return '我的样式 $count';
  }

  @override
  String get diaryCardStyleRename => '重命名';

  @override
  String diaryCardStyleSavedDone(String name) {
    return '已保存「$name」';
  }

  @override
  String diaryCardStyleDeletedDone(String name) {
    return '已删除「$name」';
  }

  @override
  String diaryCardStyleSavedActions(String name) {
    return '「$name」的更多操作';
  }

  @override
  String get diaryCardStyleShareTitle => '分享与导入';

  @override
  String get diaryCardStyleCopyCode => '复制样式码';

  @override
  String get diaryCardStyleCopyCodeSubtitle => '发给朋友，或留作这套样式的备份';

  @override
  String get diaryCardStyleImportCode => '从剪贴板导入';

  @override
  String get diaryCardStyleImportCodeSubtitle => '套用别人分享的样式码';

  @override
  String get diaryCardStyleCodeCopied => '样式码已复制';

  @override
  String get diaryCardStyleImportEmpty => '剪贴板是空的';

  @override
  String get diaryCardStyleImportInvalid => '剪贴板里没有可用的样式码';

  @override
  String get diaryCardStyleImportNewer => '已导入，部分来自新版本的设置可能未生效';

  @override
  String get diaryCardStyleImported => '已导入样式';

  @override
  String diaryCardStyleImportedNamed(String name) {
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
  String get diaryCardStyleEditColor => '编辑颜色';

  @override
  String get diaryCardStyleColorDarkAuto => '深色模式自动配色';

  @override
  String get diaryCardStyleColorDarkAutoSubtitle => '按浅色值推导出暗色下易读的颜色';

  @override
  String get diaryCardStyleHexLabel => 'HEX 颜色';

  @override
  String get diaryCardStyleHexInvalid => '请输入 6 位十六进制颜色，如 FFB300';

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
    return '已选 $selected/$total 张，微博等应用单次最多 9 张';
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
  String get diaryShareTargetQq => 'QQ';

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
    return '单次最多分享 $count 张图片，已取前 $count 张';
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
}
