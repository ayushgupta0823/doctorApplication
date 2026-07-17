import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

const _kVoiceNotesKey = 'more.voice_notes';

class _VoiceNote {
  _VoiceNote({required this.id, required this.path, required this.label, required this.recordedAt});
  final String id;
  final String path;
  final String label;
  final DateTime recordedAt;

  Map<String, dynamic> toJson() => {'id': id, 'path': path, 'label': label, 'recordedAt': recordedAt.toIso8601String()};
  static _VoiceNote fromJson(Map<String, dynamic> j) => _VoiceNote(
        id: j['id'] as String,
        path: j['path'] as String,
        label: j['label'] as String,
        recordedAt: DateTime.tryParse(j['recordedAt'] as String? ?? '') ?? DateTime.now(),
      );
}

/// Dictated notes recorded and played back entirely on this device — there
/// is no backend route for a doctor's personal voice memos, so this is
/// genuinely real within device scope rather than pretending to sync
/// anywhere.
class VoiceNotesScreen extends StatefulWidget {
  const VoiceNotesScreen({super.key});

  @override
  State<VoiceNotesScreen> createState() => _VoiceNotesScreenState();
}

class _VoiceNotesScreenState extends State<VoiceNotesScreen> {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  List<_VoiceNote> _notes = [];
  bool _loaded = false;
  bool _recording = false;
  String? _playingId;
  DateTime? _recordStart;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kVoiceNotesKey);
    if (!mounted) return;
    setState(() {
      _notes = raw == null ? [] : (jsonDecode(raw) as List).cast<Map<String, dynamic>>().map(_VoiceNote.fromJson).toList();
      _loaded = true;
    });
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kVoiceNotesKey, jsonEncode(_notes.map((n) => n.toJson()).toList()));
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      final path = await _recorder.stop();
      if (!mounted) return;
      setState(() => _recording = false);
      if (path != null) {
        final durationLabel = _recordStart == null ? '' : ' (${DateTime.now().difference(_recordStart!).inSeconds}s)';
        setState(() {
          _notes.insert(0, _VoiceNote(id: '${DateTime.now().microsecondsSinceEpoch}', path: path, label: 'Note$durationLabel', recordedAt: DateTime.now()));
        });
        _persist();
      }
      return;
    }

    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required to record a voice note.'), backgroundColor: AppColors.red600),
        );
      }
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/voice_note_${DateTime.now().microsecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    _recordStart = DateTime.now();
    if (mounted) setState(() => _recording = true);
  }

  Future<void> _playPause(_VoiceNote note) async {
    if (_playingId == note.id) {
      await _player.stop();
      setState(() => _playingId = null);
      return;
    }
    try {
      await _player.setFilePath(note.path);
      setState(() => _playingId = note.id);
      await _player.play();
      if (mounted) setState(() => _playingId = null);
    } catch (e) {
      if (mounted) {
        setState(() => _playingId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not play this recording — $e'), backgroundColor: AppColors.red600),
        );
      }
    }
  }

  Future<void> _delete(_VoiceNote note) async {
    setState(() => _notes.removeWhere((n) => n.id == note.id));
    await _persist();
    try {
      final f = File(note.path);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // Best-effort cleanup — an orphaned file isn't worth failing the delete over.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blue50,
      appBar: AppBar(
        backgroundColor: AppColors.blue50,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.ink900), onPressed: () => Navigator.pop(context)),
        title: Text('Voice Notes', style: AppText.display(size: 16)),
        centerTitle: true,
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Recorded and stored on this device only.', style: AppText.body(size: 11.5, color: AppColors.ink400)),
                ),
                Expanded(
                  child: _notes.isEmpty
                      ? Center(child: EmptyState(icon: Icons.mic_none_outlined, message: 'No voice notes yet.'))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          itemCount: _notes.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final n = _notes[i];
                            final playing = _playingId == n.id;
                            return AppCard(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: ListTile(
                                leading: IconButton(
                                  icon: Icon(playing ? Icons.stop_circle : Icons.play_circle_fill, color: AppColors.blue600, size: 30),
                                  onPressed: () => _playPause(n),
                                ),
                                title: Text(n.label, style: AppText.body(size: 13, weight: FontWeight.w600)),
                                subtitle: Text('${n.recordedAt.toLocal()}'.split('.').first, style: AppText.body(size: 10.5, color: AppColors.ink600)),
                                trailing: IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.red600), onPressed: () => _delete(n)),
                              ),
                            ).animate(delay: (i * 40).ms).fadeIn(duration: 220.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOut);
                          },
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: AppButton(
                      label: _recording ? 'Stop Recording' : 'Record a Voice Note',
                      icon: Icon(_recording ? Icons.stop : Icons.mic, size: 18),
                      variant: _recording ? AppButtonVariant.danger : AppButtonVariant.primary,
                      block: true,
                      onPressed: _toggleRecording,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
