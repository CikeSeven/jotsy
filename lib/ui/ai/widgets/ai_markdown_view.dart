import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/widgets/external_link.dart';
import '../../settings/widgets/release_notes_view.dart';

/// AI 回答的 Markdown 渲染：复用更新说明的 Markdown 子集渲染
/// （[ReleaseNotesView]），网址链接在浏览器打开，`[Dn]` 引用经
/// [onCitation] 跳到日记。流式生成中内容不断变长，按全文重新解析（回答
/// 通常不长，解析很快）。
class AiMarkdownView extends StatelessWidget {
  const AiMarkdownView({
    super.key,
    required this.markdown,
    this.onCitation,
    this.bodyStyle,
  });

  final String markdown;
  final ValueChanged<String>? onCitation;
  final TextStyle? bodyStyle;

  @override
  Widget build(BuildContext context) {
    return ReleaseNotesView(
      markdown: markdown,
      bodyStyle: bodyStyle,
      onCitation: onCitation,
      onOpenLink: (link) => openExternalLink(context, link),
    );
  }
}

/// 可折叠的思考过程：默认收起，标题行点按展开；内容为灰色小字。
class AiReasoningFold extends StatefulWidget {
  const AiReasoningFold({
    super.key,
    required this.reasoning,
    this.initiallyExpanded = false,
  });

  final String reasoning;
  final bool initiallyExpanded;

  @override
  State<AiReasoningFold> createState() => _AiReasoningFoldState();
}

class _AiReasoningFoldState extends State<AiReasoningFold> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final style = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
      height: 1.5,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                FaIcon(
                  FontAwesomeIcons.lightbulb,
                  size: 12,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  context.l10n.aiPanelReasoning,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: ExpressiveMotion.duration(
                    context,
                    ExpressiveMotion.fast,
                  ),
                  child: FaIcon(
                    FontAwesomeIcons.angleDown,
                    size: 10,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
          curve: ExpressiveMotion.effects,
          alignment: Alignment.topLeft,
          child: _expanded
              ? Container(
                  margin: const EdgeInsets.only(top: 4, bottom: 6),
                  padding: const EdgeInsets.only(left: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: colors.outlineVariant, width: 2),
                    ),
                  ),
                  child: Text(widget.reasoning.trim(), style: style),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
