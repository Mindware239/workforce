import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/widgets/feature_widgets.dart';

/// Pieces the production floor and warehouse screens share.

final NumberFormat _qtyFormat = NumberFormat('#,##,##0.###', 'en_IN');

/// A quantity as the web shows it: Indian grouping, up to 3 decimals, and
/// the unit in lower case after it.
String formatQty(dynamic value, [String? unit]) {
  final n = toNum(value);

  if (n == null) return '—';

  final text = _qtyFormat.format(n);

  return (unit == null || unit.isEmpty) ? text : '$text ${unit.toLowerCase()}';
}

/// Minutes as `1h 5m` / `12m`.
String formatMinutes(dynamic value) {
  final m = toNum(value);

  if (m == null) return '—';

  final h = m ~/ 60;
  final r = (m % 60).round();

  return h > 0 ? '${h}h ${r}m' : '${r}m';
}

/// `IN_TRANSIT` -> `IN TRANSIT`, as the web badges read.
String humanStatus(String? status) => (status ?? '').replaceAll('_', ' ');

/// A number typed into a quantity field; empty or junk is null.
num? parseQty(String text) => num.tryParse(text.trim());

/// Stock status label/tone, from the web's STOCK_STATUS.
(String, ChipTone) stockStatus(WidgetRef ref, String? status) {
  return switch (status) {
    'IN_TRANSIT' => (ref.tr('ops.statusInTransit'), ChipTone.info),
    'QUARANTINE' => (ref.tr('ops.statusQuarantine'), ChipTone.warning),
    'HOLD' => (ref.tr('ops.statusHold'), ChipTone.warning),
    'DAMAGED' => (ref.tr('ops.statusDamaged'), ChipTone.danger),
    'SCRAP' => (ref.tr('ops.statusScrap'), ChipTone.danger),
    'BLOCKED' => (ref.tr('ops.statusBlocked'), ChipTone.neutral),
    'EXPIRED' => (ref.tr('ops.statusExpired'), ChipTone.danger),
    _ => (ref.tr('ops.statusAvailable'), ChipTone.success),
  };
}

enum NoteTone { info, warning, success }

/// A soft coloured note (the web's `Alert`).
class NoteBanner extends StatelessWidget {
  final String message;
  final NoteTone tone;

  const NoteBanner(this.message, {super.key, this.tone = NoteTone.info});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color border, Color fg) = switch (tone) {
      NoteTone.info => (AppColors.navyLight, const Color(0xFFC9CFEE), AppColors.navy),
      NoteTone.warning => (AppColors.saffronTint, AppColors.saffronLight, AppColors.saffronText),
      NoteTone.success => (AppColors.indiaGreenLight, const Color(0xFFC3E6BF), AppColors.indiaGreen),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(fontSize: 12, height: 1.35, color: fg),
      ),
    );
  }
}

/// The plan does not include this feature (the web's `FeatureLocked`).
class FeatureLockedPanel extends ConsumerWidget {
  final String featureName;

  const FeatureLockedPanel({super.key, required this.featureName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FeatureCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFF1F1F3),
            ),
            child: const Icon(Icons.lock_outline, color: AppColors.mutedColor),
          ),
          const SizedBox(height: 10),
          Text(
            fill(ref.tr('ops.lockedTitle'), {'name': featureName}),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ref.tr('ops.lockedHint'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedColor),
          ),
        ],
      ),
    );
  }
}

/// A small uppercase caption (`WO-0012 · CUTTING`).
class OpsCaption extends StatelessWidget {
  final String text;

  const OpsCaption(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: .5,
        color: AppColors.mutedColor,
      ),
    );
  }
}

/// A modal bottom sheet with a title, a description, a body and a footer,
/// lifted above the keyboard.
Future<T?> showOpsSheet<T>(
  BuildContext context, {
  required String title,
  String? description,
  required Widget Function(BuildContext sheetContext) builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textColor,
                ),
              ),
              if (description != null && description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.mutedColor,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              builder(sheetContext),
            ],
          ),
        ),
      );
    },
  );
}

/// A small spinner for buttons that are working.
class ButtonSpinner extends StatelessWidget {
  final Color color;

  const ButtonSpinner({super.key, this.color = AppColors.white});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    );
  }
}
