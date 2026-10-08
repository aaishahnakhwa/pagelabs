import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../theme/app_colors.dart';
import '../services/image_service.dart';
import '../services/storage_service.dart';
import '../services/file_picker_helper.dart';
import '../widgets/page_lab_app_bar.dart';
import '../widgets/tool_empty_state.dart';
import '../widgets/export_progress_dialog.dart';

class BulkResizeScreen extends StatefulWidget {
  final List<Uint8List>? initialImages;

  const BulkResizeScreen({super.key, this.initialImages});

  @override
  State<BulkResizeScreen> createState() => _BulkResizeScreenState();
}

class _BulkResizeScreenState extends State<BulkResizeScreen> {
  final List<Uint8List> _images = [];
  final Set<int> _selectedIndices = {};

  final TextEditingController _widthController = TextEditingController(text: '1080');
  final TextEditingController _heightController = TextEditingController(text: '1080');
  bool _keepAspectRatio = true;

  double? _percentageScale; // null if by dimensions
  ImageOutputFormat _outputFormat = ImageOutputFormat.jpg;
  double _quality = 85;

  bool _isProcessing = false;
  double _processingProgress = 0.0;
  int _processedCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialImages != null && widget.initialImages!.isNotEmpty) {
      _images.addAll(widget.initialImages!);
      _selectedIndices.addAll(List.generate(_images.length, (i) => i));
    }
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await FilePickerHelper.pickMultipleImages();
    if (picked.isNotEmpty) {
      setState(() {
        for (final bytes in picked) {
          _images.add(bytes);
          _selectedIndices.add(_images.length - 1);
        }
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
      final newSelected = <int>{};
      for (final sel in _selectedIndices) {
        if (sel < index) {
          newSelected.add(sel);
        } else if (sel > index) {
          newSelected.add(sel - 1);
        }
      }
      _selectedIndices
        ..clear()
        ..addAll(newSelected);
      if (_selectedIndices.isEmpty && _images.isNotEmpty) {
        _selectedIndices.add(0);
      }
    });
  }

  void _toggleSelect(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        if (_selectedIndices.length > 1) {
          _selectedIndices.remove(index);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('At least one image must remain selected.')),
          );
        }
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIndices.clear();
      _selectedIndices.addAll(List.generate(_images.length, (i) => i));
    });
  }

  void _applyDimensionPreset(int width, int height) {
    setState(() {
      _percentageScale = null;
      _widthController.text = width.toString();
      _heightController.text = height.toString();
    });
  }

  Future<void> _processBulk() async {
    if (_selectedIndices.isEmpty) return;

    final total = _selectedIndices.length;
    final dialog = ExportProgressDialog(
      context,
      title: 'Bulk Resizing',
      initialStatus: 'Processing 0 of $total images...',
      autoAnimate: false,
    );
    dialog.show();

    setState(() {
      _isProcessing = true;
      _processingProgress = 0.0;
      _processedCount = 0;
    });

    final targetW = int.tryParse(_widthController.text) ?? 1080;
    final targetH = int.tryParse(_heightController.text) ?? 1080;
    int successCount = 0;

    try {
      for (final index in _selectedIndices) {
        try {
          final raw = _images[index];
          final decoded = ImageService().decode(raw);
          if (decoded != null) {
            img.Image resized;
            if (_percentageScale != null) {
              resized = ImageService().resizeByPercentage(
                src: decoded,
                percentage: _percentageScale!,
              );
            } else {
              resized = ImageService().resizeImage(
                src: decoded,
                width: targetW,
                height: targetH,
                maintainAspect: _keepAspectRatio,
              );
            }

            final encoded = ImageService().encode(
              resized,
              format: _outputFormat,
              quality: _quality.round(),
            );

            final ext = _outputFormat.name;
            final fileName = 'Bulk_${resized.width}x${resized.height}_${DateTime.now().millisecondsSinceEpoch}_$index.$ext';
            await StorageService().saveFile(
              fileName: fileName,
              bytes: encoded,
              type: 'image',
              subtitle: 'Bulk Resized (${resized.width} × ${resized.height})',
            );
            successCount++;
          }
        } catch (e) {
          debugPrint('Error processing image at $index: $e');
        }

        _processedCount++;
        final currentProgress = _processedCount / total;
        dialog.update(currentProgress, 'Processed $_processedCount of $total images');
        setState(() {
          _processingProgress = currentProgress;
        });
      }

      await dialog.complete('Resized $successCount images!');
    } catch (e) {
      dialog.dismiss();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Successfully resized $successCount ${_selectedIndices.length == 1 ? "image" : "images"}!'),
        backgroundColor: AppColors.sageGreen,
        action: SnackBarAction(
          label: 'View Files',
          textColor: Colors.white,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: PageLabAppBar(
        title: 'Bulk Resize',
        subtitle: _images.isNotEmpty ? '${_selectedIndices.length} of ${_images.length} images selected' : null,
        actions: [
          if (_images.isNotEmpty)
            IconButton(
              tooltip: 'Add images',
              icon: const Icon(Icons.add_photo_alternate_outlined),
              onPressed: _pickImages,
            ),
        ],
      ),
      body: _images.isEmpty
          ? ToolEmptyState(
              title: 'Select Images to Bulk Resize',
              subtitle: 'Batch resize, compress, and rename multiple images simultaneously.',
              icon: Icons.filter_none_rounded,
              iconColor: AppColors.sageGreen,
              iconBgColor: AppColors.toolGreenBg,
              buttonText: 'Select Images to Begin',
              onSelect: _pickImages,
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Batch Selection Header Row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_selectedIndices.length} selected',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tap cards to toggle',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _selectAll,
                        icon: const Icon(Icons.done_all_rounded, size: 16),
                        label: const Text('Select All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 1. Horizontal multi-image strip with checkmarks & remove buttons
            SizedBox(
              height: 124,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _images.length + 1,
                itemBuilder: (context, index) {
                  if (index == _images.length) {
                    return GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        width: 90,
                        margin: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.cardDarkElevated : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            width: 1.5,
                            strokeAlign: BorderSide.strokeAlignInside,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppColors.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add_rounded, size: 24, color: AppColors.primary),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Add More',
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

                  final isSelected = _selectedIndices.contains(index);
                  return GestureDetector(
                    onTap: () => _toggleSelect(index),
                    child: Container(
                      width: 94,
                      margin: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardDarkElevated : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : (isDark ? AppColors.borderDark : AppColors.borderLight),
                          width: isSelected ? 2.5 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.memory(
                              _images[index],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                          // Subtle dark overlay if unselected
                          if (!isSelected)
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: Colors.black.withValues(alpha: 0.35),
                              ),
                            ),
                          // Selection badge top-right
                          Positioned(
                            top: 6,
                            right: 6,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : Colors.black45,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isSelected ? Icons.check : Icons.circle_outlined,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          // Index label bottom-left
                          Positioned(
                            bottom: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '#${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          // Delete button top-left
                          Positioned(
                            top: 6,
                            left: 6,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // 2. Preset Dimensions Pills
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Dimension Presets',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Quick Match',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPresetChip('Square 1:1', 1080, 1080),
                        _buildPresetChip('Full HD 16:9', 1920, 1080),
                        _buildPresetChip('Story 9:16', 1080, 1920),
                        _buildPresetChip('Standard 4:3', 1024, 768),
                        _buildPresetChip('Web 800×600', 800, 600),
                        _buildPresetChip('Thumb 400', 400, 400),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 3. Resize Configuration Card (Exact Dimensions + Aspect Ratio)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDarkElevated : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
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
                          'Target Dimensions',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        if (_percentageScale != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Scale: ${(_percentageScale! * 100).round()}%',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Dimensions input
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _widthController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Width',
                              suffixText: 'px',
                              prefixIcon: Icon(Icons.swap_horiz_rounded, size: 20),
                            ),
                            onTap: () => setState(() => _percentageScale = null),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text('×', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.grey)),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _heightController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Height',
                              suffixText: 'px',
                              prefixIcon: Icon(Icons.swap_vert_rounded, size: 20),
                            ),
                            onTap: () => setState(() => _percentageScale = null),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Keep aspect ratio toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Keep aspect ratio',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.textLight : AppColors.textDark,
                              ),
                            ),
                            Text(
                              'Scale proportionally to prevent distortion',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _keepAspectRatio,
                          activeTrackColor: AppColors.primary,
                          onChanged: (val) => setState(() => _keepAspectRatio = val),
                        ),
                      ],
                    ),

                    const Divider(height: 24),

                    // Percentage Scale quick options
                    Text(
                      'Or Scale by Percentage',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildPercentChip('25%', 0.25),
                        _buildPercentChip('50%', 0.50),
                        _buildPercentChip('75%', 0.75),
                        _buildPercentChip('150%', 1.50),
                        _buildPercentChip('200%', 2.00),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 4. Format & Quality Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDarkElevated : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Output Format',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildFormatRadio('JPG', 'Smaller Size', ImageOutputFormat.jpg),
                        _buildFormatRadio('PNG', 'Lossless Sharp', ImageOutputFormat.png),
                        _buildFormatRadio('WebP', 'Modern Web', ImageOutputFormat.webp),
                      ],
                    ),
                    if (_outputFormat != ImageOutputFormat.png) ...[
                      const Divider(height: 26),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Quality Compression',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_quality.round()}%',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _quality,
                        min: 50,
                        max: 100,
                        divisions: 10,
                        activeColor: AppColors.primary,
                        inactiveColor: isDark ? AppColors.borderDark : AppColors.borderLight,
                        onChanged: (val) => setState(() => _quality = val),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if (_isProcessing) ...[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _processingProgress,
                        minHeight: 10,
                        backgroundColor: isDark ? AppColors.cardDarkElevated : Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Processing $_processedCount of ${_selectedIndices.length} images...',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],

            // 5. Process Images Button
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processBulk,
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
                            Text('Batch Resizing...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              'Resize ${_selectedIndices.length} ${_selectedIndices.length == 1 ? "Image" : "Images"}',
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
            ),
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _buildPresetChip(String label, int width, int height) {
    final currentW = int.tryParse(_widthController.text);
    final currentH = int.tryParse(_heightController.text);
    final isSelected = _percentageScale == null && currentW == width && currentH == height;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => _applyDimensionPreset(width, height),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.cardDarkElevated : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : (isDark ? AppColors.borderDark : AppColors.borderLight),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : (isDark ? AppColors.textLight : AppColors.textDark),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPercentChip(String label, double scale) {
    final isSelected = _percentageScale == scale;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _percentageScale = null;
              } else {
                _percentageScale = scale;
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? AppColors.cardDark : AppColors.surfaceMuted),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 12,
                color: isSelected ? Colors.white : (isDark ? AppColors.textLight : AppColors.textDark),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormatRadio(String label, String subtitle, ImageOutputFormat format) {
    final isSelected = _outputFormat == format;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _outputFormat = format),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryContainer
                : (isDark ? AppColors.cardDark : Colors.transparent),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.primary : (isDark ? AppColors.borderDark : AppColors.borderLight),
              width: isSelected ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: isSelected ? AppColors.primary : (isDark ? AppColors.textLight : AppColors.textDark),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.8)
                      : (isDark ? AppColors.textMutedDark : AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
