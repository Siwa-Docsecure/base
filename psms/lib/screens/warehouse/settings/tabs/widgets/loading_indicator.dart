// widgets/loading_indicator.dart
import 'package:flutter/material.dart';
import 'package:psms/constants/app_constants.dart';

class LoadingIndicator extends StatelessWidget {
  final String message;
  final bool showBackground;
  final Color? backgroundColor;
  final Color? indicatorColor;
  final double? size;

  const LoadingIndicator({
    super.key,
    this.message = 'Loading...',
    this.showBackground = false,
    this.backgroundColor,
    this.indicatorColor,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    if (showBackground) {
      return Container(
        color: backgroundColor ?? AppColors.background,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  indicatorColor ?? AppColors.primary,
                ),
                strokeWidth: 3,
              ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  message,
                  style: AppTypography.bodyText(color: AppColors.textMedium),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size ?? 40,
            height: size ?? 40,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                indicatorColor ?? AppColors.primary,
              ),
              strokeWidth: 3,
            ),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              message,
              style: AppTypography.bodyText(color: AppColors.textMedium),
            ),
          ],
        ],
      ),
    );
  }
}

// For linear loading (for app bars, etc.)
class LinearLoadingIndicator extends StatelessWidget {
  final Color? color;
  final double? height;

  const LinearLoadingIndicator({
    super.key,
    this.color,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height ?? 2,
      child: LinearProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? AppColors.primary,
        ),
        backgroundColor: Colors.transparent,
      ),
    );
  }
}

// For shimmer effect
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final bool isLoading;

  const ShimmerLoading({
    super.key,
    required this.child,
    required this.isLoading,
  });

  @override
  ShimmerLoadingState createState() => ShimmerLoadingState();
}

class ShimmerLoadingState extends State<ShimmerLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                AppColors.background.withOpacity(0.6),
                AppColors.white.withOpacity(0.9),
                AppColors.background.withOpacity(0.6),
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.topRight,
              transform: _GradientTransform(_controller.value),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

class _GradientTransform extends GradientTransform {
  final double percent;

  _GradientTransform(this.percent);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final dx = bounds.width * 2;
    return Matrix4.translationValues(dx * (percent - 0.5), 0.0, 0.0);
  }
}