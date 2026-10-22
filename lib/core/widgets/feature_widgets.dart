import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/styles/tricolour_strip.dart';

/// Small building blocks shared by the expenses, assets and reviews screens,
/// in the look the rest of the app uses (bordered white cards, Inter text,
/// saffron app bar with the tricolour strip).

// ============================================================================
// FORMATTING
// ============================================================================

final NumberFormat _inr = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);

String formatInr(num? value) {
  if (value == null) return '-';

  final text = _inr.format(value);

  // ₹1,200.00 -> ₹1,200 when there are no paise.
  return text.endsWith('.00') ? text.substring(0, text.length - 3) : text;
}

num? toNum(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;

  return num.tryParse(value.toString());
}

int? toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();

  return int.tryParse(value.toString());
}

/// API dates come as `YYYY-MM-DD` (DATE columns) or ISO timestamps.
DateTime? parseApiDate(dynamic value) {
  if (value == null) return null;

  final parsed = DateTime.tryParse(value.toString());

  if (parsed == null) return null;

  return parsed.isUtc ? parsed.toLocal() : parsed;
}

String formatApiDate(dynamic value, {String fallback = '-'}) {
  final date = parseApiDate(value);

  if (date == null) return fallback;

  return DateFormat('dd MMM yyyy').format(date);
}

String apiDateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

/// `{name}` placeholders, as the localization file uses them.
String fill(String template, Map<String, Object?> values) {
  var out = template;

  values.forEach((key, value) {
    out = out.replaceAll('{$key}', value?.toString() ?? '');
  });

  return out;
}

// ============================================================================
// APP BAR
// ============================================================================

/// The deep saffron bar with the tricolour strip under it.
PreferredSizeWidget featureAppBar({String? title, List<Widget>? actions}) {
  return AppBar(
    centerTitle: true,
    backgroundColor: AppColors.appBarColor,
    surfaceTintColor: AppColors.appBarColor,
    foregroundColor: AppColors.onAppBarColor,
    elevation: 0,
    bottom: const TricolourStrip(),
    title: title == null
        ? null
        : Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.onAppBarColor,
            ),
          ),
    actions: actions,
  );
}

// ============================================================================
// HEADINGS / CARDS
// ============================================================================

class FeatureHeading extends StatelessWidget {
  final String title;
  final String? subtitle;

  const FeatureHeading({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppColors.textColor,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.35,
              color: AppColors.mutedColor,
            ),
          ),
        ],
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textColor,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class FeatureCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  const FeatureCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

// ============================================================================
// STATUS CHIP
// ============================================================================

enum ChipTone { warning, success, danger, info, neutral, primary }

class StatusChip extends StatelessWidget {
  final String label;
  final ChipTone tone;

  const StatusChip({super.key, required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (tone) {
      ChipTone.warning => (AppColors.saffronTint, AppColors.saffronText),
      ChipTone.success => (AppColors.indiaGreenLight, AppColors.indiaGreen),
      ChipTone.danger => (const Color(0xFFFDECEC), const Color(0xFFB3261E)),
      ChipTone.info => (AppColors.navyLight, AppColors.navy),
      ChipTone.neutral => (const Color(0xFFF1F1F3), AppColors.mutedColor),
      ChipTone.primary => (AppColors.saffronLight, AppColors.saffronText),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

// ============================================================================
// STATES
// ============================================================================

class ErrorBanner extends StatelessWidget {
  final String message;

  const ErrorBanner(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF5C2C0)),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: const Color(0xFFB3261E),
        ),
      ),
    );
  }
}

class EmptyNote extends StatelessWidget {
  final String message;
  final IconData icon;

  const EmptyNote(this.message, {super.key, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    return FeatureCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: [
          Icon(icon, size: 32, color: AppColors.mutedColor),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.mutedColor),
          ),
        ],
      ),
    );
  }
}

class LoadErrorView extends StatelessWidget {
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  const LoadErrorView({
    super.key,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 8),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 44,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textColor),
          ),
          const SizedBox(height: 14),
          ElevatedButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}

/// A label above a value, as on the profile screen.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const InfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.mutedColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared outlined text field decoration for the forms.
InputDecoration featureInputDecoration(
  String label, {
  String? hint,
  String? prefixText,
  Widget? suffixIcon,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppColors.borderColor),
  );

  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixText: prefixText,
    suffixIcon: suffixIcon,
    isDense: true,
    filled: true,
    fillColor: AppColors.white,
    labelStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.mutedColor),
    hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.mutedColor),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: const BorderSide(color: AppColors.saffronDeep, width: 1.4),
    ),
  );
}

/// Yes/no confirmation in the app's dialog style.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        title,
        style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      content: Text(
        message,
        style: GoogleFonts.inter(fontSize: 13, color: AppColors.mutedColor),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        ElevatedButton(
          style: destructive
              ? ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB3261E),
                  foregroundColor: AppColors.white,
                )
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );

  return result == true;
}

void showFeatureSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
