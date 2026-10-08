import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/storage_service.dart';
import 'crop_resize_screen.dart';
import 'bulk_resize_screen.dart';
import 'hd_enhance_screen.dart';
import 'image_to_pdf_screen.dart';
import 'pdf_to_image_screen.dart';
import 'compress_pdf_screen.dart';
import 'passport_photo_screen.dart';
import 'format_converter_screen.dart';
import 'merge_pdf_screen.dart';
import 'split_pdf_screen.dart';
import 'bg_remover_screen.dart';
import 'sign_pdf_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onNavigateToFiles;
  final VoidCallback onNavigateToTools;

  const HomeScreen({
    super.key,
    required this.onNavigateToFiles,
    required this.onNavigateToTools,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 18,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryLight, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.layers_rounded, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'PageLab',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: isDark ? AppColors.textLight : AppColors.textDark,
                  ),
                ),
                Text(
                  'Offline Image & PDF Suite',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'All Tools Catalog',
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDarkElevated : AppColors.surfaceMuted,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  width: 0.8,
                ),
              ),
              child: const Icon(Icons.search_rounded, size: 18),
            ),
            onPressed: onNavigateToTools,
          ),
          IconButton(
            tooltip: 'Settings & Storage',
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDarkElevated : AppColors.surfaceMuted,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  width: 0.8,
                ),
              ),
              child: const Icon(Icons.settings_outlined, size: 18),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isWide = width >= 720;
          final isDesktop = width >= 1024;
          final horizontalPadding = isDesktop ? 32.0 : (isWide ? 24.0 : 16.0);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Recent Files Strip (if any)
                    _buildRecentFilesSection(context, isDark),

                    // 2. Featured Passport Photo Hero Banner (Prominently at the top!)
                    _buildFeaturedPassportCard(context, isDark, isWide),
                    const SizedBox(height: 24),

                    // 3. Photo & Image Tools (6 tools)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitle('Photo & Image Tools'),
                        Text(
                          '6 Tools',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: isDesktop ? 360 : (isWide ? 420 : 600),
                        mainAxisExtent: 84,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      children: [
                        _buildToolCard(
                          context: context,
                          title: 'Passport Photo',
                          subtitle: 'Visa, ID & A4 sheet',
                          icon: Icons.account_box_rounded,
                          iconColor: AppColors.toolRedIcon,
                          bgColor: AppColors.toolRedBg,
                          badge: 'Popular',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const PassportPhotoScreen()),
                          ),
                        ),
                        _buildToolCard(
                          context: context,
                          title: 'AI BG Remover',
                          subtitle: '1-click cutout & colors',
                          icon: Icons.auto_awesome_rounded,
                          iconColor: AppColors.sageGreen,
                          bgColor: AppColors.toolGreenBg,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const BgRemoverScreen()),
                          ),
                        ),
                        _buildToolCard(
                          context: context,
                          title: 'Crop & Resize',
                          subtitle: 'Aspect ratio, rotate & flip',
                          icon: Icons.crop_rotate_rounded,
                          iconColor: AppColors.toolOrangeIcon,
                          bgColor: AppColors.toolOrangeBg,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const CropResizeScreen()),
                          ),
                        ),
                        _buildToolCard(
                          context: context,
                          title: 'HD Enhance',
                          subtitle: 'Sharpness & denoise',
                          icon: Icons.high_quality_rounded,
                          iconColor: AppColors.toolAmberIcon,
                          bgColor: AppColors.toolAmberBg,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const HdEnhanceScreen()),
                          ),
                        ),
                        _buildToolCard(
                          context: context,
                          title: 'Format Converter',
                          subtitle: 'JPG, PNG & WebP',
                          icon: Icons.swap_horiz_rounded,
                          iconColor: AppColors.toolPurpleIcon,
                          bgColor: AppColors.toolPurpleBg,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const FormatConverterScreen()),
                          ),
                        ),
                        _buildToolCard(
                          context: context,
                          title: 'Bulk Resize',
                          subtitle: 'Batch process multiple',
                          icon: Icons.filter_none_rounded,
                          iconColor: AppColors.sageGreen,
                          bgColor: AppColors.toolGreenBg,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const BulkResizeScreen()),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // 4. PDF Studio Tools (6 tools)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitle('PDF Tools'),
                        Text(
                          '6 Tools',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: isDesktop ? 360 : (isWide ? 420 : 600),
                        mainAxisExtent: 84,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      children: [
                        _buildToolCard(
                          context: context,
                          title: 'Image to PDF',
                          subtitle: 'Photos to A4/Letter PDF',
                          icon: Icons.picture_as_pdf_outlined,
                          iconColor: AppColors.toolRedIcon,
                          bgColor: AppColors.toolRedBg,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ImageToPdfScreen()),
                          ),
                        ),
                        _buildToolCard(
                          context: context,
                          title: 'PDF to Image',
                          subtitle: 'Extract crisp JPG / PNG',
                          icon: Icons.image_outlined,
                          iconColor: AppColors.toolBlueIcon,
                          bgColor: AppColors.toolBlueBg,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const PdfToImageScreen()),
                          ),
                        ),
                        _buildToolCard(
                          context: context,
                          title: 'Compress PDF',
                          subtitle: 'Reduce size, keep crisp',
                          icon: Icons.compress_rounded,
                          iconColor: AppColors.toolPurpleIcon,
                          bgColor: AppColors.toolPurpleBg,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const CompressPdfScreen()),
                          ),
                        ),
                        _buildToolCard(
                          context: context,
                          title: 'Merge PDF',
                          subtitle: 'Combine multiple documents',
                          icon: Icons.call_merge_rounded,
                          iconColor: AppColors.toolRedIcon,
                          bgColor: AppColors.toolRedBg,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const MergePdfScreen()),
                          ),
                        ),
                        _buildToolCard(
                          context: context,
                          title: 'Split PDF',
                          subtitle: 'Extract specific pages',
                          icon: Icons.call_split_rounded,
                          iconColor: AppColors.slateBlue,
                          bgColor: AppColors.slateBlueContainer,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SplitPdfScreen()),
                          ),
                        ),
                        _buildToolCard(
                          context: context,
                          title: 'Bulk to PDF',
                          subtitle: 'Multi-image booklet',
                          icon: Icons.collections_bookmark_rounded,
                          iconColor: AppColors.toolOrangeIcon,
                          bgColor: AppColors.toolOrangeBg,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ImageToPdfScreen()),
                          ),
                        ),
                        _buildToolCard(
                          context: context,
                          title: 'Sign PDF',
                          subtitle: 'Draw, type, or stamp sign',
                          icon: Icons.draw_rounded,
                          iconColor: AppColors.primary,
                          bgColor: AppColors.primaryContainer,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SignPdfScreen()),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // Privacy Note
                    Center(child: _buildPrivacyFooter(isDark)),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Featured Hero Banner for Passport Size Photo Studio
  Widget _buildFeaturedPassportCard(BuildContext context, bool isDark, bool isWide) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF2E221B), const Color(0xFF221E29)]
              : [const Color(0xFFFFF6F0), const Color(0xFFFBF1E6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PassportPhotoScreen()),
          ),
          child: Padding(
            padding: EdgeInsets.all(isWide ? 22 : 18),
            child: isWide
                ? Row(
                    children: [
                      Expanded(
                        child: _buildFeaturedPassportDetails(context, isDark),
                      ),
                      const SizedBox(width: 24),
                      _buildFeaturedPassportAction(isDark),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFeaturedPassportDetails(context, isDark),
                      const SizedBox(height: 16),
                      _buildFeaturedPassportAction(isDark, fullWidth: true),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedPassportDetails(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, color: Colors.white, size: 12),
                  SizedBox(width: 4),
                  Text(
                    'FEATURED STUDIO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.toolRedBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.toolRedIcon.withValues(alpha: 0.2),
                ),
              ),
              child: const Icon(
                Icons.badge_rounded,
                color: AppColors.toolRedIcon,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Passport Size Photo Studio',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: isDark ? AppColors.textLight : AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Official country presets, automatic background changer & printable A4 sheets',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildPresetChip('India 35 x 45 mm', isDark),
            _buildPresetChip('US 2 x 2 in', isDark),
            _buildPresetChip('UK 35 x 45 mm', isDark),
            _buildPresetChip('Schengen', isDark),
            _buildPresetChip('Custom cm / mm', isDark),
            _buildPresetChip('A4 Sheet Grid', isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildPresetChip(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardDarkElevated.withValues(alpha: 0.9)
            : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? AppColors.borderDark
              : AppColors.borderLight.withValues(alpha: 0.9),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.textLight : AppColors.textDark,
        ),
      ),
    );
  }

  Widget _buildFeaturedPassportAction(bool isDark, {bool fullWidth = false}) {
    final buttonChild = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Create Photo',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          SizedBox(width: 6),
          Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
        ],
      ),
    );

    if (fullWidth) {
      return SizedBox(
        width: double.infinity,
        child: buttonChild,
      );
    }
    return buttonChild;
  }

  Widget _buildRecentFilesSection(BuildContext context, bool isDark) {
    return AnimatedBuilder(
      animation: StorageService(),
      builder: (context, _) {
        final history = StorageService().history;
        if (history.isEmpty) return const SizedBox.shrink();

        final recentFiles = history.take(6).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle('Recent Outputs'),
                TextButton(
                  onPressed: onNavigateToFiles,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.primary,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('View All', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 16),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 68,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: recentFiles.length,
                itemBuilder: (context, index) {
                  final item = recentFiles[index];

                  return GestureDetector(
                    onTap: () => StorageService().openFile(item.filePath),
                    child: Container(
                      width: 155,
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardDarkElevated : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: item.type == 'pdf' ? AppColors.toolRedBg : AppColors.toolBlueBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              item.type == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                              size: 18,
                              color: item.type == 'pdf' ? AppColors.toolRedIcon : AppColors.toolBlueIcon,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
          ],
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildToolCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
    String? badge,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDarkElevated : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          hoverColor: AppColors.primary.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark ? iconColor.withValues(alpha: 0.18) : bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: isDark ? AppColors.textLight : AppColors.textDark,
                              ),
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badge,
                                style: const TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 11,
                  color: (isDark ? AppColors.textMutedDark : AppColors.textMuted).withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyFooter(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardDarkElevated.withValues(alpha: 0.6)
            : AppColors.surfaceMuted.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline_rounded, size: 15, color: AppColors.sageGreen),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Your files and photos are always on your device, not on our cloud.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
