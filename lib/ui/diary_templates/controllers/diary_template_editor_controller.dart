import 'package:flutter/widgets.dart';
import '../../../core/services/editing_session_registry.dart';
import '../../diaries/controllers/diary_editor_controller.dart' as editor;

import '../../diaries/models/diary_meta_draft.dart';
import '../../diaries/models/time_capsule.dart';
import '../../diaries/viewmodels/diary_meta_draft_controller.dart';
import '../models/diary_template.dart';
import '../models/diary_template_json.dart';
import '../models/diary_template_recommend.dart';
import 'diary_templates_controller.dart';

/// 模板编辑页的草稿状态：各字段、正文块文档、未保存判断与保存。
///
/// 输入：要编辑的模板（null 为新建；id 为空的模板是“另存为模板”预填的新
/// 模板，同样算新建）。输出：[build] 出的模板与 [save] 的写入。
///
/// 心情与精力借用一个只在本页使用的 [DiaryMetaDraftController]，从而直接复用
/// 发布面板的心情、精力区块；其余字段由本控制器自己持有。
///
/// 未保存判断拿 [build] 的结果与基线比较：已保存的模板以它本身为基线（经同一
/// 套编码归一，打开即离开不会误报）；新建与预填的模板以空白模板为基线，预填
/// 的内容没保存就离开会提示。
///
/// 存在期间是局域网同步的阻塞者：保存时整份写回打开时的模板，同步在这期间
/// 改动同一模板会被覆盖。构造时登记，[dispose] 注销。
class DiaryTemplateEditorController extends ChangeNotifier {
  DiaryTemplateEditorController(DiaryTemplate? template)
    : _id = template?.id ?? '',
      name = TextEditingController(text: template?.name ?? ''),
      description = TextEditingController(text: template?.description ?? ''),
      titlePattern = TextEditingController(text: template?.titlePattern ?? ''),
      body = editor.DiaryEditorController(
        document: editor.diaryEditorDocument(
          template?.bodyJson ?? DiaryTemplate.emptyBodyJson,
        ),
        selection: editor.Selection.single(path: [0], startOffset: 0),
      ),
      meta = DiaryMetaDraftController(
        DiaryMetaDraft(
          moodEmoji: template?.mood,
          energyLevel: template?.energy?.toDouble(),
        ),
      ),
      _icon = template?.icon ?? DiaryTemplateIcon.penNib,
      _accent = template?.accent,
      _category = template?.category ?? DiaryTemplateCategory.other,
      _tags = template?.tags ?? const <DiaryTemplateTagRef>[],
      _capsule = template?.capsule,
      _recommend = template?.recommend ?? DiaryTemplateRecommendRules.none,
      _editingLease = EditingSessionRegistry.instance.beginEditing(
        'template-editor',
      ) {
    // 空白控制器 build 出的正是这个模板（空正文、默认图标与分类）。
    _baseline = _id.isEmpty ? const DiaryTemplate(id: '', name: '') : build();
    for (final listenable in <Listenable>[
      name,
      description,
      titlePattern,
      meta,
      body,
    ]) {
      listenable.addListener(notifyListeners);
    }
  }

  String _id;
  final EditingLease _editingLease;
  final TextEditingController name;
  final TextEditingController description;
  final TextEditingController titlePattern;
  final editor.DiaryEditorController body;
  final DiaryMetaDraftController meta;
  late DiaryTemplate _baseline;

  DiaryTemplateIcon _icon;
  int? _accent;
  DiaryTemplateCategory _category;
  List<DiaryTemplateTagRef> _tags;
  TimeCapsulePreset? _capsule;
  DiaryTemplateRecommendRules _recommend;
  bool _nameMissing = false;
  bool _saving = false;

  bool get isNew => _id.isEmpty;
  DiaryTemplateIcon get icon => _icon;
  int? get accent => _accent;
  DiaryTemplateCategory get category => _category;
  List<DiaryTemplateTagRef> get tags => _tags;
  TimeCapsulePreset? get capsule => _capsule;
  DiaryTemplateRecommendRules get recommend => _recommend;

  /// 保存时名称为空：设置页名称框显示错误。
  bool get nameMissing => _nameMissing;
  bool get saving => _saving;

  bool get dirty => build() != _baseline;

  set icon(DiaryTemplateIcon value) => _set(() => _icon = value);
  set accent(int? value) => _set(() => _accent = value);
  set category(DiaryTemplateCategory value) => _set(() => _category = value);
  set capsule(TimeCapsulePreset? value) => _set(() => _capsule = value);
  set recommend(DiaryTemplateRecommendRules value) =>
      _set(() => _recommend = value);

  /// 加一个预设标签；同名的已有就不再加，超过上限时忽略。
  void addTag(DiaryTemplateTagRef tag) {
    final name = tag.name.trim();
    if (name.isEmpty ||
        _tags.length >= DiaryTemplate.maxTags ||
        _tags.any((t) => t.name == name)) {
      return;
    }
    _set(
      () =>
          _tags = List<DiaryTemplateTagRef>.unmodifiable(<DiaryTemplateTagRef>[
            ..._tags,
            DiaryTemplateTagRef(name: name, color: tag.color),
          ]),
    );
  }

  void removeTag(String name) => _set(
    () => _tags = List<DiaryTemplateTagRef>.unmodifiable(
      _tags.where((t) => t.name != name),
    ),
  );

  void _set(VoidCallback change) {
    change();
    if (_nameMissing && name.text.trim().isNotEmpty) _nameMissing = false;
    notifyListeners();
  }

  /// 当前编辑中的模板（正文经白名单清洗，与保存后读回的一致）。
  DiaryTemplate build() {
    final metaValue = meta.value;
    return DiaryTemplate(
      id: _id,
      name: normalizeDiaryTemplateLine(name.text, DiaryTemplate.maxNameLength),
      description: normalizeDiaryTemplateLine(
        description.text,
        DiaryTemplate.maxDescriptionLength,
      ),
      icon: _icon,
      accent: _accent,
      category: _category,
      titlePattern: normalizeDiaryTemplateLine(
        titlePattern.text,
        DiaryTemplate.maxTitleLength,
      ),
      bodyJson: encodeDiaryTemplateBody(body.document.toJson()),
      tags: _tags,
      mood: metaValue.moodEmoji,
      energy: metaValue.energyLevel?.round(),
      capsule: _capsule,
      recommend: _recommend,
    );
  }

  /// 保存；名称为空时不保存、标记 [nameMissing] 并返回 false。写入失败向上
  /// 抛出，由页面提示。
  ///
  /// 已有的模板没有改动时不写入、直接返回 true：内置模板一经保存就会在库里
  /// 留下一份“改过的版本”（列表里标“已修改”），打开看一眼再点保存不该如此。
  Future<bool> save(DiaryTemplatesController templates) async {
    if (_saving) return false;
    if (name.text.trim().isEmpty) {
      _nameMissing = true;
      notifyListeners();
      return false;
    }
    if (!isNew && !dirty) return true;
    _saving = true;
    notifyListeners();
    try {
      final template = build();
      _id = await templates.save(template);
      _baseline = build();
      return true;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _editingLease.end();
    name.dispose();
    description.dispose();
    titlePattern.dispose();
    body.dispose();
    meta.dispose();
    super.dispose();
  }
}
