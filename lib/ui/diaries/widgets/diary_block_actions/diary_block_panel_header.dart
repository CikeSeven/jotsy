import 'package:flutter/material.dart';

/// 段落操作栏面板的表头高度（含与下方内容的间距）：与表格、代码块、列表
/// 面板的表头同高。
const double kDiaryBlockPanelHeaderHeight = 40 + 4;

/// 段落操作栏面板的表头：标题字号与字重同表格、代码块、列表面板。
class DiaryBlockPanelHeader extends StatelessWidget {
  const DiaryBlockPanelHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 4, bottom: 4),
    child: SizedBox(
      height: 40,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    ),
  );
}
