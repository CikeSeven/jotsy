import '../../../l10n/app_localizations_gen.dart';
import '../../diaries/models/diary_meta_draft.dart';
import '../../diaries/viewmodels/diary_meta_draft_controller.dart';
import '../models/diary_template.dart';

/// 编辑页交给模板套用的读写口：控制器不直接碰页面 State，测试可以换成假的。
abstract interface class DiaryTemplateEditorPort {
  String get title;

  /// 当前正文的块文档 JSON（与草稿里的 `contentDocJson` 同一种编码）。
  String get contentDocJson;

  /// 标题或正文里已有内容（含图片等嵌入）。
  bool get hasContent;

  DiaryMetaDraftController get meta;

  /// 日记的日期：日历补写时是那一天，否则是今天。
  DateTime get diaryDate;

  AppLocalizations get l10n;

  /// 本机的心情选项：模板预设的心情不在其中时不套用。
  List<String> get moodOptions;

  /// 换上新的标题与正文，光标放到 [caret]；返回载入后的正文重新编码的
  /// JSON——编辑器会规整相邻的同格式文字，与传入的 [document] 未必逐字相同，
  /// 之后判断“是否原样未动”必须拿载入后的编码比较。
  String replaceContent({
    required String title,
    required Map<String, Object?> document,
    required int caret,
  });
}

/// 模板从哪里套用：只有自动套用不计入“最近使用”。
enum DiaryTemplateApplySource { strip, picker, launch, auto }

/// 一次套用留下的记录：撤销时据此只撤回模板带来的东西。
class DiaryTemplateApplied {
  DiaryTemplateApplied({
    required this.template,
    required this.title,
    required this.bodyJson,
    required this.metaBefore,
    required this.metaAfter,
  });

  final DiaryTemplate template;
  final String title;
  final String bodyJson;

  /// 套用前与刚套用完预设（心情、精力、胶囊）后的元数据。
  final DiaryMetaDraft metaBefore;
  final DiaryMetaDraft metaAfter;

  /// 模板勾上的标签（原本没选中的）与为此新建的标签；标签异步解析，撤销时
  /// 读到的是已经完成的部分。
  final Set<int> addedTagIds = <int>{};
  final Set<int> createdTagIds = <int>{};
}
