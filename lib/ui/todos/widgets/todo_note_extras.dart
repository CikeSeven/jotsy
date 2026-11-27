import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../settings/widgets/external_link.dart';
import 'todo_field_pill.dart';

/// 备注卡下面的一排小胶囊：备注里有清单行（`- [ ] 买菜`）时“把 N 行清单
/// 转为步骤”（[onChecklistToSteps]），以及备注里识别出的链接（至多
/// [maxLinks] 个，写网站名，点开经 [openExternalLink] 在外部打开）。都没有
/// 时不占位。按库里的备注算（输入防抖写库之后才更新）。
class TodoNoteExtras extends StatelessWidget {
  const TodoNoteExtras({
    super.key,
    required this.note,
    required this.onChecklistToSteps,
  });

  final String note;
  final VoidCallback onChecklistToSteps;

  static const int maxLinks = 3;

  /// 备注里的网址（http / https），去掉句尾的标点，按出现顺序去重。
  static List<Uri> linksIn(String text) {
    final links = <Uri>[];
    for (final match in _url.allMatches(text)) {
      final raw = match.group(0)!.replaceFirst(_trailing, '');
      final uri = Uri.tryParse(raw);
      if (uri == null || uri.host.isEmpty) continue;
      if (links.any((Uri link) => link.toString() == uri.toString())) continue;
      links.add(uri);
    }
    return links;
  }

  /// 网址只认 ASCII 字符：中文里网址后面常直接跟着字，不隔空格。
  static final RegExp _url = RegExp(
    r"https?://[A-Za-z0-9\-._~:/?#\[\]@!$&'()*+,;=%]+",
  );
  static final RegExp _trailing = RegExp(r'[.,;:!?)\]}>，。；：！？）】」』]+$');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final checklist = splitTodoNoteChecklist(note).steps.length;
    final links = linksIn(note).take(maxLinks).toList();
    if (checklist == 0 && links.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        if (checklist > 0)
          TodoFieldPill(
            icon: FontAwesomeIcons.listCheck,
            label: l10n.todoNoteChecklistToSteps(checklist),
            set: true,
            onTap: onChecklistToSteps,
          ),
        for (final link in links)
          Semantics(
            button: true,
            link: true,
            label: l10n.todoNoteOpenLink(link.host),
            excludeSemantics: true,
            child: TodoFieldPill(
              icon: FontAwesomeIcons.link,
              label: link.host,
              set: false,
              onTap: () => openExternalLink(context, link.toString()),
            ),
          ),
      ],
    );
  }
}
