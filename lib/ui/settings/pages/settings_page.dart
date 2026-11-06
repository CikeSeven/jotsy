import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../app_surface/widgets/app_page_backdrop.dart';
import '../../home/widgets/home_bar/home_top_bar_surface.dart';
import '../../widgets/form_width.dart';
import '../../widgets/page_header.dart';
import '../sections/settings_home_groups.dart';

/// 设置首页（首页的“设置”Tab）：按语义分成通用、写日记、整理、数据与安全
/// 四组，末尾一组为 AI 助手与关于（DESIGN.md §5.3）。这里只放进入二级页的
/// 导航行，具体设置都在各自的二级页里；分组内容见 `settings_home_groups.dart`。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.pageBackgroundColor});

  final Color? pageBackgroundColor;

  /// 分组之间的距离，与各二级页分组之间一致。
  static const double _groupGap = 16;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // 顶栏下缘看得见时（玻璃顶栏，或设置区域有背景、实色栏与透明页面底
    // 分开），第一组紧贴它显得挤：留出四个 Tab 统一的顶部间距，与探索
    // 页、日历页、日记页第一块内容离顶栏一样远。经典且无背景时栏与页面
    // 同色、下缘看不出来，不留，与改版前一致。
    final topContentGap = HomeTopBarSurface.contentGapOf(context);
    final headerHeight =
        MediaQuery.paddingOf(context).top + PageHeader.contentHeight;
    // 玻璃底栏悬浮在内容之上时，底部 padding 是底栏槽位高度（实色时为 0）：
    // 列表滚到胶囊下方，末尾多留这一段让最后一项完整露出。
    final listBottomPadding = 8.0 + MediaQuery.paddingOf(context).bottom;
    // 设置区域设了背景时页面底透明，露出首页画的背景（见 AppPagedBackground）。
    final pageBgColor =
        pageBackgroundColor ?? AppPageBackdrop.pageColorOf(context);

    return Stack(
      children: <Widget>[
        Positioned.fill(child: ColoredBox(color: pageBgColor)),
        // 宽窗口：分组保持一列、最宽 720 并居中（分组自带左右 16，列表再
        // 补齐其余留白）；手机上补的留白为 0。
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final side = FormWidth.extra(constraints.maxWidth);
            return ListView(
              padding: EdgeInsets.only(
                left: side,
                top: headerHeight + topContentGap,
                right: side,
                bottom: listBottomPadding,
              ),
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
        ),
        PageHeader(
          title: l10n.settingsTitle,
          contentMaxWidth: FormWidth.maxWidth,
        ),
      ],
    );
  }
}
