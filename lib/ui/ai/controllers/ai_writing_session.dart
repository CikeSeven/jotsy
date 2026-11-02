import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/foundation.dart';

import '../../../core/services/ai/ai_models.dart';
import '../../../core/services/ai/ai_provider_config.dart';
import '../../../core/services/ai/ai_service.dart';
import '../../diaries/controllers/diary_ai_editing.dart';
import '../../diaries/controllers/diary_editor_controller.dart';
import '../models/ai_built_ins.dart';
import '../models/ai_preference_parts.dart';
import 'ai_stream_run.dart';

/// 编辑页 AI 写作面板的会话：记住打开面板时的选区（面板打开期间正文
/// 锁定，选区不会变）、当前的作用范围、最近一次指令与生成状态。
///
/// 由编辑页持有：工具栏随键盘收起而卸载，会话不能跟着没了，生成也不能被
/// 打断。关闭面板时由编辑页 [dispose]，进行中的生成随之取消。
class AiWritingSession extends ChangeNotifier {
  AiWritingSession({
    required this.editor,
    af.Selection? selection,
    DiaryAiScope? scope,
  }) : _anchor = selection?.normalized,
       _scope =
           scope ??
           (selection != null && !selection.isCollapsed
               ? DiaryAiScope.selection
               : DiaryAiScope.paragraph) {
    run.addListener(notifyListeners);
    _target = diaryAiTarget(editor, _scope, selection: _anchor);
  }

  final DiaryEditorController editor;
  final af.Selection? _anchor;
  final AiStreamRun run = AiStreamRun();

  DiaryAiScope _scope;
  DiaryAiTarget? _target;
  DiaryAiTarget? _runTarget;
  AiActionInfo? _action;
  String? _instruction;
  bool _disposed = false;

  DiaryAiScope get scope => _scope;

  /// 当前作用范围对应的目标（面板上显示“作用于…”）。
  DiaryAiTarget? get target => _target;

  /// 最近一次生成用的指令（重试时沿用）。
  AiActionInfo? get action => _action;
  String? get instruction => _instruction;

  /// 打开时有没有选中文字（决定“选中的文字”是否可选）。
  bool get hasSelection => !(_anchor?.isCollapsed ?? true);

  /// 结果：收拾过的模型输出。
  String get result => aiCleanOutput(run.text);

  /// 结果默认的用法：内置 / 自建指令的设定；自由指令替换原文。
  AiActionOutput get defaultOutput => _action?.output ?? AiActionOutput.replace;

  void setScope(DiaryAiScope scope) {
    if (scope == _scope) return;
    _scope = scope;
    _target = diaryAiTarget(editor, scope, selection: _anchor);
    run.reset();
  }

  /// 指令实际作用的目标：续写一律取光标前的内容，其余取当前范围。
  DiaryAiTarget? targetFor(AiActionInfo? action) {
    if (action?.scope == AiActionScope.beforeCaret) {
      return diaryAiTarget(
        editor,
        DiaryAiScope.beforeCaret,
        selection: _anchor,
      );
    }
    return _target;
  }

  /// 开始生成。[target] 是这次实际作用的目标（应用结果时写回它）。
  Future<void> start({
    required AiService service,
    required AiResolvedModel model,
    required AiRequest request,
    required DiaryAiTarget target,
    AiActionInfo? action,
    String? instruction,
  }) {
    _action = action;
    _instruction = instruction;
    _runTarget = target;
    return run.start(
      (token) => service.stream(model, request, cancelToken: token),
    );
  }

  /// 把结果写回正文；返回是否写入了。
  bool apply(AiActionOutput output) {
    final target = _runTarget;
    final text = result;
    if (target == null || text.isEmpty || editor.readOnly) return false;
    switch (output) {
      case AiActionOutput.replace:
        // 续写没有可替换的原文，按插入处理。
        if (target.scope == DiaryAiScope.beforeCaret) {
          insertDiaryAiBelow(editor, target, text);
        } else {
          replaceDiaryAiTarget(editor, target, text);
        }
      case AiActionOutput.insertBelow:
        insertDiaryAiBelow(editor, target, text);
      case AiActionOutput.preview:
        return false;
    }
    return true;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    run
      ..removeListener(notifyListeners)
      ..dispose();
    super.dispose();
  }
}
