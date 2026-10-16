import 'package:flutter/foundation.dart';

/// 分享文字里标签的写法。
enum DiaryShareTagStyle {
  /// `#标签`：多数应用（含小红书、微信、QQ）把它当普通文字或话题。
  hashtag,

  /// `#标签#`：微博话题必须首尾都有 `#`，否则不会识别成话题。
  weiboTopic;

  String format(String tagName) => switch (this) {
    DiaryShareTagStyle.hashtag => '#$tagName',
    DiaryShareTagStyle.weiboTopic => '#$tagName#',
  };
}

/// 分享面板里的分享目标。
///
/// 指定应用的目标只在 Android 上、且已安装时出现：原生侧按包名发出
/// `ACTION_SEND(_MULTIPLE)`，应用内有多个分享入口（如微信的“发送给朋友 /
/// 收藏”）时交给系统列出该应用自己的入口。[system] 走系统分享面板，所有
/// 平台都可用。
///
/// 带图分享时，这些应用普遍忽略随图片一起传入的文字（`EXTRA_TEXT`），所以
/// 文字改为复制到剪贴板、由用户在发布页粘贴（Diarium 分享到微博的做法）；
/// 只分享文字时直接把文字发给目标应用。
enum DiaryShareTarget {
  weibo(packageName: 'com.sina.weibo', tagStyle: DiaryShareTagStyle.weiboTopic),
  xiaohongshu(packageName: 'com.xingin.xhs', requiresImages: true),
  wechat(packageName: 'com.tencent.mm'),
  qq(packageName: 'com.tencent.mobileqq'),
  system(packageName: null, maxImages: null);

  const DiaryShareTarget({
    required this.packageName,
    this.maxImages = 9,
    this.tagStyle = DiaryShareTagStyle.hashtag,
    this.requiresImages = false,
  });

  /// 目标应用包名；null 表示系统分享面板。
  final String? packageName;

  /// 单次最多带几张图（微博、小红书、微信、QQ 的发布页都是 9 张）；
  /// null 表示不限制。
  final int? maxImages;

  final DiaryShareTagStyle tagStyle;

  /// 是否必须带图：小红书的分享入口只接收图片或视频，纯文字发不过去。
  final bool requiresImages;

  /// 需要原生侧检测是否安装的应用目标。
  static List<DiaryShareTarget> get appTargets => values
      .where((DiaryShareTarget target) => target.packageName != null)
      .toList(growable: false);
}

/// 分享面板的用户选择，交由预览页执行（执行期间显示动作等待遮罩）。
@immutable
class DiaryShareRequest {
  /// 分享到 [target]：[text] 为空时只发图片，[images] 为空时只发文字。
  const DiaryShareRequest.toTarget(
    DiaryShareTarget this.target, {
    required this.text,
    required this.images,
  }) : action = DiaryShareAction.target;

  /// 只把文字复制到剪贴板。
  const DiaryShareRequest.copyText(this.text)
    : action = DiaryShareAction.copyText,
      target = null,
      images = const <String>[];

  /// 截取预览页生成长图后交给系统分享。
  const DiaryShareRequest.longImage()
    : action = DiaryShareAction.longImage,
      target = null,
      text = '',
      images = const <String>[];

  final DiaryShareAction action;
  final DiaryShareTarget? target;
  final String text;

  /// 已勾选的图片来源（正文中的写法：本地路径、http(s) 或 data URI），按
  /// 面板中的顺序排列，尚未按目标上限截断。
  final List<String> images;
}

enum DiaryShareAction { target, copyText, longImage }
