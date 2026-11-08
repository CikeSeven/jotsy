import 'package:flutter/material.dart';

/// 待办里“画在卡片 / 面板表面上”的输入框装饰：不填底、没有任何状态的描边、
/// 不显示字数，只留竖向内边距。
///
/// 主题的输入框是带填充底与聚焦描边的独立控件；详情的标题、备注、步骤与
/// 列表末尾的内联新建本身已在卡片里，再套一层就成了框中框，文字也被主题的
/// 横向内边距推离方框。只写 `border: InputBorder.none` 挡不住主题的
/// `enabledBorder` / `focusedBorder`，所以各状态逐个置空。
InputDecoration todoBareInputDecoration({
  String? hintText,
  EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(vertical: 10),
}) {
  return InputDecoration(
    hintText: hintText,
    counterText: '',
    filled: false,
    isDense: true,
    contentPadding: contentPadding,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
  );
}
