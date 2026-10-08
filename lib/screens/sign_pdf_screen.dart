import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import '../models/placed_signature_item.dart';
import '../services/file_picker_helper.dart';
import '../services/file_saver/file_saver.dart' as saver;
import '../services/pdf_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/export_progress_dialog.dart';
import '../widgets/page_lab_app_bar.dart';
import '../widgets/tool_empty_state.dart';

class SignPdfScreen extends StatefulWidget {
  final Uint8List? initialPdfBytes;
  final String? initialFileName;

  const SignPdfScreen({
    super.key,
    this.initialPdfBytes,
    this.initialFileName,
  });

  @override
  State<SignPdfScreen> createState() => _SignPdfScreenState();
}

class _SignPdfScreenState extends State<SignPdfScreen> {
  Uint8List? _docBytes;
  String _docName = 'Document.pdf';
  bool _isPdf = true;

  bool _isLoadingDoc = false;
  List<Uint8List> _pageImages = [];
  int _currentPageIndex = 0;

  final List<PlacedSignatureItem> _placedItems = [];
  String? _selectedItemId;

  @override
  void initState() {
    super.initState();
    if (widget.initialPdfBytes != null) {
      _loadDocument(widget.initialPdfBytes!, widget.initialFileName ?? 'Document.pdf');
    }
  }

  Future<void> _pickDocument() async {
    final doc = await FilePickerHelper.pickSingleDocumentOrImageWithDetails();
    if (doc != null) {
      _loadDocument(doc.bytes, doc.name);
    }
  }

  Future<void> _loadDocument(Uint8List bytes, String name) async {
    setState(() {
      _isLoadingDoc = true;
      _docBytes = bytes;
      _docName = name;
      _isPdf = name.toLowerCase().endsWith('.pdf');
      _pageImages.clear();
      _placedItems.clear();
      _currentPageIndex = 0;
      _selectedItemId = null;
    });

    try {
      if (_isPdf) {
        final pages = await PdfService().pdfToImages(
          pdfBytes: bytes,
          dpi: 140.0,
          isJpg: false,
        );
        if (mounted) {
          setState(() {
            _pageImages = pages;
            _isLoadingDoc = false;
          });
        }
      } else {
        // Direct image
        if (mounted) {
          setState(() {
            _pageImages = [bytes];
            _isLoadingDoc = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDoc = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load document: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _addPlacedItem({
    required Uint8List imageBytes,
    required String label,
    double widthPercent = 0.28,
    double heightPercent = 0.12,
  }) {
    final newItem = PlacedSignatureItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      pageIndex: _currentPageIndex,
      normX: 0.36,
      normY: 0.65,
      normWidth: widthPercent,
      normHeight: heightPercent,
      imageBytes: imageBytes,
      label: label,
    );

    setState(() {
      _placedItems.add(newItem);
      _selectedItemId = newItem.id;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label placed! Drag to position or resize using corners.'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.sageGreen,
      ),
    );
  }

  Future<void> _openSignatureCreator() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SignatureCreatorModal(
        onSignatureReady: (bytes, label) {
          Navigator.of(ctx).pop();
          _addPlacedItem(imageBytes: bytes, label: label);
        },
      ),
    );
  }

  Future<void> _addDateStamp() async {
    final today = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final datePng = await _renderTextToPng(
      today,
      GoogleFonts.roboto(fontSize: 22, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
      const Size(180, 50),
    );
    _addPlacedItem(
      imageBytes: datePng,
      label: 'Date ($today)',
      widthPercent: 0.22,
      heightPercent: 0.06,
    );
  }

  Future<void> _saveAndExport() async {
    if (_pageImages.isEmpty) return;

    final progressDialog = ExportProgressDialog(
      context,
      title: 'Exporting Signed Document',
      initialStatus: 'Compositing signatures...',
    );
    progressDialog.show();

    try {
      final signedPdfBytes = await PdfService().createSignedPdf(
        pageImages: _pageImages,
        items: _placedItems,
        onProgress: (pct, msg) => progressDialog.update(pct, msg),
      );

      progressDialog.update(0.80, 'Saving document...');
      final baseName = _docName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
      final outFileName = '${baseName}_Signed.pdf';

      final savedItem = await StorageService().saveFile(
        fileName: outFileName,
        bytes: signedPdfBytes,
        type: 'pdf',
        subtitle: 'Signed PDF (${_pageImages.length} page${_pageImages.length > 1 ? "s" : ""}, ${_placedItems.length} sign/stamp)',
      );

      await progressDialog.complete('Document Signed!');

      if (!mounted) return;
      saver.saveAndDownloadFile(fileName: outFileName, bytes: signedPdfBytes);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Document exported successfully: $outFileName'),
          backgroundColor: AppColors.sageGreen,
          action: SnackBarAction(
            label: 'Open',
            textColor: Colors.white,
            onPressed: () => StorageService().openFile(savedItem.filePath, item: savedItem),
          ),
        ),
      );
    } catch (e) {
      progressDialog.dismiss();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: PageLabAppBar(
        title: 'Sign PDF & Document',
        subtitle: _docBytes != null
            ? '$_docName • ${_pageImages.length} Page${_pageImages.length > 1 ? "s" : ""}'
            : null,
        actions: [
          if (_docBytes != null) ...[
            IconButton(
              tooltip: 'Change Document',
              icon: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDarkElevated : AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.folder_open_rounded, size: 18),
              ),
              onPressed: _pickDocument,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: _docBytes == null
          ? ToolEmptyState(
              title: 'Upload Document to Sign',
              subtitle: 'Place digital signatures, handwritten marks, and date stamps on PDF pages or photos.',
              icon: Icons.draw_rounded,
              iconColor: AppColors.primary,
              iconBgColor: AppColors.primaryContainer,
              buttonText: 'Select PDF or Document',
              buttonIcon: Icons.add_circle_outline_rounded,
              onSelect: _pickDocument,
              supportedFormats: const ['PDF', 'JPG', 'PNG'],
            )
          : _isLoadingDoc
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading document pages...', style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              : _buildDocumentWorkspace(isDark),
      bottomNavigationBar: _docBytes != null && _pageImages.isNotEmpty
          ? _buildBottomActionBar(isDark)
          : null,
    );
  }

  Widget _buildDocumentWorkspace(bool isDark) {
    final currentPageItems = _placedItems.where((it) => it.pageIndex == _currentPageIndex).toList();

    return Column(
      children: [
        // Top Page Navigator Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                onPressed: _currentPageIndex > 0
                    ? () => setState(() => _currentPageIndex--)
                    : null,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDarkElevated : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Page ${_currentPageIndex + 1} of ${_pageImages.length}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onPressed: _currentPageIndex < _pageImages.length - 1
                    ? () => setState(() => _currentPageIndex++)
                    : null,
              ),
            ],
          ),
        ),

        // Interactive Page Canvas
        Expanded(
          child: Container(
            color: isDark ? const Color(0xFF141318) : const Color(0xFFF1F5F9),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Max page display size (standard A4 proportion)
                        final maxW = math.min(constraints.maxWidth, 680.0);
                        final pageImg = _pageImages[_currentPageIndex];

                        return ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxW),
                          child: AspectRatio(
                            // Maintain aspect ratio of the page image
                            aspectRatio: 1 / 1.414, // standard A4
                            child: LayoutBuilder(
                              builder: (ctx, boxConstraints) {
                                final canvasW = boxConstraints.maxWidth;
                                final canvasH = boxConstraints.maxHeight;

                                return Stack(
                                  children: [
                                    // Base Document Page with RepaintBoundary
                                    Positioned.fill(
                                      child: RepaintBoundary(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.memory(
                                            pageImg,
                                            fit: BoxFit.fill,
                                            gaplessPlayback: true,
                                            filterQuality: FilterQuality.medium,
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Placed Signatures / Stamps
                                    for (final item in currentPageItems)
                                      _DraggablePlacedItemWidget(
                                        key: ValueKey(item.id),
                                        item: item,
                                        canvasW: canvasW,
                                        canvasH: canvasH,
                                        isSelected: _selectedItemId == item.id,
                                        onSelected: () => setState(() => _selectedItemId = item.id),
                                        onDelete: () {
                                          setState(() {
                                            _placedItems.removeWhere((i) => i.id == item.id);
                                            if (_selectedItemId == item.id) _selectedItemId = null;
                                          });
                                        },
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDarkElevated : Colors.white,
        border: Border(top: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openSignatureCreator,
                icon: const Icon(Icons.draw_rounded, size: 18),
                label: const Text('Add Signature', style: TextStyle(fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _addDateStamp,
              icon: const Icon(Icons.calendar_today_rounded, size: 16),
              label: const Text('Date', style: TextStyle(fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _saveAndExport,
                icon: const Icon(Icons.download_rounded, size: 18, color: Colors.white),
                label: const Text('Export Signed', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraggablePlacedItemWidget extends StatefulWidget {
  final PlacedSignatureItem item;
  final double canvasW;
  final double canvasH;
  final bool isSelected;
  final VoidCallback onSelected;
  final VoidCallback onDelete;

  const _DraggablePlacedItemWidget({
    super.key,
    required this.item,
    required this.canvasW,
    required this.canvasH,
    required this.isSelected,
    required this.onSelected,
    required this.onDelete,
  });

  @override
  State<_DraggablePlacedItemWidget> createState() => _DraggablePlacedItemWidgetState();
}

class _DraggablePlacedItemWidgetState extends State<_DraggablePlacedItemWidget> {
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final canvasW = widget.canvasW;
    final canvasH = widget.canvasH;
    final isSelected = widget.isSelected;

    final itemW = item.normWidth * canvasW;
    final itemH = item.normHeight * canvasH;
    final itemLeft = (item.normX * canvasW).clamp(0.0, canvasW - itemW);
    final itemTop = (item.normY * canvasH).clamp(0.0, canvasH - itemH);

    return Positioned(
      left: itemLeft,
      top: itemTop,
      width: itemW,
      height: itemH,
      child: GestureDetector(
        onTap: widget.onSelected,
        onPanUpdate: (details) {
          setState(() {
            item.normX = ((item.normX * canvasW + details.delta.dx) / canvasW).clamp(0.0, 1.0 - item.normWidth);
            item.normY = ((item.normY * canvasH + details.delta.dy) / canvasH).clamp(0.0, 1.0 - item.normHeight);
          });
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Signature visual container
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  width: 1.5,
                ),
                color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Image.memory(
                item.imageBytes,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                gaplessPlayback: true,
              ),
            ),

            // Delete badge on top right
            if (isSelected)
              Positioned(
                top: -12,
                right: -12,
                child: GestureDetector(
                  onTap: widget.onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                  ),
                ),
              ),

            // Resize handle on bottom right
            if (isSelected)
              Positioned(
                bottom: -8,
                right: -8,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      final newW = ((item.normWidth * canvasW + details.delta.dx) / canvasW).clamp(0.10, 0.70);
                      final newH = ((item.normHeight * canvasH + details.delta.dy) / canvasH).clamp(0.04, 0.40);
                      item.normWidth = newW;
                      item.normHeight = newH;
                    });
                  },
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.open_in_full_rounded, size: 12, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Modal Sheet to Draw, Type, or Upload a Signature
class _SignatureCreatorModal extends StatefulWidget {
  final Function(Uint8List bytes, String label) onSignatureReady;

  const _SignatureCreatorModal({required this.onSignatureReady});

  @override
  State<_SignatureCreatorModal> createState() => _SignatureCreatorModalState();
}

class _SignatureCreatorModalState extends State<_SignatureCreatorModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Draw Mode state
  final List<List<Offset>> _strokes = [];
  Color _selectedPenColor = const Color(0xFF1E293B); // Deep Navy Black
  final double _strokeWidth = 3.0;

  // Type Mode state
  final TextEditingController _typeController = TextEditingController(text: 'John Doe');
  int _selectedFontStyleIndex = 0;

  final List<Color> _penColors = [
    const Color(0xFF0F172A), // Slate Black
    const Color(0xFF1D4ED8), // Royal Blue
    const Color(0xFFB91C1C), // Deep Crimson Red
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  Future<void> _finishDrawnSignature() async {
    if (_strokes.isEmpty) return;
    const size = Size(360, 160);
    final png = await _renderStrokesToPng(_strokes, _selectedPenColor, _strokeWidth, size);
    widget.onSignatureReady(png, 'Drawn Signature');
  }

  Future<void> _finishTypedSignature() async {
    final text = _typeController.text.trim();
    if (text.isEmpty) return;

    TextStyle fontStyle;
    switch (_selectedFontStyleIndex) {
      case 0:
        fontStyle = GoogleFonts.dancingScript(fontSize: 38, fontWeight: FontWeight.w700, color: _selectedPenColor);
        break;
      case 1:
        fontStyle = GoogleFonts.caveat(fontSize: 42, fontWeight: FontWeight.w700, color: _selectedPenColor);
        break;
      default:
        fontStyle = GoogleFonts.greatVibes(fontSize: 40, fontWeight: FontWeight.w500, color: _selectedPenColor);
        break;
    }

    const size = Size(360, 120);
    final png = await _renderTextToPng(text, fontStyle, size);
    widget.onSignatureReady(png, 'Typed Signature ($text)');
  }

  Future<void> _pickSignatureImage() async {
    final imageBytes = await FilePickerHelper.pickSingleImage();
    if (imageBytes != null) {
      final transparentBytes = _makeSignatureTransparent(imageBytes);
      widget.onSignatureReady(transparentBytes, 'Uploaded Signature');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 480,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDarkElevated : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            tabs: const [
              Tab(icon: Icon(Icons.draw_rounded), text: 'Draw'),
              Tab(icon: Icon(Icons.text_fields_rounded), text: 'Type'),
              Tab(icon: Icon(Icons.cloud_upload_outlined), text: 'Upload'),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDrawTab(isDark),
                _buildTypeTab(isDark),
                _buildUploadTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawTab(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Pen color & Stroke controls
          Row(
            children: [
              for (final c in _penColors) ...[
                GestureDetector(
                  onTap: () => setState(() => _selectedPenColor = c),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedPenColor == c ? AppColors.primary : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _strokes.clear()),
                icon: const Icon(Icons.clear_rounded, size: 16),
                label: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Drawing Area
          Expanded(
            child: _SmoothSignaturePad(
              strokes: _strokes,
              color: _selectedPenColor,
              strokeWidth: _strokeWidth,
              isDark: isDark,
              onStrokeChange: () => setState(() {}),
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _strokes.isEmpty ? null : _finishDrawnSignature,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Insert Signature', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTab(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _typeController,
            decoration: InputDecoration(
              labelText: 'Enter Full Name',
              hintText: 'e.g. Rahul Sharma',
              prefixIcon: const Icon(Icons.badge_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          // Color selector
          Row(
            children: [
              for (final c in _penColors) ...[
                GestureDetector(
                  onTap: () => setState(() => _selectedPenColor = c),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedPenColor == c ? AppColors.primary : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // Font previews
          Expanded(
            child: ListView(
              children: [
                _buildFontOption(0, 'Dancing Script', GoogleFonts.dancingScript(fontSize: 26, color: _selectedPenColor)),
                _buildFontOption(1, 'Caveat Script', GoogleFonts.caveat(fontSize: 28, color: _selectedPenColor)),
                _buildFontOption(2, 'Great Vibes', GoogleFonts.greatVibes(fontSize: 26, color: _selectedPenColor)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _typeController.text.trim().isEmpty ? null : _finishTypedSignature,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Insert Typed Signature', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFontOption(int index, String name, TextStyle style) {
    final isSelected = _selectedFontStyleIndex == index;
    final text = _typeController.text.trim().isEmpty ? 'Signature Preview' : _typeController.text.trim();

    return GestureDetector(
      onTap: () => setState(() => _selectedFontStyleIndex = index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
        ),
        child: Row(
          children: [
            Expanded(child: Text(text, style: style)),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadTab(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.photo_camera_back_outlined, size: 44, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'Upload Handwritten Signature',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              'Upload a photo of your signature on paper.\nBackground will be converted to transparent automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _pickSignatureImage,
              icon: const Icon(Icons.upload_file_rounded, size: 18, color: Colors.white),
              label: const Text('Browse Photo', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmoothSignaturePad extends StatefulWidget {
  final List<List<Offset>> strokes;
  final Color color;
  final double strokeWidth;
  final bool isDark;
  final VoidCallback onStrokeChange;

  const _SmoothSignaturePad({
    required this.strokes,
    required this.color,
    required this.strokeWidth,
    required this.isDark,
    required this.onStrokeChange,
  });

  @override
  State<_SmoothSignaturePad> createState() => _SmoothSignaturePadState();
}

class _SmoothSignaturePadState extends State<_SmoothSignaturePad> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E1D24) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) {
          widget.strokes.add([details.localPosition]);
          setState(() {});
          widget.onStrokeChange();
        },
        onPanUpdate: (details) {
          if (widget.strokes.isNotEmpty) {
            setState(() {
              widget.strokes.last.add(details.localPosition);
            });
          }
        },
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _StrokePainter(
              strokes: widget.strokes,
              color: widget.color,
              strokeWidth: widget.strokeWidth,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _StrokePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color color;
  final double strokeWidth;

  _StrokePainter({
    required this.strokes,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) => true;
}

Future<Uint8List> _renderStrokesToPng(
  List<List<Offset>> strokes,
  Color color,
  double strokeWidth,
  Size size,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size.width, size.height));
  final paint = Paint()
    ..color = color
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = strokeWidth
    ..style = PaintingStyle.stroke;

  for (final stroke in strokes) {
    if (stroke.length < 2) continue;
    final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
    for (int i = 1; i < stroke.length; i++) {
      path.lineTo(stroke[i].dx, stroke[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  final picture = recorder.endRecording();
  final imgObj = await picture.toImage(size.width.toInt(), size.height.toInt());
  final byteData = await imgObj.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

Future<Uint8List> _renderTextToPng(
  String text,
  TextStyle style,
  Size size,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size.width, size.height));
  final textPainter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: ui.TextDirection.ltr,
  )..layout(maxWidth: size.width);

  final offset = Offset(
    (size.width - textPainter.width) / 2,
    (size.height - textPainter.height) / 2,
  );
  textPainter.paint(canvas, offset);

  final picture = recorder.endRecording();
  final imgObj = await picture.toImage(size.width.toInt(), size.height.toInt());
  final byteData = await imgObj.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

Uint8List _makeSignatureTransparent(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  final rgba = decoded.convert(numChannels: 4);
  for (final p in rgba) {
    final luminance = (p.r * 0.299 + p.g * 0.587 + p.b * 0.114);
    if (luminance > 190) {
      p.a = 0; // Transparent paper
    } else {
      p.a = 255;
      final darkVal = (luminance * 0.6).round().clamp(0, 255);
      p.r = darkVal;
      p.g = darkVal;
      p.b = darkVal;
    }
  }
  return Uint8List.fromList(img.encodePng(rgba));
}
