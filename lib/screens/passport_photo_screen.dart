import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/passport_preset.dart';
import '../models/passport_person.dart';
import '../services/image_service.dart';
import '../services/pdf_service.dart';
import '../services/storage_service.dart';
import '../services/file_picker_helper.dart';
import 'package:printing/printing.dart';
import '../widgets/page_lab_app_bar.dart';
import '../widgets/bg_remover_block.dart';
import '../widgets/tool_empty_state.dart';
import '../widgets/export_progress_dialog.dart';

class PassportPhotoScreen extends StatefulWidget {
  final Uint8List? initialPhotoBytes;

  const PassportPhotoScreen({super.key, this.initialPhotoBytes});

  @override
  State<PassportPhotoScreen> createState() => _PassportPhotoScreenState();
}

class _PassportPhotoScreenState extends State<PassportPhotoScreen> {
  // Global Sheet Options
  bool _exportAsPdfSheet = true;
  bool _isProcessing = false;

  // View Mode: 0 = Edit Photo & Settings, 1 = Real Page Preview
  int _currentViewTab = 0;

  // Multi-person support list with independent settings per person
  final List<PassportPersonItem> _persons = [];
  int _selectedPersonIndex = 0;

  bool _showOriginalPreview = false;
  bool _showSilhouetteGuide = true;
  Timer? _reprocessDebounceTimer;
  double _startZoom = 1.0;
  bool _isDragging = false;

  String _customUnit = 'mm'; // 'mm' or 'cm'
  late final TextEditingController _customWidthController;
  late final TextEditingController _customHeightController;
  bool _isCustomMode = false;

  @override
  void initState() {
    super.initState();
    _customWidthController = TextEditingController(text: '35');
    _customHeightController = TextEditingController(text: '45');
    if (widget.initialPhotoBytes != null) {
      _addPersonFromBytes(widget.initialPhotoBytes!, name: 'Person 1');
    }
  }

  @override
  void dispose() {
    _reprocessDebounceTimer?.cancel();
    _customWidthController.dispose();
    _customHeightController.dispose();
    super.dispose();
  }

  PassportPersonItem? get _currentPerson {
    if (_persons.isEmpty) return null;
    if (_selectedPersonIndex >= _persons.length) {
      _selectedPersonIndex = _persons.length - 1;
    }
    return _persons[_selectedPersonIndex];
  }

  Future<void> _addPersonFromBytes(Uint8List bytes, {String? name}) async {
    final personName = name ?? 'Person ${_persons.length + 1}';
    final person = PassportPersonItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: personName,
      sourceBytes: bytes,
      preset: PassportPreset.presets[0],
      removeBackground: true,
      autoEnhance: true,
      copies: _persons.isEmpty ? 8 : 4,
      isProcessing: true,
    );

    setState(() {
      _persons.add(person);
      _selectedPersonIndex = _persons.length - 1;
    });

    await _processPerson(person);
  }

  Future<void> _processPerson(PassportPersonItem person) async {
    setState(() => person.isProcessing = true);

    try {
      final inputBytes = (person.removeBackground && person.cutoutBytes != null)
          ? person.cutoutBytes!
          : person.sourceBytes;

      final decoded = await Future.microtask(() => ImageService().decode(inputBytes));
      if (!mounted || decoded == null) {
        if (mounted) setState(() => person.isProcessing = false);
        return;
      }

      person.decodedSource = decoded;

      final processed = await Future.microtask(() {
        return ImageService().processPassportPhoto(
          src: decoded,
          targetAspectRatio: person.preset.aspectRatio,
          autoEnhance: person.autoEnhance,
          removeBackground: false,
          isFastPreview: false,
          panX: person.panX,
          panY: person.panY,
          zoom: person.zoom,
        );
      });

      final bytes = await Future.microtask(() {
        final format = (person.removeBackground && person.cutoutBytes != null)
            ? ImageOutputFormat.png
            : ImageOutputFormat.jpg;
        return ImageService().encode(
          processed,
          format: format,
          quality: 90,
        );
      });

      if (mounted) {
        setState(() {
          person.processedBytes = bytes;
          person.isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => person.isProcessing = false);
    }
  }

  void _scheduleReprocess(PassportPersonItem person) {
    _reprocessDebounceTimer?.cancel();
    _reprocessDebounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        _processPerson(person);
      }
    });
  }

  Future<void> _pickSingleOrMultiplePhotos() async {
    final images = await FilePickerHelper.pickMultipleImages();
    if (images.isNotEmpty) {
      for (int i = 0; i < images.length; i++) {
        await _addPersonFromBytes(images[i]);
      }
    }
  }

  void _removePerson(int index) {
    setState(() {
      _persons.removeAt(index);
      if (_persons.isNotEmpty && _selectedPersonIndex >= _persons.length) {
        _selectedPersonIndex = _persons.length - 1;
      } else if (_persons.isEmpty) {
        _selectedPersonIndex = 0;
      }
    });
  }

  int get _totalCopiesOnSheet {
    return _persons.fold(0, (sum, p) => sum + p.copies);
  }

  Future<Uint8List> _generatePdfBytes() async {
    final List<MultiPersonPhoto> sheetItems = [];
    for (final p in _persons) {
      if (p.copies > 0) {
        if (p.processedBytes == null) {
          await _processPerson(p);
        }
        final photoBytes = p.processedBytes ?? p.sourceBytes;
        sheetItems.add(MultiPersonPhoto(
          photoBytes: photoBytes,
          copies: p.copies,
          name: p.name,
          preset: p.preset,
        ));
      }
    }

    final defaultPreset = _currentPerson?.preset ?? PassportPreset.presets[0];
    return await PdfService().createMultiPersonPassportPrintSheet(
      persons: sheetItems,
      preset: defaultPreset,
      isA4: true,
    );
  }

  Future<void> _generateAndSave() async {
    if (_persons.isEmpty) return;

    final progressDialog = ExportProgressDialog(
      context,
      title: _exportAsPdfSheet ? 'Exporting Print Sheet' : 'Exporting Photo',
      initialStatus: 'Preparing photos...',
    );
    progressDialog.show();

    setState(() => _isProcessing = true);

    try {
      await Future.delayed(const Duration(milliseconds: 30));

      if (_exportAsPdfSheet) {
        progressDialog.update(0.20, 'Framing portraits...');
        final defaultPreset = _currentPerson?.preset ?? PassportPreset.presets[0];
        
        progressDialog.update(0.55, 'Generating A4 print layout...');
        final pdfBytes = await _generatePdfBytes();

        final fileName = _persons.length == 1
            ? 'Passport_${defaultPreset.country.replaceAll(' ', '_')}_Sheet.pdf'
            : 'Passport_Batch_${_persons.length}_People_Sheet.pdf';

        progressDialog.update(0.85, 'Saving to device...');
        final savedItem = await StorageService().saveFile(
          fileName: fileName,
          bytes: pdfBytes,
          type: 'pdf',
          subtitle: '${defaultPreset.label}, $_totalCopiesOnSheet Photos (${_persons.length} ${_persons.length == 1 ? "Person" : "People"})',
        );

        await progressDialog.complete('Sheet Ready!');

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print-ready sheet saved: $fileName (${savedItem.formattedSize})'),
            backgroundColor: AppColors.sageGreen,
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () => StorageService().openFile(savedItem.filePath),
            ),
          ),
        );
      } else {
        // Single selected person photo save
        progressDialog.update(0.25, 'Framing portrait photo...');
        final current = _currentPerson ?? _persons.first;
        if (current.processedBytes == null) {
          await _processPerson(current);
        }
        progressDialog.update(0.65, 'Encoding high-resolution image...');
        final photoBytes = current.processedBytes ?? current.sourceBytes;
        final ext = current.removeBackground ? 'png' : 'jpg';
        final fileName = 'Passport_${current.name.replaceAll(' ', '_')}_${current.preset.country.replaceAll(' ', '_')}.$ext';

        progressDialog.update(0.88, 'Saving file...');
        final savedItem = await StorageService().saveFile(
          fileName: fileName,
          bytes: photoBytes,
          type: 'image',
          subtitle: '${current.preset.label}, ${current.name}',
        );

        await progressDialog.complete('Photo Saved!');

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Passport photo saved: $fileName'),
            backgroundColor: AppColors.sageGreen,
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () => StorageService().openFile(savedItem.filePath),
            ),
          ),
        );
      }
    } catch (e) {
      progressDialog.dismiss();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating photo: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final current = _currentPerson;

    return Scaffold(
      appBar: PageLabAppBar(
        title: 'Passport Size Photo',
        subtitle: current?.preset.label,
        actions: [
          IconButton(
            tooltip: 'Add photo',
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDarkElevated : AppColors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_photo_alternate_outlined, size: 18),
            ),
            onPressed: _pickSingleOrMultiplePhotos,
          ),
          if (_persons.isNotEmpty)
            IconButton(
              tooltip: 'Reset',
              icon: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDarkElevated : AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.refresh_rounded, size: 18),
              ),
              onPressed: () {
                setState(() => _persons.clear());
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _persons.isEmpty
          ? _buildUploadPrompt(isDark)
          : LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 960;

                if (isDesktop) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: Studio Workspace Preview
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          child: Column(
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 500),
                                child: _buildViewTabSelector(isDark),
                              ),
                              const SizedBox(height: 16),
                              if (_currentViewTab == 1)
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 720),
                                  child: _buildRealPagePreviewSection(isDark),
                                )
                              else
                                _buildWorkspacePreview(current, isDark, isDesktop: true),
                            ],
                          ),
                        ),
                      ),

                      // Desktop Divider
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      ),

                      // Right: Studio Controls Sidebar
                      SizedBox(
                        width: 440,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMultiPersonStrip(isDark),
                              const SizedBox(height: 16),
                              if (current != null) ...[
                                _buildInspectorControls(current, isDark),
                                const SizedBox(height: 16),
                                _buildPrimaryGenerateButton(isDark),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }

                // Mobile / Narrow Layout
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          _buildMultiPersonStrip(isDark),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _buildViewTabSelector(isDark),
                          ),
                          const SizedBox(height: 12),
                          if (_currentViewTab == 1)
                            _buildRealPagePreviewSection(isDark)
                          else ...[
                            _buildWorkspacePreview(current, isDark, isDesktop: false),
                            const SizedBox(height: 16),
                            if (current != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: _buildInspectorControls(current, isDark),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: _buildPrimaryGenerateButton(isDark),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildInspectorControls(PassportPersonItem current, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
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
                      // Active Person Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Settings for: ${current.name}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${current.copies} copies',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Photo Size & Dimensions (Country Standard Presets vs Custom cm/mm)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Photo Size & Dimensions',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.cardDark : AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                              ),
                            ),
                            child: Row(
                              children: [
                                _buildModePill('Standard', !_isCustomMode, isDark, () {
                                  setState(() => _isCustomMode = false);
                                  if (current.preset.isCustom) {
                                    setState(() => current.preset = PassportPreset.presets[0]);
                                    _processPerson(current);
                                  }
                                }),
                                _buildModePill('Custom (cm/mm)', _isCustomMode, isDark, () {
                                  setState(() => _isCustomMode = true);
                                  _applyCustomSize(current);
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (!_isCustomMode) ...[
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
                            child: DropdownButton<PassportPreset>(
                              value: current.preset.isCustom ? PassportPreset.presets[0] : current.preset,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded),
                              items: PassportPreset.presets.map((preset) {
                                return DropdownMenuItem(
                                  value: preset,
                                  child: Text(preset.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => current.preset = val);
                                  _processPerson(current);
                                }
                              },
                            ),
                          ),
                        ),
                      ] else ...[
                        _buildCustomDimensionsCard(current, isDark),
                      ],

                      const SizedBox(height: 14),

                      // Copies for this current person
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.cardDark : AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Print Copies: ${current.name}',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                                    ),
                                    Text(
                                      'How many photos of ${current.name} to print',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.remove_circle_outline, size: 22),
                                      onPressed: current.copies > 1
                                          ? () => setState(() => current.copies--)
                                          : null,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${current.copies}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.add_circle_outline, size: 22),
                                      onPressed: () => setState(() => current.copies++),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [1, 2, 4, 6, 8, 12].map((count) {
                                final isSelected = current.copies == count;
                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => current.copies = count),
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 2),
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppColors.primary : (isDark ? AppColors.cardDarkElevated : Colors.white),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected ? AppColors.primary : (isDark ? AppColors.borderDark : AppColors.borderLight),
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '$count',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: isSelected ? Colors.white : (isDark ? AppColors.textLight : AppColors.textDark),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Dedicated Smart Background Remover Container for this person
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: current.removeBackground
                              ? (isDark
                                  ? AppColors.toolOrangeBg.withValues(alpha: 0.15)
                                  : const Color(0xFFFFF7F0))
                              : (isDark ? AppColors.cardDark : AppColors.surfaceMuted),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: current.removeBackground
                                ? AppColors.primary.withValues(alpha: 0.4)
                                : (isDark ? AppColors.borderDark : AppColors.borderLight),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: current.removeBackground ? AppColors.primary : Colors.grey.shade400,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.auto_fix_high_rounded, color: Colors.white, size: 18),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Background Remover',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                                  ),
                                ),
                                Switch(
                                  value: current.removeBackground,
                                  activeTrackColor: AppColors.primary,
                                  onChanged: (v) {
                                    setState(() => current.removeBackground = v);
                                    _processPerson(current);
                                  },
                                ),
                              ],
                            ),

                            if (current.removeBackground) ...[
                              const SizedBox(height: 14),
                              BgRemoverBlock(
                                key: ValueKey('${current.id}_${current.removeBackground}'),
                                initialBytes: current.sourceBytes,
                                showHeaderBanner: false,
                                onCutoutChanged: (cutoutBytes) {
                                  if (cutoutBytes != null && mounted) {
                                    setState(() {
                                      current.cutoutBytes = cutoutBytes;
                                    });
                                    _scheduleReprocess(current);
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Auto-enhance photo switch for this person
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Auto-enhance photo',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                          Switch(
                            value: current.autoEnhance,
                            activeTrackColor: AppColors.primary,
                            onChanged: (v) {
                              setState(() => current.autoEnhance = v);
                              _processPerson(current);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Dedicated Combined Print Sheet Card (Paper Saver)
                Container(
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.print_outlined, color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 10),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'A4 Print Sheet (Same Page)',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  'Pack all photos together to save paper',
                                  style: TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Switch(
                          value: _exportAsPdfSheet,
                          activeTrackColor: AppColors.primary,
                          onChanged: (v) => setState(() => _exportAsPdfSheet = v),
                        ),
                      ],
                    ),

                    if (_exportAsPdfSheet) ...[
                      const SizedBox(height: 14),

                      // Paper-saving notice box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.cardDark : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF86EFAC).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.eco_outlined, color: Color(0xFF16A34A), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _persons.length > 1
                                    ? 'Paper Saver: Photos of all ${_persons.length} people will be printed together on the same A4 page.'
                                    : 'All copies will be neatly arranged on a single printable sheet.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : const Color(0xFF15803D),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Capacity and total copies badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Copies per person on this sheet:',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$_totalCopiesOnSheet Photos Total (${(_totalCopiesOnSheet / 20).ceil()} A4 Page${(_totalCopiesOnSheet / 20).ceil() > 1 ? "s" : ""})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Per-person copy count rows
                      ..._persons.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final person = entry.value;
                        final isPersonSelected = idx == _selectedPersonIndex;

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isPersonSelected
                                ? AppColors.primary.withValues(alpha: 0.08)
                                : (isDark ? AppColors.cardDark : AppColors.surfaceMuted),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isPersonSelected
                                  ? AppColors.primary.withValues(alpha: 0.4)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  person.processedBytes ?? person.sourceBytes,
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      person.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: isPersonSelected ? AppColors.primary : null,
                                      ),
                                    ),
                                    Text(
                                      '${person.preset.country} (${person.preset.widthMm.toStringAsFixed(1).replaceAll(RegExp(r"\.0$"), "")} x ${person.preset.heightMm.toStringAsFixed(1).replaceAll(RegExp(r"\.0$"), "")} mm)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.remove_circle_outline, size: 20),
                                onPressed: person.copies > 1
                                    ? () => setState(() => person.copies--)
                                    : null,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.cardDarkElevated : Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                                ),
                                child: Text(
                                  '${person.copies}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.add_circle_outline, size: 20),
                                onPressed: () => setState(() => person.copies++),
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 14),

                      // Preview button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _showSheetLayoutPreview,
                          icon: const Icon(Icons.fullscreen_rounded, size: 20),
                          label: Text('Open Fullscreen Real Page Preview ($_totalCopiesOnSheet Photos on A4)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
  }

  Widget _buildPrimaryGenerateButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _generateAndSave,
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
                  Text('Generating Sheet...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _exportAsPdfSheet ? Icons.print_rounded : Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _exportAsPdfSheet
                        ? 'Generate & Save Sheet ($_totalCopiesOnSheet photos)'
                        : 'Generate & Save Photo',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildViewTabSelector(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDarkElevated : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentViewTab = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _currentViewTab == 0
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 16,
                      color: _currentViewTab == 0
                          ? Colors.white
                          : (isDark ? AppColors.textLight : AppColors.textDark),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Photo Settings',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _currentViewTab == 0
                            ? Colors.white
                            : (isDark ? AppColors.textLight : AppColors.textDark),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentViewTab = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _currentViewTab == 1
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.print_outlined,
                      size: 16,
                      color: _currentViewTab == 1
                          ? Colors.white
                          : (isDark ? AppColors.textLight : AppColors.textDark),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Real Page Preview',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _currentViewTab == 1
                            ? Colors.white
                            : (isDark ? AppColors.textLight : AppColors.textDark),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspacePreview(PassportPersonItem? current, bool isDark, {bool isDesktop = false}) {
    final double targetAspect = current?.preset.aspectRatio ?? (35.0 / 45.0);
    final double previewW = isDesktop ? 290.0 : 250.0;
    final double previewH = (previewW / targetAspect).clamp(240.0, 380.0);

    return Column(
      children: [
        // Photo Frame with Alignment Silhouette Guide
        Center(
          child: Container(
            width: previewW,
            height: previewH,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B1B26) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _isDragging
                    ? AppColors.primary
                    : (isDark ? AppColors.borderDark : const Color(0xFFDFD7CA)),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isDragging
                      ? AppColors.primary.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: MouseRegion(
                cursor: _isDragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
                child: Listener(
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent && current != null) {
                      setState(() {
                        final zoomDelta = -event.scrollDelta.dy * 0.0015;
                        current.zoom = (current.zoom + zoomDelta).clamp(1.0, 3.5);
                      });
                      _scheduleReprocess(current);
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: (details) {
                      if (current == null) return;
                      _startZoom = current.zoom;
                      setState(() => _isDragging = true);
                    },
                    onScaleUpdate: (details) {
                      if (current == null) return;
                      setState(() {
                        // Panning
                        final deltaX = details.focalPointDelta.dx / previewW;
                        final deltaY = details.focalPointDelta.dy / previewH;
                        current.panX = (current.panX + deltaX).clamp(-0.8, 0.8);
                        current.panY = (current.panY + deltaY).clamp(-0.8, 0.8);

                        // Pinch zoom
                        if (details.scale != 1.0) {
                          current.zoom = (_startZoom * details.scale).clamp(1.0, 3.5);
                        }
                      });
                      _scheduleReprocess(current);
                    },
                    onScaleEnd: (_) {
                      setState(() => _isDragging = false);
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Checkered pattern if transparent background is chosen
                        if (current?.removeBackground == true)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: const _CheckeredBackgroundPainter(squareSize: 8),
                            ),
                          ),

                        // Interactive Photo Preview with smooth Pan and Zoom
                        if (current != null)
                          Transform.translate(
                            offset: _showOriginalPreview
                                ? Offset.zero
                                : Offset(current.panX * previewW, current.panY * previewH),
                            child: Transform.scale(
                              scale: _showOriginalPreview ? 1.0 : current.zoom,
                              child: SizedBox(
                                width: previewW,
                                height: previewH,
                                child: Image.memory(
                                  _showOriginalPreview
                                      ? current.sourceBytes
                                      : ((current.removeBackground && current.cutoutBytes != null)
                                          ? current.cutoutBytes!
                                          : current.sourceBytes),
                                  fit: BoxFit.cover,
                                  alignment: const Alignment(0.0, -0.30),
                                  filterQuality: FilterQuality.medium,
                                ),
                              ),
                            ),
                          ),

                        // Silhouette Guide overlay
                        if (_showSilhouetteGuide)
                          IgnorePointer(
                            child: CustomPaint(
                              size: Size(previewW, previewH),
                              painter: _PassportGuidePainter(),
                            ),
                          ),

                        // Alignment drag feedback indicator
                        if (_isDragging)
                          IgnorePointer(
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.filter_center_focus_rounded,
                                  size: 32,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),

                        // Loading spinner
                        if (current?.isProcessing == true && !_isDragging)
                          Container(
                            color: Colors.black54,
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'Processing Photo...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Bottom "Hold to Compare" button
                        if (current != null &&
                            (current.removeBackground ||
                                current.panX != 0.0 ||
                                current.panY != 0.0 ||
                                current.zoom != 1.0))
                          Positioned(
                            bottom: 12,
                            child: GestureDetector(
                              onTapDown: (_) => setState(() => _showOriginalPreview = true),
                              onTapUp: (_) => setState(() => _showOriginalPreview = false),
                              onTapCancel: () => setState(() => _showOriginalPreview = false),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _showOriginalPreview
                                      ? AppColors.primary
                                      : Colors.black.withValues(alpha: 0.72),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white30, width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _showOriginalPreview
                                          ? Icons.visibility_rounded
                                          : Icons.compare_rounded,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _showOriginalPreview ? 'Showing Original' : 'Hold to View Original',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
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
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Quick Drag hint badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDarkElevated : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.touch_app_rounded, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Drag photo to center • Scroll or slider to zoom',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),

        // Dedicated Framing & Alignment Toolbar
        if (current != null)
          _buildAlignmentToolbar(current, isDark, isDesktop),

        const SizedBox(height: 14),

        // Quick Actions: Add multiple people or change photo
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _pickSingleOrMultiplePhotos,
              icon: const Icon(Icons.group_add_rounded, size: 18),
              label: Text(
                _persons.length <= 1 ? 'Add More People' : 'Add Person (${_persons.length})',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final bytes = await FilePickerHelper.pickSingleImage();
                if (bytes != null && current != null) {
                  current.sourceBytes = bytes;
                  current.cutoutBytes = null;
                  current.resetAlignment();
                  await _processPerson(current);
                }
              },
              icon: const Icon(Icons.sync_rounded, size: 16),
              label: const Text('Change This Photo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? AppColors.textLight : AppColors.textDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAlignmentToolbar(PassportPersonItem current, bool isDark, bool isDesktop) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: isDesktop ? 360 : 320),
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDarkElevated : Colors.white,
          borderRadius: BorderRadius.circular(18),
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
          children: [
            // Row 1: Center Photo button, Guide toggle, Reset button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Center Align button
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      current.panX = 0.0;
                      current.panY = 0.0;
                    });
                    _scheduleReprocess(current);
                  },
                  icon: const Icon(Icons.filter_center_focus_rounded, size: 15),
                  label: const Text('Center Photo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),

                // Guide toggle button
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _showSilhouetteGuide = !_showSilhouetteGuide);
                  },
                  icon: Icon(
                    _showSilhouetteGuide ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                    size: 14,
                    color: _showSilhouetteGuide ? AppColors.primary : (isDark ? AppColors.textMutedDark : AppColors.textMuted),
                  ),
                  label: Text(
                    _showSilhouetteGuide ? 'Guide: On' : 'Guide: Off',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textLight : AppColors.textDark,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(
                      color: _showSilhouetteGuide ? AppColors.primary.withValues(alpha: 0.5) : (isDark ? AppColors.borderDark : AppColors.borderLight),
                    ),
                  ),
                ),

                // Reset button
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      current.resetAlignment();
                    });
                    _scheduleReprocess(current);
                  },
                  icon: const Icon(Icons.replay_rounded, size: 14),
                  label: const Text('Reset', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Row 2: Zoom Slider & Controls
            Row(
              children: [
                Text(
                  'Zoom',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'Zoom Out',
                  icon: const Icon(Icons.remove_circle_outline_rounded, size: 16),
                  onPressed: current.zoom > 1.0
                      ? () {
                          setState(() {
                            current.zoom = (current.zoom - 0.1).clamp(1.0, 3.5);
                          });
                          _scheduleReprocess(current);
                        }
                      : null,
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2.5,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    ),
                    child: Slider(
                      value: current.zoom.clamp(1.0, 3.5),
                      min: 1.0,
                      max: 3.5,
                      divisions: 25,
                      activeColor: AppColors.primary,
                      onChanged: (v) {
                        setState(() => current.zoom = v);
                        _scheduleReprocess(current);
                      },
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'Zoom In',
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                  onPressed: current.zoom < 3.5
                      ? () {
                          setState(() {
                            current.zoom = (current.zoom + 0.1).clamp(1.0, 3.5);
                          });
                          _scheduleReprocess(current);
                        }
                      : null,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${current.zoom.toStringAsFixed(1)}x',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Row 3: Directional Nudge Pad (Compact arrow buttons)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Fine Nudge:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 8),
                _buildNudgeButton(Icons.arrow_back_rounded, 'Move Left', () {
                  setState(() => current.panX = (current.panX - 0.03).clamp(-0.8, 0.8));
                  _scheduleReprocess(current);
                }, isDark),
                const SizedBox(width: 4),
                _buildNudgeButton(Icons.arrow_upward_rounded, 'Move Up', () {
                  setState(() => current.panY = (current.panY - 0.03).clamp(-0.8, 0.8));
                  _scheduleReprocess(current);
                }, isDark),
                const SizedBox(width: 4),
                _buildNudgeButton(Icons.arrow_downward_rounded, 'Move Down', () {
                  setState(() => current.panY = (current.panY + 0.03).clamp(-0.8, 0.8));
                  _scheduleReprocess(current);
                }, isDark),
                const SizedBox(width: 4),
                _buildNudgeButton(Icons.arrow_forward_rounded, 'Move Right', () {
                  setState(() => current.panX = (current.panX + 0.03).clamp(-0.8, 0.8));
                  _scheduleReprocess(current);
                }, isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNudgeButton(IconData icon, String tooltip, VoidCallback onPressed, bool isDark) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
              width: 0.8,
            ),
          ),
          child: Icon(icon, size: 13, color: isDark ? AppColors.textLight : AppColors.textDark),
        ),
      ),
    );
  }

  Widget _buildUploadPrompt(bool isDark) {
    return ToolEmptyState(
      title: 'Select Photo for Passport & Visa Maker',
      subtitle: 'Upload portrait photos to generate biometric-compliant passport photos with background replacement and print-ready sheets.',
      icon: Icons.account_box_rounded,
      iconColor: AppColors.toolRedIcon,
      iconBgColor: AppColors.toolRedBg,
      buttonText: 'Select Portrait Photo(s)',
      onSelect: _pickSingleOrMultiplePhotos,
    );
  }

  Widget _buildMultiPersonStrip(bool isDark) {
    return Container(
      height: 104,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _persons.length + 1,
        itemBuilder: (context, index) {
          if (index == _persons.length) {
            // Add Person Button
            return Container(
              margin: const EdgeInsets.only(left: 6, top: 6, bottom: 6),
              child: InkWell(
                onTap: _pickSingleOrMultiplePhotos,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 76,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDarkElevated : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, color: AppColors.primary, size: 28),
                      SizedBox(height: 4),
                      Text(
                        '+ Person',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final person = _persons[index];
          final isSelected = index == _selectedPersonIndex;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: () => setState(() => _selectedPersonIndex = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  width: 78,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : (isDark ? AppColors.cardDark : Colors.white),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : (isDark ? AppColors.borderDark : AppColors.borderLight),
                      width: isSelected ? 2.5 : 1.2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          person.processedBytes ?? person.sourceBytes,
                          width: 42,
                          height: 42,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          person.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? AppColors.primary : (isDark ? AppColors.textLight : AppColors.textDark),
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : (isDark ? Colors.white12 : Colors.black12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${person.copies} prints',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _removePerson(index),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 13, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRealPagePreviewSection(bool isDark) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          height: 520,
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDarkElevated : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: PdfPreview(
              key: ValueKey('preview_${_persons.length}_$_totalCopiesOnSheet'),
              build: (format) async => await _generatePdfBytes(),
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              allowPrinting: true,
              allowSharing: true,
              maxPageWidth: 460,
              pdfFileName: 'PageLab_Passport_Photos.pdf',
              previewPageMargin: const EdgeInsets.all(12),
              loadingWidget: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text(
                      'Rendering Real A4 Page Preview...',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showSheetLayoutPreview,
              icon: const Icon(Icons.fullscreen_rounded, size: 20),
              label: const Text('Open Fullscreen Real Page Preview'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showSheetLayoutPreview() {
    if (_persons.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: PageLabAppBar(
            title: 'Real Page Print Preview',
            subtitle: '$_totalCopiesOnSheet Photos on A4 Sheet',
          ),
          body: PdfPreview(
            build: (format) async => await _generatePdfBytes(),
            canChangeOrientation: false,
            canChangePageFormat: false,
            canDebug: false,
            allowPrinting: true,
            allowSharing: true,
            maxPageWidth: 700,
            pdfFileName: 'PageLab_Passport_Photos.pdf',
            previewPageMargin: const EdgeInsets.all(16),
            loadingWidget: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text(
                    'Generating Real Page Preview...',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            actions: [
              PdfPreviewAction(
                icon: const Icon(Icons.download_rounded),
                onPressed: (context, build, pageFormat) async {
                  await _generateAndSave();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModePill(String label, bool isSelected, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.textMutedDark : AppColors.textMuted),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomDimensionsCard(PassportPersonItem current, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Unit of Measurement',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textLight : AppColors.textDark,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDarkElevated : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Row(
                  children: [
                    _buildUnitOption('mm', current, isDark),
                    _buildUnitOption('cm', current, isDark),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Two input fields: Breadth (Width) and Length (Height)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Breadth (Width)',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _customWidthController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        suffixText: _customUnit,
                        suffixStyle: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      onChanged: (_) => _applyCustomSize(current),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Length (Height)',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _customHeightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        suffixText: _customUnit,
                        suffixStyle: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      onChanged: (_) => _applyCustomSize(current),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Quick preset buttons for common custom sizes
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildQuickCustomSizeButton('35 x 45 mm', 35, 45, 'mm', current),
              _buildQuickCustomSizeButton('3.5 x 4.5 cm', 3.5, 4.5, 'cm', current),
              _buildQuickCustomSizeButton('50 x 50 mm', 50, 50, 'mm', current),
              _buildQuickCustomSizeButton('5.0 x 5.0 cm', 5.0, 5.0, 'cm', current),
              _buildQuickCustomSizeButton('30 x 40 mm', 30, 40, 'mm', current),
              _buildQuickCustomSizeButton('40 x 60 mm', 40, 60, 'mm', current),
            ],
          ),

          const SizedBox(height: 10),
          // Live Size Summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.straighten_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Active Size: ${current.preset.widthMm.toStringAsFixed(1).replaceAll(RegExp(r"\.0$"), "")} x ${current.preset.heightMm.toStringAsFixed(1).replaceAll(RegExp(r"\.0$"), "")} mm (${(current.preset.widthMm / 10).toStringAsFixed(1)} x ${(current.preset.heightMm / 10).toStringAsFixed(1)} cm)',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitOption(String unit, PassportPersonItem current, bool isDark) {
    final isSelected = _customUnit == unit;
    return GestureDetector(
      onTap: () => _onUnitChanged(unit, current),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          unit.toUpperCase(),
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.textMutedDark : AppColors.textMuted),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickCustomSizeButton(
    String label,
    double w,
    double h,
    String unit,
    PassportPersonItem current,
  ) {
    return ActionChip(
      visualDensity: VisualDensity.compact,
      label: Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
      onPressed: () {
        setState(() {
          _customUnit = unit;
          _customWidthController.text = w.toString();
          _customHeightController.text = h.toString();
        });
        _applyCustomSize(current);
      },
    );
  }

  void _onUnitChanged(String newUnit, PassportPersonItem current) {
    if (newUnit == _customUnit) return;
    final currentW = double.tryParse(_customWidthController.text) ?? (_customUnit == 'cm' ? 3.5 : 35.0);
    final currentH = double.tryParse(_customHeightController.text) ?? (_customUnit == 'cm' ? 4.5 : 45.0);

    setState(() {
      _customUnit = newUnit;
      if (newUnit == 'cm') {
        // mm to cm: divide by 10
        _customWidthController.text = (currentW / 10.0).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
        _customHeightController.text = (currentH / 10.0).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
      } else {
        // cm to mm: multiply by 10
        _customWidthController.text = (currentW * 10.0).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
        _customHeightController.text = (currentH * 10.0).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
      }
    });
    _applyCustomSize(current);
  }

  void _applyCustomSize(PassportPersonItem current) {
    final w = double.tryParse(_customWidthController.text);
    final h = double.tryParse(_customHeightController.text);
    if (w == null || h == null || w <= 0 || h <= 0) return;

    final newPreset = PassportPreset.createCustom(
      width: w,
      height: h,
      unit: _customUnit,
    );

    setState(() {
      current.preset = newPreset;
    });
    _processPerson(current);
  }
}

class _CheckeredBackgroundPainter extends CustomPainter {
  final double squareSize;
  const _CheckeredBackgroundPainter({this.squareSize = 8.0});

  @override
  void paint(Canvas canvas, Size size) {
    final lightPaint = Paint()..color = const Color(0xFFF0F0F2);
    final darkPaint = Paint()..color = const Color(0xFFDCDCE0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), lightPaint);

    final cols = (size.width / squareSize).ceil();
    final rows = (size.height / squareSize).ceil();

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if ((r + c) % 2 == 1) {
          canvas.drawRect(
            Rect.fromLTWH(c * squareSize, r * squareSize, squareSize, squareSize),
            darkPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PassportGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(size.width / 2, size.height * 0.42);
    final ovalRect = Rect.fromCenter(
      center: center,
      width: size.width * 0.58,
      height: size.height * 0.52,
    );
    canvas.drawOval(ovalRect, paint);

    // Eye line guideline
    canvas.drawLine(
      Offset(size.width * 0.25, size.height * 0.40),
      Offset(size.width * 0.75, size.height * 0.40),
      dashPaint,
    );

    // Chin guideline
    canvas.drawLine(
      Offset(size.width * 0.35, size.height * 0.68),
      Offset(size.width * 0.65, size.height * 0.68),
      dashPaint,
    );

    // Shoulder arch
    final shoulderPath = Path();
    shoulderPath.moveTo(size.width * 0.05, size.height);
    shoulderPath.quadraticBezierTo(
      size.width * 0.2,
      size.height * 0.76,
      size.width * 0.35,
      size.height * 0.74,
    );
    shoulderPath.moveTo(size.width * 0.65, size.height * 0.74);
    shoulderPath.quadraticBezierTo(
      size.width * 0.8,
      size.height * 0.76,
      size.width * 0.95,
      size.height,
    );
    canvas.drawPath(shoulderPath, dashPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
