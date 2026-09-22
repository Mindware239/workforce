import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/localization/app_localization.dart';

class HelpSupportScreen extends ConsumerWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: AppColors.whiteBackgroundColor,
        surfaceTintColor: AppColors.whiteBackgroundColor,
        title: Text(
          ref.tr('helpSupport.title'),
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
              _buildHero(ref),
        
              const SizedBox(height: 12),
        
              _buildPopularTopics(ref),
        
              const SizedBox(height: 16),
        
              _buildDirectAssistance(ref),
        
              const SizedBox(height: 16),
        
              _buildBugReport(ref),
        
              const SizedBox(height: 24),
        
              _buildEnterpriseSupport(ref),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(WidgetRef ref) {
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
            ref.tr('helpSupport.title'),
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            ref.tr('helpSupport.heroDescription'),
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
                    ref.tr('helpSupport.searchHint'),
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

  Widget _buildPopularTopics(WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ref.tr('helpSupport.popularTopics'),
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
                title: ref.tr('helpSupport.attendance'),
                onTap: () {},
              ),
            ),

            const SizedBox(width: 7),

            Expanded(
              child: _TopicCard(
                icon: Icons.calendar_month_outlined,
                title: ref.tr('helpSupport.shiftSchedule'),
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
                title: ref.tr('helpSupport.salaryPayslip'),
                onTap: () {},
              ),
            ),

            const SizedBox(width: 7),

            Expanded(
              child: _TopicCard(
                icon: Icons.flight_takeoff_outlined,
                title: ref.tr('helpSupport.leaveTimeOff'),
                onTap: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDirectAssistance(WidgetRef ref) {
    return _SupportCard(
      height: 144,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ref.tr('helpSupport.directAssistanceTitle'),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textColor,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              ref.tr('helpSupport.directAssistanceDescription'),
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
                  ref.tr('helpSupport.contactHr'),
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

  Widget _buildBugReport(WidgetRef ref) {
    return _SupportCard(
      height: 144,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ref.tr('helpSupport.foundBug'),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textColor,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              ref.tr('helpSupport.bugDescription'),
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
                  ref.tr('helpSupport.reportIssue'),
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

  Widget _buildEnterpriseSupport(WidgetRef ref) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 1,
          color: AppColors.borderColor,
        ),

        const SizedBox(height: 16),

        Text(
          ref.tr('helpSupport.enterpriseSupportContact'),
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
          ref.tr('helpSupport.availability'),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedColor),
        ),
      ],
    );
  }
}

class _TopicCard extends ConsumerWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _TopicCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

