import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../home/widgets/home_bar/home_top_bar_surface.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/form_width.dart';
import '../../widgets/page_header.dart';
import '../sections/settings_home_groups.dart';

// 设置首页有两种外壳，内容（[_SettingsGroupList]）相同，由导航栏样式里的
// “设置入口”决定用哪一种（`HomeBarBehavior.settingsPlacement`）：
// - 导航栏（默认）：首页末尾的“设置”Tab，[SettingsPage]，PageHeader 叠在
//   列表上，背景由首页按 Tab 区域画；
// - 日记页“更多”菜单：[openSettingsPage] 推入 [SettingsRoutePage]，标准
//   顶栏带返回键，自己画设置区域的背景。

/// 打开设置首页（设置入口在日记页“更多”菜单时）：日记页菜单与 AI 助手的
/// “前往设置”都经这里。
Future<void> openSettingsPage(BuildContext context) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const SettingsRoutePage(),
      ),
    );

/// 设置首页（首页的“设置”Tab，排在导航栏末尾）：按语义分成通用、写日记、
/// 整理、数据与安全四组，末尾一组为 AI 助手与关于（DESIGN.md §5.3）。这里只
/// 放进入二级页的导航行，具体设置都在各自的二级页里；分组内容见
/// `settings_home_groups.dart`。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 顶栏下缘看得见时（首页下顶栏恒为玻璃，或设置区域有背景、实色栏与
    // 透明页面底分开），第一组紧贴它显得挤：留出各 Tab 统一的顶部间距，与
    // 探索页、日历页、日记页第一块内容离顶栏一样远。
    final topContentGap = HomeTopBarSurface.contentGapOf(context);
    final headerHeight =
        MediaQuery.paddingOf(context).top + PageHeader.contentHeight;
    // 底栏悬浮在内容之上，底部 padding 是底栏槽位高度：列表滚到胶囊下方，
    // 末尾多留这一段让最后一项完整露出。
    final listBottomPadding = 8.0 + MediaQuery.paddingOf(context).bottom;

    return Stack(
      children: <Widget>[
        // 设置区域设了背景时页面底透明，露出首页画的背景（见
        // AppPagedBackground）。
        Positioned.fill(
          child: ColoredBox(color: AppPageBackdrop.pageColorOf(context)),
        ),
        _SettingsGroupList(
          top: headerHeight + topContentGap,
          bottom: listBottomPadding,
        ),
        // 页头不随 720 的分组列内收：首页各 Tab 的标题在任何宽度下都距
        // 左缘 16，切换 Tab 时停在同一位置（#308）。
        PageHeader(title: context.l10n.settingsTitle),
      ],
    );
  }
}

/// 推入的设置首页（设置入口在日记页“更多”菜单时）：标准顶栏 + 返回键，
/// 内容与 [SettingsPage] 相同。
class SettingsRoutePage extends StatelessWidget {
  const SettingsRoutePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // 设置区域的背景画在 Scaffold 外面；页面底色经 Builder 从背景组件之下
    // 读（有背景时透明，没有时就是原来的页面底色）。
    return AppPageBackground(
      area: AppBackgroundArea.settings,
      child: Builder(
        builder: (BuildContext context) => Scaffold(
          backgroundColor: AppPageBackdrop.pageColorOf(context),
          appBar: AppTopBar(
            contentMaxWidth: FormWidth.maxWidth,
            title: Text(l10n.settingsTitle),
            leading: IconButton(
              tooltip: l10n.commonBack,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
            ),
          ),
          // 底部让出系统手势条，最后一组完整露出。
          body: Builder(
            builder: (BuildContext context) => _SettingsGroupList(
              top: 12,
              bottom: 24 + MediaQuery.paddingOf(context).bottom,
            ),
          ),
        ),
      ),
    );
  }
}

/// 设置首页的分组列表（两种外壳共用），[top] / [bottom] 为列表首尾的留白。
class _SettingsGroupList extends StatelessWidget {
  const _SettingsGroupList({required this.top, required this.bottom});

  /// 分组之间的距离，与各二级页分组之间一致。
  static const double _groupGap = 16;

  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    // 宽窗口：分组保持一列、最宽 720 并居中（分组自带左右 16，列表再补齐
    // 其余留白）；手机上补的留白为 0。
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final side = FormWidth.extra(constraints.maxWidth);
        return ListView(
          padding: EdgeInsets.fromLTRB(side, top, side, bottom),
          children: const <Widget>[
            SettingsGeneralGroup(),
            SizedBox(height: _groupGap),
            SettingsWritingGroup(),
            SizedBox(height: _groupGap),
            SettingsOrganizeGroup(),
            SizedBox(height: _groupGap),
            SettingsDataSecurityGroup(),
            SizedBox(height: _groupGap),
            SettingsMoreGroup(),
          ],
        );
      },
    );
  }
}
