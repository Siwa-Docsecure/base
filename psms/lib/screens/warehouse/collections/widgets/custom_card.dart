// custom_card.dart
import 'package:flutter/material.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final Color? backgroundColor;
  final double borderRadius;
  final double elevation;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Border? border;
  final bool showShadow;

  const CustomCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.backgroundColor,
    this.borderRadius = 12,
    this.elevation = 2,
    this.onTap,
    this.onLongPress,
    this.border,
    this.showShadow = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: Material(
        color: backgroundColor ?? Theme.of(context).cardColor,
        elevation: showShadow ? elevation : 0,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: border ??
                  Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.1),
                    width: 1,
                  ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}