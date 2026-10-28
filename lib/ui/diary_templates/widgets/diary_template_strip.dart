import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../app_surface/widgets/app_card_surface.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../../app_surface/widgets/app_glass_scope.dart';
import '../../app_surface/widgets/app_glass_surface.dart';
import '../../widgets/glass/glass_reveal.dart';
import '../controllers/diary_template_apply_controller.dart';
import '../models/diary_template.dart';
import '../providers/diary_template_providers.dart';
import '../viewmodels/diary_template_library.dart';
import 'diary_template_icon_badge.dart';
import '../../widgets/desktop_horizontal_scroll.dart';

/// 新建空白日记时放在标题下方的“从模板开始”建议条。
///
/// 列出几个模板（推荐的在前、再是最近用过的，见
/// [DiaryTemplateLibrary.suggestions]），点一下即套用；“全部”打开完整的
/// 模板面板，✕ 收起后本次编辑不再出现。用户写了字、已经套用、偏好里关掉
/// 建议条、或者没有可选的模板时整块收起不占位；出现与收起经 [AnimatedSize]
/// 平滑展开、折叠，与“这天拍的照片”提示条同一套动效。
///
/// 只负责展示；套用、撤销与提示由编辑页经 [onApply] / [onOpenAll] 完成。
class DiaryTemplateStrip extends ConsumerWidget {
  const DiaryTemplateStrip({
    super.key,
    required this.controller,
    required this.diaryDate,
    required this.busy,
    required this.onApply,
    required this.onOpenAll,
  });

  final DiaryTemplateApplyController controller;

  /// 日记的日期（补写时是那一天），决定推荐。
  final DateTime diaryDate;

  /// 正在保存、录音或导入媒体：模板不可点。
  final bool busy;
  final ValueChanged<DiaryTemplate> onApply;
  final VoidCallback onOpenAll;

  /// 建议条上最多几个模板，更多的在“全部”里。
  static const int maxSuggestions = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = watchDiaryTemplateLibrary(ref, context.l10n).library;
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final suggestions = controller.stripVisible && library.prefs.showStrip
            ? library.suggestions(
                now: DateTime.now(),
                diaryDate: diaryDate,
                limit: maxSuggestions,
              )
            : const <DiaryTemplateSuggestion>[];
        return AnimatedSize(
          duration: ExpressiveMotion.durationNonZero(
            context,
            ExpressiveMotion.medium,
          ),
          curve: ExpressiveMotion.effects,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
            switchInCurve: ExpressiveMotion.effects,
            switchOutCurve: ExpressiveMotion.exit,
            // 卡片为玻璃时提示条是玻璃表面，不能放进 FadeTransition（模糊会
            // 采不到页面），改经 GlassReveal 由玻璃自己淡入。
            transitionBuilder: AppCardSurface.isGlass(context)
                ? (Widget child, Animation<double> animation) =>
                      GlassRevealTransition(progress: animation, child: child)
                : AnimatedSwitcher.defaultTransitionBuilder,
            layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
              alignment: Alignment.topCenter,
              children: <Widget>[...previous, ?current],
            ),
            child: suggestions.isEmpty
                ? const SizedBox(
                    key: ValueKey<String>('hidden'),
                    width: double.infinity,
                  )
                : _StripCard(
                    key: const ValueKey<String>('templates'),
                    suggestions: suggestions,
                    busy: busy,
                    onApply: onApply,
                    onOpenAll: onOpenAll,
                    onDismiss: controller.dismiss,
                  ),
          ),
        );
      },
    );
  }
}

class _StripCard extends StatelessWidget {
  const _StripCard({
    super.key,
    required this.suggestions,
    required this.busy,
    required this.onApply,
    required this.onOpenAll,
    required this.onDismiss,
  });

  final List<DiaryTemplateSuggestion> suggestions;
  final bool busy;
  final ValueChanged<DiaryTemplate> onApply;
  final VoidCallback onOpenAll;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.m),
      child: _StripBox(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.m,
            AppSpacing.xs,
            AppSpacing.xs,
            AppSpacing.m,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  FaIcon(
                    FontAwesomeIcons.wandMagicSparkles,
                    size: 14,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Text(
                      l10n.diaryTemplateStripTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: busy ? null : onOpenAll,
                    child: Text(l10n.diaryTemplateStripAll),
                  ),
                  IconButton(
                    tooltip: l10n.diaryTemplateStripDismiss,
                    visualDensity: VisualDensity.compact,
                    onPressed: onDismiss,
                    icon: FaIcon(
                      FontAwesomeIcons.xmark,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              // 横向滚动的一排模板；按内容高度排布，字号放大时不会被截断。
              DesktopHorizontalScroll(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: AppSpacing.s),
                  child: Row(
                    children: <Widget>[
                      for (final suggestion in suggestions) ...<Widget>[
                        _TemplateChip(
                          suggestion: suggestion,
                          onTap: busy
                              ? null
                              : () => onApply(suggestion.template),
                        ),
                        const SizedBox(width: AppSpacing.s),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 一个模板：强调色小圆标 + 名称，推荐的带“推荐”标记。
class _TemplateChip extends StatelessWidget {
  const _TemplateChip({required this.suggestion, required this.onTap});

  final DiaryTemplateSuggestion suggestion;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final template = suggestion.template;
    final name = template.name.isEmpty
        ? l10n.diaryTemplateUntitled
        : template.name;
    // 玻璃时为半透明底色 + 玻璃描边，经典时原样。
    final glassField = AppGlassField.of(context);
    return Material(
      color: glassField?.fill ?? theme.colorScheme.surfaceContainerHigh,
      shape: StadiumBorder(side: glassField?.border ?? BorderSide.none),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DiaryTemplateIconBadge(
                icon: template.icon,
                accent: template.accent,
                size: 26,
              ),
              const SizedBox(width: AppSpacing.s),
              Text(
                name,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (suggestion.recommended) ...<Widget>[
                const SizedBox(width: 6),
                DiaryTemplateBadge(label: l10n.diaryTemplateRecommended),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 提示条外壳：经典为卡片表面 + 0.8dp 微边框；“卡片”为玻璃时为内容玻璃
/// （与页面里的其他卡片同一材质，切换的淡入见 transitionBuilder）。
class _StripBox extends StatelessWidget {
  const _StripBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(AppRadii.input));
    if (AppCardSurface.isGlass(context)) {
      return AppGlassSurface(
        component: AppGlassComponent.cards,
        borderRadius: radius,
        child: child,
      );
    }
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ExpressiveSurfaces.cardColor(colorScheme),
        borderRadius: radius,
        border: Border.fromBorderSide(
          ExpressiveSurfaces.cardBorderSide(colorScheme),
        ),
      ),
      child: child,
    );
  }
}
