with open('lib/src/features/chat/presentation/group_info_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Update _buildRealMembersCard to support inline search & Add Member sheet
old_card_header = """          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Members (${memberIds.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              Row(
                children: [
                  _buildHeaderPillButton(
                    icon: Icons.person_add_alt_1_rounded,
                    label: 'Add Member',
                    isDark: isDark,
                    onTap: () => context.push('/chat/user-search'),
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderPillButton(
                    icon: Icons.search_rounded,
                    label: 'Search',
                    isDark: isDark,
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Real Member List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: memberIds.length,"""

new_card_header = """          final filteredIds = memberIds.where((uid) {
            if (_memberSearchQuery.isEmpty) return true;
            final name = (channel.memberNames[uid] ?? '').toLowerCase();
            return name.contains(_memberSearchQuery.toLowerCase());
          }).toList();

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorderColor, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Members (${filteredIds.length})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        _buildHeaderPillButton(
                          icon: Icons.person_add_alt_1_rounded,
                          label: 'Add Member',
                          isDark: isDark,
                          onTap: () => _showAddMemberSheet(context, channel),
                        ),
                        const SizedBox(width: 8),
                        _buildHeaderPillButton(
                          icon: _isSearchingMembers ? Icons.close_rounded : Icons.search_rounded,
                          label: _isSearchingMembers ? 'Close' : 'Search',
                          isDark: isDark,
                          onTap: () {
                            setState(() {
                              _isSearchingMembers = !_isSearchingMembers;
                              if (!_isSearchingMembers) _memberSearchQuery = '';
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                if (_isSearchingMembers) ...[
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    style: TextStyle(color: textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search members by name...',
                      hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, color: textSecondary, size: 18),
                      filled: true,
                      fillColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onChanged: (val) => setState(() => _memberSearchQuery = val),
                  ),
                ],
                const SizedBox(height: 16),

                // Real Member List
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredIds.length,"""

# Let's replace the outer container in _buildRealMembersCard
old_members_card_start = """  Widget _buildRealMembersCard({
    required ChatChannel channel,
    required Color cardColor,
    required Color cardBorderColor,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    final memberIds = channel.memberIds;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Members (${memberIds.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              Row(
                children: [
                  _buildHeaderPillButton(
                    icon: Icons.person_add_alt_1_rounded,
                    label: 'Add Member',
                    isDark: isDark,
                    onTap: () => context.push('/chat/user-search'),
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderPillButton(
                    icon: Icons.search_rounded,
                    label: 'Search',
                    isDark: isDark,
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Real Member List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: memberIds.length,"""

new_members_card_start = """  Widget _buildRealMembersCard({
    required ChatChannel channel,
    required Color cardColor,
    required Color cardBorderColor,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    final memberIds = channel.memberIds;
    final filteredIds = memberIds.where((uid) {
      if (_memberSearchQuery.isEmpty) return true;
      final name = (channel.memberNames[uid] ?? '').toLowerCase();
      return name.contains(_memberSearchQuery.toLowerCase());
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Members (${filteredIds.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              Row(
                children: [
                  _buildHeaderPillButton(
                    icon: Icons.person_add_alt_1_rounded,
                    label: 'Add Member',
                    isDark: isDark,
                    onTap: () => _showAddMemberSheet(context, channel),
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderPillButton(
                    icon: _isSearchingMembers ? Icons.close_rounded : Icons.search_rounded,
                    label: _isSearchingMembers ? 'Close' : 'Search',
                    isDark: isDark,
                    onTap: () {
                      setState(() {
                        _isSearchingMembers = !_isSearchingMembers;
                        if (!_isSearchingMembers) _memberSearchQuery = '';
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          if (_isSearchingMembers) ...[
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              style: TextStyle(color: textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search members by name...',
                hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: textSecondary, size: 18),
                filled: true,
                fillColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (val) => setState(() => _memberSearchQuery = val),
            ),
          ],
          const SizedBox(height: 16),

          // Real Member List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredIds.length,"""

content = content.replace(old_members_card_start, new_members_card_start)
content = content.replace("final uid = memberIds[index];", "final uid = filteredIds[index];")

# Append new helper methods
helper_methods = """
  Future<void> _shareGroupLink(String displayName) async {
    final link = 'https://abuadapp.com.ng/join/group/${widget.channelId}';
    await SharePlus.instance.share(
      'Join our ABUAD campus group "$displayName" on ABUAD Life:\\n$link',
      subject: 'Join $displayName on ABUAD Life',
    );
  }

  Future<void> _showWallpaperPicker(BuildContext context, bool isDark) async {
    final repo = ref.read(chatRepositoryProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.black : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Group Wallpaper & Background',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Set a custom background image for all members of this group.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryTeal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: AppColors.secondaryTeal),
                  ),
                  title: const Text('Choose Photo from Gallery', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Upload a custom group photo or campus banner', style: TextStyle(fontSize: 12)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      final imageService = ref.read(imageUploadServiceProvider);
                      final file = await imageService.pickImage();
                      if (file != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Setting group wallpaper...')),
                        );
                        final url = await imageService.uploadImage(file, path: 'chat_wallpapers/${widget.channelId}/');
                        if (url != null) {
                          await repo.updateGroupWallpaper(widget.channelId, url);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Group wallpaper updated successfully!')),
                            );
                          }
                        }
                      }
                    } catch (e) {
                      debugPrint('Error uploading group wallpaper: $e');
                    }
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.palette_rounded, color: Colors.purple),
                  ),
                  title: const Text('ABUAD Emerald Campus Preset', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Official ABUAD green and gold mesh style', style: TextStyle(fontSize: 12)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await repo.updateGroupWallpaper(widget.channelId, 'preset_emerald');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ABUAD Emerald wallpaper applied!')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.restart_alt_rounded, color: Colors.red),
                  ),
                  title: const Text('Reset to Default Wallpaper', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.red)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('chat_wallpaper_${widget.channelId}');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Wallpaper reset to default.')),
                      );
                    }
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddMemberSheet(BuildContext context, ChatChannel channel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return _AddMemberModal(
          channel: channel,
          onMembersAdded: () {
            setState(() {
              _channelFuture = ref.read(chatRepositoryProvider).getChannel(widget.channelId);
            });
          },
        );
      },
    );
  }
}

class _AddMemberModal extends ConsumerStatefulWidget {
  final ChatChannel channel;
  final VoidCallback onMembersAdded;

  const _AddMemberModal({required this.channel, required this.onMembersAdded});

  @override
  ConsumerState<_AddMemberModal> createState() => _AddMemberModalState();
}

class _AddMemberModalState extends ConsumerState<_AddMemberModal> {
  final _searchController = TextEditingController();
  final Set<String> _selectedUids = {};
  List<AppUser> _searchResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialUsers();
  }

  Future<void> _loadInitialUsers() async {
    setState(() => _isLoading = true);
    try {
      final userRepo = ref.read(userRepositoryProvider);
      final users = await userRepo.searchUsers('');
      final existingIds = widget.channel.memberIds.toSet();
      if (mounted) {
        setState(() {
          _searchResults = users.where((u) => !existingIds.contains(u.uid)).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onSearch(String query) async {
    setState(() => _isLoading = true);
    try {
      final userRepo = ref.read(userRepositoryProvider);
      final users = await userRepo.searchUsers(query);
      final existingIds = widget.channel.memberIds.toSet();
      if (mounted) {
        setState(() {
          _searchResults = users.where((u) => !existingIds.contains(u.uid)).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.white60 : Colors.black54;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add Members',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  if (_selectedUids.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        final selected = _selectedUids.toList();
                        final success = await ref
                            .read(chatRepositoryProvider)
                            .addMembersToGroup(widget.channel.id, selected);
                        if (success) {
                          widget.onMembersAdded();
                          nav.pop();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Added ${selected.length} member(s) to group')),
                            );
                          }
                        }
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.secondaryTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Text('Add (${_selectedUids.length})'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search students by name or matric...',
                  hintStyle: TextStyle(color: textSecondary),
                  prefixIcon: Icon(Icons.search_rounded, color: textSecondary),
                  filled: true,
                  fillColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: _onSearch,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _searchResults.isEmpty
                      ? Center(
                          child: Text(
                            'No eligible students found to add',
                            style: TextStyle(color: textSecondary),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                          ),
                          itemBuilder: (context, index) {
                            final user = _searchResults[index];
                            final isChecked = _selectedUids.contains(user.uid);
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 4),
                              leading: CircleAvatar(
                                radius: 22,
                                backgroundImage: (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                                    ? CachedNetworkImageProvider(user.avatarUrl!)
                                    : null,
                                backgroundColor: AppColors.secondaryTeal.withValues(alpha: 0.2),
                                child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                                    ? Text(
                                        user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      )
                                    : null,
                              ),
                              title: Text(
                                user.displayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                user.department ?? '@${user.handle}',
                                style: TextStyle(color: textSecondary, fontSize: 12),
                              ),
                              trailing: Checkbox(
                                value: isChecked,
                                activeColor: AppColors.secondaryTeal,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedUids.add(user.uid);
                                    } else {
                                      _selectedUids.remove(user.uid);
                                    }
                                  });
                                },
                              ),
                              onTap: () {
                                setState(() {
                                  if (isChecked) {
                                    _selectedUids.remove(user.uid);
                                  } else {
                                    _selectedUids.add(user.uid);
                                  }
                                });
                              },
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }
}
"""

# Replace the closing brace of _GroupInfoScreenState
last_brace_index = content.rfind('}')
content = content[:last_brace_index] + helper_methods

with open('lib/src/features/chat/presentation/group_info_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("group_info_screen updated successfully!")
