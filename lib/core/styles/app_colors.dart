import 'dart:ui';

/// Indian tricolour palette (light mode only).
///
/// Saffron leads (app bars, primary buttons, FABs, selected nav),
/// India green is secondary + success, navy is used for accents/links/info.
///
/// Contrast notes (WCAG, against white #FFFFFF):
/// - [saffron] #FF9933 ........ 2.1:1  -> decorative only (strip, tints, gradients)
/// - [saffronDeep] #E07800 .... 3.1:1  -> fills behind bold/large white text, icons
/// - [saffronText] #B35600 .... 4.9:1  -> small saffron text on white
/// - [indiaGreen] #138808 ..... 4.6:1
/// - [navy] #000080 ........... 16:1
class AppColors {
  // ---------------------------------------------------------------------------
  // Tricolour brand tokens
  // ---------------------------------------------------------------------------
  static const saffron = Color(0xFFFF9933);
  static const saffronDeep = Color(0xFFE07800);
  static const saffronText = Color(0xFFB35600);
  static const saffronLight = Color(0xFFFFE8CC);
  static const saffronTint = Color(0xFFFFF4E6);

  static const indiaGreen = Color(0xFF138808);
  static const indiaGreenLight = Color(0xFFE3F4E1);

  static const navy = Color(0xFF000080);
  static const navyLight = Color(0xFFE5E8F7);

  static const white = Color(0xFFFFFFFF);

  /// Saffron gradient (light -> deep) for hero cards / banners.
  static const saffronGradient = [saffron, saffronDeep];

  // ---------------------------------------------------------------------------
  // Semantic tokens used throughout the app
  // ---------------------------------------------------------------------------
  static const backgroundColor = Color(0xFFFFFCF8);
  static const primaryFillColor = saffronDeep;
  static const selectedColor = saffronDeep;
  static const unSelectedColor = Color(0xFF4A4A55);
  static const borderColor = Color(0xFFE2D8CC);
  static const mutedColor = Color(0xFF5C5F6B);
  static const textColor = Color(0xFF1B1B24);

  static const successColor = indiaGreen;
  static const infoColor = navy;
  static const linkColor = navy;

  /// Soft saffron tint for icon bubbles / status pills.
  static const primaryTintColor = saffronLight;

  /// Very light saffron surface (input fills, subtle highlights).
  static const primarySurfaceTintColor = saffronTint;

  static const appBarColor = saffronDeep;
  static const onAppBarColor = white;
  static const onAppBarMutedColor = Color(0xFFFFF1E0);

  static const whiteBackgroundColor = Color(0xFFFFFFFF);
  static const activeColor = Color(0xFFFFFFFF);
  static const inactiveColor = Color(0xFF45464D);
}
