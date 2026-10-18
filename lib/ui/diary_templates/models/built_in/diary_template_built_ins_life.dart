import '../../../../l10n/app_localizations_gen.dart';
import '../../../diaries/models/time_capsule.dart';
import '../diary_template.dart';
import '../diary_template_body.dart';
import '../diary_template_recommend.dart';
import 'diary_template_built_in_support.dart';

/// 生活、工作与其他类内置模板（见 `buildBuiltInDiaryTemplates`）。
List<DiaryTemplate> buildLifeDiaryTemplates(
  AppLocalizations l10n,
  DiaryTemplateTokens t,
) {
  return <DiaryTemplate>[
    builtInDiaryTemplate(
      key: 'dream',
      name: l10n.diaryTemplateDreamName,
      description: l10n.diaryTemplateDreamDesc,
      icon: DiaryTemplateIcon.cloudMoon,
      accentFamily: Palette.purple,
      category: DiaryTemplateCategory.life,
      title: l10n.diaryTemplateDreamTitle(t.date),
      tags: <DiaryTemplateTagRef>[
        builtInTag(l10n.diaryTemplateTagDream, Palette.purple),
      ],
      recommend: const DiaryTemplateRecommendRules(
        slots: <DiaryTemplateTimeSlot>{DiaryTemplateTimeSlot.morning},
      ),
      blocks: <DiaryTemplateBlock>[
        TplHeading(l10n.diaryTemplateDreamHappened),
        const TplParagraph(),
        TplHeading(l10n.diaryTemplateDreamImages),
        TplBullets(blanks(1)),
        TplHeading(l10n.diaryTemplateDreamWaking),
        const TplParagraph(),
      ],
    ),
    builtInDiaryTemplate(
      key: 'travel',
      name: l10n.diaryTemplateTravelName,
      description: l10n.diaryTemplateTravelDesc,
      icon: DiaryTemplateIcon.plane,
      accentFamily: Palette.blue,
      category: DiaryTemplateCategory.life,
      title: l10n.diaryTemplateTravelTitle(t.date),
      tags: <DiaryTemplateTagRef>[
        builtInTag(l10n.diaryTemplateTagTravel, Palette.blue),
      ],
      blocks: <DiaryTemplateBlock>[
        TplHeading(l10n.diaryTemplateTravelRoute),
        TplNumbered(blanks(1)),
        TplHeading(l10n.diaryTemplateTravelSights),
        const TplParagraph(),
        TplHeading(l10n.diaryTemplateTravelFood),
        TplBullets(blanks(1)),
        TplHeading(l10n.diaryTemplateTravelNotes),
        const TplParagraph(),
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
    builtInDiaryTemplate(
      key: 'movie',
      name: l10n.diaryTemplateMovieName,
      description: l10n.diaryTemplateMovieDesc,
      icon: DiaryTemplateIcon.film,
      accentFamily: Palette.red,
      category: DiaryTemplateCategory.life,
      title: l10n.diaryTemplateMovieTitle(t.date),
      tags: <DiaryTemplateTagRef>[
        builtInTag(l10n.diaryTemplateTagMovie, Palette.red),
      ],
      blocks: <DiaryTemplateBlock>[
        TplParagraph(l10n.diaryTemplateMovieFilm),
        TplParagraph(l10n.diaryTemplateMovieRating),
        TplHeading(l10n.diaryTemplateMovieStory),
        const TplParagraph(),
        TplHeading(l10n.diaryTemplateMovieMoved),
        const TplParagraph(),
        TplHeading(l10n.diaryTemplateMovieLines),
        const TplQuote(),
      ],
    ),
    builtInDiaryTemplate(
      key: 'workout',
      name: l10n.diaryTemplateWorkoutName,
      description: l10n.diaryTemplateWorkoutDesc,
      icon: DiaryTemplateIcon.personRunning,
      accentFamily: Palette.green,
      category: DiaryTemplateCategory.life,
      title: l10n.diaryTemplateWorkoutTitle(t.date),
      tags: <DiaryTemplateTagRef>[
        builtInTag(l10n.diaryTemplateTagWorkout, Palette.green),
      ],
      blocks: <DiaryTemplateBlock>[
        TplParagraph(l10n.diaryTemplateWorkoutActivity),
        TplParagraph(l10n.diaryTemplateWorkoutDuration),
        TplHeading(l10n.diaryTemplateWorkoutTraining),
        TplChecklist(blanks(3)),
        TplHeading(l10n.diaryTemplateWorkoutBody),
        const TplParagraph(),
      ],
    ),
    builtInDiaryTemplate(
      key: 'work',
      name: l10n.diaryTemplateWorkName,
      description: l10n.diaryTemplateWorkDesc,
      icon: DiaryTemplateIcon.briefcase,
      accentFamily: Palette.cyan,
      category: DiaryTemplateCategory.work,
      title: l10n.diaryTemplateWorkTitle(t.date, t.weekday),
      tags: <DiaryTemplateTagRef>[
        builtInTag(l10n.diaryTemplateTagWork, Palette.cyan),
      ],
      recommend: const DiaryTemplateRecommendRules(
        slots: <DiaryTemplateTimeSlot>{
          DiaryTemplateTimeSlot.afternoon,
          DiaryTemplateTimeSlot.evening,
        },
        weekdays: <int>{1, 2, 3, 4, 5},
      ),
      blocks: <DiaryTemplateBlock>[
        TplHeading(l10n.diaryTemplateWorkDone),
        TplChecklist(blanks(3)),
        TplHeading(l10n.diaryTemplateWorkInProgress),
        TplBullets(blanks(1)),
        TplHeading(l10n.diaryTemplateWorkBlockers),
        TplBullets(blanks(1)),
        TplHeading(l10n.diaryTemplateWorkTomorrow),
        TplChecklist(blanks(2)),
      ],
    ),
    builtInDiaryTemplate(
      key: 'letter',
      name: l10n.diaryTemplateLetterName,
      description: l10n.diaryTemplateLetterDesc,
      icon: DiaryTemplateIcon.envelope,
      accentFamily: Palette.red,
      category: DiaryTemplateCategory.other,
      title: l10n.diaryTemplateLetterTitle,
      capsule: TimeCapsulePreset.year,
      blocks: <DiaryTemplateBlock>[
        TplParagraph(l10n.diaryTemplateLetterGreeting),
        const TplParagraph(),
        TplHeading(l10n.diaryTemplateLetterNow),
        const TplParagraph(),
        TplHeading(l10n.diaryTemplateLetterMind),
        const TplParagraph(),
        TplHeading(l10n.diaryTemplateLetterHope),
        const TplParagraph(),
        const TplDivider(),
        TplParagraph(l10n.diaryTemplateLetterSignature(t.date, t.lunar)),
      ],
    ),
  ];
}
