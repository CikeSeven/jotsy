import 'package:flutter/widgets.dart';

import '../../../../core/services/app_platform.dart';
import '../../controllers/diary_editor_controller.dart';

/// 不输入文字的选区操作（拖选区把手、复制后收成光标、全选）此刻是否该让
/// 软键盘保持收起：手机上软键盘收着时是。键盘开着时照常同步输入法（键盘
/// 本来就在）；桌面没有软键盘，输入法连接要跟着选区，接着打字才落在新选区。
bool diaryShouldHoldKeyboard(BuildContext context) =>
    AppPlatform.isMobile && View.of(context).viewInsets.bottom == 0;

/// 按 [diaryShouldHoldKeyboard] 决定是否经
/// [DiaryEditorController.holdingKeyboard] 执行 [action]。
T holdHiddenKeyboard<T>(
  BuildContext context,
  DiaryEditorController controller,
  T Function() action,
) => diaryShouldHoldKeyboard(context) && !controller.isDisposed
    ? controller.holdingKeyboard(action)
    : action();
