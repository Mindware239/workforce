import 'package:flutter/material.dart';
import 'package:workforce/core/styles/app_colors.dart';

/// A thin saffron / white / green band.
///
/// Implements [PreferredSizeWidget] so it can be used directly as an
/// `AppBar.bottom`. Pass [width] to draw a short centred accent instead of a
/// full-width band (e.g. under a logo).
class TricolourStrip extends StatelessWidget implements PreferredSizeWidget {
  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  const TricolourStrip({
    super.key,
    this.height = 4,
    this.width,
    this.borderRadius,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final band = SizedBox(
      height: height,
      width: width ?? double.infinity,
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: ColoredBox(color: AppColors.saffron)),
          Expanded(child: ColoredBox(color: AppColors.white)),
          Expanded(child: ColoredBox(color: AppColors.indiaGreen)),
        ],
      ),
    );

    if (borderRadius == null) return band;
    return ClipRRect(borderRadius: borderRadius!, child: band);
  }
}
