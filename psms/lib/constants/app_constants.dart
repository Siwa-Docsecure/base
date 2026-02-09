import 'package:flutter/material.dart';

/// Design System Constants for DocSecure PSMS
/// 
/// This file contains all design tokens including colors, spacing, typography,
/// and other constants used throughout the warehouse UI.

class AppColors {
  // Private constructor to prevent instantiation
  AppColors._();

  // Primary Colors
  static const Color primary = Color(0xFF3498DB);
  static const Color primaryDark = Color(0xFF2980B9);
  static const Color primaryLight = Color(0xFF5DADE2);

  // Secondary Colors
  static const Color success = Color(0xFF27AE60);
  static const Color warning = Color(0xFFF39C12);
  static const Color danger = Color(0xFFE74C3C);
  static const Color info = Color(0xFF3498DB);
  static const Color purple = Color(0xFF9B59B6);

  // Neutral Colors
  static const Color textDark = Color(0xFF2C3E50);
  static const Color textMedium = Color(0xFF7F8C8D);
  static const Color textLight = Color(0xFF95A5A6);
  static const Color background = Color(0xFFF5F6FA);
  static const Color white = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE0E0E0);

  // Semantic Colors
  static const Color boxStored = success;
  static const Color boxRetrieved = info;
  static const Color boxDestroyed = danger;
  static const Color boxPending = warning;

  // UI Element Colors
  static const Color cardBackground = white;
  static const Color sidebarBackground = white;
  static const Color headerBackground = white;
  static const Color selectedBackground = Color(0xFFE3F2FD);
  
  // Shadow Colors
  static Color shadowLight = Colors.grey.withOpacity(0.1);
  static Color shadowMedium = Colors.grey.withOpacity(0.2);
}

class AppSizes {
  AppSizes._();

  // Sidebar
  static const double sidebarExpandedWidth = 260.0;
  static const double sidebarCollapsedWidth = 80.0;
  static const double sidebarAnimationDuration = 300.0; // milliseconds

  // Header
  static const double headerHeight = 64.0;
  static const double searchBarWidth = 320.0;

  // Spacing
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing48 = 48.0;

  // Border Radius
  static const double radiusSmall = 4.0;
  static const double radiusMedium = 8.0;
  static const double radiusLarge = 12.0;
  static const double radiusCircle = 999.0;

  // Icon Sizes
  static const double iconSmall = 16.0;
  static const double iconMedium = 20.0;
  static const double iconLarge = 24.0;
  static const double iconXLarge = 32.0;

  // Button Heights
  static const double buttonHeightSmall = 32.0;
  static const double buttonHeightMedium = 40.0;
  static const double buttonHeightLarge = 48.0;

  // Elevation/Shadows
  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;
}

class AppBreakpoints {
  AppBreakpoints._();

  static const double mobile = 768.0;
  static const double tablet = 1024.0;
  static const double desktop = 1440.0;

  static bool isMobile(double width) => width < mobile;
  static bool isTablet(double width) => width >= mobile && width < tablet;
  static bool isDesktop(double width) => width >= tablet;
}

class AppTypography {
  AppTypography._();

  // Font Weights
  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  // Font Sizes
  static const double heading1 = 32.0;
  static const double heading2 = 28.0;
  static const double heading3 = 24.0;
  static const double heading4 = 20.0;
  static const double heading5 = 18.0;
  static const double heading6 = 16.0;
  
  static const double bodyLarge = 16.0;
  static const double body = 14.0;
  static const double bodySmall = 13.0;
  static const double caption = 12.0;
  static const double tiny = 11.0;

  // Text Styles
  static TextStyle h1({Color? color}) => TextStyle(
    fontSize: heading1,
    fontWeight: bold,
    color: color ?? AppColors.textDark,
  );

  static TextStyle h2({Color? color}) => TextStyle(
    fontSize: heading2,
    fontWeight: bold,
    color: color ?? AppColors.textDark,
  );

  static TextStyle h3({Color? color}) => TextStyle(
    fontSize: heading3,
    fontWeight: bold,
    color: color ?? AppColors.textDark,
  );

  static TextStyle h4({Color? color}) => TextStyle(
    fontSize: heading4,
    fontWeight: semiBold,
    color: color ?? AppColors.textDark,
  );

  static TextStyle h5({Color? color, required FontWeight fontWeight}) => TextStyle(
    fontSize: heading5,
    fontWeight: semiBold,
    color: color ?? AppColors.textDark,
  );

  static TextStyle bodyLargeStyle({Color? color, FontWeight? weight}) => TextStyle(
    fontSize: bodyLarge,
    fontWeight: weight ?? regular,
    color: color ?? AppColors.textDark,
  );

  static TextStyle bodyText({Color? color, FontWeight? weight, }) => TextStyle(
    fontSize: body,
    fontWeight: weight ?? regular,
    color: color ?? AppColors.textMedium,
  );

  static TextStyle captionText({Color? color,  FontWeight? fontWeight}) => TextStyle(
    fontSize: caption,
    fontWeight: regular,
    color: color ?? AppColors.textLight,
  );
}

class AppDurations {
  AppDurations._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
}

class AppAnimations {
  AppAnimations._();

  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve fastOutSlowIn = Curves.fastOutSlowIn;
  static const Curve easeIn = Curves.easeIn;
  static const Curve easeOut = Curves.easeOut;
}

/// Box shadows for elevation effects
class AppShadows {
  AppShadows._();

  static List<BoxShadow> light = [
    BoxShadow(
      color: AppColors.shadowLight,
      spreadRadius: 0,
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> medium = [
    BoxShadow(
      color: AppColors.shadowLight,
      spreadRadius: 0,
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> high = [
    BoxShadow(
      color: AppColors.shadowMedium,
      spreadRadius: 0,
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];
}

/// Gradient definitions
class AppGradients {
  AppGradients._();

  static const LinearGradient primary = LinearGradient(
    colors: [AppColors.primary, AppColors.primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient success = LinearGradient(
    colors: [Color(0xFF27AE60), Color(0xFF229954)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warning = LinearGradient(
    colors: [Color(0xFFF39C12), Color(0xFFE67E22)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient danger = LinearGradient(
    colors: [Color(0xFFE74C3C), Color(0xFFC0392B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Common border radius configurations
class AppBorderRadius {
  AppBorderRadius._();

  static BorderRadius small = BorderRadius.circular(AppSizes.radiusSmall);
  static BorderRadius medium = BorderRadius.circular(AppSizes.radiusMedium);
  static BorderRadius large = BorderRadius.circular(AppSizes.radiusLarge);
  static BorderRadius circle = BorderRadius.circular(AppSizes.radiusCircle);

  static BorderRadius topOnly = const BorderRadius.only(
    topLeft: Radius.circular(AppSizes.radiusMedium),
    topRight: Radius.circular(AppSizes.radiusMedium),
  );

  static BorderRadius bottomOnly = const BorderRadius.only(
    bottomLeft: Radius.circular(AppSizes.radiusMedium),
    bottomRight: Radius.circular(AppSizes.radiusMedium),
  );
}

/// Common padding/margin values
class AppEdgeInsets {
  AppEdgeInsets._();

  static const EdgeInsets allSmall = EdgeInsets.all(AppSizes.spacing8);
  static const EdgeInsets allMedium = EdgeInsets.all(AppSizes.spacing16);
  static const EdgeInsets allLarge = EdgeInsets.all(AppSizes.spacing24);

  static const EdgeInsets horizontalSmall = EdgeInsets.symmetric(
    horizontal: AppSizes.spacing8,
  );
  static const EdgeInsets horizontalMedium = EdgeInsets.symmetric(
    horizontal: AppSizes.spacing16,
  );
  static const EdgeInsets horizontalLarge = EdgeInsets.symmetric(
    horizontal: AppSizes.spacing24,
  );

  static const EdgeInsets verticalSmall = EdgeInsets.symmetric(
    vertical: AppSizes.spacing8,
  );
  static const EdgeInsets verticalMedium = EdgeInsets.symmetric(
    vertical: AppSizes.spacing16,
  );
  static const EdgeInsets verticalLarge = EdgeInsets.symmetric(
    vertical: AppSizes.spacing24,
  );

  static const EdgeInsets pageDefault = EdgeInsets.all(AppSizes.spacing24);
  static const EdgeInsets cardDefault = EdgeInsets.all(AppSizes.spacing16);
}

/// Icon assets paths (if using custom icons)
class AppIcons {
  AppIcons._();

  // Add custom icon paths here
  // static const String logo = 'assets/icons/logo.svg';
}

/// Image assets paths
class AppImages {
  AppImages._();

  // Add image paths here
  // static const String emptyState = 'assets/images/empty_state.png';
}

/// API and environment constants
class AppConstants {
  AppConstants._();

  // These should be moved to environment variables in production
  static const String appName = 'DocSecure PSMS';
  static const String appVersion = '2.0.0';
  
  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration shortTimeout = Duration(seconds: 10);

  // Local storage keys
  static const String storageKeyToken = 'auth_token';
  static const String storageKeyUser = 'user_data';
  static const String storageKeyTheme = 'theme_mode';
}
