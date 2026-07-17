import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Numbered/iconed circle-and-line progress stepper used across the
/// onboarding flow (NMC verification -> digital signature -> permissions).
class StepProgressIndicator extends StatelessWidget {
  const StepProgressIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.currentStepIcon,
    this.labels,
  });

  /// 0-based index of the active step.
  final int currentStep;
  final int totalSteps;
  final IconData? currentStepIcon;

  /// Optional short label rendered under each step circle (e.g. "Personal
  /// Details"). Must match [totalSteps] in length when provided. Leaving
  /// this null keeps the original bare circle-and-line look.
  final List<String>? labels;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < totalSteps; i++) {
      final state = i < currentStep
          ? _StepState.done
          : i == currentStep
              ? _StepState.active
              : _StepState.pending;
      children.add(_StepCircle(
        index: i,
        state: state,
        icon: i == currentStep ? currentStepIcon : null,
        label: labels != null ? labels![i] : null,
      ));
      if (i != totalSteps - 1) {
        children.add(Expanded(
          child: Container(
            height: 2,
            margin: EdgeInsets.only(
              left: 4,
              right: 4,
              // With labels present, the row is top-aligned (so label text
              // can extend below without stretching the circles) — offset
              // the line down so it still crosses through the circles'
              // vertical center instead of hugging the row's top edge.
              top: labels != null ? 13 : 0,
            ),
            color: i < currentStep ? AppColors.blue600 : AppColors.line,
          ),
        ));
      }
    }
    return Row(
      crossAxisAlignment: labels != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: children,
    );
  }
}

enum _StepState { done, active, pending }

class _StepCircle extends StatelessWidget {
  const _StepCircle({required this.index, required this.state, this.icon, this.label});
  final int index;
  final _StepState state;
  final IconData? icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final Color border;
    switch (state) {
      case _StepState.done:
        bg = AppColors.blue600;
        fg = Colors.white;
        border = AppColors.blue600;
        break;
      case _StepState.active:
        bg = AppColors.blue600;
        fg = Colors.white;
        border = AppColors.blue600;
        break;
      case _StepState.pending:
        bg = Colors.white;
        fg = AppColors.ink400;
        border = AppColors.line;
        break;
    }

    Widget child;
    if (state == _StepState.done) {
      child = const Icon(Icons.check, size: 16, color: Colors.white);
    } else if (icon != null) {
      child = Icon(icon, size: 16, color: fg);
    } else {
      child = Text('${index + 1}', style: AppText.mono(size: 12, weight: FontWeight.w700, color: fg));
    }

    final circle = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1.5),
      ),
      alignment: Alignment.center,
      child: child,
    );

    if (label == null) return circle;

    return SizedBox(
      width: 70,
      child: Column(
        children: [
          circle,
          const SizedBox(height: 6),
          Text(
            label!,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.body(
              size: 9.5,
              weight: state == _StepState.pending ? FontWeight.w500 : FontWeight.w700,
              color: state == _StepState.pending ? AppColors.ink400 : AppColors.blue700,
            ),
          ),
        ],
      ),
    );
  }
}
