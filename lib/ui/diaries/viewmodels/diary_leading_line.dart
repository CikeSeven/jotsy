/// 正文纯文本的第一行：日记卡片与草稿行“没写标题时取正文第一行当标题”
/// 共用的拆分口径。
///
/// 输入：`contentText`（每个块一行，媒体与分隔线只占一个空行，见
/// `diaryBlocksPlainText`）；输出：第一个含非空白字符的行（连续空白折叠成
/// 一个空格、去掉首尾空白）与其后剩余文本的起点。纯函数，无副作用。
///
/// 只记剩余文本的起点而不复制它：日记卡片的派生数据按日记版本长期缓存，
/// 保留一整份“去掉第一行的正文”会让缓存的文本占用翻倍；摘要与搜索开窗
/// 各自只截取需要的那一段。
class DiaryLeadingLine {
  const DiaryLeadingLine._(this.line, this.restStart);

  /// 拆出 [text] 的第一行；正文没有任何文字（空、全是空白或只有媒体）时为
  /// null。[maxLength] 限制第一行的长度：整篇只有一个长段落时，标题只显示
  /// 一两行，不必为它保留与排版整段文字。
  static DiaryLeadingLine? of(String text, {int? maxLength}) {
    var start = 0;
    while (start < text.length) {
      var end = text.indexOf('\n', start);
      if (end < 0) {
        end = text.length;
      }
      var raw = text.substring(start, end).trimLeft();
      if (raw.isNotEmpty) {
        if (maxLength != null && raw.length > maxLength) {
          raw = raw.substring(0, maxLength);
        }
        return DiaryLeadingLine._(
          raw.replaceAll(_whitespace, ' ').trim(),
          end < text.length ? end + 1 : text.length,
        );
      }
      start = end + 1;
    }
    return null;
  }

  static final RegExp _whitespace = RegExp(r'\s+');

  /// 单行化的第一行，非空。
  final String line;

  /// 第一行之后的剩余文本在原文中的起点（第一行就是最后一行时为原文长度）。
  final int restStart;

  /// [text]（须为拆分时的同一段原文）去掉第一行后的剩余部分。
  String restOf(String text) => text.substring(restStart);
}
