import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_platform.dart';

/// 其他应用提供的文字处理动作（Android `ACTION_PROCESS_TEXT`：翻译、添加到
/// 笔记等），给日记正文的选区菜单用。
///
/// 输入框不需要它：Flutter 已把这些动作放进 `EditableTextState.contextMenuButtonItems`
/// （`ContextMenuButtonType.custom`）。日记正文是 AppFlowy 编辑器，没有这条
/// 链路，只能自己查询。
///
/// - 输出：同步可读的 [current] 与变化通知 [actions]。菜单打开时直接读缓存
///   显示，同时调用 [refresh] 在后台更新（不阻塞显示）；装卸了应用，下次打开
///   菜单即可看到。
/// - 失败：查询失败（通道未注册、平台异常）一律吞掉并保留旧值，菜单少几项
///   不影响主要操作；[process] 失败返回 null。
/// - 平台：只在 [AppPlatform.supportsProcessText] 时查询，其他平台 [current]
///   始终为空，[process] 直接返回 null。
///
/// 可注入：测试经 [debugOverride] 换成假的实例，或构造时传入假的
/// [ProcessTextService]。
class TextProcessActionsService {
  TextProcessActionsService({ProcessTextService? service})
    : _service = service ?? DefaultProcessTextService();

  static TextProcessActionsService? _override;
  static final TextProcessActionsService _shared = TextProcessActionsService();

  /// 全应用共用的实例。
  static TextProcessActionsService get instance => _override ?? _shared;

  /// 测试里替换 [instance]；传 null 恢复。
  @visibleForTesting
  static void debugOverride(TextProcessActionsService? service) =>
      _override = service;

  final ProcessTextService _service;
  final ValueNotifier<List<ProcessTextAction>> _actions =
      ValueNotifier<List<ProcessTextAction>>(const <ProcessTextAction>[]);

  /// 正在进行的查询：菜单接连打开时共用一次，不并发打到平台通道。
  Future<void>? _pending;

  /// 最近一次查询到的动作（还没查询过时为空）。
  List<ProcessTextAction> get current => _actions.value;

  /// [current] 的变化通知，菜单可监听它在查询返回后补上新动作。
  ValueListenable<List<ProcessTextAction>> get actions => _actions;

  /// 在后台重新查询；不支持的平台什么也不做。
  Future<void> refresh() {
    if (!AppPlatform.supportsProcessText) return Future<void>.value();
    return _pending ??= _query().whenComplete(() => _pending = null);
  }

  Future<void> _query() async {
    try {
      final result = await _service.queryTextActions();
      if (!listEquals(result, _actions.value)) {
        _actions.value = List<ProcessTextAction>.unmodifiable(result);
      }
    } on Object catch (error) {
      // 查询失败不影响菜单的其余部分，保留上次的结果。
      debugPrint('TextProcessActionsService.refresh failed: $error');
    }
  }

  /// 把 [text] 交给动作 [id] 处理；[readOnly] 为 true 时对方不能回写文字。
  /// 返回对方处理后的文字（只读、取消或失败时为 null）。
  Future<String?> process(
    String id,
    String text, {
    required bool readOnly,
  }) async {
    if (!AppPlatform.supportsProcessText) return null;
    try {
      return await _service.processTextAction(id, text, readOnly);
    } on Object catch (error) {
      debugPrint('TextProcessActionsService.process failed: $error');
      return null;
    }
  }
}
