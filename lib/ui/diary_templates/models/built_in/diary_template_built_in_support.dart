import '../../../../core/database/app_database.dart'
    show builtInDiaryTemplateIdPrefix;
import '../../../../l10n/app_localizations_gen.dart';
import '../../../diaries/models/diary_text_colors.dart';
import '../../../widgets/color_palette_families.dart';
import '../diary_template.dart';
import '../diary_template_body.dart';
import '../diary_template_json.dart';
import '../diary_template_recommend.dart';

/// 内置模板共用的构造工具：变量占位、强调色与统一的模板构造。

/// 当前界面语言下各变量的占位写法（如 `{{日期}}`），内置模板的文案经 ARB
/// 占位符把它们嵌进标题与正文。
class DiaryTemplateTokens {
  DiaryTemplateTokens(AppLocalizations l10n)
    : date = _wrap(l10n.diaryTemplateVarDateToken),
      weekday = _wrap(l10n.diaryTemplateVarWeekdayToken),
      time = _wrap(l10n.diaryTemplateVarTimeToken),
      week = _wrap(l10n.diaryTemplateVarWeekToken),
      yearProgress = _wrap(l10n.diaryTemplateVarYearProgressToken),
      solarTerm = _wrap(l10n.diaryTemplateVarSolarTermToken),
      question = _wrap(l10n.diaryTemplateVarQuestionToken);

  final String date;
  final String weekday;
  final String time;
  final String week;
  final String yearProgress;
  final String solarTerm;
  final String question;

  static String _wrap(String name) => '{{$name}}';
}

/// 内置模板的强调色：[family] 是色板（`kColorPaletteFamilies`）里的色系下标
/// （0 红 1 粉 2 橙 3 黄 4 绿 5 青 6 蓝 7 紫 8 棕 9 灰），取其中间色作为
/// 模板图标的种子色与预设标签的颜色；[ink] 是同一色相的正文文字色预设，
/// 用作正文小标题的颜色——预设色在白纸与暗色卡片上都有 3:1 以上的对比度，
/// 而色板中间色在暗色下不一定看得清。
enum BuiltInAccent {
  pink(1, DiaryColorPreset.pink),
  orange(2, DiaryColorPreset.orange),
  green(4, DiaryColorPreset.green),
  cyan(5, DiaryColorPreset.teal),
  blue(6, DiaryColorPreset.blue),
  purple(7, DiaryColorPreset.purple),
  brown(8, DiaryColorPreset.brown);

  const BuiltInAccent(this.family, this.ink);

  final int family;
  final DiaryColorPreset ink;

  /// 不透明 ARGB。
  int get seed => kColorPaletteFamilies[family].colors[5].toARGB32();

  /// 写进正文的小标题颜色（大写 `#AARRGGBB`）。
  String get inkValue => encodeDiaryColor(ink.colorFor(DiaryColorTarget.text));
}

/// 小字注释的颜色：中性灰预设，亮暗主题下都清楚又不抢正文。
final String _noteColor = encodeDiaryColor(
  DiaryColorPreset.gray.colorFor(DiaryColorTarget.text),
);

DiaryTemplate builtInDiaryTemplate({
  required String key,
  required String name,
  required String description,
  required DiaryTemplateIcon icon,
  required BuiltInAccent accent,
  required DiaryTemplateCategory category,
  required String title,
  required List<DiaryTemplateBlock> blocks,
  List<DiaryTemplateTagRef> tags = const <DiaryTemplateTagRef>[],
  DiaryTemplateRecommendRules recommend = DiaryTemplateRecommendRules.none,
}) {
  return DiaryTemplate(
    id: '$builtInDiaryTemplateIdPrefix$key',
    name: name,
    description: description,
    icon: icon,
    accent: accent.seed,
    category: category,
    titlePattern: title,
    bodyJson: encodeDiaryTemplateBody(
      compileDiaryTemplateBlocks(
        blocks,
        labelColor: accent.inkValue,
        noteColor: _noteColor,
      ),
    ),
    tags: tags,
    recommend: recommend,
  );
}

DiaryTemplateTagRef builtInTag(String name, BuiltInAccent accent) =>
    DiaryTemplateTagRef(name: name, color: accent.seed);

/// N 个待填写的空项。
List<String> blanks(int count) => List<String>.filled(count, '');
