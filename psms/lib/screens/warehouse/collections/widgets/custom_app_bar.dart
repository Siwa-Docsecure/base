// TODO Implement this library.// custom_app_bar.dart
import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget> actions;
  final Widget? leading;
  final bool showBackButton;
  final Color? backgroundColor;
  final Color? textColor;
  final double elevation;
  final VoidCallback? onBackPressed;

  const CustomAppBar({
    Key? key,
    required this.title,
    this.actions = const [],
    this.leading,
    this.showBackButton = true,
    this.backgroundColor,
    this.textColor,
    this.elevation = 2,
    this.onBackPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: backgroundColor ?? Theme.of(context).primaryColor,
      elevation: elevation,
      leading: leading ?? (showBackButton ? _buildBackButton(context) : null),
      actions: actions,
      centerTitle: true,
      iconTheme: IconThemeData(color: textColor ?? Colors.white),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}