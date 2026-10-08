import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/storage_service.dart';
import '../widgets/bg_remover_block.dart';
import '../widgets/page_lab_app_bar.dart';
import '../widgets/export_progress_dialog.dart';
import '../widgets/web_apk_notice_banner.dart';

class BgRemoverScreen extends StatefulWidget {
  const BgRemoverScreen({super.key});

  @override
  State<BgRemoverScreen> createState() => _BgRemoverScreenState();
}

class _BgRemoverScreenState extends State<BgRemoverScreen> {
  Uint8List? _processedBytes;

  Future<void> _saveImage() async {
    if (_processedBytes == null) return;

    final dialog = ExportProgressDialog(
      context,
      title: 'Saving Cutout',
      initialStatus: 'Preparing PNG file...',
    );
    dialog.show();

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final exportName = 'bg_removed_$timestamp.png';

      dialog.update(0.60, 'Saving transparent PNG...');
      final item = await StorageService().saveFile(
        fileName: exportName,
        bytes: _processedBytes!,
        type: 'BG_REMOVED',
        subtitle: 'Clean Cutout PNG',
      );

      await dialog.complete('Image Saved!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved: ${item.title}'),
            backgroundColor: AppColors.sageGreen,
          ),
        );
      }
    } catch (e) {
      dialog.dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PageLabAppBar(
        title: 'Background Remover',
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const WebApkNoticeBanner(),
                BgRemoverBlock(
                  showHeaderBanner: false,
                  onCutoutChanged: (bytes) {
                    setState(() => _processedBytes = bytes);
                  },
                ),

                if (_processedBytes != null) ...[
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _saveImage,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Download Processed Image (PNG)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
