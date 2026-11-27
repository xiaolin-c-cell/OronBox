import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/core/providers/theme_locale_providers.dart';

enum XiaomiAirQualityBand {
  good,
  moderate,
  unhealthyForSensitiveGroups,
  unhealthy,
  veryUnhealthy,
  hazardous,
  unknown,
}

/// Converts Xiaomi's server-side AQI labels into the labels used by the app.
///
/// The official endpoint currently returns English labels even when the
/// request locale is Chinese. Prefer the numeric AQI when it is available,
/// then fall back to the known labels returned by Xiaomi and other weather
/// endpoints. Localization is kept in ARB files instead of this parser.
class XiaomiAirQualityNormalizer {
  const XiaomiAirQualityNormalizer._();

  static String normalize({
    required int? aqi,
    required String? raw,
    Locale? locale,
  }) {
    final band = bandFor(aqi: aqi, raw: raw);
    if (band == XiaomiAirQualityBand.unknown) return '';

    final l10n = lookupAppLocalizations(locale ?? defaultLocale());
    return switch (band) {
      XiaomiAirQualityBand.good => l10n.weatherAqiGood,
      XiaomiAirQualityBand.moderate => l10n.weatherAqiModerate,
      XiaomiAirQualityBand.unhealthyForSensitiveGroups =>
        l10n.weatherAqiSensitive,
      XiaomiAirQualityBand.unhealthy => l10n.weatherAqiUnhealthy,
      XiaomiAirQualityBand.veryUnhealthy => l10n.weatherAqiVeryUnhealthy,
      XiaomiAirQualityBand.hazardous => l10n.weatherAqiHazardous,
      XiaomiAirQualityBand.unknown => '',
    };
  }

  static XiaomiAirQualityBand bandFor({
    required int? aqi,
    required String? raw,
  }) {
    if (aqi != null && aqi >= 0) return _bandForAqi(aqi);

    final value = raw?.trim().toLowerCase();
    if (value == null || value.isEmpty) return XiaomiAirQualityBand.unknown;

    return switch (value) {
      'good' ||
      'excellent' ||
      '优' ||
      '優' ||
      '優良' ||
      '良好' => XiaomiAirQualityBand.good,
      'moderate' ||
      'fair' ||
      '良' ||
      '中等' ||
      '普通' => XiaomiAirQualityBand.moderate,
      'unhealthy for sensitive groups' ||
      'unhealthy for sensitive group' ||
      '轻度污染' ||
      '輕度污染' => XiaomiAirQualityBand.unhealthyForSensitiveGroups,
      'unhealthy' || '不健康' || '中度污染' => XiaomiAirQualityBand.unhealthy,
      'very unhealthy' ||
      '非常不健康' ||
      '重度污染' => XiaomiAirQualityBand.veryUnhealthy,
      'hazardous' ||
      '危险' ||
      '危險' ||
      '严重污染' ||
      '嚴重污染' => XiaomiAirQualityBand.hazardous,
      'unknown' || 'unknow' || '未知' => XiaomiAirQualityBand.unknown,
      _ => XiaomiAirQualityBand.unknown,
    };
  }

  static Locale defaultLocale() {
    try {
      final configured = LocaleSettings.load().materialLocale;
      return configured ?? PlatformDispatcher.instance.locale;
    } on StateError {
      // Unit tests and early-startup protocol code can run before shared
      // preferences are initialized. Keep the historical Chinese default for
      // those paths, while normal app runs use the configured/system locale.
      return const Locale('zh', 'CN');
    }
  }

  static XiaomiAirQualityBand _bandForAqi(int aqi) {
    if (aqi <= 50) return XiaomiAirQualityBand.good;
    if (aqi <= 100) return XiaomiAirQualityBand.moderate;
    if (aqi <= 150) {
      return XiaomiAirQualityBand.unhealthyForSensitiveGroups;
    }
    if (aqi <= 200) return XiaomiAirQualityBand.unhealthy;
    if (aqi <= 300) return XiaomiAirQualityBand.veryUnhealthy;
    return XiaomiAirQualityBand.hazardous;
  }
}
