import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

class CallTab extends StatelessWidget {
  const CallTab({super.key});

  String _fmt(int totalSeconds) {
    final mm = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final ss = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isCallActive = app.rtcState == 'connected' || app.rtcState == 'reconnecting';

    return Column(
      children: [
        // Video Stage Box
        Container(
          margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          height: 250,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.blue900, Color(0xFF173F72)],
            ),
            boxShadow: const [
              BoxShadow(color: Color.fromRGBO(15, 27, 45, 0.10), blurRadius: 24, offset: Offset(0, 8)),
            ],
          ),
          child: Stack(
            children: [
              // 1. Connecting State
              if (app.rtcState == 'connecting')
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.white),
                      const SizedBox(height: 16),
                      Text(
                        'Acquiring WebRTC Session token...',
                        style: AppText.body(size: 12.5, color: const Color(0xFFBFD2EC)),
                      ),
                    ],
                  ),
                ),

              // 2. Disconnected / Waiting State
              if (app.rtcState == 'disconnected')
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.videocam_off,
                        size: 36,
                        color: Color(0xFF7CA3D6),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Consultation Call Offline',
                        style: AppText.display(size: 15, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap "Join Call" below to establish WebRTC media channel.',
                        style: AppText.body(size: 12, color: const Color(0xFF9FB6D9)),
                      ),
                    ],
                  ),
                ),

              // 3. Connected / Active Video Feed
              if (isCallActive) ...[
                // Simulated patient camera stream — a real WebRTC remote
                // track isn't available without a signaling backend, so
                // this is a self-contained placeholder rather than a
                // fetched stock photo (which would also fail offline).
                Positioned.fill(
                  child: Container(
                    color: const Color(0xFF14243B),
                    alignment: Alignment.center,
                    child: app.videoMuted
                        ? null
                        : const Icon(Icons.person, size: 48, color: Color(0xFF7CA3D6)),
                  ),
                ),

                // Top Widgets
                Positioned(
                  top: 12,
                  left: 12,
                  child: _LiveBadge(),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _Pill(
                    color: Colors.black.withValues(alpha: 0.4),
                    child: Text(
                      _fmt(app.callSeconds),
                      style: AppText.mono(size: 11.5, color: Colors.white),
                    ),
                  ),
                ),

                // Consent Banner (Clinical Requirement)
                Positioned(
                  top: 50,
                  left: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.tealDark.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, size: 12, color: AppColors.teal100),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'AI Scribe transcription & recording consent active',
                            style: AppText.body(size: 9.5, color: Colors.white, weight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Center Indicator
                if (app.videoMuted)
                  Center(
                    child: Text(
                      'Patient camera turned off',
                      style: AppText.body(size: 12, color: const Color(0xFFBFD2EC)),
                    ),
                  ),

                // Doctor's local preview (Bottom-Right)
                Positioned(
                  bottom: 68,
                  right: 12,
                  child: Container(
                    width: 76,
                    height: 98,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1E38),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person, size: 20, color: Color(0xFF7CA3D6)),
                        const SizedBox(height: 4),
                        Text(
                          app.videoMuted ? 'Muted' : 'You',
                          style: AppText.body(size: 9, color: const Color(0xFF7CA3D6), weight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),

                // Call Controls
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _CtrlBtn(
                        icon: app.audioMuted ? Icons.mic_off : Icons.mic,
                        label: app.audioMuted ? 'Unmute microphone' : 'Mute microphone',
                        off: app.audioMuted,
                        onTap: app.toggleMic,
                      ),
                      const SizedBox(width: 10),
                      _CtrlBtn(
                        icon: app.videoMuted ? Icons.videocam_off : Icons.videocam,
                        label: app.videoMuted ? 'Turn camera on' : 'Turn camera off',
                        off: app.videoMuted,
                        onTap: app.toggleCam,
                      ),
                      const SizedBox(width: 10),
                      _CtrlBtn(
                        icon: Icons.screen_share,
                        label: app.screenSharing ? 'Stop screen share' : 'Start screen share',
                        off: app.screenSharing,
                        onTap: app.toggleShare,
                      ),
                      const SizedBox(width: 10),
                      _CtrlBtn(
                        icon: Icons.call_end,
                        label: 'End call',
                        end: true,
                        onTap: app.endCall,
                      ),
                    ],
                  ),
                ),

                // 4. Reconnecting overlay
                if (app.rtcState == 'reconnecting')
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.65),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: AppColors.amberBorder),
                          const SizedBox(height: 16),
                          Text(
                            '⚠️ Connection Unstable',
                            style: AppText.display(size: 15, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Attempting to reconnect WebRTC channel...',
                            style: AppText.body(size: 12, color: AppColors.amberBorder),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),

        // Action Buttons Row
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Row(
            children: [
              if (app.rtcState == 'disconnected')
                Expanded(
                  child: AppButton(
                    label: 'Join Call',
                    icon: const Icon(Icons.play_arrow),
                    block: true,
                    onPressed: app.beginCall,
                  ),
                ),
              if (isCallActive) ...[
                Expanded(
                  child: AppButton(
                    label: 'Simulate Poor Network',
                    variant: AppButtonVariant.subtle,
                    icon: const Icon(Icons.wifi_off),
                    block: true,
                    onPressed: app.triggerPoorNetwork,
                  ),
                ),
              ],
            ],
          ),
        ),

        // Scribe Transcript Panel
        if (isCallActive)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.mic, size: 16, color: AppColors.ink900),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'AI Scribe — Live Transcript',
                              style: AppText.display(size: 13.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Streaming live...',
                      style: AppText.mono(size: 10, color: AppColors.blue600),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: app.activeTranscript.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: Center(
                              child: Text(
                                'Listening for patient & doctor conversation...',
                                style: AppText.body(size: 12, color: AppColors.ink400),
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            reverse: true, // Auto scrolls to bottom
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: app.activeTranscript
                                  .map((t) => _TranscriptLine(speaker: t.speaker, text: t.text))
                                  .toList(),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LiveBadge extends StatefulWidget {
  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Pill(
      color: const Color(0xFFD0342C).withValues(alpha: 0.92),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween(begin: 1.0, end: .25).animate(_c),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'LIVE CALL',
            style: AppText.mono(size: 10, weight: FontWeight.w700, color: Colors.white).copyWith(letterSpacing: .5),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.color, required this.child});
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: child,
    );
  }
}

class _CtrlBtn extends StatelessWidget {
  const _CtrlBtn({
    required this.icon,
    required this.label,
    this.off = false,
    this.end = false,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool off;
  final bool end;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = end
        ? AppColors.red600
        : (off ? Colors.white : Colors.white.withValues(alpha: 0.14));
    final fg = off && !end ? AppColors.blue900 : Colors.white;
    return Tooltip(
      message: label,
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, size: 19, color: fg, semanticLabel: label),
          ),
        ),
      ),
    );
  }
}

class _TranscriptLine extends StatelessWidget {
  const _TranscriptLine({required this.speaker, required this.text});
  final String speaker;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = speaker == 'doctor' ? AppColors.teal500 : AppColors.blue600;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text.rich(
        TextSpan(
          style: AppText.body(size: 12, color: AppColors.ink900),
          children: [
            TextSpan(
              text: '${speaker.toUpperCase()}  ',
              style: AppText.mono(size: 10, weight: FontWeight.w600, color: color),
            ),
            TextSpan(text: text),
          ],
        ),
      ),
    );
  }
}
