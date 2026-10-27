part of 'home_page.dart';

/// 首页的底栏 / 侧边栏与“新建”入口（全局 FAB / 玻璃底栏并排按钮 / 侧边栏
/// 顶部按钮）的组装。
///
/// 只负责按 [HomeBarResolvedStyle] 与首页状态拼出 widget，状态（当前 Tab、
/// 切页中、滚动隐藏、提示可见）都由 [_HomePageState] 持有与更新。
extension _HomePageChrome on _HomePageState {
  /// Scaffold.bottomNavigationBar 槽位：实色贴底栏或玻璃悬浮胶囊。
  Widget _buildBottomBar({
    required List<BottomNavItem> navItems,
    required HomeBarResolvedStyle barStyle,
    required HomeBarBehavior barBehavior,
    required bool inlineCreate,
  }) {
    return HomeBottomBar(
      items: navItems,
      selectedIndex: _effectiveIndex,
      onTap: _controller.onTap,
      style: barStyle,
      position: barBehavior.indicatorFollowsSwipe ? _pagePosition : null,
      inlineAction: inlineCreate ? _buildInlineCreateButton(barStyle) : null,
      // 并排按钮与 FAB 一样只属于日记页（按目标 Tab，点击即生效），但不跟随
      // 日记列表的滚动显隐：它在底栏里，不会挡住列表末尾。
      showInlineAction: _effectiveTab == HomeTab.diaries,
      hidden: _barHiddenByScroll,
    );
  }

  /// 宽窗口的 Scaffold.body：侧边栏 + 页面区。
  ///
  /// 页面区 [content] 是挂着 GlobalKey 的同一棵子树（见 `_buildHomeShell`），
  /// 外面再包切页入场 [HomeTabEntrance]，并去掉侧边栏已经避让过的那一侧
  /// 系统内边距（横屏刘海等），各 Tab 不再重复留白。Row 在从右到左的语言
  /// 下自动把侧边栏放到右侧。
  Widget _buildWideBody({
    required List<BottomNavItem> navItems,
    required HomeBarResolvedStyle barStyle,
    required Widget content,
  }) {
    final ltr = Directionality.of(context) == TextDirection.ltr;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        HomeNavRail(
          items: navItems,
          selectedIndex: _effectiveIndex,
          onTap: _controller.onTap,
          style: barStyle,
          leading: _buildRailCreateButton(),
        ),
        Expanded(
          // Builder 取 Scaffold.body 这一层的 MediaQuery（而不是首页外层的）。
          child: Builder(
            builder: (context) => MediaQuery.removePadding(
              context: context,
              removeLeft: ltr,
              removeRight: !ltr,
              child: HomeTabEntrance(
                generation: _wideEntranceGeneration,
                color: _wideEntranceCoverColor(context),
                child: content,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 宽窗口切页入场的盖层颜色（见 [HomeTabEntrance]）。
  ///
  /// 盖层模拟“内容在页面底色上淡入”：目标 Tab 没有背景时就是原来的页面
  /// 底色；有背景时页面底下是背景层（随切页交叉淡入），一块纯色盖层会在
  /// 图片上闪出一个色块，改为透明——此时只有轻微放大，淡入交给背景层。
  Color _wideEntranceCoverColor(BuildContext context) {
    final backdrop = AppPageBackdrop.of(context);
    return backdrop.hasBackground
        ? Colors.transparent
        : Theme.of(context).colorScheme.surface;
  }

  /// 侧边栏顶部的新建按钮：文字（提示）与全局 FAB 相同，在任何 Tab 都可用。
  ///
  /// “控件”为玻璃时按钮是玻璃（见 [HomeNavRailCreateButton]），启动入场
  /// 改经 [LaunchReveal.builder] + [GlassReveal]，不放进透明度层。
  Widget _buildRailCreateButton() {
    final button = Consumer(
      builder: (context, ref, _) => HomeNavRailCreateButton(
        label: _createLabel(context, ref),
        onPressed: () {
          unawaited(_openCreate());
        },
      ),
    );
    if (AppGlass.of(context).isGlass(AppGlassComponent.controls)) {
      return LaunchReveal.builder(
        slot: LaunchRevealSlot.action,
        builder: (BuildContext context, double opacity, Widget? child) =>
            GlassReveal(progress: opacity, child: child!),
        child: button,
      );
    }
    return LaunchReveal(slot: LaunchRevealSlot.action, child: button);
  }

  /// 玻璃底栏右侧的并排新建按钮；文字与全局 FAB 相同，只作提示与读屏。
  /// 按钮是实色的，可以放进 LaunchReveal 的 Opacity，按 action 槽位弹出。
  Widget _buildInlineCreateButton(HomeBarResolvedStyle barStyle) {
    return IgnorePointer(
      // 切页动画途中不响应，与全局 FAB 一致。
      ignoring: !_canUseGlobalCreateFab,
      child: LaunchReveal(
        slot: LaunchRevealSlot.action,
        child: Consumer(
          builder: (context, ref, _) => HomeInlineCreateButton(
            style: barStyle,
            label: _createLabel(context, ref),
            onPressed: () {
              unawaited(_openCreateFromGlobalFab());
            },
          ),
        ),
      ),
    );
  }

  /// 新建入口的文字随日记页的范围变化：在普通日记本里为“写进「旅行」”，
  /// 新建的日记预先收进这本；其余为“新建”。
  String _createLabel(BuildContext context, WidgetRef ref) {
    final notebook = ref.watch(homeNotebookScopeResolutionProvider).notebook;
    return notebook != null && notebook.isManual
        ? context.l10n.notebookWriteInto(shortNotebookName(notebook.name))
        : context.l10n.commonNew;
  }

  /// “新建”FAB 只属于日记页：日历页的日期长按菜单已能在任意一天写日记或
  /// 时间胶囊，再叠一个 FAB 会挡住当天日记列表的末尾。
  ///
  /// 实色底栏时 body 止于底栏上沿，FAB 按原样离底栏 10dp；玻璃底栏时 body
  /// 延伸到屏幕底部，再加上悬浮槽位的高度（胶囊 + 底部间距 + 手势条），
  /// 让 FAB 仍在胶囊上方 10dp；底栏被滚动收起时落到手势条上方 10dp。
  /// 提示出现时的上移量在此之上照旧计算（提示同样排在底栏槽位上方）。
  Widget _buildGlobalCreateFab(HomeBarResolvedStyle barStyle) {
    final shouldShow =
        _effectiveTab == HomeTab.diaries && _diariesFabVisibleByScroll;
    final fabBaseBottomOffset = _HomePageState._fabBottomGapAboveNav;
    final navOffset = !barStyle.isGlass
        ? 0.0
        : _barHiddenByScroll
        ? MediaQuery.viewPaddingOf(context).bottom
        : HomeBottomBar.floatingSlotExtent(context, barStyle);

    final hintExtent = HomeHintVisibilityScope.maybeController(
      context,
    )?.hintExtentNotifier;
    // “控件”为玻璃时换成主色玻璃 FAB（见 [_buildGlassFabReveal]）。
    final glassFab = AppGlass.of(context).isGlass(AppGlassComponent.controls);
    // 只有按钮文字随日记页的范围变化：在普通日记本里为“写进「旅行」”，
    // 新建的日记预先收进这本。
    final button = Consumer(
      builder: (context, ref, _) {
        return FloatingActionButton.extended(
          onPressed: () {
            unawaited(_openCreateFromGlobalFab());
          },
          icon: const FaIcon(FontAwesomeIcons.plus, size: 20),
          label: Text(
            _createLabel(context, ref),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable?>[
        widget.homeHintVisibleListenable,
        hintExtent,
      ]),
      builder: (context, child) {
        final homeHintVisible = widget.homeHintVisibleListenable.value;
        // 上移量取“实测提示高度 + 间隙”与默认值的较大者：双行提示或大字号
        // 时 SnackBar 更高，固定 60dp 会让 FAB 压在提示上。
        final measuredLift =
            (hintExtent?.value ?? 0) +
            _HomePageState._fabGapAboveHint -
            fabBaseBottomOffset;
        final fabBottomOffset =
            navOffset +
            fabBaseBottomOffset +
            (homeHintVisible
                ? math.max(
                    _HomePageState._fabLiftOffsetWhenHintVisible,
                    measuredLift,
                  )
                : 0);
        return AnimatedPositioned(
          duration: ExpressiveMotion.duration(
            context,
            _HomePageState._fabLiftDuration,
          ),
          curve: _HomePageState._fabLiftCurve,
          right: AppSpacing.xl,
          bottom: fabBottomOffset,
          child: IgnorePointer(
            ignoring: !shouldShow || !_canUseGlobalCreateFab,
            child: AnimatedSlide(
              duration: ExpressiveMotion.duration(
                context,
                _HomePageState._fabVisibilityDuration,
              ),
              curve: ExpressiveMotion.spatial,
              offset: shouldShow ? Offset.zero : const Offset(0, 1.6),
              child: glassFab
                  ? _buildGlassFabReveal(context, shouldShow, button)
                  : AnimatedOpacity(
                      duration: ExpressiveMotion.duration(
                        context,
                        _HomePageState._fabVisibilityDuration,
                      ),
                      curve: _HomePageState._fabVisibilityCurve,
                      opacity: shouldShow ? 1 : 0,
                      child: LaunchReveal(
                        slot: LaunchRevealSlot.action,
                        child: button,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  /// 玻璃 FAB 的显隐与启动入场。
  ///
  /// 经典 FAB 的两层透明度（显隐的 AnimatedOpacity、启动编排的
  /// LaunchReveal）在玻璃时都不能用：背景模糊放进透明度层后只能采到层
  /// 自己，淡入途中先露出没有模糊的底、结束时模糊“啪”地出现。改为两层
  /// [GlassReveal]：显隐由 TweenAnimationBuilder 按同样的时长与曲线补间
  /// 进度，入场取 [LaunchReveal.builder] 给出的不透明度（位移与缩放照旧由
  /// 它负责），两者相乘后由玻璃表面自己缩放底色、描边、投影与模糊，并把
  /// 按钮内容放进玻璃里面的透明度层一起淡入。
  Widget _buildGlassFabReveal(
    BuildContext context,
    bool shouldShow,
    Widget button,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: shouldShow ? 1 : 0),
      duration: ExpressiveMotion.duration(
        context,
        _HomePageState._fabVisibilityDuration,
      ),
      curve: _HomePageState._fabVisibilityCurve,
      builder: (BuildContext context, double visibility, Widget? child) =>
          GlassReveal(progress: visibility, child: child!),
      child: LaunchReveal.builder(
        slot: LaunchRevealSlot.action,
        builder: (BuildContext context, double opacity, Widget? child) =>
            GlassReveal(
              progress: opacity,
              // 浮在日记列表上：总是模糊下面的卡片。
              child: AppGlassFab(child: child!),
            ),
        child: button,
      ),
    );
  }
}
