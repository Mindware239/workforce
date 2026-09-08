import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:workforce/app/routes/app_routes.dart';

import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/profile/presentation/bank_details_widget.dart';
import 'package:workforce/features/profile/providers/profile_provider.dart';
import 'package:workforce/features/setting/presentation/settings_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      ref.read(profileProvider.notifier).getProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);

    final profile = profileState.profile ?? {};

    final fullName =
        profile['fullName']?.toString() ?? 'Employee';

    final employeeId =
        profile['employeeId']?.toString() ?? '-';

    final mobileNumber =
        profile['mobileNumber']?.toString() ?? '-';

    final email =
        profile['email']?.toString() ?? '-';

    final role =
        profile['role']?.toString() ?? '-';

    final organizationName =
        _getValue(profile['organizationName']);

    final organizationId =
        _getValue(profile['organizationId']);

    final workspaceId =
        _getValue(
          profile['workspaceId'] ??
              profile['workspace'] ??
              profile['workspaceId'],
        );

    final department =
        _getValue(profile['department']);

    final designation =
        _getValue(profile['designation']);

    final joiningDate =
        _getValue(
          profile['joiningDate'] ??
              profile['dateOfJoining'],
        );

    final reportingManager =
        _getValue(
          profile['reportingManager'] ??
              profile['reportingManagerName'] ??
              profile['manager'],
        );

    final hasPhoto =
        profile['hasPhoto'] == true;

    final photoPath =
        profile['photoPath']?.toString();

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
        child: profileState.isLoading && profileState.profile == null
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : profileState.error != null &&
                    profileState.profile == null
                ? _buildError(profileState.error!)
                : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildProfileHeader(
                        fullName: fullName,
                        employeeId: employeeId,
                        hasPhoto: hasPhoto,
                        photoPath: photoPath,
                      ),
                
                      const SizedBox(height: 24),
                
                      _buildEmploymentDetails(
                        role: role,
                        designation: designation,
                        mobileNumber: mobileNumber,
                        email: email,
                        department: department,
                        joiningDate: joiningDate,
                        reportingManager: reportingManager,
                      ),
                
                      const SizedBox(height: 16),
                
                      _buildWorkplace(
                        organizationName: organizationName,
                        workspaceId: workspaceId,
                        organizationId: organizationId,
                      ),
                
                      const SizedBox(height: 16),
                
                      _buildDocument(context),
                
                      const SizedBox(height: 16),
                
                      const BankDetailsWidget(),
                    ],
                  ),
                ),
      ),
    );
  }

  // ============================================================
  // PROFILE HEADER
  // ============================================================

  Widget _buildProfileHeader({
    required String fullName,
    required String employeeId,
    required bool hasPhoto,
    required String? photoPath,
  }) {
    final photoUrl = _getPhotoUrl(
      hasPhoto: hasPhoto,
      photoPath: photoPath,
    );

    return Column(
      children: [
        Container(
          width: 128,
          height: 128,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryFillColor,
            border: Border.all(
              color: AppColors.borderColor,
              width: 1,
            ),
          ),
          child: ClipOval(
            child: photoUrl != null
                ? Image.network(
                    photoUrl,
                    width: 128,
                    height: 128,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return _buildInitials(fullName);
                    },
                    loadingBuilder: (
                      context,
                      child,
                      loadingProgress,
                    ) {
                      if (loadingProgress == null) {
                        return child;
                      }

                      return _buildInitials(fullName);
                    },
                  )
                : _buildInitials(fullName),
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

        // SizedBox(
        //   width: 160,
        //   height: 48,
        //   child: ElevatedButton.icon(
        //     onPressed: () {},
        //     style: ElevatedButton.styleFrom(
        //       backgroundColor: AppColors.primaryFillColor,
        //       foregroundColor: Colors.white,
        //       elevation: 0,
        //       padding: EdgeInsets.zero,
        //       shape: RoundedRectangleBorder(
        //         borderRadius: BorderRadius.circular(8),
        //       ),
        //     ),
        //     icon: const Icon(
        //       Icons.edit_outlined,
        //       size: 16,
        //     ),
        //     label: Text(
        //       'Edit Profile',
        //       style: GoogleFonts.inter(
        //         fontSize: 16,
        //         fontWeight: FontWeight.w600,
        //       ),
        //     ),
        //   ),
        // ),
      
      
      ],
    );
  }

  Widget _buildInitials(String fullName) {
    return Container(
      width: 128,
      height: 128,
      color: AppColors.primaryFillColor,
      alignment: Alignment.center,
      child: Text(
        _getInitials(fullName),
        style: GoogleFonts.inter(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'E';
    }

    if (parts.length == 1) {
      final value = parts.first;

      return value.length >= 2
          ? value.substring(0, 2).toUpperCase()
          : value.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}'
        '${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  // ============================================================
  // PHOTO URL
  // ============================================================

  String? _getPhotoUrl({
    required bool hasPhoto,
    required String? photoPath,
  }) {
    if (!hasPhoto) {
      return null;
    }

    if (photoPath == null || photoPath.isEmpty) {
      return null;
    }

    return 'https://workforce.orkuts.com/uploads/$photoPath';
  }

  // ============================================================
  // EMPLOYMENT DETAILS
  // ============================================================

  Widget _buildEmploymentDetails({
    required String role,
    required String designation,
    required String mobileNumber,
    required String email,
    required String department,
    required String joiningDate,
    required String reportingManager,
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
            label: 'DESIGNATION',
            value: designation,
          ),

          _DetailItem(
            label: 'DEPARTMENT',
            value: department,
          ),

          _DetailItem(
            label: 'MOBILE NUMBER',
            value: mobileNumber,
          ),

          _DetailItem(
            label: 'EMAIL',
            value: email,
          ),

          _DetailItem(
            label: 'JOINING DATE',
            value: joiningDate,
          ),

          _DetailItem(
            label: 'REPORTING MANAGER',
            value: reportingManager,
            isLast: true,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // WORKPLACE
  // ============================================================

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
              borderRadius: BorderRadius.circular(12),
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
                    color: const Color(0xFF3525CD)
                        .withValues(alpha: 0.1),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textColor,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        'Workspace: $workspaceId',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.mutedColor,
                        ),
                      ),

                      if (organizationId != '-') ...[
                        const SizedBox(height: 2),

                        Text(
                          'Organization ID: $organizationId',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppColors.mutedColor,
                          ),
                        ),
                      ],
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

  // ============================================================
  // DOCUMENTS
  // ============================================================

  Widget _buildDocument(BuildContext context) {
    return _ProfileCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            icon: Icons.file_copy,
            title: 'Documents',
          ),

          const SizedBox(height: 8),

          OutlinedButton(
            onPressed: () {
              context.push(AppRoutes.document);
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              minimumSize: Size.zero,
              tapTargetSize:
                  MaterialTapTargetSize.shrinkWrap,
              side: const BorderSide(
                color: AppColors.borderColor,
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'View & Upload Documents',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: .2,
                color: AppColors.mutedColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.redAccent,
            ),

            const SizedBox(height: 12),

            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textColor,
              ),
            ),

            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: () {
                ref
                    .read(profileProvider.notifier)
                    .getProfile();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // VALUE HELPER
  // ============================================================

  String _getValue(dynamic value) {
    if (value == null) {
      return 'Not available';
    }

    if (value is String) {
      return value.isEmpty ? 'Not available' : value;
    }

    if (value is num || value is bool) {
      return value.toString();
    }

    if (value is Map) {
      final possibleKeys = [
        'name',
        'fullName',
        'title',
        'label',
        'value',
        'id',
      ];

      for (final key in possibleKeys) {
        final nestedValue = value[key];

        if (nestedValue != null &&
            nestedValue.toString().isNotEmpty) {
          return nestedValue.toString();
        }
      }
    }

    return value.toString();
  }
}

// ================================================================
// PROFILE CARD
// ================================================================

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

// ================================================================
// CARD HEADER
// ================================================================

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

// ================================================================
// DETAIL ITEM
// ================================================================

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
      padding: const EdgeInsets.symmetric(
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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