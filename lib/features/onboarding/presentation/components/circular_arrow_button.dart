import 'package:flutter/material.dart';

import '../../../../core/haptics/app_haptics.dart';
import '../../../../core/theme/app_colors.dart';

/// Reusable circular outline next button matching Reference 3.
///
/// Features:
/// - Circular outline with customizable border color and arrow color
/// - Interactive scale micro-press:
///   press: scale 1.0 → 0.94 (100ms easeOut)
///   release: scale 0.94 → 1.0 (200ms easeOutBack)
/// - Integrated light haptic feedback
class CircularArrowButton extends StatefulWidget {
  final VoidCallback onTap;
  final Color color;
  final double size;
  final double borderWidth;
  final double iconSize;

  const CircularArrowButton({
    super.key,
    required this.onTap,
    this.color = AppColors.navy900,
    this.size = 58.0,
    this.borderWidth = 1.5,
    this.iconSize = 20.0,
  });

  @override
  State<CircularArrowButton> createState() => _CircularArrowButtonState();
}

class _CircularArrowButtonState extends State<CircularArrowButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) async {
        setState(() => _isPressed = false);
        AppHaptics.light();
        await Future<void>.delayed(const Duration(milliseconds: 140));
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: Duration(milliseconds: _isPressed ? 100 : 200),
        curve: _isPressed ? Curves.easeOut : Curves.easeOutBack,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
            border: Border.all(color: widget.color, width: widget.borderWidth),
          ),
          child: Center(
            child: Icon(
              Icons.arrow_forward_rounded,
              size: widget.iconSize,
              color: widget.color,
            ),
          ),
        ),
      ),
    );
  }
}
