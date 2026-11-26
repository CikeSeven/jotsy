part of 'calendar_page.dart';

/// 按页面可用宽度 [_CalendarPageLayout._buildCalendarLayout] 摆放日历页。
typedef _CalendarHeaderFactory =
    CalendarHeader Function({required bool showArrows});
typedef _CalendarPanelFactory =
    Widget Function({required bool wide, required bool headerArrows});

/// 日历页的三种摆放（页面装配的一部分）：
///
/// - 紧凑（< 600）：手机布局，单个 CustomScrollView；
/// - 中等（600–1023）：同样单列，所有区块居中到 [AppContentWidth.reading]
///   （720）宽；
/// - 展开（≥ 1024）：内容容器居中到 [AppContentWidth.grid]（1200）；
///   左栏是日历卡片（月/周网格或年视图，宽 `clamp(可用宽 × 0.5, 440, 600)`），
///   不随右栏滚动；右栏是独立的滚动列表（选中日标题、纪念日、当天日记、
///   那年今日，最宽 720）。左栏选日即改页面状态，右栏随之重建。
///
/// 页头（[CalendarHeader]，与其他 Tab 同一个 [PageHeader]）叠在内容之上：
/// 内容从它下面滚过（玻璃顶栏时透出并被模糊），滚动视图顶部留出页头高度。
/// 标题栏铺满页宽、距左右 16，不随内容列内收：与日记、待办、探索的页头
/// 标题停在同一位置，切换 Tab 不跳（#308）。
///
/// 翻月箭头只在宽窗口与桌面放进页头；手机上靠左右滑网格，年视图没有滑动，
/// 由年视图自己在着色依据两侧放上一年 / 下一年（[_CalendarPanelFactory] 的
/// `headerArrows`）。
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
    final headerArrows = windowClass.isWide || AppPlatform.isDesktop;
    final headerHeight =
        MediaQuery.paddingOf(context).top + CalendarHeader.height;
    final Widget body;
    if (windowClass == AppWindowClass.expanded) {
      body = _buildTwoColumnLayout(
        width: width,
        topSpace: headerHeight,
        buildPanel: buildPanel,
        daySlivers: daySlivers,
        bottomSpace: bottomSpace,
      );
    } else {
      // 单列：区块各自带左右内边距，居中的是含内边距的 720 宽一列。
      final side = windowClass == AppWindowClass.compact
          ? 0.0
          : math.max(0.0, (width - AppContentWidth.reading) / 2);
      Widget centred(Widget sliver) => side == 0
          ? sliver
          : SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: side),
              sliver: sliver,
            );
      body = CustomScrollView(
        slivers: <Widget>[
          centred(
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  _CalendarPageState._calendarCardHorizontalPadding,
                  headerHeight + _CalendarPageState._calendarCardTopPadding,
                  _CalendarPageState._calendarCardHorizontalPadding,
                  _CalendarPageState._calendarBottomGap,
                ),
                child: buildPanel(
                  wide: windowClass.isWide,
                  headerArrows: headerArrows,
                ),
              ),
            ),
          ),
          for (final sliver in daySlivers) centred(sliver),
          SliverToBoxAdapter(child: SizedBox(height: bottomSpace)),
        ],
      );
    }
    return Stack(
      children: <Widget>[
        Positioned.fill(child: body),
        buildHeader(showArrows: headerArrows),
      ],
    );
  }

  /// 展开档的双栏：两栏各自滚动，顶部都让出页头高度，选中日标题与左栏
  /// 卡片顶端对齐。
  Widget _buildTwoColumnLayout({
    required double width,
    required double topSpace,
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
    // 右栏区块自带 12 的左右内边距：左侧那 12 是两栏间距的一部分，右侧那
    // 12 落在内容容器之内，故右栏滚动视图的右内边距要扣掉它。超出 720 的
    // 部分也并入右侧留白。
    final rightContent = math.min(
      contentWidth - leftWidth - _columnGap,
      AppContentWidth.reading - AppSpacing.m * 2,
    );
    final rightPadding =
        width - side - leftWidth - rightContent - AppSpacing.m * 2;
    final top = topSpace + _CalendarPageState._calendarCardTopPadding;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 左栏一般放得下；窗口很矮时可单独滚动。不继承首页下发的主滚动
        // 控制器，那是右栏的（“点当前 Tab 回到顶部”）。
        SizedBox(
          width: side + leftWidth,
          child: SingleChildScrollView(
            primary: false,
            padding: EdgeInsets.fromLTRB(side, top, 0, bottomSpace),
            child: buildPanel(wide: true, headerArrows: true),
          ),
        ),
        Expanded(
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(child: SizedBox(height: top)),
              for (final sliver in daySlivers)
                SliverPadding(
                  padding: EdgeInsets.only(right: math.max(0.0, rightPadding)),
                  sliver: sliver,
                ),
              SliverToBoxAdapter(child: SizedBox(height: bottomSpace)),
            ],
          ),
        ),
      ],
    );
  }
}
