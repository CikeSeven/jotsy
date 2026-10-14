import 'dart:ui' as ui show Image;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderImage;

import '../../app/theme/expressive_motion.dart';

/// 看图页共享元素转场（缩略图/正文图/头图 ↔ 看图页）的公共部分。
///
/// 两端都是同一张图，但来源处多为裁切的缩略图或带圆角的块，看图页是完整原图：
/// - 看图页把 Hero 包在“原图比例”的盒子里（Center + AspectRatio），两端画面都按
///   cover 铺满各自的盒子：缩略图端是裁切的方块，看图页端恰好是完整画面，飞行
///   途中盒子比例连续变化，画面从裁切平滑展开成全图，没有落地瞬间的跳变；
/// - 飞行与原图解码完成前显示来源处已解码的画面（[ImageViewerHero.placeholder]），
///   不会先空白再淡入；
/// - 两端统一直线飞行（MaterialApp 默认的弧线会让照片绕一道弯），圆角在飞行中
///   从来源端圆角补间到目标端圆角（见 [ImageHero]）；
/// - 系统开启“减少动态效果”时不建立 Hero，按无动画路由直接打开。

/// 共享元素标签：来源区域 + 区域内唯一标识。同一张图可能在一页里出现多次
/// （如未设封面时封面就是正文首图），只按图片地址做标签会冲突。
@immutable
class ImageViewerHeroTag {
  const ImageViewerHeroTag(this.scope, this.id);

  final String scope;
  final Object id;

  @override
  bool operator ==(Object other) =>
      other is ImageViewerHeroTag && other.scope == scope && other.id == id;

  @override
  int get hashCode => Object.hash(scope, id);

  @override
  String toString() => 'ImageViewerHeroTag($scope, $id)';
}

/// 日记头图的共享元素标签：列表封面 ↔ 预览页头图 ↔ 看图页共用。
Object diaryCoverHeroTag(String diaryId) =>
    ImageViewerHeroTag('diary_cover', diaryId);

/// 从来源图片飞入目标页所需的信息（看图页初始页、预览页头图）。
///
/// [placeholder] 是来源处已绘制画面的克隆句柄，所有权随对象转交给目标页，
/// 由它在销毁时调用 [dispose]。
class ImageViewerHero {
  ImageViewerHero._({required this.tag, required this.placeholder});

  final Object tag;
  final ui.Image placeholder;

  /// 画面宽高比；缩略图按原比例解码，与原图一致。
  double get aspectRatio => placeholder.width / placeholder.height;

  void dispose() => placeholder.dispose();

  /// 在 [context] 的渲染子树里找到第一张已绘制的图片并克隆其画面。
  ///
  /// 图片尚未解码、加载失败，或系统开启“减少动态效果”时返回 null，调用方按
  /// 普通方式打开。点按时调用：此刻画面一定是用户看到的那一张。
  static ImageViewerHero? capture(BuildContext context, {required Object tag}) {
    if (ExpressiveMotion.reduceMotion(context)) {
      return null;
    }
    final root = context.findRenderObject();
    if (root == null) {
      return null;
    }
    ui.Image? found;
    void visit(RenderObject node) {
      if (found != null) {
        return;
      }
      if (node is RenderImage && node.image != null) {
        found = node.image;
        return;
      }
      node.visitChildren(visit);
    }

    visit(root);
    final image = found;
    if (image == null || image.width == 0 || image.height == 0) {
      return null;
    }
    return ImageViewerHero._(tag: tag, placeholder: image.clone());
  }
}

/// 记录来源画面所在的 context，供点按时抓取共享元素画面。
///
/// 点按区域往往大于画面本身（整张卡片都可点），抓取必须针对画面所在的子树，
/// 而不是点按处的 context。画面所在处用 Builder 写入 [context]；来源不存在
/// （如卡片没有封面）时保持 null，[capture] 返回 null。
class ImageViewerHeroAnchor {
  BuildContext? context;

  ImageViewerHero? capture({required Object tag}) {
    final anchorContext = context;
    if (anchorContext == null || !anchorContext.mounted) {
      return null;
    }
    return ImageViewerHero.capture(anchorContext, tag: tag);
  }
}

RectTween _straightRectTween(Rect? begin, Rect? end) =>
    RectTween(begin: begin, end: end);

/// 图片共享元素统一使用的 Hero：额外携带本端画面的可见圆角 [borderRadius]。
///
/// 飞行画面由 [_imageHeroShuttle] 统一绘制，两端都是同一张图：
/// - 内容取“上层路由”那一端的子树（看图页的原图、预览页的头图），它的盒子
///   就是原图比例，按 cover 铺满时从裁切的缩略图连续展开成全图；
/// - 圆角按路由动画在“下层端圆角 → 上层端圆角”之间逐角补间，push 与 pop
///   同一公式（pop 时动画从 1 倒放到 0）；四角可以不同，如瀑布流卡片顶部的
///   封面只有上方两角被卡片裁圆，起飞时不会先变成方角；
/// - 统一直线飞行（MaterialApp 默认的弧线会让照片绕一道弯）。
class ImageHero extends Hero {
  const ImageHero({
    super.key,
    required super.tag,
    required super.child,
    this.borderRadius = BorderRadius.zero,
  }) : super(
         createRectTween: _straightRectTween,
         flightShuttleBuilder: _imageHeroShuttle,
         curve: ExpressiveMotion.effects,
       );

  final BorderRadius borderRadius;
}

Widget _imageHeroShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final push = direction == HeroFlightDirection.push;
  final lower = (push ? fromHeroContext : toHeroContext).widget;
  final upper = (push ? toHeroContext : fromHeroContext).widget as Hero;
  final lowerRadius = lower is ImageHero
      ? lower.borderRadius
      : BorderRadius.zero;
  final upperRadius = upper is ImageHero
      ? upper.borderRadius
      : BorderRadius.zero;
  return AnimatedBuilder(
    animation: animation,
    child: upper.child,
    builder: (BuildContext context, Widget? child) {
      return ClipRRect(
        borderRadius: BorderRadius.lerp(
          lowerRadius,
          upperRadius,
          animation.value,
        )!,
        child: child,
      );
    },
  );
}

/// 来源端的 Hero：画面仍是来源自己的图片，[borderRadius] 为其可见圆角（含
/// 外层容器裁切出的圆角）。
///
/// 减少动画时不建立 Hero，避免在无动画路由下仍触发飞行。
class ImageViewerHeroSource extends StatelessWidget {
  const ImageViewerHeroSource({
    super.key,
    required this.tag,
    required this.child,
    this.borderRadius = BorderRadius.zero,
  });

  final Object? tag;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final heroTag = tag;
    if (heroTag == null || ExpressiveMotion.reduceMotion(context)) {
      return child;
    }
    return ImageHero(tag: heroTag, borderRadius: borderRadius, child: child);
  }
}

/// 看图页端的 Hero：在原图比例的盒子里叠放“来源画面 + 原图”，原图解码完成后
/// 淡入覆盖来源画面。
class ImageViewerHeroTarget extends StatelessWidget {
  const ImageViewerHeroTarget({
    super.key,
    required this.hero,
    required this.fullImage,
  });

  final ImageViewerHero hero;

  /// 以 cover 铺满盒子的原图（盒子比例即原图比例，cover 不会裁切）。
  final Widget fullImage;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: hero.aspectRatio,
        child: ImageHero(
          tag: hero.tag,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              RawImage(image: hero.placeholder, fit: BoxFit.cover),
              fullImage,
            ],
          ),
        ),
      ),
    );
  }
}
