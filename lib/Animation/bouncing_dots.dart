
import 'dart:math';
import 'package:flutter/material.dart' show AnimatedBuilder, AnimationController, BoxDecoration, BoxShape, BuildContext, Color, Colors, Container, MainAxisAlignment, Row, SizedBox, State, StatefulWidget, TickerProviderStateMixin, Transform, Widget;

class BouncingDotsIndicator extends StatefulWidget {
  final Color color;
  final double size;

  const BouncingDotsIndicator({
    super.key,
    this.color = Colors.green,
    this.size = 4.0,
  });

  @override
  State<BouncingDotsIndicator> createState() => _BouncingDotsIndicatorState();
}

class _BouncingDotsIndicatorState extends State<BouncingDotsIndicator>
    with TickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              final animationValue =
              (_animationController.value - (index * 0.1)).clamp(0.0, 1.0);
              final scale = (sin(animationValue * pi) * 0.5 + 0.5);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}