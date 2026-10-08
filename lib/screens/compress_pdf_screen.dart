import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/pdf_service.dart';
import '../services/storage_service.dart';
import '../services/file_picker_helper.dart';
import '../widgets/page_lab_app_bar.dart';
import '../widgets/tool_empty_state.dart';
import '../widgets/export_progress_dialog.dart';

class CompressPdfScreen extends StatefulWidget {
  final Uint8List? initialPdfBytes;
  final String? initialFileName;

  const CompressPdfScreen({
    super.key,
    this.initialPdfBytes,
    this.initialFileName,
  });

  @override
  State<CompressPdfScreen> createState() => _CompressPdfScreenState();
}

class _CompressPdfScreenState extends State<CompressPdfScreen> {
  Uint8List? _pdfBytes;
  String _fileName = '';
  int _originalSizeBytes = 0;

  PdfCompressionLevel _compressionLevel = PdfCompressionLevel.medium;
  bool _isCompressing = false;
  int? _resultSizeBytes;

  @override
  void initState() {
    super.initState();
    if (widget.initialPdfBytes != null) {
      _loadPdf(
        widget.initialPdfBytes!,
        widget.initialFileName ?? 'Selected_Document.pdf',
      );
    }
  }

  void _loadPdf(Uint8List bytes, String name) {
    setState(() {
      _pdfBytes = bytes;
      _fileName = name;
      _originalSizeBytes = bytes.length;
      _resultSizeBytes = null;
    });
  }

  Future<void> _pickPdf() async {
    final doc = await FilePickerHelper.pickSinglePdf();
    if (doc != null) {
      _loadPdf(doc.bytes, doc.name);
    }
  }

  double get _reductionFactor {
    switch (_compressionLevel) {
      case PdfCompressionLevel.low:
        return 0.35;
      case PdfCompressionLevel.medium:
        return 0.74; // Matches mockup: 74%
      case PdfCompressionLevel.high:
        return 0.86;
    }
  }

  int get _estimatedBytes => (_originalSizeBytes * (1.0 - _reductionFactor)).round();

  String get _estimatedSizeText {
    final mb = _estimatedBytes / (1024 * 1024);
    final pct = (_reductionFactor * 100).round();
    if (mb >= 1.0) {
      return '~ ${mb.toStringAsFixed(1)} MB ($pct% smaller)';
    } else {
      final kb = _estimatedBytes / 1024;
      return '~ ${kb.toStringAsFixed(0)} KB ($pct% smaller)';
    }
  }

  String get _levelExplanation {
    switch (_compressionLevel) {
      case PdfCompressionLevel.low:
        return 'Preserves high resolution (200 DPI). Ideal for crisp text.';
      case PdfCompressionLevel.medium:
        return 'Good balance between size and quality. Recommended for sharing.';
      case PdfCompressionLevel.high:
        return 'Maximum compression (90 DPI). Best for email attachment limits.';
    }
  }

  Future<void> _compress() async {
    if (_pdfBytes == null) return;

    final dialog = ExportProgressDialog(
      context,
      title: 'Compressing PDF',
      initialStatus: 'Optimizing PDF assets...',
    );
    dialog.show();

    setState(() => _isCompressing = true);

    try {
      final compressedBytes = await PdfService().compressPdf(
        pdfBytes: _pdfBytes!,
        level: _compressionLevel,
        onProgress: (pct, msg) => dialog.update(pct, msg),
      );

      dialog.update(0.85, 'Saving compressed file...');
      final outName = 'Compressed_${_fileName.replaceAll('.pdf', '')}.pdf';
      final item = await StorageService().saveFile(
        fileName: outName,
        bytes: compressedBytes,
        type: 'pdf',
        subtitle: 'Compressed (${_compressionLevel.name.toUpperCase()}), ${itemFormattedSize(compressedBytes.length)}',
      );

      setState(() {
        _resultSizeBytes = compressedBytes.length;
      });

      await dialog.complete('PDF Compressed!');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Compressed successfully! New size: ${item.formattedSize}'),
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
        SnackBar(content: Text('Compression failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isCompressing = false);
    }
  }

  String itemFormattedSize(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: PageLabAppBar(
        title: 'Compress PDF',
        subtitle: _fileName,
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
              title: 'Select PDF Document to Compress',
              subtitle: 'Compress large PDF files while preserving clear fonts and high readability.',
              icon: Icons.compress_rounded,
              iconColor: AppColors.toolPurpleIcon,
              iconBgColor: AppColors.toolPurpleBg,
              buttonText: 'Select PDF Document',
              buttonIcon: Icons.upload_file_rounded,
              supportedFormats: const ['PDF'],
              onSelect: _pickPdf,
            )
          : Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
            // 1. Prominent PDF Document Card (Mockup Screen 7)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [AppColors.cardDarkElevated, AppColors.cardDark]
                      : [Colors.white, const Color(0xFFFDFBF9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Stylized 3D Document Fold Icon
                  Container(
                    width: 78,
                    height: 102,
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.shade200, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.12),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.red.shade200,
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(14),
                                bottomLeft: Radius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.picture_as_pdf_rounded, size: 38, color: Colors.red.shade500),
                              const SizedBox(height: 4),
                              Text(
                                'PDF',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // File Name
                  Text(
                    _fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.textLight : AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Original Size
                  Text(
                    'Original Size',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    itemFormattedSize(_originalSizeBytes),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: isDark ? AppColors.textLight : AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 2. Compression Level Selector (Low, Medium, High)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Compression Level',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.textLight : AppColors.textDark,
                ),
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDarkElevated : AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: Row(
                children: [
                  _buildLevelTab('Low', '200 DPI', PdfCompressionLevel.low),
                  _buildLevelTab('Medium', 'Recommended', PdfCompressionLevel.medium),
                  _buildLevelTab('High', 'Smallest', PdfCompressionLevel.high),
                ],
              ),
            ),

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _levelExplanation,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 3. Estimated Output Size Card with Reduction Visualizer (Mockup Screen 7)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.sageGreenContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppColors.sageGreen.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.sageGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_downward_rounded, size: 12, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Estimated Output Size',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                          color: AppColors.sageGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _resultSizeBytes != null
                        ? itemFormattedSize(_resultSizeBytes!)
                        : _estimatedSizeText,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.sageGreen,
                    ),
                  ),
                  if (_resultSizeBytes != null && _pdfBytes != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.sageGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Reduced by ${(((_pdfBytes!.length - _resultSizeBytes!) / _pdfBytes!.length) * 100).clamp(0, 100).toStringAsFixed(0)}% (${itemFormattedSize(_pdfBytes!.length)} → ${itemFormattedSize(_resultSizeBytes!)})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.sageGreen,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  // Visual comparison bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Row(
                      children: [
                        Expanded(
                          flex: (100 * (1 - _reductionFactor)).round(),
                          child: Container(height: 8, color: AppColors.sageGreen),
                        ),
                        Expanded(
                          flex: (100 * _reductionFactor).round(),
                          child: Container(
                            height: 8,
                            color: AppColors.sageGreen.withValues(alpha: 0.2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 4. Primary Compress Action Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isCompressing ? null : _compress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 3,
                  shadowColor: AppColors.primary.withValues(alpha: 0.35),
                ),
                child: _isCompressing
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          ),
                          SizedBox(width: 14),
                          Text('Compressing...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.compress_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Compress PDF',
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
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _buildLevelTab(String label, String hint, PdfCompressionLevel level) {
    final isSelected = _compressionLevel == level;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _compressionLevel = level),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
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
          alignment: Alignment.center,
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: isSelected
                      ? Colors.white
                      : (Theme.of(context).brightness == Brightness.dark
                          ? AppColors.textLight
                          : AppColors.textDark),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hint,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected
                      ? Colors.white70
                      : (Theme.of(context).brightness == Brightness.dark
                          ? AppColors.textMutedDark
                          : AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
