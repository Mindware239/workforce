import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/core/styles/app_colors.dart';

import 'package:workforce/features/attendence/presentation/attendence_screen.dart';
import 'package:workforce/features/chat/presentation/chat_list_screen.dart';
import 'package:workforce/features/chat/providers/chat_provider.dart';
import 'package:workforce/features/chat/providers/chat_realtime.dart';
import 'package:workforce/features/dashboard/providers/dashboard_provider.dart';
import 'package:workforce/features/home/presentation/home_screen.dart';
// import 'package:workforce/features/profile/presentation/profile_screen.dart';

import 'package:workforce/features/task/presentation/task_screen.dart';
import 'package:workforce/features/task/providers/task_provider.dart';

class DashboardPage extends ConsumerWidget {
  final int index;

  const DashboardPage({
    super.key,
    this.index = 0,
  });

  static const List<Widget> screens = [
    HomeScreen(),
    AttendanceScreen(),
    TasksScreen(),
    ChatListScreen(),
    // ProfileScreen(),
  ];

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final selectedIndex =
        ref.watch(dashboardTabProvider);

    // The signed-in shell keeps chat live: opens the socket and folds
    // pushed events into chatProvider, this badge included.
    ref.watch(chatRealtimeProvider);

    // Watch the unread total so the bottom navigation
    // badge updates immediately.
    final unreadCount =
        ref.watch(chatProvider.select((s) => s.unreadCount));

    // Watch task count for the bottom navigation badge.
    final taskCount = ref.watch(taskProvider.select((s) {
      final active = s.pendingCount + s.inProgressCount;
      if (active > 0) return active;
      if (s.pendingCount > 0) return s.pendingCount;
      return s.tasks.where((t) {
        final status = t['status']?.toString().toLowerCase();
        return status == 'pending' || status == 'in_progress';
      }).length;
    }));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(taskProvider.notifier).fetchSummary();
    });

    if (index != 0 && selectedIndex == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(dashboardTabProvider.notifier)
            .state = _validateIndex(index);
      });
    }

    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: screens,
      ),

      bottomNavigationBar: _DashboardBottomNav(
        currentIndex: selectedIndex,
        unreadCount: unreadCount,
        taskCount: taskCount,
        onTap: (index) {
          ref
              .read(dashboardTabProvider.notifier)
              .state = index;
        },
      ),
    );
  }

  static int _validateIndex(int index) {
    if (index < 0 || index >= screens.length) {
      return 0;
    }

    return index;
  }
}

// ============================================================
// BOTTOM NAVIGATION
// ============================================================

class _DashboardBottomNav extends StatelessWidget {
  final int currentIndex;
  final int unreadCount;
  final int taskCount;
  final ValueChanged<int> onTap;

  const _DashboardBottomNav({
    required this.currentIndex,
    required this.unreadCount,
    this.taskCount = 0,
    required this.onTap,
  });

  static const List<_NavItem> items = [
    _NavItem(
      label: 'Dashboard',
      icon: 'assets/icons/dashboard.svg',
    ),
    _NavItem(
      label: 'Attendance',
      icon: 'assets/icons/attendence.svg',
    ),
    _NavItem(
      label: 'Task',
      icon: 'assets/icons/task.svg',
    ),
    _NavItem(
      label: 'Chat',
      icon: 'assets/icons/chat.svg',
    ),
    // _NavItem(
    //   label: 'Profile',
    //   icon: 'assets/icons/profile.svg',
    // ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 80,
        decoration: const BoxDecoration(
          color: AppColors.whiteBackgroundColor,
          border: Border(
            top: BorderSide(
              color: Color(0xFFD5D5D5),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: List.generate(
            items.length,
            (index) {
              final item = items[index];

              final bool isSelected =
                  currentIndex == index;

              // Task is index 2.
              final bool isTask = index == 2;

              // Chat is index 3.
              final bool isChat =
                  index == 3;

              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      debugPrint(
                        'NAV CLICKED: $index',
                      );

                      onTap(index);
                    },
                    child: Container(
                      height: double.infinity,
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            // ------------------------------------------------
                            // ICON + UNREAD BADGE
                            // ------------------------------------------------

                            SizedBox(
                              width: 30,
                              height: 24,
                              child: Stack(
                                clipBehavior:
                                    Clip.none,
                                alignment:
                                    Alignment.center,
                                children: [
                                  SvgPicture.asset(
                                    item.icon,
                                    width: 18,
                                    height: 18,
                                    colorFilter:
                                        ColorFilter.mode(
                                      isSelected
                                          ? AppColors
                                              .selectedColor
                                          : AppColors
                                              .unSelectedColor,
                                      BlendMode.srcIn,
                                    ),
                                  ),

                                  if (isTask &&
                                      taskCount > 0)
                                    Positioned(
                                      top: -5,
                                      right: -3,
                                      child:
                                          _UnreadBadge(
                                        count:
                                            taskCount,
                                      ),
                                    ),

                                  if (isChat &&
                                      unreadCount > 0)
                                    Positioned(
                                      top: -5,
                                      right: -3,
                                      child:
                                          _UnreadBadge(
                                        count:
                                            unreadCount,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              item.label,
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                              textAlign:
                                  TextAlign.center,
                              style:
                                  GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight:
                                    FontWeight.w600,
                                color: isSelected
                                    ? AppColors
                                        .selectedColor
                                    : AppColors
                                        .unSelectedColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ============================================================
// UNREAD BADGE
// ============================================================

class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge({
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final text = count > 99
        ? '99+'
        : count.toString();

    return Container(
      constraints: const BoxConstraints(
        minWidth: 16,
        minHeight: 16,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 4,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primaryFillColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.whiteBackgroundColor,
          width: 1.5,
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}

// ============================================================
// NAV ITEM
// ============================================================

class _NavItem {
  final String label;
  final String icon;

  const _NavItem({
    required this.label,
    required this.icon,
  });
}