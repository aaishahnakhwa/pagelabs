import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../theme/app_colors.dart';
import '../services/image_service.dart';
import '../services/storage_service.dart';
import '../services/file_picker_helper.dart';
import '../widgets/page_lab_app_bar.dart';
import '../widgets/tool_empty_state.dart';
import '../widgets/export_progress_dialog.dart';

class CropResizeScreen extends StatefulWidget {
  final Uint8List? initialImageBytes;

  const CropResizeScreen({super.key, this.initialImageBytes});

  @override
  State<CropResizeScreen> createState() => _CropResizeScreenState();
}

class _CropResizeScreenState extends State<CropResizeScreen> {
  Uint8List? _imageBytes;
  img.Image? _decodedImage;

  // Transform states
  int _rotationAngle = 0;
  bool _isFlippedH = false;
  bool _isFlippedV = false;

  // Aspect ratio states
  String _selectedRatio = 'Free';
  double? _targetAspectRatio;

  // Crop rectangle in normalized 0.0 - 1.0 coordinates
  Rect _cropRect = const Rect.fromLTWH(0.08, 0.08, 0.84, 0.84);

  // Resize controllers
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  bool _maintainAspect = true;

  // Export settings
  ImageOutputFormat _outputFormat = ImageOutputFormat.jpg;
  double _quality = 90;
  int? _targetKb; // null = standard quality slider, or e.g. 20, 50, 100, 200, 500 KB
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialImageBytes != null) {
      _loadImage(widget.initialImageBytes!);
    }
  }

  void _loadImage(Uint8List bytes) {
    setState(() {
      _imageBytes = bytes;
      _decodedImage = ImageService().decode(bytes);
      if (_decodedImage != null) {
        _widthController.text = _decodedImage!.width.toString();
        _heightController.text = _decodedImage!.height.toString();
      }
      _cropRect = const Rect.fromLTWH(0.06, 0.06, 0.88, 0.88);
      _rotationAngle = 0;
      _isFlippedH = false;
      _isFlippedV = false;
    });
  }

  Future<void> _pickImage() async {
    final bytes = await FilePickerHelper.pickSingleImage();
    if (bytes != null) {
      _loadImage(bytes);
    }
  }

  void _setAspectRatio(String label, double? ratio) {
    setState(() {
      _selectedRatio = label;
      _targetAspectRatio = ratio;

      if (ratio != null && _decodedImage != null) {
        final imgAspect = _decodedImage!.width / _decodedImage!.height;
        if (imgAspect > ratio) {
          final w = (_cropRect.height / imgAspect) * ratio;
          _cropRect = Rect.fromCenter(
            center: _cropRect.center,
            width: w.clamp(0.15, 0.95),
            height: _cropRect.height,
          );
        } else {
          final h = (_cropRect.width * imgAspect) / ratio;
          _cropRect = Rect.fromCenter(
            center: _cropRect.center,
            width: _cropRect.width,
            height: h.clamp(0.15, 0.95),
          );
        }
      }
    });
  }

  void _rotateClockwise() {
    setState(() {
      _rotationAngle = (_rotationAngle + 90) % 360;
    });
  }

  void _toggleFlipH() {
    setState(() {
      _isFlippedH = !_isFlippedH;
    });
  }

  void _toggleFlipV() {
    setState(() {
      _isFlippedV = !_isFlippedV;
    });
  }

  void _onPanCenter(DragUpdateDetails details, double renderW, double renderH) {
    if (renderW <= 0 || renderH <= 0) return;
    final dx = details.delta.dx / renderW;
    final dy = details.delta.dy / renderH;
    setState(() {
      final newL = (_cropRect.left + dx).clamp(0.0, 1.0 - _cropRect.width);
      final newT = (_cropRect.top + dy).clamp(0.0, 1.0 - _cropRect.height);
      _cropRect = Rect.fromLTWH(newL, newT, _cropRect.width, _cropRect.height);
    });
  }

  void _onPanTop(DragUpdateDetails details, double renderW, double renderH) {
    if (renderW <= 0 || renderH <= 0) return;
    final dy = details.delta.dy / renderH;
    const minSize = 0.08;
    setState(() {
      double newTop = (_cropRect.top + dy).clamp(0.0, _cropRect.bottom - minSize);
      double newHeight = _cropRect.bottom - newTop;
      double newLeft = _cropRect.left;
      double newWidth = _cropRect.width;

      if (_targetAspectRatio != null) {
        final imgAspect = renderW / renderH;
        newWidth = (newHeight * _targetAspectRatio!) / imgAspect;
        if (newLeft + newWidth > 1.0) {
          newWidth = 1.0 - newLeft;
          newHeight = (newWidth / _targetAspectRatio!) * imgAspect;
          newTop = _cropRect.bottom - newHeight;
        }
      }
      _cropRect = Rect.fromLTWH(newLeft, newTop, newWidth, newHeight);
    });
  }

  void _onPanBottom(DragUpdateDetails details, double renderW, double renderH) {
    if (renderW <= 0 || renderH <= 0) return;
    final dy = details.delta.dy / renderH;
    const minSize = 0.08;
    setState(() {
      double newHeight = (_cropRect.height + dy).clamp(minSize, 1.0 - _cropRect.top);
      double newLeft = _cropRect.left;
      double newWidth = _cropRect.width;

      if (_targetAspectRatio != null) {
        final imgAspect = renderW / renderH;
        newWidth = (newHeight * _targetAspectRatio!) / imgAspect;
        if (newLeft + newWidth > 1.0) {
          newWidth = 1.0 - newLeft;
          newHeight = (newWidth / _targetAspectRatio!) * imgAspect;
        }
      }
      _cropRect = Rect.fromLTWH(newLeft, _cropRect.top, newWidth, newHeight);
    });
  }

  void _onPanLeft(DragUpdateDetails details, double renderW, double renderH) {
    if (renderW <= 0 || renderH <= 0) return;
    final dx = details.delta.dx / renderW;
    const minSize = 0.08;
    setState(() {
      double newLeft = (_cropRect.left + dx).clamp(0.0, _cropRect.right - minSize);
      double newWidth = _cropRect.right - newLeft;
      double newTop = _cropRect.top;
      double newHeight = _cropRect.height;

      if (_targetAspectRatio != null) {
        final imgAspect = renderW / renderH;
        newHeight = (newWidth / _targetAspectRatio!) * imgAspect;
        if (newTop + newHeight > 1.0) {
          newHeight = 1.0 - newTop;
          newWidth = (newHeight * _targetAspectRatio!) / imgAspect;
          newLeft = _cropRect.right - newWidth;
        }
      }
      _cropRect = Rect.fromLTWH(newLeft, newTop, newWidth, newHeight);
    });
  }

  void _onPanRight(DragUpdateDetails details, double renderW, double renderH) {
    if (renderW <= 0 || renderH <= 0) return;
    final dx = details.delta.dx / renderW;
    const minSize = 0.08;
    setState(() {
      double newWidth = (_cropRect.width + dx).clamp(minSize, 1.0 - _cropRect.left);
      double newTop = _cropRect.top;
      double newHeight = _cropRect.height;

      if (_targetAspectRatio != null) {
        final imgAspect = renderW / renderH;
        newHeight = (newWidth / _targetAspectRatio!) * imgAspect;
        if (newTop + newHeight > 1.0) {
          newHeight = 1.0 - newTop;
          newWidth = (newHeight * _targetAspectRatio!) / imgAspect;
        }
      }
      _cropRect = Rect.fromLTWH(_cropRect.left, newTop, newWidth, newHeight);
    });
  }

  void _onPanTopLeft(DragUpdateDetails details, double renderW, double renderH) {
    if (renderW <= 0 || renderH <= 0) return;
    final dx = details.delta.dx / renderW;
    final dy = details.delta.dy / renderH;
    const minSize = 0.08;
    setState(() {
      double newLeft = (_cropRect.left + dx).clamp(0.0, _cropRect.right - minSize);
      double newWidth = _cropRect.right - newLeft;
      double newTop;
      double newHeight;

      if (_targetAspectRatio != null) {
        final imgAspect = renderW / renderH;
        newHeight = (newWidth / _targetAspectRatio!) * imgAspect;
        newTop = _cropRect.bottom - newHeight;
        if (newTop < 0.0) {
          newTop = 0.0;
          newHeight = _cropRect.bottom;
          newWidth = (newHeight * _targetAspectRatio!) / imgAspect;
          newLeft = _cropRect.right - newWidth;
        }
      } else {
        newTop = (_cropRect.top + dy).clamp(0.0, _cropRect.bottom - minSize);
        newHeight = _cropRect.bottom - newTop;
      }
      _cropRect = Rect.fromLTWH(newLeft, newTop, newWidth, newHeight);
    });
  }

  void _onPanTopRight(DragUpdateDetails details, double renderW, double renderH) {
    if (renderW <= 0 || renderH <= 0) return;
    final dx = details.delta.dx / renderW;
    final dy = details.delta.dy / renderH;
    const minSize = 0.08;
    setState(() {
      double newWidth = (_cropRect.width + dx).clamp(minSize, 1.0 - _cropRect.left);
      double newTop;
      double newHeight;

      if (_targetAspectRatio != null) {
        final imgAspect = renderW / renderH;
        newHeight = (newWidth / _targetAspectRatio!) * imgAspect;
        newTop = _cropRect.bottom - newHeight;
        if (newTop < 0.0) {
          newTop = 0.0;
          newHeight = _cropRect.bottom;
          newWidth = (newHeight * _targetAspectRatio!) / imgAspect;
        }
      } else {
        newTop = (_cropRect.top + dy).clamp(0.0, _cropRect.bottom - minSize);
        newHeight = _cropRect.bottom - newTop;
      }
      _cropRect = Rect.fromLTWH(_cropRect.left, newTop, newWidth, newHeight);
    });
  }

  void _onPanBottomLeft(DragUpdateDetails details, double renderW, double renderH) {
    if (renderW <= 0 || renderH <= 0) return;
    final dx = details.delta.dx / renderW;
    final dy = details.delta.dy / renderH;
    const minSize = 0.08;
    setState(() {
      double newLeft = (_cropRect.left + dx).clamp(0.0, _cropRect.right - minSize);
      double newWidth = _cropRect.right - newLeft;
      double newHeight;

      if (_targetAspectRatio != null) {
        final imgAspect = renderW / renderH;
        newHeight = (newWidth / _targetAspectRatio!) * imgAspect;
        if (_cropRect.top + newHeight > 1.0) {
          newHeight = 1.0 - _cropRect.top;
          newWidth = (newHeight * _targetAspectRatio!) / imgAspect;
          newLeft = _cropRect.right - newWidth;
        }
      } else {
        newHeight = (_cropRect.height + dy).clamp(minSize, 1.0 - _cropRect.top);
      }
      _cropRect = Rect.fromLTWH(newLeft, _cropRect.top, newWidth, newHeight);
    });
  }

  void _onPanBottomRight(DragUpdateDetails details, double renderW, double renderH) {
    if (renderW <= 0 || renderH <= 0) return;
    final dx = details.delta.dx / renderW;
    final dy = details.delta.dy / renderH;
    const minSize = 0.08;
    setState(() {
      double newWidth = (_cropRect.width + dx).clamp(minSize, 1.0 - _cropRect.left);
      double newHeight;

      if (_targetAspectRatio != null) {
        final imgAspect = renderW / renderH;
        newHeight = (newWidth / _targetAspectRatio!) * imgAspect;
        if (_cropRect.top + newHeight > 1.0) {
          newHeight = 1.0 - _cropRect.top;
          newWidth = (newHeight * _targetAspectRatio!) / imgAspect;
        }
      } else {
        newHeight = (_cropRect.height + dy).clamp(minSize, 1.0 - _cropRect.top);
      }
      _cropRect = Rect.fromLTWH(_cropRect.left, _cropRect.top, newWidth, newHeight);
    });
  }

  void _resetCropToFull() {
    setState(() {
      _cropRect = const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0);
      _selectedRatio = 'Free';
      _targetAspectRatio = null;
    });
  }

  Widget _buildCornerHandleWidget({
    required double left,
    required double top,
    required IconData icon,
    required MouseCursor cursor,
    required GestureDragUpdateCallback onPanUpdate,
  }) {
    // 36x36 touch area, with sleek compact 20x20 visual handle
    return Positioned(
      left: left - 18,
      top: top - 18,
      width: 36,
      height: 36,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: onPanUpdate,
          child: Center(
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryLight, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                ],
              ),
              child: Center(
                child: Icon(icon, size: 11, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEdgeHandleWidget({
    required double left,
    required double top,
    required bool isHorizontal,
    required MouseCursor cursor,
    required GestureDragUpdateCallback onPanUpdate,
  }) {
    // 36x36 touch area, with compact 24x12 / 12x24 visual pill
    final hitW = isHorizontal ? 40.0 : 32.0;
    final hitH = isHorizontal ? 32.0 : 40.0;
    final visualW = isHorizontal ? 24.0 : 12.0;
    final visualH = isHorizontal ? 12.0 : 24.0;

    return Positioned(
      left: left - (hitW / 2),
      top: top - (hitH / 2),
      width: hitW,
      height: hitH,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: onPanUpdate,
          child: Center(
            child: Container(
              width: visualW,
              height: visualH,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.primary, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  isHorizontal ? Icons.swap_vert_rounded : Icons.swap_horiz_rounded,
                  size: 9,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveAndExport() async {
    if (_decodedImage == null) return;

    final dialog = ExportProgressDialog(
      context,
      title: 'Exporting Image',
      initialStatus: 'Processing image...',
    );
    dialog.show();

    setState(() => _isProcessing = true);

    try {
      dialog.update(0.20, 'Applying crop & transforms...');
      img.Image current = img.Image.from(_decodedImage!);

      if (_rotationAngle != 0) {
        current = ImageService().rotateImage(current, _rotationAngle);
      }
      if (_isFlippedH) {
        current = ImageService().flipImage(current, horizontal: true);
      }
      if (_isFlippedV) {
        current = ImageService().flipImage(current, horizontal: false);
      }

      final cropX = (_cropRect.left * current.width).round();
      final cropY = (_cropRect.top * current.height).round();
      final cropW = (_cropRect.width * current.width).round();
      final cropH = (_cropRect.height * current.height).round();

      current = ImageService().cropImage(
        src: current,
        x: cropX,
        y: cropY,
        width: cropW,
        height: cropH,
      );

      final targetW = int.tryParse(_widthController.text);
      final targetH = int.tryParse(_heightController.text);
      if (targetW != null && targetH != null && targetW > 0 && targetH > 0) {
        dialog.update(0.50, 'Resizing image...');
        current = ImageService().resizeImage(
          src: current,
          width: targetW,
          height: targetH,
          maintainAspect: _maintainAspect,
        );
      }

      dialog.update(
        0.75,
        _targetKb != null
            ? 'Compressing to under $_targetKb KB...'
            : 'Encoding ${_outputFormat.name.toUpperCase()} format...',
      );

      final Uint8List encodedBytes;
      if (_targetKb != null) {
        encodedBytes = ImageService().compressToTargetSize(
          current,
          targetKb: _targetKb!,
          format: _outputFormat,
        );
      } else {
        encodedBytes = ImageService().encode(
          current,
          format: _outputFormat,
          quality: _quality.round(),
        );
      }

      final ext = _outputFormat.name;
      final fileName = 'PageLab_${current.width}x${current.height}.$ext';

      dialog.update(0.90, 'Saving to device...');
      final savedItem = await StorageService().saveFile(
        fileName: fileName,
        bytes: encodedBytes,
        type: 'image',
        subtitle: '${current.width} x ${current.height} px, ${_targetKb != null ? "Target <${_targetKb}KB (${(encodedBytes.length / 1024).toStringAsFixed(1)} KB)" : ext.toUpperCase()}',
      );

      await dialog.complete('Image Saved!');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved: $fileName (${savedItem.formattedSize})'),
          backgroundColor: AppColors.sageGreen,
          action: SnackBarAction(
            label: 'Open',
            textColor: Colors.white,
            onPressed: () => StorageService().openFile(savedItem.filePath),
          ),
        ),
      );
    } catch (e) {
      dialog.dismiss();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving image: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currentCropW = _decodedImage != null ? (_cropRect.width * _decodedImage!.width).round() : 0;
    final currentCropH = _decodedImage != null ? (_cropRect.height * _decodedImage!.height).round() : 0;

    return Scaffold(
      appBar: PageLabAppBar(
        title: 'Crop & Resize',
        subtitle: _decodedImage != null
            ? '${_decodedImage!.width} × ${_decodedImage!.height} px original'
            : null,
        actions: [
          if (_imageBytes != null) ...[
            IconButton(
              tooltip: 'Change image',
              icon: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDarkElevated : AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_library_outlined, size: 18),
              ),
              onPressed: _pickImage,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: _imageBytes == null
          ? ToolEmptyState(
              title: 'Select Image to Crop & Resize',
              subtitle: 'Crop with custom aspect ratios, rotate, flip, and resize dimensions with precision.',
              icon: Icons.crop_rotate_rounded,
              iconColor: AppColors.toolOrangeIcon,
              iconBgColor: AppColors.toolOrangeBg,
              buttonText: 'Select Image to Begin',
              onSelect: _pickImage,
            )
          : LayoutBuilder(
              builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 960;

          // 1. Interactive Preview Viewport with Corner Handles & Rule-of-Thirds Grid
          final previewWidget = Padding(
            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 0 : 16, vertical: 8),
            child: Container(
              height: isDesktop ? 520 : 350,
              width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF171720) : const Color(0xFF1E1E26),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : const Color(0xFF2C2C38),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Source Image with transformations
                      if (_imageBytes != null)
                        Transform.rotate(
                          angle: _rotationAngle * (3.141592653589793 / 180),
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.diagonal3Values(
                              _isFlippedH ? -1.0 : 1.0,
                              _isFlippedV ? -1.0 : 1.0,
                              1.0,
                            ),
                            child: Image.memory(
                              _imageBytes!,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                        ),

                      // Interactive 4-Side & 4-Corner Crop Overlay
                      Positioned.fill(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final boxW = constraints.maxWidth;
                            final boxH = constraints.maxHeight;

                            final isRotated90or270 = (_rotationAngle % 180 != 0);
                            final imgW = (isRotated90or270
                                    ? (_decodedImage?.height ?? 1080)
                                    : (_decodedImage?.width ?? 1080))
                                .toDouble();
                            final imgH = (isRotated90or270
                                    ? (_decodedImage?.width ?? 1080)
                                    : (_decodedImage?.height ?? 1080))
                                .toDouble();

                            final containerAspect = boxW / boxH;
                            final imgAspect = imgW / imgH;

                            double renderW, renderH, offsetX, offsetY;
                            if (containerAspect > imgAspect) {
                              renderH = boxH;
                              renderW = boxH * imgAspect;
                              offsetX = (boxW - renderW) / 2;
                              offsetY = 0;
                            } else {
                              renderW = boxW;
                              renderH = boxW / imgAspect;
                              offsetX = 0;
                              offsetY = (boxH - renderH) / 2;
                            }

                            final left = offsetX + _cropRect.left * renderW;
                            final top = offsetY + _cropRect.top * renderH;
                            final width = _cropRect.width * renderW;
                            final height = _cropRect.height * renderH;

                            final cropRect = Rect.fromLTWH(left, top, width, height);
                            final imageRect = Rect.fromLTWH(offsetX, offsetY, renderW, renderH);

                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // 1. Dark Scrim Dimming outside Crop Box
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _CropScrimPainter(
                                      cropRect: cropRect,
                                      imageRect: imageRect,
                                    ),
                                  ),
                                ),

                                // 2. Crop Box Visuals (White Border & Rule-of-Thirds Grid)
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _CropBoxPainter(cropRect: cropRect),
                                  ),
                                ),

                                // 3. Center Pan Zone (Moves whole crop box)
                                Positioned(
                                  left: left + 20,
                                  top: top + 20,
                                  width: math.max(10.0, width - 40),
                                  height: math.max(10.0, height - 40),
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.move,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onPanUpdate: (details) => _onPanCenter(details, renderW, renderH),
                                    ),
                                  ),
                                ),

                                // 4. Side 1: Top Edge Handle
                                _buildEdgeHandleWidget(
                                  left: left + (width / 2),
                                  top: top,
                                  isHorizontal: true,
                                  cursor: SystemMouseCursors.resizeUpDown,
                                  onPanUpdate: (details) => _onPanTop(details, renderW, renderH),
                                ),

                                // 5. Side 2: Bottom Edge Handle
                                _buildEdgeHandleWidget(
                                  left: left + (width / 2),
                                  top: top + height,
                                  isHorizontal: true,
                                  cursor: SystemMouseCursors.resizeUpDown,
                                  onPanUpdate: (details) => _onPanBottom(details, renderW, renderH),
                                ),

                                // 6. Side 3: Left Edge Handle
                                _buildEdgeHandleWidget(
                                  left: left,
                                  top: top + (height / 2),
                                  isHorizontal: false,
                                  cursor: SystemMouseCursors.resizeLeftRight,
                                  onPanUpdate: (details) => _onPanLeft(details, renderW, renderH),
                                ),

                                // 7. Side 4: Right Edge Handle
                                _buildEdgeHandleWidget(
                                  left: left + width,
                                  top: top + (height / 2),
                                  isHorizontal: false,
                                  cursor: SystemMouseCursors.resizeLeftRight,
                                  onPanUpdate: (details) => _onPanRight(details, renderW, renderH),
                                ),

                                // 8. Corner 1: Top-Left Handle
                                _buildCornerHandleWidget(
                                  left: left,
                                  top: top,
                                  icon: Icons.north_west_rounded,
                                  cursor: SystemMouseCursors.resizeUpLeftDownRight,
                                  onPanUpdate: (details) => _onPanTopLeft(details, renderW, renderH),
                                ),

                                // 9. Corner 2: Top-Right Handle
                                _buildCornerHandleWidget(
                                  left: left + width,
                                  top: top,
                                  icon: Icons.north_east_rounded,
                                  cursor: SystemMouseCursors.resizeUpRightDownLeft,
                                  onPanUpdate: (details) => _onPanTopRight(details, renderW, renderH),
                                ),

                                // 10. Corner 3: Bottom-Left Handle
                                _buildCornerHandleWidget(
                                  left: left,
                                  top: top + height,
                                  icon: Icons.south_west_rounded,
                                  cursor: SystemMouseCursors.resizeUpRightDownLeft,
                                  onPanUpdate: (details) => _onPanBottomLeft(details, renderW, renderH),
                                ),

                                // 11. Corner 4: Bottom-Right Handle
                                _buildCornerHandleWidget(
                                  left: left + width,
                                  top: top + height,
                                  icon: Icons.south_east_rounded,
                                  cursor: SystemMouseCursors.resizeUpLeftDownRight,
                                  onPanUpdate: (details) => _onPanBottomRight(details, renderW, renderH),
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                      // Floating Live Crop Dimensions Badge (Top-Center)
                      Positioned(
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24, width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.crop_free_rounded, size: 12, color: AppColors.primaryLight),
                              const SizedBox(width: 6),
                              Text(
                                '$currentCropW × $currentCropH px',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Reset to Full Image Action (Top-Right)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: GestureDetector(
                          onTap: _resetCropToFull,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white24, width: 0.8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.fullscreen_rounded, size: 14, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Full',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Floating Guidance Hint Badge (Bottom-Center)
                      Positioned(
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.touch_app_rounded, size: 12, color: AppColors.primaryLight),
                              SizedBox(width: 6),
                              Text(
                                'Drag any of 4 sides, corners, or center to crop',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
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
            );

            // 2. Aspect Ratio Chips Row (Free, 1:1, 4:3, 16:9, 3:4, 9:16)
            final aspectPresetsWidget = Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Aspect Ratio Presets',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                        ),
                      ),
                      Text(
                        _selectedRatio,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildRatioPill('Free', null, Icons.crop_free_rounded),
                        _buildRatioPill('1:1', 1.0, Icons.crop_square_rounded),
                        _buildRatioPill('4:3', 4.0 / 3.0, Icons.crop_landscape_rounded),
                        _buildRatioPill('16:9', 16.0 / 9.0, Icons.tv_rounded),
                        _buildRatioPill('3:4', 3.0 / 4.0, Icons.crop_portrait_rounded),
                        _buildRatioPill('9:16', 9.0 / 16.0, Icons.phone_android_rounded),
                      ],
                    ),
                  ),
                ],
              ),
            );

            // 3. Transform Controls (Rotate & Flip)
            final transformControlsWidget = Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.rotate_right_rounded,
                      label: 'Rotate $_rotationAngle deg',
                      onTap: _rotateClockwise,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.flip_rounded,
                      label: _isFlippedH ? 'Flipped H' : 'Flip Horiz',
                      isActive: _isFlippedH,
                      onTap: _toggleFlipH,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.swap_vert_rounded,
                      label: _isFlippedV ? 'Flipped V' : 'Flip Vert',
                      isActive: _isFlippedV,
                      onTap: _toggleFlipV,
                    ),
                  ),
                ],
              ),
            );

            // 4. Custom Resize Dimensions Card (Width × Height, Maintain Aspect Ratio)
            final resizeDimensionsWidget = Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDarkElevated : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
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
                          'Resize Output Dimensions',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        Row(
                          children: [
                            Text(
                              'Keep aspect',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Switch(
                              value: _maintainAspect,
                              activeTrackColor: AppColors.primary,
                              onChanged: (val) => setState(() => _maintainAspect = val),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _widthController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Width',
                              suffixText: 'px',
                              prefixIcon: Icon(Icons.swap_horiz_rounded, size: 18),
                            ),
                            onChanged: (val) {
                              if (_maintainAspect && _decodedImage != null) {
                                final w = int.tryParse(val);
                                if (w != null && w > 0) {
                                  final aspect = _decodedImage!.width / _decodedImage!.height;
                                  _heightController.text = (w / aspect).round().toString();
                                }
                              }
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.cardDark : AppColors.surfaceMuted,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _maintainAspect ? Icons.link_rounded : Icons.link_off_rounded,
                              size: 16,
                              color: _maintainAspect ? AppColors.primary : Colors.grey,
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _heightController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Height',
                              suffixText: 'px',
                              prefixIcon: Icon(Icons.swap_vert_rounded, size: 18),
                            ),
                            onChanged: (val) {
                              if (_maintainAspect && _decodedImage != null) {
                                final h = int.tryParse(val);
                                if (h != null && h > 0) {
                                  final aspect = _decodedImage!.width / _decodedImage!.height;
                                  _widthController.text = (h * aspect).round().toString();
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Resolution presets
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildPresetChip('HD 1080p', 1920, 1080),
                        _buildPresetChip('Square 1080', 1080, 1080),
                        _buildPresetChip('Web 800', 800, 600),
                        _buildPresetChip('Thumb 400', 400, 400),
                      ],
                    ),
                  ],
                ),
              ),
            );

            // 5. Output Format & Quality Control
            final outputFormatWidget = Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDarkElevated : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Export Format & Quality',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildFormatSegment('JPG', 'Smaller size', ImageOutputFormat.jpg),
                        const SizedBox(width: 8),
                        _buildFormatSegment('PNG', 'Lossless detail', ImageOutputFormat.png),
                        const SizedBox(width: 8),
                        _buildFormatSegment('WebP', 'Modern web', ImageOutputFormat.webp),
                      ],
                    ),
                    if (_outputFormat != ImageOutputFormat.png) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Target Size Limit (KB)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          if (_targetKb != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.sageGreen.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Under $_targetKb KB',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.sageGreen,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildTargetKbChip('None (Auto)', null),
                            const SizedBox(width: 6),
                            _buildTargetKbChip('< 20 KB', 20),
                            const SizedBox(width: 6),
                            _buildTargetKbChip('< 50 KB', 50),
                            const SizedBox(width: 6),
                            _buildTargetKbChip('< 100 KB', 100),
                            const SizedBox(width: 6),
                            _buildTargetKbChip('< 200 KB', 200),
                            const SizedBox(width: 6),
                            _buildTargetKbChip('< 500 KB', 500),
                          ],
                        ),
                      ),
                      if (_targetKb == null) ...[
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Compression Quality: ${_quality.round()}%',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _quality > 85 ? 'High (Crisp)' : 'Balanced',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _quality,
                          min: 30,
                          max: 100,
                          activeColor: AppColors.primary,
                          onChanged: (val) => setState(() => _quality = val),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            );

            if (isDesktop) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Interactive Canvas & Quick Transform Bar
                        Expanded(
                          flex: 6,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                previewWidget,
                                const SizedBox(height: 16),
                                transformControlsWidget,
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Right Column: Inspector Controls Panel
                        SizedBox(
                          width: 440,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                aspectPresetsWidget,
                                resizeDimensionsWidget,
                                outputFormatWidget,
                                _buildSaveButton(),
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
                      previewWidget,
                      aspectPresetsWidget,
                      transformControlsWidget,
                      resizeDimensionsWidget,
                      outputFormatWidget,
                      _buildSaveButton(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isProcessing ? null : _saveAndExport,
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
                    Text('Exporting...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ],
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Save Image',
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
  }

  Widget _buildRatioPill(String label, double? ratio, IconData icon) {
    final isSelected = _selectedRatio == label;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => _setAspectRatio(label, ratio),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.cardDarkElevated : Colors.white),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? AppColors.borderDark : AppColors.borderLight),
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.textMutedDark : AppColors.textMuted),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? AppColors.textLight : AppColors.textDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(
        icon,
        size: 17,
        color: isActive ? AppColors.primary : null,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
          color: isActive ? AppColors.primary : null,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        backgroundColor: isActive ? AppColors.primaryContainer : (isDark ? AppColors.cardDark : Colors.white),
        side: BorderSide(
          color: isActive ? AppColors.primary : (isDark ? AppColors.borderDark : AppColors.borderLight),
          width: isActive ? 1.5 : 1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _buildPresetChip(String title, int w, int h) {
    return ActionChip(
      label: Text('$title ($w×$h)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.cardDark
          : AppColors.surfaceMuted,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onPressed: () {
        _widthController.text = w.toString();
        _heightController.text = h.toString();
      },
    );
  }

  Widget _buildFormatSegment(String label, String hint, ImageOutputFormat format) {
    final isSelected = _outputFormat == format;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _outputFormat = format),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
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
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                  color: isSelected ? AppColors.primary : null,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hint,
                style: TextStyle(
                  fontSize: 9,
                  color: isSelected ? AppColors.primary : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTargetKbChip(String label, int? kb) {
    final isSelected = _targetKb == kb;
    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? Colors.white : null,
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      onSelected: (_) => setState(() => _targetKb = kb),
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}

class _CropScrimPainter extends CustomPainter {
  final Rect cropRect;
  final Rect imageRect;

  _CropScrimPainter({required this.cropRect, required this.imageRect});

  @override
  void paint(Canvas canvas, Size size) {
    final scrimPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.52)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addRect(imageRect)
      ..addRect(cropRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, scrimPaint);
  }

  @override
  bool shouldRepaint(covariant _CropScrimPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect || oldDelegate.imageRect != imageRect;
  }
}

class _CropBoxPainter extends CustomPainter {
  final Rect cropRect;

  _CropBoxPainter({required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    final left = cropRect.left;
    final top = cropRect.top;
    final width = cropRect.width;
    final height = cropRect.height;
    final right = cropRect.right;
    final bottom = cropRect.bottom;

    // 1. White boundary border
    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawRect(cropRect, borderPaint);

    // 2. Rule of thirds grid
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.38)
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(left + width / 3, top), Offset(left + width / 3, bottom), gridPaint);
    canvas.drawLine(Offset(left + width * 2 / 3, top), Offset(left + width * 2 / 3, bottom), gridPaint);
    canvas.drawLine(Offset(left, top + height / 3), Offset(right, top + height / 3), gridPaint);
    canvas.drawLine(Offset(left, top + height * 2 / 3), Offset(right, top + height * 2 / 3), gridPaint);
  }

  @override
  bool shouldRepaint(covariant _CropBoxPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect;
  }
}
