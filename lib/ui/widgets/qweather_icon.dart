import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 和风天气图标组件。
///
/// 图标来源：`https://icons.qweather.com/assets/icons/{iconCode}.svg`
/// 兼容策略：
/// - 旧数据没有 iconCode 时，自动回退到 `999`（未知天气）；
/// - 网络加载失败时，底层保留默认 FontAwesome 图标兜底。
class QWeatherIcon extends StatelessWidget {
  const QWeatherIcon({
    super.key,
    this.iconCode,
    this.size = 16,
    this.fallbackIcon = FontAwesomeIcons.cloudSun,
    this.fallbackColor,
    this.semanticLabel = '天气图标',
  });

  static const String defaultIconCode = '999';
  static const String _iconBaseUrl = 'https://icons.qweather.com/assets/icons';

  final String? iconCode;
  final double size;
  final IconData fallbackIcon;
  final Color? fallbackColor;
  final String semanticLabel;

  /// 统一规整 icon code，避免把空串或非法值拼到 URL。
  static String normalizeIconCode(String? rawCode) {
    final normalized = rawCode?.trim();
    if (normalized == null || normalized.isEmpty) {
      return defaultIconCode;
    }
    final valid = RegExp(r'^\d{3,4}$').hasMatch(normalized);
    return valid ? normalized : defaultIconCode;
  }

  static String iconUrl(String? code) {
    final normalized = normalizeIconCode(code);
    return '$_iconBaseUrl/$normalized.svg';
  }

  @override
  Widget build(BuildContext context) {
    final url = iconUrl(iconCode);
    final fallbackIconColor = fallbackColor ?? Theme.of(context).colorScheme.onSurfaceVariant;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Center(
            child: FaIcon(
              fallbackIcon,
              size: size * 0.86,
              color: fallbackIconColor,
            ),
          ),
          SvgPicture.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.contain,
            semanticsLabel: semanticLabel,
          ),
        ],
      ),
    );
  }
}
