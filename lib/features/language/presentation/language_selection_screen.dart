import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/onboarding/presentation/widget/primary_button.dart';
import 'package:workforce/features/onboarding/presentation/widget/radio_circle.dart';
import 'package:workforce/features/onboarding/presentation/widget/workforce_brand.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String selectedLanguage = 'English';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: AppColors.whiteBackgroundColor,
        surfaceTintColor: AppColors.whiteBackgroundColor,
       
        
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              WorkforceBrand(),

              const SizedBox(height: 48),

              Text(
                'Choose your language',
                style: GoogleFonts.inter(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Select the language you prefer to use\n'
                'throughout the application.',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  height: 1.4,
                  color: AppColors.mutedColor,
                ),
              ),

              const SizedBox(height: 16),

              _LanguageOption(
                title: 'English',
                subtitle: 'English',
                selected: selectedLanguage == 'English',
                onTap: () {
                  setState(() {
                    selectedLanguage = 'English';
                  });
                },
              ),

              const SizedBox(height: 12),

              _LanguageOption(
                title: 'हिन्दी',
                subtitle: 'Hindi',
                selected: selectedLanguage == 'Hindi',
                onTap: () {
                  setState(() {
                    selectedLanguage = 'Hindi';
                  });
                },
              ),

              const Spacer(),
              Divider(color: AppColors.borderColor, thickness: 1),
              const SizedBox(height: 4),

              WorkforcePrimaryButton(title: 'Continue', onPressed: () {}),

              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          height: 74,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.primaryFillColor
                  : AppColors.borderColor,
              width: selected ? 1 : .8,
            ),
          ),
          child: Row(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textColor,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.mutedColor,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              RadioCircle(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}
