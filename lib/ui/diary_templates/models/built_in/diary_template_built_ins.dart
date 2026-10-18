import '../../../../l10n/app_localizations_gen.dart';
import '../diary_template.dart';
import '../diary_template_body.dart';
import '../diary_template_recommend.dart';
import 'diary_template_built_in_support.dart';

/// 内置模板库：只保留最常用的 8 个模板（太多反而难挑，其余场景交给“我的
/// 模板”），文案全部来自 ARB、跟随界面语言，结构由块描述给出（中英文两版
/// 结构一致）。内置模板只读、不落库；用户想改就“复制为我的模板”。id 固定为 `builtin.<key>`，最近使用、隐藏与自动套用都按它记录，
/// 切换界面语言不受影响。
///
/// 结果按语言缓存：模板面板、建议条每次重建都会取它。
List<DiaryTemplate> buildBuiltInDiaryTemplates(AppLocalizations l10n) {
  return _cache[l10n.localeName] ??= List<DiaryTemplate>.unmodifiable(
    _templates(l10n, DiaryTemplateTokens(l10n)),
  );
}

final Map<String, List<DiaryTemplate>> _cache = <String, List<DiaryTemplate>>{};

/// 按日常 → 复盘 → 情绪 → 生活的顺序排列，模板面板与管理页按此顺序展示。
List<DiaryTemplate> _templates(AppLocalizations l10n, DiaryTemplateTokens t) {
  return <DiaryTemplate>[
    builtInDiaryTemplate(
      key: 'daily',
      name: l10n.diaryTemplateDailyName,
      description: l10n.diaryTemplateDailyDesc,
      icon: DiaryTemplateIcon.penNib,
      accentFamily: Palette.blue,
      category: DiaryTemplateCategory.daily,
      title: l10n.diaryTemplateDailyTitle(t.date, t.weekday),
      blocks: <DiaryTemplateBlock>[
        TplHeading(l10n.diaryTemplateDailyHappened),
        const TplParagraph(),
        TplHeading(l10n.diaryTemplateDailyMoment),
        const TplParagraph(),
        TplHeading(l10n.diaryTemplateDailyMood),
        const TplParagraph(),
      ],
    ),
    builtInDiaryTemplate(
      key: 'morning',
      name: l10n.diaryTemplateMorningName,
      description: l10n.diaryTemplateMorningDesc,
      icon: DiaryTemplateIcon.sun,
      accentFamily: Palette.orange,
      category: DiaryTemplateCategory.daily,
      title: l10n.diaryTemplateMorningTitle(t.date),
      recommend: const DiaryTemplateRecommendRules(
        slots: <DiaryTemplateTimeSlot>{DiaryTemplateTimeSlot.morning},
      ),
      blocks: <DiaryTemplateBlock>[
        TplParagraph(l10n.diaryTemplateMorningWake(t.time, t.solarTerm)),
        TplHeading(l10n.diaryTemplateMorningTop3),
        TplChecklist(blanks(3)),
        TplHeading(l10n.diaryTemplateMorningLookForward),
        TplBullets(blanks(1)),
        TplHeading(l10n.diaryTemplateMorningWords),
        const TplQuote(),
      ],
    ),
    builtInDiaryTemplate(
      key: 'evening',
      name: l10n.diaryTemplateEveningName,
      description: l10n.diaryTemplateEveningDesc,
      icon: DiaryTemplateIcon.moon,
      accentFamily: Palette.purple,
      category: DiaryTemplateCategory.review,
      title: l10n.diaryTemplateEveningTitle(t.date),
      recommend: const DiaryTemplateRecommendRules(
        slots: <DiaryTemplateTimeSlot>{
          DiaryTemplateTimeSlot.evening,
          DiaryTemplateTimeSlot.night,
        },
      ),
      blocks: <DiaryTemplateBlock>[
        TplHeading(l10n.diaryTemplateEveningDone),
        TplBullets(blanks(1)),
        TplHeading(l10n.diaryTemplateEveningWentWell),
        TplBullets(blanks(1)),
        TplHeading(l10n.diaryTemplateEveningBetter),
        TplBullets(blanks(1)),
        TplHeading(l10n.diaryTemplateEveningTomorrow),
        TplChecklist(blanks(2)),
      ],
    ),
    builtInDiaryTemplate(
      key: 'gratitude',
      name: l10n.diaryTemplateGratitudeName,
      description: l10n.diaryTemplateGratitudeDesc,
      icon: DiaryTemplateIcon.handHoldingHeart,
      accentFamily: Palette.pink,
      category: DiaryTemplateCategory.mood,
      title: l10n.diaryTemplateGratitudeTitle(t.date),
      tags: <DiaryTemplateTagRef>[
        builtInTag(l10n.diaryTemplateTagGratitude, Palette.pink),
      ],
      blocks: <DiaryTemplateBlock>[
        TplParagraph(l10n.diaryTemplateGratitudeThree),
        TplNumbered(blanks(3)),
        TplHeading(l10n.diaryTemplateGratitudeThanks),
        const TplParagraph(),
      ],
    ),
    builtInDiaryTemplate(
      key: 'question',
      name: l10n.diaryTemplateQuestionName,
      description: l10n.diaryTemplateQuestionDesc,
      icon: DiaryTemplateIcon.circleQuestion,
      accentFamily: Palette.cyan,
      category: DiaryTemplateCategory.daily,
      title: l10n.diaryTemplateQuestionTitle(t.date),
      blocks: <DiaryTemplateBlock>[TplQuote(t.question), const TplParagraph()],
    ),
    builtInDiaryTemplate(
      key: 'weekly',
      name: l10n.diaryTemplateWeeklyName,
      description: l10n.diaryTemplateWeeklyDesc,
      icon: DiaryTemplateIcon.calendarWeek,
      accentFamily: Palette.green,
      category: DiaryTemplateCategory.review,
      title: l10n.diaryTemplateWeeklyTitle(t.date),
      recommend: const DiaryTemplateRecommendRules(weekdays: <int>{7, 1}),
      blocks: <DiaryTemplateBlock>[
        TplHeading(l10n.diaryTemplateWeeklyHighlights),
        TplBullets(blanks(1)),
        TplHeading(l10n.diaryTemplateWeeklyWins),
        TplBullets(blanks(1)),
        TplHeading(l10n.diaryTemplateWeeklyOpen),
        TplChecklist(blanks(1)),
        TplHeading(l10n.diaryTemplateWeeklyNext),
        TplChecklist(blanks(3)),
      ],
    ),
    builtInDiaryTemplate(
      key: 'emotion',
      name: l10n.diaryTemplateEmotionName,
      description: l10n.diaryTemplateEmotionDesc,
      icon: DiaryTemplateIcon.faceSmile,
      accentFamily: Palette.brown,
      category: DiaryTemplateCategory.mood,
      title: l10n.diaryTemplateEmotionTitle(t.date),
      blocks: <DiaryTemplateBlock>[
        TplHeading(l10n.diaryTemplateEmotionHappened),
        const TplParagraph(),
        TplHeading(l10n.diaryTemplateEmotionFelt),
        const TplParagraph(),
        TplHeading(l10n.diaryTemplateEmotionSource),
        const TplParagraph(),
        TplHeading(l10n.diaryTemplateEmotionNeed),
        const TplParagraph(),
        TplHeading(l10n.diaryTemplateEmotionStep),
        TplChecklist(blanks(1)),
      ],
    ),
    builtInDiaryTemplate(
      key: 'reading',
      name: l10n.diaryTemplateReadingName,
      description: l10n.diaryTemplateReadingDesc,
      icon: DiaryTemplateIcon.bookOpen,
      accentFamily: Palette.orange,
      category: DiaryTemplateCategory.life,
      title: l10n.diaryTemplateReadingTitle(t.date),
      tags: <DiaryTemplateTagRef>[
        builtInTag(l10n.diaryTemplateTagReading, Palette.orange),
      ],
      blocks: <DiaryTemplateBlock>[
        TplParagraph(l10n.diaryTemplateReadingBook),
        TplParagraph(l10n.diaryTemplateReadingAuthor),
        TplParagraph(l10n.diaryTemplateReadingProgress),
        TplHeading(l10n.diaryTemplateReadingQuotes),
        const TplQuote(),
        TplHeading(l10n.diaryTemplateReadingThoughts),
        const TplParagraph(),
      ],
    ),
  ];
}
