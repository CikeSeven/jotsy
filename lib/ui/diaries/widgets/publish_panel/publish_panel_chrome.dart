import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/l10n/app_localizations.dart';

/// 面板子页骨架：顶部固定表头 + 分隔线，下方内容随展开进度淡入。
///
/// 拖拽中只重建淡入层与交互开关，[content] 作为缓存 child 不随进度重建；
/// 展开到 58% 以上才开放内部交互，避免半展开时误触。
class PublishPanelPageScaffold extends StatelessWidget {
  const PublishPanelPageScaffold({
    super.key,
    required this.progress,
    required this.headerHeight,
    required this.header,
    required this.content,
  });

  final ValueListenable<double> progress;
  final double headerHeight;
  final Widget header;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    final dividerColor = Theme.of(
      context,
    ).colorScheme.outlineVariant.withValues(alpha: 0.5);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned.fill(
          top: headerHeight + 1,
          child: ClipRect(
            child: ValueListenableBuilder<double>(
              valueListenable: progress,
              builder: (BuildContext context, double value, Widget? child) {
                final detailsOpacity = ((value - 0.15) / 0.85)
                    .clamp(0.0, 1.0)
                    .toDouble();
                return IgnorePointer(
                  ignoring: value < 0.58,
                  child: Opacity(opacity: detailsOpacity, child: child),
                );
              },
              child: content,
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              header,
              Divider(height: 1, color: dividerColor),
            ],
          ),
        ),
      ],
    );
  }
}

/// 主页表头：双箭头 + “上划展开 / 下滑收起”，点按切换展开状态。
///
/// 箭头随拖拽进度连续翻转：纵向缩放 1 → -1，上指的双箭头先压扁成一道横线
/// 再翻成下指，跟手且不会在越过阈值的那一帧突然掉头；文案仍按阈值切换，
/// 用短交叉淡入衔接。减少动态效果时朝向按阈值直接切换。
class PublishPanelMainHeader extends StatelessWidget {
  const PublishPanelMainHeader({
    super.key,
    required this.progress,
    required this.height,
    required this.onExpand,
    required this.onCollapse,
  });

  /// 低于该进度按“收起”呈现（箭头朝上、文案“上划展开”）。
  static const double collapsedVisualThreshold = 0.56;

  final ValueListenable<double> progress;
  final double height;
  final VoidCallback onExpand;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700);
    final reduceMotion = ExpressiveMotion.reduceMotion(context);
    return SizedBox(
      height: height,
      child: ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (BuildContext context, double value, Widget? _) {
          final collapsedVisual = value < collapsedVisualThreshold;
          final flip = reduceMotion
              ? (collapsedVisual ? 1.0 : -1.0)
              : 1 - 2 * value;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: collapsedVisual ? onExpand : onCollapse,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.diagonal3Values(1, flip, 1),
                      child: const FaIcon(FontAwesomeIcons.anglesUp, size: 14),
                    ),
                    const SizedBox(width: 10),
                    // 中英文案长短不一：宽度随文案平滑过渡，箭头不会跳位。
                    AnimatedSize(
                      duration: ExpressiveMotion.durationNonZero(
                        context,
                        ExpressiveMotion.fast,
                      ),
                      curve: ExpressiveMotion.effects,
                      child: AnimatedSwitcher(
                        duration: ExpressiveMotion.duration(
                          context,
                          ExpressiveMotion.fast,
                        ),
                        switchInCurve: ExpressiveMotion.effects,
                        switchOutCurve: ExpressiveMotion.exit,
                        child: Text(
                          collapsedVisual ? l10n.autoT0158 : l10n.autoT0159,
                          key: ValueKey<bool>(collapsedVisual),
                          style: titleStyle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 子页表头：左返回、中标题、右侧等宽占位让标题居中。
class PublishPanelSubHeader extends StatelessWidget {
  const PublishPanelSubHeader({
    super.key,
    required this.title,
    required this.height,
    required this.onBack,
  });

  final String title;
  final double height;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: onBack,
            icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
            tooltip: context.l10n.commonBack,
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

/// 发表主按钮。[sealing] 为 true 时文案为“封存这篇日记”；[busy] 时停用并
/// 显示“发布中…”。
class PublishPanelActionButton extends StatelessWidget {
  const PublishPanelActionButton({
    super.key,
    required this.busy,
    required this.sealing,
    required this.onPressed,
  });

  final bool busy;
  final bool sealing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          minimumSize: const Size(64, 56),
          textStyle: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        onPressed: busy ? null : onPressed,
        icon: const FaIcon(FontAwesomeIcons.paperPlane, size: 13),
        label: Text(
          busy
              ? l10n.autoT0176
              : sealing
              ? l10n.timeCapsuleSealAction
              : l10n.autoT0138,
        ),
      ),
    );
  }
}
