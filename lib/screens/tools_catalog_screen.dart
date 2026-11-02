import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'crop_resize_screen.dart';
import 'bulk_resize_screen.dart';
import 'hd_enhance_screen.dart';
import 'passport_photo_screen.dart';
import 'format_converter_screen.dart';
import 'bg_remover_screen.dart';

class ToolsCatalogScreen extends StatefulWidget {
  const ToolsCatalogScreen({super.key});

  @override
  State<ToolsCatalogScreen> createState() => _ToolsCatalogScreenState();
}

class _ToolsCatalogScreenState extends State<ToolsCatalogScreen> {
  String _categoryFilter = 'All';
  String _search = '';

  final List<_ToolItem> _allTools = [
    _ToolItem(
      title: 'Passport Size Photo',
      category: 'Passport & Portrait',
      description: 'India, US, UK, Schengen & custom sizes with printable sheets',
      icon: Icons.account_box_rounded,
      color: AppColors.toolRedIcon,
      bgColor: AppColors.toolRedBg,
      builder: (_) => const PassportPhotoScreen(),
    ),
    _ToolItem(
      title: 'AI Background Remover',
      category: 'Passport & Portrait',
      description: '100% Free offline portrait cutout, white & blue background changer',
      icon: Icons.auto_awesome_rounded,
      color: AppColors.sageGreen,
      bgColor: AppColors.toolGreenBg,
      builder: (_) => const BgRemoverScreen(),
    ),
    _ToolItem(
      title: 'HD Quality Enhancement',
      category: 'Passport & Portrait',
      description: 'Sharpness enhancement, detail boost and interactive split comparison',
      icon: Icons.high_quality_rounded,
      color: AppColors.toolAmberIcon,
      bgColor: AppColors.toolAmberBg,
      builder: (_) => const HdEnhanceScreen(),
    ),
    _ToolItem(
      title: 'Image Cropping & Resizing',
      category: 'Image Editing',
      description: 'Free crop, 1:1, 4:3, 16:9, rotate, flip and custom dimensions',
      icon: Icons.crop_rounded,
      color: AppColors.toolOrangeIcon,
      bgColor: AppColors.toolOrangeBg,
      builder: (_) => const CropResizeScreen(),
    ),
    _ToolItem(
      title: 'Bulk Image Resize',
      category: 'Image Editing',
      description: 'Resize 10s or 100s of images at once by px or percentage',
      icon: Icons.filter_none_rounded,
      color: AppColors.sageGreen,
      bgColor: AppColors.toolGreenBg,
      builder: (_) => const BulkResizeScreen(),
    ),
    _ToolItem(
      title: 'Format Converter',
      category: 'Image Editing',
      description: 'Convert between JPG, PNG and WebP formats instantly',
      icon: Icons.swap_horiz_rounded,
      color: AppColors.toolPurpleIcon,
      bgColor: AppColors.toolPurpleBg,
      builder: (_) => const FormatConverterScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtered = _allTools.where((tool) {
      if (_categoryFilter != 'All' && tool.category != _categoryFilter) {
        return false;
      }
      if (_search.isNotEmpty &&
          !tool.title.toLowerCase().contains(_search.toLowerCase()) &&
          !tool.description.toLowerCase().contains(_search.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 18,
        title: const Text(
          'Tools Catalog',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.3),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;
          final isDesktop = constraints.maxWidth >= 1024;
          final horizontalPadding = isDesktop ? 32.0 : (isWide ? 24.0 : 16.0);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Search tools (e.g. passport, cutout, crop, enhance)...',
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                            suffixIcon: _search.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () => setState(() => _search = ''),
                                  )
                                : null,
                          ),
                          onChanged: (val) => setState(() => _search = val),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildCategoryChip('All'),
                              _buildCategoryChip('Passport & Portrait'),
                              _buildCategoryChip('Image Editing'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
                                const SizedBox(height: 12),
                                Text(
                                  'No tools found for "$_search"',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding,
                              vertical: 12,
                            ),
                            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: isWide ? 520 : 600,
                              mainAxisExtent: 88,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final tool = filtered[index];
                              return Container(
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.cardDarkElevated : Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.02),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(18),
                                  child: ListTile(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 4,
                                    ),
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(builder: tool.builder),
                                    ),
                                    leading: Container(
                                      padding: const EdgeInsets.all(9),
                                      decoration: BoxDecoration(
                                        color: isDark ? tool.color.withValues(alpha: 0.2) : tool.bgColor,
                                        borderRadius: BorderRadius.circular(13),
                                      ),
                                      child: Icon(tool.icon, color: tool.color, size: 24),
                                    ),
                                    title: Text(
                                      tool.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        tool.description,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                    trailing: const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryChip(String label) {
    final isSelected = _categoryFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primaryContainer,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? AppColors.primary : null,
        ),
        onSelected: (_) => setState(() => _categoryFilter = label),
      ),
    );
  }
}

class _ToolItem {
  final String title;
  final String category;
  final String description;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final WidgetBuilder builder;

  _ToolItem({
    required this.title,
    required this.category,
    required this.description,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.builder,
  });
}
