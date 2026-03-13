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
    this.weatherText,
    this.size = 16,
    this.fallbackIcon = FontAwesomeIcons.cloudSun,
    this.fallbackColor,
    this.semanticLabel = '天气图标',
  });

  static const String _iconBaseUrl = 'https://icons.qweather.com/assets/icons';

  final String? iconCode;
  final String? weatherText;
  final double size;
  final IconData fallbackIcon;
  final Color? fallbackColor;
  final String semanticLabel;

  // 关键词推断规则（按优先级排序）：
  // 先匹配灾害/强天气，再匹配普通天气，避免“雷阵雨”被“雨”提前吞掉。
  static final List<_WeatherKeywordRule> _keywordRules = <_WeatherKeywordRule>[
    _WeatherKeywordRule(pattern: RegExp(r'(雷|thunder|storm)', caseSensitive: false), code: '302'),
    _WeatherKeywordRule(pattern: RegExp(r'(雪|sleet|hail|snow)', caseSensitive: false), code: '400'),
    _WeatherKeywordRule(pattern: RegExp(r'(雾|霾|fog|mist|haze)', caseSensitive: false), code: '500'),
    _WeatherKeywordRule(pattern: RegExp(r'(雨|rain|shower|drizzle)', caseSensitive: false), code: '305'),
    _WeatherKeywordRule(pattern: RegExp(r'(晴|sunny|c|partly)', caseSensitive: false), code: '101'),
    _WeatherKeywordRule(pattern: RegExp(r'(阴|overcalear)', caseSensitive: false), code: '100'),
    _WeatherKeywordRule(pattern: RegExp(r'(多云|cloudyst)', caseSensitive: false), code: '104'),
    _WeatherKeywordRule(pattern: RegExp(r'(风|wind|breeze|gale)', caseSensitive: false), code: '300'),
  ];

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

  /// 基于天气文案关键词推断和风 icon code（中英双语）。
  static String? inferIconCodeFromWeatherText(String? rawWeatherText) {
    final normalized =
        rawWeatherText?.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    for (final rule in _keywordRules) {
      if (rule.pattern.hasMatch(normalized)) {
        return rule.code;
      }
    }
    return null;
  }

  /// 统一解析最终 icon code：优先使用显式 code，再回退关键词推断。
  static String? resolveIconCode({String? iconCode, String? weatherText}) {
    final normalizedCode = normalizeIconCode(iconCode);
    if (normalizedCode != null) {
      return normalizedCode;
    }
    return inferIconCodeFromWeatherText(weatherText);
  }

  static String? iconUrl(String? code, {String? weatherText}) {
    final resolved = resolveIconCode(iconCode: code, weatherText: weatherText);
    if (resolved == null) {
      return null;
    }
    return '$_iconBaseUrl/$resolved.svg';
  }

  @override
  Widget build(BuildContext context) {
    final url = iconUrl(iconCode, weatherText: weatherText);
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

class _WeatherKeywordRule {
  const _WeatherKeywordRule({required this.pattern, required this.code});

  final RegExp pattern;
  final String code;
}
