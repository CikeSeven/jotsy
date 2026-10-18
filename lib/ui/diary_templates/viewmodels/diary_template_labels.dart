import '../../../l10n/app_localizations_gen.dart';
import '../../diaries/models/time_capsule.dart';
import '../models/diary_template.dart';
import '../models/diary_template_variables.dart';

/// 模板相关枚举在界面上的名称。

String diaryTemplateCategoryLabel(
  AppLocalizations l10n,
  DiaryTemplateCategory category,
) => switch (category) {
  DiaryTemplateCategory.daily => l10n.diaryTemplateCategoryDaily,
  DiaryTemplateCategory.review => l10n.diaryTemplateCategoryReview,
  DiaryTemplateCategory.mood => l10n.diaryTemplateCategoryMood,
  DiaryTemplateCategory.life => l10n.diaryTemplateCategoryLife,
  DiaryTemplateCategory.work => l10n.diaryTemplateCategoryWork,
  DiaryTemplateCategory.other => l10n.diaryTemplateCategoryOther,
};

/// 胶囊预设的时长文字（与发布页胶囊快捷项同一组文案）。
String diaryTemplateCapsuleLabel(
  AppLocalizations l10n,
  TimeCapsulePreset preset,
) => switch (preset) {
  TimeCapsulePreset.week => l10n.timeCapsuleQuickWeek,
  TimeCapsulePreset.month => l10n.timeCapsuleQuickMonth,
  TimeCapsulePreset.year => l10n.timeCapsuleQuickYear,
};

/// 变量的名称（“日期”“Date”）。
String diaryTemplateVariableLabel(
  AppLocalizations l10n,
  DiaryTemplateVariable variable,
) => switch (variable) {
  DiaryTemplateVariable.date => l10n.diaryTemplateVarDateLabel,
  DiaryTemplateVariable.weekday => l10n.diaryTemplateVarWeekdayLabel,
  DiaryTemplateVariable.time => l10n.diaryTemplateVarTimeLabel,
  DiaryTemplateVariable.year => l10n.diaryTemplateVarYearLabel,
  DiaryTemplateVariable.month => l10n.diaryTemplateVarMonthLabel,
  DiaryTemplateVariable.day => l10n.diaryTemplateVarDayLabel,
  DiaryTemplateVariable.week => l10n.diaryTemplateVarWeekLabel,
  DiaryTemplateVariable.dayOfYear => l10n.diaryTemplateVarDayOfYearLabel,
  DiaryTemplateVariable.yearProgress => l10n.diaryTemplateVarYearProgressLabel,
  DiaryTemplateVariable.lunar => l10n.diaryTemplateVarLunarLabel,
  DiaryTemplateVariable.solarTerm => l10n.diaryTemplateVarSolarTermLabel,
  DiaryTemplateVariable.question => l10n.diaryTemplateVarQuestionLabel,
};

/// 插入时写进正文的占位（当前界面语言的写法，如 `{{日期}}`）。
String diaryTemplateVariableToken(
  AppLocalizations l10n,
  DiaryTemplateVariable variable,
) => diaryTemplateToken(switch (variable) {
  DiaryTemplateVariable.date => l10n.diaryTemplateVarDateToken,
  DiaryTemplateVariable.weekday => l10n.diaryTemplateVarWeekdayToken,
  DiaryTemplateVariable.time => l10n.diaryTemplateVarTimeToken,
  DiaryTemplateVariable.year => l10n.diaryTemplateVarYearToken,
  DiaryTemplateVariable.month => l10n.diaryTemplateVarMonthToken,
  DiaryTemplateVariable.day => l10n.diaryTemplateVarDayToken,
  DiaryTemplateVariable.week => l10n.diaryTemplateVarWeekToken,
  DiaryTemplateVariable.dayOfYear => l10n.diaryTemplateVarDayOfYearToken,
  DiaryTemplateVariable.yearProgress => l10n.diaryTemplateVarYearProgressToken,
  DiaryTemplateVariable.lunar => l10n.diaryTemplateVarLunarToken,
  DiaryTemplateVariable.solarTerm => l10n.diaryTemplateVarSolarTermToken,
  DiaryTemplateVariable.question => l10n.diaryTemplateVarQuestionToken,
});
