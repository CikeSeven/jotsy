import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart'
    show kDiaryVideoWidthKey;

import 'diary_editor_controller.dart';

/// 视频菜单（`diaryVideoMenuItems`）里只属于视频的写入：调整宽度。小图切换
/// 与删除与图片同一实现（`DiaryImageEmbedActions.setThumbnail` / `remove`，
/// 只看节点、不看类型）。
abstract final class DiaryVideoEmbedActions {
  /// 确认调整后一次写入宽度上限（取整，逻辑像素），一步撤销；保持原选区，
  /// 面板关闭时不重新请求键盘。拖动期间的预览只在视频块内改变约束。
  static void resize(
    DiaryEditorController controller, {
    required af.Node node,
    required double width,
  }) {
    if (node.parent == null || controller.readOnly) return;
    controller.apply(
      controller.state.transaction
        ..updateNode(node, {kDiaryVideoWidthKey: width.roundToDouble()})
        ..afterSelection = controller.selection,
      updateSelection: false,
    );
  }
}
