import '../../../../core/database/app_database.dart'
    show builtInDiaryTemplateIdPrefix;
import '../../../../l10n/app_localizations_gen.dart';
import '../../../widgets/color_palette_families.dart';
import '../diary_template.dart';
import '../diary_template_body.dart';
import '../diary_template_json.dart';
import '../diary_template_recommend.dart';

/// 内置模板共用的构造工具：变量占位、色板颜色与统一的模板构造。

/// 当前界面语言下各变量的占位写法（如 `{{日期}}`），内置模板的文案经 ARB
/// 占位符把它们嵌进标题与正文。
class DiaryTemplateTokens {
  DiaryTemplateTokens(AppLocalizations l10n)
    : date = _wrap(l10n.diaryTemplateVarDateToken),
      weekday = _wrap(l10n.diaryTemplateVarWeekdayToken),
      time = _wrap(l10n.diaryTemplateVarTimeToken),
      solarTerm = _wrap(l10n.diaryTemplateVarSolarTermToken),
      question = _wrap(l10n.diaryTemplateVarQuestionToken);

  final String date;
  final String weekday;
  final String time;
  final String solarTerm;
  final String question;

  static String _wrap(String name) => '{{$name}}';
}

/// 色板（`kColorPaletteFamilies`）里某个色系的中间色，作为强调色种子或标签
/// 颜色；色系下标：0 红 1 粉 2 橙 3 黄 4 绿 5 青 6 蓝 7 紫 8 棕 9 灰。
int paletteColor(int family) =>
    kColorPaletteFamilies[family].colors[5].toARGB32();

abstract final class Palette {
  static const int pink = 1;
  static const int orange = 2;
  static const int green = 4;
  static const int cyan = 5;
  static const int blue = 6;
  static const int purple = 7;
  static const int brown = 8;
}

DiaryTemplate builtInDiaryTemplate({
  required String key,
  required String name,
  required String description,
  required DiaryTemplateIcon icon,
  required int accentFamily,
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
    accent: paletteColor(accentFamily),
    category: category,
    titlePattern: title,
    bodyJson: encodeDiaryTemplateBody(compileDiaryTemplateBlocks(blocks)),
    tags: tags,
    recommend: recommend,
  );
}

DiaryTemplateTagRef builtInTag(String name, int family) =>
    DiaryTemplateTagRef(name: name, color: paletteColor(family));

/// N 个待填写的空项。
List<String> blanks(int count) => List<String>.filled(count, '');
