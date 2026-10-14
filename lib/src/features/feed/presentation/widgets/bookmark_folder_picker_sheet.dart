import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/bookmark_folders_service.dart';

class BookmarkFolderPickerSheet extends ConsumerStatefulWidget {
  final String postId;

  const BookmarkFolderPickerSheet({super.key, required this.postId});

  static Future<void> show(BuildContext context, String postId) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BookmarkFolderPickerSheet(postId: postId),
    );
  }

  @override
  ConsumerState<BookmarkFolderPickerSheet> createState() => _BookmarkFolderPickerSheetState();
}

class _BookmarkFolderPickerSheetState extends ConsumerState<BookmarkFolderPickerSheet> {
  final _folderNameController = TextEditingController();
  bool _isCreatingFolder = false;
  String _selectedEmoji = '📁';

  final List<String> _emojiChoices = ['📁', '📚', '🎟️', '🛍️', '😂', '⭐', '💡', '🔥', '🎵', '💻', '🎨'];

  @override
  void dispose() {
    _folderNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final folders = ref.watch(bookmarkFoldersProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryTeal.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.bookmark_added_rounded,
                      color: AppColors.secondaryTeal,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Save to Collections',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Organize your saved posts into folders',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isCreatingFolder ? Icons.close_rounded : Icons.create_new_folder_outlined,
                      color: AppColors.secondaryTeal,
                    ),
                    tooltip: _isCreatingFolder ? 'Cancel' : 'New Folder',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _isCreatingFolder = !_isCreatingFolder;
                      });
                    },
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Create New Folder Section
            if (_isCreatingFolder) ...[
              Container(
                padding: const EdgeInsets.all(16),
                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Emoji Picker
                        PopupMenuButton<String>(
                          initialValue: _selectedEmoji,
                          onSelected: (emoji) {
                            setState(() => _selectedEmoji = emoji);
                          },
                          itemBuilder: (context) => _emojiChoices
                              .map(
                                (e) => PopupMenuItem(
                                  value: e,
                                  child: Text(e, style: const TextStyle(fontSize: 20)),
                                ),
                              )
                              .toList(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.black12,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Text(_selectedEmoji, style: const TextStyle(fontSize: 20)),
                                const Icon(Icons.arrow_drop_down, size: 18),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Folder Name Input
                        Expanded(
                          child: TextField(
                            controller: _folderNameController,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'Collection name (e.g. Exams)',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.grey[500] : Colors.grey[400],
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              filled: true,
                              fillColor: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (_) => _handleCreateFolder(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _handleCreateFolder,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondaryTeal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],

            // Folders List
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: folders.length,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 64),
                itemBuilder: (context, index) {
                  final folder = folders[index];
                  final isSavedInFolder = folder.postIds.contains(widget.postId);

                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        folder.emoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    title: Text(
                      folder.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Text(
                      '${folder.postIds.length} saved posts',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    trailing: Checkbox(
                      value: isSavedInFolder,
                      activeColor: AppColors.secondaryTeal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      onChanged: (bool? val) {
                        HapticFeedback.lightImpact();
                        ref
                            .read(bookmarkFoldersProvider.notifier)
                            .togglePostInFolder(widget.postId, folder.id);
                      },
                    ),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref
                          .read(bookmarkFoldersProvider.notifier)
                          .togglePostInFolder(widget.postId, folder.id);
                    },
                  );
                },
              ),
            ),

            // Bottom Done Button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleCreateFolder() {
    final name = _folderNameController.text.trim();
    if (name.isNotEmpty) {
      HapticFeedback.mediumImpact();
      ref.read(bookmarkFoldersProvider.notifier).createFolder(name, emoji: _selectedEmoji);
      _folderNameController.clear();
      setState(() => _isCreatingFolder = false);
    }
  }
}
