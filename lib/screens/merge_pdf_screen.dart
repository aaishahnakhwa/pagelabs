import 'dart:math' as math;
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

class MergePdfScreen extends StatefulWidget {
  const MergePdfScreen({super.key});

  @override
  State<MergePdfScreen> createState() => _MergePdfScreenState();
}

class _MergePdfScreenState extends State<MergePdfScreen> {
  final List<_PdfDocItem> _pdfList = [];
  final List<_PageSequenceItem> _pageSequence = [];

  int _selectedTab = 0; // 0 = By Files, 1 = Page Sequence
  bool _isSequenceListView = false;
  bool _isMerging = false;
  String _mergeStatus = '';

  Future<void> _pickPdfs() async {
    final docs = await FilePickerHelper.pickMultiplePdfs();
    if (docs.isNotEmpty) {
      for (final doc in docs) {
        final item = _PdfDocItem(
          id: '${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(10000)}',
          name: doc.name,
          bytes: doc.bytes,
        );
        setState(() {
          _pdfList.add(item);
        });
        _loadDocPages(item);
      }
    }
  }

  Future<void> _loadDocPages(_PdfDocItem doc) async {
    try {
      final raster = Printing.raster(doc.bytes, dpi: 60);
      int idx = 0;
      final pagesList = <_PdfPagePreview>[];
      await for (final page in raster) {
        final png = await page.toPng();
        pagesList.add(_PdfPagePreview(
          pageIndex: idx,
          pageNumber: idx + 1,
          thumbnail: png,
        ));
        idx++;
      }
      if (mounted) {
        setState(() {
          doc.pages = pagesList;
          doc.isLoadingPages = false;
          doc.selectedPageIndices = Set.from(List.generate(pagesList.length, (i) => i));
          doc.rangeController.text = pagesList.isNotEmpty ? '1-${pagesList.length}' : '';
          _regeneratePageSequence();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => doc.isLoadingPages = false);
      }
    }
  }

  void _regeneratePageSequence() {
    _pageSequence.clear();
    for (final doc in _pdfList) {
      final indices = doc.isAllPages
          ? List.generate(doc.pages.length, (i) => i)
          : (doc.selectedPageIndices.toList()..sort());

      for (final pIndex in indices) {
        if (pIndex >= 0 && pIndex < doc.pages.length) {
          final pagePreview = doc.pages[pIndex];
          _pageSequence.add(_PageSequenceItem(
            id: '${doc.id}_page_$pIndex',
            docId: doc.id,
            docName: doc.name,
            pageIndex: pIndex,
            pageNumber: pagePreview.pageNumber,
            thumbnail: pagePreview.thumbnail,
          ));
        }
      }
    }
  }

  void _moveDoc(int index, int delta) {
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= _pdfList.length) return;
    setState(() {
      final item = _pdfList.removeAt(index);
      _pdfList.insert(newIndex, item);
      _regeneratePageSequence();
    });
  }

  void _removeDoc(int index) {
    setState(() {
      final removed = _pdfList.removeAt(index);
      removed.rangeController.dispose();
      _regeneratePageSequence();
    });
  }

  void _movePageInSequence(int index, int delta) {
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= _pageSequence.length) return;
    setState(() {
      final item = _pageSequence.removeAt(index);
      _pageSequence.insert(newIndex, item);
    });
  }

  void _removePageFromSequence(int index) {
    setState(() {
      final item = _pageSequence.removeAt(index);
      // Uncheck from doc
      for (final doc in _pdfList) {
        if (doc.id == item.docId) {
          doc.isAllPages = false;
          doc.selectedPageIndices.remove(item.pageIndex);
          doc.rangeController.text = _formatIndicesToRange(doc.selectedPageIndices);
          break;
        }
      }
    });
  }

  void _toggleDocPage(_PdfDocItem doc, int pageIndex) {
    setState(() {
      doc.isAllPages = false;
      if (doc.selectedPageIndices.contains(pageIndex)) {
        doc.selectedPageIndices.remove(pageIndex);
      } else {
        doc.selectedPageIndices.add(pageIndex);
      }
      doc.rangeController.text = _formatIndicesToRange(doc.selectedPageIndices);
      _regeneratePageSequence();
    });
  }

  void _applyDocRange(_PdfDocItem doc, String text) {
    final parsed = _parseRangeString(text, doc.pages.length);
    setState(() {
      doc.isAllPages = false;
      doc.selectedPageIndices = parsed;
      _regeneratePageSequence();
    });
  }

  void _setDocSelectionPreset(_PdfDocItem doc, String preset) {
    setState(() {
      doc.isAllPages = false;
      final total = doc.pages.length;
      if (preset == 'all') {
        doc.isAllPages = true;
        doc.selectedPageIndices = Set.from(List.generate(total, (i) => i));
      } else if (preset == 'clear') {
        doc.selectedPageIndices.clear();
      } else if (preset == 'odd') {
        doc.selectedPageIndices = {
          for (int i = 0; i < total; i++)
            if ((i + 1) % 2 != 0) i
        };
      } else if (preset == 'even') {
        doc.selectedPageIndices = {
          for (int i = 0; i < total; i++)
            if ((i + 1) % 2 == 0) i
        };
      }
      doc.rangeController.text = _formatIndicesToRange(doc.selectedPageIndices);
      _regeneratePageSequence();
    });
  }

  Set<int> _parseRangeString(String text, int maxPages) {
    final result = <int>{};
    if (text.trim().isEmpty) return result;
    final parts = text.split(RegExp(r'[,;\s]+'));
    for (final part in parts) {
      if (part.contains('-')) {
        final range = part.split('-');
        if (range.length == 2) {
          final start = int.tryParse(range[0].trim());
          final end = int.tryParse(range[1].trim());
          if (start != null && end != null) {
            final low = math.min(start, end).clamp(1, maxPages);
            final high = math.max(start, end).clamp(1, maxPages);
            for (int i = low; i <= high; i++) {
              result.add(i - 1);
            }
          }
        }
      } else {
        final p = int.tryParse(part.trim());
        if (p != null && p >= 1 && p <= maxPages) {
          result.add(p - 1);
        }
      }
    }
    return result;
  }

  String _formatIndicesToRange(Set<int> indices) {
    if (indices.isEmpty) return '';
    final sorted = indices.toList()..sort();
    final ranges = <String>[];
    int i = 0;
    while (i < sorted.length) {
      int start = sorted[i];
      int end = start;
      while (i + 1 < sorted.length && sorted[i + 1] == end + 1) {
        i++;
        end = sorted[i];
      }
      if (start == end) {
        ranges.add('${start + 1}');
      } else {
        ranges.add('${start + 1}-${end + 1}');
      }
      i++;
    }
    return ranges.join(', ');
  }

  Future<void> _merge() async {
    if (_pdfList.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least 2 PDF documents to merge.')),
      );
      return;
    }

    if (_pageSequence.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one page to merge.')),
      );
      return;
    }

    final totalPages = _pageSequence.length;
    final dialog = ExportProgressDialog(
      context,
      title: 'Merging PDF',
      initialStatus: 'Preparing pages...',
      autoAnimate: false,
    );
    dialog.show();

    setState(() {
      _isMerging = true;
      _mergeStatus = 'Preparing document...';
    });

    try {
      final mergedDoc = pw.Document();

      for (int i = 0; i < totalPages; i++) {
        final pageItem = _pageSequence[i];
        final currentProgress = (i) / totalPages;
        dialog.update(currentProgress, 'Rendering page ${i + 1} of $totalPages');
        if (mounted) {
          setState(() {
            _mergeStatus = 'Rendering page ${i + 1} of $totalPages...';
          });
        }

        final docItem = _pdfList.firstWhere((d) => d.id == pageItem.docId);
        final raster = Printing.raster(docItem.bytes, pages: [pageItem.pageIndex], dpi: 150);

        await for (final page in raster) {
          final pngBytes = await page.toPng();
          final pwImage = pw.MemoryImage(pngBytes);
          mergedDoc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat(page.width.toDouble(), page.height.toDouble()),
              margin: pw.EdgeInsets.zero,
              build: (pw.Context ctx) => pw.FullPage(
                ignoreMargins: true,
                child: pw.Image(pwImage, fit: pw.BoxFit.cover),
              ),
            ),
          );
        }
      }

      dialog.update(0.92, 'Saving merged PDF...');
      if (mounted) {
        setState(() => _mergeStatus = 'Saving PDF document...');
      }

      final mergedBytes = await mergedDoc.save();
      final fileName = 'PageLab_Merged_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final item = await StorageService().saveFile(
        fileName: fileName,
        bytes: mergedBytes,
        type: 'pdf',
        subtitle: 'Merged ${_pageSequence.length} pages from ${_pdfList.length} files',
      );

      await dialog.complete('PDF Merged!');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Merged PDF saved: $fileName (${(mergedBytes.length / 1024).toStringAsFixed(1)} KB)'),
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
        SnackBar(content: Text('Merge failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isMerging = false);
    }
  }

  @override
  void dispose() {
    for (final doc in _pdfList) {
      doc.rangeController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: PageLabAppBar(
        title: 'Merge PDF',
        subtitle: _pdfList.isNotEmpty
            ? '${_pdfList.length} of 2+ files • ${_pageSequence.length} pages'
            : null,
        actions: [
          if (_pdfList.isNotEmpty) ...[
            IconButton(
              tooltip: 'Add more PDFs',
              icon: const Icon(Icons.add_rounded),
              onPressed: _pickPdfs,
            ),
            IconButton(
              tooltip: 'Clear all',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () {
                setState(() {
                  for (final doc in _pdfList) {
                    doc.rangeController.dispose();
                  }
                  _pdfList.clear();
                  _pageSequence.clear();
                });
              },
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: _pdfList.isEmpty
          ? ToolEmptyState(
              title: 'Select PDF Documents to Merge',
              subtitle: 'Combine multiple PDFs, choose full files or select specific pages, and reorder the final sequence.',
              icon: Icons.call_merge_rounded,
              iconColor: AppColors.toolRedIcon,
              iconBgColor: AppColors.toolRedBg,
              buttonText: 'Select PDF Documents',
              buttonIcon: Icons.upload_file_rounded,
              supportedFormats: const ['PDF'],
              onSelect: _pickPdfs,
            )
          : Column(
              children: [
                // Mode Selector Bar (By Files vs Page Sequence)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: isDark ? AppColors.cardDark : AppColors.surfaceMuted,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 880),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildModeTab(
                              title: 'Files & Pages',
                              countBadge: '${_pdfList.length}',
                              isSelected: _selectedTab == 0,
                              icon: Icons.description_outlined,
                              onTap: () => setState(() => _selectedTab = 0),
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildModeTab(
                              title: 'Page Sequence',
                              countBadge: '${_pageSequence.length} pgs',
                              isSelected: _selectedTab == 1,
                              icon: Icons.view_carousel_outlined,
                              onTap: () => setState(() => _selectedTab = 1),
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Minimum 2 PDFs Banner when only 1 PDF is added
                if (_pdfList.length < 2)
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 880),
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2E2415) : AppColors.toolAmberBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.toolAmberIcon.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.toolAmberIcon),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Minimum 2 PDF documents required to merge. Please add at least 1 more PDF.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.toolAmberIcon,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _pickPdfs,
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Add PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.toolAmberIcon,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Main Content View
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 880),
                      child: _selectedTab == 0
                          ? _buildFilesListTab(isDark)
                          : _buildPageSequenceTab(isDark),
                    ),
                  ),
                ),

                // Bottom Fixed Action Bar
                _buildBottomMergeBar(isDark),
              ],
            ),
    );
  }

  Widget _buildModeTab({
    required String title,
    required String countBadge,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.cardDarkElevated : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.borderDark : AppColors.borderLight),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.primary : (isDark ? AppColors.textMutedDark : AppColors.textMuted),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 13,
                color: isSelected ? AppColors.primary : (isDark ? AppColors.textLight : AppColors.textDark),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : (isDark ? AppColors.cardDark : Colors.grey.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                countBadge,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppColors.primary : (isDark ? AppColors.textMutedDark : AppColors.textMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilesListTab(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pdfList.length + 1,
      itemBuilder: (context, index) {
        if (index == _pdfList.length) {
          return InkWell(
            onTap: _pickPdfs,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDarkElevated : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Add Another PDF Document',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        final doc = _pdfList[index];
        return _buildDocCard(doc, index, isDark);
      },
    );
  }

  Widget _buildDocCard(_PdfDocItem doc, int index, bool isDark) {
    final selectedCount = doc.isAllPages ? doc.pages.length : doc.selectedPageIndices.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDarkElevated : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header with Order Controls
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F1F2B) : const Color(0xFFF9F7F4),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
            ),
            child: Row(
              children: [
                // Sequence Index Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.picture_as_pdf_rounded, color: AppColors.toolRedIcon, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      Text(
                        '${(doc.bytes.length / 1024).toStringAsFixed(1)} KB • ${doc.pages.length} pages total',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                // Reorder Sequence Buttons (Move Up / Down)
                IconButton(
                  tooltip: 'Move Up',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                  onPressed: index > 0 ? () => _moveDoc(index, -1) : null,
                ),
                IconButton(
                  tooltip: 'Move Down',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                  onPressed: index < _pdfList.length - 1 ? () => _moveDoc(index, 1) : null,
                ),
                IconButton(
                  tooltip: 'Remove',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.redAccent),
                  onPressed: () => _removeDoc(index),
                ),
              ],
            ),
          ),

          // Body: Page Selection Options
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Include in Merge:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: Text('All Pages (${doc.pages.length})'),
                      selected: doc.isAllPages,
                      onSelected: (val) {
                        if (val) _setDocSelectionPreset(doc, 'all');
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('Specific Pages ($selectedCount)'),
                      selected: !doc.isAllPages,
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            doc.isAllPages = false;
                            if (doc.selectedPageIndices.isEmpty) {
                              doc.selectedPageIndices = Set.from(List.generate(doc.pages.length, (i) => i));
                              doc.rangeController.text = _formatIndicesToRange(doc.selectedPageIndices);
                            }
                            _regeneratePageSequence();
                          });
                        }
                      },
                    ),
                  ],
                ),

                // If specific pages is active, show page selection controls
                if (!doc.isAllPages) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      // Text input for page range
                      Expanded(
                        child: TextField(
                          controller: doc.rangeController,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'e.g. 1-3, 5 (up to ${doc.pages.length})',
                            labelText: 'Page range',
                            labelStyle: const TextStyle(fontSize: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          style: const TextStyle(fontSize: 13),
                          onChanged: (val) => _applyDocRange(doc, val),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Quick presets
                      OutlinedButton(
                        onPressed: () => _setDocSelectionPreset(doc, 'all'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: const Text('All', style: TextStyle(fontSize: 11)),
                      ),
                      const SizedBox(width: 4),
                      OutlinedButton(
                        onPressed: () => _setDocSelectionPreset(doc, 'odd'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: const Text('Odd', style: TextStyle(fontSize: 11)),
                      ),
                      const SizedBox(width: 4),
                      OutlinedButton(
                        onPressed: () => _setDocSelectionPreset(doc, 'even'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: const Text('Even', style: TextStyle(fontSize: 11)),
                      ),
                      const SizedBox(width: 4),
                      OutlinedButton(
                        onPressed: () => _setDocSelectionPreset(doc, 'clear'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: const Text('Clear', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ],

                // Thumbnail chips strip
                if (doc.pages.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 94,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: doc.pages.length,
                      itemBuilder: (context, pIdx) {
                        final pagePreview = doc.pages[pIdx];
                        final isSelected = doc.isAllPages || doc.selectedPageIndices.contains(pIdx);

                        return GestureDetector(
                          onTap: () => _toggleDocPage(doc, pIdx),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 68,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.cardDark : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark ? AppColors.borderDark : Colors.grey.shade300),
                                width: isSelected ? 2.0 : 1.0,
                              ),
                            ),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(9),
                                  child: Image.memory(
                                    pagePreview.thumbnail,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                ),
                                if (!isSelected)
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(9),
                                      color: Colors.black.withValues(alpha: 0.55),
                                    ),
                                  ),
                                Positioned(
                                  top: 4,
                                  left: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.primary : Colors.black54,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      'p.${pagePreview.pageNumber}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: Icon(
                                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                    color: isSelected ? AppColors.primary : Colors.white70,
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ] else if (doc.isLoadingPages) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text('Loading pages...', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageSequenceTab(bool isDark) {
    if (_pageSequence.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_none_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'No Pages Selected',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Select pages in the "Files & Pages" tab to build your sequence.',
              style: TextStyle(color: isDark ? AppColors.textMutedDark : AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.drag_indicator_rounded, size: 20, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Drag pages to reorder output sequence',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isDark ? AppColors.textLight : AppColors.textDark,
                  ),
                ),
              ),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, icon: Icon(Icons.grid_view_rounded, size: 16), tooltip: 'Draggable Grid'),
                  ButtonSegment(value: true, icon: Icon(Icons.view_list_rounded, size: 16), tooltip: 'Reorderable List'),
                ],
                selected: {_isSequenceListView},
                onSelectionChanged: (val) => setState(() => _isSequenceListView = val.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => setState(_regeneratePageSequence),
                icon: const Icon(Icons.sync_rounded, size: 15),
                label: const Text('Reset', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isSequenceListView
              ? _buildSequenceReorderableList(isDark)
              : _buildSequenceDraggableGrid(isDark),
        ),
      ],
    );
  }

  Widget _buildSequenceDraggableGrid(bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisExtent: 220,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _pageSequence.length,
      itemBuilder: (context, index) {
        final page = _pageSequence[index];

        return DragTarget<int>(
          onWillAcceptWithDetails: (details) => details.data != index,
          onAcceptWithDetails: (details) {
            final fromIndex = details.data;
            setState(() {
              final item = _pageSequence.removeAt(fromIndex);
              _pageSequence.insert(index, item);
            });
          },
          builder: (context, candidateData, rejectedData) {
            final isDropTarget = candidateData.isNotEmpty;

            return Draggable<int>(
              data: index,
              feedback: Material(
                color: Colors.transparent,
                elevation: 10,
                borderRadius: BorderRadius.circular(14),
                child: Opacity(
                  opacity: 0.9,
                  child: SizedBox(
                    width: 150,
                    height: 215,
                    child: _buildSequenceGridCard(page, index, isDark, isDragging: true),
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.25,
                child: _buildSequenceGridCard(page, index, isDark),
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: isDropTarget
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 10,
                          ),
                        ],
                      )
                    : null,
                child: _buildSequenceGridCard(page, index, isDark),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSequenceReorderableList(bool isDark) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _pageSequence.length,
      onReorderItem: (oldIndex, newIndex) {
        setState(() {
          final item = _pageSequence.removeAt(oldIndex);
          _pageSequence.insert(newIndex, item);
        });
      },
      itemBuilder: (context, index) {
        final page = _pageSequence[index];

        return Container(
          key: ValueKey(page.id),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDarkElevated : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: ListTile(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '#${index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.memory(
                    page.thumbnail,
                    width: 36,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ),
            title: Text(
              '${page.docName} (Page ${page.pageNumber})',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              'Output position: #${index + 1}',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Exclude page',
                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                  onPressed: () => _removePageFromSequence(index),
                ),
                const Icon(Icons.drag_handle_rounded, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSequenceGridCard(_PageSequenceItem page, int index, bool isDark, {bool isDragging = false}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDarkElevated : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDragging ? 0.12 : 0.04),
            blurRadius: isDragging ? 10 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Bar with Sequence Number, Drag Handle, and Close
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '#${index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const Tooltip(
                  message: 'Click & drag to reorder',
                  child: Icon(Icons.drag_indicator_rounded, size: 18, color: Colors.grey),
                ),
                IconButton(
                  tooltip: 'Exclude this page',
                  icon: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _removePageFromSequence(index),
                ),
              ],
            ),
          ),

          // Thumbnail Preview
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  page.thumbnail,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // Source Information
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            child: Text(
              '${page.docName} (p.${page.pageNumber})',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Move Left / Right Buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : AppColors.surfaceMuted,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'Move earlier',
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: index > 0 ? () => _movePageInSequence(index, -1) : null,
                ),
                Text(
                  'Order',
                  style: TextStyle(fontSize: 10, color: isDark ? AppColors.textMutedDark : AppColors.textMuted),
                ),
                IconButton(
                  tooltip: 'Move later',
                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: index < _pageSequence.length - 1 ? () => _movePageInSequence(index, 1) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomMergeBar(bool isDark) {
    final bool hasMinPdfs = _pdfList.length >= 2;
    final bool canMerge = !_isMerging && hasMinPdfs && _pageSequence.isNotEmpty;

    String buttonLabel;
    if (_isMerging) {
      buttonLabel = 'Merging...';
    } else if (!hasMinPdfs) {
      buttonLabel = 'Add At Least 2 PDFs to Merge (${_pdfList.length} of 2 added)';
    } else if (_pageSequence.isEmpty) {
      buttonLabel = 'Select At Least 1 Page';
    } else {
      buttonLabel = 'Merge into PDF (${_pageSequence.length} Pages)';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDarkElevated : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isMerging) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _mergeStatus,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: canMerge ? _merge : null,
                  icon: const Icon(Icons.call_merge_rounded, size: 20),
                  label: Text(
                    buttonLabel,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: isDark ? Colors.white12 : Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    disabledForegroundColor: isDark ? Colors.white38 : Colors.grey.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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

class _PdfPagePreview {
  final int pageIndex; // 0-based
  final int pageNumber; // 1-based
  final Uint8List thumbnail;

  _PdfPagePreview({
    required this.pageIndex,
    required this.pageNumber,
    required this.thumbnail,
  });
}

class _PdfDocItem {
  final String id;
  final String name;
  final Uint8List bytes;
  List<_PdfPagePreview> pages;
  bool isAllPages;
  Set<int> selectedPageIndices;
  bool isLoadingPages;
  final TextEditingController rangeController;

  _PdfDocItem({
    required this.id,
    required this.name,
    required this.bytes,
    List<_PdfPagePreview>? pages,
    Set<int>? selectedPageIndices,
  })  : pages = pages ?? [],
        isAllPages = true,
        isLoadingPages = true,
        selectedPageIndices = selectedPageIndices ?? <int>{},
        rangeController = TextEditingController();
}

class _PageSequenceItem {
  final String id;
  final String docId;
  final String docName;
  final int pageIndex; // 0-based
  final int pageNumber; // 1-based
  final Uint8List thumbnail;

  _PageSequenceItem({
    required this.id,
    required this.docId,
    required this.docName,
    required this.pageIndex,
    required this.pageNumber,
    required this.thumbnail,
  });
}
