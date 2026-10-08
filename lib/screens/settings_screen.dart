import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/theme_controller.dart';
import '../services/storage_service.dart';
import '../widgets/page_lab_app_bar.dart';
import 'onboarding_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: ThemeController(),
      builder: (context, _) {
        final currentMode = ThemeController().themeMode;

        return Scaffold(
          appBar: const PageLabAppBar(
            title: 'Settings',
            subtitle: 'Preferences & Storage',
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView(
                padding: const EdgeInsets.all(18),
            children: [
              // 1. Privacy Banner (Key value proposition: 100% Offline)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.sageGreen.withValues(alpha: 0.16),
                      AppColors.slateBlue.withValues(alpha: 0.12),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppColors.sageGreen.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(
                        color: AppColors.sageGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '100% Offline & Private',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: isDark ? AppColors.textLight : AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'All cropping, resizing, PDF rendering, compression and passport photo generation happen locally on your device.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 2. Theme Mode Selector
              _buildSectionTitle('Appearance & Theme'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDarkElevated : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Row(
                  children: [
                    _buildThemeTile(
                      context: context,
                      label: 'System',
                      icon: Icons.brightness_auto_rounded,
                      mode: ThemeMode.system,
                      currentMode: currentMode,
                    ),
                    _buildThemeTile(
                      context: context,
                      label: 'Light',
                      icon: Icons.light_mode_rounded,
                      mode: ThemeMode.light,
                      currentMode: currentMode,
                    ),
                    _buildThemeTile(
                      context: context,
                      label: 'Dark',
                      icon: Icons.dark_mode_rounded,
                      mode: ThemeMode.dark,
                      currentMode: currentMode,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 3. Storage & History
              _buildSectionTitle('Storage & Preferences'),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDarkElevated : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.toolAmberBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.cleaning_services_rounded, color: AppColors.amberWarm, size: 20),
                      ),
                      title: const Text('Clear File History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: const Text('Remove saved output records', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                      onTap: () async {
                        await StorageService().clearHistory();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('File history cleared')),
                          );
                        }
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.toolBlueBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.replay_rounded, color: AppColors.toolBlueIcon, size: 20),
                      ),
                      title: const Text('Review Onboarding Walkthrough', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: const Text('Tour PageLab core tools again', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 4. About App
              _buildSectionTitle('About PageLab'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDarkElevated : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('App Version', '1.0.0 (Build 2026)', isDark),
                    const Divider(height: 20),
                    _buildInfoRow('Privacy Mode', '100% Local / Offline', isDark, isHighlight: true),
                    const Divider(height: 20),
                    _buildInfoRow('Engine Architecture', 'Dart Vector & Canvas', isDark),
                  ],
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
      },
    );
  }

  Widget _buildThemeTile({
    required BuildContext context,
    required String label,
    required IconData icon,
    required ThemeMode mode,
    required ThemeMode currentMode,
  }) {
    final isSelected = currentMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => ThemeController().setThemeMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? Colors.white
                    : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String title, String value, bool isDark, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w500,
            color: isHighlight
                ? AppColors.sageGreen
                : (isDark ? AppColors.textMutedDark : AppColors.textMuted),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textMuted),
    );
  }
}
