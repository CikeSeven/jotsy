import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/app_breakpoints.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/expressive_motion.dart';
import '../../../../app/theme/seeded_theme_cache.dart';
import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/widgets/app_page_backdrop.dart';
import '../../../diaries/providers/diary_card_style_provider.dart';
import '../../../diaries/providers/diary_mood_palette_provider.dart';
import '../../../diaries/providers/diary_preview_style_provider.dart';
import '../../../diaries/sections/diaries_list_section.dart';
import '../../../diaries/sections/diary_head_section.dart';
import '../../../home/models/home_bar_style/home_bar_resolved_style.dart';
import '../../../home/models/home_bar_style/home_bar_style.dart';
import '../../../home/models/home_tab.dart';
import '../../../home/widgets/home_bar/home_chrome_scope.dart';
import '../../../home/widgets/home_bar/home_floating_bar.dart';
import '../../../home/widgets/home_bar/home_top_bar_surface.dart';
import '../../../widgets/bottom_nav.dart';
import '../../controllers/home_bar_style_editor_controller.dart';
import '../../widgets/style_editor/style_preview_background.dart';
import 'home_bar_style_preview_toolbar.dart';

/// 导航栏样式的实时预览：一个缩小的首页。
///
/// 输入：编辑控制器（当前样式含拖动中的草稿、栏的行为、预览明暗）与示例
/// 日记；输出：圆角画框里的“首页”——顶部 56dp 的日记页顶栏、可滚动的示例
/// 日记列表（真实的 [DiariesListSection]，套用用户当前的卡片样式），底部按
/// 材质画实色底栏 [BottomNav] 或悬浮的玻璃胶囊 [HomeFloatingBar]，以及新建
/// 按钮。无副作用：导航项点按只改预览里的选中项，新建按钮与卡片都不做事。
///
/// - 列表上下留出栏的高度，首尾两张卡片能完整露出，中间的内容可以滚到
///   玻璃栏下方，直接看到模糊与透出的效果；
/// - 画框内去掉系统内边距：预览不是全屏，底栏不该再避让手势条；
/// - 明暗与应用相反时，用设置里的种子色另装配一份主题（与卡片样式预览
///   同一份缓存），样式按预览主题的 ColorScheme 解析；
/// - 打开“指示器跟随滑动”时，点按导航项后指示器沿着一个补间的页面位置
///   滑过去，模拟左右滑动切换时的样子；关闭时只在选中变化时切换。
class HomeBarStylePreview extends ConsumerStatefulWidget {
  const HomeBarStylePreview({
    super.key,
    required this.controller,
    required this.samples,
    this.showToolbar = true,
    this.bottomPadding = 0,
  });

  final HomeBarStyleEditorController controller;
  final List<DiaryWithTags> samples;

  /// 是否在预览上方显示工具条（宽屏时由预览自己显示）。
  final bool showToolbar;

  /// 预览底部被选项面板圆角压住的高度；画框在它之上结束，底栏不被遮住。
  final double bottomPadding;

  @override
  ConsumerState<HomeBarStylePreview> createState() =>
      _HomeBarStylePreviewState();
}

class _HomeBarStylePreviewState extends ConsumerState<HomeBarStylePreview>
    with SingleTickerProviderStateMixin {
  /// 新建按钮在栏上方时与栏的距离、与右缘的距离（与首页一致）。
  static const double _fabGap = 10;
  static const double _fabEnd = 20;
  static const double _topBarHeight = 56;

  int _selected = 0;

  /// 指示器跟随滑动时的“页面位置”，从旧选中项补间到新选中项。
  late final AnimationController _position = AnimationController(
    vsync: this,
    upperBound: (HomeTab.values.length - 1).toDouble(),
  );

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index == _selected) {
      return;
    }
    setState(() => _selected = index);
    _position.animateTo(
      index.toDouble(),
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.long),
      curve: ExpressiveMotion.effects,
    );
  }

  ThemeData _themeFor(ThemeData appTheme, Brightness brightness) {
    if (brightness == appTheme.brightness) {
      return appTheme;
    }
    return SeededThemeCache.of(
      ref.watch(appThemeSeedColorProvider),
      brightness,
      reduceMotion: MediaQuery.disableAnimationsOf(context),
    );
  }

  /// 宽屏并排时手机画框的最大宽度。
  static const double _phoneFrameMaxWidth = 412;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final appTheme = Theme.of(context);
    final brightness = controller.previewBrightness ?? appTheme.brightness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.showToolbar)
          HomeBarStylePreviewToolbar(controller: controller),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 12 + widget.bottomPadding),
            child: Theme(
              data: _themeFor(appTheme, brightness),
              // 并排布局（宽屏）时预览仍是手机首页：样式塑造的是底栏 / 悬浮
              // 胶囊，宽窗口的侧边栏只借用实色与指示器颜色。画框最宽
              // [_phoneFrameMaxWidth] 并在预览栏里水平居中，高度照常铺满；
              // 窄屏（上下布局）不变。
              child: widget.showToolbar
                  ? CenteredContent(
                      maxWidth: _phoneFrameMaxWidth,
                      // 画框里的卡片列表按屏宽解析样式：把 MediaQuery 的尺寸
                      // 换成画框尺寸，卡片按手机宽度排版。
                      child: LayoutBuilder(
                        builder: (BuildContext context, BoxConstraints box) =>
                            MediaQuery(
                              data: MediaQuery.of(
                                context,
                              ).copyWith(size: box.biggest),
                              child: Builder(builder: _buildFrame),
                            ),
                      ),
                    )
                  : Builder(builder: _buildFrame),
            ),
          ),
        ),
      ],
    );
  }

  /// 画框与其中的“首页”；在预览主题之下构建，取到的是预览的配色。
  Widget _buildFrame(BuildContext context) {
    final controller = widget.controller;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final resolved = HomeBarResolvedStyle.resolve(
      controller.style,
      scheme,
      highContrast: MediaQuery.highContrastOf(context),
    );
    final behavior = controller.behavior;
    final items = <BottomNavItem>[
      for (final tab in HomeTab.values)
        BottomNavItem(label: tab.label(l10n), icon: tab.icon),
    ];
    final position = behavior.indicatorFollowsSwipe ? _position : null;
    final barExtent = resolved.isGlass
        ? resolved.barHeight + resolved.bottomGap
        : BottomNav.navHeight;
    final inline =
        resolved.isGlass && resolved.fabPlacement == HomeBarFabPlacement.inline;
    final radius = BorderRadius.circular(AppRadii.card);

    final bottomBar = resolved.isGlass
        ? Positioned(
            left: resolved.sideMargin,
            right: resolved.sideMargin,
            bottom: resolved.bottomGap,
            child: HomeFloatingBar(
              items: items,
              selectedIndex: _selected,
              onTap: _select,
              style: resolved,
              position: position,
              inlineAction: HomeInlineCreateButton(
                style: resolved,
                label: l10n.commonNew,
                onPressed: () {},
              ),
              showInlineAction: inline,
            ),
          )
        : Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomNav(
              items: items,
              selectedIndex: _selected,
              onTap: _select,
              style: resolved,
              position: position,
            ),
          );

    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          removeBottom: true,
          removeLeft: true,
          removeRight: true,
          child: HomeChromeScope(
            style: resolved,
            behavior: behavior,
            // 画框里就是首页的日记 Tab：日记页区域的背景铺满画框（在预览
            // 主题之内，明暗切换时遮罩随之切换），页面底与真实首页一样改读
            // AppPageBackdrop——画了背景时透明，玻璃栏与玻璃顶栏模糊到背景；
            // 没有背景时即预览主题的页面底色，与原来相同。
            child: StylePreviewBackground(
              child: Builder(
                builder: (BuildContext context) => _buildPage(
                  context,
                  barExtent: barExtent,
                  inline: inline,
                  bottomBar: bottomBar,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 画框里的“首页”：示例列表、顶栏、新建按钮与底栏。要在
  /// [StylePreviewBackground] 之下的 [context] 里构建，才能读到日记页区域的
  /// 页面底色。
  Widget _buildPage(
    BuildContext context, {
    required double barExtent,
    required bool inline,
    required Widget bottomBar,
  }) {
    final controller = widget.controller;
    final l10n = context.l10n;
    return Material(
      color: AppPageBackdrop.pageColorOf(context),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: _SampleList(
              samples: widget.samples,
              tagLimit: controller.settingsService.diaryCardTagLimit,
              topPadding: _topBarHeight + 10,
              bottomPadding: barExtent + 12,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _PreviewTopBar(title: HomeTab.diaries.label(l10n)),
          ),
          // 栏上方的新建按钮：实色与玻璃都有（与首页一致），位置随
          // 栏高变化；放在栏右侧时由悬浮栏自己画。
          if (!inline)
            Positioned(
              right: _fabEnd,
              bottom: barExtent + _fabGap,
              child: FloatingActionButton.extended(
                // 不参与 Hero：首页的新建按钮就在下层路由里。
                heroTag: null,
                onPressed: () {},
                icon: const FaIcon(FontAwesomeIcons.plus, size: 20),
                label: Text(l10n.commonNew),
              ),
            ),
          bottomBar,
        ],
      ),
    );
  }
}

/// 预览里的日记页顶栏：与 PageHeader 同样的标题字阶，底由
/// [HomeTopBarSurface] 按“顶栏也用玻璃”画实色或磨砂。
class _PreviewTopBar extends StatelessWidget {
  const _PreviewTopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HomeTopBarSurface(
      // 与真实日记页顶栏一样取区域的实色栏底色：无背景为 surface，图片
      // 背景时仍不透明，纯色背景时与背景同色。
      solidColor: AppPageBackdrop.solidBarColorOf(context),
      child: SizedBox(
        height: _HomeBarStylePreviewState._topBarHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 示例日记列表：真实的 [DiariesListSection]，套用用户当前的卡片样式与心情
/// 配置；上下留白让首尾卡片能从栏下露出来。卡片点按不做事，共享元素关闭，
/// 避免与下层首页列表的同名 Hero 冲突。
class _SampleList extends ConsumerWidget {
  const _SampleList({
    required this.samples,
    required this.tagLimit,
    required this.topPadding,
    required this.bottomPadding,
  });

  final List<DiaryWithTags> samples;
  final int tagLimit;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      primary: false,
      slivers: <Widget>[
        SliverToBoxAdapter(child: SizedBox(height: topPadding)),
        DiariesListSection(
          diaries: samples,
          layoutMode: DiaryLayoutMode.list,
          selectedDiaryIds: const <String>{},
          isSelectionMode: false,
          maxVisibleTags: tagLimit,
          onCreate: () {},
          onOpenEditor: (_, _) {},
          onToggleSelection: (_, _) {},
          cardStyle: ref.watch(diaryCardStyleProvider),
          moodPalette: ref.watch(diaryMoodPaletteProvider),
          enableCoverHero: false,
          opensLockedCapsulePage: false,
        ),
        SliverToBoxAdapter(child: SizedBox(height: bottomPadding)),
      ],
    );
  }
}
