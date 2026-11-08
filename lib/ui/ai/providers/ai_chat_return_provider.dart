import 'package:flutter_riverpod/flutter_riverpod.dart';

/// “回到对话”：AI 的前往卡片把用户带回首页（某个 Tab、或切换首页的日记本
/// 范围）时，对话页随首页之上的页面一起被关掉；这里记下那段对话的 id，
/// 首页与日记页的返回键、以及落地后的提示条据此把它重新打开。
///
/// - 对话页打开会离开对话的目标前登记（[arm]），打开后对话页还在（例如上锁
///   的日记本验证没通过）就撤销登记；
/// - 任何对话页打开时（含重新打开）、用户点底栏换 Tab 时撤销登记：用户已经
///   去做别的事了，返回键恢复原来的行为。
final aiChatReturnProvider = NotifierProvider<AiChatReturn, String?>(
  AiChatReturn.new,
);

class AiChatReturn extends Notifier<String?> {
  @override
  String? build() => null;

  void arm(String conversationId) => state = conversationId;

  void disarm() {
    if (state != null) state = null;
  }
}
