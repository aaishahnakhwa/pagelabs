import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/file_picker_helper.dart';
import '../theme/app_colors.dart';
import '../services/image_service.dart';
import '../services/storage_service.dart';
import '../widgets/page_lab_app_bar.dart';
import '../widgets/tool_empty_state.dart';
import '../widgets/export_progress_dialog.dart';

class FormatConverterScreen extends StatefulWidget {
  final Uint8List? initialImageBytes;
  const FormatConverterScreen({super.key, this.initialImageBytes});

  @override
  State<FormatConverterScreen> createState() => _FormatConverterScreenState();
}

class _FormatConverterScreenState extends State<FormatConverterScreen> {
  Uint8List? _sourceBytes;
  String _sourceFormat = 'JPG';
  ImageOutputFormat _targetFormat = ImageOutputFormat.png;
  final double _quality = 90;
  bool _isConverting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialImageBytes != null) {
      _sourceBytes = widget.initialImageBytes;
    }
  }

  Future<void> _pickImage() async {
    final bytes = await FilePickerHelper.pickSingleImage();
    if (bytes != null) {
      setState(() {
        _sourceBytes = bytes;
        _sourceFormat = 'IMG';
      });
    }
  }

  Future<void> _convert() async {
    if (_sourceBytes == null) return;

    final dialog = ExportProgressDialog(
      context,
      title: 'Converting Image',
      initialStatus: 'Decoding image...',
    );
    dialog.show();

    setState(() => _isConverting = true);

    try {
      dialog.update(0.25, 'Decoding image data...');
      final decoded = ImageService().decode(_sourceBytes!);
      if (decoded == null) throw Exception('Could not decode image');

      final ext = _targetFormat.name;
      dialog.update(0.65, 'Encoding to ${ext.toUpperCase()}...');
      final convertedBytes = ImageService().encode(
        decoded,
        format: _targetFormat,
        quality: _quality.round(),
      );

      dialog.update(0.88, 'Saving converted file...');
      final fileName = 'Converted_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final item = await StorageService().saveFile(
        fileName: fileName,
        bytes: convertedBytes,
        type: 'image',
        subtitle: 'Converted to ${ext.toUpperCase()}',
      );

      await dialog.complete('Image Converted!');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved: $fileName (${item.formattedSize})'),
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
        SnackBar(content: Text('Conversion failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isConverting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: PageLabAppBar(
        title: 'Format Converter',
        subtitle: 'JPG, PNG, WebP',
        actions: [
          if (_sourceBytes != null) ...[
            IconButton(
              tooltip: 'Change image',
              icon: const Icon(Icons.photo_library_outlined),
              onPressed: _pickImage,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: _sourceBytes == null
          ? ToolEmptyState(
              title: 'Select Image to Convert Format',
              subtitle: 'Easily convert between JPG, PNG, and WebP while preserving full image quality.',
              icon: Icons.swap_horiz_rounded,
              iconColor: AppColors.toolPurpleIcon,
              iconBgColor: AppColors.toolPurpleBg,
              buttonText: 'Select Image to Begin',
              onSelect: _pickImage,
            )
          : Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Preview
                Container(
                  height: 320,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDarkElevated : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _sourceBytes != null
                        ? Image.memory(_sourceBytes!, fit: BoxFit.contain)
                        : const Center(child: Text('No image selected')),
                  ),
                ),

                const SizedBox(height: 24),

                // Conversion Direction Box
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildFormatBadge('Source: $_sourceFormat', AppColors.slateBlue),
                          const Icon(Icons.arrow_forward_rounded, color: AppColors.primary),
                          _buildFormatBadge('Target: ${_targetFormat.name.toUpperCase()}', AppColors.primary),
                        ],
                      ),
                      const Divider(height: 28),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Select Target Format',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildChoiceChip('JPG', ImageOutputFormat.jpg),
                          const SizedBox(width: 8),
                          _buildChoiceChip('PNG', ImageOutputFormat.png),
                          const SizedBox(width: 8),
                          _buildChoiceChip('WebP', ImageOutputFormat.webp),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isConverting ? null : _convert,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isConverting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Convert to ${_targetFormat.name.toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
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

  Widget _buildFormatBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }

  Widget _buildChoiceChip(String label, ImageOutputFormat format) {
    final isSelected = _targetFormat == format;
    return Expanded(
      child: ChoiceChip(
        label: Center(child: Text(label)),
        selected: isSelected,
        selectedColor: AppColors.primaryContainer,
        labelStyle: TextStyle(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? AppColors.primary : null,
        ),
        onSelected: (_) => setState(() => _targetFormat = format),
      ),
    );
  }
}
