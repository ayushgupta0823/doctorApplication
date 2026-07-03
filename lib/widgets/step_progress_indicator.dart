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
  });

  /// 0-based index of the active step.
  final int currentStep;
  final int totalSteps;
  final IconData? currentStepIcon;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < totalSteps; i++) {
      children.add(_StepCircle(
        index: i,
        state: i < currentStep
            ? _StepState.done
            : i == currentStep
                ? _StepState.active
                : _StepState.pending,
        icon: i == currentStep ? currentStepIcon : null,
      ));
      if (i != totalSteps - 1) {
        children.add(Expanded(
          child: Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: i < currentStep ? AppColors.blue600 : AppColors.line,
          ),
        ));
      }
    }
    return Row(children: children);
  }
}

enum _StepState { done, active, pending }

class _StepCircle extends StatelessWidget {
  const _StepCircle({required this.index, required this.state, this.icon});
  final int index;
  final _StepState state;
  final IconData? icon;

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

    return Container(
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
  }
}
