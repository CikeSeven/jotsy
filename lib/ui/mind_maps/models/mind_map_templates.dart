import '../../../core/database/mind_map/mind_map_document.dart';
import '../../../core/database/mind_map/mind_map_ops.dart';
import '../../../core/database/mind_map/mind_map_text.dart';
import '../../../l10n/app_localizations.dart';
import 'mind_map_options.dart';
import 'mind_map_themes.dart';

/// 空导图起步卡里的内置模板。
///
/// 内容放在 ARB 里，每个模板一条缩进大纲（第一行是中心主题，每级两个
/// 空格，经 [mindMapNodeFromOutline] 解析），翻译只改文字。每个模板带一个
/// 合适的结构与配色，套用后用户可以随时在样式面板里换。
enum MindMapTemplate {
  brainstorm(MindMapStructure.mindMap, MindMapThemeId.rainbow),
  swot(MindMapStructure.mindMap, MindMapThemeId.macaron),
  book(MindMapStructure.logicRight, MindMapThemeId.paper),
  project(MindMapStructure.orgDown, MindMapThemeId.ocean),
  week(MindMapStructure.timeline, MindMapThemeId.sunset),
  decision(MindMapStructure.logicRight, MindMapThemeId.ink),
  trip(MindMapStructure.mindMap, MindMapThemeId.forest),
  goals(MindMapStructure.mindMap, MindMapThemeId.sakura);

  const MindMapTemplate(this.structure, this.theme);

  final MindMapStructure structure;
  final MindMapThemeId theme;

  String name(AppLocalizations l10n) => switch (this) {
    brainstorm => l10n.mindMapTemplateBrainstorm,
    swot => l10n.mindMapTemplateSwot,
    book => l10n.mindMapTemplateBook,
    project => l10n.mindMapTemplateProject,
    week => l10n.mindMapTemplateWeek,
    decision => l10n.mindMapTemplateDecision,
    trip => l10n.mindMapTemplateTrip,
    goals => l10n.mindMapTemplateGoals,
  };

  String outline(AppLocalizations l10n) => switch (this) {
    brainstorm => l10n.mindMapTemplateBrainstormOutline,
    swot => l10n.mindMapTemplateSwotOutline,
    book => l10n.mindMapTemplateBookOutline,
    project => l10n.mindMapTemplateProjectOutline,
    week => l10n.mindMapTemplateWeekOutline,
    decision => l10n.mindMapTemplateDecisionOutline,
    trip => l10n.mindMapTemplateTripOutline,
    goals => l10n.mindMapTemplateGoalsOutline,
  };

  /// 套用到 [base]：换掉整棵树，结构与配色换成模板的；根节点已经写了字
  /// （新建页转成导图时带过来的标题）时保留它。
  MindMapDocument applyTo(MindMapDocument base, AppLocalizations l10n) {
    final parsed = mindMapNodeFromOutline(outline(l10n));
    if (parsed == null) return base;
    final title = base.root.text.trim();
    final root = title.isEmpty ? parsed : parsed.copyWith(text: title);
    return MindMapOps.replaceRoot(
      base.copyWith(structure: structure.id, theme: theme.id),
      root,
    );
  }

  /// 样式面板预览用的样例图（按界面语言缓存：缩略图按文档引用判断要不要
  /// 重新布局，每次都新建一份会让预览格逐帧重排）。
  static MindMapDocument sample(AppLocalizations l10n) =>
      _samples[l10n.localeName] ??= MindMapTemplate.brainstorm.applyTo(
        MindMapDocument.blank(),
        l10n,
      );

  /// 起步卡里这个模板的预览图（同样按界面语言缓存）。
  MindMapDocument preview(AppLocalizations l10n) =>
      _previews[(this, l10n.localeName)] ??= applyTo(
        MindMapDocument.blank(),
        l10n,
      );

  static final Map<String, MindMapDocument> _samples =
      <String, MindMapDocument>{};
  static final Map<(MindMapTemplate, String), MindMapDocument> _previews =
      <(MindMapTemplate, String), MindMapDocument>{};
}
