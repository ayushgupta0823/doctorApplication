import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../data/api/api.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/avatar.dart';

/// Recent patients you can message — real backend-backed async chat
/// (`POST/GET /consultations/:id/messages`), scoped to a specific past
/// consultation rather than an open-ended inbox the backend doesn't model.
class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final threads = app.patientHistory;

    return Scaffold(
      backgroundColor: AppColors.blue50,
      appBar: AppBar(
        backgroundColor: AppColors.blue50,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.ink900), onPressed: () => Navigator.pop(context)),
        title: Text('Chat Interaction', style: AppText.display(size: 16)),
        centerTitle: true,
      ),
      body: threads.isEmpty
          ? Center(child: EmptyState(icon: Icons.chat_bubble_outline, message: 'No past consultations to message about yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: threads.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final t = threads[i];
                return AppCard(
                  padding: const EdgeInsets.all(4),
                  child: ListTile(
                    leading: InitialsAvatar(name: t.name, size: 38, fontSize: 12),
                    title: Text(t.name, style: AppText.body(size: 13, weight: FontWeight.w700)),
                    subtitle: Text('Consultation on ${t.date}', style: AppText.body(size: 11, color: AppColors.ink600)),
                    trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.ink400),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatThreadScreen(consultationId: t.id, patientName: t.name))),
                  ),
                ).animate(delay: (i * 40).ms).fadeIn(duration: 220.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOut);
              },
            ),
    );
  }
}

class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({super.key, required this.consultationId, required this.patientName});
  final String consultationId;
  final String patientName;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _messages = [];
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final messages = await Api.messages.list(widget.consultationId);
      if (!mounted) return;
      setState(() => _messages = messages);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = context.read<AppState>().describeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await Api.messages.send(widget.consultationId, text);
      _controller.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Message not sent — ${context.read<AppState>().describeError(e)}'), backgroundColor: AppColors.red600),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool _isFromDoctor(Map<String, dynamic> m) {
    final role = (m['senderRole'] ?? m['role'] ?? m['sender']) as String?;
    return role == 'doctor';
  }

  String _text(Map<String, dynamic> m) => (m['message'] ?? m['content'] ?? m['text'] ?? '') as String;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blue50,
      appBar: AppBar(
        backgroundColor: AppColors.blue50,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.ink900), onPressed: () => Navigator.pop(context)),
        title: Text(widget.patientName, style: AppText.display(size: 16)),
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _load)],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: EmptyState(
                          icon: Icons.error_outline,
                          iconColor: AppColors.red600,
                          iconBackground: AppColors.red100,
                          message: 'Could not load messages — $_error',
                        ),
                      )
                    : _messages.isEmpty
                        ? Center(child: EmptyState(icon: Icons.forum_outlined, message: 'No messages yet — say hello.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (context, i) {
                              final m = _messages[i];
                              final fromDoctor = _isFromDoctor(m);
                              return Align(
                                alignment: fromDoctor ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                                  decoration: BoxDecoration(
                                    color: fromDoctor ? AppColors.blue600 : AppColors.white,
                                    border: fromDoctor ? null : Border.all(color: AppColors.line),
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    boxShadow: AppShadow.sm,
                                  ),
                                  child: Text(_text(m), style: AppText.body(size: 13, color: fromDoctor ? Colors.white : AppColors.ink900)),
                                ),
                              ).animate(delay: (i * 25).ms).fadeIn(duration: 200.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOut);
                            },
                          ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(hintText: 'Type a message…'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: _sending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send, size: 18),
                    onPressed: _sending ? null : _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
