import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/core/styles/app_colors.dart';

class LeaveRequestScreen extends StatefulWidget {
  const LeaveRequestScreen({super.key});

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen> {
  String leaveType = 'Casual Leave';
  String days = '1';

  final TextEditingController startDateController = TextEditingController();
  final TextEditingController endDateController = TextEditingController();
  final TextEditingController reasonController = TextEditingController();

  @override
  void dispose() {
    startDateController.dispose();
    endDateController.dispose();
    reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            
              _buildHeader(),

              const SizedBox(height: 16),

              _buildBalanceCards(),

              const SizedBox(height: 16),

              _buildNewRequest(),

              const SizedBox(height: 16),

              _buildRecentRequests(),
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
          'Leave Request',
          style: GoogleFonts.inter(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: AppColors.textColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Submit a new time-off request or check your current balances.',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.mutedColor),
        ),
      ],
    );
  }

  Widget _buildBalanceCards() {
    return Row(
      children: [
        Expanded(
          child: _BalanceCard(
            title: 'CASUAL\nLEAVE',
            value: '6',
            suffix: 'days left',
            icon: Icons.event_available_outlined,
            textColor: AppColors.primaryFillColor,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _BalanceCard(
            title: 'SICK LEAVE',
            value: '4',
            suffix: 'days left',
            icon: Icons.sick_outlined,
            textColor: const Color(0xFF7E3000),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _BalanceCard(
            title: 'EARNED\nLEAVE',
            value: '8',
            suffix: 'days left',
            icon: Icons.beach_access_outlined,
            textColor: const Color(0xFF059669),
          ),
        ),
      ],
    );
  }

  Widget _buildNewRequest() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('New Request'),

          const SizedBox(height: 12),

          _FieldLabel('Leave Type'),

          _DropdownField(
            value: leaveType,
            onChanged: (value) {
              if (value == null) return;

              setState(() {
                leaveType = value;
              });
            },
            items: const ['Casual Leave', 'Sick Leave', 'Earned Leave'],
          ),

          const SizedBox(height: 8),

          _FieldLabel('Number of Days'),

          _TextField(
            controller: TextEditingController(text: days),
            keyboardType: TextInputType.number,
          ),

          const SizedBox(height: 8),

          _FieldLabel('Start Date'),

          _TextField(
            controller: startDateController,
            hint: 'mm/dd/yyyy',
            suffixIcon: Icons.calendar_today_outlined,
          ),

          const SizedBox(height: 8),

          _FieldLabel('End Date'),

          _TextField(
            controller: endDateController,
            hint: 'mm/dd/yyyy',
            suffixIcon: Icons.calendar_today_outlined,
          ),

          const SizedBox(height: 8),

          _FieldLabel('Reason'),

          _TextField(
            controller: reasonController,
            hint: 'Please provide a brief reason for your leave...',
            maxLines: 4,
          ),

          const SizedBox(height: 16),

          _FieldLabel('Attachment (Optional)'),

          Container(
            width: double.infinity,
            height: 94,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderColor, width: 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.file_upload_outlined,
                  size: 20,
                  color: AppColors.mutedColor,
                ),

                const SizedBox(height: 4),

                Text(
                  'Click to upload medical certificate or supporting documents',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.mutedColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                width: 94,
                height: 48,
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    side: const BorderSide(
                      color: AppColors.borderColor,
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryFillColor,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              SizedBox(
                width: 148,
                height: 48,
                child: ElevatedButton(
                  onPressed: _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryFillColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Submit Request',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

 
  Widget _buildRecentRequests() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Requests',
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
              _RecentRequest(
                icon: Icons.event_busy_outlined,
                title: 'Sick Leave (2 Days)',
                date: 'Oct 12 - Oct 13, 2023',
                status: 'PENDING',
                statusColor: const Color(0xFFE68A00),
              ),
              _RecentRequest(
                icon: Icons.beach_access_outlined,
                title: 'Casual Leave (1 Day)',
                date: 'Oct 5, 2023',
                status: 'APPROVED',
                statusColor: const Color(0xFF2E7D32),
              ),

              _RecentRequest(
                icon: Icons.work_history_outlined,
                title: 'Earned Leave (5 Days)',
                date: 'Aug 10 - Aug 14, 2022',
                status: 'REJECTED',
                statusColor: const Color(0xFFB71C1C),
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textColor,
      ),
    );
  }

  void _submitRequest() {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Leave request submitted')));
  }
}

class _BalanceCard extends StatelessWidget {
  final String title;
  final String value;
  final String suffix;
  final IconData icon;
  final Color textColor;

  const _BalanceCard({
    required this.title,
    required this.value,
    required this.suffix,
    required this.icon,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
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
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedColor,
            ),
          ),

          const Spacer(),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 30,
                  height: .9,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(
                  suffix,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.mutedColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: child,
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.mutedColor,
        ),
      ),
    );
  }
}


class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final IconData? suffixIcon;
  final int maxLines;
  final TextInputType? keyboardType;

  const _TextField({
    required this.controller,
    this.hint,
    this.suffixIcon,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(fontSize: 14, color: AppColors.textColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.mutedColor),
        suffixIcon: suffixIcon == null
            ? null
            : Icon(suffixIcon, size: 16, color: AppColors.mutedColor),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderColor, width: .8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderColor, width: .8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primaryFillColor,
            width: 1,
          ),
        ),
      ),
    );
  }
}


class _DropdownField extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;
  final List<String> items;

  const _DropdownField({
    required this.value,
    required this.onChanged,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      style: GoogleFonts.inter(fontSize: 7, color: AppColors.textColor),
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        size: 13,
        color: AppColors.mutedColor,
      ),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.borderColor, width: .8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.borderColor, width: .8),
        ),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(value: item, child: Text(item)),
          )
          .toList(),
    );
  }
}


class _RecentRequest extends StatelessWidget {
  final IconData icon;
  final String title;
  final String date;
  final String status;
  final Color statusColor;
  final bool isLast;

  const _RecentRequest({
    required this.icon,
    required this.title,
    required this.date,
    required this.status,
    required this.statusColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // height: 72,
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
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFEDE5F7),
            ),
            child: Icon(icon, size: 20, color: AppColors.mutedColor),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  date,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.mutedColor,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
