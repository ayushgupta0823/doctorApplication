import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppButtonVariant { primary, ghost, subtle, danger, success }

/// Pill-ish action button, ported from `.btn.*` classes, with a
/// press-down scale animation (`.btn:active{transform:scale(.97)}`).
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.onPressed,
    this.small = false,
    this.block = false,
    this.loading = false,
  });

  final String label;
  final Widget? icon;
  final AppButtonVariant variant;
  final VoidCallback? onPressed;
  final bool small;
  final bool block;
  final bool loading;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  ({Color bg, Color fg, Color? border}) get _colors {
    switch (widget.variant) {
      case AppButtonVariant.primary:
        return (bg: AppColors.blue600, fg: Colors.white, border: null);
      case AppButtonVariant.ghost:
        return (bg: Colors.white, fg: AppColors.blue700, border: AppColors.line);
      case AppButtonVariant.subtle:
        return (bg: AppColors.blue100, fg: AppColors.blue700, border: null);
      case AppButtonVariant.danger:
        return (bg: AppColors.red100, fg: AppColors.red600, border: null);
      case AppButtonVariant.success:
        return (bg: AppColors.green600, fg: Colors.white, border: null);
    }
  }

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    final disabled = widget.onPressed == null || widget.loading;

    final child = Row(
      mainAxisSize: widget.block ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: c.fg),
          )
        else if (widget.icon != null)
          IconTheme(data: IconThemeData(color: c.fg, size: 16), child: widget.icon!),
        if (widget.loading || widget.icon != null) const SizedBox(width: 6),
        Flexible(
          child: Text(
            widget.label,
            overflow: TextOverflow.ellipsis,
            style: AppText.body(
              size: widget.small ? 11.5 : 12.5,
              weight: FontWeight.w700,
              color: c.fg,
            ),
          ),
        ),
      ],
    );

    return Opacity(
      opacity: disabled && !widget.loading ? .45 : 1,
      child: GestureDetector(
        onTapDown: disabled ? null : (_) => _setPressed(true),
        onTapUp: disabled ? null : (_) => _setPressed(false),
        onTapCancel: disabled ? null : () => _setPressed(false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: Material(
            color: c.bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: c.border != null ? BorderSide(color: c.border!) : BorderSide.none,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: disabled ? null : widget.onPressed,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: widget.small ? 36 : 44),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: widget.small ? 10 : 14, vertical: widget.small ? 6 : 9),
                  child: Center(child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
