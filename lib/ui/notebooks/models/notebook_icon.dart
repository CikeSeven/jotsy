import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// 日记本可选的图标。按 [Enum.name] 存进 `NotebookPayload.icon`，名字一经
/// 发布就不能改（改了旧数据会回退成默认图标）；新增图标只往后加。
enum NotebookIcon {
  book(FontAwesomeIcons.book),
  bookOpen(FontAwesomeIcons.bookOpen),
  plane(FontAwesomeIcons.plane),
  suitcase(FontAwesomeIcons.suitcase),
  mountainSun(FontAwesomeIcons.mountainSun),
  umbrellaBeach(FontAwesomeIcons.umbrellaBeach),
  heart(FontAwesomeIcons.solidHeart),
  baby(FontAwesomeIcons.baby),
  paw(FontAwesomeIcons.paw),
  house(FontAwesomeIcons.house),
  briefcase(FontAwesomeIcons.briefcase),
  graduationCap(FontAwesomeIcons.graduationCap),
  pen(FontAwesomeIcons.pen),
  lightbulb(FontAwesomeIcons.solidLightbulb),
  utensils(FontAwesomeIcons.utensils),
  mugHot(FontAwesomeIcons.mugHot),
  music(FontAwesomeIcons.music),
  film(FontAwesomeIcons.film),
  camera(FontAwesomeIcons.camera),
  palette(FontAwesomeIcons.palette),
  dumbbell(FontAwesomeIcons.dumbbell),
  personRunning(FontAwesomeIcons.personRunning),
  seedling(FontAwesomeIcons.seedling),
  leaf(FontAwesomeIcons.leaf),
  moon(FontAwesomeIcons.solidMoon),
  sun(FontAwesomeIcons.solidSun),
  star(FontAwesomeIcons.solidStar),
  gift(FontAwesomeIcons.gift),
  cakeCandles(FontAwesomeIcons.cakeCandles),
  stethoscope(FontAwesomeIcons.stethoscope),
  wallet(FontAwesomeIcons.wallet),
  gamepad(FontAwesomeIcons.gamepad);

  const NotebookIcon(this.data);

  final FaIconData data;

  /// 默认图标：未设置或认不出的名字（损坏数据、更新版本新增的图标）都用它。
  static const NotebookIcon fallback = book;

  /// 快速新建弹窗里先露出的几个常用图标，其余在“更多”里展开。
  static const List<NotebookIcon> common = <NotebookIcon>[
    book,
    plane,
    heart,
    briefcase,
    baby,
    pen,
  ];

  static NotebookIcon fromName(String? name) =>
      values.asNameMap()[name] ?? fallback;
}
