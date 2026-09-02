import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/core/styles/app_colors.dart';

class MonthlySummaryScreen extends StatelessWidget {
  const MonthlySummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: AppBar(
         backgroundColor: AppColors.whiteBackgroundColor,
          surfaceTintColor: AppColors.whiteBackgroundColor,
        title: Text(
          'Monthly Summary',
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
              _buildHeader(),

              const SizedBox(height: 16),

              _buildAttendanceRate(),

              const SizedBox(height: 16),

              _buildMiniStats(),

              const SizedBox(height: 16),

              _buildHoursLogged(),

              const SizedBox(height: 16),

              _buildWeeklyBreakdown(),

              const SizedBox(height: 16),

              _buildExceptions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'October Summary',
          style: GoogleFonts.inter(
            fontSize: 30,
            height: 1,
            fontWeight: FontWeight.bold,
            color: AppColors.textColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your monthly performance and attendance overview.',
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.15,
            color: AppColors.mutedColor,
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceRate() {
    return _SummaryCard(
      height: 104,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'ATTENDANCE RATE',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .35,
                    color: AppColors.mutedColor,
                  ),
                ),

                const Spacer(),

                const Icon(
                  Icons.verified_outlined,
                  size: 16,
                  color: AppColors.primaryFillColor,
                ),
              ],
            ),

            const Spacer(),

            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '96%',
                  style: GoogleFonts.inter(
                    fontSize: 30,
                    height: 1,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textColor,
                  ),
                ),

                const SizedBox(width: 12),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2DFFF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+2% vs Sep',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryFillColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStats() {
    return Row(
      children: [
        Expanded(
          child: _SmallStatCard(
            title: 'DAYS WORKED',
            value: '25',
            secondaryValue: ' / 26',
            icon: Icons.calendar_today_outlined,
          ),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: _SmallStatCard(
            title: 'AVG PRODUCTIVITY',
            value: '92%',
            icon: Icons.trending_up,
          ),
        ),
      ],
    );
  }

  Widget _buildHoursLogged() {
    return _SummaryCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL HOURS LOGGED',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .3,
                      color: AppColors.mutedColor,
                    ),
                  ),

                  const SizedBox(height: 8),

                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '208',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textColor,
                          ),
                        ),
                        TextSpan(
                          text: ' h',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.mutedColor,
                          ),
                        ),
                        TextSpan(
                          text: ' · ',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.mutedColor,
                          ),
                        ),
                        TextSpan(
                          text: '15h Overtime',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF7E3000),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F2FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.chevron_right,
                size: 14,
                color: AppColors.mutedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyBreakdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Weekly Hours Breakdown',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textColor,
          ),
        ),

        const SizedBox(height: 8),

        Container(
          width: double.infinity,
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderColor, width: 1),
          ),
          child: const _WeeklyChart(),
        ),
      ],
    );
  }

  Widget _buildExceptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notable Exceptions',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textColor,
          ),
        ),

        const SizedBox(height: 8),

        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderColor, width: 1),
          ),
          child: Column(
            children: [
              _ExceptionRow(
                icon: Icons.access_time,
                title: 'Late Arrival',
                subtitle: 'Oct 12 · 15 mins late',
                color: const Color(0xFFD9414D),
              ),

              _ExceptionRow(
                icon: Icons.access_time,
                title: 'Late Arrival',
                subtitle: 'Oct 28 · 10 mins late',
                color: const Color(0xFFD9414D),
              ),

              _ExceptionRow(
                icon: Icons.trending_up,
                title: 'Consistent Punctuality',
                subtitle: 'Top 5% in department this month',
                color: const Color(0xFF8566A8),
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ================================================================
// SUMMARY CARD
// ================================================================

class _SummaryCard extends StatelessWidget {
  final Widget child;
  final double? height;

  const _SummaryCard({required this.child, this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: .8),
      ),
      child: child,
    );
  }
}

class _SmallStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? secondaryValue;
  final IconData icon;

  const _SmallStatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.secondaryValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 114,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TITLE
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: .35,
              color: AppColors.mutedColor,
            ),
          ),

          const SizedBox(height: 8),

          // VALUE
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textColor,
                ),
              ),

              if (secondaryValue != null)
                Text(
                  secondaryValue!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.mutedColor,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // ICON
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,

              border: Border.all(color: AppColors.borderColor, width: 1),
            ),
            child: Icon(icon, size: 16, color: AppColors.mutedColor),
          ),
        ],
      ),
    );
  }
}

class _ExceptionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isLast;

  const _ExceptionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // height: 73,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.borderColor, width: .7),
              ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: .10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
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
          ),

          const Icon(
            Icons.chevron_right,
            size: 18,
            color: AppColors.mutedColor,
          ),
        ],
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WeeklyChartPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _WeeklyChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

 
    const double left = 2;
    final double right = width - 2;

    const double top = 8;
    final double bottom = height - 22;

    final double chartWidth = right - left;
    final double chartHeight = bottom - top;

   
    final gridPaint = Paint()
      ..color = const Color(0xFFD9C5CC)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final baselinePaint = Paint()
      ..color = const Color(0xFFB99FA8)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final purplePaint = Paint()
      ..color = const Color(0xFF9B6AE8)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final orangePaint = Paint()
      ..color = const Color(0xFFFFC15C)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final purplePointPaint = Paint()
      ..color = const Color(0xFF9B6AE8)
      ..style = PaintingStyle.fill;

    final orangePointPaint = Paint()
      ..color = const Color(0xFFFFC15C)
      ..style = PaintingStyle.fill;

  
    final middleY = top + chartHeight * 0.55;

    canvas.drawLine(
      Offset(left, middleY),
      Offset(right, middleY),
      gridPaint,
    );

  
    canvas.drawLine(
      Offset(left, bottom),
      Offset(right, bottom),
      baselinePaint,
    );

 
    final purplePoints = [
      Offset(
        left,
        bottom - chartHeight * 0.08,
      ),
      Offset(
        left + chartWidth * 0.16,
        top + chartHeight * 0.48,
      ),
      Offset(
        left + chartWidth * 0.33,
        top + chartHeight * 0.72,
      ),
      Offset(
        left + chartWidth * 0.50,
        top + chartHeight * 0.55,
      ),
      Offset(
        left + chartWidth * 0.67,
        top + chartHeight * 0.20,
      ),
      Offset(
        left + chartWidth * 0.83,
        top + chartHeight * 0.58,
      ),
      Offset(
        right,
        top,
      ),
    ];

    // ============================================================
    // ORANGE DATA
    // ============================================================

    final orangePoints = [
      Offset(
        left,
        bottom - chartHeight * 0.08,
      ),
      Offset(
        left + chartWidth * 0.16,
        top,
      ),
      Offset(
        left + chartWidth * 0.33,
        top + chartHeight * 0.28,
      ),
      Offset(
        left + chartWidth * 0.50,
        top + chartHeight * 0.48,
      ),
      Offset(
        left + chartWidth * 0.67,
        top + chartHeight * 0.60,
      ),
      Offset(
        left + chartWidth * 0.83,
        top + chartHeight * 0.75,
      ),
      Offset(
        right,
        top + chartHeight * 0.28,
      ),
    ];

    // ============================================================
    // DRAW PURPLE LINE
    // ============================================================

    final purplePath = Path()
      ..moveTo(
        purplePoints.first.dx,
        purplePoints.first.dy,
      );

    for (int i = 1; i < purplePoints.length; i++) {
      purplePath.lineTo(
        purplePoints[i].dx,
        purplePoints[i].dy,
      );
    }

    canvas.drawPath(
      purplePath,
      purplePaint,
    );

    // ============================================================
    // DRAW ORANGE LINE
    // ============================================================

    final orangePath = Path()
      ..moveTo(
        orangePoints.first.dx,
        orangePoints.first.dy,
      );

    for (int i = 1; i < orangePoints.length; i++) {
      orangePath.lineTo(
        orangePoints[i].dx,
        orangePoints[i].dy,
      );
    }

    canvas.drawPath(
      orangePath,
      orangePaint,
    );

    // ============================================================
    // DRAW PURPLE POINTS
    // ============================================================

    for (final point in purplePoints) {
      canvas.drawCircle(
        point,
        3.5,
        purplePointPaint,
      );
    }

    // ============================================================
    // DRAW ORANGE POINTS
    // ============================================================

    for (final point in orangePoints) {
      canvas.drawCircle(
        point,
        3.5,
        orangePointPaint,
      );
    }

    // ============================================================
    // WEEK LABELS
    // ============================================================

    const labels = [
      'W1',
      'W2',
      'W3',
      'W4',
      'W5',
    ];

    // Labels are placed between the chart points.
    final labelPositions = [
      chartWidth * 0.09,
      chartWidth * 0.29,
      chartWidth * 0.49,
      chartWidth * 0.69,
      chartWidth * 0.89,
    ];

    for (int i = 0; i < labels.length; i++) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 8,
            fontWeight: FontWeight.w500,
            color: Color(0xFF75666C),
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      final x = left + labelPositions[i];

      textPainter.paint(
        canvas,
        Offset(
          x - textPainter.width / 2,
          bottom + 10,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}