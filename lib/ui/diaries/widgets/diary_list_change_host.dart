import 'package:flutter/widgets.dart';

import '../../../core/database/app_database.dart';
import '../../widgets/container_transform/morph_landing.dart';
import '../../widgets/list_change_host.dart';
import '../../widgets/list_make_room.dart';
import '../controllers/diary_list_switch_motion.dart';

/// 日记列表一次构建要排版的列表（见 [ListChangeFrame]）。
typedef DiaryListChangeFrame = ListChangeFrame<DiaryWithTags>;

/// 日记列表的数据变化动效：列表就在眼前换数据时（双栏里边写边存、同步、
/// 批量改标签、撤销……），卡片不再瞬间跳到新位置。
///
/// 移动、移除与插入的做法见通用的 [ListChangeHost]（按日记 id 对应同一项）；
/// 这里只补上日记列表自己不演的时候：列表整体切换途中（[switchMotion] 不在
/// 静止态，由它级联入场）与新建日记正落进列表（[MorphLandingSession]，由
/// 让位动画处理）。
class DiaryListChangeHost extends StatelessWidget {
  const DiaryListChangeHost({
    super.key,
    required this.diaries,
    required this.duration,
    required this.builder,
    this.pendingHideDiaryIds = const <String>{},
    this.appearingDiaryIds = const <String>{},
    this.hiddenDiaryIds = const <String>{},
    this.makeRoom,
    this.switchMotion,
  });

  final List<DiaryWithTags> diaries;

  /// 单项进出场的时长（与调用方的 `ListItemPresence` 一致）：退场项过了
  /// 这么久才拿掉。
  final Duration duration;
  final Set<String> pendingHideDiaryIds;
  final Set<String> appearingDiaryIds;

  /// 宿主刻意直接拿掉的日记：从列表里消失时不留退场项，只让位。
  final Set<String> hiddenDiaryIds;

  /// 宿主的让位控制器（日记页还用它演新建日记落进列表）；null 时自己建
  /// 一个。
  final MakeRoomController? makeRoom;
  final DiaryListSwitchMotion? switchMotion;
  final Widget Function(BuildContext context, DiaryListChangeFrame frame)
  builder;

  static String _idOf(DiaryWithTags diary) => diary.diary.diaryId;

  @override
  Widget build(BuildContext context) {
    final switchMotion = this.switchMotion;
    return ListChangeHost<DiaryWithTags>(
      items: diaries,
      keyOf: _idOf,
      duration: duration,
      pendingHideKeys: pendingHideDiaryIds,
      appearingKeys: appearingDiaryIds,
      hiddenKeys: hiddenDiaryIds,
      makeRoom: makeRoom,
      canAnimate: () =>
          (switchMotion?.isIdle ?? true) &&
          MorphLandingSession.current.value == null,
      builder: builder,
    );
  }
}
