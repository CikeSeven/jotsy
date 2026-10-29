import 'package:flutter/widgets.dart';

import '../../core/services/editing_session_registry.dart';

/// 页面存在期间登记为局域网同步的阻塞者。
///
/// 给握着一份可编辑内存副本、保存时整份写回的页面用（纪念日、日记本编辑页）：
/// 同步在它打开期间写库，保存就会用打开时读到的旧值覆盖同步来的改动。
/// `initState` 登记、`dispose` 注销，覆盖页面读取初值（异步加载）到关闭的
/// 整段时间；页面不必自己管理租约。
mixin EditingSessionBlocker<T extends StatefulWidget> on State<T> {
  /// 诊断用的来源标签（[EditingSessionRegistry.activeEditorLabels]）。
  String get editingSessionLabel;

  late final EditingLease _editingSessionLease;

  @override
  void initState() {
    super.initState();
    _editingSessionLease = EditingSessionRegistry.instance.beginEditing(
      editingSessionLabel,
    );
  }

  @override
  void dispose() {
    _editingSessionLease.end();
    super.dispose();
  }
}
