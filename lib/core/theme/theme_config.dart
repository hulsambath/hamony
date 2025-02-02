import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:harmony/core/constants/app_constants.dart';

class ThemeConfig {
  static Color brandColor = Color(
    int.parse(AppConstants.brandColor.replaceFirst('#', 'FF'), radix: 16),
  );

  final bool isDarkMode;

  ThemeConfig(this.isDarkMode);

  ThemeConfig.fromDarkMode(this.isDarkMode);

  final lightScheme = ColorScheme.fromSeed(
    seedColor: brandColor,
    brightness: Brightness.light,
  ).copyWith(
    primary: brandColor,
  );

  final darkScheme = ColorScheme.fromSeed(
    seedColor: brandColor,
    brightness: Brightness.dark,
  ).copyWith(
    primary: brandColor,
  );

  factory ThemeConfig.light() {
    return ThemeConfig.fromDarkMode(false);
  }

  factory ThemeConfig.dark() {
    return ThemeConfig.fromDarkMode(true);
  }

  ThemeData get themeData {
    ThemeData themeData = isDarkMode ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
    ColorScheme colorScheme = isDarkMode ? darkScheme : lightScheme;

    TargetPlatform platform = defaultTargetPlatform;

    return themeData.copyWith(
      brightness: colorScheme.brightness,
      primaryColor: colorScheme.primary,
      primaryColorDark: darkScheme.primaryContainer,
      primaryColorLight: lightScheme.primaryContainer,
      scaffoldBackgroundColor: colorScheme.surface,
      colorScheme: colorScheme,
      platform: platform,
      splashFactory: splashFactory(platform),
      textButtonTheme: TextButtonThemeData(
        style: (themeData.textButtonTheme.style ?? const ButtonStyle()).copyWith(
          splashFactory: splashFactory(themeData.platform),
        ),
      ),
    );
  }

  static InteractiveInkFeatureFactory splashFactory(TargetPlatform platform) {
    return isApple(platform) ? NoSplash.splashFactory : InkSparkle.splashFactory;
  }

  static bool isApple(TargetPlatform platform) {
    switch (platform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return false;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
    }
  }
}
