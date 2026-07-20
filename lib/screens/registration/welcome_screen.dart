import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';

/// First screen a brand-new doctor sees — a full-bleed hero using the app's
/// own blue/teal brand gradient (the same one [AppLogoMark] uses) rather
/// than a one-off palette, with a doctor illustration and a single
/// "Registration Profile" call to action leading into
/// [DoctorRegistrationScreen].
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onCreateAccount});

  final VoidCallback onCreateAccount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.blue900, AppColors.blue700],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                flex: 5,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Soft brand-teal glow, bottom-left — same accent color
                    // the rest of the app uses, just deployed as depth here.
                    Positioned(
                      left: -70,
                      bottom: -60,
                      child: _Glow(color: AppColors.teal500, size: 280, opacity: 0.35),
                    ),
                    Positioned(
                      top: -50,
                      right: -60,
                      child: _Glow(color: AppColors.blue500, size: 240, opacity: 0.3),
                    ),
                    Center(
                      child: Image.asset(
                        'assets/images/doctor_welcome.png',
                        height: 300,
                        fit: BoxFit.contain,
                        // Falls back to the code-drawn illustration until
                        // the real asset is dropped into assets/images/ —
                        // keeps the app buildable and the screen populated
                        // either way.
                        errorBuilder: (context, error, stackTrace) => CustomPaint(
                          size: const Size(230, 310),
                          painter: _DoctorIllustrationPainter(),
                        ),
                      ),
                    ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack, duration: 550.ms),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Welcome',
                        style: AppText.display(size: 34, color: AppColors.teal100),
                      ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
                      Row(
                        children: [
                          Text('to ', style: AppText.display(size: 30, color: Colors.white)),
                          Flexible(
                            child: Text(
                              'MediConnectAI',
                              overflow: TextOverflow.ellipsis,
                              style: AppText.display(size: 30, color: Colors.white, weight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 220.ms, duration: 400.ms),
                      const SizedBox(height: 20),
                      Text(
                        'Consultation with general practitioners & specialists, anytime, anywhere',
                        style: AppText.body(size: 14, color: Colors.white.withValues(alpha: 0.82)).copyWith(height: 1.4),
                      ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: _WelcomeButton(label: 'Registration Profile', onPressed: onCreateAccount),
                      ).animate().fadeIn(delay: 380.ms, duration: 400.ms),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Soft radial blur, ported from the same `_Glow` pattern used on the
/// (removed) OTP login screen — kept here so the welcome hero has the same
/// depth language as the rest of the app.
class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size, this.opacity = 0.5});
  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0.0)]),
        ),
      ),
    );
  }
}

/// The regular [AppButton] is styled for the clinical blue/white app body —
/// this splash instead needs a light pill that reads against the dark blue
/// background, so it's a small standalone variant rather than stretching
/// [AppButton]'s variant enum for a one-off screen.
class _WelcomeButton extends StatefulWidget {
  const _WelcomeButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  State<_WelcomeButton> createState() => _WelcomeButtonState();
}

class _WelcomeButtonState extends State<_WelcomeButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(100),
          child: InkWell(
            borderRadius: BorderRadius.circular(100),
            onTap: widget.onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Center(
                child: Text(
                  widget.label,
                  style: AppText.body(size: 14.5, weight: FontWeight.w700, color: AppColors.blue700),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A flat-style illustration of a doctor — head, coat, stethoscope, a hand
/// holding a phone, and a small potted plant — drawn with plain canvas
/// primitives (no image asset was supplied) using the app's own blue/teal
/// palette so it reads as "this app" rather than a generic stock graphic.
class _DoctorIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.56;

    // Soft halo behind the head — the one purely decorative touch that
    // keeps the figure from reading as flat/emoji-like.
    canvas.drawCircle(
      Offset(cx, h * 0.28),
      46,
      Paint()..shader = RadialGradient(colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0)]).createShader(
            Rect.fromCircle(center: Offset(cx, h * 0.28), radius: 46),
          ),
    );

    // Ground shadow.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.97), width: w * 0.62, height: h * 0.035),
      Paint()..color = AppColors.blue900.withValues(alpha: 0.28),
    );

    _paintPlant(canvas, Offset(w * 0.08, h * 0.72), w * 0.22);

    const skin = Color(0xFFF2C6A0);
    const hair = Color(0xFF3B2A20);
    const scrub = AppColors.teal500;
    const steth = AppColors.blue900;

    // Legs (teal scrub trousers — coordinates with the coat's teal lining).
    final legPaint = Paint()..color = scrub;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - 34, h * 0.72, 26, h * 0.24), const Radius.circular(10)), legPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx + 6, h * 0.72, 26, h * 0.24), const Radius.circular(10)), legPaint);

    // Coat (torso) — subtle gradient instead of flat white for some depth.
    final coatRect = Rect.fromLTWH(cx - 46, h * 0.40, 92, h * 0.35);
    final coatRRect = RRect.fromRectAndCorners(
      coatRect,
      topLeft: const Radius.circular(28),
      topRight: const Radius.circular(28),
      bottomLeft: const Radius.circular(14),
      bottomRight: const Radius.circular(14),
    );
    canvas.drawRRect(
      coatRRect,
      Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, Color(0xFFEAF1F8)]).createShader(coatRect),
    );
    canvas.drawRRect(coatRRect, Paint()..color = const Color(0xFFDDE3EA)..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // V-neck strip of teal scrubs peeking through the coat.
    final vNeck = Path()
      ..moveTo(cx - 10, h * 0.40)
      ..lineTo(cx + 10, h * 0.40)
      ..lineTo(cx, h * 0.40 + 30)
      ..close();
    canvas.drawPath(vNeck, Paint()..color = scrub.withValues(alpha: 0.9));

    // Coat seam + a small ID badge on the chest pocket, for a touch of
    // professional detail beyond a flat silhouette.
    canvas.drawLine(
      Offset(cx, h * 0.40 + 30),
      Offset(cx, h * 0.40 + (h * 0.35) - 8),
      Paint()..color = const Color(0xFFDDE3EA)..strokeWidth = 1.5,
    );
    final badgeRect = Rect.fromLTWH(cx - 40, h * 0.40 + 44, 14, 18);
    canvas.drawRRect(RRect.fromRectAndRadius(badgeRect, const Radius.circular(2)), Paint()..color = AppColors.blue100);
    canvas.drawCircle(Offset(badgeRect.center.dx, badgeRect.top + 6), 3, Paint()..color = AppColors.blue600);

    // Arms.
    final armPaint = Paint()
      ..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, Color(0xFFEAF1F8)])
          .createShader(Rect.fromLTWH(cx - 62, h * 0.44, 124, h * 0.22));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - 62, h * 0.44, 20, h * 0.22), const Radius.circular(10)), armPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx + 42, h * 0.44, 20, h * 0.16), const Radius.circular(10)), armPaint);

    // Hand holding a phone.
    canvas.drawCircle(Offset(cx - 52, h * 0.44 + h * 0.22), 10, Paint()..color = skin);
    final phoneRect = Rect.fromLTWH(cx - 66, h * 0.44 + h * 0.22 - 4, 22, 34);
    canvas.drawRRect(RRect.fromRectAndRadius(phoneRect, const Radius.circular(5)), Paint()..color = steth);
    canvas.drawRRect(RRect.fromRectAndRadius(phoneRect.deflate(3), const Radius.circular(3)), Paint()..color = AppColors.blue100);

    // Stethoscope: a loop around the neck down to a chest piece.
    final stethPath = Path()
      ..moveTo(cx - 16, h * 0.40 + 6)
      ..cubicTo(cx - 24, h * 0.40 + 26, cx - 20, h * 0.40 + 44, cx - 8, h * 0.40 + 50)
      ..moveTo(cx + 16, h * 0.40 + 6)
      ..cubicTo(cx + 24, h * 0.40 + 26, cx + 18, h * 0.40 + 46, cx + 6, h * 0.40 + 52);
    canvas.drawPath(
      stethPath,
      Paint()..color = steth..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(cx - 1, h * 0.40 + 54), 6, Paint()..color = steth);

    // Head + simple bob hairstyle, with a soft highlight for shine.
    final headCenter = Offset(cx, h * 0.30);
    canvas.drawCircle(headCenter, 26, Paint()..color = skin);
    canvas.drawCircle(
      Offset(headCenter.dx - 9, headCenter.dy - 9),
      9,
      Paint()..color = Colors.white.withValues(alpha: 0.25),
    );
    final hairPath = Path()
      ..moveTo(headCenter.dx - 26, headCenter.dy - 2)
      ..arcToPoint(Offset(headCenter.dx + 26, headCenter.dy - 2), radius: const Radius.circular(26), clockwise: false)
      ..lineTo(headCenter.dx + 24, headCenter.dy + 22)
      ..quadraticBezierTo(headCenter.dx + 14, headCenter.dy + 6, headCenter.dx + 10, headCenter.dy + 20)
      ..quadraticBezierTo(headCenter.dx, headCenter.dy + 4, headCenter.dx - 10, headCenter.dy + 20)
      ..quadraticBezierTo(headCenter.dx - 14, headCenter.dy + 6, headCenter.dx - 24, headCenter.dy + 22)
      ..close();
    canvas.drawPath(hairPath, Paint()..color = hair);
  }

  void _paintPlant(Canvas canvas, Offset base, double scale) {
    final potPaint = Paint()..color = const Color(0xFF6B4A3A);
    final potPath = Path()
      ..moveTo(base.dx - scale * 0.35, base.dy)
      ..lineTo(base.dx + scale * 0.35, base.dy)
      ..lineTo(base.dx + scale * 0.28, base.dy + scale * 0.32)
      ..lineTo(base.dx - scale * 0.28, base.dy + scale * 0.32)
      ..close();
    canvas.drawPath(potPath, potPaint);

    final leafPaint = Paint()..color = const Color(0xFF3E9A72);
    for (final angle in [-0.5, 0.0, 0.5]) {
      canvas.save();
      canvas.translate(base.dx, base.dy);
      canvas.rotate(angle);
      canvas.drawOval(Rect.fromCenter(center: Offset(0, -scale * 0.5), width: scale * 0.28, height: scale * 0.7), leafPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
