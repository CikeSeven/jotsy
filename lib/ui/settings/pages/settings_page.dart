import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/form_width.dart';
import '../sections/settings_home_groups.dart';

/// 打开设置首页：日记页顶栏“更多 → 设置”与 AI 助手的“前往设置”都经这里。
Future<void> openSettingsPage(BuildContext context) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const SettingsPage(),
      ),
    );

/// 设置首页（从日记页顶栏“更多”推入的二级页）：按语义分成通用、写日记、
/// 整理、数据与安全四组，末尾一组为 AI 助手与关于（DESIGN.md §5.3）。这里只
/// 放进入二级页的导航行，具体设置都在各自的二级页里；分组内容见
/// `settings_home_groups.dart`。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  /// 分组之间的距离，与各二级页分组之间一致。
  static const double _groupGap = 16;

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
          // 宽窗口：分组保持一列、最宽 720 并居中（分组自带左右 16，列表再
          // 补齐其余留白）；手机上补的留白为 0。底部再让出系统手势条，最后
          // 一组完整露出。
          body: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final side = FormWidth.extra(constraints.maxWidth);
              return ListView(
                padding: EdgeInsets.fromLTRB(
                  side,
                  12,
                  side,
                  24 + MediaQuery.paddingOf(context).bottom,
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
        ),
      ),
    );
  }
}
