// widgets/custom_card.dart
import 'package:flutter/material.dart';
import 'package:psms/constants/app_constants.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final double? elevation;

  const CustomCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin ?? AppEdgeInsets.allMedium,
      elevation: elevation ?? 2,
      color: backgroundColor ?? AppColors.cardBackground,
      child: Padding(
        padding: padding ?? AppEdgeInsets.allMedium,
        child: child,
      ),
    );
  }
}