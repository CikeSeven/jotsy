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
  String get settingsLanguage => '语言';

  @override
  String get settingsLanguageSubtitle => '切换应用语言';

  @override
  String get settingsEditorTitle => '编辑器设置';

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
}
