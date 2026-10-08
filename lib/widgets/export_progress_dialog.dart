import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Reusable modal loading square overlay that displays circular progress with live percentage.
class ExportProgressDialog {
  final BuildContext context;
  final String title;
  final String initialStatus;
  final bool autoAnimate;

  final ValueNotifier<double> _progressNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<String> _statusNotifier;
  final ValueNotifier<bool> _isCompletedNotifier = ValueNotifier<bool>(false);

  bool _isShowing = false;
  Timer? _autoProgressTimer;

  ExportProgressDialog(
    this.context, {
    this.title = 'Exporting...',
    this.initialStatus = 'Please wait a moment',
    this.autoAnimate = true,
  }) : _statusNotifier = ValueNotifier<String>(initialStatus);

  /// Shows the square loading overlay dialog with backdrop blur.
  void show() {
    if (_isShowing) return;
    _isShowing = true;

    if (autoAnimate) {
      _startAutoProgress();
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      barrierLabel: 'ExportProgress',
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6 * anim1.value, sigmaY: 6 * anim1.value),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.82, end: 1.0).animate(curved),
            child: FadeTransition(
              opacity: anim1,
              child: child,
            ),
          ),
        );
      },
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;

        return PopScope(
          canPop: false,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: ExportProgressCard(
                title: title,
                progressNotifier: _progressNotifier,
                statusNotifier: _statusNotifier,
                isCompletedNotifier: _isCompletedNotifier,
                isDark: isDark,
              ),
            ),
          ),
        );
      },
    ).then((_) {
      _isShowing = false;
      _autoProgressTimer?.cancel();
    });
  }

  void _startAutoProgress() {
    _autoProgressTimer?.cancel();
    // Smoothly crawl towards 0.85 until manual updates or completion
    _autoProgressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_progressNotifier.value < 0.85 && !_isCompletedNotifier.value) {
        final step = (0.85 - _progressNotifier.value) * 0.05;
        _progressNotifier.value = (_progressNotifier.value + step).clamp(0.0, 0.85);
      }
    });
  }

  /// Manually update progress percentage (0.0 to 1.0) and optional status text.
  void update(double progress, [String? status]) {
    _progressNotifier.value = progress.clamp(0.0, 1.0);
    if (status != null && status.isNotEmpty) {
      _statusNotifier.value = status;
    }
  }

  /// Finish progress at 100%, show completion checkmark briefly, then dismiss.
  Future<void> complete([String? status]) async {
    _autoProgressTimer?.cancel();
    _isCompletedNotifier.value = true;
    _progressNotifier.value = 1.0;
    if (status != null) {
      _statusNotifier.value = status;
    } else {
      _statusNotifier.value = 'Done!';
    }

    // Brief pause so user sees 100% checkmark confirmation
    await Future.delayed(const Duration(milliseconds: 400));
    dismiss();
  }

  /// Dismisses the dialog immediately.
  void dismiss() {
    _autoProgressTimer?.cancel();
    if (_isShowing && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
      _isShowing = false;
    }
  }

  /// Convenience runner: wraps an async export task with progress overlay.
  static Future<T> run<T>({
    required BuildContext context,
    String title = 'Exporting...',
    String initialStatus = 'Preparing file...',
    required Future<T> Function(void Function(double progress, [String? status]) update) task,
  }) async {
    final dialog = ExportProgressDialog(
      context,
      title: title,
      initialStatus: initialStatus,
    );
    dialog.show();

    try {
      final result = await task((p, [s]) => dialog.update(p, s));
      await dialog.complete();
      return result;
    } catch (e) {
      dialog.dismiss();
      rethrow;
    }
  }
}

/// Standalone Square Loading Card
class ExportProgressCard extends StatelessWidget {
  final String title;
  final ValueNotifier<double> progressNotifier;
  final ValueNotifier<String> statusNotifier;
  final ValueNotifier<bool> isCompletedNotifier;
  final bool isDark;

  const ExportProgressCard({
    super.key,
    required this.title,
    required this.progressNotifier,
    required this.statusNotifier,
    required this.isCompletedNotifier,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Perfectly square card container (210 x 210)
    return Container(
      width: 215,
      height: 215,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2A) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFE5DFD5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Circular progress ring with live percentage in center
          ValueListenableBuilder<bool>(
            valueListenable: isCompletedNotifier,
            builder: (context, isCompleted, _) {
              return ValueListenableBuilder<double>(
                valueListenable: progressNotifier,
                builder: (context, progress, _) {
                  final percentInt = (progress * 100).clamp(0, 100).toInt();

                  return SizedBox(
                    width: 82,
                    height: 82,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background track
                        SizedBox(
                          width: 82,
                          height: 82,
                          child: CircularProgressIndicator(
                            value: 1.0,
                            strokeWidth: 6.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isCompleted
                                  ? AppColors.sageGreen.withValues(alpha: 0.18)
                                  : AppColors.primary.withValues(alpha: 0.15),
                            ),
                          ),
                        ),

                        // Active animated progress ring
                        SizedBox(
                          width: 82,
                          height: 82,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.0, end: progress),
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            builder: (context, animatedValue, _) {
                              return CircularProgressIndicator(
                                value: animatedValue,
                                strokeWidth: 6.5,
                                strokeCap: StrokeCap.round,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isCompleted ? AppColors.sageGreen : AppColors.primary,
                                ),
                              );
                            },
                          ),
                        ),

                        // Center content: live % or completion check icon
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: isCompleted
                              ? const Icon(
                                  Icons.check_rounded,
                                  key: ValueKey('completed_icon'),
                                  color: AppColors.sageGreen,
                                  size: 36,
                                )
                              : Text(
                                  '$percentInt%',
                                  key: const ValueKey('percent_text'),
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                    color: isDark ? Colors.white : AppColors.textDark,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 14),

          // Title
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.textLight : AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),

          // Status label
          ValueListenableBuilder<String>(
            valueListenable: statusNotifier,
            builder: (context, statusText, _) {
              return Text(
                statusText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
