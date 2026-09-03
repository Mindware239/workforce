import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/auth/presentation/employee_login_screen.dart';
import 'package:workforce/features/onboarding/presentation/widget/primary_button.dart';
import 'package:workforce/features/onboarding/presentation/widget/radio_circle.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String selectedRole = 'Employee';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              _buildBrand(),

              const SizedBox(height: 48),

              Text(
                'Welcome',
                style: GoogleFonts.inter(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'How will you use Workforce Pro?',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppColors.mutedColor,
                ),
              ),

              const SizedBox(height: 16),

              _RoleOption(
                icon: Icons.badge_outlined,
                title: 'Employee',
                description: 'Manage attendance, shifts, leave and\nsalary.',
                selected: selectedRole == 'Employee',
                onTap: () {
                  setState(() {
                    selectedRole = 'Employee';
                  });
                },
              ),

              const SizedBox(height: 12),

              _RoleOption(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Administrator',
                description: 'Manage employees, attendance and\npayroll.',
                selected: selectedRole == 'Administrator',
                onTap: () {
                  setState(() {
                    selectedRole = 'Administrator';
                  });
                },
              ),

              const Spacer(),

              WorkforcePrimaryButton(title: 'Continue', onPressed: () {
                 Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EmployeeLoginScreen(),
                    ),
                  );
              }),

              const SizedBox(height: 16),

              Center(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Need help? ',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.mutedColor,
                        ),
                      ),
                      TextSpan(
                        text: 'Contact Support',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryFillColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrand() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.business_center_outlined,
            size: 18,
            color: AppColors.primaryFillColor,
          ),

          const SizedBox(width: 5),

          Text(
            'Workforce Pro',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryFillColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _RoleOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          height: 102,
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
              // Icon background
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0ECF9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: AppColors.mutedColor),
              ),

              const SizedBox(width: 12),

              // Text
              Expanded(
                child: Column(
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
                      description,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        height: 1.15,
                        color: AppColors.mutedColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 5),

              RadioCircle(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}
