class AppConstants {
  // App Information
  static const String appName = 'SmartPOS';
  static const String appVersion = '1.0.0';
  static const String companyName = 'SmartPOS Solutions';
  
  // Database
  static const String databaseName = 'smartpos.db';
  static const int databaseVersion = 1;
  
  // Stock Thresholds
  static const int lowStockThreshold = 10;
  static const int criticalStockThreshold = 5;
  
  // Pagination
  static const int defaultPageSize = 20;
  
  // Currency
  static const String currencySymbol = '\$';
  
  // Date Formats
  static const String dateFormat = 'yyyy-MM-dd';
  static const String dateTimeFormat = 'yyyy-MM-dd HH:mm:ss';
  static const String displayDateFormat = 'MMM dd, yyyy';
  static const String displayDateTimeFormat = 'MMM dd, yyyy HH:mm';
  
  // Animation Durations
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);
  
  // Spacing
  static const double spacingXSmall = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingXLarge = 32.0;
  
  // Legacy spacing (for backward compatibility)
  static const double smallSpacing = 8.0;
  static const double mediumSpacing = 16.0;
  static const double largeSpacing = 24.0;
  static const double extraLargeSpacing = 32.0;
  
  // Border Radius
  static const double borderRadiusSmall = 4.0;
  static const double borderRadiusMedium = 8.0;
  static const double borderRadiusLarge = 12.0;
  static const double borderRadiusXLarge = 16.0;
  
  // Legacy border radius (for backward compatibility)
  static const double smallBorderRadius = 4.0;
  static const double mediumBorderRadius = 8.0;
  static const double largeBorderRadius = 12.0;
  static const double extraLargeBorderRadius = 16.0;
  
  // Elevation
  static const double lowElevation = 2.0;
  static const double mediumElevation = 4.0;
  static const double highElevation = 8.0;
  
  // Padding
  static const double padding = 16.0;
  static const double smallPadding = 8.0;
  static const double mediumPadding = 16.0;
  static const double largePadding = 24.0;
  static const double extraLargePadding = 32.0;
  
  // Additional padding constants for backward compatibility
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;
  
  // Material 3 Design System Constants
  static const double cardElevation = 1.0;
  static const double surfaceElevation = 0.0;
  static const double modalElevation = 3.0;
  
  // Typography Scale
  static const double headlineSize = 32.0;
  static const double titleSize = 22.0;
  static const double bodySize = 16.0;
  static const double labelSize = 14.0;
  static const double captionSize = 12.0;
  
  // Icon Sizes
  static const double iconSmall = 16.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 32.0;
  static const double iconXLarge = 48.0;
  
  // Button Heights
  static const double buttonHeight = 48.0;
  static const double compactButtonHeight = 40.0;
  static const double smallButtonHeight = 32.0;
  
  // Container Constraints
  static const double maxContentWidth = 1200.0;
  static const double minTouchTarget = 48.0;
  
  // Grid and Layout
  static const double gridSpacing = 16.0;
  static const double listItemHeight = 72.0;
  static const double compactListItemHeight = 56.0;
  
  // Opacity Values
  static const double disabledOpacity = 0.38;
  static const double hoverOpacity = 0.08;
  static const double focusOpacity = 0.12;
  static const double selectedOpacity = 0.12;
  static const double pressedOpacity = 0.12;
}