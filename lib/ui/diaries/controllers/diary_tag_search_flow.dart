import 'package:flutter/widgets.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/database/diary_list_scope.dart';
import '../pages/diary_search_page.dart';

/// 点按一个标签：打开搜索页并选中这个标签（探索页的标签卡与周期回顾、预览页
/// 信息栏、日记本统计页“常用标签”共用）。
///
/// 日记本统计页传入这本的范围 [scope]（连同名称 [scopeLabel] 与图标
/// [scopeIcon]），搜索页里显示为可移除的日记本条件，与在日记本里点搜索一致；
/// 其余入口在全部日记中找，私密日记照常排除。搜索页自己维护筛选，进去后仍可
/// 增减标签、输入关键词，不影响首页的标签筛选。
Future<void> openDiaryTagSearch(
  BuildContext context,
  int tagId, {
  DiaryListScope scope = DiaryListScope.all,
  String? scopeLabel,
  FaIconData? scopeIcon,
}) {
  return Navigator.of(context).push(
    DiarySearchPage.buildRoute(
      initialTagIds: <int>{tagId},
      scope: scope,
      scopeLabel: scopeLabel,
      scopeIcon: scopeIcon,
    ),
  );
}
