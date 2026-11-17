/// 应用内日期选择的统一可选范围：日历、发表时间、纪念日、日记本日期规则，
/// 以及导出 / AI 回顾等“选一段过去日期”的入口共用同一个下限，避免各处
/// 写死不同的年份（曾有的 2010 下限让补记早年的日记无从选起）。
///
/// - 下限 1900-01-01：覆盖长辈生日、老照片补记等场景；农历换算（tyme）
///   与 table_calendar 都支持这一范围。
/// - 上限 2100-12-31：日历与纪念日可往后看的最远日期。只选过去的入口
///   （导出、AI 回顾）各自用更近的上限，不取这里的值。
abstract final class DatePickerRange {
  static final DateTime firstDate = DateTime(1900);
  static final DateTime lastDate = DateTime(2100, 12, 31);
}
