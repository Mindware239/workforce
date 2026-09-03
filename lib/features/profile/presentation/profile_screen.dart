import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/auth/providers/auth_provider.dart';
import 'package:workforce/features/profile/presentation/bank_details_widget.dart';
import 'package:workforce/features/setting/presentation/settings_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    debugPrint("Hello:-->'$user?.toString()'");

    final String fullName = user?['fullName']?.toString() ?? 'Employee';
    final String employeeId = user?['employeeId']?.toString() ?? '-';
    final String mobileNumber = user?['mobileNumber']?.toString() ?? '-';
    final String email = user?['email']?.toString() ?? '-';
    final String role = user?['role']?.toString() ?? '-';
    final String organizationName =
        user?['organizationName']?.toString() ?? '-';
    final String workspaceId = user?['workspaceId']?.toString() ?? '-';
    final String organizationId =
        user?['organizationId']?.toString() ?? '-';

    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.whiteBackgroundColor,
        surfaceTintColor: AppColors.whiteBackgroundColor,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
            icon: const Icon(
              Icons.settings_outlined,
              color: AppColors.primaryFillColor,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildProfileHeader(
                fullName: fullName,
                employeeId: employeeId,
              ),

              const SizedBox(height: 24),

              _buildEmploymentDetails(
                role: role,
                mobileNumber: mobileNumber,
                email: email,
              ),

              const SizedBox(height: 16),

              _buildWorkplace(
                organizationName: organizationName,
                workspaceId: workspaceId,
                organizationId: organizationId,
              ),
               const SizedBox(height: 16),

              BankDetailsWidget()
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader({
    required String fullName,
    required String employeeId,
  }) {
    return Column(
      children: [
        Container(
          width: 128,
          height: 128,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/profile.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return const Icon(
                  Icons.person,
                  size: 45,
                  color: Colors.white,
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 7),

        Text(
          fullName,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: AppColors.textColor,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          'ID: $employeeId',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppColors.mutedColor,
          ),
        ),

        const SizedBox(height: 8),

        SizedBox(
          width: 160,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryFillColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(
              Icons.edit_outlined,
              size: 16,
            ),
            label: Text(
              'Edit Profile',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmploymentDetails({
    required String role,
    required String mobileNumber,
    required String email,
  }) {
    return _ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            icon: Icons.business_center_outlined,
            title: 'Employment Details',
          ),

          const SizedBox(height: 8),

          _DetailItem(
            label: 'ROLE',
            value: role,
          ),

          _DetailItem(
            label: 'MOBILE NUMBER',
            value: mobileNumber,
          ),

          _DetailItem(
            label: 'EMAIL',
            value: email,
          ),

          const _DetailItem(
            label: 'DEPARTMENT',
            value: 'Not available',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildWorkplace({
    required String organizationName,
    required String workspaceId,
    required String organizationId,
  }) {
    return _ProfileCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            icon: Icons.location_on_outlined,
            title: 'Workplace',
          ),

          const SizedBox(height: 8),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.borderColor,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3525CD).withValues(
                      alpha: 0.1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.business,
                    size: 20,
                    color: AppColors.primaryFillColor,
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ORGANIZATION',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: .2,
                          color: AppColors.mutedColor,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        organizationName,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textColor,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        'Workspace: $workspaceId',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.mutedColor,
                        ),
                      ),
                    ],
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

class _ProfileCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _ProfileCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.borderColor,
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

class _CardHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _CardHeader({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.primaryFillColor,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textColor,
          ),
        ),
      ],
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _DetailItem({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: .25,
              color: AppColors.mutedColor,
            ),
          ),

          const SizedBox(height: 2),

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
    );
  }
}