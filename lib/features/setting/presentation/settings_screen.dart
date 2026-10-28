import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:workforce/app/routes/app_routes.dart';
import 'package:workforce/core/localization/app_language.dart';
import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/push/push_notification_service.dart';
import 'package:workforce/core/realtime/realtime_service.dart';
import 'package:workforce/core/services/auth_service.dart';
import 'package:workforce/core/services/secure_storage.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/styles/tricolour_strip.dart';
import 'package:workforce/features/attendence/services/employee_location_service.dart';
import 'package:workforce/features/language/presentation/language_selection_screen.dart';
import 'package:workforce/features/language/providers/language_provider.dart';
import 'package:workforce/features/notification/presentation/notification.dart';
import 'package:workforce/features/setting/presentation/help_support_screen.dart';
import 'package:workforce/features/account/providers/account_provider.dart';
import 'package:workforce/core/offline/offline_sync_service.dart';
import 'package:workforce/features/field_work/services/field_work_tracker.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool isDarkMode = false;

  Future<void> _logout() async {
    final secureStorage = SecureStorage();

    // Close the live connection before the token goes.
    RealtimeService.instance.disconnect();
    // While the token is still stored: the backend forgets this phone.
    await PushNotificationService.instance.unregisterDevice();

    // Remove JWT and saved employee data
    await secureStorage.clearAuth();

    // Update authentication state
    await LocationTrackingService.stop();
    await FieldWorkTracker.clear();
    await ref.read(offlineSyncProvider.notifier).clearAll();

    AuthService.logout();

    if (!mounted) return;

    // Go to login and remove previous navigation history
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final selectedLanguage = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: AppColors.appBarColor,
        surfaceTintColor: AppColors.appBarColor,
        foregroundColor: AppColors.onAppBarColor,
        bottom: const TricolourStrip(),
        title: Text(
          ref.tr('settings.settings'),
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.onAppBarColor,
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
              // GENERAL
              _buildSectionTitle(ref.tr('settings.general')),

              const SizedBox(height: 8),

              _buildSettingsCard(
                children: [
                  _SettingsRow(
                    icon: Icons.notifications_none_rounded,
                    title: ref.tr('settings.notifications'),
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
                    title: ref.tr('settings.language'),
                    trailingText: selectedLanguage == AppLanguage.english
                        ? selectedLanguage.englishName
                        : selectedLanguage.hindiName,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const LanguageSelectionScreen(),
                        ),
                      );

                      // The server copy lets the choice follow the person to
                      // the web app; the local choice stands regardless.
                      final language = ref.read(languageProvider);

                      try {
                        await ref
                            .read(accountRepositoryProvider)
                            .savePreferences(language: language.code);
                      } catch (_) {}
                    },
                    isLast: true,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // SECURITY & PRIVACY
              _buildSectionTitle(ref.tr('settings.security_privacy')),

              const SizedBox(height: 16),

              _buildSettingsCard(
                children: [
                  _SettingsRow(
                    icon: Icons.lock_outline_rounded,
                    title: ref.tr('setx.changePassword'),
                    onTap: () => context.push(AppRoutes.changePassword),
                  ),

                  _SettingsRow(
                    icon: Icons.description_outlined,
                    title: ref.tr('termsx.title'),
                    onTap: () => context.push(AppRoutes.terms),
                  ),

                  _SettingsRow(
                    icon: Icons.person_remove_outlined,
                    title: ref.tr('delx.cardTitle'),
                    onTap: () => context.push(AppRoutes.deleteAccount),
                    isLast: true,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // PREFERENCES
              _buildSectionTitle(ref.tr('settings.preferences')),

              const SizedBox(height: 16),

              _buildSettingsCard(
                children: [
                  _SettingsRow(
                    icon: Icons.settings_outlined,
                    title: ref.tr('settings.helpSupport'),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const HelpSupportScreen(),
                        ),
                      );
                    },
                  ),

                  // _SettingsRow(
                  //   icon: Icons.dark_mode_outlined,
                  //   title: ref.tr('settings.dark_mode'),
                  //   trailing: Switch(
                  //     value: isDarkMode,
                  //     onChanged: (value) {
                  //       setState(() {
                  //         isDarkMode = value;
                  //       });
                  //     },
                  //     activeThumbColor: AppColors.primaryFillColor,
                  //     materialTapTargetSize:
                  //         MaterialTapTargetSize.shrinkWrap,
                  //   ),
                  //   isLast: true,
                  // ),
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
      onTap: _logout,
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
              ref.tr('settings.logout'),
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
    this.isLast = false,
  }) : trailing = null;

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
