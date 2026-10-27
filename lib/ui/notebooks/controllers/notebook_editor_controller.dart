import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/diary_cover_storage_service.dart';
import '../../../core/services/diary_media_storage_service.dart';
import '../models/notebook_icon.dart';
import '../viewmodels/notebook_view.dart';

/// 选封面的结果，页面据此给提示。
enum NotebookCoverPickResult { cancelled, missingPath, failed, picked }

/// 编辑页表单里会被比较“有没有改动”的全部值。
typedef _NotebookDraft = ({
  String name,
  String description,
  NotebookIcon icon,
  int? color,
  String? coverPath,
  NotebookCoverStyle coverStyle,
  String? parentId,
  NotebookKind kind,
  NotebookVisibility visibility,
  NotebookSort sort,
  String? templateId,
  NotebookRuleSet rules,
  NotebookGoal? goal,
});

/// 日记本编辑页的表单状态与保存（新建与编辑共用）。
///
/// 输入：要编辑的日记本（null 为新建）与新建时的初始类型、名称；输出：经
/// [save] 写进数据库并返回业务 id。页面只负责组合与提示。
///
/// - 名称与简介是 [TextEditingController]，其余字段经 setter 修改并通知；
/// - [dirty] 比较当前值与打开时（或上次保存后）的快照，决定返回时是否确认；
/// - 编辑时以原 payload 为底 `copyWith`，章节这类本页不编辑的字段原样保留；新建时以 [NotebookEditorController.new] 的 `initialPayload`
///   为底（日历、搜索的快捷新建预填规则）；
/// - 智能规则（[rules]）也是表单的一部分：参与改动比较；智能日记本至少要有
///   一条规则才能保存（空规则什么都不匹配）；保存为普通日记本时不写规则；
/// - 智能日记本不能私密：类型选了“智能”时私密选项隐藏，保存一律写 normal
///   （数据库层也会兜底），切回“普通”时恢复之前的选择；
/// - 写作目标只属于普通日记本：开关关闭时周期与篇数仍记在表单里（再打开时
///   恢复），保存时不写；智能日记本保存时一律清除目标；
/// - 选封面只拷贝新图到封面私有目录，被替换或移除的旧封面不在这里删除——
///   它可能仍被已保存的数据引用，由按引用回收的清理服务处理；从本子的日记
///   里选图（[setCoverFromFile]）同样拷贝一份，不引用日记的原图；
/// - 封面图换了或移除时取景（`NotebookCoverStyle` 的对齐点与放大）随之重置，
///   版式与纹理保留；
/// - 上级（[parentId]）也是表单的一部分：新建时可由调用方预填（在某本的
///   头部“新建子本”），保存时经数据库层校验，不合法时保存失败。
class NotebookEditorController extends ChangeNotifier {
  NotebookEditorController({
    NotebookView? notebook,
    NotebookKind initialKind = NotebookKind.manual,
    String? initialName,
    NotebookPayload? initialPayload,
    String? initialParentId,
  }) : _notebook = notebook,
       _basePayload =
           notebook?.payload ?? initialPayload ?? NotebookPayload.defaults {
    final payload = _basePayload;
    name = TextEditingController(text: notebook?.name ?? initialName ?? '');
    description = TextEditingController(text: payload.description);
    _icon = notebook?.icon ?? NotebookIcon.fallback;
    _color = payload.color;
    _coverPath = payload.coverPath;
    _coverStyle = payload.coverStyle;
    _parentId = notebook == null ? initialParentId : notebook.parentId;
    _kind = notebook?.kind ?? initialKind;
    _visibility = notebook?.visibility ?? NotebookVisibility.normal;
    _sort = payload.sort;
    _templateId = payload.templateId;
    _rules = NotebookRuleSet.decode(payload.rules);
    final goal = payload.goal;
    _goalEnabled = goal != null;
    _goalPeriod = goal?.period ?? NotebookGoalPeriod.week;
    _goalTarget = goal?.target ?? defaultGoalTarget;
    _initial = _draft;
    name.addListener(notifyListeners);
    description.addListener(notifyListeners);
  }

  /// 名称在界面上的长度上限（数据库允许 60，书架格子放不下那么长）。
  static const int maxNameLength = 30;

  final NotebookView? _notebook;

  /// 表单的底：编辑时为原 payload，新建时为预填的 payload。
  final NotebookPayload _basePayload;
  late final TextEditingController name;
  late final TextEditingController description;
  late _NotebookDraft _initial;

  bool get isNew => _notebook == null;
  String? get notebookId => _notebook?.id;

  late NotebookIcon _icon;
  NotebookIcon get icon => _icon;
  set icon(NotebookIcon value) => _set(() => _icon = value);

  int? _color;
  int? get color => _color;
  set color(int? value) => _set(() => _color = value);

  String? _coverPath;
  String? get coverPath => _coverPath;

  /// 换图或移除时一并重置取景（旧图的取景对新图没有意义）。
  set coverPath(String? value) => _set(() {
    if (value != _coverPath) _coverStyle = _coverStyle.withoutCrop();
    _coverPath = value;
  });

  late NotebookCoverStyle _coverStyle;

  /// 封面版式、纹理与取景。
  NotebookCoverStyle get coverStyle => _coverStyle;
  set coverStyle(NotebookCoverStyle value) => _set(() => _coverStyle = value);

  String? _parentId;

  /// 上级日记本的业务 id；null 为书架顶层。
  String? get parentId => _parentId;
  set parentId(String? value) => _set(() => _parentId = value);

  late NotebookKind _kind;
  NotebookKind get kind => _kind;

  /// 只有新建时可改类型。
  set kind(NotebookKind value) {
    if (!isNew) return;
    _set(() => _kind = value);
  }

  late NotebookVisibility _visibility;
  NotebookVisibility get visibility => _visibility;
  set visibility(NotebookVisibility value) => _set(() => _visibility = value);

  late NotebookSort _sort;
  NotebookSort get sort => _sort;
  set sort(NotebookSort value) => _set(() => _sort = value);

  String? _templateId;
  String? get templateId => _templateId;
  set templateId(String? value) => _set(() => _templateId = value);

  late NotebookRuleSet _rules;

  /// 智能日记本的规则（草稿）。
  NotebookRuleSet get rules => _rules;

  bool get canAddRule => _rules.rules.length < NotebookRuleSet.maxRules;

  set ruleMatch(NotebookRuleMatch value) =>
      _set(() => _rules = _rules.copyWith(match: value));

  /// 追加一条规则；已到上限时忽略。
  void addRule(NotebookRule rule) {
    if (!canAddRule) return;
    _set(
      () => _rules = _rules.copyWith(
        rules: <NotebookRule>[..._rules.rules, rule],
      ),
    );
  }

  void replaceRule(int index, NotebookRule rule) {
    if (index < 0 || index >= _rules.rules.length) return;
    _set(
      () => _rules = _rules.copyWith(
        rules: <NotebookRule>[..._rules.rules]..[index] = rule,
      ),
    );
  }

  void removeRuleAt(int index) {
    if (index < 0 || index >= _rules.rules.length) return;
    _set(
      () => _rules = _rules.copyWith(
        rules: <NotebookRule>[..._rules.rules]..removeAt(index),
      ),
    );
  }

  /// “从示例开始”：放入示例规则；名称还空着时一并填上 [name]。
  void applyExample(NotebookRule rule, {required String name}) {
    if (name.isNotEmpty && this.name.text.trim().isEmpty) {
      this.name.text = name;
    }
    addRule(rule);
  }

  /// 打开目标开关时的默认篇数（“每周写 3 篇”）。
  static const int defaultGoalTarget = 3;

  late bool _goalEnabled;

  /// “设置目标”开关。
  bool get goalEnabled => _goalEnabled;
  set goalEnabled(bool value) => _set(() => _goalEnabled = value);

  late NotebookGoalPeriod _goalPeriod;
  NotebookGoalPeriod get goalPeriod => _goalPeriod;
  set goalPeriod(NotebookGoalPeriod value) => _set(() => _goalPeriod = value);

  late int _goalTarget;
  int get goalTarget => _goalTarget;

  /// 篇数夹到 [NotebookGoal.minTarget]..[NotebookGoal.maxTarget]。
  set goalTarget(int value) => _set(
    () => _goalTarget = value.clamp(
      NotebookGoal.minTarget,
      NotebookGoal.maxTarget,
    ),
  );

  /// 当前表单的目标：开关关闭或智能日记本时为 null。
  NotebookGoal? get goal => _goalEnabled && !isSmart
      ? NotebookGoal(period: _goalPeriod, target: _goalTarget)
      : null;

  bool _saving = false;
  bool get saving => _saving;

  bool _importingCover = false;
  bool get importingCover => _importingCover;

  bool get isSmart => _kind == NotebookKind.smart;

  /// 智能日记本还没有规则（保存键因此不可用，页面给出说明）。
  bool get needsRule => isSmart && _rules.isEmpty;

  bool get canSave => name.text.trim().isNotEmpty && !_saving && !needsRule;

  bool get dirty => _draft != _initial;

  _NotebookDraft get _draft => (
    name: name.text.trim(),
    description: description.text.trim(),
    icon: _icon,
    color: _color,
    coverPath: _coverPath,
    coverStyle: _coverStyle,
    parentId: _parentId,
    kind: _kind,
    visibility: _visibility,
    sort: _sort,
    templateId: _templateId,
    rules: _rules,
    goal: goal,
  );

  /// 实际写入的可见性：智能日记本一律 normal。
  NotebookVisibility get effectiveVisibility =>
      isSmart ? NotebookVisibility.normal : _visibility;

  /// 当前表单对应的 payload（编辑时保留本页不编辑的字段）。
  NotebookPayload get payload {
    return _basePayload.copyWith(
      description: description.text,
      icon: _icon.name,
      color: _color,
      clearColor: _color == null,
      coverPath: _coverPath,
      clearCoverPath: _coverPath == null,
      coverStyle: _coverStyle,
      sort: _sort,
      templateId: _templateId,
      clearTemplateId: _templateId == null,
      rules: isSmart ? _rules.encode() : null,
      clearRules: !isSmart,
      goal: goal,
      clearGoal: goal == null,
    );
  }

  bool _disposed = false;

  /// 异步操作（保存、拷贝封面）可能在页面关闭后才结束，此时不再通知。
  void _set(VoidCallback change) {
    change();
    if (!_disposed) notifyListeners();
  }

  /// 写入数据库并返回业务 id；名称为空时返回 null。失败时抛出，由页面提示。
  Future<String?> save(AppDatabase database) async {
    if (!canSave) return null;
    _set(() => _saving = true);
    try {
      final existing = _notebook;
      final String id;
      if (existing == null) {
        id = await database.createNotebook(
          name: name.text,
          kind: _kind,
          visibility: effectiveVisibility,
          payload: payload,
          parentId: _parentId,
        );
      } else {
        id = existing.id;
        await database.updateNotebook(
          id,
          name: name.text,
          visibility: effectiveVisibility,
          payload: payload,
          // 只在改了上级时写：改动上级会把它排到新上级的子本最后。
          parentId: _parentId == _initial.parentId
              ? const Value<String?>.absent()
              : Value<String?>(_parentId),
        );
      }
      _initial = _draft;
      return id;
    } finally {
      _set(() => _saving = false);
    }
  }

  /// 从系统选择器挑一张图，拷贝进封面私有目录后设为封面。
  ///
  /// 与发布页选封面同一条链路：选择器的临时副本用完即删；拷贝失败时不改动
  /// 当前封面。
  Future<NotebookCoverPickResult> pickCover() async {
    if (_importingCover) return NotebookCoverPickResult.cancelled;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null) return NotebookCoverPickResult.cancelled;
    final selectedPath = result.files.first.path?.trim();
    if (selectedPath == null || selectedPath.isEmpty) {
      return NotebookCoverPickResult.missingPath;
    }
    _set(() => _importingCover = true);
    try {
      coverPath = await DiaryCoverStorageService.importCover(selectedPath);
      return NotebookCoverPickResult.picked;
    } catch (error) {
      debugPrint('Notebook cover import failed: $error');
      return NotebookCoverPickResult.failed;
    } finally {
      await DiaryMediaStorageService.discardPickerCopy(selectedPath);
      _set(() => _importingCover = false);
    }
  }

  /// 把 [sourcePath]（本子里某篇日记用到的图片）拷贝进封面私有目录后设为
  /// 封面；原图不动、也不引用它（日记删掉后封面仍在）。拷贝失败时不改动
  /// 当前封面。
  Future<NotebookCoverPickResult> setCoverFromFile(String sourcePath) async {
    if (_importingCover) return NotebookCoverPickResult.cancelled;
    _set(() => _importingCover = true);
    try {
      coverPath = await DiaryCoverStorageService.importCover(sourcePath);
      return NotebookCoverPickResult.picked;
    } catch (error) {
      debugPrint('Notebook cover copy failed: $error');
      return NotebookCoverPickResult.failed;
    } finally {
      _set(() => _importingCover = false);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    name.dispose();
    description.dispose();
    super.dispose();
  }
}
