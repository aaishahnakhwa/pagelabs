import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../theme/app_colors.dart';
import '../services/pdf_service.dart';
import '../services/storage_service.dart';
import '../services/file_picker_helper.dart';
import '../widgets/page_lab_app_bar.dart';
import '../widgets/tool_empty_state.dart';
import '../widgets/export_progress_dialog.dart';

class PdfToImageScreen extends StatefulWidget {
  final Uint8List? initialPdfBytes;

  const PdfToImageScreen({super.key, this.initialPdfBytes});

  @override
  State<PdfToImageScreen> createState() => _PdfToImageScreenState();
}

class _PdfToImageScreenState extends State<PdfToImageScreen> {
  Uint8List? _pdfBytes;
  final List<Uint8List> _previewPages = [];
  int _currentPageIndex = 0;
  bool _isLoadingPdf = false;
  bool _isConverting = false;

  // Options
  String _outputFormat = 'JPG';
  String _resolution = 'High (300 DPI)';
  bool _selectAllPages = true;
  final Set<int> _selectedPageIndices = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialPdfBytes != null) {
      _loadPdf(widget.initialPdfBytes!);
    }
  }

  Future<void> _loadPdf(Uint8List bytes) async {
    setState(() {
      _pdfBytes = bytes;
      _isLoadingPdf = true;
      _previewPages.clear();
      _selectedPageIndices.clear();
      _currentPageIndex = 0;
    });

    try {
      final rasterPages = Printing.raster(bytes, dpi: 100);
      int idx = 0;
      await for (final page in rasterPages) {
        final png = await page.toPng();
        if (mounted) {
          setState(() {
            _previewPages.add(png);
            _selectedPageIndices.add(idx);
          });
        }
        idx++;
      }
    } catch (e) {
      debugPrint('Error previewing PDF pages: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPdf = false);
    }
  }

  Future<void> _pickPdf() async {
    final doc = await FilePickerHelper.pickSinglePdf();
    if (doc != null) {
      _loadPdf(doc.bytes);
    }
  }

  Future<void> _convert() async {
    if (_pdfBytes == null || _previewPages.isEmpty) return;

    final dialog = ExportProgressDialog(
      context,
      title: 'Extracting Images',
      initialStatus: 'Rendering PDF pages...',
    );
    dialog.show();

    setState(() => _isConverting = true);

    try {
      double targetDpi = 150.0;
      if (_resolution.contains('300')) {
        targetDpi = 300.0;
      } else if (_resolution.contains('72')) {
        targetDpi = 72.0;
      }

      final List<int> pagesToExtract = _selectAllPages
          ? List.generate(_previewPages.length, (i) => i + 1)
          : _selectedPageIndices.map((i) => i + 1).toList()..sort();

      dialog.update(0.35, 'Converting ${pagesToExtract.length} pages...');
      final convertedImages = await PdfService().pdfToImages(
        pdfBytes: _pdfBytes!,
        pageNumbers: pagesToExtract,
        dpi: targetDpi,
        isJpg: _outputFormat == 'JPG',
      );

      final ext = _outputFormat.toLowerCase();
      int savedCount = 0;

      for (int i = 0; i < convertedImages.length; i++) {
        final pageNum = pagesToExtract[i];
        final progressVal = 0.50 + ((i + 1) / convertedImages.length) * 0.45;
        dialog.update(progressVal, 'Saving page ${i + 1} of ${convertedImages.length}...');
        final fileName = 'PageLab_Page_${pageNum}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        await StorageService().saveFile(
          fileName: fileName,
          bytes: convertedImages[i],
          type: 'image',
          subtitle: 'Page $pageNum, $_resolution',
        );
        savedCount++;
      }

      await dialog.complete('Extracted $savedCount images!');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully extracted $savedCount images!'),
          backgroundColor: AppColors.sageGreen,
        ),
      );
    } catch (e) {
      dialog.dismiss();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Conversion error: $e'), backgroundColor: Colors.red),
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
        title: 'PDF to Image',
        subtitle: _previewPages.isNotEmpty
            ? '${_previewPages.length} Pages detected'
            : 'Select PDF',
        actions: [
          if (_pdfBytes != null) ...[
            IconButton(
              tooltip: 'Change PDF',
              icon: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDarkElevated : AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.folder_open_rounded, size: 18),
              ),
              onPressed: _pickPdf,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: _pdfBytes == null
          ? ToolEmptyState(
              title: 'Select PDF to Convert to Images',
              subtitle: 'Extract high-resolution JPG or PNG pages from your PDF document.',
              icon: Icons.image_outlined,
              iconColor: AppColors.toolBlueIcon,
              iconBgColor: AppColors.toolBlueBg,
              buttonText: 'Select PDF Document',
              buttonIcon: Icons.upload_file_rounded,
              supportedFormats: const ['PDF'],
              onSelect: _pickPdf,
            )
          : _isLoadingPdf
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Rendering PDF pages...', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 960;

                // 1. PDF Page Viewer Card with Page Counter
                final previewViewerWidget = Padding(
                  padding: EdgeInsets.symmetric(horizontal: isDesktop ? 0 : 16, vertical: isDesktop ? 0 : 16),
                  child: Container(
                    height: isDesktop ? 460 : 330,
                    width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF171720) : const Color(0xFFEBE6DC),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : const Color(0xFFDFD7CA),
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_previewPages.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.memory(
                                    _previewPages[_currentPageIndex],
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),

                          // Page Counter Badge (1/8)
                          Positioned(
                            bottom: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white24, width: 0.8),
                              ),
                              child: Text(
                                '${_currentPageIndex + 1} / ${_previewPages.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );

                // 2. Horizontal Thumbnails Strip (Mockup Screen 6)
                final thumbnailsStripWidget = _previewPages.length > 1
                    ? SizedBox(
                        height: 94,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: _previewPages.length,
                        itemBuilder: (context, index) {
                          final isCurrent = _currentPageIndex == index;
                          final isChecked = _selectedPageIndices.contains(index);

                          return GestureDetector(
                            onTap: () => setState(() => _currentPageIndex = index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 68,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isCurrent
                                      ? AppColors.primary
                                      : (isDark ? AppColors.borderDark : AppColors.borderLight),
                                  width: isCurrent ? 2.5 : 1,
                                ),
                                boxShadow: isCurrent
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.25),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.memory(
                                      _previewPages[index],
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    ),
                                  ),
                                  if (!_selectAllPages)
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            if (isChecked) {
                                              _selectedPageIndices.remove(index);
                                            } else {
                                              _selectedPageIndices.add(index);
                                            }
                                          });
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: isChecked ? AppColors.primary : Colors.white70,
                                            shape: BoxShape.circle,
                                          ),
                                          padding: const EdgeInsets.all(2),
                                          child: Icon(
                                            isChecked ? Icons.check : Icons.circle_outlined,
                                            size: 13,
                                            color: isChecked ? Colors.white : Colors.black54,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  : const SizedBox.shrink();

                // 3. Conversion Options Card
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
                        // Output Format (JPG / PNG)
                        Text(
                          'Output Format',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildFormatChip('JPG', 'Smaller size, ideal for photo pages'),
                            const SizedBox(width: 12),
                            _buildFormatChip('PNG', 'Lossless, best for sharp text'),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // Resolution Selector
                        Text(
                          'Resolution / DPI',
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
                              value: _resolution,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded),
                              items: const [
                                DropdownMenuItem(
                                  value: 'High (300 DPI)',
                                  child: Text('High (300 DPI) - Print Quality & Crystal Clear', style: TextStyle(fontWeight: FontWeight.w600)),
                                ),
                                DropdownMenuItem(
                                  value: 'Medium (150 DPI)',
                                  child: Text('Medium (150 DPI) - Web & Fast Sharing', style: TextStyle(fontWeight: FontWeight.w600)),
                                ),
                                DropdownMenuItem(
                                  value: 'Standard (72 DPI)',
                                  child: Text('Standard (72 DPI) - Minimum File Size', style: TextStyle(fontWeight: FontWeight.w600)),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _resolution = val);
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Page Selection Mode
                        Text(
                          'Select Pages',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectAllPages = true),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                  decoration: BoxDecoration(
                                    color: _selectAllPages
                                        ? AppColors.primaryContainer
                                        : (isDark ? AppColors.cardDark : AppColors.surfaceMuted),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _selectAllPages ? AppColors.primary : Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'All Pages (${_previewPages.length})',
                                    style: TextStyle(
                                      fontWeight: _selectAllPages ? FontWeight.w800 : FontWeight.w600,
                                      color: _selectAllPages ? AppColors.primary : (isDark ? AppColors.textLight : AppColors.textDark),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectAllPages = false),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                  decoration: BoxDecoration(
                                    color: !_selectAllPages
                                        ? AppColors.primaryContainer
                                        : (isDark ? AppColors.cardDark : AppColors.surfaceMuted),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: !_selectAllPages ? AppColors.primary : Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    !_selectAllPages
                                        ? '${_selectedPageIndices.length} Selected'
                                        : 'Custom Selection',
                                    style: TextStyle(
                                      fontWeight: !_selectAllPages ? FontWeight.w800 : FontWeight.w600,
                                      color: !_selectAllPages ? AppColors.primary : (isDark ? AppColors.textLight : AppColors.textDark),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );

                // 4. Primary Convert Button
                final actionButton = Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isConverting ? null : _convert,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 3,
                        shadowColor: AppColors.primary.withValues(alpha: 0.35),
                      ),
                      child: _isConverting
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                ),
                                SizedBox(width: 14),
                                Text('Extracting Pages...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.collections_rounded, color: Colors.white, size: 20),
                                SizedBox(width: 10),
                                Text(
                                  'Convert to Images',
                                  style: TextStyle(
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
                      constraints: const BoxConstraints(maxWidth: 1280),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Column: PDF Page Preview + Thumbnails Strip
                            Expanded(
                              flex: 6,
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    previewViewerWidget,
                                    const SizedBox(height: 16),
                                    thumbnailsStripWidget,
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            // Right Column: Options & Convert Action
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

                // Mobile / Tablet single column layout
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          previewViewerWidget,
                          thumbnailsStripWidget,
                          const SizedBox(height: 14),
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

  Widget _buildFormatChip(String format, String hint) {
    final isSelected = _outputFormat == format;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _outputFormat = format),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                format,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? AppColors.primary : (isDark ? AppColors.textLight : AppColors.textDark),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hint,
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
}
