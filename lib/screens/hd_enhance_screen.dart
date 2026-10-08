import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../theme/app_colors.dart';
import '../services/image_service.dart';
import '../services/storage_service.dart';
import '../services/file_picker_helper.dart';
import '../widgets/page_lab_app_bar.dart';
import '../widgets/before_after_slider.dart';
import '../widgets/tool_empty_state.dart';
import '../widgets/export_progress_dialog.dart';

class HdEnhanceScreen extends StatefulWidget {
  final Uint8List? initialImageBytes;

  const HdEnhanceScreen({super.key, this.initialImageBytes});

  @override
  State<HdEnhanceScreen> createState() => _HdEnhanceScreenState();
}

class _HdEnhanceScreenState extends State<HdEnhanceScreen> {
  Uint8List? _originalBytes;
  Uint8List? _enhancedBytes;
  img.Image? _decodedOriginal;
  img.Image? _decodedEnhanced;

  EnhancementLevel _selectedLevel = EnhancementLevel.hd;
  ImageOutputFormat _exportFormat = ImageOutputFormat.jpg;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialImageBytes != null) {
      _loadSource(widget.initialImageBytes!);
    }
  }

  void _loadSource(Uint8List bytes) {
    setState(() {
      _originalBytes = bytes;
      _decodedOriginal = ImageService().decode(bytes);
    });
    _applyEnhancement();
  }

  Future<void> _pickImage() async {
    final bytes = await FilePickerHelper.pickSingleImage();
    if (bytes != null) {
      _loadSource(bytes);
    }
  }

  void _applyEnhancement() {
    if (_decodedOriginal == null) return;

    setState(() => _isProcessing = true);

    Future.microtask(() {
      final enhanced = ImageService().enhanceImage(_decodedOriginal!, _selectedLevel);
      final bytes = ImageService().encode(enhanced, format: ImageOutputFormat.jpg, quality: 95);

      if (mounted) {
        setState(() {
          _decodedEnhanced = enhanced;
          _enhancedBytes = bytes;
          _isProcessing = false;
        });
      }
    });
  }

  Future<void> _export() async {
    if (_decodedEnhanced == null) return;

    final dialog = ExportProgressDialog(
      context,
      title: 'Exporting HD Photo',
      initialStatus: 'Encoding enhanced image...',
    );
    dialog.show();

    setState(() => _isProcessing = true);

    try {
      dialog.update(0.40, 'Encoding ${_exportFormat.name.toUpperCase()} format...');
      final bytes = ImageService().encode(
        _decodedEnhanced!,
        format: _exportFormat,
        quality: 95,
      );

      final ext = _exportFormat.name;
      final fileName = 'PageLab_HD_${_selectedLevel.name.toUpperCase()}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      dialog.update(0.85, 'Saving to device...');
      final item = await StorageService().saveFile(
        fileName: fileName,
        bytes: bytes,
        type: 'image',
        subtitle: '${_selectedLevel.name.toUpperCase()} Enhanced, ${_decodedEnhanced!.width} x ${_decodedEnhanced!.height}',
      );

      await dialog.complete('HD Photo Saved!');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enhanced photo saved: $fileName (${item.formattedSize})'),
          backgroundColor: AppColors.sageGreen,
          action: SnackBarAction(
            label: 'Open',
            textColor: Colors.white,
            onPressed: () => StorageService().openFile(item.filePath),
          ),
        ),
      );
    } catch (e) {
      dialog.dismiss();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: PageLabAppBar(
        title: 'HD Quality Enhancement',
        subtitle: _decodedEnhanced != null
            ? '${_decodedEnhanced!.width} × ${_decodedEnhanced!.height} px output'
            : null,
        actions: [
          if (_originalBytes != null) ...[
            IconButton(
              tooltip: 'Change image',
              icon: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDarkElevated : AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_library_outlined, size: 18),
              ),
              onPressed: _pickImage,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: _originalBytes == null
          ? ToolEmptyState(
              title: 'Select Photo to Enhance Quality',
              subtitle: 'Super-resolution sharpness, noise reduction, and contrast boost.',
              icon: Icons.high_quality_rounded,
              iconColor: AppColors.toolAmberIcon,
              iconBgColor: AppColors.toolAmberBg,
              buttonText: 'Select Image to Begin',
              onSelect: _pickImage,
            )
          : LayoutBuilder(
              builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 960;

          // Comparison slider widget
          final sliderWidget = Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _originalBytes != null && _enhancedBytes != null
                  ? BeforeAfterSlider(
                      beforeBytes: _originalBytes!,
                      afterBytes: _enhancedBytes!,
                      height: isDesktop ? 480 : 330,
                    )
                  : Container(
                      height: isDesktop ? 480 : 330,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardDarkElevated : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.touch_app_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Drag the center slider horizontally to compare',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          );

          // Controls & Options card
          final controlsCard = Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDarkElevated : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Enhancement Preset',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _selectedLevel.name.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _buildLevelCard('Standard', 'Subtle clarity', EnhancementLevel.standard),
                    const SizedBox(width: 8),
                    _buildLevelCard('HD', 'Sharpen & tones', EnhancementLevel.hd),
                    const SizedBox(width: 8),
                    _buildLevelCard('Ultra HD', 'Max sharpness', EnhancementLevel.ultraHd),
                  ],
                ),
                const Divider(height: 28),
                Text(
                  'Export Format',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildFormatSegment('JPG', 'Crisp photo', ImageOutputFormat.jpg),
                    const SizedBox(width: 8),
                    _buildFormatSegment('PNG', 'Lossless detail', ImageOutputFormat.png),
                    const SizedBox(width: 8),
                    _buildFormatSegment('WebP', 'Modern web', ImageOutputFormat.webp),
                  ],
                ),
              ],
            ),
          );

          // Save / Export button
          final exportButton = SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _export,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 3,
                shadowColor: AppColors.primary.withValues(alpha: 0.35),
              ),
              child: _isProcessing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        ),
                        SizedBox(width: 14),
                        Text('Enhancing...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Export Enhanced Image',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          );

          if (isDesktop) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: Interactive Before/After Split Canvas
                      Expanded(
                        flex: 6,
                        child: SingleChildScrollView(
                          child: sliderWidget,
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Right Column: Presets & Export Actions
                      SizedBox(
                        width: 440,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              controlsCard,
                              const SizedBox(height: 20),
                              exportButton,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // Mobile / Tablet single column layout
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    sliderWidget,
                    const SizedBox(height: 20),
                    controlsCard,
                    const SizedBox(height: 20),
                    exportButton,
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLevelCard(String label, String hint, EnhancementLevel level) {
    final isSelected = _selectedLevel == level;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedLevel = level);
          _applyEnhancement();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryContainer
                : (isDark ? AppColors.cardDark : AppColors.surfaceMuted),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                  color: isSelected ? AppColors.primary : null,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? AppColors.primary : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormatSegment(String label, String hint, ImageOutputFormat format) {
    final isSelected = _exportFormat == format;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _exportFormat = format),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryContainer
                : (isDark ? AppColors.cardDark : AppColors.surfaceMuted),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                  color: isSelected ? AppColors.primary : null,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hint,
                style: TextStyle(
                  fontSize: 9,
                  color: isSelected ? AppColors.primary : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
