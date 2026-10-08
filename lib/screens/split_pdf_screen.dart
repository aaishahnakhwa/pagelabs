import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/file_picker_helper.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../theme/app_colors.dart';
import '../services/storage_service.dart';
import '../widgets/page_lab_app_bar.dart';
import '../widgets/tool_empty_state.dart';
import '../widgets/export_progress_dialog.dart';

class SplitPdfScreen extends StatefulWidget {
  final Uint8List? initialPdfBytes;
  final String? initialFileName;

  const SplitPdfScreen({
    super.key,
    this.initialPdfBytes,
    this.initialFileName,
  });

  @override
  State<SplitPdfScreen> createState() => _SplitPdfScreenState();
}

class _SplitPdfScreenState extends State<SplitPdfScreen> {
  Uint8List? _pdfBytes;
  String _fileName = 'Report.pdf';
  final List<Uint8List> _pages = [];
  final Set<int> _selectedPageIndices = {};
  bool _isLoading = false;
  bool _isSplitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPdfBytes != null) {
      _loadPdf(widget.initialPdfBytes!, widget.initialFileName ?? 'Document.pdf');
    }
  }

  Future<void> _loadPdf(Uint8List bytes, String name) async {
    setState(() {
      _pdfBytes = bytes;
      _fileName = name;
      _isLoading = true;
      _pages.clear();
      _selectedPageIndices.clear();
    });

    try {
      final raster = Printing.raster(bytes, dpi: 100);
      int idx = 0;
      await for (final page in raster) {
        final png = await page.toPng();
        if (mounted) {
          setState(() {
            _pages.add(png);
            _selectedPageIndices.add(idx);
          });
        }
        idx++;
      }
    } catch (e) {
      debugPrint('Error previewing PDF: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickPdf() async {
    final doc = await FilePickerHelper.pickSinglePdf();
    if (doc != null) {
      _loadPdf(doc.bytes, doc.name);
    }
  }

  void _togglePage(int index) {
    setState(() {
      if (_selectedPageIndices.contains(index)) {
        if (_selectedPageIndices.length > 1) {
          _selectedPageIndices.remove(index);
        }
      } else {
        _selectedPageIndices.add(index);
      }
    });
  }

  Future<void> _split() async {
    if (_pdfBytes == null || _selectedPageIndices.isEmpty) return;

    final sortedIndices = _selectedPageIndices.toList()..sort();
    final dialog = ExportProgressDialog(
      context,
      title: 'Splitting PDF',
      initialStatus: 'Extracting pages...',
      autoAnimate: false,
    );
    dialog.show();

    setState(() => _isSplitting = true);

    try {
      final splitDoc = pw.Document();

      for (int i = 0; i < sortedIndices.length; i++) {
        final idx = sortedIndices[i];
        dialog.update((i) / sortedIndices.length, 'Compiling page ${i + 1} of ${sortedIndices.length}...');
        final pngBytes = _pages[idx];
        final pwImg = pw.MemoryImage(pngBytes);
        splitDoc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (pw.Context ctx) => pw.FullPage(
              ignoreMargins: true,
              child: pw.Image(pwImg, fit: pw.BoxFit.cover),
            ),
          ),
        );
      }

      dialog.update(0.88, 'Saving split document...');
      final splitBytes = await splitDoc.save();
      final outName = 'Split_${_fileName.replaceAll('.pdf', '')}_Pages.pdf';
      final item = await StorageService().saveFile(
        fileName: outName,
        bytes: splitBytes,
        type: 'pdf',
        subtitle: 'Extracted ${sortedIndices.length} pages',
      );

      await dialog.complete('PDF Split Saved!');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Split PDF saved: $outName'),
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
        SnackBar(content: Text('Split failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSplitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: PageLabAppBar(
        title: 'Split PDF',
        subtitle: _pdfBytes != null ? '${_selectedPageIndices.length} of ${_pages.length} pages selected' : null,
        actions: [
          if (_pdfBytes != null) ...[
            IconButton(
              tooltip: 'Change PDF',
              icon: const Icon(Icons.folder_open_rounded),
              onPressed: _pickPdf,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: _pdfBytes == null
          ? ToolEmptyState(
              title: 'Select PDF Document to Split',
              subtitle: 'Extract specific pages or page ranges from your document with ease.',
              icon: Icons.call_split_rounded,
              iconColor: AppColors.toolOrangeIcon,
              iconBgColor: AppColors.toolOrangeBg,
              buttonText: 'Select PDF Document',
              buttonIcon: Icons.upload_file_rounded,
              supportedFormats: const ['PDF'],
              onSelect: _pickPdf,
            )
          : _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tap pages to select or deselect',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                if (_selectedPageIndices.length == _pages.length) {
                                  _selectedPageIndices.clear();
                                  _selectedPageIndices.add(0);
                                } else {
                                  _selectedPageIndices.addAll(List.generate(_pages.length, (i) => i));
                                }
                              });
                            },
                            child: Text(
                              _selectedPageIndices.length == _pages.length ? 'Deselect All' : 'Select All',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _pages.length,
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.72,
                        ),
                        itemBuilder: (context, index) {
                      final isSelected = _selectedPageIndices.contains(index);
                      return GestureDetector(
                        onTap: () => _togglePage(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.cardDarkElevated : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.borderLight,
                              width: isSelected ? 2.5 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.memory(
                                  _pages[index],
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primary : Colors.black45,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    isSelected ? Icons.check : Icons.circle_outlined,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Page ${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
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
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isSplitting ? null : _split,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSplitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'Extract ${_selectedPageIndices.length} Pages to New PDF',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}
