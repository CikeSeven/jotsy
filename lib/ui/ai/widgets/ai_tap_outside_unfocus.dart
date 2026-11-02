import 'package:flutter/widgets.dart';

/// 点输入框以外的地方即取消输入框的焦点（触屏也是）。
///
/// Flutter 在手机上默认“点外面不取消焦点”：用户用系统返回或键盘上的收起键
/// 收起键盘后，焦点仍留在输入框里；之后点一行打开面板、对话框或下一页，
/// 回来时路由把焦点还给那个输入框，键盘就又弹出来，每操作一次都得再收一次。
/// 这里覆盖输入框的 [EditableTextTapOutsideIntent]（它是可被祖先覆盖的
/// 动作）：按下的位置在输入框之外就取消焦点，再打开什么也不会把键盘带回来。
///
/// 按在输入框自己的区域里（含它的前后缀图标，如密钥框的显示 / 隐藏）不受
/// 影响；希望点了不收键盘的按钮（如对话页的发送）用 [TextFieldTapRegion]
/// 包起来，就算作输入框的一部分。
class AiTapOutsideUnfocus extends StatelessWidget {
  const AiTapOutsideUnfocus({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: <Type, Action<Intent>>{
        EditableTextTapOutsideIntent:
            CallbackAction<EditableTextTapOutsideIntent>(
              onInvoke: (EditableTextTapOutsideIntent intent) {
                intent.focusNode.unfocus();
                return null;
              },
            ),
      },
      child: child,
    );
  }
}
