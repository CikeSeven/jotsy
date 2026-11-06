import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/core/services/app_platform.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/widgets/launch_reveal.dart';

import '../controllers/tag_filter_pull_hint_controller.dart';

/// 标签栏收着时的“下拉展开”提示行（一次性功能提示，时序见
/// `TagFilterPullHintController`）。
///
/// 与展开后底部的 `TagFilterCollapseHandle` 是同一个位置、同一套版式（居中的
/// 12dp 箭头 + labelSmall 文字），箭头朝下、用主色，两者互为镜像，看到一个
/// 就能猜到另一个。点按直接展开标签栏，桌面上鼠标不习惯“下拉”，同样可以
/// 点；在这一行上下拉的手势由外层的标签栏手势处理。
///
/// [peek] 为轻推演示的进度，箭头随标签栏同步下沉 [_arrowTravel]。
class TagFilterPullHint extends StatelessWidget {
  const TagFilterPullHint({
    super.key,
    required this.count,
    required this.onTap,
    this.peek,
  });

  static const double _arrowTravel = 3;

  /// 当前标签栏里的标签数（不含日记本切换胶囊与清除按钮）。
  final int count;
  final VoidCallback onTap;
  final Animation<double>? peek;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = theme.colorScheme.primary;
    final label = AppPlatform.isDesktop
        ? context.l10n.diaryTagPullHintDesktop(count)
        : context.l10n.diaryTagPullHint(count);
    final arrow = FaIcon(
      FontAwesomeIcons.angleDown,
      size: 12,
      color: foreground,
    );
    final peek = this.peek;
    return Semantics(
      label: label,
      hint: context.l10n.diaryTagExpand,
      button: true,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (peek == null)
                    arrow
                  else
                    AnimatedBuilder(
                      animation: peek,
                      child: arrow,
                      builder: (BuildContext context, Widget? child) =>
                          Transform.translate(
                            offset: Offset(
                              0,
                              _arrowTravel * peek.value.clamp(0.0, 1.0),
                            ),
                            child: child,
                          ),
                    ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: foreground,
                      ),
                    ),
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

/// 把“此刻能否提示”同步给 [TagFilterPullHintController]，原样返回 [child]。
///
/// 单独成一个小组件，是为了把它读取的 TickerMode（日记 Tab 是否可见）、路由
/// 是否在最上层、入场编排与减少动画这几项依赖收在这一小块里：切换 Tab、推入
/// 或返回页面时只有它重建（[child] 是同一个实例，不会连带重建），不牵动整个
/// 日记页。[enabled] 为页面自己的条件（不在多选、标签栏收着）。
class TagFilterPullHintSync extends StatelessWidget {
  const TagFilterPullHintSync({
    super.key,
    required this.controller,
    required this.settings,
    required this.enabled,
    required this.child,
  });

  final TagFilterPullHintController controller;
  final SettingsService settings;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    controller.sync(
      settings: settings,
      reveal: LaunchRevealScope.maybeOf(context),
      pageActive:
          enabled &&
          TickerMode.valuesOf(context).enabled &&
          ModalRoute.isCurrentOf(context) != false,
      reduceMotion: ExpressiveMotion.reduceMotion(context),
    );
    return child;
  }
}
