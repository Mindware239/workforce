import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/setting/presentation/settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
       appBar: AppBar(
         backgroundColor: AppColors.whiteBackgroundColor,
          surfaceTintColor: AppColors.whiteBackgroundColor,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (context) => const SettingsScreen()));
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
          // physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(
            16
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildProfileHeader(),
        
              const SizedBox(height: 24),
        
              _buildEmploymentDetails(),
        
              const SizedBox(height: 16),
        
              _buildWorkplace(),
            ],
          ),
        ),
      ),
    );
  }

  
  Widget _buildProfileHeader() {
    return Column(
      children: [
        // Profile photo
        Container(
          width: 128,
          height: 128,
          decoration: BoxDecoration(
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
          'Alex Sharma',
          style: GoogleFonts.inter(
            fontSize: 30,
            
            fontWeight: FontWeight.bold,
            color: AppColors.textColor,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          'ID: EMP-0142',
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

  
  Widget _buildEmploymentDetails() {
    return _ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.business_center_outlined,
            title: 'Employment Details',
          ),

          const SizedBox(height: 8),

          _DetailItem(
            label: 'DEPARTMENT',
            value: 'Production',
          ),

          _DetailItem(
            label: 'DESIGNATION',
            value: 'Machine Operator',
          ),

          _DetailItem(
            label: 'JOINING DATE',
            value: 'Jan 12, 2022',
          ),

          _DetailItem(
            label: 'REPORTING MANAGER',
            value: ' Sarah Chen',
            isLast: true,
          ),
        ],
      ),
    );
  }

  
  Widget _buildWorkplace() {
    return _ProfileCard(
      padding: const EdgeInsets.all(
       16
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.location_on_outlined,
            title: 'Workplace',
          ),

          const SizedBox(height: 8),

          Container(
            width: double.infinity,
            // height: 55,
            padding: const EdgeInsets.all(
              8
            ),
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.business,
                    size: 20,
                    color: AppColors.primaryFillColor,
                  ),
                ),

                const SizedBox(width: 8),

                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRIMARY LOCATION',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: .2,
                        color: AppColors.mutedColor,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      'HQ – Factory Floor',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textColor,
                      ),
                    ),
                  ],
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
    this.padding = const EdgeInsets.all(
     16,
    ),
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