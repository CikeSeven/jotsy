part of 'diary_color_panel.dart';

/// 标题让位成图标时，图标占的宽度。
const double _kTitleIconSize = 16;

/// 颜色面板的表头（40dp）：左侧目标标题，右侧色板 / 色系 / 自定义页签。
///
/// 排布优先级：
/// - 页签按标签自身宽度完整显示（缩小的页签字小、按钮也矮，不好点）；
/// - 标题放得下就写全（沿用工具栏按钮名“文字颜色 / 背景颜色”），放不下
///   （窄屏英文）就换成工具栏上同一个按钮的图标（调色盘 / 荧光笔），名称
///   留给长按提示与读屏，不显示半截的省略文字；
/// - 连图标都放不下时（超大字号）页签整体缩小，不溢出表头；
/// - 标题与图标的起点都对齐第一个色块圆的左缘；切换目标或在文字与图标之间
///   切换时交叉淡入。
class _DiaryColorPanelHeader extends StatelessWidget {
  const _DiaryColorPanelHeader({
    required this.target,
    required this.mode,
    required this.columns,
    required this.onModeChanged,
  });

  final DiaryColorTarget target;
  final DiaryColorPanelMode mode;
  final int columns;
  final ValueChanged<DiaryColorPanelMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final width = constraints.maxWidth;
        // 与色块网格同一列宽（可用宽度 / 列数），色块在格子里居中。
        final inset = (width / columns - kDiaryColorSwatchSize) / 2;
        const gap = 8.0;
        return Row(
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.only(start: inset),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) =>
                      _buildTitle(context, constraints.maxWidth),
                ),
              ),
            ),
            const SizedBox(width: gap),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: math.max(0, width - inset - _kTitleIconSize - gap),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerEnd,
                child: _buildTabs(context),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTitle(BuildContext context, double available) {
    final colors = Theme.of(context).colorScheme;
    final title = _targetItem.label(context.l10n);
    final style = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: colors.onSurface,
    );
    final fits = _textWidth(context, title, style) <= available;
    return AnimatedSwitcher(
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
      switchInCurve: ExpressiveMotion.effects,
      switchOutCurve: ExpressiveMotion.exit,
      layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
        alignment: AlignmentDirectional.centerStart,
        children: <Widget>[...previous, ?current],
      ),
      child: fits
          ? Text(
              title,
              key: ValueKey<(DiaryColorTarget, bool)>((target, true)),
              maxLines: 1,
              softWrap: false,
              style: style,
            )
          : Tooltip(
              key: ValueKey<(DiaryColorTarget, bool)>((target, false)),
              message: title,
              child: Semantics(
                label: title,
                excludeSemantics: true,
                child: FaIcon(
                  _targetItem.iconData,
                  size: _kTitleIconSize,
                  color: colors.onSurface,
                ),
              ),
            ),
    );
  }

  Widget _buildTabs(BuildContext context) {
    final l10n = context.l10n;
    Widget label(String text) => Text(text, maxLines: 1);
    return ExpressiveButtonGroup<DiaryColorPanelMode>(
      dense: true,
      segments: <ButtonSegment<DiaryColorPanelMode>>[
        ButtonSegment<DiaryColorPanelMode>(
          value: DiaryColorPanelMode.swatches,
          label: label(l10n.diaryColorPanelSwatches),
        ),
        ButtonSegment<DiaryColorPanelMode>(
          value: DiaryColorPanelMode.material,
          label: label(l10n.diaryColorPanelMaterial),
        ),
        ButtonSegment<DiaryColorPanelMode>(
          value: DiaryColorPanelMode.custom,
          label: label(l10n.diaryColorPanelCustom),
        ),
      ],
      selected: <DiaryColorPanelMode>{mode},
      onSelectionChanged: (Set<DiaryColorPanelMode> selection) =>
          onModeChanged(selection.single),
    );
  }

  /// 标题按实际字体与字号排出来的宽度（与 Text 同样合并 DefaultTextStyle、
  /// 跟随系统字号缩放）。
  static double _textWidth(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  /// 标题与图标沿用工具栏上对应按钮（文字颜色 / 背景颜色）。
  DiaryToolbarItem get _targetItem => switch (target) {
    DiaryColorTarget.text => DiaryToolbarItem.textColor,
    DiaryColorTarget.background => DiaryToolbarItem.backgroundColor,
  };
}
