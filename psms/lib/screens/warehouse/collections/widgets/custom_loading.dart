// custom_loading.dart
import 'package:flutter/material.dart';

class CustomLoading extends StatelessWidget {
  final String? message;
  final double size;
  final Color color;
  final bool showMessage;
  final Axis direction;
  final double spacing;

  const CustomLoading({
    Key? key,
    this.message,
    this.size = 40,
    this.color = Colors.blue,
    this.showMessage = true,
    this.direction = Axis.vertical,
    this.spacing = 16,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final loadingWidget = SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 3,
        valueColor: AlwaysStoppedAnimation<Color>(color),
        backgroundColor: color.withOpacity(0.2),
      ),
    );

    if (!showMessage && message == null) {
      return Center(child: loadingWidget);
    }

    return Center(
      child: direction == Axis.vertical
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                loadingWidget,
                SizedBox(height: spacing),
                if (message != null)
                  Text(
                    message!,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                loadingWidget,
                SizedBox(width: spacing),
                if (message != null)
                  Text(
                    message!,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
    );
  }
}