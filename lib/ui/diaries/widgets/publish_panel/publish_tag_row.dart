import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/widgets/expressive_icon_swap.dart';
import 'package:node_diary/ui/widgets/expressive_state_blend.dart';
import 'package:node_diary/ui/app_surface/widgets/on_glass.dart';

/// 标签子页的一行：`#` 色块 + 名称 + 勾选圈，点整行切换选中。
///
/// 选中时行底补间到标签色浅底，勾选圈换成标签色实心勾。多选日记的标签
/// 面板另有“部分有”（[partial]：只有部分所选日记带着这个标签）：行底同样
/// 是标签色浅底，勾选圈换成标签色的减号（与日记本选本面板的三态同一画法）；
/// 点按时 [onToggle] 收到 true（部分有 → 全部加上）。
class PublishTagRow extends StatelessWidget {
  const PublishTagRow({
    super.key,
    required this.tag,
    required this.selected,
    required this.onToggle,
    this.partial = false,
  });

  final Tag tag;
  final bool selected;
  final ValueChanged<bool> onToggle;

  /// 三态里的“部分有”；为 true 时 [selected] 应为 false。
  final bool partial;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final tagColor = Color(tag.color);
    // 未选中的底色：画在玻璃面板上时换成半透明的凹槽色（见 OnGlass），
    // 经典面板上照旧。
    final idle = OnGlass.of(context)
        ? OnGlass.wellColor(colorScheme)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.45);
    final active = selected || partial;
    final (checkIcon, checkColor) = selected
        ? (FontAwesomeIcons.solidCircleCheck, tagColor)
        : partial
        ? (FontAwesomeIcons.circleMinus, tagColor)
        : (FontAwesomeIcons.circle, colorScheme.outlineVariant);
    // 选中换色经 ExpressiveStateBlend 补间（Material 不补间颜色）。
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        checked: selected,
        mixed: partial ? true : null,
        child: ExpressiveStateBlend(
          active: active,
          builder: (context, t, child) => Material(
            color: Color.lerp(
              idle,
              tagColor.withValues(alpha: isLight ? 0.12 : 0.22),
              t,
            ),
            borderRadius: BorderRadius.circular(12),
            child: child,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onToggle(!selected),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: tagColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: tagColor.withValues(alpha: 0.45),
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '#',
                        style: TextStyle(
                          color: tagColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tag.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    ExpressiveIconSwap(
                      switchKey: (selected, partial),
                      child: FaIcon(checkIcon, size: 18, color: checkColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 按字母排序时的分组标题：字母与行里的 `#` 色块同列居中，右侧一道细线。
class PublishTagSectionHeader extends StatelessWidget {
  const PublishTagSectionHeader({super.key, required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        // 左 14 与行的内边距一致，字母落在 24dp 色块的正上方。
        padding: const EdgeInsets.fromLTRB(14, 4, 4, 8),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 24,
              child: Text(
                letter,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
