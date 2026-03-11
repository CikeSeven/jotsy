import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 和风天气图标组件。
///
/// 图标来源：`https://icons.qweather.com/assets/icons/{iconCode}.svg`
/// 兼容策略：
/// - 旧数据没有 iconCode 时，直接回退到默认 FontAwesome 天气图标；
/// - 网络加载失败时，使用默认 FontAwesome 图标兜底。
class QWeatherIcon extends StatelessWidget {
  const QWeatherIcon({
    super.key,
    this.iconCode,
    this.size = 16,
    this.fallbackIcon = FontAwesomeIcons.cloudSun,
    this.fallbackColor,
    this.semanticLabel = '天气图标',
  });

  static const String _iconBaseUrl = 'https://icons.qweather.com/assets/icons';

  final String? iconCode;
  final double size;
  final IconData fallbackIcon;
  final Color? fallbackColor;
  final String semanticLabel;

  /// 统一规整 icon code，避免把空串或非法值拼到 URL。
  ///
  /// 返回 `null` 表示当前没有可用的和风图标编码，应直接走默认图标。
  static String? normalizeIconCode(String? rawCode) {
    final normalized = rawCode?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    final valid = RegExp(r'^\d{3,4}$').hasMatch(normalized);
    return valid ? normalized : null;
  }

  static String? iconUrl(String? code) {
    final normalized = normalizeIconCode(code);
    if (normalized == null) {
      return null;
    }
    return '$_iconBaseUrl/$normalized.svg';
  }

  @override
  Widget build(BuildContext context) {
    final url = iconUrl(iconCode);
    final fallbackIconColor = fallbackColor ?? Theme.of(context).colorScheme.onSurfaceVariant;

    Widget buildFallbackIcon() {
      return Center(
        child: FaIcon(
          fallbackIcon,
          size: size * 0.86,
          color: fallbackIconColor,
        ),
      );
    }

    if (url == null) {
      return SizedBox(width: size, height: size, child: buildFallbackIcon());
    }

    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticsLabel: semanticLabel,
        placeholderBuilder: (_) => buildFallbackIcon(),
        errorBuilder: (_, __, ___) => buildFallbackIcon(),
      ),
    );
  }
}
