// lib/widget/common/skeleton_widgets.dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonWidgets {
  // Private constructor to prevent instantiation
  SkeletonWidgets._();

  // Default colors
  static const Color _baseColor = Color(0xFFE0E0E0);
  static const Color _highlightColor = Color(0xFFF5F5F5);
  static const Color _primaryColor = Color(0xFFB21E1E);

  // Initial loading skeleton with bouncing dots
  static Widget buildInitialLoadingSkeleton({
    String message = 'Loading...',
    Color? dotColor,
    double dotSize = 8.0,
    EdgeInsets padding = const EdgeInsets.all(40),
  }) {
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BouncingDotsIndicator(
              color: dotColor ?? _primaryColor,
              size: dotSize,
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Generic card skeleton
  static Widget buildCardSkeleton({
    double? width,
    double height = 100,
    EdgeInsets margin = EdgeInsets.zero,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Shimmer.fromColors(
        baseColor: _baseColor,
        highlightColor: _highlightColor,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  // List item skeleton
  static Widget buildListItemSkeleton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Shimmer.fromColors(
        baseColor: _baseColor,
        highlightColor: _highlightColor,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 200,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Page skeleton (combines multiple skeletons)
  static Widget buildPageSkeleton({
    bool showMap = true,
    bool showActionButtons = true,
    bool showBookingsList = true,
    int bookingItemsCount = 3,
  }) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),
          if (showMap) ...[
            buildCardSkeleton(width: double.infinity, height: 250),
            const SizedBox(height: 16),
          ],
          if (showActionButtons) ...[
            buildCardSkeleton(width: double.infinity, height: 80),
            const SizedBox(height: 16),
          ],
          if (showBookingsList) ...[
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Shimmer.fromColors(
                    baseColor: _baseColor,
                    highlightColor: _highlightColor,
                    child: Container(
                      width: 150,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(bookingItemsCount, (index) =>
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: buildListItemSkeleton(),
                      ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Bouncing dots indicator widget
class BouncingDotsIndicator extends StatefulWidget {
  final Color color;
  final double size;
  final int dotCount;
  final Duration animationDuration;

  const BouncingDotsIndicator({
    Key? key,
    this.color = Colors.blue,
    this.size = 8.0,
    this.dotCount = 3,
    this.animationDuration = const Duration(milliseconds: 600),
  }) : super(key: key);

  @override
  State<BouncingDotsIndicator> createState() => _BouncingDotsIndicatorState();
}

class _BouncingDotsIndicatorState extends State<BouncingDotsIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _animationControllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationControllers = List.generate(
      widget.dotCount,
          (index) => AnimationController(
        duration: widget.animationDuration,
        vsync: this,
      ),
    );

    _animations = _animationControllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();

    // Start animations with delays
    for (int i = 0; i < _animationControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) {
          _animationControllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _animationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.dotCount, (index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            return Container(
              margin: EdgeInsets.symmetric(horizontal: widget.size * 0.2),
              child: Transform.translate(
                offset: Offset(0, -_animations[index].value * widget.size),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

// Extension for easy usage
extension SkeletonExtension on Widget {
  Widget withSkeleton({
    required bool isLoading,
    Widget? skeleton,
  }) {
    return isLoading ? (skeleton ?? SkeletonWidgets.buildCardSkeleton()) : this;
  }
}