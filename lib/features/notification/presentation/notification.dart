import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/core/styles/app_colors.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,

      appBar: AppBar(
        centerTitle: true,
        backgroundColor: AppColors.whiteBackgroundColor,
        surfaceTintColor: AppColors.whiteBackgroundColor,
        title: Text(
          'Notification',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryFillColor,
          ),
         
        ),
        actions: [

          TextButton(
  onPressed: () {
    // Mark all notifications as read
  },
  style: TextButton.styleFrom(
    // padding: EdgeInsets.zero,
    // minimumSize: Size.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  ),
  child: Text(
    'Mark all\nas read',
    textAlign: TextAlign.center,
    style: GoogleFonts.inter(
      fontSize: 12,
      height: 1.15,
      fontWeight: FontWeight.w600,
      color: AppColors.primaryFillColor,
    ),
  ),
),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // _buildHeader(context),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(
                 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // const SizedBox(height: 12),

                    _buildSectionTitle('TODAY'),

                    const SizedBox(height: 8),

                    _NotificationItem(
                      icon: Icons.fingerprint_rounded,
                      title: 'Attendance successfully recorded',
                      time: '10:30 AM',
                      unread: true,
                    ),

                    _NotificationItem(
                      icon: Icons.receipt_long_outlined,
                      title: 'Salary credited',
                      time: '09:00 AM',
                    ),

                    const SizedBox(height: 20),

                    _buildSectionTitle('EARLIER'),

                    const SizedBox(height: 5),

                    _NotificationItem(
                      icon: Icons.fact_check_outlined,
                      title: 'Leave request approved',
                      time: 'Yesterday, 2:15 PM',
                    ),

                    _NotificationItem(
                      icon: Icons.calendar_month_outlined,
                      title: 'Shift schedule updated',
                      time: 'Oct 24, 11:00 AM',
                    ),

                    const SizedBox(height: 20),

                    Center(
                      child: Text(
                        "You're all caught up",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.borderColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 8,
      ),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: .5,
          color: AppColors.mutedColor,
        ),
      ),
    );
  }
}


class _NotificationItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String time;
  final bool unread;

  const _NotificationItem({
    required this.icon,
    required this.title,
    required this.time,
    this.unread = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.borderColor,
            width: .7,
          ),
        ),
      ),
      child: Row(
        children: [
          // UNREAD DOT
          SizedBox(
            width: 12,
            child: unread
                ? Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryFillColor,
                    ),
                  )
                : null,
          ),

          // ICON
          Container(
            width: 25,
            height: 25,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
              color: AppColors.primaryFillColor,
            ),
          ),

          const SizedBox(width: 8),

          // CONTENT
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: unread
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: AppColors.textColor,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  time,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.mutedColor,
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