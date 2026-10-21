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
/// 输入：内置模板的默认内容（按界面语言编译）、数据库里的模板行（已按手动
/// 排序）、模板偏好；输出：选择面板、建议条与管理页要用的列表。纯计算、
/// 无副作用。
///
/// 数据库里 id 与某个内置模板相同的行是用户改过的这个内置模板：它替换默认
/// 内容、留在内置模板原来的位置（[builtIns]），不算“我的模板”。被删除的
/// 内置模板（偏好里的 `hidden`）不出现在 [visible]，[byId] 也找不到它——与
/// 删除我的模板一样，自动套用、日记本的默认模板都不再套用它；恢复后照常。
class DiaryTemplateLibrary {
  factory DiaryTemplateLibrary({
    required List<DiaryTemplate> builtIns,
    required List<DiaryTemplate> userTemplates,
    required DiaryTemplatePrefs prefs,
  }) {
    final defaultIds = <String>{for (final template in builtIns) template.id};
    final edited = <String, DiaryTemplate>{};
    final mine = <DiaryTemplate>[];
    for (final template in userTemplates) {
      // 内置 id 却对不上任何内置模板（将来的版本去掉了它）：留作我的模板，
      // 不让用户改过的内容凭空消失。
      if (defaultIds.contains(template.id)) {
        edited[template.id] = template;
      } else {
        mine.add(template);
      }
    }
    return DiaryTemplateLibrary._(
      builtIns: List<DiaryTemplate>.unmodifiable(<DiaryTemplate>[
        for (final template in builtIns) edited[template.id] ?? template,
      ]),
      userTemplates: List<DiaryTemplate>.unmodifiable(mine),
      editedBuiltIns: Set<String>.unmodifiable(edited.keys),
      prefs: prefs,
    );
  }

  DiaryTemplateLibrary._({
    required this.builtIns,
    required this.userTemplates,
    required this.editedBuiltIns,
    required this.prefs,
  });

  /// 内置模板（改过的已替换为用户的版本），含已删除的，按内置顺序。
  final List<DiaryTemplate> builtIns;

  /// 我的模板（手动排序），不含改过的内置模板。
  final List<DiaryTemplate> userTemplates;

  /// 改过内容的内置模板 id（数据库里有它的行，可以恢复默认）。
  final Set<String> editedBuiltIns;

  final DiaryTemplatePrefs prefs;

  bool isDeleted(DiaryTemplate template) =>
      prefs.hiddenBuiltIns.contains(template.id);

  /// 被删除的内置模板，按内置顺序；管理页据此提供恢复。
  late final List<DiaryTemplate> deletedBuiltIns =
      List<DiaryTemplate>.unmodifiable(builtIns.where(isDeleted));

  /// 可选用的模板：我的模板在前（手动排序），被删除的内置模板不出现。
  late final List<DiaryTemplate> visible = List<DiaryTemplate>.unmodifiable(
    <DiaryTemplate>[...userTemplates, ...builtIns.where((t) => !isDeleted(t))],
  );

  late final Map<String, DiaryTemplate> _byId = <String, DiaryTemplate>{
    for (final template in visible) template.id: template,
  };

  /// 按 id 找可选用的模板；已删除（含被删除的内置模板）时为 null。
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
