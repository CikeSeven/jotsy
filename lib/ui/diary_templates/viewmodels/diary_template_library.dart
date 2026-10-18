import 'package:flutter/foundation.dart';

import '../models/diary_template.dart';
import '../models/diary_template_prefs.dart';
import '../models/diary_template_recommend.dart';

/// 一个可供选用的模板及它此刻是否推荐。
@immutable
class DiaryTemplateSuggestion {
  const DiaryTemplateSuggestion(this.template, {this.recommended = false});

  final DiaryTemplate template;
  final bool recommended;
}

/// 全部模板（用户模板 + 内置模板）与偏好合在一起后的视图。
///
/// 输入：内置模板（按界面语言编译）、数据库里的用户模板（已按手动排序）、
/// 模板偏好；输出：选择面板与建议条要用的列表。纯计算、无副作用。
class DiaryTemplateLibrary {
  DiaryTemplateLibrary({
    required this.builtIns,
    required this.userTemplates,
    required this.prefs,
  });

  final List<DiaryTemplate> builtIns;
  final List<DiaryTemplate> userTemplates;
  final DiaryTemplatePrefs prefs;

  /// 可选用的模板：我的模板在前（手动排序），隐藏的内置模板不出现。
  late final List<DiaryTemplate> visible =
      List<DiaryTemplate>.unmodifiable(<DiaryTemplate>[
        ...userTemplates,
        ...builtIns.where((t) => !prefs.hiddenBuiltIns.contains(t.id)),
      ]);

  late final Map<String, DiaryTemplate> _byId = <String, DiaryTemplate>{
    for (final template in builtIns) template.id: template,
    for (final template in userTemplates) template.id: template,
  };

  /// 按 id 找模板（含隐藏的内置模板：自动套用、最近使用仍认它们）。
  DiaryTemplate? byId(String? id) => id == null ? null : _byId[id];

  /// 自动套用的模板；设置里指向的模板已被删除时为 null。
  DiaryTemplate? get autoTemplate => byId(prefs.autoTemplateId);

  /// 可选用的模板及推荐标记，推荐的排最前（按命中的条件数，再按库内顺序）。
  List<DiaryTemplateSuggestion> ranked({
    required DateTime now,
    required DateTime diaryDate,
  }) {
    final scored = <(DiaryTemplate, int?, int)>[
      for (var i = 0; i < visible.length; i++)
        (
          visible[i],
          scoreDiaryTemplate(
            visible[i].recommend,
            now: now,
            diaryDate: diaryDate,
          ),
          i,
        ),
    ];
    scored.sort((a, b) {
      final scoreA = a.$2 ?? 0;
      final scoreB = b.$2 ?? 0;
      if (scoreA != scoreB) return scoreB.compareTo(scoreA);
      return a.$3.compareTo(b.$3);
    });
    return <DiaryTemplateSuggestion>[
      for (final (template, score, _) in scored)
        DiaryTemplateSuggestion(template, recommended: score != null),
    ];
  }

  /// 建议条上的几个模板：先放推荐的，再放最近用过的，不够 [limit] 个时按
  /// 库内顺序补齐；同一个模板只出现一次。
  List<DiaryTemplateSuggestion> suggestions({
    required DateTime now,
    required DateTime diaryDate,
    int limit = 5,
  }) {
    final all = ranked(now: now, diaryDate: diaryDate);
    final byId = <String, DiaryTemplateSuggestion>{
      for (final item in all) item.template.id: item,
    };
    final picked = <String, DiaryTemplateSuggestion>{};
    void add(DiaryTemplateSuggestion? item) {
      if (item == null || picked.length >= limit) return;
      picked.putIfAbsent(item.template.id, () => item);
    }

    all.where((item) => item.recommended).forEach(add);
    prefs.recent.map((id) => byId[id]).forEach(add);
    all.forEach(add);
    return picked.values.toList(growable: false);
  }
}
