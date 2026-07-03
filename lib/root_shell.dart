import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/biometric_lock_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/more/more_menu_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/patients_screen.dart';
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

    if (!app.isLoggedIn) return const LoginScreen();
    if (!app.isOnboarded) return const OnboardingScreen();
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
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_tabs.length, (i) {
              final active = i == currentIndex;
              final color = active ? AppColors.blue600 : AppColors.ink400;
              return InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () => context.read<AppState>().setTab(_tabs[i]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
              );
            }),
          ),
        ),
      ),
    );
  }
}
