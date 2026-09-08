import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/app/routes/app_routes.dart';
import 'package:workforce/core/services/auth_service.dart';
import 'package:workforce/core/services/secure_storage.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/notification/presentation/notification.dart';
import 'package:workforce/features/onboarding/presentation/screen/language_selection_screen.dart';
import 'package:workforce/features/attendence/presentation/verification_unsuccessful_screen.dart';
import 'package:workforce/features/setting/presentation/help_support_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isDarkMode = false;

  Future<void> _logout() async {
  final secureStorage = SecureStorage();

  // Remove JWT and saved employee data
  await secureStorage.clearAuth();
  // await LocationTrackingService.stop();

  // Update authentication state
  AuthService.logout();

  if (!mounted) return;

  // Go to login and remove previous navigation history
  context.go(AppRoutes.login);
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: AppColors.whiteBackgroundColor,
        surfaceTintColor: AppColors.whiteBackgroundColor,
        title: Text(
          'Setting',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textColor,
          ),
        ),
        
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('GENERAL'),

              const SizedBox(height: 8),

              _buildSettingsCard(
                children: [
                  _SettingsRow(
                    icon: Icons.person_outline_rounded,
                    title: 'Account',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const HelpSupportScreen(),
                        ),
                      );
                    },
                  ),

                  _SettingsRow(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const NotificationScreen(),
                        ),
                      );
                    },
                  ),

                  _SettingsRow(
                    icon: Icons.language_rounded,
                    title: 'Language',
                    trailingText: 'English',

                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const LanguageSelectionScreen(),
                        ),
                      );
                    },
                    isLast: true,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _buildSectionTitle('SECURITY & PRIVACY'),

              const SizedBox(height: 16),

              _buildSettingsCard(
                children: [
                  _SettingsRow(
                    icon: Icons.lock_outline_rounded,
                    title: 'Security',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const VerificationUnsuccessfulScreen(),
                        ),
                      );
                    },
                  ),

                  _SettingsRow(
                    icon: Icons.shield_outlined,
                    title: 'Privacy',
                    onTap: () {},
                    isLast: true,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _buildSectionTitle('PREFERENCES'),

              const SizedBox(height: 16),

              _buildSettingsCard(
                children: [
                  _SettingsRow(
                    icon: Icons.settings_outlined,
                    title: 'App Preferences',
                    onTap: () {},
                  ),

                  _SettingsRow(
                    icon: Icons.dark_mode_outlined,
                    title: 'Dark Mode',

                    trailing: Switch(
                      value: isDarkMode,
                      onChanged: (value) {
                        setState(() {
                          isDarkMode = value;
                        });
                      },
                      activeThumbColor: AppColors.primaryFillColor,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    isLast: true,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              _buildLogoutButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: .4,
        color: AppColors.mutedColor,
      ),
    );
  }

  Widget _buildSettingsCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: () {
         _logout();
      },
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFDAD6), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.logout_rounded,
              size: 20,
              color: Color(0xFFBA1A1A),
            ),

            const SizedBox(width: 8),

            Text(
              'Logout',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFBA1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailingText;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isLast;

  const _SettingsRow({
    required this.icon,
    required this.title,
    this.onTap,
    this.trailingText,
    this.trailing,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : const Border(
                    bottom: BorderSide(color: AppColors.borderColor, width: 1),
                  ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.mutedColor),

              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textColor,
                  ),
                ),
              ),

              if (trailingText != null)
                Text(
                  trailingText!,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.mutedColor,
                  ),
                ),

              if (trailingText != null) const SizedBox(width: 4),

              if (trailing != null)
                trailing!
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppColors.mutedColor,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
