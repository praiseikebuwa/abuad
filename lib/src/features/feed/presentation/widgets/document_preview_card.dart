import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'document_viewer_screen.dart';

class DocumentPreviewCard extends StatelessWidget {
  final String? documentUrl;
  final String? fileName;
  final String? fileSize;
  final VoidCallback? onRemove;
  final bool isCompact;

  const DocumentPreviewCard({
    super.key,
    this.documentUrl,
    this.fileName,
    this.fileSize,
    this.onRemove,
    this.isCompact = false,
  });

  String get _cleanFileName {
    if (fileName != null && fileName!.isNotEmpty && !fileName!.startsWith('http')) {
      return fileName!;
    }
    if (documentUrl != null && documentUrl!.isNotEmpty) {
      try {
        final uri = Uri.parse(documentUrl!);
        final segment = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'document';
        final parts = segment.split('-');
        if (parts.length > 1 && int.tryParse(parts[0]) != null) {
          return parts.sublist(1).join('-');
        }
        return segment;
      } catch (_) {}
    }
    return 'Document';
  }

  String get _extension {
    final name = _cleanFileName.toLowerCase();
    if (name.contains('.')) {
      return name.split('.').last.toUpperCase();
    }
    return 'DOC';
  }

  Color get _themeColor {
    final ext = _extension.toLowerCase();
    switch (ext) {
      case 'pdf':
        return const Color(0xFFEF4444);
      case 'doc':
      case 'docx':
        return const Color(0xFF2563EB);
      case 'ppt':
      case 'pptx':
        return const Color(0xFFEA580C);
      case 'xls':
      case 'xlsx':
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF8B5CF6);
    }
  }

  IconData get _iconData {
    final ext = _extension.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  void _openViewer(BuildContext context) {
    if (documentUrl == null || documentUrl!.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(
          documentUrl: documentUrl!,
          title: _cleanFileName,
          fileSize: fileSize,
          fileType: _extension,
        ),
      ),
    );
  }

  Future<void> _download(BuildContext context) async {
    if (documentUrl == null || documentUrl!.isEmpty) return;
    try {
      final uri = Uri.parse(documentUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open document link')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _themeColor;
    final name = _cleanFileName;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161E2E) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? color.withValues(alpha: 0.3) : color.withValues(alpha: 0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.08 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openViewer(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Extension Icon Badge
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _iconData,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _extension,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // File Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$_extension Document',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ),
                          if (fileSize != null && fileSize!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              '• $fileSize',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white60 : Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Trailing Action Button
                if (onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: Colors.red[400],
                    onPressed: onRemove,
                  )
                else ...[
                  // Action buttons: Preview & Download
                  IconButton(
                    tooltip: 'Preview Document',
                    icon: Icon(
                      Icons.visibility_rounded,
                      color: color,
                      size: 20,
                    ),
                    onPressed: () => _openViewer(context),
                  ),
                  IconButton(
                    tooltip: 'Download',
                    icon: Icon(
                      Icons.download_rounded,
                      color: isDark ? Colors.white70 : Colors.grey[700],
                      size: 20,
                    ),
                    onPressed: () => _download(context),
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
