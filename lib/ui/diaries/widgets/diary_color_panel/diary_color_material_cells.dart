part of 'diary_color_material_page.dart';

// 色系页的两种格子：一页色阶（左右翻页的一页）与下方一行的色系圆点。

/// 色系圆点平时的直径：比色块小一圈，看得出它是“选色系”而不是直接上色。
const double _kFamilyDotSize = 20;

/// 选中环直径，与色块的选中环相同。
const double _kFamilyRingSize = 36;

/// 一个色系的全部色阶：按 [columns] 逐行靠起点排（两行各 7 格或一行 14 格），
/// 第一个强调色前隔一道竖线；没有强调色的色系（棕、蓝灰）只占前十格。
///
/// 色块复用 [DiaryColorSwatch]：选中环、背景目标的“A”、按下缩小与切换目标
/// 时的原地变色都与色板页一致。
class _ShadeGrid extends StatelessWidget {
  const _ShadeGrid({
    required this.family,
    required this.target,
    required this.current,
    required this.columns,
    required this.cellWidth,
    required this.onSelected,
  });

  final DiaryMaterialFamily family;
  final DiaryColorTarget target;
  final DiaryColorValue current;
  final int columns;
  final double cellWidth;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shades = family.shades;
    Widget cell(int index) {
      final shade = shades[index];
      final swatch = DiaryColorSwatch(
        color: shade.color,
        target: target,
        selected: current.matches(shade.color),
        label: family.shadeLabel(l10n, shade),
        onTap: () => onSelected(shade.color),
      );
      final startsAccents =
          shade.kind == DiaryMaterialShadeKind.accent &&
          index % columns != 0 &&
          shades[index - 1].kind != DiaryMaterialShadeKind.accent;
      if (!startsAccents) return swatch;
      return Stack(
        children: <Widget>[
          Positioned.fill(child: swatch),
          const PositionedDirectional(
            start: 0,
            top: 10,
            bottom: 10,
            child: _AccentDivider(),
          ),
        ],
      );
    }

    return Column(
      children: <Widget>[
        for (var start = 0; start < shades.length; start += columns)
          SizedBox(
            height: DiaryColorGridLayout.cellHeight,
            child: Row(
              children: <Widget>[
                for (
                  var index = start;
                  index < math.min(start + columns, shades.length);
                  index++
                )
                  SizedBox(width: cellWidth, child: cell(index)),
              ],
            ),
          ),
      ],
    );
  }
}

/// 色阶与强调色之间的竖线（1×20dp，与我的颜色一行的分隔同一规格）。
class _AccentDivider extends StatelessWidget {
  const _AccentDivider();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 1,
    child: ColoredBox(color: Theme.of(context).colorScheme.outlineVariant),
  );
}

/// 色系一行的一个圆点（500 色阶）：点按换到这个色系，不写正文。
///
/// 当前色系的圆点放大到色块大小并加 onSurface 外环（放大走 spatial，外环
/// 缩放淡入同色块的选中环）；按下时轻微缩小。两种目标下都画实心圆：这里
/// 选的是色系，不是要写进正文的颜色。
class _FamilyDot extends StatefulWidget {
  const _FamilyDot({
    required this.color,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  State<_FamilyDot> createState() => _FamilyDotState();
}

class _FamilyDotState extends State<_FamilyDot> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fast = ExpressiveMotion.duration(context, ExpressiveMotion.fast);
    final medium = ExpressiveMotion.duration(context, ExpressiveMotion.medium);
    final selected = widget.selected;
    final scale =
        (selected ? 1.0 : _kFamilyDotSize / kDiaryColorSwatchSize) *
        (_pressed ? 0.88 : 1.0);
    return Tooltip(
      message: widget.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: widget.label,
        excludeSemantics: true,
        child: InkResponse(
          onTap: widget.onTap,
          onHighlightChanged: (bool highlighted) {
            if (highlighted != _pressed) {
              setState(() => _pressed = highlighted);
            }
          },
          radius: _kFamilyRingSize / 2,
          child: Center(
            child: SizedBox.square(
              dimension: _kFamilyRingSize,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: fast,
                    curve: selected
                        ? ExpressiveMotion.effects
                        : ExpressiveMotion.exit,
                    child: AnimatedScale(
                      scale: selected ? 1 : 0.8,
                      duration: fast,
                      curve: selected
                          ? ExpressiveMotion.spatial
                          : ExpressiveMotion.exit,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.onSurface, width: 2),
                        ),
                        child: const SizedBox.square(
                          dimension: _kFamilyRingSize,
                        ),
                      ),
                    ),
                  ),
                  AnimatedScale(
                    scale: scale,
                    duration: _pressed ? fast : medium,
                    curve: ExpressiveMotion.spatial,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: widget.color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.outlineVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      child: const SizedBox.square(
                        dimension: kDiaryColorSwatchSize,
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
