import 'package:flutter/material.dart';

/// Responsive Helper - Simple device checks and screen sizes
class ResponsiveHelper {
  ResponsiveHelper._();

  // Breakpoints
  static const double mobileBreakpoint = 768.0;
  static const double tabletBreakpoint = 1024.0;

  // Device checks
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint;

  // Screen sizes
  static double width(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double height(BuildContext context) =>
      MediaQuery.of(context).size.height;

  /// Picks a value based on the current device class. `tablet` falls back
  /// to `desktop` when not supplied, since a tablet layout is most often a
  /// slightly scaled-down desktop layout rather than a third bespoke design.
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet ?? desktop;
    return mobile;
  }
}

/// Context extension for cleaner syntax
extension ResponsiveContext on BuildContext {
  bool get isMobile => ResponsiveHelper.isMobile(this);
  bool get isTablet => ResponsiveHelper.isTablet(this);
  bool get isDesktop => ResponsiveHelper.isDesktop(this);

  double get screenWidth => ResponsiveHelper.width(this);
  double get screenHeight => ResponsiveHelper.height(this);

  /// `context.responsive<double>(mobile: 14, tablet: 16, desktop: 18)`
  T responsive<T>({required T mobile, T? tablet, required T desktop}) =>
      ResponsiveHelper.value(this, mobile: mobile, tablet: tablet, desktop: desktop);
}