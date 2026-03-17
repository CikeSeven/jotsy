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
  String get settingsEditorGroup => '编辑器';

  @override
  String get settingsDataPrivacy => '数据与隐私';

  @override
  String get settingsDataPrivacySubtitle => '管理备份、应用锁与回收站';

  @override
  String get settingsDataPrivacyTitle => '数据与隐私';

  @override
  String get settingsDataManagement => '数据管理';

  @override
  String get settingsDataManagementSubtitle => '导入/导出 zip 备份文件';

  @override
  String get settingsTagManagement => '标签管理';

  @override
  String get settingsTagManagementSubtitle => '删除标签会自动解除与日记的关联关系';

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
  String get aboutSubmitIssue => '提交 Issue';

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
  String get aboutFooterMadeWith => 'Made by 柒月';

  @override
  String get aboutFooterCopyright => '© 2026 Jot Project';

  @override
  String get dataMgmtTitle => '数据管理';

  @override
  String get dataMgmtExport => '导出数据';

  @override
  String get dataMgmtExportSubtitle => '导出为 zip，包含日记、标签、设置与本地图片资源';

  @override
  String get dataMgmtImport => '导入数据';

  @override
  String get dataMgmtImportSubtitle => '从 zip 恢复数据，会覆盖当前内容';

  @override
  String get dataMgmtHint => '建议先执行一次导出备份，再进行导入操作。';

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
  String get dataMgmtImportConfirmTitle => '导入数据';

  @override
  String get dataMgmtImportConfirmContent => '导入会覆盖当前数据，确认继续吗？';

  @override
  String get dataMgmtImportAction => '导入';

  @override
  String get dataMgmtBusyLabel => '数据处理中';

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
  String get autoT0142 => '最近更新';

  @override
  String get autoT0143 => '最早更新';

  @override
  String get autoT0144 => '标题 A-Z';

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
}
