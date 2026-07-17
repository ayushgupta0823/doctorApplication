import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/ekg_painter.dart';

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
              colors: [AppColors.blue900, AppColors.callSurfaceEnd, AppColors.callSurfaceDark],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            boxShadow: [
              ...AppShadow.lg,
              BoxShadow(color: AppColors.blue900.withValues(alpha: 0.28), blurRadius: 32, offset: const Offset(0, 14)),
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
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.blue500.withValues(alpha: 0.4)),
                            )
                                .animate(onPlay: (c) => c.repeat(reverse: true))
                                .scaleXY(begin: 0.78, end: 1.2, duration: 1100.ms, curve: Curves.easeInOut)
                                .fade(begin: 0.55, end: 0.05, duration: 1100.ms, curve: Curves.easeInOut),
                            const SizedBox(
                              width: 34,
                              height: 34,
                              child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2.6),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Acquiring WebRTC Session token...',
                        style: AppText.body(size: 12.5, color: AppColors.callTextLight),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(width: 130, child: EkgLine(height: 16)),
                    ],
                  ),
                ).animate().fadeIn(duration: 240.ms),

              // 2. Disconnected / Waiting State
              if (app.rtcState == 'disconnected')
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06)),
                        child: const Icon(
                          Icons.videocam_off,
                          size: 30,
                          color: AppColors.callIconMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Consultation Call Offline',
                        style: AppText.display(size: 15, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap "Join Call" below to establish WebRTC media channel.',
                        style: AppText.body(size: 12, color: AppColors.callTextMuted),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 240.ms),

              // 3. Connected / Active Video Feed
              if (isCallActive) ...[
                // Simulated patient camera stream — a real WebRTC remote
                // track isn't available without a signaling backend, so
                // this is a self-contained placeholder rather than a
                // fetched stock photo (which would also fail offline).
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.1,
                        colors: [AppColors.callSurfaceDark, AppColors.callSurfaceDarker],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: app.videoMuted
                        ? null
                        : Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05)),
                            child: const Icon(Icons.person, size: 44, color: AppColors.callIconMuted),
                          ),
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule, size: 11, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          _fmt(app.callSeconds),
                          style: AppText.mono(size: 11.5, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),

                // Consent Banner (Clinical Requirement)
                Positioned(
                  top: 50,
                  left: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.tealDark.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))],
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
                ).animate().fadeIn(duration: 260.ms).slideY(begin: -0.1, end: 0, curve: Curves.easeOut),

                // Center Indicator
                if (app.videoMuted)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.videocam_off, size: 13, color: AppColors.callTextLight),
                          const SizedBox(width: 6),
                          Text(
                            'Patient camera turned off',
                            style: AppText.body(size: 12, color: AppColors.callTextLight),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 200.ms),

                // Doctor's local preview (Bottom-Right)
                Positioned(
                  bottom: 74,
                  right: 12,
                  child: Container(
                    width: 76,
                    height: 98,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.callSurfaceDarker,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(app.videoMuted ? Icons.videocam_off : Icons.person, size: 20, color: AppColors.callIconMuted),
                        const SizedBox(height: 4),
                        Text(
                          app.videoMuted ? 'Muted' : 'You',
                          style: AppText.body(size: 9, color: AppColors.callIconMuted, weight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),

                // Call Controls — grouped in a frosted pill bar, matching
                // the control-tray pattern of modern telehealth apps.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6))],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
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
                  ),
                ),

                // 4. Reconnecting overlay
                if (app.rtcState == 'reconnecting')
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.6),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 64,
                              height: 64,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.amberBorder.withValues(alpha: 0.3)),
                                  )
                                      .animate(onPlay: (c) => c.repeat(reverse: true))
                                      .scaleXY(begin: 0.8, end: 1.2, duration: 900.ms, curve: Curves.easeInOut)
                                      .fade(begin: 0.6, end: 0.1, duration: 900.ms, curve: Curves.easeInOut),
                                  const CircularProgressIndicator(color: AppColors.amberBorder),
                                ],
                              ),
                            ),
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
                  ).animate().fadeIn(duration: 220.ms),
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
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(color: AppColors.blue100, borderRadius: BorderRadius.circular(AppRadius.xs)),
                            child: const Icon(Icons.mic, size: 14, color: AppColors.blue700),
                          ),
                          const SizedBox(width: 8),
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.blue100, borderRadius: BorderRadius.circular(100)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 5, height: 5, decoration: const BoxDecoration(color: AppColors.blue600, shape: BoxShape.circle))
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .fadeIn(duration: 700.ms)
                              .then()
                              .fadeOut(duration: 700.ms),
                          const SizedBox(width: 5),
                          Text(
                            'Streaming live...',
                            style: AppText.mono(size: 10, color: AppColors.blue600),
                          ),
                        ],
                      ),
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
                                  .toList()
                                  .animate()
                                  .fadeIn(duration: 180.ms),
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
      color: AppColors.red600.withValues(alpha: 0.92),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2))],
      ),
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
        elevation: end ? 4 : 0,
        shadowColor: AppColors.red600.withValues(alpha: 0.6),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Icon(icon, key: ValueKey(icon), size: 19, color: fg, semanticLabel: label),
              ),
            ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(border: Border(left: BorderSide(color: color.withValues(alpha: 0.5), width: 2))),
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
