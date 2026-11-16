import 'package:flutter/widgets.dart';

/// 导图所在的日记能不能用 AI 的判断，由宿主页面（日记编辑页）提供。
///
/// 导图工作区与嵌入导图的编辑页不知道自己属于哪篇日记，也不该自己判断
/// 私密：编辑页的 [allowed] 会看这篇日记是否私密、新日记要收进的日记本
/// 是否私密（不能用时自己提示原因）。工作区只在找得到本作用域、且 AI 写作
/// 模块可用时显示 AI 入口，每次打开 AI 面板前先 await [allowed]。
///
/// 嵌入导图的编辑页是另一条路由，读不到编辑页里的作用域：打开时由
/// `editDiaryMindMap` 从块所在的 context 取出，再在新页面里重新提供。
class MindMapAiScope extends InheritedWidget {
  const MindMapAiScope({
    super.key,
    required this.allowed,
    required super.child,
  });

  final Future<bool> Function() allowed;

  static MindMapAiScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MindMapAiScope>();

  // 宿主每次构建都会给一个新的闭包，判断的口径却不变：不必通知依赖者。
  @override
  bool updateShouldNotify(MindMapAiScope oldWidget) => false;
}
