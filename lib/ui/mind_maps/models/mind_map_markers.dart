import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// 节点上的图标贴纸（存在节点的 `icons` 里，值为 `分组:取值`）。
///
/// 同一分组在一个节点上只放一个（换一个即替换，与常见导图软件一致）；
/// `emoji:` 可放任意 emoji、可以有多个。认不出的取值不显示，但原样保留。

/// 贴纸分组。
enum MindMapMarkerGroup {
  priority('priority'),
  progress('progress'),
  flag('flag'),
  star('star'),
  face('face'),
  symbol('symbol'),
  emoji('emoji');

  const MindMapMarkerGroup(this.id);

  final String id;

  /// 同组只能有一个的分组（emoji 可以有多个）。
  bool get exclusive => this != MindMapMarkerGroup.emoji;
}

/// 贴纸用的六种颜色（固定种子，按明暗换算后使用，见 `MindMapPalette`）。
enum MindMapMarkerColor {
  red(0xFFD32F2F),
  orange(0xFFF57C00),
  yellow(0xFFF9A825),
  green(0xFF2E7D32),
  blue(0xFF1565C0),
  purple(0xFF7B1FA2);

  const MindMapMarkerColor(this.seed);

  final int seed;
}

/// 贴纸的画法。
sealed class MindMapMarkerLook {
  const MindMapMarkerLook();
}

/// 实心圆 + 数字（优先级）。
final class MindMapNumberLook extends MindMapMarkerLook {
  const MindMapNumberLook(this.number, this.color);

  final int number;
  final MindMapMarkerColor color;
}

/// 进度饼（0–100）。
final class MindMapProgressLook extends MindMapMarkerLook {
  const MindMapProgressLook(this.percent);

  final int percent;
}

/// Font Awesome 字形。
final class MindMapGlyphLook extends MindMapMarkerLook {
  const MindMapGlyphLook(this.icon, this.color);

  final FaIconData icon;
  final MindMapMarkerColor color;
}

/// emoji 文字。
final class MindMapEmojiLook extends MindMapMarkerLook {
  const MindMapEmojiLook(this.emoji);

  final String emoji;
}

/// 一个贴纸。
final class MindMapMarker {
  const MindMapMarker(this.group, this.value, this.look);

  final MindMapMarkerGroup group;
  final String value;
  final MindMapMarkerLook look;

  String get id => '${group.id}:$value';

  /// 解析存储的 id；认不出时为 null。
  static MindMapMarker? parse(String id) {
    final split = id.indexOf(':');
    if (split <= 0) return null;
    final group = id.substring(0, split);
    final value = id.substring(split + 1);
    if (group == MindMapMarkerGroup.emoji.id) {
      return value.isEmpty
          ? null
          : MindMapMarker(
              MindMapMarkerGroup.emoji,
              value,
              MindMapEmojiLook(value),
            );
    }
    for (final marker in catalog) {
      if (marker.id == id) return marker;
    }
    return null;
  }

  /// 面板里可选的全部贴纸（emoji 另由输入添加）。
  static final List<MindMapMarker> catalog = <MindMapMarker>[
    for (var i = 1; i <= 6; i++)
      MindMapMarker(
        MindMapMarkerGroup.priority,
        '$i',
        MindMapNumberLook(i, MindMapMarkerColor.values[i - 1]),
      ),
    for (final percent in const <int>[0, 25, 50, 75, 100])
      MindMapMarker(
        MindMapMarkerGroup.progress,
        '$percent',
        MindMapProgressLook(percent),
      ),
    for (final color in MindMapMarkerColor.values)
      MindMapMarker(
        MindMapMarkerGroup.flag,
        color.name,
        MindMapGlyphLook(FontAwesomeIcons.solidFlag, color),
      ),
    for (final color in MindMapMarkerColor.values)
      MindMapMarker(
        MindMapMarkerGroup.star,
        color.name,
        MindMapGlyphLook(FontAwesomeIcons.solidStar, color),
      ),
    for (final (value, emoji) in const <(String, String)>[
      ('smile', '😀'),
      ('laugh', '😂'),
      ('love', '😍'),
      ('think', '🤔'),
      ('surprise', '😮'),
      ('sad', '😢'),
      ('angry', '😠'),
      ('cool', '😎'),
    ])
      MindMapMarker(MindMapMarkerGroup.face, value, MindMapEmojiLook(emoji)),
    MindMapMarker(
      MindMapMarkerGroup.symbol,
      'check',
      const MindMapGlyphLook(
        FontAwesomeIcons.solidCircleCheck,
        MindMapMarkerColor.green,
      ),
    ),
    MindMapMarker(
      MindMapMarkerGroup.symbol,
      'cross',
      const MindMapGlyphLook(
        FontAwesomeIcons.solidCircleXmark,
        MindMapMarkerColor.red,
      ),
    ),
    MindMapMarker(
      MindMapMarkerGroup.symbol,
      'question',
      const MindMapGlyphLook(
        FontAwesomeIcons.solidCircleQuestion,
        MindMapMarkerColor.blue,
      ),
    ),
    MindMapMarker(
      MindMapMarkerGroup.symbol,
      'exclaim',
      const MindMapGlyphLook(
        FontAwesomeIcons.circleExclamation,
        MindMapMarkerColor.orange,
      ),
    ),
    MindMapMarker(
      MindMapMarkerGroup.symbol,
      'idea',
      const MindMapGlyphLook(
        FontAwesomeIcons.solidLightbulb,
        MindMapMarkerColor.yellow,
      ),
    ),
    MindMapMarker(
      MindMapMarkerGroup.symbol,
      'heart',
      const MindMapGlyphLook(
        FontAwesomeIcons.solidHeart,
        MindMapMarkerColor.red,
      ),
    ),
  ];

  /// 把 [marker] 加到 [icons]（同组互斥的先去掉同组的旧值）；已经有了就去掉
  /// （再点一次取消）。
  static List<String> toggle(List<String> icons, MindMapMarker marker) {
    if (icons.contains(marker.id)) {
      return <String>[
        for (final id in icons)
          if (id != marker.id) id,
      ];
    }
    final prefix = '${marker.group.id}:';
    return <String>[
      for (final id in icons)
        if (!marker.group.exclusive || !id.startsWith(prefix)) id,
      marker.id,
    ];
  }
}
