import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../../utils/date_range_format.dart';

/// 智能日记本规则在界面上的名称、说明、图标与一行摘要（纯函数）。
///
/// 规则编辑区的条件行、“添加条件”的类型面板与各编辑面板共用；摘要里的
/// 日期一律按界面语言格式化。

/// “添加条件”面板里可选的规则类型（与 JSON 的 `type` 一一对应，天气、地点、
/// 关键词在模型里同属 [NotebookTextRule]）。
enum NotebookRuleType {
  tags,
  mood,
  weather,
  location,
  keyword,
  date,
  media,
  flag,
}

/// 规则所属的类型；认不出的规则为 null。
NotebookRuleType? notebookRuleTypeOf(NotebookRule rule) => switch (rule) {
  NotebookTagsRule() => NotebookRuleType.tags,
  NotebookMoodRule() => NotebookRuleType.mood,
  NotebookTextRule(:final field) => switch (field) {
    NotebookTextField.weather => NotebookRuleType.weather,
    NotebookTextField.location => NotebookRuleType.location,
    NotebookTextField.keyword => NotebookRuleType.keyword,
  },
  NotebookDateRule() => NotebookRuleType.date,
  NotebookMediaRule() => NotebookRuleType.media,
  NotebookFlagRule() => NotebookRuleType.flag,
  NotebookUnknownRule() => null,
};

String notebookRuleTypeLabel(AppLocalizations l10n, NotebookRuleType type) =>
    switch (type) {
      NotebookRuleType.tags => l10n.notebookRuleTypeTags,
      NotebookRuleType.mood => l10n.notebookRuleTypeMood,
      NotebookRuleType.weather => l10n.notebookRuleTypeWeather,
      NotebookRuleType.location => l10n.notebookRuleTypeLocation,
      NotebookRuleType.keyword => l10n.notebookRuleTypeKeyword,
      NotebookRuleType.date => l10n.notebookRuleTypeDate,
      NotebookRuleType.media => l10n.notebookRuleTypeMedia,
      NotebookRuleType.flag => l10n.notebookRuleTypeFlag,
    };

String notebookRuleTypeHint(AppLocalizations l10n, NotebookRuleType type) =>
    switch (type) {
      NotebookRuleType.tags => l10n.notebookRuleTypeTagsHint,
      NotebookRuleType.mood => l10n.notebookRuleTypeMoodHint,
      NotebookRuleType.weather => l10n.notebookRuleTypeWeatherHint,
      NotebookRuleType.location => l10n.notebookRuleTypeLocationHint,
      NotebookRuleType.keyword => l10n.notebookRuleTypeKeywordHint,
      NotebookRuleType.date => l10n.notebookRuleTypeDateHint,
      NotebookRuleType.media => l10n.notebookRuleTypeMediaHint,
      NotebookRuleType.flag => l10n.notebookRuleTypeFlagHint,
    };

FaIconData notebookRuleTypeIcon(NotebookRuleType? type) => switch (type) {
  NotebookRuleType.tags => FontAwesomeIcons.tag,
  NotebookRuleType.mood => FontAwesomeIcons.faceSmile,
  NotebookRuleType.weather => FontAwesomeIcons.cloudSun,
  NotebookRuleType.location => FontAwesomeIcons.locationDot,
  NotebookRuleType.keyword => FontAwesomeIcons.magnifyingGlass,
  NotebookRuleType.date => FontAwesomeIcons.calendarDays,
  NotebookRuleType.media => FontAwesomeIcons.photoFilm,
  NotebookRuleType.flag => FontAwesomeIcons.thumbtack,
  null => FontAwesomeIcons.circleQuestion,
};

String notebookTagMatchLabel(AppLocalizations l10n, NotebookTagMatch mode) =>
    switch (mode) {
      NotebookTagMatch.any => l10n.notebookRuleTagAny,
      NotebookTagMatch.all => l10n.notebookRuleTagAll,
      NotebookTagMatch.none => l10n.notebookRuleTagNone,
    };

String notebookDateKindLabel(AppLocalizations l10n, NotebookDateKind kind) =>
    switch (kind) {
      NotebookDateKind.between => l10n.notebookRuleDateBetween,
      NotebookDateKind.lastDays => l10n.notebookRuleDateLastDays,
      NotebookDateKind.thisYear => l10n.notebookRuleDateThisYear,
      NotebookDateKind.monthEveryYear => l10n.notebookRuleDateMonth,
      NotebookDateKind.dayEveryYear => l10n.notebookRuleDateToday,
    };

String notebookMediaKindLabel(AppLocalizations l10n, NotebookMediaKind kind) =>
    switch (kind) {
      NotebookMediaKind.image => l10n.notebookRuleMediaImage,
      NotebookMediaKind.audio => l10n.notebookRuleMediaAudio,
      NotebookMediaKind.video => l10n.notebookRuleMediaVideo,
      NotebookMediaKind.attachment => l10n.notebookRuleMediaAttachment,
    };

String notebookFlagKindLabel(AppLocalizations l10n, NotebookFlagKind kind) =>
    switch (kind) {
      NotebookFlagKind.hasCover => l10n.notebookRuleFlagCover,
      NotebookFlagKind.pinned => l10n.notebookRuleFlagPinned,
    };

/// 一段日期的写法（“10月6日 – 10月18日”）：固定区间规则的摘要与由日历范围
/// 新建的日记本默认名称共用，年份规则同日历范围标题。
String notebookDateRangeLabel(
  AppLocalizations l10n,
  DateTime first,
  DateTime last, {
  required DateTime now,
}) {
  final format = dateRangeEndpointFormat(
    l10n.localeName,
    first: first,
    last: last,
    now: now,
  );
  return l10n.notebookRuleSummaryRange(
    format.format(first),
    format.format(last),
  );
}

/// 月份名称（英文摘要用；中文摘要直接写数字）。
String notebookMonthName(AppLocalizations l10n, int month) =>
    DateFormat.MMMM(l10n.localeName).format(DateTime(2000, month));

/// 月份短名（“10月”“Oct”）：日期规则面板的月份胶囊。
String notebookMonthShortName(AppLocalizations l10n, int month) =>
    DateFormat.MMM(l10n.localeName).format(DateTime(2000, month));

/// 条件行的一行摘要，如“标签含任一：#旅行 #出差”“最近 30 天”“每年 10 月”。
String notebookRuleSummary(
  AppLocalizations l10n,
  NotebookRule rule, {
  required DateTime now,
}) {
  switch (rule) {
    case NotebookTagsRule(:final mode, :final names):
      final tags = names.map((name) => '#$name').join(' ');
      return switch (mode) {
        NotebookTagMatch.any => l10n.notebookRuleSummaryTagsAny(tags),
        NotebookTagMatch.all => l10n.notebookRuleSummaryTagsAll(tags),
        NotebookTagMatch.none => l10n.notebookRuleSummaryTagsNone(tags),
      };
    case NotebookMoodRule(:final emojis):
      return l10n.notebookRuleSummaryMood(emojis.join(' '));
    case NotebookTextRule(:final field, :final text):
      return switch (field) {
        NotebookTextField.weather => l10n.notebookRuleSummaryWeather(text),
        NotebookTextField.location => l10n.notebookRuleSummaryLocation(text),
        NotebookTextField.keyword => l10n.notebookRuleSummaryKeyword(text),
      };
    case NotebookDateRule():
      return _dateSummary(l10n, rule, now);
    case NotebookMediaRule(:final kind):
      return notebookMediaKindLabel(l10n, kind);
    case NotebookFlagRule(:final kind):
      return notebookFlagKindLabel(l10n, kind);
    case NotebookUnknownRule():
      return l10n.notebookRuleUnknown;
  }
}

String _dateSummary(
  AppLocalizations l10n,
  NotebookDateRule rule,
  DateTime now,
) {
  switch (rule.kind) {
    case NotebookDateKind.between:
      final from = rule.from;
      final to = rule.to;
      if (from == null || to == null) return l10n.notebookRuleDateBetween;
      return notebookDateRangeLabel(l10n, from, to, now: now);
    case NotebookDateKind.lastDays:
      return l10n.notebookRuleSummaryLastDays(
        rule.days ?? NotebookDateRule.minDays,
      );
    case NotebookDateKind.thisYear:
      return l10n.notebookRuleDateThisYear;
    case NotebookDateKind.monthEveryYear:
      final month = rule.month ?? now.month;
      return l10n.notebookRuleSummaryMonth(
        month,
        notebookMonthName(l10n, month),
      );
    case NotebookDateKind.dayEveryYear:
      return l10n.notebookRuleSummaryToday(
        DateFormat.MMMd(l10n.localeName).format(now),
      );
  }
}

/// “从示例开始”的一个示例：胶囊文字、规则，以及名称还空着时填入的名称。
typedef NotebookRuleExample = ({String label, NotebookRule rule, String name});

/// 四个示例：最近 30 天 / 每年这个月 / 有图片的日记 / 置顶的日记。
/// “每年这个月”的名称写成具体月份（“每年 10 月”），过了这个月名称仍然准确。
List<NotebookRuleExample> notebookRuleExamples(
  AppLocalizations l10n, {
  required DateTime now,
}) {
  final thisMonth = NotebookDateRule.monthEveryYear(now.month);
  return <NotebookRuleExample>[
    (
      label: l10n.notebookRuleExampleRecent,
      rule: NotebookDateRule.lastDays(30),
      name: l10n.notebookRuleExampleRecent,
    ),
    (
      label: l10n.notebookRuleExampleThisMonth,
      rule: thisMonth,
      name: notebookRuleSummary(l10n, thisMonth, now: now),
    ),
    (
      label: l10n.notebookRuleExampleImages,
      rule: const NotebookMediaRule(NotebookMediaKind.image),
      name: l10n.notebookRuleExampleImages,
    ),
    (
      label: l10n.notebookRuleExamplePinned,
      rule: const NotebookFlagRule(NotebookFlagKind.pinned),
      name: l10n.notebookRuleExamplePinned,
    ),
  ];
}
