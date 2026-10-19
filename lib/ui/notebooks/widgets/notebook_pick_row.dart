import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../widgets/expressive_icon_swap.dart';
import '../../widgets/expressive_state_blend.dart';
import '../models/notebook_pick_selection.dart';
import '../viewmodels/notebook_view.dart';
import 'notebook_cover_parts.dart';

/// 收录选择器的一行（底部面板与发布面板的日记本子页共用），外观沿用发布
/// 面板的标签行：32dp 图标圆（日记本的容器色）、名称（bodyLarge w600）、
/// 篇数与私密图标，行尾为勾选状态。
///
/// - [state] 为三态：空心圆 / 实心勾 / 实心减号（“部分已收进”）；切换经
///   [ExpressiveIconSwap]，底色经 [ExpressiveStateBlend] 补间；
/// - [showCheck] 为 false 时行尾不显示勾选（“移动到…”点一下就选定）。
class NotebookPickRow extends StatelessWidget {
  const NotebookPickRow({
    super.key,
    required this.notebook,
    required this.state,
    required this.onTap,
    this.count,
    this.showCheck = true,
  });

  final NotebookView notebook;
  final NotebookPickState state;
  final VoidCallback? onTap;

  /// 篇数；null 时不显示。
  final int? count;
  final bool showCheck;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final accent = notebookAccentColors(notebook.color, scheme);
    final active = state != NotebookPickState.none;
    final count = this.count;
    final privateIcon = switch (notebook.visibility) {
      NotebookVisibility.locked => FontAwesomeIcons.lock,
      NotebookVisibility.hidden => FontAwesomeIcons.eyeSlash,
      NotebookVisibility.normal => null,
    };
    final mutedStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final (checkIcon, checkColor) = switch (state) {
      NotebookPickState.all => (
        FontAwesomeIcons.solidCircleCheck,
        accent.onContainer,
      ),
      NotebookPickState.some => (
        FontAwesomeIcons.circleMinus,
        accent.onContainer,
      ),
      NotebookPickState.none => (
        FontAwesomeIcons.circle,
        scheme.outlineVariant,
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        checked: showCheck ? state == NotebookPickState.all : null,
        mixed: showCheck && state == NotebookPickState.some ? true : null,
        button: !showCheck,
        child: ExpressiveStateBlend(
          active: active && showCheck,
          builder: (context, t, child) => Material(
            color: Color.lerp(
              scheme.surfaceContainerHighest.withValues(alpha: 0.45),
              accent.container.withValues(alpha: isLight ? 0.72 : 0.6),
              t,
            ),
            borderRadius: BorderRadius.circular(12),
            child: child,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: <Widget>[
                    NotebookIconCircle(
                      icon: notebook.icon,
                      accent: accent,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            notebook.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (count != null || privateIcon != null)
                            Row(
                              children: <Widget>[
                                if (count != null)
                                  Flexible(
                                    child: Text(
                                      l10n.notebookEntryCount(count),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: mutedStyle,
                                    ),
                                  ),
                                if (privateIcon != null) ...<Widget>[
                                  if (count != null) const SizedBox(width: 6),
                                  FaIcon(
                                    privateIcon,
                                    size: 11,
                                    color: scheme.onSurfaceVariant,
                                    semanticLabel:
                                        notebook.visibility ==
                                            NotebookVisibility.locked
                                        ? l10n.notebookStateLocked
                                        : l10n.notebookStateHidden,
                                  ),
                                ],
                              ],
                            ),
                        ],
                      ),
                    ),
                    if (showCheck) ...<Widget>[
                      const SizedBox(width: 8),
                      ExpressiveIconSwap(
                        switchKey: state,
                        child: FaIcon(checkIcon, size: 18, color: checkColor),
                      ),
                    ],
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

/// 选择器顶部的“＋ 新建日记本”行，与 [NotebookPickRow] 同一表面。
class NotebookPickCreateRow extends StatelessWidget {
  const NotebookPickCreateRow({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                FaIcon(FontAwesomeIcons.plus, size: 12, color: scheme.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    context.l10n.notebookNew,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
