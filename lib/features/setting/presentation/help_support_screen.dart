import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/core/styles/app_colors.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: AppColors.whiteBackgroundColor,
        surfaceTintColor: AppColors.whiteBackgroundColor,
        title: Text(
          'Help & Support',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textColor,
          ),
        ),
       
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          // physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHero(),
        
              const SizedBox(height: 12),
        
              _buildPopularTopics(),
        
              const SizedBox(height: 16),
        
              _buildDirectAssistance(),
        
              const SizedBox(height: 16),
        
              _buildBugReport(),
        
              const SizedBox(height: 24),
        
              _buildEnterpriseSupport(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      height: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryFillColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Help & Support',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Find answers and get help with your account.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withValues(alpha: .78),
            ),
          ),

          const Spacer(),

          Container(
            height: 48,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),

                const Icon(Icons.search, size: 18, color: AppColors.mutedColor),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    'How can we help?',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.mutedColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularTopics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Popular Topics',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textColor,
          ),
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: _TopicCard(
                icon: Icons.fact_check_outlined,
                title: 'Attendance',
                onTap: () {},
              ),
            ),

            const SizedBox(width: 7),

            Expanded(
              child: _TopicCard(
                icon: Icons.calendar_month_outlined,
                title: 'Shift & Schedule',
                onTap: () {},
              ),
            ),
          ],
        ),

        const SizedBox(height: 7),

        Row(
          children: [
            Expanded(
              child: _TopicCard(
                icon: Icons.payments_outlined,
                title: 'Salary & Payslip',
                onTap: () {},
              ),
            ),

            const SizedBox(width: 7),

            Expanded(
              child: _TopicCard(
                icon: Icons.flight_takeoff_outlined,
                title: 'Leave & Time Off',
                onTap: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDirectAssistance() {
    return _SupportCard(
      height: 144,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Need direct assistance?',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textColor,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              'Get in touch with your HR representative.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.mutedColor,
              ),
            ),

            const Spacer(),

            SizedBox(
              width: 140,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryFillColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.support_agent_outlined, size: 16),
                label: Text(
                  'Contact HR',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBugReport() {
    return _SupportCard(
      height: 144,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Found a bug?',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textColor,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              'Help us improve by reporting technical issues.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.mutedColor,
              ),
            ),

            const Spacer(),

            SizedBox(
              width: 140,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryFillColor,
                  side: const BorderSide(color: AppColors.borderColor, width: 1),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.bug_report_outlined, size: 16),
                label: Text(
                  'Report Issue',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnterpriseSupport() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 1,
          color: AppColors.borderColor,
        ),

        const SizedBox(height: 16),

        Text(
          'ENTERPRISE SUPPORT CONTACT',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: .35,
            color: AppColors.mutedColor,
          ),
        ),

        const SizedBox(height: 12),

        _ContactRow(
          icon: Icons.email_outlined,
          text: 'support@workforcepro.com',
        ),

        const SizedBox(height: 8),

        _ContactRow(icon: Icons.phone_outlined, text: '1-800-HR-SUPPORT'),

        const SizedBox(height: 12),

        Text(
          'Available Monday - Friday, 9AM - 5PM EST',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedColor),
        ),
      ],
    );
  }
}

class _TopicCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _TopicCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 102,
          decoration: BoxDecoration(
          
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderColor, width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFDADFF3),
                ),
                child: Icon(icon, size: 20, color: AppColors.primaryFillColor),
              ),

              const SizedBox(height: 8),

              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  final Widget child;
  final double height;

  const _SupportCard({required this.child, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
      
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: child,
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ContactRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: AppColors.primaryFillColor),

        const SizedBox(width: 8),

        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.primaryFillColor,
          ),
        ),
      ],
    );
  }
}
