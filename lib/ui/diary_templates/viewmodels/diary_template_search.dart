import '../../../l10n/app_localizations_gen.dart';
import '../models/diary_template.dart';
import 'diary_template_labels.dart';

/// 模板面板的搜索匹配（纯函数，不碰状态）。
///
/// 输入：搜索框原文与一个模板；输出：是否命中。
/// 规则：去掉首尾空白、统一小写后按空白切成若干词，每个词都要（“且”）
/// 出现在模板的显示名称、说明或分类名称之一里。查的是界面上看得到的文字：
/// 没起名的用户模板按“未命名模板”查，分类按当前语言的名称查，
/// 这样用户照着屏幕上的字输入就一定能搜到。不做拼音匹配。

/// 把搜索框原文切成小写的搜索词；只有空白时返回空列表（视为没在搜索）。
List<String> diaryTemplateSearchTerms(String query) {
  final trimmed = query.trim().toLowerCase();
  if (trimmed.isEmpty) return const <String>[];
  return trimmed.split(RegExp(r'\s+'));
}

/// [template] 是否命中 [query]；空查询命中全部。
bool diaryTemplateMatchesQuery(
  AppLocalizations l10n,
  DiaryTemplate template,
  String query,
) {
  final terms = diaryTemplateSearchTerms(query);
  if (terms.isEmpty) return true;
  final name = template.name.isEmpty
      ? l10n.diaryTemplateUntitled
      : template.name;
  // 三段文字用换行拼起来：换行不会出现在搜索词里（词已按空白切开），
  // 所以一个词不会跨越两段被误判命中。
  final haystack = <String>[
    name,
    template.description,
    diaryTemplateCategoryLabel(l10n, template.category),
  ].join('\n').toLowerCase();
  return terms.every(haystack.contains);
}
