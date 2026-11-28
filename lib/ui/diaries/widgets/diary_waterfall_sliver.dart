import 'package:flutter/widgets.dart';

import '../../../core/database/app_database.dart';
import '../../widgets/list_make_room.dart';

/// 日记瀑布流 sliver：输入有序日记与卡片构造器，输出带侧边距且位置稳定的
/// 瀑布流 sliver（底层为 `RenderStableMasonryGrid`）。
///
/// 不再通过换 key 销毁整棵瀑布流来清旧布局：
/// - 经 [itemKey] 与 `findChildIndexCallback` 按日记 id 复用存活卡片元素，
///   删改条目时未变卡片不卸载、不重建、不闪烁；
/// - 经 `itemKeys` 把稳定键列表交给渲染对象缓存实测高度并在视口上方删改时
///   保持锚点位置不跳动；
/// - 给了 [makeRoom] 时让位途中按 [MakeRoomSliverMasonryGrid] 画出预构建区并
///   按位移排序绘制。
class DiaryWaterfallSliver extends StatelessWidget {
  const DiaryWaterfallSliver({
    super.key,
    required this.diaries,
    required this.columns,
    required this.sideMargin,
    required this.cardGap,
    required this.itemBuilder,
    this.makeRoom,
  });

  /// 瀑布流卡片的稳定键：[itemBuilder] 返回的根节点应使用此键，以便 sliver
  /// 按日记 id 复用子元素。
  static ValueKey<String> itemKey(String diaryId) =>
      ValueKey<String>('waterfall_$diaryId');

  final List<DiaryWithTags> diaries;
  final int columns;
  final double sideMargin;
  final double cardGap;
  final IndexedWidgetBuilder itemBuilder;

  /// 列表让位（FLIP）的控制器；各项须由调用方包 [MakeRoomItem]。
  final MakeRoomController? makeRoom;

  @override
  Widget build(BuildContext context) {
    final itemKeys = <Object>[for (final item in diaries) item.diary.diaryId];
    final indexByKey = <String, int>{
      for (var i = 0; i < diaries.length; i++)
        'waterfall_${diaries[i].diary.diaryId}': i,
    };
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: sideMargin),
      sliver: MakeRoomSliverMasonryGrid.count(
        crossAxisCount: columns,
        mainAxisSpacing: cardGap,
        crossAxisSpacing: cardGap,
        childCount: diaries.length,
        itemKeys: itemKeys,
        findChildIndexCallback: (Key key) =>
            key is ValueKey<String> ? indexByKey[key.value] : null,
        itemBuilder: itemBuilder,
        makeRoom: makeRoom,
      ),
    );
  }
}
