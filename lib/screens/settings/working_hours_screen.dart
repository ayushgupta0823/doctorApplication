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

const _capabilityOptions = [
  ('in_person', 'In-Person Only'),
  ('online', 'Video Only'),
  ('both', 'Both'),
];

const _modeLabels = {'online': '🎥 Video', 'in_person': '🏥 In-Person', 'both': 'Both'};
const _slotDurations = [15, 20, 30];

/// Which mode options a range can be set to, given the doctor's overall
/// consultation-modes capability — mirrors the website's `AvailabilityEditor`.
List<String> _modeOptionsFor(String capability) {
  if (capability == 'online') return const ['online'];
  if (capability == 'in_person') return const ['in_person'];
  return const ['online', 'in_person', 'both'];
}

String _defaultModeFor(String capability) => capability == 'both' ? 'both' : capability;

class _Range {
  _Range({required this.start, required this.end, required this.mode});
  TimeOfDay start;
  TimeOfDay end;
  String mode;
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

/// Working Hours: a real weekly-schedule editor backed by the live
/// `GET/PUT /doctors/me/availability` + `PUT /doctors/me/profile` endpoints.
/// Each day holds any number of independently mode-tagged ranges (e.g.
/// 09:00-13:00 video, 13:00-17:00 in-person), matching the website's
/// `AvailabilityEditor` component 1:1, plus the "Consultation Modes Offered"
/// capability selector that also drives `Doctor.consultationType`.
class WorkingHoursScreen extends StatefulWidget {
  const WorkingHoursScreen({super.key});

  @override
  State<WorkingHoursScreen> createState() => _WorkingHoursScreenState();
}

class _WorkingHoursScreenState extends State<WorkingHoursScreen> {
  final Map<String, List<_Range>> _schedule = {for (final d in AppState.weekdays) d: <_Range>[]};
  String _capability = 'both';
  int _slotDurationMinutes = 20;
  bool _seeded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    if (app.doctorProfile?['consultationType'] is String) {
      _capability = app.doctorProfile!['consultationType'] as String;
    }
    if (app.doctorAvailability != null) {
      _seedFromAvailability(app.doctorAvailability);
    } else {
      app.loadAvailability();
    }
  }

  void _seedFromAvailability(Map<String, dynamic>? availability) {
    _seeded = true;
    if (availability?['slotDurationMinutes'] is int) {
      _slotDurationMinutes = availability!['slotDurationMinutes'] as int;
    }
    final schedule = availability?['weeklySchedule'];
    if (schedule is! Map) return;
    for (final day in AppState.weekdays) {
      final slots = schedule[day];
      if (slots is! List) continue;
      _schedule[day] = slots.whereType<Map>().map((slot) {
        final start = _parseTime(slot['start'] as String?) ?? const TimeOfDay(hour: 9, minute: 0);
        final end = _parseTime(slot['end'] as String?) ?? const TimeOfDay(hour: 17, minute: 0);
        return _Range(start: start, end: end, mode: (slot['mode'] as String?) ?? _defaultModeFor(_capability));
      }).toList();
    }
  }

  Future<void> _pickTime(_Range range, {required bool isStart}) async {
    final current = isStart ? range.start : range.end;
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null) return;
    setState(() {
      if (isStart) {
        range.start = picked;
      } else {
        range.end = picked;
      }
    });
  }

  void _addRange(String day) {
    setState(() => _schedule[day]!.add(_Range(start: const TimeOfDay(hour: 9, minute: 0), end: const TimeOfDay(hour: 17, minute: 0), mode: _defaultModeFor(_capability))));
  }

  void _removeRange(String day, int index) => setState(() => _schedule[day]!.removeAt(index));

  Future<void> _save(AppState app) async {
    setState(() => _saving = true);
    final weeklySchedule = {
      for (final day in AppState.weekdays)
        day: _schedule[day]!.map((r) => {'start': _formatTime(r.start), 'end': _formatTime(r.end), 'mode': r.mode}).toList(),
    };
    final results = await Future.wait([
      app.saveAvailability(weeklySchedule, slotDurationMinutes: _slotDurationMinutes),
      app.updateDoctorProfile({'consultationType': _capability}),
    ]);
    if (!mounted) return;
    setState(() => _saving = false);
    if (results.every((ok) => ok)) {
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
    final modeOptions = _modeOptionsFor(_capability);
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
                Text('CONSULTATION MODES OFFERED', style: AppText.mono(size: 10, color: AppColors.ink600, weight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final (value, label) in _capabilityOptions)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _ChoiceChipButton(label: label, selected: _capability == value, onTap: () => setState(() => _capability = value)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                for (final day in AppState.weekdays)
                  _DayCard(
                    dayKey: day,
                    ranges: _schedule[day]!,
                    modeOptions: modeOptions,
                    onAddRange: () => _addRange(day),
                    onRemoveRange: (i) => _removeRange(day, i),
                    onPickTime: (r, isStart) => _pickTime(r, isStart: isStart),
                    onModeChanged: (r, mode) => setState(() => r.mode = mode),
                  ),
                const SizedBox(height: 8),
                Text('SLOT DURATION', style: AppText.mono(size: 10, color: AppColors.ink600, weight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final d in _slotDurations)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _ChoiceChipButton(label: '$d min', selected: _slotDurationMinutes == d, onTap: () => setState(() => _slotDurationMinutes = d)),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                AppButton(label: _saving ? 'Saving...' : 'Save Changes', block: true, loading: _saving, onPressed: _saving ? null : () => _save(app)),
              ],
            ),
    );
  }
}

class _ChoiceChipButton extends StatelessWidget {
  const _ChoiceChipButton({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.blue600 : AppColors.white,
          border: Border.all(color: selected ? AppColors.blue600 : AppColors.line),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(label, style: AppText.body(size: 12, weight: FontWeight.w600, color: selected ? Colors.white : AppColors.ink600)),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.dayKey,
    required this.ranges,
    required this.modeOptions,
    required this.onAddRange,
    required this.onRemoveRange,
    required this.onPickTime,
    required this.onModeChanged,
  });
  final String dayKey;
  final List<_Range> ranges;
  final List<String> modeOptions;
  final VoidCallback onAddRange;
  final ValueChanged<int> onRemoveRange;
  final void Function(_Range range, bool isStart) onPickTime;
  final void Function(_Range range, String mode) onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppColors.white, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(_dayLabels[dayKey]!, style: AppText.body(size: 13.5, weight: FontWeight.w700))),
              TextButton.icon(
                onPressed: onAddRange,
                icon: const Icon(Icons.add, size: 15),
                label: Text('Add range', style: AppText.body(size: 11.5, weight: FontWeight.w600)),
                style: TextButton.styleFrom(foregroundColor: AppColors.blue600, padding: EdgeInsets.zero, minimumSize: const Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
            ],
          ),
          if (ranges.isEmpty)
            Padding(padding: const EdgeInsets.only(top: 2, bottom: 4), child: Text('Unavailable', style: AppText.body(size: 11.5, color: AppColors.ink400)))
          else
            for (var i = 0; i < ranges.length; i++) ...[
              const SizedBox(height: 6),
              _RangeRow(range: ranges[i], modeOptions: modeOptions, onPickTime: (isStart) => onPickTime(ranges[i], isStart), onModeChanged: (m) => onModeChanged(ranges[i], m), onRemove: () => onRemoveRange(i)),
            ],
        ],
      ),
    );
  }
}

class _RangeRow extends StatelessWidget {
  const _RangeRow({required this.range, required this.modeOptions, required this.onPickTime, required this.onModeChanged, required this.onRemove});
  final _Range range;
  final List<String> modeOptions;
  final ValueChanged<bool> onPickTime;
  final ValueChanged<String> onModeChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _TimeChip(label: 'Start', time: range.start, onTap: () => onPickTime(true))),
        const SizedBox(width: 6),
        Expanded(child: _TimeChip(label: 'End', time: range.end, onTap: () => onPickTime(false))),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(color: AppColors.blue50, borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: AppColors.line)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: modeOptions.contains(range.mode) ? range.mode : modeOptions.first,
              isDense: true,
              style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.blue700),
              items: modeOptions.map((m) => DropdownMenuItem(value: m, child: Text(_modeLabels[m] ?? m))).toList(),
              onChanged: modeOptions.length == 1 ? null : (v) { if (v != null) onModeChanged(v); },
            ),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: onRemove,
          child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.delete_outline, size: 16, color: AppColors.red600)),
        ),
      ],
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
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.access_time, size: 13, color: AppColors.blue700),
            const SizedBox(width: 4),
            Flexible(child: Text(_formatTime(time), style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.blue700), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}
