import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/services/app_platform.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/empty_hint.dart';
import '../diary_preview/diary_preview_host.dart';
import '../diary_preview/diary_preview_neighbors.dart';
import '../diary_preview/diary_preview_view.dart';

/// 宽窗口日记页（双栏）的右栏：阅读左栏选中的一篇，没有选中时提示去选。
///
/// 输入：选中的日记 [diary]（null 为没有选中）、交给嵌入预览的宿主 [host]
/// 与列表里的位置 [paging]（上一篇 / 下一篇在列表里换选）；输出：上、右、
/// 下各留 12、圆角 24、1dp `outlineVariant` 描边并裁切的面板。没有副作用，
/// 选中状态与删除后的去向都由日记页决定。
///
/// 面板里的预览按面板自己的尺寸排版：外包一层只改 `size` 的 [MediaQuery]，
/// 预览里按屏宽 / 屏高推算的版式（正文边距与限宽、头图最高为屏高的 70%）
/// 就以面板为“屏幕”。推入的页面、底部面板与对话框是别的路由，不受影响。
class DiaryDetailPane extends StatelessWidget {
  const DiaryDetailPane({
    super.key,
    required this.diary,
    required this.host,
    this.paging,
  });

  /// 面板外边距：左侧为 0，与左栏之间靠左栏自己的边距隔开。
  static const EdgeInsets margin = EdgeInsets.fromLTRB(0, 12, 12, 12);
  static const double radius = 24;

  final DiaryWithTags? diary;
  final DiaryPreviewHost host;
  final DiaryPreviewPaging? paging;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(radius);
    final diary = this.diary;
    return SafeArea(
      left: false,
      bottom: false,
      child: Padding(
        padding: margin,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: borderRadius),
          // 描边画在内容之上：预览的纸色铺满面板时也看得见边界。
          foregroundDecoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: diary == null
              ? const _DiaryDetailPaneEmpty()
              : LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    return MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(size: constraints.biggest),
                      child: DiaryPreviewView(
                        // 换选即换一篇：控制器、滚动位置与导出状态都从头开始。
                        key: ValueKey<String>(diary.diary.diaryId),
                        diaryId: diary.diary.diaryId,
                        initialDetail: diary,
                        paging: paging,
                        host: host,
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

/// 没有选中时的提示；桌面端多一行新建快捷键（macOS 为 ⌘N）。
class _DiaryDetailPaneEmpty extends StatelessWidget {
  const _DiaryDetailPaneEmpty();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final message = AppPlatform.isDesktop
        ? '${l10n.diaryDetailPaneEmpty}\n'
              '${l10n.diaryDetailPaneCreateHint(AppPlatform.isMacOS ? '⌘N' : 'Ctrl+N')}'
        : l10n.diaryDetailPaneEmpty;
    return EmptyHint(icon: FontAwesomeIcons.bookOpen, message: message);
  }
}
