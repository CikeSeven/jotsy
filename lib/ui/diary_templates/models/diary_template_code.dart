import '../../diaries/models/style_library/style_code.dart';
import 'diary_template.dart';
import 'diary_template_json.dart';

/// 模板码：经剪贴板分享与导入一个模板，格式与样式码相同
/// （`jotsy-template:v1:<base64url(JSON)>`，见 [StyleCodeFormat]）。
///
/// 名称放在模板 JSON 里，不用样式码的 `n` 字段。导入得到的模板 id 为空串，
/// 由调用方生成新的 id 后保存；正文在解码时已经白名单清洗。
final StyleCodeFormat<DiaryTemplate> diaryTemplateCodeFormat =
    StyleCodeFormat<DiaryTemplate>(
      scheme: 'jotsy-template',
      version: DiaryTemplateJson.version,
      fromJson: (json) => DiaryTemplateJson.fromJson(json, id: ''),
      toJson: DiaryTemplateJson.toJson,
    );

/// 导出模板码；超过 [StyleCodeFormat.maxLength]（导入时会被拒绝）返回 null，
/// 界面提示正文太长、不能生成模板码，而不是给出一个导不进来的码。
String? encodeDiaryTemplateCode(DiaryTemplate template) {
  final code = diaryTemplateCodeFormat.encode(template);
  return code.length > StyleCodeFormat.maxLength ? null : code;
}
