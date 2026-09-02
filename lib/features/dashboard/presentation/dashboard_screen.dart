import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/core/styles/app_colors.dart';

import 'package:workforce/features/attendence/presentation/attendence_screen.dart';
import 'package:workforce/features/home/presentation/home_screen.dart';
import 'package:workforce/features/profile/presentation/profile_screen.dart';
import 'package:workforce/features/schedule/presentation/schedule_screen.dart';

class DashboardPage extends StatefulWidget {
  final int index;

  const DashboardPage({super.key, this.index = 0});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late int selectedIndex;

  static const List<Widget> screens = [
    HomeScreen(),
    AttendanceScreen(),
    ScheduleScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    selectedIndex = _validateIndex(widget.index);
  }

  int _validateIndex(int index) {
    if (index < 0 || index >= screens.length) {
      return 0;
    }

    return index;
  }

  @override
  void didUpdateWidget(DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.index != widget.index) {
      setState(() {
        selectedIndex = _validateIndex(widget.index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: selectedIndex, children: screens),
      bottomNavigationBar: _DashboardBottomNav(
        currentIndex: selectedIndex,
        onTap: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
      ),
    );
  }
}

class _DashboardBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _DashboardBottomNav({required this.currentIndex, required this.onTap});

  static const List<_NavItem> items = [
    _NavItem(label: 'Dashboard', icon: 'assets/icons/dashboard.svg'),
    _NavItem(label: 'Attendance', icon: 'assets/icons/attendence.svg'),
    _NavItem(label: 'Schedule', icon: 'assets/icons/schedule.svg'),
    _NavItem(label: 'Profile', icon: 'assets/icons/profile.svg'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 80,
        decoration: const BoxDecoration(
          color: AppColors.whiteBackgroundColor,
          border: Border(top: BorderSide(color: Color(0xFFD5D5D5), width: 1)),
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final bool isSelected = currentIndex == index;

            return Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    debugPrint('NAV CLICKED: $index');
                    onTap(index);
                  },
                  child: Container(
                    height: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            item.icon,
                            width: 18,
                            height: 18,
                            colorFilter: ColorFilter.mode(
                              isSelected
                                  ? AppColors.selectedColor
                                  : AppColors.unSelectedColor,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                   ? AppColors.selectedColor
                                  : AppColors.unSelectedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final String icon;

  const _NavItem({required this.label, required this.icon});
}
