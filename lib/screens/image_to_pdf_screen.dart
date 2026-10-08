import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import '../theme/app_colors.dart';
import '../services/pdf_service.dart';
import '../services/storage_service.dart';
import '../services/file_picker_helper.dart';
import '../widgets/page_lab_app_bar.dart';
import '../widgets/tool_empty_state.dart';
import '../widgets/export_progress_dialog.dart';

class ImageToPdfScreen extends StatefulWidget {
  final List<Uint8List>? initialImages;

  const ImageToPdfScreen({super.key, this.initialImages});

  @override
  State<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends State<ImageToPdfScreen> {
  final List<Uint8List> _images = [];

  String _pageSize = 'A4 (Recommended)';
  bool _isLandscape = false;
  PageMarginSetting _margin = PageMarginSetting.none;
  bool _highDpiMode = true;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialImages != null && widget.initialImages!.isNotEmpty) {
      _images.addAll(widget.initialImages!);
    }
  }

  Future<void> _pickImages() async {
    final picked = await FilePickerHelper.pickMultipleImages();
    if (picked.isNotEmpty) {
      setState(() {
        _images.addAll(picked);
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  Future<void> _generatePdf() async {
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one image.')),
      );
      return;
    }

    final dialog = ExportProgressDialog(
      context,
      title: 'Creating PDF',
      initialStatus: 'Preparing images...',
    );
    dialog.show();

    setState(() => _isGenerating = true);

    try {
      dialog.update(0.20, 'Configuring layout & pages...');
      PdfPageFormat format = PdfPageFormat.a4;
      bool fitToImage = false;

      if (_pageSize.contains('Letter')) {
        format = PdfPageFormat.letter;
      } else if (_pageSize.contains('Legal')) {
        format = PdfPageFormat.legal;
      } else if (_pageSize.contains('Fit to Image')) {
        fitToImage = true;
      }

      dialog.update(0.60, 'Rendering PDF pages...');
      final pdfBytes = await PdfService().createPdfFromImages(
        images: _images,
        pageFormat: format,
        isLandscape: _isLandscape,
        marginSetting: _margin,
        jpegQuality: _highDpiMode ? 95 : 80,
        fitToImage: fitToImage,
      );

      dialog.update(0.88, 'Saving document...');
      final fileName = 'PageLab_Doc_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final item = await StorageService().saveFile(
        fileName: fileName,
        bytes: pdfBytes,
        type: 'pdf',
        subtitle: '${_images.length} pages, ${_pageSize.split(' ').first}',
      );

      await dialog.complete('PDF Created!');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Created: $fileName (${item.formattedSize})'),
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
        SnackBar(content: Text('Error creating PDF: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: PageLabAppBar(
        title: 'Images to PDF',
        subtitle: _images.isNotEmpty ? '${_images.length} ${_images.length == 1 ? "page" : "pages"} ready' : null,
        actions: [
          if (_images.isNotEmpty) ...[
            IconButton(
              tooltip: 'Add images',
              icon: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDarkElevated : AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              ),
              onPressed: _pickImages,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: _images.isEmpty
          ? ToolEmptyState(
              title: 'Select Images to Convert to PDF',
              subtitle: 'Select one or more images to combine into an elegant, print-ready PDF document.',
              icon: Icons.picture_as_pdf_outlined,
              iconColor: AppColors.toolRedIcon,
              iconBgColor: AppColors.toolRedBg,
              buttonText: 'Select Images to Begin',
              onSelect: _pickImages,
            )
          : LayoutBuilder(
              builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 960;

          final gridSection = Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _images.length + 1,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 180,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.88,
              ),
              itemBuilder: (context, index) {
                  if (index == _images.length) {
                    return InkWell(
                      onTap: _pickImages,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.cardDarkElevated : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add_rounded, size: 22, color: AppColors.primary),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '+ Add Images',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final bytes = _images[index];
                  return Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(17),
                          child: Image.memory(
                            bytes,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),

                      // Page number tag
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white24, width: 0.6),
                          ),
                          child: Text(
                            'Page ${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),

                      // Delete 'x' badge
                      Positioned(
                        top: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white30, width: 0.8),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );

            // 2. Page Options Configuration Card (Mockup Screen 5)
            final optionsCard = Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDarkElevated : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.025),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Page Size Dropdown
                    Text(
                      'Page Size',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardDark : AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _pageSize,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          items: const [
                            DropdownMenuItem(
                              value: 'A4 (Recommended)',
                              child: Text('A4 (Recommended) - 210 x 297 mm', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                            DropdownMenuItem(
                              value: 'US Letter',
                              child: Text('US Letter - 8.5 x 11 in', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                            DropdownMenuItem(
                              value: 'Legal',
                              child: Text('Legal - 8.5 x 14 in', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                            DropdownMenuItem(
                              value: 'Fit to Image',
                              child: Text('Fit to Image Dimensions', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _pageSize = val);
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Orientation Selector
                    Text(
                      'Orientation',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildOrientationSegment('Portrait', Icons.stay_current_portrait_rounded, !_isLandscape),
                        const SizedBox(width: 10),
                        _buildOrientationSegment('Landscape', Icons.stay_current_landscape_rounded, _isLandscape),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Page Margin
                    Text(
                      'Page Margin',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildMarginChip('None', PageMarginSetting.none),
                        _buildMarginChip('Small', PageMarginSetting.small),
                        _buildMarginChip('Medium', PageMarginSetting.medium),
                        _buildMarginChip('Large', PageMarginSetting.large),
                      ],
                    ),

                    const Divider(height: 28),

                    // HD PDF Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'High-Resolution HD PDF',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Preserve crisp detail without unnecessary compression',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                        Switch(
                          value: _highDpiMode,
                          activeTrackColor: AppColors.primary,
                          onChanged: (v) => setState(() => _highDpiMode = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );

            // 3. Primary Create PDF Action Button
            final actionButton = Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isGenerating ? null : _generatePdf,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 3,
                    shadowColor: AppColors.primary.withValues(alpha: 0.35),
                  ),
                  child: _isGenerating
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            ),
                            SizedBox(width: 14),
                            Text('Generating PDF...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              'Create PDF (${_images.length} ${_images.length == 1 ? "page" : "pages"})',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            );

            if (isDesktop) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1300),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Responsive Images Grid
                        Expanded(
                          flex: 6,
                          child: SingleChildScrollView(
                            child: gridSection,
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Right Column: Options Card & Action Button
                        SizedBox(
                          width: 440,
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                optionsCard,
                                actionButton,
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

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      gridSection,
                      optionsCard,
                      actionButton,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

  Widget _buildOrientationSegment(String label, IconData icon, bool isSelected) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isLandscape = (label == 'Landscape')),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 19,
                color: isSelected ? AppColors.primary : (isDark ? AppColors.textMutedDark : AppColors.textMuted),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                  color: isSelected ? AppColors.primary : (isDark ? AppColors.textLight : AppColors.textDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarginChip(String label, PageMarginSetting marginSetting) {
    final isSelected = _margin == marginSetting;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: GestureDetector(
          onTap: () => setState(() => _margin = marginSetting),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryContainer
                  : (isDark ? AppColors.cardDark : AppColors.surfaceMuted),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppColors.primary : (isDark ? AppColors.textLight : AppColors.textDark),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
