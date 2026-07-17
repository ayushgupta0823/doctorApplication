import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/status_badge.dart';
import 'consult_room/consult_room_screen.dart';

const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _weekdayLong = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Calendar / Roster: month + week navigation around today's schedule.
/// Only today's appointments are backed by real data in this demo — other
/// days show an honest empty state rather than fabricated history.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _selectedDay;
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _selectedDay = today;
    _weekStart = today.subtract(Duration(days: today.weekday - 1));
  }

  bool get _isToday => _isSameDay(_selectedDay, DateTime.now());

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  void _shiftWeek(int delta) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * delta));
      _selectedDay = _weekStart;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final total = app.queue.length;
    final completed = app.queue.where((p) => p.status == ConsultStatus.completed).length;
    final inProgress = app.queue.where((p) => p.status == ConsultStatus.inProgress).length;
    final upcoming = app.queue.where((p) => [ConsultStatus.scheduled, ConsultStatus.confirmed, ConsultStatus.waiting].contains(p.status)).length;

    final sorted = List<QueuePatient>.from(app.queue)..sort((a, b) => a.time.compareTo(b.time));

    return Scaffold(
      backgroundColor: AppColors.blue50,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(child: Text('My Roster', style: AppText.display(size: 20, color: AppColors.blue900))),
                  IconButton(
                    tooltip: 'Add walk-in',
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.blue700),
                    onPressed: () => app.setTab(RootTab.queue),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _shiftWeek(-1)),
                  Flexible(
                    child: Text(
                      '${_monthNames[_weekStart.month - 1]} ${_weekStart.year}',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.display(size: 14),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _shiftWeek(1)),
                ],
              ),
            ),
            SizedBox(
              height: 68,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 7,
                itemBuilder: (context, i) {
                  final day = _weekStart.add(Duration(days: i));
                  final selected = _isSameDay(day, _selectedDay);
                  final isRealToday = _isSameDay(day, DateTime.now());
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDay = day),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 46,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.blue600 : AppColors.white,
                        border: Border.all(color: selected ? AppColors.blue600 : (isRealToday ? AppColors.blue500 : AppColors.line)),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: selected ? AppShadow.md : AppShadow.sm,
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_weekdayShort[day.weekday - 1], style: AppText.body(size: 9.5, weight: FontWeight.w600, color: selected ? Colors.white : AppColors.ink400)),
                          const SizedBox(height: 4),
                          Text('${day.day}', style: AppText.display(size: 15, color: selected ? Colors.white : AppColors.ink900)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: !_isToday
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: AppCard(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: const BoxDecoration(color: AppColors.blue100, shape: BoxShape.circle),
                                child: const Icon(Icons.event_busy_outlined, size: 24, color: AppColors.blue700),
                              ),
                              const SizedBox(height: 16),
                              Text('No Schedule Data', style: AppText.display(size: 15.5)),
                              const SizedBox(height: 6),
                              Text(
                                'Only today\'s roster is live in this demo — other days will show real appointments once historical data is wired up.',
                                textAlign: TextAlign.center,
                                style: AppText.body(size: 12.5, color: AppColors.ink600),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(duration: 220.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      children: [
                        Text(
                          '${_weekdayLong[_selectedDay.weekday - 1]}, ${_selectedDay.day} ${_monthNames[_selectedDay.month - 1]} ${_selectedDay.year}',
                          style: AppText.display(size: 13, color: AppColors.blue700),
                        ),
                        const SizedBox(height: 10),
                        for (var i = 0; i < sorted.length; i++)
                          _ScheduleRow(patient: sorted[i])
                              .animate(delay: (i * 40).ms)
                              .fadeIn(duration: 220.ms)
                              .slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
                        const SizedBox(height: 16),
                        Text('DAY SUMMARY', style: AppText.mono(size: 10, color: AppColors.ink600, weight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _SummaryStat(label: 'Total', value: total, color: AppColors.blue700)),
                            const SizedBox(width: 8),
                            Expanded(child: _SummaryStat(label: 'Completed', value: completed, color: AppColors.green600)),
                            const SizedBox(width: 8),
                            Expanded(child: _SummaryStat(label: 'In Progress', value: inProgress, color: AppColors.blue600)),
                            const SizedBox(width: 8),
                            Expanded(child: _SummaryStat(label: 'Upcoming', value: upcoming, color: AppColors.amber600)),
                          ],
                        ).animate().fadeIn(delay: 120.ms, duration: 280.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.patient});
  final QueuePatient patient;

  @override
  Widget build(BuildContext context) {
    Widget action;
    if (patient.status == ConsultStatus.inProgress) {
      action = AppButton(
        label: 'Resume',
        small: true,
        variant: AppButtonVariant.success,
        onPressed: () {
          final app = context.read<AppState>();
          app.resumeConsult(patient.id);
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConsultRoomScreen()));
        },
      );
    } else if ([ConsultStatus.scheduled, ConsultStatus.confirmed, ConsultStatus.waiting].contains(patient.status)) {
      action = AppButton(label: 'Open', small: true, variant: AppButtonVariant.subtle, onPressed: () => context.read<AppState>().setTab(RootTab.queue));
    } else {
      action = StatusBadge(status: patient.status);
    }

    // In-progress entries get the same warm accent treatment as the Queue
    // tab so an active consultation stands out on the day's schedule.
    final isActive = patient.status == ConsultStatus.inProgress;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isActive ? AppColors.orange100.withValues(alpha: 0.35) : AppColors.white,
        border: Border.all(color: isActive ? AppColors.orange600.withValues(alpha: 0.35) : AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: isActive ? AppShadow.md : AppShadow.sm,
      ),
      child: Row(
        children: [
          SizedBox(width: 62, child: Text(patient.time, style: AppText.mono(size: 11, weight: FontWeight.w700, color: AppColors.blue700))),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patient.name, style: AppText.body(size: 12.5, weight: FontWeight.w700)),
                Text(patient.mode, style: AppText.body(size: 10.5, color: AppColors.ink400)),
              ],
            ),
          ),
          action,
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: 0.05), AppColors.white),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        children: [
          Text('$value', style: AppText.mono(size: 17, weight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: AppText.body(size: 9, color: AppColors.ink600, weight: FontWeight.bold), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
