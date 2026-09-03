import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CurrentDateText extends StatelessWidget {
  const CurrentDateText({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final currentDate =
        '${weekdays[now.weekday - 1]}, '
        '${months[now.month - 1]} ${now.day}';

    return Text(
      currentDate,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: const Color(0xFF585E6F),
      ),
    );
  }
}