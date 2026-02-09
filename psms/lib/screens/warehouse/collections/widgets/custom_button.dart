// custom_button.dart
import 'package:flutter/material.dart';

enum ButtonVariant { primary, secondary, outline, danger, success }

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;
  final ButtonVariant variant;
  final bool isLoading;
  final bool disabled;
  final double width;
  final double height;
  final EdgeInsets padding;
  final double borderRadius;
  final TextStyle? textStyle;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;

  const CustomButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.variant = ButtonVariant.primary,
    this.isLoading = false,
    this.disabled = false,
    this.width = double.infinity,
    this.height = 48,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    this.borderRadius = 8,
    this.textStyle,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _getColors(theme);

    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: (disabled || isLoading) ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.backgroundColor,
          foregroundColor: colors.textColor,
          padding: padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            side: variant == ButtonVariant.outline
                ? BorderSide(color: borderColor ?? theme.primaryColor, width: 1.5)
                : BorderSide.none,
          ),
          elevation: variant == ButtonVariant.outline ? 0 : 2,
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.textColor,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 20,
                      color: colors.textColor,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: textStyle ??
                        TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colors.textColor,
                        ),
                  ),
                ],
              ),
      ),
    );
  }

  _ButtonColors _getColors(ThemeData theme) {
    switch (variant) {
      case ButtonVariant.primary:
        return _ButtonColors(
          backgroundColor: backgroundColor ?? theme.primaryColor,
          textColor: textColor ?? Colors.white,
        );
      case ButtonVariant.secondary:
        return _ButtonColors(
          backgroundColor: backgroundColor ?? Colors.grey.shade200,
          textColor: textColor ?? Colors.grey.shade800,
        );
      case ButtonVariant.outline:
        return _ButtonColors(
          backgroundColor: Colors.transparent,
          textColor: textColor ?? theme.primaryColor,
        );
      case ButtonVariant.danger:
        return _ButtonColors(
          backgroundColor: backgroundColor ?? Colors.red,
          textColor: textColor ?? Colors.white,
        );
      case ButtonVariant.success:
        return _ButtonColors(
          backgroundColor: backgroundColor ?? Colors.green,
          textColor: textColor ?? Colors.white,
        );
      default:
        return _ButtonColors(
          backgroundColor: backgroundColor ?? theme.primaryColor,
          textColor: textColor ?? Colors.white,
        );
    }
  }
}

class _ButtonColors {
  final Color backgroundColor;
  final Color textColor;

  _ButtonColors({
    required this.backgroundColor,
    required this.textColor,
  });
}