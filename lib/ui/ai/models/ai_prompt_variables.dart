import '../../../l10n/app_localizations_gen.dart';

/// 自定义写作指令提示词里可用的变量，写作 `{{文字}}` 或 `{{text}}`。中英
/// 别名都认（换界面语言后已写的提示词照样生效），认不出的原样保留。
enum AiPromptVariable {
  text(<String>['text', '文字']),
  diary(<String>['diary', '全文']),
  title(<String>['title', '标题']),
  date(<String>['date', '日期']),
  mood(<String>['mood', '心情']);

  const AiPromptVariable(this.aliases);

  /// 第一个为英文、第二个为中文写法。
  final List<String> aliases;

  /// 插入提示词时的写法（按界面语言选别名）。
  String token({required bool zh}) => '{{${zh ? aliases[1] : aliases[0]}}}';

  String label(AppLocalizations l10n) => switch (this) {
    text => l10n.aiVariableText,
    diary => l10n.aiVariableDiary,
    title => l10n.aiVariableTitle,
    date => l10n.aiVariableDate,
    mood => l10n.aiVariableMood,
  };

  static AiPromptVariable? fromAlias(String alias) {
    final normalized = alias.trim().toLowerCase();
    for (final value in values) {
      if (value.aliases.contains(normalized)) return value;
    }
    return null;
  }
}

final RegExp _variablePattern = RegExp(r'\{\{\s*([^{}\s]+)\s*\}\}');

/// 提示词里是否写了某个变量。
bool aiPromptUses(String template, AiPromptVariable variable) {
  for (final match in _variablePattern.allMatches(template)) {
    if (AiPromptVariable.fromAlias(match.group(1)!) == variable) return true;
  }
  return false;
}

/// 把变量换成取值；没有取值的变量换成空字符串，认不出的写法原样保留。
String fillAiPromptVariables(
  String template,
  Map<AiPromptVariable, String> values,
) {
  return template.replaceAllMapped(_variablePattern, (Match match) {
    final variable = AiPromptVariable.fromAlias(match.group(1)!);
    if (variable == null) return match.group(0)!;
    return values[variable] ?? '';
  });
}
