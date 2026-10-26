part of 'calendar_page.dart';

/// 按页面可用宽度 [_CalendarPageLayout._buildCalendarLayout] 摆放日历页。
typedef _CalendarHeaderFactory =
    Widget Function(double collapsedExtent, double horizontalInset);
typedef _CalendarPanelFactory = Widget Function({required bool wide});

/// 日历页的三种摆放（页面装配的一部分）：
///
/// - 紧凑（< 600）：手机布局，单个 CustomScrollView，与改版前完全一致；
/// - 中等（600–1023）：同样单列，页头内容与所有区块居中到
///   [AppContentWidth.reading]（720）宽；
/// - 展开（≥ 1024）：页头横跨居中的 [AppContentWidth.grid]（1200）容器、
///   始终展开；其下左栏是日历卡片（月/周网格或年视图，宽
///   `clamp(可用宽 × 0.5, 440, 600)`），不随右栏滚动；右栏是独立的滚动
///   列表（选中日标题、纪念日、当天日记、那年今日，最宽 720）。左栏选日即
///   改页面状态，右栏随之重建。
///
/// 居中一律用滚动视图的左右内边距（[AppContentWidth.gutter] 的思路），
/// 滚动视图本身不收窄：滚动条留在窗口边缘，留白处的滚轮也能滚动内容。
extension _CalendarPageLayout on _CalendarPageState {
  /// 双栏时两栏之间、内容与窗口边缘的最小间距。
  static const double _columnGap = AppSpacing.m;

  Widget _buildCalendarLayout({
    required double width,
    required _CalendarHeaderFactory buildHeader,
    required _CalendarPanelFactory buildPanel,
    required List<Widget> daySlivers,
    required double bottomSpace,
  }) {
    final windowClass = AppBreakpoints.classOf(width);
    if (windowClass == AppWindowClass.expanded) {
      return _buildTwoColumnLayout(
        width: width,
        buildHeader: buildHeader,
        buildPanel: buildPanel,
        daySlivers: daySlivers,
        bottomSpace: bottomSpace,
      );
    }
    // 单列：区块各自带 16 的左右内边距，居中的是含内边距的 720 宽一列。
    final side = windowClass == AppWindowClass.compact
        ? 0.0
        : math.max(0.0, (width - AppContentWidth.reading) / 2);
    Widget centred(Widget sliver) => side == 0
        ? sliver
        : SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: side),
            sliver: sliver,
          );
    return CustomScrollView(
      slivers: <Widget>[
        // 页头固定在顶部，月份行随下滑收起、只留标题栏，见
        // CalendarHeaderSliver。底色铺满页宽，按钮行与下方一列对齐。
        CalendarHeaderSliver(
          builder: (_, double collapsedExtent) =>
              buildHeader(collapsedExtent, side),
        ),
        centred(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                _CalendarPageState._calendarCardHorizontalPadding,
                _CalendarPageState._calendarCardTopPadding,
                _CalendarPageState._calendarCardHorizontalPadding,
                _CalendarPageState._calendarBottomGap,
              ),
              child: buildPanel(wide: windowClass.isWide),
            ),
          ),
        ),
        for (final sliver in daySlivers) centred(sliver),
        SliverToBoxAdapter(child: SizedBox(height: bottomSpace)),
      ],
    );
  }

  /// 展开档的双栏。页头不放进滚动视图：两栏各自滚动，“下滑收起月份行”
  /// 无从对应，页头始终完整显示（月份行可见）。
  Widget _buildTwoColumnLayout({
    required double width,
    required _CalendarHeaderFactory buildHeader,
    required _CalendarPanelFactory buildPanel,
    required List<Widget> daySlivers,
    required double bottomSpace,
  }) {
    // 内容容器：最宽 1200 居中，窄于此时左右各留 16。
    final side = AppContentWidth.gutter(
      width,
      AppContentWidth.grid,
      minGutter: _columnGap,
    );
    final contentWidth = width - side * 2;
    // 取整：网格（table_calendar 的 PageView）宽度为整数，翻页不累积浮点误差。
    final leftWidth = (width * 0.5).clamp(440.0, 600.0).floorToDouble();
    // 右栏区块自带 16 的左右内边距：左侧那 16 正好是两栏间距，右侧那 16
    // 落在内容容器之内，故右栏滚动视图的右内边距要扣掉它。超出 720 的部分
    // 也并入右侧留白。
    final rightContent = math.min(
      contentWidth - leftWidth - _columnGap,
      AppContentWidth.reading - AppSpacing.m * 2,
    );
    final rightPadding =
        width - side - leftWidth - rightContent - AppSpacing.m * 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 页头的左右内边距本身是 16，再内缩到内容容器的左右边缘。
        buildHeader(0, side - AppSpacing.m),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                width: side + leftWidth,
                // 左栏一般放得下；窗口很矮时可单独滚动。不继承首页下发的
                // 主滚动控制器，那是右栏的（“点当前 Tab 回到顶部”）。
                child: SingleChildScrollView(
                  primary: false,
                  padding: EdgeInsets.fromLTRB(
                    side,
                    _CalendarPageState._calendarCardTopPadding,
                    0,
                    bottomSpace,
                  ),
                  child: buildPanel(wide: true),
                ),
              ),
              Expanded(
                child: CustomScrollView(
                  slivers: <Widget>[
                    const SliverToBoxAdapter(
                      child: SizedBox(
                        height: _CalendarPageState._calendarCardTopPadding,
                      ),
                    ),
                    for (final sliver in daySlivers)
                      SliverPadding(
                        padding: EdgeInsets.only(
                          right: math.max(0.0, rightPadding),
                        ),
                        sliver: sliver,
                      ),
                    SliverToBoxAdapter(child: SizedBox(height: bottomSpace)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
