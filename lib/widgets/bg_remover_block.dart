import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../theme/app_colors.dart';
import '../services/bg_remover_service.dart';
import '../services/file_picker_helper.dart';
import 'web_apk_notice_banner.dart';

enum BgBlockTool { autoCut, markerErase, markerRestore }

class BgRemoverBlock extends StatefulWidget {
  final Uint8List? initialBytes;
  final ValueChanged<Uint8List?>? onCutoutChanged;
  final bool showHeaderBanner;

  const BgRemoverBlock({
    super.key,
    this.initialBytes,
    this.onCutoutChanged,
    this.showHeaderBanner = true,
  });

  @override
  State<BgRemoverBlock> createState() => _BgRemoverBlockState();
}

class _BgRemoverBlockState extends State<BgRemoverBlock> {
  Uint8List? _originalBytes;
  Uint8List? _maskBytes; // 0 = Background, 255 = Subject
  Uint8List? _finalBytes;

  int _imgWidth = 1;
  int _imgHeight = 1;

  bool _isProcessing = false;
  BgBlockTool _activeTool = BgBlockTool.markerErase;
  double _tolerance = 35.0;
  double _brushRadius = 25.0;

  // Default Studio Background Color (Pure White)
  Color _selectedBgColor = Colors.white;

  final GlobalKey _imageKey = GlobalKey();
  Offset? _currentPointerPos;
  final List<Offset> _currentStroke = [];

  final List<Color> _presetColors = [
    Colors.white, // Pure White
    const Color(0xFFD0E8F2), // Soft Sky Blue
    const Color(0xFF1E88E5), // Studio Blue
    const Color(0xFFD32F2F), // Passport Red
    const Color(0xFF388E3C), // Studio Green
    Colors.transparent, // PNG Transparent
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialBytes != null) {
      _loadSource(widget.initialBytes!);
    }
  }

  @override
  void didUpdateWidget(covariant BgRemoverBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialBytes != null && widget.initialBytes != oldWidget.initialBytes) {
      _loadSource(widget.initialBytes!);
    }
  }

  void _loadSource(Uint8List bytes) {
    _originalBytes = bytes;
    final decoded = img.decodeImage(bytes);
    if (decoded != null) {
      _imgWidth = decoded.width;
      _imgHeight = decoded.height;
    }
    _runAutoCutout();
  }

  Future<void> _pickImage() async {
    final doc = await FilePickerHelper.pickSingleImageWithDetails();
    if (doc != null) {
      _loadSource(doc.bytes);
    }
  }

  Future<void> _runAutoCutout() async {
    if (_originalBytes == null) return;
    setState(() => _isProcessing = true);

    final maskResult = await BgRemoverService().generateInitialMask(
      imageBytes: _originalBytes!,
      tolerance: _tolerance.round(),
    );

    if (mounted && maskResult != null) {
      _maskBytes = maskResult.maskBytes;
      _imgWidth = maskResult.width;
      _imgHeight = maskResult.height;
      await _renderAndApplyColor();
    } else if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _renderAndApplyColor() async {
    if (_originalBytes == null || _maskBytes == null) {
      setState(() => _isProcessing = false);
      return;
    }

    final rendered = await BgRemoverService().renderMaskedImage(
      originalImageBytes: _originalBytes!,
      maskBytes: _maskBytes!,
      backgroundColor: _selectedBgColor,
    );

    if (mounted) {
      setState(() {
        _isProcessing = false;
        if (rendered != null) {
          _finalBytes = rendered;
        }
      });
      _notifyParent();
    }
  }

  Future<void> _changeBackgroundColor(Color color) async {
    setState(() {
      _selectedBgColor = color;
      _isProcessing = true;
    });
    await _renderAndApplyColor();
  }

  Rect? _getFittedImageRect(Size containerSize) {
    if (_imgWidth <= 0 || _imgHeight <= 0 || containerSize.width <= 0 || containerSize.height <= 0) return null;
    final double imgAspect = _imgWidth / _imgHeight;
    final double boxAspect = containerSize.width / containerSize.height;

    double renderW, renderH, offsetX, offsetY;
    if (imgAspect > boxAspect) {
      renderW = containerSize.width;
      renderH = containerSize.width / imgAspect;
      offsetX = 0;
      offsetY = (containerSize.height - renderH) / 2;
    } else {
      renderH = containerSize.height;
      renderW = containerSize.height * imgAspect;
      offsetX = (containerSize.width - renderW) / 2;
      offsetY = 0;
    }
    return Rect.fromLTWH(offsetX, offsetY, renderW, renderH);
  }

  void _onPanStart(DragStartDetails details) {
    if (_maskBytes == null || _originalBytes == null || _activeTool == BgBlockTool.autoCut) return;
    final RenderBox? box = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final Offset localPos = box.globalToLocal(details.globalPosition);
    setState(() {
      _currentPointerPos = localPos;
      _currentStroke.clear();
      _currentStroke.add(localPos);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_maskBytes == null || _originalBytes == null || _activeTool == BgBlockTool.autoCut) return;
    final RenderBox? box = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final Offset localPos = box.globalToLocal(details.globalPosition);
    setState(() {
      _currentPointerPos = localPos;
      _currentStroke.add(localPos);
    });
  }

  Future<void> _onPanEnd(DragEndDetails details) async {
    if (_maskBytes == null || _originalBytes == null || _currentStroke.isEmpty || _activeTool == BgBlockTool.autoCut) {
      setState(() {
        _currentPointerPos = null;
        _currentStroke.clear();
      });
      return;
    }

    final RenderBox? box = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final fittedRect = _getFittedImageRect(box.size);
    if (fittedRect == null) return;

    final pixelPoints = <Offset>[];
    for (final p in _currentStroke) {
      final relX = (p.dx - fittedRect.left) / fittedRect.width;
      final relY = (p.dy - fittedRect.top) / fittedRect.height;
      if (relX >= 0.0 && relX <= 1.0 && relY >= 0.0 && relY <= 1.0) {
        pixelPoints.add(Offset(relX * _imgWidth, relY * _imgHeight));
      }
    }

    setState(() {
      _currentPointerPos = null;
      _currentStroke.clear();
    });

    if (pixelPoints.isEmpty) return;

    setState(() => _isProcessing = true);

    final double scaleRatio = _imgWidth / fittedRect.width;
    final int scaledRadius = (_brushRadius * scaleRatio).round();

    final updatedMask = await BgRemoverService().updateMaskWithBrush(
      maskBytes: _maskBytes!,
      width: _imgWidth,
      height: _imgHeight,
      pixelPoints: pixelPoints,
      radius: scaledRadius,
      isEraser: _activeTool == BgBlockTool.markerErase,
    );

    if (mounted && updatedMask != null) {
      _maskBytes = updatedMask;
      await _renderAndApplyColor();
    } else if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  void _notifyParent() {
    if (widget.onCutoutChanged != null) {
      widget.onCutoutChanged!(_finalBytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDarkElevated : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Banner
          if (widget.showHeaderBanner) ...[
            const WebApkNoticeBanner(),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.sageGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.sageGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: AppColors.sageGreen, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'AI Background Remover & Marker Eraser Block',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textLight : AppColors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Background Color Palette Selector ABOVE Canvas
          if (_originalBytes != null) ...[
            Row(
              children: [
                Text(
                  'Desired Studio BG: ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isDark ? AppColors.textLight : AppColors.textDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _presetColors.map((color) => _buildColorButton(color)).toList(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Upload or Interactive Canvas
          if (_originalBytes == null)
            _buildUploadBox(isDark)
          else
            _buildCanvasSection(isDark),

          const SizedBox(height: 16),

          // Controls Toolbar when image is loaded
          if (_finalBytes != null) ...[
            // Tool selector tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    avatar: const Icon(Icons.cleaning_services_rounded, size: 16),
                    label: const Text('Auto AI Cut'),
                    selected: _activeTool == BgBlockTool.autoCut,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _activeTool = BgBlockTool.autoCut);
                        _runAutoCutout();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.edit_off_rounded, size: 16, color: Colors.redAccent),
                    label: const Text('Marker Eraser'),
                    selected: _activeTool == BgBlockTool.markerErase,
                    onSelected: (selected) => setState(() => _activeTool = BgBlockTool.markerErase),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.brush_rounded, size: 16, color: Colors.green),
                    label: const Text('Restore Brush'),
                    selected: _activeTool == BgBlockTool.markerRestore,
                    onSelected: (selected) => setState(() => _activeTool = BgBlockTool.markerRestore),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Brush Radius / Tolerance Sliders
            if (_activeTool != BgBlockTool.autoCut) ...[
              Row(
                children: [
                  const Text('Marker Eraser Size:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: _brushRadius,
                      min: 8,
                      max: 70,
                      divisions: 15,
                      label: '${_brushRadius.round()} px',
                      onChanged: (val) => setState(() => _brushRadius = val),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  const Text('AI Cut Sensitivity:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: _tolerance,
                      min: 10,
                      max: 75,
                      divisions: 13,
                      label: '${_tolerance.round()}',
                      onChanged: (val) {
                        setState(() => _tolerance = val);
                        _runAutoCutout();
                      },
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),

            // Change Photo Button
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image_outlined, size: 18),
              label: const Text('Change Photo'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUploadBox(bool isDark) {
    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_upload_rounded, color: AppColors.primary, size: 36),
            ),
            const SizedBox(height: 14),
            Text(
              'Upload Photo for Background Removal',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isDark ? AppColors.textLight : AppColors.textDark,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
              label: const Text('Select Photo to Begin', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvasSection(bool isDark) {
    final containerBg = _selectedBgColor == Colors.transparent
        ? (isDark ? AppColors.cardDarkElevated : Colors.grey.shade200)
        : _selectedBgColor;

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Container(
        key: _imageKey,
        height: 340,
        width: double.infinity,
        decoration: BoxDecoration(
          color: containerBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_selectedBgColor == Colors.transparent)
              CustomPaint(
                size: Size.infinite,
                painter: _CheckerboardPainter(),
              ),

            if (_isProcessing)
              const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 12),
                  Text('Processing Cutout...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              )
            else if (_finalBytes != null)
              Image.memory(_finalBytes!, fit: BoxFit.contain)
            else if (_originalBytes != null)
              Image.memory(_originalBytes!, fit: BoxFit.contain),

            // Real-Time Stroke Overlay while dragging mouse/finger
            if (_currentStroke.isNotEmpty && !_isProcessing)
              CustomPaint(
                size: Size.infinite,
                painter: _StrokePainter(
                  points: _currentStroke,
                  radius: _brushRadius,
                  color: _activeTool == BgBlockTool.markerErase
                      ? (_selectedBgColor == Colors.transparent ? Colors.red.withValues(alpha: 0.5) : _selectedBgColor)
                      : Colors.green.withValues(alpha: 0.5),
                ),
              ),

            // Visual Marker Circle Overlay during drag
            if (_currentPointerPos != null && !_isProcessing)
              Positioned(
                left: _currentPointerPos!.dx - _brushRadius,
                top: _currentPointerPos!.dy - _brushRadius,
                child: Container(
                  width: _brushRadius * 2,
                  height: _brushRadius * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _activeTool == BgBlockTool.markerErase
                        ? Colors.red.withValues(alpha: 0.35)
                        : Colors.green.withValues(alpha: 0.35),
                    border: Border.all(
                      color: _activeTool == BgBlockTool.markerErase ? Colors.red : Colors.green,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorButton(Color color) {
    final isSelected = _selectedBgColor == color;
    return GestureDetector(
      onTap: () => _changeBackgroundColor(color),
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: color == Colors.transparent ? Colors.grey.shade300 : color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade400,
            width: isSelected ? 3.0 : 1.2,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 6)]
              : [],
        ),
        child: color == Colors.transparent
            ? const Icon(Icons.grid_on_rounded, size: 14, color: Colors.black54)
            : isSelected
                ? Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                  )
                : null,
      ),
    );
  }
}

class _StrokePainter extends CustomPainter {
  final List<Offset> points;
  final double radius;
  final Color color;

  _StrokePainter({
    required this.points,
    required this.radius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = radius * 2
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _CheckerboardPainter extends CustomPainter {
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;

  @override
  void paint(Canvas canvas, Size size) {
    const double squareSize = 10.0;
    final paint1 = Paint()..color = Colors.white;
    final paint2 = Paint()..color = Colors.grey.shade300;

    for (double y = 0; y < size.height; y += squareSize) {
      for (double x = 0; x < size.width; x += squareSize) {
        final isEven = ((x / squareSize).floor() + (y / squareSize).floor()) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, squareSize, squareSize),
          isEven ? paint1 : paint2,
        );
      }
    }
  }
}
