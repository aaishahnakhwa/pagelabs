import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ToolEmptyState extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String buttonText;
  final IconData? buttonIcon;
  final VoidCallback onSelect;
  final List<String> supportedFormats;
  final Color? iconColor;
  final Color? iconBgColor;

  const ToolEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.buttonText,
    required this.onSelect,
    this.buttonIcon,
    this.supportedFormats = const ['JPG', 'PNG', 'WEBP'],
    this.iconColor,
    this.iconBgColor,
  });

  @override
  State<ToolEmptyState> createState() => _ToolEmptyStateState();
}

class _ToolEmptyStateState extends State<ToolEmptyState> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveIconColor = widget.iconColor ?? AppColors.primary;
    final effectiveIconBgColor = widget.iconBgColor ??
        (isDark
            ? effectiveIconColor.withValues(alpha: 0.18)
            : effectiveIconColor.withValues(alpha: 0.12));

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onSelect,
              child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDarkElevated : Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: _isHovered
                      ? effectiveIconColor.withValues(alpha: 0.6)
                      : (isDark ? AppColors.borderDark : AppColors.borderLight),
                  width: _isHovered ? 2.0 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isHovered
                        ? effectiveIconColor.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: _isHovered ? 28 : 16,
                    offset: Offset(0, _isHovered ? 10 : 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Animated Icon Bubble
                  AnimatedScale(
                    scale: _isHovered ? 1.08 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: effectiveIconBgColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: effectiveIconColor.withValues(alpha: 0.15),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.icon,
                        size: 46,
                        color: effectiveIconColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: isDark ? AppColors.textLight : AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    widget.subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Primary Select Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: widget.onSelect,
                      icon: Icon(widget.buttonIcon ?? Icons.add_photo_alternate_rounded, size: 20),
                      label: Text(
                        widget.buttonText,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: _isHovered ? 6 : 2,
                        shadowColor: AppColors.primary.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
