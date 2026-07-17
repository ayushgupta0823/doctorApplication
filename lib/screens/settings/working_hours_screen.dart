import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';

const _dayLabels = {
  'monday': 'Monday',
  'tuesday': 'Tuesday',
  'wednesday': 'Wednesday',
  'thursday': 'Thursday',
  'friday': 'Friday',
  'saturday': 'Saturday',
  'sunday': 'Sunday',
};

class _DayHours {
  _DayHours({this.open = false, this.start = const TimeOfDay(hour: 9, minute: 0), this.end = const TimeOfDay(hour: 17, minute: 0)});
  bool open;
  TimeOfDay start;
  TimeOfDay end;
}

TimeOfDay? _parseTime(String? raw) {
  if (raw == null) return null;
  final parts = raw.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return TimeOfDay(hour: h, minute: m);
}

String _formatTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Working Hours: a real weekly-schedule editor backed by the already-live
/// `GET/PUT /doctors/me/availability` endpoints (`DoctorAvailability` model
/// server-side) — replaces what used to be a dead "Nothing here yet" row on
/// the Profile screen. One open/closed toggle + one time range per day; the
/// backend supports multiple ranges per day, but a single range covers the
/// real need without over-building a UI nobody asked for.
class WorkingHoursScreen extends StatefulWidget {
  const WorkingHoursScreen({super.key});

  @override
  State<WorkingHoursScreen> createState() => _WorkingHoursScreenState();
}

class _WorkingHoursScreenState extends State<WorkingHoursScreen> {
  final Map<String, _DayHours> _days = {for (final d in AppState.weekdays) d: _DayHours()};
  bool _seeded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    if (app.doctorAvailability != null) {
      _seedFromAvailability(app.doctorAvailability);
    } else {
      app.loadAvailability();
    }
  }

  void _seedFromAvailability(Map<String, dynamic>? availability) {
    _seeded = true;
    final schedule = availability?['weeklySchedule'];
    if (schedule is! Map) return;
    for (final day in AppState.weekdays) {
      final slots = schedule[day];
      if (slots is List && slots.isNotEmpty && slots.first is Map) {
        final slot = slots.first as Map;
        final start = _parseTime(slot['start'] as String?);
        final end = _parseTime(slot['end'] as String?);
        _days[day] = _DayHours(open: true, start: start ?? const TimeOfDay(hour: 9, minute: 0), end: end ?? const TimeOfDay(hour: 17, minute: 0));
      }
    }
  }

  Future<void> _pickTime(String day, {required bool isStart}) async {
    final current = isStart ? _days[day]!.start : _days[day]!.end;
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _days[day]!.start = picked;
      } else {
        _days[day]!.end = picked;
      }
    });
  }

  Future<void> _save(AppState app) async {
    setState(() => _saving = true);
    final weeklySchedule = {
      for (final day in AppState.weekdays)
        day: _days[day]!.open ? [{'start': _formatTime(_days[day]!.start), 'end': _formatTime(_days[day]!.end), 'mode': 'both'}] : <Map<String, String>>[],
    };
    final ok = await app.saveAvailability(weeklySchedule);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Working hours saved', style: AppText.body(size: 13, color: Colors.white, weight: FontWeight.bold)), backgroundColor: AppColors.green600),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (!_seeded && app.doctorAvailability != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _seedFromAvailability(app.doctorAvailability));
      });
    }
    return Scaffold(
      backgroundColor: AppColors.blue50,
      appBar: AppBar(
        backgroundColor: AppColors.blue50,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.ink900), onPressed: () => Navigator.pop(context)),
        title: Text('Working Hours', style: AppText.display(size: 16)),
        centerTitle: true,
      ),
      body: app.isLoadingAvailability
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Set the days and hours you take consultations. Patients see this when booking with you.',
                  style: AppText.body(size: 12, color: AppColors.ink600),
                ),
                const SizedBox(height: 16),
                for (final day in AppState.weekdays) _DayRow(dayKey: day, hours: _days[day]!, onToggle: (v) => setState(() => _days[day]!.open = v), onPickTime: (isStart) => _pickTime(day, isStart: isStart)),
                const SizedBox(height: 20),
                AppButton(label: _saving ? 'Saving...' : 'Save Changes', block: true, loading: _saving, onPressed: _saving ? null : () => _save(app)),
              ],
            ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.dayKey, required this.hours, required this.onToggle, required this.onPickTime});
  final String dayKey;
  final _DayHours hours;
  final ValueChanged<bool> onToggle;
  final ValueChanged<bool> onPickTime;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(_dayLabels[dayKey]!, style: AppText.body(size: 13.5, weight: FontWeight.w700))),
              Text(hours.open ? 'Open' : 'Closed', style: AppText.body(size: 11.5, weight: FontWeight.w600, color: hours.open ? AppColors.green600 : AppColors.ink400)),
              Switch(value: hours.open, activeThumbColor: AppColors.green600, onChanged: onToggle),
            ],
          ),
          if (hours.open) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: _TimeChip(label: 'Start', time: hours.start, onTap: () => onPickTime(true))),
                const SizedBox(width: 10),
                Expanded(child: _TimeChip(label: 'End', time: hours.end, onTap: () => onPickTime(false))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.label, required this.time, required this.onTap});
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: AppColors.blue50, borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: AppColors.line)),
        child: Row(
          children: [
            const Icon(Icons.access_time, size: 14, color: AppColors.blue700),
            const SizedBox(width: 6),
            Text('$label: ${_formatTime(time)}', style: AppText.body(size: 11.5, weight: FontWeight.w600, color: AppColors.blue700)),
          ],
        ),
      ),
    );
  }
}
