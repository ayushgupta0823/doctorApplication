import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_theme.dart';

/// A single shimmering placeholder block — a stand-in for text, an
/// avatar, or any other not-yet-loaded content.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 4, this.shape = BoxShape.rectangle});

  final double? width;
  final double height;
  final double radius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.lineSoft,
        shape: shape,
        borderRadius: shape == BoxShape.rectangle ? BorderRadius.circular(radius) : null,
      ),
    );
  }
}

/// Wraps any arrangement of [SkeletonBox]es in one shared shimmer sweep —
/// replaces the hand-rolled `AnimationController`/`FadeTransition` pulse
/// that used to be reimplemented per-screen.
class ShimmerLoading extends StatelessWidget {
  const ShimmerLoading({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.lineSoft,
      highlightColor: AppColors.white,
      child: child,
    );
  }
}
