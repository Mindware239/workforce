import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:workforce/core/styles/app_colors.dart';

/// Global standard shimmer effect wrapper.
class ShimmerLoading extends StatelessWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration period;

  const ShimmerLoading({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.period = const Duration(milliseconds: 1400),
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor ?? Colors.grey.shade200,
      highlightColor: highlightColor ?? Colors.grey.shade100,
      period: period,
      child: child,
    );
  }
}

/// A single shimmer rectangle/pill with rounded corners.
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// A circular shimmer element (e.g. for avatars, icons, badges).
class ShimmerCircle extends StatelessWidget {
  final double size;
  final EdgeInsetsGeometry? margin;

  const ShimmerCircle({
    super.key,
    required this.size,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      margin: margin,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Shimmer card matching FeatureCard style.
class ShimmerCard extends StatelessWidget {
  final double? height;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final Widget? child;

  const ShimmerCard({
    super.key,
    this.height,
    this.margin = const EdgeInsets.only(bottom: 12),
    this.padding = const EdgeInsets.all(14),
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.5)),
      ),
      child: child,
    );
  }
}

/// A standard shimmer list item simulating a card with icon, title, subtitle & trailing.
class ShimmerListTile extends StatelessWidget {
  final double leadingSize;
  final bool hasLeading;
  final bool isCircleLeading;
  final EdgeInsetsGeometry margin;

  const ShimmerListTile({
    super.key,
    this.leadingSize = 40,
    this.hasLeading = true,
    this.isCircleLeading = false,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerCard(
      margin: margin,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (hasLeading) ...[
            if (isCircleLeading)
              ShimmerCircle(size: leadingSize)
            else
              ShimmerBox(
                width: leadingSize,
                height: leadingSize,
                borderRadius: 8,
              ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const ShimmerBox(width: 160, height: 14, borderRadius: 4),
                const SizedBox(height: 8),
                ShimmerBox(
                  width: double.infinity,
                  height: 11,
                  borderRadius: 4,
                  margin: const EdgeInsets.only(right: 40),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const ShimmerBox(width: 50, height: 20, borderRadius: 10),
        ],
      ),
    );
  }
}

/// A vertical skeleton list of cards with shimmer animation.
class ShimmerCardList extends StatelessWidget {
  final int count;
  final EdgeInsetsGeometry padding;
  final double cardHeight;
  final Widget Function(BuildContext, int)? itemBuilder;

  const ShimmerCardList({
    super.key,
    this.count = 4,
    this.padding = EdgeInsets.zero,
    this.cardHeight = 90,
    this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: padding,
        child: Column(
          children: List.generate(
            count,
            (index) =>
                itemBuilder?.call(context, index) ??
                ShimmerCard(
                  height: cardHeight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          ShimmerBox(width: 120, height: 14, borderRadius: 4),
                          ShimmerBox(width: 60, height: 18, borderRadius: 9),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const ShimmerBox(width: 200, height: 12, borderRadius: 4),
                      const SizedBox(height: 8),
                      const ShimmerBox(width: 140, height: 10, borderRadius: 4),
                    ],
                  ),
                ),
          ),
        ),
      ),
    );
  }
}

/// Shimmer detail screen skeleton (app bar card, summary, rows).
class ShimmerDetailView extends StatelessWidget {
  final EdgeInsetsGeometry padding;

  const ShimmerDetailView({
    super.key,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: ListView(
        padding: padding,
        children: [
          // Header card
          ShimmerCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    ShimmerBox(width: 140, height: 18, borderRadius: 4),
                    ShimmerBox(width: 70, height: 24, borderRadius: 12),
                  ],
                ),
                const SizedBox(height: 14),
                const ShimmerBox(width: 100, height: 12, borderRadius: 4),
                const SizedBox(height: 10),
                const ShimmerBox(width: double.infinity, height: 14, borderRadius: 4),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Details breakdown card
          ShimmerCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: List.generate(
                4,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      ShimmerBox(width: 90, height: 13, borderRadius: 4),
                      ShimmerBox(width: 120, height: 13, borderRadius: 4),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Actions or notes box
          const ShimmerCard(
            height: 100,
            padding: EdgeInsets.all(16),
          ),
        ],
      ),
    );
  }
}

/// Shimmer skeleton for profile screen.
class ShimmerProfileView extends StatelessWidget {
  const ShimmerProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 12),
            const ShimmerCircle(size: 96),
            const SizedBox(height: 16),
            const ShimmerBox(width: 160, height: 20, borderRadius: 6),
            const SizedBox(height: 8),
            const ShimmerBox(width: 100, height: 14, borderRadius: 4),
            const SizedBox(height: 24),

            // Card 1: Personal info
            ShimmerCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: List.generate(
                  4,
                  (index) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: const [
                        ShimmerBox(width: 90, height: 13, borderRadius: 4),
                        SizedBox(width: 16),
                        Expanded(
                          child: ShimmerBox(height: 13, borderRadius: 4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Card 2: Work info
            ShimmerCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: List.generate(
                  3,
                  (index) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: const [
                        ShimmerBox(width: 90, height: 13, borderRadius: 4),
                        SizedBox(width: 16),
                        Expanded(
                          child: ShimmerBox(height: 13, borderRadius: 4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
