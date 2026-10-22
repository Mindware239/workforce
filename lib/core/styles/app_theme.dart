import 'package:flutter/material.dart';
import 'package:workforce/core/styles/app_colors.dart';

/// Light-only Indian tricolour theme.
class AppTheme {
  AppTheme._();

  static final ColorScheme colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.saffron,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.saffronDeep,
    onPrimary: AppColors.white,
    primaryContainer: AppColors.saffronLight,
    onPrimaryContainer: const Color(0xFF4A2300),
    secondary: AppColors.indiaGreen,
    onSecondary: AppColors.white,
    secondaryContainer: AppColors.indiaGreenLight,
    onSecondaryContainer: const Color(0xFF053A02),
    tertiary: AppColors.navy,
    onTertiary: AppColors.white,
    tertiaryContainer: AppColors.navyLight,
    onTertiaryContainer: AppColors.navy,
    surface: AppColors.white,
    onSurface: AppColors.textColor,
    onSurfaceVariant: AppColors.mutedColor,
    outline: AppColors.borderColor,
    surfaceTint: Colors.transparent,
  );

  static final ThemeData light = _build();

  static ThemeData _build() {
    final scheme = colorScheme;
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      primaryColor: AppColors.saffronDeep,
      scaffoldBackgroundColor: AppColors.backgroundColor,
      canvasColor: AppColors.white,
      dividerColor: AppColors.borderColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.appBarColor,
        foregroundColor: AppColors.onAppBarColor,
        surfaceTintColor: AppColors.appBarColor,
        iconTheme: IconThemeData(color: AppColors.onAppBarColor),
        actionsIconTheme: IconThemeData(color: AppColors.onAppBarColor),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.saffronDeep,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.saffronLight,
          disabledForegroundColor: AppColors.mutedColor,
          elevation: 0,
          shape: buttonShape,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.saffronDeep,
          foregroundColor: AppColors.white,
          shape: buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.saffronText,
          side: const BorderSide(color: AppColors.saffronDeep),
          shape: buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.navy),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.saffronDeep,
        foregroundColor: AppColors.white,
        elevation: 2,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.saffronDeep,
        unselectedItemColor: AppColors.unSelectedColor,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.white,
        indicatorColor: AppColors.saffronLight,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.saffronDeep
                : AppColors.unSelectedColor,
          ),
        ),
      ),
      // Focused borders fall back to colorScheme.primary (saffron); explicit
      // enabled/focused borders are not set here so per-field borders
      // (e.g. InputBorder.none) keep working.
      inputDecorationTheme: const InputDecorationTheme(
        focusColor: AppColors.saffronDeep,
        floatingLabelStyle: TextStyle(color: AppColors.saffronText),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.saffronDeep,
        selectionColor: AppColors.saffronLight,
        selectionHandleColor: AppColors.saffronDeep,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.white,
        selectedColor: AppColors.saffronLight,
        checkmarkColor: AppColors.saffronText,
        side: const BorderSide(color: AppColors.borderColor),
        labelStyle: const TextStyle(color: AppColors.textColor),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.saffronDeep,
        linearTrackColor: AppColors.saffronLight,
        circularTrackColor: Colors.transparent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.white
              : AppColors.mutedColor,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.indiaGreen
              : AppColors.borderColor,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.saffronDeep
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(AppColors.white),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.saffronDeep
              : AppColors.mutedColor,
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.saffronText,
        unselectedLabelColor: AppColors.mutedColor,
        indicatorColor: AppColors.saffronDeep,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.navy,
        contentTextStyle: TextStyle(color: AppColors.white),
        actionTextColor: AppColors.saffron,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.white,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
