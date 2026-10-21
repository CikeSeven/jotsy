import '../../../../l10n/app_localizations_gen.dart';
import '../diary_template.dart';
import '../diary_template_body.dart';
import '../diary_template_recommend.dart';
import 'diary_template_built_in_support.dart';

/// 内置模板库：只保留最常用的 8 个模板（太多反而难挑，其余场景交给“我的
/// 模板”），文案全部来自 ARB、跟随界面语言，结构由块描述给出（中英文两版
/// 结构一致）。这里编译出的是默认内容，不落库；用户编辑后的版本以同一个
/// id 存进数据库并替换默认内容（见 `DiaryTemplateLibrary`），“恢复默认”删掉
/// 那一行即回到这里的内容。id 固定为 `builtin.<key>`，最近使用、删除（隐藏）
/// 与自动套用都按它记录，切换界面语言不受影响。
///
/// 排版：小标题是与正文同字号的粗体行，带模板强调色与一个 emoji 符号，以
/// 不带格式的冒号结尾（原因见 [TplLabel]）；小字注释用灰色小一档的字；
/// 小标题之间空一行（[TplGap]），分隔线把“记录”与“收尾的一句话”隔开。正文
/// 里不用 Quill 的标题级别。
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
      accent: BuiltInAccent.blue,
      category: DiaryTemplateCategory.daily,
      title: l10n.diaryTemplateDailyTitle(t.date, t.weekday),
      blocks: <DiaryTemplateBlock>[
        TplLabel(l10n.diaryTemplateDailyHappened, mark: '📖'),
        const TplParagraph(),
        const TplGap(),
        TplLabel(l10n.diaryTemplateDailyMoment, mark: '✨'),
        const TplParagraph(),
        const TplGap(),
        TplLabel(l10n.diaryTemplateDailyMood, mark: '🌿'),
        const TplParagraph(),
        const TplDivider(),
        TplLabel(l10n.diaryTemplateDailyWords, mark: '🌙'),
        const TplQuote(),
      ],
    ),
    builtInDiaryTemplate(
      key: 'morning',
      name: l10n.diaryTemplateMorningName,
      description: l10n.diaryTemplateMorningDesc,
      icon: DiaryTemplateIcon.sun,
      accent: BuiltInAccent.orange,
      category: DiaryTemplateCategory.daily,
      title: l10n.diaryTemplateMorningTitle(t.date),
      recommend: const DiaryTemplateRecommendRules(
        slots: <DiaryTemplateTimeSlot>{DiaryTemplateTimeSlot.morning},
      ),
      blocks: <DiaryTemplateBlock>[
        TplNote(l10n.diaryTemplateMorningWake(t.time, t.solarTerm), mark: '⏰'),
        TplLabel(l10n.diaryTemplateMorningTop3, mark: '🎯'),
        TplChecklist(blanks(3)),
        const TplGap(),
        TplLabel(l10n.diaryTemplateMorningLookForward, mark: '🌱'),
        TplBullets(blanks(1)),
        const TplDivider(),
        TplLabel(l10n.diaryTemplateMorningWords, mark: '☀️'),
        const TplQuote(),
      ],
    ),
    builtInDiaryTemplate(
      key: 'evening',
      name: l10n.diaryTemplateEveningName,
      description: l10n.diaryTemplateEveningDesc,
      icon: DiaryTemplateIcon.moon,
      accent: BuiltInAccent.purple,
      category: DiaryTemplateCategory.review,
      title: l10n.diaryTemplateEveningTitle(t.date),
      recommend: const DiaryTemplateRecommendRules(
        slots: <DiaryTemplateTimeSlot>{
          DiaryTemplateTimeSlot.evening,
          DiaryTemplateTimeSlot.night,
        },
      ),
      blocks: <DiaryTemplateBlock>[
        TplLabel(l10n.diaryTemplateEveningDone, mark: '✅'),
        TplBullets(blanks(1)),
        const TplGap(),
        TplLabel(l10n.diaryTemplateEveningWentWell, mark: '👍'),
        TplBullets(blanks(1)),
        const TplGap(),
        TplLabel(l10n.diaryTemplateEveningBetter, mark: '🔧'),
        TplBullets(blanks(1)),
        const TplDivider(),
        TplLabel(l10n.diaryTemplateEveningTomorrow, mark: '📅'),
        TplChecklist(blanks(2)),
        const TplGap(),
        TplLabel(l10n.diaryTemplateEveningNight, mark: '🌙'),
        const TplQuote(),
      ],
    ),
    builtInDiaryTemplate(
      key: 'gratitude',
      name: l10n.diaryTemplateGratitudeName,
      description: l10n.diaryTemplateGratitudeDesc,
      icon: DiaryTemplateIcon.handHoldingHeart,
      accent: BuiltInAccent.pink,
      category: DiaryTemplateCategory.mood,
      title: l10n.diaryTemplateGratitudeTitle(t.date),
      tags: <DiaryTemplateTagRef>[
        builtInTag(l10n.diaryTemplateTagGratitude, BuiltInAccent.pink),
      ],
      blocks: <DiaryTemplateBlock>[
        TplLabel(l10n.diaryTemplateGratitudeThree, mark: '🌸'),
        TplNumbered(blanks(3)),
        const TplGap(),
        TplLabel(l10n.diaryTemplateGratitudeThanks, mark: '💌'),
        const TplParagraph(),
        const TplGap(),
        TplLabel(l10n.diaryTemplateGratitudeSelf, mark: '🤍'),
        const TplParagraph(),
      ],
    ),
    builtInDiaryTemplate(
      key: 'question',
      name: l10n.diaryTemplateQuestionName,
      description: l10n.diaryTemplateQuestionDesc,
      icon: DiaryTemplateIcon.circleQuestion,
      accent: BuiltInAccent.cyan,
      category: DiaryTemplateCategory.daily,
      title: l10n.diaryTemplateQuestionTitle(t.date),
      blocks: <DiaryTemplateBlock>[
        TplLabel(l10n.diaryTemplateQuestionPrompt, mark: '💭'),
        TplQuote(t.question),
        const TplGap(),
        TplLabel(l10n.diaryTemplateQuestionAnswer, mark: '✍️'),
        const TplParagraph(),
      ],
    ),
    builtInDiaryTemplate(
      key: 'weekly',
      name: l10n.diaryTemplateWeeklyName,
      description: l10n.diaryTemplateWeeklyDesc,
      icon: DiaryTemplateIcon.calendarWeek,
      accent: BuiltInAccent.green,
      category: DiaryTemplateCategory.review,
      title: l10n.diaryTemplateWeeklyTitle(t.date),
      recommend: const DiaryTemplateRecommendRules(weekdays: <int>{7, 1}),
      blocks: <DiaryTemplateBlock>[
        TplNote(
          l10n.diaryTemplateWeeklyProgress(t.week, t.yearProgress),
          mark: '🗓️',
        ),
        TplLabel(l10n.diaryTemplateWeeklyHighlights, mark: '🌟'),
        TplBullets(blanks(1)),
        const TplGap(),
        TplLabel(l10n.diaryTemplateWeeklyWins, mark: '🏆'),
        TplBullets(blanks(1)),
        const TplGap(),
        TplLabel(l10n.diaryTemplateWeeklyOpen, mark: '⏳'),
        TplChecklist(blanks(1)),
        const TplDivider(),
        TplLabel(l10n.diaryTemplateWeeklyNext, mark: '🧭'),
        TplChecklist(blanks(3)),
        const TplGap(),
        TplLabel(l10n.diaryTemplateWeeklyNote, mark: '💬'),
        const TplQuote(),
      ],
    ),
    builtInDiaryTemplate(
      key: 'emotion',
      name: l10n.diaryTemplateEmotionName,
      description: l10n.diaryTemplateEmotionDesc,
      icon: DiaryTemplateIcon.faceSmile,
      accent: BuiltInAccent.brown,
      category: DiaryTemplateCategory.mood,
      title: l10n.diaryTemplateEmotionTitle(t.date),
      blocks: <DiaryTemplateBlock>[
        TplLabel(l10n.diaryTemplateEmotionHappened, mark: '🌧️'),
        const TplParagraph(),
        const TplGap(),
        TplLabel(l10n.diaryTemplateEmotionFelt, mark: '💗'),
        const TplParagraph(),
        const TplGap(),
        TplLabel(l10n.diaryTemplateEmotionSource, mark: '🔍'),
        const TplParagraph(),
        const TplGap(),
        TplLabel(l10n.diaryTemplateEmotionNeed, mark: '🤲'),
        const TplParagraph(),
        const TplDivider(),
        TplLabel(l10n.diaryTemplateEmotionStep, mark: '🌱'),
        TplChecklist(blanks(1)),
      ],
    ),
    builtInDiaryTemplate(
      key: 'reading',
      name: l10n.diaryTemplateReadingName,
      description: l10n.diaryTemplateReadingDesc,
      icon: DiaryTemplateIcon.bookOpen,
      accent: BuiltInAccent.orange,
      category: DiaryTemplateCategory.life,
      title: l10n.diaryTemplateReadingTitle(t.date),
      tags: <DiaryTemplateTagRef>[
        builtInTag(l10n.diaryTemplateTagReading, BuiltInAccent.orange),
      ],
      blocks: <DiaryTemplateBlock>[
        // 书名、作者与进度在冒号后同一行填写。
        TplLabel(l10n.diaryTemplateReadingBook, mark: '📚'),
        TplLabel(l10n.diaryTemplateReadingAuthor, mark: '🖋️'),
        TplLabel(l10n.diaryTemplateReadingProgress, mark: '🔖'),
        const TplDivider(),
        TplLabel(l10n.diaryTemplateReadingQuotes, mark: '✒️'),
        const TplQuote(),
        const TplGap(),
        TplLabel(l10n.diaryTemplateReadingThoughts, mark: '💡'),
        const TplParagraph(),
      ],
    ),
  ];
}
