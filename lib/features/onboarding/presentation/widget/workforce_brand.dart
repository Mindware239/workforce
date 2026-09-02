import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/core/styles/app_colors.dart';

class WorkforceBrand extends StatelessWidget {
  const WorkforceBrand({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/icons/logo.svg',
            width: 23,
            height: 23,
          ),

          const SizedBox(width: 6),

          Text(
            'Workforce Pro',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryFillColor,
            ),
          ),
        ],
      ),
    );
  }
}