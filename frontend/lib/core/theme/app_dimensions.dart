import 'package:flutter/material.dart';

/// Centralized layout, spacing, and sizing tokens.
abstract final class AppDimensions {
  // Spacing values
  static const double spacing2xs = 2.0;
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacing2xl = 48.0;

  // Corner radii
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusFull = 9999.0;

  // Common UI element heights
  static const double buttonHeight = 48.0;
  static const double inputHeight = 48.0;
  static const double cardElevation = 0.0;
  static const double cardBorderWidth = 1.0;

  // Edge insets shortcuts
  static const EdgeInsets paddingScreen = EdgeInsets.all(spacingMd);
  static const EdgeInsets paddingCard = EdgeInsets.all(spacingMd);
  static const EdgeInsets paddingButton = EdgeInsets.symmetric(
    horizontal: spacingLg,
    vertical: spacingMd,
  );
}
