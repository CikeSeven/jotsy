import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 和风天气图标组件。
///
/// 图标来源：`assets/weather_icons/qweather/{iconCode}.svg`
/// 兼容策略：
/// - 旧数据没有 iconCode 时，直接回退到默认 FontAwesome 天气图标；
/// - 本地图标缺失时，使用默认 FontAwesome 图标兜底。
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

  static const String _iconAssetBasePath = 'assets/weather_icons/qweather';

  final String? iconCode;
  final String? weatherText;
  final double size;
  final IconData fallbackIcon;
  final Color? fallbackColor;
  final String semanticLabel;

  static final RegExp _nightPattern = RegExp(
    r'(夜|夜间|night|tonight|evening)',
    caseSensitive: false,
  );

  static const Map<String, String> _nightVariantCodeMap = <String, String>{
    '100': '150',
    '101': '151',
    '102': '152',
    '103': '153',
    '300': '350',
    '301': '351',
    '406': '456',
    '407': '457',
  };

  // 关键词推断规则（按优先级排序）：
  // 从“更具体”的天气文案开始匹配，避免被通用关键词提前命中。
  static final List<_WeatherKeywordRule> _keywordRules = <_WeatherKeywordRule>[
    _WeatherKeywordRule(
      pattern: RegExp(
        r'(大暴雨到特大暴雨|heavy to severe storm)',
        caseSensitive: false,
      ),
      code: '318',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(
        r'(暴雨到大暴雨|storm to heavy storm)',
        caseSensitive: false,
      ),
      code: '317',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(
        r'(大到暴雨|heavy rain to storm)',
        caseSensitive: false,
      ),
      code: '316',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(
        r'(中到大雨|moderate to heavy rain)',
        caseSensitive: false,
      ),
      code: '315',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(
        r'(小到中雨|light to moderate rain)',
        caseSensitive: false,
      ),
      code: '314',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(
        r'(雷阵雨伴有冰雹|thundershower with hail)',
        caseSensitive: false,
      ),
      code: '304',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(
        r'(强雷阵雨|heavy thunderstorm)',
        caseSensitive: false,
      ),
      code: '303',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(
        r'(雷阵雨|thundershower|thunderstorm)',
        caseSensitive: false,
      ),
      code: '302',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(
        r'(强阵雨|heavy shower rain)',
        caseSensitive: false,
      ),
      code: '301',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(
        r'(?<!强)(阵雨|shower rain)',
        caseSensitive: false,
      ),
      code: '300',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(特大暴雨|\bsevere storm\b)', caseSensitive: false),
      code: '312',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(大暴雨|\bheavy storm\b)', caseSensitive: false),
      code: '311',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(暴雨|\bstorm\b)', caseSensitive: false),
      code: '310',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(毛毛雨|细雨|drizzle rain)', caseSensitive: false),
      code: '309',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(极端降雨|extreme rain)', caseSensitive: false),
      code: '308',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(大雨|heavy rain)', caseSensitive: false),
      code: '307',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(中雨|moderate rain)', caseSensitive: false),
      code: '306',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(小雨|light rain)', caseSensitive: false),
      code: '305',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(冻雨|freezing rain)', caseSensitive: false),
      code: '313',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(
        r'(大到暴雪|heavy snow to snowstorm)',
        caseSensitive: false,
      ),
      code: '410',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(
        r'(中到大雪|moderate to heavy snow)',
        caseSensitive: false,
      ),
      code: '409',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(
        r'(小到中雪|light to moderate snow)',
        caseSensitive: false,
      ),
      code: '408',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(雨雪天气|rain and snow)', caseSensitive: false),
      code: '405',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(阵雨夹雪|shower snow)', caseSensitive: false),
      code: '406',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(阵雪|snow flurry)', caseSensitive: false),
      code: '407',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(雨夹雪|sleet)', caseSensitive: false),
      code: '404',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(暴雪|snowstorm)', caseSensitive: false),
      code: '403',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(大雪|heavy snow)', caseSensitive: false),
      code: '402',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(中雪|moderate snow)', caseSensitive: false),
      code: '401',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(小雪|light snow)', caseSensitive: false),
      code: '400',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(特强浓雾)', caseSensitive: false),
      code: '515',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(强浓雾)', caseSensitive: false),
      code: '510',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(浓雾)', caseSensitive: false),
      code: '509',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(大雾)', caseSensitive: false),
      code: '514',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(薄雾|mist)', caseSensitive: false),
      code: '500',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(?<!薄)雾|fog', caseSensitive: false),
      code: '501',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(严重霾)', caseSensitive: false),
      code: '513',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(重度霾)', caseSensitive: false),
      code: '512',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(中度霾)', caseSensitive: false),
      code: '511',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(霾|haze|smog)', caseSensitive: false),
      code: '502',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(强沙尘暴|duststorm)', caseSensitive: false),
      code: '508',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(沙尘暴|sandstorm)', caseSensitive: false),
      code: '507',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(扬沙|sand)', caseSensitive: false),
      code: '503',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(浮尘|dust)', caseSensitive: false),
      code: '504',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(晴间多云|partly cloudy)', caseSensitive: false),
      code: '103',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(少云|few clouds?)', caseSensitive: false),
      code: '102',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(多云|cloudy)', caseSensitive: false),
      code: '101',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(阴|overcast)', caseSensitive: false),
      code: '104',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(晴|sunny|clear)', caseSensitive: false),
      code: '100',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(热|hot)', caseSensitive: false),
      code: '900',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(冷|cold)', caseSensitive: false),
      code: '901',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(雪|snow)', caseSensitive: false),
      code: '499',
    ),
    _WeatherKeywordRule(
      pattern: RegExp(r'(雨|rain)', caseSensitive: false),
      code: '399',
    ),
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
    final normalized = rawWeatherText
        ?.toLowerCase()
        .replaceAll(RegExp(r'[-+]?\d+(?:\.\d+)?\s*(?:°c|°f|℃|℉)?'), ' ')
        .replaceAll(RegExp(r'[|/,，。;；]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    final isNight = _nightPattern.hasMatch(normalized);
    for (final rule in _keywordRules) {
      if (rule.pattern.hasMatch(normalized)) {
        if (!isNight) {
          return rule.code;
        }
        return _nightVariantCodeMap[rule.code] ?? rule.code;
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
    return '$_iconAssetBasePath/$resolved.svg';
  }

  @override
  Widget build(BuildContext context) {
    final assetPath = iconUrl(iconCode, weatherText: weatherText);
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

    if (assetPath == null) {
      return SizedBox(width: size, height: size, child: buildFallbackIcon());
    }

    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        assetPath,
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
