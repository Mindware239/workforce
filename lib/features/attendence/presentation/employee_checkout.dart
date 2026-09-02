import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/onboarding/presentation/widget/primary_button.dart';

class ConfirmCheckoutPhotoScreen extends StatelessWidget {
  final String imagePath;

  const ConfirmCheckoutPhotoScreen({
    super.key,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: AppColors.whiteBackgroundColor,
        surfaceTintColor: AppColors.whiteBackgroundColor,
        title: Text(
          'Confirm check-out photo',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryFillColor,
          ),
        ),),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              
              _buildPhoto(),

              const SizedBox(height: 12),

              
              Text(
                'Verify your photo before completing your shift.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.mutedColor,
                ),
              ),

              const SizedBox(height: 16),

              
              _buildDetails(),

              const SizedBox(height: 16),

              
              WorkforcePrimaryButton(
                title: 'Confirm Check-out',
                onPressed: () {
                  _confirmCheckout(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

 
 
 Widget _buildPhoto() {
  return ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: SizedBox(
      width: double.infinity,
      height: 464,
      child: imagePath.isNotEmpty
          ? Image.file(
              File(imagePath),
              fit: BoxFit.cover,
            )
          : Image.asset(
              'assets/images/check-out.png',
              fit: BoxFit.cover,
            ),
    ),
  );
}

  Widget _buildDetails() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderColor,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _CheckoutDetailRow(
            icon: Icons.person_outline_rounded,
            label: 'EMPLOYEE',
            value: 'Alex Johnson',
          ),
          _CheckoutDetailRow(
            icon: Icons.access_time_outlined,
            label: 'TIMESTAMP',
            value: 'Oct 24, 2023 • 05:12 PM',
          ),
          _CheckoutDetailRow(
            icon: Icons.location_on_outlined,
            label: 'WORKPLACE',
            value: 'HQ – Factory Floor',
            isLast: true,
          ),
        ],
      ),
    );
  }

 
  void _confirmCheckout(BuildContext context) {
    // TODO:
    // Call checkout API here.
    //
    // Example:
    // await repository.completeCheckout(imagePath);

    Navigator.pop(context);
  }
}


class _CheckoutDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _CheckoutDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 65,
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(
                  color: AppColors.borderColor,
                  width: 1,
                ),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ICON CIRCLE
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFE9DDF7),
            ),
            child: Icon(
              icon,
              size: 16,
              color: AppColors.primaryFillColor,
            ),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: .3,
                    color: AppColors.mutedColor,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}