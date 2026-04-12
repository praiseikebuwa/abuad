import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../user/data/user_repository.dart';
import '../data/chat_repository.dart';
import '../../../core/theme/app_colors.dart';

class BroadcastSearchScreen extends ConsumerStatefulWidget {
  const BroadcastSearchScreen({super.key});

  @override
  ConsumerState<BroadcastSearchScreen> createState() => _BroadcastSearchScreenState();
}

class _BroadcastSearchScreenState extends ConsumerState<BroadcastSearchScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _selectedUserIds = {};
  final Map<String, AppUser> _selectedUsers = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleUser(AppUser user) {
    setState(() {
      if (_selectedUserIds.contains(user.uid)) {
        _selectedUserIds.remove(user.uid);
        _selectedUsers.remove(user.uid);
      } else {
        _selectedUserIds.add(user.uid);
        _selectedUsers[user.uid] = user;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final usersStream = ref.watch(userRepositoryProvider).searchUsers(_searchQuery);
    final currentUserId = ref.watch(chatRepositoryProvider).currentUserId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New Broadcast'),
            if (_selectedUserIds.isNotEmpty)
              Text(
                '${_selectedUserIds.length} selected',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          if (_selectedUserIds.isNotEmpty)
            TextButton(
              onPressed: () => context.push(
                '/chat/broadcast/compose',
                extra: _selectedUsers.values.toList(),
              ),
              child: const Text('Next', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search friends to broadcast to...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value.trim()),
            ),
          ),

          // User List
          Expanded(
            child: StreamBuilder<List<AppUser>>(
              stream: usersStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final users = (snapshot.data ?? [])
                    .where((u) => u.uid != currentUserId)
                    .toList();

                if (users.isEmpty) {
                  return const Center(child: Text('No users found'));
                }

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isSelected = _selectedUserIds.contains(user.uid);

                    return ListTile(
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            backgroundImage: user.avatarUrl != null
                                ? CachedNetworkImageProvider(user.avatarUrl!)
                                : null,
                            child: user.avatarUrl == null
                                ? Text(user.displayName[0].toUpperCase())
                                : null,
                          ),
                          if (isSelected)
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: AppColors.secondaryTeal,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, size: 12, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                      title: Text(user.displayName),
                      subtitle: Text(user.handle.isNotEmpty ? user.handle : user.email),
                      trailing: Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggleUser(user),
                        activeColor: AppColors.secondaryTeal,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      onTap: () => _toggleUser(user),
                    );
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
