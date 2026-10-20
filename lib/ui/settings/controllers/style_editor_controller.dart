import '../../diaries/models/style_library/saved_style.dart';
import '../../diaries/models/style_library/style_code.dart';
import 'style_draft_controller.dart';

/// 带“我的样式”与样式码的样式编辑页（卡片样式、预览页样式）共用的业务
/// 编排。
///
/// 草稿、预览明暗、提交与重置等通用部分见 [StyleDraftController]；这里在
/// 整体设置 [L]（[StyleLibrary]）之上加上保存/改名/删除“我的样式”与样式码
/// 导入导出。副作用：经 `persist` 写入设置。
abstract class StyleEditorController<S, L extends StyleLibrary<S, L>>
    extends StyleDraftController<L, S> {
  StyleEditorController({
    required super.rawNotifier,
    required super.decode,
    required super.persist,
    required this.codeFormat,
    required super.defaultStyle,
  }) : super(
         currentOf: (L settings) => settings.current,
         withCurrent: (L settings, S style) => settings.withCurrent(style),
       );

  final StyleCodeFormat<S> codeFormat;

  L get settings => stored;

  /// 当前样式对应的“我的样式”；不是任何保存项时为 null。
  SavedStyle<S>? get matchingSaved =>
      SavedStyles.matching(settings.saved, style);

  bool get canSaveMore => settings.canSaveMore;

  /// 把当前样式存为“我的样式”；已达上限或名字无效时返回 false。
  Future<bool> saveCurrentAs(String name) async {
    if (!settings.canSaveMore) {
      return false;
    }
    final current = style;
    final next = settings.addSaved(name, current);
    if (next == settings) {
      return false;
    }
    dropDraft();
    await save(next.withCurrent(current));
    return true;
  }

  Future<void> renameSaved(String id, String name) =>
      save(settings.renameSaved(id, name));

  /// 删除一份保存项；返回被删的条目与原位置供撤销。
  Future<(SavedStyle<S>, int)?> deleteSaved(String id) async {
    final index = settings.saved.indexWhere((item) => item.id == id);
    if (index < 0) {
      return null;
    }
    final item = settings.saved[index];
    await save(settings.removeSaved(id));
    return (item, index);
  }

  Future<void> restoreSaved(SavedStyle<S> item, int index) =>
      save(settings.restoreSaved(item, index));

  /// 当前样式的样式码（附带当前预设或保存项的名字，便于对方识别）。
  String exportCode({String? name}) =>
      codeFormat.encode(style, name: name ?? matchingSaved?.name);

  /// 解析并套用样式码；无法解析时不改动样式。返回解析结果与此前的样式。
  Future<(StyleCodeResult<S>, S?)> importCode(String? text) async {
    final result = codeFormat.decode(text);
    final imported = result.style;
    if (imported == null) {
      return (result, null);
    }
    final previous = await applyStyle(imported);
    return (result, previous);
  }
}
