import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/biometric_lock_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/home_screen.dart';
import 'screens/more/more_menu_screen.dart';
import 'screens/patients_screen.dart';
import 'screens/registration/registration_screen.dart';
import 'screens/queue_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

/// App scaffold with the 5-tab bottom navigation bar: Home, Queue,
/// Patients, Calendar, More. Consultation, Patient Details, Profile,
/// Appointments, and Reports are all pushed routes — a doctor only ever
/// enters them for a specific patient/purpose rather than browsing into
/// them as standalone destinations.
class RootShell extends StatelessWidget {
  const RootShell({super.key});

  static const _tabs = [
    RootTab.home,
    RootTab.queue,
    RootTab.patients,
    RootTab.calendar,
    RootTab.more,
  ];

  static const _screens = [
    HomeScreen(),
    QueueScreen(),
    PatientsScreen(),
    CalendarScreen(),
    MoreMenuScreen(),
  ];

  static const _icons = [
    Icons.home_outlined,
    Icons.assignment_outlined,
    Icons.groups_outlined,
    Icons.calendar_month_outlined,
    Icons.grid_view_outlined,
  ];

  static const _labels = ['Home', 'Queue', 'Patients', 'Calendar', 'More'];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    if (!app.isOnboarded) return const RegistrationScreen();
    if (app.isAppLocked) return const BiometricLockScreen();

    final currentIndex = _tabs.indexOf(app.tab);

    return Scaffold(
      backgroundColor: AppColors.blue50,
      body: SafeArea(
        bottom: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: KeyedSubtree(
            key: ValueKey(currentIndex),
            child: IndexedStack(index: currentIndex, children: _screens),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: AppShadow.md,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slotWidth = constraints.maxWidth / _tabs.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    left: slotWidth * currentIndex,
                    top: 0,
                    bottom: 0,
                    width: slotWidth,
                    child: Center(
                      child: Container(
                        width: slotWidth - 12,
                        decoration: BoxDecoration(color: AppColors.blue100, borderRadius: BorderRadius.circular(AppRadius.lg)),
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(_tabs.length, (i) {
                      final active = i == currentIndex;
                      final color = active ? AppColors.blue600 : AppColors.ink400;
                      return Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          onTap: () => context.read<AppState>().setTab(_tabs[i]),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_icons[i], size: 21, color: color),
                                const SizedBox(height: 3),
                                Text(
                                  _labels[i],
                                  style: AppText.body(size: 10.5, weight: FontWeight.w600, color: color),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
