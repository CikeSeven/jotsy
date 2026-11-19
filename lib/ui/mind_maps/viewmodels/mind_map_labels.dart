import '../../../l10n/app_localizations.dart';
import '../models/mind_map_options.dart';
import '../models/mind_map_themes.dart';

/// 导图各类选项的界面文案。

String mindMapStructureLabel(
  AppLocalizations l10n,
  MindMapStructure structure,
) => switch (structure) {
  MindMapStructure.mindMap => l10n.mindMapStructureMindMap,
  MindMapStructure.logicRight => l10n.mindMapStructureLogicRight,
  MindMapStructure.logicLeft => l10n.mindMapStructureLogicLeft,
  MindMapStructure.orgDown => l10n.mindMapStructureOrgDown,
  MindMapStructure.treeRight => l10n.mindMapStructureTreeRight,
  MindMapStructure.timeline => l10n.mindMapStructureTimeline,
  MindMapStructure.fishbone => l10n.mindMapStructureFishbone,
};

String mindMapThemeLabel(AppLocalizations l10n, MindMapThemeId theme) =>
    switch (theme) {
      MindMapThemeId.follow => l10n.mindMapThemeFollow,
      MindMapThemeId.rainbow => l10n.mindMapThemeRainbow,
      MindMapThemeId.ocean => l10n.mindMapThemeOcean,
      MindMapThemeId.forest => l10n.mindMapThemeForest,
      MindMapThemeId.sunset => l10n.mindMapThemeSunset,
      MindMapThemeId.sakura => l10n.mindMapThemeSakura,
      MindMapThemeId.ink => l10n.mindMapThemeInk,
      MindMapThemeId.paper => l10n.mindMapThemePaper,
      MindMapThemeId.neon => l10n.mindMapThemeNeon,
      MindMapThemeId.macaron => l10n.mindMapThemeMacaron,
    };

String mindMapLineLabel(AppLocalizations l10n, MindMapLineStyle line) =>
    switch (line) {
      MindMapLineStyle.curve => l10n.mindMapLineCurve,
      MindMapLineStyle.straight => l10n.mindMapLineStraight,
      MindMapLineStyle.elbow => l10n.mindMapLineElbow,
      MindMapLineStyle.rounded => l10n.mindMapLineRounded,
    };

String mindMapSpacingLabel(AppLocalizations l10n, MindMapSpacing spacing) =>
    switch (spacing) {
      MindMapSpacing.compact => l10n.mindMapSpacingCompact,
      MindMapSpacing.standard => l10n.mindMapSpacingStandard,
      MindMapSpacing.loose => l10n.mindMapSpacingLoose,
    };

String mindMapTextSizeLabel(AppLocalizations l10n, MindMapTextSize size) =>
    switch (size) {
      MindMapTextSize.small => l10n.mindMapSizeSmall,
      MindMapTextSize.medium => l10n.mindMapSizeMedium,
      MindMapTextSize.large => l10n.mindMapSizeLarge,
      MindMapTextSize.huge => l10n.mindMapSizeHuge,
    };

/// 导图在标题处的名字：中心主题的文字（压成一行），没写时为“未命名导图”。
String mindMapTitle(AppLocalizations l10n, String rootText) {
  final title = rootText.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();
  return title.isEmpty ? l10n.mindMapUntitled : title;
}
