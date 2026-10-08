import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BeforeAfterSlider extends StatefulWidget {
  final Uint8List beforeBytes;
  final Uint8List afterBytes;
  final double height;

  const BeforeAfterSlider({
    super.key,
    required this.beforeBytes,
    required this.afterBytes,
    this.height = 320,
  });

  @override
  State<BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<BeforeAfterSlider> {
  double _splitFraction = 0.5;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final splitX = totalWidth * _splitFraction;

        return ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Container(
            height: widget.height,
            width: totalWidth,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.borderLight, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. After (Enhanced) Image in background
                Image.memory(
                  widget.afterBytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),

                // 2. Before (Original) Image clipped to left side
                ClipRect(
                  clipper: _LeftClipper(splitX),
                  child: Image.memory(
                    widget.beforeBytes,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),

                // 3. Before Badge (Top Left)
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24, width: 0.8),
                    ),
                    child: const Text(
                      'BEFORE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),

                // 4. After Badge (Top Right)
                Positioned(
                  top: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white30, width: 0.8),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      'AFTER (HD)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),

                // 5. Divider Line
                Positioned(
                  left: splitX - 1.5,
                  top: 0,
                  bottom: 0,
                  width: 3,
                  child: Container(
                    color: Colors.white,
                    child: Center(
                      child: Container(
                        width: 1,
                        color: Colors.black26,
                      ),
                    ),
                  ),
                ),

                // 6. Center Floating Thumb
                Positioned(
                  left: splitX - 20,
                  top: (widget.height / 2) - 20,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.compare_arrows_rounded,
                        size: 22,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),

                // Full surface horizontal drag handler
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _splitFraction = (details.localPosition.dx / totalWidth).clamp(0.04, 0.96);
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LeftClipper extends CustomClipper<Rect> {
  final double width;
  _LeftClipper(this.width);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, width, size.height);
  }

  @override
  bool shouldReclip(covariant _LeftClipper oldClipper) => oldClipper.width != width;
}
