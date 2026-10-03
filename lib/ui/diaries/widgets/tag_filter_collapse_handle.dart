import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

/// A separate collapse target keeps browsing gestures out of the expansion
/// state machine. The enclosing tag recognizer handles swipes on this footer;
/// tapping it provides the same action for accessibility and precise pointers.
class TagFilterCollapseHandle extends StatelessWidget {
  const TagFilterCollapseHandle({super.key, required this.onCollapse});

  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      label: context.l10n.diaryTagCollapse,
      hint: context.l10n.diaryTagCollapseHint,
      button: true,
      onTap: onCollapse,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onCollapse,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  FaIcon(FontAwesomeIcons.angleUp, size: 12, color: foreground),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.diaryTagCollapse,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: foreground),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
