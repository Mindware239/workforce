import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/widgets/feature_widgets.dart';

/// Pieces the review list and the review screen share.

const List<String> reviewStages = [
  'goal_setting',
  'goals_submitted',
  'goals_approved',
  'self_submitted',
  'manager_submitted',
  'finalized',
  'acknowledged',
];

ChipTone reviewStageTone(String? stage) {
  switch (stage) {
    case 'goal_setting':
      return ChipTone.neutral;
    case 'goals_submitted':
    case 'self_submitted':
      return ChipTone.warning;
    case 'goals_approved':
    case 'manager_submitted':
      return ChipTone.info;
    case 'finalized':
      return ChipTone.primary;
    case 'acknowledged':
      return ChipTone.success;
    default:
      return ChipTone.neutral;
  }
}

class ReviewStageChip extends ConsumerWidget {
  final String? stage;

  const ReviewStageChip({super.key, required this.stage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StatusChip(
      label: ref.tr('reviews.stage_${stage ?? 'goal_setting'}'),
      tone: reviewStageTone(stage),
    );
  }
}

String formatScore(dynamic score) {
  final value = toNum(score);

  return value == null ? '-' : value.toStringAsFixed(2);
}

/// 1–5 stars with the rating's name. Read-only when [onChanged] is null.
class RatingPicker extends ConsumerWidget {
  final int? value;
  final ValueChanged<int>? onChanged;
  final double size;

  const RatingPicker({
    super.key,
    required this.value,
    this.onChanged,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = value ?? 0;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var n = 1; n <= 5; n++)
          Semantics(
            button: onChanged != null,
            label: fill(ref.tr('reviews.ratingOf'), {'n': n}),
            selected: n == current,
            child: InkResponse(
              onTap: onChanged == null ? null : () => onChanged!(n),
              radius: size * 0.7,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  n <= current ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: size,
                  color: n <= current
                      ? AppColors.saffronDeep
                      : AppColors.borderColor,
                ),
              ),
            ),
          ),
        const SizedBox(width: 6),
        Text(
          value == null
              ? ref.tr('reviews.notRated')
              : ref.tr('reviews.rating_$value'),
          style: GoogleFonts.inter(
            fontSize: 12,
            color: value == null ? AppColors.mutedColor : AppColors.textColor,
          ),
        ),
      ],
    );
  }
}

/// A labelled block of free text (strengths, comments, ...).
class TextBlock extends StatelessWidget {
  final String label;
  final String? text;

  const TextBlock({super.key, required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    if (text == null || text!.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            text!,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textColor,
            ),
          ),
        ],
      ),
    );
  }
}
