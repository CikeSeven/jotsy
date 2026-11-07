import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/services/app_platform.dart';
import '../../controllers/diary_embed_editing.dart';

/// 插入点停在嵌入块上时的输入法连接（规则见 diary_embed_editing.dart）。
///
/// 为什么要自己连：上游只按插入点所在块的文字给输入法编辑值，块里没有文字
/// 时什么都不做——键盘不弹出，弹着的也还连着上一行的文字，打字会按那一行
/// 计算。这里给输入法一个空行的编辑值（与上游给空段落的完全一样，上游会再
/// 垫一个空格占位），键盘照常弹出：退格删掉的是这个占位，交给退格规则；
/// 打的字由拦截器先补一行、再交给上游照常写进去，输入法这边始终是“空行
/// 开始输入”，组字不受打扰。
///
/// 连接经上游键盘服务自己的输入服务，不另开连接：上游随后为文字块连接时
/// 沿用同一个连接，按编辑值比较决定要不要重发。
abstract final class DiaryEmbedCaretInput {
  /// 插入点停在嵌入块上时连接输入法（手机上键盘收着时先断开再连，好让它
  /// 弹出），返回 true；不在嵌入块上或键盘服务还没就绪时返回 false。
  static bool attach(af.EditorState state) {
    if (state.isDisposed || diaryEmbedAtCaret(state) == null) return false;
    final service = state.service.keyboardService;
    // 上游把键盘服务的状态类标成仅供测试，但没有别的入口拿到它的输入服务。
    // ignore: invalid_use_of_visible_for_testing_member
    if (service is! af.KeyboardServiceWidgetState || !service.mounted) {
      return false;
    }
    final context = service.context;
    final input = service.textInputService;
    // 编辑值与上次相同（上一处也是空行）时上游不重发、也不 show：键盘
    // 收着就断开重连（同 DiaryEditorKeyboardReopen 的情形 2）。
    if (AppPlatform.isMobile && View.of(context).viewInsets.bottom == 0) {
      input.close();
    }
    input
      ..clearComposingTextRange()
      ..attach(
        const TextEditingValue(selection: TextSelection.collapsed(offset: 0)),
        TextInputConfiguration(
          viewId: View.of(context).viewId,
          inputType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          inputAction: TextInputAction.newline,
          keyboardAppearance: Theme.of(context).brightness,
          allowedMimeTypes:
              service.widget.contentInsertionConfiguration?.allowedMimeTypes ??
              const [],
        ),
      );
    return true;
  }

  /// 按当前选区重新同步输入法：停在嵌入块上时经 [attach]，否则交给上游。
  static void sync(af.EditorState state) {
    final selection = state.selection;
    if (state.isDisposed || selection == null) return;
    if (!attach(state)) {
      state.service.keyboardService?.enableKeyBoard(selection);
    }
  }
}
