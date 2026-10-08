import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'web_iframe_helper.dart';

class DocxContentBlock {
  final String text;
  final bool isHeading;
  final int headingLevel;
  final bool isListItem;
  final bool isTable;
  final List<List<String>>? tableData;

  DocxContentBlock({
    required this.text,
    this.isHeading = false,
    this.headingLevel = 1,
    this.isListItem = false,
    this.isTable = false,
    this.tableData,
  });
}

class DocxParseResult {
  final List<DocxContentBlock> blocks;
  final String rawText;
  final int wordCount;
  final int readingTimeMinutes;

  DocxParseResult({
    required this.blocks,
    required this.rawText,
    required this.wordCount,
    required this.readingTimeMinutes,
  });
}

class DocumentViewerScreen extends StatefulWidget {
  final String documentUrl;
  final String title;
  final String? fileSize;
  final String? fileType;

  const DocumentViewerScreen({
    super.key,
    required this.documentUrl,
    required this.title,
    this.fileSize,
    this.fileType,
  });

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;

  // Parsed content states
  DocxParseResult? _docxResult;
  String? _rawTextContent;
  bool _isImage = false;
  bool _isPdf = false;
  bool _isOfficeDoc = false;

  // Controls state
  double _fontSize = 16.0;
  bool _showControls = false;
  bool _showSearch = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  TabController? _tabController;

  // Active view tab: 0 = Document Reader, 1 = Embedded Web Frame
  int _activeViewMode = 0;

  @override
  void initState() {
    super.initState();
    _detectFileType();
    _loadDocumentContent();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  String get _cleanFileName {
    if (widget.title.isNotEmpty && !widget.title.startsWith('http')) {
      return widget.title;
    }
    try {
      final uri = Uri.parse(widget.documentUrl);
      final segment = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'document';
      final parts = segment.split('-');
      if (parts.length > 1 && int.tryParse(parts[0]) != null) {
        return parts.sublist(1).join('-');
      }
      return segment;
    } catch (_) {
      return 'Document';
    }
  }

  String get _extension {
    final name = _cleanFileName.toLowerCase();
    if (name.contains('.')) {
      return name.split('.').last.toUpperCase();
    }
    if (widget.fileType != null && widget.fileType!.isNotEmpty) {
      return widget.fileType!.toUpperCase();
    }
    return 'FILE';
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
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
      case 'gif':
        return const Color(0xFF06B6D4);
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
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
      case 'gif':
        return Icons.image_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  void _detectFileType() {
    final ext = _extension.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'webp', 'gif', 'svg'].contains(ext)) {
      _isImage = true;
    } else if (ext == 'pdf') {
      _isPdf = true;
      _activeViewMode = kIsWeb ? 1 : 0; // Default to embedded view on web for PDF
    } else if (['doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx'].contains(ext)) {
      _isOfficeDoc = true;
    }
  }

  Future<void> _loadDocumentContent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isImage) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await http.get(Uri.parse(widget.documentUrl)).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode != 200) {
        throw Exception('Server returned status code ${response.statusCode}');
      }

      final ext = _extension.toLowerCase();

      if (ext == 'docx') {
        final parsed = _parseDocxBytes(response.bodyBytes);
        setState(() {
          _docxResult = parsed;
          _rawTextContent = parsed.rawText;
          _isLoading = false;
        });
      } else if (['txt', 'md', 'json', 'csv', 'log', 'dart', 'js', 'py', 'html', 'xml'].contains(ext) ||
          !_isPdf && !_isOfficeDoc) {
        final text = utf8.decode(response.bodyBytes, allowMalformed: true);
        setState(() {
          _rawTextContent = text;
          _isLoading = false;
        });
      } else {
        // PDF or PPT/XLS where we rely on embedded web preview / fallback
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  DocxParseResult _parseDocxBytes(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final docFile = archive.findFile('word/document.xml');
      if (docFile == null) {
        return DocxParseResult(blocks: [], rawText: '', wordCount: 0, readingTimeMinutes: 0);
      }

      final xmlContent = utf8.decode(docFile.content as List<int>, allowMalformed: true);
      final blocks = <DocxContentBlock>[];
      final fullTextBuffer = StringBuffer();

      final blockRegex = RegExp(r'<(w:p|w:tbl)[^>]*>(.*?)</\1>', dotAll: true);
      final matches = blockRegex.allMatches(xmlContent);

      for (final match in matches) {
        final tagType = match.group(1);
        final innerXml = match.group(2) ?? '';

        if (tagType == 'w:tbl') {
          final rows = <List<String>>[];
          final rowRegex = RegExp(r'<w:tr[^>]*>(.*?)</w:tr>', dotAll: true);
          final cellRegex = RegExp(r'<w:tc[^>]*>(.*?)</w:tc>', dotAll: true);
          final textRegex = RegExp(r'<w:t[^>]*>(.*?)</w:t>', dotAll: true);

          for (final rMatch in rowRegex.allMatches(innerXml)) {
            final rowContent = rMatch.group(1) ?? '';
            final rowCells = <String>[];
            for (final cMatch in cellRegex.allMatches(rowContent)) {
              final cellXml = cMatch.group(1) ?? '';
              final cellTexts = textRegex
                  .allMatches(cellXml)
                  .map((m) => _cleanXmlText(m.group(1) ?? ''))
                  .join('')
                  .trim();
              rowCells.add(cellTexts);
            }
            if (rowCells.isNotEmpty) {
              rows.add(rowCells);
            }
          }

          if (rows.isNotEmpty) {
            blocks.add(DocxContentBlock(text: '', isTable: true, tableData: rows));
          }
        } else if (tagType == 'w:p') {
          final textRegex = RegExp(r'<w:t[^>]*>(.*?)</w:t>', dotAll: true);
          final pText = textRegex
              .allMatches(innerXml)
              .map((m) => _cleanXmlText(m.group(1) ?? ''))
              .join('')
              .trim();

          if (pText.isEmpty) continue;

          fullTextBuffer.writeln(pText);

          final isHeading = innerXml.contains('Heading1') ||
              innerXml.contains('Heading2') ||
              innerXml.contains('Heading3') ||
              innerXml.contains('Title');

          int headingLevel = 1;
          if (innerXml.contains('Heading2')) headingLevel = 2;
          if (innerXml.contains('Heading3')) headingLevel = 3;

          final isList = innerXml.contains('w:numPr') || innerXml.contains('w:ilvl');

          blocks.add(DocxContentBlock(
            text: pText,
            isHeading: isHeading,
            headingLevel: headingLevel,
            isListItem: isList,
          ));
        }
      }

      final rawText = fullTextBuffer.toString();
      final words = rawText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      final readingTime = (words / 200).ceil();

      return DocxParseResult(
        blocks: blocks,
        rawText: rawText,
        wordCount: words,
        readingTimeMinutes: readingTime < 1 ? 1 : readingTime,
      );
    } catch (_) {
      return DocxParseResult(blocks: [], rawText: '', wordCount: 0, readingTimeMinutes: 0);
    }
  }

  String _cleanXmlText(String xmlText) {
    return xmlText
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll(RegExp(r'<[^>]*>'), '');
  }

  Future<void> _openExternal() async {
    try {
      final uri = Uri.parse(widget.documentUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: $e')),
        );
      }
    }
  }

  String get _googleEmbedUrl {
    return 'https://docs.google.com/gview?url=${Uri.encodeComponent(widget.documentUrl)}&embedded=true';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _themeColor;
    final fileName = _cleanFileName;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_iconData, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.fileSize != null)
                    Text(
                      widget.fileSize!,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_docxResult != null || _rawTextContent != null) ...[
            IconButton(
              tooltip: 'Search Document',
              icon: Icon(
                _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
                color: _showSearch ? color : null,
              ),
              onPressed: () {
                setState(() {
                  _showSearch = !_showSearch;
                  if (!_showSearch) {
                    _searchQuery = '';
                    _searchController.clear();
                  }
                });
              },
            ),
            IconButton(
              tooltip: 'Text Size',
              icon: Icon(
                Icons.text_format_rounded,
                color: _showControls ? color : null,
              ),
              onPressed: () {
                setState(() {
                  _showControls = !_showControls;
                });
              },
            ),
          ],
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share_rounded),
            onPressed: () {
              SharePlus.instance.share(
                ShareParams(
                  text: 'Check out this document: ${widget.documentUrl}',
                  subject: fileName,
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Download',
            icon: const Icon(Icons.download_rounded),
            onPressed: _openExternal,
          ),
        ],
      ),
      body: Column(
        children: [
          // Sub-header controls (Search bar & Font size controller)
          if (_showSearch) _buildSearchBar(isDark, color),
          if (_showControls) _buildFontSizeControls(isDark, color),

          // View mode switcher tab (Document Reader vs Embedded Web Preview)
          if ((_isPdf || _isOfficeDoc) && !_isLoading && _errorMessage == null)
            _buildViewModeTabBar(isDark, color),

          // Main Content Area
          Expanded(
            child: _isLoading
                ? _buildLoadingState(color)
                : _errorMessage != null
                    ? _buildErrorState(isDark, color)
                    : _activeViewMode == 1
                        ? buildWebIframeWidget(_googleEmbedUrl, color)
                        : _buildDocumentBody(isDark, color),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActions(isDark, color),
    );
  }

  Widget _buildSearchBar(bool isDark, Color color) {
    return Container(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Search text in document...',
                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                prefixIcon: Icon(Icons.search_rounded, color: color, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFontSizeControls(bool isDark, Color color) {
    return Container(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          const Text('Text Size:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Text('${_fontSize.toInt()}pt', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          Expanded(
            child: Slider(
              value: _fontSize,
              min: 12.0,
              max: 28.0,
              divisions: 8,
              activeColor: color,
              onChanged: (val) {
                setState(() => _fontSize = val);
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.text_decrease_rounded, size: 18),
            onPressed: _fontSize > 12
                ? () => setState(() => _fontSize = (_fontSize - 2).clamp(12.0, 28.0))
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.text_increase_rounded, size: 20),
            onPressed: _fontSize < 28
                ? () => setState(() => _fontSize = (_fontSize + 2).clamp(12.0, 28.0))
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeTabBar(bool isDark, Color color) {
    return Container(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeViewMode = 0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _activeViewMode == 0 ? color : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.article_rounded,
                                size: 16,
                                color: _activeViewMode == 0 ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Document Reader',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _activeViewMode == 0 ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeViewMode = 1),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _activeViewMode == 1 ? color : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.web_rounded,
                                size: 16,
                                color: _activeViewMode == 1 ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Embedded Web View',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _activeViewMode == 1 ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: color),
          const SizedBox(height: 16),
          Text(
            'Preparing document preview...',
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDark, Color color) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: color.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text(
              'Document Ready for Viewing',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap below to open or view this document via external application.',
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white60 : Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openExternal,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open File Directly'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentBody(bool isDark, Color color) {
    if (_isImage) {
      return InteractiveViewer(
        maxScale: 4.0,
        child: Center(
          child: Image.network(
            widget.documentUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(child: CircularProgressIndicator(color: color));
            },
            errorBuilder: (context, error, stackTrace) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_rounded, size: 64, color: color),
                const SizedBox(height: 12),
                const Text('Could not load image'),
              ],
            ),
          ),
        ),
      );
    }

    if (_docxResult != null && _docxResult!.blocks.isNotEmpty) {
      return _buildDocxPaperView(isDark, color);
    }

    if (_rawTextContent != null && _rawTextContent!.isNotEmpty) {
      return _buildRawTextView(isDark, color);
    }

    // Default fallback for PDF or office document preview card
    return _buildFallbackPreviewCard(isDark, color);
  }

  Widget _buildDocxPaperView(bool isDark, Color color) {
    final blocks = _docxResult!.blocks;
    final search = _searchQuery.toLowerCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          // Document Header Info Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_iconData, color: color, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _cleanFileName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_docxResult!.wordCount} words  •  ~${_docxResult!.readingTimeMinutes} min read',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Paper Sheet Container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: SelectableText.rich(
              TextSpan(
                children: blocks.map((block) {
                  if (block.isTable && block.tableData != null) {
                    return WidgetSpan(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: isDark ? Colors.white24 : Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Table(
                          border: TableBorder.all(
                            color: isDark ? Colors.white12 : Colors.grey[200]!,
                          ),
                          children: block.tableData!.map((row) {
                            return TableRow(
                              children: row.map((cell) {
                                return Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    cell,
                                    style: TextStyle(
                                      fontSize: _fontSize - 2,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  }

                  final text = block.text;
                  final matchesSearch = search.isNotEmpty && text.toLowerCase().contains(search);

                  if (block.isHeading) {
                    return TextSpan(
                      text: '$text\n\n',
                      style: TextStyle(
                        fontSize: _fontSize + (4 - block.headingLevel * 2),
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                        color: matchesSearch
                            ? Colors.amber[400]
                            : (isDark ? Colors.white : const Color(0xFF0F172A)),
                        backgroundColor: matchesSearch ? Colors.amber.withValues(alpha: 0.3) : null,
                      ),
                    );
                  }

                  if (block.isListItem) {
                    return TextSpan(
                      text: ' • $text\n\n',
                      style: TextStyle(
                        fontSize: _fontSize,
                        height: 1.6,
                        color: matchesSearch
                            ? Colors.amber[400]
                            : (isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF334155)),
                        backgroundColor: matchesSearch ? Colors.amber.withValues(alpha: 0.3) : null,
                      ),
                    );
                  }

                  return TextSpan(
                    text: '$text\n\n',
                    style: TextStyle(
                      fontSize: _fontSize,
                      height: 1.65,
                      color: matchesSearch
                          ? Colors.amber[400]
                          : (isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF334155)),
                      backgroundColor: matchesSearch ? Colors.amber.withValues(alpha: 0.3) : null,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRawTextView(bool isDark, Color color) {
    final text = _rawTextContent ?? '';
    final isMd = _extension.toLowerCase() == 'md';

    if (isMd) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: MarkdownBody(
            data: text,
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: TextStyle(fontSize: _fontSize, height: 1.6),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SelectableText(
        text,
        style: TextStyle(
          fontSize: _fontSize,
          fontFamily: 'monospace',
          height: 1.5,
          color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildFallbackPreviewCard(bool isDark, Color color) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [color.withValues(alpha: 0.2), const Color(0xFF1E293B)]
                      : [color.withValues(alpha: 0.1), Colors.white],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(_iconData, color: Colors.white, size: 44),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '$_extension DOCUMENT',
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _cleanFileName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _activeViewMode = 1),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.visibility_rounded, size: 18),
                        label: const Text('View Embedded Document'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions(bool isDark, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _openExternal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.download_rounded, size: 20),
                label: const Text('Download / Save File', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              tooltip: 'Copy Text',
              icon: const Icon(Icons.copy_rounded, size: 20),
              onPressed: () {
                final textToCopy = _rawTextContent ?? widget.documentUrl;
                Clipboard.setData(ClipboardData(text: textToCopy));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Document text copied to clipboard!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
