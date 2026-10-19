import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_effects.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../../core/database/app_database.dart';
import '../../widgets/expressive_state_blend.dart';
import '../models/notebook_icon.dart';
import '../viewmodels/notebook_labels.dart';
import '../viewmodels/notebook_view.dart';
import 'notebook_cover_parts.dart';

enum _TileVariant { full, mini, create }

/// 日记本封面：书架网格、收录选择器与编辑页预览共用。
///
/// - 默认：3:4 的封面卡片。底色为强调色经主题换算后的容器色（见
///   [notebookAccentColors]），有封面图时图片铺满上部，下方为名称与篇数；
///   右上角按状态显示一个角标（上锁 / 隐藏 / 智能）；[selected] 时描边补间到
///   2dp primary，[closed] 时整体 0.6 不透明度；
/// - [NotebookCoverTile.mini]：44×56 的小封面，列表行左侧用，不含文字；
/// - [NotebookCoverTile.create]：描边的“＋ 新建日记本”格子，放在网格末尾。
///
/// 只负责展示与回调；点按墨水层叠在内容之上（DESIGN.md §4.3），封面图不会
/// 盖住水波纹。
class NotebookCoverTile extends StatelessWidget {
  const NotebookCoverTile({
    super.key,
    required String this.name,
    required this.icon,
    this.color,
    this.coverPath,
    this.count,
    this.kind = NotebookKind.manual,
    this.visibility = NotebookVisibility.normal,
    this.selected = false,
    this.closed = false,
    this.onTap,
    this.onLongPress,
  }) : _variant = _TileVariant.full;

  /// 列表行左侧的小封面（44×56，无文字、无角标）。
  const NotebookCoverTile.mini({
    super.key,
    required this.icon,
    this.color,
    this.coverPath,
    this.closed = false,
  }) : _variant = _TileVariant.mini,
       name = null,
       count = null,
       kind = NotebookKind.manual,
       visibility = NotebookVisibility.normal,
       selected = false,
       onTap = null,
       onLongPress = null;

  /// 网格末尾的“＋ 新建日记本”格子。
  const NotebookCoverTile.create({super.key, required this.onTap})
    : _variant = _TileVariant.create,
      name = null,
      icon = NotebookIcon.fallback,
      color = null,
      coverPath = null,
      count = null,
      kind = NotebookKind.manual,
      visibility = NotebookVisibility.normal,
      selected = false,
      closed = false,
      onLongPress = null;

  /// 由 [NotebookView] 构造默认封面。
  factory NotebookCoverTile.fromView(
    NotebookView notebook, {
    Key? key,
    int? count,
    bool selected = false,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) => NotebookCoverTile(
    key: key,
    name: notebook.name,
    icon: notebook.icon,
    color: notebook.color,
    coverPath: notebook.coverPath,
    count: count,
    kind: notebook.kind,
    visibility: notebook.visibility,
    selected: selected,
    closed: notebook.isClosed,
    onTap: onTap,
    onLongPress: onLongPress,
  );

  static const double radius = 20;
  static const double aspectRatio = 3 / 4;

  final _TileVariant _variant;
  final String? name;
  final NotebookIcon icon;

  /// 强调色种子（ARGB），null 跟随主题色。
  final int? color;
  final String? coverPath;

  /// 篇数；null 时不显示篇数行。
  final int? count;
  final NotebookKind kind;
  final NotebookVisibility visibility;
  final bool selected;
  final bool closed;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) => switch (_variant) {
    _TileVariant.full => _buildFull(context),
    _TileVariant.mini => _buildMini(context),
    _TileVariant.create => NotebookCreateTile(onTap: onTap),
  };

  Widget _buildFull(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final accent = notebookAccentColors(color, scheme);
    final badge = notebookBadgeFor(kind, visibility);
    final borderRadius = BorderRadius.circular(radius);
    final semantics = <String>[
      name!,
      if (count != null) l10n.notebookEntryCount(count!),
      if (badge != null) notebookBadgeLabel(l10n, badge),
      if (closed) l10n.notebookStateClosed,
    ].join(l10n.notebookSemanticsSeparator);
    final surface = Material(
      color: accent.container,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          NotebookCoverBody(
            name: name!,
            icon: icon,
            accent: accent,
            coverPath: coverPath,
            countLabel: count == null ? null : l10n.notebookEntryCount(count!),
          ),
          if (badge != null)
            PositionedDirectional(
              top: 8,
              end: 8,
              child: NotebookStateBadge(badge: badge),
            ),
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: onTap, onLongPress: onLongPress),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: semantics,
      excludeSemantics: true,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Opacity(
        opacity: closed ? 0.6 : 1,
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: ExpressiveStateBlend(
            active: selected,
            child: surface,
            builder: (BuildContext context, double t, Widget? child) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  boxShadow: AppEffects.restingCardShadow(scheme),
                ),
                // 描边画在前景：底下的 Material 是不透明的，背景描边会被盖住。
                foregroundDecoration: BoxDecoration(
                  borderRadius: borderRadius,
                  border: Border.all(
                    color: Color.lerp(
                      ExpressiveSurfaces.cardBorderColor(scheme),
                      scheme.primary,
                      t,
                    )!,
                    width: 0.8 + 1.2 * t,
                  ),
                ),
                child: child,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMini(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = notebookAccentColors(color, scheme);
    final borderRadius = BorderRadius.circular(10);
    final cover = coverPath;
    return ExcludeSemantics(
      child: Opacity(
        opacity: closed ? 0.6 : 1,
        child: Container(
          width: 44,
          height: 56,
          decoration: BoxDecoration(
            color: accent.container,
            borderRadius: borderRadius,
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.fromBorderSide(
              ExpressiveSurfaces.cardBorderSide(scheme),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Center(
                child: FaIcon(icon.data, size: 18, color: accent.onContainer),
              ),
              if (cover != null) NotebookCoverImage(path: cover, width: 44),
            ],
          ),
        ),
      ),
    );
  }
}
