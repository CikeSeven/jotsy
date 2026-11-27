import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import 'todo_tile_meta.dart';

/// 待办标签的微胶囊（DESIGN §5.2 的样子：无边框、淡底、w600 字，前缀 `@`；
/// 颜色取 `tertiary`，与清单的强调色、优先级色都分得开）。只借日记标签的
/// 外观，不用日记标签的组件与数据。
abstract final class TodoTagChips {
  /// 淡底：亮色 14%、暗色 24%，`tertiary` 字在上面两种主题都读得清。
  static Color background(ColorScheme scheme) => scheme.tertiary.withValues(
    alpha: scheme.brightness == Brightness.light ? 0.14 : 0.24,
  );

  /// 行上的标签胶囊：前 [max] 个各一颗，多出来的合成一颗“+N”。
  static List<Widget> forRow(
    BuildContext context,
    List<String> tags, {
    int max = 2,
  }) {
    if (tags.isEmpty) return const <Widget>[];
    final scheme = Theme.of(context).colorScheme;
    final bg = background(scheme);
    final shown = tags.length > max ? tags.take(max) : tags;
    final more = tags.length - shown.length;
    return <Widget>[
      for (final tag in shown)
        TodoMetaPill(
          text: '@$tag',
          background: bg,
          foreground: scheme.tertiary,
        ),
      if (more > 0)
        Semantics(
          label: context.l10n.todoTagsMoreLabel(more),
          excludeSemantics: true,
          child: TodoMetaPill(
            text: '+$more',
            background: bg,
            foreground: scheme.tertiary,
          ),
        ),
    ];
  }
}
