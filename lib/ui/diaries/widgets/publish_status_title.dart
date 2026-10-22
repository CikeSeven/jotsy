import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/expressive_motion.dart';

/// 发布页顶栏标题，同时是“已发表”的提示。
///
/// 发布页进入即发表：写库前为“发表日记”，写库成功（[published]）后换成
/// 主题色对勾 + “日记已发表”，并一直停在顶栏——它说明的是这篇日记此刻的
/// 状态，不用弹出、也不用等它消失的提示条。切换时旧标题淡出、新标题淡入，
/// 对勾以弹性放大出现；减少动画时直接替换。读屏经 liveRegion 播报。
class PublishStatusTitle extends StatelessWidget {
  const PublishStatusTitle({super.key, required this.published});

  final bool published;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = published
        ? Row(
            key: const ValueKey<bool>(true),
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const _PoppingCheck(),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  l10n.publishSucceeded,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          )
        : Text(
            l10n.autoT0138,
            key: const ValueKey<bool>(false),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
    return Semantics(
      liveRegion: published,
      child: AnimatedSwitcher(
        duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
        switchInCurve: ExpressiveMotion.effects,
        switchOutCurve: ExpressiveMotion.exit,
        // 新旧标题都靠起始边对齐，交叉淡入时不左右跳。
        layoutBuilder: (current, previous) => Stack(
          alignment: AlignmentDirectional.centerStart,
          children: <Widget>[...previous, ?current],
        ),
        child: title,
      ),
    );
  }
}

/// 对勾第一次出现时以弹性曲线从 0.4 放大到 1（缩放允许过冲，透明度交给外层
/// 的 AnimatedSwitcher，不叠弹簧曲线）。
class _PoppingCheck extends StatelessWidget {
  const _PoppingCheck();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.4, end: 1),
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.long),
      curve: ExpressiveMotion.spatial,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: FaIcon(
        FontAwesomeIcons.circleCheck,
        size: 18,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
