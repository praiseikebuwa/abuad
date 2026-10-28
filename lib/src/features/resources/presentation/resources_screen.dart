import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../data/resource_repository.dart';
import '../domain/resource.dart';
import '../../portal/presentation/cbt_practice_screen.dart';
import '../../feed/presentation/widgets/document_viewer_screen.dart';

class ResourcesScreen extends ConsumerStatefulWidget {
  const ResourcesScreen({super.key});

  @override
  ConsumerState<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends ConsumerState<ResourcesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedLevel = 'All';
  String _selectedType = 'All';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedLevel = 'All';
      _selectedType = 'All';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final repo = ref.watch(resourceRepositoryProvider);

    final resourcesStream = _selectedLevel == 'All'
        ? repo.watchResources()
        : repo.watchResourcesByLevel(_selectedLevel);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Academic Resources",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        actions: [
          IconButton(
            tooltip: "Refresh library",
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(resourceRepositoryProvider);
              setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header Container
          Container(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modern Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: "Search by title, GST 112, MTH 101, notes...",
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        size: 20,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Level Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _FilterChip(
                        label: "All Levels",
                        isSelected: _selectedLevel == 'All',
                        onSelected: () => setState(() => _selectedLevel = 'All'),
                      ),
                      const SizedBox(width: 8),
                      ...['100', '200', '300', '400', '500'].map(
                        (lvl) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _FilterChip(
                            label: "${lvl}L",
                            isSelected: _selectedLevel == lvl,
                            onSelected: () => setState(() => _selectedLevel = lvl),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // File Type Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _TypeChip(
                        label: "All Types",
                        icon: Icons.apps_rounded,
                        isSelected: _selectedType == 'All',
                        onSelected: () => setState(() => _selectedType = 'All'),
                      ),
                      const SizedBox(width: 8),
                      _TypeChip(
                        label: "PDFs",
                        icon: Icons.picture_as_pdf_rounded,
                        iconColor: const Color(0xFFEF4444),
                        isSelected: _selectedType == 'pdf',
                        onSelected: () => setState(() => _selectedType = 'pdf'),
                      ),
                      const SizedBox(width: 8),
                      _TypeChip(
                        label: "Word (DOC)",
                        icon: Icons.description_rounded,
                        iconColor: const Color(0xFF2563EB),
                        isSelected: _selectedType == 'doc',
                        onSelected: () => setState(() => _selectedType = 'doc'),
                      ),
                      const SizedBox(width: 8),
                      _TypeChip(
                        label: "PowerPoint",
                        icon: Icons.slideshow_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        isSelected: _selectedType == 'ppt',
                        onSelected: () => setState(() => _selectedType = 'ppt'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Resources List
          Expanded(
            child: StreamBuilder<List<Resource>>(
              stream: resourcesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_off_rounded, size: 56, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text("Failed to load resources: ${snapshot.error}"),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => setState(() {}),
                            child: const Text("Retry"),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                var resources = snapshot.data ?? [];

                // Filter by file type
                if (_selectedType != 'All') {
                  resources = resources.where((r) {
                    final ext = r.fileExtension.toLowerCase();
                    if (_selectedType == 'pdf') return ext == 'pdf';
                    if (_selectedType == 'doc') return ext == 'doc' || ext == 'docx';
                    if (_selectedType == 'ppt') return ext == 'ppt' || ext == 'pptx';
                    return ext == _selectedType;
                  }).toList();
                }

                // Filter by search query
                if (_searchQuery.isNotEmpty) {
                  resources = resources.where((r) {
                    final title = r.title.toLowerCase();
                    final course = r.courseCode.toLowerCase();
                    final level = "${r.level} level".toLowerCase();
                    return title.contains(_searchQuery) ||
                        course.contains(_searchQuery) ||
                        level.contains(_searchQuery);
                  }).toList();
                }

                if (resources.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.menu_book_rounded,
                              size: 48,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? "No materials matching '$_searchQuery'"
                                : "No academic materials found",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isNotEmpty
                                ? "Try searching with a different course code or keyword."
                                : "Course PDFs, past questions, and lecture notes will appear here once uploaded by admins.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                          ),
                          if (_searchQuery.isNotEmpty || _selectedLevel != 'All' || _selectedType != 'All') ...[
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _clearFilters,
                              icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                              label: const Text("Clear Filters"),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: resources.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final resource = resources[index];
                    return _ResourceCard(resource: resource);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4F46E5)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4F46E5)
                : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? iconColor;
  final bool isSelected;
  final VoidCallback onSelected;

  const _TypeChip({
    required this.label,
    required this.icon,
    this.iconColor,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4F46E5)
                : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? const Color(0xFF4F46E5) : (iconColor ?? Colors.grey[500]),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? const Color(0xFF4F46E5)
                    : (isDark ? Colors.white70 : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  final Resource resource;

  const _ResourceCard({required this.resource});

  // Clean title display (strips temporary file markers like ~$ if present)
  String get cleanTitle {
    var text = resource.title.trim();
    if (text.startsWith('~\$')) {
      text = text.substring(2);
    }
    return text.isNotEmpty ? text : "${resource.courseCode} Material";
  }

  void _openDocument(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentViewerScreen(
          documentUrl: resource.url,
          title: cleanTitle,
          fileType: resource.fileType,
        ),
      ),
    );
  }

  void _openExternal(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not open external url $url");
    }
  }

  void _shareResource(BuildContext context) {
    SharePlus.instance.share(
      ShareParams(
        text: 'Check out this academic material for ${resource.courseCode}: "$cleanTitle"\n${resource.url}',
        subject: '${resource.courseCode} Resource: $cleanTitle',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ext = resource.fileExtension.toLowerCase();

    // File type branding colors & icons
    Color badgeColor;
    IconData fileIcon;
    if (ext == 'pdf') {
      badgeColor = const Color(0xFFEF4444);
      fileIcon = Icons.picture_as_pdf_rounded;
    } else if (ext == 'doc' || ext == 'docx') {
      badgeColor = const Color(0xFF2563EB);
      fileIcon = Icons.description_rounded;
    } else if (ext == 'ppt' || ext == 'pptx') {
      badgeColor = const Color(0xFFF59E0B);
      fileIcon = Icons.slideshow_rounded;
    } else if (ext == 'xls' || ext == 'xlsx') {
      badgeColor = const Color(0xFF10B981);
      fileIcon = Icons.table_chart_rounded;
    } else {
      badgeColor = const Color(0xFF4F46E5);
      fileIcon = Icons.insert_drive_file_rounded;
    }

    return InkWell(
      onTap: () => _openDocument(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // File Type Brand Badge
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(fileIcon, color: badgeColor, size: 24),
                  ),
                ),
                const SizedBox(width: 14),

                // Title & Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cleanTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),

                      // Course Code, Level & Extension Tags
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              resource.courseCode.isNotEmpty ? resource.courseCode : 'GENERAL',
                              style: const TextStyle(
                                color: Color(0xFF4F46E5),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "${resource.level} Level",
                              style: TextStyle(
                                color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              resource.fileType,
                              style: TextStyle(
                                color: badgeColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // More Menu Button (Share & Download)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: isDark ? Colors.white60 : Colors.grey[500],
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) {
                    if (value == 'open') {
                      _openDocument(context);
                    } else if (value == 'browser') {
                      _openExternal(resource.url);
                    } else if (value == 'share') {
                      _shareResource(context);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'open',
                      child: Row(
                        children: [
                          Icon(Icons.remove_red_eye_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Read In-App'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'browser',
                      child: Row(
                        children: [
                          Icon(Icons.open_in_browser_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Open in Browser / Download'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Share Link'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Action Buttons Row
            Row(
              children: [
                // In-App Open File Button
                Expanded(
                  flex: 3,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      side: BorderSide(
                        color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: Icon(fileIcon, size: 15, color: badgeColor),
                    label: const Text(
                      'Open File',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () => _openDocument(context),
                  ),
                ),
                const SizedBox(width: 8),

                // Practice CBT Button
                Expanded(
                  flex: 4,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 15),
                    label: const Text(
                      'Practice CBT',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CbtPracticeScreen(
                            initialCourseCode: resource.courseCode,
                            initialResourceId: resource.id,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
