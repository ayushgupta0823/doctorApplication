import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

const _kRemindersKey = 'more.personal_reminders';

class _Reminder {
  _Reminder({required this.id, required this.text, this.done = false});
  final String id;
  String text;
  bool done;

  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'done': done};
  static _Reminder fromJson(Map<String, dynamic> j) => _Reminder(id: j['id'] as String, text: j['text'] as String, done: j['done'] as bool? ?? false);
}

/// Doctor's own personal task reminders — genuinely persisted on this
/// device via `shared_preferences` (the backend's reminder API is
/// patient-only and server-stubbed, so there's no real endpoint this could
/// call instead).
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<_Reminder> _reminders = [];
  bool _loaded = false;
  final _newController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _newController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kRemindersKey);
    if (!mounted) return;
    setState(() {
      _reminders = raw == null ? [] : (jsonDecode(raw) as List).cast<Map<String, dynamic>>().map(_Reminder.fromJson).toList();
      _loaded = true;
    });
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRemindersKey, jsonEncode(_reminders.map((r) => r.toJson()).toList()));
  }

  void _add() {
    final text = _newController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _reminders.insert(0, _Reminder(id: '${DateTime.now().microsecondsSinceEpoch}', text: text));
      _newController.clear();
    });
    _persist();
  }

  void _toggle(_Reminder r) {
    setState(() => r.done = !r.done);
    _persist();
  }

  void _remove(_Reminder r) {
    setState(() => _reminders.removeWhere((x) => x.id == r.id));
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blue50,
      appBar: AppBar(
        backgroundColor: AppColors.blue50,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.ink900), onPressed: () => Navigator.pop(context)),
        title: Text('Reminders', style: AppText.display(size: 16)),
        centerTitle: true,
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newController,
                          decoration: const InputDecoration(hintText: 'Add a reminder…'),
                          onSubmitted: (_) => _add(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AppButton(label: 'Add', small: true, onPressed: _add),
                    ],
                  ),
                ),
                Expanded(
                  child: _reminders.isEmpty
                      ? Center(
                          child: EmptyState(
                            icon: Icons.notifications_none_outlined,
                            message: 'No reminders yet — add one above.',
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: _reminders.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final r = _reminders[i];
                            return AppCard(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: ListTile(
                                leading: Checkbox(value: r.done, onChanged: (_) => _toggle(r), activeColor: AppColors.blue600),
                                title: Text(
                                  r.text,
                                  style: AppText.body(size: 13, color: r.done ? AppColors.ink400 : AppColors.ink900)
                                      .copyWith(decoration: r.done ? TextDecoration.lineThrough : null),
                                ),
                                trailing: IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.red600), onPressed: () => _remove(r)),
                              ),
                            ).animate(delay: (i * 40).ms).fadeIn(duration: 220.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOut);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
