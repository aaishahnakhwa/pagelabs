import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../theme/app_colors.dart';
import '../models/history_item.dart';
import '../services/storage_service.dart';
import '../services/file_saver/file_saver.dart' as saver;
import 'crop_resize_screen.dart';
import 'image_to_pdf_screen.dart';
import 'compress_pdf_screen.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  String _filter = 'All';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  String _formatTotalBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: StorageService(),
      builder: (context, _) {
        final history = StorageService().history;

        final filteredList = history.where((item) {
          if (_filter == 'Images' && item.type != 'image') return false;
          if (_filter == 'PDFs' && item.type != 'pdf') return false;
          if (_searchQuery.isNotEmpty &&
              !item.title.toLowerCase().contains(_searchQuery.toLowerCase()) &&
              !item.subtitle.toLowerCase().contains(_searchQuery.toLowerCase())) {
            return false;
          }
          return true;
        }).toList();

        final totalStorageBytes = history.fold<int>(0, (sum, i) => sum + i.fileSizeBytes);

        return Scaffold(
          appBar: _isSelectionMode
              ? AppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() {
                      _isSelectionMode = false;
                      _selectedIds.clear();
                    }),
                  ),
                  title: Text(
                    '${_selectedIds.length} Selected',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedIds.length == filteredList.length) {
                            _selectedIds.clear();
                          } else {
                            _selectedIds.addAll(filteredList.map((e) => e.id));
                          }
                        });
                      },
                      child: Text(
                        _selectedIds.length == filteredList.length ? 'Deselect All' : 'Select All',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (_selectedIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: IconButton(
                          tooltip: 'Delete Selected',
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                          onPressed: () => _confirmDeleteSelected(context),
                        ),
                      ),
                  ],
                )
              : AppBar(
                  titleSpacing: 18,
                  title: const Text(
                    'My Files',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.3),
                  ),
                  actions: [
                    if (filteredList.isNotEmpty)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? AppColors.textLight : AppColors.textDark,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        icon: const Icon(Icons.checklist_rounded, size: 18),
                        label: const Text('Select', style: TextStyle(fontWeight: FontWeight.w700)),
                        onPressed: () => setState(() => _isSelectionMode = true),
                      ),
                    if (history.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            backgroundColor: Colors.red.withValues(alpha: 0.08),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                          label: const Text(
                            'Delete All',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          onPressed: () => _confirmClearHistory(context),
                        ),
                      ),
                  ],
                ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 720;
              final isDesktop = constraints.maxWidth >= 1024;
              final horizontalPadding = isDesktop ? 32.0 : (isWide ? 24.0 : 16.0);

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Column(
                    children: [
                      // Search & Filter
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: 8,
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search files by name or type...',
                                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: (val) => setState(() => _searchQuery = val),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildFilterPill('All', history.length),
                                _buildFilterPill('Images', history.where((i) => i.type == 'image').length),
                                _buildFilterPill('PDFs', history.where((i) => i.type == 'pdf').length),
                                if (history.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '• ${_formatTotalBytes(totalStorageBytes)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                if (filteredList.isNotEmpty)
                                  OutlinedButton.icon(
                                    onPressed: () => _confirmClearHistory(
                                      context,
                                      filteredList.length < history.length ? filteredList : null,
                                    ),
                                    icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Colors.redAccent),
                                    label: Text(
                                      filteredList.length < history.length
                                          ? 'Delete (${filteredList.length})'
                                          : 'Delete All',
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.redAccent,
                                      side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      visualDensity: VisualDensity.compact,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Files List or Clean Empty State
                      Expanded(
                        child: filteredList.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryContainer.withValues(alpha: 0.5),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.folder_open_rounded,
                                          size: 56,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      Text(
                                        history.isEmpty
                                            ? 'No files generated yet'
                                            : 'No matching files found',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        history.isEmpty
                                            ? 'Your cropped photos, converted PDFs, and passport sheets will appear here.'
                                            : 'Try searching with a different keyword.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      if (history.isEmpty) ...[
                                        const SizedBox(height: 24),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            ActionChip(
                                              avatar: const Icon(Icons.crop_rounded, size: 16, color: AppColors.primary),
                                              label: const Text('Crop an Image'),
                                              onPressed: () => Navigator.of(context).push(
                                                MaterialPageRoute(builder: (_) => const CropResizeScreen()),
                                              ),
                                            ),
                                            ActionChip(
                                              avatar: const Icon(Icons.picture_as_pdf_outlined, size: 16, color: AppColors.toolRedIcon),
                                              label: const Text('Create PDF'),
                                              onPressed: () => Navigator.of(context).push(
                                                MaterialPageRoute(builder: (_) => const ImageToPdfScreen()),
                                              ),
                                            ),
                                            ActionChip(
                                              avatar: const Icon(Icons.compress_rounded, size: 16, color: AppColors.toolPurpleIcon),
                                              label: const Text('Compress PDF'),
                                              onPressed: () => Navigator.of(context).push(
                                                MaterialPageRoute(builder: (_) => const CompressPdfScreen()),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              )
                            : GridView.builder(
                                padding: EdgeInsets.symmetric(
                                  horizontal: horizontalPadding,
                                  vertical: 12,
                                ),
                                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: isWide ? 520 : 650,
                                  mainAxisExtent: 84,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                                itemCount: filteredList.length,
                                itemBuilder: (context, index) {
                                  final item = filteredList[index];
                                  final thumbBytes = StorageService().getThumbnailBytes(item);

                                  final isSelected = _selectedIds.contains(item.id);

                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    decoration: BoxDecoration(
                                      color: _isSelectionMode && isSelected
                                          ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.08)
                                          : (isDark ? AppColors.cardDarkElevated : Colors.white),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: _isSelectionMode && isSelected
                                            ? AppColors.primary
                                            : (isDark ? AppColors.borderDark : AppColors.borderLight),
                                        width: _isSelectionMode && isSelected ? 1.8 : 1.0,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.02),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(18),
                                      child: ListTile(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                        onTap: _isSelectionMode
                                            ? () {
                                                setState(() {
                                                  if (isSelected) {
                                                    _selectedIds.remove(item.id);
                                                    if (_selectedIds.isEmpty) _isSelectionMode = false;
                                                  } else {
                                                    _selectedIds.add(item.id);
                                                  }
                                                });
                                              }
                                            : () => _showFilePreview(context, item),
                                        onLongPress: () {
                                          setState(() {
                                            _isSelectionMode = true;
                                            _selectedIds.add(item.id);
                                          });
                                        },
                                        leading: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            width: 44,
                                            height: 44,
                                            color: item.type == 'pdf'
                                                ? AppColors.toolRedBg
                                                : AppColors.toolBlueBg,
                                            child: item.type == 'image' && thumbBytes != null
                                                ? Image.memory(
                                                    thumbBytes,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (ctx, err, stack) => const Icon(
                                                      Icons.image_outlined,
                                                      color: AppColors.toolBlueIcon,
                                                    ),
                                                  )
                                                : Icon(
                                                    item.type == 'pdf'
                                                        ? Icons.picture_as_pdf_rounded
                                                        : Icons.image_rounded,
                                                    color: item.type == 'pdf'
                                                        ? AppColors.toolRedIcon
                                                        : AppColors.toolBlueIcon,
                                                  ),
                                          ),
                                        ),
                                        title: Text(
                                          item.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 2),
                                            Text(
                                              item.subtitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${item.formattedSize}, ${DateFormat('MMM d, h:mm a').format(item.createdAt)}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                        trailing: _isSelectionMode
                                            ? Checkbox(
                                                value: isSelected,
                                                activeColor: AppColors.primary,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                                onChanged: (val) {
                                                  setState(() {
                                                    if (val == true) {
                                                      _selectedIds.add(item.id);
                                                    } else {
                                                      _selectedIds.remove(item.id);
                                                      if (_selectedIds.isEmpty) _isSelectionMode = false;
                                                    }
                                                  });
                                                },
                                              )
                                            : Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    tooltip: 'View file',
                                                    icon: const Icon(Icons.visibility_outlined, size: 20),
                                                    onPressed: () => _showFilePreview(context, item),
                                                  ),
                                            IconButton(
                                              tooltip: 'Share or Download',
                                              icon: const Icon(Icons.share_outlined, size: 18),
                                              onPressed: () => StorageService().shareFile(item.filePath, item: item),
                                            ),
                                            PopupMenuButton<String>(
                                              icon: const Icon(Icons.more_vert_rounded, size: 18),
                                              onSelected: (val) {
                                                if (val == 'preview') {
                                                  _showFilePreview(context, item);
                                                } else if (val == 'open_tab') {
                                                  StorageService().openFile(item.filePath, item: item);
                                                } else if (val == 'download') {
                                                  final bytes = StorageService().getFileBytes(item);
                                                  if (bytes != null) {
                                                    saver.saveAndDownloadFile(fileName: item.title, bytes: bytes);
                                                  } else {
                                                    StorageService().openFile(item.filePath, item: item);
                                                  }
                                                } else if (val == 'delete') {
                                                  StorageService().deleteHistoryItem(item);
                                                }
                                              },
                                              itemBuilder: (context) => [
                                                const PopupMenuItem(
                                                  value: 'preview',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.visibility_rounded, size: 18),
                                                      SizedBox(width: 8),
                                                      Text('View / Preview'),
                                                    ],
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'open_tab',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.open_in_new_rounded, size: 18),
                                                      SizedBox(width: 8),
                                                      Text('Open in Browser'),
                                                    ],
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'download',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.download_rounded, size: 18),
                                                      SizedBox(width: 8),
                                                      Text('Download Again'),
                                                    ],
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'delete',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                                      SizedBox(width: 8),
                                                      Text('Delete', style: TextStyle(color: Colors.red)),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFilterPill(String label, int count) {
    final isSelected = _filter == label;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _filter = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.cardDarkElevated : Colors.white),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.primary : (isDark ? AppColors.borderDark : AppColors.borderLight),
              width: 1.2,
            ),
          ),
          child: Text(
            '$label ($count)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : (isDark ? AppColors.textLight : AppColors.textDark),
            ),
          ),
        ),
      ),
    );
  }

  void _showFilePreview(BuildContext context, HistoryItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fileBytes = StorageService().getFileBytes(item) ?? StorageService().getThumbnailBytes(item);
    final isPdf = item.type == 'pdf';

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) {
        return Dialog(
          backgroundColor: isDark ? AppColors.cardDarkElevated : Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isPdf
                              ? AppColors.toolRedBg
                              : AppColors.toolBlueBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                          size: 20,
                          color: isPdf ? AppColors.toolRedIcon : AppColors.toolBlueIcon,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.subtitle} • ${item.formattedSize} • ${DateFormat('MMM d, h:mm a').format(item.createdAt)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Preview Content
                Flexible(
                  child: Container(
                    width: double.infinity,
                    color: isDark ? const Color(0xFF14171E) : const Color(0xFFF1F5F9),
                    child: isPdf
                        ? Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: AppColors.toolRedBg,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.toolRedIcon.withValues(alpha: 0.2),
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.picture_as_pdf_rounded,
                                    size: 56,
                                    color: AppColors.toolRedIcon,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  item.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'PDF Document (${item.formattedSize})',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'You can view all pages in your browser tab, download the file, or print directly.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : fileBytes != null
                            ? InteractiveViewer(
                                minScale: 0.5,
                                maxScale: 4.0,
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Image.memory(
                                      fileBytes,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.image_not_supported_outlined, size: 52, color: Colors.grey),
                                      const SizedBox(height: 14),
                                      const Text(
                                        'Preview Not Cached',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'This file was previously saved directly to your Downloads folder as "${item.title}".',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                  ),
                ),
                const Divider(height: 1),

                // Action Footer
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text('Delete'),
                        onPressed: () {
                          StorageService().deleteHistoryItem(item);
                          Navigator.of(ctx).pop();
                        },
                      ),
                      if (fileBytes != null) ...[
                        OutlinedButton.icon(
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text('Download'),
                          onPressed: () {
                            saver.saveAndDownloadFile(
                              fileName: item.title,
                              bytes: fileBytes,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Downloading ${item.title}...'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        if (isPdf)
                          OutlinedButton.icon(
                            icon: const Icon(Icons.print_rounded, size: 18),
                            label: const Text('Print / Preview'),
                            onPressed: () {
                              Printing.layoutPdf(
                                name: item.title,
                                onLayout: (_) => fileBytes,
                              );
                            },
                          ),
                      ],
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: Text(isPdf ? 'Open in Browser' : 'Open Full'),
                        onPressed: () {
                          StorageService().openFile(
                            item.filePath,
                            bytes: fileBytes,
                            fileName: item.title,
                            item: item,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmClearHistory(BuildContext context, [List<HistoryItem>? targetList]) {
    final allCount = StorageService().history.length;
    final isFiltered = targetList != null && targetList.length < allCount && targetList.isNotEmpty;
    final countToDelete = isFiltered ? targetList.length : allCount;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isFiltered ? 'Delete Filtered Files?' : 'Delete All Files?',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isFiltered
                  ? 'Are you sure you want to permanently delete $countToDelete matching files from PageLab history?'
                  : 'Are you sure you want to permanently delete all $allCount files from PageLab history?',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 10),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade400,
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.delete_forever_rounded, size: 17),
            onPressed: () async {
              if (isFiltered) {
                await StorageService().deleteMultipleItems(targetList);
              } else {
                await StorageService().clearHistory();
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isFiltered
                          ? '$countToDelete files deleted successfully'
                          : 'All $allCount files deleted successfully',
                    ),
                    backgroundColor: AppColors.sageGreen,
                  ),
                );
              }
            },
            label: Text(
              isFiltered ? 'Delete ($countToDelete)' : 'Delete All',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSelected(BuildContext context) {
    final selectedCount = _selectedIds.length;
    if (selectedCount == 0) return;

    final itemsToDelete = StorageService().history.where((i) => _selectedIds.contains(i.id)).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete $selectedCount File${selectedCount > 1 ? "s" : ""}?',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete $selectedCount selected file${selectedCount > 1 ? "s" : ""} from PageLab history?',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 10),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade400,
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.delete_forever_rounded, size: 17),
            onPressed: () async {
              await StorageService().deleteMultipleItems(itemsToDelete);
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (mounted) {
                setState(() {
                  _selectedIds.clear();
                  _isSelectionMode = false;
                });
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$selectedCount files deleted successfully'),
                    backgroundColor: AppColors.sageGreen,
                  ),
                );
              }
            },
            label: Text('Delete ($selectedCount)', style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
