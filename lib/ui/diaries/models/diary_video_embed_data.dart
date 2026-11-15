import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart'
    show kDiaryVideoWidthKey;

/// 视频块记录的显示宽度上限（逻辑像素，[kDiaryVideoWidthKey]，视频菜单
/// “调整大小”写入）；没设或不是正数时为 null，卡片铺满正文列。只作上限：
/// 正文列更窄时以列宽为准，高度随视频比例。
double? diaryVideoWidthLimit(af.Node node) {
  final raw = node.attributes[kDiaryVideoWidthKey];
  final value = raw is num ? raw.toDouble() : double.tryParse('${raw ?? ''}');
  return value != null && value.isFinite && value > 0 ? value : null;
}
