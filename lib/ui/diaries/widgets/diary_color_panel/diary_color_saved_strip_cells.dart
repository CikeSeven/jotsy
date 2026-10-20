part of 'diary_color_saved_strip.dart';

// 我的颜色一行里的各种格子：可展开 / 收拢的色块格、首格“+”、末格管理开关、
// 两组之间的竖分隔与空状态说明。

/// 一格的展开 / 收拢：宽度从 0 展开（effects，收拢 exit），同时淡入并以
/// spatial 弹性放大；收拢中不响应点按。
class _StripCell extends StatefulWidget {
  const _StripCell({
    super.key,
    required this.width,
    required this.leaving,
    required this.animateIn,
    required this.onExited,
    required this.child,
  });

  final double width;
  final bool leaving;
  final bool animateIn;
  final VoidCallback onExited;
  final Widget child;

  @override
  State<_StripCell> createState() => _StripCellState();
}

class _StripCellState extends State<_StripCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: widget.animateIn ? 0 : 1,
  )..addStatusListener(_handleStatus);
  late final CurvedAnimation _size = CurvedAnimation(
    parent: _controller,
    curve: ExpressiveMotion.effects,
    reverseCurve: ExpressiveMotion.exit,
  );
  late final Animation<double> _scale = Tween<double>(begin: 0.6, end: 1)
      .animate(
        CurvedAnimation(
          parent: _controller,
          curve: ExpressiveMotion.spatial,
          reverseCurve: ExpressiveMotion.exit,
        ),
      );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    if (!_started) {
      _started = true;
      if (widget.leaving) {
        _controller.reverse();
      } else if (widget.animateIn) {
        _controller.forward();
      }
    }
  }

  @override
  void didUpdateWidget(covariant _StripCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.leaving != oldWidget.leaving) {
      if (widget.leaving) {
        _controller.reverse();
      } else {
        _controller.forward();
      }
    }
  }

  void _handleStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || !widget.leaving) return;
    // 减少动画时 reverse 在构建中同步结束，移除要等这一帧之后。
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.leaving) widget.onExited();
    });
  }

  @override
  void dispose() {
    _size.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: widget.leaving,
      child: SizeTransition(
        sizeFactor: _size,
        axis: Axis.horizontal,
        child: FadeTransition(
          opacity: _size,
          child: ScaleTransition(
            scale: _scale,
            child: SizedBox(width: widget.width, child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// 首格：空心圆加“+”，点按转到自定义页调一个新颜色；按下时以 spatial
/// 轻微缩小（与色块一致）。
class _CreateCell extends StatefulWidget {
  const _CreateCell({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_CreateCell> createState() => _CreateCellState();
}

class _CreateCellState extends State<_CreateCell> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = context.l10n.diaryColorPanelNewColor;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkResponse(
          onTap: widget.onTap,
          onHighlightChanged: (bool highlighted) {
            if (highlighted != _pressed) {
              setState(() => _pressed = highlighted);
            }
          },
          radius: 18,
          child: Center(
            child: AnimatedScale(
              scale: _pressed ? 0.88 : 1,
              duration: ExpressiveMotion.duration(
                context,
                ExpressiveMotion.fast,
              ),
              curve: ExpressiveMotion.spatial,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.outline, width: 1.2),
                ),
                child: SizedBox.square(
                  dimension: kDiaryColorSwatchSize,
                  child: Center(
                    child: FaIcon(
                      FontAwesomeIcons.plus,
                      size: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 末格：管理开关。平时是笔，管理中换成勾、衬 secondaryContainer 圆底，
/// 底色与图标色经 [ExpressiveStateBlend] 补间。
class _ManageToggle extends StatelessWidget {
  const _ManageToggle({required this.editing, required this.onTap});

  final bool editing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final label = editing
        ? l10n.diaryColorPanelManageDone
        : l10n.diaryColorPanelManageColors;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        toggled: editing,
        label: label,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap,
          radius: 18,
          child: Center(
            child: ExpressiveStateBlend(
              active: editing,
              builder: (BuildContext context, double t, Widget? child) {
                final ink = Color.lerp(
                  colors.onSurfaceVariant,
                  colors.onSecondaryContainer,
                  t,
                )!;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.secondaryContainer.withValues(alpha: t),
                  ),
                  child: SizedBox.square(
                    dimension: 32,
                    child: Center(
                      child: ExpressiveIconSwap(
                        switchKey: editing,
                        child: FaIcon(
                          editing
                              ? FontAwesomeIcons.check
                              : FontAwesomeIcons.pen,
                          size: 12,
                          color: ink,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _StripDivider extends StatelessWidget {
  const _StripDivider();

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 1,
      height: 20,
      child: ColoredBox(color: Theme.of(context).colorScheme.outlineVariant),
    ),
  );
}

/// 还没有任何颜色时的说明，起点对齐色块圆的左缘。
class _EmptyHint extends StatelessWidget {
  const _EmptyHint({super.key, required this.inset});

  final double inset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(start: inset, end: 4),
      child: Text(
        context.l10n.diaryColorPanelSavedEmpty,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          height: 1.3,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
