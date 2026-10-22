import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/app/routes/app_routes.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/styles/tricolour_strip.dart';
import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/widgets/feature_widgets.dart';

const String _supportEmail = 'support@workforcepro.com';
const String _supportPhone = '1-800-HR-SUPPORT';

/// A help topic: where it leads, and the words that find it (the same
/// keyword lists the web help page searches).
class _Topic {
  final String labelKey;
  final IconData icon;
  final String route;
  final String terms;

  const _Topic(this.labelKey, this.icon, this.route, this.terms);
}

const List<_Topic> _topics = [
  _Topic(
    'helpSupport.attendance',
    Icons.fact_check_outlined,
    AppRoutes.attendance,
    'attendance check in out selfie face verification shift',
  ),
  _Topic(
    'helpSupport.shiftSchedule',
    Icons.calendar_month_outlined,
    AppRoutes.monthlySummary,
    'shift schedule roster timing hours summary',
  ),
  _Topic(
    'helpSupport.salaryPayslip',
    Icons.payments_outlined,
    AppRoutes.myPay,
    'salary payslip pay overtime deduction pf esi',
  ),
  _Topic(
    'helpSupport.leaveTimeOff',
    Icons.flight_takeoff_outlined,
    AppRoutes.leaveRequest,
    'leave holiday time off casual sick earned absence',
  ),
];

class HelpSupportScreen extends ConsumerStatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  ConsumerState<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends ConsumerState<HelpSupportScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _copy(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));

    if (!mounted) return;

    showFeatureSnack(context, message);
  }

  void _contactHr() {
    _copy(
      _supportEmail,
      fill(ref.tr('helpx.emailCopied'), {'email': _supportEmail}),
    );
  }

  void _reportIssue() {
    final report = 'To: $_supportEmail\n'
        'Subject: WorkForce issue report\n\n'
        'Describe what happened:\n\n\n---\n'
        'Screen: \n'
        'Time: ${DateTime.now().toIso8601String()}';

    _copy(report, ref.tr('helpx.reportCopied'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: AppColors.appBarColor,
        surfaceTintColor: AppColors.appBarColor,
        foregroundColor: AppColors.onAppBarColor,
        bottom: const TricolourStrip(),
        title: Text(
          ref.tr('helpSupport.title'),
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.onAppBarColor,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHero(),
              const SizedBox(height: 12),
              _buildPopularTopics(),
              const SizedBox(height: 16),
              _buildSupportCard(
                title: ref.tr('helpSupport.directAssistanceTitle'),
                description: ref.tr('helpSupport.directAssistanceDescription'),
                button: ElevatedButton.icon(
                  onPressed: _contactHr,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryFillColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
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
              const SizedBox(height: 16),
              _buildSupportCard(
                title: ref.tr('helpSupport.foundBug'),
                description: ref.tr('helpSupport.bugDescription'),
                button: OutlinedButton.icon(
                  onPressed: _reportIssue,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.saffronText,
                    side: const BorderSide(color: AppColors.borderColor),
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
          const SizedBox(height: 16),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textColor),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              hintText: ref.tr('helpSupport.searchHint'),
              hintStyle: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.mutedColor,
              ),
              prefixIcon: const Icon(
                Icons.search,
                size: 18,
                color: AppColors.mutedColor,
              ),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(_search.clear),
                    ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularTopics() {
    final term = _search.text.trim().toLowerCase();
    final topics = _topics.where((topic) {
      if (term.isEmpty) return true;

      return topic.terms.contains(term) ||
          ref.tr(topic.labelKey).toLowerCase().contains(term);
    }).toList();

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
        if (topics.isEmpty)
          EmptyNote(ref.tr('helpx.noTopics'), icon: Icons.search_off_rounded)
        else
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 7,
            crossAxisSpacing: 7,
            childAspectRatio: 1.6,
            children: [
              for (final topic in topics)
                _TopicCard(
                  icon: topic.icon,
                  title: ref.tr(topic.labelKey),
                  onTap: () => context.push(topic.route),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildSupportCard({
    required String title,
    required String description,
    required Widget button,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedColor),
          ),
          const SizedBox(height: 12),
          SizedBox(height: 44, child: button),
        ],
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
        Center(
          child: _ContactRow(
            icon: Icons.email_outlined,
            text: _supportEmail,
            onTap: () => _copy(
              _supportEmail,
              fill(ref.tr('helpx.emailCopied'), {'email': _supportEmail}),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: _ContactRow(
            icon: Icons.phone_outlined,
            text: _supportPhone,
            onTap: () => _copy(
              _supportPhone,
              fill(ref.tr('helpx.phoneCopied'), {'phone': _supportPhone}),
            ),
          ),
        ),
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
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
                  color: AppColors.saffronTint,
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

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _ContactRow({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primaryFillColor),
            const SizedBox(width: 8),
            Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.saffronText,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.copy_rounded,
              size: 13,
              color: AppColors.mutedColor,
            ),
          ],
        ),
      ),
    );
  }
}
