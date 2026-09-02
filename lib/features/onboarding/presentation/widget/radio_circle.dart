import 'package:flutter/material.dart';
import 'package:workforce/core/styles/app_colors.dart';

class RadioCircle extends StatelessWidget {
  final bool selected;
  final double size;

  const RadioCircle({
    super.key,
    required this.selected,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected
              ? AppColors.primaryFillColor
              : AppColors.mutedColor,
          width: 1,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: size,
                height: size, 
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryFillColor,
                ),
              ),
            )
          : null,
    );
  }
}